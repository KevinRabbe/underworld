# Underworld — Prototype Character Contract

## Status

**DIRECTIONAL / prototype implementation contract.**

This document defines the replaceable gameplay mannequin used while Underworld's
movement and combat foundations are developed. Exact timing, stamina costs,
proportions and visual style remain tuning values unless promoted to a locked
design decision later.

## Core rule

The visible character is not the gameplay collision body.

```text
CharacterBody3D + capsule
        = movement / world collision

PrototypeMannequin + Skeleton3D
        = visual articulation

PlayerActionController
        = dodge / parry / block / tool-use commitment

StaminaComponent
        = generic stamina resource
```

A future production character must be replaceable without rewriting the player
motor, persistence, combat resolver or equipment ownership.

## Prototype rig

The current mannequin is built from Godot primitives at runtime and contains a
real `Skeleton3D` with named humanoid bones:

```text
root
└─ pelvis
   ├─ spine_01
   │  └─ spine_02
   │     └─ chest
   │        ├─ neck -> head
   │        ├─ clavicle_l -> upperarm_l -> forearm_l -> hand_l
   │        └─ clavicle_r -> upperarm_r -> forearm_r -> hand_r
   ├─ thigh_l -> calf_l -> foot_l
   └─ thigh_r -> calf_r -> foot_r
```

Box meshes are attached to bones through `BoneAttachment3D`. They are visual
only and may later be replaced by a skinned production mesh.

## Equipment sockets

Standard prototype sockets exist from the start:

```text
hand_r
hand_l
back
hip_r
hip_l
```

The current axe/pickaxe visual is attached through the right-hand socket rather
than positioned directly under the player's root.

## Universal prototype actions

Current intended universal actions:

```text
move
sprint
jump
attack / harvest
directional dodge
parry
block
```

There is no MMO-style ability bar and no progressive weapon-technique unlock
system implied by this contract.

The prototype action controller currently exposes mutually exclusive committed
states for dodge, parry, held block and active tool/melee use. An accepted LMB
or RMB swing enters `USING_TOOL` for the existing tool-use duration, preventing
that swing from being cancelled directly into dodge, parry, block, jump or
sprint. Ordinary walking remains available during the swing.

## Current prototype controls

```text
WASD      movement
Shift     sprint
Space     jump
Ctrl      dodge
Q         parry
F         block (temporary prototype binding)
LMB       harvest / tool action
RMB       melee attack
```

Input bindings are prototype defaults, not permanent UX decisions.

## Combat facing

Attack/tool use, parry and block establish a combat-facing direction from the
horizontal camera forward vector. The mannequin's +Z visual-forward axis is
aligned to that direction when the action begins.

While block is held, normal locomotion does not rotate the visual root. This
keeps the guard cone stable while the player strafes. Dodge retains its own
committed movement direction.

This is a prototype facing contract, not a lock-on system.

## Stamina

Current starting tuning:

```text
max stamina       100
sprint drain      12 / second
dodge cost        25
parry cost        15
regen delay       0.75 s
regen rate        20 / second
```

Stamina owns only resource accounting. It does not know what a dodge, sprint,
parry or block is.

## Dodge contract

Current prototype:

```text
duration          0.48 s
iframe start      0.09 s
iframe end        0.30 s
peak speed        10.8 m/s
```

Movement input selects dodge direction. A no-input dodge becomes a predictable
backstep. Normal horizontal movement temporarily yields authority to the dodge
curve. The full dodge animation is not invulnerable.

Dodge iframes are not directional: an attack from any direction is avoided while
the iframe window is active.

## Parry contract

Current prototype:

```text
startup                 0.06 s
active window           0.12 s
recovery                0.30 s
frontal coverage        ~160 degrees total
```

Parry is a committed timed action. During the active window, a parryable melee
hit resolves as `parried` only when the attacker is also inside the character's
frontal parry arc. Rear attacks therefore bypass an active parry instead of
turning parry into a 360-degree immunity field.

