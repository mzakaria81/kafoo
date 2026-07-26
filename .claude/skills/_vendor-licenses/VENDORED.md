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

License texts are alongside this file. CC BY 4.0 requires attribution — keep
`task-observer.LICENSE` and the credit above with any redistribution.

## What was trimmed

- **Task Observer**: two ~1.5 MB PNG banners omitted; `SKILL.md` + `references/` only.
- **UI UX Pro Max**: the named skill only. Its sibling skills in the upstream repo
  (`ui-styling` ~5.9 MB, `design`, `design-system`, `brand`, `slides`, `banner-design`) were
  not installed — add them from the source repo if wanted.
- Upstream skill names are preserved because Superpowers skills cross-reference each other by
  name; renaming them breaks those references.

### delegate-skills: 5 of 7 variants omitted

The upstream package ships seven delegate skills, one per implementer CLI. Only
`opencode-delegate` and `claude-delegate` are installed — the CLIs the other five drive
(`codex`, `grok`, `kimi`, `qodercli`, `agy`) are not available on this account, and each unused
skill still costs context in every session. Add one with:

```bash
npx skills add amElnagdy/delegate-skills --skill codex-delegate
```

Model policy for `opencode-delegate` (flat-rate `opencode-go/` namespace only) lives in the
"Delegating implementation work" section of `CLAUDE.md`.

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

## Updating

Re-clone the source at a newer commit and re-copy the skill directory, then update the commit
hash in the table above.
