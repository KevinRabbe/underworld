# Underworld — Validation Suite Ownership and Intent Index

Status: **current-main validation ownership reference**

This document explains **what each major validation surface protects, which domain owns the invariant, and where a failure should be routed**. It complements [Validation Matrix](VALIDATION_MATRIX.md), which remains the operational reference for commands, cadence, path filters, cost classes, and exact-head execution guidance.

This index does not create acceptance gates, duplicate workflow command tables, or define a permanent workflow count. Executable runners and workflow YAML remain authoritative for what actually runs.

Current-main baseline used for this refresh: `29860a0ef8af1b823d929b665194be80b8477dc9`.

## Failure-routing vocabulary

Use these categories when a check fails:

- **Implementation defect** — the owning gameplay, content, worldgen, persistence, presentation, or tooling contract is violated by the candidate.
- **Integration / staleness** — preserved components or evidence no longer compose with the accepted baseline, or validation belongs to an older head/base.
- **Tooling / documentation debt** — a validator, report adapter, inspector, or reference document is stale while authoritative behavior intentionally remains correct.
- **Governance state** — required review/acceptance/process state is missing, stale, revoked, or not repository-enforced. Governance evidence is distinct from software correctness.

Route a failure to the invariant owner. Do not weaken the reporting aggregate or an unrelated suite merely because it is the first red check visible in CI.

## Ownership map

| Validation surface | Owning domain | What it protects | Failure routing |
| --- | --- | --- | --- |
| **Character Validation** | Player / combat / character gameplay | Character-state, movement/combat integration, mannequin/rig/socket contracts and gameplay ownership boundaries | Character/combat implementation or shared-contract integration |
| **Repository Layout Validation** | Repository architecture | Canonical roots, forbidden dependency directions, retired paths and explicit structural exceptions | Architecture/integration defect; validator debt only after an intentional architecture change |
| **Inventory Validation** | Inventory / item-state transactions | Container invariants, transaction atomicity, accepted equipment/hotbar state and accepted surface-harvest inventory integration | Inventory/equipment transaction implementation or HARVEST integration |
| **Cave Presentation Validation** | Cave presentation | Presentation/material/realization contracts that sit above semantic world truth | Presentation implementation/integration; do not rewrite worldgen semantics to satisfy appearance-only assumptions |
| **Deterministic Worldgen fast contracts** | World definition + runtime worldgen integration | Deterministic identity/RNG/provenance/topology/geometry/runtime contracts including MAP-014/MAP-015 ownership | Owning worldgen/runtime implementation or intentional-contract integration |
| **Deterministic Worldgen shard campaign** | Deterministic worldgen | Reproduction over the committed ten-shard seed/region campaign | Nondeterminism or generation regression unless an intentional versioned contract change was not propagated |
| **`Godot headless contracts` aggregate** | CI integration surface | Requires the shard matrix and current Content contracts to succeed | **Not a root-cause owner**; inspect the failed dependency and route there |
| **Content registry/family aggregate** | Authored semantic content | ContentId/schema/reference/family/rulebook contracts and accepted semantic realization boundaries | Content family, registry/schema or content-integration owner |
| **Cross-Region Validation** | Stage-4 cross-region graph ownership | Owner/reference endpoint structure, remote/local consistency and malformed-reference rejection | Connectivity/graph ownership implementation |
| **Graph Canonicalization Validation** | Deterministic graph representation | Order-invariant canonical graph text/fingerprints without source mutation | Canonicalization/deterministic graph implementation |
| **Seed Domain Audit** | Deterministic RNG-domain governance | Named, registry-backed persistent RNG domains and deterministic registry validity | RNG-domain call-site/registry implementation |
| **Surface Contract Validation** | Surface definition + pickup runtime boundary | Deterministic sampler behavior, coordinate boundaries, normalized fields, DTO ownership, non-mutating pickup discovery and StableId-compatible runtime identity | Surface sampler/runtime-contract implementation or HARVEST integration |
| **World Definition Service Validation** | World-definition service | Cache/request identity, descriptor lifecycle, ordering and negative-coordinate behavior | Service lifecycle/integration implementation |
| **Generator Manifest Validation** | Generator compatibility identity | Stage/profile/contract revision identity, ordering and invalid revision rejection | Manifest/versioning implementation |
| **TEST-056 Worldgen Edge Cases** | Worldgen edge replay / procedural identity | Fresh Stage-1→4 replay at signed/high-bit seeds and coordinate boundaries plus order invariance | Worldgen/StableAddress/StableId implementation or explicit compatibility revision |
| **Worldgen Purity Validation** | Worldgen architecture boundary | Pure-data production-worldgen boundary; rejects disallowed engine/runtime ownership crossing into deterministic definition code | Architecture/implementation boundary violation |
| **Map Data Serialization Validation** | Persistence / map data | Serialization schema, durable representation and round-trip compatibility | Persistence/schema/migration implementation |
| **Stable ID Audit** | StableAddress / StableId | Large deterministic identity corpus reproduction and collision resistance | Procedural identity implementation |
| **Worldgen Inspector Validation** | Developer tooling / inspection | Reproducible inspector/atlas/export schemas over worldgen data | Inspector/export tooling or adapter integration, not generator truth by default |
| **Worldgen Benchmark** | Diagnostic performance evidence | Fixed deterministic timing corpus and report schema | Benchmark/tooling or performance investigation; not semantic acceptance by itself |
| **Runtime Cave Performance Validation** | Runtime performance evidence | MAP-015 runtime cave profiling/report contract | Runtime performance investigation; not semantic correctness by itself |
| **PM Acceptance Gate** | Project governance | Exact-head PM acceptance metadata/status behavior | Governance state; never substitute it for domain validation |

