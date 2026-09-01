# Underworld — First Overworld Biome

Status: **LOCKED first-biome product direction; exact balance values, final art and names not explicitly locked below remain OPEN**

This document defines the first player-facing Overworld biome as a deliberately small, self-contained learning/exploration/survival/building experience.

It is a content and progression contract, not a replacement for the accepted two-domain world architecture. The Overworld/Underworld split remains valid. The first biome simply does **not** require a cave, portal, gateway or Underworld transition in order to teach and prove the game.

## 1. Biome purpose

Biome 1 must be fun before later biome/domain systems are needed.

The player should be able to:
- explore a readable surface environment;
- gather basic natural resources;
- hunt and cook food;
- learn the fundamental combat vocabulary;
- craft a small set of useful equipment;
- build a real wooden home/structure using the final construction grammar;
- discover at least one progression resource that becomes usable only after Biome 2 unlocks.

The first biome is not a tutorial corridor and does not need a cave or portal as its payoff. It should support ordinary free exploration and settlement.

## 2. Explicit first-biome exclusions

Do not require for Biome 1:
- cave entry;
- portal/gateway traversal;
- Underworld entry;
- pickaxe;
- mining/ore progression;
- stone or metal building tiers;
- farming/planting;
- advanced food systems;
- multiple arrow tiers;
- large enemy rosters;
- weapon-content variants merely to increase item count.

The player may encounter seeds before farming exists. Seeing future progression before being able to use it is intentional.

## 3. Combat input grammar

The weapon system should stay compact rather than becoming an ability bar.

Core combat input contract:

```text
LMB = normal attack / weapon-specific normal combo
MMB = exactly one weapon-specific signature special attack
RMB = block / defensive action
```

The special attack is not automatically a generic high-damage button. It should express the weapon's identity. Exact stamina cost, timing, damage, stagger and block effectiveness remain balance work unless locked below.

## 4. Biome 1 weapon roster

The first biome targets one useful weapon of each intended type rather than multiple material/content variants:

- Sword
- Knife
- Axe
- Spear
- War Pike
- Bow
- Shield

This roster exists for the game as a whole. **Biome 1 enemies do not need to make every weapon equally effective.** Different biomes and enemy anatomies may create different favorable and unfavorable matchups.

### Spear — spacing weapon

The normal Spear is a controlled thrust/stab weapon focused on:
- reach;
- precision;
- maintaining distance;
- punishing enemies that try to close the gap.

Its normal attacks should have little forward drift compared with the War Pike. Its exact MMB special remains open, but it must reinforce spacing rather than become the War Pike dash under another name.

### War Pike — aggressive forward-pressure weapon

The War Pike is a separate weapon from the normal Spear.

Locked identity:
- **LMB:** a three-hit forward-moving thrust combo; the sequence naturally drives the player into/through pressure rather than anchoring in place;
- **MMB:** a real physical forward dash-thrust with a **high stamina cost**;
- **RMB:** block/defense under the shared combat grammar.

The MMB attack is not a teleport. It is a committed forward movement with limited correction once launched. Missing should create meaningful positional/stamina risk.

The War Pike closes distance. The Spear controls distance.

## 5. Armor scope

Biome 1 contains **two armor types/sets**.

Their exact stat identity, material naming, set bonuses and balance are not locked by this document. Do not multiply armor variants before the two first sets have a clear gameplay reason.

## 6. Crafting and stations

### Basic Workbench — required

One basic workbench is required for the first biome's primitive crafting/building loop.

It should support the authored Biome 1 recipes appropriate to wood/basic creature materials and the initial wooden building kit.

A second workbench/station may be added only if the recipe/material split genuinely justifies it. The second station is **not yet mandatory or named**.

### Cooking Rack — required

Cooking is physical/world-facing rather than only a menu conversion:

```text
hunt fox
-> obtain raw meat
-> place raw meat on Cooking Rack
-> wait
-> remove cooked meat
```

Exact burn/overcook behavior is open; Biome 1 only requires the basic raw-to-cooked loop.

## 7. Food and simple ecology

Biome 1 deliberately starts with a tiny food/ecology set.

### Berries

- directly gathered;
- directly edible;
- basic early food source.

### Fox

The fox is the primary huntable food animal for Biome 1.

Role:
- ordinary wildlife rather than a combat enemy family;
- cautious/quick enough to make hunting meaningful;
- supplies raw meat for the Cooking Rack;
- additional hide/fur output is optional and recipe-driven, not required by this lock.

### Small meerkat-like creature

Biome 1 also contains one small **meerkat-like ambient creature**.

Its primary job is ecology/atmosphere rather than becoming another required combat/resource grind. It may stand/scout, warn, dig or flee according to later behavior design.

Do not force every living creature to exist only as loot.

## 8. Seed / farming progression teaser

