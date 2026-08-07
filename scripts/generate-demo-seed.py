#!/usr/bin/env python3
"""Compile supabase/demo-data.json into the demo block at the foot of supabase/seed.sql.

WHY A GENERATOR RATHER THAN HAND-WRITTEN SQL. The founder maintains this data and does not write
SQL. A JSON list of Meals is something he can add to; a wall of INSERT statements with quoted
Arabic and array literals is something he would have to ask for every time. Same shape as
scripts/generate-exclusions.py and scripts/generate-prompts.ts: one source, one generated artefact,
committed, and a gate check that fails on drift.

    python3 scripts/generate-demo-seed.py            # write
    python3 scripts/generate-demo-seed.py --check    # fail if seed.sql is stale

WHERE THE OUTPUT RUNS, and it is the whole safety argument. seed.sql runs on `supabase db reset`
locally and on preview-branch creation. It does NOT run on production — `supabase db push` applies
migrations and nothing else, which supabase/seed.sql's own header records as measured rather than
assumed. business-rules.md forbids synthetic Cooks and Meals in production; this never gets there.

The generated block adds a second, independent guard anyway: it inserts nothing into a database
that already holds a person. Two protections, because the first one is a property of a tool's
behaviour and the second is a property of the statement.
"""

from __future__ import annotations

import json
import pathlib
import sys
import uuid

SOURCE = pathlib.Path("supabase/demo-data.json")
TARGET = pathlib.Path("supabase/seed.sql")

BEGIN = "-- >>> GENERATED DEMO DATA — scripts/generate-demo-seed.py — DO NOT EDIT BELOW"
END = "-- <<< END GENERATED DEMO DATA"

# A fixed namespace, so every regeneration produces the SAME ids for the same data. Random ids
# would make this file churn on every run and make a diff impossible to read.
NAMESPACE = uuid.UUID("6b6f6166-6f6f-4465-6d6f-536565644944")


def q(value: str) -> str:
    """A single-quoted SQL literal. Arabic text is full of nothing dangerous and one apostrophe is
    all it takes, so this is not optional."""
    return "'" + value.replace("'", "''") + "'"


def array(values: list[str]) -> str:
    if not values:
        return "'{}'::text[]"
    return "ARRAY[" + ", ".join(q(v) for v in values) + "]::text[]"


def stable_id(*parts: str) -> str:
    return str(uuid.uuid5(NAMESPACE, "/".join(parts)))


def build() -> str:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    lines: list[str] = [
        BEGIN,
        "--",
        "-- Compiled from supabase/demo-data.json. Edit that file and re-run the generator.",
        "--",
        "-- IT REFUSES TO RUN ON A DATABASE THAT ALREADY HOLDS A PERSON. seed.sql does not execute",
        "-- against production at all — `supabase db push` applies migrations only — and this guard",
        "-- is the second lock rather than the first. business-rules.md calls a synthetic Cook on the",
        "-- real marketplace product-fatal, and 'the tool would not do that' is a weaker sentence than",
        "-- a statement that cannot.",
        "--",
        "-- Every Meal here is seeded WITHOUT a vector, so it is visible in browse and invisible to",
        "-- search until scripts/backfill-meal-embeddings.ts is run against the branch. That is the",
        "-- documented behaviour of a missing embedding, not an oversight: harder to find, never lost.",
        "DO $demo$",
        "BEGIN",
        "  IF EXISTS (SELECT 1 FROM auth.users) THEN",
        "    RAISE NOTICE 'demo data skipped: this database already has a person in it';",
        "    RETURN;",
        "  END IF;",
        "",
    ]

    for cook in data["cooks"]:
        phone = cook["phone"]
        cook_id = stable_id("cook", phone)
        kitchen = cook["kitchen"]

        lines += [
            f"  -- {kitchen['display_name']} — {phone}, OTP {cook['otp']}",
            "  INSERT INTO auth.users (",
            "    id, instance_id, aud, role, phone, phone_confirmed_at,",
            "    encrypted_password, created_at, updated_at,",
            "    raw_app_meta_data, raw_user_meta_data,",
            "    confirmation_token, recovery_token, email_change_token_new, email_change,",
            "    phone_change, phone_change_token, email_change_token_current, reauthentication_token",
            "  ) VALUES (",
            f"    {q(cook_id)}::uuid, '00000000-0000-0000-0000-000000000000',",
            f"    'authenticated', 'authenticated', {q(phone)}, now(),",
            "    'not-a-real-password-hash', now(), now(),",
            "    '{\"provider\":\"phone\",\"providers\":[\"phone\"]}'::jsonb, '{}'::jsonb,",
            "    '', '', '', '', '', '', '', ''",
            "  );",
            "",
            "  INSERT INTO public.kitchen_profiles",
            "    (cook_id, display_name, story, area, delivery_terms, address_form)",
            "  VALUES (",
            f"    {q(cook_id)}::uuid, {q(kitchen['display_name'])}, {q(kitchen['story'])},",
            f"    {q(kitchen['area'])}, {q(kitchen['delivery_terms'])}, {q(cook['address_form'])}",
            "  );",
            "",
        ]

        for meal in cook["meals"]:
            published = meal["status"] == "published"
            calories = meal.get("calories")
            lines += [
                "  INSERT INTO public.meals",
                "    (id, cook_id, title, description, price, cuisine, category, status,",
                "     ingredients, allergens, calories, nutrition_source, published_at)",
                "  VALUES (",
                f"    {q(stable_id('meal', phone, meal['title']))}::uuid, {q(cook_id)}::uuid,",
                f"    {q(meal['title'])}, {q(meal['description'])}, {meal['price']},",
                f"    {q(meal['cuisine'])}, {q(meal['category'])}, {q(meal['status'])},",
                f"    {array(meal['ingredients'])}, {array(meal['allergens'])},",
                # 'ai', never 'cook'. Nobody verified these numbers, and `cook` is what the app
                # renders as a figure a human stood behind. A seeded estimate labelled as verified
                # is a small lie in the one place the rules say never to tell one.
                f"    {calories if calories is not None else 'NULL'}, 'ai',",
                f"    {'now()' if published else 'NULL'}",
                "  );",
                "",
            ]

    lines += [
        f"  RAISE NOTICE 'demo data loaded: {len(data['cooks'])} cooks';",
        "END",
        "$demo$;",
        END,
    ]
    return "\n".join(lines) + "\n"


def main() -> int:
    check = "--check" in sys.argv
    if not SOURCE.exists():
        print(f"{SOURCE} is missing", file=sys.stderr)
        return 1

    generated = build()
    current = TARGET.read_text(encoding="utf-8")

    if BEGIN in current:
        head = current[: current.index(BEGIN)]
        tail_at = current.index(END) + len(END)
        tail = current[tail_at:].lstrip("\n")
        updated = head + generated + tail
    else:
        updated = current.rstrip("\n") + "\n\n" + generated

    if check:
        if updated != current:
            print(
                "supabase/seed.sql is stale.\n"
                "Run: python3 scripts/generate-demo-seed.py",
                file=sys.stderr,
            )
            return 1
        print("   demo seed matches supabase/demo-data.json")
        return 0

    TARGET.write_text(updated, encoding="utf-8")
    meals = sum(len(c["meals"]) for c in json.loads(SOURCE.read_text(encoding="utf-8"))["cooks"])
    print(f"wrote {TARGET}: {len(json.loads(SOURCE.read_text(encoding='utf-8'))['cooks'])} cooks, {meals} meals")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
