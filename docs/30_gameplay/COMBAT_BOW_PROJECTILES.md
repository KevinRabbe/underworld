# Underworld — Bow and Physical Projectile Combat

Status: **LOCKED DIRECTION for Phase-7 Bow projectile behavior; exact draw timing, arrow velocity, gravity, ammo economy and recovery rules remain OPEN**

This document complements [`COMBAT_FOUNDATION.md`](COMBAT_FOUNDATION.md), [`COMBAT_HIT_RESOLUTION.md`](COMBAT_HIT_RESOLUTION.md), [`COMBAT_RECOVERY.md`](COMBAT_RECOVERY.md), and [`../40_content/WEAPON_RULEBOOK.md`](../40_content/WEAPON_RULEBOOK.md). It defines the physical projectile language for Bow combat without locking final ammunition, tuning, or mastery details.

## 1. Bow is manual-aim physical ranged combat

Bow identity is player-skill-first aiming and release execution.

```text
player aims
-> draw / hold
-> release
-> authoritative projectile is created
-> projectile travels through 3D world
-> physical contact resolves
```

Ordinary Bow shots should not be disguised hitscan attacks. Distance, target movement, verticality, trajectory and player lead should remain meaningful.

Mastery must not replace manual aiming with automatic targeting.

## 2. Release commits the shot

At release, the shot's launch state becomes authoritative.

```text
release arrow
-> launch position / direction committed

player turns camera afterward
-> arrow continues its existing trajectory
```

Once created, the projectile is world-owned combat state rather than a live extension of the current weapon input.

```text
arrow released
-> player swaps weapon
-> arrow continues

arrow released
-> source dies
-> already-created projectile may continue until it resolves / expires
```

The dead actor cannot create new attacks, but an already-launched projectile remains a real world effect.

## 3. Three-dimensional trajectory matters

Projectile travel occurs in full 3D space.

```text
close target
-> little lead required

moving distant target
-> player may need to lead movement

high / low target
-> actual launch direction and vertical separation matter

long shot
-> authored projectile drop may matter
```

Exact gravity scale, velocity, drag or other ballistic parameters are implementation/tuning work.

## 4. First meaningful contact is the ordinary baseline

An ordinary arrow should normally resolve against the first meaningful physical obstruction/contact it reaches.

```text
arrow travels
     |
     +-> wall / terrain / solid obstruction
     |      -> projectile stops / embeds / resolves as authored
     |
     +-> valid defending surface
     |      -> interception / block behavior resolves
     |
     +-> target body / protected region / weak point
            -> hit resolves
            -> ordinary arrow normally stops
```

Normal arrows do not require automatic enemy piercing. A later authored projectile, mastery skill or special ammunition may behave differently, but penetration is not the default Phase-7 assumption.

## 5. Actual impact point drives the result

Weak points and protected regions use the actual projectile contact point.

```text
arrow intersects ordinary body
-> normal hit

arrow physically intersects authored weak point
-> weak-point result
```

The system must not convert a near-head crosshair into a headshot when the projectile physically hit another region.

This composes with the existing authored weak-point and armor-region rules in `COMBAT_HIT_RESOLUTION.md`.

## 6. World geometry is strongly authoritative for arrows

Projectile combat should respect terrain and environment collision.

A shot through a narrow opening is valid when the projectile physically clears the opening. A wall, tree, rock, ledge or other solid obstruction can prevent a target behind it from being hit.

The gameplay collision volume may use small practical tolerance so Bow combat is not needlessly brittle, but it should remain close to the visible projectile rather than becoming a large invisible flying hit sphere.

## 7. Defensive interception composes with shared combat authority

A valid Shield or authored defensive surface may intercept a projectile before body contact.

Weapon-only projectile parries/deflections remain family- and action-specific. Phase 7 does not require every melee weapon to automatically swat arrows out of the air.

Exact Shield/projectile behavior remains open because Shield equipment and skill semantics are not yet fully locked.

## 8. Bow movement is not melee lunge movement

Bow draw/aim actions may constrain locomotion, but they do not use melee-style target lunges.

```text
draw / aim
-> authored movement restriction where needed
-> manual camera/aim remains authoritative

release
-> projectile launches
```

Exact movement penalties, hold behavior and dodge/cancel legality remain playtest work.

## 9. Draw strength behavior remains open

A longer or more committed draw may later influence some combination of:

```text
projectile velocity
trajectory / drop
health damage
impact
accuracy / stability
other authored shot properties
```

This document deliberately does not reduce draw duration to a single universal `longer draw = more damage` rule.

## 10. Streaming and authority boundary

Projectiles must resolve against the authoritative loaded combat world. Long-range shots must not become arbitrary damage messages against actors that are not validly simulated/resolved by the current world authority.

Exact projectile simulation range, streaming handoff and lifetime limits are technical implementation decisions.

## 11. Explicitly open

The following remain implementation/content/playtest decisions:

- exact arrow velocity;
- exact gravity/drop behavior;
- exact draw/hold/release timing;
- exact movement restrictions while aiming/drawing;
- projectile lifetime and maximum simulation distance;
- projectile collision tolerance;
- arrow embedding presentation;
- ordinary and special projectile penetration rules;
- Shield/projectile interception details;
- weapon-based projectile parry/deflection support;
- ammo inventory/economy;
- arrow crafting;
- fired-arrow recovery/pickup;
- special arrow types;
- mastery interactions;
- exact weak-point bonuses;
- final Bow damage/impact/posture values.

Do not infer arbitrary ballistic or ammunition values from genre convention. The locked Phase-7 direction is manual aim, authored draw/release, physical 3D projectile travel, world collision and actual contact-point resolution.