#!/usr/bin/env python3
"""Static guard for Underworld worldgen pure-data and runtime-realization boundaries."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[2]
DEFAULT_WORLDGEN_ROOT = REPO_ROOT / "worldgen"

SCANNED_SUFFIXES = {".gd", ".cs", ".tres", ".tscn", ".gdshader", ".shader"}
FORBIDDEN_SCENE_SUFFIXES = {".tscn", ".scn"}

# These dependencies cross ownership domains and remain forbidden in every
# worldgen lane, including explicit Stage-8/runtime realization code.
FORBIDDEN_RESOURCE_PREFIXES = (
    "res://app/",
    "res://combat/",
    "res://data/",
    "res://game/",
    "res://gameplay/",
    "res://player/",
    "res://presentation/",
    "res://scenes/",
    "res://scripts/",
    "res://world/",
)

# Explicit accepted engine-runtime lanes. Classification is repository-path
# based; names that merely contain "runtime" or "realization" gain no exemption.
RUNTIME_ALLOWED_SUBTREES = (
    "runtime/",
)
RUNTIME_ALLOWED_FILES = frozenset(
    {
        "geometry/cave_mesh_realization_boundary.gd",
        "geometry/cave_runtime_mesh_handle.gd",
    }
)

FORBIDDEN_RUNTIME_SYMBOLS = (
    "Node",
    "Node2D",
    "Node3D",
    "CanvasItem",
    "Control",
    "Window",
    "Viewport",
    "SubViewport",
    "SceneTree",
    "PackedScene",
    "Mesh",
    "ArrayMesh",
    "ImmediateMesh",
    "SurfaceTool",
    "MeshInstance2D",
    "MeshInstance3D",
    "MultiMeshInstance2D",
    "MultiMeshInstance3D",
    "VisualInstance3D",
    "GeometryInstance3D",
    "Camera2D",
    "Camera3D",
    "Light2D",
    "Light3D",
    "CollisionObject2D",
    "CollisionObject3D",
    "PhysicsBody2D",
    "PhysicsBody3D",
    "StaticBody2D",
    "StaticBody3D",
    "CharacterBody2D",
    "CharacterBody3D",
    "RigidBody2D",
    "RigidBody3D",
    "Area2D",
    "Area3D",
    "CollisionShape2D",
    "CollisionShape3D",
    "CollisionPolygon2D",
    "CollisionPolygon3D",
    "NavigationRegion2D",
    "NavigationRegion3D",
    "NavigationAgent2D",
    "NavigationAgent3D",
    "AnimationPlayer",
    "Timer",
)

_RUNTIME_SYMBOL_RE = re.compile(
    r"\b(?:" + "|".join(re.escape(symbol) for symbol in FORBIDDEN_RUNTIME_SYMBOLS) + r")\b"
)
_SCENE_ACCESS_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("SceneTree access", re.compile(r"\bget_tree\s*\(")),
    ("scene node lookup", re.compile(r"\bget_node(?:_or_null)?\s*\(")),
    ("scene child mutation", re.compile(r"\b(?:add_child|remove_child|move_child|reparent)\s*\(")),
    ("scene lifetime mutation", re.compile(r"\bqueue_free\s*\(")),
    ("viewport access", re.compile(r"\bget_viewport\s*\(")),
    ("Node shorthand lookup", re.compile(r"(?<![\w$])\$[A-Za-z_%@]")),
    ("onready scene lifecycle annotation", re.compile(r"\B@onready\b")),
)


@dataclass(frozen=True, order=True)
class Violation:
    path: str
    line: int
    rule: str
    detail: str

    def format(self) -> str:
        return f"{self.path}:{self.line}: {self.rule}: {self.detail}"


def _strip_comment(line: str) -> str:
    """Remove a GDScript-style # comment while preserving quoted resource paths."""
    quote: str | None = None
    escaped = False
    result: list[str] = []
    for char in line:
        if escaped:
            result.append(char)
            escaped = False
            continue
        if char == "\\" and quote is not None:
            result.append(char)
            escaped = True
            continue
        if quote is not None:
            result.append(char)
            if char == quote:
                quote = None
            continue
        if char in {'"', "'"}:
            quote = char
            result.append(char)
            continue
        if char == "#":
            break
        result.append(char)
    return "".join(result)


