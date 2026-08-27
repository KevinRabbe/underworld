# Underworld — Generation Pipeline Interfaces

## Status

This document defines the deterministic generation stages that transform a world seed/address into finalized Underworld definitions and, later, geometry descriptions.

The stage boundaries are **LOCKED at the architectural level**. Exact GDScript class/function names may change, but generation must remain decomposed into pure-data stages rather than collapsing into a monolithic cave generator.

Core pipeline:

```text
WorldGenerationContext
        |
        v
1. Macro Region Planning
        |
        v
2. Primary Topology Generation
        |
        v
3. Entrance Generation / Selection
        |
        v
4. Secondary Connectivity Analysis
        |
        v
5. Special-Location Hook Reservation
        |
        v
6. Region Finalization + Validation
        |
        v
Finalized UndergroundRegionDefinition
        |
        v
7. Base Geometry Description Generation
        |
        v
8. Runtime Build / Streaming
```

Depth-profile evaluation is a service used by macro/topology/entrance/connectivity stages rather than a one-time cosmetic pass after topology already exists.

---

## 1. Fundamental stage rule — LOCKED

A deterministic generation stage is conceptually:

```text
Result = Stage.generate(immutable_context, immutable_typed_input)
```

A stage must not require:

- a Godot scene tree;
- loaded meshes;
- physics bodies;
- active AI/audio;
- player position;
- player progression;
- player buildings;
- save deltas;
- wall-clock time;
- shared mutable RNG state;
- thread-completion order.

World truth is generated independently of what the player has done or discovered.

This preserves the design rule that a rare cavern, boss hook, deposit or structure can exist under a future base because the world generated it there independently.

---

## 2. `WorldGenerationContext`

Every deterministic stage receives a read-only context containing the services/configuration needed to reproduce world truth.

Conceptual fields/services:

```text
WorldGenerationContext
- world_seed
- world_id
- schema_version
- generator_manifest
- seed_schema_version
- stable_address_factory
- stable_id_factory
- seed_deriver
- depth_profile_registry
- deterministic_surface_sampler
- world/macro generation settings
```

### Must not contain

```text
Player
SceneTree
current loaded chunks
current FPS/time
save-file mutation dictionaries
runtime enemy state
mutable shared RNG
```

### Context immutability

The context is immutable/read-only during one generation contract.

Generator stages may create local builders/results, but they do not mutate global world generation configuration.

---

## 3. Generator manifest and stage revisions

Randomness revisions are not sufficient to describe every generation change. A deterministic algorithm can change while consuming the same seed domains.

Therefore the future `GeneratorManifest` must be able to record at least conceptually:

```text
seed domain revisions
stage revisions
profile/config revisions
persistent external algorithm/config revisions where required
```

Example:

```text
macro_region_stage_rev = 1
primary_topology_stage_rev = 2
entrance_stage_rev = 1
secondary_connectivity_stage_rev = 3
geometry_description_stage_rev = 2
```

Exact manifest encoding belongs to persistence/version architecture, but stage interfaces must expose a stable revision identity.

Global generator version remains a manifest identity, not a universal random salt.

---

## 4. Pipeline scheduler versus generation stages

The scheduler and the generators have different responsibilities.

### Pipeline scheduler owns

```text
which region/stage is requested
stage dependency resolution
worker-task scheduling
pure-data cache lookup/storage
neighbor primary-topology dependency collection
cancellation/prioritization for streaming
main-thread handoff for runtime construction
```

### Generator stage owns

```text
deterministic transformation of its supplied data
candidate creation
stable addresses/IDs through central factories
domain-derived randomness
canonical sorting/tie rules
stage-local diagnostics
```

### Important consequence

A stage does **not** secretly fetch/generate neighbor regions itself.

If a stage needs neighboring data, the scheduler resolves that dependency and passes an immutable typed view into the stage.

This prevents hidden recursive generation, deadlocks and order-dependent behavior.

---

## 5. Stage 1 — Macro Region Planning

### Purpose

Create the deterministic high-level plan for one underground macro region before individual cave networks are built.

### Input

```text
MacroRegionRequest
- region StableAddress / region_coord
- canonical region world-space bounds
```

plus `WorldGenerationContext`.

### Output

```text
MacroRegionPlan
- region stable_id/address
- region bounds/anchor
- regional depth/profile bias parameters
- macro geology/topology tendency data
- fixed network candidate-slot addresses/budget
- entrance tendency/context data
- special-location candidate-slot budget/hooks-to-consider
- boundary/proximity analysis metadata
- canonical diagnostics/fingerprint fields
```

