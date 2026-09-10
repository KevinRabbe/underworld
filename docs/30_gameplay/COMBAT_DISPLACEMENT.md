# Underworld — Combat Displacement and Forced Movement

Status: **LOCKED DIRECTION for Phase-7 physical displacement semantics; exact strengths, thresholds, distances, wall interactions and per-action tuning remain OPEN**

This document complements [`COMBAT_FOUNDATION.md`](COMBAT_FOUNDATION.md), [`COMBAT_HIT_RESOLUTION.md`](COMBAT_HIT_RESOLUTION.md), and [`COMBAT_GROUP_PRESSURE.md`](COMBAT_GROUP_PRESSURE.md). It defines how pushes, knockback, charges, body strikes and other forced movement can reinforce physical combat without turning every heavy hit into a launch effect or replacing impact/posture authority.

## 1. Displacement is a separate physical result

Health damage, impact, posture pressure and displacement are related but distinct authored outcomes.

```text
successful physical combat result
-> health damage
-> impact / interruption
-> posture pressure
-> optional displacement
```

A high-impact attack does not automatically need large knockback, and a displacement-heavy action does not need extreme health damage merely to move a target.

For example, a downward heavy strike may create a strong stagger with little lateral movement, while a shoulder check or driving body attack may move the target more substantially.

## 2. Forced movement must come from authored force and world context

Displacement should be physically motivated and readable.

Conceptually:

```text
authored attack / collision event
-> determine intended displacement behavior
-> consider target mass / stability / current state
-> resolve against world and actor collision
-> apply only the movement that can physically occur
```

The game must not use generic `heavy attack -> launch target` logic for every action.

## 3. Mass and stability strongly affect displacement

Target size and stability should matter.

```text
small creature
-> easier to push / knock back

human-sized target
-> meaningful but bounded displacement

large enemy / boss
-> strongly resists ordinary displacement
-> requires appropriately forceful or encounter-authored effects to move significantly
```

This resistance comes from authored mass/stability and encounter design rather than a blanket rule that bosses are immune to all movement effects.

Exact mass classes, thresholds and formulas remain open.

## 4. Weapon identity may use displacement differently

Displacement should reinforce the existing physical identity of an action or family without becoming mandatory on every attack.

High-level examples:

```text
Knife
-> little ordinary displacement
-> relies on precision / recovery rather than moving targets around

Sword
-> modest displacement only where an action physically supports it

Axe
-> concentrated force may create strong recoil / stagger
-> large lateral knockback is not required on every chop

Greatsword
-> some committed attacks may produce stronger displacement through broad force

Spear
-> primarily spacing / piercing pressure
-> ordinary thrusts need not launch targets backward

War Pike
-> driving attacks may strongly contest or move an approaching target where mass allows

Gauntlets & Greaves
-> punches, kicks, shoulders and body strikes can use displacement as part of close-range identity

Bow
-> ordinary arrows are not expected to produce large physical knockback by default
```

These are identity directions, not final attack lists or numerical values.

## 5. Source movement and target displacement are different

A moving attack can displace the attacker, the target, both, or neither. These must remain separate authored concepts.

```text
War Pike drive
-> source performs authored forward movement
-> valid contact may also displace target if force/mass allow

Greatsword stationary heavy
-> source may remain mostly planted
-> target may stagger or move from impact
```

Do not infer target knockback solely from the attacker's forward movement, and do not move the attacker by applying target-knockback logic in reverse.

## 6. World collision remains authoritative

Forced movement cannot pass actors through solid world geometry merely because an authored displacement distance was requested.

```text
target pushed toward clear space
-> move according to resolved displacement

target pushed into wall
-> world collision stops / constrains movement

target pushed toward ledge
-> target may leave stable ground if the resolved movement genuinely carries it past the edge
```

A wall collision does not automatically create bonus health damage, a stun, or another effect. Additional wall-impact consequences require explicit authoring/design.

Likewise, falling after genuine displacement should use the normal world/fall rules rather than a special combat-only teleport or death path.

Exact wall-impact and fall consequences remain separate decisions.

## 7. Displacement must not create unstable crowd physics

Group combat already requires physical actor presence without rigid traffic jams. Forced movement must preserve that rule.

```text
pushed target reaches another actor
-> collision / separation handles the contact stably
-> avoid uncontrolled chain reactions and jitter
```

The baseline does not require full rigid-body momentum transfer between every combatant. The combat controller may resolve bounded authored movement and stable separation rather than simulating unconstrained physics impulses through a crowd.

Exact actor-to-actor transfer behavior remains implementation work.

## 8. Displacement and reactions remain distinct

Movement of the target does not automatically imply a specific reaction state.

```text
small shove
-> may reposition target without stagger

strong impact
-> may stagger with little movement

very forceful authored hit
-> may both stagger and displace

knockdown
-> severe reaction state
-> may include displacement where authored
```

This preserves the existing reaction hierarchy and prevents displacement distance from becoming a proxy for impact or posture.

## 9. Defense can alter forced movement

Block, parry and other valid interception outcomes may reduce, redirect or otherwise change displacement where physically appropriate.

```text
unblocked body hit
-> full authored displacement evaluation

normal block
-> guard recoil / displacement may still occur from absorbed force

successful parry / deflection
-> attack path is altered
-> ordinary target knockback from the original direct hit does not also apply
```

Exact block recoil distance, redirection and force transfer remain per-action tuning work.

## 10. Dodge invulnerability does not create hit-owned displacement

If a damaging attack is successfully avoided by the dodge's valid invulnerability window, that avoided hit should not also apply the attack's ordinary target-displacement result.

This does not make the player intangible to walls, terrain or meaningful actor body collision. Those remain movement/collision concerns as defined in `COMBAT_HIT_RESOLUTION.md`.

Exact charge/body-collision behavior during a dodge remains open where attack overlap and actor collision occur at the same time.

## 11. Direction should follow the authored physical event

Forced movement should generally follow the readable direction of the force rather than using arbitrary camera-relative movement.

Examples may include:

```text
forward body check
-> displacement away from source / along the driving line

lateral sweeping force
-> lateral displacement where authored

overhead impact
-> may create little horizontal movement despite high impact
```

Exact vector derivation, contact-normal use and vertical components remain implementation/playtest decisions.

## 12. Presentation follows gameplay movement

Animation, hit reactions and optional ragdoll-like presentation should visualize the authoritative resolved movement rather than secretly moving the gameplay actor independently.

A presentation system may exaggerate pose, recoil or secondary motion, but logical actor position must remain owned by gameplay/collision authority.

Full physics ragdoll is not required for Phase 7 and must not become a second source of uncontrolled combat positioning if introduced later.

## 13. Explicitly open

The following remain implementation/playtest or later content decisions:

- exact displacement strengths and distances;
- target mass/stability categories and formulas;
- exact per-weapon/per-action displacement profiles;
- exact block recoil and parry redirection behavior;
- whether specific attacks use contact-normal or authored-vector displacement;
- vertical displacement and launch behavior, if any;
- wall-impact reactions or bonus damage;
- fall-damage interaction after combat displacement;
- actor-to-actor momentum transfer;
- crowd chain-reaction behavior;
- exact charge/body-collision behavior during dodge i-frames;
- whether selected bosses or encounters allow environmental knock-off outcomes;
- ragdoll usage and presentation;
- later mastery skills that explicitly push, pull or reposition targets.

Do not infer arbitrary knockback distances, universal launch rules or full rigid-body combat simulation from genre convention. The Phase-7 requirement is readable, bounded physical displacement that composes with mass, collision, impact, posture and authored attack identity.