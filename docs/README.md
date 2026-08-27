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

Existing code is not automatically the design. Prototype code may be replaced when it conflicts with the documented architecture.

## Documents

- `GAME_PILLARS.md` — what Underworld is and what it should not drift into.
- `WORLD_ARCHITECTURE.md` — surface/Underworld relationship, depth layers, cave topology, entrances, connectivity, building freedom, terrain modification, and audio rules.
- `MINING_AND_RESOURCES.md` — small-node harvesting versus large-deposit excavation.
- `TECHNICAL_ARCHITECTURE.md` — system boundaries: deterministic definitions, topology, geometry descriptions, runtime representation, streaming, persistence and validation.
- `UNDERWORLD_GRAPH_SCHEMA.md` — concrete pure-data schema for regions, networks, nodes, edges, entrances, cross-region links and future special-location hooks.
- `STABLE_PROCEDURAL_IDS.md` — candidate-address identity model for surface/underground generation plus migration from prototype v2 accepted-array-index IDs.
- `DETERMINISTIC_SEED_DOMAINS.md` — named/revisioned randomness domains, stable-address seed derivation, project-owned deterministic RNG contract and parallel-safe generation rules.
- `GENERATION_PIPELINE_INTERFACES.md` — pure-data stage contracts from macro region planning through topology, entrances, connectivity, special hooks, geometry descriptions and runtime handoff.
- `STREAMING_OWNERSHIP.md` — definition/cache/runtime ownership, surface/Underworld overlap, streaming tiers, async request lifetime and delta separation.
- `DEVELOPMENT_RULEBOOK.md` — architecture-first development, testing cadence, persistence, deterministic generation, and feature-scope rules.
- `NEXT_DEVELOPMENT_CYCLE.md` — current architecture deliverables and exit criteria before main Underworld generator implementation.
- `DECISION_LOG.md` — chronological record of locked decisions and later revisions.

## Change rule

A locked rule may change, but only deliberately. When changing one:

1. state why the old rule is insufficient;
2. describe the replacement;
3. update the affected document;
4. add an entry to `DECISION_LOG.md`;
5. then change implementation.

Do not silently change a locked design because a local implementation is easier.
