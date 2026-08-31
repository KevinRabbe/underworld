# Underworld Documentation

This directory is the project design and architecture reference. Use this page to find the contract that owns a decision; this index does not redefine those contracts.

## Decision status and authority

Important rules use these states:

- **LOCKED** — implementation follows the rule unless deliberately superseded.
- **DIRECTIONAL** — strong current direction; exact parameters remain tunable.
- **OPEN** — intentionally undecided.
- **SUPERSEDED** — historical rule replaced by a later explicit decision/ADR.

When sources disagree, use this order:

1. the latest explicit decision/ADR and its named supersessions;
2. the current owning architecture/design contract;
3. supporting architecture/index documents;
4. existing implementation;
5. old prototype behavior.

Historical text remains history; it does not defeat a later explicit ADR that names the clause it replaces.

Current cross-domain supersession authority:
- [`00_project/ADR-001_TWO_WORLD_DOMAINS.md`](00_project/ADR-001_TWO_WORLD_DOMAINS.md)
- [`20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](20_world/WORLD_DOMAINS_AND_TRANSITIONS.md)
- [`00_project/DECISION_INDEX.md`](00_project/DECISION_INDEX.md)

Existing code is not automatically the design.

## Documentation architecture

The organization contract is [`00_project/DOCUMENTATION_ARCHITECTURE.md`](00_project/DOCUMENTATION_ARCHITECTURE.md).

| Section | Responsibility | Current state |
| --- | --- | --- |
| [`00_project/`](00_project/) | Project intent, governance, decisions/ADRs, milestones, glossary, roadmap and visual direction | Active |
| [`10_architecture/`](10_architecture/) | Cross-system boundaries, repository/content architecture, dependency direction and scalability | Active |
| [`20_world/`](20_world/) | World-domain relationship and domain-specific procedural-generation architecture | Active |
| [`30_gameplay/`](30_gameplay/) | Gameplay-system architecture such as Building and item/inventory/crafting | Active |
| [`40_content/`](40_content/) | Content IDs, categories, capabilities, references and family rulebooks | Active |
| [`50_authoring/`](50_authoring/) | Human workflows for creating valid authored content and systems | Active |
| [`60_validation/`](60_validation/) | Machine-enforced contracts, reproducibility evidence and validation guidance | Active |

Root-level documents remain authoritative where the staged documentation migration has not replaced them. The numeric prefixes are reading-order markers, not runtime/version namespaces.

## Start here by concern

### Project governance and intent

- [`GAME_PILLARS.md`](GAME_PILLARS.md) — high-level product identity and development principles.
- [`DECISION_LOG.md`](DECISION_LOG.md) — append-only chronological decision history, including the 2026-08-31 two-domain supersession.
- [`00_project/ADR-001_TWO_WORLD_DOMAINS.md`](00_project/ADR-001_TWO_WORLD_DOMAINS.md) — explicit architecture supersession from one continuous world to independent procedural domains.
- [`00_project/DECISION_INDEX.md`](00_project/DECISION_INDEX.md) — current-vs-superseded decision routing.
- [`00_project/MASTER_ROADMAP.md`](00_project/MASTER_ROADMAP.md) — multi-lane long-horizon roadmap.
- [`00_project/MILESTONES.md`](00_project/MILESTONES.md) — accepted milestone history/criteria.
- [`00_project/VISUAL_DIRECTION.md`](00_project/VISUAL_DIRECTION.md) — visual-production principles.
- [`00_project/GLOSSARY.md`](00_project/GLOSSARY.md) — canonical terminology and owning links.
- [`00_project/DOCUMENTATION_ARCHITECTURE.md`](00_project/DOCUMENTATION_ARCHITECTURE.md) — document ownership/migration rules.

### World domains and procedural generation

Read these in order when changing world architecture:

1. [`20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](20_world/WORLD_DOMAINS_AND_TRANSITIONS.md) — **Overworld/Underworld relationship and gateway authority**.
2. [`WORLD_ARCHITECTURE.md`](WORLD_ARCHITECTURE.md) — world-design rules using domain-local coordinates/depth.
3. [`20_world/UNDERWORLD_GENERATION_PIPELINE.md`](20_world/UNDERWORLD_GENERATION_PIPELINE.md) — normative Underworld-local generation pipeline.
4. [`UNDERWORLD_GRAPH_SCHEMA.md`](UNDERWORLD_GRAPH_SCHEMA.md) — pure region/network/node/edge/entry-site schema.
5. [`STABLE_PROCEDURAL_IDS.md`](STABLE_PROCEDURAL_IDS.md) — `WorldId`, `StableAddress` and procedural `StableId`.
6. [`DETERMINISTIC_SEED_DOMAINS.md`](DETERMINISTIC_SEED_DOMAINS.md) — deterministic randomness and compatibility.
7. [`STREAMING_OWNERSHIP.md`](STREAMING_OWNERSHIP.md) — domain-local runtime demand, caches, tiers, async lifetime and transition readiness.
8. [`PERSISTENCE_AND_VERSIONING.md`](PERSISTENCE_AND_VERSIONING.md) — active-domain/domain-local Player location plus generator/delta compatibility.

