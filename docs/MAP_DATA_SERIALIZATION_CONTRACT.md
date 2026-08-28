# Underworld — Map Data Serialization Contract

## Status

Task: `MAP-008`

This contract implements the first executable serialization boundary for generated-world persistence. It follows the locked persistence architecture in `PERSISTENCE_AND_VERSIONING.md`:

> Untouched deterministic world definitions are regenerated. Saves persist the deterministic generation identity plus durable player/world deltas.

A save therefore does **not** contain a visited cave graph, chamber mesh, tunnel list, generated terrain snapshot, or other complete copy of procedural world truth.

## Schema

Current executable schema:

```text
underworld-map-save-v3
save_schema_version = 3
```

The envelope contains exactly three semantic sections plus the schema version:

```text
schema
save_schema_version
world
deltas
```

### `world`

The world header pins the deterministic contract required to interpret the deltas:

```text
world_seed
generator_manifest_id
generator_manifest_canonical
world_id
```

Validation requires:

- the `WorldId` is syntactically valid;
- the `WorldId` matches the serialized world seed;
- the manifest canonical text uses the supported manifest schema prefix;
- `generator_manifest_id` equals the SHA-256 identity of the serialized canonical manifest contract.

A corrupt or mismatched identity is rejected. The loader must not silently substitute current generator defaults.

### `deltas`

The current durable generated-world delta categories are:

```text
destroyed_objects
object_state
special_location_state
terrain_delta_index
player_created_objects
```

They match the logical `WorldDeltaStore` boundary. This schema defines their envelope and round-trip behavior; it does not define the eventual binary terrain-delta format or player-created object identity policy.

## Canonical JSON

`MapDataSerializationContract` emits compact canonical JSON with dictionary keys sorted recursively. Equivalent logical state therefore produces byte-identical JSON independent of dictionary insertion order.

Only JSON-safe values are accepted in the serialized delta payload:

```text
null
bool
int
float
string
array
dictionary with string keys
```

Runtime-only Variant values such as `Vector3`, scene objects, resources, nodes, and callables are rejected rather than serialized ambiguously.

## Decode / load boundary

Decode is intentionally staged:

```text
JSON text
  -> parse
  -> validate schema + world identity
  -> validated envelope
  -> load delta payload into WorldDeltaStore
```

The contract does not instantiate cave topology from serialized data because untouched topology is not durable save state. Runtime generation recreates the deterministic baseline from the pinned world/generator contract, then applies the validated deltas.

## Compatibility behavior

This implementation supports exactly `save_schema_version = 3` and schema name `underworld-map-save-v3`.

Unknown newer/older versions are rejected explicitly. Migration policy belongs to explicit migration adapters, not permissive parsing.

## Out of scope

- full save transaction / atomic file replacement;
- player inventory/progression serialization;
- terrain deformation binary representation;
- physical save sharding;
- autosave scheduling/UI;
- generator migration implementation;
- serializing generated cave/terrain definitions as durable save state.

## Validation

`tests/persistence/test_map_data_serialization_contract.gd` covers:

- world header and delta round-trip;
- large integer seed preservation through JSON;
- byte-identical canonical JSON for equivalent state with different insertion order;
- `WorldDeltaStore` reload;
- corrupt WorldId and seed mismatch rejection;
- generator manifest fingerprint mismatch rejection;
- unsupported schema rejection;
- rejection of unexpected topology fields;
- rejection of non-JSON runtime Variant values.
