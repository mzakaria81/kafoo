# Recycled phone numbers — settling E1's Open Question 2

**Date:** 2026-07-31
**Status:** Approved — decision only, **not implemented**
**Decision record:** `decisions/0007-dormancy-severs-a-phone-credential-not-a-person.md`
**Settles:** `specs/002-identity-kitchen-profile/spec.md` Open Question 2

> **E1 does not implement this.** E1 is merged and behaves as it always did: a phone number resolves
> to the same Person indefinitely. What is settled is the policy, not the code. The implementation
> needs the two open dependencies below closed first, and lands in its own slice with its own plan.

## The problem

Kafoo anchors identity to a phone number. Egyptian carriers recycle numbers. Nothing in E1 stops
the new holder of a recycled number from signing in and landing in the previous holder's account.

E1 settled the modelling half: FR-025 makes a Person independent of the number that proves them,
and FR-026 lets a number move between identities. The policy half was left open — when should
Kafoo stop trusting a number to prove who someone is, and does re-entry need more than a code.

## Why it had to be answered before E2

Today the loss is a Kitchen Profile. After E4 and E5 it is Orders and Reviews — real reputation
attached to the wrong person. That is the same failure class as the synthetic Reviews the
constitution calls product-fatal, arrived at by a different route. The decision is cheap only
while E1 is the whole surface area.

## The decision

**A phone number proves an identity only while that identity is in use. Dormancy severs the
credential, never the Person.**

After `D` = 90 days with no Kafoo activity, the number is detached from the Person it proved.
Whoever next presents that number with a valid code becomes a **new** Person with nothing attached.

The trade-off was chosen on Kafoo's priority order, where user trust ranks first. The two failures
are not symmetric:

| | Lockout | Inheritance |
|---|---|---|
| Who is harmed | One person | The Cook whose reputation is taken, every Customer trusting it, and FR-008 itself |
| Visible to the victim | Immediately | Never |
| Reversible | Yes, via the recovery email | Not once an Order is placed under it |
| Existing mitigation | Recovery email (FR-028), assisted route if Open Question 4 is answered | None |

A third option — challenging the caller at re-entry for an account detail — was rejected. The
question itself reveals the number is known and hints at what is behind it, which is the disclosure
FR-006 forbids, and a Cook who declined the email has no second credential to be asked about.

## The clock

**Dormancy is measured from last activity on a valid session, not from the last sign-in.** This
matters more than the threshold value does.

The carrier measures dormancy from the last revenue-generating use of the *line*. Kafoo cannot
observe that. It can observe its own use, and the two relate in one direction:

> Using Kafoo consumes data, so it is line activity. The last Kafoo activity is therefore never
> later than the last line activity, which makes Kafoo-dormancy always **greater than or equal to**
> carrier-dormancy.

That asymmetry is what makes the policy sound rather than lucky. When a line becomes reassignable
at 105 days, Kafoo's own clock reads at least 105, so the sever has already happened. Kafoo errs
early, never late, and never has to trust the length of the carrier's quarantine.

Measuring from `last_sign_in_at` instead would break this. Sessions survive force-quits by design
(T027), so a Cook using Kafoo happily on a months-old session would read as dormant and be severed.
Any app open counts as activity; no re-authentication is required to stay active.

## Thresholds

| Symbol | Value | Meaning |
|---|---|---|
| `D` | 90 days | No Kafoo activity → the number is detached at the next sign-in attempt |
| `R` | 365 days | Severed Person with no way back in → removed |

`D` is bounded above by the prepaid reassignment window of 105 days, which governs both line types
because Kafoo cannot tell them apart. 90 leaves the 15-day grace period as margin. Any value at or
under 105 is sound by the asymmetry above; 90 is chosen for the margin and because it is a number a
Cook can be told.

`R` runs from the sever. Removal goes through **the same path as FR-032 account removal**, not a
second deletion routine. One path means whatever E3 and E5 decide about keeping Orders and Reviews
a Customer needs applies here automatically, instead of a background job quietly deleting records
the removal flow was careful about.

