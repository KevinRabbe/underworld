# Underworld — Combat Recovery and Whiff Punishment

Status: **LOCKED DIRECTION for Phase-7 recovery/commitment behavior; exact timings, transition windows and per-weapon tuning remain OPEN**

This document complements [`COMBAT_FOUNDATION.md`](COMBAT_FOUNDATION.md), [`COMBAT_HIT_RESOLUTION.md`](COMBAT_HIT_RESOLUTION.md) and [`../PLAYER_ATTACK_CONTRACT.md`](../PLAYER_ATTACK_CONTRACT.md). It defines how authored attacks return to player/enemy control after commitment without introducing artificial basic-attack cooldowns.

## 1. Recovery is part of attack commitment

A physical attack remains an authored action through startup, active contact and recovery:

```text
startup
-> attack prepares / commits

active
-> authored attack geometry can connect

recovery
-> actor completes the committed motion
-> freedom returns according to authored transition rules
```

Recovery is therefore a primary cost of using a committed action badly. Base attacks do not need an unrelated hidden cooldown to create vulnerability.

## 2. Missing matters through authored motion

A miss should be punishable because the actor still has to finish the motion that was chosen, not because the game detects `MISS` and adds an arbitrary stun.

```text
committed Greatsword heavy misses
-> swing still completes
-> substantial authored recovery
-> opponent receives a real punish opportunity

fast Knife attack misses
-> much shorter authored recovery
-> smaller punish window
```

The project should not add a generic extra `miss penalty` timer on top of an otherwise identical action merely to manufacture whiff punishment.

## 3. Hitting does not automatically cancel recovery

A successful hit does not grant universal hit-cancel freedom.

```text
attack connects
-> resolve health / impact / posture / feedback
-> target reacts according to the combat rules
-> attacker still completes the authored action or authored legal follow-up
```

A hit may be safer in practice because impact, stagger, guard recoil, displacement or a posture break changes the opponent's ability to retaliate. That is different from automatically erasing the attacker's recovery because contact occurred.

Likewise, a miss is often more dangerous because no target reaction protects the attacker while the same commitment finishes.

## 4. Combo transitions are authored recovery exits

An attack chain may provide legal transition windows that shorten the practical return-to-neutral path:

```text
Sword light 1
-> legal follow-up input is buffered
-> transition into Sword light 2

no legal follow-up
-> finish recovery
-> return to neutral
```

This composes with the one-pending-action buffering rule in `COMBAT_FOUNDATION.md`. It must not become universal `hit anything -> cancel into anything` behavior.

## 5. Defense contacts can change recovery

Different physical outcomes may produce different authored recovery states:

```text
direct miss
-> normal authored whiff recovery

normal block
-> attacker and defender respond according to force / guard interaction
-> attack may continue or recoil where authored

successful parry / deflection
-> attacker may enter a stronger vulnerable recovery
-> defender receives a readable counter opportunity where appropriate
```

Exact block-recoil continuation and parry-recovery behavior remain attack-specific rather than one universal animation/timer.

## 6. Weapon identity through recovery

Recovery should reinforce family identity at a high level:

```text
Knife
-> short recovery / quick disengagement

Sword
-> moderate adaptable recovery

Axe
-> noticeable recovery after committed chops

Greatsword
-> substantial recovery after large committed attacks

Spear
-> controlled recovery supporting spacing rhythm

War Pike
-> meaningful recovery after strong forward commitment

Gauntlets & Greaves
-> short recovery between close combination actions

Bow
-> draw / release / recovery rhythm rather than melee swing recovery
```

These are direction-level identity constraints, not final frame/timing values.

## 7. Enemy recovery uses the same readable principle

Enemies and bosses should expose recovery that matches what they physically performed.

A large creature that visibly commits to a crushing attack and misses should create a meaningful opportunity for the player to reposition, counterattack or recover resources. A quick low-commitment bite or jab may recover much faster.

This preserves the established rule that enemy difficulty comes from readable timing, sequences, spacing, force and consequences rather than attacks instantly resetting after obvious commitment.

## 8. Baseline commitment relationship

As a design tendency rather than a universal mathematical law:

```text
more power / reach / movement commitment
               |
               v
usually more exposure when used badly
```

Individual actions may intentionally break this tendency when their identity requires it, but the exception should be authored and readable rather than accidental.

## 9. Explicitly open

The following remain implementation/playtest work:

- exact recovery durations;
- exact hit-vs-whiff transition differences;
- exact combo transition windows;
- exact parry-induced attacker recovery;
- exact block-recoil continuation behavior;
- exact dodge/block cancel availability during recovery;
- exact per-weapon and per-action timing values;
- final animation implementation of recovery states;
- mastery-skill-specific cancel/transition rules.

Do not infer arbitrary timing values from genre convention.