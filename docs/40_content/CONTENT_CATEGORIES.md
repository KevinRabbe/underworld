# Content Category Rules

Status: **LOCKED classification direction**

Categories are controlled hierarchical labels that answer: **what kind of content is this?**

They are not runtime instances and must not become a hidden replacement for capabilities or gameplay systems.

## Hierarchical categories

Nested categories are allowed and encouraged where they make authoring/validation clearer.

Example:
```text
item
└─ equipment
   └─ weapon
      └─ melee
         └─ sword
            ├─ shortsword
            ├─ longsword
            └─ greatsword
```

Possible semantic registry form:
```text
category.item
category.item.equipment
category.item.equipment.weapon
category.item.equipment.weapon.melee
category.item.equipment.weapon.melee.sword
category.item.equipment.weapon.melee.sword.longsword
```

## Classification vs behavior

Categories primarily classify.

Good:
```text
categories:
  item
  item.equipment
  item.equipment.weapon
  item.equipment.weapon.melee
  item.equipment.weapon.melee.axe
```

Behavior belongs in capabilities/definitions:
```text
capabilities:
  equipable
  damage_dealer
  harvest_tool
  repairable
```

Do not rely on `category == axe` to secretly implement all axe mechanics.

## Category inheritance of validation

A category may add required data/reference constraints.

Example:
```text
Item
  requires item identity/inventory contract

Equipment
  additionally requires equipment profile

Weapon
  additionally requires attack set

MeleeWeapon
  additionally requires melee hit profile

Sword
  may require compatible sword animation family
```

A member must satisfy every applicable parent rule.

This is validation composition, not runtime class inheritance.

## Controlled vocabulary

Categories come from an authoritative category registry/schema.

Definitions must not invent arbitrary category strings such as:
```text
cool_sword
weaponthing
melee2
```

Unknown categories become validation errors.

## Multiple categories

Content may participate in more than one compatible category branch when semantically useful, but this must remain understandable and valid under each branch's constraints.

Capabilities are preferred when the second classification is really about behavior rather than identity.

## Category parent rules

- one category may have a canonical parent;
- category ancestry must be deterministic;
- category parent cycles are forbidden;
- deleting/renaming a used category is a schema/versioning change;
- leaf categories should be added only when they provide meaningful organization or validation value.

## Categories must not contain runtime state

A category must not reference:
- current player state;
- loaded Nodes;
- save-specific values;
- runtime AI state;
- physics objects.

## Query usage

Systems/tools may use categories for filtering, authoring UIs, validation, loot/spawn eligibility or high-level dispatch where appropriate.

Specific gameplay behavior should prefer typed definitions/capabilities rather than giant category switches.

## Future validation

Validation should check:
- category exists;
- parent exists;
- no parent cycle;
- definition satisfies parent/category requirements;
- category is legal for the definition family;
- category combinations do not violate declared incompatibilities.
