# Creature / Enemy Rulebook

Status: **ENEMY-001 executable authored-content contract**

This rulebook defines authored creature identity, immutable baseline tuning, semantic capabilities and semantic combat/presentation references. It does not own AI execution, mutable entity state, encounter placement, world generation or final presentation realization.

## Purpose

A `CreatureDefinition` answers **what authored creature this is and which validated contracts it depends on**. Runtime actor scripts answer what the currently spawned entity is doing.

The first migration proof is the existing Burrower. ENEMY-001 preserves its current behavior and tuning rather than redesigning it.

## Stable semantic identity

Creature definitions use the `creature.*` ContentId family.

The Burrower proof is:

```text
creature.enemy.burrower
```

This ContentId is not:

- a scene or script path;
- a mesh/material identity;
- a runtime Node instance ID;
- an encounter spawn serial;
- a future generated placement StableId.

Replacing presentation or moving an authored resource does not rename the creature.

## Category and capability contract

The baseline enemy category is:

```text
category.creature
└─ category.creature.enemy
```

The executable enemy-family rule requires the enemy proof to declare explicit capabilities for:

```text
capability.movement
capability.sensing
capability.combat.melee
```

These are semantic schema declarations. They do not contain AI implementation.

## Authored immutable tuning

The Burrower definition owns the seven values that were previously hard-coded in the prototype encounter controller's spawn dictionary:

```text
max_health       = 36
move_speed       = 3.3
detection_range  = 16.0
attack_range     = 1.80
attack_damage    = 10
attack_cooldown  = 1.20
attack_windup    = 0.42
```

`CreatureDefinition.runtime_stats()` is a narrow compatibility handoff into the existing Burrower actor. It does not create a second runtime-state model.

The existing hit-stagger (`0.20`) and parry-stagger (`0.85`) behavior remain actor/combat-reaction contract values in this migration. ENEMY-001 does not duplicate them into authored content merely to claim ownership it does not consume.

## Semantic references

A validated creature definition selects dependencies by semantic identity:

```text
combat.attack_profile      -> attack_profile.*
presentation.archetype     -> archetype.*
presentation.animation_set -> animation_set.*
presentation.rig_profile   -> rig_profile.*
```

The Burrower proof also declares the animation and rig roles it requires. The creature family validator verifies that the selected animation set and rig profile actually provide those roles.

Concrete clip names, bone names, meshes and scene filenames remain presentation-owned.

## Attack-profile boundary

ENEMY-001 adds a narrow `CreatureAttackProfileDefinition` semantic target. The initial profile records the attack style and whether the attack is parryable.

The current Burrower melee execution remains in its existing actor/combat path. This card does not create a second damage-resolution system and does not move attack timing into animation.

Future attack-system work may deepen this semantic attack-profile boundary deliberately. It must not silently duplicate current combat authority inside creature scenes.

## Runtime state remains runtime-owned

Shared `CreatureDefinition` resources do **not** store per-spawn mutable state such as:

```text
current health
target/home position
velocity
attack cooldown timer
attack windup timer
pending attack state
hit/parry stagger timers
wander timer/target/RNG
death state
runtime Node identity
```

A spawned Burrower derives current health and baseline tuning from the definition, then owns its mutable values independently.

## Encounter policy remains separate

ENEMY-001 deliberately leaves prototype encounter policy in `prototype_burrower_encounter_controller.gd`:

```text
TARGET_ENEMY_COUNT = 4
SPAWN_MIN_DISTANCE = 18.0
SPAWN_MAX_DISTANCE = 34.0
SPAWN_INTERVAL = 2.0
RELEASE_DISTANCE = 72.0
```

Candidate sampling, terrain checks, spawn serials, active-enemy lifetime and release policy are encounter/placement responsibilities. They are not creature-definition fields.

CONTENT-002/#77 may later consume authored creature definitions for deterministic underground placement. ENEMY-001 does not implement that placement system.

## Burrower migration

The encounter controller now loads the authored Burrower definition and passes `runtime_stats()` into the unchanged actor configuration seam.

This removes the concrete stat dictionary from the encounter controller while preserving:

- existing AI state-machine behavior;
- `receive_melee_attack` compatibility;
- parry/dodge/block behavior;
- gravity and turning;
- hit/parry reactions;
- spawn/release/terrain policy;
- placeholder presentation.

The placeholder `_build_placeholder_visual()` remains replaceable presentation and is not creature identity.

## Validation

The creature family fails closed when:

- semantic family `creature` resolves to a definition that is not `CreatureDefinition`;
- a creature category lies outside `category.creature`;
- an enemy omits required movement/sensing/melee capability declarations;
- required semantic references are missing or use the wrong family;
- the attack-profile target is not `CreatureAttackProfileDefinition`;
- the archetype target is not an accepted `ArchetypeDefinition`;
- animation-set or rig-profile targets use the wrong concrete definition type;
- the selected animation set targets a different rig profile;
- a required animation or rig role is not provided by the selected presentation contracts.

Focused tests also prove two compatible creature definitions can use the same `CreatureDefinition` boundary with different authored tuning and no concrete-ID branch in the encounter/combat manager.

## Forbidden patterns

Do not:

- put current health, timers, target state or wander state in shared creature definitions;
- move encounter counts/distances/terrain sampling into a creature definition;
- use scene/mesh/script paths as creature identity;
- add a concrete Burrower branch to a central content/combat manager;
- rewrite Burrower AI as part of authored-content migration;
- rebalance the Burrower during ENEMY-001;
- move melee resolution authority into animation clips or archetype presentation;
- absorb CONTENT-002, WEAPON-001, CONTENT-006 or MAP-016 scope.

## Minimal conceptual example

```text
content_id: creature.enemy.burrower
category: category.creature.enemy
capabilities:
  - capability.movement
  - capability.sensing
  - capability.combat.melee
baseline tuning:
  health: 36
  move_speed: 3.3
  detection_range: 16.0
  attack_range: 1.80
  damage: 10
  cooldown: 1.20
  windup: 0.42
references:
  combat.attack_profile: attack_profile.creature.burrower.melee
  presentation.archetype: archetype.creature.burrower.prototype
  presentation.animation_set: animation_set.humanoid.prototype
  presentation.rig_profile: rig_profile.humanoid.prototype
```
