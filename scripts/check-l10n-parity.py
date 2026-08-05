#!/usr/bin/env python3
"""Compare Kafoo's Arabic and English ARB files for structural parity.

Run by ./scripts/verify.sh under the step name `localization parity`. Exists because a key-name
diff alone cannot see the mistakes a forthcoming ICU `select` conversion will make: a branch
present in one locale and missing in the other, a select converted in Arabic and missed in
English, a missing `other` branch that only fails at runtime, or a placeholder the string uses
but the `@key` metadata never declared.

What it refuses:

  * a message key present in one locale and absent from the other (both directions)
  * a key whose placeholder set differs between locales
  * a key that is an ICU select in one locale and not in the other
  * an ICU select whose branch-name set differs between locales
  * an ICU select with no `other` branch, in either locale
  * a key whose `@key` metadata declares placeholders the string does not use, or whose string
    uses a placeholder the metadata does not declare — checked in both locales

Parsing of ICU select uses a brace-matching scanner, not a regular expression: braces nest, and a
regex that works on today's flat strings will silently mis-parse the first nested one.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
AR_PATH = REPO / "apps/mobile/lib/l10n/app_ar.arb"
EN_PATH = REPO / "apps/mobile/lib/l10n/app_en.arb"


def _is_ident_start(ch: str) -> bool:
    return ch.isalpha() or ch == "_"


def _is_ident_cont(ch: str) -> bool:
    return ch.isalnum() or ch == "_"


def _skip_ws(s: str, i: int) -> int:
    while i < len(s) and s[i].isspace():
        i += 1
    return i


def _read_ident(s: str, i: int) -> tuple[str | None, int]:
    i = _skip_ws(s, i)
    if i >= len(s) or not _is_ident_start(s[i]):
        return None, i
    start = i
    i += 1
    while i < len(s) and _is_ident_cont(s[i]):
        i += 1
    return s[start:i], i


def _read_branch_name(s: str, i: int) -> tuple[str | None, int]:
    """Branch selector: identifier, or plural-style =N / =0."""
    i = _skip_ws(s, i)
    if i >= len(s):
        return None, i
    if s[i] == "=":
        j = i + 1
        if j < len(s) and (s[j] == "-" or s[j].isdigit()):
            j += 1
            while j < len(s) and s[j].isdigit():
                j += 1
            return s[i:j], j
        return None, i
    return _read_ident(s, i)


def _parse_braced(s: str, i: int) -> tuple[str, int]:
    """s[i] must be '{'. Return inner text and index after closing '}'."""
    assert s[i] == "{"
    depth = 0
    start = i + 1
    j = i
    while j < len(s):
        ch = s[j]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return s[start:j], j + 1
        j += 1
    raise ValueError(f"unbalanced brace starting at index {i}")


def _scan_message(text: str) -> tuple[set[str], list[tuple[str, frozenset[str]]]]:
    """Walk a message string. Return (placeholder names, list of (select var, branch names))."""
    placeholders: set[str] = set()
    selects: list[tuple[str, frozenset[str]]] = []

    def walk(fragment: str) -> None:
        i = 0
        n = len(fragment)
        while i < n:
            if fragment[i] != "{":
                i += 1
                continue
            try:
                inner, after = _parse_braced(fragment, i)
            except ValueError:
                i += 1
                continue
            # inner is content between the outer braces
            name, j = _read_ident(inner, 0)
            if name is None:
                i = after
                continue
            j = _skip_ws(inner, j)
            if j >= len(inner):
                # simple {name}
                placeholders.add(name)
                i = after
                continue
            if inner[j] != ",":
                # treat whole thing as opaque; still count leading name if it looks like one
                placeholders.add(name)
                i = after
                continue
            j = _skip_ws(inner, j + 1)
            typ, j = _read_ident(inner, j)
            if typ is None:
                placeholders.add(name)
                i = after
                continue
            placeholders.add(name)
            j = _skip_ws(inner, j)
            if j < len(inner) and inner[j] == ",":
                j += 1
            if typ == "select":
                branches: set[str] = set()
                while True:
                    j = _skip_ws(inner, j)
                    if j >= len(inner):
                        break
                    bname, j2 = _read_branch_name(inner, j)
                    if bname is None:
                        break
                    j2 = _skip_ws(inner, j2)
                    if j2 >= len(inner) or inner[j2] != "{":
                        break
                    body, j = _parse_braced(inner, j2)
                    branches.add(bname)
                    walk(body)
                selects.append((name, frozenset(branches)))
            else:
                # plural / other complex forms: still walk nested braced bodies for placeholders
                while j < len(inner):
                    if inner[j] == "{":
                        body, j = _parse_braced(inner, j)
                        walk(body)
                    else:
                        j += 1
            i = after

    walk(text)
    return placeholders, selects


def _message_keys(data: dict) -> dict[str, str]:
    out: dict[str, str] = {}
    for key, value in data.items():
        if key.startswith("@"):
            continue
        if isinstance(value, str):
            out[key] = value
    return out


def _meta_placeholders(data: dict, key: str) -> set[str] | None:
    """Return declared placeholder names, or None if there is no @key entry."""
    meta = data.get(f"@{key}")
    if meta is None:
        return None
    if not isinstance(meta, dict):
        return set()
    ph = meta.get("placeholders")
    if ph is None:
        return set()
    if not isinstance(ph, dict):
        return set()
    return set(ph.keys())


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def check(ar_data: dict, en_data: dict) -> list[str]:
    errors: list[str] = []
    ar_msgs = _message_keys(ar_data)
    en_msgs = _message_keys(en_data)
    ar_keys = set(ar_msgs)
    en_keys = set(en_msgs)

    for key in sorted(en_keys - ar_keys):
        errors.append(f"{key}: present in en, missing from ar")
    for key in sorted(ar_keys - en_keys):
        errors.append(f"{key}: present in ar, missing from en")

    for key in sorted(ar_keys & en_keys):
        ar_ph, ar_sel = _scan_message(ar_msgs[key])
        en_ph, en_sel = _scan_message(en_msgs[key])

        if ar_ph != en_ph:
            only_ar = sorted(ar_ph - en_ph)
            only_en = sorted(en_ph - ar_ph)
            parts: list[str] = []
            if only_ar:
                parts.append(f"only in ar: {', '.join(only_ar)}")
            if only_en:
                parts.append(f"only in en: {', '.join(only_en)}")
            errors.append(f"{key}: placeholder set differs ({'; '.join(parts)})")

        ar_is_select = len(ar_sel) > 0
        en_is_select = len(en_sel) > 0
        if ar_is_select != en_is_select:
            if ar_is_select:
                errors.append(f"{key}: ICU select in ar but not in en")
            else:
                errors.append(f"{key}: ICU select in en but not in ar")
        else:
            # Compare select structures pairwise by position; also by var name if counts match
            if len(ar_sel) != len(en_sel):
                errors.append(
                    f"{key}: select count differs (ar={len(ar_sel)}, en={len(en_sel)})"
                )
            else:
                for idx, ((ar_var, ar_branches), (en_var, en_branches)) in enumerate(
                    zip(ar_sel, en_sel)
                ):
                    label = f"{key} select[{idx}] ({ar_var})"
                    if ar_var != en_var:
                        errors.append(
                            f"{key}: select[{idx}] switches on {ar_var!r} in ar "
                            f"but {en_var!r} in en"
                        )
                        label = f"{key} select[{idx}]"
                    if ar_branches != en_branches:
                        only_ar_b = sorted(ar_branches - en_branches)
                        only_en_b = sorted(en_branches - ar_branches)
                        parts = []
                        if only_ar_b:
                            parts.append(f"only in ar: {', '.join(only_ar_b)}")
                        if only_en_b:
                            parts.append(f"only in en: {', '.join(only_en_b)}")
                        errors.append(f"{label}: branch set differs ({'; '.join(parts)})")

        for locale, sels in (("ar", ar_sel), ("en", en_sel)):
            for var, branches in sels:
                if "other" not in branches:
                    errors.append(
                        f"{key}: ICU select on {var!r} in {locale} has no 'other' branch"
                    )

        for locale, data, used in (
            ("ar", ar_data, ar_ph),
            ("en", en_data, en_ph),
        ):
            declared = _meta_placeholders(data, key)
            if declared is None:
                if used:
                    errors.append(
                        f"{key}: {locale} string uses placeholders "
                        f"{{{', '.join(sorted(used))}}} but has no @{key} metadata"
                    )
                continue
            extra_meta = declared - used
            extra_str = used - declared
            if extra_meta:
                errors.append(
                    f"{key}: {locale} @{key} declares unused placeholders: "
                    f"{', '.join(sorted(extra_meta))}"
                )
            if extra_str:
                errors.append(
                    f"{key}: {locale} string uses placeholders not in @{key}: "
                    f"{', '.join(sorted(extra_str))}"
                )

    return errors


def main() -> int:
    if not AR_PATH.is_file() or not EN_PATH.is_file():
        print("   arb files not present yet — skipping")
        return 0
    try:
        ar_data = _load(AR_PATH)
        en_data = _load(EN_PATH)
    except json.JSONDecodeError as exc:
        print(f"   invalid ARB JSON: {exc}")
        return 1

    errors = check(ar_data, en_data)
    if errors:
        for line in errors:
            print(f"   {line}")
        return 1
    ar_n = len(_message_keys(ar_data))
    print(f"   {ar_n} keys, placeholders and ICU selects match across ar/en")
    return 0


if __name__ == "__main__":
    sys.exit(main())
