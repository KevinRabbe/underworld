# Performance and Scalability Architecture

Status: **LOCKED architecture direction; numeric budgets remain profile-driven**

Underworld should be designed so that ordinary play is cheap and extreme player behavior degrades gracefully rather than exposing architecture that only works at expected content scale.

The project has already shown that runtime cave extraction/loading can dominate user-visible latency. Player building creates a second long-term scale risk because successful builders may place thousands or tens of thousands of pieces in one region.

This document defines the architectural response.

## 1. Primary rule: represent less work, not merely faster work

Optimization should prefer eliminating unnecessary runtime work before micro-optimizing code that should not have been running.

Examples:
- do not instantiate one runtime object per deterministic world fact when a data representation is enough;
- do not execute structural simulation every frame when nothing changed;
- do not render full-detail distant content the player cannot perceive;
- do not keep collision/AI/audio active outside relevant interest ranges;
- do not regenerate immutable deterministic truth when a canonical cache/result already exists;
- do not synchronize static data repeatedly over the network.

The question is normally:

> What work can be skipped, deferred, cached, batched or represented more cheaply?

before:

> How do we make the same amount of work 10% faster?

## 2. Canonical state and runtime representation are separate

A logical object may have multiple runtime representations.

```text
canonical logical state
        |
        +--> persistence representation
        +--> network representation
        +--> near runtime representation
        +--> far/LOD representation
        +--> collision representation
        +--> batched render representation
```

The renderer, physics server, SceneTree and network transport do not define persistent identity.

This is mandatory for:
- procedural world cells;
- vegetation;
- resources;
- player buildings;
- structures;
- static props;
- distant world presentation.

## 3. Static state should approach zero CPU cost

If a piece of world state is unchanged and does not require active behavior, it should ideally perform no per-frame gameplay work.

For a settled building or static generated prop:

```text
nothing changed
-> no support solve
-> no placement solve
-> no persistence work
-> no network resend
-> no gameplay process callback
```

Rendering/visibility costs may remain, but logical simulation should be event-driven where practical.

## 4. Worker/main-thread boundary

Expensive pure-data work should be eligible for worker execution.

Worker-safe examples:
- deterministic generation;
- noise/field evaluation;
- placement candidate generation;
- topology calculations;
- mesh vertex/index preparation where Godot API restrictions permit;
- support-graph recalculation over pure data;
- LOD/proxy preparation;
- serialization preparation.

Main-thread responsibilities include operations that require SceneTree/engine-object ownership.

A completed worker job must not be allowed to create a new main-thread hitch by publishing an unbounded amount of work at once.

## 5. Commit/publication budgets

Runtime systems should expose bounded publication/commit budgets.

Conceptually:

```text
GenerationBudget
- max active generation jobs
- max completed results committed per frame
- max mesh realization work per frame
- max collision realization work per frame
- max spawn realization work per frame
- memory/cache budget
```

Exact units and values remain profile-driven.

The architecture requirement is that expensive work can be throttled instead of implicitly blocking one frame.

## 6. Priority scheduling

Streaming/generation priority should reflect player need.

Typical priority order:
1. safety-critical cell/region containing the player;
2. collision/traversal required immediately;
3. visible near content;
4. predicted movement direction;
5. remaining near content;
6. medium LOD;
7. far/horizon representation.

Priority must not change deterministic world truth. It only changes when representation work happens.

## 7. Spatial partitioning

Large dynamic/static collections must be spatially partitionable.

Examples:
- world generation cells;
- cave runtime cells;
- Overworld terrain sectors;
- vegetation sectors;
- building sectors/clusters;
- replication interest regions.

Changing one local region should not force rebuild/recalculation of an entire world, cave network or settlement.

## 8. Rendering repeated modular content

Repeated geometry should be designed for batching/instancing.

Strong candidates include:
- building walls/floors/beams;
- repeated rocks;
- vegetation archetypes;
- resource props;
- common structural modules;
- decorative clutter.

Possible runtime techniques include:
- MultiMesh/GPU instancing;
- spatial render batches;
- mesh clustering;
- LOD meshes;
- impostors/billboards;
- far structure proxies;
- occlusion/frustum culling.

The chosen technique is replaceable. Logical identity must remain individually addressable where gameplay requires it.

## 9. Collision is an independent representation

Visual identity and physics identity are different concerns.

A logical collection of thousands of static pieces does not automatically require thousands of independently active physics bodies forever.

Possible optimization directions include:
- static collision aggregation by spatial sector;
- collision activation tiers;
- simplified distant collision or no collision outside interaction range;
- local rebuild of affected collision sectors after edits.

