# Underworld — Underground World Graph Schema

## Status

This document defines the first concrete data model for the deterministic Underworld topology.

The schema is **LOCKED at the architectural level**: topology must exist as pure data before geometry/runtime scene objects. Exact field names, collection types and binary/string ID encoding may still change during implementation if the same semantics are preserved.

The purpose of this schema is to answer one question cleanly:

> What deterministic data describes the underground world before Godot creates any cave mesh, collision body, creature, audio source or scene node?

Stable identity is defined in `STABLE_PROCEDURAL_IDS.md`. Deterministic randomness for these addresses is defined in `DETERMINISTIC_SEED_DOMAINS.md`.

---

## 1. Core model

The underground world is represented as a graph hierarchy:

```text
WorldDefinitionIndex
    |
    +-- UndergroundRegionDefinition
            |
            +-- CaveNetworkDefinition
            |       |
            |       +-- CaveNodeDefinition
            |       +-- primary CaveEdgeDefinition
            |       +-- EntranceDefinition refs
            |
            +-- secondary/cross-network CaveEdgeDefinition
            +-- EntranceDefinition
            +-- SpecialLocationHookDefinition
```

Definitions are deterministic world data. They are not Godot scene-tree objects.

### Terminology

- **Region** — deterministic macro-generation/ownership partition. A region is not necessarily a visible biome and is not a runtime streaming chunk.
- **Network** — one primary generated cave component with a stable identity.
- **Node** — abstract chamber, junction, transition anchor or other important graph point.
- **Edge** — abstract traversable connection between nodes.
- **Entrance** — deterministic surface-to-underground connection description.
- **Secondary connector** — an accepted post-generation connection/loop between already-generated graph parts.
- **Special-location hook** — stable reserved anchor for future structures, large deposits, boss lairs or other special content.

A later secondary connection does **not** merge or rename the original networks. Stable network identities survive future connectivity passes.

---

## 2. Representation in Godot

### 2.1 Pure data classes — LOCKED DIRECTION

The first implementation should use typed data-only GDScript classes extending `RefCounted` (or an equivalently scene-independent representation).

They must not depend on:

- `Node`;
- `Node3D`;
- scene-tree ownership;
- active physics objects;
- loaded meshes;
- runtime AI/audio state.

This keeps topology generation usable on worker threads and in headless validation.

### 2.2 IDs are opaque at this layer

Every definition stores a stable procedural ID as an opaque value produced by the central stable-ID/address architecture.

The first implementation may use `String` for readability/debugging, but graph code must not infer semantic meaning by manually parsing ad-hoc ID strings.

Where generation needs randomness, it derives that randomness from the semantic stable address plus a named/revisioned seed domain. A cached local seed/value may be stored as data, but it is not the identity and is not produced by a parent/shared mutable RNG stream.

### 2.3 Collection rule

Objects are indexed by stable ID rather than by accepted-array position.

A region may physically store definitions in dictionary-like indexes plus sorted ID arrays for deterministic iteration/debug output.

Generation, hashing and serialization must never rely on dictionary iteration order.

---

## 3. `WorldDefinitionIndex`

The world-level definition should remain lightweight. It is an address/index, not a requirement to hold the entire Underworld in memory.

Required semantic fields:

```text
WorldDefinitionIndex
- world_seed
- schema_version
- generator_version / manifest reference
- seed_schema_version
- world_id
- surface_definition_address / surface bounds reference
- underground_region_addressing configuration
- optional generated-region cache/index metadata
```

### Rules

- The world seed is the root deterministic entropy input.
- `schema_version` describes the data layout/contract.
- `generator_version` describes/identifies the compatible set of generation contracts.
- `seed_schema_version` identifies the fundamental seed-derivation encoding/algorithm contract.
- World definition indexing must support lazy regional generation.
- Opening a save must not require constructing every underground network as a live object.

---

## 4. `UndergroundRegionDefinition`

A region is the primary deterministic ownership unit for underground topology generation.

It exists to make generation, caching, streaming hand-off, validation and cross-region ownership manageable.

Required semantic fields:

```text
UndergroundRegionDefinition
- stable_id
- stable_address
- region_coord
- world_space_bounds / anchor
- dominant_profile_bias / profile data
- network_ids
- entrance_ids
- secondary_edge_ids owned by this region
- special_location_hook_ids
- topology metrics / validation metadata
```

A region coordinate/address is a generation partition. It is not required to equal a runtime streaming cell.

---

## 5. `CaveNetworkDefinition`

A network represents one primary generated cave component before secondary connections are applied.

Required semantic fields:

```text
CaveNetworkDefinition
- stable_id
- stable_address
- owning_region_id
- root_node_id
- node_ids
- primary_edge_ids
- entrance_path_edge_ids
- attached_entrance_ids
- topology metrics
```

