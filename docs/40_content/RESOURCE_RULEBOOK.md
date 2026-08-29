# Underground Resource / Deposit Rulebook

Status: **RESOURCE-001 executable authored-content contract**

This rulebook specializes the project-wide [Content Rulebook Contract](CONTENT_RULEBOOK.md) for underground resources. It defines authored resource truth only. Deterministic placement, runtime spawning, cave geometry, excavation simulation and presentation realization are separate consumers.

## Purpose

A resource definition describes **what can be harvested or excavated and what authored items it yields**. It does not describe where a generated occurrence lives, which mesh represents it, or how much of one placed occurrence remains after player interaction.

The contract preserves two important forms without forcing them into one oversized schema:

- small harvest nodes, modeled through a resource-family extension with node-specific data;
- larger excavatable deposits, modeled through a separate resource-family extension/profile with deposit-specific data.

Both inherit the narrow common resource definition contract.

## Stable semantic identity

Every authored underground resource uses the `resource.*` ContentId family. Examples:

```text
resource.node.copper
resource.node.crystal_cluster
resource.deposit.iron_seam
resource.deposit.salt_bed
```

The ContentId is authored semantic identity. It remains authoritative across file moves and presentation replacement.

The following are explicitly different identities and must not be collapsed into the ContentId:

- a future deterministic generated placement StableId;
- a runtime Node/object identity;
- a Resource or scene path;
- a mesh/material identity;
- a persisted mutable depletion record key.

Generated placement identity belongs to CONTENT-002/#77 and later persistence integration, not RESOURCE-001.

## Category contract

Every validated resource declares at least one registered category in the `category.resource` ancestry.

The baseline form categories demonstrated by this contract are:

```text
category.resource
├─ category.resource.node
└─ category.resource.deposit
```

A small node and a large deposit are deliberately not represented by unrelated base systems. They share `ResourceDefinition` and specialize through family extensions/composition.

Category ancestry is registry-owned. Dotted naming is semantic identity syntax, not executable inheritance logic.

## Capability contract

Capabilities are controlled `capability.*` schema declarations. The baseline form contract demonstrates:

```text
category.resource.node    -> capability.harvestable
category.resource.deposit -> capability.excavatable
```

The focused RESOURCE-001 form extension rejects incompatible combinations. Future mechanics may add capabilities through additional compositional rules; they must not add concrete resource IDs to a central switch.

## Common authored definition data

`ResourceDefinition` owns only data common to authored resource families:

```text
ContentDefinition fields
capacity_units
typed yield rules
semantic references
```

`capacity_units` is an authored/tunable capacity scale and must be greater than zero. RESOURCE-001 defines the contract, not final economy numbers.

Node-specific harvest chunk data and deposit-specific excavation-step/profile data do not live in the common base. The focused fixtures prove those fields can be owned independently by child definitions/extensions.

## Typed yield contract

Every resource definition declares at least one `ResourceYieldRule`.

A yield rule contains:

```text
source resource ContentId
semantic yield.* role
target item.* ContentId
expected family = item
quantity_per_capacity_unit > 0
```

The target is a CONTENT-005 `ContentReference`, not a file path. Validation resolves it through the accepted content registry and requires the resolved target to be an accepted concrete `ItemDefinition`, not merely any generic `ContentDefinition` carrying the string family `item`.

`quantity_per_capacity_unit` makes the relationship authorable without freezing final balance. Actual harvest/excavation systems may interpret validated capacity and yield ratios later; they do not change semantic resource identity.

## Small-node composition

A small harvest node composes the base resource contract with node-specific data/rules. The executable fixture demonstrates a `harvest_chunk_units` field owned by the node extension and a `category.resource.node` + `capability.harvestable` invariant.

This is an architecture proof, not final interaction tuning. Later harvesting gameplay may replace or extend the exact profile data without modifying the common resource identity/reference boundary.

## Large-deposit composition

A larger excavatable deposit composes the same base contract with deposit-specific data/rules. The executable fixture demonstrates an `excavation_step_units` field owned by the deposit extension and a `category.resource.deposit` + `capability.excavatable` invariant.

