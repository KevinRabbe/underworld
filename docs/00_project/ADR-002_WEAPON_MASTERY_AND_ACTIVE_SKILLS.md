# ADR-002 — Weapon Mastery and Active Skills

Date: **2026-09-10**  
Status: **ACTIVE — LOCKED DIRECTION**

## Decision

Underworld's target weapon progression uses **weapon-family mastery** with a bounded active-skill loadout.

The durable product rules are:

- mastery belongs to a **weapon family**, not to each material/tier weapon item;
- changing to another material/tier item in the same family preserves that family's mastery;
- each significant mastery family has two specialization branches;
- the player may select/equip **at most three active skills for the currently used weapon family**;
- meaningful passive choices may also live in the family mastery;
- the previous **exactly one signature special per weapon** target is superseded;
- physical input bindings are not part of this decision and may be migrated independently;
- Shield is not currently its own mastery family: current direction is skill-driven defensive Shield gameplay, while exact equipment/hand/pairing semantics remain open.

The owning gameplay contract is [`../30_gameplay/WEAPON_MASTERY.md`](../30_gameplay/WEAPON_MASTERY.md).

## Current first-biome mastery families

Current families are:

- Sword;
- Knife;
- Axe;
- Spear;
- War Pike;
- Bow.

Current provisional branch labels are:

| Family | Branch A | Branch B |
| --- | --- | --- |
| Sword | Swordmaster | Defender |
| Knife | Predator | Duelist |
| Axe | Executioner | Reaver |
| Spear | Hunter | Sentinel |
| War Pike | Assault | Warden |
| Bow | Marksman | Ranger |

These branch names are provisional and may be renamed without changing this ADR.

## Family-identity constraints preserved

This decision does not erase previously established weapon identities that still make sense under mastery:

- Spear remains a spacing/reach/precision family rather than a slower War Pike.
- War Pike remains an aggressive forward-pressure family; its advancing three-hit Primary concept remains valid, and any moving technique uses real collision-aware movement rather than teleportation.
- Bow remains player-skill-first; mastery does not replace aiming, draw/release timing, lead/drop judgment or other execution with automatic targeting.
- Axe remains one authored Axe family for both combat and eligible wood/resource harvesting. Do not split it into duplicate combat-Axe and harvest-Axe ownership.
- Natural favorable/unfavorable weapon matchups are allowed; one biome does not have to validate every family equally.

## Shield decision boundary

The old first-biome roster listed Shield alongside weapons. This ADR narrows that interpretation:

> Shield gameplay should be expressed through defensive skill/technique choices rather than a separate Shield mastery tree.

This does **not** decide:

- whether Shield is a dedicated off-hand/equipment item;
- which weapons can pair with it;
- one-hand/two-hand occupancy;
- ready-loadout representation;
- exact block/parry/guard mechanics;
- which active skill(s) use or require a Shield.

Those remain product-open and must be asked/decided explicitly rather than inferred from genre convention.

## Roadmap sequencing

Weapon mastery is intentionally a **later-phase system**.

- **Phase 7 — Combat depth and skill-expression** establishes the core combat foundation: strong weapon archetypes, attacks, defense/aim behavior, enemy interactions, bosses, animation/feedback and the underlying action lifecycle. Phase 7 does **not** require mastery XP, mastery levels, mastery trees, passive-node progression, mastery persistence or the three-selected-skill progression UI to be implemented.
- **Phase 13 — Meta progression and long-term social depth** owns implementation/integration of weapon mastery and its long-term progression layer.
- Earlier combat code and content should remain compatible with later mastery by using semantic combat/action boundaries, but workers must not build mastery early merely because the target product direction is already documented.

The three-active-skill mastery model therefore remains authoritative **target design**, not a Phase-7 acceptance requirement.

## Future/proposed families

Greatsword, Gauntlets & Greaves and Life Staff are future/proposed families, not current first-biome mastery families. Their provisional branch labels are:

- Greatsword — Onslaught / Bulwark;
- Gauntlets & Greaves — Striker / Breaker;
- Life Staff — Restoration / Sanctuary.

Life Staff's future role is healing/support and may enable a low-damage, very-high-survivability Sword + Life Staff hybrid. Exact attributes, skills, numbers and release timing remain open.

## Supersedes

This ADR explicitly supersedes the following **planning assumptions**, while preserving those issue bodies as historical planning context:

- issue **#470**, clause `MMB exactly one signature special per weapon`;
- issue **#485**, the global `weapon_special -> exactly one authored signature special` model and per-family requirement to author exactly one signature special;
- any later document/task text that treats the above one-special model as current solely by inheriting #470/#485.

The remainder of #470/#485 is **not** automatically superseded. In particular, surviving family identities and matchup rules remain valid where they do not depend on the one-special model.

Issue **#473** remains useful for its unresolved loadout/equipment questions. This ADR does not guess those answers; it only establishes that Shield is not a standalone mastery family in the current direction.

## Rationale

Family mastery creates build variety without requiring a large number of mechanically shallow weapon items. Keeping mastery at family level lets material progression improve equipment vertically while the player develops playstyle horizontally.

A three-active-skill cap preserves action-game readability and prevents the combat model from drifting into a large MMO hotbar. Two branches give each family room for distinct playstyles while retaining a recognizable core weapon identity.

Separating Shield mastery from Shield equipment semantics prevents an unresolved loadout decision from blocking the mastery architecture.

Deferring mastery until the later progression phase keeps Phase 7 focused on making the underlying weapons and combat feel good first. Mastery should deepen combat that already works; it should not be used to compensate for weak baseline weapon mechanics.

## Affected contracts

Current authority should be read through:

- [`../30_gameplay/WEAPON_MASTERY.md`](../30_gameplay/WEAPON_MASTERY.md) — player-facing mastery/progression rules;
- [`../40_content/WEAPON_RULEBOOK.md`](../40_content/WEAPON_RULEBOOK.md) — weapon family/content boundary;
- [`../PLAYER_ATTACK_CONTRACT.md`](../PLAYER_ATTACK_CONTRACT.md) — action/attack execution lifecycle;
- [`../40_content/ITEM_RULEBOOK.md`](../40_content/ITEM_RULEBOOK.md) — item/material identity separation;
- [`MASTER_ROADMAP.md`](MASTER_ROADMAP.md) — implementation sequencing;
- [`DECISION_INDEX.md`](DECISION_INDEX.md) — current governance index.

## Migration consequence

This ADR is a **documentation/product-direction change only**. It does not claim the current runtime already implements mastery or three active skills.

When Phase-13 mastery implementation is authorized:

- old one-special input/content assumptions must not become the target schema;
- final semantic input actions must support three selected active skills without hard-coding physical keys into weapon definitions;
- mastery persistence must be family-based;
- existing combat timing/commitment/action authority should be reused rather than bypassed by skill UI/input code.

Before that phase, combat implementation should expose clean semantic hooks for later skills without implementing mastery XP, trees, unlock UI or persistence prematurely.

Exact implementation classes, ContentIds, skill schemas, XP curves, balance values and save migrations remain future implementation decisions.