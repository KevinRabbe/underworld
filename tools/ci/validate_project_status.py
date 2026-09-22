#!/usr/bin/env python3
"""Validate the checked-in project status snapshot.

This tool deliberately validates only committed repository data. It does not
query GitHub, mutate issue state, or attempt to decide whether a milestone is
complete. Live PM/review/integration authority remains external to this file.
"""

from __future__ import annotations

import argparse
import json
import re
from datetime import date
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
STATUS_JSON = Path("docs/00_project/project_status.json")
STATUS_MD = Path("docs/00_project/PROJECT_STATUS.md")
README = Path("README.md")

SHA_RE = re.compile(r"^[0-9a-f]{40}$")
PLAYABLE_STATES = {"NOT_YET", "SMOKE_CANDIDATE", "CORE_PLAYABLE", "FIRST_PLAYABLE"}
MILESTONE_STATES = {"PLANNED", "IN_PROGRESS", "NOT_ACHIEVED", "ACHIEVED", "BLOCKED"}
EXPECTED_DOMAINS = ["OVERWORLD", "UNDERWORLD"]
EXPECTED_TOPOLOGY_GATES = [872, 873, 875, 876, 877, 878]


def _read_text(root: Path, relative: Path, errors: list[str]) -> str:
    path = root / relative
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"cannot read {relative}: {exc}")
        return ""


def _load_manifest(root: Path, errors: list[str]) -> dict[str, Any]:
    raw = _read_text(root, STATUS_JSON, errors)
    if not raw:
        return {}
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        errors.append(f"{STATUS_JSON} is not valid JSON: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{STATUS_JSON} root must be an object")
        return {}
    return value


def _require_keys(mapping: dict[str, Any], keys: set[str], where: str, errors: list[str]) -> None:
    missing = sorted(keys.difference(mapping.keys()))
    if missing:
        errors.append(f"{where} missing required keys: {', '.join(missing)}")


def _marker(name: str, value: str) -> str:
    return f"<!-- PROJECT_STATUS_{name}: {value} -->"


