# Underworld Documentation

This directory is the project design and architecture reference. Use this page to find the contract that owns a decision; linked documents remain authoritative and this index does not redefine them.

## Decision status and authority

Important rules use three states:

- **LOCKED** — implementation follows the rule unless it is deliberately revised.
- **DIRECTIONAL** — strong current direction; exact parameters may still change.
- **OPEN** — intentionally undecided; do not hard-code a permanent answer by accident.

When sources disagree, use this order:

1. the latest explicit decision in [`DECISION_LOG.md`](DECISION_LOG.md);
2. locked rules in the relevant design document;
3. architecture specifications;
4. existing implementation;
5. old prototype behavior.

Existing code is not automatically the design.

## Documentation architecture

The organization contract is [`00_project/DOCUMENTATION_ARCHITECTURE.md`](00_project/DOCUMENTATION_ARCHITECTURE.md).

| Section | Responsibility | Current state |
| --- | --- | --- |
| [`00_project/`](00_project/) | Project intent, governance, glossary, decisions, milestones and visual direction | Active |
| [`10_architecture/`](10_architecture/) | System boundaries, repository/content architecture and dependency direction | Active |
| `20_world/` | World-specific generation, streaming, terrain and world-delta design | Planned; authoritative world contracts still live at `docs/` root |
| [`30_gameplay/`](30_gameplay/) | Building and item/inventory/crafting architecture, with root-level gameplay contracts still active where not migrated | Active |
| [`40_content/`](40_content/) | Content IDs, categories, capabilities, references and family rulebooks | Active |
| [`50_authoring/`](50_authoring/) | Human workflows for creating valid authored content and gameplay systems | Active |
| [`60_validation/`](60_validation/) | Machine-enforced contracts, reproducibility evidence and operational validation guidance | Active |

The numeric prefixes are reading-order markers only. They are not game versions, content IDs, save IDs, runtime IDs or code namespaces.

## Start here by concern

### Project governance and intent

- [`GAME_PILLARS.md`](GAME_PILLARS.md) — what Underworld is and what it should not drift into.
- [`DEVELOPMENT_RULEBOOK.md`](DEVELOPMENT_RULEBOOK.md) — architecture-first development and feature-scope rules.
- [`DECISION_LOG.md`](DECISION_LOG.md) — chronological architectural/project decisions and revisions.
- [`00_project/DECISION_INDEX.md`](00_project/DECISION_INDEX.md) — current decision/topic routing into owning contracts and historical checkpoints.
- [`00_project/MILESTONES.md`](00_project/MILESTONES.md) — accepted project milestone structure and completion criteria.
- [`00_project/VISUAL_DIRECTION.md`](00_project/VISUAL_DIRECTION.md) — visual-direction principles and replaceable presentation expectations.
- [`00_project/DOCUMENTATION_ARCHITECTURE.md`](00_project/DOCUMENTATION_ARCHITECTURE.md) — documentation ownership, document types and migration rules.
- [`00_project/GLOSSARY.md`](00_project/GLOSSARY.md) — canonical project terminology and links to owning contracts.
- [`10_architecture/SYSTEM_OWNERSHIP_MAP.md`](10_architecture/SYSTEM_OWNERSHIP_MAP.md) — cross-system ownership, identity boundaries and dependency routing.

### Core architecture and dependency direction

- [`10_architecture/REPOSITORY_STRUCTURE.md`](10_architecture/REPOSITORY_STRUCTURE.md) — repository ownership, file placement, PackedScene placement and dependency direction by root.
- [`10_architecture/DEPENDENCY_RULES.md`](10_architecture/DEPENDENCY_RULES.md) — allowed/forbidden dependencies between definitions, runtime systems and assets.
- [`10_architecture/CONTENT_ARCHITECTURE.md`](10_architecture/CONTENT_ARCHITECTURE.md) — semantic definitions, categories/capabilities, assets and runtime separation.
- [`10_architecture/CONTENT_REGISTRY.md`](10_architecture/CONTENT_REGISTRY.md) — semantic content-ID resolution boundary.
- [`10_architecture/PRESENTATION_BOUNDARY.md`](10_architecture/PRESENTATION_BOUNDARY.md) — replaceable visual/animation realization boundary and gameplay/presentation authority split.
- [`TECHNICAL_ARCHITECTURE.md`](TECHNICAL_ARCHITECTURE.md) — existing root-level system architecture; remains authoritative until explicitly migrated.

