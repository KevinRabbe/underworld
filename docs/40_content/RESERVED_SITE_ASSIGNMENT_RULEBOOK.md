# Reserved-Site Content Assignment Rulebook

Status: **CONTENT-001 baseline contract**

This rulebook defines the authored-content boundary that maps deterministic generic underworld `reserved_site` hooks to semantic content definitions. It extends the accepted CONTENT-003 semantic-content foundation; it does not redefine procedural world generation or category/capability registry ownership.

## 1. Purpose

World generation reserves spatial opportunities. Authored content decides what those opportunities mean to gameplay.

```text
Deterministic reserved-site hook
  StableId + bounds + anchor/profile
                ↓
ReservedSiteAssignmentService
                ↓
ReservedSiteContentDefinition
  ContentDefinition + site eligibility/weight
                ↓
ReservedSiteAssignment overlay
```

A reserved-site assignment is not cave truth, not a new geometry descriptor, and not a runtime Node.

## 2. Parent content contract

`ReservedSiteContentDefinition` is a subtype of the accepted `ContentDefinition` Resource in `core/content/registry/content_definition.gd`.

The generic fields are therefore owned by CONTENT-003:

- `content_id`;
- `definition_family`;
- `schema_revision`;
- generic semantic-ID/family validation;
- generic canonical descriptor data;
- `ContentRegistry` compatibility and lookup.

`ContentId` in `core/content/identity/content_id.gd` is the authority for semantic content-ID syntax and family extraction. CONTENT-001 must not maintain a second semantic-ID parser or a parallel base-definition model.

The reserved-site subtype adds only site-specific authored data:

- categories used to classify the site content;
- eligible generic hook categories;
- deterministic selection weight;
- profile eligibility window;
- family-specific metadata.

`ContentRegistry` may index and resolve these subtype Resources through the normal CONTENT-003 boundary. CONTENT-001 does not duplicate registry indexing, path loading, typed-reference resolution, or duplicate-ID policy.

## 3. Stable identity

The deterministic hook keeps its existing procedural identity:

```text
site_stable_id = sid1:...
```

The authored target keeps a semantic content ID from an existing content namespace, for example:

```text
structure.underworld.crystal_shrine
structure.underworld.watch_post
spawn_profile.underworld.guardian_event
```

These identities answer different questions:

- procedural StableId: **which generated site is this?**
- semantic content ID: **what authored concept is assigned here?**

Assignment must never replace, rewrite, derive or alias the hook StableId. A content ID must never be used as procedural site identity.

`rsa1:<sha256>` is an assignment compatibility/debug fingerprint only. It is neither semantic content identity nor procedural world identity.

New top-level content namespaces remain subject to the architecture review required by `CONTENT_IDS.md`.

## 4. Category contract

Reserved-site definitions declare one or more `category.*` references.

Example:

```text
category.structure
category.structure.underworld
category.structure.underworld.shrine
```

Categories classify the authored definition. They do not execute boss, encounter, structure or resource behavior.

CONTENT-001 only requires structurally explicit `category.*` references and deterministic ordering. Authoritative existence, ancestry, compatibility and capability-schema validation belong to CONTENT-004/#83 and must not be reimplemented here.

The initial hook eligibility vocabulary is the deterministic hook's existing semantic category:

```text
reserved_site
```

Future hook categories may be added only when the deterministic world contract genuinely exposes a new generic site family. Ordinary authored variation must remain definitions/categories/rules rather than new worldgen branches.

## 5. Required definition data

Inherited from `ContentDefinition`:

- `content_id` — canonical semantic content ID validated by `ContentId`;
- `definition_family` — canonical top-level family derived from the content ID for constructed reserved-site definitions;
- `schema_revision` — positive compatibility-sensitive definition schema revision.

Reserved-site-specific fields:

- `categories` — one or more `category.*` references;
- `eligible_hook_categories` — generic site categories the definition may occupy;
- `selection_weight` — positive deterministic relative weight;
- `minimum_profile` / `maximum_profile` — normalized hook-profile eligibility window;
- `metadata` — family-specific authored data outside procedural identity.

Definitions do not contain procedural StableIds, geometry-cell addresses, runtime Nodes or save-specific state.

## 6. Selection and rulebook revision

Assignment is deterministic for a fixed input contract.

The service:

1. validates reserved-site definitions through `validate_definition()`, which includes the inherited CONTENT-003 validation;
2. canonicalizes definitions by `content_id`;
3. canonicalizes hooks by procedural StableId;
4. filters definitions by explicit hook category and profile eligibility;
5. selects from eligible definitions using the site StableId, rulebook revision and canonical eligible-definition manifest;
6. emits assignments in StableId order.

Caller/runtime array order is not semantic input.

`rulebook_revision` owns changes to assignment policy. The inherited `schema_revision` owns compatibility-sensitive changes to an authored definition's schema/meaning. Both participate in assignment compatibility fingerprinting.

Weights and eligibility must never use frame order, loaded-node order, wall-clock time or mutable global RNG state.

## 7. Unsupported and ineligible combinations

Assignment fails clearly when:

- the inherited `ContentDefinition`/`ContentId` contract is invalid;
- reserved-site-specific definition data is invalid;
- two definitions claim the same semantic content ID;
- a hook lacks a procedural StableId or bounds;
- the same hook StableId appears twice in one assignment request;
- no authored definition is eligible for a hook;
- a hook profile lies outside every candidate definition's declared eligibility.

The service must not silently pick an unrelated fallback merely to make generation succeed.

## 8. World-generation relationship

The dependency direction is one-way:

```text
worldgen generic hook  →  content assignment
```

Never:

```text
content assignment  →  worldgen topology/geometry decisions
worldgen  →  authored ContentRegistry
```

CONTENT-001 does not modify:

- macro regions;
- cave topology or entrances;
- special-location StableAddresses/StableIds;
- reserved bounds;
- geometry descriptors or geometry-cell identity;
- voxel/mesh realization;
- streaming ownership;
- collision ownership.

The accepted M2 deterministic/runtime architecture remains authoritative.

## 9. Runtime ownership

The assignment layer returns pure overlay data. It owns no scene-tree lifetime.

A later gameplay/factory boundary may resolve `content_id` through the accepted `ContentRegistry` and create the relevant runtime representation. Presentation assets remain replaceable references and cannot define site/content identity.

The assignment service does not become a second ContentRegistry. It receives already available reserved-site definition objects and applies only reserved-site eligibility/selection policy.

## 10. Persistence and world deltas

Base deterministic site truth regenerates from world generation. Deterministic assignment may likewise regenerate from the same compatible assignment policy.

Durable player/world effects are overlays, keyed using stable semantic/procedural identities as appropriate. Examples include:

- a site permanently cleared;
- a generated structure destroyed or altered;
- an encounter completion state;
- a persistent authored variant chosen by an explicit save contract.

Do not serialize regenerated cave topology, reserved-site bounds, geometry cells or mesh resources merely because content is assigned there.

If a shipped save depends on a particular assignment result, revision/migration policy must preserve or explicitly migrate that result. Changing content IDs remains a semantic-ID migration; changing incompatible definition schema requires the normal content schema revision/migration discipline.

## 11. Assignment overlay data

A `ReservedSiteAssignment` records:

- original `site_stable_id`;
- original site AABB;
- assigned semantic `content_id`;
- classification references;
- assignment `rulebook_revision`;
- selected definition's inherited `content_schema_revision` snapshot;
- assignment fingerprint;
- copied definition metadata.

The overlay does not claim ownership of the source hook or of the registered content definition.

## 12. Extension points

Bosses, events, structures and resources scale through authored definitions and child rulebooks.

Examples:

```text
structure.underworld.*
spawn_profile.underworld.*
creature.underworld.*
item.resource.*
```

A future placement/realization system may consume an assignment and dispatch to family-specific factories. The assignment service itself must not become a giant switch over final content IDs.

Profile eligibility may later grow into typed reusable rule objects when the content family needs more expressive constraints. That extension should remain authored/testable and preserve canonical selection semantics.

Category/capability vocabulary registration remains CONTENT-004/#83. General definition-schema/content-shape work remains CONTENT-005/#84. CONTENT-001 must not absorb either scope.

## 13. Validation

Executable validation must prove at minimum:

- the reserved-site definition is a valid `ContentDefinition` subtype;
- `ContentRegistry` can index/resolve that subtype through the accepted generic boundary;
- `ContentId` owns semantic-ID/family validation;
- inherited `schema_revision` is preserved into assignment compatibility data;
- assigning authored content does not mutate hook StableId or bounds;
- semantic content ID and procedural site identity remain separate;
- category/subcategory metadata survives the assignment boundary;
- reversed hook/definition array order produces identical assignments;
- unsupported/ineligible combinations fail with actionable diagnostics;
- rulebook revision participates in compatibility-sensitive assignment fingerprinting;
- no worldgen/runtime ownership contract is imported into the authored definition model.

The tests run through `tests/run_content.gd`, the accepted content-contract runner introduced with CONTENT-003.

## 14. Forbidden patterns

Do not:

- duplicate `ContentId` parsing/validation;
- create a second generic content-definition base class;
- duplicate `ContentRegistry` indexing/resolution;
- implement CONTENT-004 category/capability registries inside this family;
- hard-code boss/resource/structure IDs into world generation;
- derive a site's StableId from assigned content;
- rewrite hook bounds to fit authored content silently;
- use file paths, PackedScene identity or Node instance IDs as semantic content identity;
- make the assignment service own spawned Nodes, streaming cells or collision bodies;
- persist regenerated cave truth as assignment state;
- depend on input array order or shared mutable RNG;
- add one central special-case branch per authored content ID.

## 15. Minimal valid example

```text
content_id: structure.underworld.crystal_shrine
definition_family: structure       # inherited / derived from ContentId
schema_revision: 1                 # inherited ContentDefinition contract
categories:
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

When assigned, the result retains the original site's `sid1:...` and AABB and adds the semantic `structure.underworld.crystal_shrine` reference as overlay data.
