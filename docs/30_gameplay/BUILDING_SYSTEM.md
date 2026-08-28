# Building System Architecture

Status: **LOCKED design direction; implementation deferred**

This document records the agreed gameplay architecture for player construction. It defines ownership and extension boundaries, not final balance values, art assets, dimensions, recipes, or implementation classes.

Authoritative cross-system contracts remain in the linked architecture, persistence, content, and world-generation documents. If this document conflicts with a lower-level authoritative contract, the owning contract wins and the conflict must be resolved explicitly.

## Core model

Underworld uses **modular piece construction** built from authored definitions and persistent placed instances.

```text
BuildPieceDefinition
        |
        v
placement request -> validation -> authoritative commit
                                |
                                v
                         BuildInstance state
                                |
                 +--------------+--------------+
                 |                             |
                 v                             v
          runtime realization            durable persistence
                 |
                 v
             presentation
```

The building system does not become procedural world generation. A world seed defines deterministic base truth; player construction is a durable world delta layered on top of that truth.

## 1. Definition identity vs placed identity

A build-piece definition describes a reusable authored concept such as a wall, floor, beam, stair, roof piece, door frame, workstation, or storage object.

A definition may own or reference rules such as:
- semantic definition ID and schema/version information;
- category/capability tags;
- canonical placement footprint/geometry contract;
- snap-socket definitions;
- structural profile;
- durability/repair profile;
- construction requirements;
- upgrade-family compatibility;
- presentation binding.

A placed building object is separate mutable state. A persistent `BuildInstance`-equivalent record should contain only the data required to reconstruct the logical placed object, for example:
- persistent instance identity;
- semantic piece-definition ID;
- world transform;
- logical socket/connections where persistence requires them;
- mutable health/durability;
- owner/faction or permissions where applicable;
- selected variant/customization state;
- other explicitly durable gameplay state.

Meshes, materials, runtime Nodes, LOD state, active streaming cells, draw batches, and temporary preview state are not persistent building identity.

See also:
- [`../10_architecture/CONTENT_ARCHITECTURE.md`](../10_architecture/CONTENT_ARCHITECTURE.md)
- [`../10_architecture/CONTENT_REGISTRY.md`](../10_architecture/CONTENT_REGISTRY.md)
- [`../PERSISTENCE_AND_VERSIONING.md`](../PERSISTENCE_AND_VERSIONING.md)
- [`../00_project/GLOSSARY.md`](../00_project/GLOSSARY.md)

## 2. Modular pieces, not voxel-authoritative construction

The construction model is based on modular pieces rather than treating a voxel field as the authoritative building representation.

Prototype and future piece families may include:
- foundations/posts;
- floors;
- walls and door/window frames;
- beams and structural supports;
- stairs/ladders;
- roofs;
- doors/gates;
- crafting stations;
- storage;
- defenses;
- lights and utility objects;
- furniture and decoration.

Nothing in this contract requires final piece dimensions or final art. Prototype boxes are valid as long as they satisfy the same logical placement contract.

A later alternate renderer may make those pieces appear substantially different without changing their logical definitions or placed identities.

## 3. Socket-based snapping with optional free placement

Structural pieces expose explicit authored snap sockets rather than deriving all connections from arbitrary render meshes.

A socket should describe only placement-relevant semantics, such as:
- stable socket role/name within the piece definition;
- local transform;
- compatible socket categories/capabilities;
- orientation constraints;
- optional structural/support role.

Examples include wall-side, floor-edge, roof-edge, beam-end, support-bottom, or equivalent semantic roles.

The placement system may rank nearby compatible sockets using distance, orientation, view/aim context, and explicit compatibility. The final ranking algorithm is not locked here.

Not every object must use structural snapping. Furniture, torches, chests, workstations, decorations, and similar pieces may support surface-aligned or free placement. Fine-placement or snap-disable controls remain a usability extension.

**Rule:** presentation mesh vertices are not the source of truth for logical snap compatibility.

## 4. Placement is request -> validation -> commit

Placement must be transactional even in single-player architecture.

Conceptually:

```text
BuildPlacementRequest
        |
        v
candidate transform / socket pair
        |
        v
BuildPlacementValidator
        |
        +-- placement geometry / overlap
        +-- allowed surface / slope / support
        +-- world restrictions / protected clearances
        +-- ownership / permission rules
        +-- resource availability
        |
        v
Authoritative commit
        |
        +-- consume resources atomically
        +-- create persistent BuildInstance
        +-- update structural/connectivity state
        +-- realize runtime representation
```

Failure must not partially consume resources or create half-committed building state.

The eventual inventory/crafting system should provide the resource transaction; the building system should not invent a second resource representation.

## 5. Building is a durable world delta

Player construction is not written back into deterministic generator definitions.

Conceptually:

```text
world seed + generator manifest -> deterministic base world
                                      |
                                      v
                              durable player/world deltas
                                      |
                                      v
                                 realized world
```

Building persistence therefore records authored piece identity plus mutable instance state. On reload, the deterministic base world may be regenerated and durable construction state reapplied through the persistence layer.

This distinction is required so:
- changing runtime streaming does not delete buildings;
- changing presentation assets does not change buildings;
- unloading a chunk/cell does not lose buildings;
- deterministic generation remains reproducible independently of player edits.

See [`../PERSISTENCE_AND_VERSIONING.md`](../PERSISTENCE_AND_VERSIONING.md) and [`../GENERATION_PIPELINE_INTERFACES.md`](../GENERATION_PIPELINE_INTERFACES.md).

## 6. One surface and Underworld building architecture

There should not be separate incompatible `surface building` and `cave building` systems.

Placement validity is expressed through surface/restriction semantics. A candidate surface may expose tags/capabilities such as terrain, rock, structure, wall, ceiling, or other explicit roles. A piece definition declares what it can anchor to.

Examples:
- a foundation may accept terrain/rock/support surfaces;
- a wall torch may accept vertical structural/rock surfaces;
- a hanging light may accept ceiling/support surfaces;
- furniture may require a sufficiently horizontal supported surface.

The exact tag vocabulary belongs to the future building/content rulebook, not this architecture document.

The building system may query world-owned restrictions such as reserved clearances, protected authored areas, entrance clearances, illegal overlap zones, or other no-build rules. It must not redefine those world contracts itself.

In particular, cave/entrance generation remains authoritative for whether deterministic geometry exists; construction only asks whether placement is allowed at a candidate location.

## 7. Structural integrity is a gameplay graph

Underworld should use an understandable graph-based support model rather than full real-time engineering simulation.

Conceptually:

```text
terrain / rock / valid anchor
            |
            v
       foundation/root
            |
       supported links
       /      |      \
    wall     beam    floor
       \       |      /
            roof
```

Structural roots obtain support from valid anchor surfaces. Connections propagate support according to piece/material structural profiles. The model may represent states such as supported, stressed, unstable, and unsupported, but exact thresholds and failure timing remain balance decisions.

Different material families may later change spans, vertical support, durability, fire behavior, or load properties. Those values are authored/balance data, not hard-coded architectural identity.

Destroying or removing support may trigger graph re-evaluation. This enables future collapse/siege behavior without requiring a rigid-body simulation for every building piece.

## 8. Runtime realization is replaceable

Persistent/logical building state and runtime render representation are separate.

A distant settlement may contain hundreds or thousands of logical pieces without requiring the same number of permanently active Godot Nodes or draw calls.

Runtime presentation may later use:
- spatial streaming;
- instance pooling;
- MultiMesh/instancing where compatible;
- static mesh combining or render clusters;
- LODs/impostors;
- collision activation tiers;
- damage-specific local rebuilds.

Those optimizations must not merge or erase the logical identities needed for durability, ownership, upgrades, deconstruction, or persistence.

A render cluster containing twenty walls is still twenty logical building pieces if gameplay/persistence requires those twenty pieces independently.

## 9. Interactive pieces use composition

Doors, chests, crafting stations, lights, beds, traps, and similar objects remain build pieces for placement/persistence purposes, then compose with the gameplay component that owns their special behavior.

Examples:

```text
DoorPieceDefinition + door interaction/state
StoragePieceDefinition + container state
WorkbenchPieceDefinition + crafting-station capability
LightPieceDefinition + light/fuel behavior
```

The building system owns construction placement and structural participation. It should not duplicate storage, crafting, combat, or other gameplay subsystems inside building-specific special cases.

## 10. Upgrades preserve logical continuity

Compatible upgrades should be able to replace a piece definition while preserving the placed object's logical continuity where the upgrade family permits it.

For example, an eventual wood-to-reinforced or stone-to-reinforced upgrade may preserve:
- persistent instance identity;
- transform;
- compatible socket relationships;
- ownership/permissions;
- explicitly transferable mutable state.

The definition/rulebook decides whether two pieces are upgrade-compatible. The presentation mesh is not the compatibility key.

Exact material tiers and upgrade progression are intentionally not locked here.

## 11. Blueprints are a planned extension

The architecture should permit a future blueprint to describe a set of semantic piece definitions plus relative transforms/socket relationships without requiring blueprint support in the first implementation.

Potential consumers include:
- player-saved designs;
- developer-authored structures;
- settlement/NPC authoring;
- repeated construction layouts.

A blueprint is not a reason to collapse all pieces into one persistent object. It is a reusable placement description over ordinary building definitions/instances.

## 12. Terrain editing is separate

Building must not require terrain deformation to function.

Foundations, posts, beams, stairs, and other structural pieces should allow useful construction on uneven generated terrain without forcing an early flatten/raise/lower/dig system.

If terrain editing is implemented later, it is a separate durable world-delta family with its own compatibility/persistence rules. The building system may consume the resulting world surface but must not make terrain mutation an implicit side effect of every placement.

## 13. Presentation remains replaceable

Canonical placement geometry and presentation geometry are deliberately different concerns.

A wooden wall can later change from a prototype box to a detailed stylized wall with richer materials, damage variants, trim, moss, paint, or LODs while remaining the same logical piece definition/placed instance.

Likewise, an art-style or shader change must not alter:
- semantic building definition identity;
- snap compatibility unless the authored logical contract explicitly changes;
- persistent instance identity;
- deterministic base-world identity;
- saved ownership/durability state.

## 14. Intentionally adjustable decisions

This contract does **not** lock:
- exact foundation/wall/floor dimensions;
- rotation increments;
- snap-ranking weights;
- maximum unsupported spans;
- material tiers/stat values;
- durability/damage balance;
- construction recipes;
- resource refund percentages;
- terrain-editing rules;
- exact inventory integration UX;
- final mesh/material/art style;
- streaming radii or render-cluster sizes;
- final multiplayer authority implementation.

Those decisions require prototypes, balancing, profiling, and/or later owning contracts.

## 15. Implementation order

When implementation is eventually promoted, prefer a narrow sequence that proves the architecture before feature expansion:

1. build-piece definition/catalog boundary;
2. placement preview, ray/surface selection and rotation;
3. authored socket snapping;
4. validation + atomic resource transaction;
5. persistent placed-instance/world-delta representation;
6. minimal prototype construction set;
7. structural-support graph;
8. repair/deconstruction/damage;
9. interactive pieces through composed gameplay systems;
10. streaming/batching optimizations;
11. later upgrades, blueprints, cosmetic variants and terrain editing.

This is sequencing guidance, not permission to bypass the project pull board or dependency gates.

## Locked invariants

Future implementation should preserve these invariants unless an explicit architecture decision supersedes them:

1. procedural base-world truth and player-built durable deltas are different ownership layers;
2. authored build-piece identity is independent of file/scene/mesh paths;
3. placed-instance identity is independent of runtime Node/chunk/cell lifetime;
4. structural snapping comes from authored logical sockets, not arbitrary render geometry;
5. placement commits atomically with resource/state mutation;
6. surface and Underworld construction share one building architecture;
7. structural integrity is an explicit gameplay graph, not accidental physics behavior;
8. presentation, LOD, batching and mesh replacement cannot redefine logical building state;
9. specialized interactive behavior composes with building placement rather than duplicating whole subsystems;
10. final balance values and art remain adjustable behind these boundaries.