def _strip_strings_and_comment(line: str) -> str:
    """Blank quoted text/comments so prose and resource paths cannot trigger symbol checks."""
    quote: str | None = None
    escaped = False
    result: list[str] = []
    for char in line:
        if escaped:
            result.append(" ")
            escaped = False
            continue
        if quote is not None:
            if char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            result.append(" ")
            continue
        if char in {'"', "'"}:
            quote = char
            result.append(" ")
            continue
        if char == "#":
            break
        result.append(char)
    return "".join(result)


def _display_path(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()
    except ValueError:
        try:
            return path.resolve().relative_to(root.resolve()).as_posix()
        except ValueError:
            return path.as_posix()


def _worldgen_relative_path(path: Path, root: Path) -> str:
    """Return a normalized path relative to the worldgen root used for policy classification."""
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.name


def is_runtime_realization_path(path: Path, root: Path) -> bool:
    relative = _worldgen_relative_path(path, root)
    return relative in RUNTIME_ALLOWED_FILES or any(
        relative.startswith(prefix) for prefix in RUNTIME_ALLOWED_SUBTREES
    )


def scan_file(path: Path, root: Path) -> list[Violation]:
    display_path = _display_path(path, root)
    if path.suffix.lower() in FORBIDDEN_SCENE_SUFFIXES:
        return [
            Violation(
                display_path,
                1,
                "scene-resource",
                "scene resources are not allowed under worldgen/",
            )
        ]
    if path.suffix.lower() not in SCANNED_SUFFIXES:
        return []

    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        return [Violation(display_path, 1, "unreadable-source", str(exc))]

    runtime_allowed = is_runtime_realization_path(path, root)
    violations: list[Violation] = []
    for line_number, raw_line in enumerate(lines, start=1):
        path_line = _strip_comment(raw_line)
        for prefix in FORBIDDEN_RESOURCE_PREFIXES:
            if prefix in path_line:
                violations.append(
                    Violation(
                        display_path,
                        line_number,
                        "runtime-dependency",
                        f"forbidden resource reference {prefix}",
                    )
                )

        if runtime_allowed:
            continue

        code_line = _strip_strings_and_comment(raw_line)
        for match in _RUNTIME_SYMBOL_RE.finditer(code_line):
            violations.append(
                Violation(
                    display_path,
                    line_number,
                    "runtime-symbol",
                    f"forbidden runtime symbol {match.group(0)}",
                )
            )
        for rule, pattern in _SCENE_ACCESS_PATTERNS:
            if pattern.search(code_line):
                violations.append(Violation(display_path, line_number, "scene-access", rule))

    return violations


def scan_tree(root: Path) -> tuple[list[Path], list[Violation]]:
    root = root.resolve()
    if not root.is_dir():
        raise FileNotFoundError(f"worldgen root does not exist: {root}")

    files = sorted(path for path in root.rglob("*") if path.is_file())
    production_files = [
        path
        for path in files
        if path.suffix.lower() in SCANNED_SUFFIXES | FORBIDDEN_SCENE_SUFFIXES
    ]
    violations: list[Violation] = []
    for path in production_files:
        violations.extend(scan_file(path, root))
    return production_files, sorted(set(violations))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_WORLDGEN_ROOT,
        help="worldgen-like root to scan (default: repository worldgen/)",
    )
    args = parser.parse_args(argv)

    try:
        files, violations = scan_tree(args.root)
    except (OSError, ValueError) as exc:
        print("[WORLDGEN PURITY] FAIL — guard could not initialize", file=sys.stderr)
        print(f"  - {exc}", file=sys.stderr)
        return 1

    if violations:
        print(f"[WORLDGEN PURITY] FAIL — {len(violations)} violation(s)", file=sys.stderr)
        for violation in violations:
            print(f"  - {violation.format()}", file=sys.stderr)
        return 1

    print("[WORLDGEN PURITY] PASS")
    print(f"  scanned production files: {len(files)}")
    print("  forbidden cross-domain dependencies: 0")
    print("  pure-data runtime ownership/scene access violations: 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
