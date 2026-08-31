# Building System Architecture

Status: **LOCKED core design direction; implementation/content expansion phased**

Building is a core creative pillar of Underworld. The target is an expressive modular construction system in the spirit of Valheim: easy to use normally, permissive enough for advanced builders to create combinations the developers did not explicitly design, and architected to remain viable when players construct settlements far beyond ordinary expected scale.

This document defines ownership and extension boundaries. Exact dimensions, keybinds, balance values, final art and final performance budgets remain profile/prototype decisions.

## 1. Core model

Underworld uses authored modular building definitions plus durable placed-instance state.

```text
BuildPieceDefinition
        |
        v
placement request -> preview/snap/free transform -> validation -> authoritative commit
                                                        |
                                                        v
                                                 BuildInstance state
                                                        |
                                   +--------------------+--------------------+
                                   |                                         |
                                   v                                         v
                            runtime representations                   durable world delta
```

The deterministic base world and player construction are different ownership layers.

## 2. Definition identity vs placed identity

A `BuildPieceDefinition`-equivalent describes reusable content such as a wall, floor, beam, stair, roof piece, arch, gate, workstation or decoration.

A definition may own/reference:
- semantic definition ID and schema/version;
- category/subcategory/tags;
- canonical placement bounds/footprint;
- snap sockets;
- allowed orientation/placement capabilities;
- structural/material profile;
- durability/repair profile;
- construction requirements;
- upgrade-family compatibility;
- presentation binding;
- catalog/search metadata.

A placed instance is separate mutable durable state.

Conceptually:

```text
BuildInstance
- persistent instance identity
- semantic piece definition ID
- arbitrary world-domain-local transform
- durable connection state only where required
- mutable health/durability
- permissions/ownership where applicable
- selected variant/customization state
- explicitly durable special-component state references
```

Runtime Nodes, draw batches, mesh clusters, LODs, collision aggregation and preview objects are not persistent building identity.

## 3. Building pieces are declarative content

The architecture is expected to support a very large long-term library, potentially **1000+ player-usable building pieces/variants**.

That scale must remain primarily a content-authoring problem rather than 1000 bespoke code paths.

Avoid:

```text
WoodWallA.gd
WoodWallB.gd
StoneWallA.gd
Roof17.gd
...
```

Prefer:

```text
one generic placement/runtime architecture
+ validated BuildPieceDefinition content
+ composed special capabilities where required
```

Before the library grows large, the family needs:
- identity rules;
- category/tag rules;
- socket rules;
- structural-profile rules;
- authoring workflow;
- automated validation.

## 4. Modular pieces, not voxel-authoritative blocks

The authoritative construction unit is a modular architectural/structural piece, not a generic voxel cube.

Families may include:
- foundations;
- posts/pillars;
- floors/half floors;
- walls/half walls;
- beams in multiple lengths;
- diagonal braces;
- stairs/ladders;
- roofs in multiple angles;
- roof corners/joins;
- arches;
- door/window frames;
- rails/fences;
- gates/doors;
- workstations/storage;
- defenses;
- lights/utilities;
- furniture/decorations.

The logical construction grid exists to create predictable compatibility; the visual pieces do not need to look like grid cubes.

## 5. Shape vocabulary before cosmetic variety

Early building content should prove **construction grammar first**.

The first useful kit should favor many combinable shapes with very little cosmetic duplication.

Indicative initial direction:

```text
WOOD
- one main visual/material family
- useful floors/walls/half pieces
- several beam/post lengths
- diagonal braces
- stairs/rails/door
- a small useful roof-angle/join family

STONE
- foundation/floor/wall/pillar/arch/stair essentials

IRON
- primarily reinforcement, beams/support, bars/gates and structural utility first
```

Exact piece counts and dimensions are not locked.

A new beam length, roof join or half-piece often creates more new building possibilities than another recolor of an existing wall. Cosmetic/material-family multiplication comes after the shape language is proven.

## 6. Grid + semantic sockets

The system should use a canonical construction grid together with authored semantic snap sockets.

The grid provides predictable coarse dimensions/alignment.

