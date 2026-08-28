# Underworld Project Glossary

Status: **Canonical terminology index**

This document is a review/task-claim aid, not a second architecture specification. It summarizes existing project terms and points to the contract that owns each meaning.

If this glossary conflicts with an authoritative linked contract, **the authoritative contract wins** and the glossary should be corrected.

## Identity at a glance

| Question | Canonical identity |
| --- | --- |
| Which seeded world is this? | `WorldId` |
| Which exact deterministic generation contract produced it? | `GeneratorManifest` / manifest ID |
| Which procedural candidate/location is this? | `StableAddress` / `StableId` |
| What authored kind of game content is this? | semantic content ID |
| Which bounded geometry partition is this? | geometry-cell address |
| Which live runtime partition currently owns representation? | runtime-cell identity/address |

These identities are deliberately separate.

## Canonical terms

### Authored definition
A stable data description of one authored game concept, identified by a **semantic content ID** and resolved to its current data/assets. Definitions do not own scene-tree lifetime or runtime simulation.

**Not:** a generated-world instance, a live `Node`, a file path, or a procedural `StableId`.

Authority: [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md), [Content Registry](../10_architecture/CONTENT_REGISTRY.md).

### Base world truth / deterministic base truth
The untouched procedural baseline reproduced from the world seed plus the pinned compatible generation contract. Examples include untouched cave topology, entrances, base geometry, procedural placement, and special-location hooks.

It may be cached, evicted, and regenerated. The cache is not authoritative state.

**Not:** a visited-map snapshot, runtime scene state, or a player/world delta.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md).

### Cave network
A persistent topology component/identity inside the Underworld graph. Networks contain/own topological nodes and edges according to the generation contracts.

A network may cross multiple geometry/runtime cells, and a cell may contain fragments from more than one network.

**Not:** a geometry cell, runtime cell, floor, loaded scene, or streaming ownership unit.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md).

### Entrance
A deterministic world-definition object selected against already-generated cave topology to connect surface space with the Underworld. Surface integration is exposed as pure `SurfaceEntranceIntegrationDescriptor` data describing opening/clearance and connection requirements.

**Not:** a random hole placed independently of topology, a teleport requirement, a mesh, or a live portal `Node`.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md).

### Fragment / geometry fragment
A cell-local pure-data contribution produced when one source geometry descriptor overlaps one geometry cell. A cross-cell chamber/tunnel therefore yields multiple fragments that retain reference to the same source procedural identity.

Fragment identity (for example `gfrag1`) is partition/processing identity; it does **not** create a new persistent gameplay `StableId` for each cell crossing.

**Not:** a new cave network, new procedural object, runtime mesh instance, or durable save object.

Authority: [Streaming Ownership](../STREAMING_OWNERSHIP.md), [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md). Executable contract: [`geometry_cell_fragment.gd`](../../worldgen/geometry/geometry_cell_fragment.gd).

### Generation stage
One deterministic pure-data transformation in the world-generation pipeline. A stage consumes an immutable context and typed inputs and produces a result/diagnostics/fingerprint without depending on SceneTree state, player state, wall-clock time, shared mutable RNG, or worker completion order.

**Not:** a streaming tier, loading phase, gameplay state, or arbitrary sequence of runtime callbacks.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md).

### Generator manifest
The canonical identity/description of the **complete deterministic generation contract** needed to reproduce world truth: seed schema, stable-address schema, stage revisions, seed-domain revisions, profile/config revisions, and other pinned deterministic dependencies.

The manifest is a compatibility contract, **not a universal random salt**. The same `WorldId` may be associated with a different manifest when generation contracts change.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Deterministic Seed Domains](../DETERMINISTIC_SEED_DOMAINS.md).

### Geometry cell
A bounded 3D partition used for deterministic base-geometry planning/generation/cache work. It has its own spatial address (currently a `gcell1` contract) and may contain fragments from several source networks/regions.

Geometry cells are allowed to share an initial grid with runtime cells for convenience, but the architecture does not equate them.

**Not:** a macro region, a cave network, a gameplay `StableId`, or the authoritative lifetime owner of live Nodes.

