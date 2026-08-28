# Underworld — Identity and Naming Conventions

Status: **architecture reference derived from existing authoritative contracts**

This document is a compact naming and review aid. It does not create a new identity schema and does not override the owning architecture documents linked below. If this reference conflicts with an authoritative source, the authoritative source wins and this file should be corrected.

The central rule is:

> Use an identity name that states **what is being identified and who owns that identity**. Do not reuse file paths, runtime object identity, fingerprints or indexes as substitutes for a different identity class.

## 1. Identity classes at a glance

| Identity class | Question it answers | Typical example | Authority / lifetime |
| --- | --- | --- | --- |
| Semantic authored definition ID | **What authored kind of thing is this?** | `item.weapon.iron_sword` | Authored content; stable across file/presentation moves |
| Procedural `StableAddress` | **Which deterministic candidate/location/lineage is this?** | canonical worldgen address | Deterministic world definition |
| Procedural `StableId` | **Which generated procedural candidate/location is this?** | `sid1:...` | Persistent generated-world identity derived from `StableAddress` |
| Persistent instance ID | **Which individually stateful player/gameplay-created instance is this?** | future build/item instance ID | Durable gameplay/save state; exact format may be subsystem-defined later |
| Stack identity/state | **Which compatible quantity/state is grouped together?** | `item.resource.wood` + quantity | Inventory/container state; often no per-unit ID |
| Presentation/content asset identity | **Which authored presentation definition or role is requested?** | `visual.weapon.iron_sword`, semantic visual/animation role | Authored presentation binding; concrete asset path remains replaceable |
| Runtime object/Node identity | **Which live engine object currently represents this?** | a `Node`/RID/resource instance | Transient runtime implementation only |
| Revision/version field | **Which schema/contract revision interprets this data?** | `schema_revision = 3` | Compatibility metadata, not logical object identity |
| Fingerprint | **Do these canonical contents/dependencies match exactly?** | stage/manifest/content fingerprint | Derived verification/cache identity; not a replacement for semantic identity |
| Address / partition key | **Where/which deterministic or spatial partition is this?** | region/cell address | Contract-specific location/partition identity |
| Handle / index | **How do I refer to a current implementation slot efficiently?** | renderer handle, array index | Transient acceleration/implementation detail |

See the [Project Glossary](../00_project/GLOSSARY.md) for canonical terminology and the more specific contracts linked throughout this document.

## 2. Semantic authored definition IDs

Semantic content IDs identify authored concepts: **what the thing is**, not where its file lives and not which concrete instance currently exists.

Examples already established by the project include:

```text
item.resource.wood
item.weapon.iron_sword
creature.underworld.burrower
attack_set.sword.basic
animation_set.humanoid.one_handed_sword
structure.surface.ruined_hut
visual.weapon.iron_sword
recipe.weapon.iron_sword
```

Naming rules come from [Content IDs](../40_content/CONTENT_IDS.md):

- lowercase dot-separated semantic hierarchy;
- stable meaning rather than display wording;
- no whitespace or filesystem separators;
- paths may mirror IDs for convenience but never define them;
- a persisted semantic-ID rename is a migration, not a cosmetic file rename.

Use names such as:

```text
content_id
item_definition_id
recipe_id
attack_set_id
visual_definition_id
```

when a field stores semantic authored identity.

Avoid ambiguous names such as `id` when several identity classes coexist in the same structure.

### Definition ID is not instance ID

One definition may describe many instances:

```text
item_definition_id = "item.weapon.iron_sword"
```

does not identify one particular owned sword, dropped sword, generated pickup, or build instance.

Authority: [Content Architecture](CONTENT_ARCHITECTURE.md), [Content IDs](../40_content/CONTENT_IDS.md), [Item / Inventory / Crafting](../30_gameplay/ITEM_INVENTORY_CRAFTING.md).

## 3. Procedural `StableAddress` and `StableId`

Procedural identity answers **which deterministic generated candidate/location/lineage is this?**

The project deliberately separates:

```text
StableAddress
    canonical readable semantic procedural address
        ↓
StableId
    persistent procedural identifier derived from that address
```

Use `*_address` for canonical procedural/spatial address objects or strings and `*_stable_id` / `stable_id` for the derived procedural persistent ID where context is unambiguous.

Do not call a semantic authored definition ID a `StableId`. Likewise, do not assign a procedural `StableId` to a player-created object merely because it exists in the world.

