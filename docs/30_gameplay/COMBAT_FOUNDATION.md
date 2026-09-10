# Underworld — Combat Foundation

Status: **LOCKED DIRECTION for shared physical-combat rules; exact values, timings and tuning remain OPEN**

This document defines the common Phase-7 combat language that weapon families and enemies compose with. It intentionally stays above animation-frame, balance-number and final implementation-schema detail.

Companion contracts:
- [`../PLAYER_ATTACK_CONTRACT.md`](../PLAYER_ATTACK_CONTRACT.md) — authoritative attack/action execution lifecycle;
- [`WEAPON_MASTERY.md`](WEAPON_MASTERY.md) — later Phase-13 scaling, variety and skill progression;
- [`../40_content/WEAPON_RULEBOOK.md`](../40_content/WEAPON_RULEBOOK.md) — authored weapon-family/content boundary.

## 1. Core combat resources

Underworld separates three different combat concerns:

```text
HEALTH
-> whether the actor remains alive

STAMINA
-> whether the actor can continue performing demanding physical actions

POSTURE
-> whether the actor can remain structurally stable under pressure
```

These are not aliases for one another.

### Health

Health is life-state damage. Armor, defense and other systems may reduce or modify received health damage, but health is not used as the action-economy resource.

### Stamina

Stamina is the shared physical action economy. It may be spent by attacks, heavy attacks, dodges, absorbing force while blocking and later physical active skills.

Simply holding guard should not continuously consume stamina by itself. Current direction is that guarding should stop or strongly reduce stamina regeneration so indefinite passive guarding still has an opportunity cost. Exact regeneration behavior and costs remain tuning work.

### Posture

Posture represents accumulated destabilization under pressure. It is not a player-spent resource.

Sustained or heavy pressure can build posture toward a break. When pressure stops, posture should recover. Exact rates and thresholds remain open.

A full posture break creates a meaningful exposed punish window rather than merely changing a hidden number.

## 2. Shared defense model

The common physical-defense vocabulary is:

```text
well-timed defensive input
-> PARRY / DEFLECTION where the incoming attack is physically parryable

continued guard
-> BLOCK

DODGE
-> physically avoid the attack and reposition
```

Exact physical bindings remain outside this document.

Two-handed melee weapons may defend with the weapon itself. Shield mastery is not a separate family; exact Shield equipment and skill semantics remain product-open.

## 3. Normal block outcome

A successful ordinary block does **not** erase the incoming attack.

Current baseline direction is that some of the force still reaches the defender as a combination of:

```text
incoming attack
     |
     v
successful normal block
     |
     +-> reduced health damage / chip damage
     +-> stamina drain
     +-> posture / guard pressure
     +-> small guard recoil / stumble
```

The exact term and animation for the small reaction are not important yet; `guard recoil / stumble` means a short physical response showing that force was absorbed rather than deleted.

The amount of chip damage, stamina drain, posture pressure and recoil should depend on the incoming attack and the defender's available defensive capacity. Exact percentages, thresholds and formulas remain TBD.

If the defender does not have enough stamina/capacity to absorb the hit, the guard can collapse into a stronger stagger/exposed state. The exact guard-break threshold and follow-up window remain tuning work.

This block model is intended to prevent permanent low-risk turtling while still making blocking a useful defensive choice.

## 4. Parry / deflection

Parry is the higher-skill timing response and should be more efficient/rewarding than simply holding block.

The baseline successful-parry direction is:

```text
successful parry / deflection
     |
     +-> no or almost no health damage
     +-> substantially lower stamina cost than absorbing the same hit with a normal block
     +-> incoming attack is deflected rather than fully absorbed
     +-> attacker is briefly opened for a counter opportunity where physically appropriate
```

Exact parry window, stamina cost, any residual chip damage, counter-window duration and family-specific response remain playtest/tuning work.

Not every attack must be parryable. Physical readability and attack type should determine whether a parry makes sense. A sword swing, for example, can participate in this language; a ground shockwave does not become parryable merely because the player pressed the parry input at the right time.

## 5. Dodge

Dodge is a universal physical avoidance/repositioning tool.

The baseline dodge is a **smooth forward dodge roll**. It is a real movement action, costs stamina and includes a brief invulnerability window during the clean evasive portion of the roll. The dodge must not become a free cancel out of an already committed attack/action.

```text
dodge request
     |
     +-> pay stamina
     +-> commit to smooth forward roll
     +-> physically reposition
     +-> brief evasive invulnerability window
     +-> recover back into normal movement/combat
```

The project does **not** use an armor-weight/equip-load dodge-class system. Armor does not select Light/Medium/Heavy roll categories or impose a weight-based movement class; the same baseline dodge-roll family applies regardless of armor.

