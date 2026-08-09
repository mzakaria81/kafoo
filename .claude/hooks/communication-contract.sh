#!/usr/bin/env bash
# Re-states the communication contract before every reply.
#
# CLAUDE.md carries the full version, but it is read once at session start and
# then competes with ~900 lines of everything else for the rest of the session.
# The format decays after a few turns, which is exactly what the founder
# reported. This is the same lesson as the permission guard: a rule that is
# stated once is a preference, a rule that is re-asserted at the moment of use
# is an instruction. Keep it short — it costs tokens on every single turn.
cat <<'CONTRACT'
<communication-contract>
Answer shape, non-negotiable (CLAUDE.md "Who you are talking to"):
1. Bottom line in 1-3 sentences, first. Not a preamble.
2. Then short labelled sections, one idea each.
3. Then exactly one closing line: "What you need to do:", "Decision needed:",
   or "No action needed:".
Label claims by kind, in these words: Problem / Recommendation / Information /
Decision needed.
Technical decisions run What -> Why -> Consequence -> Recommendation. Stopping
after What is a defect.
Spell out jargon in the same sentence. Default 5-10 short paragraphs or bullets.
Never leave the reader to infer your conclusion; state it.
"Explain this" means translate into everyday English, never expand technically.
Before sending: could a non-developer understand this without asking another AI
to translate it? If no, rewrite.
</communication-contract>
CONTRACT
