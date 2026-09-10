# Item Rulebook

Status: **ITEM-001 executable base contract**

This rulebook specializes the project-wide [Content Rulebook Contract](CONTENT_RULEBOOK.md) for authored item definitions. Child item families add constraints through compositional rule extensions; they do not copy or replace this base contract.

## Purpose

An item definition describes **what an item is**. Mutable stack or per-copy state describes **what is currently true of owned units**. Containers, equipment, crafting and world pickup systems consume those concepts but are not implemented by this rulebook.

## Stable identity

Every item definition uses the semantic `item.*` ContentId family. Examples include:

```text
item.resource.wood
item.tool.stone_pickaxe
item.weapon.iron_sword
```

The ContentId is authoritative across file moves. Resource paths, runtime Nodes, scene paths, inventory slots and procedural StableIds are not item-definition identity.

For weapons, a concrete item ContentId is also **not automatically the mastery identity**. A material/tier Sword item can be a distinct item definition while still belonging to the same Sword mastery family as other Sword items. See [Weapon Mastery and Active Skills](../30_gameplay/WEAPON_MASTERY.md) and [Weapon Rulebook](WEAPON_RULEBOOK.md).

## Category contract

Every validated item declares at least one registered category in the `category.item` ancestry. An item may declare more than one compatible item category when the child rulebooks permit it, but it may not mix unrelated category roots into the base item definition.

Examples:

```text
category.item.resource
category.item.equipment.tool
category.item.equipment.weapon.melee.sword
```

## Capability contract

Capabilities remain controlled `capability.*` schemas. The base item rulebook does not require one universal capability because ordinary resources may have none. Child rules bind categories to required/forbidden capabilities where behavior participation demands it.

Examples include `capability.equipable`, `capability.harvest_tool`, `capability.damage_dealer`, `capability.consumable`, `capability.placeable`, `capability.repairable` and `capability.fuel`.

One item may legitimately compose more than one compatible gameplay capability. In particular, the project direction uses the **same authored Axe** for combat and eligible wood/resource harvesting rather than creating duplicate combat-Axe and harvest-Axe item identities.

## Common authored definition data

`ItemDefinition` owns only fields common to ordinary item authoring:

```text
ContentDefinition fields
stack_limit
unit_weight
semantic ContentReference roles
```

`stack_limit` must be at least 1. `unit_weight` must be non-negative. Exact balance values remain authored/tunable data.

Fields such as attack data, harvest power, armor values, consumable effects, mastery data or durability rules do not belong in the generic base merely because some items use them. Those belong to child definitions/profiles, gameplay-owned progression contracts and child rulebooks.

## Semantic references

Item definitions expose references through the accepted CONTENT-005 `ContentReference` boundary. Roles may target presentation archetypes, animation sets, effects or other compatible semantic content as child contracts require.

A reference declares:

```text
owning item ContentId
semantic role
semantic target ContentId
expected target family
required/optional status
```

Runtime resource paths are not semantic references. If item presentation requires runtime realization, the target archetype is realized only through the accepted ARCHETYPE-001 validation/adapter boundary.

## Mutable state ownership

Authored `ItemDefinition` Resources are shared definition data and are not mutated to represent inventory state.

`ItemStackState` stores:

```text
item ContentId
quantity
stack-compatibility mutable state
```

`ItemInstanceState` stores:

```text
item ContentId
per-copy mutable state
```

The base contract deliberately does not lock the future persistent item-instance ID encoding. Persistence identity for an individual owned copy remains separate from semantic ContentId and world StableId.

Player-owned weapon mastery is a third, separate concern: it is progression attached to the weapon family/mastery identity, not mutable state stored on every material weapon copy.

## Weapon family vs material/tier item progression

The weapon-mastery decision establishes this separation:

```text
weapon family/mastery
    = horizontal player progression

concrete weapon item/material tier
    = vertical equipment progression
```

Therefore:

- replacing an early-material Sword with a later-material Sword does not create or reset Sword mastery;
- item stats, durability, crafting cost, material and presentation may vary by concrete definition without forking mastery;
- a child weapon rule must not derive a new mastery merely from the concrete item ContentId or material name;
- save data must not duplicate the same family mastery onto each owned material variant when mastery semantically belongs to the player/family.

The exact mastery ContentIds/resources/save schema are intentionally not defined by ITEM-001; they belong to future implementation work under the owning mastery contract.

## Child rule composition

`ItemFamilyValidator` enforces this base rulebook and may host `ItemRuleExtension` implementations. A weapon, tool, armor, consumable or resource rulebook should add only its own category/capability/data/reference invariants through that extension boundary.

The validator must not become a central switch over concrete item IDs.

Weapon-specific family/mastery constraints are owned by [Weapon Rulebook](WEAPON_RULEBOOK.md), while player-facing mastery progression is owned by [Weapon Mastery and Active Skills](../30_gameplay/WEAPON_MASTERY.md).

## Runtime ownership

Gameplay item/inventory/equipment systems interpret validated definitions and mutable state. Presentation systems interpret semantic presentation roles. Content validation owns structural validity before runtime systems consume the item.

A future mastery runtime may read the active weapon's stable family association, but it must not rewrite the shared item definition to store player progress.

## Persistence and migration

Persist semantic item ContentIds plus required mutable stack/per-copy state. Do not persist Resource paths, runtime object IDs, scene paths or slot widgets as item identity. Renaming a persisted semantic ContentId is a migration.

When weapon mastery persistence is implemented, it must be persisted separately by stable family/mastery identity according to the mastery and SAVE contracts. Material/item replacement must not silently lose family mastery.

## Validation

An item is structurally valid only when:

- the semantic ContentId is a valid `item.*` ID;
- common definition data passes the base field contract;
- at least one registered declared category belongs to the `category.item` ancestry;
- declared categories/capabilities exist in the accepted schema registries;
- applicable child rule extensions pass;
- typed semantic references resolve through CONTENT-005 with the expected family;
- authored definition data remains separate from mutable stack/per-copy state.

Future mastery-specific validation is not claimed as already executable by this base rulebook.

## Forbidden patterns

Do not:

- use file paths, scene paths, runtime Nodes or inventory slots as item identity;
- mutate shared ItemDefinition Resources to store quantity, durability, mastery progress or other owned-item/player state;
- add every child-family field to one oversized ItemDefinition;
- hard-code concrete item IDs in a central manager/validator;
- create a parallel item identity, category, capability or reference registry;
- bypass CONTENT-005 before consuming required semantic references;
- collapse semantic item identity, weapon-family mastery identity, persistent item-instance identity and procedural world StableId into one ID;
- create separate combat-Axe and harvest-Axe item/mastery families merely to avoid composing capabilities;
- create separate mastery trees per material tier when the items belong to the same weapon family.

## Minimal valid example

Conceptually:

```text
content_id: item.resource.stone
family: item
categories:
  - category.item.resource
stack_limit: 64
unit_weight: 1.0
capabilities: []
references: []
```

A tool/weapon/armor/consumable/resource child definition then adds only the fields and rules owned by that child family.