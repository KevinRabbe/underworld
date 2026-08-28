# Underworld Project Glossary

Status: **canonical terminology index**

This glossary is a navigation aid for reviews, task claims, implementation handoffs and documentation. It summarizes existing project terms; it does **not** replace the authoritative architecture and contract documents linked below.

If a short definition here appears to conflict with an authoritative contract, the contract wins and the glossary should be corrected.

## Authoritative sources

- [Stable Procedural ID Architecture](../STABLE_PROCEDURAL_IDS.md) — `WorldId`, `StableAddress`, procedural `StableId`, deterministic ownership.
- [Deterministic Generation Seed Domains](../DETERMINISTIC_SEED_DOMAINS.md) — seed derivation, domain IDs and domain revisions.
- [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md) — generation stages, macro regions, cave networks, entrances, special-location hooks and base geometry.
- [Persistence and Generator Versioning](../PERSISTENCE_AND_VERSIONING.md) — generator manifests, deterministic baseline versus durable deltas and compatibility boundaries.
- [Streaming Ownership and Runtime Lifetime](../STREAMING_OWNERSHIP.md) — geometry cells, runtime cells, ownership layers and representation tiers.
- [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md) and [Content ID Rules](../40_content/CONTENT_IDS.md) — authored definitions, semantic content identity and runtime instances.
- [Repository and File Architecture](../10_architecture/REPOSITORY_STRUCTURE.md) — filesystem/system ownership versus game identity.
- [Documentation Architecture](DOCUMENTATION_ARCHITECTURE.md) — documentation placement and numbering rules.

## Terms

### Authored definition
A stable data description of a game concept, usually identified by a **semantic content ID**. Definitions contain data and references; they do not own scene-tree lifetime or runtime simulation.

**Not:** a live Node, a procedural world instance, or a filesystem path.

Source: [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md).

### Base world truth / deterministic base truth
The untouched world produced by the deterministic generation contract for a world seed and generator manifest: topology, base geometry, entrances, procedural placement and other deterministic definitions.

It is regenerated when needed and then composed with durable changes to obtain current world state.

**Not:** player mining, harvested-object state, player buildings, cleared collapses or other durable changes.

Sources: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Persistence and Generator Versioning](../PERSISTENCE_AND_VERSIONING.md).

### Cave network
A deterministic topology component inside the underground world, containing stable nodes and edges produced by primary topology generation. Network identity belongs to deterministic generation lineage, not to a geometry cell or runtime cell.

One network may cross many geometry/runtime cells.

Sources: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Streaming Ownership and Runtime Lifetime](../STREAMING_OWNERSHIP.md).

### Entrance
A deterministic world-definition object selected after primary cave topology exists. An entrance connects surface space to underground topology and may produce a pure-data surface integration descriptor describing required opening/clearance geometry.

**Not:** merely a random terrain hole, loaded entrance mesh or runtime scene.

Source: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md).

### Fragment
A bounded cell-local geometry representation derived from a canonical source world-definition object and a geometry-cell address. Fragments let one chamber, tunnel, entrance opening or reserved site contribute geometry across cell boundaries.

A fragment does **not** create a new persistent gameplay identity for the source object merely because geometry was split across cells.

Source: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), especially geometry ownership across cells.

### Generation stage
One deterministic pure-data transformation in the world-generation pipeline. A stage consumes explicit context plus typed inputs and produces deterministic typed output/fingerprints without depending on scene-tree state, player state, wall-clock time or worker completion order.

Stage algorithm revisions belong to the generator contract and remain distinct from seed-domain revisions.

Source: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md).

### Generator manifest
The canonical description/fingerprint of the deterministic generation contract for a world. It pins the versions/revisions/configuration needed to reproduce world truth, including stage, seed-domain, address/schema and relevant profile/config revisions.

**Not:** a universal random salt. A manifest change does not imply that every seed domain must produce different randomness.

