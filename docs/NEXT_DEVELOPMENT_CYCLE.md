# Underworld — Next Development Cycle

## Architecture foundation status — COMPLETE

The architecture-design cycle that preceded Underworld implementation is complete.

The required contracts are now defined in:

- `UNDERWORLD_GRAPH_SCHEMA.md` — deterministic underground graph/world-definition data;
- `STABLE_PROCEDURAL_IDS.md` — persistent candidate-address identity and prototype-v2 migration mapping;
- `DETERMINISTIC_SEED_DOMAINS.md` — isolated named/revisioned randomness domains;
- `GENERATION_PIPELINE_INTERFACES.md` — pure typed generation-stage inputs/outputs;
- `STREAMING_OWNERSHIP.md` — definition/cache/runtime ownership and continuous surface/Underworld streaming;
- `PERSISTENCE_AND_VERSIONING.md` — explicit generator manifests, delta ownership and compatibility/migration policy;
- `VALIDATION_HARNESS.md` — headless deterministic validation, batch campaigns, fingerprints, migration fixtures and streaming simulations.

These documents answer the architecture questions that had to be resolved before substantial cave-generation code.

---

# Next cycle: Foundation implementation before the cave generator

## Goal

Implement the small reusable deterministic infrastructure that the future Underworld generator depends on, together with its automated tests.

This cycle is **not** the first cave-content cycle yet.

Success means the project has concrete tested primitives for identity, randomness, manifests, graph data and validation so the first topology generator can be written against stable interfaces rather than inventing infrastructure while generating caves.

---

## Required implementation deliverables

### 1. Canonical stable-address / StableId primitives

Implement a central data-only address/ID module that supports at least the semantic categories already required by the architecture:

```text
surface candidate cells/slots
underground regions
network candidates
nodes/edges
entrances
secondary/cross-region connectors
special-location hooks
persistent generated children
```

Requirements:

- no gameplay code manually concatenates identity strings;
- canonical ordering for undirected endpoints;
- negative coordinates are unambiguous;
- equality/sorting/debug representation are deterministic;
- runtime indexes are not part of identity.

Add L0/L1 validation vectors immediately.

### 2. Seed-domain registry and deterministic value/RNG contract

Implement:

```text
SeedDomain registry
explicit immutable domain IDs/names/revisions
central seed derivation from world seed + semantic StableAddress + domain + subkey
project-owned deterministic stateless values and/or local PRNG sequence
```

Before any persistent generator depends on it, commit hard-coded deterministic test vectors.

Do not route new persistent generation through the current mutable per-chunk RNG pattern.

### 3. Generator manifest primitives

Implement data-only types/canonical serialization for:

```text
save/generation contract identity
seed schema version
stable-address schema version
stage revisions
seed-domain revisions
profile/config revisions or references
manifest fingerprint/ID
```

The global manifest identifies the deterministic contract but is not mixed into every RNG seed as a universal salt.

### 4. Pure graph definition classes

Implement the first scene-independent typed classes described in `UNDERWORLD_GRAPH_SCHEMA.md`:

```text
WorldDefinitionIndex
UndergroundRegionDefinition
CaveNetworkDefinition
CaveNodeDefinition
CaveEdgeDefinition
EntranceDefinition
SpecialLocationHookDefinition
```

This cycle does not need to generate interesting caves yet.

The classes must be usable without `Node`, `Node3D`, meshes, physics, AI or audio.

### 5. Canonical serialization / fingerprints / invariant validator

Implement reusable test/debug infrastructure for deterministic data:

```text
canonical sorted representation
fingerprint generation
StableId uniqueness checks
graph reference checks
finite numeric checks
canonical ownership checks
```

A deliberately constructed invalid graph should fail with a precise reason and stable address/ID context.

### 6. Headless validation runner skeleton

Implement the first executable validation entry point capable of:

```text
run fast contract tests
run one named fixture
run one world/region reproduction case
print deterministic fingerprints/diagnostics
return non-zero/failure status for CI or scripts
```

Exact CLI/framework is an implementation choice.

No rendered game window should be required for these tests.

### 7. Prototype-v2 save migration adapter and fixtures

Before incompatible surface decoration/pickup generation changes, implement the legacy mapping path while the current algorithm is still reproducible.

Fixtures should cover at least:

```text
empty modifications
harvested tree/rock
collected branch/stone
multiple destroyed objects
negative chunk coordinates
wood/stone/tool/hotbar state
```

The migration should translate old `chunk_x:chunk_z:type:accepted_index` references to modern StableIds or explicitly quarantine unresolved references.

Do **not** simultaneously redesign surface densities/generation in this cycle.

### 8. Service/interface skeletons only where needed

Create lightweight interfaces/data contracts required to connect future work, such as:

```text
WorldGenerationContext
stage request/result base conventions
WorldDefinitionService interface boundary
WorldDeltaStore logical interface boundary
```

Do not build a large runtime framework just to satisfy the document. Implement only the boundary needed by the next topology cycle and tests.

---

## Explicitly out of scope

Do not add merely because later architecture supports it:

- finished cave topology algorithm;
- cave meshes/art;
- additional enemies or bosses;
- block/parry/dodge/stamina;
- underground ecology/content roster;
- building system;
- finished terrain deformation;
- large-deposit mining implementation;
- inventory/logistics overhaul;
- audio propagation implementation;
- additional surface biomes;
- surface decoration density retuning;
- runtime 3D Underworld streaming cells beyond minimal interface/test scaffolding.

This is an infrastructure/testing cycle.

---

## Testing cadence for this cycle

Manual F5/playtesting is not required for each change.

Use automated/headless tests as the normal validation path:

```text
implement primitive
-> deterministic unit/fixture tests
-> batch/simple headless validation
-> continue
```

A human playtest is unnecessary until a later milestone contains experiential behavior worth judging.

---

## Exit criteria

The foundation implementation cycle is complete when:

1. stable semantic addresses/IDs are concrete and tested;
2. deterministic seed-domain derivation has frozen test vectors;
3. generator manifests can be canonically represented/fingerprinted;
4. pure underground graph definitions exist independently of scene nodes;
5. graph/ID invariant validation and canonical fingerprints work;
6. the test harness can run headlessly and reproduce one exact failing case from seed/address data;
7. prototype-v2 save fixtures migrate safely to modern StableIds;
8. no new gameplay subsystem had to invent its own identity/randomness/persistence convention.

Only after this cycle should the first actual **primary Underworld topology generator** be implemented.
