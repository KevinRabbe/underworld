# Underworld Design Documentation

This directory is the authoritative design and architecture reference for the project.

The purpose is to prevent accidental design drift while still allowing deliberate changes when playtesting or technical evidence shows that a rule should change.

## Decision status

Every important rule should be treated as one of three states:

- **LOCKED** — implementation must follow this unless we explicitly revise the rule.
- **DIRECTIONAL** — strong current direction, but exact parameters are still expected to change.
- **OPEN** — intentionally undecided; do not accidentally hard-code a permanent solution.

## Authority order

When sources disagree, use this order:

1. Latest explicit decision recorded in `DECISION_LOG.md`.
2. Locked rules in the relevant design document.
3. Architecture specifications.
4. Existing implementation.
5. Old prototype behavior.

Existing code is not automatically the design. Prototype code may be replaced when it conflicts with documented architecture.

## Documentation architecture

New scalable documentation uses ordered top-level sections:

```text
docs/
├─ 00_project/
├─ 10_architecture/
├─ 20_world/
├─ 30_gameplay/
├─ 40_content/
├─ 50_authoring/
└─ 60_validation/
```

The numeric prefixes are internal reading/order markers only. They are not patch numbers, content IDs, runtime namespaces or save identifiers.

See `00_project/DOCUMENTATION_ARCHITECTURE.md` for the organization contract and migration rules.

Existing root-level documents remain authoritative until they are deliberately migrated in documentation-only changes. Do not move active contracts merely for cosmetic organization.

## New architecture package

### Project/documentation governance
- `00_project/DOCUMENTATION_ARCHITECTURE.md` — numbered documentation hierarchy, document types, migration policy and scaling gate.

### Core architecture
- `10_architecture/CONTENT_ARCHITECTURE.md` — definition/category/capability/asset/runtime separation.
- `10_architecture/CONTENT_REGISTRY.md` — future semantic-ID registry/resolution boundary.
- `10_architecture/DEPENDENCY_RULES.md` — allowed and forbidden dependency direction.

### Content contracts
- `40_content/CONTENT_RULEBOOK.md` — meta-rule defining what every scalable family rulebook must answer.
- `40_content/CONTENT_IDS.md` — stable semantic content identity rules.
- `40_content/CONTENT_CATEGORIES.md` — controlled hierarchical classification rules.
- `40_content/CONTENT_CAPABILITIES.md` — behavioral composition contracts.
- `40_content/CONTENT_REFERENCES.md` — typed semantic reference and cycle rules.
- `40_content/RULEBOOK_TEMPLATE.md` — reusable family-rulebook template.
- `40_content/animations/ANIMATION_SET_RULEBOOK.md` — first family-specific rulebook; animation implementation remains deferred.

### Authoring
- `50_authoring/AUTHORING_CONTRACT.md` — project-wide content authoring workflow.
- `50_authoring/ADDING_ANIMATION_SET.md` — first family-specific authoring guide.

### Validation
- `60_validation/CONTENT_VALIDATION.md` — staged machine-enforcement architecture for IDs, categories, capabilities, definitions, references and assets.

## Existing authoritative documents

The following root documents remain authoritative while staged migration is pending:

- `GAME_PILLARS.md` — what Underworld is and what it should not drift into.
- `WORLD_ARCHITECTURE.md` — surface/Underworld relationship, depth layers, cave topology, entrances, connectivity, building freedom, terrain modification, and audio rules.
- `MINING_AND_RESOURCES.md` — small-node harvesting versus large-deposit excavation.
- `TECHNICAL_ARCHITECTURE.md` — system boundaries: deterministic definitions, topology, geometry descriptions, runtime representation, streaming, persistence and validation.
- `UNDERWORLD_GRAPH_SCHEMA.md` — concrete pure-data schema for regions, networks, nodes, edges, entrances, cross-region links and future special-location hooks.
- `STABLE_PROCEDURAL_IDS.md` — candidate-address identity model for surface/underground generation plus migration from prototype v2 accepted-array-index IDs.
- `DETERMINISTIC_SEED_DOMAINS.md` — named/revisioned randomness domains, stable-address seed derivation, project-owned deterministic RNG contract and parallel-safe generation rules.
- `GENERATION_PIPELINE_INTERFACES.md` — pure-data stage contracts from macro region planning through topology, entrances, connectivity, special hooks, geometry descriptions and runtime handoff.
- `STREAMING_OWNERSHIP.md` — definition/cache/runtime ownership, surface/Underworld overlap, streaming tiers, async request lifetime and delta separation.
- `PERSISTENCE_AND_VERSIONING.md` — save/delta ownership, generator manifests, compatibility classification and transactional migration rules.
- `VALIDATION_HARNESS.md` — deterministic primitives, stage fingerprints, graph invariants, batch-seed campaigns, migration fixtures and streaming-lifetime tests.
- `PROTOTYPE_CHARACTER.md` — replaceable humanoid mannequin, movement/defense states, stamina, combat facing and prototype controls.
- `PLAYER_ATTACK_CONTRACT.md` — data-driven player melee ownership, startup/active/recovery phases, immutable execution messages and hit-resolution boundaries.
- `PLAYER_INPUT_BUFFER.md` — one-slot expiring combat intent buffer, ownership boundary, execution-time attack state and reset/expiry rules.
- `DEVELOPMENT_RULEBOOK.md` — architecture-first development, testing cadence, persistence, deterministic generation, and feature-scope rules.
- `NEXT_DEVELOPMENT_CYCLE.md` — current architecture-cycle completion state and handoff into foundational implementation.
- `DECISION_LOG.md` — chronological record of locked decisions and later revisions.

## Core scaling principle

Underworld systems should scale primarily by adding definitions, categories, capabilities, assets and compositions—not by adding special-case branches to central managers.

Before a content family becomes large, establish its architecture placement, stable identity, rulebook, authoring guide and validation contract.

## Change rule

A locked rule may change, but only deliberately. When changing one:

1. state why the old rule is insufficient;
2. describe the replacement;
3. update the affected document;
4. add an entry to `DECISION_LOG.md`;
5. then change implementation.

Do not silently change a locked design because a local implementation is easier.