The table is an ownership index, not an exhaustive list of every test file or workflow. New focused suites may be added without changing the principle: the invariant owner remains the diagnostic destination.

## Broad every-candidate surfaces

### Character Validation

Workflow: [`character-validation.yml`](../../.github/workflows/character-validation.yml)  
Runner: [`tests/run_character.gd`](../../tests/run_character.gd)

Character Validation owns the current Player/combat character spine and its cross-system gameplay contracts. It covers the accepted mannequin/rig/socket layer, action state, combat timing and integration boundaries represented by the current runner.

A failure here should normally be repaired in Character/combat code or in an intentionally changed shared contract. Do not make presentation hierarchy authoritative for gameplay simply to restore green CI.

### Repository Layout Validation

Workflow: [`repository-layout-validation.yml`](../../.github/workflows/repository-layout-validation.yml)

This is structural architecture evidence. It owns repository roots, dependency-policy boundaries and retired-path enforcement rather than gameplay behavior.

If a candidate introduces a forbidden dependency, repair the dependency. Add or relax a structural exception only when the architecture contract itself has intentionally changed.

### Inventory Validation

Workflow: [`inventory-validation.yml`](../../.github/workflows/inventory-validation.yml)  
Runner: [`tests/run_inventory.gd`](../../tests/run_inventory.gd)

The accepted Inventory surface owns item-container invariants and atomic inventory transactions, and it grows with accepted inventory-adjacent state such as equipment/hotbar contracts. At this baseline it also executes HARVEST-001 surface-harvest inventory integration, proving that accepted harvesting consumes INV-002 rather than mutating container state directly.

Transaction/container semantics remain Inventory-owned. HARVEST still owns its tool eligibility, hit/depletion sequencing and surface-world mutation integration. Diagnose whether a failed harvest path violated INV contracts or whether the accepted harvest integration itself is wrong; do not move transaction authority into the feature merely because the feature test exposed the failure.

### Cave Presentation Validation

Workflow: [`cave-presentation-validation.yml`](../../.github/workflows/cave-presentation-validation.yml)  
Runner: [`tests/run_cave_presentation.gd`](../../tests/run_cave_presentation.gd)

This suite owns the accepted cave presentation boundary: semantic cave output may be realized with materials/presentation details without making those details authoritative world identity or topology.

MAP-016 Marching-Cubes realization and PRESENTATION-001 are accepted-main context. A presentation failure should not be “fixed” by changing semantic topology, StableIds, fixture selectors, or deterministic world ownership unless an owning worldgen contract actually failed too.

## Deterministic Worldgen aggregate

Workflow: [`foundation-validation.yml`](../../.github/workflows/foundation-validation.yml)  
Runner: [`tests/run_validation.gd`](../../tests/run_validation.gd)

### Fast contracts

Every deterministic shard first runs `tests/run_validation.gd -- --mode=fast`. The fast surface composes many current-main invariants: deterministic identity/RNG, manifest/provenance, graph/topology/entrances/connectivity, cave geometry/cell partitioning, runtime-cell lifecycle, surface handoff, collision/readiness and accepted runtime integration fixtures.

