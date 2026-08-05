#!/usr/bin/env python3
"""Spend ledger for delegated OpenCode work.

WHY THIS EXISTS. OpenCode Go is not flat-rate. It meters usage against three dollar-denominated
caps — $12 per rolling five hours, $30 a week, $60 a month — and the failure mode is not a surprise
bill, it is work stopping in the middle of a task. Before this file existed, every dispatch was
fire-and-hope: the cost was visible in the relay's result.json afterwards and nowhere before.

WHY A FILE IN THE REPOSITORY AND NOT `opencode stats`. `opencode stats` reads the local session
database, and Kafoo development runs in ephemeral containers that are destroyed after each session.
That number resets to zero every time, which is exactly wrong for a rolling multi-day cap. The
repository is the only storage that outlives a container, and only for what is committed — so the
ledger is committed, and a session that forgets to commit it has lost its own history.

WHAT IT IS NOT. This is not a quota reading. The authoritative number lives in the OpenCode
workspace console, which needs a browser credential this environment does not have and should not
have. This ledger is a record of what WE spent, which approximates the account total only while
delegated coding is the sole consumer of the subscription. The founder confirmed that on
2026-08-03. If that ever stops being true, this under-reports and the gap is silent.

WHY IT READS OTHER BRANCHES. The caps are per account, not per branch and not per session. Two
Claude Code sessions working in parallel each have their own checkout, so a report that read only
the local file would show each session roughly half the real spend — and both would print "OK to
dispatch" while jointly over a cap. So `report` also reads this file out of every remote-tracking
ref and unions the rows, deduplicating on the relay session id. That makes a committed and pushed
row visible to the other session, and an uncommitted one invisible: push after every dispatch.

USAGE

    scripts/opencode-spend.py record <path to a relay result.json or its directory>
    scripts/opencode-spend.py report            # human-readable, before dispatching
    scripts/opencode-spend.py report --json     # machine-readable
    scripts/opencode-spend.py report --local    # skip the fetch and the other branches

Append-only. One JSON object per line, never rewritten, so two sessions writing at once cannot
destroy each other's rows — the same reason the observation log is appended rather than edited.
"""

from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LEDGER = REPO / ".claude" / "opencode-spend.jsonl"
LEDGER_PATH_IN_GIT = ".claude/opencode-spend.jsonl"

# What the OpenCode console actually billed, per day and per model, read off the founder's daily
# screenshot. Kept in its own file rather than as rows in the ledger: a calibration row carrying a
# `cost` would be summed as spend by everything below, and the check would corrupt the number it
# exists to check.
#
# This exists because the ledger's figures are what the relay COMPUTES, not what the account is
# BILLED, and on 2026-08-05 those turned out to differ per model rather than uniformly:
#
#     qwen3.6-plus   ledger $4.24  console $4.36   -2.7%   (-2%, -3%, -3% on three days)
#     grok-4.5       ledger $7.28  console $5.35  +36.0%   (+1181%, -25%, +33%, +33%)
#
# qwen is accurate to within 3% every day. grok is not, and the two most recent days agree at +33%,
# which is stable enough to correct for. The two earliest days are the first two days this tooling
# was used at all and include a failed Zen dispatch and two runs at 21:03 and 21:10 UTC — close
# enough to a day boundary that the console may bill them to the next day. That is a hypothesis, not
# a finding: rows near midnight UTC are the diagnostic, and more calibration days will settle it.
#
# The correction below is therefore honest about being empirical. It is a measured factor per model,
# not a theory about why.
CALIBRATION = REPO / ".claude" / "opencode-calibration.jsonl"

# The founder's stated tolerance, 2026-08-05: a day inside this after correction is fine. Outside it
# means the factor has stopped holding — a signal to investigate, never to widen the band.
TOLERANCE = 0.08

