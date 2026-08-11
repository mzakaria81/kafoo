# Kafoo's OpenCode account — allowlist, billing and the spend ledger

Project-specific configuration for this repository. The rest of this skill is generic; everything
here is Kafoo's account and Kafoo's rules. Read it before dispatching anything.

Moved out of `CLAUDE.md` on 2026-08-09. It was 228 lines of the 631-line always-loaded instruction
file, describing a procedure that only matters in sessions that actually delegate.

> **Delegation is SUSPENDED as of 2026-08-06.** The weekly limit is reached. The founder lifts the
> suspension, not this file and not the ledger. Do not dispatch until he does.

## Why delegation exists here

**YOU MUST delegate implementation** when the suspension is lifted. Writing production code
directly is the exception, not the default. Founder's decision, 2026-08-02.

The reason is not cost. It is that **the author of a change is the worst available reviewer of it**,
and this repository's safety model — RLS negative tests seen to fail, mutation checks, a gate that
must go red before it goes green — depends on somebody reading the code with fresh eyes. Delegating
creates that separation structurally instead of asking one agent to pretend.

**Delegate, always:** feature code, migrations, Edge Functions, tests, refactors, renames, sweeps.

**Do it yourself, and say why:**

- **Architecture and decisions.** ADRs, spec and plan documents, choosing between approaches, and
  anything in `decisions/` or `.claude/`. A brief cannot carry the conversation that produced the
  judgement.
- **Diagnosis.** Use `--read-only` (the `plan` agent) to investigate; do not delegate a fix for a
  bug nobody has understood yet.
- **A change smaller than its brief.** A one-line fix costs more to describe than to make.
- **Anything the founder asked you specifically to do.** He asked you, not a subagent.

**Reviewing is not optional and not a formality.** Never accept "gates passed" on faith — run
`./scripts/verify.sh` yourself, read the diff against the brief, and check what a delegated agent
has no way to know: canonical vocabulary, Egyptian Arabic register, whether a negative test was
actually seen to fail, whether an RLS policy is as narrow as it looks. **You are accountable for
what you commit, whoever typed it.**

## Delegated work is still Kafoo work

Everything in `CLAUDE.md` and `.specify/memory/constitution.md` binds delegated code too. The brief
MUST carry the constraints the task touches — canonical vocabulary, RLS in the same migration, `ar`
ARB entries, no AI write path without human approval — because the implementer has none of the
orchestrator's context and does not auto-load `CLAUDE.md`.

The relay passes the parent environment to the child process: **do not delegate in a working tree
holding a real `.env`.**

## Signing in

Set `OPENCODE_API_KEY` as a cloud-environment variable, at claude.ai/code → the cloud icon above the
message box → the gear on your environment → **Environment variables**, one `KEY=value` per line.
opencode reads it directly for both the Go and Zen providers, so a session starts signed in.
`opencode auth login` also works but writes `~/.local/share/opencode/auth.json`, which dies with the
container — it signs in that session only.

**Never put the key in this repository**; `./scripts/verify.sh` fails if a real-looking one is
tracked by git.

Two caveats. Cloud environments have **no secrets store** — anyone who can use the environment can
read the value, so keep the key in a personal environment rather than an organization-shared one,
and treat it as rotatable. And `opencode.ai` is **not** on the default **Trusted** network
allowlist; an environment restricted to Trusted needs it added under **Custom**.

Without a credential, `opencode models` lists only the anonymous free tier and shows none of the
allowlist below. That is a missing key, not a drifted plan.

The opencode CLI is installed by `scripts/install-toolchain.sh`, so it is on `PATH` in every session.

## The prefix IS the billing boundary, and it is `opencode-go/`

**MUST NOT** dispatch anything outside `opencode-go/`. A metered model produces a real, unbudgeted
charge. If a task seems to need one, say so and let a human decide.

One `OPENCODE_API_KEY` authenticates two separate providers:

| Prefix | Provider | Billing | Models |
|---|---|---|---|
| `opencode-go/` | OpenCode Go | subscription, metered against caps | 18 — the published Go lineup |
| `opencode/` | OpenCode Zen | **metered, per token** | 60 — includes frontier models |

Both appear in `opencode models`, both carry Go-lineup model names, and the flat-rate one sorts
lower. **Verifying that a model exists is not verifying which account pays for it.** `opencode auth
list` shows the credential listed twice, once per provider.

This was found the hard way: a dispatch to `opencode/grok-4.5` failed with HTTP 401 `CreditsError:
Insufficient balance` against `https://opencode.ai/zen/v1/responses`. The model string named a
Go-lineup model and the request still went to Zen. The zero balance made that mistake free; a
topped-up balance would have made it silent.

**Do not substitute a same-named model from another provider.** `cloudflare-ai-gateway/`,
`amazon-bedrock/`, `github-models/` and `openrouter/` all carry Go-lineup names and none are covered
by this subscription. Same trap, one level out. If a model is missing from `opencode-go/`, the
subscription cannot reach it and no configuration changes that.

## The caps

