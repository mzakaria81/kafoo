#!/usr/bin/env python3
"""PreToolUse guard for the four blocks that must not be bypassable.

`permissions.deny` matches a command's leading text, so `rm -rf` is stopped and
`rm -f -r` is not. That is fine for a speed bump and useless for a hard block.
Everything else in this repo is deliberately wide open; these four are the
exceptions, so they are matched on meaning instead of on spelling.

Blocks: reading or writing .env, recursive rm, force-push to main, and any
command that reaches the live Supabase or Cloudflare project.

Self-test: python3 .claude/hooks/guard-hard-blocks.py --self-test
"""
import json
import re
import sys

# .env in any directory, but .env.example is the documented template to copy.
ENV = re.compile(r"(^|[\s'\"=/])\.env(?!\.example)\b")
# -r/-R/--recursive in any position or flag grouping: -rf, -f -r, -fr, --recursive
RM_RECURSIVE = re.compile(r"\brm\b(?=[^|;&]*\s-(?:-recursive\b|[a-z]*[rR]))")
FIND_DELETE = re.compile(r"\bfind\b[^|;&]*\s-(?:delete\b|exec(?:dir)?\b[^|;&]*\brm\b)")
FORCE_PUSH = re.compile(r"\bgit\s+push\b[^|;&]*(?:\s--force\S*|\s-f\b|\s\+[\w./-]+:)")
MAIN_REF = re.compile(r"(?:^|[\s:/])(?:main|master)(?:\s|$|:)")
LIVE_PROJECT = re.compile(
    r"\bsupabase\s+(?:link|db\s+push)\b"
    r"|\bsupabase\b[^|;&]*--(?:linked|project-ref)\b"
    r"|\bwrangler\s+(?:deploy|publish)\b"
)

RULES = [
    (ENV, "Reading or writing .env is a hard block. Copy .env.example instead."),
    (RM_RECURSIVE, "Recursive rm is a hard block, in every flag spelling."),
    (FIND_DELETE, "find -delete / -exec rm is recursive deletion by another name."),
    (LIVE_PROJECT, "This reaches the live Supabase or Cloudflare project. Hard block."),
]

# Prose is not a file access. A commit message that says ".env" and a command
# that reads .env are the same characters, so drop the text that cannot name a
# target before matching: heredoc bodies, then quoted spans. Blocking prose
# instead is not a harmless over-reach — it made this very hook unable to commit
# the message describing itself.
HEREDOC = re.compile(r"<<-?\s*(['\"]?)(\w+)\1.*?^\2$", re.S | re.M)
QUOTED = re.compile(r"'[^']*'|\"[^\"]*\"")


def strip_prose(command):
    return QUOTED.sub(" ", HEREDOC.sub(" ", command))


def verdict(command):
    """Return a block reason, or None to let the command through."""
    command = strip_prose(command)
    for pattern, reason in RULES:
        if pattern.search(command):
            return reason
    if FORCE_PUSH.search(command) and MAIN_REF.search(command):
        return "Force-pushing main is a hard block. Feature branches will prompt instead."
    return None


def self_test():
    blocked = [
        "cat .env", "cat ./.env", "cat /home/user/kafoo/.env", "head -5 .env.local",
        "xxd .env", "grep -r KEY .env", "echo x > .env",
        "rm -rf build", "rm -f -r build", "rm -fr build", "rm --recursive build",
        "rm -Rf build", "ls && rm -rf /tmp/x",
        "find . -name '*.tmp' -delete", "find . -exec rm {} \\;",
        "git push --force origin main", "git push --force-with-lease origin main",
        "git push -f origin main", "git push origin +main:main",
        "supabase link --project-ref abc", "supabase db push --linked",
        "supabase functions deploy discover --project-ref abc", "wrangler deploy",
    ]
    allowed = [
        "cp .env.example .env.example.bak", "cat .env.example",
        "rm build/app.apk", "rm -f pubspec.lock",
        "git push -u origin feat/x", "git push --force-with-lease origin feat/x",
        "supabase start", "supabase db reset", "supabase migration new add_meal",
        "./scripts/verify.sh", "git commit -m 'x'", "flutter test",
        "grep -rn environment lib/",
        # Prose that names a blocked thing without doing it.
        "git commit -m 'never read .env or run rm -rf'",
        "git commit -F - <<'EOF'\nDocument why .env is blocked\nand rm -rf too\nEOF",
        "echo 'copy .env.example to .env by hand'",
    ]
    bad = [c for c in blocked if not verdict(c)] + [c for c in allowed if verdict(c)]
    for c in bad:
        print(f"FAIL: {c!r} -> {verdict(c)}", file=sys.stderr)
    print("FAIL" if bad else f"ok ({len(blocked)} blocked, {len(allowed)} allowed)")
    return 1 if bad else 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    payload = json.load(sys.stdin)
    reason = verdict(payload.get("tool_input", {}).get("command", ""))
    if reason:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }}))
    sys.exit(0)
