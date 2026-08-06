#!/usr/bin/env python3
"""Weaken one RLS policy clause at a time and record which assertions notice.

    ./scripts/local-db.sh start
    python3 scripts/mutate-policies.py [report.json]

WHY THIS EXISTS. `supabase/tests/` had 104 assertions and nobody knew how many of them could fail.
On 2026-08-05 one was found by accident: "non-owner cannot write another Cook's address form"
passed with the UPDATE policy weakened to `USING (true)`, because that fixture's kitchen has no Meal
on offer, so the SELECT policy refuses the statement before the UPDATE policy is ever consulted.
The suite had PREDICTED that in a comment written while kitchens were still private, and E2 shipped
the change that triggered it without anyone re-reading the warning.

An assertion that cannot fail is worse than no assertion, because it occupies the place where a
real one would go. This script is how that question gets asked of all of them at once, and it is
meant to be re-run — a new policy or a new fixture can mask something that was isolated yesterday.

HOW IT MUTATES, AND WHY NOT THE OBVIOUS WAY.

It weakens **one conjunct at a time**, keeping the rest, rather than replacing a whole policy with
`true`. Replacing the whole predicate also removes its scoping: `bucket_id = 'kitchen-photos'` goes
with it, a bucket-scoped policy briefly governs the whole table, and — because permissive policies
are OR'd together — it starts permitting rows that belong to an entirely different policy. Measured
on 2026-08-06, that produced a confident false negative: the kitchen-photos INSERT policy appeared
to be guarding a meal-photos assertion, and the real gap it was hiding was that nothing guards
kitchen-photo uploads at all.

Dropping one clause asks the question actually meant: **is THIS clause load-bearing?**

WHAT A RESULT MEANS, STATED NARROWLY.

- A clause with at least one red assertion is load-bearing for that assertion. It does NOT follow
  that the assertion tests only that clause — permissive policies are OR'd, so a "cannot" assertion
  always tests the union.
- A clause with **no** red assertion is not covered by anything in the suite. That is the finding
  this script exists to produce, and it is not a probabilistic one.

Nothing on disk is ever weakened. Mutation is `ALTER POLICY` against the running database, every
cycle restores the captured expression, and the restore is read back out of the catalog and
compared before the next mutation runs. A failed restore aborts rather than continuing against a
database that no longer matches the migrations.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOCKET = '/tmp/kafoo-pg/socket'
DB = 'kafoo_test'
SCHEMAS = ('public', 'storage')


def psql(sql: str) -> str:
    r = subprocess.run(
        ['psql', '-h', SOCKET, '-U', 'postgres', '-d', DB, '-X', '-q', '-t', '-A',
         '-v', 'ON_ERROR_STOP=1', '-c', sql], capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f'psql failed on:\n{sql}\n{r.stderr}')
    return r.stdout.strip()


def policies() -> list[dict]:
    rows = psql(
        "SELECT json_agg(row_to_json(p)) FROM ("
        " SELECT schemaname, tablename, policyname, cmd, qual, with_check"
        f" FROM pg_policies WHERE schemaname IN {SCHEMAS}"
        " ORDER BY schemaname, tablename, policyname) p")
    if not rows or rows == '':
        raise SystemExit('no policies found — is the local database up? scripts/local-db.sh start')
    return json.loads(rows)


def split_and(expr: str) -> list[str]:
    """Top-level AND conjuncts. Paren-aware, so a subquery's AND is not mistaken for one."""
    expr = expr.strip()
    while expr.startswith('(') and expr.endswith(')'):
        depth = 0
        for i, ch in enumerate(expr):
            depth += (ch == '(') - (ch == ')')
            if depth == 0 and i < len(expr) - 1:
                break
        else:
            expr = expr[1:-1].strip()
            continue
        break
    parts, depth, start, i = [], 0, 0, 0
    while i < len(expr):
        depth += (expr[i] == '(') - (expr[i] == ')')
        if depth == 0 and expr[i:i + 3].upper() == 'AND' and re.match(r'\bAND\b', expr[i:], re.I):
            parts.append(expr[start:i].strip())
            start = i = i + 3
            continue
        i += 1
    parts.append(expr[start:].strip())
    return [p for p in parts if p]


