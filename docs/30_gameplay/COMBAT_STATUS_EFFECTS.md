# Underworld — Combat Status Effects

Status: **LOCKED DIRECTION for Phase-7 status-effect architecture; exact status roster, durations, stacking rules and balance values remain OPEN**

This document complements [`COMBAT_FOUNDATION.md`](COMBAT_FOUNDATION.md), [`COMBAT_HIT_RESOLUTION.md`](COMBAT_HIT_RESOLUTION.md), [`COMBAT_RECOVERY.md`](COMBAT_RECOVERY.md), and [`COMBAT_HEALING_CONSUMABLES.md`](COMBAT_HEALING_CONSUMABLES.md). It defines how persistent combat effects compose with immediate damage, reactions and later mastery/magic without collapsing every combat state into one generic effect bucket.

## 1. Status effects are persistent gameplay state

A status effect is a real gameplay state with explicit ownership and lifetime semantics. It is not merely a UI icon or presentation cue.

Conceptually:

```text
attack / skill / world effect
-> successfully resolves
-> may apply status

status
├─ semantic effect identity
├─ source / attribution where relevant
├─ target or world owner
├─ duration / persistence rule
└─ gameplay modifiers and/or periodic effects
```

Exact runtime class names and serialization schema are not defined here.

## 2. Immediate combat reactions are not ordinary statuses

Do not collapse all combat state into one `StatusEffect` system.

The shared reaction and structural systems retain their own authority:

```text
STAGGER
-> immediate reaction state

KNOCKDOWN
-> immediate/severe reaction state

POSTURE BREAK
-> structural combat state produced by posture authority

GUARD BREAK
-> defensive failure / exposed state

WOUND / POISON / REGEN / WARD / similar
-> persistent effect state
```

A status system may interact with reactions or posture, but it must not become the authority that replaces attack resolution, reaction handling or posture resolution.

## 3. Small shared physical vocabulary first

Phase 7 should keep the persistent-status vocabulary intentionally small. Physical combat does not need a large MMO-style debuff catalog to be complete.

Useful shared concepts may include:

```text
EXPOSED
-> temporary vulnerability produced by an authored combat event
   such as posture break, guard break, successful parry outcome
   or a specific enemy vulnerability

WOUND
-> persistent physical injury effect where an authored attack/skill creates it
-> exact damage-over-time or healing interaction remains open

SLOW / HINDER
-> movement impairment where physically justified
-> exact strength and source rules remain open
```

These names describe product-level concepts; final implementation names remain open.

## 4. Application follows actual combat resolution

Persistent effects should respect the same physical contact and defense authority as direct damage.

```text
attack misses
-> no hit-applied status

attack is validly blocked
-> status applies only if that authored attack explicitly allows
   an effect through block / guard interaction

attack lands on target
-> status application may resolve

weak point / exposed-state condition
-> may enable or improve an authored effect
```

A wound effect, for example, should not silently pass through a successful Shield or weapon interception merely because the attack definition contains a `Wound` tag.

## 5. Stacking behavior belongs to the effect definition

There is no universal rule that every status stacks, every status refreshes, or every status has the same maximum count.

A repeated application may be authored to:

```text
refresh duration
increase intensity
add a stack
replace a weaker version
have no additional effect
use another explicitly defined policy
```

The effect definition owns that behavior. Exact stack caps and conflict-resolution rules remain future implementation/tuning work.

This is especially important for multiplayer and damage-over-time effects so duplicate applications do not multiply power accidentally.

## 6. Source attribution remains available

Where progression, kill credit or contribution systems require it, a persistent effect should retain sufficient source attribution to identify who or what applied it.

Conceptually:

```text
player A applies Wound
player B contributes direct damage
enemy dies later
-> progression / contribution authority can evaluate valid contributors
```

The status itself belongs to the target/world state for its lifetime. It must not disappear merely because the source unequips the originating weapon unless the effect is explicitly a maintained weapon-bound state.

## 7. Weapon swap and effect ownership

Effect lifetime follows ownership rather than equipment-slot coincidence.

```text
Sword applies Wound
-> switch to Axe
-> Wound remains for its authored lifetime

Life Staff applies regeneration
-> switch to Sword
-> regeneration remains for its authored lifetime

weapon-specific charged stance
-> switch weapon
-> may end / decay because the maintained state belongs to that weapon/action
```

This preserves the previously accepted principle that applied target/world or character effects can persist across weapon swaps while maintained weapon states may not.

## 8. Periodic effects remain readable

Damage-over-time and healing-over-time may resolve periodically, but combat feedback should not depend on excessive floating-number spam.

```text
poison / wound-like effect
-> persistent readable world/target cue
-> periodic gameplay consequence internally

regeneration
-> persistent readable healing cue
-> periodic or continuous recovery internally
```

Exact tick cadence, numerical display and presentation are open. The important rule is that the player should be able to understand that the effect exists and broadly what it is doing.

## 9. Resistance and immunity are authored, not blanket rules

Status resistance belongs to the target/effect relationship rather than to an armor-weight class.

Examples may include:

```text
stone-like creature
-> may strongly resist or ignore a bleed-like Wound

creature with unusual biology
-> may interact differently with poison

boss
-> may reduce duration / intensity of selected effects
-> may use encounter-specific immunity where justified
```

Bosses should not default to `immune to all statuses` or `immune to all crowd control`. Resistance, altered behavior or immunity should be explicit and readable where needed to preserve the encounter.

## 10. Later magic composes the same framework

The persistent-effect architecture should be able to support later magic concepts such as:

```text
Burn
Chill / Frost
Poison
Corruption
Regeneration
Ward
Curse
Root / Bind
```

These names are future possibilities, not a locked Phase-7 magic roster. Magic remains later progression and does not need to be implemented to complete the physical combat foundation.

## 11. Authority separation

The intended composition is:

```text
COMBAT RESULT
├─ immediate health damage
├─ impact / reaction
├─ posture pressure
└─ optional persistent effect
       |
       v
   STATUS AUTHORITY
       ├─ lifetime / duration
       ├─ stacking policy
       ├─ source attribution
       ├─ periodic effect
       ├─ modifiers
       └─ expiry / removal
```

The status authority must not become a second damage resolver or duplicate the reaction/posture systems.

## 12. Explicitly open

The following remain implementation/playtest or later product decisions:

- final Phase-7 status roster;
- exact status durations;
- exact Wound behavior;
- exact Slow/Hinder behavior;
- whether `Exposed` is represented as a formal status object or another bounded vulnerability state;
- stack caps and stack/refresh/replace policies per effect;
- effect conflict and priority rules;
- cleanse/dispel rules;
- damage-over-time and healing-over-time tick cadence;
- exact source-attribution storage;
- status resistance formulas;
- boss resistance and immunity profiles;
- status UI/icons and numerical display;
- persistence across save/load where applicable;
- multiplayer replication and contribution-credit details;
- final magic status roster.

Do not infer arbitrary values or a generic MMO status template. The requirement is a small, explicit, ownership-safe framework that can support physical combat now and later mastery/magic without replacing the project's existing combat authorities.
