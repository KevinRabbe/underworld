# Underworld — Identity and Naming Conventions

Status: **architecture reference derived from existing authoritative contracts**

This file is a naming/review aid, not a new identity schema. The authoritative contracts linked below win if any summary here conflicts with them.

Core rule:

> Name an identifier for **what it identifies and which subsystem owns it**. Paths, runtime objects, indexes and fingerprints are not interchangeable with logical identity.

## Identity classes

| Identity class | Question answered | Example / direction | Lifetime / owner |
| --- | --- | --- | --- |
| Semantic authored content ID | What authored kind is this? | `item.weapon.iron_sword` | Stable authored definition identity |
| Procedural `StableAddress` | Which deterministic candidate/location/lineage is this? | canonical worldgen address | Deterministic world definition |
| Procedural `StableId` | Which generated procedural candidate/location is this? | `sid1:...` | Persistent generated-world identity |
| Persistent instance ID | Which individually stateful player/gameplay-created copy is this? | future `build_instance_id`, `item_instance_id` | Durable gameplay/save state; exact encoding may remain open |
| Stack state | Which compatible quantity/state is grouped together? | item content ID + quantity | Inventory/container state; often no per-unit ID |
| Presentation definition/role | Which replaceable presentation concept is requested? | `visual.weapon.iron_sword`, animation/audio role | Authored presentation binding |
| Runtime object identity | Which live engine object currently represents this? | `Node`, RID, resource instance | Transient runtime implementation |
| Version/revision | Which contract/schema interprets this data? | `save_schema_version`, `stage_revision` | Compatibility metadata, not object identity |
| Fingerprint | Do canonical contents/dependencies match? | provenance/output/manifest fingerprint | Derived verification/cache identity |
| Address/partition key | Which deterministic/spatial partition is this? | region/cell address | Contract-specific partition identity |
| Handle/index | Which current implementation slot is this? | render handle, pool/array index | Transient acceleration detail |

The [Project Glossary](../00_project/GLOSSARY.md) remains the canonical terminology index.

## 1. Semantic authored definition IDs

Semantic content IDs answer **what kind of authored concept is this?**

Established examples include:

```text
item.resource.wood
item.weapon.iron_sword
creature.underworld.burrower
attack_set.sword.basic
animation_set.humanoid.one_handed_sword
visual.weapon.iron_sword
recipe.weapon.iron_sword
```

Use names such as:

```text
content_id
item_definition_id
recipe_id
attack_set_id
visual_definition_id
```

Rules from [Content IDs](../40_content/CONTENT_IDS.md): lowercase dot-separated semantic IDs are independent of file paths, runtime Nodes and procedural StableIds. A persisted content-ID rename is a migration, not a cosmetic file move.

One definition ID may describe many logical/runtime instances. `item.weapon.iron_sword` does not identify one particular owned or dropped sword.

Authority: [Content Architecture](CONTENT_ARCHITECTURE.md), [Content IDs](../40_content/CONTENT_IDS.md), [Item / Inventory / Crafting](../30_gameplay/ITEM_INVENTORY_CRAFTING.md).

## 2. Procedural `StableAddress` and `StableId`

Procedural identity answers **which deterministic generated candidate/location is this?**

```text
StableAddress
    canonical procedural address/lineage
        ↓
StableId
    persistent procedural identifier derived from the address
```

Use `*_address` for canonical procedural/spatial addresses and `stable_id` / `*_stable_id` for procedural `StableId`s.

Do not call a semantic content ID a `StableId`. Do not give player-created objects procedural StableAddresses merely because they exist in the world.

A generated object may legitimately have both:

```text
content_id = "item.resource.copper_ore"
stable_id  = "sid1:..."
```

The first says what it is; the second says which generated instance/location it is. A `StableId` alone is not full generation provenance.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Project Glossary](../00_project/GLOSSARY.md).

## 3. Persistent gameplay/player-created instance IDs

Use a separate persistent identity category when one player/gameplay-created copy must retain state independently.

Examples include a placed building piece or an individually stateful item with durability/modifiers.

Prefer explicit names:

```text
build_instance_id
item_instance_id
persistent_instance_id
```

The exact encoding for future player-created/item-instance IDs is intentionally open; this reference does not choose UUID, monotonic, save-scoped or another format.

A placed building instance remains the same logical object when its mesh, runtime Node, render batch or streamed cell changes.

Authority: [Building System](../30_gameplay/BUILDING_SYSTEM.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md).

## 4. Stack identity for fungible resources

Fungible items do not require one persistent ID per unit.