Go is $5 for the first month then $10/month, metered against three dollar caps
(https://opencode.ai/docs/go/):

| Window | Cap |
|---|---|
| rolling 5 hours | $12 |
| week | $30 |
| month | $60 |

The `cost` field in a relay's `result.json` is what counts against those caps. Three `grok-4.5`
dispatches cost $0.44, $0.71 and $0.76 — $1.91 for one session, about a sixth of a five-hour window.
A delegation-heavy day can exhaust a window, and the failure mode is work stopping mid-task rather
than a surprise bill.

Model choice moves this by orders of magnitude, not percentages: the docs put MiMo-V2.5 at roughly
150,400 requests a month against Kimi K3's 490. **Send mechanical work to a cheap model because it
is cheap, not merely because it is sufficient.**

## Allowlist

The full published Go lineup, all eighteen:

`deepseek-v4-flash` · `deepseek-v4-pro` · `glm-5.1` · `glm-5.2` · `gpt-5.6-luna` · `grok-4.5` ·
`hy3` · `kimi-k2.6` · `kimi-k2.7-code` · `kimi-k3` · `mimo-v2.5` · `mimo-v2.5-pro` ·
`minimax-m2.7` · `minimax-m3` · `qwen3.6-plus` · `qwen3.7-max` · `qwen3.7-plus` · `qwen3.8-max`

**Always `opencode models --refresh` before concluding a model is missing.** The local catalog
caches, and a stale cache is indistinguishable from unavailability — a plain `opencode models`
returned seventeen of these where `--refresh` returned eighteen.

| Task shape | Model |
|---|---|
| Mechanical — renames, migrations, removal sweeps, formatting | `opencode-go/deepseek-v4-flash` |
| Ordinary implementation | `opencode-go/qwen3.6-plus` |
| Subtle logic, tricky bugs, anything near money, auth, or RLS | `opencode-go/grok-4.5` |

**Pick down this table, not up.** `grok-4.5` is the expensive row; reserve it for what the row
actually says. Update this allowlist from `--refresh` rather than improvising per task — a model
that no longer exists fails loudly, which is safe; a metered one does not.

## The spend ledger

**YOU MUST run it around every dispatch.** Neither command is optional:

```bash
python3 scripts/opencode-spend.py report          # BEFORE dispatching. Obey the verdict.
python3 scripts/opencode-spend.py record <relay-result-dir>   # AFTER every relay, pass or fail
```

Then **commit AND push `.claude/opencode-spend.jsonl` immediately, not at the end of the session.**
It is append-only, one row per dispatch, and lives in the repository because cloud containers are
destroyed after each session — an uncommitted ledger resets to zero against a cap that does not.
`opencode stats` cannot do this job; it reads the container's local database and starts empty.

Push immediately because **the caps are per account and `report` reads every remote branch**, not
just this checkout. Two parallel sessions see each other's spend only through what has been pushed,
so an uncommitted row is a row the other session will dispatch straight through. The report says how
many rows it found elsewhere and warns if it could not reach the remote — **that warning means halve
every cap**, because you are seeing at most your own half. `--local` skips the fetch and is for
debugging; it is not a faster `report`, it is a blind one.

Verdicts: `OK`, `WARN` at 70% of any window, `STOP` at 90%. `WARN` means send the next task down the
model table. `STOP` means finish what is in flight and start nothing new — the failure being avoided
is a long task dying halfway, not a bill.

**A ledger verdict is never authority to resume a suspension.** On 2026-08-06 `report` printed
`OK to dispatch` and `$18.85 left` while the account was already over its weekly limit. A quota
reconstructed from local records proves only a lower bound on consumption; its one trustworthy
answer is "stop".

## Calibration

The ledger is an approximation and honest about being one. It records what Kafoo spent, which tracks
the account only while delegated coding is the sole consumer of the subscription. It cannot see
spend from a laptop or another machine.

The authoritative number is the OpenCode workspace console, which needs a browser credential that
**must not** go in a cloud environment — no secrets store, and a console session reaches billing
rather than just model calls. So the founder sends a screenshot at the end of each day; he hovers a
day's bar and the tooltip gives the exact figure per model. Record each reading in
`.claude/opencode-calibration.jsonl`, one row per day per model, and commit it with the ledger.

**Do not put calibration rows in the ledger.** They carry a cost figure, everything that reads the
ledger sums cost figures, and the check would corrupt the number it exists to check.

The relay's `cost` is what the CLI computes, not what the account is billed, and the gap is per
model rather than uniform:

| Model | Ledger | Console | Drift |
|---|---|---|---|
| `qwen3.6-plus` | $4.24 | $4.36 | −2.7%, within 1% on every single day |
| `grok-4.5` | $7.28 | $5.35 | +36%, i.e. a third of a five-hour window spent on nothing |

`report` corrects per model from those readings before comparing to a cap, and prints the relay's
own figure beside the corrected one so the correction is visible rather than silent. **Adding a
day's reading is what keeps it accurate** — an uncalibrated report says so in its output.

Founder's tolerance, 2026-08-05: **8% per day after correction.** **A day outside tolerance is a
defect to investigate, never a reason to widen the band** — scaling a number that is wrong for a
knowable reason only hides the reason.
