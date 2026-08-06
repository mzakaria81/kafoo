# Spike: the Gemini Live API for Customer discovery

T084 / WP-005, run 2026-08-06 against the live free-tier key. **Throwaway by construction** — every
line of probe code was written in a scratch directory outside the repository and is gone. Nothing
here is wired into Kafoo, and nothing should be until ADR-0009 is decided.

## The question, and the answer

ADR-0009 scopes this spike to three questions **in order, stopping at the first no**:

1. **Does the ephemeral-token flow actually work?** If not, the thin-client proposal is dead.
2. Does Live hear Egyptian Arabic better than on-device transcription?
3. What does a conversation cost?

**Question 1 is NO as tested, so questions 2 and 3 were not run.** That is the instruction, and it
is also the honest use of a free-tier budget: a dialect comparison against an architecture that
cannot ship would be a number nobody can act on.

## What was actually established

| Claim | Result |
|---|---|
| The Live API surface exists and answers this key | **YES** — `gemini-2.5-flash-native-audio-preview-09-2025` opened a `BidiGenerateContent` socket and returned a setup response |
| `POST /v1alpha/auth_tokens` exists | **YES** — HTTP 200, returns a 76-character `auth_…` token |
| A minted token opens a Live session | **NO** — refused in both presentations |
| The token honours `uses: 1` | **Unknown** — it never worked once, so there was nothing to exhaust |

The two refusals, which say different things and are both worth recording:

```
?access_token=<token>   1008  Method doesn't allow unregistered callers
                              (callers without established identity).
?key=<token>            1007  API key not valid. Please pass a valid API key.
```

`?key=` is the right slot — the error moves from "who are you" to "that is not a valid key" — and
the token is still rejected.

**The mint endpoint accepts anything and validates nothing.** Four payloads were sent: bare,
with `expireTime`, with `bidiGenerateContentSetup`, and with `newSessionExpireTime`. All four
returned an identical `{"name": "<76 chars>"}` — no echo, no expiry, no session binding, no error on
fields it should have rejected. An endpoint that returns the same stub whatever you ask it is not
obviously wired up for this account.

**Latency, since it was measured anyway:** minting took 492–705 ms; refusals came back in
365–390 ms.

**Cost: zero.** No session completed, so no audio tokens were consumed. Question 3 remains open, as
it should — it is behind a gate that did not open.

## What this means for ADR-0009

ADR-0009 says of Option C, thin client with ephemeral tokens:

> If ephemeral tokens do not work as believed, this collapses into B and must not be built.

Option B is a compiled-in credential in a shipped binary, which that ADR already records as
disqualifying — it cannot be rotated, and it reverses ADR-0005 Amendment 1.

**So on today's evidence Option C is not available and Option A (status quo) stands.** Nothing needs
building, which is the cheapest possible outcome.

**Recommendation: leave ADR-0009 at Proposed rather than moving it to Rejected**, and re-run this
spike before E3 commits. The reason is in the next section — the thing being tested is a preview
surface that is visibly in flux, and "does not work today" is a weaker claim than "cannot work".

## What I could not rule out, stated plainly

**I cannot prove the token is unusable, only that I could not use it.** Two presentations were
tried. A third may exist — an `Authorization: Token` header, a different socket path, a field
combination the mint silently requires. The ADR turns on this, so the residual uncertainty belongs
in the record rather than being rounded to a verdict.

**What is solid** is narrower and still decisive for now: with the documented query-parameter
presentations, a token minted by this account does not open a Live session, while the long-lived key
does. Anyone re-running this should start by trying to make the token work, not by re-confirming
that Live is reachable.

## Two things that would have produced a confidently wrong answer

Both are the same failure this repository keeps finding — a check that answers without being able to
know — and both were caught only by asking the thing itself rather than the thing that describes it.

**1. The model listing says Live does not exist.** `GET /v1beta/models` and `GET /v1alpha/models`
both return 50 models and **not one** advertises `bidiGenerateContent`. No native-audio model, no
`*-live-*` model. Read alone, that is a clean "the Live API is unavailable on this key" — and it is
wrong. Opening the socket directly worked on the first candidate name.

**2. `auth_tokens:create` returns 404.** That was the first path tried, by analogy with other Google
APIs. Taken at face value it says the ephemeral-token endpoint does not exist, which would have
killed ADR-0009 Option C outright. The correct path is `auth_tokens` with no `:create` suffix, and
it returns 200. **The hinge of the whole decision was one URL suffix away from a wrong answer in the
decisive direction.**

**The rule both cases point at: a 404 or an empty listing is evidence about the question you asked,
not about the world.** Before concluding a capability is absent, call something you know works and
confirm you are talking to the service at all.

## The rate-limit page and the API disagree, in both directions

WP-005's brief records three Live models from the founder's AI Studio rate-limit page on
2026-08-05 — Gemini 2.5 Flash Native Audio Dialog, Gemini 3 Flash Live, Gemini 3.5 Live Translate —
and records Veo 3 as **not** available, reading 0/0.

Measured against the API on 2026-08-06:

- Of the three named Live models, **only one responds**, under a longer name
  (`gemini-2.5-flash-native-audio-preview-09-2025`). `gemini-3-flash-live-preview` and
  `gemini-live-2.5-flash-preview` are both refused as not found.
- **`veo-3.1-generate-preview` is listed and visible**, the one the page said was unavailable.

A quota page shows what a plan is entitled to. It does not show what a key can call today. Treat it
as a budget document and not as an inventory — the same distinction `CLAUDE.md` already draws for
OpenCode, where a model appearing in a listing says nothing about which account pays for it.

## If this is re-run

Free tier only — the founder authorised no paid tier, and this spike never left it. Start at the
token, not at the socket. The order that would have saved time here:

1. Mint a token and try every presentation until one opens a session, or the presentations are
   exhausted and written down.
2. Only then, dialect quality against T083's on-device baseline.
3. Only then, cost per minute of conversation.

And before believing any negative result, make a call you expect to succeed.
