# Player Input Buffer Contract

Status: **DIRECTIONAL architecture, prototype timing**

This document defines the small input-responsiveness layer that sits between raw discrete player input and the committed action state machine.

## Purpose

Underworld should not require frame-perfect button timing at the end of committed actions. A short input buffer may remember one recent discrete intent so the next action can begin as soon as the current commitment finishes.

The buffer exists for responsiveness. It is **not** a combo system, action queue, animation-cancel system, or second action controller.

## Ownership

`PlayerInputBuffer` owns only short-lived input memory.

`PlayerActionController` remains authoritative for whether an action can start and for all startup / active / recovery / dodge / parry / block timing.

The buffer must never force the action controller into an otherwise illegal transition.

## One-slot rule

The buffer contains at most one intent.

- Default prototype lifetime: **120 ms**.
- A newer bufferable discrete input replaces the older buffered input.
- No FIFO queue is allowed in this layer.
- Consumption is one-shot.
- Expired intent is discarded silently.
- Respawn / hard reset clears the slot.

The 120 ms value is tunable. The one-slot architecture is the important rule.

## Current bufferable actions

Prototype scope:

- light attack
- dodge
- parry

Not buffered by this system:

- block, because it is a held state
- sprint, because it is a held locomotion state
- movement axes
- jump, which already has its own coyote/jump-buffer contract
- harvest/tool use

Adding another action to this buffer later must be deliberate rather than automatic.

## Buffering is not commitment

A buffered action has **not started yet**.

This distinction is important for attacks:

1. RMB is pressed while another action is committed.
2. The buffer stores only the recent `attack` intent.
3. The player may still turn the camera or change equipment during the remaining commitment.
4. When the controller becomes free within the buffer lifetime, the current attack definition and current combat facing are resolved.
5. At that moment the attack starts and the normal attack commitment contract takes over.
6. Once started, attack definition and direction remain immutable through startup / active / recovery as defined by `PLAYER_ATTACK_CONTRACT.md`.

This prevents the buffer from making combat feel stale by freezing weapon or facing before the action is actually allowed to begin.

## Directional dodge exception

Dodge direction is part of the dodge button intent itself, so a buffered dodge snapshots its requested world direction at input time.

That payload is deep-copied by the buffer. Later camera movement does not silently rewrite an already requested dodge direction.

## Ground eligibility

Dodge and parry remain grounded actions in the current prototype.

If such an intent is buffered but the controller becomes free while the player is not on the ground, the intent may remain in the one slot until either:

- the grounded requirement becomes valid within the remaining lifetime; or
- the intent expires.

The buffer does not bypass action eligibility.

## Failure behavior

When a buffered intent is consumed, the target action still performs its normal validation.

Examples:

- insufficient stamina can reject a buffered dodge/parry;
- an invalid attack definition can reject a buffered attack;
- expired input never starts later;
- hard reset never replays old input.

A rejected consumed action is not requeued automatically.

## Testing requirements

Headless character validation should cover at least:

- one-slot replacement
- exact expiry behavior
- one-shot consumption
- deep payload snapshotting
- hard reset clearing
- busy attack input does not start immediately
- buffer waits while commitment remains active
- attack starts when the controller becomes free inside the lifetime
- buffered attack uses execution-time weapon/facing
- once that attack starts, the normal immutable attack commitment contract still applies

## Explicit non-goals

This cycle does not introduce:

- multi-entry action queues
- combo definitions
- heavy attacks
- attack-chain bonuses
- special cancel windows
- input priority graphs
- fighting-game-style command buffering

Those systems, if ever needed, require separate design decisions rather than growing accidentally out of this responsiveness helper.
