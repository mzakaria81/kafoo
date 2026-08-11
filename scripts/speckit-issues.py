#!/usr/bin/env python3
"""Backfill the Kafoo task hierarchy into GitHub issues.

Three levels, mirroring how the work was actually organised:

    epic -> task                    for tasks that predate coordination/
    epic -> work package -> task    for tasks a WP-###.json claims

Idempotent. Every created issue is recorded in the state file before the next
call, so a re-run after a rate-limit stall or a container teardown resumes
instead of duplicating. Nothing is created twice.

Usage:
    python3 scripts/speckit-issues.py --dry-run
    python3 scripts/speckit-issues.py --apply
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import hashlib
import re
import sys
import time
import urllib.error
import urllib.request

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
STATE_PATH = REPO_ROOT / ".claude" / "speckit-issue-map.json"
API = "https://api.github.com"
# GitHub does not resolve repo-relative links inside issue bodies the way it does
# in a README, so every link here is absolute against the default branch.
BLOB = "https://github.com/mzakaria81/kafoo/blob/main"

# 001-004 are E0-E3. The number in the directory name is not the epic number.
EPICS = [
    ("E0", "001-e0-foundation", "Foundation"),
    ("E1", "002-identity-kitchen-profile", "Identity and Kitchen Profile"),
    ("E2", "003-meal-publishing", "Meal Publishing"),
    ("E3", "004-customer-discovery", "Customer Discovery"),
]

LABELS = {
    "epic": ("6f42c1", "An epic. Its sub-issues are work packages or tasks."),
    "work-package": ("0e8a16", "A coordination/packages/WP-###.json unit of work."),
    "task": ("1d76db", "A T### task from a specs/*/tasks.md."),
    "E0": ("ededed", "Epic E0 — Foundation"),
    "E1": ("ededed", "Epic E1 — Identity and Kitchen Profile"),
    "E2": ("ededed", "Epic E2 — Meal Publishing"),
    "E3": ("ededed", "Epic E3 — Customer Discovery"),
}

TASK_RE = re.compile(r"^- \[([ x])\] (T\d{3})\s+(.*)$")
MARKER_RE = re.compile(r"^(?:\[(P)\]\s*)?(?:\[(US\d)\]\s*)?(.*)$", re.S)
TITLE_MAX = 180


# --------------------------------------------------------------------------- parse


def parse_tasks(epic_key: str, spec_dir: str) -> list[dict]:
    """Pull every task out of a tasks.md, with its phase, section and prose."""
    path = REPO_ROOT / "specs" / spec_dir / "tasks.md"
    lines = path.read_text(encoding="utf-8").splitlines()
    tasks: list[dict] = []
    phase = section = None
    current: dict | None = None

    for line in lines:
        if line.startswith("## "):
            phase, section, current = line[3:].strip(), None, None
            continue
        if line.startswith("### "):
            section, current = line[4:].strip(), None
            continue
        if line.strip() == "---":
            current = None
            continue

        m = TASK_RE.match(line)
        if m:
            checked, task_id, rest = m.groups()
            parallel, story, desc = MARKER_RE.match(rest).groups()
            current = {
                "id": task_id,
                "epic": epic_key,
                "spec_dir": spec_dir,
                "done": checked == "x",
                "parallel": parallel == "P",
                "story": story,
                "description": desc.strip(),
                "phase": phase,
                "section": section,
                "extra": [],
            }
            tasks.append(current)
            continue

        # Anything after a task line and before the next task/header belongs to it.
        if current is not None:
            current["extra"].append(line)

    for t in tasks:
        while t["extra"] and not t["extra"][-1].strip():
            t["extra"].pop()
    return tasks


def parse_packages() -> dict:
    """Load every WP-###.json."""
    packages: dict[str, dict] = {}
    for p in sorted((REPO_ROOT / "coordination" / "packages").glob("WP-*.json")):
        wp = json.loads(p.read_text(encoding="utf-8"))
        packages[wp["id"]] = wp
    return packages


def qualify(epic_key: str, task_id: str) -> str:
    """A T### is only unique within its epic.

    E0, E1 and E2 each restart their numbering at T001, so `T045` names an E0
    task and an E1 task and an E2 task. Every key, title and parent lookup here
    is epic-qualified for that reason: keying on the bare id makes E1's T001
    resolve to E0's issue, and GitHub then rejects the second parent with a 422.
    """
    return f"{epic_key}/{task_id}"