### Rules

- The plan contains candidate **slots**, not only accepted networks.
- Candidate slots exist before acceptance so later identities do not compact/renumber.
- Macro planning does not generate meshes.
- Macro planning does not generate enemies/resources/boss gameplay.
- Regional profile bias is a tendency, not a hard depth-floor classification.

---

## 6. Depth-profile service — architectural dependency

Shallow/mid/deep are not a cosmetic pass after topology.

The topology generator must be able to ask:

```text
profile = DepthProfileProvider.sample(
    world_position,
    region_plan,
    stable_address/context
)
```

and receive conceptually:

```text
DepthProfileSample
- shallow_weight
- mid_weight
- deep_weight
- depth/reference metrics
- local exception/bias data where applicable
```

### Surface-relative depth

The provider must be capable of using a deterministic surface reference, for example conceptually:

```text
depth_below_surface = surface_reference_height(x,z) - world_y
```

The exact final depth formula remains open, especially around ocean/terrain edge cases, but it must use deterministic world data rather than loaded surface meshes.

### Resolved generation grammar

A stage may convert profile weights into blended generation parameters:

```text
ResolvedCaveGrammar
- chamber size distribution
- tunnel length/width tendency
- verticality
- branch/dead-end tendency
- connectivity tendency
- water/geology hooks
- entrance tendency
- future content hooks
```

The three base profiles remain explicit data/config objects. Avoid scattering `if depth > X` conditionals throughout generators.

---

## 7. Stage 2 — Primary Topology Generation

### Purpose

Generate stable primary cave networks, nodes and primary edges inside one macro region.

This stage determines the core local cave graph before entrances and secondary connectivity are added.

### Input

```text
PrimaryTopologyRequest
- MacroRegionPlan
- depth-profile service/config view
```

plus `WorldGenerationContext`.

### Output

```text
PrimaryTopologyResult
- region stable_id/address
- accepted CaveNetworkDefinition builders/data
- CaveNodeDefinition builders/data
- primary CaveEdgeDefinition builders/data
- stable transient candidate metadata needed by later analysis
- canonical topology metrics
- boundary/proximity candidate metadata
- diagnostics/fingerprint
```

### Rules

- Network/node/edge addresses exist before acceptance using the stable candidate architecture.
- A rejected network/node candidate does not renumber later candidates.
- Primary network generation queries shallow/mid/deep grammar while generating structure.
- Primary topology should remain locally understandable as generated cave systems; secondary loop logic is not hidden inside this stage.
- Primary topology does not create surface openings yet.
- Detailed tunnel/chamber meshes are out of scope.

### Region-boundary rule — DIRECTIONAL

Primary topology is owned by one macro region. Cross-region relationships are reconciled later through canonical secondary/cross-region analysis rather than allowing two independently generated regions to accidentally claim the same connection.

The topology stage may emit stable transient boundary/proximity anchors/candidates for later analysis.

---

## 8. Primary topology invariants

Before later stages consume primary topology, validate at least:

```text
unique stable IDs
valid network ownership
valid node positions/bounds
valid primary edge endpoints
no duplicate forbidden primary edges
primary components satisfy stage connectivity rules
profile weights valid
candidate metadata canonical
all values finite
```

Later stages should not be forced to compensate for structurally invalid primary topology.

---

## 9. Stage 3 — Entrance Generation / Selection

### Purpose

Select viable deterministic surface connections into already-generated primary cave topology.

Entrances are real world-definition objects, not random holes placed before caves exist.

### Input

```text
EntranceGenerationRequest
- MacroRegionPlan
- PrimaryTopologyResult/view
- deterministic surface sampling view
- depth-profile view
```

plus `WorldGenerationContext`.

### Output

```text
EntranceGenerationResult
- accepted EntranceDefinition data
- entrance-path edge definitions/references
- SurfaceEntranceIntegrationDescriptor list
- rejected-candidate diagnostics if needed
- entrance topology metrics
- canonical fingerprint
```

### `SurfaceEntranceIntegrationDescriptor`

This is pure deterministic data telling the surface/runtime geometry systems where an entrance must physically integrate.

Conceptual fields:

```text
entrance stable_id
world-space bounds
surface opening/clearance requirement
surface anchor position/orientation
underground connection anchor
entrance/descent profile
ownership/reference data
```