The fast runner is a bundle of owners, not one monolithic owner. Route a failure to the named failing contract/domain.

### Ten-shard campaign

The workflow starts at seeds `1`, `26`, `51`, `76`, `101`, `126`, `151`, `176`, `201`, and `226`. Each shard runs 25 seeds over region radius 1, yielding the committed 2,250 seed/region deterministic campaign.

This campaign is broad reproduction evidence. Do not shrink seed counts, region coverage or equality checks to make a changed implementation pass. Intentional truth changes must travel through the owning compatibility/version/fixture contract.

### Stable aggregate

`Godot headless contracts` succeeds only after both:

1. the complete deterministic shard matrix succeeds; and
2. the current `Content registry contracts` job succeeds.

It is a stable umbrella result. It deliberately does **not** answer which subsystem caused a failure.

## Content registry and family contracts

Current job: `Content registry contracts` in [`foundation-validation.yml`](../../.github/workflows/foundation-validation.yml)  
Runner: [`tests/run_content.gd`](../../tests/run_content.gd)

The Content runner is a **growing aggregate**. At this baseline it includes registry, category/capability schema, semantic-role schema, validation-pipeline, archetype definition/realization, item, resource, creature, weapon, reserved-site assignment, underground placement and surface-harvest authored-content contracts. Those correspond to accepted boundaries including CONTENT-003/004/005, ARCHETYPE-001, ITEM-001, ANIM-001, RESOURCE-001, ENEMY-001, WEAPON-001, CONTENT-001, CONTENT-002 and HARVEST-001, but this list is illustrative rather than a forever-exhaustive child inventory.

Content ownership includes:

- semantic authored ContentIds independent of filesystem path;
- deterministic registry and typed-reference behavior;
- controlled category/capability/semantic-role schema vocabularies;
- family rulebooks and family-specific validator composition;
- semantic definition/realization separation;
- additive extension without converting one family into authority over another.

When a family is added, wire it through the accepted validation pipeline/runner rather than bypassing generic rules. Do not solve one authored-definition failure by weakening duplicate-ID, unknown-schema, typed-reference, category/capability or family-rule checks globally.

## Specialized deterministic and architecture suites

### Cross-Region Validation

Workflow: [`cross-region-validation.yml`](../../.github/workflows/cross-region-validation.yml)  
Runner: [`tests/run_cross_region_validation.gd`](../../tests/run_cross_region_validation.gd)

Owns Stage-4 cross-region owner/reference structure for real generated and deliberately malformed cases. Failures route to connectivity/graph ownership, not to UI or presentation.

### Graph Canonicalization Validation

Workflow: [`graph-canonicalization-validation.yml`](../../.github/workflows/graph-canonicalization-validation.yml)  
Runner: [`tests/run_graph_canonicalization.gd`](../../tests/run_graph_canonicalization.gd)

Owns permutation/order invariance of canonical graph representation and fingerprints. A failure is a deterministic graph/canonicalization defect unless an explicit logical-content change is expected to alter identity.

### Seed Domain Audit

Workflow: [`seed-domain-audit.yml`](../../.github/workflows/seed-domain-audit.yml)  
Audit: [`tools/ci/seed_domain_audit.py`](../../tools/ci/seed_domain_audit.py)

Owns persistent RNG-domain naming/registry discipline. Magic numeric/undeclared persistent domains, duplicate registry identity, or invalid revisions belong to seed-domain implementation ownership.

### Surface Contract Validation

Workflow: [`surface-contract-validation.yml`](../../.github/workflows/surface-contract-validation.yml)  
Runner: [`tests/run_surface_contract.gd`](../../tests/run_surface_contract.gd)

This suite owns both the deterministic surface sampler contract and the accepted HARVEST-001 pickup-runtime handoff. The sampler side covers positive/negative coordinate-boundary behavior, finite normalized fields and pure-data DTO ownership. The pickup-runtime side proves discovery is repeatable and non-mutating, excludes destroyed candidates, and preserves StableId-compatible candidate identity/order including negative-coordinate cases.

Surface sampler defects remain surface-definition ownership. Pickup discovery/runtime-identity failures route to the surface-runtime/HARVEST integration boundary. Neither should be redirected to underground presentation merely because cave entrances also consume surface data.

