# Underworld — Item, Inventory and Crafting Architecture

Status: **LOCKED architectural direction; balance/tuning values remain OPEN**

This document defines the shared gameplay boundary for item state, containers, inventory mutation and crafting. It does **not** define concrete item-family rulebooks, recipes, progression balance, final capacity numbers or implementation classes.

Authoritative semantic content rules remain in [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md), [Content IDs](../40_content/CONTENT_IDS.md), [Categories](../40_content/CONTENT_CATEGORIES.md), [Capabilities](../40_content/CONTENT_CAPABILITIES.md), [References](../40_content/CONTENT_REFERENCES.md) and the [Content Rulebook Contract](../40_content/CONTENT_RULEBOOK.md). This document composes with those contracts rather than replacing them.

## 1. Core separation

The item system uses separate concepts for **what an item is**, **how many/stateful units are grouped together**, and **which individually persistent item this is**.

```text
ItemDefinition
    authored, stable semantic data
            |
            v
Item stack/state
    quantity + stack-relevant mutable state
            |
            +--> optional individual ItemInstance identity/state
            |
            v
Container / world representation
            |
            v
Replaceable runtime/presentation representation
```

A file path, mesh, scene, UI slot, runtime Node or array index is never authoritative item identity.

## 2. Identity model

### 2.1 ItemDefinition identity — what is this item?

An `ItemDefinition` is authored content identified by a stable semantic content ID such as:

```text
item.resource.wood
item.resource.stone
item.tool.stone_pickaxe
item.weapon.iron_sword
```

The semantic ID is the durable identity of the **definition**, not one owned copy of that item.

Definitions may contain or reference classification, capabilities, base parameters, presentation roles and family-specific data. Runtime systems resolve them through the content-definition boundary rather than branching on concrete file paths.

See [Content IDs](../40_content/CONTENT_IDS.md) and [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md).

### 2.2 Stack state — how much compatible state is grouped together?

Fungible resources should use lightweight stack state rather than allocating a persistent ID to every unit.

Conceptually:

```text
ItemStackState
- semantic item content ID
- quantity
- only mutable state required to determine stack compatibility
```

Example: 40 ordinary units of `item.resource.wood` may be one stack. The architecture does not require 40 persistent item-instance IDs.

Items may stack only when their state is compatible under the applicable item-family rules. Exact stack limits and compatibility fields are future rulebook/balance decisions.

### 2.3 Individual persistent item instance — which stateful owned item is this?

Use individual persistent item-instance identity only when one copy must retain state independently from otherwise equivalent copies.

Potential future reasons include:

```text
durability
individual modifiers
customization
quality/material state when individually mutable
unique history/name where gameplay requires it
other persistent per-copy state
```

The exact item-instance ID format is intentionally open. It must be a persistence-safe identity category separate from:

- semantic content IDs;
- procedural world `StableId`s;
- runtime Node/Resource instance IDs;
- inventory slot indexes.

A generated world object may separately have a procedural `StableId`; that does not automatically make the contained/owned item instance use the same identity scheme.

### Identity rule

```text
semantic content ID = what definition is this?
stack state         = what compatible quantity/state is grouped?
item instance ID    = which individually persistent owned copy is this?
world StableId      = which generated world object/location is this?
```

Do not collapse these identities.

## 3. Item behavior uses composition

Items must not grow into either:

1. a deep runtime inheritance tree for every combination; or
2. one giant `Item` class containing dozens of unrelated optional fields.

Use validated definition composition instead:

```text
ItemDefinition
+ categories
+ capabilities
+ typed profile/reference data
```

Examples of capability direction already established by the project include `capability.equipable`, `capability.harvest_tool`, `capability.damage_dealer`, `capability.placeable`, `capability.consumable`, `capability.repairable` and `capability.fuel`.

Capabilities state which gameplay contracts an item may participate in. Runtime systems implement those contracts. See [Content Capabilities](../40_content/CONTENT_CAPABILITIES.md).

Future ITEM-001, WEAPON-001 and child rulebooks remain responsible for family-specific validity. This architecture does not pre-implement those rulebooks.

