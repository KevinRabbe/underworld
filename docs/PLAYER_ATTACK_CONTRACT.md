# Underworld — Player Attack Contract

## Status

**DIRECTIONAL / prototype architecture contract.**

This document defines the first data-driven player melee attack pipeline. Exact
phase timings, damage values and hit-volume dimensions remain tuning values.

The architectural ownership rules are the important part.

## Core rule

A melee attack is not an immediate consequence of an input event.

```text
RMB input
   ↓
select immutable AttackDefinition
   ↓
commit direction + definition
   ↓
STARTUP
   ↓
ACTIVE boundary
   ↓
emit one AttackExecution
   ↓
CombatManager resolves supplied execution
   ↓
RECOVERY
   ↓
FREE
```

Input starts an attack. It does not deal damage directly.

## Ownership

```text
PlayerAttackDefinition
    timing / damage / reach / hit geometry

PlayerAttackCatalog
    maps current prototype equipment to definitions

PlayerActionController
    attack commitment and phase clock

Player
    captures definition + facing and emits at active boundary

PrototypeMannequin
    visualizes supplied total duration only

CombatManager
    validates and resolves the supplied execution against world physics
```

`CombatManager` must not inspect the current hotbar to discover the damage of an
attack that was already committed.

## AttackDefinition

The current pure-data contract contains:

```text
attack_id
startup
active
recovery
damage
reach
center_distance
radius
minimum_dot
```

The definition can produce an `AttackExecution` dictionary containing the
combat-relevant immutable values plus the committed source position/direction.

This dictionary is a runtime message, not save data.

## Prototype profiles

Current tuning only:

| Attack | Startup | Active | Recovery | Damage |
| --- | ---: | ---: | ---: | ---: |
| Hands light | 0.10 s | 0.10 s | 0.18 s | 7 |
| Stone axe light | 0.12 s | 0.10 s | 0.20 s | 16 |
| Stone pickaxe light | 0.14 s | 0.10 s | 0.20 s | 13 |

These values are not design locks. Their purpose is to prove that weapons can
vary through data rather than branching the player controller.

## Phase contract

### Startup

The character is committed, but no hit is resolved.

The player cannot cancel startup directly into:

```text
dodge
parry
block
jump
sprint
another attack/tool action
```

Ordinary walking remains available in the first prototype.

### Active

Crossing from startup into active creates **one attack activation**.

The current prototype performs one physics hit sample at that boundary. The
active-duration field still exists as part of the action phase contract so later
weapon implementations may support sustained sweeps or multiple intentional
samples without changing the state model.

One committed attack must never emit its activation twice.

### Recovery

The hit has already happened, but the action remains committed until recovery
finishes.

No combo/cancel-window behavior is implied yet.

## Commitment snapshot

At attack start the player captures:

```text
selected AttackDefinition
horizontal combat direction
```

The definition is then independent of later equipment changes.

Example:

```text
commit stone axe swing
→ switch hotbar before active frame
→ committed execution is still stone_axe_light / 16 damage
```

This prevents mid-swing equipment state from mutating damage or hit geometry.

The execution source position is sampled when the active frame occurs, allowing
normal walking during startup while retaining the originally committed facing.

## Facing

Attack commitment uses horizontal camera-forward as combat facing.

The visual root keeps that facing for the committed attack instead of rotating
with ordinary locomotion during the swing.

This is not lock-on targeting.

## Hit geometry

Each definition currently supplies a short directional sphere-volume contract:

```text
reach
center distance from source chest
sphere radius
minimum forward dot
```

`CombatManager` also retains the existing clear-path ray so terrain/world
objects can block the melee connection.

The manager chooses the nearest valid enemy in the supplied attack volume.

## Visual timing

The procedural mannequin does not own a second combat attack duration.

`Player` passes the selected definition's total duration into
`PrototypeMannequin.play_attack(duration)`. The mannequin normalizes its
placeholder pose across that supplied duration.

Production animation can replace the procedural pose later while preserving the
same gameplay phase contract.

## Harvesting is intentionally separate

LMB harvesting currently remains on the simpler `USING_TOOL` action path.

Mining/harvesting will eventually need its own interaction timing architecture,
but this attack cycle does not silently redefine that system.

## Explicitly out of scope

This contract does **not** add:

```text
attack combos
advanced input buffering
heavy attacks
attack stamina costs
lock-on
root motion
new weapons
weapon technique unlock trees
```

Those require separate design decisions.

## Automated validation

Headless character validation proves that:

- all prototype attack definitions are valid;
- hands/axe/pickaxe values are supplied through data;
- attack phase transitions are startup → active → recovery → free;
- startup produces no early activation;
- the active boundary produces exactly one activation;
- committed attacks reject dodge/parry/block/tool overlap;
- execution direction is normalized and horizontal;
- live RMB emits no attack on its input frame;
- live RMB emits once when startup reaches active;
- changing equipment after commitment cannot mutate the pending execution;
- mannequin attack duration follows supplied definition timing.

The existing deterministic-worldgen gate must remain green on the same PR head.
