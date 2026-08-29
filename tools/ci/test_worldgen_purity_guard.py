#!/usr/bin/env python3
"""Focused contracts for worldgen_purity_guard.py."""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

import worldgen_purity_guard as guard


HERE = Path(__file__).resolve().parent
FIXTURES = HERE / "worldgen_purity_fixtures"


def fail(message: str) -> None:
    print(f"[WORLDGEN PURITY TEST] FAIL — {message}", file=sys.stderr)
    raise SystemExit(1)


def write_fixture(root: Path, relative_path: str, content: str) -> Path:
    path = root / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def require_no_violations(label: str, violations: list[guard.Violation]) -> None:
    if violations:
        fail(label + ": " + "; ".join(v.format() for v in violations))


def require_rule(
    label: str,
    violations: list[guard.Violation],
    rule: str,
    detail_fragment: str | None = None,
) -> None:
    matches = [
        violation
        for violation in violations
        if violation.rule == rule
        and (detail_fragment is None or detail_fragment in violation.detail)
    ]
    if not matches:
        fail(
            f"{label}: expected {rule}"
            + (f" containing {detail_fragment!r}" if detail_fragment else "")
            + ", got "
            + "; ".join(v.format() for v in violations)
        )


def main() -> int:
    allowed_files, allowed_violations = guard.scan_tree(FIXTURES / "allowed")
    if len(allowed_files) != 1:
        fail(f"expected 1 allowed pure-data fixture, got {len(allowed_files)}")
    require_no_violations("allowed pure-data fixture produced violations", allowed_violations)

    forbidden_files, forbidden_violations = guard.scan_tree(FIXTURES / "forbidden")
    if len(forbidden_files) != 1:
        fail(f"expected 1 forbidden pure-data fixture, got {len(forbidden_files)}")
    require_rule("pure-data runtime symbol", forbidden_violations, "runtime-symbol", "Node3D")
    require_rule("pure-data mesh symbol", forbidden_violations, "runtime-symbol", "MeshInstance3D")
    require_rule(
        "pure-data cross-domain dependency",
        forbidden_violations,
        "runtime-dependency",
        "res://gameplay/",
    )
    require_rule("pure-data SceneTree access", forbidden_violations, "scene-access", "SceneTree access")
    require_rule("pure-data node shorthand", forbidden_violations, "scene-access", "Node shorthand lookup")

    with tempfile.TemporaryDirectory(prefix="worldgen-purity-") as temp_dir:
        worldgen = Path(temp_dir) / "worldgen"
        worldgen.mkdir()

        runtime_allowed = write_fixture(
            worldgen,
            "runtime/accepted_stage8.gd",
            """extends Node3D
func realize() -> void:
    var mesh := MeshInstance3D.new()
    add_child(mesh)
    get_tree().process_frame
""",
        )
        require_no_violations(
            "explicit worldgen/runtime lane rejected accepted engine runtime ownership",
            guard.scan_file(runtime_allowed, worldgen),
        )

        runtime_dependency = write_fixture(
            worldgen,
            "runtime/forbidden_dependency.gd",
            """extends Node3D
const GameplayOwner := preload("res://gameplay/player/player.gd")
""",
        )
        runtime_dependency_violations = guard.scan_file(runtime_dependency, worldgen)
        require_rule(
            "runtime lane must retain cross-domain isolation",
            runtime_dependency_violations,
            "runtime-dependency",
            "res://gameplay/",
        )
        if any(v.rule in {"runtime-symbol", "scene-access"} for v in runtime_dependency_violations):
            fail("runtime lane incorrectly re-enabled pure-data runtime-symbol checks")

        fuzzy_runtime_name = write_fixture(
            worldgen,
            "underworld/runtime_realization_helper.gd",
            """extends Node3D
func attach() -> void:
    add_child(Node3D.new())
""",
        )
        fuzzy_violations = guard.scan_file(fuzzy_runtime_name, worldgen)
        require_rule(
            "runtime/realization filename substring must not grant exemption",
            fuzzy_violations,
            "runtime-symbol",
            "Node3D",
        )
        require_rule(
            "non-exempt scene ownership must still fail",
            fuzzy_violations,
            "scene-access",
            "scene child mutation",
        )

        geometry_boundary = write_fixture(
            worldgen,
            "geometry/cave_mesh_realization_boundary.gd",
            """extends RefCounted
func realize():
    var mesh := ArrayMesh.new()
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    return mesh
""",
        )
        require_no_violations(
            "authoritative geometry realization boundary rejected engine mesh types",
            guard.scan_file(geometry_boundary, worldgen),
        )

        nearby_geometry = write_fixture(
            worldgen,
            "geometry/cave_mesh_builder.gd",
            """extends RefCounted
func build():
    return ArrayMesh.new()
""",
        )
        require_rule(
            "ordinary geometry helper must remain pure-data",
            guard.scan_file(nearby_geometry, worldgen),
            "runtime-symbol",
            "ArrayMesh",
        )

        runtime_named_handle = write_fixture(
            worldgen,
            "geometry/cave_runtime_mesh_handle.gd",
            """extends RefCounted
var mesh: Mesh
""",
        )
        require_no_violations(
            "explicit runtime mesh handle rejected engine mesh type",
            guard.scan_file(runtime_named_handle, worldgen),
        )

        deterministic_path = write_fixture(
            worldgen,
            "underworld/stage_one_generator.gd",
            """extends RefCounted
func build():
    return Node3D.new()
""",
        )
        deterministic_violations = guard.scan_file(deterministic_path, worldgen)
        require_rule(
            "deterministic Stage-1-7 style path must reject runtime ownership",
            deterministic_violations,
            "runtime-symbol",
            "Node3D",
        )

        formatted = [violation.format() for violation in deterministic_violations]
        if formatted != sorted(formatted):
            fail("diagnostics are not deterministically ordered")
        if not formatted or ":3:" not in formatted[0]:
            fail("diagnostic does not identify the expected source line")

    print("[WORLDGEN PURITY TEST] PASS")
    print(f"  allowed pure-data fixtures: {len(allowed_files)}")
    print(f"  forbidden pure-data fixtures: {len(forbidden_files)}")
    print("  explicit Stage-8/runtime ownership allowance: PASS")
    print("  Stage-8 cross-domain dependency isolation: PASS")
    print("  fuzzy runtime/realization path rejection: PASS")
    print("  authoritative geometry realization classification: PASS")
    print("  deterministic pure-data runtime rejection: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
