# Underworld — Validation Suite Ownership and Intent Index

Status: **current-main validation ownership reference**

This document explains **what each major validation surface protects, which domain owns the invariant, and where a failure should be routed**. It complements [Validation Matrix](VALIDATION_MATRIX.md), which remains the operational reference for commands, cadence, path filters, cost classes, and exact-head execution guidance.

This index does not create acceptance gates, duplicate workflow command tables, or define a permanent workflow count. Executable runners and workflow YAML remain authoritative for what actually runs.

Current-main baseline used for this refresh: `7d444b3540ee424da67a5b92bb8c50c4a0ae645b`.

## Failure-routing vocabulary

Use these categories when a check fails:

- **Implementation defect** — the owning gameplay, content, worldgen, persistence, presentation, or tooling contract is violated by the candidate.
- **Integration / staleness** — individually valid components, frozen evidence, or path-trigger coverage no longer compose with the accepted baseline.
- **Tooling / documentation debt** — a validator, report adapter, inspector, workflow dependency list, or reference document is stale while authoritative behavior intentionally remains correct.
- **Governance state** — required review/acceptance/process state is missing, stale, revoked, or not repository-enforced. Governance evidence is distinct from software correctness.

Route a failure to the invariant owner. A workflow that dispatches another domain's runner is **coverage evidence**, not a transfer of semantic ownership. Do not weaken an aggregate or an unrelated suite merely because it is the first red check visible in CI.

## Ownership map