The player returns a small combat result (`hit`, `dodged`, `parried`, `blocked`,
or `ignored`); enemies decide what that result means for their own behavior.

The prototype Burrower consumes `parried` by entering a distinct **0.85 second
stagger**, cancelling the current attack, flashing, and receiving recoil away
from the player. A `dodged` result is intentionally different: the attack simply
misses and does not stagger the Burrower.

## Block contract

Block is a held defensive state rather than a timed invulnerability window.
Raising guard itself has no stamina cost. Stamina is paid when an impact is
actually absorbed.

Current prototype:

```text
frontal coverage          ~140 degrees total
movement while blocking   2.4 m/s
impact stamina cost        5 + 1.25 × incoming damage
upfront guard cost         0
```

A block succeeds only when the attacker is inside the character's frontal arc.
Rear attacks bypass guard and resolve as normal hits. Sprinting and new
attack/harvest actions cannot start while guard is held.

If stamina cannot pay the impact cost, guard breaks immediately, remaining
stamina is drained to zero, and the same attack continues through the normal hit
path. Therefore block is safer and more forgiving than parry, but repeated or
heavy impacts can exhaust it.

`blocked` is deliberately not equivalent to `parried`: the prototype Burrower
does not receive parry stagger or recoil when its attack is merely blocked.

The mannequin includes a persistent held guard pose. This is a visual layer,
not a timed action: gameplay owns whether guard is active, and the mannequin only
renders the corresponding stance.

## Prototype HUD feedback

The existing debug/survival HUD exposes the character systems needed for tuning:

```text
HP current/max
stamina current/max
current action state
enemy count / combat message
Ctrl: dodge
Q: parry
F: block
```

This is diagnostic UI, not a final stamina bar or final combat HUD.

## Animation strategy

The prototype currently uses procedural bone poses rather than production
animation assets. It supports placeholder poses for:

```text
idle / locomotion
sprint lean
airborne pose
attack
parry
directional dodge
held guard
hit reaction
```

Movement remains code-driven. Visual animation does not own world displacement.

Production animation clips/AnimationTree can replace these procedural poses
later while preserving the same high-level visual API and action timings.

## Automated validation

`tests/run_character.gd` validates headlessly that:

- the rig constructs under Godot;
- required bones and sockets exist;
- the tool root is attached to the hand socket;
- placeholder timed action poses advance and recover;
- held guard visual state activates and clears without becoming a timed action;
- stamina spending/regeneration follows its contract;
- dodge startup/iframe/recovery timing is correct;
- parry startup/active/recovery timing is correct;
- frontal parry succeeds while rear melee bypasses it;
- combat facing aligns the mannequin to horizontal camera forward;
- held block starts/releases and is mutually exclusive with dodge/parry;
- block impact stamina is charged exactly;
- frontal block prevents damage while rear attacks bypass it;
- guard facing remains stable while strafing;
- insufficient stamina produces guard break, drains the remainder and clears the visual guard;
- accepted live tool/melee use enters the committed `USING_TOOL` state;
- tool commitment rejects dodge/parry/block and ends with the existing cooldown;
- `player.gd` constructs and resolves normal/dodged/parried/blocked melee;
- a parried Burrower attack produces the long parry stagger and recoil;
- dodged or blocked Burrower attacks do not accidentally produce parry stagger.

Spatial integration fixtures run only after the headless SceneTree is active so
`global_position` behavior is the same contract used during actual play.

Visual feel is deliberately not treated as an automated-test question.

## First-character checkpoint boundary

This prototype is considered structurally sufficient once the character and
existing deterministic-worldgen gates are green on the same PR head. The next
character work should not automatically expand this PR into combos, production
animation, armor, lock-on, advanced input buffering or weapon-specific combat.
Those belong to later, deliberately scoped cycles.
