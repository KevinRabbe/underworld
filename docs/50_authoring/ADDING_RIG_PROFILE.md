# Adding a Rig Profile

Status: **DIRECTIONAL authoring guide**

Rig-profile authoring maps a concrete Skeleton3D/model setup to Underworld's semantic `rig_role.*` schema so animation/equipment systems do not depend on imported bone names.

## Workflow

1. Choose a semantic rig-profile ID, for example:
   ```text
   rig_profile.humanoid.prototype
   ```
2. Select the compatible rig category, for example:
   ```text
   category.rig_profile.humanoid
   ```
3. Identify the concrete Skeleton3D/root used by the presentation scene.
4. Map every required `rig_role.*` ID to a concrete bone/socket.
5. Define scale/orientation/rest-pose/retarget metadata required by the animation pipeline.
6. Verify required equipment socket roles.
7. Run rig-profile/content validation.
8. Run animation-set compatibility validation.
9. Run character presentation integration tests.
10. Only then evaluate visual/animation quality in-game.

## Prototype humanoid minimum

The first box-mannequin profile should map at least:
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

## Importing a different humanoid

A new model does not need the prototype bone names.

Instead:
1. import the model/skeleton;
2. create or reuse an appropriate `rig_profile.*` definition;
3. map its concrete bones to the same semantic `rig_role.*` roles;
4. retarget/reuse compatible animation sets;
5. keep gameplay code unchanged.

## Socket rule

Equipment authoring uses semantic socket roles.

Do not add imported bone paths to weapon/item gameplay definitions merely because one model names its right hand differently.

## Definition of done

A rig profile is structurally done when:
- semantic ID is valid/unique;
- all required rig roles resolve to concrete bones/sockets;
- required socket roles exist;
- orientation/scale/retarget metadata is valid;
- intended animation sets validate against it;
- no gameplay/equipment code gained a concrete bone-path special case.
