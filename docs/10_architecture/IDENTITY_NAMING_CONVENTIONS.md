# Underworld — Identity and Naming Conventions

Status: **architecture reference derived from accepted authoritative contracts**

This file is a naming/review aid, not a new identity schema. The authoritative contracts linked below win if any summary here conflicts with them.

Core rule:

> Name an identifier for **what it identifies and which subsystem owns it**. Semantic definitions, schema vocabulary, procedural identity, mutable state, paths, runtime objects, indexes and fingerprints are different concepts even when all are represented as strings or numbers.

## Identity and state classes

| Class | Question answered | Example / direction | Authority / lifetime |
| --- | --- | --- | --- |
| Authored `ContentId` | What authored definition is this? | `item.weapon.iron_sword`, `resource.node.copper`, `archetype.creature.burrower` | Stable authored content identity |
| Controlled `SchemaId` | Which registered category/capability/semantic role is declared? | `category.item.weapon`, `capability.harvest_tool`, `animation_role.action.attack.light_01`, `rig_role.socket.hand.right` | Registered schema vocabulary |
| Procedural `StableAddress` | Which deterministic candidate/location/lineage is this? | canonical worldgen address | Deterministic world definition |
| Procedural `StableId` | Which generated procedural candidate/location is this? | `sid1:...` | Persistent generated-world identity |
| Mutable gameplay state | What mutable state belongs to a logical definition/copy/location? | `ItemStackState`, per-copy `ItemInstanceState`, `ResourceDepletionState` | Runtime/save-compatible gameplay state |
| Future persistent per-copy item identity | Which individually persistent owned copy is this? | future `item_instance_id` | Identity category is accepted; exact encoding remains **OPEN** |
| Presentation definition/binding | Which replaceable presentation concept/configuration is requested? | `archetype.*`, `animation_set.*`, `rig_profile.*`, cave presentation profile | Authored/replaceable presentation boundary |
| Runtime object identity | Which live engine object currently represents this? | `Node`, `Object`, RID, Resource instance | Transient runtime implementation |
| Version/revision | Which contract/schema interprets this data? | `save_schema_version`, `schema_revision` | Compatibility metadata, not object identity |
| Fingerprint | Do canonical contents/dependencies match? | provenance/output/manifest fingerprint | Derived verification/cache value |
| Address/partition key | Which deterministic/spatial partition is this? | region/cell address | Contract-specific partition identity |
| Handle/index | Which current implementation slot is this? | render handle, pool/array/slot index | Transient acceleration/detail |
| Display/localization label | What text should a person see? | localized name, debug label | Human-facing text, never identity |

The [Project Glossary](../00_project/GLOSSARY.md) remains the canonical terminology index.

---

## 1. `ContentId` — authored semantic definition identity

A `ContentId` answers **what authored definition is this?**

Accepted families include directions such as:

```text
item.resource.wood
item.weapon.iron_sword
resource.node.copper
creature.underworld.burrower
archetype.creature.burrower
animation_set.humanoid.prototype
rig_profile.humanoid.prototype
attack_set.weapon.sword.basic
```

Use names that expose the target when useful:

```text
content_id
item_content_id
resource_definition_id
archetype_id
animation_set_id
rig_profile_id
attack_set_id
```

Rules:

- lowercase dotted spelling is semantic naming, not a filesystem path;
- a file/resource move does not change a definition's `ContentId`;
- one authored definition may describe many stacks, owned copies, generated placements and runtime Nodes;
- a persisted `ContentId` rename is a migration, not a cosmetic refactor;
- `ContentId` families and `SchemaId` families are not interchangeable.

For example, `item.weapon.iron_sword` says **what item definition** is involved. It does not identify one particular owned sword, one generated world placement, an equipment slot or the scene currently displaying it.

Authority: [Content Architecture](CONTENT_ARCHITECTURE.md), [Content IDs](../40_content/CONTENT_IDS.md), [Content Families](../40_content/CONTENT_FAMILIES.md), [Item Rulebook](../40_content/ITEM_RULEBOOK.md).

---

## 2. `SchemaId` — controlled vocabulary, not authored content identity

The accepted schema namespaces are distinct from `ContentId`. Current controlled families include:

```text
category.*
capability.*
animation_role.*
rig_role.*
```

