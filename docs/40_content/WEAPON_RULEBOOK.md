# Underworld — Weapon Rulebook

Status: **LOCKED foundational weapon-family contract; balance values, mastery implementation schema and advanced techniques remain OPEN**

This rulebook defines the authored boundary for reusable weapons. It extends the accepted Item rulebook rather than creating a second item identity or inventory system.

Authoritative parent/companion contracts:
- [Item Rulebook](ITEM_RULEBOOK.md)
- [Item, Inventory and Crafting Architecture](../30_gameplay/ITEM_INVENTORY_CRAFTING.md)
- [Weapon Mastery and Active Skills](../30_gameplay/WEAPON_MASTERY.md)
- [ADR-002 — Weapon Mastery and Active Skills](../00_project/ADR-002_WEAPON_MASTERY_AND_ACTIVE_SKILLS.md)
- [Content References](CONTENT_REFERENCES.md)
- [Content Categories](CONTENT_CATEGORIES.md)
- [Content Capabilities](CONTENT_CAPABILITIES.md)
- [Replaceable Presentation Boundary](../10_architecture/PRESENTATION_BOUNDARY.md)
- [Player Attack Contract](../PLAYER_ATTACK_CONTRACT.md)

## 1. Identity and ownership

A weapon is an `ItemDefinition` specialization with semantic `item.*` identity. Weapon identity is not a mesh, scene path, animation clip, character animation set, character rig profile, inventory slot, equipped Node, mastery level or attack-controller branch.

```text
WeaponDefinition
  = item identity + weapon semantic requirements/bindings

Weapon family
  = stable gameplay family used by mastery/progression

ItemInstanceState / future durability state
  = mutable per-copy ownership

Equipment state
  = which owned item is equipped where

Character presentation composition
  = selected character Animation Set + Rig Profile satisfying weapon-required roles

UnderworldPlayerAttackDefinition
  = gameplay-owned attack timing, damage and hit geometry

Weapon mastery state
  = player-owned progression for a weapon family
```

Do not copy mutable durability/equipped state, player mastery progress, concrete character presentation-pack identity or attack phase timing into the shared weapon definition.

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

Cross-cutting behavior composes normally. An Axe may additionally provide `capability.harvest_tool`; that does not require a combined weapon-harvesting manager. The project direction is specifically to use the **same authored Axe** for combat and eligible wood/resource harvesting rather than creating separate `combat axe` and `harvest axe` items/masteries for convenience.

Conversely, a pickaxe may remain an equipment/tool item with harvesting and damage capabilities without being forced into the weapon-definition subtype merely because it can deal damage.

## 3. Weapon family and mastery relationship

Weapon mastery belongs to a **weapon family**, not to an individual material/tier item definition.

Conceptually:

```text
Sword family / Sword mastery
    +-- material-tier Sword item A
    +-- material-tier Sword item B
    +-- material-tier Sword item C
```

Changing material/tier inside the same family must not create a second mastery or reset player progression. Material progression is item/equipment progression; mastery is family progression.

The exact resource field, ContentId namespace and implementation schema that bind a `WeaponDefinition` to a mastery family remain **TBD** until mastery implementation work is authorized. Do not invent that schema inside unrelated code now.

Current first-biome mastery families are:

- Sword;
- Knife;
- Axe;
- Spear;
- War Pike;
- Bow.

Shield is **not currently a standalone weapon mastery family**. Current direction is skill-driven defensive Shield gameplay. Exact Shield equipment/off-hand/hand-occupancy/pairing rules remain product-open; do not infer them from genre convention.

Future/proposed families such as Greatsword, Gauntlets & Greaves and Life Staff remain outside the current first-biome roster. See [Weapon Mastery and Active Skills](../30_gameplay/WEAPON_MASTERY.md).

## 4. Semantic combat binding

A weapon references an authored `attack_set.*` definition through role:

```text
weapon.attack_set
```

A foundational weapon attack set maps semantic technique roles such as:

```text
weapon_technique.light.primary
```

to gameplay attack IDs. It does not own startup/active/recovery duration, damage, reach or hit geometry.

At runtime a resolver selects the existing `UnderworldPlayerAttackDefinition` by semantic attack ID and returns that exact gameplay-owned definition. Adding a Sword therefore does not require adding `sword` branches to the player action controller or combat resolver.

Mastery-selected active skills must compose with this data-driven execution architecture. A skill that attacks, blocks, moves, heals or applies a status must resolve through its appropriate gameplay authority; UI/input code must not directly apply damage/effects.

The **old exactly-one-signature-special-per-weapon model is superseded by ADR-002**. The target product model supports multiple authored active-skill options per family with at most three selected/equipped active skills. Exact skill-definition schema and technique vocabulary remain open until implementation requires them.

