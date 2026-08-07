#!/usr/bin/env python3
"""The AI Assistant is structurally unable to write, with one written-down exception.

An Edge Function that can reach a model provider must not also hold a credential that can write,
because a function with both is structurally able to let a model's output reach the database
unreviewed. That is Kafoo's domain rule — AI suggests, humans approve — enforced by absence of means
rather than by good behaviour.

ONE EXCEPTION EXISTS, approved by the founder on 2026-08-07 and reasoned in ADR-0011: `embed-meal`
stores a Meal's embedding. An embedding is the one AI-derived value the approval rule cannot
sensibly cover — it is not a claim, not content, and shown to nobody, so there is no human judgement
to apply to 768 floating-point numbers.

THE EXCEPTION IS NARROWER THAN THE RULE IT REPLACES, WHICH IS THE POINT. Before it, `embed-meal`
would simply have been banned. Now it is permitted and CONSTRAINED: this script asserts the function
writes exactly the columns named below, to exactly the tables named below, and never inserts,
deletes or calls an RPC. The day somebody adds a second column, the gate goes red again — which is
the property a hand-waved exemption would have thrown away.

Run by scripts/verify.sh. Exits non-zero with an explanation.
"""

from __future__ import annotations

import pathlib
import re
import sys

FUNCTIONS = pathlib.Path("supabase/functions")

# Anything reaching this import can talk to a model provider.
AI_IMPORT = re.compile(r"_shared/ai/")

# A connection string IS a write credential. Without these, a function reaching Postgres directly
# was not detected as holding one at all, so it skipped every constraint below — which defeated the
# blanket ban for every function, not just the exception.
WRITE_CREDENTIAL = re.compile(
    r"SUPABASE_SERVICE_ROLE_KEY|SUPABASE_SECRET_KEY|SERVICE_ROLE"
    r"|SUPABASE_DB_URL|DATABASE_URL|POSTGRES(QL)?_URL|PG(HOST|PASSWORD|DATABASE)"
)

# Deno runs JavaScript too. Scanning only *.ts made the blanket ban NARROWER than the grep it
# replaced — the same function written in .js was invisible. Demonstrated by ai-boundary-reviewer.
SOURCE_SUFFIXES = (".ts", ".tsx", ".js", ".mjs", ".jsx")

# dir name -> (tables it may touch, columns it may write)
#
# Adding an entry here is an ADR-level decision, not a fix for a red gate. If you are here because
# the gate is failing, the answer is almost certainly to stop writing that column.
ALLOWED: dict[str, tuple[set[str], set[str]]] = {
    "embed-meal": ({"meals"}, {"embedding"}),
}

# `.update({ a: 1, b: 2 })` — the object literal, however it is spaced or wrapped.
UPDATE_CALL = re.compile(r"\.update\(\s*\{(.*?)\}\s*\)", re.DOTALL)
# A key at the start of an object entry: `embedding:` or `'embedding':`.
OBJECT_KEY = re.compile(r"(?:^|,)\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?\s*:")
FROM_CALL = re.compile(r"\.from\(\s*['\"]([^'\"]+)['\"]\s*\)")
# `.auth.admin` and `.storage.` are write paths the PostgREST patterns do not model at all.
# `deleteUser` and `updateUserById` are "delete content" and "impersonate a Customer or Cook" — two
# of the six things business-rules.md says the AI may not do under any framing — and the admin
# client is one property access away in any function that already built one.
FORBIDDEN_PATTERNS = (
    ".insert(", ".upsert(", ".delete(", ".rpc(", ".auth.admin", ".storage.",
)
FORBIDDEN_CALLS = tuple(f"`{p}`" for p in FORBIDDEN_PATTERNS)

# `.update(` or `.from(` whose argument is NOT a literal. Fail closed: a payload extracted into a
# variable is what any implementer does when an object grows, and it made `.update(patch)` with
# `status: 'published'` invisible — literally "the AI publishes a Meal", green.
NON_LITERAL_UPDATE = re.compile(r"\.update\(\s*(?!\{)")
NON_LITERAL_FROM = re.compile(r"\.from\(\s*(?![\'\"`])")


def all_files(directory: pathlib.Path) -> list[pathlib.Path]:
    return [p for p in directory.rglob("*") if p.is_file() and p.suffix in SOURCE_SUFFIXES]


def source_files(directory: pathlib.Path) -> list[pathlib.Path]:
    # Test files are scanned too. A `helper.test.ts` in an allowlisted directory that writes a
    # second column is still a write path — Deno will not run it in production, but nothing stops
    # the next person moving the code out of it.
    return all_files(directory)


