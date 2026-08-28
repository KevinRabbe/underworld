# Underworld Cross-System Ownership and Dependency Map

Status: **architecture index; authoritative contracts remain the linked documents**

This document is a compact routing map for workers deciding **which subsystem owns a concern** and **which identities may cross a boundary**. It summarizes existing architecture; it does not redefine generator, runtime, persistence, gameplay, or content contracts.

If this map conflicts with a linked authoritative contract, the authoritative contract wins and this map must be corrected.

## Reading the dependency arrows

In the diagrams below:

```text
A -> B
```

means **B may consume A's public contract/data**. It does not grant B ownership of A's state or identity.

The broad direction is:

```text
project/core contracts
        |
        +-> deterministic world definition/generation
        |       -> geometry description + partitioning
        |               -> runtime streaming/realization
        |                       -> presentation adapters/assets
        |
        +-> authored content definitions
        |       -> gameplay/simulation
        |               -> runtime instances / presentation state
        |
        +-> persistence schemas + WorldDeltaStore
                -> runtime/gameplay restoration and composition

developer tooling + validation -> may inspect/call project contracts
production runtime             -X-> must not depend on tools/tests
```

Persistent deltas overlay runtime realization; they do **not** become inputs that redefine deterministic base world truth.

## Layer ownership matrix

| Layer | Owns | May depend on / consume | Must not own | Allowed identity/reference types | Authority |
| --- | --- | --- | --- | --- | --- |
| **Deterministic world definition / generation** | Reproducible world plans, topology, entrances, generated definitions, deterministic stage results, stable procedural addresses/IDs, generation fingerprints/provenance | Project/core pure primitives, immutable generation context, generator manifest/config, named seed domains, explicit upstream/neighbor stage views | SceneTree lifetime, live Nodes, player state, save mutations, active AI/audio, presentation assets, runtime load state | `WorldId`, `StableAddress`, `StableId`, generator manifest ID, seed-domain IDs/revisions, stage fingerprints/provenance | [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Stable Procedural IDs](../STABLE_PROCEDURAL_IDS.md), [Deterministic Seed Domains](../DETERMINISTIC_SEED_DOMAINS.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md) |
| **Geometry description + partitioning** | Pure deterministic geometry descriptions, bounded geometry-cell addresses/plans, cell-local fragments, clipping/continuation metadata, derived geometry fingerprints | Finalized deterministic world definitions and their exact compatible generation identity/provenance | New cave topology, new gameplay StableIds for fragments, runtime Nodes/MeshInstance3D lifetime, player deltas | Source procedural `StableId` references, geometry-cell address, derived fragment identity, compatible generation provenance/fingerprints | [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md), [Stable Procedural IDs](../STABLE_PROCEDURAL_IDS.md) |
| **Runtime streaming / realization** | Which representations are live, runtime-cell/chunk lifetime, render/collision realization, request priority/lifecycle, transient source-ID-to-instance mappings | Deterministic definitions, geometry descriptions, read-only/bounded persistent delta views, narrow gameplay interfaces, runtime configuration | Authoritative cave topology, durable save ownership, semantic content identity, generator decisions | Runtime-cell/chunk address or transient owner key; source `StableId` references; semantic content IDs as references; transient Node/resource handles only locally | [Streaming Ownership](../STREAMING_OWNERSHIP.md), [Repository Structure](REPOSITORY_STRUCTURE.md) |
| **Persistence / durable deltas** | Save envelope/schema, generator compatibility metadata, durable generated-world modifications, migration/quarantine of unresolved references | Stable generated identities, semantic content IDs where appropriate, explicit world/generator compatibility contracts | Live runtime-cell lifetime, complete visited-world snapshots as authority, guessed nearest-object identity, scene paths/Node instance IDs as persistent identity | `WorldId`, procedural `StableId`, semantic content ID, generator manifest ID, save-scoped player-created identity, spatial delta indexes where specified | [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Map Data Serialization Contract](../MAP_DATA_SERIALIZATION_CONTRACT.md), [Stable Procedural IDs](../STABLE_PROCEDURAL_IDS.md) |
| **Authored content definitions** | Semantic descriptions of items, creatures, attacks, structures, profiles, categories/capabilities and typed content references | Project/content schemas, other approved semantic definitions, validated asset roles/references | Scene-tree lifetime, live player/AI state, deterministic generated-instance identity, central runtime managers | **Semantic content IDs** such as `item.weapon.iron_sword`; category/capability schema IDs; typed asset roles | [Content Architecture](CONTENT_ARCHITECTURE.md), [Content Registry](CONTENT_REGISTRY.md), [Dependency Rules](DEPENDENCY_RULES.md) |
| **Gameplay / simulation** | Runtime rules and state transitions: player/actors, combat, interaction, inventory/equipment, harvesting, crafting, building, survival, creature behavior | Core primitives, authored definitions, runtime-world interfaces, bounded persistence operations/views where required | Procedural generator algorithms, presentation asset-path semantics, durable world-state storage implementation, content-definition special cases in central managers | Semantic content IDs, source procedural `StableId` references for generated objects, runtime actor/component identity internally | [Dependency Rules](DEPENDENCY_RULES.md), [Repository Structure](REPOSITORY_STRUCTURE.md), [Content Architecture](CONTENT_ARCHITECTURE.md) |
| **Presentation / audio / VFX** | Replaceable visuals, rigs, animation libraries/adapters, materials, textures, audio, VFX, UI presentation and concrete visual scenes | Semantic roles/content references and observable gameplay/world state through adapters | Gameplay rules, persistent identity, deterministic world truth, generator acceptance decisions | Asset/resource/scene paths as **replaceable implementation references**, semantic presentation roles/IDs; never file paths as authoritative game identity | [Repository Structure](REPOSITORY_STRUCTURE.md), [Dependency Rules](DEPENDENCY_RULES.md), [Content Architecture](CONTENT_ARCHITECTURE.md) |
| **Developer tooling / validation** | Inspectors, exporters, validators, test runners, fixtures, diagnostics, reproducibility tools, CI orchestration | Public/pure project APIs and test-only helpers/fixtures | Production runtime behavior, authoritative gameplay/world ownership, hidden alternate generation behavior | May display/compare all canonical identities and fingerprints; tooling-local IDs are never game identity | [Repository Structure](REPOSITORY_STRUCTURE.md), [Documentation Architecture](../00_project/DOCUMENTATION_ARCHITECTURE.md) |

