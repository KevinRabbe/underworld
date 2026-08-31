# Underworld Project Glossary

Status: **Canonical terminology index**

This document summarizes project terms and points to the owning contracts. It does not create competing architecture.

If this glossary conflicts with an authoritative linked contract, the authoritative contract wins and this glossary must be corrected.

Current world-domain authority:
- [`ADR-001_TWO_WORLD_DOMAINS.md`](ADR-001_TWO_WORLD_DOMAINS.md)
- [`../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md)

## Identity at a glance

| Question | Canonical identity |
| --- | --- |
| Which seeded root world/save scope? | `WorldId` |
| Which procedural runtime space? | `WorldDomain` (`OVERWORLD` / `UNDERWORLD`) |
| Which exact deterministic contract? | `GeneratorManifest` / manifest identity |
| Which generated candidate/site/object? | `StableAddress` / `StableId` |
| Which authored kind of content? | semantic content ID |
| Which cross-domain connection? | `WorldGatewayDefinition` / gateway StableId |
| Which Underworld destination/source site? | `UnderworldEntrySiteDefinition` / site StableId |
| Which bounded geometry partition? | geometry-cell address |
| Which live lifetime partition? | runtime-cell/chunk address |
| Which player-created building piece instance? | build-instance identity |

These identities are deliberately separate.

---

## WorldId

Stable identity of one root seeded world/save scope.

A `WorldId` may contain both Overworld and Underworld domains. It does **not** imply shared domain coordinates.

**Not:** save-slot ID, world domain, procedural object ID, generator-manifest ID.

Authority: [`../PERSISTENCE_AND_VERSIONING.md`](../PERSISTENCE_AND_VERSIONING.md).

## WorldDomain

Explicit procedural/runtime space qualifier.

Current domains:

```text
OVERWORLD
UNDERWORLD
```

Positions, spatial addresses and Player transforms are interpreted inside their owning domain.

**Not:** biome, cave depth class, SceneTree path or loading state.

Authority: [`ADR-001`](ADR-001_TWO_WORLD_DOMAINS.md), [`WORLD_DOMAINS_AND_TRANSITIONS`](../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md).

## Domain-local transform

A spatial transform meaningful only together with its `WorldDomain`.

Modern durable Player position is conceptually:

```text
active_domain + domain_local_transform
```

An Overworld XYZ value does not automatically correspond to the same Underworld XYZ value.

**Not:** global cross-domain coordinate or gateway identity.

Authority: [`../PERSISTENCE_AND_VERSIONING.md`](../PERSISTENCE_AND_VERSIONING.md).

## World gateway

A deterministic semantic connection between a source site in one domain and a destination site in another domain (or potentially within a domain where later design permits).

Conceptually:

```text
WorldGatewayDefinition
- stable gateway identity
- source domain/site
- destination domain/site
- directionality/pair semantics
- transition policy
```

A gateway is resolved by semantic identity, not coordinate conversion.

**Not:** a mesh, loading-screen animation, collision hole, runtime portal Node or nearest-coordinate relationship.

Authority: [`../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md).

## Overworld gateway/source site

A deterministic/authored Overworld-local place capable of owning or referencing a gateway.

Presentation might be a modeled cave mouth, mine entrance, crypt, fissure or portal.

It does not require the actual Underworld mesh behind it.

**Not:** Underworld destination coordinate or physical cross-domain tunnel.

