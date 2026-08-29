# Underground Resource and Deposit Rulebook

Status: **RESOURCE-001 executable authored-content contract**

This rulebook specializes the project-wide [Content Rulebook Contract](CONTENT_RULEBOOK.md) and composes with the accepted [Item Rulebook](ITEM_RULEBOOK.md). It defines what an underground harvest node or excavatable deposit **is**. Deterministic placement, runtime spawning, cave geometry, depletion persistence keys and economy balance are separate concerns.

## Semantic families

RESOURCE-001 owns two authored ContentId families:

```text
resource_node.*
resource_deposit.*
```

Both inherit the common `ResourceDefinition` contract. They remain different semantic families because a small interaction node and a volumetric deposit participate in different gameplay rules.

Examples:

```text
resource_node.iron.small
resource_node.crystal.surface_cluster
resource_deposit.iron.large
resource_deposit.stone.massive
```

A resource ContentId is authored semantic identity. File paths, scenes, meshes, runtime Nodes, world coordinates and procedural StableIds are not resource-definition identity.

## Common definition contract

`ResourceDefinition` owns only data shared by both forms:

```text
ContentDefinition fields
capacity_units
item yield entries
optional semantic presentation reference
```

`capacity_units` is an authored capacity basis, not mutable depletion state. Exact values are balance data.

Every resource must declare at least one `ResourceYieldEntry`. Each yield entry references an `item.*` ContentId through CONTENT-005 with expected family `item`; the resource family validator additionally requires the resolved target to be an actual accepted `ItemDefinition` rather than a generic definition spoofing the family string.

Yield entries express a ratio per capacity unit plus event quantity bounds. They describe the structural conversion contract without fixing final progression or economy values.

## Small harvest nodes

`ResourceNodeDefinition` uses family `resource_node` and owns interaction-specific fields:

```text
harvest_capacity_cost
interaction_radius
```

Validated nodes declare a category under:

```text
category.world_resource.node
```

and require:

```text
capability.harvestable
capability.depletable
```

These fields do not belong in the common definition or in large deposits.

## Large deposits

`ResourceDepositDefinition` uses family `resource_deposit` and owns volumetric/excavation fields:

```text
capacity_units_per_cubic_meter
minimum_excavation_volume
```

Validated deposits declare a category under:

```text
category.world_resource.deposit
```

and require:

```text
capability.excavatable
capability.depletable
```

These values define authored extraction semantics only. RESOURCE-001 does not place deposit volumes, alter terrain, create marching-cubes geometry or decide which world cell owns a deposit.

## Mutable depletion state

`ResourceDepletionState` is separate from shared authored definitions. It stores:

```text
resource ContentId
remaining capacity units
family-owned mutable delta data
```

Harvesting/depletion mutates this state, never the shared `ResourceDefinition` Resource.

RESOURCE-001 deliberately does **not** give depletion state a world position, StableId or placement ID. CONTENT-002/#77 owns generated placement identity. A later persistence/runtime layer may associate a placement identity with depletion delta without changing authored resource identity.

## Presentation boundary

A resource may reference replaceable presentation content semantically, normally through an `archetype.*` target. Resource identity does not change when a scene, mesh, material, animation or archetype realization changes.

If runtime realization is needed, presentation must use the accepted validated content/archetype boundary. Cave generators and meshing code must not import concrete resource presentation assets.

## Validation and fail-closed families

`ResourceNodeFamilyValidator` and `ResourceDepositFamilyValidator` select definitions by semantic family first, then require the correct concrete definition subtype. Therefore a generic `ContentDefinition` cannot bypass resource rules by setting `definition_family = "resource_node"` or `"resource_deposit"`.

Validation requires:

- a valid `resource_node.*` or `resource_deposit.*` ContentId matching its definition family;
- positive common capacity;
- at least one structurally valid typed item yield;
- yield targets resolving to actual `ItemDefinition` resources;
- registered resource categories under `category.world_resource` and the correct node/deposit child category;
- required harvest/excavation and depletion capabilities;
- positive child-specific node/deposit fields;
- required semantic references resolving through CONTENT-005.

## Placement and worldgen ownership

RESOURCE-001 is intentionally placement-agnostic. Later CONTENT-002 work may choose where a resource definition appears and create generated placement identity. Worldgen may expose placement hooks or deterministic addresses, but resource authored definitions do not mutate topology, cave descriptors, marching-cubes extraction or geometry-cell identity.

A generated placement should conceptually combine:

```text
resource ContentId       -> what this resource is
placement StableId       -> which generated occurrence this is
mutable depletion delta  -> what has changed at that occurrence
presentation realization -> how it is currently shown
```

Those identities remain distinct.

## Forbidden patterns

Do not:

- bake resource definitions into cave geometry descriptors;
- use mesh/scene/resource paths as resource identity;
- mutate shared definitions to store depletion;
- put node-only and deposit-only behavior into one oversized base schema;
- accept a generic ContentDefinition merely because its family string says resource or item;
- implement placement, runtime spawning or excavation geometry in this rulebook;
- let resource presentation become deterministic worldgen truth;
- collapse authored ContentId, generated placement StableId and mutable depletion state into one identity.