Source: [Persistence and Generator Versioning](../PERSISTENCE_AND_VERSIONING.md).

### Geometry cell
A bounded deterministic base-geometry generation/cache partition. Geometry cells own cell-local geometry plans/fragments, while source cave graph objects retain their graph/persistent identity.

**Not:** a cave network and not necessarily the same partition as a runtime streaming cell. The two grids may coincide initially without being architecturally identical.

Sources: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Streaming Ownership and Runtime Lifetime](../STREAMING_OWNERSHIP.md).

### Macro region
The deterministic high-level generation and ownership partition used to plan an area of the Underworld before individual cave networks are built. Stage 1 creates its candidate slots, bounds, regional tendencies and later-stage context.

**Not:** a runtime streaming lifetime unit.

Sources: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Streaming Ownership and Runtime Lifetime](../STREAMING_OWNERSHIP.md).

### Owner / contributor
**Owner** means the canonical authority chosen by the relevant contract when multiple regions, cells or systems touch the same thing. A **contributor** is a non-owning input/overlap participant that may contribute data or a fragment without becoming the authoritative owner.

Ownership is contract-specific: for example, cross-region connectors have one canonical owner; graph objects keep graph ownership while geometry cells own their local fragments; runtime streamers own live representation but not deterministic truth or durable state.

**Do not infer owner from:** load order, worker completion order, current caller, array position or filesystem path.

Sources: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Streaming Ownership and Runtime Lifetime](../STREAMING_OWNERSHIP.md).

### Player/world delta / durable delta
Persistent state describing explicit changes relative to deterministic base truth, such as harvested generated objects, persistent object state, terrain/deformation changes, special-location state or player-built structures.

The logical durable owner is `WorldDeltaStore`. Runtime cells may query/cache delta views but do not own the durable state.

**Not:** the base cave graph or a serialized copy of every visited generated region.

Sources: [Persistence and Generator Versioning](../PERSISTENCE_AND_VERSIONING.md), [Streaming Ownership and Runtime Lifetime](../STREAMING_OWNERSHIP.md).

### Provenance
Pure generation metadata that binds a generated result to the world/generator context, stage/region identity and the exact source-stage ancestry used to produce it. Provenance is used to detect mixed, stale or otherwise incoherent generation inputs across stage boundaries.

**Not:** gameplay ownership, save history or filesystem authorship.

Sources: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md) for stage/context boundaries and the implemented [GenerationProvenance contract](../../worldgen/pipeline/generation_provenance.gd).

### Reserved site
A deterministic location/clearance reservation produced from special-location hook planning and carried into geometry so later content systems can realize something there without topology code spawning that gameplay directly.

Potential uses include deposits, structures, boss lairs, ancient complexes or collapses.

**Not:** the actual spawned boss, resource, structure or encounter.

Source: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), especially Special-Location Hook Reservation and Base Geometry Description Generation.

### Runtime cell
A lifetime/LOD partition for currently live underground representation. Runtime cells may own Nodes, meshes, collision bodies and local runtime proxies while active.

They do **not** own the authoritative deterministic cave graph or durable save state, and they are architecturally separate from geometry cells even if both initially use the same grid.

Source: [Streaming Ownership and Runtime Lifetime](../STREAMING_OWNERSHIP.md).

### Runtime realization
The temporary live representation created from deterministic/authored definitions, geometry, assets and relevant delta views: Nodes, meshes, collision, interactable proxies and similar runtime objects.

Runtime realization may be discarded and rebuilt as streaming demand changes.

**Not:** semantic content identity, procedural StableId or durable world state.

Sources: [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md), [Streaming Ownership and Runtime Lifetime](../STREAMING_OWNERSHIP.md).

### Seed domain
A named deterministic-randomness responsibility with a permanent domain identifier and explicit domain revision. Each persistent random decision derives from the world seed, domain, stable address and optional subkey rather than a shared mutable RNG stream.