## Mechanism

**The sever is lazy.** Nothing runs in the background — no cron, no sweep over `auth.users`. The
check happens at exactly one moment: when a caller presents a phone number and a valid code, and
that number resolves to an existing Person.

```
caller presents number + valid code
        │
        ├── number resolves to no Person ──────────────► new Person (unchanged behaviour)
        │
        └── number resolves to Person P
                │
                ├── P last active < 90 days ago ───────► sign in as P (unchanged behaviour)
                │
                └── P last active ≥ 90 days ago ───────► detach number from P
                                                         create new Person for the caller
                                                         P survives, credential-less
```

**What the sever does to the phone number:** it detaches it. The most sensitive field Kafoo touches
is gone at the moment of severing, a year before anything else — FR-022's retention promise doing
real work rather than restating itself.

## What a person sees

**The severed caller sees an ordinary first-time Kafoo.** No hint the number was known, which is
FR-006.

**A wrongly-severed Cook sees the same thing**, because Kafoo cannot tell them apart from a
stranger. Any message that distinguished the two would be the disclosure FR-006 forbids.

**With a recovery email attached, the recovery is one extra step and needs nothing new built:**
sign in by email (T060) → land in the original Person → attach the current number through
change-of-number (T063). This decision gives the recovery email invitation a second and sharper
reason to exist; it does not add a recovery path.

**Without one, the loss is real.** That is the accepted cost, and it is the cost E1 already
accepted at spec.md line 351 for a permanently lost number, widened from "lost the number" to
"stopped using the number".

## Testing

The behaviour is a boundary condition on a clock, so the tests are about the boundary and the
identity, not the UI:

- A caller whose Person was last active **just under** `D` reaches the **same** Person id.
- A caller whose Person was last active **just over** `D` reaches a **different** Person id.
- After a sever, the original Person still exists and still owns its Kitchen Profile.
- After a sever, the original Person has no phone number attached.
- After a sever, the new Person reads **zero** rows of the original's Kitchen Profile — the
  existing RLS negative tests already cover this shape and should be extended rather than copied.
- Any app open with a valid session moves the clock; a session refresh alone is not required to.

## Follow-on obligations

| What | Where | State |
|---|---|---|
| The decision, its costs and revisit trigger | `decisions/0007-…md` | Written |
| The rule as a domain invariant | `docs/product/domain-model.md` | Written |
| An event for the sever — `PhoneNumberDetached`, attribute `days_dormant` | `docs/product/event-model.md` | Written, status `planned` |
| Open Question 2 marked settled | `specs/002-identity-kitchen-profile/spec.md` | Written |
| Confirm 90/105/180/195 against NTRA's published terms | Before `D` is fixed in code | **Open** |
| Confirm the Supabase interception point | Before an implementation plan | **Open** |

## What this deliberately does not settle

**Open Question 4 — a person-assisted way back — stays open.** This design works with or without
it; the answer only changes how bad the no-email case is.

**If Question 4 is answered "no assisted route",** the severed-with-no-email case could have `R`
shortened, since the identity is then unreachable by construction. That is a later decision and
disturbs nothing here.

## Unverified premises, named as such

Two facts this design rests on are not verified, and are recorded as unverified rather than
absorbed as fact:

1. **The carrier windows are founder-supplied.** ADR-0006 asserted a signing failure model on
   exactly this footing across three documents and was wrong in both halves. Three documents
   agreeing was one unverified belief copied forward.
2. **The Supabase interception point is unknown.** Phone OTP resolves a verified number to its
   existing user automatically, and that is what this design must interrupt. Whether an auth hook
   reaches it or the OTP exchange needs wrapping in an Edge Function has to be read out of
   Supabase's documentation, not recalled.

Neither changes the decision. The first changes a number; the second changes the implementation.
