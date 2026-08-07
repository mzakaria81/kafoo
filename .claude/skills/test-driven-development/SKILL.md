---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

**Always:**
- New features
- Bug fixes
- Refactoring
- Behavior changes

**Exceptions (ask your human partner):**
- Throwaway prototypes
- Generated code
- Configuration files

Thinking "skip TDD just this once"? Stop. That's rationalization.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from tests. Period.

## Red-Green-Refactor

```dot
digraph tdd_cycle {
    rankdir=LR;
    red [label="RED\nWrite failing test", shape=box, style=filled, fillcolor="#ffcccc"];
    verify_red [label="Verify fails\ncorrectly", shape=diamond];
    green [label="GREEN\nMinimal code", shape=box, style=filled, fillcolor="#ccffcc"];
    verify_green [label="Verify passes\nAll green", shape=diamond];
    refactor [label="REFACTOR\nClean up", shape=box, style=filled, fillcolor="#ccccff"];
    next [label="Next", shape=ellipse];

    red -> verify_red;
    verify_red -> green [label="yes"];
    verify_red -> red [label="wrong\nfailure"];
    green -> verify_green;
    verify_green -> refactor [label="yes"];
    verify_green -> green [label="no"];
    refactor -> verify_green [label="stay\ngreen"];
    verify_green -> next;
    next -> red;
}
```

### RED - Write Failing Test

Write one minimal test showing what should happen.

<Good>
```typescript
test('retries failed operations 3 times', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };

  const result = await retryOperation(operation);

  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```
Clear name, tests real behavior, one thing
</Good>

<Bad>
```typescript
test('retry works', async () => {
  const mock = jest.fn()
    .mockRejectedValueOnce(new Error())
    .mockRejectedValueOnce(new Error())
    .mockResolvedValueOnce('success');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(3);
});
```
Vague name, tests mock not code
</Bad>

**Requirements:**
- One behavior
- Clear name
- Real code (no mocks unless unavoidable)

### Verify RED - Watch It Fail

**MANDATORY. Never skip.**

```bash
npm test path/to/test.test.ts
```

Confirm:
- Test fails (not errors)
- Failure message is expected
- Fails because feature missing (not typos)

**Test passes?** You're testing existing behavior. Fix test.

**Test errors?** Fix error, re-run until it fails correctly.

### GREEN - Minimal Code

Write simplest code to pass the test.

<Good>
```typescript
async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
  for (let i = 0; i < 3; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i === 2) throw e;
    }
  }
  throw new Error('unreachable');
}
```
Just enough to pass
</Good>

<Bad>
```typescript
async function retryOperation<T>(
  fn: () => Promise<T>,
  options?: {
    maxRetries?: number;
    backoff?: 'linear' | 'exponential';
    onRetry?: (attempt: number) => void;
  }
): Promise<T> {
  // YAGNI
}
```
Over-engineered
</Bad>

Don't add features, refactor other code, or "improve" beyond the test.

### Verify GREEN - Watch It Pass

**MANDATORY.**

```bash
npm test path/to/test.test.ts
```

Confirm:
- Test passes
- Other tests still pass
- Output pristine (no errors, warnings)

**Test fails?** Fix code, not test.

**Other tests fail?** Fix now.

### REFACTOR - Clean Up

After green only:
- Remove duplication
- Improve names
- Extract helpers

Keep tests green. Don't add behavior.

### Repeat

Next failing test for next feature.

## When Red-Green Isn't Available, Or Isn't Enough

Red-green works when you write the test and can run it. Three situations break that, and each has
its own discipline. All three end in the same place: **a test earns trust by discriminating, not by
passing.**

### The suite is green but was never seen red

Inherited suites, repaired suites, tests written before an environment existed. You know they run;
you do not know they guard anything.

**Mutation-test them.** For each assertion, remove the specific protection it names and confirm
that assertion turns red. Assertions that stay green are not necessarily wrong, but they do not
test what their name claims, and the discrepancy belongs in a comment next to them.

Three ways this goes wrong:

- **A sibling guard does the work.** "Seen to fail" only counts when the failure has the same cause
  as the property claimed. A negative authorization test written before its column existed fails
  with "column does not exist" — necessary, not sufficient. Where several guards overlap, break the
  specific one the test names and watch that test alone go red. If it stays green, the usual cause
  is a fixture in a state where the named guard is never the operative one; move or duplicate the
  test onto a fixture where it is.
- **The mutation itself silently failed.** Diff the mutated artefact against the original and fail
  loudly if the change is not exactly what was intended. A broken mutation script that empties a
  file instead of removing a line makes the check report green — and "the check is asleep" is the
  most expensive wrong conclusion available, because it accuses a working check of being broken.
- **A tight threshold quietly loosened.** An assertion pinned to "exactly what exists today"
  inherits a dependency on whatever measures it. Improving the instrument moves the derived count in
  the direction that keeps the assertion green, so the whole class of drift is invisible by
  construction. Whenever the instrument changes, re-derive the number: raise the threshold by one
  and confirm the test fails naming the actual count.

### The test cannot run at all

- **"Not yet run" describes a schedule; "cannot run" describes a defect.** They are recorded with
  the same words. When tests are written ahead of the code they test, the deliverable is the test
  file *plus* a demonstration that the harness starts. If the environment can't run them, record
  what was never verified precisely: not "these have not run" but "these have never been observed
  to start, and their dependencies are uninstalled".
