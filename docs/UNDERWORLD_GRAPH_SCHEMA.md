# Underworld — Underground World Graph Schema

## Status

This document defines the first concrete data model for the deterministic Underworld topology.

The schema is **LOCKED at the architectural level**: topology must exist as pure data before geometry/runtime scene objects. Exact field names, collection types and binary/string ID encoding may still change during implementation if the same semantics are preserved.

The purpose of this schema is to answer one question cleanly:

> What deterministic data describes the underground world before Godot creates any cave mesh, collision body, creature, audio source or scene node?

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

Every definition stores a stable procedural ID as an opaque value. The first implementation may use `String` for readability/debugging, but the exact encoding is specified separately by the stable-ID architecture.

Graph code must not infer semantic meaning by manually parsing ID strings unless the stable-ID specification explicitly defines that operation.

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
- generator_version
- world_id
- surface_definition_address / surface bounds reference
- underground_region_addressing configuration
- optional generated-region cache/index metadata
```

### Rules

- The world seed is the root deterministic input.
- `schema_version` describes the data layout/contract.
- `generator_version` describes the algorithm/content-generation contract.
- World definition indexing must support lazy regional generation.
- Opening a save must not require constructing every underground network as a live object.

---

## 4. `UndergroundRegionDefinition`

A region is the primary deterministic ownership unit for underground topology generation.

It exists to make generation, caching, streaming hand-off, validation and cross-region ownership manageable.

Required semantic fields:

```text
UndergroundRegionDefinition
- id
- deterministic_seed
- region_key / macro address
- world-space horizontal footprint or macro bounds
- supported vertical/depth extent metadata
- network_ids
- node index
- edge index
- entrance index
- special_location_hook index
- references to cross-region edges owned elsewhere
- derived validation/topology metrics
```

### Important distinction

**Region != cave network != runtime chunk.**

A region is an ownership/generation partition. A cave network is semantic topology. Runtime streaming may use completely different 3D cells.

This separation is locked because large deep systems may cross region boundaries and runtime streaming should not be forced to match macro generation size.

---

## 5. `CaveNetworkDefinition`

A network represents one primary generated cave component before optional secondary connections join it to other networks.

Required semantic fields:

```text
CaveNetworkDefinition
- id
- owner_region_id
- deterministic_seed
- root_or_anchor_node_id
- primary_node_ids
- primary_edge_ids
- entrance_ids
- accepted_secondary_edge_ids
- dominant/profile-summary metadata
- semantic tags
- derived topology metrics
```

### Stable identity rule — LOCKED

If network A and network B are later connected by a proximity tunnel or topology loop, they remain network A and network B.

Do not renumber or merge them into a new accepted-array component identity.

This prevents secondary topology changes from cascading into unrelated persistent IDs.

### Network connectivity invariant

The **primary** node/edge set of a network should form one connected component unless a future explicit network type documents otherwise.

---

## 6. `CaveNodeDefinition`

A node represents an important abstract spatial volume/anchor before detailed geometry generation.

Suggested semantic fields:

```text
CaveNodeDefinition
- id
- owner_region_id
- owner_network_id
- deterministic_seed
- world_position : Vector3
- node_role
- approximate_horizontal_clearance
- approximate_vertical_clearance
- depth_below_local_surface
- depth_profile_blend
- semantic_tags
- optional reserved-space hint
```

### `node_role`

Initial stable semantic roles should be small and generic, for example:

- `chamber`
- `junction`
- `transition`
- `entrance_attach`
- `special_anchor`

Roles describe topology intent, not final art/mesh shape.

### Approximate clearance

Topology needs enough spatial information to avoid impossible overlaps and to evaluate possible connections. Therefore nodes may carry approximate clearance/volume hints.

These hints are **not final cave geometry**.

The geometry stage remains free to create irregular organic spaces inside the allowed envelope.

---

## 7. Continuous depth representation

The graph does not store a single hard `SHALLOW`, `MID` or `DEEP` enum as the complete truth.

Each node should store:

```text
depth_below_local_surface : float

