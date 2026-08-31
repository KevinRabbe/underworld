# Underworld — Underground World Graph Schema

## Status

This document defines the concrete deterministic data model for **Underworld-domain topology**.

The schema is **LOCKED at the architectural level**: topology exists as pure data before geometry/runtime scene objects. Exact field names, collection types and binary/string ID encoding may change if the same semantics are preserved.

World-domain relationship and cross-domain gateway ownership are governed by `20_world/WORLD_DOMAINS_AND_TRANSITIONS.md` and ADR-001.

The purpose of this schema is to answer one question cleanly:

> What deterministic data describes the Underworld before Godot creates cave meshes, collision, creatures, audio or scene nodes?

Stable identity is defined in `STABLE_PROCEDURAL_IDS.md`. Deterministic randomness is defined in `DETERMINISTIC_SEED_DOMAINS.md`.

---

## 1. Core model

The Underworld is represented as a graph hierarchy:

```text
UnderworldDefinitionIndex
    |
    +-- UndergroundRegionDefinition
            |
            +-- CaveNetworkDefinition
            |       |
            |       +-- CaveNodeDefinition
            |       +-- primary CaveEdgeDefinition
            |       +-- UnderworldEntrySiteDefinition refs
            |
            +-- secondary/cross-network CaveEdgeDefinition
            +-- UnderworldEntrySiteDefinition
            +-- SpecialLocationHookDefinition
```

Definitions are deterministic Underworld data. They are not Godot scene-tree objects and they do not contain Overworld runtime state.

### Terminology

- **Region** — deterministic Underworld macro-generation/ownership partition; not necessarily a biome or runtime streaming cell.
- **Network** — one primary generated cave component with stable identity.
- **Node** — abstract chamber, junction, vertical transition or other important graph point.
- **Edge** — abstract traversable connection between nodes.
- **Underworld entry site** — deterministic Underworld-local arrival/exit/topology attachment site that may be targeted by a cross-domain gateway.
- **World gateway** — cross-domain semantic mapping owned outside this graph; maps source domain/source gateway to destination domain/destination site.
- **Secondary connector** — accepted post-generation connection/loop between existing graph parts.
- **Special-location hook** — stable reserved anchor for later structures, deposits, boss spaces or other content.

A later secondary connection does **not** merge or rename original networks. Stable network identities survive future connectivity passes.

---

## 2. Representation in Godot

### 2.1 Pure data classes — LOCKED DIRECTION

Use typed data-only classes extending `RefCounted` or an equivalent scene-independent representation.

They must not depend on:

- `Node` / `Node3D`;
- scene-tree ownership;
- active physics objects;
- loaded meshes;
- runtime AI/audio;
- active world-domain state;
- Overworld runtime/generator objects.

This keeps topology generation worker-safe and headless-testable.

### 2.2 IDs are opaque at this layer

Every definition stores stable procedural identity produced by the central StableAddress/StableId architecture.

Graph code must not infer identity by parsing ad-hoc readable strings.

Randomness derives from semantic stable addresses plus registered seed domains/revisions. Cached local deterministic values may be stored, but RNG state is not identity.

### 2.3 Collection rule

Objects are indexed by stable ID rather than accepted-array position.

A region may use dictionary-like indexes plus sorted stable-ID arrays for deterministic iteration/debugging.

Generation, hashing and canonical serialization never rely on dictionary iteration order.

---

## 3. `UnderworldDefinitionIndex`

The domain-level definition index remains lightweight. It is an address/index, not a requirement to hold the complete Underworld in memory.

Required semantic fields conceptually:

```text
UnderworldDefinitionIndex
- root_world_id
- root_world_seed / compatible generation context reference
- generator_manifest reference
- seed_schema_version
- underworld_generation_schema_version
- underground_region_addressing configuration
- optional generated-region cache/index metadata
```

### Rules

- The root world seed/`WorldId` scopes deterministic world identity.
- Underworld generation contracts remain separately revisionable inside the compatible manifest.
- World-domain identity is explicit; these addresses are Underworld addresses.
- Lazy regional generation is required.
- Opening a save must not construct every underground network as live runtime state.
- This index does not need an Overworld surface-definition address or a shared coordinate-space reference.

---

## 4. `UndergroundRegionDefinition`

A region is the primary deterministic ownership unit for Underworld topology generation.

Required semantic fields:

```text
UndergroundRegionDefinition
- stable_id
- stable_address
- region_coord
- underworld_local_bounds / anchor
- dominant_profile_bias / profile data
- network_ids
- entry_site_ids
- secondary_edge_ids owned by this region
- special_location_hook_ids
- topology metrics / validation metadata
```

