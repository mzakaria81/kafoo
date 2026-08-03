# Why caveman is `off` by default here

`config.json` sets `defaultMode: "off"`, which is deliberate and is the one setting in this
directory worth understanding before you change it.

Caveman compresses **the assistant's prose to the reader**. Upstream's default is `full`. This
repository's `CLAUDE.md` opens with an explicit, non-default communication contract: the reader is
the founder and a company director who does not read Dart, SQL or shell, and who needs decisions
first, consequences rather than mechanism, and jargon spelled out on first use.

Those two instructions cannot both be followed. `full` mode would answer "does this leak a
Customer's address?" with something like *"RLS good. no leak."* — accurate, and useless to the
person who has to decide whether to ship it.

So the machinery is installed and wired, and the mode is off. Nothing is lost: every command still
works on demand, and any of them can be run for a single answer without changing the default.

```
/caveman lite        # turn it on for this session only
/caveman off         # back off again
/caveman-stats       # real token counts — unaffected by the mode
/caveman-commit      # compressed commit message
/caveman-review      # compressed review comments
```

**To make it permanent instead**, change the one value here to `lite`, `full` or `ultra` and commit.
`lite` is the one to try first — it trims filler without dropping into telegraphic prose.

Precedence, highest first: `CAVEMAN_DEFAULT_MODE` in the environment → this file → the user-level
config → upstream's `full`. So this file is what makes the default reproducible for anyone who
clones the repository, which matters here because Kafoo development runs in containers that are
destroyed after each session.

The sibling tool, ponytail, is configured separately in `.claude/settings.json` and is **on** at
`lite` — it shapes generated *code* rather than prose, so it does not collide with the
communication contract. See `.claude/skills/_vendor-licenses/VENDORED.md`.