## 4. One universal container contract

Player inventory, equipment, storage and processing inventories should share one reusable container model rather than separate mutation/storage systems.

Conceptually a container owns:

```text
ordered or addressed slots where applicable
contained stack/instance state
capacity policy
item-acceptance rules
transaction boundary
```

Container roles may include:

```text
player inventory
equipment slots
chest/storage
crafting inputs
crafting outputs
furnace/processor inputs and outputs
trade/transfer buffers where needed
```

The contract may support specialized acceptance rules without changing the underlying ownership model.

### Equipment is a specialized container

Equipment uses the same item-state/container foundation with additional slot compatibility and gameplay binding rules.

For example, a hand slot may accept definitions satisfying an equipment contract. The equipment system must not identify a sword by its visual scene path or by a concrete mesh hierarchy.

Presentation binding occurs after logical equipment state has been resolved.

## 5. Capacity model

The initial architecture supports both:

```text
slot capacity
+ weight capacity
```

Their exact values, formulas, UI treatment and balance are **not locked here**.

Container types may configure which capacity constraints apply. Changing balance values must not require replacing the item identity or transaction architecture.

## 6. Atomic inventory transactions

Mutations that affect one or more containers must use an atomic transaction boundary.

Relevant operations include:

```text
crafting
building-cost consumption
loot pickup/transfer
repair
trade
splitting/merging stacks
moving equipment
processing inputs/outputs
```

Conceptual flow:

```text
request mutation
    |
validate definitions, quantities, capacity and compatibility
    |
produce complete mutation plan
    |
commit all changes atomically
    |
notify/update runtime views
```

If validation or commit cannot complete, the operation must not leave a partially applied inventory state.

Example failure to avoid:

```text
remove 20 wood
remove 10 stone -> fails
result: wood already lost
```

The transaction layer owns state mutation consistency. UI, crafting stations and world objects request mutations; they do not each implement their own direct container-edit sequence.

## 7. Recipe definitions

Recipes are authored data definitions, with semantic recipe identity such as the existing `recipe.*` namespace direction.

A recipe may conceptually declare:

```text
inputs
outputs
required crafting capability/context
processing/timing metadata where applicable
other family-specific constraints
```

An ingredient requirement may target:

- an exact semantic content definition; or
- a validated compatible category/tag/schema concept where substitution is intentionally allowed.

The exact ingredient schema is a later content/rulebook decision. Recipe resolution must not depend on filenames, display names or scene names.

Building costs and crafting recipes consume the same underlying semantic item/resource definitions rather than creating a second resource-ID system.

## 8. Crafting-station capabilities

A recipe must not depend on a concrete scene name such as:

```text
res://scenes/workbench_v2.tscn
```

Instead, a crafting station exposes semantic capabilities/context that recipes can require.

Conceptually:

```text
recipe requirement
    -> station capability/profile
    -> compatible runtime station may satisfy it
```

This permits alternate visuals, upgraded stations or multiple compatible station types without rewriting recipe identity.

### Hand crafting, station crafting and timed processing

These share the same recipe and transaction foundation.

```text
hand crafting
    = recipe resolved with actor/self-provided crafting context

station crafting
    = recipe resolved with station-provided capabilities

timed processing
    = recipe/transaction foundation + processing lifecycle/time owner
```

Timed processing may reserve/consume/produce state according to its later rulebook, but it must not become a separate unrelated inventory system.

## 9. Dropped and world items

Dropping an item changes its **owner/location representation**, not its semantic definition.

A dropped/world item retains the logical state required to reconstruct its stack or individual instance.

Conceptually:

```text
container item state
    -> drop/transfer transaction
    -> world-owned logical item state
    -> runtime pickup representation
```

Picking it up performs the inverse ownership transfer through a transaction.

The visible pickup mesh/scene is replaceable presentation. Replacing it must not change semantic item identity, quantity, durability or other logical item state.

Procedurally generated world pickups may also carry the appropriate generated-world `StableId` for world persistence. That world identity remains separate from the item definition and any individually persistent owned-item identity.

