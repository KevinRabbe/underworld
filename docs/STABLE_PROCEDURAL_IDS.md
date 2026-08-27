# Underworld — Stable Procedural ID Architecture

## Status

This document defines how deterministic generated world objects are addressed so persistence does not depend on array position, generation order, thread scheduling or runtime scene-node identity.

The architecture is **LOCKED**. Exact text/binary encoding may change later, but the semantic address of an object must remain based on stable generation coordinates/slots rather than on the order in which accepted objects were appended.

The core rule is:

> **Identity belongs to a deterministic generation candidate/address, not to the object's current array index, runtime node, mesh instance, or RNG call order.**

---

## 1. Why the current prototype ID is unsafe

The current surface prototype creates IDs equivalent to:

```text
chunk_x : chunk_z : object_type : accepted_array_index
```

For example:

```text
2:-1:tree:7
```

This is sufficient for a short prototype but not for a persistent procedural world.

Trees, rocks, branches and loose stones are currently appended only after a candidate passes generation rules. If density, thresholds, rejection logic or generation order changes, the object that used to be accepted-array index `7` may become index `6`, `8`, or disappear entirely.

A save could then apply an old destruction delta to the wrong object.

This architecture removes accepted-array position from persistent identity.

---

## 2. Identity layers

Use three related concepts and do not collapse them.

### 2.1 `WorldId`

Identifies one generated world instance/seed scope.

Semantic inputs:

```text
world seed
world-generation family/version where required
```

A save file already belongs to one world seed, so individual persisted object IDs do not need to repeat the world seed in every string.

When a reference leaves that save/world scope — global cache, diagnostics, multiplayer/world-transfer tooling, etc. — use the pair:

```text
(WorldId, StableId)
```

### 2.2 `StableAddress`

The canonical semantic address that explains **where in deterministic generation space this identity comes from**.

Examples:

```text
surface / tree-candidates / cell(120,-44) / slot(tree)
underground / region(4,-2) / network(slot-3) / node(root/branch-2/slot-1)
underground / region(4,-2) / entrance(slot-1)
underground / region(4,-2) / special(ore-deposit, slot-6)
```

The exact string syntax is not important. The semantic components are.

### 2.3 `StableId`

The value stored/referenced by generated definitions and save deltas.

The first implementation should use a canonical readable `String` produced only by a central ID builder. A compact hash/binary representation may be introduced later if profiling justifies it.

Gameplay/generator code must not manually concatenate ad-hoc ID strings.

---

## 3. Stable-ID invariants — LOCKED

For a compatible generator version, all persistent procedural IDs must satisfy these invariants:

1. Same world seed + same stable generation address = same ID.
2. Load order does not affect the ID.
3. Worker-thread scheduling does not affect the ID.
4. Runtime creation/destruction order does not affect the ID.
5. MultiMesh instance index does not affect the ID.
6. Dictionary/array iteration order does not affect the ID.
7. Rejected sibling candidates do not renumber accepted siblings.
8. Changing an unrelated system must not rename an object merely because it consumed a different number of RNG calls.
9. A secondary cave connection must not rename the networks/nodes it connects.
10. Cross-region generated objects have exactly one canonical deterministic owner/address.

A change that necessarily violates these invariants for existing world content is a **generator compatibility boundary** and must be handled through generator versioning/migration rather than silently reusing old deltas.

---

## 4. Candidate-address principle

The most important implementation pattern is to identify the **candidate slot before deciding whether an object exists**.

Wrong:

```text
accepted trees = []
if candidate passes:
    accepted trees.append(tree)
ID = accepted-tree-array-index
```

Correct:

```text
candidate address = deterministic cell + semantic slot
candidate RNG = derive(world_seed, candidate address, generation domain)
if candidate passes:
    object ID = ID(candidate address)
```

If an earlier candidate stops spawning after a density change, later candidates keep their own addresses.

---

## 5. Surface procedural-object addressing

### 5.1 Global candidate cells — LOCKED DIRECTION

Surface persistent objects should be addressed from a deterministic **global candidate lattice/domain**, not from a compact accepted-object array.

Conceptual address:

```text
surface / <candidate-domain> / cell(<global_cell_x>,<global_cell_z>) / <slot-key>
```

Examples:

```text
surface/tree/cell(401,-73)/slot-0
surface/rock/cell(401,-73)/slot-0
surface/branch/cell(812,-146)/slot-0
surface/loose-stone/cell(812,-146)/slot-0
```

Tree/rock and loose-pickup candidate lattices may have different spacing/domains. Their address domains therefore remain separate.

### 5.2 Chunk independence

Chunks are streaming/storage boundaries, not the fundamental identity of the object.

