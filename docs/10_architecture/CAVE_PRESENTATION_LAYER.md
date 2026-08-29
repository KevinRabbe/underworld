# Underworld — Cave Presentation Layer

Status: **M3 presentation contract; visual tuning remains replaceable**

This layer applies authored cave materials, local lighting, ambience metadata and visual-dressing hooks to accepted cave render cells. It follows the locked [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md): presentation represents deterministic cave state but never becomes cave identity, topology, collision or persistence truth.

## 1. Ownership

```text
accepted worldgen cell plan
        ↓ compact value snapshot
runtime render semantic handoff + accepted cave mesh
        ↓
CavePresentationCatalog + profiles
        ↓
CavePresentationController / Realizer
        ↓
material + local light + ambience/fog metadata + dressing hooks
```

Worldgen owns whether chambers, tunnels, entrances and reserved sites exist. MAP-016 owns deterministic mesh extraction and mesh/collision fingerprints. Presentation owns only how those accepted render cells look and which disposable visual hooks accompany them.

The cave presentation layer must not:
- alter Marching-Cubes samples, triangles, normals, UV identity or partition ownership;
- alter traversal gates or collision;
- create or rename procedural StableIds;
- store durable player/world deltas;
- make a material, profile, Node or renderer handle part of save identity;
- choose gameplay resources or encounter behavior.

## 2. Presentation identity

Authored visual profiles use semantic IDs under:

```text
presentation.cave.*
```

These are **presentation IDs**, not procedural StableIds or durable object IDs. Replacing `presentation.cave.chamber` with another color/material treatment changes appearance only.

Profile selection context deliberately excludes source StableIds, source descriptor IDs, fragment IDs and source/provenance fingerprints. It uses only presentation-safe semantic values copied from accepted runtime descriptors:
- source volume kinds (`chamber`, `tunnel`, `entrance`, `reserved_site`);
- entrance/reserved-site presence flags;
- optional biome semantic token supplied by the presentation composition layer;
- depth derived from copied cell bounds;
- semantic tags;
- world bounds for positioning disposable presentation helpers.

Changing the identity of the same semantic chamber must therefore not choose a different visual profile by accident.

## 3. Compact runtime semantic handoff

A realized render node must **not retain `GeometryCellPlan` or fragment objects**. Those objects own generation-plan graphs, fingerprints and metadata that presentation does not need and keeping them alive would work against streaming reclamation.

Before render realization, `UnderworldCaveRuntimeController.build_cell_semantic_snapshot()` copies only the allowed value facts into a compact read-only `Dictionary`:

```text
source_kinds: Array[String]
has_entrance: bool
has_reserved_site: bool
tags: Array[String]
world_bounds: AABB
```

The arrays and outer dictionary are made read-only before handoff. The snapshot contains no `Object`, `RefCounted`, `Node`, `Resource`, RID, Callable, StableId, source fingerprint, provenance fingerprint or fragment reference. The render node stores this value snapshot as `cell_semantic_snapshot`.

Presentation may retain or copy that compact value snapshot for its disposable lifetime. Dropping the original `GeometryCellPlan` must not prevent presentation from being rebuilt.

## 4. Authored profile resolution

`CavePresentationCatalog` resolves profiles by:
1. highest authored priority;
2. highest semantic specificity (volume kind / biome / depth restriction);
3. profile ID as deterministic visual tie-breaker.

The M3 prototype catalog provides:
- default cave treatment;
- chamber treatment;
- tunnel treatment;
- high-priority entrance treatment;
- reserved-site treatment;
- deeper-cave variation;
- one example biome-driven (`basalt`) variation.

This is intentionally data-driven. Additional profiles extend the catalog without adding central `match cave_type` gameplay logic.

## 5. Exterior and backside readability

MAP-016 intentionally realizes the navigable cave shell with interior-facing geometry. Exterior disappearance is therefore treated as a presentation problem unless a real topology/collision defect is reproduced.

The M3 cave material uses a double-sided `StandardMaterial3D` (`CULL_DISABLED`). This makes the accepted shell readable from approach/backside viewpoints without duplicating triangles, reversing deterministic winding or changing collision geometry.

Entrance profiles use a warmer/brighter material and small transient local light so the surface-to-underworld transition reads more clearly. These values are presentation tuning and may change freely.

## 6. Lighting, ambience and dressing hooks

A profile may author:
- local light color/energy/range;
- ambience semantic ID;
- fog presentation metadata;
- semantic dressing hook IDs.

The current realizer creates only disposable representation:
- optional `OmniLight3D`;
- ambience/fog metadata for later audio/environment adapters;
- `Marker3D` dressing hooks for later prop/VFX realization.

Those hooks do not assert that a durable prop, resource or gameplay object exists. Future systems must resolve them through their own presentation/content boundaries rather than treating the marker as world truth.

## 7. Streaming and rebuild

Presentation follows render-cell lifetime. When a cave render node is recreated after streaming, the controller reads its compact `cell_semantic_snapshot`, resolves an authored profile, and rebuilds material/light/ambience/dressing representation. The authoritative generation plan does not need to remain referenced by the render node.

No cave-presentation instance state needs to be saved. Removing an old `CavePresentationAttachment` and creating a new one must leave:
- cave mesh output fingerprint unchanged;
- source/provenance fingerprints unchanged;
- StableIds unchanged;
- collision/traversal unchanged;
- durable world/player state unchanged.

## 8. Runtime integration seam

`UnderworldCaveRuntimeController` remains worldgen/runtime authority. It already exposes an optional material seam and a `cell_attached` render event.

PRESENTATION-001 adds one neutral value handoff: worldgen copies presentation-safe semantic facts from the accepted cell plan into `cell_semantic_snapshot` before attaching the disposable render `MeshInstance3D`. Worldgen does not import presentation code, presentation never receives the original cell plan through this seam, and the snapshot is excluded from every deterministic fingerprint.

## 9. Validation

Focused cave-presentation contracts prove:
- authored catalog/profile validity;
- chamber/tunnel/entrance/reserved/depth/biome resolution;
- source StableId/descriptor identity does not select visual profiles;
- the runtime semantic snapshot is read-only and contains no Object/RefCounted/Node/RID/Callable authority;
- the actual render node carries the compact snapshot and no `source_cell_plan` reference;
- dropping the original `GeometryCellPlan` does not prevent presentation rebuild;
- the M3 material is double-sided;
- changing/rebuilding presentation does not change `CaveMeshData.output_fingerprint` or replace the accepted mesh;
- presentation attachments are transient and can be reconstructed after render-node disposal.

Broad repository, Character and deterministic worldgen gates remain required because presentation integration must not regress accepted runtime behavior.

## 10. Intentionally open

PRESENTATION-001 does not lock:
- final cave palette or textures;
- final shader technology;
- final fog/audio implementation;
- final prop/VFX dressing assets;
- final biome roster;
- final lighting budget or shadow policy;
- LOD/batching optimizations.

Those can evolve while preserving the identity/ownership boundary above.