### Network identity rule — LOCKED

A secondary connector that links Network A and Network B does **not** merge their identities into a newly numbered network.

After connection:

```text
Network A identity remains A
Network B identity remains B
Secondary Edge X connects nodes from A and B
```

This prevents persistent IDs from changing simply because topology later gains a useful loop/reconnection.

Entrance-anchor nodes belong to the existing network, while their edges are kept
in `entrance_path_edge_ids`. They therefore extend reachability without being
misclassified as part of the original primary tree.

---

## 6. `CaveNodeDefinition`

A node represents an abstract important underground volume before detailed geometry is produced.

Required semantic fields:

```text
CaveNodeDefinition
- stable_id
- stable_address
- owning_network_id
- world_position
- approximate_shape / bounds parameters
- profile_blend
- semantic_type / tags
- generation metadata needed by later stages
```

Potential semantic node types include:

```text
chamber
junction
vertical_transition
terminal
major_chamber
structure_anchor
```

These are generation semantics, not final gameplay content classes.

### Profile blend — LOCKED

Nodes carry continuous shallow/mid/deep weights, conceptually:

```text
profile_blend = [shallow, mid, deep]
```

Example:

```text
[0.35, 0.60, 0.05]
```

Weights should be normalized/canonical for deterministic serialization.

This allows smooth structural transitions without converting the Underworld into rigid floors.

---

## 7. `CaveEdgeDefinition`

An edge represents one abstract traversable connection between two nodes.

Required semantic fields:

```text
CaveEdgeDefinition
- stable_id
- stable_address
- endpoint_a_node_id
- endpoint_b_node_id
- owning_region_id
- connection_class
- topology parameters
- geometry-tendency parameters / later geometry-description address
- optional tags
```

Connection classes should distinguish at least conceptually:

```text
primary
vertical_transition
entrance_path
proximity_connection
deliberate_loop
cross_region_connection
```

The class describes why the edge exists. It does not force a specific mesh shape.

### Endpoint canonicalization

If an edge is semantically undirected, endpoint ordering must be canonical for identity/serialization purposes.

For example:

```text
A-B == B-A
```

must not become two persistent connector identities.

---

## 8. `EntranceDefinition`

An entrance is its own stable world-definition object rather than an incidental hole in a surface mesh.

Required semantic fields:

```text
EntranceDefinition
- stable_id
- stable_address
- owning_region_id
- connected_network_id
- connected_node_id
- surface_world_position
- underground_connection_position / depth
- entrance_kind / descent_profile
- surface-integration parameters
- generation metadata
```

Potential descent profiles include conceptually:

```text
gradual_cave
steep_sinkhole
constructed_descent
crevice
```

The exact final roster remains open.

### Entrance count

The design target of roughly 1–3 entrances applies to suitable networks/regions as a procedural tendency rather than a hard invariant for every generated system.

The schema therefore stores an arbitrary list and the generator/validator applies the actual profile rules.

---

## 9. Secondary connection model

Secondary connections happen **after** primary topology exists.

Conceptual transient candidate:

```text
ConnectionCandidate
- endpoint_a
- endpoint_b
- canonical candidate address
- physical distance
- topology gain
- depth/profile usefulness
- entrance/network usefulness
- redundancy penalty
- estimated connector cost
- score
```

`ConnectionCandidate` is analysis/transient data and does not become persistent world truth unless accepted.

If accepted:

```text
ConnectionCandidate
    -> stable CaveEdgeDefinition
```

The resulting edge receives its own stable ID/address according to the stable-ID architecture.

Random score/acceptance terms derive from that candidate address and secondary-connectivity seed domains, not from candidate enumeration order.

### Why this matters

This keeps the ~10% Souls-style connectivity as an explicit analysis layer rather than accidental random spaghetti.

---

## 10. Cross-region connections

Underworld networks can eventually cross macro region boundaries.

Cross-region connections must have exactly one deterministic owner.

Conceptual canonical ownership rule:

```text
owner = deterministic minimum/canonical region key
```

or another explicit canonical function chosen during implementation.

Requirements:

- Region A generated first or Region B generated first must produce the same connection identity.
- No duplicate connectors may appear because both regions believe they own it.
- Cross-region candidates use canonical ordered region/endpoint keys before stable-ID and seed derivation.
- Neighbor-region metadata may be requested/generated as pure data without instantiating either region as runtime scene geometry.

---

## 11. `SpecialLocationHookDefinition`

The topology architecture must support future special content without implementing it now.

Required semantic fields conceptually:

```text
SpecialLocationHookDefinition
- stable_id
- stable_address
- owning_region_id
- anchor_node_id / edge_id / free world anchor
- semantic category
- reserved bounds / clearance needs
- profile/depth context
- generation metadata
```

Future categories may include:

```text
large_deposit
structure
boss_lair
ancient_complex
major_rubble/collapse
other special location
```

The hook reserves/identifies world space. The later gameplay/content generator decides what actual content to build there.

This prevents topology code from becoming a giant boss/ore/ruin generator.

---

## 12. Topology is not geometry

The graph schema describes connectivity and approximate spatial intent.

It does not contain final mesh triangles.

Conceptually:

```text
CaveNodeDefinition
CaveEdgeDefinition
        |
        v
GeometryDescription
        |
        +-- chamber volumes
        +-- tunnel centerline/control points
        +-- cross-section parameters
        +-- structural bedrock classification
        +-- optional modifiable-material volumes
        |
        v
Runtime meshes/collision
```

A geometry algorithm may be replaced without requiring the graph topology to be redesigned.

Topology randomness and detailed geometry randomness also use separate seed domains so geometry changes do not automatically reshuffle connectivity.

---

## 13. Runtime streaming cells are separate

Runtime streaming cells partition expensive instantiated content.

They are not necessarily the same size or shape as:

```text
macro underground regions
cave networks
surface chunks
```

One cave network may pass through multiple runtime cells.

One runtime cell may contain pieces of multiple networks.

Stable world objects keep their graph identity regardless of runtime cell assignment.

---

## 14. Finalized definitions are immutable-by-convention — LOCKED

Generation stages may use mutable builders while constructing a region.

Once finalized/validated, the deterministic world definition is treated as immutable for that seed/generation contract.

Gameplay does not modify the graph definition directly.

Instead:

```text
generated definition + saved player delta = current world state
```

Examples:

```text
collapsed edge exists in definition
save delta says collapse was cleared

ore deposit exists in definition
save delta says deposit was partially mined
```

This keeps regeneration and persistence cleanly separated.

---

## 15. Canonical serialization/debug representation

For testing and debugging, every definition must support a canonical representation.

Requirements:

- sort objects by stable ID/address;
- canonical endpoint ordering;
- canonical normalized profile weights;
- explicit field order in fingerprints/serialized debug form;
- do not rely on dictionary iteration order;
- do not serialize runtime object addresses/instance IDs;
- deterministic numeric rounding policy where floating values enter fingerprints.

This allows tests like:

```text
fingerprint(seed=123, region=4,-2, run=A)
==
fingerprint(seed=123, region=4,-2, run=B)
```

including when generated in different worker/load orders.

---

## 16. Required graph invariants

Headless validation should be able to assert at least:

1. every ID in one ownership scope is unique;
2. every edge endpoint references an existing node;
3. every node references an existing owning network;
4. every entrance references an existing target network/node;
5. primary networks are internally reachable according to their generation contract;
6. no prohibited self-edge exists;
7. duplicate undirected edges are absent unless explicitly allowed;
8. secondary connectors obey per-profile connectivity caps;
9. cross-region edges have exactly one canonical owner;
10. profile weights are valid/normalized;
11. world positions/bounds are finite;
12. canonical serialization is repeatable;
13. identical stable addresses/domain contracts derive identical deterministic randomness independent of generation order.

A test failure must identify:

```text
world seed
generator/seed-schema version
region ID
network ID if applicable
object ID/address if applicable
seed domain/revision if randomness is involved
invariant violated
```

---

## 17. Initial GDScript class direction

Exact implementation is not written in this documentation cycle, but the first code pass should favor small typed data classes rather than nested untyped dictionaries everywhere.

Conceptually:

```text
world/generation/
    stable_address.gd
    stable_id.gd
    seed_domains.gd
    seed_deriver.gd
    deterministic_rng.gd
    world_definition_index.gd
    underground_region_definition.gd
    cave_network_definition.gd
    cave_node_definition.gd
    cave_edge_definition.gd
    entrance_definition.gd
    special_location_hook_definition.gd
```

A builder/validator layer can follow separately.

This is directional structure, not a requirement that every file name remain exactly this way.

---

## 18. What remains open

This schema intentionally does not yet lock:

- exact underground region size;
- exact runtime streaming-cell dimensions;
- exact chamber-shape representation;
- exact spline/tunnel representation;
- exact numerical shallow/mid/deep curves;
- exact entrance-placement algorithm;
- exact secondary-connection scoring weights;
- exact geometry meshing algorithm;
- exact binary/string stable-ID encoding;
- exact seed hash/PRNG implementation below the `DETERMINISTIC_SEED_DOMAINS.md` contract.

Those choices belong to later architecture/implementation steps. The semantic data boundaries above are now the contract they must fit.
