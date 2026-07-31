# Phase 0 — Research

Decisions taken before design, with what was rejected and why. Where something could not be
verified from this environment, it says so and names the check that must happen — asserting an
unverified fact is the failure mode E0 was created to stop.

---

## 1. Where identity lives

**Decision**: `auth.users` **is** the Person. Kafoo stores no phone number, no email address, and
no credential of its own. Application tables reference `auth.users(id)`.

**Rationale**: FR-025 requires a person's identity to exist independently of the phone number that
proves it. Supabase Auth already models exactly that — one `auth.users` row with `phone` and
`email` as separate nullable columns on it. The identity is the row; the credentials are fields.
Changing a number is an update to that row, which is FR-026 for free.

It also satisfies FR-020 without any policy of our own: `auth.users` is not exposed through the
data API, so a phone number is reachable only through the signed-in person's own session. A phone
number we never copy into our own tables is one we can never leak from them.

**Alternatives considered**:

- *A `people` table of our own, keyed to the auth user.* An extra table with no field E1 needs,
  and a second place a phone number could end up. Rejected as unrequested structure.
- *Phone number as the primary key.* Rejected in `/speckit-clarify`; would make FR-026 a migration
  touching every future table.

---

## 2. The one-time code, and who sends it

**Decision**: Supabase Auth phone OTP. Provider chosen in configuration, not in code. **Start with
Twilio Verify**, and treat the choice as reversible.

**Rationale**: Supabase supports Twilio, Twilio Verify, MessageBird, Vonage and TextLocal, all
selected by configuration. Nothing in Kafoo's code changes if the provider does, so this is not an
architectural decision and does not deserve to be treated as one. Twilio Verify is the starting
point because it owns retry, expiry and fraud handling, which are otherwise ours to build and get
wrong — and because delivery into Egypt is then its problem rather than Kafoo's.

**Cost is the real trade**, and it is not small: Twilio Verify is billed per successful
verification, materially above a raw SMS. Every sign-in on a new device costs money, which makes
FR-005's rate limiting a spending control as much as a security one.

**Must be verified before implementation, not assumed** — neither could be confirmed from here:

1. **Egypt A2P deliverability and sender-ID registration.** Egyptian operators generally require
   registered sender IDs for application-to-person messaging. An unregistered sender can be
   silently filtered — the worst failure mode, because the code simply never arrives and nothing
   errors.
2. **Real per-verification cost into Egyptian networks**, against expected sign-in volume.

Both are a spike with a real phone on an Egyptian network, not a documentation exercise. Until it
passes, the sign-in flow is unproven no matter what the tests say.

**Alternatives considered**:

- *A local Egyptian SMS aggregator.* Almost certainly cheapest per message and best placed for
  sender-ID registration, but needs a business entity and a contract, neither of which exists.
  Revisit once Kafoo is incorporated.
- *WhatsApp OTP.* Enormous reach in Egypt and would fit the audience well. Rejected for now:
  it needs a WhatsApp Business account, template approval, and a provider integration — a
  significant scope increase for a fallback that phone OTP already covers. Worth a spike later.

---

## 3. Spoken answers

**Decision**: **on-device speech recognition** via the platform's own engine (`speech_to_text`,
which wraps Apple's Speech framework and Android's `SpeechRecognizer`). Typing is always available
and is never a second-class path.

**Rationale**: this is the rare choice that satisfies a privacy rule by construction rather than by
policy. The constitution requires voice to be transcribed and discarded, with an ADR before any raw
audio is stored. On-device recognition means **audio never leaves the phone at all** — there is no
transport to secure, no retention policy to write, and no ADR needed, because Kafoo never receives
a recording.

It also keeps this feature entirely clear of ADR-0005: no model call, so no `AiProvider`, so no
provider abstraction to route through and no golden-case test to write. E1 stays free of any
dependency on a model provider, which was the point of keeping the AI Assistant out of scope.

And it costs nothing per use, where cloud transcription is billed per minute of a Cook talking.

**Must be verified, and it is the larger risk of the two**: whether `ar-EG` recognition is actually
available on the devices Egyptian Cooks own. Platform support for a locale is not the same as it
being present on a given handset — Android in particular downloads language packs, and a mid-range
device bought in Egypt may not have Arabic installed. This cannot be checked from here.

**The design must therefore not assume it works.** If recognition is unavailable, the conversation
degrades to typing with an explanation rather than failing. FR-012 requires spoken answers to be
accepted; it does not require them to be the only way, and a flow that breaks without a language
pack would be worse than one that never offered voice.

**Alternatives considered**:

- *Cloud transcription (Whisper or similar).* Better and more consistent Egyptian Arabic, almost
  certainly. Rejected for E1 because it sends audio off the device, engages the provider
  abstraction, requires an ADR for audio handling, and costs per minute. It is the right answer
  *if* the on-device spike fails — and that is a decision worth making on evidence.

---

## 4. Removing an account

**Decision**: a single Edge Function, `delete-account`. It takes **no arguments**, reads the person
from the verified JWT, and removes their storage objects, their rows, and their auth user.

**Rationale**: this is forced rather than chosen — the client SDK cannot delete an auth user, which
requires the service role, and a service-role key must never reach a phone. So the work belongs
somewhere trusted, and an Edge Function is the only such place Kafoo has.

Taking no arguments is the design, not an accident. The constitution requires Edge Functions to
read identity from the JWT and never from a client-supplied `user_id`. A function with no
parameters cannot be made to delete the wrong person, however it is called. There is no input to
validate because there is no input.

