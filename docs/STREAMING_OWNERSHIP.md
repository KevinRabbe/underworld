# Underworld — Streaming Ownership and Runtime Lifetime Architecture

## Status

This document defines who owns deterministic world definitions, geometry descriptions, runtime cells, collision, simulation and audio as the player moves through one continuous surface/Underworld world.

The responsibility boundaries are **LOCKED at the architectural level**. Exact cell sizes, cache budgets and Godot class names remain tuning/implementation choices.

Core principle:

> **Streaming decides which representations of the world are currently expensive/live. It does not decide what the deterministic world contains.**

---

## 1. One world, not surface mode versus cave mode — LOCKED

Surface and Underworld share one global world coordinate system.

Streaming must therefore not be built around a hard state such as:

```text
current_world = SURFACE
```

or:

```text
current_world = UNDERGROUND
```

because near a cave mouth the player may need:

```text
surface render/collision
+ entrance geometry
+ nearby underground render/collision
```

at the same time.

Deep underground, surface runtime content can usually be released because it is not relevant, but this is a streaming-demand decision rather than a separate world instance.

---

## 2. Ownership layers

Use distinct owners for distinct lifetimes.

```text
WorldDefinitionService
    owns/accesses deterministic finalized definitions

GeometryDescriptionService/Cache
    owns evictable pure base-geometry descriptions

WorldStreamingCoordinator
    computes runtime demand from observer(s)

SurfaceRuntimeStreamer
    owns live surface chunk/runtime representation

UnderworldRuntimeStreamer
    owns live 3D underground runtime cells

WorldDeltaStore
    owns persistent player-caused world changes

Simulation/Audio activation layers
    own expensive nearby runtime behavior
```

Do not make one chunk/node object own all of these responsibilities.

---

## 3. `WorldDefinitionService`

### Responsibility

Provide deterministic finalized world-definition data by stable address/region and coordinate with the pure generation pipeline when data is not already cached.

Conceptual API:

```text
request_region_definition(region_address, priority)
get_region_definition_if_ready(region_address)
request_entrance_descriptors(world_bounds, priority)
query_definition_objects(world_bounds / stable IDs)
```

### Owns

```text
immutable finalized UndergroundRegionDefinition cache
world/region address index
surface entrance-integration descriptor index/cache
in-flight deterministic definition-generation requests
```

### Does not own

```text
runtime Nodes
rendered meshes
physics bodies
AI
save deltas
player progression
```

### Cache rule

Finalized definitions are deterministic and regenerable. The in-memory cache may evict them when not pinned/recently useful.

Evicting a definition cache entry does not destroy world state.

---

## 4. Definition cache versus save data

A deterministic definition cache is disposable.

```text
cache deleted -> regenerate from seed/contracts
```

A persistent world delta is not disposable.

```text
delta deleted -> player state lost
```

These must never share ownership merely because both refer to a region/object.

The `WorldDeltaStore` is described further in persistence architecture, but streaming always treats it as an external durable state source.

---

## 5. `GeometryDescriptionService`

### Responsibility

Produce/cache pure `BaseGeometryDescription` data for bounded geometry cells/world bounds from finalized definitions.

Conceptual API:

```text
request_geometry(cell_address, quality/profile, priority)
get_geometry_if_ready(cell_address)
release_geometry_interest(cell_address)
```

### Owns

```text
in-flight pure geometry-generation jobs
evictable geometry-description cache
geometry fingerprints/diagnostics
```

### Does not own

```text
runtime MeshInstance3D nodes
CollisionShape3D nodes
persistent player modifications
AI/audio
```

A geometry description is intermediate deterministic data, not a scene.

---

## 6. Geometry cells versus macro regions versus networks

These are separate partitions.

```text
Macro region
    deterministic generation/ownership partition

Cave network
    topology component/identity

Geometry cell
    bounded base-geometry generation/cache partition

Runtime streaming cell
    lifetime/LOD partition for live runtime representation
```

Geometry and runtime cells may use the same spatial grid initially if that is practical, but the architecture must not require that forever.

One cave network may cross many cells.

One cell may contain fragments from several networks/regions.

A tunnel fragment does not get a new persistent gameplay identity just because it crosses a cell boundary.

---

## 7. Underground runtime cells — DIRECTIONAL

The Underworld should use a 3D runtime spatial index because different caves can occupy the same X/Z at different Y/depths.