Any aggregation must preserve correct gameplay interaction/deconstruction/damage behavior through logical mapping.

## 10. Structural simulation is event-driven

Building structural support must be represented as an explicit graph/cache.

Do not run a full support search every frame.

```text
place/remove/damage structural piece
-> mark affected graph region dirty
-> recompute bounded affected state
-> propagate only changed support values
-> cache result
```

A 20,000-piece settlement that nobody is modifying should not continuously pay a 20,000-piece support-solving cost.

## 11. Player megabuilds are a first-class stress case

Performance validation must not assume that a normal house is the maximum relevant construction.

The project should intentionally test abusive but valid structures such as:
- thousands of walls/floors/beams in one settlement;
- tall support towers;
- long iron-supported spans;
- dense overlapping decorative construction;
- multi-building towns;
- large elevated platforms/cities;
- many lights, doors, containers and crafting stations in one area.

Exact acceptable counts depend on target hardware and profiling, but architecture should aim for graceful scaling rather than a cliff immediately above ordinary build sizes.

## 12. Expensive special objects use separate budgets

Geometry count is not the only scale risk.

Large settlements may contain many:
- dynamic/shadowed lights;
- particles;
- audio emitters;
- animated doors;
- crafting stations;
- storage containers;
- interactables;
- AI/nav modifiers.

Those systems require their own activity/visibility budgets.

Example perceptual optimization:

```text
100 visible torches
-> 100 emissive/flame presentations
-> only a bounded nearby subset own expensive dynamic shadowed lights
```

## 13. Network interest management

Static world/building data should be synchronized as state changes, not streamed repeatedly every frame.

Replication should be bounded by:
- active world domain;
- spatial relevance;
- interaction relevance;
- ownership/permission relevance where applicable.

A player far from a large town should not receive continuous per-piece updates merely because the town exists.

## 14. LOD changes representation, never truth

A forest may be represented as individual trees nearby and a canopy proxy far away. A settlement may be represented as individual pieces nearby and a simplified cluster far away.

The canonical world/building data remains unchanged.

```text
same logical state
├─ near: full representation
├─ medium: batched/simplified representation
└─ far: proxy/impostor/horizon representation
```

Gameplay/persistence must not infer that missing LOD detail means missing logical objects.

## 15. Perceptual complexity is an optimization tool

The project should spend detail where the player perceives it.

A simple base mesh may appear substantially richer through:
- silhouette quality;
- normals;
- materials/roughness;
- AO;
- translucency;
- wind/deformation;
- decals;
- fog/atmosphere;
- shadows;
- controlled VFX;
- color variation.

This is not permission for poor silhouettes. Geometry should carry the large forms that materially affect readability; shaders/presentation carry detail that does not need dedicated geometry.

## 16. Vegetation scaling

Tree/vegetation production should favor a small reusable archetype library with strong presentation.

A tree system may use:
- simple trunk/branch geometry;
- coarse foliage volume/cluster meshes;
- shader-driven leaf breakup/transmission;
- wind;
- per-instance tint/scale/rotation;
- multiple LOD tiers;
- far forest proxies.

The objective is not to model every leaf. The objective is to create the perceptual signals of a convincing forest at sustainable runtime and production cost.

## 17. Profiling discipline

Performance work requires measurement.

For every major scalable subsystem, establish:
- representative ordinary case;
- heavy case;
- deliberately abusive stress case;
- CPU frame-time breakdown;
- main-thread stalls;
- worker latency;
- render/draw statistics;
- physics cost;
- memory/cache cost;
- transition/loading latency where applicable.

Do not permanently lock numeric budgets before measuring representative production content.

## 18. Performance gates should grow with the project

As systems become production-relevant, add reproducible performance scenarios rather than relying only on subjective observation.

Planned benchmark families should eventually include:
- Overworld streaming;
- Underworld streaming/extraction;
- domain transition cold/warm paths;
- dense vegetation;
- large settlement rendering;
- structural mutation in megabuilds;
- large-save load/reconstruction;
- multiplayer replication around dense settlements.

## Locked invariants

1. Canonical logical state is independent of runtime representation.
2. Static unchanged gameplay state should approach zero CPU work.
3. Expensive pure-data work must be schedulable off the main thread where safe.
4. Result publication must be budgetable; worker completion cannot justify an unbounded main-thread spike.
5. World/building systems must be spatially partitionable.
6. Rendering, collision, simulation, persistence and networking may use different representations of the same logical state.
7. LOD/batching never erase logical identity.
8. Structural support is event-driven/cached rather than continuously recomputed.
9. Megabuilds are intentional stress cases.
10. Performance decisions use measured evidence, not assumed counts.
