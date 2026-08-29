# Weapon Rulebook

Status: **WEAPON-001 executable ITEM-child contract**

This rulebook specializes the accepted [Item Rulebook](ITEM_RULEBOOK.md) for authored weapons. A weapon remains an `item.*` definition: WEAPON-001 does not introduce a parallel identity family, inventory model, combat resolver or presentation registry.

## Ownership

`WeaponDefinition` owns immutable authored weapon binding data only:

- the semantic `item.*` ContentId and common `ItemDefinition` fields;
- a registered category under `category.item.equipment.weapon`;
- the `capability.damage_dealer` capability declaration;
- a semantic light-attack profile ID consumed by the existing player attack-definition boundary;
- a semantic attack animation role;
- a semantic rig socket/grip role;
- a semantic presentation/archetype ContentId;
- small immutable grip metadata needed to describe the authored weapon.

Per-copy durability, equipped state, inventory position, modifiers, runtime Nodes and save-instance identity do **not** belong in `WeaponDefinition`.

## Attack handoff

Weapons select an attack through an `attack_profile.*` semantic ID. `WeaponAttackAdapter` resolves that ID through `PlayerAttackCatalog.for_profile()` and returns the existing `PlayerAttackDefinition` contract.

The weapon definition does not own or duplicate startup, active, recovery, damage, reach, hit radius, facing thresholds or execution payload fields. Those values remain in `PlayerAttackDefinition` / `PlayerAttackCatalog`, and `PlayerActionController` remains authoritative for phase timing and one-shot activation.

The legacy `for_tool()` compatibility entrypoint remains for hands, stone axe and stone pickaxe, but it now delegates to the same semantic attack-profile boundary. Adding an authored sword does not add a `prototype_sword`, `stone_sword` or other concrete sword branch to Player, PlayerAttackCatalog or a central combat manager.

## Presentation binding

Weapon presentation is semantic rather than path-based. The authored definition carries:

- an `animation_role.action.attack.*` role;
- a `rig_role.socket.*` grip/socket role;
- a semantic presentation/archetype ContentId.

The WEAPON-001 rule extension checks the animation and rig roles against the accepted semantic-role registry. Bone names, AnimationPlayer track names, scene paths and imported asset paths are presentation implementation details and are not weapon identity.

Changing the presentation archetype or realization path does not change the weapon ContentId or attack timing.

## Child validation

WEAPON-001 composes through `ItemRuleExtension`; `ItemFamilyValidator` remains the owning item-family validator. This avoids a second content-family registry and makes weapon-category selection fail closed.

A weapon-category definition is valid only when:

1. it inherits `WeaponDefinition`;
2. it retains the semantic `item` definition family;
3. it declares a registered category at or below `category.item.equipment.weapon`;
4. it declares `capability.damage_dealer`;
5. its light-attack profile exists in the attack-definition boundary;
6. its attack animation role is registered;
7. its grip role is a registered rig socket role;
8. its required semantic presentation/archetype reference resolves through CONTENT-005;
9. all inherited ITEM-001 definition rules pass.

A plain `ItemDefinition` authored under the weapon category is rejected rather than silently treated as a generic item.

## Minimal sword proof

`content/items/weapons/prototype_sword.tres` is the initial proof. It uses:

```text
ContentId: item.weapon.prototype_sword
category: category.item.equipment.weapon.melee.sword
capability: capability.damage_dealer
attack profile: attack_profile.player.standard_blade_light
animation role: animation_role.action.attack.light_01
grip role: rig_role.socket.hand.right
presentation: archetype.weapon.prototype_sword
```

The concrete sword ID is not known by `PlayerAttackCatalog`. The attack catalog knows only semantic attack profiles; multiple weapon definitions can select different profiles and different presentation bindings through the same generic adapter.

## Extensibility rule

A new simple weapon should normally require authored definition/resource work, registered category/capability/semantic-role vocabulary where genuinely new, and an attack profile only when the existing attack-definition vocabulary cannot express it. It must not require a new concrete-item branch in Player or a central combat manager.

Future combos, heavy attacks, skills, enemy-family rules, loot/drop tables, full durability behavior and inventory/equipment UX are separate tasks. WEAPON-001 intentionally does not define them.

## Forbidden patterns

Do not:

- switch on concrete weapon ContentIds in Player or central combat managers;
- copy attack timing or damage fields into `WeaponDefinition`;
- use bone names, clip names, scene paths or asset paths as semantic weapon bindings;
- mutate shared weapon definitions for durability/equipped/per-copy state;
- bypass ITEM-001 or CONTENT-005 validation;
- create a second item identity or content registry for weapons;
- absorb MAP-016 world generation, ENEMY-001, loot tables or advanced combat into this rulebook.