Examples:

```text
category.item.weapon
category.resource.deposit
capability.equipable
capability.harvest_tool
animation_role.action.attack.light_01
rig_role.socket.hand.right
```

Prefer the accepted field vocabulary where the domain is known:

```text
category_ids
capability_ids
attack_animation_role
rig_role
attachment_root_role
```

Do not call these values content definitions and do not resolve them through a parallel content-ID system.

### Relationship ownership

Dotted spelling does **not** create ancestry, implication or membership by itself.

- category ancestry is owned by `CategorySchemaRegistry`;
- capability implication/composition is owned by `CapabilitySchemaRegistry`;
- animation/rig semantic-role membership is owned by `SemanticRoleSchemaRegistry`.

Therefore:

```text
category.item.weapon.sword
```

is not automatically a descendant of `category.item.weapon` merely because its spelling has more tokens. The registered schema relationship is authoritative.

Likewise, a capability name does not imply another capability because their text looks related, and an animation/rig role is valid because it belongs to the accepted role schema, not because a string happens to start with `animation_role.` or `rig_role.`.

Authority: [Content Categories](../40_content/CONTENT_CATEGORIES.md), [Content Capabilities](../40_content/CONTENT_CAPABILITIES.md), accepted `core/content/schema/` contracts.

---

## 3. Procedural `StableAddress` and `StableId`

Procedural identity answers **which deterministic generated candidate/location is this?**

```text
StableAddress
    canonical procedural address/lineage
        ↓
StableId
    persistent procedural identifier derived from that address
```

Use `*_address` for canonical procedural/spatial addresses and `stable_id` / `*_stable_id` for procedural `StableId`s.

Do not:

- call a semantic `ContentId` a `StableId`;
- use a category/capability/role `SchemaId` as procedural identity;
- give player-created objects procedural `StableAddress` values merely because they exist in the world;
- derive a `StableId` from runtime Node identity, array order or presentation assets.

A generated resource placement may legitimately carry multiple independent facts:

```text
resource_content_id = "resource.node.copper"
stable_id           = "sid1:..."
```

The first says what authored definition is realized; the second says which generated placement/candidate it is. Neither replaces the other, and a `StableId` alone is not complete generation provenance.

MAP-016 is accepted-main. Its deterministic cave geometry/runtime representation does not change this ownership: generation addresses/StableIds remain world truth while mesh resources, collision objects and presentation Nodes remain replaceable runtime representation.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Project Glossary](../00_project/GLOSSARY.md).

---

## 4. Mutable gameplay state is not authored definition identity

Mutable state describes the changing state associated with an authored definition, owned copy or generated location. It does not mutate the shared authored definition into a runtime instance.

Accepted examples include:

```text
ItemStackState
ItemInstanceState
ResourceDepletionState
```

### `ItemStackState`

Fungible resources may use lightweight stack state:

```text
item_content_id = "item.resource.wood"
quantity = 40
compatibility_state = {...}
```

Forty ordinary units do not require forty persistent IDs.

### Per-copy `ItemInstanceState`

When one non-fungible copy requires mutable state, keep that state separate from `ItemDefinition`:

```text
item_content_id = "item.weapon.iron_sword"
per_copy_state = { durability = 81 }
```

The accepted mutable-state class does **not** lock the future persistent per-copy item identity encoding. A later durable `item_instance_id` may be required when cross-session identity of one copy matters, but UUID/monotonic/save-scoped/other encoding remains intentionally **OPEN**.

### `ResourceDepletionState`

Placed resource/deposit depletion belongs to mutable placement/runtime state. It must not be stored by mutating the shared `ResourceDefinition`.

Use explicit names for state fields and structures. Do not call mutable state itself a definition ID or a procedural `StableId`.

Authority: [Item Rulebook](../40_content/ITEM_RULEBOOK.md), [Resource Rulebook](../40_content/RESOURCE_RULEBOOK.md), [Item / Inventory / Crafting](../30_gameplay/ITEM_INVENTORY_CRAFTING.md).

---

## 5. Future persistent gameplay/player-created instance IDs

Use a separate persistent identity category when one gameplay-created copy must remain the same logical object across save/load even though its runtime representation changes.

Potential examples:

```text
build_instance_id
item_instance_id
persistent_instance_id
```

The identity category is distinct from:

- authored `ContentId`;
- controlled `SchemaId`;
- procedural world `StableId`;
- mutable per-copy state;
- inventory/equipment slot indexes;
- Node/Object/RID identity.

The exact future per-copy item ID encoding remains open. This reference intentionally does not choose a format.

A placed building or individually persistent item remains the same logical copy when its mesh, Node, render batch, streamed cell or UI representation changes.

Authority: [Building System](../30_gameplay/BUILDING_SYSTEM.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Item / Inventory / Crafting](../30_gameplay/ITEM_INVENTORY_CRAFTING.md).

---

## 6. Presentation identity and role vocabulary

Presentation is replaceable and must not become gameplay/world/save authority.

A typical boundary is:

```text
authoritative logical identity/state
        ↓
semantic presentation definition / schema role
        ↓
replaceable asset/resource
        ↓
transient runtime Node/Object/RID/handle
```

Keep authored presentation definitions and role vocabulary distinct:

```text
archetype.*       -> authored ContentId family
animation_set.*   -> authored ContentId family
rig_profile.*     -> authored ContentId family
animation_role.*  -> controlled semantic-role SchemaId
rig_role.*        -> controlled semantic-role SchemaId
```

Concrete engine/storage locations should be named as such:

```text
resource_path
scene_path
mesh_path
material_path
clip_name
```

Changing a mesh, scene, animation library or material must not silently rename gameplay identity.

### Accepted cave presentation boundary

PRESENTATION-001 is accepted-main. Cave presentation profiles/materials/lights/ambience and their runtime realization are replaceable presentation data. The compact cave semantic snapshot passed to presentation is **context for presentation selection**, not a new gameplay/persistence identity system.

Do not invent a durable gameplay `StableId`, save identity or content identity merely for a cave presentation Node/profile/snapshot. Worldgen geometry/collision/StableId truth remains owned by MAP/worldgen contracts.

Authority: [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md), [Cave Presentation Layer](CAVE_PRESENTATION_LAYER.md), [Content References](../40_content/CONTENT_REFERENCES.md).

---

## 7. Runtime Node/Object/Resource identity is transient

These values identify a current engine object or implementation slot, not durable game/world identity:

```text
Node instance ID
Object instance ID
NodePath
RID
Resource memory identity
runtime array index
pool slot
renderer batch index
```

Name them explicitly:

```text
node
node_path
runtime_handle
render_handle
pool_index
batch_index
slot_index
```

Do not persist them as semantic identity and do not derive `ContentId`, `SchemaId`, `StableAddress`, `StableId` or future persistent per-copy identity from them.

Authority: [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md).

---

## 8. Versions and revisions are compatibility metadata

Version/revision fields say how data or a contract is interpreted. They normally do not identify the logical object.

Examples:

```text
save_schema_version
seed_schema_version
stable_address_schema_version
stage_revision
schema_revision
```

Use `_version` or `_revision` for those concepts. Do not change a semantic/procedural identity merely because a compatible schema revision changes, and do not hide an incompatible persistent identity change behind an unchanged revision.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Content Registry Architecture](CONTENT_REGISTRY.md).

---

## 9. Fingerprints verify canonical contents/dependencies

A fingerprint answers whether canonical contents/dependencies match exactly. It is normally derived, not the semantic identity of the underlying thing.

Examples:

```text
content_fingerprint
dependency_fingerprint
provenance_fingerprint
output_fingerprint
manifest_id
```

Do not use `fingerprint` as a generic synonym for every ID:

- authored definitions use `ContentId`;
- schema vocabulary uses `SchemaId`;
- generated candidates use `StableAddress` / `StableId`;
- canonical-content verification uses fingerprints.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md).

---

## 10. Addresses and partition keys

`address` should mean a canonical procedural/spatial/logical location under a specific owning contract.

Examples:

```text
StableAddress          -> procedural candidate/location/lineage
region_address         -> generation partition
geometry_cell_address  -> deterministic geometry partition
runtime_cell_address   -> live runtime lifetime partition
```

A geometry-cell address is not automatically a gameplay `StableId`, and sharing coordinates with a runtime cell does not make the two ownership concepts identical.