A domain revision changes only the intended randomness responsibility; it is not interchangeable with a generator-manifest revision.

Source: [Deterministic Generation Seed Domains](../DETERMINISTIC_SEED_DOMAINS.md).

### Semantic content ID
A stable lowercase dot-separated identifier answering **what game concept is this?**, such as `item.weapon.iron_sword` or `creature.underworld.burrower`.

It remains independent from file paths, documentation numbers, runtime Nodes and procedural instance identity.

**Not:** a procedural `StableId`. A generated object may carry both a content ID (what it is) and a StableId (which generated instance it is).

Sources: [Content ID Rules](../40_content/CONTENT_IDS.md), [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md).

### StableAddress
The canonical semantic address explaining where a persistent procedural identity comes from in deterministic generation space: region, candidate domain/slot, network lineage, entrance slot, connector endpoints, and similar stable components.

Identity/randomness may both use the address, but they remain separate concepts.

**Not:** an array index, runtime Node path, loaded chunk index or file path.

Source: [Stable Procedural ID Architecture](../STABLE_PROCEDURAL_IDS.md).

### StableId
The canonical persistent identifier derived for a deterministic generated candidate/address and referenced by generated definitions and save deltas.

Within a world/save scope, it answers **which generated instance/location is this?** Cross-world/global references use it together with `WorldId`.

**Not:** a semantic content ID, runtime instance ID or manually concatenated gameplay string.

Source: [Stable Procedural ID Architecture](../STABLE_PROCEDURAL_IDS.md).

### Streaming tier
One level in the progressive runtime-representation cost model. The current architecture names T0–T6, from uncached address/world definition through definition, geometry, render, collision, simulation/interactables and local audio representation.

Tiers describe **how much representation is currently live/cached**, not whether the deterministic world object exists.

Source: [Streaming Ownership and Runtime Lifetime](../STREAMING_OWNERSHIP.md).

### WorldId
Identity for one generated world/seed scope. It disambiguates procedural identities when references leave the save/world scope; global references use `(WorldId, StableId)`.

**Not:** a semantic content ID or a replacement for `StableAddress`.

Source: [Stable Procedural ID Architecture](../STABLE_PROCEDURAL_IDS.md).

## Commonly confused pairs

| Pair | Canonical distinction |
| --- | --- |
| **StableId vs semantic content ID** | StableId identifies **which deterministic generated instance/location**; semantic content ID identifies **what authored game concept** it is. A generated object may have both. |
| **Geometry cell vs runtime cell** | Geometry cell partitions deterministic base-geometry generation/cache; runtime cell partitions the lifetime/LOD of live representation. They may share a grid without becoming the same contract. |
| **Deterministic base truth vs durable delta** | Base truth is regenerated from seed/contracts. Durable delta records persistent changes relative to that baseline and is owned by `WorldDeltaStore`. |
| **Manifest revision vs seed-domain behavior** | The generator manifest pins the complete compatible generation contract. A seed-domain revision isolates intentional randomness changes for one semantic random responsibility; a manifest change is not a universal RNG reseed. |
| **Filesystem ownership vs semantic identity** | Repository paths express which system/content family owns a file. Semantic content IDs and procedural StableIds remain stable game identities and must not be derived from those paths. |
| **Cave network vs cell** | A cave network is topology/identity; geometry/runtime cells are spatial generation/lifetime partitions. One network may cross many cells. |
| **Definition vs runtime realization** | Definitions are stable data/contracts. Runtime realization is temporary live representation built from those definitions/assets and may be unloaded/rebuilt. |

## Introducing a future glossary term

Add a term here only when it already exists in an accepted contract, implementation boundary or authoritative architecture document. Link that source, define what the term means and—where confusion is plausible—what it explicitly does **not** mean.

Do not use the glossary to introduce new architecture. If a term exposes a conflict between existing contracts, record the conflict for the owning architecture/task and resolve it there before making the glossary choose a new meaning.
