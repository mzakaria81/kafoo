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


def parse_packages() -> tuple[dict, dict]:
    """Load every WP-###.json, and map each task id to its owning package."""
    packages: dict[str, dict] = {}
    owner: dict[str, str] = {}
    for p in sorted((REPO_ROOT / "coordination" / "packages").glob("WP-*.json")):
        wp = json.loads(p.read_text(encoding="utf-8"))
        packages[wp["id"]] = wp
        for task_id in wp.get("tasks", []):
            # A sub-issue has exactly one parent, so the first claimant wins and
            # the later one is recorded in both bodies rather than dropped.
            owner.setdefault(task_id, wp["id"])
    return packages, owner


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
    unpackaged = [t for t in tasks if t["id"] not in PARSED_OWNER]
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
    if wp.get("pr"):
        out.append(f"**PR**: #{wp['pr']}")
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

    def close_issue(self, number: int) -> None:
        self._request(
            "PATCH",
            f"/repos/{self.owner}/{self.repo}/issues/{number}",
            {"state": "closed", "state_reason": "completed"},
        )

    def add_sub_issue(self, parent_number: int, child_id: int) -> None:
        self._request(
            "POST",
            f"/repos/{self.owner}/{self.repo}/issues/{parent_number}/sub_issues",
            {"sub_issue_id": child_id},
        )


# --------------------------------------------------------------------------- state


def load_state() -> dict:
    if STATE_PATH.exists():
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    return {"issues": {}, "links": [], "closed": []}


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
    packages, PARSED_OWNER = parse_packages()

    # Which package claims a task more than once — recorded, never dropped.
    claims: dict[str, list[str]] = {}
    for wp_id, wp in packages.items():
        for task_id in wp.get("tasks", []):
            claims.setdefault(task_id, []).append(wp_id)

    epics: list[dict] = []
    all_tasks: list[dict] = []
    for key, spec_dir, name in EPICS:
        tasks = parse_tasks(key, spec_dir)
        # Re-walk to attach phase/section, which parse_tasks tracked positionally.
        epics.append({"key": key, "spec_dir": spec_dir, "name": name, "tasks": tasks})
        all_tasks.extend(tasks)

    task_by_id = {t["id"]: t for t in all_tasks}
    wp_epic: dict[str, str] = {}
    for wp_id, wp in packages.items():
        for task_id in wp.get("tasks", []):
            if task_id in task_by_id:
                wp_epic[wp_id] = task_by_id[task_id]["epic"]
                break

    epic_wps: dict[str, list[str]] = {e["key"]: [] for e in epics}
    for wp_id in sorted(packages):
        epic_wps.setdefault(wp_epic.get(wp_id, "E3"), []).append(wp_id)

    n_close = sum(1 for t in all_tasks if t["done"])
    n_issues = len(epics) + len(packages) + len(all_tasks)
    n_links = len(packages) + len(all_tasks)
    log(
        f"plan: {len(epics)} epics, {len(packages)} work packages, {len(all_tasks)} tasks "
        f"= {n_issues} issues, {n_links} sub-issue links, {n_close} to close"
    )
    for e in epics:
        unp = [t for t in e["tasks"] if t["id"] not in PARSED_OWNER]
        log(
            f"  {e['key']}: {len(e['tasks'])} tasks "
            f"({sum(1 for t in e['tasks'] if t['done'])} done), "
            f"{len(epic_wps[e['key']])} packages, {len(unp)} tasks direct on the epic"
        )
    dupes = {t: w for t, w in claims.items() if len(w) > 1}
    if dupes:
        log(f"  tasks claimed by more than one package: {dupes}")

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

    def ensure_issue(key: str, title: str, body: str, labels: list[str]) -> dict:
        if key in issues:
            return issues[key]
        made = gh.create_issue(title, body, labels)
        issues[key] = {"number": made["number"], "id": made["id"]}
        save_state({"issues": issues, "links": sorted(links), "closed": sorted(closed)})
        log(f"  created #{made['number']}  {key}")
        return issues[key]

    def ensure_link(parent_key: str, child_key: str) -> None:
        pair = (parent_key, child_key)
        if pair in links:
            return
        gh.add_sub_issue(issues[parent_key]["number"], issues[child_key]["id"])
        links.add(pair)
        save_state({"issues": issues, "links": sorted(links), "closed": sorted(closed)})

    def ensure_closed(key: str) -> None:
        if key in closed:
            return
        gh.close_issue(issues[key]["number"])
        closed.add(key)
        save_state({"issues": issues, "links": sorted(links), "closed": sorted(closed)})

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
        wp = packages[wp_id]
        epic_key = wp_epic.get(wp_id, "E3")
        extra = [t for t in wp.get("tasks", []) if len(claims.get(t, [])) > 1]
        ensure_issue(
            wp_id,
            title_for(wp_id, wp["title"]),
            package_body(wp, epic_key, extra),
            ["work-package", epic_key],
        )
        ensure_link(epic_key, wp_id)

    log("tasks")
    for t in all_tasks:
        wp_id = PARSED_OWNER.get(t["id"])
        extra_wps = [w for w in claims.get(t["id"], []) if w != wp_id]
        ensure_issue(
            t["id"],
            title_for(t["id"], t["description"]),
            task_body(t, wp_id, extra_wps),
            ["task", t["epic"]],
        )
        ensure_link(wp_id or t["epic"], t["id"])
        if t["done"]:
            ensure_closed(t["id"])

    log(f"done — {gh.writes} write requests, {len(issues)} issues, {len(links)} links")
    return 0


if __name__ == "__main__":
    sys.exit(main())
