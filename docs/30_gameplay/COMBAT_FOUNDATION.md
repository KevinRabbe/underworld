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

## 11. Enemy attack readability

The preferred default is **physical readability**, not MMO-style universal color coding or a giant warning marker for every dangerous attack.

Attack danger should primarily be communicated through:

```text
animation / body preparation
weapon or limb size
movement commitment
audio cue
attack geometry
recovery after the attack
```

For design and authoring, enemy attacks may use a small set of broad behavior classes. These are gameplay-language categories, not final implementation enum names:

| Attack class | High-level meaning | Expected defensive reading |
| --- | --- | --- |
| **Quick** | fast, relatively low-commitment attack | block, parry or dodge depending on weapon/geometry |
| **Committed** | visible wind-up and meaningful commitment | block, parry or dodge can all be valid with different risk/cost |
| **Crushing** | very heavy force intended to punish passive defense | normal block is costly; dodge/reposition is often safest; parry only where physically authored |
| **Charge** | attacker movement is part of the attack | evade the line, intercept with an appropriate mechanic such as Brace, or otherwise answer the movement physically |
| **Control / Grab** | attack tries to seize, pin, displace or otherwise control the target | positioning/dodge is normally the main answer; weapon parry only if the authored motion physically supports it |

These categories should not override the actual geometry. A thrust is a line, a sweep covers a lateral arc, an overhead strike is narrow and forceful, a body charge is moving collision pressure, and a ground attack can create an area that cannot be sword-parried merely because the player timed a button press.

Large committed misses should have meaningful recovery. Reading an attack correctly must create a real opportunity to reposition, counterattack or recover stamina rather than the enemy instantly snapping into another unrelated attack.

Enemy sequences should be learnable. Difficulty can come from chained patterns, altered timing, spacing, mixed attack classes and consequences, but attacks should still look and sound connected to what the enemy is actually doing.

Audio matters especially when an attack begins near the edge of the camera. Off-screen pressure should remain fair through readable sound/movement cues rather than requiring enemies to wait passively for camera focus.

Exact telegraph duration, animation, audio mix, attack-class schema and accessibility indicators remain future implementation/playtest work.

## 12. Attack commitment and steering

Attacks should preserve player/enemy intent and physical commitment without becoming either magnetically target-snapped or unnecessarily rigid.

The baseline direction is:

```text
before attack
-> actor chooses facing / attack direction

attack begins
-> action commits to that intent

light / low-commitment action
-> limited steering may remain

heavy / highly committed action
-> much less steering after commitment

moving attack
-> real collision-aware actor movement
-> never teleport or snap to the target
```

A committed Greatsword overhead or comparable heavy attack should be capable of missing when the target moves out of the attack geometry. The game must not rotate the attacker through an implausibly large angle during the swing merely to guarantee a connection.

The same rule applies to enemies. Once a large enemy has visibly committed to a crushing overhead, charge or similar attack, it should not unrealistically rotate midway through the committed portion solely to catch a correctly timed dodge.

Limited steering is still useful for lighter attacks so ordinary combat does not feel mechanically stiff. The amount of steering belongs to the authored action/commitment profile and must be tuned in playtesting rather than derived from one universal turn-rate constant.

This is compatible with the existing attack lifecycle: facing/intent is committed through gameplay authority, while any allowed steering or movement remains explicit action behavior rather than presentation-only correction.

Exact turn rates, steering windows, facing lock timing and per-attack movement values remain implementation/playtest work.

## 13. Zero stamina and action gating

Reaching zero stamina should be dangerous because options disappear, not because the game automatically applies an unrelated exhaustion stun.

The baseline rule is:

```text
enough stamina
-> stamina-costing action may begin

not enough stamina
-> that stamina-costing action cannot begin

stamina reaches zero through ordinary spending
-> no automatic stun
-> demanding stamina-costing actions remain unavailable
-> recovery resumes when normal regeneration conditions allow
```

Stamina should not normally be treated as a deeply negative resource. If an incoming blocked attack requires more defensive stamina than the defender has remaining, the available stamina is consumed and the **unabsorbed force** converts into guard failure rather than silently driving stamina far below zero.

Conceptually:

```text
block incoming force
     |
     +-> enough stamina: absorb according to normal block rules
     |
     +-> insufficient stamina:
             remaining stamina consumed
             + unabsorbed force
             -> guard break / stronger stumble or stagger
             -> brief exposed state
```

This creates the intended physical loop: attacking aggressively can reduce defensive options; repeated blocking can collapse guard; good parries preserve more stamina; dodging spends stamina to avoid the hit; disengaging creates room for stamina and posture recovery.

Exact minimum-action thresholds, guard-break conversion, recovery delay and regeneration rates remain playtest/tuning work.

## 14. Phase-7 boundary

Phase 7 should establish this shared combat foundation and make each base weapon mechanically complete without mastery.

Mastery remains a later Phase-13 overlay for **scaling, variety and skills**. Phase-7 combat must therefore stand on its own and expose clean semantic hooks for later mastery without implementing mastery XP, trees, passive-node progression or mastery persistence early.

## 15. Explicitly open

This document intentionally leaves the following for implementation/playtesting:

- exact stamina pool and regeneration values;
- exact attack/heavy/dodge stamina costs and minimum-action thresholds;
- exact stamina-regeneration behavior while guarding;
- exact zero-stamina recovery delay and guard-break force conversion;
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
- exact attack telegraph timings, animation/audio details and accessibility indicators;
- exact implementation schema/names for attack readability classes;
- exact attack steering/turn rates, steering windows, facing-lock timing and movement values;
- exact Shield equipment/skill interaction with block/parry.

Those are tuning or later explicit product decisions. Do not infer arbitrary values from genre convention.