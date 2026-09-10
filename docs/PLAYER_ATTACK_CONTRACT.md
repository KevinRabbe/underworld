# Underworld — Player Attack Contract

## Status

**DIRECTIONAL / prototype architecture contract.**

This document defines the data-driven player attack lifecycle that current and future weapon actions must compose with. Exact phase timings, damage values, hit-volume dimensions, final physical bindings and mastery-skill execution details remain tuning/implementation work.

Product authority for weapon mastery and active skills is [`30_gameplay/WEAPON_MASTERY.md`](30_gameplay/WEAPON_MASTERY.md) and [`00_project/ADR-002_WEAPON_MASTERY_AND_ACTIVE_SKILLS.md`](00_project/ADR-002_WEAPON_MASTERY_AND_ACTIVE_SKILLS.md).

The architectural ownership rules below are the important part.

## Prototype bindings vs target actions

Any mouse-button examples in this contract describe the **current prototype implementation**, not a permanent product binding.

The target weapon system must be able to represent semantic actions equivalent to:

```text
primary weapon action / combo
weapon defense or aim behavior where applicable
selected active skill 1
selected active skill 2
selected active skill 3
universal dodge
```

Exact physical keys/buttons remain open and should be input-mapped independently of weapon content.

The older product plan of `MMB -> exactly one signature special per weapon` is **superseded**. The target is multiple active-skill choices per weapon family with **at most three selected/equipped active skills**. Existing prototype controls may remain until an explicit implementation migration changes them.

## Core rule

An attack is not an immediate consequence of an input event.

Current prototype example:

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

Future semantic Primary or active-skill attacks must preserve the same ownership principle:

```text
semantic combat action
   ↓
resolve legal authored gameplay definition
   ↓
commit authoritative action state
   ↓
execute through gameplay lifecycle/authority
   ↓
resolve effect
```

Input starts or requests an action. UI/input code does not deal damage, heal, move the authoritative Player or apply combat status directly.

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

Future mastery/skill system
    chooses unlocked/selected semantic skill actions
    but does not replace attack/effect authority
```

`CombatManager` must not inspect the current hotbar to discover the damage of an attack that was already committed.

A future mastery UI must not become combat authority merely because it lets the player select skills.

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

The definition can produce an `AttackExecution` dictionary containing the combat-relevant immutable values plus the committed source position/direction.

This dictionary is a runtime message, not save data.

Future active skills may require additional bounded gameplay contracts for movement, defense, healing, status, stamina/mana or other effects. Those schemas are **not invented here**. Add them only when an authored skill actually requires them, while preserving explicit ownership and fail-closed resolution.

## Prototype profiles

Current tuning only:

| Attack | Startup | Active | Recovery | Damage |
| --- | ---: | ---: | ---: | ---: |
| Hands light | 0.10 s | 0.10 s | 0.18 s | 7 |
| Stone axe light | 0.12 s | 0.10 s | 0.20 s | 16 |
| Stone pickaxe light | 0.14 s | 0.10 s | 0.20 s | 13 |

These values are not design locks. Their purpose is to prove that weapons can vary through data rather than branching the player controller.

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

Ordinary walking remains available in the current prototype.

This is prototype behavior, not a final universal cancel table for every future mastery skill. Skill-specific cancellation rules require explicit authoring/design rather than accidental behavior.

### Active

Crossing from startup into active creates **one attack activation**.

The current prototype performs one physics hit sample at that boundary. The active-duration field still exists as part of the action phase contract so later weapon implementations may support sustained sweeps or multiple intentional samples without changing the state model.

One committed attack must never emit its activation twice.

### Recovery

The hit has already happened, but the action remains committed until recovery finishes.

No combo/cancel-window behavior is implied by the current prototype contract. Weapon families that later author combos or skills must define those transitions explicitly.

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

The same principle applies to future active skills: once an action is legally committed, later UI selection/equipment state must not silently transform that pending execution into another skill.

The execution source position is sampled when the active frame occurs, allowing normal walking during startup while retaining the originally committed facing.

## Facing

Attack commitment uses horizontal camera-forward as combat facing in the current prototype.

The visual root keeps that facing for the committed attack instead of rotating with ordinary locomotion during the swing.

This is not lock-on targeting. Bow and other skill-first ranged play must remain player-controlled rather than mastery-driven auto-aim unless a later explicit product decision says otherwise.

## Hit geometry

Each current attack definition supplies a short directional sphere-volume contract:

```text
reach
center distance from source chest
sphere radius
minimum forward dot
```

`CombatManager` also retains the existing clear-path ray so terrain/world objects can block the melee connection.

The manager chooses the nearest valid enemy in the supplied attack volume.

Future moving attacks such as War Pike techniques must move the real authoritative Player through accepted movement/collision ownership. A presentation-only dash or teleport-to-target must not substitute for gameplay movement.

## Visual timing

The procedural mannequin does not own a second combat attack duration.

`Player` passes the selected definition's total duration into `PrototypeMannequin.play_attack(duration)`. The mannequin normalizes its placeholder pose across that supplied duration.

Production animation can replace the procedural pose later while preserving the same gameplay phase contract.

Mastery/skill presentation likewise consumes gameplay truth; animation names, VFX and UI labels do not define damage, movement distance, timing or effect authority.

## Harvesting is intentionally separate

LMB harvesting currently remains on the simpler `USING_TOOL` action path.

Mining/harvesting will eventually need its own interaction timing architecture, but this attack cycle does not silently redefine that system.

The **same authored Axe** is intended to compose combat and eligible wood/resource harvesting. That product rule does not mean combat and harvesting need to share one runtime action state or one resolver.

## Weapon mastery composition

Mastery belongs to the weapon family and is separate from a concrete material item.

A future material upgrade such as one Sword item to another Sword item must not alter the attack lifecycle merely because mastery persists. The mastery layer selects unlocked/equipped family skills; equipment supplies the concrete item; combat resolves committed gameplay definitions.

Conceptually:

```text
player Sword mastery
      + selected skill loadout
              |
              v
active Sword-family item
              |
              v
resolved semantic action/skill
              |
              v
PlayerActionController / gameplay authority
              |
              v
committed execution/effect
```

Exact mastery XP, persistence schema, skill resource classes and input bindings remain outside this prototype attack contract.

## Explicitly out of current prototype implementation

The current executable prototype does **not** claim to implement:

```text
production attack combos
advanced input buffering
heavy attacks
production attack stamina costs
lock-on
root motion
weapon mastery progression
mastery XP / points / passives
three equipped active skills
Shield skill/equipment integration
future Life Staff healing/status actions
```

Those are separate implementation tasks. Their absence from the prototype is not permission to revert to the superseded one-signature-special product model.

## Automated validation

Current headless character validation proves that:

- all prototype attack definitions are valid;
- hands/axe/pickaxe values are supplied through data;
- attack phase transitions are startup → active → recovery → free;
- startup produces no early activation;
- the active boundary produces exactly one activation;
- committed attacks reject dodge/parry/block/tool overlap under the current prototype rules;
- execution direction is normalized and horizontal;
- live prototype RMB emits no attack on its input frame;
- live prototype RMB emits once when startup reaches active;
- changing equipment after commitment cannot mutate the pending execution;
- mannequin attack duration follows supplied definition timing.

Future mastery/skill tests must be added when that runtime exists. Documentation must not pretend those tests already pass.

The existing deterministic-worldgen gate must remain green on the same PR head for future implementation changes.