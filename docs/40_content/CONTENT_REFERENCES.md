# Content Reference Rules

Status: **LOCKED reference direction**

Content definitions reference other content through semantic, typed roles. References are part of the authored definition graph and should be validated before runtime whenever practical.

## Reference shape

A reference should communicate both target identity and expected role/type.

Conceptual example:
```text
weapon.attack_set -> attack_set.sword.one_handed.basic
weapon.animation_set -> animation_set.humanoid.one_handed_sword
recipe.output -> item.weapon.iron_sword
creature.loot_table -> loot_table.underworld.burrower
```

Avoid ambiguous untyped bags of arbitrary IDs when a stable semantic role exists.

## Semantic IDs, not file paths

Cross-definition references use content IDs rather than paths.

Bad:
```text
res://content/items/weapons/iron_sword.tres
```
as the authoritative recipe output identity.

Good:
```text
item.weapon.iron_sword
```

The registry resolves the current definition/resource location.

## Required vs optional references

Family rulebooks define which references are:
- required;
- optional;
- one-of alternatives;
- arrays/sets;
- forbidden for that category/capability.

A missing required reference is a validation error, not a late runtime surprise.

## Reference compatibility

A reference target must satisfy the expected family/category/capability contract.

Example:
```text
weapon.attack_set
```
may not point to:
```text
item.resource.wood
```
even though both are syntactically valid content IDs.

## Weak/display-only references

Some references may be non-gameplay metadata, previews or optional presentation links. These should be explicitly identified so missing optional content does not accidentally become a hard gameplay dependency.

## Cycles

Reference graphs are acyclic by default.

A family that intentionally supports recursion (for example nested loot tables) must define:
- whether cycles are forbidden;
- maximum nesting/expansion rules;
- deterministic traversal behavior;
- validation strategy.

Undocumented cycles are errors.

## Runtime resolution

Runtime systems resolve definitions through the registry/resolver boundary. Definitions do not instantiate or own each other directly merely because they reference each other.

## Versioning

Changing a referenced content ID after persistent use is a migration concern. Removing a referenced definition requires either:
- updating all references in the same compatible change; or
- providing an explicit compatibility/migration strategy.

## Diagnostics

Validation errors should name:
- source definition ID;
- reference role;
- missing/incompatible target ID;
- expected family/category/capability.

Example:
```text
item.weapon.deep_sword
  reference role: attack_set
  target: attack_set.sword.deep_01
  error: target does not exist
```