def resolve_wp_epics(packages: dict, tasks_by_epic: dict[str, set]) -> dict[str, str]:
    """Which epic each package belongs to: the one holding most of its task ids.

    Derived independently of who claims a task. A package whose every task was
    already claimed by a lower-numbered package still belongs to its epic, and
    inferring the epic from the claim map instead would file it under a default.

    A package can also have NO tasks — WP-021 was created in place of an analytics
    epic and carries acceptance criteria only. Its epic comes from what it depends
    on, which is a stated fact about the package rather than a guess. If that
    cannot be resolved either, it is left absent and the caller reports it: a
    default here would file a real package under whichever epic was hardcoded and
    look entirely plausible doing it.
    """
    wp_epic: dict[str, str] = {}
    for wp_id in sorted(packages):
        ids = set(packages[wp_id].get("tasks", []))
        if ids:
            wp_epic[wp_id] = max(tasks_by_epic, key=lambda e: len(ids & tasks_by_epic[e]))

    # Second pass, so a task-less package can inherit from a dependency resolved above.
    for _ in range(len(packages)):
        changed = False
        for wp_id in sorted(packages):
            if wp_id in wp_epic:
                continue
            for dep in packages[wp_id].get("dependencies") or []:
                if dep in wp_epic:
                    wp_epic[wp_id] = wp_epic[dep]
                    changed = True
                    break
        if not changed:
            break
    return wp_epic


def resolve_owners(
    packages: dict, tasks_by_epic: dict[str, set], wp_epic: dict[str, str]
) -> dict[str, str]:
    """Map an epic-qualified task id to the package that claims it."""
    owner: dict[str, str] = {}
    for wp_id in sorted(packages):
        epic_key = wp_epic.get(wp_id)
        if not epic_key:
            continue
        for task_id in packages[wp_id].get("tasks", []):
            if task_id in tasks_by_epic[epic_key]:
                # A sub-issue has exactly one parent, so the first claimant wins
                # and any later one is recorded in both bodies rather than dropped.
                owner.setdefault(qualify(epic_key, task_id), wp_id)
    return owner


def merge_duplicate_ids(tasks: list[dict]) -> tuple[list[dict], dict[str, int]]:
    """Fold a task id recorded more than once in one tasks.md into one entry.

    E2 records T094 and T095 twice — once in their phase and once in a trailing
    section — with the same status and the same "folded into T088" text. They are
    one task written down twice, so they become one issue carrying both blocks.
    Two issues cannot share an id: the key would collide and the second link
    would be refused as a second parent.
    """
    merged: dict[str, dict] = {}
    counts: dict[str, int] = {}
    for t in tasks:
        counts[t["id"]] = counts.get(t["id"], 0) + 1
        first = merged.get(t["id"])
        if first is None:
            merged[t["id"]] = t
            continue
        first["duplicates"] = first.get("duplicates", [])
        first["duplicates"].append(t)
        first["done"] = first["done"] or t["done"]
    return list(merged.values()), {i: n for i, n in counts.items() if n > 1}


# --------------------------------------------------------------------------- bodies


def strip_md(text: str) -> str:
    text = re.sub(r"[`*_]", "", text)
    return re.sub(r"\s+", " ", text).strip()


def title_for(prefix: str, description: str) -> str:
    flat = strip_md(description)
    if len(flat) > TITLE_MAX:
        flat = flat[: TITLE_MAX - 1].rstrip() + "…"
    return f"{prefix}: {flat}"


