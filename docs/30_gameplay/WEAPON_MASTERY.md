# Underworld — Weapon Mastery and Active Skills

Status: **LOCKED product direction; exact skills, tuning, input bindings and implementation schema remain OPEN**

This document owns the player-facing weapon-mastery progression model. It composes with the authored weapon contract in [`../40_content/WEAPON_RULEBOOK.md`](../40_content/WEAPON_RULEBOOK.md) and the attack lifecycle in [`../PLAYER_ATTACK_CONTRACT.md`](../PLAYER_ATTACK_CONTRACT.md).

The governing supersession decision is [`../00_project/ADR-002_WEAPON_MASTERY_AND_ACTIVE_SKILLS.md`](../00_project/ADR-002_WEAPON_MASTERY_AND_ACTIVE_SKILLS.md).

## 1. Core rule

Weapon mastery belongs to the **weapon family**, not to one material/tier item.

```text
SWORD MASTERY
    |
    +-- early-material Sword
    +-- later-material Sword
    +-- higher-tier Sword
    +-- future authored Sword variants that still belong to the Sword family
```

Upgrading or replacing a weapon with another item in the same family does not create a new mastery and does not reset family mastery.

This produces two distinct progression axes:

```text
horizontal progression = weapon mastery / chosen skills / passives / specialization
vertical progression   = equipment material/tier/base item power
```

Material/tier progression may change stats, crafting requirements, durability, appearance or other item-owned properties. It must not silently fork the family into a new mastery tree.

## 2. Active-skill model

The previous design of **exactly one signature special per weapon** is superseded.

The target model is:

- each supported weapon family owns a mastery progression;
- a weapon family may offer multiple active skills;
- the player may equip/select **at most three active skills for the currently used weapon family**;
- mastery also contains meaningful passive choices;
- each significant weapon family has **two specialization branches**;
- the same family mastery continues across material progression.

This is an action-combat system, not an MMO hotbar. The three selected weapon skills are the bounded ability budget for the weapon. Exact physical buttons/keys are intentionally not locked here; input actions must remain semantically mapped so bindings can change without redefining weapon content.

The old one-special model may remain visible in historical issues or prototype implementation until migration work occurs. It is no longer the target product design.

## 3. Mastery progression

Using a weapon family should advance that family rather than a specific material instance.

Mastery XP should reward **meaningful family use**, not only final-hit kills. Eligible contribution may include successful attacks and, for families whose identity includes defense, valid defensive execution. Exact XP sources, anti-farming rules, level cap, XP curve, point cadence and respec rules remain **TBD** until authored and playtested.

A material upgrade must preserve the player's existing family progression.

Conceptually:

```text
player mastery state
    sword -> mastery progress + unlocked choices
    axe   -> mastery progress + unlocked choices
    bow   -> mastery progress + unlocked choices

owned/equipped item
    item.weapon.<material>_sword -> family: sword
```

The exact persistent schema and semantic IDs are implementation decisions and are not created by this document.

## 4. Current weapon mastery families

The current first-biome weapon-family direction is:

| Family | Current role direction | Provisional mastery branches |
| --- | --- | --- |
| **Sword** | versatile melee; offensive and defensive specialization | **Swordmaster / Defender** |
| **Knife** | fast close-range precision/mobility | **Predator / Duelist** |
| **Axe** | committed melee with strong chopping identity; same authored Axe also performs eligible wood harvesting | **Executioner / Reaver** |
| **Spear** | spacing, reach, controlled thrusts and tip precision | **Hunter / Sentinel** |
| **War Pike** | aggressive forward pressure and physical advancing attacks | **Assault / Warden** |
| **Bow** | player-skill-first draw/release ranged weapon | **Marksman / Ranger** |

The branch names are **provisional labels**. They may change later without changing the two-branch mastery architecture.

### Sword

The family must support meaningful offensive and defensive build expression. Exact Primary chain, active skills, passives and defensive technique details remain TBD.

### Knife

The family should remain fast and close-range rather than being normalized against every enemy. Natural poor matchups are allowed. Exact active skills and passives remain TBD.

### Axe

One canonical authored Axe family serves both combat and eligible wood/resource harvesting. Do not create separate combat-Axe and harvesting-Axe masteries or duplicate items merely to simplify dispatch.

### Spear

Spear identity is **keep enemies away / control spacing**. It favors reach, precision and controlled thrusts with minimal unnecessary forward drift. Do not turn it into a slower War Pike.

### War Pike

War Pike identity is **close distance / drive through enemies**. The established advancing three-hit Primary concept remains part of the family identity. Physical forward movement must remain collision-aware and must never be teleportation.

The old dash-thrust signature-special concept may be re-authored as one candidate active skill under the new system; its exact final skill design, cost and unlock location remain TBD.

### Bow

Bow remains execution-driven. Hold/release draw behavior, aim, lead/drop judgment and release timing remain player-owned mechanics rather than mastery-driven auto-aim. The exact active-skill set remains TBD.

## 5. Shield direction

Shield is **not currently a standalone weapon mastery family**.

Current product direction is to express Shield gameplay through **defensive skill/technique choices** and compatible defensive equipment presentation rather than giving Shield its own independent weapon mastery tree.

