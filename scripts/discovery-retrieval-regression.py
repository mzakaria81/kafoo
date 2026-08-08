#!/usr/bin/env python3
"""SC-002 and SC-003, by name, against the discovery corpus.

T153 and T155. `spike-discovery-embeddings.py` answered "does embedding retrieval work at all" once,
by hand, across four candidate models. This asks a narrower question on a schedule: **does the model
Kafoo actually ships still satisfy the two success criteria that depend on retrieval quality?**

    GEMINI_API_KEY=... python3 scripts/discovery-retrieval-regression.py
    GEMINI_API_KEY=... python3 scripts/discovery-retrieval-regression.py --record   # set the baseline

- **SC-002** — a request phrased in a different language or script from a Meal's description returns
  that Meal in the top five in at least **95%** of tested cases.
- **SC-003** — for requests something on offer genuinely answers, a relevant Meal appears in the top
  five in at least **80%** of tested cases.

THIS RUNS NIGHTLY, NOT IN THE GATE. Founder's decision, 2026-08-08. It calls a vendor, and
`./scripts/verify.sh` has never depended on one — putting it there would mean a Google outage or an
expired key blocks every commit by every session, for a property that drifts over weeks rather than
between commits. `.github/workflows/retrieval-regression.yml` is where it runs.

WHAT THIS MEASURES, AND WHAT IT DOES NOT. It ranks the corpus by cosine similarity in memory, which
is the retrieval quality of the MODEL. The shipped path adds pgvector's HNSW index on top, and an
approximate index can return a different top five from an exact scan. So a green run here means the
embeddings are still good; it does not prove the deployed query is. Measuring that needs the corpus
in a database, and the corpus is synthetic — Kafoo's trust rules keep it out of any environment that
holds real Meals, which is why this stops at the model.
# ponytail: exact scan, not the index. If HNSW recall ever becomes the suspect, this needs a
# throwaway database rather than a bigger script.

The corpus is a fixture and stays one: `docs/ops/discovery-corpus.json`, synthetic by design, never
seed data, never near a migration.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CORPUS = ROOT / "docs" / "ops" / "discovery-corpus.json"
BASELINE = ROOT / "docs" / "ops" / "discovery-retrieval-baseline.json"
REGISTRY = ROOT / "supabase" / "functions" / "_shared" / "ai" / "registry.ts"

# The thresholds are the success criteria themselves. They live in specs/004-customer-discovery/
# spec.md and are repeated here because a check that reads its own pass mark from a document nobody
# parses is a check with no pass mark. If the spec changes, change both and say so in the commit.
SC002_MIN = 0.95
SC003_MIN = 0.80

# The vendor call, its retry policy and its free-tier pacing are all hard-won and commented in the
# spike. Importing them beats a second copy that learns the same lessons again. The filename has
# hyphens, so it cannot be a plain import.
_spec = importlib.util.spec_from_file_location(
    "spike_discovery_embeddings", ROOT / "scripts" / "spike-discovery-embeddings.py"
)
_spike = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_spike)


def shipped_config() -> tuple[str, int]:
    """The embedding model and width Kafoo actually uses, read from the registry.

    Not hardcoded, and not passed in by the workflow. ADR-0005 Amendment 1 makes the registry the
    one place a model id lives; a regression that names its own model measures whatever it was
    written against and goes on passing after somebody switches the provider.
    """
    source = REGISTRY.read_text(encoding="utf-8")
    model = re.search(r"embeddingModel:\s*'([^']+)'", source)
    dims = re.search(r"EMBEDDING_DIMENSIONS\s*=\s*(\d+)", source)
    if not model or not dims:
        raise SystemExit(
            f"could not read embeddingModel / EMBEDDING_DIMENSIONS from {REGISTRY}. "
            "The registry moved or was reshaped; fix this rather than hardcoding a model."
        )
    # The first `embeddingModel:` in the file is the default provider's. Anthropic and OpenAI
    # declare null, which this pattern does not match, so it cannot silently pick the wrong one.
    return model.group(1), int(dims.group(1))


def measure(rows: list[dict], queries: list[dict]) -> dict:
    """SC-002 and SC-003 from the spike's per-query rows.

    "In the top five" is `recall_at_k > 0` — at least one relevant Meal among the five. Not top-1:
    both criteria are written about the top five, and holding them to rank 1 would fail runs that
    satisfy the thing the Customer was promised.
    """
    by_id = {q["id"]: q for q in queries}
    answerable = [r for r in rows if r["has_relevant"]]
    cross = [r for r in answerable if by_id[r["id"]].get("cross_script")]

    # ONE predicate, used by both the count and the rate. They were separate expressions until a
    # mutation run on 2026-08-08 changed "top five" to "top one" and the self-check stayed green:
    # the rate moved and the count did not, so nothing disagreed. Two copies of a rule are a rule
    # that can half-change.
    def in_top_five(r: dict) -> bool:
        return (r["recall_at_k"] or 0) > 0

    def summarise(subset: list[dict], statement: str, threshold: float) -> dict:
        hits = sum(1 for r in subset if in_top_five(r))
        return {
            "statement": statement,
            "cases": len(subset),
            "hits": hits,
            "rate": (hits / len(subset)) if subset else None,
            "threshold": threshold,
            "queries": {r["id"]: r["first_rank"] for r in subset},
        }

    return {
        "SC-002": summarise(
            cross,
            "A request phrased in a different language or script from a Meal's description "
            "returns that Meal in the top five results in at least 95% of tested cases.",
            SC002_MIN,
        ),
        "SC-003": summarise(
            answerable,
            "For requests that something on offer genuinely answers, a relevant Meal appears "
            "in the top five in at least 80% of tested cases.",
            SC003_MIN,
        ),
    }


def verdicts(result: dict) -> list[tuple[str, bool, str]]:
    out = []
    for name in ("SC-002", "SC-003"):
        sc = result[name]
        if sc["rate"] is None:
            out.append((name, False, "no cases — the corpus lost the queries this criterion needs"))
            continue
        ok = sc["rate"] >= sc["threshold"]
        out.append(
            (
                name,
                ok,
                f"{sc['hits']}/{sc['cases']} in the top five = {sc['rate']:.0%} "
                f"(needs {sc['threshold']:.0%})",
            )
        )
    return out


def compare(result: dict, baseline: dict) -> list[str]:
    """Per-query rank movement against the recorded baseline.

    Reported, never failed on. A rank that slips from 1 to 2 satisfies both criteria and is not a
    regression; failing on it would train everyone to re-record the baseline, which is how a
    baseline stops meaning anything.
    """
    notes = []
    for name in ("SC-002", "SC-003"):
        was = baseline.get("criteria", {}).get(name, {}).get("queries", {})
        now = result[name]["queries"]
        for qid, rank in sorted(now.items()):
            before = was.get(qid)
            if before is None:
                notes.append(f"  {name} {qid}: new query, rank {rank}")
            elif before != rank:
                notes.append(f"  {name} {qid}: rank {before} -> {rank}")
    return notes


def self_check() -> int:
    """The arithmetic, with no network and no key.

    The failure this exists to catch is the expensive one: a run that prints PASS while a criterion
    is breached. That is silent, it is believed, and the nightly job would go on being green for
    months. So the cases below are all near the threshold rather than obviously right or wrong, and
    the workflow runs this BEFORE spending anything.

    Every case was watched failing before it passed — `>=` flipped to `>`, `recall_at_k` swapped for
    top-1, and the cross-script filter dropped — each of which turns exactly one assertion red.
    """

    def rows(*spec):
        # (id, has_relevant, rank_of_first_relevant_or_None)
        return [
            {
                "id": qid,
                "has_relevant": has,
                "recall_at_k": (1.0 if rank and rank <= _spike.TOP_K else 0.0) if has else None,
                "first_rank": rank,
            }
            for qid, has, rank in spec
        ]

    def queries(*ids_cross):
        return [{"id": qid, "cross_script": cross} for qid, cross in ids_cross]

    # 1. Rank 5 counts and rank 6 does not. "Top five" is the promise, and an off-by-one here
    #    quietly changes what both criteria mean. Asserted on the RATE as well as the count: when
    #    those were two expressions, a "top five -> top one" mutation moved one and not the other
    #    and this case stayed green.
    r = measure(
        rows(("a", True, 5), ("b", True, 6)),
        queries(("a", True), ("b", True)),
    )
    assert r["SC-002"]["hits"] == 1, r["SC-002"]
    assert r["SC-002"]["cases"] == 2, r["SC-002"]
    assert r["SC-002"]["rate"] == 0.5, r["SC-002"]

    # 1b. And rank 1 is not the bar. A criterion written about the top five must not quietly become
    #     a criterion about rank 1 — that fails runs which deliver exactly what was promised.
    r = measure(rows(("mid", True, 4)), queries(("mid", False)))
    assert r["SC-003"]["rate"] == 1.0, r["SC-003"]
    assert verdicts(r)[1][1] is True, "rank 4 is inside the top five"

    # 2. SC-002 counts ONLY cross-script queries; SC-003 counts every answerable one. A filter that
    #    silently widens turns four hard cases into twenty easy ones and the criterion stops biting.
    r = measure(
        rows(("cross", True, 1), ("arabic", True, 1), ("also_arabic", True, 99)),
        queries(("cross", True), ("arabic", False), ("also_arabic", False)),
    )
    assert r["SC-002"]["cases"] == 1, r["SC-002"]
    assert r["SC-003"]["cases"] == 3, r["SC-003"]

    # 3. A query nothing answers belongs to neither criterion. Both are written about requests that
    #    something on offer genuinely answers; counting the no-match query as a miss would fail a
    #    run for behaving correctly.
    r = measure(rows(("none", False, None)), queries(("none", False)))
    assert r["SC-003"]["cases"] == 0, r["SC-003"]
    assert r["SC-003"]["rate"] is None, r["SC-003"]
    assert verdicts(r)[1][1] is False, "an empty criterion must not report PASS"

    # 4. The threshold is inclusive. Exactly 80% satisfies "at least 80%", and a `>` here would fail
    #    a run that meets the spec — the direction that gets fixed by weakening the threshold.
    r = measure(
        rows(*[(f"q{i}", True, 1) for i in range(4)], ("miss", True, 99)),
        queries(*[(f"q{i}", False) for i in range(4)], ("miss", False)),
    )
    assert r["SC-003"]["rate"] == 0.8, r["SC-003"]
    assert verdicts(r)[1][1] is True, "80% must satisfy 'at least 80%'"

    # 5. And one under it fails, so the check can actually go red.
    r = measure(
        rows(*[(f"q{i}", True, 1) for i in range(3)], ("m1", True, 99), ("m2", True, 99)),
        queries(*[(f"q{i}", False) for i in range(3)], ("m1", False), ("m2", False)),
    )
    assert verdicts(r)[1][1] is False, "60% must not satisfy 'at least 80%'"

    # 6. Rank movement is reported, never failed on. A cross-script query is counted by BOTH
    #    criteria, so it moves under both — which is what the first run of this case proved, by
    #    disagreeing with an expectation that had assumed one line.
    moved = compare(
        measure(rows(("a", True, 2)), queries(("a", True))),
        {"criteria": {"SC-002": {"queries": {"a": 1}}, "SC-003": {"queries": {"a": 1}}}},
    )
    assert moved == ["  SC-002 a: rank 1 -> 2", "  SC-003 a: rank 1 -> 2"], moved

    # 7. A query the baseline never saw is named as new rather than silently ignored — otherwise
    #    adding a query to the corpus and never measuring it looks identical to measuring it.
    moved = compare(
        measure(rows(("fresh", True, 3)), queries(("fresh", False))),
        {"criteria": {"SC-003": {"queries": {}}}},
    )
    assert moved == ["  SC-003 fresh: new query, rank 3"], moved

    print("self-check: 8 cases pass, no network used")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--record",
        action="store_true",
        help="write the measured result to the baseline file instead of checking against it",
    )
    parser.add_argument(
        "--self-check",
        action="store_true",
        help="verify this script's own arithmetic without a key or a network call",
    )
    args = parser.parse_args()

    if args.self_check:
        return self_check()

    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise SystemExit("GEMINI_API_KEY is unset — nothing to measure.")

    corpus = json.loads(CORPUS.read_text(encoding="utf-8"))
    model, dims = shipped_config()
    print(f"{len(corpus['meals'])} Meals, {len(corpus['queries'])} queries, {model} @ {dims}d")

    rows = _spike.evaluate(corpus, model, dims, key)
    result = measure(rows, corpus["queries"])

    for name, ok, detail in verdicts(result):
        print(f"  {name}  {'PASS' if ok else 'FAIL'}  {detail}")

    if args.record:
        BASELINE.write_text(
            json.dumps(
                {
                    "note": (
                        "Recorded by scripts/discovery-retrieval-regression.py --record. "
                        "Rank movement against this file is reported, never failed on; only the "
                        "SC-002 and SC-003 thresholds fail a run."
                    ),
                    "model": model,
                    "dimensions": dims,
                    "criteria": result,
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"\nbaseline written to {BASELINE.relative_to(ROOT)}")
        return 0

    if BASELINE.exists():
        baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
        if baseline.get("model") != model or baseline.get("dimensions") != dims:
            print(
                f"\n  baseline was recorded against {baseline.get('model')} @ "
                f"{baseline.get('dimensions')}d — rank comparison skipped."
            )
        else:
            moved = compare(result, baseline)
            print("\nagainst the baseline:")
            print("\n".join(moved) if moved else "  every rank unchanged")
    else:
        print(f"\n  no baseline at {BASELINE.relative_to(ROOT)} — run with --record to set one.")

    failed = [name for name, ok, _ in verdicts(result) if not ok]
    if failed:
        print(f"\nFAIL: {', '.join(failed)}", file=sys.stderr)
        return 1
    print("\nPASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