| Validation surface | Owning domain | What it protects | Failure routing |
| --- | --- | --- | --- |
| **Repository Layout Validation** | Repository architecture | Canonical roots, dependency directions, retired paths and structural exceptions | Architecture/integration defect; validator debt only after intentional architecture change |
| **Character Validation** | Player / combat / creature integration | Character state, movement/action/combat, equipment-facing gameplay, mannequin/rig/socket contracts and Burrower combat behavior | Character/combat/creature implementation or shared-contract integration |
| **Enemy LOS Validation** | Burrower combat / LOS integration | World-occluded melee and accepted Character/App Shell composition for Burrower LOS-sensitive changes | Burrower/LOS implementation; Character/App Shell only when their own contract is what failed |
| **App Shell Validation** | AppRoot / GameFlow / route lifecycle | Title/game routing, off-tree NEW/CONTINUE preparation, pause/resume, Save & Quit, teardown and application-theme composition | AppRoot/GameFlow/route-composition implementation or persistence integration |
| **Inventory Validation** | Inventory / item-state transactions | Container invariants, transaction atomicity, authored-definition compatibility, equipment/hotbar state, harvest/loot consumers | Inventory/equipment transaction owner or the failing consumer integration |
| **Inventory Identity Integration Validation** | Integration coverage for Inventory identity | Ensures changes to canonical ItemContainer authored-definition identity also compose through accepted App Shell paths | Inventory identity if semantic compatibility fails; workflow coverage debt if required dependency dispatch is missing |
| **Crafting Validation** | Recipe / crafting transaction authority | Recipe validation, plan construction, inventory transaction atomicity and equipment/progression composition | Crafting/recipe/content implementation; Inventory only for actual transaction invariant failures |
| **Numeric Validation** | Shared finite-number policy | Finite semantic/state boundaries and atomic rejection of NaN/Inf or malformed numeric state | Owning domain that admitted invalid numeric state, or shared numeric-policy implementation |
| **Persistence State Validation** | SAVE / gameplay-state persistence | Gameplay codecs, typed detached save wire, atomic slot lifecycle, integrated real-Game Continue, legacy retirement and death/recovery save compatibility | Persistence/SAVE/Game lifecycle; source domain only when its snapshot contract is invalid |
| **Resource Runtime Validation** | Underground RESOURCE / WorldDelta transaction composition | Semantic pickaxe eligibility, atomic mine→inventory yield, persistent depletion, idempotence, rollback and dependency-trigger closure | Resource runtime / WorldDelta / inventory integration; workflow debt when a direct dependency does not dispatch the suite |
| **HUD Validation** | Gameplay HUD presentation | Read-only HUD sampling/rendering, feedback surface and accepted App Shell composition | HUD/read-model/composition; never gameplay truth merely to satisfy presentation |
| **UI Architecture Validation** | Reusable UI architecture | Theme/semantic style roles, reusable 9-slice/skin boundaries and UI structural conventions | UI architecture/presentation implementation |
| **Audio Presentation Validation** | Semantic audio presentation | Cue catalog/controller/binding behavior and observation-only routing from committed gameplay outcomes | Audio binding/presentation; source gameplay only if the committed semantic outcome itself is wrong |
| **Cave Presentation Validation** | Cave presentation | Material/mesh/realization contracts above semantic cave/world truth | Presentation implementation/integration; do not rewrite worldgen identity/topology for appearance-only assumptions |
| **Entrance UX Validation** | Generated natural-route composition | Deterministic ordinary entrance selection/bootstrap, route identity/readiness and safe presentation-facing route contract | Entrance selector/bootstrap/composition; cave runtime only when its accepted readiness contract actually fails |
| **Deterministic Worldgen fast contracts** | World definition + runtime worldgen integration | Deterministic identity/RNG/provenance/topology/geometry/runtime contracts including MAP runtime boundaries | Named failing worldgen/runtime invariant owner |
| **Deterministic Worldgen shard campaign** | Deterministic worldgen | Reproduction over the committed ten-shard seed/region campaign | Nondeterminism/generation regression unless an explicit compatibility revision was intentionally changed |
| **Content registry contracts** | Authored semantic content | ContentId/schema/reference/family validation, production catalog composition and snapshot-bound validation evidence | Content family/registry/schema/validator or stale-evidence consumer |
| **`Godot headless contracts` aggregate** | CI integration surface | Requires Content registry contracts plus the complete deterministic shard matrix | **Not a root-cause owner**; inspect the failed dependency |
| **Cross-Region Validation** | Stage-4 cross-region graph ownership | Owner/reference endpoint structure, remote/local consistency and malformed-reference rejection | Connectivity/graph ownership |
| **Graph Canonicalization Validation** | Deterministic graph representation | Order-invariant canonical graph text/fingerprints without source mutation | Canonicalization/deterministic graph implementation |
| **Seed Domain Audit** | Deterministic RNG-domain governance | Named, registry-backed persistent RNG domains and deterministic registry validity | RNG-domain call-site/registry implementation |
| **Surface Contract Validation** | Surface definition + pickup runtime boundary | Deterministic sampler behavior, coordinate boundaries, DTO ownership and non-mutating pickup discovery/StableId-compatible identity | Surface sampler/runtime-contract or HARVEST integration |
| **World Definition Service Validation** | World-definition service | Cache/request identity, descriptor lifecycle, ordering and negative-coordinate behavior | Service lifecycle/integration implementation |
| **Generator Manifest Validation** | Generator compatibility identity | Stage/profile/contract revision identity, ordering and invalid revision rejection | Manifest/versioning implementation |
| **TEST-056 Worldgen Edge Cases** | Worldgen edge replay / procedural identity | Fresh Stage-1→4 replay at signed/high-bit seeds/coordinates plus order invariance | Worldgen/StableAddress/StableId or explicit compatibility revision |
| **Worldgen Purity Validation** | Worldgen architecture boundary | Pure-data production-worldgen boundary and forbidden engine/runtime ownership crossings | Architecture/implementation boundary violation |
| **Map Data Serialization Validation** | Persistence / map data | Map serialization schema, durable representation and round-trip compatibility | Persistence/schema/migration implementation |
| **Stable ID Audit** | StableAddress / StableId | Large deterministic identity corpus reproduction and collision resistance | Procedural identity implementation |
| **Worldgen Inspector Validation** | Developer tooling / inspection | Reproducible inspector/atlas/export schemas over worldgen data | Inspector/export tooling or adapter integration, not generator truth by default |
| **Worldgen Benchmark** | Diagnostic performance evidence | Fixed deterministic timing corpus and report schema | Benchmark/tooling/performance investigation; not semantic acceptance by itself |
| **Runtime Cave Performance Validation** | Runtime performance evidence | Production cave/runtime profiling and bounded latency/hitch evidence | Runtime/performance investigation; semantic correctness remains with owning runtime tests |
| **PM Acceptance Gate** | Project governance | Exact-head PM acceptance metadata/status lifecycle | Governance state; never substitute it for domain validation |

