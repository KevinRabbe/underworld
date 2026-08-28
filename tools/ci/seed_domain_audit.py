#!/usr/bin/env python3
"""Audit Underworld's deterministic seed-domain registry and static call sites."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[2]
REGISTRY_RELATIVE_PATH = Path("worldgen/random/seed_domains.gd")
SCHEMA = "seed-domain-audit-v1"

CONST_RE = re.compile(
    r"^\s*const\s+([A-Z][A-Z0-9_]*):\s*int\s*=\s*(0x[0-9A-Fa-f]+|\d+)\s*$",
    re.MULTILINE,
)
ENTRY_RE = re.compile(
    r"SeedDomainScript\.new\(\s*"
    r"([A-Z][A-Z0-9_]*|0x[0-9A-Fa-f]+|\d+)\s*,\s*"
    r'"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*'
    r"(-?\d+)\s*\)",
    re.DOTALL,
)
INTEGER_LITERAL_RE = re.compile(r"-?(?:0x[0-9A-Fa-f]+|\d+)$")
NAMED_DOMAIN_RE = re.compile(r"SeedDomains\.([A-Z][A-Z0-9_]*)$")

DOMAIN_ARGUMENT_CALLS = (
    ("SeedDeriver.derive_u32", 2, "magic-seed-deriver-domain"),
    ("SeedDeriver.derive_state_words", 2, "magic-seed-deriver-domain"),
    ("SeedDeriver.random_unit", 2, "magic-seed-deriver-domain"),
    ("DeterministicRng.from_context", 2, "magic-deterministic-rng-domain"),
)
DOMAIN_LOOKUP_CALL = "SeedDomains.get_domain"


@dataclass(frozen=True)
class RegistryEntry:
    symbol: str
    domain_id: int | None
    readable_name: str
    revision: int
    line: int

    def as_machine_dict(self) -> dict:
        return {
            "symbol": self.symbol,
            "domain_id": None if self.domain_id is None else f"0x{self.domain_id:08x}",
            "readable_name": self.readable_name,
            "revision": self.revision,
            "line": self.line,
        }


@dataclass(frozen=True)
class Violation:
    code: str
    path: str
    line: int
    message: str

    def as_machine_dict(self) -> dict:
        return asdict(self)


def _line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def _parse_int_literal(value: str) -> int:
    return int(value, 0)


def parse_registry(text: str, path: str = str(REGISTRY_RELATIVE_PATH)) -> tuple[list[RegistryEntry], list[Violation]]:
    constants: dict[str, int] = {
        match.group(1): _parse_int_literal(match.group(2))
        for match in CONST_RE.finditer(text)
    }
    entries: list[RegistryEntry] = []
    violations: list[Violation] = []

    for match in ENTRY_RE.finditer(text):
        id_token, readable_name, revision_text = match.groups()
        line = _line_number(text, match.start())
        revision = int(revision_text)
        domain_id: int | None

        if INTEGER_LITERAL_RE.fullmatch(id_token):
            domain_id = _parse_int_literal(id_token)
            symbol = id_token
            violations.append(
                Violation(
                    "registry-magic-domain-id",
                    path,
                    line,
                    f"registry entry uses numeric domain ID directly: {id_token}",
                )
            )
        else:
            symbol = id_token
            domain_id = constants.get(symbol)
            if domain_id is None:
                violations.append(
                    Violation(
                        "registry-unknown-domain-symbol",
                        path,
                        line,
                        f"registry entry references undeclared domain constant: {symbol}",
                    )
                )

        if not readable_name:
            violations.append(
                Violation("empty-domain-name", path, line, "seed domain readable name is empty")
            )
        if revision <= 0:
            violations.append(
                Violation(
                    "non-positive-domain-revision",
                    path,
                    line,
                    f"seed domain revision must be positive: {symbol}={revision}",
                )
            )

        entries.append(RegistryEntry(symbol, domain_id, readable_name, revision, line))

    ids: dict[int, RegistryEntry] = {}
    names: dict[str, RegistryEntry] = {}
    for entry in entries:
        if entry.domain_id is not None:
            previous = ids.get(entry.domain_id)
            if previous is not None:
                violations.append(
                    Violation(
                        "duplicate-domain-id",
                        path,
                        entry.line,
                        (
                            f"domain ID 0x{entry.domain_id:08x} is shared by "
                            f"{previous.symbol} and {entry.symbol}"
                        ),
                    )
                )
            else:
                ids[entry.domain_id] = entry

        if entry.readable_name:
            previous_name = names.get(entry.readable_name)
            if previous_name is not None:
                violations.append(
                    Violation(
                        "duplicate-domain-name",
                        path,
                        entry.line,
                        (
                            f"readable name {entry.readable_name!r} is shared by "
                            f"{previous_name.symbol} and {entry.symbol}"
                        ),
                    )
                )
            else:
                names[entry.readable_name] = entry

    entries.sort(key=lambda entry: (entry.domain_id is None, entry.domain_id or 0, entry.symbol))
    return entries, violations


def _iter_calls(text: str, call_name: str):
    """Yield (line, argument_texts) for simple GDScript calls, honoring nesting/strings/comments."""
    cursor = 0
    marker = call_name + "("
    while True:
        start = text.find(marker, cursor)
        if start < 0:
            return
        open_paren = start + len(call_name)
        index = open_paren + 1
        depth = 0
        args: list[str] = []
        current: list[str] = []
        quote: str | None = None
        escaped = False
        comment = False

        while index < len(text):
            char = text[index]

            if comment:
                if char == "\n":
                    comment = False
                    current.append(char)
                index += 1
                continue

            if quote is not None:
                current.append(char)
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
                index += 1
                continue

            if char in ('"', "'"):
                quote = char
                current.append(char)
                index += 1
                continue
            if char == "#":
                comment = True
                index += 1
                continue
            if char in "([{":
                depth += 1
                current.append(char)
                index += 1
                continue
            if char in ")]}":
                if char == ")" and depth == 0:
                    args.append("".join(current).strip())
                    yield _line_number(text, start), args
                    cursor = index + 1
                    break
                depth -= 1
                current.append(char)
                index += 1
                continue
            if char == "," and depth == 0:
                args.append("".join(current).strip())
                current = []
                index += 1
                continue

            current.append(char)
            index += 1
        else:
            return


def _normalize_expression(value: str) -> str:
    return re.sub(r"\s+", "", value)


def audit_source_text(
    path: str,
    text: str,
    registered_symbols: set[str],
) -> list[Violation]:
    violations: list[Violation] = []

    for line, args in _iter_calls(text, DOMAIN_LOOKUP_CALL):
        if not args:
            continue
        expression = _normalize_expression(args[0])
        if INTEGER_LITERAL_RE.fullmatch(expression):
            violations.append(
                Violation(
                    "magic-domain-id-lookup",
                    path,
                    line,
                    f"SeedDomains.get_domain uses numeric ID directly: {expression}",
                )
            )
            continue
        named_match = NAMED_DOMAIN_RE.fullmatch(expression)
        if named_match and named_match.group(1) not in registered_symbols:
            violations.append(
                Violation(
                    "undeclared-domain-symbol",
                    path,
                    line,
                    f"SeedDomains.get_domain references unregistered symbol: {named_match.group(1)}",
                )
            )

    for call_name, domain_index, magic_code in DOMAIN_ARGUMENT_CALLS:
        for line, args in _iter_calls(text, call_name):
            if len(args) <= domain_index:
                continue
            domain_expression = _normalize_expression(args[domain_index])
            if INTEGER_LITERAL_RE.fullmatch(domain_expression):
                violations.append(
                    Violation(
                        magic_code,
                        path,
                        line,
                        f"{call_name} receives numeric domain directly: {domain_expression}",
                    )
                )
            elif domain_expression.startswith("SeedDomainScript.new(") or domain_expression.startswith("SeedDomain.new("):
                violations.append(
                    Violation(
                        "inline-seed-domain-construction",
                        path,
                        line,
                        f"{call_name} constructs a seed domain outside the registry",
                    )
                )

    return violations


def _tracked_files(root: Path) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z"],
            check=True,
            capture_output=True,
        )
        return sorted(
            item.decode("utf-8")
            for item in result.stdout.split(b"\0")
            if item
        )
    except (OSError, subprocess.CalledProcessError):
        return sorted(
            path.relative_to(root).as_posix()
            for path in root.rglob("*")
            if path.is_file()
        )


def audit_repository(root: Path) -> tuple[list[RegistryEntry], list[Violation], int]:
    registry_path = root / REGISTRY_RELATIVE_PATH
    registry_text = registry_path.read_text(encoding="utf-8")
    entries, violations = parse_registry(registry_text)
    registered_symbols = {entry.symbol for entry in entries if entry.domain_id is not None}

    scanned = 0
    for relative_path in _tracked_files(root):
        if not relative_path.startswith("worldgen/") or not relative_path.endswith(".gd"):
            continue
        if relative_path == REGISTRY_RELATIVE_PATH.as_posix():
            continue
        scanned += 1
        text = (root / relative_path).read_text(encoding="utf-8")
        violations.extend(audit_source_text(relative_path, text, registered_symbols))

    violations.sort(key=lambda item: (item.path, item.line, item.code, item.message))
    return entries, violations, scanned


def _machine_payload(
    entries: list[RegistryEntry],
    violations: list[Violation],
    scanned_files: int,
) -> dict:
    return {
        "schema": SCHEMA,
        "registry_entries": [entry.as_machine_dict() for entry in entries],
        "production_files_scanned": scanned_files,
        "violations": [violation.as_machine_dict() for violation in violations],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args(argv)

    try:
        entries, violations, scanned_files = audit_repository(args.root.resolve())
    except (OSError, ValueError) as exc:
        print("[SEED DOMAIN AUDIT] FAIL — audit could not initialize", file=sys.stderr)
        print(f"  - {exc}", file=sys.stderr)
        return 1

    if args.json_output:
        print(json.dumps(_machine_payload(entries, violations, scanned_files), sort_keys=True))
        return 1 if violations else 0

    if violations:
        print(f"[SEED DOMAIN AUDIT] FAIL — {len(violations)} violation(s)", file=sys.stderr)
        print(f"  schema: {SCHEMA}", file=sys.stderr)
        for violation in violations:
            print(
                f"  - {violation.code} {violation.path}:{violation.line} — {violation.message}",
                file=sys.stderr,
            )
        return 1

    print("[SEED DOMAIN AUDIT] PASS")
    print(f"  schema: {SCHEMA}")
    print(f"  registry entries: {len(entries)}")
    print(f"  production GDScript files scanned: {scanned_files}")
    print("  duplicate IDs/names: 0")
    print("  non-positive revisions: 0")
    print("  statically detectable magic/undeclared domain lookups: 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