### World Definition Service Validation

Workflow: [`world-definition-service-validation.yml`](../../.github/workflows/world-definition-service-validation.yml)  
Runner: [`tests/run_world_definition_service.gd`](../../tests/run_world_definition_service.gd)

Owns world-definition cache/request/descriptor lifecycle and deterministic ordering. Failures route to the service boundary or its explicit integration contract.

### Generator Manifest Validation

Workflow: [`generator-manifest-validation.yml`](../../.github/workflows/generator-manifest-validation.yml)  
Runner: [`tests/run_generator_manifest.gd`](../../tests/run_generator_manifest.gd)

Owns generator compatibility identity: stage/profile/contract revisions, insertion-order invariance, copy isolation and rejection of invalid revisions. Do not hide compatibility changes by suppressing manifest identity changes.

### TEST-056 Worldgen Edge Case Validation

Workflow: [`worldgen-edge-case-validation.yml`](../../.github/workflows/worldgen-edge-case-validation.yml)  
Runner: [`tests/worldgen_edge_cases/run_worldgen_edge_cases.gd`](../../tests/worldgen_edge_cases/run_worldgen_edge_cases.gd)

TEST-056 is **accepted current-main evidence**. It owns genuinely fresh Stage-1→4 replay across the committed signed/high-bit seed and coordinate-edge corpus, including the four cardinal neighbor views needed by Stage 4, execution-order invariance and StableAddress/StableId canonical behavior.

Do not describe this as an audit-branch-only candidate and do not replace its committed selectors with invented “representative” values.

### Worldgen Purity Validation

Workflow: [`worldgen-purity-validation.yml`](../../.github/workflows/worldgen-purity-validation.yml)  
Guard: [`tools/ci/worldgen_purity_guard.py`](../../tools/ci/worldgen_purity_guard.py)  
Fixtures/tests: [`tools/ci/test_worldgen_purity_guard.py`](../../tools/ci/test_worldgen_purity_guard.py)

The purity guard scans production `worldgen/**` and owns the pure-data architectural boundary. Engine/runtime ownership that violates the allowed deterministic-definition boundary is an architecture defect, not something to waive locally for convenience.

## Persistence, identity and tooling evidence

### Map Data Serialization Validation

Workflow: [`map-data-serialization-validation.yml`](../../.github/workflows/map-data-serialization-validation.yml)  
Runner: [`tests/run_map_data_serialization_validation.gd`](../../tests/run_map_data_serialization_validation.gd)

Owns durable map-data serialization/round-trip compatibility. Intentional schema changes require their owning migration/versioning response; do not delete compatibility assertions simply to accept incompatible saved state.

### Stable ID Audit

Workflow: [`stable-id-audit.yml`](../../.github/workflows/stable-id-audit.yml)  
Runner: [`tools/stable_id_audit/run_stable_id_audit.gd`](../../tools/stable_id_audit/run_stable_id_audit.gd)

Owns large-corpus StableAddress/StableId reproduction and collision resistance. A collision or reproduction failure belongs to procedural identity unless the audit itself is demonstrably stale.

### Worldgen Inspector Validation

Workflow: [`worldgen-inspector-validation.yml`](../../.github/workflows/worldgen-inspector-validation.yml)

Owns inspector/atlas/export tooling schemas and reproducible diagnostic exports. Inspector output may expose a generator defect, but the inspector is not authoritative world truth. If generator truth intentionally changes while remaining contract-correct, update the tooling adapter/export contract instead of forcing generation to preserve obsolete visualization assumptions.

## Runtime fixture ownership

### MAP-014 / MAP-015

MAP-014 and MAP-015 are accepted current-main runtime integration evidence embedded in the deterministic fast suite, with focused reproduction modes available through `tests/run_validation.gd`.

Their ownership includes runtime-cell lifecycle/stale-result rejection, collision/traversal readiness, deterministic runtime-harness behavior and the committed MAP-015 bootstrap fixture/route/rebuild semantics.

MAP-016 is also accepted-main: it replaced the cave realization representation without redefining the protected MAP-015 semantic selector. If a representation change breaks collision readiness, stale-result behavior, ownership or fixture reproducibility, route the failure to runtime/geometry integration rather than changing the selector.

Manual OBS-001 remains separate observation evidence; it is not a substitute for deterministic automation.

## Diagnostic performance evidence