Sockets describe meaningful relationships such as:
- wall left/right/top/bottom;
- floor edge/corner;
- beam end;
- post top/bottom;
- roof edge/ridge;
- arch connection;
- railing edge;
- structural support role.

A socket is a logical placement contract, not a render-mesh vertex.

A future piece may extend visually beyond its logical module bounds as long as it preserves compatibility and does not break placement/collision expectations.

## 7. Snapping is the default, not a prison

Normal placement should strongly favor convenient snapping.

Advanced builders must also be able to deliberately escape snapping and create transforms that were not part of the intended socket combinations.

Conceptually:

```text
normal placement
-> grid/socket assistance

hold/toggle snap-disable modifier
-> free placement / manual alignment

release/restore
-> snapping returns
```

The exact input key (for example Shift) is not locked by this architecture document.

Possible advanced controls may later include:
- snap-point cycling;
- fine rotation increments;
- local/global rotation modes;
- small positional offsets;
- duplicate targeted/last piece;
- preserve-transform replacement;
- temporary collision/surface alignment modes.

## 8. Arbitrary transforms are durable

The persisted building model must not reduce every piece to a grid coordinate plus 90-degree rotation.

Advanced constructions require general transforms.

Conceptually persist:

```text
position
rotation/basis/quaternion
piece definition identity
```

The grid/socket system helps calculate a transform. It does not define the only transforms that are legal.

This permits beams to become:
- structural beams;
- trim;
- ladder steps;
- railings;
- decorative framing;
- custom stairs;
- embedded supports;
- shapes the original kit did not explicitly provide.

## 9. Overlap is usually allowed

Do not use generic render/physics overlap as an automatic placement rejection rule.

Creative building depends on substantial intentional overlap.

Default direction:

```text
partial overlap with another build piece -> allowed
piece embedded into another piece       -> allowed
near-identical overlapping transforms   -> allowed unless a narrow technical rule says otherwise
piece embedded into valid terrain       -> allowed/desirable
hard protected gameplay volume          -> reject
invalid/out-of-world numeric transform  -> reject
```

Exact duplicate prevention may be added only as a narrowly scoped accidental-placement safeguard and must not prohibit legitimate near-duplicate construction.

Coplanar visual z-fighting is a presentation issue, not a reason to globally ban overlapping architecture.

## 10. Terrain embedding is first-class

Posts, foundations, walls, stone and other pieces must be able to extend into terrain.

Procedural terrain is uneven; exact bottom-face alignment would make construction unnecessarily fragile.

A buried piece may look and behave more believable than one hovering precisely on the terrain surface.

Terrain/rock contact may also provide structural root support according to explicit anchor rules.

Terrain embedding and terrain deformation are separate concepts. A piece may intersect terrain without automatically modifying the terrain data.

## 11. Placement is request -> validation -> commit

Placement remains transactional.

```text
BuildPlacementRequest
        |
        v
candidate arbitrary transform / optional socket relationship
        |
        v
BuildPlacementValidator
        |
        +-- finite/valid transform
        +-- allowed world domain / protected zones
        +-- allowed anchor/surface where required
        +-- structural root/connection semantics where required
        +-- permissions
        +-- resource availability
        +-- only narrow hard-overlap restrictions where gameplay truly requires them
        |
        v
Authoritative commit
        |
        +-- consume resources atomically
        +-- create persistent BuildInstance
        +-- update local structure/connectivity graph
        +-- realize/update runtime representation
```

Failure must not partially consume resources or create half-committed state.

Inventory/crafting owns resource transactions; building does not invent a second resource model.

## 12. Structural integrity is a gameplay graph

Underworld should use an understandable graph-based support model rather than full real-time structural engineering.

```text
terrain / rock / valid structural root
                |
                v
          foundation/post
                |
         support propagation
          /      |       \
       wall     beam     floor
          \       |       /
                 roof
```

Structural state is explicit logical data, not accidental rigid-body behavior.

## 13. Material-dependent support propagation

Materials should differ structurally, not merely by hit points or appearance.

Locked relative direction:
- **wood** transfers/propagates structural support less effectively and over shorter practical spans;
- **stone** provides strong foundation/massive structural support;
- **iron** enables very strong reinforcement and long/ambitious structural spans.

