# Underworld — Persistence and Generator Versioning Architecture

## Status

This document defines how saves reference deterministic generated world truth, how player-caused deltas survive streaming, and how generator changes are classified/migrated without silently applying old state to the wrong world objects.

The compatibility boundaries are **LOCKED at the architectural level**. Exact file format, compression and long-term legacy-support policy remain implementation/product decisions.

Core rule:

> **A save stores player/world-state deltas against an explicitly identified deterministic generation contract. It never silently assumes that today's generator is equivalent to the generator that created the save.**

---

## 1. What is saved versus regenerated — LOCKED

### Regenerated from deterministic world contracts

```text
untouched surface terrain
untouched cave topology
untouched cave base geometry
untouched procedural object placement
untouched entrances
untouched special-location hooks
other untouched deterministic world definitions
```

### Saved as durable player/world state

```text
player inventory/progression state
harvested/removed generated object IDs
partial persistent object state where required
cleared collapses/changed special locations
terrain/deformation deltas
player-built structures
other explicit player-caused or persistent simulation state
```

Do not serialize entire visited cave networks merely because the player loaded them once.

---

## 2. Logical persistence owner — `WorldDeltaStore`

`WorldDeltaStore` is the single logical authority for persistent generated-world modifications.

Conceptual responsibilities:

```text
load/validate save payload
expose read-only bounded delta views
apply explicit world-state mutations
track dirty shards/categories
serialize atomically/safely
run schema/generator migrations
quarantine unresolved references
```

Runtime chunks/cells may cache/query deltas but do not own durable state.

---

## 3. Version concepts must remain separate

Do not overload one integer called `version` to mean everything.

### 3.1 `save_schema_version`

Describes the serialized save layout.

Examples of changes:

```text
rename JSON fields
split one state map into two
change how tools/inventory are represented
add physical save shards/indexes
```

A save-schema migration can occur without changing the generated world.

### 3.2 `seed_schema_version`

Defined in `DETERMINISTIC_SEED_DOMAINS.md`.

Describes the fundamental canonical seed-derivation encoding/hash contract.

Changes should be rare and are major world-generation compatibility events.

### 3.3 `stable_address_schema_version`

Describes the canonical persistent stable-address/ID encoding semantics where a version distinction is required.

A readable StableId format may evolve without changing semantic identity if migration is lossless; an incompatible semantic address change is a generator compatibility boundary.

### 3.4 `generator_manifest`

Identifies the complete deterministic generation contract for one world.

It is not merely a random salt.

The manifest pins the revisions/configuration required to reproduce world truth.

---

## 4. `GeneratorManifest` — LOCKED DIRECTION

Conceptual content:

```text
GeneratorManifest
- manifest_schema_version
- manifest_id / canonical fingerprint
- seed_schema_version
- stable_address_schema_version
- stage revisions
- seed-domain IDs + revisions used by persistent generation
- depth/profile/config revisions
- surface generation contract revision(s)
- Underworld generation contract revision(s)
- persistent noise/algorithm/config revision references
- other deterministic-generation dependencies required for reproduction
```

### Important rule

The manifest must pin generation **configuration**, not only code labels.

An old world must not silently read today's mutable default generation settings if those settings changed.

Generation parameters/profiles must therefore be either:

1. embedded/snapshotted into the world's immutable generation manifest/config package; or
2. referenced by an immutable versioned config asset/package that remains reproducible.

Exact storage choice remains open.

---

## 5. Manifest identity

A manifest should have a canonical fingerprint/ID derived from its canonical serialized contract description.

Conceptually:

```text
manifest_id = fingerprint(canonical GeneratorManifest)
```

This allows caches, saves and diagnostics to state exactly which deterministic contract they expect.

Do not derive world randomness directly from `manifest_id`; domain isolation rules still apply.

---

## 6. World metadata

Every modern save/world should record enough immutable metadata to identify its generated baseline.

Conceptually:

```text
WorldSaveHeader
- save_schema_version
- world_seed
- world_id
- generator_manifest_id
- generator manifest/config snapshot or resolvable reference
- creation metadata if useful (non-generation)
```

Creation timestamp may be stored for UI but is never generation entropy.

---

## 7. Delta categories

The physical format may change, but conceptually separate state by semantics.

### Generated-object deltas

```text
destroyed_objects : Set<StableId>
object_state       : Map<StableId, state>
```

Examples:

```text
harvested tree/rock
partially mined persistent deposit
opened/changed generated container
```

### Special-location deltas

```text
special_location_state : Map<StableId, state>
```

### Terrain/material deltas

Spatially addressable modifications relative to deterministic base geometry/surface.

Exact representation is open.

### Player-created objects

Player-built objects are not procedural candidate identities.

They need a separate persistent user-created identity scheme (save-scoped ID/UUID/monotonic identity or equivalent) when the building system is designed.

Do not pretend a player-created wall has a procedural `StableAddress` merely because it exists in the world.

---