```text
item_content_id = "item.resource.wood"
quantity = 40
```

may be sufficient stack state when all units are compatible under the item rules.

Use names such as `stack`, `stack_state`, `quantity`, and `item_content_id`. Introduce `item_instance_id` only when one copy needs persistent per-item state.

Authority: [Item / Inventory / Crafting](../30_gameplay/ITEM_INVENTORY_CRAFTING.md).

## 5. Presentation definitions, roles and asset references

Presentation is replaceable and must not become authoritative identity.

```text
logical identity/state
        ↓
semantic visual / animation / audio definition or role
        ↓
current mesh / scene / material / clip / sound resource
```

Semantic fields may use names such as:

```text
visual_id
animation_set_id
presentation_role
animation_role
audio_role
asset_reference
```

Concrete storage/engine locations should be named as such:

```text
resource_path
scene_path
mesh_path
material_path
clip_name
```

Changing those concrete assets must not silently rename the logical object. Renderer/MultiMesh/batch handles and indexes are transient even when they map back to logical identity.

Authority: [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md), [Content References](../40_content/CONTENT_REFERENCES.md).

## 6. Runtime Node/object identity is transient

These values identify a current engine object or implementation slot, not durable game/world identity:

```text
Node instance ID
NodePath
RID
Resource memory identity
runtime array index
pool slot
renderer batch index
```

Name them explicitly (`node`, `node_path`, `runtime_handle`, `render_handle`, `pool_index`, `batch_index`). Do not persist them as semantic identity or derive content IDs/StableIds from them.

Authority: [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md).

## 7. Versions and revisions are compatibility metadata

Version/revision fields say how data or a contract is interpreted. They normally do not identify the logical object.

Examples:

```text
save_schema_version
seed_schema_version
stable_address_schema_version
stage_revision
schema_revision
```

Use `_version` or `_revision` names for those concepts. Do not change a semantic/procedural identity merely because a compatible schema revision changes, and do not hide an incompatible identity change behind an unchanged revision.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Content Registry Architecture](CONTENT_REGISTRY.md).

## 8. Fingerprints verify canonical contents/dependencies

A fingerprint answers whether defined canonical contents/dependencies match exactly.

Examples include generation-stage, provenance, geometry/output, dependency and generator-manifest fingerprints.

Use specific names such as:

```text
fingerprint
content_fingerprint
dependency_fingerprint
provenance_fingerprint
manifest_id
```

Do not use `fingerprint` as a generic synonym for every ID. Semantic concepts use content IDs; procedural candidates use StableAddress/StableId terminology; canonical-content verification uses fingerprints.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md).

## 9. Addresses and partition identities

`address` should mean a canonical procedural/spatial/logical location under a specific contract.

Examples:

```text
StableAddress          -> procedural candidate/location/lineage
region_address         -> generation partition
geometry_cell_address  -> deterministic geometry partition
runtime_cell_address   -> live runtime lifetime partition
```

A geometry-cell address is not automatically a gameplay `StableId`, and sharing coordinates with a runtime cell does not make the two ownership concepts identical.

Authority: [Project Glossary](../00_project/GLOSSARY.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md).

## 10. References describe relationships

A reference points to another identity under a semantic role/type; it is not a new identity class.

```text
weapon.attack_set -> attack_set.sword.basic
recipe.output     -> item.weapon.iron_sword
```

Prefer names that expose the relationship/target when useful:

```text
attack_set_id
output_item_id
visual_reference
source_stable_id
owner_instance_id
```

Authored cross-definition references use semantic IDs rather than current file paths. Do not name a path string `item_id` merely because it currently leads to the item Resource.

Authority: [Content References](../40_content/CONTENT_REFERENCES.md).

## 11. Display names are not identity

Human-facing/debug names may change, localize or duplicate:

```text
display_name
localized_name
debug_label
editor_label
```

For example, `content_id = "item.weapon.iron_sword"` can remain stable while the visible name changes in every supported language.

Authority: [Content IDs](../40_content/CONTENT_IDS.md), [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md).

## Cross-system examples

### Worldgen

```text
world_id                -> which seeded world
stable_address          -> which deterministic candidate/location
stable_id               -> persistent procedural candidate/location
provenance_fingerprint  -> exact generation ancestry verification
geometry_cell_address   -> deterministic geometry partition
runtime_handle          -> current representation only
```

Generation order, array position, load order and Node identity are not generated-object identity.

### Building

```text
piece_definition_id -> authored build-piece kind
build_instance_id   -> persistent placed copy
socket_role         -> semantic connection role
mesh_path           -> current presentation resource only
runtime_node        -> currently loaded representation only
```

