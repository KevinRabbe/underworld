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

A weapon is an `ItemDefinition` specialization with semantic `item.*` identity. Weapon identity is not a mesh, scene path, animation clip, character animation set, character rig profile, inventory slot, equipped Node or attack-controller branch.

```text
WeaponDefinition
  = item identity + weapon semantic requirements/bindings

ItemInstanceState / future durability state
  = mutable per-copy ownership

Equipment state
  = which owned item is equipped where

Character presentation composition
  = selected character Animation Set + Rig Profile satisfying weapon-required roles

UnderworldPlayerAttackDefinition
  = gameplay-owned attack timing, damage and hit geometry
```

Do not copy mutable durability/equipped state, concrete character presentation-pack identity or attack phase timing into the shared weapon definition.

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

At runtime a resolver selects the existing `UnderworldPlayerAttackDefinition` by semantic attack ID and returns that exact gameplay-owned definition. Adding a sword therefore does not require adding `sword` branches to the player action controller or combat resolver.

Advanced combo trees, heavy attacks and skill progression are outside WEAPON-001.

## 4. Presentation ownership and semantic requirements

A weapon may reference its replaceable **weapon presentation archetype**:

```text
presentation.archetype -> archetype.*
```

The weapon also declares semantic requirements that the active character/equipment presentation composition must satisfy:
- an attack animation role such as `animation_role.action.attack.light_01`;
- a grip socket role such as `rig_role.socket.hand.right`.

A foundational `WeaponDefinition` does **not** select a concrete character `animation_set.*` or `rig_profile.*`.

That distinction is intentional:

```text
weapon definition
  requires animation_role.action.attack.light_01
  requires rig_role.socket.hand.right

character presentation pack A
  animation_set.character.a -> resolves attack role
  rig_profile.character.a    -> resolves right-hand socket

character presentation pack B
  animation_set.character.b -> resolves same attack role
  rig_profile.character.b    -> resolves same right-hand socket
```

Both presentation packs may consume the same unchanged weapon ContentId and gameplay attack definition even when their concrete clip names, bones, sockets or scenes differ.

Weapon-family validation proves the semantic role IDs exist in the accepted role registry and that the grip role is an allowed hand socket. The later active character/equipment composition boundary owns the check that its selected Animation Set and Rig Profile can actually resolve those requirements.

## 5. Required typed references

A valid foundational weapon has two required semantic content targets:

| Role | Expected family |
| --- | --- |
| `weapon.attack_set` | `attack_set` |
| `presentation.archetype` | `archetype` |

Character `animation_set` and `rig_profile` targets are deliberately absent from weapon identity. Missing/wrong attack-set or weapon-archetype targets fail during CONTENT-005 validation. Unknown attack-animation roles and invalid/non-hand grip roles also fail during weapon-family validation.

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
4. reference the replaceable weapon presentation archetype;
5. choose accepted semantic technique/attack-animation/grip roles;
6. run CONTENT-005 and focused weapon contracts;
7. let the active character/equipment presentation later prove its current Animation Set/Rig Profile satisfy the weapon-required semantic roles;
8. let existing gameplay attack/controller code consume the resolved gameplay attack definition.

No central `match sword`, scene-path identity, character-presentation pinning or duplicated combat-resolution implementation is allowed.

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
- inventory/equipment runtime or UI;
- final weapon meshes/animations;
- character presentation-pack selection;
- enemy definitions or encounter placement;
- MAP-016/worldgen behavior.

Those systems may compose the semantic weapon contract later without redefining weapon identity.
