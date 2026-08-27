# Content Authoring Contract

Status: **LOCKED workflow direction**

Authoring guides translate architecture/rulebooks into repeatable creation steps. They should make the tenth or hundredth content member cheaper to create than the first.

## Standard authoring workflow

For an ordinary new content member:

1. choose the correct content family;
2. assign a unique semantic content ID;
3. select registered categories;
4. declare supported capabilities;
5. fill required family fields;
6. assign typed references;
7. assign required asset roles;
8. run content validation;
9. resolve all structural errors;
10. only then test runtime feel/behavior.

## Template-first authoring

Where practical, each mature family should provide:
- a minimal valid template;
- optional richer templates for common variants;
- an authoring checklist;
- validation diagnostics.

Duplicating a template is acceptable. Duplicating runtime infrastructure is not.

## Adding a category/capability

Do not invent a new category/capability merely to finish one asset quickly.

Before adding one:
- check whether an existing term already represents the concept;
- decide whether it is classification or behavior;
- document required parent/constraints;
- add schema/validation support;
- then use it in content.

## When code changes are expected

Ordinary members of an established family should usually require no central-system code changes.

Code changes are reasonable when:
- introducing a genuinely new mechanic;
- adding a new reusable capability/system;
- extending the family schema deliberately;
- creating new authoring/validation tooling.

If adding a normal sword requires editing several managers, stop and review the architecture.

## Asset replacement rule

Presentation assets should be replaceable without changing semantic content identity or unrelated gameplay definitions.

Example:
```text
item.weapon.iron_sword
```
may receive a new model/animation/audio set without becoming a different item ID unless gameplay semantics truly changed identity.

## Validation before playtest

Structural validity is automated first. Human playtests answer feel/pacing/readability questions after content passes structural validation.

Do not use manual playtesting as the primary way to discover missing IDs, references or rulebook-required fields.

## Family-specific guides

Once a family becomes active, create focused guides such as:
```text
ADDING_A_WEAPON.md
ADDING_A_CREATURE.md
ADDING_AN_ANIMATION_SET.md
ADDING_A_STRUCTURE.md
```

Those guides inherit this workflow and document only family-specific steps.

## Definition-of-done for authored content

A new authored member is structurally done when:
- semantic ID is valid/unique;
- all applicable rulebooks pass;
- references resolve;
- required assets exist;
- registry discovers it;
- content validation passes;
- no central ID-specific workaround was introduced.

Gameplay/art quality acceptance is a separate milestone.