### World and deterministic generation

- [`WORLD_ARCHITECTURE.md`](WORLD_ARCHITECTURE.md) — surface/Underworld relationship, depth, topology, entrances and world rules.
- [`UNDERWORLD_GRAPH_SCHEMA.md`](UNDERWORLD_GRAPH_SCHEMA.md) — pure-data region/network/node/edge/entrance graph schema.
- [`STABLE_PROCEDURAL_IDS.md`](STABLE_PROCEDURAL_IDS.md) — `WorldId`, `StableAddress` and procedural `StableId` architecture.
- [`DETERMINISTIC_SEED_DOMAINS.md`](DETERMINISTIC_SEED_DOMAINS.md) — named/revisioned deterministic randomness and parallel-safe seed derivation.
- [`GENERATION_PIPELINE_INTERFACES.md`](GENERATION_PIPELINE_INTERFACES.md) — pure-data stage contracts from macro planning through geometry/runtime handoff.
- [`STREAMING_OWNERSHIP.md`](STREAMING_OWNERSHIP.md) — definition/cache/runtime ownership, runtime tiers and async lifetime boundaries.
- [`MINING_AND_RESOURCES.md`](MINING_AND_RESOURCES.md) — harvesting versus large-deposit excavation design.

### Persistence and serialization

- [`PERSISTENCE_AND_VERSIONING.md`](PERSISTENCE_AND_VERSIONING.md) — deterministic baseline versus durable deltas, generator manifests and compatibility.
- [`MAP_DATA_SERIALIZATION_CONTRACT.md`](MAP_DATA_SERIALIZATION_CONTRACT.md) — current executable generated-world save envelope.
- [`STABLE_PROCEDURAL_IDS.md`](STABLE_PROCEDURAL_IDS.md) — generated-instance identity used by persistence.
- [`50_authoring/PERSISTENCE_VERSIONING_CHECKLIST.md`](50_authoring/PERSISTENCE_VERSIONING_CHECKLIST.md) — implementation/authoring checklist for persistence-sensitive changes.

### Gameplay

- [`30_gameplay/BUILDING_SYSTEM.md`](30_gameplay/BUILDING_SYSTEM.md) — building architecture, definition/runtime separation and placement/ownership boundaries.
- [`30_gameplay/ITEM_INVENTORY_CRAFTING.md`](30_gameplay/ITEM_INVENTORY_CRAFTING.md) — item, inventory and crafting architecture and ownership boundaries.
- [`PROTOTYPE_CHARACTER.md`](PROTOTYPE_CHARACTER.md) — current replaceable character/movement/defense prototype contract.
- [`PLAYER_ATTACK_CONTRACT.md`](PLAYER_ATTACK_CONTRACT.md) — player melee ownership and execution boundaries.
- [`PLAYER_INPUT_BUFFER.md`](PLAYER_INPUT_BUFFER.md) — combat-intent buffering contract.
- [`GAME_PILLARS.md`](GAME_PILLARS.md) — design-direction context before changing gameplay rules.
- [`10_architecture/DEPENDENCY_RULES.md`](10_architecture/DEPENDENCY_RULES.md) — check before introducing gameplay/content/presentation coupling.

### Content definitions

- [`40_content/CONTENT_IDS.md`](40_content/CONTENT_IDS.md) — stable semantic content identity.
- [`40_content/CONTENT_CATEGORIES.md`](40_content/CONTENT_CATEGORIES.md) — hierarchical classification rules.
- [`40_content/CONTENT_CAPABILITIES.md`](40_content/CONTENT_CAPABILITIES.md) — behavioral composition contracts.
- [`40_content/CONTENT_REFERENCES.md`](40_content/CONTENT_REFERENCES.md) — typed semantic references and cycle rules.
- [`40_content/CONTENT_FAMILIES.md`](40_content/CONTENT_FAMILIES.md) — major scalable content families.
- [`40_content/CONTENT_RULEBOOK.md`](40_content/CONTENT_RULEBOOK.md) — shared family-rulebook requirements.
- [`40_content/ITEM_RULEBOOK.md`](40_content/ITEM_RULEBOOK.md) — accepted base item-definition/rulebook contract.
- [`40_content/RESOURCE_RULEBOOK.md`](40_content/RESOURCE_RULEBOOK.md) — accepted authored underground resource/deposit definition and yield contract.
- [`40_content/RULEBOOK_TEMPLATE.md`](40_content/RULEBOOK_TEMPLATE.md) — reusable rulebook structure.

