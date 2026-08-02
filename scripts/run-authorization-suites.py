#!/usr/bin/env python3
"""Run supabase/tests/*.sql against a deployed Supabase branch, over HTTPS only.

WHY THIS EXISTS, given `supabase test db` is the documented local command.

`supabase test db` needs a direct Postgres connection on port 5432. Preview branch
hosts publish no IPv4 record, and plenty of CI and sandbox networks allow nothing
but HTTPS, so that path is not reliably available to an automated runner. This
script talks to the Management API's query endpoint instead, which is HTTPS, and
therefore works anywhere the rest of the toolchain already works.

Locally, keep using `supabase test db` — see supabase/tests/README.md. This is the
same suites, executed a second way, not a second definition of passing.

HOW IT RUNS THEM

The endpoint returns only the last statement's rows, and each pgTAP assertion
returns its TAP line as text, so every assertion is captured into a temp table and
selected at the end. The whole file runs in one request because
tests.authenticate_as sets a transaction-local role, which would not survive being
split across requests.

Usage:
    run-authorization-suites.py --ref <project-ref> [files...]
    run-authorization-suites.py --parent <ref> --git-branch <name> [files...]

Needs SUPABASE_ACCESS_TOKEN in the environment.
"""
import argparse
import glob
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

API = "https://api.supabase.com"
# Functions returning a TAP line worth capturing. The tests.* helpers return void
# or uuid and must not be wrapped.
TAP = {"plan", "ok", "is", "isnt", "throws_ok", "lives_ok", "finish", "matches"}


def api(path, method="GET", body=None):
    req = urllib.request.Request(
        API + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={
            "Authorization": "Bearer " + os.environ["SUPABASE_ACCESS_TOKEN"],
            "Content-Type": "application/json",
            # Not optional. The API sits behind a WAF that answers urllib's
            # default User-Agent with "403 error code: 1010" — which reads like
            # an authentication failure and is not one.
            "User-Agent": "kafoo-authorization-suites/1.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return {"__error__": f"HTTP {e.code}: {e.read().decode()[:500]}"}


def split_statements(sql):
    """Split on semicolons outside quotes, dollar-quotes and comments.

    Comments must be consumed rather than scanned: the suites contain semicolons
    and apostrophes inside `--` comments, either of which desynchronises a naive
    splitter and produces a syntax error many lines later.
    """
    out, buf, i = [], [], 0
    in_s = in_d = False
    dollar = None
    while i < len(sql):
        c = sql[i]
        if dollar:
            if sql.startswith(dollar, i):
                buf.append(dollar)
                i += len(dollar)
                dollar = None
                continue
        elif in_s:
            if c == "'":
                in_s = False
        elif in_d:
            if c == '"':
                in_d = False
        else:
            if sql.startswith("--", i):
                j = sql.find("\n", i)
                i = len(sql) if j == -1 else j + 1
                continue
            if sql.startswith("/*", i):
                j = sql.find("*/", i)
                i = len(sql) if j == -1 else j + 2
                continue
            m = re.match(r"\$[A-Za-z_]*\$", sql[i:])
            if m:
                dollar = m.group(0)
                buf.append(dollar)
                i += len(dollar)
                continue
            if c == "'":
                in_s = True
            elif c == '"':
                in_d = True
            elif c == ";":
                out.append("".join(buf).strip())
                buf = []
                i += 1
                continue
        buf.append(c)
        i += 1
    if "".join(buf).strip():
        out.append("".join(buf).strip())
    return [s for s in out if s]


def build(path):
    stmts = []
    for s in split_statements(open(path).read()):
        head = s.lstrip()
        if head.lower() in ("begin", "commit", "rollback"):
            continue  # our own transaction control replaces the file's
        m = re.match(r"select\s+([a-z_]+)\s*\(", head.lower(), re.S)
        stmts.append(
            f"INSERT INTO _out(line) {head}" if m and m.group(1) in TAP else head
        )
    # Fixture emails repeat across files and tests.authenticate_as resolves by
    # email, so each suite starts from an empty slate. No DELETE on
    # storage.objects: Supabase rejects direct deletes there by design.
    return (
        "DELETE FROM public.analytics_events;\n"
        "DELETE FROM public.kitchen_profiles;\n"
        "DELETE FROM auth.users;\n"
        "BEGIN;\n"
        "CREATE TEMP TABLE _out(seq serial, line text);\n"
        # Assertions run after the session has switched to anon/authenticated.
        "GRANT ALL ON _out TO anon, authenticated;\n"
        "GRANT USAGE, SELECT ON SEQUENCE _out_seq_seq TO anon, authenticated;\n"
        + ";\n".join(stmts)
        + ";\nSELECT seq, line FROM _out ORDER BY seq;"
    )


def resolve_branch(parent, git_branch, timeout=600):
    """Wait for the preview branch belonging to a git branch to be usable."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        branches = api(f"/v1/projects/{parent}/branches")
        if isinstance(branches, dict):
            print("  cannot list branches:", branches.get("__error__"))
            return None
        for b in branches:
            if b.get("git_branch") == git_branch and not b.get("is_default"):
                if b.get("status") in ("FUNCTIONS_DEPLOYED", "MIGRATIONS_PASSED"):
                    return b["project_ref"]
                print(f"  branch {b['name']}: {b.get('status')} — waiting")
        time.sleep(15)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref")
    ap.add_argument("--parent")
    ap.add_argument("--git-branch")
    ap.add_argument("files", nargs="*")
    a = ap.parse_args()

    ref = a.ref
    if not ref:
        if not (a.parent and a.git_branch):
            sys.exit("need --ref, or --parent with --git-branch")
        ref = resolve_branch(a.parent, a.git_branch)
        if not ref:
            sys.exit("no ready preview branch found for " + a.git_branch)
    print(f"running against branch {ref}\n")

    files = a.files or sorted(glob.glob("supabase/tests/*.sql"))
    passed = failed = 0
    for path in files:
        print("=" * 70)
        print(path)
        print("=" * 70)
        res = api(f"/v1/projects/{ref}/database/query", "POST", {"query": build(path)})
        if isinstance(res, dict):
            print("  ERROR:", json.dumps(res)[:1200])
            failed += 1
            continue
        for row in res:
            for line in (row.get("line") or "").split("\n"):
                if line.startswith("not ok"):
                    failed += 1
                    print("  FAIL  " + line)
                elif line.startswith("ok "):
                    passed += 1
                    print("  pass  " + line)
                elif line.strip():
                    print("        " + line)
        print()

    print("=" * 70)
    print(f"TOTAL: {passed} passed, {failed} FAILED")
    print("=" * 70)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