def epic_body(key: str, spec_dir: str, name: str, tasks: list[dict], wp_ids: list[str]) -> str:
    done = sum(1 for t in tasks if t["done"])
    base = f"specs/{spec_dir}"
    out = [
        f"# {key} — {name}",
        "",
        f"**Spec**: [`{base}/spec.md`]({BLOB}/{base}/spec.md) · "
        f"[`plan.md`]({BLOB}/{base}/plan.md) · [`tasks.md`]({BLOB}/{base}/tasks.md) · "
        f"[`quickstart.md`]({BLOB}/{base}/quickstart.md)",
        "",
        f"**Tasks**: {len(tasks)} total, {done} complete, {len(tasks) - done} outstanding.",
        "",
    ]
    if wp_ids:
        out += [
            "## Work packages",
            "",
            "Work arrives as a package, not as a task — see "
            f"[`coordination/README.md`]({BLOB}/coordination/README.md). "
            f"{len(wp_ids)} package(s) sit under this epic as sub-issues, "
            "each holding the tasks it delivers:",
            "",
            "",
        ]
        out[-1] = ", ".join(f"`{w}`" for w in wp_ids)
        out.append("")
    unpackaged = [t for t in tasks if qualify(key, t["id"]) not in PARSED_OWNER]
    if unpackaged:
        out += [
            "## Tasks without a work package",
            "",
            f"{len(unpackaged)} task(s) predate `coordination/` and hang directly off this "
            "epic. That is a record of when packages were adopted, not an omission.",
            "",
        ]
    out += [
        "---",
        "",
        "`tasks.md` remains the reasoning; these issues are the tracking surface. "
        "Only the coordinator edits planning state, and only after pulling `main`.",
    ]
    return "\n".join(out)


def package_body(wp: dict, epic_key: str, also_claims: list[str]) -> str:
    out = [
        f"**Epic**: {epic_key} · **Status**: `{wp['status']}` · "
        f"**Execution**: `{wp['execution_mode']}` · **Priority**: {wp.get('priority')}",
        "",
        f"## Objective\n\n{wp['objective']}",
        "",
        "## Acceptance criteria",
        "",
    ]
    out += [f"- {c}" for c in wp.get("acceptance_criteria", [])]
    out += ["", f"## Tasks\n\n{', '.join('`' + t + '`' for t in wp.get('tasks', []))}"]
    out.append("")

    deps = wp.get("dependencies") or []
    out.append(f"**Dependencies**: {', '.join('`' + d + '`' for d in deps) if deps else 'none'}")
    owner = wp.get("owner")
    out.append(f"**Owner**: {'`' + owner + '`' if owner else '_unowned_'}")
    if wp.get("branch"):
        out.append(f"**Branch**: `{wp['branch']}`")
    pr = wp.get("pr")
    if pr:
        out.append(f"**PR**: {pr}" if str(pr).startswith("http") else f"**PR**: #{pr}")
    if wp.get("blocked_reason"):
        out.append(f"**Blocked**: {wp['blocked_reason']}")
    out.append(
        f"**Spend envelope**: ${wp.get('spend_envelope_usd')} · "
        f"**Suggested model**: `{wp.get('suggested_model')}`"
    )
    out.append("")

    scope = wp.get("scope", {})
    if scope.get("files"):
        out += ["## Scope", ""] + [f"- `{f}`" for f in scope["files"]]
        out.append("")
    if scope.get("shared_files"):
        out += [
            "**Shared with other packages** — the coordinator serialises these:",
            "",
        ] + [f"- `{f}`" for f in scope["shared_files"]]
        out.append("")

    if also_claims:
        out += [
            f"> **Note**: {', '.join('`' + t + '`' for t in also_claims)} is also listed in "
            "another package. A GitHub sub-issue has exactly one parent, so the task issue is "
            "nested under whichever package claimed it first; this is recorded rather than "
            "silently resolved.",
            "",
        ]

    if wp.get("notes"):
        out += ["## Notes", "", wp["notes"], ""]

    out += [
        "---",
        "",
        f"Source of truth: [`coordination/packages/{wp['id']}.json`]"
        f"({BLOB}/coordination/packages/{wp['id']}.json). "
        "State lives in the JSON; this issue mirrors it.",
    ]
    return "\n".join(out)