A generated object may legitimately carry both:

```text
content_id = "item.resource.copper_ore"
stable_id  = "sid1:..."
```

The first says what authored rules/content it uses. The second says which generated world instance/location it is.

A `StableId` alone is also not proof of world/generator provenance; deterministic provenance additionally binds the relevant world/generator/stage ancestry.

Authority: [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Project Glossary](../00_project/GLOSSARY.md).

## 4. Persistent gameplay/player-created instance IDs

Stateful player-created or individually owned gameplay objects may require an identity category separate from authored definition IDs and procedural world IDs.

Examples include:

- a placed building piece whose health/ownership must survive reload;
- one individually stateful item copy with durability/modifiers/customization;
- other future player-created persistent objects.

Prefer explicit names such as:

```text
build_instance_id
item_instance_id
persistent_instance_id
```

rather than borrowing `stable_id` unless the owning contract explicitly defines that identity as a procedural `StableId`.

The exact encoding for future player-created and item-instance IDs is intentionally open. This document does not define UUID, monotonic, save-scoped or other formats.

### Building example

A durable placed piece may conceptually contain:

```text
persistent instance identity
semantic piece-definition ID
world transform
mutable durability/ownership state
```

Changing its mesh, runtime Node, streamed cell or render batch must not change its persistent placed-instance identity.

Authority: [Building System](../30_gameplay/BUILDING_SYSTEM.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md).

## 5. Stack identity for fungible resources

Fungible quantities do not need one persistent identity per unit.

For example:

```text
item_content_id = "item.resource.wood"
quantity = 40
```

may be sufficient logical stack state when all 40 units are compatible under the item rules.

Use names such as:

```text
stack
stack_state
quantity
item_content_id
```

Do not invent `item_instance_id` values for every fungible unit solely to make them addressable.

If later mutable per-copy state makes one item individually persistent, that item may move into the separate item-instance identity category without changing its semantic definition identity.

Authority: [Item / Inventory / Crafting](../30_gameplay/ITEM_INVENTORY_CRAFTING.md).

## 6. Presentation IDs, semantic roles and asset references

Presentation may use semantic authored identities and roles to select replaceable assets. The semantic request is separate from the concrete file/resource currently satisfying it.

Conceptually:

```text
logical identity/state
        ↓
semantic visual / animation / audio role or definition
        ↓
current mesh / scene / material / clip / sound resource
```

Useful names include:

```text
visual_id
animation_set_id
presentation_role
animation_role
audio_role
asset_reference
```

when those values are semantic authored references.

Names such as these should be reserved for actual storage/engine references when appropriate:

```text
resource_path
scene_path
mesh_path
material_path
clip_name
```

Those concrete presentation identifiers are replaceable implementation data and must not become semantic gameplay/save identity.

A renderer-local handle, `MultiMesh` index or batch index is likewise transient even if it maps back to a logical object.

Authority: [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md), [Content References](../40_content/CONTENT_REFERENCES.md).

## 7. Runtime Node/object identity is transient

Godot runtime identities answer only which currently loaded engine object/resource is being referenced.

Examples include:

```text
Node instance ID
NodePath
RID
Resource memory identity
runtime array index
pool slot
renderer batch index
```

Use explicit implementation names such as:

```text
node
node_path
runtime_handle
render_handle
pool_index
batch_index
```

Do not persist them as authoritative world/gameplay identity and do not use them to derive semantic content IDs or procedural StableIds.

Runtime objects may be unloaded and rebuilt while authoritative definitions and durable state remain unchanged.

Authority: [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md), [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md).

## 8. Revision/version fields are not logical identity

Version and revision values explain how to interpret a contract. They do not normally identify the game concept itself.

Examples already kept separate by architecture include:

```text
save_schema_version
seed_schema_version
stable_address_schema_version
stage_revision
definition schema_revision
generator manifest identity/revision data
```

Prefer names ending in `_version` or `_revision` when the value is compatibility/schema metadata.

Do not silently rename a semantic or procedural identity because only a schema revision changed. Conversely, do not hide an incompatible identity-semantic change behind an unchanged revision field.

A content definition such as `item.weapon.iron_sword` may receive a schema revision change while remaining the same semantic definition if the owning compatibility rules allow it.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Content Registry Architecture](CONTENT_REGISTRY.md).

## 9. Fingerprints are derived verification identity

