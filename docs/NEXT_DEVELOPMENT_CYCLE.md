# Underworld — Next Development Cycle

## Cycle: Architecture foundation before Underworld implementation

### Goal

Design the technical architecture required for the Underworld before adding substantial cave-generation/gameplay code.

This cycle is intentionally architecture-heavy. It is successful when the implementation boundaries, data model, persistence model and validation strategy are clear enough that cave code can be added without immediately redesigning foundations.

## Required deliverables

### 1. Stable procedural ID specification — COMPLETE

Defined in `STABLE_PROCEDURAL_IDS.md`.

The architecture now specifies:

- `WorldId`, semantic `StableAddress`, and persisted `StableId` as separate concepts;
- candidate-address identity rather than accepted-array indexes;
- global surface candidate domains/cells plus fixed semantic slots;
- hierarchical underground region/network/node/edge/entrance/special-location addresses;
- canonical endpoint/owner rules for secondary and cross-region connectors;
- parent-derived stable IDs for persistent generated child objects;
- runtime index mappings as transient caches only;
- a one-time migration path from prototype v2 `chunk:type:index` IDs before incompatible surface-density/generation tuning;
- automated ID determinism/migration validation requirements.

Exact textual/binary encoding remains open, but the semantic identity rules are locked.

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

### 3. Deterministic generation seed domains — COMPLETE

Defined in `DETERMINISTIC_SEED_DOMAINS.md`.

The architecture now specifies:

- stable-address + named-domain seed derivation instead of a shared mutable world RNG;
- separate `seed_schema_version`, immutable domain IDs and explicit per-domain revisions;
- global generator version as a compatibility manifest rather than a universal RNG salt;
- independent randomness for unrelated systems and important semantic properties;
- deterministic local sequences/subkeys where a system naturally needs multiple samples;
- a project-owned deterministic RNG/value interface with frozen test vectors before persistent generation depends on it;
- separate topology and geometry randomness domains;
- canonical candidate enumeration/tie resolution;
- parallel/thread-order independence;
- canonical cross-region seed ownership;
- legacy-surface migration considerations and engine/noise fingerprint testing.

The exact low-level hash/PRNG algorithms remain an implementation choice, but must be frozen and protected by hard-coded test vectors before production world generation uses them.

### 4. Generation-stage interfaces — NEXT

Define concrete inputs/outputs and ownership boundaries for:

- macro underground-region generation;
- primary network candidate/topology generation;
- depth-profile assignment/blending;
- entrance candidate generation/selection;
- secondary connectivity proposal/scoring/acceptance;
- special-location hook reservation;
- geometry-description generation;
- runtime streaming/build stage.

The interfaces must preserve the locked separation:

```text
stable addresses + seed domains
        -> pure world/topology definitions
        -> geometry descriptions
        -> runtime scene representation
```

No generation stage should require Godot scene-tree nodes merely to produce deterministic world truth.

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
- generator version/manifest;
- seed-schema/domain revision recording where required;
- delta ownership;
- stable-ID references;
- migration boundaries;
- behavior when a future generation algorithm changes incompatibly.

### 7. Test/validation harness specification

Before large generator implementation, define a headless/simple test runner capable of batch seeds.

Initial validation targets:

- deterministic seed test vectors;
- stable IDs;
- valid graph references;
- entrance validity/reachability;
- depth constraints;
- bounded topology/connectivity;
- canonical serialization/fingerprints;
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
2. How is every persistent generated object addressed stably? **Answered by `STABLE_PROCEDURAL_IDS.md`.**
3. How is randomness isolated from load order, thread scheduling, sibling rejection and unrelated generator changes? **Answered by `DETERMINISTIC_SEED_DOMAINS.md`.**
4. How do shallow/mid/deep profiles feed the topology generator? **Data representation answered; generation-stage interface/curves still pending.**
5. How are 1–3 entrances and secondary loops generated, represented and validated? **Representation answered; stage interfaces/scoring contract still pending.**
6. What gets generated on worker threads versus instantiated on the main thread?
7. What is saved versus regenerated, and how are generator compatibility boundaries represented?
8. How can hundreds/thousands of seeds be validated without manual exploration?

Only after these answers are reflected in concrete interfaces/data structures should the main Underworld generator implementation begin.
