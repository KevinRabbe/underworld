# Underworld Dependency Rules

Status: **LOCKED architectural direction**

This document defines allowed dependency direction between content definitions, runtime systems and assets. Its purpose is to prevent circular architecture and central-manager knowledge of every concrete content member.

## High-level direction

```text
Project rules / schemas
        ↓
Content definitions
        ↓
Content registry / resolvers
        ↓
Gameplay systems / factories
        ↓
Runtime instances
        ↓
Presentation adapters / assets
```

Runtime systems may consume definitions. Definitions must not reach upward into runtime systems.

## Allowed definition references

Typical allowed references include:

```text
WeaponDefinition
  ├─→ AttackSetDefinition
  ├─→ AnimationSetDefinition
  ├─→ AudioSetDefinition
  └─→ Visual asset role

RecipeDefinition
  ├─→ input ItemDefinitions
  └─→ output ItemDefinition

LootTableDefinition
  └─→ ItemDefinition / other loot table entries

CreatureDefinition
  ├─→ AttackSetDefinition
  ├─→ AnimationSetDefinition
  ├─→ AIProfileDefinition
  └─→ LootTableDefinition
```

References must be typed/role-specific enough that validation can explain what is missing or incompatible.

## Forbidden dependency direction

Content definitions must not directly reference:
- the live player Node;
- scene-tree managers;
- physics space state;
- loaded world chunks;
- runtime AI instances;
- current save objects;
- UI controls;
- transient instance IDs.

A definition describes content. A runtime system interprets it.

## Central-manager rule

Central managers must not grow lists such as:

```text
if weapon_id == "iron_sword":
    ...
elif weapon_id == "steel_sword":
    ...
elif weapon_id == "bone_sword":
    ...
```

Ordinary member differences belong in definitions, referenced profiles or capabilities.

A special case in infrastructure is justified only when the content introduces a genuinely new mechanic that cannot be represented by an existing contract.

## Asset dependency direction

Gameplay definitions may reference asset roles, but gameplay logic should not depend on internal scene hierarchy.

Good:
```text
RIGHT_HAND_SOCKET
ACTION_LIGHT_ATTACK_01
visual_scene
```

Bad:
```text
Skeleton3D/Bone_018/Child_4
MeshInstance3D2
animation filename hard-coded in CombatManager
```

Presentation adapters translate semantic roles into concrete rig/scene paths.

## Category and capability dependency

Categories may depend on parent categories for classification/validation inheritance.

Capabilities may define required interfaces/data roles.

Categories and capabilities must not reference runtime instances.

## Cycles

The semantic content reference graph should be acyclic by default.

Explicit recursive structures such as nested loot tables may be allowed only if their family rulebook defines cycle detection and either forbids cycles or provides safe bounded semantics.

Unknown cycles are validation errors.

## Persistence boundary

Persistent records store stable semantic content IDs and stable world-instance IDs where appropriate. They must not persist file paths, Resource memory identities or Node instance IDs as authoritative identity.

## Worldgen boundary

Deterministic world generation may select semantic content IDs/profiles as deterministic output, but it must not require live runtime scenes for world truth generation.

A generated structure hook may say:
```text
content_id = structure.ancient.shrine
```
without instantiating the shrine scene during topology generation.

## Validation requirement

Future content validation must be able to detect:
- unknown content IDs;
- incompatible reference roles;
- forbidden dependency families;
- illegal category parents;
- unsupported capabilities;
- forbidden/cyclic reference graphs where relevant.