The table is an ownership index, not an exhaustive inventory of every test file or workflow. New focused suites may be added without changing the principle: **the invariant owner remains the diagnostic destination**.

---

## Application and gameplay integration surfaces

### App Shell Validation

Workflow: [`app-shell-validation.yml`](../../.github/workflows/app-shell-validation.yml)  
Runner: [`tests/run_app_shell.gd`](../../tests/run_app_shell.gd)

The App Shell runner owns the application lifecycle boundary represented by `AppRoot` and `GameFlow`: title/game routing, off-tree NEW/CONTINUE preparation, pause/resume, Save & Quit, route teardown and the application theme boundary.

A failure here is not permission to bypass SAVE or route preparation. Route it to AppRoot/GameFlow/composition, or to Persistence when the failure is genuinely the accepted save/load contract.

### Character Validation and Enemy LOS

Workflow: [`character-validation.yml`](../../.github/workflows/character-validation.yml)  
Runner: [`tests/run_character.gd`](../../tests/run_character.gd)

Character Validation owns Player/combat/creature-facing gameplay contracts and the accepted mannequin/rig/socket boundary where gameplay depends on semantic roles rather than presentation object identity.

[`enemy-los-validation.yml`](../../.github/workflows/enemy-los-validation.yml) is a focused dispatch for Burrower LOS-sensitive paths. It executes accepted Character contracts and App Shell contracts. Its semantic owner is still Burrower/LOS combat: world obstruction must prevent invalid melee resolution. The workflow's App Shell replay is integration evidence, not AppRoot ownership of LOS.

### Inventory Validation and authored-definition identity

Workflow: [`inventory-validation.yml`](../../.github/workflows/inventory-validation.yml)  
Runner: [`tests/run_inventory.gd`](../../tests/run_inventory.gd)

Inventory owns item-container invariants, capacity/weight rules, atomic mutations, equipment/hotbar state and transaction semantics. HARVEST, LOOT, crafting and resource systems consume Inventory authority; they do not gain permission to mutate canonical container state directly.

Current authored-definition identity is stricter than matching a `ContentId` string alone. Independently instantiated definitions with the same `ContentId` are compatible only when their canonical authored descriptors are equivalent. Category/capability/reference/subtype/weapon semantic drift for the same ID fails atomically before mutation. Mutable stack/per-copy state remains distinct from authored-definition identity.

[`inventory-identity-integration-validation.yml`](../../.github/workflows/inventory-identity-integration-validation.yml) protects downstream composition when `ItemContainerState` identity semantics change. Treat a missing dependency trigger as CI coverage debt; treat canonical-definition mismatch behavior as Inventory identity ownership.

### Crafting Validation

Workflow: [`crafting-validation.yml`](../../.github/workflows/crafting-validation.yml)  
Runner: [`tests/run_crafting.gd`](../../tests/run_crafting.gd)

Crafting owns recipe resolution/validation, construction of executable plans and exactly-once inventory transaction behavior. Missing ingredient/output references, stale validation evidence, invalid recipe capabilities or failed transaction/equipment composition must reject before partial state becomes authoritative.

Inventory remains the mutation authority underneath crafting. CONTENT owns authored definition/schema/reference validity. Diagnose which boundary actually failed rather than moving ownership into Crafting for convenience.