## 5. Preserved family identity constraints

Mastery must deepen a weapon family without erasing its core mechanical identity.

Current established constraints are:

- **Spear**: spacing/reach/precision; controlled thrusts and minimal unnecessary forward drift. Do not make it a slower War Pike.
- **War Pike**: aggressive forward pressure; established advancing three-hit Primary concept; moving techniques use real collision-aware Player movement and never teleport.
- **Bow**: player-skill-first draw/release and aiming; mastery must not replace aim/lead/drop/release execution with automatic targeting.
- **Axe**: one canonical authored family composes combat and eligible harvesting.
- weapon diversity is game-wide; natural favorable/unfavorable enemy matchups are valid and do not require every biome/enemy family to make every weapon equally efficient.

Exact Sword/Knife active-skill mechanics, exact skill lists for every family and balance values remain open.

## 6. Presentation ownership and semantic requirements

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

Mastery branch/skill UI labels and weapon art are presentation of semantic gameplay state; neither becomes mastery identity.

## 7. Required typed references

A valid foundational weapon currently has two required semantic content targets:

| Role | Expected family |
| --- | --- |
| `weapon.attack_set` | `attack_set` |
| `presentation.archetype` | `archetype` |

Character `animation_set` and `rig_profile` targets are deliberately absent from weapon identity. Missing/wrong attack-set or weapon-archetype targets fail during CONTENT-005 validation. Unknown attack-animation roles and invalid/non-hand grip roles also fail during weapon-family validation.

This table describes the **currently implemented foundational schema**. It does not claim that future mastery/skill references are already implemented or validated.

## 8. Fail-closed child-family rule

Weapon is an ITEM-001 child family. `ItemFamilyValidator` remains the semantic `item` family authority and executes the weapon rule extension.

Validation selects the weapon rule when either:
- the definition is a concrete `WeaponDefinition`; or
- an ordinary `ItemDefinition` declares a category under `category.item.equipment.weapon`.

Therefore a base `ItemDefinition` cannot bypass weapon rules merely by declaring a weapon category. It fails explicitly because weapon-category content must use `WeaponDefinition`.

When mastery is implemented, family/mastery references must likewise fail closed if required semantic identities are absent or incompatible. Do not silently derive mastery from display names, material strings or file paths.

## 9. Minimal weapon authoring flow

A new simple material/tier weapon should require only authored content plus existing generic registries/resolvers:

1. create a `WeaponDefinition` with stable `item.weapon.*` ID;
2. declare the weapon category and required capabilities;
3. reference a compatible `attack_set.*`;
4. reference the replaceable weapon presentation archetype;
5. choose accepted semantic technique/attack-animation/grip roles;
6. associate the item with its stable weapon family when the mastery schema exists;
7. run CONTENT-005 and focused weapon contracts;
8. let the active character/equipment presentation later prove its current Animation Set/Rig Profile satisfy the weapon-required semantic roles;
9. let existing gameplay attack/controller code consume resolved gameplay attack definitions.

Adding a higher-material Sword must extend the Sword equipment progression, not create `iron_sword_mastery`, `steel_sword_mastery`, etc.

No central `match sword`, scene-path identity, character-presentation pinning or duplicated combat-resolution implementation is allowed.

## 10. Persistence and mutable state

The accepted Item architecture remains authoritative:
- shared weapon definition = immutable authored semantic data;
- item-instance state = mutable per-copy data when required;
- equipment/container state = ownership/location/equipped relationship;
- player mastery state = persistent progression keyed by stable family/mastery identity when implemented;
- world `StableId` = generated world-object identity where applicable;
- runtime Node/Resource identity = transient implementation detail.

Mastery progress must not be keyed to a specific material item ID when the progress belongs to the family. Exact mastery save schema/versioning remains open and must follow the persistence/migration contracts.

WEAPON-001 still does not define a final persistent item-instance ID encoding or durability economy.

## 11. Explicit exclusions / open implementation work

This foundational rulebook does not itself implement:
- mastery runtime/state resources;
- XP curves, mastery level cap or point cadence;
- exact active-skill/passive node lists;
- final skill damage/cost/cooldown values;
- final physical input bindings;
- Shield equipment slot/pairing/hand-occupancy rules;
- a new combat resolver or attack-phase controller;
- final durability/balance values;
- inventory/equipment runtime or UI;
- final weapon meshes/animations;
- character presentation-pack selection;
- enemy definitions or encounter placement;
- MAP-016/worldgen behavior.

Those systems may compose the semantic weapon contract later without redefining weapon identity, family mastery ownership or the three-active-skill product limit.