Exact roll distance, duration, stamina cost, invulnerability timing and recovery remain playtest/tuning decisions.

## 6. Attack properties are separate

An attack can carry separate gameplay properties for:

```text
damage
impact / interruption force
posture pressure
```

These must not be collapsed into one damage number.

This allows, for example, a fast precision weapon to deal useful health damage without launching or constantly staggering enemies, while heavier committed weapons can carry substantially more physical impact and posture pressure.

Guard pressure may also need an explicit authored value when implementation requires it; the final schema is not invented here.

## 7. Reaction hierarchy

The shared reaction language is approximately:

```text
small hit reaction
-> interrupt
-> stagger
-> posture break
-> knockdown
```

These are severity concepts, not a requirement that every hit progress through every stage.

**Stagger and posture break are different mechanisms.** Stagger is an immediate response to enough impact/interruption force from a hit. Posture break is the result of accumulated posture pressure reaching its break threshold. A heavy strike may cause an immediate stagger without filling posture, while repeated pressure may eventually create a posture break without every contributing hit being a large stagger.

Knockdown should be comparatively rare and must respect target size/mass and attack force. Fast/light weapons should not permanently interrupt large targets merely through attack speed.

## 8. Stunlock protection

Combat should not allow a player or enemy to be held indefinitely in repeated hit reactions by fast low-impact attacks.

After a meaningful stagger or similar strong reaction, the recovering actor should receive a short **stabilization** period against repeated low-impact stagger/interrupt effects. This is not general invulnerability: health damage and posture pressure can still apply normally, and sufficiently strong impact can still overcome the stabilization when physically appropriate.

Conceptually:

```text
meaningful stagger
     |
     v
short recovery / stabilization
     |
     +-> low-impact repeat hit: damage/posture may apply, but no immediate re-stagger
     +-> sufficiently strong impact: may still stagger
     |
     v
normal reaction susceptibility returns
```

The same principle applies to player and enemy combat where appropriate. Bosses and very large enemies may have stronger resistance through their authored mass/stability and encounter tuning, but they should still use the same readable reaction language rather than arbitrary immunity to the whole system.

Exact stabilization duration, impact threshold and which reaction classes trigger it remain playtest/tuning work.

## 9. Commitment resistance

The project does not rely on a universal armor-derived poise system.

Instead, specific committed attack phases may receive temporary resistance to interruption when that matches the physical action. Examples include a descending heavy Axe strike, a committed Greatsword heavy or a driving War Pike engagement.

This resistance belongs to the action/phase, not permanently to an armor-weight class.

Exact resistance values and eligible phases remain weapon-authoring/tuning work.

## 10. Enemy and boss participation

Enemies use the same underlying combat language as the player where appropriate. Enemy attacks can carry health damage, impact, posture pressure, guard pressure and parryability/readability information.

Enemy size/mass affects displacement and knockdown response. Bosses are not exempt from posture and reaction systems, but their mass, attack sequences and recovery windows can make them substantially harder to control than ordinary enemies.

Boss difficulty should come from timing, sequences, positioning, force and consequences rather than silently ignoring the combat rules.

## 11. Readability

The preferred default is physical readability rather than MMO-style universal color coding.

Attack danger should primarily be communicated through animation, body commitment, weapon size, movement, sound and impact preparation.

Broad internal attack classes may later be useful for authoring/validation, such as Quick, Committed, Crushing, Charge and Control/Grab, but exact enum/schema names are not locked by this document.

Large missed attacks should have meaningful recovery so successful reads create real punish opportunities.

## 12. Phase-7 boundary

Phase 7 should establish this shared combat foundation and make each base weapon mechanically complete without mastery.

Mastery remains a later Phase-13 overlay for **scaling, variety and skills**. Phase-7 combat must therefore stand on its own and expose clean semantic hooks for later mastery without implementing mastery XP, trees, passive-node progression or mastery persistence early.

## 13. Explicitly open

This document intentionally leaves the following for implementation/playtesting:

- exact stamina pool and regeneration values;
- exact attack/heavy/dodge stamina costs;
- exact stamina-regeneration behavior while guarding;
- exact block chip-damage percentage/formula;
- exact block stamina drain and guard-pressure formulas;
- exact guard recoil/stumble strength and animation;
- exact guard-break threshold and recovery;
- exact posture capacity, recovery and break duration;
- exact parry window, stamina cost, residual chip and counter-window duration;
- exact dodge-roll distance, duration, stamina cost, invulnerability timing and recovery;
- exact impact/interruption thresholds;
- exact stunlock-protection stabilization duration and override threshold;
- exact action-phase commitment resistance values;
- exact enemy/boss reaction tuning;
- exact Shield equipment/skill interaction with block/parry.

Those are tuning or later explicit product decisions. Do not infer arbitrary values from genre convention.