depth_profile_blend:
- shallow_weight
- mid_weight
- deep_weight
```

Weights should normally sum to approximately `1.0`.

Examples:

```text
very shallow chamber:  [0.95, 0.05, 0.00]
transition chamber:    [0.35, 0.60, 0.05]
mid/deep transition:   [0.00, 0.45, 0.55]
deep chamber:          [0.00, 0.05, 0.95]
```

### Why this is required

- Depth grammar boundaries remain continuous.
- One vertical cave can pass naturally through multiple grammar influences.
- Geometry/resource/ecology generators can consume the same blend without duplicated depth-condition logic.
- Local exceptions remain possible.

Exact meter ranges and blend curves remain **OPEN**.

---

## 8. `CaveEdgeDefinition`

An edge is an abstract traversable relationship between two nodes.

Required semantic fields:

```text
CaveEdgeDefinition
- id
- owner_region_id
- deterministic_seed
- node_a_id
- node_b_id
- connection_origin
- route_intent
- approximate_clearance_hint
- verticality_hint
- curvature/directness hint
- semantic_tags
```

### `connection_origin`

This records **why the edge exists**, which is useful for validation and topology analysis.

Initial values:

- `primary`
- `proximity_secondary`
- `topology_loop_secondary`
- `cross_region`

An edge may carry multiple semantic tags when necessary, but its deterministic creation origin should remain inspectable.

### `route_intent`

This gives the later geometry stage constraints/tendencies without prematurely defining the mesh.

Examples:

- normal tunnel
- broad connector
- steep descent
- near-vertical shaft
- narrow crack
- water-path candidate

The exact route taxonomy remains **DIRECTIONAL** until geometry implementation.

### No mesh data

An edge must not contain final triangle vertices, collision shapes or scene references.

A later geometry-description stage consumes the edge and produces a coarse centerline/volume description before mesh construction.

---

## 9. `EntranceDefinition`

Entrances are explicit world-definition objects because they connect two different environmental domains: surface geography and underground topology.

Required semantic fields:

```text
EntranceDefinition
- id
- owner_region_id
- target_network_id
- target_node_id
- deterministic_seed
- surface_anchor_position : Vector3
- underground_connection_depth
- descent_profile
- orientation/direction hint
- surface_form_tag
- semantic_tags
```

### `descent_profile`

Initial conceptual values:

- gradual
- steep
- shaft
- constructed

These are generation intents, not guaranteed final visual types.

### Entry depth rule — LOCKED

Different entrances to the same network may connect at very different depths.

The graph must therefore never assume that entrance order corresponds to progression order.

### Entrance-count validation

Roughly 1–3 entrances is the normal design range for surface-accessible regional networks, **not an absolute invariant for every underground component**.

Validation should distinguish:

- hard invalid states (broken target, impossible surface anchor);
- design-distribution warnings (unexpectedly many/few entrances).

This preserves room for hidden/isolated systems and future special cases without silently allowing corrupted references.

---

## 10. Secondary connectivity and the ~10% philosophy

The secondary topology pass operates on completed primary network graphs.

It evaluates candidate node/network pairs and may create additional `CaveEdgeDefinition` objects.

### Candidate data is transient

A candidate connection is **not** part of the permanent world definition until accepted.

Transient analysis may contain:

```text
ConnectivityCandidate
- endpoint_a
- endpoint_b
- direct_distance
- estimated_connector_cost
- topology_gain
- depth_gain
- entrance_link_value
- redundancy_penalty
- plausibility_score
- final_score
- rejection/acceptance reason
```

Only accepted candidates become stable edges with stable IDs.

### Two supported mechanisms

1. **Proximity connection** — branches/networks physically approach one another.
2. **Deliberate topology loop** — a longer but still plausible connector materially improves the graph.

### Anti-spaghetti rules

The pass must be able to reject a connector because:

- the endpoints already have adequate alternate routes;
- local node degree is too high;
- regional loop/connectivity budget is exhausted;
- connector length/cost is excessive;
- the route would cause invalid geometry reservations;
- the depth profile discourages added connectivity;
- it adds little topology value.

The ~10% design target is a generation philosophy/distribution target, not a requirement that exactly 10% of edges are secondary.

---

## 11. Cross-network and cross-region connections

This is required so the Underworld can become materially more connected and larger than the surface without sacrificing deterministic regional generation.

### Cross-network

A secondary edge may reference nodes owned by different `CaveNetworkDefinition` objects.

The networks keep their original IDs.

### Cross-region

An edge may cross macro region ownership boundaries.

To avoid duplicate/order-dependent generation, every cross-region edge has one **canonical owner region**.

The exact canonical ordering/ID algorithm is part of the stable-ID/seed specification, but the rule is locked:

> The same cross-region connection must be produced once, with the same owner and ID, regardless of which neighboring region is generated first.

Non-owning regions may store lightweight external-edge references/boundary stubs for validation and streaming hand-off.

### Runtime implication

Runtime streaming may load geometry around a cross-region edge without loading every definition from both macro regions as scene nodes.

---

## 12. `SpecialLocationHookDefinition`

The architecture must reserve deterministic locations for future content without implementing that content during the topology cycle.

Suggested semantic fields:

```text
SpecialLocationHookDefinition
- id
- owner_region_id
- deterministic_seed
- anchor_type
- anchor_id / world_position
- category_tag
- approximate_reserved_volume
- depth_profile_blend
- semantic_tags
```

Potential future `category_tag` values include:

- structure
- large_deposit
- boss_lair
- nest
- unique_landmark
- water_feature

These are hooks only. The current architecture cycle does not implement the associated gameplay/content.

### Why hooks belong in the world definition

This preserves the design rule that important underground content can exist independently of player progression and future building choices.

A future rare boss lair beneath a player's eventual 200-hour base is deterministic world geography/content placement, not a reactive spawn caused by the base.

---

## 13. Derived topology metrics

Metrics are useful for validation and the secondary-connection scorer but are **derived data**, not source-of-truth topology.

Useful metrics include:

```text
- node_count
- primary_edge_count
- secondary_edge_count
- entrance_count
- connected_component_count
- min_depth
- max_depth
- vertical_span
- average_node_degree
- maximum_node_degree
- cycle_rank / independent_loop_count
- shortest/alternate path statistics between entrances
```

Metrics should be recomputable from the graph.

If cached metrics disagree with recomputation, validation fails.

---

## 14. Immutable finalized definitions

Generation stages may use mutable internal builders, but finalized world-definition objects are treated as immutable-by-convention.

Conceptual flow:

```text
RegionGraphBuilder
    -> primary networks
    -> depth assignment
    -> entrance assignment
    -> secondary connectivity
    -> special-location reservations
    -> validate
    -> freeze/finalize UndergroundRegionDefinition
