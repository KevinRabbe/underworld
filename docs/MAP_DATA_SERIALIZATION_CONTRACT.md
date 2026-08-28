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

`world_seed` is serialized as a **canonical signed decimal string**, not a JSON number. The runtime seed remains a signed 64-bit integer; the string wire representation prevents JavaScript and other IEEE-754-based JSON consumers from silently rounding seeds above `2^53`.

Validation requires:

- `world_seed` is a canonical decimal representation of a signed 64-bit integer;
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

## Canonical JSON and numeric types

`MapDataSerializationContract` emits compact canonical JSON with dictionary keys sorted recursively. Equivalent logical state therefore produces byte-identical JSON independent of dictionary insertion order.

Godot 4.7 parses ordinary JSON numbers as floating-point values. Durable state can legitimately distinguish an integer from a float, so the wire format must not silently turn `2` into `2.0` on load.

Logical integer values inside `deltas` therefore use a type-preserving wire tag:

```json
{"$underworld_int64":"2"}
```

The value is a canonical signed decimal string. Decode restores the tag to a native Godot `int` before the envelope is exposed to persistence consumers. Native logical floats remain ordinary JSON numbers. The reserved `$underworld_int64` key is rejected in logical delta dictionaries so user state cannot be confused with the wire encoding.

Logical floats must be finite. `NaN`, positive infinity, and negative infinity are rejected recursively before wire conversion, with a diagnostic that identifies the exact delta path. This prevents implementation-specific non-JSON numeric tokens from entering canonical save data.

`save_schema_version` remains a normal readable JSON number because its type is fixed by the schema; decode normalizes an exact integral JSON number back to a native integer before validation.

Only JSON-safe logical values are accepted in the serialized delta payload:

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

Identity-critical values that may exceed interoperable JSON numeric precision should use explicit textual wire representations, as `world_seed` does.

## Decode / load boundary

Decode is intentionally staged:

```text
JSON text
  -> parse wire representation
  -> restore typed delta integers
  -> normalize schema-version type
  -> validate schema + world identity
  -> validated logical envelope
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
- signed 64-bit seed preservation through JSON beyond the `2^53` interoperability boundary;
- native integer delta types surviving JSON round-trip;
- fractional and whole-valued native floats surviving as `TYPE_FLOAT`;
- recursive rejection of non-finite floats with exact delta paths;
- reserved integer wire-tag collisions and malformed wire tags;
- positive and negative signed 64-bit seed extrema;
- byte-identical canonical JSON for equivalent state with different insertion order;
- `WorldDeltaStore` reload;
- corrupt WorldId and seed mismatch rejection;
- non-canonical decimal seed rejection;
- generator manifest fingerprint mismatch rejection;
- unsupported schema rejection;
- rejection of unexpected topology fields;
- rejection of non-JSON runtime Variant values.
