# Underworld — Cave Presentation Layer

Status: **M3 presentation contract; visual tuning remains replaceable**

This layer applies authored cave materials, local lighting, ambience metadata and visual-dressing hooks to accepted cave render cells. It follows the locked [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md): presentation represents deterministic cave state but never becomes cave identity, topology, collision or persistence truth.

## 1. Ownership

```text
accepted worldgen cell plan / cave mesh data
                 ↓ read-only semantic context
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

Profile selection context deliberately excludes source StableIds, source descriptor IDs and fragment IDs. It uses only presentation-safe semantic facts already supplied by accepted runtime descriptors:
- volume kind (`chamber`, `tunnel`, `entrance`, `reserved_site`, `default`);
- optional biome semantic token;
- depth derived from accepted cell bounds;
- semantic tags;
- world bounds for positioning disposable presentation helpers.

Changing the identity of the same semantic chamber must therefore not choose a different visual profile by accident.

## 3. Authored profile resolution

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

## 4. Exterior and backside readability

MAP-016 intentionally realizes the navigable cave shell with interior-facing geometry. Exterior disappearance is therefore treated as a presentation problem unless a real topology/collision defect is reproduced.

The M3 cave material uses a double-sided `StandardMaterial3D` (`CULL_DISABLED`). This makes the accepted shell readable from approach/backside viewpoints without duplicating triangles, reversing deterministic winding or changing collision geometry.

Entrance profiles use a warmer/brighter material and small transient local light so the surface-to-underworld transition reads more clearly. These values are presentation tuning and may change freely.

## 5. Lighting, ambience and dressing hooks

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

## 6. Streaming and rebuild

Presentation follows render-cell lifetime. When a cave render node is recreated after streaming, the controller reads the accepted source cell plan again, resolves an authored profile, and rebuilds material/light/ambience/dressing representation.

No cave-presentation instance state needs to be saved. Removing an old `CavePresentationAttachment` and creating a new one must leave:
- cave mesh output fingerprint unchanged;
- source/provenance fingerprints unchanged;
- StableIds unchanged;
- collision/traversal unchanged;
- durable world/player state unchanged.

## 7. Runtime integration seam

`UnderworldCaveRuntimeController` remains worldgen/runtime authority. It already exposes an optional material seam and a `cell_attached` render event.

PRESENTATION-001 adds only one neutral handoff: the disposable render `MeshInstance3D` may carry the already-existing `GeometryCellPlan` object as transient metadata (`source_cell_plan`). Worldgen does not import presentation code and does not include that reference in any fingerprint. Presentation reads it after render attachment and never writes back into it.

## 8. Validation

Focused cave-presentation contracts prove:
- authored catalog/profile validity;
- chamber/tunnel/entrance/reserved/depth/biome resolution;
- source StableId/descriptor identity does not select visual profiles;
- the M3 material is double-sided;
- changing/rebuilding presentation does not change `CaveMeshData.output_fingerprint` or replace the accepted mesh;
- presentation attachments are transient and can be reconstructed after render-node disposal.

Broad repository, Character and deterministic worldgen gates remain required because presentation integration must not regress accepted runtime behavior.

## 9. Intentionally open

PRESENTATION-001 does not lock:
- final cave palette or textures;
- final shader technology;
- final fog/audio implementation;
- final prop/VFX dressing assets;
- final biome roster;
- final lighting budget or shadow policy;
- LOD/batching optimizations.

Those can evolve while preserving the identity/ownership boundary above.
