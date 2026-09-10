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

## 8. Physical health-damage types

Phase-7 physical combat uses three high-level health-damage types:

```text
CUTTING
-> edged cutting attacks such as many Sword, Greatsword, Axe and Knife strikes

PIERCING
-> thrusting/projectile attacks such as Spear, War Pike, Bow and stabbing techniques

BLUNT
-> fists, kicks, body strikes and other physically blunt techniques
```

The **attack owns the damage type**. A weapon family is not forced to use one type for every authored action. A Sword thrust may therefore be Piercing while a Sword cut is Cutting if the authored attack requires that distinction.

Health-damage type remains separate from the shared physical-response properties:

```text
health damage type
-> Cutting / Piercing / Blunt

impact
-> immediate interruption / stagger force

posture pressure
-> accumulated destabilization
```

A high-damage precision hit does not automatically imply high impact, and a heavy blunt impact does not need extreme health damage merely to feel forceful.

## 9. Armor and resistance interaction

Armor/body-region resistance may modify **health damage** by physical damage type without redefining dodge, movement class, impact or posture as the same system.

Conceptually:

```text
successful contact
-> base health damage
-> attack physical damage type
-> contacted region / armor resistance
-> final health damage

separately
-> resolve impact
-> resolve posture pressure
```

The default balance direction is **favorable/unfavorable matchups, not hard weapon invalidation**. A physical resistance can make one attack type noticeably less effective, but ordinary enemies should not routinely reduce a valid physical weapon to near-zero usefulness solely because the player chose the wrong family.

Exceptional creatures may use stronger authored resistance where their physical design makes that behavior clear, such as a stone-like body being unusually resistant to cutting. Those are content-specific exceptions, not the global baseline.

Armor resistance does **not** introduce an armor-weight dodge system. The universal dodge-roll direction from `COMBAT_FOUNDATION.md` remains unchanged.

Future magic may extend damage typing with additional non-physical categories without changing the three Phase-7 physical categories.

## 10. Interception and contact priority

Defense must physically intercept an attack rather than being applied as an unrelated after-the-fact percentage check.

For a single contact path, the first meaningful authored contact determines the immediate resolution:

```text
attack travels through space
     |
     +-> solid world obstruction
     |      -> obstruct / stop / alter attack where appropriate
     |
     +-> valid defending weapon / Shield surface
     |      -> resolve block or parry
     |      -> do not also apply a second full body hit from the same contact
     |
     +-> body / weak point / protected region
            -> resolve direct hit
```

A successful parry deflects the incoming strike and prevents that same strike from simply continuing through the defender as a normal body hit. A successful normal block resolves the established chip-damage, stamina and posture/guard-pressure outcome rather than also applying a second unblocked hit to the body.

Missing the guard remains meaningful: if the authored attack geometry reaches an exposed body region without a valid defensive interception, normal direct-hit resolution applies.

Broad sweeps and very forceful attacks may later have authored behavior that continues toward other targets after one contact. The project does **not** yet define a universal rule that every block stops the entire swing or that every heavy attack cleaves through every guard. Exact continuation/deflection behavior remains attack-specific implementation and playtest work.

## 11. Precision and critical-hit philosophy

Phase-7 physical combat should reward **readable execution** before relying on universal random critical-hit rolls.

The baseline sources of precision reward are physical and understandable:

```text
authored weak-point contact
clean weapon-specific contact
exposed enemy state
posture break / meaningful opening
well-aimed projectile
other explicitly authored vulnerability
```

A successful precision event may increase health damage, posture effect or another authored outcome, but the player should be able to connect the reward to something that happened in the combat world.

Phase 7 does **not require a universal random critical-hit chance** on ordinary physical attacks. This keeps the base combat result tied primarily to aim, spacing, contact, timing and enemy state rather than hidden dice rolls.

Later equipment, mastery or magic may introduce crit-related build mechanics if they add useful variety. Those systems should layer onto the physical contact model rather than replacing weak points and execution with automatic random spikes.

Exact weak-point multipliers, exposed-state bonuses, any future critical-chance rules and how later mastery interacts with them remain open.

## 12. Actor body collision and dodge interaction

Combatants should have physical body presence without turning encounters into rigid physics traffic jams.

Baseline movement collision is:

```text
player <-> enemy
-> bodies cannot freely occupy the same space
-> collision should slide / separate smoothly
-> ordinary movement should not ghost through another actor
-> avoid unstable hard-body shoving and jitter
```

Target size and mass should affect how strongly an actor controls space. Small creatures can be easier to displace, human-sized combatants have meaningful body presence, and large enemies or bosses should strongly occupy their physical volume rather than allowing the player to walk through their torso.

The dodge roll's brief invulnerability window is **damage avoidance, not universal physical intangibility**:

```text
dodge roll
-> attack overlap during valid i-frames: damage authority may ignore the hit
-> wall / solid terrain in path: remains physically solid
-> enemy body in path: movement/collision authority resolves the body contact
```

Dodge movement should still remain smooth. Small overlap imperfections should favor stable sliding/separation rather than abruptly cancelling a roll, while clearly solid world geometry and large actor bodies remain meaningful obstacles.

Crowd collision should create positioning pressure without creating a perfectly rigid ring that traps the player only because several collision capsules touched at once. The intended direction is physical presence plus spacing/sliding/limited displacement, not universal actor ghosting and not unconstrained rigid-body pushing.

Exact collision shapes, separation force, displacement rules, crowd handling and whether specific tiny enemies can be rolled over or through remain implementation/playtest work.

## 13. Vertical combat and uneven terrain

Combat takes place in full 3D space. Authored attack geometry, actor height and terrain elevation remain meaningful rather than collapsing melee into a flat two-dimensional radius check.

The baseline direction is:

```text
attack resolution
-> authored attack geometry exists in 3D space
-> vertical position matters
-> terrain elevation can change whether the attack actually reaches the target
```

Small height differences should not make ordinary melee unnecessarily brittle. Modest vertical alignment at action startup is allowed where needed so a target standing slightly uphill, downhill or on a stair can still be attacked naturally without visible snapping.

```text
small height difference
-> modest startup vertical alignment may occur
-> attack remains visually and physically plausible

large height difference
-> authored geometry must genuinely reach the target
-> no magical vertical homing or bending after commitment
```

This follows the same commitment rule used for horizontal steering. A Spear thrust may reasonably follow player intent toward a target slightly uphill, while a Sword or Greatsword swing does not rotate through an implausible vertical angle after the action is already committed merely to guarantee contact.

Terrain grounding should preserve readable character posture. Feet/locomotion may conform to slopes and steps where presentation supports it, but the entire combatant should not mechanically tilt to every terrain normal in a way that distorts attack intent or hit geometry.

Gameplay hit shapes should closely follow the authored visual attack while allowing a small implementation tolerance for animation, simulation and uneven-ground imperfections. That tolerance must not become a large invisible hit bubble that defeats physical readability.

Ledges and intervening geometry remain authoritative:

```text
target below a ledge
-> attack hits only if its real geometry reaches below the edge

target well above attacker
-> attack must genuinely reach upward

wall / ledge / terrain between actors
-> may obstruct the attack
```

Bow remains fully three-dimensional: manual aim, projectile travel, gravity/drop where authored, terrain collision and actual impact point determine the result.

Exact vertical-correction angles, slope limits, foot IK, hit-volume tolerance, jump/falling attacks and combat behavior while swimming or climbing remain later implementation/playtest decisions.

## 14. Explicitly not required for Phase 7

Phase 7 does not require:

- universal per-limb HP;
- universal severing/dismemberment gameplay;
- a separate damage multiplier for every body part;
- mandatory breakable armor on every enemy;
- fixed target-count caps for broad melee attacks;
- fixed cleave-damage reduction rules;
- a final thrust-piercing/multi-target rule;
- exact collision-sampling implementation;
- exact weak-point multipliers or posture bonuses;
- exact Cutting/Piercing/Blunt resistance values;
- exact armor mitigation formulas;
- exact weapon-family damage-type percentages;
- a universal random critical-hit chance for base physical combat;
- exact block/deflection continuation rules for broad or forceful attacks;
- exact actor collision shapes, crowd-separation force or displacement thresholds;
- exact dodge/body-collision exception rules;
- exact vertical startup-correction angles or slope limits;
- final foot-IK or uneven-ground presentation implementation;
- exact gameplay hit-volume tolerance around visual attack geometry;
- jump attacks, falling attacks or combat behavior while swimming/climbing;
- final magic damage categories.

Those may be evaluated later if they add value without weakening readability or maintainability.