Authority: [Streaming Ownership](../STREAMING_OWNERSHIP.md). Executable address contract: [`geometry_cell_address.gd`](../../worldgen/geometry/geometry_cell_address.gd).

### Macro region
The deterministic Underworld **generation/ownership partition** used to plan regional tendencies, candidate slots, topology dependencies, entrances, connectivity, and special-location hooks.

Macro-region boundaries organize deterministic generation; they do not imply hard gameplay floors or runtime loading boundaries.

**Not:** a runtime cell, geometry cell, cave network, or shallow/mid/deep floor.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md).

### Owner / contributor
These words are contract-scoped and must be qualified when ambiguity is possible.

For **geometry fragments**, one intersected cell is the canonical owner for a source descriptor and other intersected cells are contributors carrying cell-local fragments/continuation data. That ownership prevents duplicate source ownership; it does not manufacture new gameplay StableIds.

Other contracts also use ownership (for example canonical cross-region edge owner or live runtime owner). Do not assume those meanings are interchangeable merely because the word `owner` is reused.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md).

### Player/world delta / durable delta
Persisted state that changes or supplements deterministic base truth: destroyed/harvested generated objects, persistent object state, changed special locations, terrain modifications, player-created objects, and other explicit durable state.

Generated-object deltas normally reference procedural `StableId`s; player-created objects use their own persistent identity category.

**Not:** untouched procedural world truth, a disposable cache entry, or runtime-cell-owned state.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Map Data Serialization Contract](../MAP_DATA_SERIALIZATION_CONTRACT.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md).

### Provenance / generation provenance
Canonical ancestry metadata attached to deterministic stage results so consumers can verify that inputs belong to the expected world/generator/stage/region and exact upstream fingerprint set.

Current provenance binds at least `WorldId`, generator-manifest ID, stage identity/revision, optional region identity/address, and source-stage fingerprints.

A `StableId` alone is not provenance: the same semantic procedural address can exist under more than one world/generation context.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md). Executable contract: [`generation_provenance.gd`](../../worldgen/pipeline/generation_provenance.gd).

### Reserved site / special-location hook
A deterministic topology/world-definition reservation that preserves a stable anchor and required bounds/clearance for later authored or gameplay content such as deposits, structures, boss spaces, complexes, or collapses.

The reservation says **where/what space is reserved**, not which final boss/resource/structure instance is already spawned there.

**Not:** runtime content activation or progression-dependent spawning performed by topology generation.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md).

### Runtime cell
A 3D **lifetime/LOD partition for live Underworld representation**. Runtime cells own current live representations such as runtime roots, meshes, collision bodies, and local proxies, while referencing canonical source identities.

Runtime cells may unload safely because deterministic definitions and durable deltas are owned elsewhere.

**Not:** deterministic world truth, a geometry cell by definition, persistent save ownership, or a cave network.

Authority: [Streaming Ownership](../STREAMING_OWNERSHIP.md).

### Runtime realization / runtime instance
A temporary live representation produced from deterministic definitions, authored definitions/assets, and applicable deltas. Runtime systems/scene trees own its lifetime.

Examples include live meshes, collision, interactable proxies, creature instances, audio players, and other active engine objects.

**Not:** semantic content identity, procedural world identity, durable delta ownership, or the authoritative definition itself.

Authority: [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md).

### Seed domain / generation domain
A named, revisioned semantic source of deterministic randomness. A derived seed is a pure function of root world seed, seed-schema version, domain identity/revision, stable semantic address, and optional subkey.

Domains isolate unrelated random decisions so adding/changing one subsystem does not consume a shared RNG stream and reshuffle unrelated generation.

**Not:** a global mutable RNG, arbitrary salt, stage revision, or generator-manifest ID.

Authority: [Deterministic Seed Domains](../DETERMINISTIC_SEED_DOMAINS.md).

### Semantic content ID
The stable authored identity answering **what kind of thing is this?** Examples include `item.weapon.iron_sword` or `creature.underworld.burrower`.

It resolves through content architecture/registry rules and remains independent of file paths and runtime Node identity.

**Not:** the identity of a specific generated instance/location. That is procedural `StableAddress`/`StableId` territory.

Authority: [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md), [Content Registry](../10_architecture/CONTENT_REGISTRY.md).