Deposit excavation is not cave meshing. RESOURCE-001 does not alter MAP-016 geometry, SDFs, Marching Cubes, collision ownership or topology descriptors.

## Mutable depletion ownership

Authored `ResourceDefinition` Resources are shared immutable definition data from the perspective of gameplay state. They are never mutated to record how much remains in one placed occurrence.

`ResourceDepletionState` stores mutable occurrence-side data:

```text
resource ContentId
remaining_capacity_units
mutable depletion delta payload
```

The state contract deliberately does **not** invent a generated placement ID. A later placement/persistence system will own the key that associates a depletion delta with one deterministic occurrence.

This keeps authored definition identity, generated placement identity and mutable world delta as three separate concepts.

## Presentation boundary

Presentation is replaceable and referenced semantically, for example through an `archetype.*` reference role such as `presentation.archetype`.

Do not use scene paths, mesh paths, materials or runtime Nodes as resource identity. ARCHETYPE-001 owns realization of semantic presentation definitions. Changing a presentation target must not change the resource ContentId.

## World-generation relationship

Cave topology, geometry and meshing may expose deterministic candidate locations in later work, but they must not know concrete resource definitions.

RESOURCE-001 does not:

- choose deterministic placements;
- assign resources to caves/sites;
- spawn runtime resource objects;
- modify cave descriptors;
- modify Marching-Cubes extraction;
- create StableIds for placed resources.

Those responsibilities remain downstream, primarily CONTENT-002/#77 and later runtime/persistence work.

## Runtime ownership

Future harvesting/mining systems consume validated resource definitions and occurrence depletion state. Presentation systems consume semantic presentation bindings. Placement systems consume resource definitions by semantic reference.

Runtime systems may assume the authored definition passed CONTENT-005 plus `ResourceFamilyValidator` before use.

## Persistence and migration

Persist authored semantic `resource.*` ContentIds where definition identity is required, and persist mutable depletion as world/player delta keyed by the later placement identity contract.

Do not persist Resource paths or presentation paths as resource identity. Renaming a persisted resource ContentId is a migration. File moves and presentation replacements are not identity migrations.

## Validation

A resource definition is structurally valid only when:

- its ContentId is a valid `resource.*` ID and its definition family is `resource`;
- semantic family selection routes through `ResourceFamilyValidator` even if the concrete Resource type is wrong;
- the concrete definition inherits `ResourceDefinition`;
- common authored capacity is valid;
- at least one typed `yield.*` rule exists;
- yield quantities are positive authored values;
- yield references expect `item` and resolve to concrete accepted `ItemDefinition` targets;
- declared categories/capabilities exist in accepted schema registries;
- declared categories remain under `category.resource`;
- applicable node/deposit child rules pass;
- authored definition fields remain separate from mutable depletion state;
- semantic references resolve through CONTENT-005.

The focused headless contracts cover valid nodes/deposits, wrong concrete resource type, missing yield, missing yield target, wrong concrete item target, incompatible yield family, incompatible category/capability declarations, path independence and depletion separation.

## Forbidden patterns

Do not:

- use resource file, scene, mesh or material paths as semantic identity;
- mutate shared ResourceDefinition data to represent per-occurrence depletion;
- invent placement identity in the authored rulebook;
- place or spawn resources from this card;
- bake concrete resource families into cave geometry/topology/meshing;
- put all node/deposit/future resource fields into one oversized base definition;
- accept a generic ContentDefinition under semantic family `resource` without resource-family validation;
- treat a generic `item`-family ContentDefinition as a valid harvested item target;
- create a parallel content/category/capability/reference registry;
- hard-code final economy values into infrastructure.

## Minimal valid conceptual example

```text
content_id: resource.node.copper
definition_family: resource
categories:
  - category.resource.node
capabilities:
  - capability.harvestable
capacity_units: <authored positive value>
yields:
  - role: yield.primary
    target: item.resource.copper_chunk
    expected_family: item
    quantity_per_capacity_unit: <authored positive value>
```

A deposit uses the same base authored identity/capacity/yield contract while composing its own deposit/excavation profile and `category.resource.deposit` rules.
