#!/usr/bin/env python3
"""Validate repository-local Markdown links in Underworld documentation."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlsplit


SCRIPT_PATH = Path(__file__).resolve()
DEFAULT_REPO_ROOT = SCRIPT_PATH.parents[2]

INLINE_LINK_RE = re.compile(
    r"!?\[[^\]\n]*\]\(\s*(?P<target><[^>\n]+>|[^\s)]+)"
    r"(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\)))?\s*\)"
)
REFERENCE_TARGET_RE = re.compile(
    r"^[ \t]{0,3}\[[^\]\n]+\]:[ \t]*(?P<target><[^>\n]+>|\S+)"
)
INLINE_CODE_RE = re.compile(r"(?P<fence>`+)(?:(?!\1).)*?\1")
FENCE_RE = re.compile(r"^[ \t]{0,3}(?P<fence>`{3,}|~{3,})")
IGNORED_SCHEMES = {
    "data",
    "ftp",
    "ftps",
    "http",
    "https",
    "irc",
    "ircs",
    "javascript",
    "mailto",
    "news",
    "ssh",
    "tel",
}


def tracked_markdown_files(repo_root: Path) -> list[Path]:
    """Return tracked docs/**/*.md plus the root README.md when tracked."""
    result = subprocess.run(
        [
            "git",
            "-C",
            str(repo_root),
            "ls-files",
            "-z",
            "--",
            "docs/**/*.md",
            "docs/*.md",
            "README.md",
        ],
        check=True,
        capture_output=True,
    )
    relative_paths = sorted(
        path.decode("utf-8")
        for path in result.stdout.split(b"\0")
        if path
    )
    return [repo_root / path for path in relative_paths]


def _strip_inline_code(line: str) -> str:
    return INLINE_CODE_RE.sub(lambda match: " " * len(match.group(0)), line)


def markdown_targets(text: str) -> list[tuple[int, str]]:
    """Extract inline/reference Markdown targets outside fenced code blocks."""
    targets: list[tuple[int, str]] = []
    active_fence_char: str | None = None
    active_fence_length = 0

    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        fence_match = FENCE_RE.match(raw_line)
        if fence_match:
            fence = fence_match.group("fence")
            fence_char = fence[0]
            fence_length = len(fence)
            if active_fence_char is None:
                active_fence_char = fence_char
                active_fence_length = fence_length
                continue
            if fence_char == active_fence_char and fence_length >= active_fence_length:
                active_fence_char = None
                active_fence_length = 0
                continue

        if active_fence_char is not None:
            continue

        line = _strip_inline_code(raw_line)
        for match in INLINE_LINK_RE.finditer(line):
            targets.append((line_number, match.group("target")))

        reference_match = REFERENCE_TARGET_RE.match(line)
        if reference_match:
            targets.append((line_number, reference_match.group("target")))

    return targets


def _clean_target(raw_target: str) -> str:
    target = raw_target.strip()
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1].strip()
    return target


def resolve_repository_target(
    source_path: Path,
    raw_target: str,
    repo_root: Path,
) -> tuple[Path | None, str | None]:
    """Resolve one Markdown target or return (None, None) when it is ignored."""
    target = _clean_target(raw_target)
    if not target or target.startswith("#"):
        return None, None

    split = urlsplit(target)
    scheme = split.scheme.lower()
    if split.netloc or scheme in IGNORED_SCHEMES:
        return None, None
    if scheme:
        # Unknown URI schemes (for example Godot res:// references) are not
        # repository-relative Markdown navigation and are intentionally ignored.
        return None, None

    decoded_path = unquote(split.path)
    if not decoded_path:
        return None, None

    repo_root = repo_root.resolve()
    if decoded_path.startswith("/"):
        candidate = repo_root / decoded_path.lstrip("/")
    else:
        candidate = source_path.parent / decoded_path

    candidate = candidate.resolve(strict=False)
    try:
        candidate.relative_to(repo_root)
    except ValueError:
        return candidate, "target escapes repository root"

    return candidate, None


def validate_markdown_file(source_path: Path, repo_root: Path) -> list[str]:
    """Return deterministic diagnostics for invalid local links in one file."""
    repo_root = repo_root.resolve()
    source_path = source_path.resolve()
    try:
        text = source_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        relative_source = source_path.relative_to(repo_root).as_posix()
        return [f"{relative_source}: unable to read UTF-8 Markdown: {exc}"]

    relative_source = source_path.relative_to(repo_root).as_posix()
    errors: list[str] = []

    for line_number, raw_target in markdown_targets(text):
        candidate, resolution_error = resolve_repository_target(
            source_path,
            raw_target,
            repo_root,
        )
        if resolution_error is not None:
            errors.append(
                f"{relative_source}:{line_number}: {raw_target} — {resolution_error}"
            )
            continue
        if candidate is None:
            continue
        if not candidate.exists():
            errors.append(
                f"{relative_source}:{line_number}: {raw_target} — target does not exist"
            )

    return errors


def validate_repository(repo_root: Path) -> tuple[list[Path], list[str]]:
    files = tracked_markdown_files(repo_root)
    errors: list[str] = []
    for source_path in files:
        errors.extend(validate_markdown_file(source_path, repo_root))
    return files, sorted(errors)


def run_self_test() -> int:
    """Exercise the parser/resolver with isolated filesystem micro-fixtures."""
    with tempfile.TemporaryDirectory(prefix="underworld-doc-links-") as temp_dir:
        repo_root = Path(temp_dir).resolve()
        docs_dir = repo_root / "docs"
        docs_dir.mkdir()
        (repo_root / "README.md").write_text("# Fixture root\n", encoding="utf-8")
        (docs_dir / "target.md").write_text("# Target\n", encoding="utf-8")
        (docs_dir / "space name.md").write_text("# Encoded target\n", encoding="utf-8")

        valid_source = docs_dir / "valid.md"
        valid_source.write_text(
            "\n".join(
                [
                    "# Valid fixture",
                    "[relative](target.md)",
                    "[root](/README.md)",
                    "[encoded](space%20name.md?view=1#section)",
                    "[external](https://example.com/never-fetched)",
                    "[mail](mailto:test@example.com)",
                    "[anchor](#local-heading)",
                    "[reference][target-ref]",
                    "[target-ref]: target.md#section",
                    "`[inline-code](missing-inline.md)`",
                    "```markdown",
                    "[fenced-example](missing-fenced.md)",
                    "```",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        valid_errors = validate_markdown_file(valid_source, repo_root)
        if valid_errors:
            print("[DOCUMENTATION LINKS] SELF-TEST FAIL — valid fixture rejected", file=sys.stderr)
            for error in valid_errors:
                print(f"  - {error}", file=sys.stderr)
            return 1

        broken_source = docs_dir / "broken.md"
        broken_source.write_text("[broken](missing.md)\n", encoding="utf-8")
        broken_errors = validate_markdown_file(broken_source, repo_root)
        if len(broken_errors) != 1 or "target does not exist" not in broken_errors[0]:
            print("[DOCUMENTATION LINKS] SELF-TEST FAIL — broken target was not rejected", file=sys.stderr)
            for error in broken_errors:
                print(f"  - {error}", file=sys.stderr)
            return 1

        escape_source = docs_dir / "escape.md"
        escape_source.write_text("[escape](../../outside.md)\n", encoding="utf-8")
        escape_errors = validate_markdown_file(escape_source, repo_root)
        if len(escape_errors) != 1 or "escapes repository root" not in escape_errors[0]:
            print("[DOCUMENTATION LINKS] SELF-TEST FAIL — repository escape was not rejected", file=sys.stderr)
            for error in escape_errors:
                print(f"  - {error}", file=sys.stderr)
            return 1

    print("[DOCUMENTATION LINKS] SELF-TEST PASS")
    print("  valid internal/external/fenced-code fixture: PASS")
    print("  missing internal target rejection: PASS")
    print("  repository-root escape rejection: PASS")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate repository-local Markdown links under docs/ and README.md."
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=DEFAULT_REPO_ROOT,
        help="repository root (defaults to the repository containing this script)",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="run isolated parser/resolver micro-fixtures instead of scanning the repository",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return run_self_test()

    repo_root = args.repo_root.resolve()
    try:
        files, errors = validate_repository(repo_root)
    except (OSError, UnicodeError, subprocess.CalledProcessError) as exc:
        print("[DOCUMENTATION LINKS] FAIL — validator could not initialize", file=sys.stderr)
        print(f"  - {exc}", file=sys.stderr)
        return 1

    if errors:
        print(
            f"[DOCUMENTATION LINKS] FAIL — {len(errors)} broken internal link(s)",
            file=sys.stderr,
        )
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("[DOCUMENTATION LINKS] PASS")
    print(f"  markdown files checked: {len(files)}")
    print("  external links fetched: 0")
    print("  fragment-anchor validation: intentionally out of scope")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