[`GENERATION_PIPELINE_INTERFACES.md`](GENERATION_PIPELINE_INTERFACES.md) remains a compatibility/navigation stub for the superseded root pipeline and points at the current Underworld contract. Do not revive its old physical surface-opening model.

### Core architecture and dependency direction

- [`TECHNICAL_ARCHITECTURE.md`](TECHNICAL_ARCHITECTURE.md) — root/domain definition, topology/geometry/runtime/delta/gateway separation.
- [`10_architecture/SYSTEM_OWNERSHIP_MAP.md`](10_architecture/SYSTEM_OWNERSHIP_MAP.md) — cross-system routing including explicit gateway/world-domain ownership.
- [`10_architecture/PERFORMANCE_AND_SCALABILITY.md`](10_architecture/PERFORMANCE_AND_SCALABILITY.md) — bounded work and canonical-state/runtime-representation separation.
- [`10_architecture/REPOSITORY_STRUCTURE.md`](10_architecture/REPOSITORY_STRUCTURE.md) — repository ownership and dependency direction by root.
- [`10_architecture/DEPENDENCY_RULES.md`](10_architecture/DEPENDENCY_RULES.md) — allowed/forbidden system dependencies.
- [`10_architecture/CONTENT_ARCHITECTURE.md`](10_architecture/CONTENT_ARCHITECTURE.md) — semantic definitions and runtime/presentation separation.
- [`10_architecture/PRESENTATION_BOUNDARY.md`](10_architecture/PRESENTATION_BOUNDARY.md) — replaceable presentation boundary.

### Persistence and serialization

- [`PERSISTENCE_AND_VERSIONING.md`](PERSISTENCE_AND_VERSIONING.md) — deterministic baseline vs durable deltas, generator manifests, explicit world-domain Player location and migration policy.
- [`MAP_DATA_SERIALIZATION_CONTRACT.md`](MAP_DATA_SERIALIZATION_CONTRACT.md) — current executable generated-world delta envelope; it does not itself own integrated Player-domain save state.
- [`50_authoring/PERSISTENCE_VERSIONING_CHECKLIST.md`](50_authoring/PERSISTENCE_VERSIONING_CHECKLIST.md) — implementation checklist for persistence-sensitive changes.

### Gameplay

- [`30_gameplay/BUILDING_SYSTEM.md`](30_gameplay/BUILDING_SYSTEM.md) — scalable declarative construction, grid + semantic sockets, free placement, overlap and structural-support architecture.
- [`30_gameplay/ITEM_INVENTORY_CRAFTING.md`](30_gameplay/ITEM_INVENTORY_CRAFTING.md) — item/inventory/crafting ownership.
- [`MINING_AND_RESOURCES.md`](MINING_AND_RESOURCES.md) — harvesting vs large-deposit excavation design.
- [`PROTOTYPE_CHARACTER.md`](PROTOTYPE_CHARACTER.md), [`PLAYER_ATTACK_CONTRACT.md`](PLAYER_ATTACK_CONTRACT.md), [`PLAYER_INPUT_BUFFER.md`](PLAYER_INPUT_BUFFER.md) — current Player/combat contracts.

### Content and authoring

- [`40_content/CONTENT_IDS.md`](40_content/CONTENT_IDS.md)
- [`40_content/CONTENT_CATEGORIES.md`](40_content/CONTENT_CATEGORIES.md)
- [`40_content/CONTENT_CAPABILITIES.md`](40_content/CONTENT_CAPABILITIES.md)
- [`40_content/CONTENT_REFERENCES.md`](40_content/CONTENT_REFERENCES.md)
- [`40_content/CONTENT_FAMILIES.md`](40_content/CONTENT_FAMILIES.md)
- [`40_content/CONTENT_RULEBOOK.md`](40_content/CONTENT_RULEBOOK.md)
- [`50_authoring/AUTHORING_CONTRACT.md`](50_authoring/AUTHORING_CONTRACT.md)
- [`50_authoring/FILE_PLACEMENT_GUIDE.md`](50_authoring/FILE_PLACEMENT_GUIDE.md)
- [`50_authoring/ADDING_GAMEPLAY_SYSTEM.md`](50_authoring/ADDING_GAMEPLAY_SYSTEM.md)