### Items / inventory / crafting

```text
item_content_id  -> authored item definition
quantity         -> fungible grouped count
item_instance_id -> individually stateful owned copy, when required
slot_index       -> current container position, not item identity
recipe_id        -> authored recipe definition
world_stable_id  -> separate generated-world identity when applicable
```

### Presentation

```text
logical content / StableId / persistent instance identity
        ↓
semantic presentation role/definition
        ↓
mesh/material/scene/clip path
        ↓
runtime render/audio handle
```

### Persistence

```text
save_schema_version    -> serialized-layout compatibility
world_id               -> which seeded world
generator_manifest_id  -> which deterministic generation contract
stable_id              -> which generated procedural object/location
persistent_instance_id -> which player/gameplay-created persistent object, when applicable
```

Runtime cell indexes, scene paths and renderer handles are not durable save identity.

## Preferred vocabulary

| Suffix / term | Use when |
| --- | --- |
| `_id` | Stable logical identity under a named owning contract |
| `content_id` | Semantic authored-definition identity |
| `stable_id` | Procedural `StableId` specifically |
| `*_instance_id` | Individually persistent gameplay/player-created instance identity |
| `*_address` | Canonical procedural/spatial/partition address |
| `*_fingerprint` | Derived canonical-content/dependency verification value |
| `*_version` | Versioned serialized/contract format |
| `*_revision` | Revision of a specific schema/stage/definition contract |
| `*_reference` / `*_ref` | Relationship/reference to another identity; public fields should clarify target semantics |
| `*_handle` | Transient runtime/engine/renderer handle |
| `*_index` | Collection/slot/batch position; transient unless an owning contract explicitly says otherwise |
| `*_path` | Filesystem/scene/Node/resource location, not semantic identity |
| `display_name` / `label` | Human-facing or diagnostic text |

Avoid bare `id` in cross-system data when content, procedural, persistent-instance or runtime identity could all plausibly be meant.

## Non-authoritative identity sources

Unless a specific owning contract explicitly says otherwise, never promote these into durable semantic identity:

```text
filesystem/resource path
PackedScene path
NodePath
Godot Node instance ID
RID / Resource memory identity
array position
inventory/UI slot index
runtime cell load order
worker completion order
renderer/MultiMesh/batch index
mesh/material/texture/animation filename
display/localized name
```

## Naming checklist

Before adding an identifier-like field, answer:

1. What question does it answer: what kind, which generated candidate, which placed copy, which runtime object, which revision, or which exact contents?
2. Which subsystem owns it?
3. What is its lifetime: authored, world-persistent, save-persistent, runtime, or disposable?
4. May files/assets/runtime representations move or rebuild without changing it? If yes, keep those transient details out of the identity.
5. Is it really a fingerprint, address, reference, handle or index rather than an ID?
6. Can several identity classes coexist on the object? If yes, qualify fields (`content_id`, `stable_id`, `item_instance_id`) instead of using bare `id`.
7. Is the format intentionally open? Document the identity category without inventing an encoding.

## Source contracts

- [Project Glossary](../00_project/GLOSSARY.md) — canonical terminology and commonly confused boundaries.
- [Content Architecture](CONTENT_ARCHITECTURE.md) — authored definitions versus runtime/presentation state.
- [Content Registry Architecture](CONTENT_REGISTRY.md) — semantic lookup direction and registry responsibility boundary.
- [Content IDs](../40_content/CONTENT_IDS.md) — semantic ID format, stability and migrations.
- [Content References](../40_content/CONTENT_REFERENCES.md) — typed semantic reference direction.
- [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md) — procedural identity and provenance.
- [Streaming Ownership](../STREAMING_OWNERSHIP.md) — geometry/runtime partition and lifetime boundaries.
- [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md) — generated StableIds, player-created identity category and version concepts.
- [Building System](../30_gameplay/BUILDING_SYSTEM.md) — definition versus persistent placed instance.
- [Item / Inventory / Crafting](../30_gameplay/ITEM_INVENTORY_CRAFTING.md) — definition, stack, item-instance and world StableId separation.
- [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md) — presentation resources/handles are not game identity.

## Review invariant

A field name should make it clear whether the value is a semantic definition, procedural generated identity, persistent gameplay instance, stack state, compatibility revision, verification fingerprint, canonical address, semantic reference, replaceable asset location, or transient runtime handle.

If that meaning is ambiguous, qualify the name before it spreads into persistence, gameplay or cross-system APIs.
