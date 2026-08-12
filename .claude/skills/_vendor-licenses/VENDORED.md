# Vendored third-party skills

These skills were copied into `.claude/skills/` from public repositories, pinned to the
commits below. They are **third-party instruction sets that Claude follows autonomously** —
review them like any other dependency before trusting them in a session.

Installed: 2026-07-26

| Skill(s) | Source | Commit | License |
|---|---|---|---|
| `brainstorming`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `receiving-code-review`, `requesting-code-review`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `using-superpowers`, `verification-before-completion`, `writing-plans`, `writing-skills` | [obra/superpowers](https://github.com/obra/superpowers) | `3dcbd5c` | MIT |
| `ui-ux-pro-max` | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | `1307d97` | MIT |
| `find-skills` | [dan323/easier-life-skills](https://github.com/dan323/easier-life-skills) | `c302cb9` | MIT |
| `task-observer` | [rebelytics/one-skill-to-rule-them-all](https://github.com/rebelytics/one-skill-to-rule-them-all) | `281f134` | CC BY 4.0 |
| `opencode-delegate`, `claude-delegate` | [amElnagdy/delegate-skills](https://github.com/amElnagdy/delegate-skills) | `b28d826` | MIT |
| `caveman`, `caveman-commit`, `caveman-compress`, `caveman-help`, `caveman-review`, `caveman-stats`, `cavecrew` | [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) | `7066cc8` | MIT |
| `ponytail`, `ponytail-audit`, `ponytail-debt`, `ponytail-gain`, `ponytail-help`, `ponytail-review` | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) | `16f2980` | MIT |
| `improve-codebase-architecture`, `codebase-design` (added 2026-08-11) | [mattpocock/skills](https://github.com/mattpocock/skills) | `84fdeff` | MIT |

License texts are alongside this file. CC BY 4.0 requires attribution — keep
`task-observer.LICENSE` and the credit above with any redistribution.

## Local patches on vendored skills

A vendored skill edited here no longer matches its upstream commit, so the next
update from source will conflict on the patched section rather than applying
cleanly. Record every patch below; without the list, a future update either
silently discards the change or stalls on a diff nobody can explain.

| Skill | Patched | Change | Re-apply after upstream update? |
|---|---|---|---|
| `task-observer` | 2026-08-10 | "Name the destination before writing the fix" under *Acting on Observations*, plus its Quick Reference row. From observation #134: corrections gravitate to whichever file is open, which is how an always-loaded instruction file grows without anyone deciding it should. | Yes, unless upstream has adopted an equivalent rule. CC BY 4.0 permits the adaptation; the attribution above stays. |
| `improve-codebase-architecture` | 2026-08-11 | Four path/tooling substitutions, no methodology change. `CONTEXT.md` → `docs/vision/glossary.md` + `CLAUDE.md`'s canonical-vocabulary table; `docs/adr/` → `decisions/`; temp-file-plus-`xdg-open` → publish as an Artifact with inlined CSS (Kafoo sessions are headless, and the Artifact host's content-security policy blocks the Tailwind and Mermaid CDNs the upstream scaffold loads); the two skills it calls that are not installed here (`/grilling`, `/domain-modeling`) replaced with the equivalent Kafoo procedure. | Yes — every one of them is Kafoo-specific and upstream will never adopt them. A future update must be re-patched, not taken clean. |

Kafoo-specific configuration is deliberately kept **out** of vendored skill
bodies and in a separate reference file the skill points at — see
`opencode-delegate/references/kafoo-account.md`. Prefer that shape over
patching a vendored body whenever the content is project-specific; patch the
body only for a change that is general enough to send upstream.

## What was trimmed

- **Task Observer**: two ~1.5 MB PNG banners omitted; `SKILL.md` + `references/` only.
- **UI UX Pro Max**: the named skill only. Its sibling skills in the upstream repo
  (`ui-styling` ~5.9 MB, `design`, `design-system`, `brand`, `slides`, `banner-design`) were
  not installed — add them from the source repo if wanted.
- Upstream skill names are preserved because Superpowers skills cross-reference each other by
  name; renaming them breaks those references.
- **mattpocock/skills**: two skills of ~30. `improve-codebase-architecture` is the one that was
  asked for; `codebase-design` is its hard dependency — it supplies the vocabulary (module,
  interface, depth, seam, adapter, leverage, locality) the review is written in, and without it
  the review drifts into "component" and "service". Nothing else from that repository is
  installed, and two of the skills the installed pair reference are deliberately absent:
  `/domain-modeling`, because it would create a root `CONTEXT.md` duplicating
  `docs/vision/glossary.md` and `CLAUDE.md` — one name per concept, in one file — and
  `/grilling`, because **it is referenced by the upstream skill but not published in the
  upstream repository**. Both are handled by the local patch above rather than by a stub.
  The rest of the set overlaps heavily with `speckit-*` and the Superpowers skills already
  here; add one with `npx skills add mattpocock/skills --skill <name>` if a gap appears.

### delegate-skills: 5 of 7 variants omitted

The upstream package ships seven delegate skills, one per implementer CLI. Only
`opencode-delegate` and `claude-delegate` are installed — the CLIs the other five drive
(`codex`, `grok`, `kimi`, `qodercli`, `agy`) are not available on this account, and each unused
skill still costs context in every session. Add one with:

```bash
npx skills add amElnagdy/delegate-skills --skill codex-delegate
```

Model policy for `opencode-delegate` (flat-rate `opencode-go/` namespace only) lives in
`.claude/skills/opencode-delegate/references/kafoo-account.md`; `CLAUDE.md` carries only the
mandate and the current suspension.

Independent review of `scripts/relay.mjs` (both copies): no network calls, no third-party
dependencies (Node built-ins only), no credential reads; it spawns `opencode`/`claude`, `git`,
and `taskkill` (Windows cleanup), and writes artifacts to a temp directory. It passes the
parent environment through to the child process, so do not delegate in a tree holding a real
`.env`.

## Not installed: Mem

`claude-mem` ([thedotmack/claude-mem](https://github.com/thedotmack/claude-mem), commit
`132b463`) is not a markdown skill folder — it is an npm package (`bin: claude-mem`) with
session hooks and a local database. Its skills (`mem-search`, `cloud-sync`, `timeline-report`,
…) shell out to that binary, so copying the markdown alone would install skills that instruct
Claude to run a command that does not exist.

To install it on a persistent machine:

```bash
/plugin marketplace add thedotmack/claude-mem
/plugin install claude-mem
```

## caveman and ponytail: the skills are the smaller half

These two are the only vendored entries that are **not** markdown alone. Both are driven by Node
hooks, and a skill folder copied without them is inert — it loads a page telling Claude the hook
will do the work, the hook is absent, and the command silently does nothing.

That is not hypothetical. Six caveman skills arrived on this account through claude.ai skill sync,
which carries skill markdown and cannot carry hook scripts or edit `settings.json`. `/caveman-stats`
therefore matched a skill, loaded a page reading *"the model does not need to do anything"*, and
returned nothing at all — twice, before anyone looked. **A skill that documents a hook it does not
ship fails silently and reads as the assistant ignoring you.** It is the same failure the "Not
installed: Mem" note below was written to avoid.

So the hooks are vendored too, into `.claude/hooks/`:

| Files | Event | Does |
|---|---|---|
| `caveman-activate.js` | `SessionStart` | resolves the mode, injects the ruleset when active |
| `caveman-mode-tracker.js` | `UserPromptSubmit` | handles `/caveman …`, and runs `caveman-stats.js` on `/caveman-stats` |
| `caveman-stats.js`, `caveman-config.js`, `caveman-parse.js`, `cavecrew-model-overrides.js` | — | libraries required by the two above |
| `ponytail-activate.js` | `SessionStart` | injects the ruleset |
| `ponytail-mode-tracker.js` | `UserPromptSubmit` | handles `/ponytail …` |
| `ponytail-subagent.js` | `SubagentStart` | injects into spawned agents, scoped (below) |
| `ponytail-config.js`, `ponytail-instructions.js`, `ponytail-runtime.js` | — | libraries |

**They sit flat in `.claude/hooks/`, not in a subdirectory, and that is load-bearing.**
`caveman-activate.js` resolves the skill body at `../skills/caveman/SKILL.md` relative to its own
location, which only lands on `.claude/skills/` from `.claude/hooks/`. This mirrors upstream's own
non-plugin layout (`$CLAUDE_CONFIG_DIR/hooks/` beside `$CLAUDE_CONFIG_DIR/skills/`). Moving them
tidily into `hooks/vendor/` breaks skill resolution — the alternative was patching vendored code,
which costs more at every future update than the untidiness is worth.

Integrity: `caveman.checksums.sha256` is upstream's own manifest, and all nine files verified
against it at install. Re-check after any update with `sha256sum -c`. Both hook sets use Node
built-ins only — no `node_modules`, no network calls, no credential reads.

### Why they are installed at different intensities

**caveman is `off`** (`.caveman/config.json`). It compresses the assistant's prose, and `CLAUDE.md`
opens with a deliberate contract for a reader who does not read code and needs decisions first with
jargon spelled out. Caveman's `full` default contradicts that directly. Everything still works on
demand — `/caveman lite`, `/caveman-stats`, `/caveman-commit`, `/caveman-review`. Reasoning and the
one-line change to make it permanent: `.caveman/README.md`.

**ponytail is `lite`** (`PONYTAIL_DEFAULT_MODE` in `.claude/settings.json`). It shapes generated
*code*, not prose, so it does not collide with that contract, and its anti-over-engineering push
matches Simplicity at position 2 in `CLAUDE.md`'s priority order. `lite` rather than `full` because
this repository's non-negotiables — RLS in the same migration, a negative test seen to fail, ARB
entries in both locales — are all work that a strong "write less" prior can argue against.

`PONYTAIL_SUBAGENT_MATCHER` is set for the same reason. Unset, ponytail injects into **every**
subagent, and this repository has seven review agents whose whole job is to object. Instructing
`rls-reviewer` or `trust-reviewer` to do less is precisely backwards, so the matcher is an
allowlist covering implementation agents only. Verified at install: `rls-reviewer` receives
nothing, `general-purpose` receives the ruleset.

### Optional: the statusline badge

Not wired, deliberately — `statusLine` in project settings overrides the user's own status bar,
which is cosmetic and intrusive to take over uninvited. To opt in, add to `.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/caveman-statusline.sh" }
```

## Updating

Re-clone the source at a newer commit and re-copy the skill directory, then update the commit
hash in the table above. For caveman and ponytail, re-copy the hook files too and re-verify the
checksums — a skill folder updated without its hooks is the silent-failure case above.
