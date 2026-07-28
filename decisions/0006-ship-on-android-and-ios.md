# ADR-0006 — Ship on Android and iOS

**Status:** Accepted
**Date:** 2026-07-28
**Decider:** Founder

## Context

Kafoo is a phone product. Until this decision, the target platforms were never recorded anywhere:
not in `CLAUDE.md`, not in the constitution, not in the domain model. A grep for `ios|android`
across the governance documents returned nothing.

The gap was not harmless. `flutter create --platforms=android,ios` had generated both projects,
but `deploy.yml` built only Android, so the pipeline quietly implied Android-only while the code
implied both. Neither was a decision — both were defaults nobody had examined.

Facts bearing on the choice:

- Egypt's smartphone market skews heavily toward Android, so an Android-first launch would reach
  most of the addressable audience.
- Flutter makes the *code* cross-platform at no extra cost. One codebase compiles to both. The
  cost of iOS is not development; it is release infrastructure and ongoing obligation.
- iOS release requires Apple Developer Program membership (~$99/yr), a macOS runner (roughly ten
  times an Ubuntu minute), and a signing model with a certificate *and* a provisioning profile
  *and* entitlements — materially more surface than Android's single keystore.
- Cook and Customer are the same binary. Restricting platforms restricts both sides of the
  marketplace, and a Cook who cannot list Meals is a supply problem, not only a reach problem.

## Options considered

| Option | Cost | Risk | Reversibility |
|---|---|---|---|
| Android only | Lowest. One signing identity, Ubuntu runners, one store relationship. | Excludes iOS Customers *and* iOS Cooks. Supply-side exclusion is the sharper risk for a marketplace. | High — the code is already cross-platform; adding iOS later is pipeline work |
| iOS only | Similar infrastructure to both, for a smaller share of the Egyptian market | Misses most of the addressable audience | High |
| **Both** | Apple membership, macOS runner minutes, two signing identities, two store review relationships | Two release processes to keep working; iOS review is stricter and slower | Medium — withdrawing from a store after launch is worse than never entering |
| Both, Android first | Same eventual cost, sequenced | Risks iOS becoming permanently "next quarter" — the code stays cross-platform but the release path rots untested | High |

## Decision

Kafoo ships on **Android and iOS**. Both platform projects are maintained, and the release
pipeline builds a candidate for each.

The iOS job is gated behind a preflight check for signing secrets, so it does not start — and
does not consume macOS runner minutes — until Apple Developer credentials exist. Until then the
iOS path is configured and inert, which is deliberate: the pipeline is written while the
reasoning is fresh, rather than reconstructed under launch pressure.

## Consequences

**Accepted costs.** Apple Developer Program membership, recurring. macOS runner minutes on every
merge to `main` once signing exists. Two signing identities to store and recover rather than one,
which doubles the surface of ADR-0006's sibling problem — a lost key on either platform is
permanent for that platform. Two store review relationships, with iOS review historically
stricter and slower. Every release checklist item now applies twice.

**What this forecloses.** Android-only shortcuts: platform-specific APIs without an iOS
equivalent, Android-only permission models, and anything in the voice pipeline that assumes
Android's audio stack. Microphone permission handling in particular must be designed for both
from the start, since the voice-first flow depends on it.

**Revisit trigger.** Reopen if either holds:

1. iOS installs remain under 5% of total six months after both stores are live — the ongoing cost
   would then exceed the reach it buys, and Android-only becomes defensible on evidence rather
   than convenience.
2. Apple review rejects Kafoo on a ground that cannot be satisfied without breaking a
   constitutional rule — for example a demand that would require presenting an AI estimate as
   verified fact, or collecting allergy data beyond what a specific Order requires.

## Notes for Claude Code

Kafoo targets Android and iOS. Do not add a platform-specific dependency without checking it has
an equivalent on the other platform, and do not design a flow — especially anything touching the
microphone — that only works on one. The release checklist in
`.claude/agents/release-engineer.md` applies to both; a store listing in Egyptian Arabic is
required for each.