### StableAddress
A canonical, readable, deterministic **semantic address for a procedural candidate/location/lineage**. Candidate slots are addressable before acceptance so rejected siblings and array compaction do not renumber later identities.

The address is semantic rather than runtime-order based and is also the anchor used by deterministic seed derivation.

**Not:** a semantic content ID, runtime Node path/instance ID, array index, or proof that data came from a particular world seed/manifest.

Authority: [Deterministic Seed Domains](../DETERMINISTIC_SEED_DOMAINS.md), [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md). Executable contract: [`stable_address.gd`](../../worldgen/identity/stable_address.gd).

### StableId
The canonical persistent procedural identifier derived from a `StableAddress` (current namespace `sid1`). It answers **which generated procedural candidate/location is this?** and is used for graph/object references and durable generated-object deltas.

Because procedural addresses are semantic and seed-independent, a `StableId` by itself does not prove world/generator provenance.

**Not:** a semantic content ID, player-created-object ID, runtime Node ID, geometry-fragment ID, or file path.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md). Executable contract: [`stable_id.gd`](../../worldgen/identity/stable_id.gd).

### Streaming tier / runtime representation tier
A level of **current representation cost/availability**, not existence. The streaming architecture currently describes tiers from deterministic definition/cache state through geometry, render, collision, nearby simulation/interactables, and local audio.

Different tiers may use different activation radii and release hysteresis. Dropping a tier must not delete deterministic truth or durable deltas.

**Not:** a generation stage, cave depth profile, world version, or gameplay progression tier.

Authority: [Streaming Ownership](../STREAMING_OWNERSHIP.md).

### WorldId
The stable identity of the seeded world under the current world-ID contract (currently derived canonically from the root world seed and represented in the `wid1` namespace).

`WorldId` identifies the world, while the generator manifest identifies the exact deterministic generation contract used to interpret/reproduce that world. Caches and provenance commonly need both.

**Not:** save-slot identity, semantic content identity, procedural object identity, or generator-manifest identity.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md). Executable contract: [`world_id.gd`](../../worldgen/identity/world_id.gd).

## Commonly confused boundaries

### StableId vs semantic content ID

```text
semantic content ID -> what authored kind is it?
StableId           -> which generated procedural instance/location is it?
```

A generated copper deposit may legitimately carry both a content ID describing copper-deposit rules and a procedural StableId identifying that specific generated deposit. Never collapse the two identity systems.

### Geometry cell vs runtime cell

```text
geometry cell -> bounded deterministic geometry planning/cache partition
runtime cell  -> live representation lifetime/LOD partition
```

They may share coordinates/grid dimensions in an implementation, but code must not require permanent one-to-one equivalence.

### Deterministic base truth vs durable delta

```text
base truth -> regenerate from seed + pinned generation contract
delta      -> save persistent change/state against that baseline
```

Deleting a deterministic cache is allowed; deleting a durable delta loses player/world state.

### Manifest revision vs seed-domain behavior

A generator manifest pins the full generation contract, including non-random algorithm/config/stage changes. Seed-domain revisions control isolated deterministic randomness behavior for named decisions.

Changing manifest identity does **not** imply every domain seed must change, and manifest ID must not be mixed into all randomness as a universal salt.

### Filesystem ownership vs semantic identity

Repository paths define **code/document ownership and dependency boundaries**. They do not define persistent game identity.

A content definition may move files without changing its semantic content ID. Procedural StableIds come from StableAddresses, not source paths. Runtime scene paths/Node IDs are likewise not durable semantic identity.

Authority: [Repository Structure](../10_architecture/REPOSITORY_STRUCTURE.md), [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md), [Documentation Architecture](DOCUMENTATION_ARCHITECTURE.md).

## Adding a future glossary term

Add a term here only after its meaning exists in an authoritative architecture, rulebook, interface contract, or executable contract.

For every new entry:
1. state the narrow project meaning;
2. state the most likely **not this** confusion;
3. link the authoritative source;
4. if existing sources conflict, report/fix the conflict at its owning contract first instead of silently choosing a new meaning in the glossary.

The glossary indexes architecture; it does not create architecture.