### Resource Runtime Validation

Workflow: [`resource-runtime-validation.yml`](../../.github/workflows/resource-runtime-validation.yml)  
Runner: [`tests/run_resource_runtime.gd`](../../tests/run_resource_runtime.gd)

RESOURCE runtime owns the accepted underground mining transaction boundary: authored placement/resource identity, semantic pickaxe eligibility, atomic inventory yield, WorldDelta-backed depletion, duplicate operation rejection, strict restore compatibility and rollback when commit-phase inventory mutation fails.

Its runner also validates that direct runtime dependencies are represented in the workflow's `pull_request.paths` closure. A red dependency-trigger assertion is CI integration debt unless the underlying resource behavior also fails.

RESOURCE does not own cave topology/residency and does not serialize runtime Nodes. Production composition of authored resources into live cave cells is a separate integration concern.

### Numeric Validation

Workflow: [`numeric-validation.yml`](../../.github/workflows/numeric-validation.yml)  
Runner: [`tests/run_numeric_validation.gd`](../../tests/run_numeric_validation.gd)

Numeric Validation owns the shared rule that semantic/durable numeric boundaries must remain finite and malformed NaN/Inf values fail atomically. The shared finite-number helper is policy; the domain that admits invalid state remains responsible for its own boundary.

Do not repair a numeric failure by silently clamping persisted/gameplay truth unless that behavior is explicitly part of the owning contract.

### Persistence State Validation

Workflow: [`persistence-state-validation.yml`](../../.github/workflows/persistence-state-validation.yml)  
Runner: [`tests/run_persistence_state.gd`](../../tests/run_persistence_state.gd)

This is the authoritative integrated gameplay-state/SAVE surface. It covers gameplay codecs, typed detached save wire, atomic slot lifecycle, integrated Survival persistence, real-Game Save/Continue reconstruction, source-level legacy retirement and death/recovery save compatibility.

Persistence owns serialization/atomic durable lifecycle. Inventory, equipment, WorldDelta, pending loot and Player position remain source-domain truths represented by the save; a persistence test exposing malformed source state does not transfer source-domain authority into SAVE.

---

## Presentation validation surfaces

### HUD Validation

Workflow: [`hud-validation.yml`](../../.github/workflows/hud-validation.yml)  
Runner: [`tests/run_hud.gd`](../../tests/run_hud.gd)

HUD validation owns read-only presentation of accepted gameplay state and feedback through the gameplay HUD. HUD may derive text/visual state from semantic read models; it must not become inventory, equipment, resource, cave, loot or persistence authority.

The HUD workflow may replay App Shell integration where needed. Route a rendering/read-model failure to HUD; route a genuinely wrong gameplay state to its gameplay owner.

### UI Architecture Validation

Workflow: [`ui-architecture-validation.yml`](../../.github/workflows/ui-architecture-validation.yml)  
Runner: [`tests/run_ui_architecture.gd`](../../tests/run_ui_architecture.gd)

UI Architecture protects reusable semantic Theme/skin/9-slice structure and architectural separation between UI presentation assets and gameplay identity. Replacing artwork should not require rewriting gameplay truth.

### Audio Presentation Validation

Workflow: [`audio-presentation-validation.yml`](../../.github/workflows/audio-presentation-validation.yml)  
Runner: [`tests/run_audio_presentation.gd`](../../tests/run_audio_presentation.gd)

Audio owns semantic cue catalog/controller/binding behavior. Gameplay emits or returns committed semantic outcomes; audio observes those outcomes without polling gameplay state, parsing debug strings, or becoming mutation authority.

If a committed gameplay event/result is wrong, route to the gameplay owner. If a correct committed outcome maps/plays incorrectly, route to Audio Presentation.

### Cave Presentation Validation

Workflow: [`cave-presentation-validation.yml`](../../.github/workflows/cave-presentation-validation.yml)  
Runner: [`tests/run_cave_presentation.gd`](../../tests/run_cave_presentation.gd)