Conceptually:

```text
UnderworldRuntimeCellAddress(x, y, z)
```

Exact dimensions are open.

A 2D surface chunk grid remains suitable for surface terrain, while both systems still resolve to one global 3D world space.

---

## 8. `WorldStreamingCoordinator`

### Responsibility

Observe one or more runtime observers (initially the player/camera) and translate world position/context into demand sets for representations.

Conceptual demand classes:

```text
definition demand
geometry-description demand
render demand
collision demand
simulation/interactable demand
audio demand
entrance/prefetch demand
```

The coordinator does not generate caves itself.

### Initial observer inputs

```text
player world position
camera world position/frustum where useful
movement direction/velocity for prefetch
nearby entrance/portal relevance
environment/depth context
```

Exact heuristics remain open.

---

## 9. Runtime representation tiers — LOCKED

A location/object may exist at progressively more expensive tiers:

```text
T0  address/world definition not currently cached
T1  finalized deterministic definition cached
T2  base geometry description cached
T3  render representation active
T4  collision representation active
T5  nearby interactables/creatures simulation active
T6  local audio active when relevant
```

These tiers are not required to activate at identical radii.

Typical direction:

```text
render radius      > collision radius >= simulation radius
```

Audio uses its own finite relevance/occlusion logic rather than simply matching render distance.

Exact thresholds are open and must be profiled.

---

## 10. Hysteresis / release margins — LOCKED DIRECTION

Streaming activation and release thresholds should not be identical.

Example concept:

```text
activate collision at R
release collision at R + margin
```

This prevents cells/bodies from repeatedly loading/unloading when the player hovers near a boundary.

The existing surface prototype already uses this idea for nearby world-object physics; the generalized architecture should preserve it.

---

## 11. Surface runtime ownership

`SurfaceRuntimeStreamer` owns live surface chunk representation.

Conceptually:

```text
surface mesh/runtime chunk
surface collision tier
surface decoration render proxies
nearby surface interactable/physics proxies
```

Persistent object state remains referenced by stable ID through `WorldDeltaStore`.

Surface chunk unload must not lose harvested/building/modification state.

---

## 12. Underworld runtime ownership

`UnderworldRuntimeStreamer` owns live underground runtime cells.

A runtime cell conceptually owns only its current live representation:

```text
runtime Node root
mesh instances
collision bodies
local static/interactable proxies registered for activation
runtime references to source stable IDs
```

It does **not** own the authoritative deterministic cave graph or durable save state.

When the cell unloads, its Nodes can disappear safely.

---

## 13. Runtime cell state machine — DIRECTIONAL

A runtime cell should have an explicit lifecycle rather than ad-hoc booleans spread across managers.

Conceptually:

```text
UNREQUESTED
    -> DEFINITION_PENDING/READY
    -> GEOMETRY_PENDING/READY
    -> RENDER_ACTIVE
    -> COLLISION_ACTIVE
    -> SIMULATION_ACTIVE
```

and downgrade in reverse as demand disappears.

Audio may be an orthogonal activation flag/tier because it depends on source relevance/occlusion rather than only cell distance.

Implementation may compress states, but ownership/transitions should remain explicit.

---

## 14. Main-thread versus worker boundary

### Worker-safe/pure-data direction

```text
deterministic region generation
stage validation/fingerprinting
entrance descriptor generation
base geometry-description generation
mesh vertex/index array preparation where safely isolated
```

### Main-thread/runtime boundary

```text
scene-tree Node creation/removal
MeshInstance3D/scene ownership changes
physics body/shape scene setup
runtime registration with interaction/simulation systems
other Godot APIs not explicitly guaranteed worker-safe
```

The project should remain conservative: if Godot's thread-safety guarantee is unclear, keep engine object mutation on the main thread and move computational data preparation to workers.

---

## 15. In-flight request ownership and stale-result protection — LOCKED

Streaming requests can become obsolete while a worker task is running.

Example:

```text
player approaches cell A
-> geometry task A starts
player turns around
-> cell A no longer wanted
```

The architecture must support cancelling/discarding stale work without corrupting state.

Every asynchronous request should conceptually have:

```text
request key
source world/generator identity
cell/region address
requested tier/quality
request generation/token
```

When a worker result returns, the main thread applies it only if the current owner still wants that matching request/token.