It is not a mesh and not a loaded scene.

### Rules

- Candidate entrances have stable addresses before acceptance.
- The normal design tendency is roughly 1–3 suitable surface entrances, not a universal hard invariant.
- An entrance may connect at shallow, mid or unexpectedly deep positions when generation permits.
- Entrance selection can consider topology usefulness, surface viability and depth profile.
- Progression/player level is not an input.

---

## 10. Surface generation dependency created by entrances

Because entrances are determined from underground topology, a surface chunk may need deterministic entrance integration data even when no underground runtime geometry is loaded.

Architectural rule:

> Surface mesh generation/build must be able to query finalized `SurfaceEntranceIntegrationDescriptor`s overlapping its area from the world-definition service/cache.

This may cause pure underground **definition data** to be generated before a surface chunk is finalized. That is acceptable.

It must not require loading underground cave meshes, collisions, enemies or audio.

The streaming-ownership document will define the exact query/cache path.

---

## 11. Stage 4 — Secondary Connectivity Analysis

### Purpose

Apply the intentional ~10% connectivity philosophy after primary networks and entrances already exist.

This stage may add:

```text
natural proximity connections
deliberate useful loops
cross-network connections
cross-region connections
vertical reconnections
```

without turning the cave graph into spaghetti.

### Local input

```text
SecondaryConnectivityRequest
- owning region MacroRegionPlan
- owning region PrimaryTopologyResult
- owning region EntranceGenerationResult
- canonically sorted neighboring PrimaryTopologyView(s) where required
- neighboring entrance/topology summary where required
- connectivity/profile rules
```

The scheduler supplies all neighbor views explicitly.

### Output

```text
SecondaryConnectivityResult
- accepted owned secondary CaveEdgeDefinition data
- external cross-region edge references for involved non-owner regions
- accepted/rejected candidate metrics
- connectivity metrics before/after
- canonical fingerprint
```

### Candidate pipeline

```text
find candidate endpoint pairs
        |
canonical candidate address
        |
compute deterministic physical/topology metrics
        |
apply domain-derived random variation if desired
        |
score
        |
canonical conflict/tie resolution
        |
accept bounded useful subset
        |
create stable CaveEdgeDefinition
```

### Rules

- Candidate enumeration order cannot determine the result.
- Same numeric score uses canonical deterministic tiebreak rules.
- Connection acceptance cannot depend on which worker finishes first.
- Existing network/node IDs are never renamed after connection.
- Profile-dependent connectivity caps/targets prevent spaghetti.

---

## 12. Cross-region connectivity ownership

Cross-region connector definitions have one canonical owner.

Conceptually:

```text
canonical region pair
+ canonical endpoint pair
+ connector candidate slot/class
-> owner region
-> one stable connector ID
```

The connectivity result for the owner stores the actual edge definition.

A non-owner region may store/reference conceptually:

```text
ExternalEdgeReference
- edge stable_id
- owner region stable_id
- local endpoint node_id
- remote endpoint node_id/region_id
```

This gives both regions navigation/streaming awareness without duplicating ownership.

The final world graph index resolves the owned definition.

---

## 13. Stage 5 — Special-Location Hook Reservation

### Purpose

Reserve deterministic anchors/clearance for future content without implementing that content inside cave topology code.

### Input

```text
SpecialLocationHookRequest
- MacroRegionPlan
- primary + accepted secondary topology view
- entrance view
- depth/profile view
- candidate-slot definitions/rules
```

### Output

```text
SpecialLocationHookResult
- SpecialLocationHookDefinition list
- reserved bounds/clearance metadata
- canonical fingerprint
```

Potential future hook categories include:

```text
large deposit
structure
boss lair
ancient complex
major collapse/rubble
other special site
```

### Rules

- Hooks are world truth independent of player progression/building.
- A future boss/resource system consumes hooks; topology code does not spawn the actual boss/resource gameplay.
- Hook placement can use finalized topology and depth context.
- Hooks use stable candidate identities and their own seed domains.

---

## 14. Stage 6 — Region Finalization + Validation

### Purpose

Combine accepted deterministic stage results into the immutable-by-convention `UndergroundRegionDefinition` snapshot used by later systems.

### Input

```text
RegionFinalizationRequest
- MacroRegionPlan
- PrimaryTopologyResult
- EntranceGenerationResult
- SecondaryConnectivityResult
- SpecialLocationHookResult
```