The implementation may derive global candidate coordinates from current chunk-local generation cells, but the persisted identity should resolve to a canonical global candidate address.

That prevents a future chunk-management refactor from being conceptually confused with object identity.

Changing the actual candidate lattice definition/spacing may still be a generator compatibility boundary; it is not expected that arbitrary generator rewrites preserve old worlds automatically.

### 5.3 Multiple candidates in one cell

If a generation domain can create more than one same-kind persistent object per candidate cell, use named/fixed candidate slots:

```text
slot-0
slot-1
slot-2
```

or semantic slot keys.

Slots exist before acceptance. Never assign slots by compacting only accepted objects.

---

## 6. Underground hierarchy addressing

Underground IDs follow deterministic ownership and generation lineage.

Conceptually:

```text
region
  -> network candidate slot
      -> node candidate lineage/slot
      -> primary edge candidate slot
  -> entrance candidate slot
  -> secondary connector candidate
  -> special-location candidate slot
```

### 6.1 Region

```text
underground / region(<region_x>,<region_z>[,<region_y-if-ever-needed>])
```

The exact region dimensions remain open, but region coordinates are canonical generation coordinates once the generator version is defined.

### 6.2 Network

A network ID is based on a fixed network candidate slot within its owning region:

```text
region(...) / network(slot-N)
```

It is **not** `network index in accepted_networks`.

Rejected network candidates do not renumber later candidate slots.

### 6.3 Nodes

Node identity is based on deterministic generation lineage/candidate slots, not final sorted position.

Conceptual examples:

```text
network(slot-2) / node(root)
network(slot-2) / node(root/branch-slot-1)
network(slot-2) / node(root/branch-slot-1/branch-slot-3)
```

A generator may use another fixed candidate-key model, but accepted sibling count may not define the identity.

### 6.4 Primary edges

A primary edge can be addressed canonically from its generation relationship, for example:

```text
network(slot-2) / edge(primary, parent-node-id, child-candidate-slot)
```

Endpoint order must be canonical when the edge is semantically undirected.

### 6.5 Entrances

Entrances are stable candidate objects owned by a region/network generation address:

```text
region(...) / entrance(slot-N)
```

Their connected node/depth may be generated properties, but changing iteration order must not rename the entrance candidate.

### 6.6 Secondary/proximity/loop connectors

Secondary connections need their own deterministic candidate address.

The candidate key should be based on canonical endpoints plus connector class/domain and, where needed, a fixed candidate slot:

```text
secondary-edge(
    min(endpoint-A-id, endpoint-B-id),
    max(endpoint-A-id, endpoint-B-id),
    connector-class,
    slot-N
)
```

This prevents `A -> B` and `B -> A` from becoming two identities.

For cross-region connections, ownership follows the canonical-owner rule defined in `UNDERWORLD_GRAPH_SCHEMA.md`. The same pair of regions/endpoints must resolve to one owner regardless of which region is generated first.

### 6.7 Special-location hooks

Future generated structures, boss lairs, huge ore bodies, ruins, collapses and similar persistent locations use reserved stable candidate slots:

```text
region(...) / special(<kind>, slot-N)
```

or, when naturally attached to topology:

```text
node-id / special(<kind>, slot-N)
edge-id / special(<kind>, slot-N)
```

Their gameplay system may not exist yet; the identity can still be reserved deterministically.

---

## 7. Generated child objects

A persistent generated object created inside another stable world object derives its address from the stable parent plus a fixed local candidate key.

Examples:

```text
large-deposit-id / exposed-chunk(slot-4)
ruin-id / container(slot-storage-east)
chamber-id / rubble(slot-2)
```

Do not derive child IDs from runtime child-node order.

If a child is purely visual/transient and can be regenerated without any saved state, it does not require a persistent stable ID.

---

## 8. Identity is not position

World position may be included in diagnostics, but floating-point position alone is not the persistent identity.

Reasons:

- terrain/geometry algorithms may move an object slightly while it remains conceptually the same candidate;
- float formatting can vary;
- nearby distinct objects can require separate identities;
- topology objects have semantic relationships that are stronger than raw coordinates.

Use integer/categorical generation addresses for identity. Position is generated data belonging to that identity.

---

## 9. Identity is not RNG state

IDs must not depend on mutable/random-generator state such as "the 57th random number consumed."

The preferred dependency direction is:

```text
StableAddress
     |
     +--> StableId
     |
     +--> deterministic derived RNG seed for a named generation domain
```

not:

```text
shared RNG sequence -> object exists -> assign next ID
```

The detailed seed-domain/hash design is specified in the next architecture document.

---

## 10. String representation — DIRECTIONAL

