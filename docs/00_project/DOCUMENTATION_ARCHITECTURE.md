# Underworld Documentation Architecture

Status: **LOCKED organization contract**

The documentation tree is part of the project architecture. It must remain navigable as the game grows from prototype systems into many content families.

## Numbered top-level sections

Numeric prefixes are **documentation ordering markers only**. They are not game versions, content IDs, save IDs, runtime IDs, or code namespaces.

```text
docs/
├─ 00_project/
├─ 10_architecture/
├─ 20_world/
├─ 30_gameplay/
├─ 40_content/
├─ 50_authoring/
└─ 60_validation/
```

The gaps between numbers are intentional. New top-level sections may be inserted later without renaming the whole tree.

## Section responsibilities

### `00_project`
Project-wide intent and governance:
- game pillars
- development rules
- decision log
- glossary
- documentation architecture

### `10_architecture`
System boundaries and dependency direction:
- content architecture
- runtime ownership
- persistence architecture
- registry/resolution architecture
- cross-system dependency rules

Architecture documents answer: **How is the system divided and who owns what?**

### `20_world`
World-specific architecture and design:
- surface / Underworld relationship
- deterministic generation
- graph topology
- streaming
- persistence of world deltas
- terrain rules

### `30_gameplay`
Runtime gameplay contracts:
- character
- combat
- survival
- crafting
- building
- harvesting

### `40_content`
Definition contracts and taxonomies:
- content IDs
- categories
- capabilities
- references
- rulebooks for items, creatures, structures, attacks, animations, audio, VFX, etc.

Rulebooks answer: **What makes one member of this content family valid?**

### `50_authoring`
Human workflows:
- adding a weapon
- adding a creature
- adding an animation set
- adding a structure
- validation commands and expected feedback

Authoring documents answer: **How do I create another valid piece of content?**

### `60_validation`
Machine-enforced contracts:
- content validation
- worldgen validation
- combat validation
- migration fixtures
- dependency/reference checks

Validation documents answer: **How do we prove the architecture and content contracts still hold?**

## Architecture vs rulebook vs authoring guide

These are deliberately separate document types.

An architecture document defines ownership and dependency direction.
A rulebook defines validity for a content family.
An authoring guide gives the concrete creation workflow.
A validation document defines executable checks.

Do not collapse all four into one giant document.

## Migration of existing flat documents

Existing root-level documents under `docs/` remain authoritative until explicitly migrated. This architecture cycle establishes the destination structure first.

Migration rules:
1. move documents only in documentation-only changes;
2. update repository references in the same change;
3. preserve history and meaning;
4. do not rewrite design merely to fit a folder name;
5. avoid mass renames while active implementation branches depend on old paths.

New documentation should use the numbered architecture unless there is a strong compatibility reason not to.

## Naming rules

- Folder numbers organize reading order only.
- File names remain semantic and descriptive.
- Game content uses semantic IDs such as `item.weapon.iron_sword`; documentation numbers never enter those IDs.
- Avoid dates/version numbers in permanent architecture filenames unless the document is explicitly historical.

## Scaling rule

Before a content family becomes large, it should have:
1. architecture placement;
2. stable identity rules;
3. category/capability rules where applicable;
4. a rulebook;
5. an authoring workflow;
6. validation coverage.

The purpose is to make future growth primarily an authoring problem rather than repeated infrastructure rewrites.