### Deterministic Worldgen Benchmark

Workflow: [`worldgen-benchmark.yml`](../../.github/workflows/worldgen-benchmark.yml)  
Runner: [`tools/worldgen_benchmark/run_worldgen_benchmark.gd`](../../tools/worldgen_benchmark/run_worldgen_benchmark.gd)

The benchmark executes a fixed 20-case deterministic corpus and validates its report schema/stage timing summaries. It is useful for regression investigation and performance evidence, but a timing report is not semantic correctness authority.

### Runtime Cave Performance Validation

Workflow: [`runtime-performance-validation.yml`](../../.github/workflows/runtime-performance-validation.yml)  
Runner: [`tests/run_performance.gd`](../../tests/run_performance.gd)

This surface profiles the accepted MAP-015 runtime cave path and preserves the performance report contract. PERF-001 and PERF-002 are accepted-main optimization context at this baseline, but performance evidence still does not replace deterministic, collision, presentation or runtime correctness contracts.

## Governance evidence

### PM Acceptance Gate

Workflow: [`pm-acceptance-gate.yml`](../../.github/workflows/pm-acceptance-gate.yml)  
Governance reference: [Main Merge Gate](MAIN_MERGE_GATE.md)

PM acceptance is exact-head process evidence. It coordinates stale/revoked/accepted state but does not prove game correctness.

Repository-side `main` branch protection is **not enabled** at this baseline; owner configuration task #118 remains blocked. Do not interpret operational PM acceptance/status publication as equivalent to server-enforced branch protection.

Therefore:

- green PM acceptance never substitutes for Character, Layout, Inventory, Presentation, Worldgen, Content or specialized domain validation;
- stale-head acceptance must not be reused after synchronization;
- a governance failure should not be “repaired” by weakening software tests;
- a software failure should not be dismissed merely because PM metadata is green.

## Failure patterns that must not be solved by weakening validation

- StableId collisions must not be hidden by removing corpus cases.
- Duplicate/unknown content or schema identity must not become silent first/last-wins behavior.
- Category ancestry, capability implication or semantic-role errors must not be accepted because one authored definition needs them.
- Deterministic mismatches must not be hidden by reducing shard/seed/region coverage.
- TEST-056 failures must not be hidden by reusing cached stages where the contract requires fresh replay.
- Cross-region malformed ownership/reference data must continue to fail closed.
- Graph-order dependence must not be normalized away by mutating source fixtures.
- Stale runtime results must not be accepted by weakening generation/source ownership checks.
- MAP-015 collision/traversal readiness must not be treated as presentation-only.
- Purity violations must not be waived by moving engine ownership into deterministic world-definition code.
- Inventory consumers must not bypass atomic transaction authority to make a feature test pass.
- Serialization incompatibility must not be hidden by deleting migration/round-trip assertions.
- Presentation tests must not redefine semantic world identity.
- Performance/benchmark regressions must not be used as justification to remove deterministic parity checks.
- Missing PM acceptance must not be bypassed using an older head/status.

## Choosing the owning suite

A PR may legitimately exercise several surfaces. Diagnose each failure by **the invariant being protected**, not by the workflow name that happened to become red first.

Examples:

- A loot collection failure caused by non-atomic inventory mutation belongs to the Inventory transaction boundary even if a loot-focused test exposed it.
- A cave material failure with unchanged topology belongs to Cave Presentation, not deterministic topology.
- A generator fingerprint mismatch belongs to the relevant generator/identity contract even if `Godot headless contracts` is the only visible aggregate failure.
- A content definition that violates generic item rules belongs to the Content/item rule stack, not to whichever gameplay feature authored the file.

For practical execution commands, trigger/cadence selection and exact-head evidence requirements, use [Validation Matrix](VALIDATION_MATRIX.md). For structural constraints, use [Repository Layout Validation](REPOSITORY_LAYOUT_VALIDATION.md). For deterministic fixture selectors, use [Deterministic Fixture Catalog](DETERMINISTIC_FIXTURE_CATALOG.md). For merge-process semantics, use [Main Merge Gate](MAIN_MERGE_GATE.md).

## Freshness rule

This index describes ownership on the baseline named above. When current `main` adds or retires a validation surface, update this ownership reference by meaning, not by maintaining a hard-coded workflow total. Executable workflow/runners remain authoritative when documentation and code temporarily disagree.