- **Never unblock a test by weakening its subject.** Enumerate the candidate unblocking changes and
  reject any that alter the behaviour under test — granting the permission the test exists to deny,
  relaxing the constraint, stubbing the boundary being verified. That converts an unrunnable test
  into a misleading one, which is strictly worse. Prefer changing how the test obtains its fixtures.
  Where the right fix is bigger than the task, verify the behaviour by another route and leave the
  blocker visible.

### The check's correctness is a matter of degree

Natural language, heuristics, similarity, classification. Here "it passed" carries no information:
a correct check and a blind one produce identical output.

**Ship it as a non-failing report first.** Run it over a corpus of real recorded outputs,
hand-classify its hits into true and false, and let that measured rate decide whether it can gate.
Record the number in the suite so a later loosening of the heuristic shows up as a diff. Do the
measuring while the check still cannot fail anything — the moment it can fail a build, the
incentive shifts from measuring it to satisfying it.

### The environment is cached

A cached environment turns "the tests passed" into "the tests passed against whatever this
environment happens to contain". A harness that skips expensive setup when something is already
running will happily test a stale schema and exit 0. Either detect staleness (compare what's applied
against what's on disk and refuse to run), or recreate after every merge — and cross-check the
observed assertion count against the suites' own declared plan counts rather than trusting the exit
code. An independently derived expectation of what should have run is the only thing that catches it.

### Local passes, deployed fails

An emulator verifies your code against *its* implementation of a service, not against the service —
and it is usually the more permissive of the two. Configuration and schema that the hosted product
validates on ingest are the highest-risk category, invisible to every local test you will ever
write. The remedy is not more local tests; it is one cheap disposable instance of the real thing in
the pipeline, and the first run of it is a review step in its own right.

## Good Tests

| Quality | Good | Bad |
|---------|------|-----|
| **Minimal** | One thing. "and" in name? Split it. | `test('validates email and domain and whitespace')` |
| **Clear** | Name describes behavior | `test('test1')` |
| **Shows intent** | Demonstrates desired API | Obscures what code should do |

When writing or changing any test, read [writing-good-tests.md](writing-good-tests.md) for the rules that keep tests honest:
- Name the production change that would make the test fail — before writing it
- Assert on real behavior, never on mock behavior
- Keep test-only code in test utilities, out of production classes
- Understand a dependency's side effects before mocking it

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests written after pass immediately — which proves nothing. They may test the wrong thing, test the implementation instead of the behavior, or miss the edge case you forgot. You never watched it fail, so you never proved it can catch the bug. Test-first forces that failure. |
| "Tests after achieve same goals (spirit not ritual)" | Tests-after answer "what does this do?"; tests-first answer "what should this do?" Tests written after are biased by the code you already wrote — you verify the cases you remembered, not the ones you'd have discovered. Coverage without proof the tests work. |
| "Already manually tested" | Manual testing is ad-hoc: no record of what you covered, no way to re-run it when the code changes, easy to forget cases under pressure. "Worked when I tried it" ≠ comprehensive. Automated tests run the same way every time. |
| "Deleting X hours is wasteful" | Sunk cost fallacy — that time is already spent either way. The real choice: rewrite with TDD (high confidence) vs. keep it and bolt tests on after (low confidence, likely bugs). Keeping code you can't trust is the waste. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "Test hard = design unclear" | Listen to test. Hard to test = hard to use. |
| "TDD will slow me down" | TDD IS the pragmatic path: catches bugs before commit, prevents regressions, lets you refactor without fear. "Pragmatic" shortcuts mean debugging in production — slower, not faster. |
| "Manual test faster" | Manual doesn't prove edge cases. You'll re-test every change. |
| "Existing code has no tests" | You're improving it. Add tests for existing code. |

## Red Flags - STOP and Start Over

- Code before test
- Test after implementation
- Test passes immediately
- Can't explain why test failed
- Tests added "later"
- Rationalizing "just this once"
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about spirit not ritual"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"
- "TDD is dogmatic, I'm being pragmatic"
- "This is different because..."

**All of these mean: Delete code. Start over with TDD.**

## Example: Bug Fix

**Bug:** Empty email accepted

**RED**
```typescript
test('rejects empty email', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
```

**Verify RED**
```bash
$ npm test
FAIL: expected 'Email required', got undefined
```

**GREEN**
```typescript
function submitForm(data: FormData) {
  if (!data.email?.trim()) {
    return { error: 'Email required' };
  }
  // ...
}
```

**Verify GREEN**
```bash
$ npm test
PASS
```

**REFACTOR**
Extract validation for multiple fields if needed.

## Verification Checklist

Before marking work complete:

- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for expected reason (feature missing, not typo)
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass
- [ ] Output pristine (no errors, warnings)
- [ ] Tests use real code (mocks only if unavoidable)
- [ ] Edge cases and errors covered
- [ ] Each test failed for the reason it names, not merely because the feature was absent
- [ ] Any suite you did not watch go red has been mutation-tested
- [ ] The environment the suite ran against is current, not cached

Can't check all boxes? You skipped TDD. Start over.

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write wished-for API. Write assertion first. Ask your human partner. |
| Test too complicated | Design too complicated. Simplify interface. |
| Must mock everything | Code too coupled. Use dependency injection. |
| Test setup huge | Extract helpers. Still complex? Simplify design. |

## Debugging Integration

Bug found? Write failing test reproducing it. Follow TDD cycle. Test proves fix and prevents regression.

Never fix bugs without a test.

## Final Rule

```
Production code → test exists and failed first
Otherwise → not TDD
```

No exceptions without your human partner's permission.