Exact formulas remain balancing work.

A possible model may combine:
- source support/capacity;
- connection role;
- distance/length attenuation;
- material attenuation;
- piece-specific structural profile;
- vertical/horizontal modifiers.

The objective is a predictable construction puzzle, not finite-element analysis.

## 14. Support evaluation is event-driven and cached

Large structures must not run a full support solve every frame.

```text
place/remove/destroy relevant piece
-> mark affected graph subset dirty
-> recalculate affected support paths
-> propagate only changed results
-> cache stable state
```

If a 20,000-piece town is unchanged, structural simulation should perform near-zero continuous CPU work.

See [`../10_architecture/PERFORMANCE_AND_SCALABILITY.md`](../10_architecture/PERFORMANCE_AND_SCALABILITY.md).

## 15. Structural state should be readable

The player should understand why a construction works or fails without reading equations.

A building tool may communicate support through states/colors such as:
- grounded/rooted;
- strong;
- moderate;
- weak;
- near limit/unsupported.

Exact colors/UX remain presentation work.

The support system should create useful constraints while preserving creative freedom.

## 16. Hard constraints vs soft constraints

The system should distinguish rules that protect correctness from rules that merely help normal construction.

**Hard constraints** may include:
- invalid/non-finite transforms;
- forbidden world/protected encounter volumes;
- permission failures;
- missing resources;
- explicitly impossible anchor rules for special pieces;
- other concrete safety/integrity constraints.

**Soft constraints** include:
- grid alignment;
- recommended snap point;
- conventional orientation;
- intended piece combination;
- aesthetic intersection warnings.

Soft constraints should generally be bypassable.

## 17. Building is a durable world delta

Player construction is not written back into deterministic generator truth.

```text
world seed + domain generator manifests
        |
        v
deterministic base world
        |
        + player/world deltas
        v
realized world
```

Unloading a cell/sector must not lose buildings.

Changing meshes/materials/LOD must not change building identity.

## 18. Both world domains share one building architecture

Do not create incompatible `OverworldBuilding` and `UnderworldBuilding` systems.

The same building definition/instance architecture operates in both domains.

Placement restrictions may differ through domain/surface tags and protected volumes.

Examples:
- foundation accepts terrain/rock/support surfaces;
- wall torch accepts vertical structure/rock;
- hanging light accepts ceiling/support;
- furniture may require sufficiently horizontal support.

A save/build instance explicitly belongs to one world domain.

## 19. Runtime realization is replaceable and scalable

A large settlement may contain thousands of individually persistent logical pieces without requiring thousands of expensive permanently active Nodes/draw calls/process callbacks.

Possible representations include:
- MultiMesh/GPU instancing;
- spatial render batches;
- mesh clusters;
- sector-based visibility;
- LOD/proxy meshes;
- collision aggregation/tiers;
- pooled interactive representations;
- local dirty-sector rebuilds.

A render batch containing 500 walls may still correspond to 500 logical wall instances.

## 20. Megabuilds are a design target

The system must intentionally test structures beyond ordinary expected play.

Examples:
- multi-building towns;
- several thousand repeated pieces;
- dense decorative overlap;
- tall stone pillars;
- iron-supported sky bridges/platforms;
- elevated settlements/"sky towns";
- hundreds of lights/interactables;
- long sessions of incremental modification.

There is no promise of infinite construction; hardware always has limits. The requirement is graceful scaling and measured limits rather than architecture that immediately collapses once players exceed the expected house size.

## 21. Interactive pieces use composition

Doors, chests, workstations, lights, beds, traps and similar objects remain build pieces for placement/persistence while composing with the gameplay system that owns their special behavior.

```text
DoorPieceDefinition + door state/interaction
StoragePieceDefinition + container state
WorkbenchPieceDefinition + crafting capability
LightPieceDefinition + light/fuel behavior
```

Building owns construction placement/structure. It must not duplicate storage, crafting, combat or other subsystem authority.

## 22. Upgrades preserve continuity where compatible

A compatible replacement/upgrade may preserve:
- persistent instance identity;
- transform;
- compatible socket relationships;
- permissions;
- explicitly transferable state.