A region coordinate/address is a generation partition. It is not required to equal a runtime streaming cell and has no mandatory relationship to Overworld coordinates.

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
- entry_path_edge_ids
- attached_entry_site_ids
- topology metrics
```

### Network identity rule — LOCKED

A secondary connector linking Network A and Network B does **not** merge their identities.

```text
Network A remains A
Network B remains B
Secondary Edge X connects nodes from A and B
```

This prevents persistent IDs from changing when topology gains a useful loop/reconnection.

Entry-anchor nodes belong to existing networks; their edges may be classified separately from the original primary tree.

---

## 6. `CaveNodeDefinition`

A node represents an abstract important Underworld volume before detailed geometry is produced.

Required semantic fields:

```text
CaveNodeDefinition
- stable_id
- stable_address
- owning_network_id
- underworld_local_position
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
entry_anchor
```

These are generation semantics, not final gameplay classes.

### Profile blend — LOCKED

Nodes carry continuous shallow/mid/deep weights, conceptually:

```text
profile_blend = [shallow, mid, deep]
```

Weights are normalized/canonical for deterministic serialization.

Depth/profile is an **Underworld-local grammar**. It does not encode literal meters below the Overworld surface.

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
- geometry-tendency parameters / geometry-description address
- optional tags
```

Connection classes may include:

```text
primary
vertical_transition
entry_path
proximity_connection
deliberate_loop
cross_region_connection
```

The class describes why an edge exists, not a fixed mesh shape.

### Endpoint canonicalization

Semantically undirected edges use canonical endpoint ordering so:

```text
A-B == B-A
```

cannot become two persistent connector identities.

---

## 8. `UnderworldEntrySiteDefinition` — LOCKED TARGET SEMANTICS

An entry site is a stable **Underworld-domain** world-definition object. It is not a physical surface-to-underground bridge and it does not carry an authoritative Overworld coordinate.

Required semantic fields conceptually:

```text
UnderworldEntrySiteDefinition
- stable_id
- stable_address
- owning_region_id
- connected_network_id
- connected_node_id
- underworld_local_anchor / transform
- entry_kind / arrival_profile
- local clearance / geometry requirements
- semantic tags / gateway compatibility metadata
- generation metadata
```

Potential local profiles include:

```text
cavern_arrival
shaft_arrival
constructed_descent_end
crevice_arrival
ancient_portal_site
```

The exact roster remains open.

### Cross-domain relationship

A separate gateway architecture owns the mapping:

```text
WorldGatewayDefinition
- stable gateway identity
- source domain
- source gateway/site identity
- destination domain
- destination entry-site/arrival identity
- directionality / return policy
```

The Underworld graph does not know the Overworld source transform and does not convert coordinates between domains.

### Legacy `EntranceDefinition` compatibility

Accepted production code and deterministic identities may still use names/StableAddresses such as `EntranceDefinition`, `entrance(slot-N)` and historical `ug.entrance.*` seed domains.

Those existing identities/domains must not be silently renamed or repurposed if doing so breaks deterministic compatibility.

During migration:

- existing `EntranceDefinition` may act as the implementation representation of an Underworld entry site;
- historical fields such as surface position/integration data are legacy compatibility data, not new cross-domain authority;
- new gateway-link randomness/identity uses new semantic contracts/domains rather than changing the meaning of old persistent domains;
- future schema revision may rename the type through an explicit generator migration if justified.

### Entry-site count

A tendency such as roughly 1–3 useful entry sites for suitable regions/networks may remain a generation policy. It does not imply 1–3 physical Overworld holes or coordinate-matched openings.

---

## 9. Secondary connection model

Secondary connections happen **after** primary topology exists.

Conceptual transient candidate:

```text
ConnectionCandidate
- endpoint_a
- endpoint_b
- canonical candidate address
- underworld-local physical distance
- topology gain
- depth/profile usefulness
- entry/network usefulness
- redundancy penalty
- estimated connector cost
- score
```

`ConnectionCandidate` is transient analysis data and does not become world truth unless accepted.

Accepted candidates become stable `CaveEdgeDefinition` values.

Random score/acceptance terms derive from candidate address + secondary-connectivity seed domains, not enumeration order.

---

## 10. Cross-region connections

Underworld networks may cross macro-region boundaries.

Cross-region connections have exactly one deterministic owner.

Conceptual ownership:

```text
owner = deterministic canonical region key
```

or another explicit canonical function.

Requirements:

- generating A before B or B before A yields the same connection identity;
- no duplicate connectors because both regions think they own the edge;
- canonical ordered region/endpoint keys precede StableId and seed derivation;
- neighbor-region metadata can be generated as pure data without runtime geometry;
- cross-region means **within the Underworld domain**. It does not mean cross-world-domain travel.

---

## 11. `SpecialLocationHookDefinition`

Topology supports future special content without implementing it.

Required semantic fields conceptually:

```text
SpecialLocationHookDefinition
- stable_id
- stable_address
- owning_region_id
- anchor_node_id / edge_id / free Underworld-local anchor
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

The hook reserves/identifies domain-local space. Later content/gameplay systems decide what to realize there.

---

## 12. Topology is not geometry

The graph schema describes connectivity and approximate spatial intent; it does not contain final triangles.

```text
CaveNodeDefinition
CaveEdgeDefinition
UnderworldEntrySiteDefinition
        |
        v
