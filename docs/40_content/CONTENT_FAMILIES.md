# Underworld Content Family Map

Status: **DIRECTIONAL taxonomy skeleton**

This document maps the major authored content families that Underworld is expected to need. It is intentionally broader than current implementation so future systems have an architectural home before they become large.

The map is not a promise that every listed family ships, nor that no family may ever be added.

## Items

```text
Item
├─ Resource
│  ├─ Organic
│  ├─ Mineral
│  └─ Crafted Material
├─ Equipment
│  ├─ Weapon
│  │  ├─ Melee
│  │  │  ├─ Sword
│  │  │  ├─ Axe
│  │  │  ├─ Spear
│  │  │  └─ other deliberate families
│  │  └─ Ranged
│  ├─ Tool
│  ├─ Armor
│  └─ Utility Equipment
├─ Consumable
├─ Special / Quest-like Item
└─ Deployable / Placeable Item
```

These are categories/classification. Cross-cutting behaviors use capabilities.

Example: an axe can be both a melee weapon and a harvesting tool through capabilities without inventing a combined infrastructure subclass.

## World objects

```text
World Object
├─ Tree / Vegetation
├─ Rock / Geological Object
├─ Resource Node
├─ Large Deposit / Excavation Site
├─ Harvestable
├─ Container
├─ Interactable
└─ Environmental Utility / Hazard
```

Generated world-instance identity remains separate from semantic content identity.

## Characters and creatures

```text
Character / Creature
├─ Player-compatible humanoid presentation
├─ Neutral / passive creature
├─ Hostile creature
├─ Elite
└─ Boss / major encounter actor
```

Behavioral differences should compose AI profiles, attack sets, capabilities and family-specific definitions rather than one central creature switch.

## Structures

```text
Structure
├─ Generated
│  ├─ Ruin
│  ├─ Settlement
│  ├─ Mine / Infrastructure
│  ├─ Ancient / Constructed Underworld structure
│  └─ Encounter structure
└─ Player Built
   ├─ Structural piece
   ├─ Crafting station
   ├─ Storage
   ├─ Furniture
   └─ Utility
```

Generated structure definitions may be referenced by deterministic special-location hooks without requiring runtime scenes during topology generation.

## World-generation content

```text
Worldgen Content
├─ Biome / environment profile
├─ Cave / depth grammar profile
├─ Entrance profile
├─ Spawn profile
├─ Structure placement profile
├─ Special-location definition
└─ Resource/deposit placement profile
```

These definitions participate in deterministic generation only through pure-data contracts.

## Gameplay-data families

```text
Gameplay Data
├─ Attack Definition
├─ Attack Set
├─ Recipe
├─ Loot Table
├─ Status Effect
├─ AI Profile
├─ Equipment Profile
├─ Harvest Profile
└─ Spawn Profile
```

Gameplay data should be reusable across many concrete content members where appropriate.

## Presentation-data families

```text
Presentation Data
├─ Animation Set
├─ Rig Profile / Rig Mapping
├─ Audio Set
├─ VFX Set
├─ Visual Scene / Visual Profile
└─ UI/Icon presentation data
```

Presentation content must remain replaceable without changing unrelated gameplay identity.

## Rulebook roadmap

Not every family needs a detailed rulebook immediately.

Create a family rulebook when:
- implementation begins to depend on a stable contract; or
- more than a trivial number of authored members is expected; or
- multiple systems need to reference the family; or
- persistence/versioning depends on its identity.

Likely order after the meta-architecture:
1. Animation Set / Rig Profile
2. Creature/Enemy combat definitions
3. Item → Equipment → Weapon hierarchy
4. Resource/Harvest/Deposit families
5. Recipe/Loot families
6. Structures/building content
7. broader worldgen placement/spawn content
8. audio/VFX/status-effect families as their systems mature

This order may change with development needs.

## Family-growth rule

When a new subtype appears, decide whether it is:
- a category (what it is);
- a capability (what it can participate in);
- a reusable profile/definition (parameters/behavior configuration);
- or a genuinely new runtime mechanic/system.

Do not default to creating a new central code branch or inheritance class.
