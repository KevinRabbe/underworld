# Reserved-Site Content Assignment Rulebook

Status: **CONTENT-001 baseline contract**

This rulebook defines the authored-content boundary that maps deterministic generic underworld `reserved_site` hooks to semantic content definitions. It extends the project-wide content architecture and content-rulebook rules; it does not redefine procedural world generation.

## 1. Purpose

World generation reserves spatial opportunities. Authored content decides what those opportunities mean to gameplay.

The boundary is deliberately two-part:

```text
Deterministic reserved-site hook
  StableId + bounds + anchor/profile
                ↓
ReservedSiteAssignmentService
                ↓
Authored semantic content definition
  content_id + categories + eligibility
                ↓
ReservedSiteAssignment overlay
```

A reserved-site assignment is not cave truth, not a new geometry descriptor, and not a runtime Node.

## 2. Stable identity

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

Assignment must never replace, rewrite, derive or alias the hook StableId. A content ID must never be used as the procedural site identity.

`rsa1:<sha256>` is an assignment compatibility/debug fingerprint only. It is neither semantic content identity nor procedural world identity.

New top-level content namespaces remain subject to the architecture review required by `CONTENT_IDS.md`; this rulebook does not create one.

## 3. Category contract

Reserved-site definitions declare one or more full controlled `category.*` schema IDs.

Example:

```text
category.structure
category.structure.underworld
category.structure.underworld.shrine
```

Categories classify the authored definition. They do not execute boss, encounter, structure or resource behavior.

The initial hook eligibility vocabulary is the deterministic hook's existing semantic category:

```text
reserved_site
```

Future hook categories may be added only when the deterministic world contract genuinely exposes a new generic site family. Ordinary authored variation must remain definitions/categories/rules rather than new worldgen branches.

## 4. Required definition data

`ReservedSiteContentDefinition` requires:

- `content_id` — lowercase dot-separated semantic content ID;
- `categories` — one or more full `category.*` schema IDs;
- `eligible_hook_categories` — generic site categories the definition may occupy;
- `selection_weight` — positive deterministic relative weight;
- `definition_revision` — positive compatibility-sensitive authored revision;
- `minimum_profile` / `maximum_profile` — optional normalized hook-profile eligibility window;
- `metadata` — family-specific authored data that remains outside procedural identity.

Definitions do not contain procedural StableIds, geometry-cell addresses, runtime Nodes or save-specific state.

## 5. Selection and rulebook revision

Assignment is deterministic for a fixed input contract.

The service:

1. validates all definitions and hooks;
2. canonicalizes definitions by `content_id`;
3. canonicalizes hooks by procedural StableId;
4. filters definitions by explicit hook category and profile eligibility;
5. selects from the eligible definitions using the site StableId, rulebook revision and canonical eligible-definition manifest;
6. emits assignments in StableId order.

Therefore caller/runtime array order is not semantic input.

`rulebook_revision` owns changes to assignment policy. Compatibility-sensitive changes to selection semantics require a revision bump. Changes to one authored definition that alter compatibility-sensitive meaning require its `definition_revision` to change.

Weights and eligibility must never use frame order, loaded-node order, wall-clock time or mutable global RNG state.

## 6. Unsupported and ineligible combinations

Assignment fails clearly when:

- a content definition is structurally invalid;
- two definitions claim the same semantic content ID;
- a hook lacks a valid procedural StableId or bounds;
- the same hook StableId appears twice in one assignment request;
- no authored definition is eligible for a hook;
- a hook profile lies outside every candidate definition's declared eligibility.

The service must not silently pick an unrelated fallback merely to make generation succeed.

## 7. World-generation relationship

The dependency direction is one-way:

```text
worldgen generic hook  →  content assignment
```

Never:

```text
content assignment  →  worldgen topology/geometry decisions
worldgen  →  authored content manager/registry
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

## 8. Runtime ownership

The assignment layer returns pure overlay data. It owns no scene-tree lifetime.

A later gameplay/factory boundary may resolve `content_id` into validated authored definitions and create the relevant runtime representation. Presentation assets remain replaceable references and cannot define site/content identity.

CONTENT-001 intentionally does not implement the global `ContentRegistry`; that is owned by CONTENT-003/#82.

## 9. Persistence and world deltas

Base deterministic site truth regenerates from world generation. Deterministic assignment may likewise regenerate from the same compatible assignment policy.

Durable player/world effects are overlays, keyed using stable semantic/procedural identities as appropriate. Examples include:

- a site permanently cleared;
- a generated structure destroyed or altered;
- an encounter completion state;
- a persistent authored variant chosen by an explicit save contract.

Do not serialize regenerated cave topology, reserved-site bounds, geometry cells or mesh resources merely because content is assigned there.

If a shipped save depends on a particular assignment result, revision/migration policy must preserve or explicitly migrate that result. Changing content IDs remains a semantic-ID migration.

## 10. Extension points

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

## 11. Validation

Executable validation must prove at minimum:

- assigning authored content does not mutate hook StableId or bounds;
- semantic content ID and procedural site identity remain separate;
- category/subcategory metadata survives the assignment boundary;
- reversed hook/definition array order produces identical assignments;
- unsupported/ineligible combinations fail with actionable diagnostics;
- rulebook revision participates in compatibility-sensitive assignment fingerprinting;
- no worldgen/runtime ownership contract is imported into the authored definition model.

## 12. Forbidden patterns

Do not:

- hard-code boss/resource/structure IDs into world generation;
- derive a site's StableId from assigned content;
- rewrite hook bounds to fit authored content silently;
- use file paths, PackedScene identity or Node instance IDs as semantic content identity;
- make the assignment service own spawned Nodes, streaming cells or collision bodies;
- persist regenerated cave truth as assignment state;
- depend on input array order or shared mutable RNG;
- add one central special-case branch per authored content ID.

## 13. Minimal valid example

```text
content_id: structure.underworld.crystal_shrine
categories:
  - category.structure
  - category.structure.underworld
  - category.structure.underworld.shrine
eligible_hook_categories:
  - reserved_site
selection_weight: 1
definition_revision: 1
profile:
  min: (0, 0, 0)
  max: (1, 1, 1)
```

When assigned, the result retains the original site's `sid1:...` and AABB and adds the semantic `structure.underworld.crystal_shrine` reference as overlay data.