Authority: [Project Glossary](../00_project/GLOSSARY.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md).

---

## 11. References describe relationships

A reference points to another identity under a semantic role/type. It is not a new identity class.

Examples:

```text
weapon.attack_set      -> attack_set.weapon.sword.basic
presentation.archetype -> archetype.weapon.iron_sword
resource yield         -> item.resource.copper_chunk
```

Prefer names that expose the relationship/target when useful:

```text
attack_set_id
archetype_id
yield_item_id
source_stable_id
owner_instance_id
```

Authored cross-definition references use semantic IDs rather than current file paths. Do not name a path string `item_id` merely because it currently leads to an item Resource.

Authority: [Content References](../40_content/CONTENT_REFERENCES.md).

---

## 12. Display/localization names are not identity

Human-facing/debug names may change, localize or duplicate:

```text
display_name
localized_name
debug_label
editor_label
```

For example, `content_id = "item.weapon.iron_sword"` can remain stable while the visible name changes in every supported language.

Authority: [Content IDs](../40_content/CONTENT_IDS.md).

---

## Cross-system examples

### Content definition

```text
content_id      -> authored definition identity
category_ids    -> registered classification SchemaIds
capability_ids  -> registered capability SchemaIds
schema_revision -> definition/schema compatibility metadata
resource_path   -> current authored storage location only
```

### Worldgen / MAP

```text
world_id                -> which seeded world contract
stable_address          -> which deterministic candidate/location
stable_id               -> persistent procedural candidate/location
provenance_fingerprint  -> exact generation ancestry verification
geometry_cell_address   -> deterministic geometry partition
runtime_handle          -> current representation only
```

Generation order, array position, mesh path, collision Node and load order are not generated-object identity.

### Items / inventory

```text
item_content_id   -> authored item definition
category_ids      -> registered classification vocabulary
capability_ids    -> registered behavior-contract vocabulary
ItemStackState    -> fungible quantity + compatibility state
ItemInstanceState -> mutable per-copy state
item_instance_id  -> future persistent per-copy identity when required; encoding OPEN
slot_index        -> current container/equipment position, not item identity
```

### Resources

```text
resource_content_id     -> authored resource/deposit definition
stable_id               -> separate generated placement identity when applicable
ResourceDepletionState  -> mutable depletion/delta state for that placement
mesh/node                -> replaceable runtime presentation/realization
```

### Weapon / character presentation

```text
item.weapon.iron_sword                  -> authored weapon ContentId
attack_set.weapon.sword.basic           -> authored attack-set ContentId
archetype.weapon.iron_sword             -> authored presentation ContentId
animation_role.action.attack.light_01   -> controlled semantic-role SchemaId
rig_role.socket.hand.right              -> controlled semantic-role SchemaId
scene/mesh/clip                         -> concrete replaceable assets
runtime Node/RID                        -> transient realization
```

### Persistence

```text
save_schema_version    -> serialized-layout compatibility
world_id               -> which seeded world
generator_manifest_id  -> which deterministic generation contract
stable_id              -> which generated procedural object/location
content_id             -> which authored definition
mutable state          -> durable state required by the owning contract
item_instance_id       -> future per-copy identity only when required; encoding OPEN
```

Runtime cell indexes, scene paths, UI slots and renderer handles are not durable save identity.

---

## Preferred vocabulary

| Suffix / term | Use when |
| --- | --- |
| `_id` | Stable logical identity under a named owning contract |
| `content_id` | Semantic authored-definition `ContentId` |
| `category_ids` | Registered category `SchemaId` declarations |
| `capability_ids` | Registered capability `SchemaId` declarations |
| `animation_role` / `rig_role` | Registered semantic-role `SchemaId` |
| `stable_id` | Procedural `StableId` specifically |
| `*_instance_id` | Individually persistent gameplay/player-created copy identity |
| `*_address` | Canonical procedural/spatial/partition address |
| `*_fingerprint` | Derived canonical-content/dependency verification value |
| `*_version` | Versioned serialized/contract format |
| `*_revision` | Revision of a specific schema/stage/definition contract |
| `*_reference` / `*_ref` | Relationship/reference to another identity; public fields should clarify target semantics |
| `*_state` | Mutable logical state, not automatically identity |
| `*_handle` | Transient runtime/engine/renderer handle |
| `*_index` | Collection/slot/batch position; transient unless an owning contract explicitly says otherwise |
| `*_path` | Filesystem/scene/Node/resource location, not semantic identity |
| `display_name` / `label` | Human-facing or diagnostic text |