def alter(p: dict, using: str | None, check: str | None) -> None:
    bits = []
    if p['qual'] is not None:
        bits.append(f'USING ({using})')
    if p['with_check'] is not None:
        bits.append(f'WITH CHECK ({check})')
    name = p['policyname'].replace('"', '""')
    psql(f'ALTER POLICY "{name}" ON {p["schemaname"]}.{p["tablename"]} {" ".join(bits)}')


def run_suites() -> dict[str, str]:
    """{suite::assertion: 'ok'|'not ok'} for every assertion in supabase/tests/."""
    results: dict[str, str] = {}
    for f in sorted((REPO / 'supabase/tests').glob('*.sql')):
        r = subprocess.run(
            ['psql', '-h', SOCKET, '-U', 'postgres', '-d', DB, '-X', '-q', '-t', '-A',
             '-v', 'ON_ERROR_STOP=0', '-f', str(f)], capture_output=True, text=True)
        for line in (r.stdout + r.stderr).splitlines():
            m = re.match(r'^(not ok|ok) \d+ - (.*)$', line.strip())
            if m:
                results[f'{f.stem}::{m.group(2)}'] = m.group(1)
    return results


def restored(p: dict) -> bool:
    now = next(q for q in policies()
               if (q['schemaname'], q['tablename'], q['policyname'])
               == (p['schemaname'], p['tablename'], p['policyname']))
    return (now['qual'], now['with_check']) == (p['qual'], p['with_check'])


def main() -> int:
    baseline = run_suites()
    red = sorted(k for k, v in baseline.items() if v == 'not ok')
    if red:
        print('baseline is not green; fix that before mutating:', *red, sep='\n  ', file=sys.stderr)
        return 1
    print(f'baseline: {len(baseline)} assertions, all green', file=sys.stderr)

    report, mutations = [], 0
    for p in policies():
        expr = p['qual'] if p['qual'] is not None else p['with_check']
        conjuncts = split_and(expr)
        for idx, clause in enumerate(conjuncts):
            weak = ' AND '.join('true' if i == idx else c for i, c in enumerate(conjuncts))
            alter(p, weak, weak)
            mutations += 1
            after = run_suites()
            noticed = sorted(k for k, v in after.items()
                             if v == 'not ok' and baseline.get(k) == 'ok')
            # An assertion that did not RUN is not an assertion that passed. A mutation can abort a
            # suite partway, and counting that as "nothing noticed" would report a hole that is
            # really an unmeasured one.
            vanished = sorted(set(baseline) - set(after))
            alter(p, p['qual'], p['with_check'])
            if not restored(p):
                print(f'RESTORE FAILED on {p["policyname"]} — stopping', file=sys.stderr)
                return 1

            key = f'{p["schemaname"]}.{p["tablename"]} :: {p["policyname"]} ({p["cmd"]})'
            report.append({'policy': key, 'clause': clause,
                           'noticed': noticed, 'vanished': vanished})
            print(f'{"OK  " if noticed else "****"} {len(noticed):3d}  {key}'
                  f'\n            dropped: {clause}'
                  + (f'\n            WARNING: {len(vanished)} assertions did not run' if vanished else ''),
                  file=sys.stderr)

    uncovered = [r for r in report if not r['noticed'] and not r['vanished']]
    out = {'assertion_count': len(baseline), 'mutations': mutations,
           'uncovered_clauses': len(uncovered), 'report': report}
    Path(sys.argv[1] if len(sys.argv) > 1 else 'mutation-report.json').write_text(
        json.dumps(out, indent=2, ensure_ascii=False))
    print(f'\n{mutations} mutations, {len(uncovered)} clauses with no assertion behind them',
          file=sys.stderr)
    return 0


sys.exit(main())
