# Underworld Content Architecture

Status: **LOCKED architectural direction**

Underworld content must scale primarily by adding definitions, categories, capabilities, assets and compositions rather than adding special-case branches to central managers.

## Core vocabulary

### Content definition
A stable data description of one game concept, identified by a semantic content ID.

Examples:
- `item.weapon.iron_sword`
- `creature.underworld.burrower`
- `attack.sword.light_01`

Definitions contain data and references. They do not own scene-tree lifetime or runtime simulation.

### Category
A controlled hierarchical classification answering **what kind of content is this?**

Category schema IDs use the `category.*` namespace, for example `category.item.equipment.weapon.melee.sword`.

Categories may add validation requirements but should not become hidden runtime inheritance trees.

### Capability
A controlled declaration answering **what behaviors/interfaces may this content participate in?**

Capability schema IDs use the `capability.*` namespace, for example `capability.equipable`, `capability.damageable`, `capability.harvestable`, `capability.placeable` and `capability.repairable`.

Capabilities describe contracts. Runtime systems implement those contracts.

### Asset
Presentation/runtime resources referenced by definitions, such as PackedScenes, meshes, textures, AnimationLibraries, audio or VFX resources.

Asset paths are not stable content identity.

### Runtime instance
A temporary live representation created from definitions/assets and owned by runtime systems or scene trees.

Runtime Node identity must never replace semantic content identity in persistence or cross-system references.

### Content reference
A semantic link from one definition to another definition or controlled asset role.

References are validated before runtime where practical.

## Separation rule

```text
Definition data
      ↓
Registry / resolution
      ↓
Runtime systems / factories
      ↓
Runtime instances
      ↓
Presentation assets
```

Definitions must not directly own runtime managers, player Nodes, AI state, physics queries or scene lifetime.

## Classification model

Content may combine:
- one or more hierarchical category schema IDs;
- zero or more capability schema IDs;
- typed references to other definitions;
- typed asset references;
- family-specific parameter data.

Authored definitions use the full controlled IDs. Editor/tooling UIs may display shorter labels, but persisted/serialized architecture data must not depend on ambiguous shorthand.

Example:

```text
item.weapon.iron_longsword

categories:
  category.item
  category.item.equipment
  category.item.equipment.weapon
  category.item.equipment.weapon.melee
  category.item.equipment.weapon.melee.sword
  category.item.equipment.weapon.melee.sword.longsword

capabilities:
  capability.equipable
  capability.damage_dealer
  capability.repairable
  capability.parry_tool

references:
  attack_set = attack_set.sword.one_handed.basic
  animation_set = animation_set.humanoid.one_handed_sword
  visual = visual.weapon.iron_longsword
```

## Categories classify; capabilities enable participation

Do not encode every behavior in category inheritance.

A mining axe may be categorized as an axe while declaring both weapon and harvesting capabilities. This avoids classes such as `WeaponThatIsAlsoHarvestToolAndRepairable`.

## Stable identity vs files

A semantic content ID is authoritative game identity.

Bad:
```text
res://weapons/iron_sword_v3_final.tres
```
used as persistent identity.

Good:
```text
item.weapon.iron_sword
```
resolved by a content registry to its current definition/assets.

Files may move without changing game identity.

## Future registry boundary

A future `ContentRegistry` will be the authoritative resolver for semantic content IDs.

Systems should evolve toward asking for definitions by ID rather than scattering direct `load()` paths and string special cases across gameplay code.

The registry is not implemented by this documentation cycle; this document defines its boundary before implementation.

## Family rulebooks

Every scalable content family gets a rulebook defining:
- required data;
- optional data;
- allowed categories/capabilities;
- valid references;
- runtime ownership;
- persistence/versioning concerns;
- validation rules;
- forbidden patterns.

Family rulebooks compose with parent rulebooks rather than duplicating them.

Example:

```text
Item rules
  ↓
Equipment rules
  ↓
Weapon rules
  ↓
Melee weapon rules
  ↓
Sword rules
  ↓
Longsword rules
```

A longsword must satisfy every applicable parent contract.

## Scalability test

When adding the tenth or hundredth member of a content family, ask:

> Can this be expressed mostly as definitions/assets/composition, or am I adding another central special case?

Infrastructure changes are expected when introducing genuinely new mechanics. Ordinary content variation should not require rewriting central systems.

## Compatibility with procedural identity

Semantic content identity and procedural world identity are separate systems.

- Content ID answers **what kind of thing is this?**
- Stable procedural ID answers **which generated instance/location is this?**

A generated object may therefore persist both:
```text
content_id = item.resource.copper_ore
stable_world_id = <generated instance StableId>
```

Do not merge these concepts.
