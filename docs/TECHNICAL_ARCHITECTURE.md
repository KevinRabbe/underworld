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

Each major generation stage receives deterministic derived seeds rather than sharing mutable global RNG state.

Conceptual seed derivation:

`world_seed -> region_seed -> network_seed -> node/edge/special-location seed`

Requirements:

- generation order must not change results;
- worker scheduling must not change results;
- loading chunks in a different order must not change results;
- unrelated generator changes should be isolated where possible by independent seed domains;
- generated IDs must not depend on accepted-array ordering.

## 4. World-definition data model — DIRECTIONAL

The architecture should support data similar to:

### `WorldDefinition`

- world seed;
- generation version;
- references/addresses for macro surface and underground regions.

### `UndergroundRegionDefinition`

- stable region ID;
- deterministic seed;
- world-space bounds/anchor;
- dominant depth profile(s);
- network references;
- high-level special-location references.

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
- deterministic local seed.

### `CaveEdgeDefinition`

Represents a connection before detailed tunnel geometry.

Potential fields:

- stable ID;
- endpoints;
- connection class: primary, proximity connection, deliberate topology loop, vertical transition, entrance path, etc.;
- path/control information;
- width/verticality tendencies;
- deterministic local seed.

### `EntranceDefinition`

- stable ID;
- surface world position;
- connected network/node;
- connection depth;
- entrance/descent profile;
- deterministic local seed.

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

Do not bake the ~10% connectivity philosophy into random tunnel generation alone.

## 7. Geometry generation — LOCKED DIRECTION

Initial Underworld geometry should be chamber/tunnel based, not unrestricted destructible voxel terrain.

Geometry generation consumes graph definitions and produces streamable geometry descriptions/runtime meshes.

Structural cave geometry and locally modifiable/excavatable material must be distinguishable at the data level.

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

Persistent procedural objects need deterministic IDs derived from stable generation addresses, not array indices.

Conceptual hierarchy:

`world / region / network / node-or-edge / local-object-key`

The exact string/binary representation is **OPEN**.

A generator density change must not silently rename unrelated persistent objects.

This rule also applies to surface procedural objects. Existing prototype index-based IDs are technical debt to migrate before generator tuning makes them unsafe.

## 10. Persistence model — LOCKED

Untouched procedural world data is regenerated from seed and generation version.

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

## 11. Threading boundary — LOCKED DIRECTION

Pure deterministic generation/data work may run on worker threads.

Godot scene-tree mutation, node creation and physics-server-facing scene setup must remain on the appropriate main-thread boundary unless Godot explicitly guarantees otherwise.

The existing surface prototype already follows this general pattern; the Underworld architecture should preserve it.

## 12. Validation hooks — LOCKED

Every generated graph/data object should expose enough information for headless validation without rendering.

A failing generation test must be reproducible from at least:

- world seed;
- generation version;
- region/network stable ID;
- validation failure reason.

Architecture is incomplete if correctness can only be checked by manually walking through the rendered world.