Definition/rulebook identity determines compatibility, not presentation mesh paths.

## 23. Blueprints are a planned extension

The architecture should allow future blueprints to store a set of semantic piece definitions plus relative transforms/connections.

Potential consumers:
- player-saved designs;
- developer-authored structures;
- procedural settlements/ruins;
- repeated construction layouts.

A blueprint is a placement description over ordinary logical pieces, not a reason to destroy per-piece identity.

## 24. Player and procedural structures may share the construction language

Where useful, procedural settlements/ruins can consume the same modular piece definitions or blueprint language used by players.

This multiplies the value of the asset library and keeps architecture visually coherent.

It is not mandatory that every procedural ruin be reconstructible from player pieces; hero/special assets may remain separate where justified.

## 25. Catalog/UI must scale with content count

A 1000-piece library cannot be a single scrolling icon list.

The building content model must support discovery metadata for later UI such as:
- category/subcategory;
- material/style;
- shape/role;
- search text/tags;
- favorites;
- recent pieces;
- unlocked/available state;
- context-sensitive related variants.

UI architecture must scale with content growth without changing persistent piece identity.

## 26. Terrain editing is separate

Building must not require flatten/raise/lower/dig terrain mutation to function.

If terrain editing is implemented later, it is a separate durable world-delta family.

Construction may consume the resulting surfaces but must not make terrain mutation an implicit side effect of placement.

## 27. Presentation remains replaceable

A basic logical wood wall may later receive:
- richer geometry;
- damage variants;
- moss/dirt;
- paint/material variants;
- improved normal maps;
- LODs;
- shader effects.

None of those changes should redefine semantic piece identity unless an explicit content migration says so.

## 28. Implementation sequence

Prefer proving freedom and scale before content multiplication:

1. building-definition/content validation boundary;
2. arbitrary-transform placement preview and surface targeting;
3. canonical grid and socket model;
4. rotation and deliberate snap-disable/free placement;
5. permissive overlap + terrain embedding rules;
6. atomic resource placement/removal;
7. durable placed-instance/world-delta persistence;
8. small wood shape kit with placeholder/simple art;
9. structural graph + terrain roots;
10. wood/stone/iron structural profiles;
11. support readability/debug/build-tool feedback;
12. repair/damage/deconstruction;
13. building-sector runtime partitioning;
14. batching/instancing/collision scalability;
15. megabuild performance benchmarks;
16. stone and iron shape expansion;
17. scalable build catalog/search/favorites/recent UI;
18. interactive piece composition;
19. blueprint/prefab language;
20. later cosmetic/style multiplication and terrain editing.

This sequence is roadmap guidance and does not override the pull-board dependency/WIP protocol.

## Intentionally adjustable decisions

Not locked here:
- exact base grid dimension;
- exact wall/floor/beam sizes;
- exact roof angles;
- exact input keybinds;
- exact rotation increments;
- exact snap ranking weights;
- exact structural formulas/thresholds;
- exact material stats;
- exact initial piece count;
- exact resource recipes/refunds;
- exact collision aggregation strategy;
- exact render batch/sector size;
- exact LOD distances;
- final art/material palette;
- final multiplayer authority implementation.

## Locked invariants

1. Building uses modular declarative pieces, not voxel-authoritative construction.
2. The architecture must scale to a very large content library without bespoke code per piece.
3. Shape vocabulary is prioritized before cosmetic variety.
4. Grid/socket snapping is convenience, not a hard placement prison.
5. Placed pieces support arbitrary durable transforms.
6. Intentional overlap is normally allowed.
7. Terrain embedding is valid and desirable.
8. Structural support is explicit, understandable, graph-based and event-driven.
9. Wood propagates support less effectively than stronger stone/iron structural solutions; exact balance remains open.
10. Building state is a durable world delta separate from deterministic base generation.
11. Overworld and Underworld share one building architecture.
12. Runtime batching/LOD/collision optimization cannot erase logical piece identity.
13. Megabuilds are intentional performance stress cases.
14. Specialized interactive behavior composes with building rather than duplicating other gameplay systems.
15. A large future build catalog requires scalable taxonomy/search/UI metadata.