A fingerprint answers whether canonical data/dependencies are exactly the same under a defined fingerprint contract.

Project examples include:

- generation-stage fingerprints;
- provenance fingerprints;
- generator-manifest fingerprint/ID;
- geometry/partition/output fingerprints;
- cache/dependency fingerprints.

Use names such as:

```text
fingerprint
content_fingerprint
dependency_fingerprint
provenance_fingerprint
manifest_id
```

according to the owning contract.

Do not use `fingerprint` as a vague synonym for every ID. If a value identifies an authored concept, call it a content ID. If it identifies a procedural candidate, use StableAddress/StableId terminology. If it verifies canonical contents, call it a fingerprint.

Fingerprints may change because compatible logical identity has new contents, dependencies or representation. Whether a particular fingerprint is persistent compatibility identity is defined by its owning contract, not by the word alone.

Authority: [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md), [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md).

## 10. Addresses, cells and partition identities

An address names a deterministic/spatial/logical location or lineage according to a specific contract. The word `address` should retain that meaning rather than becoming a generic ID suffix.

Examples include:

```text
StableAddress          -> procedural candidate/location/lineage
geometry-cell address  -> deterministic geometry partition
runtime-cell address   -> current runtime lifetime partition coordinates/identity
region address         -> generation partition address
```

Qualify the owner when ambiguity is possible:

```text
region_address
geometry_cell_address
runtime_cell_address
source_address
```

A geometry-cell address is not automatically a gameplay `StableId`, and sharing coordinates with a runtime cell does not make the two ownership concepts identical.

Authority: [Project Glossary](../00_project/GLOSSARY.md), [Streaming Ownership](../STREAMING_OWNERSHIP.md).

## 11. References describe a relationship, not a new identity

A reference points from one semantic object to another identity under an expected role/type.

Examples:

```text
weapon.attack_set -> attack_set.sword.basic
recipe.output     -> item.weapon.iron_sword
```

Prefer field names that communicate both relationship and target identity when useful:

```text
attack_set_id
output_item_id
visual_reference
source_stable_id
owner_instance_id
```

For authored content, references use semantic IDs rather than current paths. Typed roles/families/capabilities should make invalid targets diagnosable.

Do not name a path string `item_id` merely because it currently leads to the item Resource.

Authority: [Content References](../40_content/CONTENT_REFERENCES.md).

## 12. Display names are presentation/localization, not identity

Human-readable names may be edited, localized or duplicated and therefore must not be authoritative identity.

Examples:

```text
display_name
localized_name
debug_label
editor_label
```

A sword can keep:

```text
content_id = "item.weapon.iron_sword"
```

while its player-facing display name changes or is localized into many languages.

Likewise, debug labels should help humans understand an identity, not become the key persisted by gameplay systems.

Authority: [Content IDs](../40_content/CONTENT_IDS.md), [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md).

## 13. Cross-system examples

### Worldgen

```text
world_id             -> which seeded world
stable_address       -> which deterministic candidate/location
stable_id            -> persistent procedural candidate/location identity
provenance_fingerprint -> exact generation ancestry verification
geometry_cell_address -> deterministic geometry partition
runtime_handle       -> current live representation handle only
```

Do not derive a generated object's identity from generation order, array position, cell-load order or runtime Node identity.

### Building

```text
piece_definition_id -> what authored build piece this is
build_instance_id   -> which persistent placed copy this is
socket_role         -> semantic connection role inside the definition
mesh_path           -> current presentation resource only
runtime_node         -> currently loaded representation only
```

The persistent instance may survive streaming, batching and mesh replacement.

### Items / inventory / crafting

```text
item_content_id  -> what item definition
quantity         -> fungible grouped count
item_instance_id -> which individually stateful owned copy, only when required
slot_index       -> current container position, not item identity
recipe_id        -> authored recipe definition
world_stable_id  -> separate generated-world identity when a procedural pickup/object requires it
```

One logical item may interact with more than one identity category without those identities becoming interchangeable.

### Presentation

```text
content/stable/persistent identity
        ↓
semantic presentation role or definition
        ↓
mesh/material/scene/clip path
        ↓
runtime render/audio handle
```

Only the upper identity/state layers are authoritative for gameplay/save semantics.

### Persistence

```text
save_schema_version -> serialized-layout compatibility
world_id            -> which seeded world
generator_manifest_id -> which deterministic generation contract
StableId            -> which generated procedural object/location\ persistent_instance_id -> which player/gameplay-created persistent object, when applicable
```