GeometryDescription
        |
        +-- chamber volumes
        +-- tunnel centerline/control points
        +-- entry-site local geometry
        +-- cross-section parameters
        +-- structural bedrock classification
        +-- optional modifiable-material volumes
        |
        v
Runtime meshes/collision
```

A geometry algorithm may change without redesigning topology.

Topology randomness and detailed geometry randomness use separate seed domains.

No geometry stage is required to join an Underworld mesh continuously to an Overworld mesh.

---

## 13. Runtime streaming cells are separate

Runtime streaming cells partition expensive instantiated Underworld content.

They are not necessarily the same size/shape as:

```text
macro Underworld regions
cave networks
Overworld chunks
```

One cave network may pass through multiple runtime cells; one runtime cell may contain fragments from several networks.

Stable world objects keep graph identity regardless of runtime-cell assignment.

The active world-domain lifecycle is owned above this schema; runtime-cell addresses do not decide which world domain the Player occupies.

---

## 14. Finalized definitions are immutable-by-convention — LOCKED

Generation stages may use mutable builders while constructing a region.

Once finalized/validated, deterministic Underworld definitions are immutable for that compatible generation contract.

Gameplay does not mutate the graph definition directly.

```text
generated definition + saved durable delta = current realized state
```

Examples:

```text
collapsed edge exists in definition
save delta says collapse was cleared

ore site exists in definition
save delta says resource was depleted
```

This keeps regeneration and persistence cleanly separated.

---

## 15. Canonical serialization/debug representation

Requirements:

- sort objects by stable ID/address;
- canonical endpoint ordering;
- canonical normalized profile weights;
- explicit field order in fingerprints/debug serialization;
- do not rely on dictionary iteration order;
- do not serialize runtime Node/instance identity;
- deterministic numeric policy where floats enter fingerprints;
- domain ownership is explicit in diagnostic context rather than inferred from coordinates.

This supports repeatable tests across generation order and worker scheduling.

---

## 16. Required graph invariants

Headless validation should assert at least:

1. every ID in one ownership scope is unique;
2. every edge endpoint references an existing node;
3. every node references an existing owning network;
4. every entry site references an existing target network/node;
5. primary networks satisfy their reachability contract;
6. no prohibited self-edge exists;
7. duplicate undirected edges are absent unless explicitly allowed;
8. secondary connectors obey profile connectivity caps;
9. cross-region edges have exactly one canonical owner;
10. profile weights are valid/normalized;
11. Underworld-local positions/bounds are finite;
12. canonical serialization is repeatable;
13. identical StableAddresses/domain contracts derive identical deterministic randomness independent of generation order;
14. no graph invariant requires an Overworld coordinate or shared-Y relationship;
15. gateway mappings reference valid destination entry-site identity through the gateway layer without mutating graph identity.

A failure report should identify:

```text
root world seed / WorldId
domain = UNDERWORLD
generator/seed-schema version
region ID
network ID if applicable
object ID/address if applicable
seed domain/revision if randomness is involved
invariant violated
```

---

## 17. Initial implementation/class direction

Exact filenames are not locked, and accepted historical names may remain during migration.

Conceptually:

```text
worldgen/
    identity/
        stable_address.gd
        stable_id.gd
    pipeline/
        seed_domains.gd
        seed_deriver.gd
        deterministic_rng.gd
        underworld_definition_index.gd
        underground_region_definition.gd
        cave_network_definition.gd
        cave_node_definition.gd
        cave_edge_definition.gd
        underworld_entry_site_definition.gd   # target semantic name
        special_location_hook_definition.gd
```

An existing `entrance_definition.gd` may remain while it implements the compatible entry-site semantics. Architecture does not require a rename-only migration.

---

## 18. What remains open

This schema intentionally does not lock:

- exact Underworld region size;
- runtime streaming-cell dimensions;
- chamber-shape representation;
- spline/tunnel representation;
- numerical shallow/mid/deep curves;
- exact entry-site generation algorithm;
- gateway source/destination matching policy beyond deterministic identity contracts;
- secondary-connection scoring weights;
- geometry meshing algorithm;
- binary/string StableId encoding;
- low-level seed hash/PRNG below `DETERMINISTIC_SEED_DOMAINS.md`.

These choices may evolve without weakening the semantic boundaries above.

## 19. Supersession note

Earlier revisions defined `EntranceDefinition` as a deterministic **surface-to-underground** object containing surface position, shared-world depth and physical surface-integration parameters. Those cross-domain/shared-coordinate semantics are superseded by ADR-001 and the 2026-08-31 two-domain decision.

Still-valid historical work remains valid where it describes deterministic Underworld topology, entry candidate identity, network attachment, stable IDs, connectivity and domain-local geometry.