```

Runtime gameplay does **not** mutate the generated graph definition to represent player actions.

Player/world changes are stored as persistent deltas referencing stable IDs.

Examples:

- collapse cleared;
- resource removed;
- boss defeated;
- player structure built;
- local modifiable volume excavated.

This protects deterministic regeneration and makes save/version reasoning possible.

---

## 15. What is explicitly NOT in the topology graph

The following must remain outside this schema:

- final mesh vertices/indices;
- `MeshInstance3D` / `StaticBody3D` / `CollisionShape3D` objects;
- currently spawned creatures;
- creature AI state;
- active audio emitters;
- particle effects;
- player inventory;
- player buildings;
- harvested/destroyed runtime state;
- detailed visual materials;
- final terrain-deformation meshes;
- production encounter logic.

Some future systems may reference graph IDs, but they do not become topology merely because they are located underground.

---

## 16. Geometry-description boundary

Topology generation ends with abstract nodes/edges/entrances and spatial constraints.

The next stage produces a **geometry description**, for example:

```text
CaveGeometryDescription
- node volume descriptions
- tunnel centerlines / spline control points
- radius/clearance samples
- structural-bedrock classification
- designated modifiable/excavatable volumes
- surface entrance cut volumes
- streaming-cell coverage metadata
```

Only after this description exists does runtime mesh/collision construction occur.

This prevents topology decisions from being hidden inside mesh-building code.

---

## 17. Required graph invariants

The validator must at minimum enforce these hard invariants.

### Identity/reference integrity

- all stable IDs are unique in their required scope;
- every referenced region/network/node/edge/entrance exists;
- IDs do not depend on accepted-array order;
- no cross-region edge has ambiguous ownership.

### Graph integrity

- primary network graph is connected;
- no accidental self-edge;
- invalid duplicate endpoint connections are rejected unless an explicit route type permits parallel paths;
- every entrance target is reachable within its referenced network;
- secondary connectors reference valid finalized primary nodes;
- graph degree/connectivity hard safety caps are respected.

### Spatial/depth integrity

- node positions are finite and inside supported world extents;
- approximate node reservations do not violate hard exclusion constraints;
- depth values are consistent with the deterministic surface-height provider within defined tolerance;
- depth-profile weights are finite, non-negative and approximately sum to 1;
- entrance surface anchors are valid surface locations;
- entrance descent route has a geometrically plausible budget.

### Derived-data integrity

- cached topology metrics match recomputation;
- canonical fingerprints are repeatable for the same seed/version/region.

---

## 18. Deterministic debug serialization

The full generated Underworld should not normally be saved into player save files, but graph definitions need deterministic debug/test export.

Every finalized definition should support a canonical primitive representation suitable for:

- JSON snapshots;
- test fixtures;
- deterministic fingerprints/hashes;
- human-readable failure reports.

Canonical export rules:

1. sort objects by stable ID before output;
2. never rely on dictionary iteration order;
3. use stable enum/tag names in debug output;
4. normalize/format floating-point values consistently for snapshot comparison;
5. include schema version and generator version;
6. do not include runtime memory addresses/object instance IDs.

A determinism test should be able to generate the same region twice under different load/thread orders and compare canonical fingerprints.

---

## 19. Worker-thread boundary

All objects defined in this document must be creatable and validated without touching the scene tree.

Allowed during graph generation:

- deterministic math/noise;
- pure surface-height queries from a deterministic data service;
- `Vector2`/`Vector3`/AABB-like value calculations;
- graph algorithms;
- stable-ID/seed derivation;
- validation;
- canonical debug serialization.

Not allowed inside the pure topology generator:

- adding/removing scene nodes;
- creating active physics bodies in the scene;
- querying gameplay AI state;
- reading mutable runtime RNG state;
- depending on player travel/load order.

---

## 20. Example topology

Illustrative only:

```text
Surface

