# Underworld — Validation Suite Ownership and Intent Index

Status: **current-main validation ownership reference**

This document explains **what each major validation suite proves, which domain owns the invariant, and how failures should be routed**. It complements [Validation Matrix](VALIDATION_MATRIX.md), which remains the quick-reference source for local commands, cost classes, workflow triggers, and exact-head execution guidance.

This index does not create acceptance gates or redefine test behavior. Executable runners and workflow YAML remain authoritative for what actually runs.

Current-main baseline used for this index: `64d32b691ea5e730534930ee47a08841e23f8d09`.

## Failure-routing vocabulary

Use these categories when a suite fails:

- **Implementation defect** — the owning production/domain contract is violated by the candidate implementation.
- **Integration / staleness** — individually valid components or preserved evidence no longer compose against the current accepted baseline, or exact-head evidence is stale after a branch/base change.
- **Tooling / documentation debt** — the validator, inspector, report contract, or documentation index is outdated while the underlying authoritative behavior is intentionally correct.
- **Governance state** — merge/process authorization is absent, stale, revoked, or not enforceable. This is distinct from software correctness.

A failure should be routed to the owner of the invariant. Do not weaken an owning test merely because an unrelated feature wants a green check.

## Current-main suite index

| Suite / evidence | Owning domain | What it protects | Evidence class | Typical failure routing |
| --- | --- | --- | --- | --- |
| **Character contracts** | Character / combat / player gameplay | Prototype mannequin/rig/socket contracts, action state, stamina/dodge/parry/block, attack phases, input buffering, player/Burrower combat integration, gameplay ownership boundaries | Broad every-PR headless contract | Usually implementation defect in character/combat integration; occasionally integration staleness after an intentional shared-contract change |
| **Repository layout contracts** | Repository architecture / dependency policy | Canonical roots, retired paths, forbidden dependency directions, explicit migration exceptions | Fast structural every-PR check | Structural/dependency violation = implementation/integration defect; obsolete validator/policy text = tooling/docs debt |
| **Deterministic Worldgen fast runner** | Deterministic world definition + runtime integration contracts | Identity, RNG, manifests, provenance, topology, entrances, connectivity, cave/geometry cells, runtime-cell lifecycle, collision/readiness, runtime harness and MAP-015 bootstrap contracts | Fast headless contract executed in every worldgen shard | Implementation defect in owning worldgen/runtime contract or integration staleness against accepted upstream truth |
| **Deterministic Worldgen ten-shard campaign** | Deterministic worldgen | Reproduction over ten 25-seed shards and a 3x3 region neighborhood per seed: 2,250 seed/region cases total | Broad deterministic campaign | Nondeterminism/generation defect unless an intentional contract revision was not propagated through fixtures/evidence |
| **`Godot headless contracts` aggregate** | CI integration surface | Requires both the deterministic shard matrix and the complete content-contract job to succeed | Stable umbrella merge check | Do not diagnose from aggregate alone; inspect the failed dependency and route to that domain |
| **Content registry + schema contracts** | Authored content core / semantic identity / category-capability schemas | Semantic ContentId validity, path independence, deterministic definition indexing, typed references, category ancestry, capability composition, schema-ID separation and deterministic schema registries | Focused headless contract, included in broad aggregate | Content-core/schema implementation or integration defect; validator debt only when authoritative content rules intentionally changed |
| **MAP-014 / MAP-015 runtime integration contracts** | Underworld runtime streaming / collision / traversal readiness | Runtime-cell lifecycle, stale-result rejection, deterministic runtime-harness fingerprint/counters, entrance collision gate readiness, MAP-015 bootstrap/route/rebuild behavior | Current-main tests inside deterministic fast runner; focused modes also exist | Runtime/streaming/collision implementation defect or integration staleness; not a presentation-only failure |
| **Map Data Serialization contracts** | Persistence / map-data serialization | Persistence serialization schema and round-trip/contract behavior under `worldgen/persistence/**` | Path-filtered focused workflow | Persistence implementation/migration/fixture integration defect; tooling debt only if the executable validator itself is stale |
| **Worldgen Inspector contracts and exports** | Developer tooling / worldgen inspection | Topology inspector/atlas contracts and reproducible JSON/SVG snapshot/atlas exports, including expected schemas and region-frame counts | Path-filtered focused tooling workflow | Inspector/export tooling defect or integration with changed worldgen data; not authority to rewrite generator truth |
| **Stable ID Audit** | Deterministic procedural identity | Large StableAddress/StableId corpus reproduction and collision resistance across required address families | Specialized path-filtered audit; 34,969 accepted cases | Identity implementation defect unless audit/report tooling is demonstrably stale |
| **Operational PM acceptance** | Repository governance / PM process | Exact-head acceptance state, stale-label invalidation, draft/revocation behavior | Operational status publisher, not software validation | Governance state or gate implementation defect; a green status does not prove game/test correctness |