The following remain intentionally **TBD** and must not be inferred from genre convention:

- whether a Shield occupies a dedicated equipment/off-hand slot;
- which weapon families may use a Shield;
- one-hand/two-hand occupancy rules;
- whether a Shield is required by specific defensive skills or merely changes their presentation/effect;
- exact block/parry/guard mechanics and their interaction with mastery;
- loadout and switching UX.

Until those decisions are made, documentation and code must not claim that Bow, Spear, War Pike or any other family can or cannot pair with a Shield.

## 6. Weapon matchup philosophy

Weapon diversity is game-wide. One biome or enemy family does not need to make every weapon equally efficient.

Natural favorable and unfavorable matchups are allowed when they support readable weapon identity. For example, the Axe may naturally be effective against woody enemies while Knife is less efficient against them. Do not fabricate enemies or flatten weapon mechanics solely to equalize every first-biome matchup.

## 7. Future/proposed weapon families

The following are **future/proposed**, not part of the current first-biome mastery roster:

| Family | Provisional branches | Status |
| --- | --- | --- |
| **Greatsword** | **Onslaught / Bulwark** | future/proposed |
| **Gauntlets & Greaves** | **Striker / Breaker** | future/proposed |
| **Life Staff** | **Restoration / Sanctuary** | future/proposed |

Life Staff is a future direction for healing/support play and enables a low-damage, high-survivability Sword + Life Staff hybrid when the broader loadout and attribute systems eventually support it.

For future cross-weapon synergy, prefer shared semantic statuses over hard-coded pair-specific rules. `Regeneration`, `Ward` and `Grace` are current **proposed** status concepts for Life Staff/support design, not yet executable schemas or locked balance content.

## 8. Authoring/architecture boundary

Weapon family, mastery progression, item tier and runtime attack execution are separate concerns:

```text
Weapon family
    -> owns player mastery relationship and family identity

Weapon item definition/material variant
    -> owns concrete item identity, material/tier/stat/presentation data

Mastery tree
    -> owns unlockable active/passive choices for that family

Attack/skill definition
    -> owns executable authored combat behavior through gameplay contracts
```

Do not encode mastery identity by mesh path, material name, inventory slot, hotbar position or runtime Node. Do not branch the player controller on every concrete item ID.

The exact resource classes, ContentIds and persistence schema for mastery/skills must be designed when implementation work is authorized; this product document does not invent them early.

## 9. Input and combat action boundary

The target semantic combat vocabulary must be capable of expressing:

```text
primary weapon action / combo
weapon defense or aim behavior where applicable
selected active skill 1
selected active skill 2
selected active skill 3
universal dodge
```

This list describes **semantic actions**, not final physical bindings. Existing prototype mouse-button mappings are implementation evidence only and may be migrated.

A skill press does not bypass the attack/action lifecycle. Skills that attack, move, block, heal or apply status must commit through the appropriate authoritative gameplay state rather than dealing effects directly from UI/input code.

## 10. Persistence rule

When mastery persistence is implemented, save data must preserve mastery by stable weapon-family/mastery identity so changing from one material variant to another does not lose progress.

Do not persist mastery against a mesh, scene path, hotbar slot or a concrete material item ID when the progress semantically belongs to the family.

Exact save schema/versioning remains TBD and must follow the project's persistence/migration contracts.

## 11. Roadmap timing

Weapon mastery is **not required for Phase 7 combat**.

Phase 7 should make the baseline combat system and weapon families strong without depending on mastery progression: attacks, defense/aim behavior, movement commitment, hit resolution, stamina/cost semantics, enemy reactions, weapon identity, bosses, animation and feedback should stand on their own.

The mastery progression layer is intentionally deferred to **Phase 13 — Meta progression and long-term social depth**. That phase may introduce mastery XP, levels, unlock trees, passive choices, the three-selected-active-skill progression/loadout layer, mastery persistence and associated UI.

Earlier systems should preserve clean semantic hooks so later active skills can use the same combat/action authority. They must not implement mastery trees, XP, unlock UI or persistence early merely because the target design is already known.

## 12. Explicitly open

This document intentionally does **not** decide:

- final physical key/button bindings;
- exact mastery level cap or XP curve;
- XP award formula and anti-farming thresholds;
- number and placement of passive nodes;
- exact active-skill lists;
- skill damage, stamina/mana costs, cooldowns or durations;
- unlock levels/point cadence/respec rules;
- final branch names;
- attribute scaling;
- ready-loadout capacity or switching UX;
- Shield slot/hand/pairing rules;
- exact future-family release order;
- implementation class/resource/schema names.

These require explicit product or implementation decisions. Do not fill them in by convention.

## 13. Supersession summary

Current target:

```text
OLD
weapon family -> one signature special

REPLACED BY
weapon family -> mastery progression
              -> two specialization branches
              -> multiple active-skill options
              -> max three equipped active skills
              -> meaningful passive choices
              -> shared mastery across material tiers
```

Historical GitHub planning issues remain useful context, but where they require exactly one signature special or treat Shield as a mandatory standalone mastery family, this document plus ADR-002 are the current authority.