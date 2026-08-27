# Underworld — Technical Architecture

This document defines the architecture that should exist before substantial Underworld generation code is added. Exact class names may change; the separation of responsibilities should not change casually.

## 1. Core separation — LOCKED

The project must separate these concepts:

1. **World definition** — deterministic data describing what exists.
2. **Topology** — graph relationships between underground regions, networks, chambers, tunnels and entrances.
3. **Geometry description** — shapes/paths/volumes derived from topology.
4. **Runtime representation** — Godot nodes, meshes, collision, AI and audio currently instantiated.
5. **Persistent deltas** — player-caused changes to the deterministic world.

Do not collapse these into one generator that creates scene nodes directly.

## 2. One world coordinate system — LOCKED

All generated definitions use global 3D world coordinates.

Surface and underground may use different spatial indexing/streaming grids internally, but all definitions must map losslessly into the same X/Y/Z world space.

## 3. Deterministic staged generation — LOCKED

Persistent generation uses the architecture in `DETERMINISTIC_SEED_DOMAINS.md`.

Randomness is derived conceptually from:

```text
world seed
+ seed-schema version
+ immutable named domain ID
+ explicit domain revision
+ semantic StableAddress
+ optional semantic subkey
```

rather than from a mutable chain such as `world RNG -> region RNG -> network RNG -> node RNG`.

Requirements:

- generation order must not change results;
- worker scheduling must not change results;
- loading chunks/regions in a different order must not change results;
- accepted/rejected candidate count must not shift sibling randomness;
- unrelated generator changes should be isolated by independent seed domains;
- topology and detailed geometry randomness are separate compatibility domains;
- generated IDs must not depend on RNG state or accepted-array ordering;
- cross-region candidates use canonical ownership/addressing before seed derivation;
- persistent generation uses a project-owned/frozen deterministic RNG/value contract with hard-coded compatibility test vectors before production saves depend on it.

The global generator version is a compatibility manifest and is **not** automatically mixed into every seed. Local domain revisions allow one generation subsystem to change without automatically reshuffling unrelated systems.

## 4. World-definition data model — DIRECTIONAL

The architecture should support data similar to:

### `WorldDefinition`

- world seed;
- schema version;
- generator version/manifest reference;
- seed-schema version;
- references/addresses for macro surface and underground regions.

### `UndergroundRegionDefinition`

- stable region ID;
- semantic stable address;
- world-space bounds/anchor;
- dominant depth profile(s);
- network references;
- high-level special-location references.

A cached derived seed may be stored for convenience, but semantic identity/address + domain contract remains the source of truth.

### `CaveNetworkDefinition`

- stable network ID;
- graph node IDs;
- graph edge IDs;
- entrance IDs;
- topology metrics useful for validation/connectivity passes.

### `CaveNodeDefinition`

Represents an abstract chamber/junction/major volume before final mesh construction.

Potential fields:

- stable ID;
- world position;
- approximate bounds/radius;
- depth/profile blend;
- semantic type/tags;
- optional cached deterministic local values derived from its stable address/domains.

### `CaveEdgeDefinition`

Represents a connection before detailed tunnel geometry.

Potential fields:

- stable ID;
- endpoints;
- connection class: primary, proximity connection, deliberate topology loop, vertical transition, entrance path, etc.;
- path/control information;
- width/verticality tendencies;
- optional cached deterministic local values derived from its stable address/domains.

### `EntranceDefinition`

- stable ID;
- surface world position;
- connected network/node;
- connection depth;
- entrance/descent profile;
- optional cached deterministic local values derived from its stable address/domains.

The exact GDScript resource/class layout is **OPEN** until implementation planning, but the graph/data split is locked.

## 5. Depth profiles — LOCKED ARCHITECTURAL INTERFACE

Shallow, mid and deep must be expressible as independent generation profiles rather than one generator full of scattered depth conditionals.

A profile should eventually control distributions such as:

- chamber size/shape;
- tunnel width/length;
- verticality;
- branch/dead-end frequency;
- network size;
- loop/connectivity tendency;
- water/geology tendencies;
- entrance tendency;
- structure/resource/ecology hooks.

Profiles may blend spatially. A cave may transition continuously across depths.

Random variation used by these profiles must come from stable-address seed domains rather than shared RNG state.

## 6. Secondary connectivity pass — LOCKED

Primary cave topology is generated first.

A separate analysis pass may then propose and score additional connections between existing graph components/branches.

This system must be able to:

- identify close physical approaches;
- identify larger useful loop opportunities;
- reject redundant connections;
- cap connectivity to avoid spaghetti graphs;
- vary behavior by depth/region profile;
- record the resulting edge as a normal stable world-definition object.

Candidate enumeration, random scoring terms and tie resolution must be deterministic and canonical. Cross-region candidates have one owner/address before seed derivation.

Do not bake the ~10% connectivity philosophy into random tunnel generation alone.

## 7. Geometry generation — LOCKED DIRECTION

Initial Underworld geometry should be chamber/tunnel based, not unrestricted destructible voxel terrain.

Geometry generation consumes graph definitions and produces streamable geometry descriptions/runtime meshes.

Structural cave geometry and locally modifiable/excavatable material must be distinguishable at the data level.

Geometry randomness is separated from topology randomness so future remeshing/tunnel-shape changes do not automatically reshuffle graph connectivity.

## 8. Runtime streaming tiers — LOCKED

Runtime systems should support progressively more expensive representations:

1. deterministic definition exists only as data/address;
2. geometry description available/cached;
3. rendered mesh loaded;
4. collision loaded nearby;
5. creatures/interactables actively simulated nearby;
6. local audio active only when relevant.

The exact distance thresholds are **OPEN** and should be measured later.

No design should require all underground networks to exist as live Godot nodes simultaneously.

## 9. Stable procedural identities — LOCKED

Persistent procedural objects use the architecture in `STABLE_PROCEDURAL_IDS.md`.

Identity derives from stable candidate/generation addresses, not accepted-array indexes, runtime nodes, runtime positions or RNG-call order.

Conceptual hierarchy:

`world / region / network / node-or-edge / local-object-key`

A generator density change must not silently rename unrelated persistent objects.

This rule also applies to surface procedural objects. Existing prototype index-based IDs must be migrated before incompatible generator tuning makes the legacy mapping unsafe.

## 10. Persistence model — LOCKED

Untouched procedural world data is regenerated from seed and compatible generation contracts.

Save data stores deltas such as:

- removed/harvested stable object IDs;
- player inventory/state;
- built structures;
- modifiable-terrain deltas;
- cleared collapses/changed structures;
- boss/special-location state;
- other explicit player/world-state changes.

Do not save complete untouched cave networks/chunks merely because they were visited.

Save migrations must be versioned and testable.

The persistence/versioning document will define how generator-version manifests, seed-schema versions and per-domain revisions interact with old worlds.

## 11. Threading boundary — LOCKED DIRECTION

Pure deterministic generation/data work may run on worker threads.

Godot scene-tree mutation, node creation and physics-server-facing scene setup must remain on the appropriate main-thread boundary unless Godot explicitly guarantees otherwise.

No shared mutable generation RNG crosses worker boundaries. Each generation task derives local randomness from stable addresses/domains.

The existing surface prototype already follows the general data-worker/runtime-main-thread split; the Underworld architecture should preserve and formalize it.

## 12. Validation hooks — LOCKED

Every generated graph/data object should expose enough information for headless validation without rendering.

A failing generation test must be reproducible from at least:

- world seed;
- seed-schema version;
- generator version/manifest;
- relevant seed domain/revision where applicable;
- region/network/object stable ID/address;
- validation failure reason.

Canonical generation fingerprints and fixed seed/RNG test vectors are part of the compatibility suite.

Architecture is incomplete if correctness can only be checked by manually walking through the rendered world.