Exactly one early seed type may be found in Biome 1.

The player **cannot plant it during Biome 1**.

Planting/farming becomes available only after the progression condition described as **unlocking Biome 2**. The exact farming tool/station/system belongs to the later biome/progression design.

## 9. Arrow scope

Biome 1 uses **Wood Arrow** as the only required arrow type.

The initial arrow recipe should use wood as its defining material and stay intentionally simple.

Future fire/flint/bone/poison/metal/special arrow variants are not Biome 1 work and should not be designed merely to pad content breadth.

The Bow itself should be good before arrow variation is used as progression.

## 10. Wood-only building tier

Biome 1 proves the fundamental construction grammar with **wood only**.

The first piece set should provide enough shape vocabulary to build real houses and more inventive structures, while final decorative/material breadth remains small.

Minimum grammar should cover the equivalent structural functions of:
- floor/foundation surfaces;
- full and partial wall surfaces;
- door/opening;
- vertical and horizontal supports/beams;
- diagonal support;
- stairs/step traversal;
- pitched roof surfaces;
- roof joins/ridge/corners required to close ordinary roofs;
- simple boundary/gate/fence pieces where the Building system actually needs them.

The accepted global Building principles remain authoritative:
- snapping is convenience, not a prison;
- deliberate free placement/snap escape is allowed;
- near-overlap/overlap is allowed where the structural system accepts it;
- pieces may embed into terrain;
- structural support/stress remains meaningful;
- shape vocabulary matters more than cosmetic/material variety.

No stone/iron building tier is required in Biome 1.

## 11. Rootwretches — first hostile family

Biome 1's first hostile race/family is the **Rootwretches**.

Shared identity:
- roughly humanoid-sized or small/medium creatures;
- bodies formed from intertwined twisted roots, twigs and branches;
- not huge tree monsters;
- not ordinary humanoids wearing wooden equipment;
- movement and attacks should feel derived from tension, flex, rooting and deformation of their actual branch/root bodies.

The Rootwretches are original enemies. References to other survival games are useful for approximate content count or player-facing role only; **do not copy their enemy behaviors and rename them**.

### Rootwretch

The base Rootwretch is the clearest expression of the woven-body concept.

Its own body is the weapon. Limbs/branch bundles may partially unwind, extend, sweep, jab or reform during attacks rather than relying on a normal humanoid club/sword moveset.

It establishes the race's creaking, tension-driven movement language.

### Rootwretch Binder

The Binder is the most visually **walking-tree-like** Rootwretch, while remaining small/medium rather than becoming a giant.

Locked behavior:
- it can physically root itself into the terrain;
- once anchored, roots spread over a limited area and try to bind/restrict the player's movement;
- while rooted, the Binder cannot freely move;
- anchoring therefore trades mobility for area control and gives the player a punish window.

Its thicker trunk/root silhouette distinguishes it from the more tightly woven base Rootwretch without turning it into a separate giant-tree race.

### Rootwretch Snapper

The Snapper exploits the mechanical tension of bent branches.

Locked combat rhythm:

```text
load / bend / twist
-> visible + audible tension telegraph
-> extremely fast snapping release
-> recovery / re-form
```

The release can be dangerous and very fast because the load is readable beforehand. The player learns the creature's tension/sound timing rather than simply fighting a generic fast melee variant.

## 12. First-biome creature roster

Current minimal roster:

| Creature | Function |
| --- | --- |
| Rootwretch | baseline hostile woven-branch creature |
| Rootwretch Binder | rooted area-control hostile |
| Rootwretch Snapper | tension-load / snap-release hostile |
| Fox | primary huntable meat wildlife |
| Meerkat-like creature | small ambient/ecology wildlife |

Berries are the basic gathered food source.

This is enough for the first biome. Do not add boar/deer/wolf/skeleton/boss equivalents merely because another survival game has those slots.

## 13. Reference rule

Valheim and other games may be used to communicate:
- approximate content breadth;
- construction freedom;
- category examples;
- player expectation or usability references.

They are **not** behavior templates.

When creating an Underworld creature or weapon, start from this game's own physical/fantasy concept and derive behavior from that concept. Do not begin with "our version of Valheim enemy X" and rename the result.

## 14. Biome 1 success condition

The first biome succeeds when the player can spend meaningful time doing this loop without needing later systems to rescue it:

```text
explore
-> gather wood / berries
-> craft basic gear
-> hunt fox
-> cook meat
-> fight Rootwretches
-> improve equipment
-> build a wooden home/structure
-> discover future progression such as the locked seed
-> continue exploring until Biome 2 progression becomes relevant
```

The design test is simple:

> **If Biome 1 alone is enjoyable, the game's foundation is working.**

Later caves, gateways, mining, farming, new materials and the Underworld should expand that foundation rather than being required to make the first hours interesting.