## 8. Logical store may be physically sharded — DIRECTIONAL

The current prototype uses one small JSON file. That is acceptable now.

A long-lived world may eventually need physical sharding/indexing such as:

```text
save header/index
player state
region/cell delta shards
construction shards
special-state shards
```

The architecture should expose one logical `WorldDeltaStore` regardless of physical layout.

Runtime systems should not know/care whether data came from one JSON file or 500 region shards.

---

## 9. Spatial delta queries

As modifications grow, runtime streaming should not scan the complete world save for every cell.

The store should eventually support conceptually:

```text
query(bounds, stable IDs/categories)
    -> read-only WorldDeltaView
```

The exact spatial index is open.

Generated-object StableIds can additionally map to owning region/candidate address for efficient lookup through central metadata/indexing.

---

## 10. Compatibility states — LOCKED

Opening a save must classify generation compatibility explicitly.

Conceptual states:

```text
EXACT
    current implementation can reproduce the pinned manifest exactly

SUPPORTED_LEGACY
    old manifest remains intentionally supported/reproducible

MIGRATION_REQUIRED
    deterministic/explicit migration path exists

INCOMPATIBLE
    no safe automatic mapping exists

UNKNOWN/CORRUPT
    header/manifest/state cannot be trusted
```

Never treat `INCOMPATIBLE` or unknown as `EXACT` by silently running the newest generator.

---

## 11. Compatible refactors

A code refactor that provably preserves deterministic outputs does not need a generation revision change.

Requirements:

```text
seed/RNG test vectors unchanged
representative stage/world fingerprints unchanged
stable IDs unchanged
migration fixtures unchanged
```

If output changes unexpectedly, the tests should expose that before release.

---

## 12. Intentional local generator changes

Example:

```text
tree shape distribution changes
```

Possible contract changes:

```text
SURFACE_TREE_SHAPE domain revision increments
relevant stage/config revision increments if required
new GeneratorManifest produced for new worlds/upgraded worlds
```

Unrelated cave topology domain revisions remain untouched.

Whether old worlds adopt the local change automatically is a compatibility-policy decision, not a side effect of launching a new game binary.

---

## 13. Fundamental generator changes

Examples:

```text
stable candidate lattice semantics change
node-address lineage semantics change
seed-schema algorithm replaced
old noise algorithm no longer reproducible
major cave topology rewrite invalidates existing persistent references
```

These create a significant compatibility boundary.

Available strategies may include:

```text
retain legacy generator contract for existing worlds
explicit deterministic world migration
explicit selective regeneration with mapped deltas
require new world / mark incompatible
```

The architecture does not promise that arbitrary future world generators can transform every old save perfectly.

It does promise that incompatibility is explicit rather than silent corruption.

---

## 14. Migration pipeline — LOCKED DIRECTION

Migration is staged and transactional conceptually:

```text
1. parse/validate old save envelope
2. identify old save schema + generator contract
3. migrate serialized schema to a readable canonical intermediate
4. resolve generation compatibility
5. run required stable-ID/world-delta migration adapters
6. validate migrated references/state
7. serialize a new save under the new schema/manifest
8. only then replace/activate the upgraded save
```

Do not partially mutate the only known-good save in place while migration is still running.

---

## 15. Prototype v2 save migration — LOCKED IMPLEMENTATION ORDER

Current prototype saves contain conceptually:

```text
version = 2
world_seed
destroyed_objects = [chunk_x:chunk_z:type:accepted_index]
wood
stone
stone_axe
stone_pickaxe
selected_slot
```

They have no generator manifest.

Treat `version=2` as a known explicit legacy contract, not as "whatever the current generator does."

### Safer migration sequence

Before incompatible surface generation changes:

1. freeze/reference the current legacy-v2 surface decoration/pickup generation behavior;
2. regenerate referenced legacy candidate sets;
3. map accepted indexes to semantic candidate addresses;
4. assign modern StableIds;
5. write a new save schema/header with an explicit generation contract;
6. initially preserve legacy surface generation output where necessary so the migrated IDs still refer to the same world objects;
7. only later introduce new surface seed-domain generation as an explicit generator-contract change/migration/new-world policy.

This avoids successfully converting an old ID only to immediately generate a different candidate population underneath it.

### Underworld generation

The new Underworld generator has no old production topology to preserve and can adopt the stable-ID/seed-domain architecture from its first implementation.

---

## 16. Unresolved references

If a migration or compatible load expects a stable generated object that cannot be resolved:

```text
do not apply the delta to a nearby/different object
do not guess by nearest position
record diagnostic/quarantined unresolved state
```

For a supposedly exact-compatible manifest, unresolved IDs indicate a generator/persistence bug and should be loud in tests/logs.

---

## 17. Position is not a migration fallback by default

Nearest-world-position matching is dangerous because a different generated object can occupy a similar coordinate.

A migration may use position as one piece of explicit migration evidence only when the migration algorithm is specifically designed/tested for that object type.

