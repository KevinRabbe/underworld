#!/usr/bin/env python3
"""Validate Underworld's migration-aware repository layout policy."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path, PurePosixPath


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[2]
POLICY_PATH = SCRIPT_PATH.with_name("repository_layout_policy.json")
TEXT_RESOURCE_SUFFIXES = {
    ".cfg",
    ".cs",
    ".gd",
    ".gdshader",
    ".godot",
    ".shader",
    ".tres",
    ".tscn",
}
PRODUCTION_ROOTS = {
    "app",
    "combat",
    "content",
    "core",
    "data",
    "gameplay",
    "presentation",
    "world",
    "worldgen",
}


def load_policy() -> dict:
    with POLICY_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "ls-files", "-z"],
        check=True,
        capture_output=True,
    )
    return sorted(
        path.decode("utf-8")
        for path in result.stdout.split(b"\0")
        if path
    )


def top_level(path: str) -> str:
    parts = PurePosixPath(path).parts
    return parts[0] if len(parts) > 1 else ""


def read_text_resource(path: str) -> str | None:
    if Path(path).suffix.lower() not in TEXT_RESOURCE_SUFFIXES:
        return None
    absolute_path = REPO_ROOT / path
    try:
        return absolute_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None


def validate_exception_contracts(
    dependency_rules: list[dict],
    dependency_exceptions: list[dict],
    files: set[str],
) -> list[str]:
    errors: list[str] = []
    rules_by_name = {
        str(rule.get("name", "")): rule
        for rule in dependency_rules
        if str(rule.get("name", ""))
    }

    for exception in dependency_exceptions:
        rule_name = str(exception.get("rule", ""))
        source_path = str(exception.get("source_path", ""))
        reason = str(exception.get("reason", "")).strip()
        allowed_prefixes = set(exception.get("allowed_prefixes", []))

        if rule_name not in rules_by_name:
            errors.append(f"dependency exception references unknown rule: {rule_name}")
            continue
        if source_path not in files:
            errors.append(f"dependency exception source does not exist: {source_path}")
        if not reason:
            errors.append(f"dependency exception requires a reason: {source_path}")

        forbidden_prefixes = set(rules_by_name[rule_name].get("forbidden_prefixes", []))
        invalid_prefixes = allowed_prefixes - forbidden_prefixes
        for prefix in sorted(invalid_prefixes):
            errors.append(
                f"dependency exception allows non-forbidden prefix {prefix} "
                f"for rule {rule_name}"
            )

    return errors


def is_dependency_exception(
    dependency_exceptions: list[dict],
    rule_name: str,
    source_path: str,
    prefix: str,
) -> bool:
    for exception in dependency_exceptions:
        if str(exception.get("rule", "")) != rule_name:
            continue
        if str(exception.get("source_path", "")) != source_path:
            continue
        if prefix in set(exception.get("allowed_prefixes", [])):
            return True
    return False


def main() -> int:
    try:
        policy = load_policy()
        files = tracked_files()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("[REPOSITORY LAYOUT] FAIL — validator could not initialize", file=sys.stderr)
        print(f"  - {exc}", file=sys.stderr)
        return 1

    canonical_roots = set(policy.get("canonical_roots", []))
    legacy_allowed_roots = set(policy.get("legacy_allowed_roots", []))
    forbidden_roots = set(policy.get("forbidden_roots", []))
    retired_resource_prefixes = tuple(policy.get("retired_resource_prefixes", []))
    dependency_rules = list(policy.get("dependency_rules", []))
    dependency_exceptions = list(policy.get("dependency_exceptions", []))

    errors: list[str] = []
    dependency_violations = 0
    retired_path_violations = 0
    dependency_exceptions_used: set[tuple[str, str, str]] = set()
    legacy_roots_present: set[str] = set()

    allowed_roots = canonical_roots | legacy_allowed_roots
    tracked_file_set = set(files)
    errors.extend(
        validate_exception_contracts(
            dependency_rules,
            dependency_exceptions,
            tracked_file_set,
        )
    )

    for path in files:
        root = top_level(path)
        if not root:
            continue
        if root in forbidden_roots:
            errors.append(f"forbidden retired root: {path}")
        elif root not in allowed_roots:
            errors.append(f"unreviewed top-level root: {path}")
        elif root in legacy_allowed_roots:
            legacy_roots_present.add(root)

    for path in files:
        text = read_text_resource(path)
        if text is None:
            continue

        for prefix in retired_resource_prefixes:
            if prefix in text:
                retired_path_violations += 1
                errors.append(f"retired resource reference {prefix} in {path}")

        root = top_level(path)
        if not root:
            continue
        for rule in dependency_rules:
            if root not in set(rule.get("source_roots", [])):
                continue
            rule_name = str(rule.get("name", "unnamed"))
            for prefix in rule.get("forbidden_prefixes", []):
                if prefix not in text:
                    continue
                if is_dependency_exception(
                    dependency_exceptions,
                    rule_name,
                    path,
                    prefix,
                ):
                    dependency_exceptions_used.add((rule_name, path, prefix))
                    continue
                dependency_violations += 1
                errors.append(
                    f"dependency rule {rule_name} forbids {prefix} in {path}"
                )

    policy_version = int(policy.get("policy_version", 0))
    production_count = sum(1 for path in files if top_level(path) in PRODUCTION_ROOTS)
    test_count = sum(1 for path in files if top_level(path) == "tests")
    tool_count = sum(1 for path in files if top_level(path) == "tools")

    if errors:
        print(f"[REPOSITORY LAYOUT] FAIL — {len(errors)} violation(s)", file=sys.stderr)
        print(f"  policy version: {policy_version}", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    legacy_summary = ", ".join(sorted(legacy_roots_present)) or "none"
    print("[REPOSITORY LAYOUT] PASS")
    print(f"  policy version: {policy_version}")
    print(f"  tracked files: {len(files)}")
    print(f"  production files: {production_count}")
    print(f"  test files: {test_count}")
    print(f"  tool files: {tool_count}")
    print(f"  legacy roots present: {legacy_summary}")
    print(f"  dependency exceptions used: {len(dependency_exceptions_used)}")
    print(f"  forbidden root dependencies: {dependency_violations}")
    print(f"  retired path violations: {retired_path_violations}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