def check_allowed(name: str, directory: pathlib.Path, problems: list[str]) -> None:
    tables, columns = ALLOWED[name]

    for path in source_files(directory):
        text = path.read_text(encoding="utf-8")

        # Comments would otherwise trip every pattern below — this file's own prose mentions
        # `.insert(`, and so does the handler's explanation of what it does not do.
        code = strip_comments(text)

        for table in FROM_CALL.findall(code):
            if table not in tables:
                problems.append(
                    f"{path}: touches table \"{table}\"; {name} may touch only "
                    f"{sorted(tables)}"
                )

        if NON_LITERAL_UPDATE.search(code):
            problems.append(
                f"{path}: an .update() whose payload is not a literal object. Write it inline so "
                f"this check can see which columns it writes — a variable hides them."
            )
        if NON_LITERAL_FROM.search(code):
            problems.append(
                f"{path}: a .from() whose table is not a literal string. Name the table inline so "
                f"this check can see which one it is."
            )

        for pattern, label in zip(FORBIDDEN_PATTERNS, FORBIDDEN_CALLS):
            if pattern in code:
                problems.append(
                    f"{path}: uses {label}. {name} may update named columns and nothing else — "
                    f"an insert, a delete or an RPC is a write path this exception does not cover."
                )

        for body in UPDATE_CALL.findall(code):
            keys = set(OBJECT_KEY.findall(body))
            if not keys:
                problems.append(
                    f"{path}: an .update() whose columns could not be read. Write it as a literal "
                    f"object so this check can see what it writes."
                )
                continue
            extra = keys - columns
            if extra:
                problems.append(
                    f"{path}: writes {sorted(extra)}. {name} may write only {sorted(columns)}. "
                    f"Widening this needs an ADR — see ADR-0011 — not an edit to this list."
                )


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"^\s*//.*$", "", text, flags=re.MULTILINE)


def main() -> int:
    if not FUNCTIONS.is_dir():
        return 0

    problems: list[str] = []

    for directory in sorted(p for p in FUNCTIONS.iterdir() if p.is_dir()):
        name = directory.name
        if name.startswith("_"):
            continue

        files = all_files(directory)
        reaches_ai = any(AI_IMPORT.search(p.read_text(encoding="utf-8")) for p in files)
        if not reaches_ai:
            continue

        holds_credential = [
            p for p in files if WRITE_CREDENTIAL.search(p.read_text(encoding="utf-8"))
        ]
        if not holds_credential:
            # NO CREDENTIAL IS NOT THE SAME AS NO WRITE, AND THIS SKIPPED EVERY CHECK ON THAT
            # ASSUMPTION. Demonstrated by ai-boundary-reviewer on 2026-08-07 with a function that
            # builds a Supabase client from the PUBLISHABLE key plus the caller's forwarded
            # Authorization header, then inserts a Review. That is the AI writing a Review — one of
            # the six things business-rules.md forbids under any framing — and it was green here,
            # because the credential regex is service-role and connection-string only. RLS permits
            # the row: the Customer genuinely owns it.
            #
            # `judge-results` is the first AI-reaching function that deliberately constructs a
            # caller-scoped client, so the shape is now live rather than hypothetical.
            #
            # The rule the constitution actually claims is "the AI Assistant cannot write", not "the
            # AI Assistant holds no service-role key". So a function with no credential is checked
            # for writes anyway, and only the allowlisted exception may perform one.
            if name in ALLOWED:
                continue
            writes = []
            for path in source_files(directory):
                code = strip_comments(path.read_text(encoding="utf-8"))
                # `.rpc(` is NOT in this list, and the omission is a stated ceiling rather than
                # an oversight. `discover` calls `search_meals` as the caller, which is a read,
                # and an RPC's own body is governed by the migration that created it. A SECURITY
                # DEFINER function that writes, called from here, is a hole this check cannot see —
                # the guard for that is the migration review, not a grep.
                for pattern in (".insert(", ".upsert(", ".delete(", ".update(",
                                ".auth.admin", ".storage."):
                    if pattern in code:
                        writes.append(f"{path}: {pattern}")
            if writes:
                problems.append(
                    f"{name} reaches the model layer and performs a write:\n   "
                    + "\n   ".join(writes)
                    + "\n   Holding no service-role key is not the same as being unable to write:"
                    "\n   a client built from the caller's own token writes as the caller, and RLS"
                    "\n   permits it. The AI Assistant writes nothing, by any credential."
                )
            continue

        if name not in ALLOWED:
            problems.append(
                f"{name} reaches the model layer and names a write credential:\n   "
                + "\n   ".join(str(p) for p in holds_credential)
                + "\n   The AI Assistant is structurally unable to write. That property comes from"
                "\n   the function not having the means, not from it choosing well."
            )
            continue

        check_allowed(name, directory, problems)

    # An allowlist entry for a function that no longer exists is a hole waiting for somebody to
    # create a directory with that name.
    for name in ALLOWED:
        if not (FUNCTIONS / name).is_dir():
            problems.append(
                f"ALLOWED names \"{name}\", which does not exist. Remove it — a standing exception "
                f"for a function nobody has written is an exception waiting to be claimed."
            )

    if problems:
        for problem in problems:
            print(f"   {problem}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
