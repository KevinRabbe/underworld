# Underworld — Replaceable Presentation Boundary

Status: **LOCKED architectural direction for ownership boundaries; renderer and art technology remain open.**

This document defines the boundary between authoritative game/world data and replaceable render, audio, VFX and animation presentation. It does not choose final art assets, shaders, renderer technology, LOD policy or cave-mesh implementation.

The governing rule is simple:

> Presentation may represent authoritative state, but it must not become authoritative identity or game/world truth.

Authoritative source contracts remain in [Technical Architecture](../TECHNICAL_ARCHITECTURE.md), [Content Architecture](CONTENT_ARCHITECTURE.md), [Dependency Rules](DEPENDENCY_RULES.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md) and the [Prototype Character Contract](../PROTOTYPE_CHARACTER.md). Those documents win if this summary conflicts with a more specific owning contract.

## 1. Three ownership layers

Keep these layers distinct:

```text
Authoritative definition / persistent state
                ↓
Runtime realization / adapter
                ↓
Presentation representation
```

### Authoritative definition / persistent state

This layer answers questions such as:

- what deterministic world feature exists;
- which procedural StableId identifies a generated instance;
- which semantic content ID identifies an authored definition;
- which durable delta records a player-caused change;
- which gameplay action/state is currently authoritative.

Examples include deterministic topology/geometry descriptions, authored item or creature definitions, player-created persistent object state, inventory state, combat state and world deltas.

This layer must remain usable without loading final meshes, materials, sounds, particles or animation clips.

### Runtime realization / adapter

This layer translates authoritative data into live engine resources and scene state.

Typical responsibilities include:

- resolving semantic asset roles;
- building or selecting render meshes;
- creating live render instances;
- binding a compatible character rig;
- attaching audio/VFX emitters;
- selecting LOD or batching strategy;
- rebuilding presentation after streaming or asset changes.

Runtime realization may cache presentation data, but cache identity is not game identity.

### Presentation representation

This layer includes replaceable visual and audible output such as:

- meshes and mesh variants;
- materials and textures;
- shaders;
- particles and VFX;
- lights and fog presentation;
- audio clips and presentation mixes;
- animation clips, libraries and rig bindings;
- UI-facing icons or presentation metadata.

These resources may change without redefining the logical object they depict.

## 2. Identity rules

Presentation resources never become authoritative identity.

Do not use any of the following as a procedural StableId, semantic content ID or durable instance identity:

```text
PackedScene path
mesh path
material path
texture path
shader path
animation clip filename
Skeleton3D bone path
Node instance ID
MultiMesh instance index
renderer-local batch index
```

The correct dependency direction is:

```text
stable logical identity
        ↓
definition / state
        ↓
asset role or presentation binding
        ↓
current file/resource path
```

Moving or replacing a file therefore must not silently rename the logical object.

## 3. Presentation replacement must not invalidate world truth

A presentation-only change must not require a new world seed or alter deterministic procedural identity.

Examples of presentation-only changes include:

- replacing one rock material with another;
- changing a terrain shader;
- replacing a weapon mesh while retaining the same semantic item definition;
- replacing the prototype mannequin with a compatible production character presentation;
- changing cave tessellation/LOD or material realization while consuming the same accepted source geometry contract;
- changing particles, lighting, ambience or audio assets.

If a proposed visual change alters authoritative topology, collision/traversal semantics, generated placement, gameplay dimensions or persistent definition/state, then it is not merely a presentation change and must go through the owning gameplay/world contract.

## 4. Shader/style replacement versus geometry/renderer replacement

These are different classes of presentation work.

### Shader/material-only style change

A shader/material change keeps the same underlying render geometry and changes how it is shaded or surfaced.

Examples:

- flat/stylized lighting versus richer PBR;
- palette or surface response changes;
- triplanar versus conventional texture presentation;
- stylized fog or rim-light treatment.

These changes should normally remain presentation-only.

### Geometry/renderer representation change

A different renderer may derive a different render representation from the same logical source data.

Examples may include:

- smooth versus faceted cave rendering;
- low-poly versus denser tessellation;
- conventional mesh versus a voxel-like visual renderer;
- static mesh instances versus a batched or combined representation.

Such alternatives are allowed only when the owning geometry/runtime contract supplies enough canonical source information and gameplay-relevant geometry semantics remain correct. A renderer may not silently invent different cave connectivity, entrance existence, persistent object positions or other world truth.

The project does not lock a final renderer technology here.

## 5. World and cave example

For deterministic terrain/caves, the ownership chain is conceptually:

```text
deterministic world/topology/geometry source
                 ↓
runtime geometry realization
                 ↓
render mesh + materials + LOD + ambience
```

The presentation layer may:

- choose material families from allowed authored/profile data;
- select visual LOD;
- batch render instances;
- add lighting, fog, particles and ambience;
- rebuild render resources after streaming.

It must not:

- decide whether a cave, entrance or generated object exists;
- create a new persistent identity because a mesh was split or combined;
- mutate deterministic topology to remove a visual seam;
- make a material/scene path part of a StableId;
- make cache or renderer lifetime own durable world deltas.

Runtime render resources remain disposable representations of reproducible source data plus current durable state.

