# Underworld — Weapon Rulebook

Status: **LOCKED foundational weapon-family contract; balance values and advanced techniques remain OPEN**

This rulebook defines the authored boundary for reusable weapons. It extends the accepted Item rulebook rather than creating a second item identity or inventory system.

Authoritative parent contracts:
- [Item Rulebook](ITEM_RULEBOOK.md)
- [Item, Inventory and Crafting Architecture](../30_gameplay/ITEM_INVENTORY_CRAFTING.md)
- [Content References](CONTENT_REFERENCES.md)
- [Content Categories](CONTENT_CATEGORIES.md)
- [Content Capabilities](CONTENT_CAPABILITIES.md)
- [Replaceable Presentation Boundary](../10_architecture/PRESENTATION_BOUNDARY.md)
- [Player Attack Contract](../PLAYER_ATTACK_CONTRACT.md)

## 1. Identity and ownership

A weapon is an `ItemDefinition` specialization with semantic `item.*` identity. Weapon identity is not a mesh, scene path, animation clip, inventory slot, equipped Node or attack-controller branch.

```text
WeaponDefinition
  = item identity + weapon semantic bindings

ItemInstanceState / future durability state
  = mutable per-copy ownership

Equipment state
  = which owned item is equipped where

Presentation
  = replaceable archetype/animation/rig realization

UnderworldPlayerAttackDefinition
  = gameplay-owned attack timing, damage and hit geometry
```

Do not copy mutable durability/equipped state or attack phase timing into the shared weapon definition.

## 2. Weapon classification and capabilities

Weapon definitions must declare a category under:

```text
category.item.equipment.weapon
```

Concrete descendants such as melee/sword/axe are classification, not central runtime switches.

Every weapon must provide:

```text
capability.equipable
capability.damage_dealer
```

Cross-cutting behavior composes normally. An axe may additionally provide `capability.harvest_tool`; that does not require a combined weapon-harvesting manager. Conversely, a pickaxe may remain an equipment/tool item with harvesting and damage capabilities without being forced into the weapon-definition subtype merely because it can deal damage.

## 3. Semantic combat binding

A weapon references an authored `attack_set.*` definition through role:

```text
weapon.attack_set
```

A weapon attack set maps semantic technique roles such as:

```text
weapon_technique.light.primary
```

to gameplay attack IDs. It does not own startup/active/recovery duration, damage, reach or hit geometry.

At runtime a resolver selects the existing `UnderworldPlayerAttackDefinition` by the semantic attack ID and returns that exact gameplay-owned definition. Adding a sword therefore does not require adding `sword` branches to the player action controller or combat resolver.

Advanced combo trees, heavy attacks and skill progression are outside WEAPON-001.

## 4. Presentation and equipment roles

Weapons reference presentation definitions semantically:

```text
presentation.archetype     -> archetype.*
presentation.animation_set -> animation_set.*
presentation.rig_profile   -> rig_profile.*
```

The weapon also declares:
- a semantic attack animation role such as `animation_role.action.attack.light_01`;
- a semantic grip socket role such as `rig_role.socket.hand.right`.

Concrete animation clip names, bone names, socket Node names and scene/resource paths remain owned by the referenced presentation definitions. The foundational weapon grip must resolve to an accepted hand-socket role.

The referenced Animation Set must be compatible with the referenced Rig Profile and must resolve the weapon's attack-animation role. The Rig Profile must resolve the weapon's grip role to a socket binding.

## 5. Required typed references

A valid foundational weapon has all four required semantic targets:

| Role | Expected family |
| --- | --- |
| `weapon.attack_set` | `attack_set` |
| `presentation.archetype` | `archetype` |
| `presentation.animation_set` | `animation_set` |
| `presentation.rig_profile` | `rig_profile` |

Missing targets, wrong target families and incompatible concrete definitions fail during CONTENT-005 validation rather than becoming runtime surprises.

## 6. Fail-closed child-family rule

Weapon is an ITEM-001 child family. `ItemFamilyValidator` remains the semantic `item` family authority and executes the weapon rule extension.

Validation selects the weapon rule when either:
- the definition is a concrete `WeaponDefinition`; or
- an ordinary `ItemDefinition` declares a category under `category.item.equipment.weapon`.

Therefore a base `ItemDefinition` cannot bypass weapon rules merely by declaring a weapon category. It fails explicitly because weapon-category content must use `WeaponDefinition`.

## 7. Minimal sword authoring flow

A new simple sword should require only authored content plus existing generic registries/resolvers:

1. create a `WeaponDefinition` with stable `item.weapon.*` ID;
2. declare the weapon category and required capabilities;
3. reference a compatible `attack_set.*`;
4. reference archetype, animation set and rig profile content;
5. choose accepted semantic technique/animation/grip roles;
6. run CONTENT-005 and focused weapon contracts;
7. let existing gameplay attack/controller code consume the resolved gameplay attack definition.

No central `match sword`, scene-path identity or duplicated combat-resolution implementation is allowed.

## 8. Persistence and mutable state

The accepted Item architecture remains authoritative:
- shared weapon definition = immutable authored semantic data;
- item-instance state = mutable per-copy data when required;
- equipment/container state = ownership/location/equipped relationship;
- world `StableId` = generated world-object identity where applicable;
- runtime Node/Resource identity = transient implementation detail.

WEAPON-001 does not define a final persistent item-instance ID encoding or durability economy.

## 9. Explicit exclusions

This foundational rulebook does not implement:
- combo trees, heavy attacks, skill trees or weapon progression;
- a new combat resolver or attack-phase controller;
- final durability/balance values;
- inventory/equipment UI;
- final weapon meshes/animations;
- enemy definitions or encounter placement;
- MAP-016/worldgen behavior.

Those systems may compose the semantic weapon contract later without redefining weapon identity.