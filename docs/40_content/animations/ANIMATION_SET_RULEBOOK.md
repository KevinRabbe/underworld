# Animation Set Rulebook

Status: **DIRECTIONAL first-family contract**

Animation sets are the first content family intended to prove the reusable architecture → rulebook → authoring → validation pattern.

This document defines the content contract only. It does not implement the AnimationTree/AnimationPlayer migration.

## Purpose

An animation set maps stable semantic animation roles used by gameplay/presentation adapters to concrete animation assets compatible with a rig/profile.

The box mannequin is replaceable. Animation semantics and authoring contracts should survive that replacement.

## Stable identity

Animation sets use semantic IDs such as:
```text
animation_set.humanoid.prototype
animation_set.humanoid.one_handed_sword
animation_set.humanoid.two_handed_axe
```

Individual semantic actions should also use controlled names/IDs rather than gameplay depending on raw clip filenames.

Directional semantic vocabulary:
```text
locomotion.idle
locomotion.walk_forward
locomotion.walk_backward
locomotion.strafe_left
locomotion.strafe_right
locomotion.sprint
locomotion.jump_start
locomotion.fall
locomotion.land

action.attack.light_01
action.dodge.forward
action.dodge.backward
action.dodge.left
action.dodge.right
action.parry
action.block

reaction.hit.front
reaction.death
```

Exact vocabulary may evolve before production content depends on it.

## Categories

Directional categories may include:
```text
animation_set
animation_set.humanoid
animation_set.humanoid.locomotion
animation_set.humanoid.combat
```

Categories classify the set; they do not decide combat timing/damage.

## Required definition data

A valid animation set should eventually define:
- semantic content ID;
- compatible rig/profile family;
- mapping from required semantic animation roles to concrete animations;
- animation library/resource references;
- root-motion policy;
- optional blend/layer metadata where the presentation system needs it.

## Optional data

May include:
- additive overlays;
- upper-body variants;
- equipment-specific variants;
- playback-rate bounds;
- fallback semantic roles;
- turn/landing variants.

## Gameplay separation

Animation sets do not own:
- attack damage;
- hit geometry;
- stamina cost;
- parry success rules;
- dodge i-frame timing;
- action legality.

Those remain gameplay/action-definition responsibilities.

The animation layer visualizes semantic actions and may expose timing markers only through explicit contracts where needed.

## Rig compatibility

Animation sets target a semantic rig/profile rather than gameplay knowing concrete bone paths.

Important roles may include:
```text
pelvis
chest
head
hand_l
hand_r
foot_l
foot_r
socket_hand_l
socket_hand_r
socket_back
```

A production character with different imported bone names can use a rig mapping/retargeting adapter.

## Asset replacement

Replacing the box mannequin or improving an animation clip must not require changes to player movement/combat logic if semantic roles and rig compatibility remain valid.

## Runtime ownership

A `CharacterAnimationController`/presentation adapter will eventually:
- receive gameplay state/semantic action requests;
- resolve the animation set;
- drive AnimationTree/AnimationPlayer;
- map semantic rig/socket roles to concrete rig resources.

Gameplay code should not manipulate bones directly once this pipeline is established.

## Validation

Future animation-set validation should check:
- valid/unique animation-set ID;
- compatible rig profile exists;
- required semantic roles exist;
- mapped animation resources/clips exist;
- no duplicate/ambiguous required role mapping;
- root-motion policy is declared;
- required equipment sockets/rig roles exist where the set needs them.

It must not try to judge animation artistic quality automatically.

## Minimal valid prototype set

For the current player foundation, the first reusable set should cover at least:
```text
idle
walk/run directional locomotion
sprint
jump/fall/land
light attack
dodge directions
parry
block
hit reaction
death
```

The first implementation may convert current procedural placeholder poses into actual reusable Animation resources while retaining the box mannequin.

## Forbidden patterns

- gameplay code hard-coding imported animation filenames;
- animation assets owning attack damage/stamina rules;
- bone-path manipulation spread through player gameplay code;
- one animation controller implementation per weapon ID;
- replacing the character model requiring a player/combat rewrite.