Animation and rig content specifications live under [`40_content/animations/`](40_content/animations/) and their authoring guides live in `50_authoring/`.

### Authoring

- [`50_authoring/AUTHORING_CONTRACT.md`](50_authoring/AUTHORING_CONTRACT.md) — general content-authoring workflow.
- [`50_authoring/FILE_PLACEMENT_GUIDE.md`](50_authoring/FILE_PLACEMENT_GUIDE.md) — practical placement guide for definitions, runtime code, scenes, assets, tools and tests.
- [`50_authoring/ADDING_GAMEPLAY_SYSTEM.md`](50_authoring/ADDING_GAMEPLAY_SYSTEM.md) — architecture-first workflow for adding a gameplay system without breaking ownership boundaries.
- [`50_authoring/ADDING_RIG_PROFILE.md`](50_authoring/ADDING_RIG_PROFILE.md) — rig-profile authoring/import workflow.
- [`50_authoring/ADDING_ANIMATION_SET.md`](50_authoring/ADDING_ANIMATION_SET.md) — semantic animation-set authoring workflow.
- [`50_authoring/PERSISTENCE_VERSIONING_CHECKLIST.md`](50_authoring/PERSISTENCE_VERSIONING_CHECKLIST.md) — checklist for save/schema/identity-sensitive work.

### Validation and operations

- [`VALIDATION_HARNESS.md`](VALIDATION_HARNESS.md) — deterministic primitives, stage fingerprints, campaigns and validation architecture.
- [`60_validation/VALIDATION_MATRIX.md`](60_validation/VALIDATION_MATRIX.md) — current validation ownership and expected evidence by change class.
- [`60_validation/CONTENT_VALIDATION.md`](60_validation/CONTENT_VALIDATION.md) — content validation architecture.
- [`60_validation/DETERMINISTIC_FIXTURE_CATALOG.md`](60_validation/DETERMINISTIC_FIXTURE_CATALOG.md) — deterministic fixture/reproducibility catalog and selector history.
- [`60_validation/REPOSITORY_LAYOUT_VALIDATION.md`](60_validation/REPOSITORY_LAYOUT_VALIDATION.md) — repository/path ownership validation.
- [`60_validation/MAIN_MERGE_GATE.md`](60_validation/MAIN_MERGE_GATE.md) — operational PM/merge-governance contract. Its presence documents the required process; it does not by itself prove repository-side protection is active.

This README remains a navigation page rather than a second validation matrix or test-suite index.

## I need to change X — where do I look first?

