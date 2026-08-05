#!/usr/bin/env python3
"""Validate the work-package files under coordination/packages/.

Run by ./scripts/verify.sh. Exists because a structured file that nothing checks is a markdown
file with braces — and the failure this whole model exists to prevent (two sessions believing they
own the same work) is silent by nature. Nobody notices until both have written the code.

What it refuses:

  * two packages with the same id, or a filename that disagrees with the id inside it
  * a status outside the lifecycle, or a transition target nobody defined
  * an active package with no owner, or a NOT_STARTED package that has one
  * more than one active EXCLUSIVE package, or any other package active alongside one
  * a dependency that does not exist, or a cycle
  * a model outside the opencode-go allowlist, which is the billing boundary
  * a missing or non-positive spend envelope

What it warns about without failing:

  * a package sitting IN_PROGRESS with an old `updated_at`. Sessions run in containers that are
    destroyed on inactivity, so a worker dying mid-package is the normal end of a session rather
    than an exception. Without this the package stays locked and nobody can legitimately take it.
    It is a warning rather than a failure because the coordinator decides whether to reclaim it,
    and a gate that fails on a stale package would block every unrelated commit until they did.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PACKAGES = REPO / "coordination" / "packages"

STATUSES = [
    "NOT_STARTED",
    "ASSIGNED",
    "IN_PROGRESS",
    "BLOCKED",
    "READY_FOR_REVIEW",
    "COMPLETED",
]

# Everything except NOT_STARTED and COMPLETED holds a worker and blocks an EXCLUSIVE package.
ACTIVE = {"ASSIGNED", "IN_PROGRESS", "BLOCKED", "READY_FOR_REVIEW"}

MODES = {"PARALLEL", "EXCLUSIVE"}

# The prefix is the billing boundary, not a naming convention. `opencode/` is a different product
# that bills per token against the same credential. See CLAUDE.md.
ALLOWED_MODELS = {
    "opencode-go/deepseek-v4-flash",
    "opencode-go/qwen3.6-plus",
    "opencode-go/grok-4.5",
}

REQUIRED = [
    "id", "title", "objective", "acceptance_criteria", "dependencies", "scope",
    "execution_mode", "status", "owner", "priority", "spend_envelope_usd",
    "suggested_model", "updated_at",
]

STALE_AFTER = timedelta(hours=6)


def _load() -> tuple[list[dict], list[str]]:
    errors: list[str] = []
    packages: list[dict] = []
    if not PACKAGES.exists():
        return packages, [f"missing {PACKAGES.relative_to(REPO)}"]

    for path in sorted(PACKAGES.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{path.name}: not valid JSON — {exc}")
            continue
        data["__file"] = path.name
        packages.append(data)
    return packages, errors


def _cycles(packages: list[dict]) -> list[str]:
    graph = {p["id"]: list(p.get("dependencies", [])) for p in packages if "id" in p}
    found: list[str] = []
    WHITE, GREY, BLACK = 0, 1, 2
    colour = {node: WHITE for node in graph}

    def walk(node: str, trail: list[str]) -> None:
        colour[node] = GREY
        for nxt in graph.get(node, []):
            if nxt not in colour:
                continue
            if colour[nxt] == GREY:
                found.append(" -> ".join(trail + [node, nxt]))
            elif colour[nxt] == WHITE:
                walk(nxt, trail + [node])
        colour[node] = BLACK

    for node in graph:
        if colour[node] == WHITE:
            walk(node, [])
    return found


def main() -> int:
    packages, errors = _load()
    warnings: list[str] = []
    now = datetime.now(timezone.utc)

    seen: dict[str, str] = {}
    for pkg in packages:
        name = pkg["__file"]

        missing = [f for f in REQUIRED if f not in pkg]
        if missing:
            errors.append(f"{name}: missing field(s): {', '.join(missing)}")
            continue

        pid = pkg["id"]
        if pid in seen:
            errors.append(f"{name}: id {pid} already used by {seen[pid]}")
        seen[pid] = name
        if name != f"{pid}.json":
            errors.append(f"{name}: filename does not match id {pid} — one package, one file")

        if pkg["status"] not in STATUSES:
            errors.append(f"{name}: status {pkg['status']!r} is not one of {', '.join(STATUSES)}")
        if pkg["execution_mode"] not in MODES:
            errors.append(f"{name}: execution_mode {pkg['execution_mode']!r} is not PARALLEL or EXCLUSIVE")

        active = pkg["status"] in ACTIVE
        if active and not pkg.get("owner"):
            errors.append(f"{name}: {pkg['status']} with no owner — an active package has exactly one")
        if pkg["status"] == "NOT_STARTED" and pkg.get("owner"):
            errors.append(f"{name}: NOT_STARTED but owned by {pkg['owner']!r} — unassign it or move it on")
        if pkg["status"] == "BLOCKED" and not pkg.get("blocked_reason"):
            errors.append(f"{name}: BLOCKED with no blocked_reason — a blocker nobody wrote down is not one")

        model = pkg.get("suggested_model")
        if model not in ALLOWED_MODELS:
            errors.append(f"{name}: suggested_model {model!r} is outside the opencode-go allowlist")

        envelope = pkg.get("spend_envelope_usd")
        if not isinstance(envelope, (int, float)) or envelope <= 0:
            errors.append(f"{name}: spend_envelope_usd must be a positive number, got {envelope!r}")

        for dep in pkg.get("dependencies", []):
            if dep not in {p.get("id") for p in packages}:
                errors.append(f"{name}: depends on {dep}, which does not exist")

        if pkg["status"] == "IN_PROGRESS":
            stamp = pkg.get("updated_at", "")
            try:
                at = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
                at = at if at.tzinfo else at.replace(tzinfo=timezone.utc)
                if now - at > STALE_AFTER:
                    hours = (now - at).total_seconds() / 3600
                    warnings.append(
                        f"{name}: IN_PROGRESS and untouched for {hours:.0f}h — the worker may be gone. "
                        f"Only the coordinator reclaims it.")
            except ValueError:
                errors.append(f"{name}: updated_at {stamp!r} is not a timestamp")

    for trail in _cycles(packages):
        errors.append(f"dependency cycle: {trail}")

    live = [p for p in packages if p.get("status") in ACTIVE]
    exclusive = [p for p in live if p.get("execution_mode") == "EXCLUSIVE"]
    if len(exclusive) > 1:
        errors.append("more than one EXCLUSIVE package is active: "
                      + ", ".join(p["id"] for p in exclusive))
    elif exclusive and len(live) > 1:
        others = [p["id"] for p in live if p["id"] != exclusive[0]["id"]]
        errors.append(f"{exclusive[0]['id']} is EXCLUSIVE and active, so nothing else may be: "
                      + ", ".join(others))

    for line in warnings:
        print(f"   warning: {line}")
    if errors:
        for line in errors:
            print(f"   {line}")
        return 1
    print(f"   {len(packages)} work package(s), {len(live)} active")
    return 0


if __name__ == "__main__":
    sys.exit(main())