def task_body(t: dict, wp_id: str | None, extra_wps: list[str]) -> str:
    base = f"specs/{t['spec_dir']}"
    meta = [f"**Epic**: {t['epic']}"]
    if wp_id:
        meta.append(f"**Work package**: `{wp_id}`")
    if t["story"]:
        meta.append(f"**Story**: {t['story']}")
    if t["parallel"]:
        meta.append("**Parallel-safe**: `[P]`")
    meta.append(f"**State in `tasks.md`**: {'complete' if t['done'] else 'outstanding'}")

    out = [" · ".join(meta), ""]
    if t.get("phase"):
        out += [f"**Phase**: {t['phase']}"]
    if t.get("section"):
        out += [f"**Section**: {t['section']}"]
    out += ["", "## Task", "", f"{t['id']} {t['description']}"]

    if t["extra"]:
        out += ["", "\n".join(t["extra"]).rstrip()]

    for i, dup in enumerate(t.get("duplicates", []), start=1):
        out += [
            "",
            f"> **This task id is recorded {i + 1} times in `tasks.md`.** The other entry is "
            f"reproduced below rather than given its own issue, since two issues cannot share "
            f"one id. Reconciling the file is a planning edit and is not done here.",
            "",
            f"**Also recorded under** _{dup.get('phase') or 'no phase'}_:",
            "",
            f"{dup['id']} {dup['description']}",
        ]
        if dup["extra"]:
            out += ["", "\n".join(dup["extra"]).rstrip()]

    if extra_wps:
        out += [
            "",
            f"> **Also claimed by** {', '.join('`' + w + '`' for w in extra_wps)}. A sub-issue "
            "has one parent, so this issue is nested under the first claimant.",
        ]

    out += [
        "",
        "---",
        "",
        f"Source: [`{base}/tasks.md`]({BLOB}/{base}/tasks.md) — the prose there is the reasoning and "
        "stays authoritative.",
    ]
    return "\n".join(out)


# --------------------------------------------------------------------------- github


class Gh:
    """Minimal GitHub REST client that respects the secondary rate limit.

    GitHub caps content-creating requests at roughly 500/hour and 80/minute, and
    signals a breach with a 403 plus Retry-After rather than a 429. Start fast,
    slow down permanently whenever it complains, and never give up silently.
    """

    def __init__(self, owner: str, repo: str, token: str, base_sleep: float = 1.0):
        self.owner, self.repo, self.token = owner, repo, token
        self.base_sleep = base_sleep
        self.writes = 0

    def _request(self, method: str, path: str, payload: dict | None = None) -> dict:
        url = f"{API}{path}"
        for attempt in range(8):
            body = json.dumps(payload).encode() if payload is not None else None
            req = urllib.request.Request(url, data=body, method=method)
            req.add_header("Authorization", f"Bearer {self.token}")
            req.add_header("Accept", "application/vnd.github+json")
            req.add_header("X-GitHub-Api-Version", "2022-11-28")
            req.add_header("Content-Type", "application/json")
            try:
                with urllib.request.urlopen(req) as resp:
                    if method != "GET":
                        self.writes += 1
                        time.sleep(self.base_sleep)
                    return json.loads(resp.read() or b"{}")
            except urllib.error.HTTPError as e:
                text = e.read().decode(errors="replace")
                retry_after = e.headers.get("Retry-After")
                secondary = e.code in (403, 429) and (
                    "secondary rate limit" in text.lower() or "abuse" in text.lower()
                )
                if secondary or e.code == 429:
                    wait = int(retry_after) if retry_after else 60 * (attempt + 1)
                    self.base_sleep = min(self.base_sleep + 0.5, 8.0)
                    log(
                        f"  rate limited ({e.code}); sleeping {wait}s, "
                        f"pacing now {self.base_sleep:.1f}s/write"
                    )
                    time.sleep(wait)
                    continue
                if e.code in (500, 502, 503, 504):
                    wait = 2 ** attempt
                    log(f"  {e.code} from GitHub; retrying in {wait}s")
                    time.sleep(wait)
                    continue
                raise RuntimeError(f"{method} {path} -> {e.code}: {text[:400]}") from None
            except urllib.error.URLError as e:
                wait = 2 ** attempt
                log(f"  network error {e}; retrying in {wait}s")
                time.sleep(wait)
        raise RuntimeError(f"{method} {path} failed after retries")

    def ensure_label(self, name: str, color: str, description: str) -> None:
        try:
            self._request("GET", f"/repos/{self.owner}/{self.repo}/labels/{name}")
        except RuntimeError:
            self._request(
                "POST",
                f"/repos/{self.owner}/{self.repo}/labels",
                {"name": name, "color": color, "description": description},
            )

    def create_issue(self, title: str, body: str, labels: list[str]) -> dict:
        return self._request(
            "POST",
            f"/repos/{self.owner}/{self.repo}/issues",
            {"title": title, "body": body, "labels": labels},
        )

    def patch(self, number: int, payload: dict) -> None:
        self._request("PATCH", f"/repos/{self.owner}/{self.repo}/issues/{number}", payload)

    def close_issue(self, number: int, body: str | None = None) -> None:
        # The body carries "State in tasks.md", so a task that has since been ticked needs its
        # body rewritten as well as its state changed. One PATCH does both — closing without
        # refreshing leaves the issue asserting it is outstanding on the line above the closed badge.
        payload = {"state": "closed", "state_reason": "completed"}
        if body is not None:
            payload["body"] = body
        self._request("PATCH", f"/repos/{self.owner}/{self.repo}/issues/{number}", payload)

    def add_sub_issue(self, parent_number: int, child_id: int) -> None:
        self._request(
            "POST",
            f"/repos/{self.owner}/{self.repo}/issues/{parent_number}/sub_issues",
            {"sub_issue_id": child_id},
        )