Avoid bare `id` in cross-system data when content, schema, procedural, persistent-instance or runtime identity could plausibly be meant.

---

## Non-authoritative identity sources

Unless a specific owning contract explicitly says otherwise, never promote these into durable semantic identity:

```text
filesystem/resource path
PackedScene path
NodePath
Godot Node/Object instance ID
RID / Resource memory identity
array position
inventory/equipment/UI slot index
runtime cell load order
worker completion order
renderer/MultiMesh/batch index
mesh/material/texture/animation filename
display/localized name
```

Likewise, do not infer schema relationships from dotted spelling alone. Registry-declared category ancestry, capability implication and semantic-role membership are authoritative.

---

## Naming checklist

Before adding an identifier-like field, answer:

1. Does it identify authored content, controlled schema vocabulary, a generated candidate, a persistent gameplay-created copy, or only a current runtime representation?
2. Is it actually mutable state, a fingerprint, address, reference, handle, index, path, version or display label rather than an ID?
3. Which subsystem/registry owns its meaning?
4. What is its lifetime: authored, world-persistent, save-persistent, runtime or disposable?
5. May files/assets/runtime representations move or rebuild without changing it? If yes, keep those transient details out of the identity.
6. Can several identity classes coexist on the same object? If yes, qualify fields (`content_id`, `stable_id`, `item_instance_id`) instead of using bare `id`.
7. For `category.*`, `capability.*`, `animation_role.*` or `rig_role.*`, is the required relationship actually registered rather than guessed from spelling?
8. Is a format intentionally open? Document the identity category without inventing an encoding.

---

## Source contracts

- [Project Glossary](../00_project/GLOSSARY.md) — canonical terminology and commonly confused boundaries.
- [Content Architecture](CONTENT_ARCHITECTURE.md) — authored definitions versus runtime/presentation state.
- [Content Registry Architecture](CONTENT_REGISTRY.md) — semantic lookup and registry responsibility boundary.
- [Content IDs](../40_content/CONTENT_IDS.md) — semantic ID format, stability and migrations.
- [Content Families](../40_content/CONTENT_FAMILIES.md) — authored family vocabulary.
- [Content Categories](../40_content/CONTENT_CATEGORIES.md) — category schema and ancestry ownership.
- [Content Capabilities](../40_content/CONTENT_CAPABILITIES.md) — capability schema and implication/composition ownership.
- [Content References](../40_content/CONTENT_REFERENCES.md) — typed semantic reference direction.
- [Item Rulebook](../40_content/ITEM_RULEBOOK.md) — accepted item definition/state boundary.
- [Resource Rulebook](../40_content/RESOURCE_RULEBOOK.md) — accepted resource/depletion boundary.
- [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md) — procedural identity and provenance.
- [Streaming Ownership](../STREAMING_OWNERSHIP.md) — geometry/runtime partition and lifetime boundaries.
- [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md) — generated StableIds, persistent gameplay identity category and version concepts.
- [Building System](../30_gameplay/BUILDING_SYSTEM.md) — definition versus persistent placed instance.
- [Item / Inventory / Crafting](../30_gameplay/ITEM_INVENTORY_CRAFTING.md) — definition, stack, item-state and world StableId separation.
- [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md) — presentation resources/handles are not gameplay identity.
- [Cave Presentation Layer](CAVE_PRESENTATION_LAYER.md) — accepted presentation-only cave realization over value-only semantic context.
- accepted `core/content/schema/` contracts — `SchemaId`, category/capability registries and `SemanticRoleSchemaRegistry`.

## Review invariant

A field name should make it clear whether the value is an authored `ContentId`, controlled `SchemaId`, procedural generated identity, persistent gameplay-created identity, mutable state, compatibility revision, verification fingerprint, canonical address, semantic reference, replaceable asset location, display label or transient runtime handle.

If that meaning is ambiguous, qualify the name before it spreads into persistence, gameplay or cross-system APIs.
