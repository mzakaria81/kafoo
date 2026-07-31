# ADR-0007 — Dormancy severs a phone credential, not a Person

**Status:** Accepted
**Date:** 2026-07-31
**Decider:** Founder

## Context

Kafoo anchors identity to a phone number (FR-001, FR-002). Egyptian numbers are recycled, so the
number that proves a Person today can belong to a stranger later. E1 raised this as Open Question 2
and deliberately did not answer it.

The carrier timings, supplied by the founder and applying uniformly across Vodafone, Orange,
Etisalat (e&) and WE under NTRA rules:

| Line type | Deactivated after | Grace period | Reassignable from |
|---|---|---|---|
| Prepaid | 90 days of no revenue-generating activity | 15 days | **105 days** |
| Postpaid | 180 days of inactivity | 15 days | 195 days |

Kafoo cannot tell a prepaid line from a postpaid one, so **105 days is the binding constraint** for
both.

What forced the decision now rather than later: the cost of getting it wrong rises sharply the
moment a Person's identity starts carrying reputation. Today a recycled number inherits a Kitchen
Profile. After E4 and E5 it inherits Orders and Reviews — real reputation attached to the wrong
person, which is the failure class the constitution already calls product-fatal for synthetic
Reviews. The decision is cheap only while E1 is the whole surface area.

## Options considered

| Option | Cost | Risk | Reversibility |
|---|---|---|---|
| Never inherit — after a dormancy window the number stops proving the identity | A Cook returning past the window who declined the recovery email cannot get back in unaided | Wrongly severs Cooks who are simply away; every such Cook without a second credential is a real loss | High — the window is one number, and the sever is lazy |
| Never lock out — a number resolves to the same Person forever | None to build | Whoever holds the number next signs in to a stranger's account, with their Kitchen Profile and, later, their Orders and Reviews. Invisible to the victim; unwindable only before the first Order | High, but the damage already done is not reversible |
| Challenge at re-entry — after dormancy the code alone is insufficient, and Kafoo asks the caller to confirm an account detail | Needs a question most Cooks can answer and a stranger cannot | The question itself reveals the number is known and hints at what is behind it, which is exactly the disclosure FR-006 forbids; and a Cook with no second credential has nothing to be asked about | High |

## Decision

A phone number proves an identity only while that identity is in use. After **90 days** with no
Kafoo activity, the number is detached from the Person it proved, and whoever next presents that
number with a valid code becomes a new Person with nothing attached. The dormant Person is not
deleted at that moment — it survives without its phone credential, reachable through an attached
recovery email, and is removed after a further **365 days** through the same path as FR-032 account
removal. The check runs lazily, at the moment a number resolves to an existing Person, and nothing
sweeps the user table in the background.

Dormancy is measured from **last activity on a valid session**, not from the last sign-in. Any app
open counts; no re-authentication is required to stay active.

## Consequences

**Accepted costs.**

A Cook who does not open Kafoo for 90 days and declined the recovery email loses their way back to
their own Kitchen Profile. This widens a cost E1 already accepted — the spec accepts it for a
permanently lost number — from "lost the number" to "stopped using the number". For a Cook who did
attach an email the cost is one extra step: sign in by email, then move the number across with
change-of-number (FR-026). Both routes already exist; this decision builds no new recovery path,
it gives the existing invitation a second reason to exist.

The sever is silent. The caller sees an ordinary first-time Kafoo, because any message
distinguishing a returning owner from a stranger would be the disclosure FR-006 forbids — which
means a wrongly-severed Cook gets no explanation either. Kafoo genuinely cannot tell them apart.

**Why 90 and not 105.** Using Kafoo consumes data, which is line activity, so the last Kafoo
activity is never later than the last line activity. Kafoo-dormancy is therefore always greater
than or equal to carrier-dormancy. When a line becomes reassignable at 105 days, Kafoo's own clock
already reads at least 105, so the sever has already happened. Kafoo errs early, never late, and it
never has to trust the length of the carrier's quarantine. 90 leaves the grace period as margin.

**What this forecloses.** Kafoo can no longer promise that a number reaches the same Person
indefinitely, and no design may assume it. Reopening that would mean accepting inheritance, which
this ADR rejects on trust grounds.

**Revisit trigger.** Any of: NTRA or a carrier changing the prepaid reassignment window below 105
days; measured evidence that ordinary Cooks routinely go 90 days without opening Kafoo; or a
verified carrier-side signal that a number has changed hands, which would make the whole
threshold approach unnecessary.

## Open dependencies

Two things this decision names and does not resolve. Neither changes the decision; both change the
implementation or the numbers.

1. **The carrier windows above are founder-supplied and unverified against NTRA's own published
   terms.** ADR-0006 asserted a signing failure model on the same footing and was wrong. Confirm
   before `D` is fixed in code.
2. **~~The interception point in Supabase is unknown.~~ Checked 2026-07-31 against Supabase's
   auth-hooks documentation: no hook reaches it.** The complete hook list is Custom Access Token,
   Send SMS, Send Email, MFA Verification Attempt, Password Verification Attempt, and Before User
   Created. None fires on a successful phone-OTP verification of an *existing* user — Before User
   Created is documented as running "before a **new** user is created", which is the one case this
   design does not need to touch.

   What remains open is which of two shapes to build, and that belongs in the plan rather than
   here:

   - **Block, don't reroute.** The Custom Access Token hook fires when a token is issued and can
     return an `error` object with an `http_code`, which Supabase Auth propagates to the client. A
     dormant identity could therefore be refused a session. That is half the behaviour: it stops
     the stranger getting in, but the number stays attached to the dormant Person, so the caller
     cannot become a new Person either. The `sub` claim is fixed by the time the hook runs, so no
     hook can reroute an identity mid-issuance.
   - **Wrap the OTP exchange in an Edge Function.** Kafoo owns the verification call: check last
     activity, detach the number from the dormant Person, then issue a session for a new one. This
     is the only shape that delivers the decided behaviour in full, and its cost is that Kafoo owns
     a step of the sign-in path it currently gets for free.

   The admin-API calls the second shape needs have not been read out of the documentation yet.

Open Question 4 — whether Kafoo offers a person-assisted way back — stays open. This design works
either way, and only the severity of the no-email case depends on it.

## Notes for Claude Code

A phone number is a credential with an expiry, not an identity. After 90 days of no Kafoo activity
the number is detached and the next caller presenting it is a new Person — never the old one. Do
not write a flow that assumes a number resolves to the same Person forever, and do not add a
message that tells a caller the number was previously known.
