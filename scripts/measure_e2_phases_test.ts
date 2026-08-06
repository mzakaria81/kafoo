// The phase selector in scripts/measure-e2-performance.ts, and the one refusal that matters.
//
// `resolvePhases` decides whether that script may run its publish phase, which sets a Meal's status
// to `published`. Against the production project that would be a synthetic Meal on the real
// marketplace — product-fatal by `.claude/rules/business-rules.md`, and the thing the founder's
// approval to measure against production on 2026-08-05 turned on never happening.
//
// So the load-bearing case here is "publish against production throws". It was seen to fail before
// the guard existed: with the production check inverted, that test went red naming the phase it had
// let through, and green again once the check was restored.
//
// A unit test by the repository's convention (`*_test.ts`): no network, no database, no local stack.
// `env` is a stub in every case — nothing here reads the real environment, and no value below
// resembles a real project ref.

import { assert, assertThrows } from "jsr:@std/assert@1";
import { resolvePhases } from "./measure-e2-performance.ts";

/// A stubbed environment. Absent keys return undefined, exactly as Deno.env.get does.
function env(
  vars: Record<string, string>,
): (key: string) => string | undefined {
  return (key) => vars[key];
}

const PRODUCTION = env({
  SUPABASE_URL: "https://prodref.supabase.co",
  SUPABASE_PROJECT_REF: "prodref",
});

const PREVIEW_BRANCH = env({
  SUPABASE_URL: "https://branchref.supabase.co",
  SUPABASE_PROJECT_REF: "prodref",
});

Deno.test("the default is latency and cost, and never publish", () => {
  const phases = resolvePhases([], PRODUCTION);
  assert(phases.has("latency"), "latency should be on by default");
  assert(phases.has("cost"), "cost should be on by default");
  assert(
    !phases.has("publish"),
    "publish must never be in the default: it writes a published Meal",
  );
  assert(phases.size === 2);
});

Deno.test("--phases=latency runs the latency phase alone", () => {
  const phases = resolvePhases(["--phases=latency"], PRODUCTION);
  assert(phases.has("latency"));
  assert(!phases.has("cost"));
  assert(!phases.has("publish"));
});

Deno.test("--phases=cost runs the cost phase alone", () => {
  const phases = resolvePhases(["--phases=cost"], PRODUCTION);
  assert(phases.has("cost"));
  assert(phases.size === 1);
});

Deno.test("an unknown phase throws and names the bad value", () => {
  const err = assertThrows(
    () => resolvePhases(["--phases=latency,publsh"], PRODUCTION),
    Error,
  );
  assert(
    err.message.includes("publsh"),
    `the message should name the typo, got: ${err.message}`,
  );
});

Deno.test("an empty phase list throws", () => {
  assertThrows(() => resolvePhases(["--phases="], PRODUCTION), Error);
  assertThrows(() => resolvePhases(["--phases=,,"], PRODUCTION), Error);
});

// THE ONE THIS FILE EXISTS FOR.
Deno.test("publish is refused against the production project", () => {
  const err = assertThrows(
    () => resolvePhases(["--phases=publish"], PRODUCTION),
    Error,
  );
  assert(
    err.message.includes("production"),
    `the refusal should say why, got: ${err.message}`,
  );
});

Deno.test("publish is refused alongside other phases too", () => {
  // The guard is on the resolved set, not on the flag looking like exactly "publish".
  assertThrows(
    () => resolvePhases(["--phases=latency,cost,publish"], PRODUCTION),
    Error,
  );
});

Deno.test("publish fails closed when the production ref is unknown", () => {
  // Without the production ref there is no way to prove the target is not production, and an
  // unprovable claim about a production write is a no.
  assertThrows(
    () =>
      resolvePhases(
        ["--phases=publish"],
        env({ SUPABASE_URL: "https://anything.supabase.co" }),
      ),
    Error,
  );
  assertThrows(
    () =>
      resolvePhases(
        ["--phases=publish"],
        env({
          SUPABASE_URL: "https://anything.supabase.co",
          SUPABASE_PROJECT_REF: "   ",
        }),
      ),
    Error,
  );
  assertThrows(
    () =>
      resolvePhases(["--phases=publish"], env({ SUPABASE_PROJECT_REF: "x" })),
    Error,
  );
});

Deno.test("publish is allowed on a preview branch", () => {
  const phases = resolvePhases(["--phases=publish"], PREVIEW_BRANCH);
  assert(phases.has("publish"));
  assert(phases.size === 1);
});