## 10. Persistence and migration

Persistent inventory/container state stores semantic identity plus required mutable state, not runtime representation.

Conceptually persisted item data may include:

```text
semantic content ID
quantity
stack-relevant state
optional persistent item-instance ID
required per-instance mutable state
container/ownership state where the save contract requires it
```

Do not persist as authoritative item identity:

```text
UI slot widget
mesh/material path
PackedScene path
Node instance ID
Resource memory identity
runtime array index
```

Persisted definition IDs and item-state schemas require explicit version/migration handling when incompatible changes occur. A renamed persistent content ID is a migration, not a cosmetic refactor.

World persistence rules remain governed by [Persistence and Generator Versioning](../PERSISTENCE_AND_VERSIONING.md); generated world `StableId`s remain a different identity system.

## 11. Integration boundaries

| System | Item/inventory boundary |
| --- | --- |
| **Combat** | Reads equipped item definitions/capabilities and mutable state such as durability where applicable. Combat does not own inventory persistence or presentation paths. |
| **Building** | Requests atomic consumption of the same semantic item/resource definitions used by inventory and crafting. Building must not invent a parallel material-ID system. |
| **Crafting/processing** | Resolves recipe definitions and capability context, then requests atomic container transactions. |
| **Loot** | Produces semantic item/stack/instance state and transfers it through the shared container transaction boundary. Loot tables do not directly edit UI slots. |
| **Persistence** | Owns serialized durable state and migrations; inventory/runtime containers expose serializable logical state rather than Nodes/assets. |
| **World runtime** | Owns live dropped/pickup representation and world-location lifecycle, while preserving the logical item state being represented. |
| **Presentation** | Resolves visual/audio/animation roles for an item or equipped state. It may be replaced without changing logical identity. |
| **Content** | Owns authored definitions, categories, capabilities, typed references and recipe definitions. Runtime mutation does not rewrite authored definitions. |

Dependency direction for content/runtime separation is further defined by [Dependency Rules](../10_architecture/DEPENDENCY_RULES.md).

## 12. Future quality, material and modifier systems

The architecture must leave room for future systems such as:

```text
quality grades
materials
crafted variants
modifiers/affixes
repair state
customization
```

These may add definition references, stack-compatibility state or individual instance state as appropriate.

They do **not** require random rarity to be a universal assumption of every item. Ordinary resources and simple items remain simple when they do not need individualized state.

A future system should answer first:

> Does this property belong to the authored definition, the stack, or one persistent item instance?

before adding storage or identity fields.

## 13. Ownership invariants

1. Semantic content ID identifies the item definition, not an owned copy or runtime Node.
2. Fungible quantities do not require one persistent ID per unit.
3. Individually stateful items may use a separate persistent item-instance identity.
4. Procedural world `StableId` and owned item-instance identity remain separate concepts.
5. Inventory, equipment, storage and processing use one shared container/transaction foundation.
6. Cross-container mutations are atomic; partial consumption is not valid state.
7. Equipment is specialized container state, not presentation hierarchy state.
8. Recipes are data definitions and station requirements are capability/context based.
9. Hand crafting, station crafting and timed processing compose the same recipe/transaction foundation.
10. Building and crafting consume the same semantic item/resource definitions.
11. Dropped-world representation may change without changing logical item state.
12. Persistent state never depends on UI slots, mesh paths, scene paths or runtime Node identity.
13. Incompatible persisted definition/state changes require explicit migration/version handling.
14. Item behavior grows through validated composition/rulebooks rather than ID-specific central-manager branches.

## 14. Intentionally open

This architecture does not lock:

- stack-size limits;
- carry-weight limits or formulas;
- inventory grid/list UI;
- exact slot counts;
- exact persistent item-instance ID encoding;
- exact recipe ingredient schema;
- recipe balance or progression gates;
- crafting/processing durations;
- durability formulas;
- quality/material/modifier design;
- trade/economy balance;
- concrete implementation class names.

Those decisions may evolve without replacing the ownership, identity, container and transaction boundaries above.
