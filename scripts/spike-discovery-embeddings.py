#!/usr/bin/env python3
"""Measure whether embedding retrieval finds the right Meal from an Egyptian Arabic phrasing.

E3's discovery design assumes an embedding model places "نفسي في حاجة خفيفة" near a salad and a
soup. That is an assumption about dialect quality, and this repository's habit after 2026-08-06 is
that a claim must have been seen to fail. This script is how it gets checked.

Reads docs/ops/discovery-corpus.json, embeds every Meal and every query, ranks by cosine
similarity, and reports accuracy split by whether the query shares words with its targets. A
retriever that only works on shared words is ILIKE with extra steps, which .claude/rules/supabase.md
forbids by name.

    GEMINI_API_KEY=... python3 scripts/spike-discovery-embeddings.py

Spike code. It calls a vendor directly rather than through the provider abstraction, which is fine
here and NOT fine in Kafoo — ADR-0005 Amendment 1 requires every production model call to go through
supabase/functions/_shared/ai/. Productionising this means moving the call, not copying this file.
"""

import json
import math
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://generativelanguage.googleapis.com/v1beta/models/{model}:batchEmbedContents?key={key}"
CORPUS = os.path.join(os.path.dirname(__file__), "..", "docs", "ops", "discovery-corpus.json")

# Each (model, dimensions) pair is a separate candidate. 3072 is Gemini's default and is included
# to be measured, not because it can ship: pgvector's HNSW index refuses more than 2000 dimensions,
# so a 3072-dimension column cannot have the index the rules require.
CANDIDATES = [
    ("gemini-embedding-001", 768),
    ("gemini-embedding-001", 1536),
    ("gemini-embedding-001", 3072),
    ("gemini-embedding-2", 1536),
]

TOP_K = 5


def embed(texts, model, dims, task_type, key):
    """Embed a list of texts. Batched, retried, and normalized."""
    out = []
    for start in range(0, len(texts), 20):
        chunk = texts[start : start + 20]
        body = {
            "requests": [
                {
                    "model": f"models/{model}",
                    "content": {"parts": [{"text": t}]},
                    "taskType": task_type,
                    "outputDimensionality": dims,
                }
                for t in chunk
            ]
        }
        payload = json.dumps(body).encode()
        for attempt in range(5):
            try:
                req = urllib.request.Request(
                    API.format(model=model, key=key),
                    data=payload,
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=120) as r:
                    data = json.load(r)
                out.extend(e["values"] for e in data["embeddings"])
                # The free tier allows 100 requests/minute per model, and a batch's ITEMS appear to
                # count individually rather than the call counting once — a four-candidate sweep
                # issues ~224 of them and trips the cap partway through, which is exactly where it
                # failed. Pace by item so the sweep completes instead of half-reporting.
                # ponytail: fixed sleep, not a token bucket. Swap it if a paid tier makes it matter.
                time.sleep(len(chunk) * 0.65)
                break
            except urllib.error.HTTPError as e:
                detail = e.read().decode()[:300]
                # The free-tier limit is per MINUTE, so backoff has to cross a minute boundary or it
                # reports a quota failure that a 60-second wait would have cleared. 15s of total
                # backoff read as "out of quota" here and was not.
                if e.code in (429, 500, 503) and attempt < 4:
                    time.sleep(min(75, 15 * 2**attempt))
                    continue
                raise SystemExit(f"{model}/{dims} {task_type}: HTTP {e.code} {detail}")
        else:
            raise SystemExit(f"{model}/{dims}: exhausted retries")
    # Gemini normalizes only at its native 3072; a truncated vector must be renormalized or cosine
    # similarity is quietly wrong. Normalizing unconditionally costs nothing and removes the doubt.
    return [_normalize(v) for v in out]


def _normalize(v):
    n = math.sqrt(sum(x * x for x in v))
    return [x / n for x in v] if n else v


def cosine(a, b):
    return sum(x * y for x, y in zip(a, b))


