# Underworld — Combat Hit Resolution

Status: **LOCKED DIRECTION for Phase-7 physical hit resolution; exact collision sampling, balance values and advanced body-part systems remain OPEN**

This document complements [`COMBAT_FOUNDATION.md`](COMBAT_FOUNDATION.md) and [`../PLAYER_ATTACK_CONTRACT.md`](../PLAYER_ATTACK_CONTRACT.md). It defines how authored attack geometry turns into physical target contacts without replacing the existing attack/action authority.

## 1. Geometry decides what is hit

Melee attacks should resolve from the authored attack geometry moving through space rather than from an arbitrary nearest-target selection.

Conceptually:

```text
attack becomes active
-> authored weapon / body hit geometry moves through space
-> valid targets physically crossed by that geometry are contacted
-> each contacted target resolves its own hit result
```

A broad attack may therefore hit multiple enemies naturally when the authored swing actually crosses them.

This is an important part of weapon identity:

```text
Sword sweep
-> moderate arc / adaptable multi-target potential

Greatsword broad swing
-> large space-control arc / naturally stronger multi-target coverage

Axe
-> more concentrated contact area

Spear thrust
-> narrow forward line

War Pike thrust
-> very long narrow line

Knife
-> short, localized contact

Gauntlets & Greaves
-> very close body-contact geometry
```

These are high-level identity constraints, not final collision dimensions or animation paths.

## 2. One target, one hit per attack activation

A single attack activation must not repeatedly damage the same target merely because its hit geometry overlaps that target for several simulation frames.

Baseline:

```text
attack activation begins
-> target A is crossed
-> target A resolves one hit

same attack remains overlapping target A
-> no duplicate hit

same attack crosses target B
-> target B may resolve one hit

new authored attack activation begins later
-> target A can be hit again
```

Multi-hit techniques may exist later only when the attack is explicitly authored as multiple hit events. They must not emerge accidentally from frame-by-frame overlap.

Exact bookkeeping implementation, hit-sampling frequency and multi-hit authoring schema remain implementation work.

## 3. World geometry matters

Attack resolution should respect the world where physically appropriate.

Walls, terrain and other solid geometry may stop, deflect or otherwise interfere with an attack rather than allowing the weapon to pass through everything solely because an enemy target is within an abstract radius.

The exact collision policy may vary by attack and environment. The Phase-7 rule is simply that world geometry is part of combat and must not be ignored by default.

## 4. Contact point is meaningful

When a hit succeeds, the actual contact point should be available to downstream combat and presentation systems.

```text
attack geometry contacts target
-> resolve contact point / contacted region
-> determine normal body, authored weak point or special hard/protected region
-> apply health damage / impact / posture according to the authored result
-> drive feedback from the actual contact
```

This supports physical weak-point gameplay without requiring every creature to have a complex universal body-part simulation.

## 5. Authored weak points

Weak points are **enemy/content-authored**, not a requirement that every body region receive a unique damage multiplier.

Examples may include:

```text
head / exposed flesh
vulnerable limb or joint
unarmored opening
creature-specific organ
broken or exposed armor section
other encounter-specific vulnerable region
```

A successful weak-point contact may improve health damage, posture pressure or another authored combat result. The exact reward depends on the target design and remains tuning work.

Weak points should be physically/readably communicated through model shape, material, animation, behavior, damage state or other world-facing cues. They should not rely primarily on hidden spreadsheet knowledge.

## 6. Hard or protected regions

Targets may also expose authored hard/protected regions that reduce the effectiveness of some attacks while still respecting impact and posture as separate properties.

A hard shell or armored plate, for example, may reduce health damage without implying that a sufficiently strong physical impact has no effect at all.

Exact armor-region behavior, resistance values and whether breakable armor sections are introduced remain separate decisions.

## 7. Weapon examples

The contact system should reinforce existing weapon identities rather than invent unrelated minigames:

```text
Bow
-> manual aim
-> physical projectile travel
-> arrow must actually intersect the weak point

Spear
-> precise tip contact can exploit exposed regions

Axe
-> clean Axe-head contact communicates concentrated force

Knife
-> short-range precision can exploit openings

Greatsword
-> broad contact remains primarily about space and force, not precision surgery
```

Exact family modifiers are not defined here.

## 8. Explicitly not required for Phase 7

Phase 7 does not require:

- universal per-limb HP;
- universal severing/dismemberment gameplay;
- a separate damage multiplier for every body part;
- mandatory breakable armor on every enemy;
- fixed target-count caps for broad melee attacks;
- fixed cleave-damage reduction rules;
- a final thrust-piercing/multi-target rule;
- exact collision-sampling implementation;
- exact weak-point multipliers or posture bonuses.

Those may be evaluated later if they add value without weakening readability or maintainability.