Cave presentation sits above semantic cave geometry/world truth. Materials, meshes, lights and presentation Nodes are replaceable representation. A presentation failure should not be “fixed” by changing topology, StableIds, generation fingerprints or fixture selectors unless an owning worldgen/runtime contract also failed.

### Entrance UX Validation

Workflow: [`entrance-ux-validation.yml`](../../.github/workflows/entrance-ux-validation.yml)

Entrance UX protects the ordinary generated natural-route boundary: deterministic selected entrance identity, finite/safe route composition, bootstrap/readiness and the read-only route information downstream presentation may consume.

It does not make UX or Game the topology owner. Stable entrance identity/fingerprint remains generated truth; cave runtime owns geometry/readiness; surface realization owns its physical terrain representation.

---

## Deterministic Worldgen and Content aggregate

Workflow: [`foundation-validation.yml`](../../.github/workflows/foundation-validation.yml)  
Worldgen runner: [`tests/run_validation.gd`](../../tests/run_validation.gd)  
Content runner: [`tests/run_content.gd`](../../tests/run_content.gd)

### Fast worldgen contracts

Every deterministic shard runs the fast worldgen contract surface before the batch probe. It composes deterministic identity/RNG, manifest/provenance, graph/topology/entrance/connectivity, cave geometry/cell partitioning, runtime-cell lifecycle, surface handoff, collision/readiness and accepted runtime fixtures.

This is a bundle of owners, not one monolithic subsystem. Route a named test failure to the named contract.

### Ten-shard deterministic campaign

The committed campaign starts at seeds:

`1, 26, 51, 76, 101, 126, 151, 176, 201, 226`

Each shard runs 25 seeds over region radius 1, preserving the full **250 seeds × 9 regions = 2,250 region cases** campaign.

Do not shrink seed counts, region coverage or equality checks to make a changed implementation pass. Intentional deterministic truth changes must travel through the owning compatibility/version/fixture contract.

### Content registry contracts and CONTENT-006 evidence

The Content runner is a growing aggregate over accepted semantic content families and their validators. It protects:

- authored `ContentId` identity independent of filesystem path;
- controlled category/capability/semantic-role vocabularies;
- typed references and family expectations;
- family-specific rulebooks/validators;
- semantic definition/realization separation;
- production catalog composition;
- dependency-closed validation where required by the accepted pipeline.

CONTENT-006 adds immutable **snapshot-bound validation evidence**. Runtime consumers that require validation authority must reject stale evidence when registry/schema/policy/validator inputs no longer match the evidence snapshot. Compatibility Dictionary result keys may remain available, but they do not make stale evidence authoritative.

A stale-evidence failure belongs to the consumer/evidence boundary or Content validation authority—not to a downstream transaction merely because it was the first caller to reject.

### Stable aggregate

`Godot headless contracts` succeeds only after:

1. `Content registry contracts` succeeds; and
2. every deterministic shard succeeds.

The aggregate is a stable reporting surface. It deliberately does **not** identify the root cause.

---

## Specialized deterministic and architecture suites

### Cross-Region Validation

Workflow: [`cross-region-validation.yml`](../../.github/workflows/cross-region-validation.yml)  
Runner: [`tests/run_cross_region_validation.gd`](../../tests/run_cross_region_validation.gd)

Owns Stage-4 cross-region owner/reference structure for real generated and deliberately malformed cases. Failures route to connectivity/graph ownership, not UI or presentation.

### Graph Canonicalization Validation

Workflow: [`graph-canonicalization-validation.yml`](../../.github/workflows/graph-canonicalization-validation.yml)  
Runner: [`tests/run_graph_canonicalization.gd`](../../tests/run_graph_canonicalization.gd)

Owns permutation/order invariance of canonical graph representation and fingerprints. A failure is a deterministic graph/canonicalization defect unless explicit logical content changed.

### Seed Domain Audit