**Alternatives considered**:

- *A `deleted` flag with a nightly sweep.* Rejected outright: Apple's guideline says explicitly
  that the ability to deactivate does not satisfy the requirement, and FR-033 requires genuine
  removal. A flag would also leave the phone number in `auth.users`, so the same number could not
  start a new person — breaking FR-033's second half.
- *Removal by request to a person at Kafoo.* Not compliant. That route is reserved for
  highly-regulated industries.

---

## 5. Where measurement goes

**Decision**: an `analytics_events` table in Kafoo's own database. **No third-party analytics SDK.**

**Rationale**: FR-039 requires that removing an account reaches the funnel data, and that is the
whole argument. In Postgres it is a foreign key — the database enforces it, and
`./scripts/verify.sh` can prove it with a test. With a third-party analytics service it becomes an
API call made on a best-effort basis to a system Kafoo cannot inspect, and the promise of genuine
removal would rest on a deletion endpoint working correctly, forever, unobserved. That is not a
promise this project can honestly make.

Three smaller reasons point the same way. FR-040's reader restriction is an RLS policy rather than
a third party's dashboard setting. No third-party SDK is shipped inside the app, so nothing phones home
from a Cook's device. And the data stays in Egypt-adjacent infrastructure Kafoo already controls
rather than being copied to another jurisdiction — which matters for personal data.

**`ON DELETE SET NULL`, not `CASCADE`.** FR-039 permits removal *or permanent unlinking*, and
unlinking is better: the funnel counts survive, so "how many people gave up at question three"
stays answerable, while nothing identifies the person who left. Since FR-037 already forbids
content in an event, a row with no person attached identifies nobody. Cascade would delete the
person *and* silently corrupt every historical funnel that included them.

**Alternatives considered**:

- *PostHog, self-hosted.* Genuinely good, and the right answer at a scale Kafoo is nowhere near.
  Another service to run, secure and back up, for a table with a handful of columns.
- *Firebase Analytics.* Rejected on FR-039: per-person deletion is awkward, and it would put
  behavioural data about Egyptian Cooks into a third party's pipeline by default.

---

## 6. Discoverability, when the thing it depends on does not exist

**Decision**: E1 ships **no public read policy** on `kitchen_profiles`. Public discovery arrives in
E2, in the migration that creates `meals`.

**Rationale**: FR-030 makes a Kitchen Profile discoverable only while its Cook has a published
Meal. Expressed as a policy that is an `EXISTS` against `meals` — a table E1 must not create, since
this project's own rule is that a table belongs to the feature that needs it, together with its
policy and its negative test.

The resolution is that the correct E1 behaviour and the achievable E1 behaviour are the same thing.
No Meals exist, so nothing should be discoverable, so the policy that grants public reads is simply
absent. That is not a stub or a placeholder — it is the deny-by-default posture the constitution
already requires, and it happens to be exactly right.

**This must be recorded where E2 will find it**, or E2 ships `meals` and silently leaves every
Kitchen Profile invisible. It goes in `data-model.md` and in the E2 handoff, not only here.

---

## 7. What is deliberately *not* being added

Each of these is a thing a Flutter project usually acquires early. None is being added, and the
reason is the same in every case: E1 does not need it, and the constitution puts simplicity second
only to trust.

- **No state-management package.** `supabase_flutter` exposes authentication state as a stream
  already. E1's entire cross-cutting state is "is someone signed in, and who". A stream and the
  widgets Flutter ships with cover it. Revisit when a screen needs state that is neither local nor
  auth — which E2 may well be.
- **No routing package.** E1 has a handful of screens and one branch. Add one when the branching is
  real.
- **No repository or service layer.** `packages/domain` holds the entity and its rules; the data
  access is thin enough to sit behind one class. An abstraction over a database Kafoo has no
  intention of changing is ceremony.

If any of these turns out to be wrong, adding it later is a normal refactor. Adding all three now
would be three abstractions justified by a feature that has not been built.

---

## 8. The photo

**Decision**: Supabase Storage, one bucket, public read, path keyed to the owner
(`{auth.uid()}/kitchen.jpg`). Write and delete restricted to the owner by storage policy.

**Rationale**: FR-019 makes the photo part of the deliberately public face of a Kitchen Profile, so
public read is the honest setting rather than a shortcut. Keying the path to the owner's id makes
the ownership policy a prefix match and removes any need to look the owner up.

**Stated plainly, because it is a real limitation**: a public bucket means anyone holding the URL
can fetch the object, without an authorization check. For data that FR-019 already declares public
that is acceptable. It would **not** be acceptable for anything private, and no private file may be
put in this bucket later on the grounds that it is convenient.

`delete-account` must remove these objects explicitly — storage is not covered by a foreign key,
so nothing removes them automatically. This is the one part of removal that is not enforced by the
database, which makes it the part most likely to be forgotten and the part most worth testing.

---

## Open risks carried into implementation

| Risk | Why it matters | How it gets resolved |
|---|---|---|
| `ar-EG` recognition missing on real Egyptian handsets | The voice-first premise of the whole product, first tested here | Spike on real mid-range Android devices before building the conversation |
| Egyptian A2P sender-ID registration | An unregistered sender is filtered silently — nothing errors, codes just never arrive | Spike with a real Egyptian number before relying on phone sign-in |
| Per-verification cost against real volume | Recurring spend that scales with sign-ins, and a decision for the founder rather than the plan | Measure during the same spike |

None of these blocks writing the code. All three block believing it works.
