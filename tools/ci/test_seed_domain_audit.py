#!/usr/bin/env python3
"""Focused contracts for seed_domain_audit.py."""

from __future__ import annotations

import json

import seed_domain_audit as audit


VALID_REGISTRY = """extends RefCounted
const SeedDomainScript := preload(\"res://worldgen/random/seed_domain.gd\")
const DOMAIN_A: int = 0x010001
const DOMAIN_B: int = 0x010002
static func all_domains() -> Array:
    return [
        SeedDomainScript.new(DOMAIN_B, \"test.b\", 2),
        SeedDomainScript.new(DOMAIN_A, \"test.a\", 1),
    ]
"""


def codes(violations: list[audit.Violation]) -> set[str]:
    return {violation.code for violation in violations}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def test_valid_registry_and_machine_order() -> None:
    entries, violations = audit.parse_registry(VALID_REGISTRY, "fixture/seed_domains.gd")
    require(not violations, f"valid registry produced violations: {violations}")
    require([entry.symbol for entry in entries] == ["DOMAIN_A", "DOMAIN_B"], "registry machine order is not stable by numeric ID")

    payload = audit._machine_payload(entries, [], 7)
    require(payload["schema"] == "seed-domain-audit-v1", "machine schema changed unexpectedly")
    require(payload["registry_entries"][0] == {
        "symbol": "DOMAIN_A",
        "domain_id": "0x00010001",
        "readable_name": "test.a",
        "revision": 1,
        "line": 8,
    }, "machine registry entry shape changed unexpectedly")
    json.dumps(payload, sort_keys=True)


def test_duplicate_id_rejected() -> None:
    text = VALID_REGISTRY.replace("const DOMAIN_B: int = 0x010002", "const DOMAIN_B: int = 0x010001")
    _, violations = audit.parse_registry(text, "fixture/seed_domains.gd")
    require("duplicate-domain-id" in codes(violations), "duplicate numeric domain ID was not rejected")


def test_duplicate_name_rejected() -> None:
    text = VALID_REGISTRY.replace('"test.b"', '"test.a"')
    _, violations = audit.parse_registry(text, "fixture/seed_domains.gd")
    require("duplicate-domain-name" in codes(violations), "duplicate readable domain name was not rejected")


def test_non_positive_revision_rejected() -> None:
    text = VALID_REGISTRY.replace('SeedDomainScript.new(DOMAIN_A, "test.a", 1)', 'SeedDomainScript.new(DOMAIN_A, "test.a", 0)')
    _, violations = audit.parse_registry(text, "fixture/seed_domains.gd")
    require("non-positive-domain-revision" in codes(violations), "zero revision was not rejected")

    text = VALID_REGISTRY.replace('SeedDomainScript.new(DOMAIN_A, "test.a", 1)', 'SeedDomainScript.new(DOMAIN_A, "test.a", -3)')
    _, violations = audit.parse_registry(text, "fixture/seed_domains.gd")
    require("non-positive-domain-revision" in codes(violations), "negative revision was not rejected")


def test_direct_registry_numeric_id_rejected() -> None:
    text = VALID_REGISTRY.replace("SeedDomainScript.new(DOMAIN_A", "SeedDomainScript.new(0x010001")
    _, violations = audit.parse_registry(text, "fixture/seed_domains.gd")
    require("registry-magic-domain-id" in codes(violations), "numeric ID inside registry entry was not rejected")


def test_magic_and_unknown_callsites_rejected() -> None:
    registered = {"DOMAIN_A", "DOMAIN_B"}
    source = """extends RefCounted
func probe(address) -> void:
    var a = SeedDomains.get_domain(0x010001)
    var b = SeedDomains.get_domain(SeedDomains.NOT_REGISTERED)
    var c = SeedDeriver.random_unit(
        42,
        address,
        0x010002,
        \"probe\"
    )
"""
    violations = audit.audit_source_text("worldgen/probe.gd", source, registered)
    found = codes(violations)
    require("magic-domain-id-lookup" in found, "numeric get_domain lookup was not reported")
    require("undeclared-domain-symbol" in found, "unknown named domain lookup was not reported")
    require("magic-seed-deriver-domain" in found, "numeric SeedDeriver domain was not reported")


def test_named_registry_callsites_pass() -> None:
    registered = {"DOMAIN_A", "DOMAIN_B"}
    source = """extends RefCounted
func probe(address) -> float:
    return SeedDeriver.random_unit(
        42,
        address,
        SeedDomains.get_domain(SeedDomains.DOMAIN_A),
        \"probe\"
    )
"""
    violations = audit.audit_source_text("worldgen/probe.gd", source, registered)
    require(not violations, f"valid named domain call produced violations: {violations}")


def main() -> int:
    tests = [
        test_valid_registry_and_machine_order,
        test_duplicate_id_rejected,
        test_duplicate_name_rejected,
        test_non_positive_revision_rejected,
        test_direct_registry_numeric_id_rejected,
        test_magic_and_unknown_callsites_rejected,
        test_named_registry_callsites_pass,
    ]
    for test in tests:
        test()

    print("[SEED DOMAIN AUDIT TEST] PASS")
    print(f"  focused contracts: {len(tests)}")
    print("  duplicate ID/name and revision failures detected")
    print("  magic/undeclared call-site diagnostics detected")
    print("  machine registry schema/order stable")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