Workflow: [`seed-domain-audit.yml`](../../.github/workflows/seed-domain-audit.yml)  
Audit: [`tools/ci/seed_domain_audit.py`](../../tools/ci/seed_domain_audit.py)

Owns persistent RNG-domain naming/registry discipline. Magic numeric or undeclared persistent domains, duplicate registry identity and invalid revisions route to seed-domain implementation.

### Surface Contract Validation

Workflow: [`surface-contract-validation.yml`](../../.github/workflows/surface-contract-validation.yml)  
Runner: [`tests/run_surface_contract.gd`](../../tests/run_surface_contract.gd)

Owns deterministic surface sampler behavior and the accepted non-mutating surface pickup discovery/StableId-compatible runtime boundary. Surface sampling defects remain surface-definition ownership; pickup discovery/runtime identity failures route to surface-runtime/HARVEST integration.

A later production surface realization test may consume accepted generated entrance truth without making this sampler or surface runtime cave-topology authority.

### World Definition Service Validation

Workflow: [`world-definition-service-validation.yml`](../../.github/workflows/world-definition-service-validation.yml)  
Runner: [`tests/run_world_definition_service.gd`](../../tests/run_world_definition_service.gd)

Owns world-definition cache/request/descriptor lifecycle, deterministic ordering and negative-coordinate behavior.

### Generator Manifest Validation

Workflow: [`generator-manifest-validation.yml`](../../.github/workflows/generator-manifest-validation.yml)  
Runner: [`tests/run_generator_manifest.gd`](../../tests/run_generator_manifest.gd)

Owns generator compatibility identity: stage/profile/contract revisions, insertion-order invariance, copy isolation and rejection of invalid revisions. Do not hide compatibility changes by suppressing manifest identity changes.

### TEST-056 Worldgen Edge Case Validation

Workflow: [`worldgen-edge-case-validation.yml`](../../.github/workflows/worldgen-edge-case-validation.yml)  
Runner: [`tests/worldgen_edge_cases/run_worldgen_edge_cases.gd`](../../tests/worldgen_edge_cases/run_worldgen_edge_cases.gd)

TEST-056 is accepted current-main evidence. It performs genuinely fresh Stage-1→4 replay over the committed signed/high-bit seed and coordinate-edge corpus, regenerates all four cardinal Stage-4 neighbor views, checks forward/reverse corpus order invariance and preserves canonical StableAddress/StableId behavior.

Do not replace its committed selectors with invented “representative” values.

### Worldgen Purity Validation

Workflow: [`worldgen-purity-validation.yml`](../../.github/workflows/worldgen-purity-validation.yml)  
Guard: [`tools/ci/worldgen_purity_guard.py`](../../tools/ci/worldgen_purity_guard.py)

The purity guard owns the production `worldgen/**` pure-data boundary. A forbidden engine/runtime ownership crossing is an architecture defect, not something to waive locally for convenience.

### Map Data Serialization Validation

Workflow: [`map-data-serialization-validation.yml`](../../.github/workflows/map-data-serialization-validation.yml)  
Runner: [`tests/run_map_data_serialization_validation.gd`](../../tests/run_map_data_serialization_validation.gd)

Owns map-data serialization/round-trip compatibility. It is narrower than integrated Persistence State validation; an intentional schema change requires the owning migration/version response.

### Stable ID Audit

Workflow: [`stable-id-audit.yml`](../../.github/workflows/stable-id-audit.yml)  
Runner: [`tools/stable_id_audit/run_stable_id_audit.gd`](../../tools/stable_id_audit/run_stable_id_audit.gd)

Owns large-corpus StableAddress/StableId reproduction and collision resistance. A collision or reproduction failure belongs to procedural identity unless the audit itself is demonstrably stale.

### Worldgen Inspector Validation

Workflow: [`worldgen-inspector-validation.yml`](../../.github/workflows/worldgen-inspector-validation.yml)

Owns inspector/atlas/export tooling schemas and reproducible diagnostic exports. Inspector output may expose a generator defect, but the inspector is not authoritative world truth.