# --------------------------------------------------------------------------- state


def load_state() -> dict:
    if STATE_PATH.exists():
        state = json.loads(STATE_PATH.read_text(encoding="utf-8"))
        state.setdefault("bodies", {})
        return state
    return {"issues": {}, "links": [], "closed": [], "bodies": {}}


def save_state(state: dict) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def log(msg: str) -> None:
    print(msg, flush=True)


# --------------------------------------------------------------------------- main

PARSED_OWNER: dict[str, str] = {}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="actually create issues")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--owner", default="mzakaria81")
    ap.add_argument("--repo", default="kafoo")
    ap.add_argument("--pace", type=float, default=1.0, help="seconds between writes")
    args = ap.parse_args()
    if not (args.apply or args.dry_run):
        ap.error("pass --apply or --dry-run")

    global PARSED_OWNER
    packages = parse_packages()

    epics: list[dict] = []
    for key, spec_dir, name in EPICS:
        epics.append(
            {"key": key, "spec_dir": spec_dir, "name": name, "tasks": parse_tasks(key, spec_dir)}
        )

    duplicates: dict[str, dict[str, int]] = {}
    all_tasks = []
    for e in epics:
        e["tasks"], dups = merge_duplicate_ids(e["tasks"])
        if dups:
            duplicates[e["key"]] = dups
        all_tasks.extend(e["tasks"])

    tasks_by_epic = {e["key"]: {t["id"] for t in e["tasks"]} for e in epics}
    wp_epic = resolve_wp_epics(packages, tasks_by_epic)
    PARSED_OWNER = resolve_owners(packages, tasks_by_epic, wp_epic)

    # Which package claims a task more than once — recorded, never dropped.
    claims: dict[str, list[str]] = {}
    for wp_id in sorted(packages):
        epic_key = wp_epic.get(wp_id)
        for task_id in packages[wp_id].get("tasks", []):
            if epic_key and task_id in tasks_by_epic[epic_key]:
                claims.setdefault(qualify(epic_key, task_id), []).append(wp_id)

    epic_wps: dict[str, list[str]] = {e["key"]: [] for e in epics}
    unplaced = [w for w in sorted(packages) if w not in wp_epic]
    for wp_id in sorted(packages):
        if wp_id in wp_epic:
            epic_wps[wp_epic[wp_id]].append(wp_id)

    n_close = sum(1 for t in all_tasks if t["done"])
    n_issues = len(epics) + len(packages) + len(all_tasks)
    n_links = len(packages) + len(all_tasks)
    log(
        f"plan: {len(epics)} epics, {len(packages)} work packages, {len(all_tasks)} tasks "
        f"= {n_issues} issues, {n_links} sub-issue links, {n_close} to close"
    )
    for e in epics:
        unp = [t for t in e["tasks"] if qualify(e["key"], t["id"]) not in PARSED_OWNER]
        log(
            f"  {e['key']}: {len(e['tasks'])} tasks "
            f"({sum(1 for t in e['tasks'] if t['done'])} done), "
            f"{len(epic_wps[e['key']])} packages, {len(unp)} tasks direct on the epic"
        )
    dupes = {t: w for t, w in claims.items() if len(w) > 1}
    if dupes:
        log(f"  tasks claimed by more than one package: {dupes}")
    if unplaced:
        log(f"  SKIPPED — no tasks and no resolvable dependency, so no epic: {unplaced}")
    for epic_key, dups in duplicates.items():
        log(f"  {epic_key}: task id recorded more than once in tasks.md, merged into one issue: {dups}")

    if args.dry_run:
        log("dry run — nothing created")
        return 0

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        log("no GITHUB_TOKEN in the environment")
        return 1

    gh = Gh(args.owner, args.repo, token, base_sleep=args.pace)
    state = load_state()
    issues = state["issues"]
    links = set(tuple(x) for x in state["links"])
    closed = set(state["closed"])
    bodies = state["bodies"]

    def snapshot() -> dict:
        return {
            "issues": issues,
            "links": sorted(links),
            "closed": sorted(closed),
            "bodies": bodies,
        }

    def digest(title: str, body: str) -> str:
        return hashlib.sha256((title + "\x00" + body).encode()).hexdigest()

    def ensure_issue(key: str, title: str, body: str, labels: list[str]) -> dict:
        # An epic body carries "39 of 48 complete" and a package body mirrors a
        # status, so both go stale the moment a box is ticked. Creating and never
        # updating leaves an issue asserting a count that is no longer true, which
        # is worse than having no count. The hash is what keeps a no-op run free:
        # only a body that actually changed is written back.
        want = digest(title, body)
        if key in issues:
            if bodies.get(key) != want:
                gh.patch(issues[key]["number"], {"title": title, "body": body})
                bodies[key] = want
                save_state(snapshot())
                log(f"  refreshed #{issues[key]['number']}  {key}")
            return issues[key]
        made = gh.create_issue(title, body, labels)
        issues[key] = {"number": made["number"], "id": made["id"]}
        bodies[key] = want
        save_state(snapshot())
        log(f"  created #{made['number']}  {key}")
        return issues[key]

    def ensure_link(parent_key: str, child_key: str) -> None:
        pair = (parent_key, child_key)
        if pair in links:
            return
        gh.add_sub_issue(issues[parent_key]["number"], issues[child_key]["id"])
        links.add(pair)
        save_state(snapshot())

    def ensure_closed(key: str, body: str | None = None) -> None:
        if key in closed:
            return
        gh.close_issue(issues[key]["number"], body)
        closed.add(key)
        save_state(snapshot())

    log("labels")
    for name, (color, desc) in LABELS.items():
        gh.ensure_label(name, color, desc)

    log("epics")
    for e in epics:
        ensure_issue(
            e["key"],
            f"{e['key']}: {e['name']}",
            epic_body(e["key"], e["spec_dir"], e["name"], e["tasks"], epic_wps[e["key"]]),
            ["epic", e["key"]],
        )

    log("work packages")
    for wp_id in sorted(packages):
        if wp_id not in wp_epic:
            continue
        wp = packages[wp_id]
        epic_key = wp_epic[wp_id]
        extra = [
            t
            for t in wp.get("tasks", [])
            if len(claims.get(qualify(epic_key, t), [])) > 1
        ]
        body = package_body(wp, epic_key, extra)
        ensure_issue(
            wp_id,
            title_for(wp_id, wp["title"]),
            body,
            ["work-package", epic_key],
        )
        ensure_link(epic_key, wp_id)
        # An epic's sub-issues are its packages, so the epic's progress is the count of
        # CLOSED package issues — not of finished tasks inside them. COMPLETED is the
        # coordinator's verdict after the merge, so it is the only status that closes one:
        # a package with every task done but still IN_PROGRESS or READY_FOR_REVIEW is
        # deliberately not finished, and closing it here would overrule the coordinator.
        if wp["status"] == "COMPLETED":
            ensure_closed(wp_id, body)

    log("tasks")
    for t in all_tasks:
        qual = qualify(t["epic"], t["id"])
        wp_id = PARSED_OWNER.get(qual)
        extra_wps = [w for w in claims.get(qual, []) if w != wp_id]
        body = task_body(t, wp_id, extra_wps)
        ensure_issue(
            qual,
            title_for(f"{t['epic']} {t['id']}", t["description"]),
            body,
            ["task", t["epic"]],
        )
        ensure_link(wp_id or t["epic"], qual)
        if t["done"]:
            ensure_closed(qual, body)

    log(f"done — {gh.writes} write requests, {len(issues)} issues, {len(links)} links")
    return 0


if __name__ == "__main__":
    sys.exit(main())
