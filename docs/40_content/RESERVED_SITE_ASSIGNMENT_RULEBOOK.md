# Reserved-Site Content Assignment Rulebook

Status: **CONTENT-001 executable authored-content contract**

This rulebook defines the authored-content boundary that maps deterministic generic underworld `reserved_site` hooks to semantic content definitions. It consumes the accepted CONTENT-003/004/005 content foundation and does not redefine procedural world generation, SchemaId vocabulary, category/capability registries, or cross-registry validation.

## Purpose and direction

World generation reserves spatial opportunities. Authored content decides what those opportunities mean to gameplay.

```text
Deterministic reserved-site hook
  StableId + bounds + anchor/profile
                ↓
ReservedSiteAssignmentService
                ↓
ReservedSiteContentDefinition
  ContentDefinition + category_ids + site eligibility/weight
                ↓
ReservedSiteAssignment overlay
```

Dependency direction is one-way:

```text
worldgen generic hook  →  content assignment
```

Never:

```text
content assignment  →  worldgen topology/geometry decisions
worldgen  →  global ContentRegistry
```

The assignment layer is pure overlay data. It does not own runtime Nodes, geometry, streaming, collision, or persistence lifetime.

## Parent content contract

`ReservedSiteContentDefinition` derives from the accepted `ContentDefinition` Resource.

Generic authored truth is therefore inherited:

- `content_id` and `definition_family` via `ContentId`;
- `schema_revision`;
- `category_ids` and `capability_ids`;
- SchemaId syntax/duplicate validation;
- canonical ordering of generic schema declarations;
- normal `ContentRegistry` indexing/resolution;
- CONTENT-005 category/capability existence validation when definitions are authoring/load validated.

CONTENT-001 must not maintain a second semantic-ID parser, base definition model, category declaration array, CategorySchemaRegistry, or validation pipeline.

The reserved-site subtype owns only:

- the family invariant that at least one inherited `category_id` is declared;
- `eligible_hook_categories` — deterministic world-hook vocabulary, separate from CategorySchema identity;
- `selection_weight` — positive deterministic relative selection weight;
- `minimum_profile` / `maximum_profile` — normalized hook-profile eligibility window;
- family-specific `metadata`.

## One canonical category truth

Authored classification lives only in inherited `ContentDefinition.category_ids`.

Example:

```text
category_ids:
  - category.structure
  - category.structure.underworld
  - category.structure.underworld.shrine
```

A reserved-site definition must declare at least one `category_id`. That non-empty requirement is a family invariant owned by `ReservedSiteContentDefinition`; syntax and duplicate checks remain inherited from `ContentDefinition`/`SchemaId`, while registered-schema existence and compatibility remain CONTENT-005/`CategorySchemaRegistry` responsibilities.

The subtype does not declare or validate a parallel `categories` field. Generic syntax and duplicate checks are inherited from `ContentDefinition`/`SchemaId`; registered-schema existence and compatibility are checked by the accepted validation pipeline and `CategorySchemaRegistry` before definitions are admitted to normal authored-content use.

The deterministic assignment service remains registry-independent. It receives definition objects that are expected to have passed the appropriate authoring/load validation and uses their canonical semantic data without resolving a global registry during world assignment.

`ReservedSiteAssignment.category_ids` is only an immutable **assignment snapshot** copied from the selected definition's inherited `category_ids`. It is not a second authored declaration source.

The assignment fingerprint likewise consumes that same inherited category list in canonical sorted order. Therefore:

- caller category order is not semantic;
- changing a category declaration changes compatibility-sensitive assignment identity;
- changing category declarations never changes the procedural site StableId or reserved bounds.

## Hook eligibility is not CategorySchema identity

`eligible_hook_categories` remains family-owned because it describes which generic deterministic site hooks a definition may occupy. The initial vocabulary is the existing world hook category:

```text
reserved_site
```

This is deliberately independent from authored `category_ids`. A definition can keep identical CategorySchema identity while changing hook eligibility, and vice versa.

Future hook categories require an actual deterministic-world contract exposing a new generic site family. Ordinary authored variation belongs in content definitions/categories/rules, not new worldgen branches.

## Stable identity

The generated site keeps procedural identity:

```text
site_stable_id = sid1:...
```

The selected definition keeps semantic identity, for example:

```text
structure.underworld.crystal_shrine
structure.underworld.watch_post
spawn_profile.underworld.guardian_event
```

These answer different questions:

- procedural StableId: **which generated site is this?**
- semantic ContentId: **what authored concept is assigned here?**

Assignment must never replace, derive, rewrite, or alias the hook StableId. `rsa1:<sha256>` is a compatibility/debug fingerprint only; it is neither semantic content identity nor procedural world identity.

## Deterministic selection

For a fixed input contract, `ReservedSiteAssignmentService`:

1. checks local definition validity through the inherited ContentDefinition boundary plus the reserved-site non-empty-category, hook/profile and weight rules;
2. canonicalizes definitions by `content_id`;
3. canonicalizes hooks by procedural StableId;
4. filters by explicit hook category and profile eligibility;
5. selects by StableId, rulebook revision, canonical definition IDs/schema revisions, and deterministic weights;
6. emits assignments in StableId order;
7. fingerprints the selected definition using its inherited `category_ids` in canonical order.

Caller array order, frame order, loaded-node order, wall-clock time, and mutable global RNG state are not semantic inputs.

`rulebook_revision` owns compatibility-sensitive assignment-policy changes. Inherited `schema_revision` owns compatibility-sensitive authored-definition changes. Both participate in assignment compatibility data.

## Assignment overlay

A `ReservedSiteAssignment` records:

- original `site_stable_id`;
- original site AABB;
- assigned semantic `content_id`;
- canonical `category_ids` snapshot sourced from inherited `category_ids`;
- assignment `rulebook_revision`;
- selected definition's `content_schema_revision` snapshot;
- `assignment_fingerprint`;
- copied definition metadata.

The overlay does not own or mutate the source hook or registered definition.

## Failure behavior

Assignment fails clearly for local deterministic-input defects such as:

- invalid ContentId/family/schema revision;
- missing/empty reserved-site `category_ids` declaration;
- invalid reserved-site hook vocabulary;
- non-positive selection weight;
- invalid profile bounds;
- duplicate semantic content IDs in one assignment request;
- invalid/duplicate hook StableIds or missing hook bounds;
- no eligible definition for a hook.

Malformed category SchemaIds fail through inherited `ContentDefinition`/`SchemaId` validation. Unknown-but-well-formed category IDs fail through CONTENT-005/CategorySchemaRegistry authoring validation, not through a CONTENT-001 parser. The assignment algorithm deliberately does not import those registries.

The service must not silently choose an unrelated fallback merely to make generation succeed.

## World-generation and persistence boundaries

CONTENT-001 does not modify:

- macro regions, topology, entrances, or special-location identity;
- reserved-site StableAddress/StableId or AABB;
- geometry descriptors/cells or MAP-016 mesh realization;
- streaming/collision ownership;
- runtime spawning/lifetime;
- durable save schema.

Base deterministic site truth and compatible deterministic assignment may regenerate. Durable player/world effects remain separate overlays keyed by appropriate semantic/procedural identities.

## Extension points

Bosses, events, structures, creatures, and resources scale through authored definitions and family-specific realization boundaries. A later placement/factory layer may consume a `ReservedSiteAssignment` and resolve its `content_id`; the assignment service itself must not become a giant switch over final content IDs or a second ContentRegistry.

CONTENT-002 owns underworld encounter/resource placement. ENEMY-001 owns creature/enemy authored rules. RESOURCE-001 owns resource/deposit definitions. MAP-016 remains separate protected geometry work.

## Validation contract

Focused executable validation must prove:

- ReservedSiteContentDefinition is a normal ContentDefinition subtype;
- every reserved-site definition declares at least one inherited `category_id`;
- ContentRegistry manifest data uses inherited `category_ids` and exposes no duplicate `categories` authored truth;
- registered categories pass CONTENT-005 validation;
- malformed/duplicate category SchemaIds fail through inherited generic validation;
- unknown registered-category references fail through CONTENT-005 rather than a local CONTENT-001 parser;
- assignment remains registry-independent after authoring validation;
- assignment `category_ids` snapshots come from inherited `category_ids` and expose no ambiguous `categories` key;
- caller category order cannot alter canonical descriptors, assignment output, or fingerprints;
- changing category declarations changes the assignment compatibility fingerprint without changing StableId/bounds;
- `eligible_hook_categories` remains independent from CategorySchema identity;
- StableId/AABB, weighting, profile eligibility, rulebook revision, and input-order invariants remain green.

Tests run through the additive accepted `tests/run_content.gd` aggregate and must preserve every already accepted sibling content suite.

## Forbidden patterns

Do not:

- add a family-owned authored `categories` array beside `ContentDefinition.category_ids`;
- duplicate ContentId/SchemaId/category/capability parsing or registries;
- require a global ContentRegistry/CategorySchemaRegistry inside deterministic assignment selection;
- hard-code final boss/resource/structure/creature IDs into world generation;
- derive procedural site identity from assigned content;
- rewrite hook bounds to fit authored content silently;
- use file paths, PackedScene identity, or Node instance IDs as semantic content identity;
- make assignment own spawned Nodes, streaming cells, collision bodies, or MAP-016 geometry;
- depend on caller array order or mutable global RNG;
- absorb CONTENT-002 placement or unrelated family implementation.

## Minimal example

```text
content_id: structure.underworld.crystal_shrine
definition_family: structure
schema_revision: 1
category_ids:
  - category.structure
  - category.structure.underworld
  - category.structure.underworld.shrine
eligible_hook_categories:
  - reserved_site
selection_weight: 1
profile:
  min: (0, 0, 0)
  max: (1, 1, 1)
```

When assigned, the result retains the original site's `sid1:...` and AABB and adds the semantic content reference plus a canonical `category_ids` snapshot as overlay data.