---

## Runtime fixture ownership

### MAP-014 / MAP-015 / MAP-016

MAP-014 and MAP-015 remain accepted deterministic runtime integration evidence in the worldgen fast suite. Their protected invariants include runtime-cell demand/lifecycle, stale-result rejection, collision/traversal readiness, deterministic runtime-harness behavior and the committed MAP-015 bootstrap selector/rebuild semantics.

MAP-016 replaced cave realization representation without redefining the MAP-015 semantic selector. A representation change that breaks collision readiness, stale-result behavior or fixture reproduction routes to runtime/geometry integration rather than changing the selector.

OBS-001 is now completed **manual observation evidence** for the accepted MAP-015 selector after MAP-016. Manual observation complements automation; it does not replace deterministic contracts.

Natural-route composition after that fixture is validated separately by Entrance UX and subsequent production surface/cave integration cards.

---

## Diagnostic performance evidence

### Deterministic Worldgen Benchmark

Workflow: [`worldgen-benchmark.yml`](../../.github/workflows/worldgen-benchmark.yml)  
Runner: [`tools/worldgen_benchmark/run_worldgen_benchmark.gd`](../../tools/worldgen_benchmark/run_worldgen_benchmark.gd)

The benchmark executes a fixed deterministic corpus and validates timing/report structure. It is useful for regression investigation but is not semantic correctness authority.

### Runtime Cave Performance Validation

Workflow: [`runtime-performance-validation.yml`](../../.github/workflows/runtime-performance-validation.yml)  
Runner: [`tests/run_performance.gd`](../../tests/run_performance.gd)

Runtime performance validation owns measured cave/runtime transition evidence such as cold generation/extraction/build cost, observer execution latency, warm re-entry and bounded work/backlog where the current profiler exposes them.

A performance PASS does not certify topology, persistence or collision semantics. Conversely, a semantic test should not invent arbitrary hardware timing thresholds. Route measured regressions to the runtime/performance owner and use the semantic suites to prove correctness.

---

## Governance evidence

### PM Acceptance Gate

Workflow: [`pm-acceptance-gate.yml`](../../.github/workflows/pm-acceptance-gate.yml)

`PM acceptance` is governance state, not software correctness. It may be red by design on worker/review heads and must never be “fixed” by weakening domain validation.

Source freeze, independent review and PM integration are separately governed by project issues/protocols. A green domain matrix does not authorize a merge when implementation WIP, review state, latest-main freshness or governance anti-race requirements are unresolved.

Repository-side ruleset enforcement remains a separate repository-governance concern from this validation ownership index.

---

## Failure-routing rules of thumb

1. **Start with the named failing contract**, not the workflow name alone.
2. **Separate semantic ownership from dispatch coverage.** A focused workflow may replay Character/App Shell/Persistence without owning those domains.
3. **Keep Content evidence snapshot-aware.** A previously valid validation result is not authoritative after its accepted registry/schema/policy/validator snapshot changes.
4. **Keep durable state authorities distinct.** Inventory, WorldDelta, pending loot, equipment and Player state do not become SAVE-owned just because SAVE serializes them.
5. **Keep presentation replaceable.** HUD/UI/audio/cave presentation failures are not permission to mutate gameplay/world truth.
6. **Treat dependency path-filter omissions as CI coverage debt.** Do not misclassify them as a gameplay defect when the underlying contract is green.
7. **Do not weaken deterministic campaigns or aggregates** to make a changed implementation pass.
8. **Do not fabricate manual evidence.** Manual gates remain explicit human observations and are not inferred from automation.
9. **Re-read current authority before landing preserved evidence.** A historically green head can become stale or non-consumable after accepted semantic drift.

This document is intentionally an ownership/failure-routing reference. For exact commands, path filters and execution cadence, use [Validation Matrix](VALIDATION_MATRIX.md) and the executable runner/workflow files.