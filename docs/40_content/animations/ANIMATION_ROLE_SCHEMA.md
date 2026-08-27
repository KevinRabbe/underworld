# Animation Role Schema

Status: **DIRECTIONAL schema contract**

`animation_role.*` identifiers are controlled semantic presentation roles. They allow gameplay/presentation code to request meaning such as "parry" or "dodge left" without depending on imported clip filenames.

Animation roles are schema identifiers, not authored content definitions.

## Namespace

Use:
```text
animation_role.<domain>.<semantic role>
```

Directional domains:
```text
animation_role.locomotion.*
animation_role.action.*
animation_role.reaction.*
animation_role.utility.*
```

## Prototype vocabulary

Initial humanoid roles:
```text
animation_role.locomotion.idle
animation_role.locomotion.walk_forward
animation_role.locomotion.walk_backward
animation_role.locomotion.strafe_left
animation_role.locomotion.strafe_right
animation_role.locomotion.sprint
animation_role.locomotion.jump_start
animation_role.locomotion.fall
animation_role.locomotion.land

animation_role.action.attack.light_01
animation_role.action.dodge.forward
animation_role.action.dodge.backward
animation_role.action.dodge.left
animation_role.action.dodge.right
animation_role.action.parry
animation_role.action.block

animation_role.reaction.hit.front
animation_role.reaction.death
```

The vocabulary is directional until the first reusable animation implementation proves it.

## Semantics, not filenames

Good:
```text
animation_role.action.parry
```

Concrete mapping may be:
```text
"humanoid_parry_proto"
"knight_sword_parry_A"
"dwarf_short_parry"
```

Gameplay continues requesting the semantic role.

## Variant rule

Do not create a new semantic role merely because an imported pack contains multiple clips.

Variants that mean the same gameplay/presentation concept should normally remain data under one role:
```text
animation_role.reaction.hit.front
  variants = [front_a, front_b, front_c]
```

Create a new role only when the distinction is semantically meaningful to systems or authoring.

## Gameplay boundary

Animation-role IDs never own:
- damage;
- attack phase timing;
- stamina cost;
- i-frame timing;
- parry/block logic;
- action legality.

They are presentation vocabulary.

## Stability

Once animation sets and gameplay/presentation adapters depend on a role ID, renaming/removing it is a schema change.

Do not reuse an old role ID for different semantics.

## Validation

Future validation should check:
- role ID exists in the controlled schema;
- required animation-set roles are present;
- unknown role IDs are rejected;
- duplicate conflicting mappings are rejected;
- role family is compatible with the animation-set/rig contract where applicable.