| Change | Look here first | Then check |
| --- | --- | --- |
| Deterministic worldgen, topology, entrances or cave definitions | [`GENERATION_PIPELINE_INTERFACES.md`](GENERATION_PIPELINE_INTERFACES.md) | [`STABLE_PROCEDURAL_IDS.md`](STABLE_PROCEDURAL_IDS.md), [`DETERMINISTIC_SEED_DOMAINS.md`](DETERMINISTIC_SEED_DOMAINS.md), [`WORLD_ARCHITECTURE.md`](WORLD_ARCHITECTURE.md) |
| Geometry/runtime cells, streaming or loaded world representation | [`STREAMING_OWNERSHIP.md`](STREAMING_OWNERSHIP.md) | [`10_architecture/REPOSITORY_STRUCTURE.md`](10_architecture/REPOSITORY_STRUCTURE.md), [`GENERATION_PIPELINE_INTERFACES.md`](GENERATION_PIPELINE_INTERFACES.md) |
| Save data, durable world changes or generator compatibility | [`PERSISTENCE_AND_VERSIONING.md`](PERSISTENCE_AND_VERSIONING.md) | [`MAP_DATA_SERIALIZATION_CONTRACT.md`](MAP_DATA_SERIALIZATION_CONTRACT.md), [`50_authoring/PERSISTENCE_VERSIONING_CHECKLIST.md`](50_authoring/PERSISTENCE_VERSIONING_CHECKLIST.md) |
| Building rules or structure authoring/runtime ownership | [`30_gameplay/BUILDING_SYSTEM.md`](30_gameplay/BUILDING_SYSTEM.md) | [`10_architecture/DEPENDENCY_RULES.md`](10_architecture/DEPENDENCY_RULES.md), applicable content rulebook |
| Items, inventory or crafting | [`30_gameplay/ITEM_INVENTORY_CRAFTING.md`](30_gameplay/ITEM_INVENTORY_CRAFTING.md) | [`40_content/ITEM_RULEBOOK.md`](40_content/ITEM_RULEBOOK.md), [`50_authoring/AUTHORING_CONTRACT.md`](50_authoring/AUTHORING_CONTRACT.md) |
| Player/combat/gameplay behavior | Relevant gameplay contract, e.g. [`PLAYER_ATTACK_CONTRACT.md`](PLAYER_ATTACK_CONTRACT.md) | [`GAME_PILLARS.md`](GAME_PILLARS.md), [`10_architecture/DEPENDENCY_RULES.md`](10_architecture/DEPENDENCY_RULES.md) |
| New gameplay system | [`50_authoring/ADDING_GAMEPLAY_SYSTEM.md`](50_authoring/ADDING_GAMEPLAY_SYSTEM.md) | [`10_architecture/SYSTEM_OWNERSHIP_MAP.md`](10_architecture/SYSTEM_OWNERSHIP_MAP.md), [`10_architecture/DEPENDENCY_RULES.md`](10_architecture/DEPENDENCY_RULES.md) |
| New item, creature, attack, structure or other authored definition | [`10_architecture/CONTENT_ARCHITECTURE.md`](10_architecture/CONTENT_ARCHITECTURE.md) | [`40_content/CONTENT_IDS.md`](40_content/CONTENT_IDS.md), applicable family rulebook, [`50_authoring/AUTHORING_CONTRACT.md`](50_authoring/AUTHORING_CONTRACT.md) |
| New/changed asset, scene, animation or file location | [`10_architecture/REPOSITORY_STRUCTURE.md`](10_architecture/REPOSITORY_STRUCTURE.md) | [`10_architecture/PRESENTATION_BOUNDARY.md`](10_architecture/PRESENTATION_BOUNDARY.md), [`50_authoring/FILE_PLACEMENT_GUIDE.md`](50_authoring/FILE_PLACEMENT_GUIDE.md) |
| Authoring another valid content member | [`50_authoring/AUTHORING_CONTRACT.md`](50_authoring/AUTHORING_CONTRACT.md) | Applicable rulebook and specialized guide |
| Tests, validation or CI evidence | [`60_validation/VALIDATION_MATRIX.md`](60_validation/VALIDATION_MATRIX.md) | [`VALIDATION_HARNESS.md`](VALIDATION_HARNESS.md), owning subsystem contract and actual workflow/runner |
| Merge/review governance | [`60_validation/MAIN_MERGE_GATE.md`](60_validation/MAIN_MERGE_GATE.md) | Actual repository settings/status checks and PM board state |
| Project/documentation governance | [`00_project/DOCUMENTATION_ARCHITECTURE.md`](00_project/DOCUMENTATION_ARCHITECTURE.md) | [`00_project/DECISION_INDEX.md`](00_project/DECISION_INDEX.md), [`DEVELOPMENT_RULEBOOK.md`](DEVELOPMENT_RULEBOOK.md), [`DECISION_LOG.md`](DECISION_LOG.md) |

## Root-level documents are still authoritative

The numbered hierarchy is the destination architecture, but migration is staged. Existing root-level documents remain authoritative until an explicit documentation-only migration moves/replaces them and updates references in the same change.

Therefore:

- do not assume a root-level document is deprecated because a numbered destination section exists;
- do not move active contracts as part of unrelated implementation work;
- keep using existing paths until a reviewed migration changes them;
- if documents conflict, resolve the conflict in the owning authoritative contract rather than silently choosing whichever file looks newer.

## Change rule

A locked rule may change, but only deliberately:

1. state why the existing rule is insufficient;
2. define the replacement;
3. update the owning document;
4. record the decision in [`DECISION_LOG.md`](DECISION_LOG.md);
5. then change implementation.

Keep this README concise. Detailed rules belong in the owning architecture, rulebook, authoring or validation document.