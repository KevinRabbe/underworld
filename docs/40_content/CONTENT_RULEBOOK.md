# Content Rulebook Contract

Status: **LOCKED meta-rule**

Every scalable content family must define what allows one member of that family to exist validly in Underworld.

A rulebook is a contract, not a lore/design essay.

## Required sections for family rulebooks

Each family rulebook should cover, where applicable:

1. **Purpose** — what the family represents.
2. **Stable identity** — required semantic ID namespace and migration rules.
3. **Category contract** — required/allowed hierarchical categories.
4. **Capability contract** — required/allowed capabilities.
5. **Required definition data** — fields that must exist.
6. **Optional definition data** — supported extensions/default behavior.
7. **References** — allowed/required referenced content roles.
8. **Assets** — required/optional visual/audio/animation/VFX roles.
9. **Runtime ownership** — which system interprets/owns live instances.
10. **Persistence** — what is saved and by which identity.
11. **World-generation relationship** — whether deterministic generation may select/reference it.
12. **Versioning/migration** — compatibility-sensitive changes.
13. **Validation** — executable invariants.
14. **Forbidden patterns** — known architecture traps.
15. **Minimal valid example** — smallest definition satisfying the contract.
16. **Production-ready example** — optional richer example when useful.

## Compositional rulebooks

Child families compose parent contracts.

Example:
```text
ITEM_RULEBOOK
  ↓
EQUIPMENT_RULEBOOK
  ↓
WEAPON_RULEBOOK
  ↓
MELEE_WEAPON_RULEBOOK
  ↓
SWORD_RULEBOOK
```

A sword rulebook should not copy all generic item rules. It should state what it inherits and what additional constraints it adds.

Validation follows the same composition.

## Categories inside families

Families may define nested categories where meaningful.

Example:
```text
weapon
└─ melee
   └─ sword
      ├─ shortsword
      ├─ longsword
      └─ greatsword
```

A child category should exist because it improves organization, validation or authoring—not merely because another label is possible.

## Capabilities instead of combination subclasses

If behavior can be composed, prefer capabilities over one bespoke subtype per combination.

Example:
```text
axe
+ equipable
+ damage_dealer
+ harvest_tool
+ repairable
```

instead of inventing a unique infrastructure type for every combination.

## What allows content to exist

A definition is considered valid only when:
- its ID is unique and valid;
- all required parent/family rules pass;
- its categories/capabilities are registered and compatible;
- all required typed references resolve;
- required asset roles exist;
- forbidden dependencies are absent;
- compatibility/versioning constraints are satisfied.

Runtime code should be allowed to assume that validated authored content satisfies these basic structural contracts.

## New family gate

Before a new content family scales beyond a trivial prototype, require:
- architecture placement;
- family rulebook;
- category/capability decision;
- stable ID namespace;
- reference roles;
- authoring guide;
- baseline validation.

Prototype experiments may precede this, but must not silently become permanent large-scale content without the gate.

## Forbidden patterns

Do not allow rulebooks to become excuses for:
- one class per content ID;
- central managers containing every member ID;
- undocumented magic strings;
- file paths as persistent identity;
- category hierarchies that execute all gameplay;
- duplicate copies of parent rules that drift independently.

## Architecture change rule

If ordinary content cannot be represented by the current contracts, first determine whether:
1. the content is genuinely introducing a new mechanic; or
2. the architecture is missing a reusable concept.

Do not immediately add an ID-specific exception.