## Identity ownership examples

### Procedural `StableId`

**Owned/defined by:** deterministic world identity architecture.

It answers **which generated world candidate/object/location is this?** It may be referenced by persistence, runtime, gameplay, tooling and diagnostics, but those consumers do not redefine it.

Do not replace it with:
- runtime Node instance ID;
- array/index position;
- geometry-cell address;
- semantic content ID;
- file path.

Authority: [Stable Procedural IDs](../STABLE_PROCEDURAL_IDS.md).

### Semantic content ID

**Owned/defined by:** authored content architecture.

It answers **what game concept/type/definition is this?** A generated object may therefore have both a semantic content ID and a procedural StableId.

Example:

```text
content_id      = item.resource.copper_ore
stable_world_id = <procedural generated-instance StableId>
```

Do not collapse those two identities.

Authority: [Content Architecture](CONTENT_ARCHITECTURE.md).

### Geometry-cell address

**Owned by:** deterministic geometry partitioning policy.

It identifies a bounded geometry-work/cache partition. It does not become the persistent identity of the cave network, tunnel, chamber or generated object inside it.

A source descriptor may contribute fragments to several geometry cells while retaining one source procedural StableId.

Authority: [Streaming Ownership](../STREAMING_OWNERSHIP.md) and the accepted geometry partition contract.

### Runtime-cell identity

**Owned by:** runtime streaming/lifetime management.

It identifies a currently demand-managed live spatial owner. Runtime and geometry grids may initially align, but architecture does not require them to remain identical.

A runtime-cell address is not a durable gameplay identity and must not replace source StableIds in save data.

Authority: [Streaming Ownership](../STREAMING_OWNERSHIP.md).

### Generator provenance

**Owned by:** deterministic generation pipeline/output contracts.

Provenance binds generated data to the world/generator/stage/region and the required upstream fingerprints. Downstream deterministic consumers validate compatible provenance; they do not mint substitute provenance from runtime state.

Persistence and caches may retain the generation contract identity needed to reject incompatible data, but the runtime loading order does not define provenance.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md) and [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md).

### Persistent delta

**Owned by:** the logical `WorldDeltaStore` / persistence layer.

A runtime cell may query or apply a delta to its live representation, but unloading that cell cannot delete durable state. Likewise, deterministic generation does not inspect player deltas when deciding what untouched world truth exists.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md) and [Streaming Ownership](../STREAMING_OWNERSHIP.md).

### Scene / prefab / resource path

