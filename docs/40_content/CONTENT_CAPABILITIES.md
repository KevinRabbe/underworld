# Content Capability Rules

Status: **LOCKED behavioral-composition direction**

Capabilities answer: **what behavior contracts may this content participate in?**

They complement categories. Categories classify; capabilities declare compatible behavior interfaces.

## Examples

Initial directional capability vocabulary may include:
```text
capability.equipable
capability.damage_dealer
capability.damageable
capability.harvestable
capability.harvest_tool
capability.placeable
capability.container
capability.consumable
capability.repairable
capability.fuel
capability.light_source
capability.interactable
capability.parry_tool
```

The exact registry grows deliberately as systems are introduced.

## Composition

A content definition may combine multiple capabilities.

Example axe:
```text
categories:
  item.equipment.weapon.melee.axe

capabilities:
  equipable
  damage_dealer
  harvest_tool
  repairable
```

Example torch:
```text
categories:
  item.equipment.utility.torch

capabilities:
  equipable
  placeable
  light_source
  fuel
```

This avoids creating one runtime class for every behavior combination.

## Capability contract

A capability may require specific definition fields, references or runtime interfaces.

Example direction:
```text
capability.equipable
  requires equipment_profile

capability.harvest_tool
  requires harvest_profile

capability.light_source
  requires light_profile
```

The capability itself does not execute gameplay. Runtime systems consume validated capability data.

## Controlled vocabulary

Capabilities come from a registry/schema. Unknown capability strings are validation errors.

Do not casually create near-duplicates such as:
```text
repairable
can_repair
repair_item
```

One semantic concept should have one authoritative capability contract.

## Capability vs category

Use a category when the distinction answers **what is it?**
Use a capability when the distinction answers **what can it do / participate in?**

A sword being a sword is a category.
A sword being repairable is a capability.

## Capability vs attack/profile data

Capabilities should remain coarse interfaces, not become huge bags of tuning numbers.

For example `damage_dealer` may require an attack/weapon profile reference; it should not duplicate every attack's timing, reach and damage inside the capability declaration.

## Runtime boundary

Runtime systems may query validated capabilities to decide whether a definition can enter a workflow.

Examples:
- equipment system accepts `equipable` definitions;
- harvesting system accepts `harvest_tool` definitions;
- building placement accepts `placeable` definitions.

Systems should still consume typed definition/profile data rather than branch on every concrete content ID.

## Compatibility constraints

Some capabilities may require or forbid others. Such rules belong in the capability schema/rulebook and must be machine-validatable.

Do not encode undocumented assumptions only in runtime code.

## Future validation

Validation should check:
- capability exists;
- capability is legal for the content family/category;
- required fields/references are present;
- required companion capabilities are present;
- forbidden combinations are absent;
- referenced profiles satisfy expected type/contract.