def evaluate(corpus, model, dims, key):
    meals, queries = corpus["meals"], corpus["queries"]
    # A Meal is embedded as the text a Customer is searching against: its name and description.
    docs = [f"{m['name']}. {m['description']}" for m in meals]
    doc_vecs = embed(docs, model, dims, "RETRIEVAL_DOCUMENT", key)
    q_vecs = embed([q["text"] for q in queries], model, dims, "RETRIEVAL_QUERY", key)

    rows = []
    for q, qv in zip(queries, q_vecs):
        scored = sorted(
            ((cosine(qv, dv), m["id"]) for m, dv in zip(meals, doc_vecs)), reverse=True
        )
        top = [mid for _, mid in scored[:TOP_K]]
        rel = set(q["relevant"])
        hits = [mid for mid in top if mid in rel]
        first = next((i + 1 for i, mid in enumerate(m for _, m in scored) if mid in rel), None)
        # An absolute cosine threshold cannot tell "nothing matched" from "something matched",
        # because score magnitude varies more between queries than between a hit and a miss. The
        # margin below asks a relative question instead: does the best Meal stand out from the rest
        # of the corpus for THIS query? A query nothing answers should produce a flat distribution.
        all_scores = [s for s, _ in scored]
        mean_s = sum(all_scores) / len(all_scores)
        std_s = math.sqrt(sum((s - mean_s) ** 2 for s in all_scores) / len(all_scores))
        margin = (scored[0][0] - mean_s) / std_s if std_s else 0.0

        rows.append(
            {
                "id": q["id"],
                "overlap": q["overlap"],
                "has_relevant": bool(rel),
                "top": top,
                "top_score": round(scored[0][0], 4),
                "margin": round(margin, 3),
                "top1_hit": bool(top and top[0] in rel),
                # Precision@5 is meaningless when a query has fewer than 5 correct answers, so it is
                # capped by how many exist. Otherwise the seafood query scores 0.4 at perfect recall.
                "p_at_k": len(hits) / min(TOP_K, len(rel)) if rel else None,
                "recall_at_k": len(hits) / len(rel) if rel else None,
                "first_rank": first,
                "rr": 1 / first if first else 0.0,
            }
        )
    return rows


def report(rows, label):
    scored = [r for r in rows if r["has_relevant"]]
    n = len(scored)
    print(f"\n=== {label} ===")
    print(f"{'query':<22} {'ovlp':<8} {'top1':<5} {'P@5':<6} {'R@5':<6} {'rank':<5} top score")
    for r in rows:
        p = f"{r['p_at_k']:.2f}" if r["p_at_k"] is not None else "  — "
        rc = f"{r['recall_at_k']:.2f}" if r["recall_at_k"] is not None else "  — "
        rank = str(r["first_rank"]) if r["first_rank"] else "—"
        print(
            f"{r['id']:<22} {r['overlap']:<8} {'YES' if r['top1_hit'] else 'no':<5} "
            f"{p:<6} {rc:<6} {rank:<5} {r['top_score']:.4f}"
        )

    def mean(key, subset):
        vals = [s[key] for s in subset if s[key] is not None]
        return sum(vals) / len(vals) if vals else float("nan")

    print(f"\n  top-1 accuracy {sum(r['top1_hit'] for r in scored)}/{n}")
    print(f"  mean P@5       {mean('p_at_k', scored):.3f}")
    print(f"  mean recall@5  {mean('recall_at_k', scored):.3f}")
    print(f"  MRR            {mean('rr', scored):.3f}")

    for kind in ("none", "direct", "negated"):
        sub = [r for r in scored if r["overlap"] == kind]
        if sub:
            print(
                f"  overlap={kind:<8} n={len(sub):<3} top-1 {sum(s['top1_hit'] for s in sub)}/{len(sub)}"
                f"  P@5 {mean('p_at_k', sub):.3f}  MRR {mean('rr', sub):.3f}"
            )

    # Can a score threshold tell "nothing matched" from "something matched"? Without that gap there
    # is no honest way to emit SearchFailed, and Kafoo would show its best wrong answer instead.
    empty = [r for r in rows if not r["has_relevant"]]
    if empty:
        for field, fmt in (("top_score", ".4f"), ("margin", ".3f")):
            worst_real = min(r[field] for r in scored)
            best_empty = max(r[field] for r in empty)
            gap = worst_real - best_empty
            verdict = "separable" if gap > 0 else "NOT SEPARABLE"
            print(
                f"  by {field:<10} no-match {best_empty:{fmt}} vs worst real {worst_real:{fmt}}"
                f"  gap {gap:+{fmt}}  → {verdict}"
            )


def main():
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise SystemExit("GEMINI_API_KEY is unset — nothing to measure.")
    with open(CORPUS, encoding="utf-8") as f:
        corpus = json.load(f)

    # Free-tier quota is tight enough that the full sweep gets throttled part way through, so
    # candidates can be named on the command line to re-run only what failed: model:dims
    candidates = CANDIDATES
    if len(sys.argv) > 1:
        candidates = [(a.rsplit(":", 1)[0], int(a.rsplit(":", 1)[1])) for a in sys.argv[1:]]

    print(f"{len(corpus['meals'])} Meals, {len(corpus['queries'])} queries")
    for model, dims in candidates:
        try:
            report(evaluate(corpus, model, dims, key), f"{model} @ {dims}d")
        except SystemExit as e:
            print(f"\n=== {model} @ {dims}d ===\n  FAILED: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