A save never treats runtime cell indexes, scene paths or renderer handles as durable identity.

## 14. Naming checklist

When adding an identifier-like field, answer these questions before choosing its name:

1. **What question does it answer?** What kind, which generated candidate, which placed copy, which runtime object, which revision, or which exact contents?
2. **Who owns it?** Content, worldgen, persistence, gameplay, runtime, presentation, tooling?
3. **What is its lifetime?** Authored/permanent, world-persistent, save-persistent, session/runtime, or disposable cache?
4. **May the file/asset/runtime representation move or be rebuilt without changing it?** If yes, do not encode those transient details into the identity.
5. **Is this actually a fingerprint, address, reference or handle rather than an ID?** Name it accordingly.
6. **Can two different identity classes coexist on the same object?** If yes, qualify fields (`content_id`, `stable_id`, `item_instance_id`) rather than using bare `id`.
7. **Is the format still intentionally open?** Document the category/semantics without inventing an encoding prematurely.

## 15. Preferred vocabulary

| Suffix / term | Use when |
| --- | --- |
| `_id` | Stable logical identity under a named owning contract |
| `content_id` | Semantic authored-definition identity |
| `stable_id` | Procedural `StableId` specifically |
| `*_instance_id` | Individually persistent gameplay/player-created instance identity |
| `*_address` | Canonical procedural/spatial/partition address |
| `*_fingerprint` | Derived canonical-content/dependency verification value |
| `*_version` | Serialized/contract version category |
| `*_revision` | Revision of a specific schema/stage/definition contract |
| `*_reference` / `*_ref` | A relationship/reference to another object/definition; clarify target semantics in public data |
| `*_handle` | Transient runtime/engine/renderer handle |
| `*_index` | Collection/slot/batch position; assume transient unless an owning contract explicitly states otherwise |
| `*_path` | Filesystem/scene/Node/resource location, not semantic identity |
| `display_name` / `label` | Human-facing or diagnostic text, not identity |

Avoid a bare `id` in cross-system structures where semantic content, procedural, persistent-instance or runtime identity could all plausibly be meant.

## 16. Non-authoritative identity sources

Unless an owning contract explicitly states otherwise, never promote these into durable semantic identity:

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
mesh/material/texture/animation filenames
display/localized names
```

These may be useful lookup, presentation or runtime values. They remain replaceable/transient and should be named accordingly.

## 17. Source contracts

This reference summarizes these authorities:

- [Project Glossary](../00_project/GLOSSARY.md) — canonical project terminology and commonly confused boundaries.
- [Content Architecture](CONTENT_ARCHITECTURE.md) — authored definitions versus runtime instances/presentation.
- [Content Registry Architecture](CONTENT_REGISTRY.md) — semantic lookup direction and registry responsibility boundary.
- [Content IDs](../40_content/CONTENT_IDS.md) — semantic ID format, namespace ownership and migration rules.
- [Content References](../40_content/CONTENT_REFERENCES.md) — typed semantic reference direction.
- [Generation Pipeline Interfaces](../GENERATION_PIPELINE_INTERFACES.md) — procedural identity/provenance contracts.
- [Streaming Ownership](../STREAMING_OWNERSHIP.md) — runtime/geometry partition identity and lifetime boundaries.
- [Persistence and Versioning](../PERSISTENCE_AND_VERSIONING.md) — generated-object StableIds, player-created identity category and version concepts.
- [Building System](../30_gameplay/BUILDING_SYSTEM.md) — authored build-piece definition versus persistent placed instance.
- [Item / Inventory / Crafting](../30_gameplay/ITEM_INVENTORY_CRAFTING.md) — definition, stack, persistent item-instance and world StableId separation.
- [Replaceable Presentation Boundary](PRESENTATION_BOUNDARY.md) — presentation resources/handles are not game identity.

## Review invariant

A naming choice is sound when another subsystem can tell from the field name and owning contract whether it is looking at:

```text
a semantic definition
a deterministic generated object/location
a persistent gameplay instance
a grouped stack
a compatibility revision
a canonical verification fingerprint
a spatial/procedural address
a semantic reference
a replaceable asset location
a transient runtime handle
```

If those meanings are ambiguous, qualify the name before the ambiguity spreads into persistence, gameplay or cross-system APIs.