# https://opencode.ai/docs/go/ — read 2026-08-03.
#
# The docs say "weekly" and "monthly" without saying whether those reset on a boundary or roll.
# Rolling is assumed because it is the stricter reading: if the real windows reset on a calendar
# boundary, this reports MORE spend than counts against the cap, and warns early rather than late.
# A budget guard should be wrong in the direction that stops work too soon, not too late.
CAPS = [
    ("5 hours", timedelta(hours=5), 12.0),
    ("week", timedelta(days=7), 30.0),
    ("month", timedelta(days=30), 60.0),
]

WARN_AT = 0.70  # fraction of a cap that turns the report yellow
STOP_AT = 0.90  # ...and red


def _parse_rows(text: str, origin: str) -> list[dict]:
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            # One unreadable row must not blind the whole report. Skipping it under-reports, which
            # is the safe direction, and the count below makes the skip visible rather than silent.
            print(f"warning: skipping unparseable ledger row in {origin}: {line[:80]}",
                  file=sys.stderr)
            continue
        row["_origin"] = origin
        rows.append(row)
    return rows


def _load() -> list[dict]:
    if not LEDGER.exists():
        return []
    return _parse_rows(LEDGER.read_text(encoding="utf-8"), "local")


def _git(*args: str, timeout: int = 30) -> str | None:
    """Run a git command, returning its stdout or None if it failed for any reason.

    Every caller treats failure as "no extra rows". A report that cannot reach the network must
    still print — it simply sees less spend, and says so, rather than refusing to answer.
    """
    try:
        done = subprocess.run(("git", *args), cwd=REPO, capture_output=True,
                              text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return done.stdout if done.returncode == 0 else None


def _identity(row: dict) -> tuple:
    """What makes two ledger rows the same dispatch across two branches.

    The relay session id is the real key and `record` already refuses to write a duplicate of one.
    A row without a session id — a relay that died before it had one — falls back to the fields
    that would have to collide by coincidence.
    """
    session = row.get("session")
    if session:
        return ("session", session)
    return ("fallback", row.get("at"), row.get("model"), row.get("cost"))


def _remote_rows(fetch: bool) -> tuple[list[dict], bool]:
    """Ledger rows committed on branches other than this one. Returns (rows, network_ok)."""
    network_ok = True
    if fetch:
        # Without this, a session started before the other one pushed would never see its rows.
        network_ok = _git("fetch", "--quiet", "--all", timeout=60) is not None

    refs = _git("for-each-ref", "--format=%(refname)", "refs/remotes")
    if refs is None:
        return [], False

    rows = []
    for ref in refs.split():
        if ref.endswith("/HEAD"):
            continue
        blob = _git("show", f"{ref}:{LEDGER_PATH_IN_GIT}")
        if blob:
            rows.extend(_parse_rows(blob, ref))
    return rows, network_ok


def _load_all(fetch: bool) -> tuple[list[dict], int, bool]:
    """Local rows unioned with every remote branch's. Returns (rows, from_other_branches, net_ok)."""
    rows = _load()
    seen = {_identity(r) for r in rows}

    remote, network_ok = _remote_rows(fetch)
    elsewhere = 0
    for row in remote:
        key = _identity(row)
        if key in seen:
            continue
        seen.add(key)
        rows.append(row)
        elsewhere += 1
    return rows, elsewhere, network_ok


def record(target: str) -> int:
    path = Path(target)
    if path.is_dir():
        path = path / "result.json"
    if not path.exists():
        print(f"no result.json at {path}", file=sys.stderr)
        return 1

    result = json.loads(path.read_text(encoding="utf-8"))

    # A run that failed before reaching a model still gets a row. Its cost is 0.0 and recording it
    # keeps the ledger a history of dispatches rather than only of successful ones — which is what
    # makes "how many attempts did that task take" answerable later.
    row = {
        "at": result.get("finishedAt") or result.get("startedAt")
        or datetime.now(timezone.utc).isoformat(),
        "model": result.get("model", "unknown"),
        "cost": float(result.get("cost") or 0.0),
        "status": result.get("status", "unknown"),
        "session": result.get("sessionId"),
        "files": len(result.get("touchedFiles") or []),
    }

    existing = _load()
    if any(r.get("session") == row["session"] and row["session"] for r in existing):
        print(f"already recorded session {row['session']} — not double counting")
        return 0

    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    with LEDGER.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"recorded {row['model']} ${row['cost']:.4f} at {row['at']}")
    return 0