def validate(root: Path = REPO_ROOT) -> list[str]:
    errors: list[str] = []
    manifest = _load_manifest(root, errors)
    if not manifest:
        return errors

    _require_keys(
        manifest,
        {
            "schema_revision",
            "accepted_main",
            "last_synced_at",
            "project_mode",
            "playable_state",
            "current_gate",
            "next_transition",
            "world_model",
            "authorities",
            "milestones",
            "topology_gates",
            "scale_program",
            "status_policy",
        },
        "project status manifest",
        errors,
    )

    if manifest.get("schema_revision") != 1:
        errors.append("schema_revision must be 1")

    accepted_main = manifest.get("accepted_main")
    if not isinstance(accepted_main, str) or not SHA_RE.fullmatch(accepted_main):
        errors.append("accepted_main must be a lowercase 40-character Git SHA")
        accepted_main = "INVALID"

    last_synced_at = manifest.get("last_synced_at")
    if not isinstance(last_synced_at, str):
        errors.append("last_synced_at must be an ISO calendar date")
    else:
        try:
            date.fromisoformat(last_synced_at)
        except ValueError:
            errors.append("last_synced_at must be an ISO calendar date (YYYY-MM-DD)")

    playable_state = manifest.get("playable_state")
    if playable_state not in PLAYABLE_STATES:
        errors.append(f"playable_state must be one of {sorted(PLAYABLE_STATES)}")
        playable_state = "INVALID"

    current_gate = manifest.get("current_gate")
    if not isinstance(current_gate, dict):
        errors.append("current_gate must be an object")
    else:
        _require_keys(current_gate, {"issue", "state", "summary"}, "current_gate", errors)
        if not isinstance(current_gate.get("issue"), int) or current_gate.get("issue", 0) <= 0:
            errors.append("current_gate.issue must be a positive integer")

    world_model = manifest.get("world_model")
    if not isinstance(world_model, dict):
        errors.append("world_model must be an object")
        world_model = {}
    else:
        _require_keys(
            world_model,
            {"domains", "underworld_topology", "exploration_scale_direction"},
            "world_model",
            errors,
        )

    if world_model.get("domains") != EXPECTED_DOMAINS:
        errors.append("world_model.domains must be exactly [OVERWORLD, UNDERWORLD]")
    if world_model.get("underworld_topology") != "CONTINUOUS_BIOME_WORLD":
        errors.append("world_model.underworld_topology must be CONTINUOUS_BIOME_WORLD")

    scale = world_model.get("exploration_scale_direction")
    if not isinstance(scale, dict):
        errors.append("world_model.exploration_scale_direction must be an object")
    else:
        over = scale.get("overworld_percent")
        under = scale.get("underworld_percent")
        if not isinstance(over, (int, float)) or not isinstance(under, (int, float)):
            errors.append("world scale percentages must be numeric")
        elif over + under != 100:
            errors.append("world scale directional percentages must sum to 100")
        if scale.get("metric") != "DIRECTIONAL_EXPLORATION_ALLOCATION_NOT_RADIUS":
            errors.append("world scale metric must explicitly state that 40/60 is not radius")

    milestones = manifest.get("milestones")
    if not isinstance(milestones, list) or not milestones:
        errors.append("milestones must be a non-empty list")
    else:
        seen_ids: set[str] = set()
        for index, milestone in enumerate(milestones):
            if not isinstance(milestone, dict):
                errors.append(f"milestones[{index}] must be an object")
                continue
            _require_keys(milestone, {"id", "state", "authority_issue", "summary"}, f"milestones[{index}]", errors)
            milestone_id = milestone.get("id")
            if not isinstance(milestone_id, str) or not milestone_id:
                errors.append(f"milestones[{index}].id must be a non-empty string")
            elif milestone_id in seen_ids:
                errors.append(f"duplicate milestone id: {milestone_id}")
            else:
                seen_ids.add(milestone_id)
            if milestone.get("state") not in MILESTONE_STATES:
                errors.append(f"milestones[{index}].state is not recognized")

    topology_gates = manifest.get("topology_gates")
    if not isinstance(topology_gates, list):
        errors.append("topology_gates must be a list")
    else:
        issue_ids = [gate.get("issue") for gate in topology_gates if isinstance(gate, dict)]
        if issue_ids != EXPECTED_TOPOLOGY_GATES:
            errors.append(
                "topology_gates must list the bounded Core topology packet in order: "
                + ", ".join(f"#{issue}" for issue in EXPECTED_TOPOLOGY_GATES)
            )

    policy = manifest.get("status_policy")
    if not isinstance(policy, dict):
        errors.append("status_policy must be an object")
    elif policy.get("numeric_progress") != "ONLY_FROM_EXPLICIT_FINITE_GATE_SET":
        errors.append("numeric progress policy must forbid arbitrary percentages")

    status_md = _read_text(root, STATUS_MD, errors)
    readme = _read_text(root, README, errors)
    marker_values = {
        "PLAYABLE_STATE": str(playable_state),
        "ACCEPTED_MAIN": str(accepted_main),
        "WORLD_MODEL": "OVERWORLD+UNDERWORLD_CONTINUOUS_BIOMES",
    }
    for marker_name, marker_value in marker_values.items():
        expected = _marker(marker_name, marker_value)
        if expected not in status_md:
            errors.append(f"{STATUS_MD} missing or stale marker: {expected}")
        if expected not in readme:
            errors.append(f"{README} missing or stale marker: {expected}")

    if "docs/00_project/PROJECT_STATUS.md" not in readme:
        errors.append("README.md must link to docs/00_project/PROJECT_STATUS.md")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="repository root (defaults to script-detected root)")
    args = parser.parse_args()

    errors = validate(args.root.resolve())
    if errors:
        print("Project status validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Project status validation PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