**Owned by:** the system or presentation/content asset package that contains the file.

A path answers **where is this implementation/asset currently stored?** It does not answer which content concept or generated world object it is.

Use semantic content IDs and validated asset roles across durable/cross-system boundaries. Presentation adapters may resolve those roles to concrete `.tscn`, mesh, animation, audio or resource paths.

Authority: [Repository Structure](REPOSITORY_STRUCTURE.md), [Dependency Rules](DEPENDENCY_RULES.md), [Content Architecture](CONTENT_ARCHITECTURE.md).

## Ownership boundaries that are easy to cross accidentally

### Base world truth vs runtime realization

```text
deterministic definition -> runtime representation
```

Runtime decides **when/how expensively** something is represented. It does not decide **whether the deterministic cave/entrance/object exists**.

### Base world truth vs durable delta

```text
base truth + durable delta -> current realized world state
```

The delta records persistent change relative to the reproducible baseline. The delta does not rewrite the generator contract.

### Geometry partition vs persistent object ownership

```text
one source StableId
    -> fragment in geometry cell A
    -> fragment in geometry cell B
```

Cell-local fragments are derived work units. Crossing a cell boundary does not create another persistent gameplay object.

### Authored definition vs runtime instance

```text
semantic definition -> factory/system -> runtime instance
```

The definition survives scene/package reorganization. The runtime instance is temporary and may be destroyed/recreated.

### Filesystem ownership vs semantic identity

The repository path expresses which system or content family maintains a file. It is not a save ID, content ID, StableId or runtime identity.

Authority: [Repository Structure](REPOSITORY_STRUCTURE.md).

## `owner` and `contributor` are context-qualified terms

Do not treat the words `owner` or `contributor` as one global identity concept.

Examples:

- a macro region may canonically **own** a cross-region generated edge while another region stores an external reference;
- a source geometry descriptor retains its canonical generated identity while several geometry cells receive **contributing fragments**;
- a runtime cell **owns the lifetime** of its live Nodes/resources but does not own the source world truth or durable delta;
- a repository folder expresses **filesystem/system ownership**, not semantic identity.

When writing a task, diagnostic or contract, qualify the term: `edge owner region`, `geometry-cell contributor`, `runtime lifetime owner`, `persistence owner`, etc.

## Where should this new feature live?

Before claiming or creating implementation work, ask in this order:

1. **Does it decide reproducible world truth from deterministic inputs?**
   - Start in `worldgen/` and the deterministic generation contracts.
2. **Does it convert accepted world truth into pure geometry work/cache data?**
   - Use the geometry-description/partition boundary; do not invent gameplay identity there.
3. **Does it decide what is loaded, rendered, collided or simulated right now?**
   - Start in `world/` runtime/streaming ownership.
4. **Must the result survive unload/restart because the player/world changed?**
   - The durable state belongs to persistence/`WorldDeltaStore`, not the runtime cell.
5. **Is it a reusable authored game concept or parameter set?**
   - Put semantic definition data under the content architecture; runtime systems consume it.
6. **Is it a gameplay rule/state transition?**
   - Put it in the owning gameplay domain, depending on semantic definitions rather than concrete presentation paths.
7. **Is it replaceable art/audio/animation/UI or an adapter to those assets?**
   - Put it under presentation ownership.
8. **Is it only for inspection, migration, validation or development?**
   - Put it under `tools/`, `tests/` or validation/docs. Production code must not depend upward on it.
9. **Does the proposed change need a different layer to own something it currently only references?**
   - Stop and review the authoritative contracts before coding; that is an architecture change, not ordinary implementation.

## Authoritative reference set

Use this map as a routing index, then read the relevant source contract:

- [Documentation Architecture](../00_project/DOCUMENTATION_ARCHITECTURE.md)
- [Repository Structure](REPOSITORY_STRUCTURE.md)
- [Dependency Rules](DEPENDENCY_RULES.md)
- [Content Architecture](CONTENT_ARCHITECTURE.md)
- [Content Registry](CONTENT_REGISTRY.md)
- [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md)
- [Stable Procedural IDs](../STABLE_PROCEDURAL_IDS.md)
- [Deterministic Seed Domains](../DETERMINISTIC_SEED_DOMAINS.md)
- [Streaming Ownership](../STREAMING_OWNERSHIP.md)
- [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md)
- [Map Data Serialization Contract](../MAP_DATA_SERIALIZATION_CONTRACT.md)

This index should change when ownership contracts change; it must not become a competing source of architecture.