### Output

```text
FinalizedRegionResult
- UndergroundRegionDefinition
- owned definitions indexed by stable ID
- external cross-region references
- surface entrance integration descriptors/index entries
- canonical validation metrics
- canonical region fingerprint
```

### Finalization rules

- Canonically sort/index stable IDs.
- Validate all owned/referenced IDs.
- Normalize profile weights/metrics.
- Freeze/treat generated definitions as immutable world truth for this generation contract.
- Player save deltas are not applied here.
- Runtime nodes are not created here.

---

## 15. Final region validation

Final validation includes at least:

```text
stable-ID uniqueness
all edge endpoints valid
all entrance targets valid
cross-region ownership/reference consistency
secondary connectivity caps
profile constraints
finite bounds/positions
special-hook clearance/reference validity
canonical serialization repeatability
seed-domain/address invariants
```

A region that fails validation is a deterministic generator failure with a reproducible seed/address—not something runtime code silently patches differently each run.

---

## 16. Stage 7 — Base Geometry Description Generation

### Purpose

Translate finalized topology into deterministic streamable **base geometry descriptions** without creating scene-tree objects.

### Input

```text
BaseGeometryRequest
- finalized region/topology view
- geometry cell/address or requested world bounds
- relevant node/edge/entrance definitions
- deterministic geometry profiles/domains
- deterministic surface integration descriptors where applicable
```

### Output

```text
BaseGeometryDescription
- geometry-description stable address/revision
- chamber volume descriptions
- tunnel centerline/control descriptions
- cross-section/clearance parameters
- structural bedrock classification
- designated removable/modifiable-material volume descriptors
- entrance integration geometry data
- collision/mesh build hints
- world-space bounds
- canonical fingerprint
```

### Important separation

The base geometry description represents untouched generated world geometry.

It does **not** include:

```text
player-dug modifications
cleared collapses
mined-away deposit state
player buildings
```

Those are save/runtime deltas composed later.

### Streamable geometry cells

Geometry descriptions should be requestable by bounded streaming ownership units rather than requiring the entire cave network to mesh at once.

A network may cross many geometry/runtime cells.

The exact cell dimensions are still open.

---

## 17. Geometry ownership across cells

A node/edge can overlap multiple geometry cells, so geometry generation needs deterministic ownership/clipping rules.

Directional approach:

```text
world-definition object keeps graph ownership
geometry cells own only generated geometry fragments/cache entries
```

Fragments must derive from canonical source definition IDs + geometry-cell address.

Do not create new persistent gameplay identities just because one tunnel mesh was split across streaming cells.

---

## 18. Base geometry versus player modifications

The finished system should preserve this conceptual composition:

```text
Deterministic BaseGeometryDescription
            +
Persistent WorldDeltaView
            =
Current Runtime Geometry State
```

How terrain/deformation deltas are represented is intentionally deferred.

The important rule is that applying a player's changes must not mutate/rewrite the deterministic cave graph as if that were the original generated world.

---

## 19. Stage 8 — Runtime Build / Streaming

Runtime construction is not a deterministic world-definition stage.

It consumes generated/cached definition/geometry data and creates Godot runtime representation.

Conceptual input:

```text
RuntimeBuildRequest
- BaseGeometryDescription
- relevant WorldDeltaView
- runtime LOD/collision request
- asset/material references
```

Conceptual output:

```text
Runtime cell Nodes
meshes
collision bodies
interactables/proxies when needed
```

### Thread boundary

Pure data/geometry-description work may run on workers.

Scene-tree mutation and Godot runtime/physics setup occur on the appropriate main-thread boundary.

The streaming-ownership document defines exact ownership/lifetime rules next.

---

## 20. Ecology/resources are downstream, not topology stages

Future systems for:

```text
creatures
ecology
ordinary resource populations
boss entities
loot
structures
```

are not added to this architecture cycle merely because topology exposes hooks for them.

They may consume:

```text
finalized topology
profile/depth context
special-location hooks
geometry/navigation context
```

later.

This prevents the generation pipeline from becoming a single god-object responsible for every game system.

---

## 21. Typed result objects versus one mutable dictionary

The first implementation should use small typed data-only result/request classes or equivalent strongly structured data.

Avoid a pipeline where every stage mutates one giant dictionary with undocumented keys.

Conceptually:

```text
MacroRegionPlan
PrimaryTopologyResult
EntranceGenerationResult
SecondaryConnectivityResult
SpecialLocationHookResult
FinalizedRegionResult
BaseGeometryDescription
```

Each stage's contract should be independently testable and serializable/fingerprintable.

---

## 22. Stage diagnostics are not world truth

Stages may output diagnostic data such as:

```text
candidate counts
rejection reasons
score distributions
connectivity metrics
timing measurements
```

Diagnostics are useful for automated tests/tuning but do not automatically belong in save files or persistent world definitions.

Deterministic fingerprint fields used for compatibility tests may be retained separately.

---

## 23. Caching model — DIRECTIONAL

Pure deterministic stage outputs may be cached because they can always be regenerated from their inputs/contracts.

Conceptual cache key:

```text
WorldId
+ generator manifest/stage revision
+ region/stable address
+ stage name
+ required dependency fingerprint(s)
```

Caches are performance artifacts, not authoritative saves.

Deleting a cache must not destroy a world.

The exact cache implementation belongs to streaming/ownership architecture.

---

## 24. Cancellation and partial generation

Streaming may request generation that becomes irrelevant before completion because the player moves elsewhere.

Scheduler tasks may be cancelled/discarded where practical.

A discarded result must not change later deterministic output. There is no mutable RNG/global builder state that requires a stage to finish for future stages to remain correct.

This is another reason for pure local generation stages.

---

## 25. Deterministic dependency graph

The scheduler may execute independent work in parallel, but logical dependencies are explicit:

```text
MacroRegionPlan
      |
      v
PrimaryTopology
      |
      +-----------> EntranceGeneration
      |                    |
      +--------------------+
                           v
             SecondaryConnectivity
             ^            ^
             |            |
    neighbor primary/entrance views
                           |
                           v
              SpecialLocationHooks
                           |
                           v
                  RegionFinalization
                           |
                           v
              BaseGeometryDescription
                           |
                           v
                    Runtime Build
```

Neighbor dependency data is supplied by the scheduler, not discovered via hidden scene/runtime queries.

---

## 26. Initial implementation structure — DIRECTIONAL

A future first implementation can converge toward modules conceptually like:

```text
world/generation/
    context/
        world_generation_context.gd
        generator_manifest.gd

    ids/
        stable_address.gd
        stable_id_factory.gd
        seed_domains.gd
        seed_deriver.gd
        deterministic_rng.gd

    profiles/
        cave_generation_profile.gd
        depth_profile_provider.gd

    underworld/
        macro_region_generator.gd
        primary_topology_generator.gd
        entrance_generator.gd
        secondary_connectivity_generator.gd
        special_location_hook_generator.gd
        region_finalizer.gd

    geometry/
        base_geometry_generator.gd

    validation/
        region_validator.gd
        generation_fingerprint.gd
```

Exact folder/class names are not locked. Responsibility boundaries are.

---

## 27. Stage-level automated tests

Each deterministic stage needs tests independent of rendering.

### Macro region

```text
same address/seed -> same plan
candidate slots stable
profile bias valid
```

### Primary topology

```text
same plan -> same graph fingerprint
no invalid references
candidate rejection does not renumber siblings
profile grammar materially affects distributions across batch seeds
```

### Entrances

```text
all accepted entrances have valid surface + topology targets
rough target distribution across batch seeds
no progression/player-state dependency
same topology/surface inputs -> same entrances
```

### Secondary connectivity

```text
canonical candidate order
A-B == B-A where applicable
same cross-region result regardless of region scheduling order
connectivity bounded
no duplicate/redundant forbidden edges
```

### Special hooks

```text
stable addresses
valid anchors/clearance
independent of player state
```

### Geometry description

```text
same source definitions -> same fingerprint
neighbor cell generation order irrelevant
structural/modifiable classifications valid
```

---

## 28. What remains intentionally open

This interface specification does not yet lock:

- exact macro region dimensions;
- exact topology-generation algorithm;
- exact depth-profile curves/parameter numbers;
- exact number of fixed candidate slots/budgets;
- exact entrance scoring formula;
- exact secondary-connectivity scoring weights;
- exact special-location categories/roster;
- exact geometry spline/volume/meshing algorithm;
- exact geometry/runtime streaming-cell dimensions;
- exact cache implementation;
- exact player terrain-delta representation.

Those can be developed without breaking this architecture as long as they respect the stage contracts and locked world rules.