## 6. Building example

Player-built structures are durable player-created state, not procedural world truth. Persistence already requires player-created objects to use their own persistent identity category rather than procedural StableAddresses.

Presentation may realize one logical building piece using different:

- meshes;
- materials;
- damage-state visuals;
- LODs;
- combined batches;
- decoration variants.

Replacing or batching those resources must not change the persistent identity or logical state of the placed object.

Exact building placement, snapping, support and crafting rules belong to the building/gameplay architecture, not this presentation contract.

## 7. Item example

Authored item identity is semantic content identity, not a mesh or scene path.

Conceptually:

```text
item semantic ID
      ↓
item definition / runtime item state
      ↓
visual or equipment presentation role
      ↓
mesh / scene / material / icon
```

A sword can therefore receive a new mesh, material, icon or held presentation without becoming a different logical item unless the authored definition itself deliberately changes.

Presentation must not move combat timing, damage authority, inventory ownership or persistence into the visual asset.

## 8. Character example

The prototype character already demonstrates the intended separation:

```text
CharacterBody3D + gameplay controllers
        = gameplay authority

visual mannequin / future compatible rig
        = presentation
```

A production body, rig or animation set may replace the mannequin while movement, persistence and combat contracts remain authoritative elsewhere.

Animation presentation may visualize an attack, parry, dodge or block state, but the animation clip must not become the sole authority for whether the gameplay action exists, whether damage resolves, or how the persistent character is identified.

Presentation adapters should translate semantic roles into concrete clip/bone/socket paths rather than exposing those paths to gameplay systems.

## 9. Audio and VFX

Audio and VFX are derived presentation unless a separate gameplay contract explicitly promotes some parameter to authoritative simulation state.

Presentation may react to authoritative events such as:

- hit resolved;
- object harvested;
- cave cell became visible;
- entrance became relevant;
- character entered an action state.

The selected sound, particle resource or emitter instance must not determine whether the underlying gameplay event occurred.

If gameplay depends on a value, that value belongs in gameplay/world data and presentation consumes it.

## 10. Batching, LOD and mesh combining

Performance representation may combine many logical objects into fewer render resources.

That optimization must preserve a mapping back to logical identity wherever interaction, persistence, diagnostics or selective updates require it.

Therefore:

```text
many logical objects -> one render batch
```

is allowed, but:

```text
one render batch -> one new logical persistent object
```

is not.

Likewise:

- an LOD switch does not create or destroy logical world content;
- mesh combining does not merge StableIds or semantic content IDs;
- renderer-local instance indexes are transient acceleration data only;
- unloading a render batch cannot erase durable state.

## 11. Streaming boundary

Presentation lifetime follows runtime demand, not persistence ownership.

A streamed representation may be created, released and rebuilt repeatedly while the underlying deterministic definition and durable deltas remain unchanged.

Near boundaries such as cave entrances, multiple presentation domains may coexist. This does not imply multiple authoritative worlds or a global presentation mode switch.

Exact streaming thresholds and performance budgets remain owned by runtime/performance work.

## 12. Dependency direction

Presentation may depend on authoritative data through explicit runtime adapters and semantic roles.

Authoritative gameplay/content/world definitions must not depend on concrete presentation internals.

Good:

```text
semantic visual role
semantic animation role
semantic audio role
renderer-neutral geometry source
```

Bad:

```text
CombatManager checks animation filename
save stores MeshInstance3D path as item identity
worldgen loads a cave scene to decide topology
building persistence uses MultiMesh index as placed-object ID
```

This follows the project-wide dependency direction in [Dependency Rules](DEPENDENCY_RULES.md).

## 13. What a presentation change is allowed to invalidate

Presentation work may invalidate disposable representation caches when necessary.

It may require rebuilding:

- render meshes;
- material instances;
- shader caches;
- LOD data;
- presentation scene instances;
- audio/VFX bindings.

It must not, solely because presentation changed, invalidate:

- world seeds;
- procedural StableIds;
- semantic content IDs;
- durable player/world deltas;
- inventory or gameplay identity;
- generator compatibility manifests unless deterministic generation itself actually changed.

## 14. Review checklist

Before treating a change as presentation-only, verify:

1. Does it leave deterministic world existence/topology/placement unchanged?
2. Does it leave semantic authored identity unchanged?
3. Does it leave durable player/world state ownership unchanged?
4. Could the new asset/file path change again without migration of logical identity?
5. Are gameplay timing, collision/traversal and simulation still owned by their existing contracts?
6. If batching or LOD changes, are logical identities still individually recoverable where required?
7. Can the presentation be unloaded/rebuilt without losing authoritative state?

If any answer is no, route the change through the owning gameplay, worldgen, persistence or runtime architecture rather than hiding it inside presentation.

## 15. Intentionally open

This contract does not decide:

- final art style or palette;
- final shader technology;
- forward/deferred/clustered or alternate renderer choice;
- final cave meshing algorithm;
- final polygon or texture budgets;
- exact LOD thresholds;
- final batching strategy;
- final animation technology;
- final audio middleware/mixing approach;
- final VFX implementation.

Those may evolve independently as long as the ownership and identity boundary above remains intact.