### Validation and operations

- [`VALIDATION_HARNESS.md`](VALIDATION_HARNESS.md) — deterministic primitives, fingerprints and campaign architecture.
- [`60_validation/VALIDATION_MATRIX.md`](60_validation/VALIDATION_MATRIX.md) — validation ownership/evidence by change class.
- [`60_validation/DETERMINISTIC_FIXTURE_CATALOG.md`](60_validation/DETERMINISTIC_FIXTURE_CATALOG.md) — deterministic fixture/reproducibility catalog.
- [`60_validation/REPOSITORY_LAYOUT_VALIDATION.md`](60_validation/REPOSITORY_LAYOUT_VALIDATION.md) — repository/path ownership validation.
- [`60_validation/MAIN_MERGE_GATE.md`](60_validation/MAIN_MERGE_GATE.md) — PM/merge-governance contract.

## I need to change X — where do I look first?

| Change | Primary authority | Then check |
| --- | --- | --- |
| Overworld ↔ Underworld transition/domain identity | [`20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](20_world/WORLD_DOMAINS_AND_TRANSITIONS.md) | ADR-001, `STREAMING_OWNERSHIP`, persistence |
| Underworld topology/depth/entry sites | [`20_world/UNDERWORLD_GENERATION_PIPELINE.md`](20_world/UNDERWORLD_GENERATION_PIPELINE.md) | graph schema, StableId, seed domains |
| Overworld generation | Owning Overworld contract/card | world-domain contract, StableId/seed-domain rules |
| Runtime cells/streaming/readiness | [`STREAMING_OWNERSHIP.md`](STREAMING_OWNERSHIP.md) | performance/scalability, domain contract |
| Save data / world deltas / generator compatibility | [`PERSISTENCE_AND_VERSIONING.md`](PERSISTENCE_AND_VERSIONING.md) | serialization contract, migration checklist |
| Building | [`30_gameplay/BUILDING_SYSTEM.md`](30_gameplay/BUILDING_SYSTEM.md) | dependency rules, content contracts, performance |
| Items/inventory/crafting | [`30_gameplay/ITEM_INVENTORY_CRAFTING.md`](30_gameplay/ITEM_INVENTORY_CRAFTING.md) | content rulebooks, authoring contract |
| New gameplay system | [`50_authoring/ADDING_GAMEPLAY_SYSTEM.md`](50_authoring/ADDING_GAMEPLAY_SYSTEM.md) | system ownership map, dependency rules |
| New/changed asset or presentation | [`10_architecture/PRESENTATION_BOUNDARY.md`](10_architecture/PRESENTATION_BOUNDARY.md) | visual direction, repository structure |
| Tests/CI evidence | [`60_validation/VALIDATION_MATRIX.md`](60_validation/VALIDATION_MATRIX.md) | validation harness, owning subsystem contract |
| Merge/review governance | [`60_validation/MAIN_MERGE_GATE.md`](60_validation/MAIN_MERGE_GATE.md) | live PM board/repository state |

## Two-domain guardrail

Do **not** introduce a new requirement that:

- Overworld and Underworld share XYZ coordinates;
- Underworld depth is derived from Overworld Y/surface height;
- a surface chunk must load/query Underworld definitions to cut a physical cross-domain hole;
- both complete domains must be resident/rendered near a gateway;
- active domain is inferred from Y sign, AABB membership, rendered cave geometry or camera depth.

If a feature genuinely needs to revise one of those rules, it is an architecture change and requires a new explicit decision/ADR rather than an implementation shortcut.

## Root-level documents and migration

The numbered hierarchy is the destination architecture, but documentation migration remains staged. Root-level documents are authoritative until explicitly replaced/migrated and references are updated.

Never choose between conflicting documents by filename age. Resolve the conflict through the current decision/ADR + owning contract and update indexes in the same governance change.

## Change rule

A locked rule may change deliberately:

1. state why the current rule is insufficient;
2. define the replacement;
3. record an explicit decision/ADR and exact supersession when needed;
4. update owning contracts and indexes;
5. then change implementation.

Keep this README a navigation page rather than a second architecture specification.