For commands and trigger details, use [Validation Matrix](VALIDATION_MATRIX.md) rather than copying command tables here.

## Character contracts

Current workflow: [`character-validation.yml`](../../.github/workflows/character-validation.yml)  
Runner: [`tests/run_character.gd`](../../tests/run_character.gd)

The suite protects the current character/gameplay spine, including:

- articulated mannequin, rig/socket and placeholder-pose contracts;
- stamina, dodge, parry and block action contracts;
- player defensive melee and guard-break integration;
- Burrower defense interactions;
- phased startup/active/recovery attack contracts;
- one-slot expiring combat input buffering;
- combat resolution versus encounter ownership;
- surface streaming/prototype survival ownership boundaries.

**Do not fix a failure** by loosening combat timing/state ownership, skipping an integration case, or making presentation hierarchy authoritative for gameplay. Route real behavior regressions to character/combat implementation.

Architecture pointer: [Prototype Character](../PROTOTYPE_CHARACTER.md).

## Repository layout contracts

Current workflow: [`repository-layout-validation.yml`](../../.github/workflows/repository-layout-validation.yml)  
Detailed policy: [Repository Layout Validation](REPOSITORY_LAYOUT_VALIDATION.md)

This suite owns repository structure and dependency-policy enforcement, not gameplay behavior. A candidate that introduces a forbidden dependency or retired root should normally change its implementation, not add a convenient validator exception.

Treat an exception/policy mismatch as tooling/documentation debt only when the architecture owner has intentionally changed the structural contract.

## Deterministic Worldgen fast and campaign evidence

Current workflow: [`foundation-validation.yml`](../../.github/workflows/foundation-validation.yml)  
Runner: [`tests/run_validation.gd`](../../tests/run_validation.gd)

### Fast runner

The current fast runner composes tests for deterministic identity/RNG, manifest/graph and legacy migration behavior, service boundaries, provenance, topology, entrances, connectivity, cave geometry, geometry-cell partitioning, cave mesh realization, runtime-cell lifecycle, surface-entrance integration, collision/readiness, runtime validation harness, cave runtime controller and MAP-015 runtime bootstrap.

A green fast runner therefore proves a **bundle of current-main contracts**. It does not transfer ownership of all of those domains to one monolithic test system.

### Ten-shard campaign

The workflow starts shards at seeds `1, 26, 51, 76, 101, 126, 151, 176, 201, 226`. Each shard checks 25 seeds across radius 1, which is a 3x3 region neighborhood. The complete configured campaign therefore covers **2,250 seed/region cases**.

This is broad reproduction evidence. Do not reduce seed counts, region coverage, or deterministic equality assertions to make a changed generator pass. If a deliberate generator-contract revision changes expected truth, update the owning version/fixture/migration contract explicitly.

Architecture pointers: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md).

## Stable `Godot headless contracts` aggregate

The current `foundation-validation.yml` publishes `Godot headless contracts` only after:

1. the full deterministic shard matrix succeeds; and
2. the current content-contract job succeeds.

The aggregate is a stable integration status, **not a root-cause suite**. When it fails, inspect the dependency result first rather than changing the aggregate job or treating every failure as worldgen-owned.

## Content registry and schema contracts

Current workflow job: `Content registry contracts` inside [`foundation-validation.yml`](../../.github/workflows/foundation-validation.yml)  
Runner: [`tests/run_content.gd`](../../tests/run_content.gd)  
Schema-registry tests: [`test_content_schema_registries.gd`](../../tests/content/test_content_schema_registries.gd)

The job now composes the accepted CONTENT-003 / #82 registry contracts with accepted CONTENT-004 / #83 category/capability schema contracts.

Registry coverage includes:

- semantic authored IDs rather than filesystem or procedural identity;
- path-independent definition identity;
- deterministic definition registry ordering/logical results;
- hard duplicate rejection;
- typed family/reference validation;
- missing/wrong-target diagnostics and optional references.

Schema coverage includes:

- category/capability SchemaId namespace separation from ordinary authored ContentIds;
- deterministic category ancestry and registration-order independence;
- category eligibility over explicit ancestry closure;
- rejection of duplicate IDs, unknown parent references and ancestry cycles;
- deterministic capability composition/closure and registration-order independence;
- clear rejection of invalid/duplicate/unknown capability schema relationships;
- content-definition category/capability declarations validated against the schema registries.

Do not make duplicate definitions/schemas first/last-wins, collapse schema IDs into ordinary ContentIds, accept unknown ancestry/composition references, or weaken typed-reference/category/capability checks to accommodate one definition.

Architecture pointers: [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md), [Content Registry](../10_architecture/CONTENT_REGISTRY.md), [Content IDs](../40_content/CONTENT_IDS.md), [Content References](../40_content/CONTENT_REFERENCES.md), [Content Categories](../40_content/CONTENT_CATEGORIES.md), [Content Capabilities](../40_content/CONTENT_CAPABILITIES.md).

## MAP-014 / MAP-015 runtime integration evidence

These are **already current-main contracts** represented inside the deterministic fast runner; they are not separate top-level workflow checks.

Relevant current-main tests include:

- [`test_runtime_cell_lifecycle.gd`](../../tests/geometry/test_runtime_cell_lifecycle.gd);
- [`test_surface_entrance_integration.gd`](../../tests/geometry/test_surface_entrance_integration.gd);
- [`test_collision_and_gate.gd`](../../tests/geometry/test_collision_and_gate.gd);
- [`test_runtime_validation_harness.gd`](../../tests/geometry/test_runtime_validation_harness.gd);
- [`test_cave_runtime_controller.gd`](../../tests/geometry/test_cave_runtime_controller.gd);
- [`test_map015_runtime_bootstrap.gd`](../../tests/geometry/test_map015_runtime_bootstrap.gd);
- [`test_map015_fixture.gd`](../../tests/geometry/test_map015_fixture.gd).

The deterministic runtime harness checks reproducible fingerprinting plus meaningful queued/ready/stale-discard/release counters. MAP-015 bootstrap validation checks render/collision realization, entrance-gate readiness, traversal across required runtime cells, no stale-result resurrection, retained runtime ownership and reproducible rebuild fingerprinting.

`tests/run_validation.gd` also exposes focused `runtime-harness` and `map015-fixture` modes for targeted evidence.

Do not weaken stale-discard, collision-gate, ownership, route or deterministic-fingerprint assertions merely to accommodate a new runtime representation. If an accepted upstream contract changed, synchronize the runtime integration deliberately.

## Map Data Serialization contracts

Current workflow: [`map-data-serialization-validation.yml`](../../.github/workflows/map-data-serialization-validation.yml)  
Runner: [`tests/run_map_data_serialization_validation.gd`](../../tests/run_map_data_serialization_validation.gd)

This is path-filtered persistence evidence. Failures belong first to persistence serialization/schema/migration ownership, not to general worldgen or presentation.

A changed durable format should update its owning compatibility/migration contract. Do not simply relax round-trip or schema assertions to hide incompatible state.

Architecture pointer: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md).

## Worldgen Inspector validation

Current workflow: [`worldgen-inspector-validation.yml`](../../.github/workflows/worldgen-inspector-validation.yml)

The current job checks:

- topology inspector contracts;
- multi-region atlas contracts;
- sample JSON/SVG topology snapshot export;
- sample 3x3 JSON/SVG atlas export;
- X/Z elevation exports;
- expected export schema markers and region-frame counts.

This is developer-tooling evidence over worldgen data. The inspector may reveal a generation problem, but the inspector is not authoritative world truth. If generator data intentionally changes while remaining contract-correct, update the tooling adapter/export contract rather than changing generation solely to preserve an obsolete visualization.

## Stable ID Audit

Current workflow: [`stable-id-audit.yml`](../../.github/workflows/stable-id-audit.yml)  
Runner: [`tools/stable_id_audit/run_stable_id_audit.gd`](../../tools/stable_id_audit/run_stable_id_audit.gd)

Accepted through ID-058 / #59, the specialized audit requires:

- 34,969 expected cases and 34,969 actual cases;
- 34,969 reproduction checks;
- zero StableId collisions;
- zero failures;
- the complete required address-family set;
- positive endpoint-order coverage.

This is deeper procedural-identity evidence than the ordinary fast suite, but it is path-filtered rather than an every-PR gate.

Do not shrink the corpus or collision/reproduction requirements to mask an identity regression. A genuine collision or reproduction failure belongs to StableAddress/StableId implementation ownership unless the audit itself is demonstrably wrong.

