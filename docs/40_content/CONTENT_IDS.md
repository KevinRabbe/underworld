# Content ID Rules

Status: **LOCKED identity contract**

Semantic content IDs identify what a game concept is. They are independent from documentation numbering, file paths, runtime Nodes and procedural world-instance IDs.

## Format

Use lowercase dot-separated semantic IDs.

Examples:
```text
item.resource.wood
item.weapon.iron_sword
item.tool.stone_pickaxe
creature.underworld.burrower
attack.sword.light_01
animation_set.humanoid.one_handed_sword
rig_profile.humanoid.prototype
visual.weapon.iron_sword
recipe.weapon.iron_sword
structure.surface.ruined_hut
```

Recommended token characters:
- `a-z`
- `0-9`
- `_` inside semantic tokens when needed
- `.` between hierarchy tokens

Do not use whitespace, display names, localized strings or filesystem separators.

## Stability

Once persistent saves or authored references depend on a content ID, treat it as permanent identity.

Display names, descriptions, file locations, visuals and balance values may change without changing the ID.

Renaming a persisted content ID is a migration, not a cosmetic refactor.

## What IDs are not

Content IDs are not:
- documentation numbers such as `40_`;
- prototype milestone versions;
- Godot Resource paths;
- scene paths;
- procedural StableIds;
- array indexes;
- database auto-increment IDs exposed as game identity.

## Namespace ownership

The leading namespace identifies the broad semantic content family.

Initial directional namespaces:
```text
item.*
creature.*
structure.*
attack.*
attack_set.*
animation_set.*
rig_profile.*
visual.*
audio_set.*
vfx_set.*
recipe.*
loot_table.*
ai_profile.*
biome.*
spawn_profile.*
status_effect.*
```

New top-level content namespaces require architecture review rather than being invented casually.

## Schema identifiers are separate

Some controlled vocabularies also use semantic dot-separated IDs but identify schema concepts rather than authored content definitions.

Examples:
```text
category.item.equipment.weapon.melee.sword
capability.equipable
animation_role.action.parry
rig_role.socket.hand.right
```

These obey the same clarity/stability discipline but are resolved by their respective category/capability/role schemas, not as ordinary content definitions.

Do not confuse:
```text
animation_set.humanoid.prototype
```
(an authored content definition)
with:
```text
animation_role.action.parry
```
(a controlled semantic role used inside animation-set definitions).

Likewise:
```text
rig_profile.humanoid.prototype
```
is an authored rig-profile definition, while:
```text
rig_role.socket.hand.right
```
is a controlled role that a rig profile maps to a concrete skeleton/socket.

## Hierarchy is semantic, not class inheritance

`item.weapon.iron_sword` communicates classification/ownership but does not require one runtime class per ID token.

Do not make content ID parsing the primary gameplay behavior system. Use categories, capabilities and typed definitions for behavior contracts.

## File-name relationship

Files may mirror IDs for authoring convenience, but paths are replaceable.

Example:
```text
content/items/weapons/iron_sword.tres
```
may currently define:
```text
item.weapon.iron_sword
```

Moving the file must not change the semantic ID.

## Aliases and migrations

If an ID must change after release/persistence dependency:
1. record the old ID;
2. provide an explicit migration/alias strategy;
3. update references transactionally;
4. validate that no unresolved old IDs remain;
5. do not silently reuse the old ID for different content.

## Duplicate IDs

Two authored definitions may never claim the same semantic content ID in one compatible content manifest.

Duplicate content IDs are hard validation errors.

## Generated instances

A generated instance may combine semantic and instance identity:
```text
content_id: item.resource.copper_ore
world_instance_id: sid1:...
```

The content ID tells systems what the object is. The world StableId tells persistence which generated instance it is.
