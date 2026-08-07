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

WRITE_CREDENTIAL = re.compile(r"SUPABASE_SERVICE_ROLE_KEY|SUPABASE_SECRET_KEY|SERVICE_ROLE")

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
FORBIDDEN_CALLS = ("`.insert(`", "`.upsert(`", "`.delete(`", "`.rpc(`")
FORBIDDEN_PATTERNS = (".insert(", ".upsert(", ".delete(", ".rpc(")


def source_files(directory: pathlib.Path) -> list[pathlib.Path]:
    return [p for p in directory.rglob("*.ts") if not p.name.endswith("_test.ts")
            and not p.name.endswith(".test.ts")]


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

        files = list(directory.rglob("*.ts"))
        reaches_ai = any(AI_IMPORT.search(p.read_text(encoding="utf-8")) for p in files)
        if not reaches_ai:
            continue

        holds_credential = [
            p for p in files if WRITE_CREDENTIAL.search(p.read_text(encoding="utf-8"))
        ]
        if not holds_credential:
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
