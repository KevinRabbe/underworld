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
| [`00_project/`](00_project/) | Project intent, governance, glossary and documentation architecture | Active |
| [`10_architecture/`](10_architecture/) | System boundaries, repository/content architecture and dependency direction | Active |
| `20_world/` | World-specific generation, streaming, terrain and world-delta design | Planned; authoritative world contracts still live at `docs/` root |
| `30_gameplay/` | Character, combat, survival, crafting, building and other gameplay contracts | Planned; authoritative gameplay contracts still live at `docs/` root |
| [`40_content/`](40_content/) | Content IDs, categories, capabilities, references and family rulebooks | Active |
| [`50_authoring/`](50_authoring/) | Human workflows for creating valid authored content | Active |
| [`60_validation/`](60_validation/) | Machine-enforced contracts and validation guidance | Active |

The numeric prefixes are reading-order markers only. They are not game versions, content IDs, save IDs, runtime IDs or code namespaces.

## Start here by concern

### Project governance and intent

- [`GAME_PILLARS.md`](GAME_PILLARS.md) — what Underworld is and what it should not drift into.
- [`DEVELOPMENT_RULEBOOK.md`](DEVELOPMENT_RULEBOOK.md) — architecture-first development and feature-scope rules.
- [`DECISION_LOG.md`](DECISION_LOG.md) — chronological architectural/project decisions and revisions.
- [`00_project/DOCUMENTATION_ARCHITECTURE.md`](00_project/DOCUMENTATION_ARCHITECTURE.md) — documentation ownership, document types and migration rules.

DOC-001 and DOC-002 add a canonical glossary and cross-system ownership map. They are intentionally not linked from this branch until those files are present on the target base; this navigation task does not depend on their merge order.

### Core architecture and dependency direction

- [`10_architecture/REPOSITORY_STRUCTURE.md`](10_architecture/REPOSITORY_STRUCTURE.md) — repository ownership, file placement, PackedScene placement and dependency direction by root.
- [`10_architecture/DEPENDENCY_RULES.md`](10_architecture/DEPENDENCY_RULES.md) — allowed/forbidden dependencies between definitions, runtime systems and assets.
- [`10_architecture/CONTENT_ARCHITECTURE.md`](10_architecture/CONTENT_ARCHITECTURE.md) — semantic definitions, categories/capabilities, assets and runtime separation.
- [`10_architecture/CONTENT_REGISTRY.md`](10_architecture/CONTENT_REGISTRY.md) — semantic content-ID resolution boundary.
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

### Gameplay

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
- [`40_content/RULEBOOK_TEMPLATE.md`](40_content/RULEBOOK_TEMPLATE.md) — reusable rulebook structure.

Animation-specific content contracts live under [`40_content/animations/`](40_content/animations/).

### Authoring

- [`50_authoring/AUTHORING_CONTRACT.md`](50_authoring/AUTHORING_CONTRACT.md) — general content-authoring workflow.
- [`50_authoring/FILE_PLACEMENT_GUIDE.md`](50_authoring/FILE_PLACEMENT_GUIDE.md) — practical placement guide for definitions, runtime code, scenes, assets, tools and tests.
- [`50_authoring/ADDING_RIG_PROFILE.md`](50_authoring/ADDING_RIG_PROFILE.md) — rig-profile authoring/import workflow.
- [`50_authoring/ADDING_ANIMATION_SET.md`](50_authoring/ADDING_ANIMATION_SET.md) — semantic animation-set authoring workflow.

### Validation

- [`VALIDATION_HARNESS.md`](VALIDATION_HARNESS.md) — deterministic primitives, stage fingerprints, campaigns and validation architecture.
- [`60_validation/CONTENT_VALIDATION.md`](60_validation/CONTENT_VALIDATION.md) — content validation architecture.
- [`60_validation/REPOSITORY_LAYOUT_VALIDATION.md`](60_validation/REPOSITORY_LAYOUT_VALIDATION.md) — repository/path ownership validation.

The complete workflow/local-runner inventory belongs to DEVX-001. This README remains a navigation page rather than a second validation matrix.

## I need to change X — where do I look first?

| Change | Look here first | Then check |
| --- | --- | --- |
| Deterministic worldgen, topology, entrances or cave definitions | [`GENERATION_PIPELINE_INTERFACES.md`](GENERATION_PIPELINE_INTERFACES.md) | [`STABLE_PROCEDURAL_IDS.md`](STABLE_PROCEDURAL_IDS.md), [`DETERMINISTIC_SEED_DOMAINS.md`](DETERMINISTIC_SEED_DOMAINS.md), [`WORLD_ARCHITECTURE.md`](WORLD_ARCHITECTURE.md) |
| Geometry/runtime cells, streaming or loaded world representation | [`STREAMING_OWNERSHIP.md`](STREAMING_OWNERSHIP.md) | [`10_architecture/REPOSITORY_STRUCTURE.md`](10_architecture/REPOSITORY_STRUCTURE.md), [`GENERATION_PIPELINE_INTERFACES.md`](GENERATION_PIPELINE_INTERFACES.md) |
| Save data, durable world changes or generator compatibility | [`PERSISTENCE_AND_VERSIONING.md`](PERSISTENCE_AND_VERSIONING.md) | [`MAP_DATA_SERIALIZATION_CONTRACT.md`](MAP_DATA_SERIALIZATION_CONTRACT.md), [`STABLE_PROCEDURAL_IDS.md`](STABLE_PROCEDURAL_IDS.md) |
| Player/combat/gameplay behavior | Relevant gameplay contract, e.g. [`PLAYER_ATTACK_CONTRACT.md`](PLAYER_ATTACK_CONTRACT.md) | [`GAME_PILLARS.md`](GAME_PILLARS.md), [`10_architecture/DEPENDENCY_RULES.md`](10_architecture/DEPENDENCY_RULES.md) |
| New item, creature, attack, structure or other authored definition | [`10_architecture/CONTENT_ARCHITECTURE.md`](10_architecture/CONTENT_ARCHITECTURE.md) | [`40_content/CONTENT_IDS.md`](40_content/CONTENT_IDS.md), applicable family rulebook, [`50_authoring/AUTHORING_CONTRACT.md`](50_authoring/AUTHORING_CONTRACT.md) |
| New/changed asset, scene or file location | [`10_architecture/REPOSITORY_STRUCTURE.md`](10_architecture/REPOSITORY_STRUCTURE.md) | [`50_authoring/FILE_PLACEMENT_GUIDE.md`](50_authoring/FILE_PLACEMENT_GUIDE.md), [`10_architecture/DEPENDENCY_RULES.md`](10_architecture/DEPENDENCY_RULES.md) |
| Authoring another valid content member | [`50_authoring/AUTHORING_CONTRACT.md`](50_authoring/AUTHORING_CONTRACT.md) | Applicable rulebook and specialized guide |
| Tests, validation or CI | [`VALIDATION_HARNESS.md`](VALIDATION_HARNESS.md) or relevant [`60_validation/`](60_validation/) contract | Owning subsystem contract and actual workflow/runner |
| Project/documentation governance | [`00_project/DOCUMENTATION_ARCHITECTURE.md`](00_project/DOCUMENTATION_ARCHITECTURE.md) | [`DEVELOPMENT_RULEBOOK.md`](DEVELOPMENT_RULEBOOK.md), [`DECISION_LOG.md`](DECISION_LOG.md) |

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