def _parse(stamp: str) -> datetime | None:
    try:
        parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def _calibration() -> list[dict]:
    if not CALIBRATION.exists():
        return []
    rows = []
    for line in CALIBRATION.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if {"day", "model", "console_cost"} <= row.keys():
            rows.append(row)

    # A second reading for a day supersedes the first rather than adding to it.
    #
    # The file is append-only on purpose — it carries a union merge so two sessions can write it at
    # once — but "append-only" is a storage rule, not an arithmetic one. A day read at noon and read
    # again at midnight produces two rows for the same day and model, and _factors() below sums
    # every row it is given: the day's ledger total would be counted twice, against two different
    # console figures, and the correction it exists to compute would be wrong in a way nothing
    # prints. Last row per (day, model) wins, ordered by recorded_at and falling back to file order
    # for rows written before that field existed.
    latest: dict[tuple[str, str], tuple[str, int, dict]] = {}
    for i, row in enumerate(rows):
        key = (row["day"], row["model"])
        stamp = (str(row.get("recorded_at", "")), i)
        if key not in latest or stamp > latest[key][:2]:
            latest[key] = (stamp[0], stamp[1], row)
    return [v[2] for v in latest.values()]


def _factors(rows: list[dict]) -> tuple[dict[str, float], list[dict]]:
    """Per-model correction from ledger figures to billed figures.

    Returns the factors and a per-day residual for each calibrated day, so the report can show
    where the correction stops holding rather than quietly absorbing it.
    """
    cal = _calibration()
    if not cal:
        return {}, []

    ledger_by_day: dict[tuple[str, str], float] = {}
    for r in rows:
        at = r.get("at", "")
        if not at:
            continue
        key = (at[:10], r["model"])
        ledger_by_day[key] = ledger_by_day.get(key, 0.0) + r["cost"]

    totals: dict[str, list[float]] = {}
    residuals = []
    for c in cal:
        key = (c["day"], c["model"])
        led = ledger_by_day.get(key, 0.0)
        con = float(c["console_cost"])
        entry = totals.setdefault(c["model"], [0.0, 0.0])
        entry[0] += led
        entry[1] += con
        residuals.append({"day": c["day"], "model": c["model"], "ledger": round(led, 4),
                          "console": round(con, 4)})

    factors = {m: (con / led) for m, (led, con) in totals.items() if led > 0}

    for r in residuals:
        f = factors.get(r["model"], 1.0)
        corrected = r["ledger"] * f
        r["corrected"] = round(corrected, 4)
        r["residual"] = round((corrected - r["console"]) / r["console"], 4) if r["console"] else 0.0
        r["within_tolerance"] = abs(r["residual"]) <= TOLERANCE
    return factors, residuals


