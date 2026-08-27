# Rig Profile Rulebook

Status: **DIRECTIONAL first-family dependency contract**

Rig profiles define the semantic skeleton/socket roles that allow animation sets, equipment and character presentation to survive replacement of the concrete model/skeleton.

The profile is presentation architecture. It must not own player movement/combat rules.

## Stable identity

Rig profiles are authored content definitions with semantic IDs such as:
```text
rig_profile.humanoid.prototype
rig_profile.humanoid.standard
```

Concrete imported skeletons may have arbitrary bone names. They map those names to controlled semantic rig-role IDs.

## Rig-role schema

Rig roles use controlled `rig_role.*` schema identifiers.

Directional humanoid roles:
```text
rig_role.root
rig_role.pelvis
rig_role.spine.lower
rig_role.spine.upper
rig_role.chest
rig_role.neck
rig_role.head

rig_role.clavicle.left
rig_role.upper_arm.left
rig_role.forearm.left
rig_role.hand.left
rig_role.clavicle.right
rig_role.upper_arm.right
rig_role.forearm.right
rig_role.hand.right

rig_role.thigh.left
rig_role.calf.left
rig_role.foot.left
rig_role.thigh.right
rig_role.calf.right
rig_role.foot.right

rig_role.socket.hand.left
rig_role.socket.hand.right
rig_role.socket.back
rig_role.socket.hip.left
rig_role.socket.hip.right
```

Exact humanoid-role vocabulary may evolve before production rigs depend on it.

## Required definition data

A valid rig profile should eventually define:
- semantic rig-profile ID;
- compatible broad rig family/category;
- semantic `rig_role.*` → concrete bone/socket mapping;
- skeleton/root path or adapter reference within the presentation scene/resource boundary;
- scale/orientation conventions where required for retargeting;
- optional retarget/rest-pose metadata.

## Categories

Directional category IDs may include:
```text
category.rig_profile
category.rig_profile.humanoid
```

Categories classify the profile. They do not determine player combat mechanics.

## Socket contract

Gameplay/equipment systems refer to semantic socket roles, never imported bone paths.

Good:
```text
rig_role.socket.hand.right
rig_role.socket.back
```

Bad:
```text
Skeleton3D/BoneAttachment3D_17
Armature/Skeleton3D:mixamorig_RightHand
```
inside gameplay/equipment logic.

The rig/presentation adapter owns conversion from semantic socket role to concrete bone/attachment.

## Animation compatibility

Animation sets reference a compatible `rig_profile.*` definition.

A production model may reuse an animation set when:
- required rig roles can be mapped;
- retarget/rest-pose constraints are satisfied;
- required sockets exist;
- presentation validation passes.

The model does not need to use the prototype's exact imported bone names.

## Equipment compatibility

Equipment definitions/scenes may request semantic attachment roles such as `rig_role.socket.hand.right`.

A missing required socket is a validation/presentation compatibility error rather than a reason to hard-code another path into gameplay.

## Gameplay separation

Rig profiles do not own:
- movement speed;
- collision capsule;
- health/stamina;
- attack damage/reach;
- dodge movement/i-frames;
- parry/block rules;
- action-state timing.

The existing gameplay body remains independent from the visual rig.

## Runtime ownership

A character presentation/animation adapter will eventually:
- resolve the rig profile;
- map semantic roles to concrete Skeleton3D bones/attachments;
- expose equipment socket transforms;
- support animation retargeting/mapping;
- keep gameplay unaware of concrete bone names.

## Validation

Future rig-profile validation should check:
- valid/unique `rig_profile.*` ID;
- required `rig_role.*` IDs exist;
- concrete mapped bones/sockets exist;
- no required role has conflicting mappings;
- required parent-chain relationships are structurally coherent where applicable;
- animation-set required roles are supported;
- equipment-required sockets are supported;
- orientation/scale/retarget metadata is valid where required.

## Minimal prototype profile

The current box mannequin should become the first implementation of:
```text
rig_profile.humanoid.prototype
```

It should map the existing ~21-bone skeleton and current hand/back/hip sockets to semantic `rig_role.*` IDs.

Later replacing the mannequin should require a new/compatible rig mapping, not changes to player motor/action/combat code.

## Forbidden patterns

- gameplay scripts referencing concrete imported bone names;
- equipment definitions storing arbitrary Skeleton3D paths as semantic attachment identity;
- one player controller per skeleton/model;
- collision body driven by visual limb transforms in the normal player architecture;
- changing the model requiring combat/action-system rewrites.
