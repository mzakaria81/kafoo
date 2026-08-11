#!/usr/bin/env python3
"""Stop hook: refuse a reply that does not follow the agreed answer shape.

The sibling UserPromptSubmit hook re-states the contract before every reply.
This one checks the reply actually followed it, because today's lesson twice
over is that a rule nobody verifies decays into decoration.

Only mechanically checkable rules are enforced. "Bottom line first" and "explain
in consequence" are judgement, and a check that guesses at them would fire on
good answers and teach the founder to ignore it. Two things are binary:

  1. Every substantial reply ends with one of the three closing lines.
  2. Every long reply has at least one labelled section.

Short replies are exempt. "Merged." needs no closing line, and a hook that
demanded one would make the contract feel like bureaucracy rather than a
service to the reader.

Self-test: python3 .claude/hooks/check-reply-shape.py --self-test
"""
import json
import re
import sys

# Without trailing punctuation on purpose: these get written as "No action
# needed." and "No action needed from you unless…" as often as with a colon,
# and a check that fails on the full stop teaches nothing except to distrust it.
CLOSERS = ("what you need to do", "decision needed", "no action needed")
LABELS = ("problem:", "recommendation:", "information:", "decision needed:")

# Below this a reply is an acknowledgement, not an answer.
EXEMPT_BELOW = 400
# Above this a reply is long enough that unbroken prose is itself the defect.
NEEDS_SECTIONS_ABOVE = 1500
# The closing line belongs at the end, not buried mid-answer.
TAIL = 600

HEADING = re.compile(r"^#{1,6}\s+\S|^\s*\|", re.M)
BOLD_LABEL = re.compile(r"\*\*[^*]{2,60}?:?\*\*")


def strip_markup(text):
    """Bold and headings wrap the closing line; the words are what matter."""
    return re.sub(r"[*_`#>]", "", text).lower()


def review(reply):
    """Return a rewrite instruction, or None if the reply is acceptable."""
    body = reply.strip()
    if len(body) < EXEMPT_BELOW:
        return None

    flat = strip_markup(body)
    if not any(c in flat[-TAIL:] for c in CLOSERS):
        return ("This reply has no closing line. End it with exactly one of "
                "'What you need to do:', 'Decision needed:' or 'No action needed:' "
                "(the <communication-contract> block injected before this reply). Re-send the reply with it.")

    if len(body) > NEEDS_SECTIONS_ABOVE:
        labelled = HEADING.search(body) or any(
            m.group(0).strip("*").strip().lower().rstrip(":") + ":" in LABELS
            for m in BOLD_LABEL.finditer(body)
        )
        if not labelled:
            return ("This reply is long and has no labelled sections. Break it into "
                    "short sections with headings, or label the claims Problem: / "
                    "Recommendation: / Information: / Decision needed: "
                    "(the <communication-contract> block injected before this reply). Re-send it restructured.")
    return None


def last_assistant_text(path):
    text = ""
    try:
        with open(path) as fh:
            for line in fh:
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                msg = entry.get("message") or {}
                if msg.get("role") != "assistant":
                    continue
                content = msg.get("content")
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    parts = [c.get("text", "") for c in content
                             if isinstance(c, dict) and c.get("type") == "text"]
                    if any(p.strip() for p in parts):
                        text = "\n".join(parts)
    except OSError:
        return ""
    return text


def self_test():
    long_body = "Context sentence. " * 90
    ok = [
        "Merged. CI passed and it is on main now.",
        "Bottom line up front.\n\n## What changed\n" + long_body +
        "\n\n**No action needed.** Only informing you.",
        "Short answer here, roughly five hundred characters of explanation so it "
        "clears the exemption threshold. " + "Filler to pad the body. " * 12 +
        "\n\n**Decision needed:** pick one of the two options above.",
    ]
    bad = [
        # substantial, no closing line
        "Here is a long technical explanation. " + "More detail follows. " * 30,
        # long, closing line present, but one undifferentiated wall of prose
        long_body + "\n\nWhat you need to do: nothing.",
        # closing line buried at the top instead of the end
        "No action needed: fine.\n\n## Detail\n" + "Then a great deal more text. " * 40,
    ]
    fails = [r for r in ok if review(r)] + [r for r in bad if not review(r)]
    for f in fails:
        print(f"FAIL on: {f[:70]!r} -> {review(f)}", file=sys.stderr)
    print("FAIL" if fails else f"ok ({len(ok)} accepted, {len(bad)} rejected)")
    return 1 if fails else 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    payload = json.load(sys.stdin)
    # Set once this hook has already blocked. Without it, a reply the check
    # cannot satisfy would loop forever.
    if payload.get("stop_hook_active"):
        sys.exit(0)
    problem = review(last_assistant_text(payload.get("transcript_path", "")))
    if problem:
        print(json.dumps({"decision": "block", "reason": problem}))
    sys.exit(0)