For the first implementation, readable strings are preferred because they make failed seeds and save files inspectable.

Conceptual examples only:

```text
sid1/surface/tree/cx/401/cz/-73/slot/0
sid1/ug/region/4/-2/network/3/node/root.b1.s3
sid1/ug/region/4/-2/entrance/1
```

Rules:

- one central builder/parser owns canonical encoding;
- components use restricted/canonical representations;
- no locale-dependent number formatting;
- no floats in identity components;
- no manual string concatenation throughout gameplay code;
- canonical ordering for unordered endpoint pairs;
- version prefix is recommended.

A later implementation may store a 128/256-bit digest internally while retaining a readable debug address, but this is not required now.

---

## 11. Runtime lookup

Runtime systems may map stable IDs to transient indexes for efficiency:

```text
stable_id -> MultiMesh instance index
stable_id -> active StaticBody3D
stable_id -> loaded cave runtime object
```

Those mappings are caches only.

The persistent save references the stable ID, never the transient runtime index.

When a MultiMesh is rebuilt after objects disappear, instance indexes may change freely without affecting persistence.

---

## 12. Persistence contract

Persistent world deltas reference stable IDs.

Examples:

```text
destroyed_objects[StableId]
cleared_collapses[StableId]
special_location_state[StableId]
modified_deposits[StableId]
```

The save system must also store enough version information to know whether those IDs can be resolved safely:

```text
save_version
generator_version
world_seed / WorldId
```

Generator-version behavior is specified separately, but one rule is locked here:

> Never silently reinterpret an old stable ID under an incompatible generator as a different object.

---

## 13. Migration from prototype save version 2

### 13.1 Current legacy state

Prototype v2 saves store:

```text
version = 2
world_seed
destroyed_objects = ["chunk_x:chunk_z:type:index", ...]
```

They do not record a generator version.

Treat them as a known legacy generation contract, conceptually:

```text
legacy_surface_v2
```

### 13.2 One-time migration strategy — LOCKED DIRECTION

Before changing the current surface candidate-generation algorithm in a way that destroys the mapping, implement a one-time migration adapter:

1. Read each legacy destroyed-object ID.
2. Parse `chunk_x`, `chunk_z`, `object_type`, `accepted_index`.
3. Regenerate only the referenced legacy chunk/type with the **frozen legacy v2 algorithm/parameters**.
4. During that legacy generation pass, record the deterministic candidate address for each accepted object.
5. Resolve the old accepted index to that candidate address.
6. Convert it to the new `StableId`.
7. Write the upgraded save using the new save/generator version.
8. Keep unresolved legacy IDs out of normal gameplay state and report them explicitly rather than applying them to the wrong object.

This migration must be tested with known old saves before the legacy adapter is removed.

### 13.3 Why we must migrate before density tuning

The current accepted-index mapping can still be reconstructed because the old algorithm is present today.

If we first change tree/rock/pickup densities, candidate stepping, RNG consumption or rejection rules and only then attempt migration, the old `index` may no longer resolve reliably.

Therefore:

> **Legacy v2 ID migration is an implementation prerequisite before incompatible surface-decoration generation tuning.**

### 13.4 Migration scope

This is a prototype migration, not a promise that every future generator version can transform every old world perfectly.

Future compatibility boundaries may choose between:

- deterministic migration;
- retaining a legacy generator for existing worlds;
- explicit world upgrade/re-generation rules;
- rejecting incompatible deltas with a clear diagnostic.

The versioning policy will define that choice.

---

## 14. Validation requirements

Automated tests must validate at least:

1. generating the same candidate twice returns the same stable ID;
2. generation in different chunk/region order returns the same IDs;
3. accepted-object array order is irrelevant;
4. removing/rejecting one candidate does not rename sibling candidate IDs;
5. cross-region connector ownership produces one ID from either generation direction;
6. endpoint canonicalization makes A-B equal to B-A for undirected connector identity;
7. no duplicate stable IDs exist inside a generated world-definition scope;
8. canonical serialization sorted by stable ID is repeatable;
9. legacy v2 IDs migrate to the expected new IDs for fixture saves.

A failure report should include:

```text
world seed
generator version
stable-address domain
candidate address / involved endpoints
expected ID
actual ID
```

---

## 15. What is intentionally still open

The following are **OPEN** until implementation/profiling makes a concrete choice useful:

- exact textual punctuation/encoding of stable IDs;
- whether release builds eventually store readable strings, hashes, or both;
- exact global surface candidate-lattice spacing/domain versioning;
- exact underground region dimensions;
- exact node-lineage key representation;
- exact hash function used to derive local RNG seeds from stable addresses.

These choices may change without violating this architecture as long as the semantic stable address and invariants remain intact.
