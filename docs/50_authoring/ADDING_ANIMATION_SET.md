# Adding an Animation Set

Status: **DIRECTIONAL authoring guide**

This is the first family-specific authoring guide and is intended to prove the reusable content workflow before animation implementation begins.

## Preconditions

Before authoring an animation set:
- the semantic animation-set ID namespace must be valid;
- the target rig/profile family must be known;
- required semantic animation roles must be defined by the animation-set rulebook;
- the referenced animation assets/libraries must exist or be created as part of the same change.

## Workflow

1. Choose a semantic ID, for example:
   ```text
   animation_set.humanoid.prototype
   ```
2. Choose the compatible rig/profile family.
3. Start from the minimal animation-set template once implemented.
4. Map required semantic animation roles to concrete animations.
5. Declare root-motion policy.
6. Add optional variants/layers only where the presentation controller supports them.
7. Run content validation.
8. Resolve all missing/duplicate/incompatible role errors.
9. Run character/presentation integration tests.
10. Playtest visual quality only after structural validation passes.

## Required prototype roles

The first humanoid prototype set should cover:
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

## Replacing an animation

To improve a clip:
1. keep the semantic role unchanged;
2. replace/remap the concrete animation asset;
3. keep gameplay timing/data in gameplay contracts unless an explicit cross-contract timing revision is made;
4. rerun validation/integration tests.

Gameplay code should not need modification merely because animation art improved.

## Replacing the character model

When replacing the box mannequin:
1. provide/verify rig mapping to the semantic rig profile;
2. verify equipment socket roles;
3. reuse the existing animation set when compatible or retarget it;
4. run animation-set validation;
5. run character integration tests.

Do not rewrite player movement/combat because imported bone names differ.

## When a new animation role is justified

Add a new semantic role only when gameplay/presentation needs a genuinely distinct concept.

Do not create role IDs for every imported filename or every cosmetic variation. Variants should remain data under one semantic concept where possible.

## Definition of done

An animation set is structurally done when:
- semantic ID is unique/valid;
- rig/profile compatibility is valid;
- all required semantic roles resolve;
- all referenced animations exist;
- root-motion policy is valid;
- content validation passes;
- gameplay code contains no new animation-filename/bone-path special case.