A stale result may be cached if useful and compatible, but it must not resurrect an unloaded runtime cell by accident.

---

## 16. No task-order world mutation

Worker completion order must not decide deterministic world truth.

```text
A finishes before B
```

versus:

```text
B finishes before A
```

may change which result becomes available first, but never:

```text
which cave exists
which connector is accepted
which stable ID is assigned
```

The pure generation architecture guarantees the data result; the streaming coordinator only decides when to display/simulate it.

---

## 17. Request priorities — DIRECTIONAL

The scheduler should prioritize work by immediate gameplay need.

Conceptual priority order:

```text
1. missing collision/simulation data immediately around player
2. visible/soon-visible geometry
3. entrance transition prefetch
4. movement-direction prefetch
5. farther render geometry
6. speculative/background definition/cache work
```

Exact scoring is open.

Do not allow large distant definition jobs to starve collision/geometry required around the player.

---

## 18. Entrance transition streaming — LOCKED DIRECTION

Entrances are where surface and Underworld representations overlap.

When an entrance becomes relevant, the coordinator should prefetch enough underground data/geometry before the player crosses the threshold that the entrance does not reveal an empty void/pop-in.

Conceptually:

```text
player approaches entrance
    |
    +--> surface remains active
    +--> entrance descriptor already integrated
    +--> connected underground definition pinned/requested
    +--> first underground geometry cells prefetched
    +--> collision ready before traversal
```

When the player moves deep enough underground, distant surface runtime content can release normally.

There is no teleport/load-screen requirement in the architecture.

---

## 19. Surface entrance integration query path

Surface chunk geometry/build needs entrance descriptors that overlap its bounds.

Conceptual dependency:

```text
SurfaceChunkRequest
      |
      v
WorldDefinitionService.request_entrance_descriptors(surface_bounds)
      |
      +-- may schedule pure underground region definition generation
      |
      v
SurfaceEntranceIntegrationDescriptor[]
      |
      v
surface geometry/build
```

This dependency must not require underground runtime cells to exist.

### Deadlock prevention

The surface streamer does not synchronously ask a live underground Node for entrance data.

Both surface and underground streaming depend on the shared pure `WorldDefinitionService`.

---

## 20. Cross-region definition pinning

Some operations such as secondary connectivity or geometry near a region boundary require neighboring definitions.

The scheduler may temporarily pin dependency definitions while a stage/geometry request uses them.

After dependent work completes and no runtime/request interest remains, those immutable definitions may become evictable.

Reference/pin counts are cache-lifetime mechanics, not persistent ownership.

---

## 21. Geometry-description cache lifecycle

Geometry descriptions are usually more expensive than topology definitions but cheaper than full runtime representation.

Directional cache policy:

```text
keep nearby/recent geometry descriptions
release runtime Nodes first
retain geometry briefly for fast backtracking
then evict geometry under memory pressure
regenerate later if necessary
```

Exact memory budget/LRU policy remains open.

This is especially useful in caves where the player may reverse direction frequently.

---

## 22. Runtime mesh/collision lifetime

Runtime render and collision resources belong to their live cell/chunk owner.

When demand drops:

```text
simulation deactivates
collision can release
render can release later
runtime cell root can be destroyed
```

The underlying deterministic definition and persistent deltas remain unaffected.

---

## 23. Persistent deltas are not cell-owned — LOCKED

A runtime cell may query/apply deltas for objects/material inside its bounds, but the cell is not their durable owner.

Wrong:

```text
cell unloads -> destroyed-tree list disappears
```

Correct:

```text
WorldDeltaStore owns destroyed stable ID
cell loads -> queries delta -> omits/changes runtime representation
cell unloads -> durable delta remains
```

The same rule applies later to:

```text
cleared rubble
mined deposits
terrain modifications
player structures
special-location state
```

---

## 24. Delta query views — DIRECTIONAL

Runtime/base-geometry composition should request a bounded/read-only `WorldDeltaView` rather than hand every cell the complete save dictionary.

Conceptually:

```text
WorldDeltaStore.query(bounds, relevant stable IDs/categories)
    -> WorldDeltaView
```

Exact indexing belongs to persistence implementation.

This becomes important as worlds accumulate many modifications over hundreds of hours.

---

## 25. Simulation activation

Creatures/interactables should not exist as fully active simulation throughout all generated caves.

The streaming coordinator or a dedicated `SimulationActivationManager` controls nearby activation.

