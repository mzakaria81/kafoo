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

# This file and settings.json decide what needs permission, so editing them
# prompts. That gate only covers the Edit tool; with Bash fully open, a redirect
# rewrites the same file and never reaches it. Both routes end here instead.
GUARDED = r"['\"]?[^\s'\"|;&]*\.claude/(?:hooks/|settings(?:\.local)?\.json)"
SEG = r"[^|;&\n]*"
SELF_WRITE = re.compile(
    rf">>?\s*{GUARDED}"
    rf"|\b(?:tee|cp|mv|install|ln|truncate|dd|chmod|chown|rm)\b{SEG}{GUARDED}"
    rf"|\bsed\b{SEG}\s-\w*i\w*\b{SEG}{GUARDED}"
    rf"|\b(?:python3?|node|deno|perl|ruby|bash|sh|zsh)\b{SEG}\s-\w*[ce]\b{SEG}{GUARDED}"
)


def strip_prose(command, keep_quotes=False):
    """Drop text that cannot name a file: heredoc bodies, and usually quotes."""
    out = HEREDOC.sub(" ", command)
    return out if keep_quotes else QUOTED.sub(" ", out)


def verdict(command):
    """Return a block reason, or None to let the command through."""
    # Quotes stay for the self-write check: a path is still a path inside them,
    # and an inline interpreter script is nothing but quoted text.
    if SELF_WRITE.search(strip_prose(command, keep_quotes=True)):
        return ("Rewriting the permission guard or settings from the shell is a hard "
                "block — use the Edit tool, which prompts.")
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
        # Shell routes around the Edit-tool prompt on the guard and settings.
        "cat > .claude/hooks/guard-hard-blocks.py",
        "echo '{}' >> .claude/settings.json",
        "cat x > /home/user/kafoo/.claude/settings.local.json",
        "sed -i s/deny/allow/ .claude/settings.json",
        "cp /tmp/x .claude/hooks/guard-hard-blocks.py",
        "rm .claude/hooks/guard-hard-blocks.py",
        "mv /tmp/x .claude/settings.json",
        "tee .claude/settings.json < /tmp/x",
        "python3 -c \"open('.claude/settings.json','w').write('{}')\"",
        "node -e \"require('fs').writeFileSync('.claude/hooks/x.js','')\"",
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
        # Reading, running and staging the guarded files stays open.
        "python3 .claude/hooks/guard-hard-blocks.py --self-test",
        "git add .claude/settings.json .claude/hooks/guard-hard-blocks.py",
        "git diff .claude/settings.json",
        "git commit -F - <<'EOF'\nHarden .claude/hooks/guard-hard-blocks.py\nEOF",
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
