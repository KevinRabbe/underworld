# Underworld — Next Development Cycle

## Cycle: Architecture foundation before Underworld implementation

### Goal

Design the technical architecture required for the Underworld before adding substantial cave-generation/gameplay code.

This cycle is intentionally architecture-heavy. It is successful when the implementation boundaries, data model, persistence model and validation strategy are clear enough that cave code can be added without immediately redesigning foundations.

## Required deliverables

### 1. Stable procedural ID specification — NEXT

Define the concrete stable-ID/address scheme for:

- surface procedural objects;
- underground regions/networks/nodes/edges/entrances;
- generated resources/special locations;
- locally generated child objects.

Include a migration strategy for existing prototype index-based saved object IDs.

### 2. Underground world-definition schema — COMPLETE

Defined in `UNDERWORLD_GRAPH_SCHEMA.md`.

The schema now specifies:

- pure data-only world/region/network/node/edge/entrance definitions;
- continuous shallow/mid/deep profile blends;
- stable network identity after secondary connections;
- accepted proximity/loop connections as stable graph edges;
- canonical ownership requirement for cross-region edges;
- future special-location hooks;
- immutable finalized definitions plus player delta state;
- required graph invariants and canonical deterministic debug serialization.

Exact class/field spellings may change during implementation, but the semantic boundaries are now architecture rules.

### 3. Deterministic generation seed domains

Specify how seeds are derived so generation remains independent of:

- load order;
- thread scheduling;
- unrelated generation-stage changes where practical.

### 4. Generation-stage interfaces

Define inputs/outputs for:

- macro region generation;
- primary network topology;
- entrance selection;
- depth-profile assignment/blending;
- secondary connectivity/loop analysis;
- geometry-description generation;
- runtime streaming/build stage.

### 5. Streaming ownership model

Define which system owns:

- generated definitions/cache;
- loaded underground geometry;
- collision activation;
- active creatures/interactables;
- transitions between surface and underground streaming.

The design must support one continuous world without requiring all underground content to be instantiated.

### 6. Persistence and generation-version strategy

Define:

- save version;
- generator version;
- delta ownership;
- stable-ID references;
- migration boundaries;
- behavior when a future generation algorithm changes incompatibly.

### 7. Test/validation harness specification

Before large generator implementation, define a headless/simple test runner capable of batch seeds.

Initial validation targets:

- determinism;
- stable IDs;
- valid graph references;
- entrance validity/reachability;
- depth constraints;
- bounded topology/connectivity;
- reproducible failure output.

## Explicitly out of scope for this cycle

Do not add merely because the design discusses them:

- additional enemies;
- bosses;
- block/parry/dodge/stamina;
- production cave art;
- underground ecology/content roster;
- building system;
- finished terrain deformation;
- large-deposit mining implementation;
- inventory/logistics overhaul;
- audio propagation implementation;
- additional surface biomes.

They may influence interfaces where future compatibility matters, but they are not implementation targets now.

## Exit criteria

The architecture cycle is complete when we can answer, concretely and without hand-waving:

1. What deterministic data describes an underground cave system before any Godot scene nodes exist? **Answered by `UNDERWORLD_GRAPH_SCHEMA.md`.**
2. How is every persistent generated object addressed stably?
3. How do shallow/mid/deep profiles feed the topology generator? **Data representation answered; generation curves/interface still pending.**
4. How are 1–3 entrances and secondary loops represented and validated? **Representation answered; generator interface/scoring parameters still pending.**
5. What gets generated on worker threads versus instantiated on the main thread?
6. What is saved versus regenerated?
7. How can hundreds/thousands of seeds be validated without manual exploration?

Only after these answers are reflected in concrete interfaces/data structures should the main Underworld generator implementation begin.