def report(as_json: bool, local_only: bool = False) -> int:
    if local_only:
        rows, elsewhere, network_ok = _load(), 0, True
    else:
        rows, elsewhere, network_ok = _load_all(fetch=True)
    now = datetime.now(timezone.utc)

    # Correct each row toward what the account was actually billed before any cap is compared
    # against it. The caps are billed dollars; the ledger holds computed dollars. Comparing the
    # second to the first was the mistake, and on grok-4.5 it overstated spend by a third — which
    # errs safe on the cap and wastes a third of the window.
    factors, residuals = _factors(rows)

    def billed(row: dict) -> float:
        return row["cost"] * factors.get(row["model"], 1.0)

    windows = []
    for label, span, cap in CAPS:
        cutoff = now - span
        spent = sum(billed(r) for r in rows
                    if (at := _parse(r.get("at", ""))) and at >= cutoff)
        windows.append({
            "window": label,
            "spent": round(spent, 4),
            "cap": cap,
            "remaining": round(cap - spent, 4),
            "used_fraction": round(spent / cap, 4) if cap else 0.0,
        })

    by_model: dict[str, dict] = {}
    for r in rows:
        entry = by_model.setdefault(r["model"], {"dispatches": 0, "cost": 0.0, "raw": 0.0})
        entry["dispatches"] += 1
        entry["cost"] = round(entry["cost"] + billed(r), 4)
        entry["raw"] = round(entry["raw"] + r["cost"], 4)

    worst = max((w["used_fraction"] for w in windows), default=0.0)
    verdict = "stop" if worst >= STOP_AT else "warn" if worst >= WARN_AT else "ok"

    if as_json:
        print(json.dumps({
            "verdict": verdict,
            "windows": windows,
            "by_model": by_model,
            "dispatches": len(rows),
            "from_other_branches": elsewhere,
            "network_ok": network_ok,
            "ledger": str(LEDGER.relative_to(REPO)),
            "factors": {m: round(f, 4) for m, f in factors.items()},
            "calibration": residuals,
            "tolerance": TOLERANCE,
        }, indent=2))
        return 0

    print("OpenCode Go spend — delegated work only, not an account reading")
    seen_elsewhere = f", {elsewhere} from other branches" if elsewhere else ""
    print(f"  ledger: {LEDGER.relative_to(REPO)}  ({len(rows)} dispatches{seen_elsewhere})")
    if not network_ok and not local_only:
        print("  WARNING: could not reach the remote, so a parallel session's spend is invisible.")
        print("  Treat every cap below as HALF of what it says.")
    print()
    for w in windows:
        bar_len = 24
        filled = min(bar_len, int(w["used_fraction"] * bar_len))
        bar = "#" * filled + "." * (bar_len - filled)
        print(f"  last {w['window']:<8} [{bar}] "
              f"${w['spent']:>6.2f} / ${w['cap']:>5.2f}   ${w['remaining']:>6.2f} left")
    print()
    if by_model:
        print("  by model (billed, with the relay's own figure beside it):")
        for model, entry in sorted(by_model.items(), key=lambda kv: -kv[1]["cost"]):
            f = factors.get(model)
            note = f"  (relay said ${entry['raw']:.2f}, x{f:.2f})" if f else "  (uncalibrated)"
            print(f"    {model:<30} {entry['dispatches']:>3} dispatches  "
                  f"${entry['cost']:.4f}{note}")
    print()

    if residuals:
        off = [r for r in residuals if not r["within_tolerance"]]
        print(f"  calibrated against the console on {len({r['day'] for r in residuals})} day(s), "
              f"tolerance {TOLERANCE:.0%}:")
        if off:
            for r in sorted(off, key=lambda r: -abs(r["residual"])):
                print(f"    OUT  {r['day']}  {r['model'].split('/')[-1]:<14} "
                      f"corrected ${r['corrected']:.2f} vs billed ${r['console']:.2f} "
                      f"({r['residual']:+.0%})")
            print("    A day outside tolerance means the correction has stopped holding for that")
            print("    model. Investigate the dispatches on that day — do not widen the band.")
        else:
            print("    every calibrated day is inside tolerance after correction")
        print()
    else:
        print("  NOT CALIBRATED — no console readings, so these are the relay's computed figures")
        print("  and not billed dollars. On grok-4.5 that ran a third high. Add a reading to")
        print(f"  {CALIBRATION.relative_to(REPO)} from the console.")
        print()
    if verdict == "stop":
        print("  STOP — a cap is nearly spent. Finish what is in flight and do not start a new")
        print("  dispatch, or a long task will die halfway through. Check the console for truth.")
    elif verdict == "warn":
        print("  WARN — send the next task to the mechanical model unless it genuinely needs")
        print("  grok-4.5. See the model table in CLAUDE.md; the spread is roughly 300x.")
    else:
        print("  OK to dispatch.")
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    command = sys.argv[1]
    if command == "record" and len(sys.argv) == 3:
        return record(sys.argv[2])
    if command == "report":
        flags = sys.argv[2:]
        return report("--json" in flags, local_only="--local" in flags)
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