Conceptually:

```text
far deterministic/content definition
    -> no active AI
near enough
    -> spawn/restore runtime simulation representation
leave area
    -> deactivate/store required persistent state
```

Exact creature persistence/ecology rules are intentionally not designed in this architecture cycle.

The locked requirement is that distant Underworld content cannot require live AI Nodes merely to exist.

---

## 26. Audio activation

Audio has a separate local activation path.

Requirements already locked by world design:

- finite 3D relevance;
- solid rock/occlusion or an efficient approximation;
- shafts/tunnels/entrances may permit farther propagation;
- deep hidden content must not leak audio to the surface through arbitrary rock.

Streaming implication:

> Far/inactive creatures/locations do not need active audio sources/processors.

An audio source definition may exist without a live `AudioStreamPlayer3D` until relevant.

---

## 27. Visibility/occlusion can reduce demand, but not define truth

Deep underground, there is usually no reason to render the surface above solid rock.

Likewise, a nearby cave cell behind thick structural rock may not need the same render priority as an open connected chamber.

Visibility/portal/occlusion heuristics may reduce runtime demand later.

However they are optimizations only.

They must never decide whether the cave/entrance itself exists.

---

## 28. Multiple observers — future-compatible direction

Initial implementation can use one player/camera observer.

The coordinator interface should not make it impossible to union demand from multiple observers later:

```text
observer A demand
UNION
observer B demand
```

This can support future multiplayer/debug cameras without redesigning all ownership.

No multiplayer implementation is required now.

---

## 29. Memory-pressure behavior

When memory pressure requires eviction, prefer dropping the most reconstructable/expensive runtime layers first according to current need.

Conceptually:

```text
inactive runtime Nodes -> evict
far geometry descriptions -> evict
far finalized definitions -> evict later
persistent deltas -> NEVER evicted as disposable cache
```

Exact budgets are profiling decisions.

---

## 30. Runtime ownership invariants

The runtime architecture should enforce:

1. one live runtime owner per surface chunk address;
2. one live runtime owner per underground runtime-cell address;
3. stale async results cannot create duplicate owners;
4. live runtime fragments reference canonical source stable IDs;
5. unloading a cell cannot delete durable world deltas;
6. deleting caches cannot change generated world truth;
7. entrance overlap can keep surface + underground live simultaneously;
8. collision is ready before allowing traversal into newly relevant geometry;
9. no far cave requires live AI/audio merely to exist;
10. surface/underground streaming use shared world-definition truth rather than querying each other's scene Nodes.

---

## 31. Automated streaming tests

Most streaming correctness can be tested without a human playtest using a fake observer and fake builders.

Required test directions:

```text
move observer across surface chunk boundaries
-> expected surface demand/retention

approach an entrance
-> surface remains demanded
-> connected underground definition/geometry prefetched
-> collision requested before crossing

move deep underground
-> local underground cells active
-> distant surface released

reverse direction rapidly
-> no duplicate runtime owners
-> stale job result discarded/does not resurrect cell

force cache eviction
-> regeneration fingerprint matches
-> deltas remain intact

cross region boundary underground
-> no duplicate cross-region edge/runtime ownership

oscillate on tier radius boundary
-> hysteresis prevents thrashing
```

The harness does not need real production meshes to validate ownership/state transitions.

---

## 32. Initial implementation shape — DIRECTIONAL

Conceptual modules:

```text
world/streaming/
    world_streaming_coordinator.gd
    world_definition_service.gd
    geometry_description_service.gd
    surface_runtime_streamer.gd
    underworld_runtime_streamer.gd
    runtime_cell.gd
    streaming_request.gd

world/persistence/
    world_delta_store.gd   # later implementation
```

Exact names/folders are open.

The key rule is to preserve ownership boundaries rather than creating a single `WorldManager` that owns generation, saves, meshes, AI and audio simultaneously.

---

## 33. What remains intentionally open

- surface and underground render/collision/simulation radii;
- exact 3D runtime-cell dimensions;
- whether geometry cells initially equal runtime cells;
- cache sizes/LRU policy;
- task priority formula;
- exact prefetch distances/timing;
- detailed cave occlusion/portal optimization;
- creature simulation persistence model;
- exact audio occlusion implementation;
- exact terrain-delta spatial index/composition path.

These parameters can be measured later without changing the ownership architecture.
