# Release signing custody

**Status: decided, not executed.** T039 remains open. This file records what was decided on
2026-07-29 and why, so the reasoning is not reconstructed under launch pressure. Nothing here has
been carried out — no account is registered, no key exists.

This file never contains a secret. It contains the path to one.

## The failure model, corrected

`spec.md`, `HANDOFF.md` and ADR-0006 all stated that losing the Android upload key or the Apple
distribution certificate permanently prevents updating the app. Checked against Google's and
Apple's documentation, that is wrong in both halves. Three files agreeing was one unverified
belief copied forward.

| Asset | Held by | If lost |
|---|---|---|
| Android **app signing key** | Google (see decision 1) | Permanent — the only one-way door |
| Android **upload key** | Us | Reset through Play Console |
| Apple distribution certificate | Us | Revoke and regenerate |
| Apple provisioning profile | Us | Regenerate |
| **Account access** (Google, Apple ID) | Us | **The real risk on both platforms** |

## Decisions

**1. Google generates and holds the Android app signing key.** Chosen at first Play upload and
irreversible thereafter. We never possess the only irrecoverable asset, so we cannot lose it.

*Accepted cost:* a Play-signed build cannot be upgraded in place by an identically-signed APK
from another store. Shipping through Huawei AppGallery or direct download later means a separate
key and a separate install base. Accepted deliberately, not by omission — revisit if Egyptian
Android distribution outside Play becomes a real channel.

**2. Apple Individual membership**, not Organization.

*Accepted cost, and it is sharp:* an Individual account cannot transfer its Account Holder role
to another person, and Apple's Digital Legacy covers personal iCloud data, not developer
memberships. So on iOS, "recoverable by more than one person" is achievable only through
credential recovery — a trustee getting into the Apple ID — never through a role handover.

*Exit:* migrating to an Organization needs a legal entity, a D-U-N-S number, a new membership and
a formal app transfer. Decide before the App Store listing, since Organization also changes what
Apple calls the seller name — the attribution a Customer sees on the listing — from a personal
legal name to `Kafoo`. ("Seller" here is Apple's field, not Kafoo vocabulary; a person who cooks
is a Cook.)

**3. Dedicated accounts.** The Play Console is registered under a Google account created for
Kafoo, and the Apple membership under an Apple ID created for Kafoo — never personal ones. A
trustee is given break-glass access to these accounts; if they were personal, that same envelope
would open personal mail, photos and backups.

**4. Custody is one indirection.** A password vault holds the credentials and the upload key; the
trustee holds only what opens the vault. Rotating a key or password never requires re-sealing the
trustee's envelope, so the envelope cannot silently go stale.

**5. The trustee is a break-glass backstop, not a second operator.** They are non-technical. The
recovery path must be a password and a printed code, never a command line.

## Execution order — reversibility first

Steps 1–3 are reversible at no cost. Step 4 is the one-way door.

1. Register the two dedicated accounts. Two-factor on both. Trustee added as the Apple **Account
   Recovery Contact** and as a second trusted phone number. Google backup codes printed.
   Do **not** enable an Apple Recovery Key — it disables support-assisted recovery, which is the
   wrong trade when the backstop is a non-technical person holding paper.
2. Create the vault. Grant the trustee time-delayed emergency access. Seal the envelope.
3. Generate the upload key locally, on a trusted machine — never in CI, never in an ephemeral
   development container:

   ```
   keytool -genkeypair -v -keystore upload.jks -keyalg RSA -keysize 4096 \
     -validity 10000 -alias kafoo-upload
   ```

   Distinct store and key passwords; `deploy.yml` reads them as separate secrets.
4. **First Play upload: choose "Let Google create and manage my app signing key."** ← one-way
5. T040 — the four Android secrets into repository settings. T041 — verify a genuinely signed
   candidate.
6. **The drill.** Before the first external TestFlight build, the trustee opens the envelope and
   reaches the vault unaided. Then reseal. An untested recovery path is `HANDOFF.md` trap #1: a
   green gate that checked nothing. The drill is what closes FR-016, not the storage.

## Open

- Whether a physical sealed envelope is workable for this trustee, or vault emergency access
  alone carries it
- Apple Individual → Organization, to be decided before the App Store listing
