# Cross-cutting principles

Generalisable takeaways promoted from the observation log by the `task-observer` weekly
review. These apply across skills rather than to any single one.

Kafoo's binding project principles live in `.specify/memory/constitution.md` and take
precedence over anything recorded here. Nothing in this file may contradict the constitution;
if an observation appears to, amend the constitution through its documented procedure instead.

---

## Active principles

### 1. Name the destination before writing a rule down

**Added:** 2026-08-10
**Applies to:** all skills
**Propagation:** opportunistic — apply at each skill's next update, not as a sweep now
**Status:** active
**Source:** observation #134

**Requirement:** Any skill that tells the agent to *record* something — a rule, a
correction, a convention, a lesson — must make the agent name the destination and justify
it, rather than leaving the choice to whatever file happens to be open. Where a project has
both an always-loaded instruction file and on-demand skills or path-scoped rules, reserve
the always-loaded one for what every session genuinely needs, and prefer a hook, test or
check over prose wherever the rule is binary.

**Why it generalises:** documentation gravitates to whichever file the author was looking at
when the lesson was learned, not to the file that owns the rule. The cost is invisible per
edit and compounds, because each individual addition is correct — so nothing signals the
growth until someone audits the total. A project instruction file audited on 2026-08-09 had
reached 631 lines, 36% of it a procedure that was suspended at the time and already covered
by an installed skill.

**Checking it:** during any skill creation or regeneration, find every instruction that
tells the agent to write something down and confirm each one says *where*. An instruction
that does not name a destination invites the next session to guess, and it will guess "the
file I already have open".