Authority: [`../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md).

## Underworld entry/exit site

A deterministic Underworld-local topology/site object suitable as a gateway destination/source.

Conceptually owns:
- StableId/address;
- owning region/network/node relationship;
- domain-local arrival anchor;
- safe-arrival/clearance metadata;
- semantic site/depth/family tags.

**Not:** Overworld terrain cutout, source cave-mouth mesh or shared-space coordinate.

Authority: [`../20_world/UNDERWORLD_GENERATION_PIPELINE.md`](../20_world/UNDERWORLD_GENERATION_PIPELINE.md).

## Historical entrance / physical integration descriptor

Older accepted generation/runtime contracts may contain `EntranceDefinition` and `SurfaceEntranceIntegrationDescriptor` concepts from the pre-ADR one-continuous-world architecture.

Those records remain historical/legacy compatibility data where needed. Their physical surface-cutout fields are **not current cross-domain authority**.

Useful semantic entrance identity may be migrated/adapted to gateway/source/destination site contracts through explicit versioned composition.

**Not:** permission to reintroduce mandatory physical surface/cave continuity.

Authority: [`ADR-001`](ADR-001_TWO_WORLD_DOMAINS.md), legacy Git history, current generation migration guidance.

---

## Authored definition

Stable semantic description of one authored game concept, identified by a semantic content ID and resolved to current rules/assets.

**Not:** generated-world instance, runtime Node, file path or procedural StableId.

Authority: content architecture/registry.

## Semantic content ID

Answers **what authored kind of thing is this?**

Examples:

```text
item.weapon.iron_sword
creature.underworld.burrower
```

A generated object can carry both semantic content ID and procedural StableId.

**Not:** identity of a specific generated location/instance.

## StableAddress

Canonical deterministic semantic address for a procedural candidate/location/lineage.

Candidate slots exist before acceptance so rejection/array compaction cannot rename later identities.

It is also the anchor for named-domain seed derivation.

**Not:** content ID, runtime Node path, array index, float position or proof of generator provenance.

Authority: `STABLE_PROCEDURAL_IDS.md`, `DETERMINISTIC_SEED_DOMAINS.md`.

## StableId

Persistent procedural ID derived from canonical StableAddress semantics.

Answers **which deterministic generated candidate/site/object is this?**

**Not:** content ID, build-instance ID, runtime Node ID, geometry fragment or asset path.

## Generator manifest

Canonical identity/description of the deterministic generation contracts required to reproduce world truth.

May include separately identifiable Overworld, Underworld and gateway-link stage/domain/config revisions.

**Not:** universal RNG salt.

Authority: `PERSISTENCE_AND_VERSIONING.md`.

## Seed domain

Named, revisioned semantic source of deterministic randomness.

A domain ID/name never changes semantic meaning after persistent use. Legacy physical-entrance domains remain reserved rather than being repurposed for new gateway linking.

**Not:** shared mutable world RNG, ad-hoc salt, stage revision or manifest ID.

Authority: `DETERMINISTIC_SEED_DOMAINS.md`.

## Generation provenance

Canonical ancestry metadata proving deterministic stage data belongs to the expected root world/domain/generator/stage/source fingerprint set.

StableId alone is not provenance.

**Not:** runtime load order or Node ancestry.

## Base world truth

Untouched deterministic procedural baseline regenerated from root world identity + pinned compatible domain contracts.

Examples:
- Overworld terrain/placements;
- Underworld topology/base geometry;
- deterministic source/destination sites;
- special-location hooks.

**Not:** visited runtime scene snapshot or player-caused delta.

---

## Macro region

Deterministic Underworld generation/ownership partition used for regional planning, topology dependencies, candidate slots, sites/connectivity/hooks.

**Not:** runtime cell, geometry cell, cave network or mandatory gameplay floor.

## Cave network

Persistent topology component inside the Underworld graph.

May cross many geometry/runtime cells.

**Not:** runtime cell, level/floor, loaded scene or world domain.

## Geometry cell

Bounded deterministic Underworld geometry work/cache partition.

One semantic source descriptor may contribute fragments to several cells.

**Not:** cave network identity, gameplay StableId or runtime lifetime owner.

## Geometry fragment

Cell-local pure-data contribution created when one source topology/geometry descriptor intersects a geometry cell.

Fragment identity is processing/partition identity and does not create a new persistent gameplay object for every cell crossing.

## Runtime cell

3D lifetime/LOD partition for live Underworld representation.

May own current Nodes/mesh/collision/proxies while referencing canonical source identity.

It unloads safely because deterministic truth and durable deltas live elsewhere.

**Not:** persistent topology or SAVE owner.

## Streaming tier

Level of current representation cost/readiness, such as:

```text
definition -> geometry -> render -> collision -> simulation -> local presentation
```

Dropping a tier cannot delete deterministic truth or durable state.

**Not:** generation stage, cave depth profile or progression tier.

---

## WorldDomainCoordinator / WorldTransitionService

Runtime owner of active-domain transition lifecycle.

Responsibilities conceptually include:
- validate gateway transition request;
- resolve destination identity;
- request destination runtime readiness;
- commit active-domain change atomically/fail-closed;
- release Player control only after required destination safety;
- coordinate source runtime release.

**Not:** topology generator, SAVE codec, UI loading overlay or domain streamer.

Authority: `STREAMING_OWNERSHIP.md` and `WORLD_DOMAINS_AND_TRANSITIONS.md`.

## Runtime realization / runtime instance

Disposable live engine representation produced from deterministic/authored truth + applicable deltas.

Examples: meshes, collisions, interactable proxies, creature Nodes, lights/audio/VFX.

**Not:** persistent semantic identity.

## Player/world delta / durable delta

Persistent change supplementing deterministic base truth.

Examples:
- harvested/generated objects;
- mined resource state;
- special-location changes;
- terrain modifications;
- player-created structures.

Runtime unload does not erase it.

Authority: `PERSISTENCE_AND_VERSIONING.md` / WorldDeltaStore.

---

## BuildPieceDefinition

Authored semantic definition of a reusable player-buildable piece.

Owns logical placement/snap/support/resource/presentation references according to building architecture.

**Not:** one placed wall/beam, runtime Node or mesh identity.

Authority: `../30_gameplay/BUILDING_SYSTEM.md`.

## BuildInstance

One persistent player-created placement of a BuildPieceDefinition.

Conceptually carries:
- build-instance ID;
- piece-definition ID;
- owning domain;
- domain-local transform;
- mutable durable state where required.

Its render/collision representation may be batched/instanced without erasing logical identity.

**Not:** procedural StableId or render-batch index.

## Snap socket

Authored logical placement relationship/anchor on a building piece.

Snapping is assistance. Validity does not require every placement to use a socket; free placement/overlap/terrain embedding may be intentionally legal.

**Not:** arbitrary mesh vertex or hard global grid identity.

## Structural support graph

Gameplay graph representing supported relationships between placed building pieces/valid anchors.

Support is cached/event-driven and material-sensitive; it is not full finite-element simulation.

**Not:** mesh overlap test or per-frame global recomputation.

---

## Presentation ID / asset path

Presentation roles/paths identify replaceable current art/audio/UI implementation.

They never become authoritative generated/gameplay/persistence identity.

## `active_domain`

Authoritative coarse semantic indicating the committed current world domain.

UI/audio may consume it read-only.

**Not:** inferred from Player Y, cave-cell AABB, render visibility or camera state.

---

## Commonly confused boundaries

### WorldId vs WorldDomain

```text
WorldId      -> which root seeded world/save scope?
WorldDomain  -> which independent procedural/runtime space inside it?
```

### Gateway vs entry site

```text
entry/source site -> one deterministic place inside one domain
gateway           -> semantic connection between source and destination sites
```

### StableId vs content ID

```text
StableId   -> which generated candidate/instance/site?
content ID -> what authored kind of thing?
```

### Geometry cell vs runtime cell

```text
geometry cell -> deterministic work/cache partition
runtime cell  -> current live lifetime/LOD partition
```

### Base truth vs durable delta

```text
base truth -> regenerate from pinned contracts
delta      -> save persistent change against baseline
```

### BuildInstance vs render batch

```text
BuildInstance -> logical persistent player-created piece
render batch  -> disposable optimized presentation of many pieces
```

---

## Adding terminology

Add a term only after its meaning exists in an owning architecture/rulebook/interface/executable contract.

For each term:
1. state narrow meaning;
2. state likely **not this** confusion;
3. link authority;
4. if sources conflict, fix the owning contract first.

The glossary indexes architecture; it does not invent it.