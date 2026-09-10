# Underworld — Combat Group Pressure

Status: **LOCKED DIRECTION for Phase-7 enemy group-pressure behavior; exact coordinator budgets, cadence values and encounter overrides remain OPEN**

This document complements [`COMBAT_FOUNDATION.md`](COMBAT_FOUNDATION.md), [`COMBAT_HIT_RESOLUTION.md`](COMBAT_HIT_RESOLUTION.md), and [`COMBAT_RECOVERY.md`](COMBAT_RECOVERY.md). It defines the default language for multiple enemies pressuring the player without reducing combat to either simultaneous unavoidable attack spam or visibly scripted turn-taking.

## 1. Coordinated pressure, not strict turns

The default group-combat direction is **coordinated pressure without obvious attack turns**.

```text
enemy group
     |
     +-> some enemies actively threaten / attack
     +-> some reposition or flank
     +-> some close distance
     +-> some recover
     +-> some search for an opening
```

A normal group should therefore keep the player under meaningful pressure even when not every enemy is currently executing a committed attack.

The implementation may use an internal pressure budget, opportunity coordinator, threat weighting or equivalent mechanism, but that machinery must not make enemies look as though they are waiting for a numbered turn.

## 2. Avoid both unfair overlap and passive waiting

Two extremes are undesirable:

```text
bad extreme A
-> many enemies launch committed attacks simultaneously
-> overlapping geometry becomes effectively unavoidable

bad extreme B
-> one enemy attacks
-> every other enemy visibly waits
```

The baseline should sit between these. A group can layer threats, but ordinary encounters should usually avoid stacking so many simultaneous committed attacks that the player has no readable response.

This is a design tendency, not a universal hard cap on the number of attacks that may exist at once.

## 3. Simultaneous attacks may occur

Overlap remains part of combat when it is readable and answerable.

```text
quick attack
+
second enemy begins slower committed attack
-> valid layered pressure

two enemies attack from different angles
-> may occur

entire ordinary pack launches unavoidable committed attacks together
-> should usually be prevented
```

Exact concurrency budgets, timing separation and encounter-specific exceptions remain tuning work.

## 4. Off-screen enemies remain active

Enemies do not become passive merely because they leave the camera.

```text
off-screen enemy
-> may move
-> may flank
-> may close distance
-> may attack
```

However, dangerous off-screen pressure must remain compatible with the physical-readability rules from `COMBAT_FOUNDATION.md`.

A meaningful attack beginning outside the player's view should provide sufficient world-facing cues through sound, movement, animation timing or another readable signal so the player has a fair opportunity to respond. Examples may include footsteps, growls, armor movement, a charge sound or a heavy attack wind-up.

The solution should not be "enemy waits until camera sees it," but neither should ordinary encounters rely on silent off-screen hits with no useful warning.

## 5. Terrain and body presence shape group pressure

Group combat should inherit the project's physical actor and world geometry rather than ignoring it.

```text
narrow passage
-> fewer enemies can physically surround the player

large enemy between player and smaller enemies
-> its body may interfere with their pathing / attack access

open field
-> more flanking opportunities exist

uneven terrain / ledges / obstacles
-> approach lines and attack geometry change
```

This allows players to solve some group pressure through positioning instead of only through numerical damage output.

## 6. Melee and ranged pressure are not identical

Melee and ranged enemies can participate in the same encounter without consuming identical pressure semantics.

```text
melee pressure
-> closing lanes
-> surrounding
-> close-range threat
-> committed physical attacks

ranged pressure
-> projectile timing
-> sight lines
-> forcing movement
-> punishing exposed positions
```

A ranged enemy may attack while melee enemies are engaged if the combined pressure remains readable and answerable. The exact cadence and coordinator weighting remain implementation/playtest work.

## 7. Encounter archetypes may push the baseline

The default group-pressure language must not become a permanent ceiling on encounter difficulty.

Authored enemy groups may intentionally use different pressure profiles where their identity supports it:

```text
ordinary group
-> coordinated readable pressure

wolf pack
-> more aggressive overlapping harassment

small swarm creatures
-> many simultaneous low-impact threats

elite squad
-> more deliberate coordinated combinations

deep Underworld encounter
-> substantially higher pressure

boss + adds
-> bespoke encounter rules
```

These exceptions should still preserve readable combat language rather than bypassing it arbitrarily.

## 8. No omniscient input reading

Enemies should react to perceivable player behavior, not raw controller/button input.

```text
player presses heal input
-> enemy does NOT instantly gain hidden knowledge

player visibly begins a healing / use action
-> nearby enemy may perceive the opening and respond

player retreats
-> pursuing enemy may close distance

player becomes cornered
-> enemies may naturally gain stronger positions
```

This keeps enemy reactions grounded in the combat world rather than in AI access to invisible player intent.

## 9. Explicitly open

The following remain implementation/playtest decisions:

- exact concurrent-attack budget or whether the implementation uses a budget at all;
- exact coordinator architecture and ownership;
- attack-opportunity scoring;
- timing separation between overlapping attacks;
- melee/ranged pressure weighting;
- flank spacing and preferred engagement positions;
- off-screen telegraph timing and audio mix;
- how crowd size changes default pressure;
- per-archetype pressure profiles;
- deep-Underworld escalation rules;
- boss-plus-adds coordination;
- difficulty-setting interaction;
- multiplayer target-distribution behavior.

Do not infer arbitrary numerical limits from genre convention. The Phase-7 requirement is coordinated, readable pressure that remains physically grounded and does not become obvious turn-taking.