Entrance E1                           Entrance E3
   |                                     |
   | gradual                             | steep/constructed
   v                                     v
[A1 shallow] -- [A2 shallow/mid] -- [A3 mid]
                      |                  |
                      |                  |
                      v                  |
                   [A4 mid]              |
                      |                  |
                 secondary loop          |
                      |                  |
                      v                  |
[B2 mid/deep] ------- [B1 deep] <--------+
   ^
   |
Entrance E2 (sinkhole reaching deep quickly)
```

Possible ownership:

```text
Network A = A1,A2,A3,A4 + primary edges
Network B = B1,B2 + primary edge
Secondary edge = A4 <-> B2
E1/E3 reference Network A
E2 references Network B
```

Even though A and B become traversably connected, their stable network IDs remain unchanged.

---

## 21. Decisions locked by this schema

The following are now architecture rules unless deliberately revised:

1. Underground topology is pure data before geometry/runtime.
2. Macro regions, cave networks and runtime streaming cells are distinct concepts.
3. Primary cave networks retain stable identities after secondary connections.
4. Nodes store continuous depth-profile blends rather than only a hard depth enum.
5. Secondary connectivity is represented as ordinary stable graph edges after acceptance.
6. Cross-region connections have canonical deterministic ownership independent of generation order.
7. Finalized graph definitions are immutable-by-convention; player changes are persistent deltas.
8. Future bosses/structures/large deposits use stable special-location hooks rather than forcing gameplay content into the topology generator.
9. Canonical graph serialization/fingerprints are required for automated determinism testing.
10. Graph generation/validation must work without scene nodes.

---

## 22. Intentionally open implementation details

Do not accidentally lock these while implementing the first version:

- exact macro region dimensions;
- whether region keys are encoded as 2D X/Z coordinates or another equivalent deterministic address;
- exact ID binary/string format;
- exact numeric shallow/mid/deep depth ranges and blend curves;
- exact node-count/network-size distributions;
- exact edge route-intent taxonomy;
- exact geometry algorithm/spline/meshing approach;
- exact runtime underground streaming-cell dimensions;
- exact cache eviction strategy;
- final water/ecology/resource/structure generation systems.

These should be decided by later architecture steps or measured implementation evidence, not by convenience inside the first graph class.