Never silently use "closest object" as a generic StableId recovery method.

---

## 18. Terrain/deformation compatibility

Terrain modifications are particularly sensitive because they are spatial changes against a deterministic base surface/geometry.

The future terrain-delta format should retain enough ownership/base-contract context to detect when the underlying base geometry is incompatible.

Conceptually a shard may be associated with:

```text
world/generator manifest
surface/geometry cell address
base geometry fingerprint/revision where useful
```

Exact deformation representation remains open.

Do not blindly apply old excavation bytes to an unrelated newly generated cave mesh.

---

## 19. Cache versioning

Caches are disposable but must not serve data produced by the wrong generation contract.

Cache keys/headers include enough contract identity such as:

```text
WorldId
GeneratorManifest ID
stage revision
region/cell address
dependency fingerprint
```

If incompatible/missing, discard and regenerate cache data.

No migration is required for disposable caches unless doing so is a performance optimization.

---

## 20. Save write safety — LOCKED DIRECTION

A save operation should not destroy the previous valid save if serialization fails halfway.

For a simple single-file implementation, prefer conceptually:

```text
serialize new payload
write temporary file
flush/close
validate enough metadata/checksum if used
atomically/safer replace active save
```

For future multi-file sharding, use an indexed generation/transaction scheme rather than leaving a header pointing to half-written shards.

Exact platform API is implementation detail.

---

## 21. Save migrations require fixtures

Every supported migration path needs known fixture saves checked into test data or generated reproducibly.

For prototype v2, fixtures should cover at least:

```text
no modifications
harvested trees/rocks
collected branches/stones
different/negative chunk coordinates
crafted tool/player resource state
multiple destroyed objects in one chunk
```

Migration test asserts:

```text
old state parsed correctly
expected modern StableIds produced
player resources/tools preserved
no wrong-object deltas introduced
new save round-trips
```

---

## 22. Generator manifest validation

On world load, validate conceptually:

```text
manifest schema supported
seed schema supported
required stage revisions available
required seed-domain revisions available
required generation config/profile snapshot resolvable
required persistent algorithm contracts available
manifest canonical fingerprint matches contents
```

Missing required generation contracts do not silently fall back to current defaults.

---

## 23. Development versus released-world policy

During early prototype development we may intentionally stop supporting obsolete experimental manifests.

That is acceptable if explicit.

Architecture still requires:

```text
identify old contract
state incompatibility/migration decision
never silently reinterpret deltas
```

Before public/stable releases, support windows and migration guarantees should become a product policy.

---

## 24. Exploration state is not generation state

If the game later stores:

```text
map discovery
fog of war
known entrances
player markers
```

those are player-state deltas/metadata.

They do not belong in deterministic cave-generation definitions simply because they reference generated locations.

---

## 25. Runtime modification flow

Conceptually:

```text
player action
    |
    v
runtime validates gameplay action
    |
    v
WorldDeltaStore.apply(delta keyed by StableId/spatial address)
    |
    +--> mark relevant state dirty
    +--> notify/rebuild affected live runtime representation
    |
    v
save transaction later/immediately as policy requires
```

The runtime cell does not become the authoritative save owner.

---

## 26. Persistence invariants

1. Save schema version and generator contract are separately identifiable.
2. Old deltas are never interpreted under an unknown/incompatible generator silently.
3. Untouched deterministic definitions are regenerated rather than serialized as visited world blobs.
4. Persistent generated-object deltas use StableIds.
5. Runtime/cell indexes never enter durable identity.
6. Player-created persistent objects use a separate identity category.
7. Cache eviction/deletion cannot remove durable state.
8. Migration writes do not destroy the only valid old save before success.
9. Exact-compatible worlds reproduce required generation fingerprints.
10. Unresolved IDs are diagnostic/quarantined, not reassigned to a guessed object.

---

## 27. Initial modern save shape — DIRECTIONAL

Conceptual readable prototype form only:

```text
{
  "save_schema_version": 3,
  "world": {
    "world_seed": 123456,
    "world_id": "...",
    "generator_manifest_id": "...",
    "generator_manifest": { ... }
  },
  "player": { ... },
  "deltas": {
    "destroyed_objects": ["StableId", ...],
    "object_state": { ... },
    "special_location_state": { ... },
    "terrain_delta_index": { ... },
    "player_created_objects": { ... }
  }
}
```

Do not treat this exact JSON shape as locked. It illustrates the separation of concerns.

---

## 28. What remains intentionally open

- exact JSON/binary/database save format;
- whether/how saves physically shard by region/cell;
- compression/checksum strategy;
- exact stable player-created-object ID format;
- exact terrain/deformation delta format;
- exact long-term legacy generator retention policy;
- exact autosave cadence/backups UI;
- exact manifest canonical serialization format;
- whether some compatible cosmetic generator revisions are adopted by old worlds automatically.

These can change without weakening the locked rule that deltas are always interpreted against an explicit deterministic generation contract.