## Operational PM acceptance

Current workflow: [`pm-acceptance-gate.yml`](../../.github/workflows/pm-acceptance-gate.yml)  
Governance contract: [Main Merge Gate](MAIN_MERGE_GATE.md)

This workflow coordinates exact-head PM metadata/status behavior. A synchronized new head is fail-closed until explicit acceptance, stale `pm-accepted` state is invalidated, draft/lifecycle transitions cannot manufacture acceptance, and only an explicit valid acceptance event can publish success for the exact head.

This is **governance evidence, not game/test correctness**.

The workflow itself documents that the `PM acceptance` context is an operational same-principal guard and is not cryptographically isolated from every other same-repository GitHub Actions principal. Repository-owner branch/ruleset enforcement is a separate governance requirement.

Therefore:

- green PM acceptance does not substitute for Character, Layout, Worldgen, Content or specialized domain checks;
- failed PM acceptance usually means missing/stale/revoked governance state, not broken gameplay;
- do not bypass the workflow by treating a stale label or old-head status as equivalent acceptance.

## Current-main versus pending / parked evidence

### Generation Debug Report — pending, not current-main validation

MAP-007 / #29 and draft PR #31 preserve a generation-debug report workflow/tooling change, but that branch still requires post-M2 synchronization and exact-head revalidation. Its proposed `generation-debug-report-validation.yml` is therefore **not current-main validation evidence**.

Until accepted and merged, describe it as parked/pending tooling only. Do not cite the preserved old green head as a current gate.

### MAP-016 protected Codex candidate — read-only status here

MAP-016 / #159 owns the protected deterministic Marching-Cubes realization. Its branch-specific implementation and candidate tests are **not current-main accepted validation** until the protected task is independently accepted and merged.

Current-main cave-mesh/runtime tests continue to protect the accepted M2 baseline and existing runtime integration contracts. This index does not define, expand or weaken MAP-016 acceptance criteria; #159 and the PM board own that protected contract.

### Preserved post-M2 audit branches

Preserved audit/validation branches may contain valuable historical evidence, but pre-refresh green heads are not current-main acceptance. A refreshed audit becomes current evidence only after it is synchronized, its logical scope is preserved, and the required exact-head checks pass.

## Examples of failures that must not be solved by weakening the test

- A StableId collision must not be hidden by removing the colliding corpus case.
- Duplicate content or schema IDs must not be converted to implicit first/last-wins behavior.
- Unknown category ancestry, capability composition references, or schema cycles must not be silently accepted.
- A deterministic mismatch must not be hidden by reducing seeds/regions or comparing less state without an owning contract change.
- A stale runtime result must not be accepted by lowering stale-discard or ownership expectations.
- An entrance collision gate that loses readiness during the MAP-015 route must not be treated as a presentation issue.
- A forbidden repository dependency must not be legalized with an ad-hoc exception unless architecture explicitly changes.
- A serialization incompatibility must not be hidden by deleting migration/round-trip assertions.
- A broken inspector export should not force generator semantics to match an obsolete visualization if the generator contract is intentionally correct.
- Missing PM acceptance must not be bypassed by reusing a status from an older PR head.

## Choosing the owning suite

When a PR changes several layers, more than one suite may legitimately be relevant. Route each failure by the invariant it protects rather than by whichever workflow happened to report red first.

For practical command/trigger selection and exact-head evidence rules, use [Validation Matrix](VALIDATION_MATRIX.md). For structural policy, use [Repository Layout Validation](REPOSITORY_LAYOUT_VALIDATION.md). For merge-governance semantics, use [Main Merge Gate](MAIN_MERGE_GATE.md).

### Documentation freshness note

At the baseline used for this index, the executable repository contains seven workflow files, including the accepted Stable ID Audit and operational PM acceptance workflow. `VALIDATION_MATRIX.md` still states an older five-workflow inventory. That mismatch is **documentation debt**, not a reason to omit current executable suites from this index. Updating the matrix itself is outside QA-001's one-file scope.

## Review invariant

A validation result should answer three separate questions explicitly:

1. **What invariant did this suite actually prove or fail?**
2. **Which domain owns that invariant?**
3. **Is the failure implementation, integration/staleness, tooling/docs debt, or governance state?**

Keeping those questions separate prevents unrelated teams from weakening tests, avoids treating tooling as world truth, and prevents governance status from being mistaken for software correctness.
