#!/usr/bin/env python3
"""Focused contracts for worldgen_purity_guard.py."""

from __future__ import annotations

import sys
from pathlib import Path

import worldgen_purity_guard as guard


HERE = Path(__file__).resolve().parent
FIXTURES = HERE / "worldgen_purity_fixtures"


def fail(message: str) -> None:
    print(f"[WORLDGEN PURITY TEST] FAIL — {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    allowed_files, allowed_violations = guard.scan_tree(FIXTURES / "allowed")
    if len(allowed_files) != 1:
        fail(f"expected 1 allowed fixture, got {len(allowed_files)}")
    if allowed_violations:
        fail(
            "allowed pure-data fixture produced violations: "
            + "; ".join(violation.format() for violation in allowed_violations)
        )

    forbidden_files, forbidden_violations = guard.scan_tree(FIXTURES / "forbidden")
    if len(forbidden_files) != 1:
        fail(f"expected 1 forbidden fixture, got {len(forbidden_files)}")

    rules = {violation.rule for violation in forbidden_violations}
    required_rules = {"runtime-dependency", "runtime-symbol", "scene-access"}
    missing = required_rules - rules
    if missing:
        fail(f"forbidden fixture did not exercise rule(s): {sorted(missing)}")

    details = "\n".join(violation.format() for violation in forbidden_violations)
    for expected in (
        "Node3D",
        "MeshInstance3D",
        "res://gameplay/",
        "SceneTree access",
        "Node shorthand lookup",
    ):
        if expected not in details:
            fail(f"missing expected diagnostic fragment: {expected}")

    print("[WORLDGEN PURITY TEST] PASS")
    print(f"  allowed fixtures: {len(allowed_files)}")
    print(f"  forbidden fixtures: {len(forbidden_files)}")
    print(f"  expected violations observed: {len(forbidden_violations)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
