# Underworld — Streaming Ownership and Runtime Lifetime Architecture

Status: **LOCKED architecture; superseded one-world assumptions removed**

This document defines runtime ownership, streaming lifetime, cache lifetime, destination readiness and bounded work for the Overworld and Underworld procedural domains.

The cross-domain decision is governed by [`00_project/ADR-001_TWO_WORLD_DOMAINS.md`](00_project/ADR-001_TWO_WORLD_DOMAINS.md) and [`20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](20_world/WORLD_DOMAINS_AND_TRANSITIONS.md).

Core principles:

> **Streaming decides which representations of deterministic world truth are currently expensive/live. It does not decide what world truth contains.**

> **Overworld and Underworld are independent runtime domains. Cross-domain travel is a lifecycle transition, not a requirement for one shared coordinate space.**

---

## 1. World domains — LOCKED

The runtime recognizes explicit world-domain identity:

```text
WorldDomain
├─ OVERWORLD
└─ UNDERWORLD
```

Positions, cell addresses and streaming demand are interpreted inside their owning domain.

A coordinate in `OVERWORLD` has no required geometric relationship to the numerically identical coordinate in `UNDERWORLD`.

Therefore this architecture does **not** require:
- one global surface/Underworld coordinate space;
- surface and Underworld runtime to be resident simultaneously;
- physical collision continuity through an entrance;
- Underworld geometry to appear behind an Overworld cave mouth;
- a surface streamer to query cave runtime Nodes;
- a cave streamer to keep surface terrain alive while the player is underground.

A transition implementation may temporarily keep both domains resident for caching or presentation, but that is an optimization, not world identity.

---

## 2. Ownership layers

Use separate owners for separate lifetimes.

```text
RootWorld / Save Identity
        |
        +-----------------------------+
        |                             |
        v                             v
OverworldDefinition             UnderworldDefinition
Services                        Services
        |                             |
        v                             v
OverworldStreamer               UnderworldRuntimeStreamer
        |                             |
        +-------------+---------------+
                      |
                      v
             WorldDomainCoordinator
             / WorldTransitionService
                      |
                      v
                 Player domain

WorldDeltaStore / persistence
    owns durable domain-qualified changes
```

The exact class names may evolve. The ownership boundaries may not collapse merely for convenience.

### WorldDomainCoordinator / transition owner
Owns:
- current/committed active domain;
- transition lifecycle;
- source/destination gateway resolution;
- destination-readiness handoff;
- atomic/fail-closed transition commit;
- domain-level presentation semantic for UI/audio;
- source-runtime release policy after successful commit.

Does not own:
- Overworld terrain generation;
- Underworld topology;
- cell generation algorithms;
- Inventory/WorldDelta/SAVE content;
- gateway selection policy that belongs to deterministic world definition.

---

## 3. Domain definition services

Each domain may use separate definition services/caches if that keeps responsibilities clear.

Conceptually:

```text
OverworldDefinitionService
- surface terrain/biome/object definitions
- Overworld gateway/source-site definitions

UnderworldDefinitionService
- finalized macro-region/network/node/edge definitions
- Underworld gateway destination/entry-site definitions
- special-location hooks
```

Shared infrastructure such as StableId factories, generator manifests, cache primitives or schedulers may be reused without making one domain generator own the other.

Definitions are deterministic/regenerable and are not runtime Nodes.

---

## 4. Cache versus durable state — LOCKED

A definition or geometry cache is disposable:

```text
cache evicted -> regenerate from seed + pinned contracts
```

Durable state is not disposable:

```text
WorldDelta / player-created structure / inventory / persistent resource state
-> survives runtime unload
```

Runtime cells/chunks may query bounded delta views. They never become the durable persistence owner.

---

## 5. Overworld runtime ownership

The Overworld streamer owns only live Overworld representations required around active/relevant observers.

Typical responsibilities:
- terrain chunks/meshes;
- local collision;
- nearby procedural vegetation/object presentation;
- nearby interactable proxies;
- local simulation activation;
- Overworld gateway/source-site presentation.

Persistent object state is keyed by semantic identity through persistence/WorldDelta authority.

Unloading an Overworld chunk cannot lose harvested objects, buildings or other durable changes.

The Overworld may use predominantly X/Z chunking/LOD where appropriate. It does not inherit Underworld 3D cell requirements merely because both domains belong to one save.

---

## 6. Underworld runtime ownership

`UnderworldRuntimeStreamer` owns the live representation/lifecycle of bounded Underworld 3D cells.

Conceptually:

```text
UnderworldRuntimeCellAddress(x, y, z)
```

A runtime cell may own:
- current live Node root;
- mesh/render resources;
- collision resources;
- currently relevant interactable/resource proxies;
- runtime references to canonical source identity;
- readiness/request-generation state.

It does **not** own:
- authoritative cave graph/topology;
- permanent generated identity;
- durable resource depletion;
- player construction persistence;
- SAVE state.

When a cell becomes irrelevant, its live representation may disappear completely and be reconstructed later.

---

## 7. Geometry regions, networks, cells and runtime cells are separate

Do not collapse these concepts:

```text
Macro region
    generation/ownership partition

Cave network
    stable topology component

Geometry cell
    bounded deterministic geometry partition

Runtime cell
    live representation / LOD / collision lifetime partition
```

They may share a grid initially where useful but architecture must not depend on permanent equivalence.

A network can span many runtime cells. A cell boundary never creates a new persistent tunnel/chamber identity by itself.

---

## 8. Runtime representation tiers — LOCKED

A location can progress through increasingly expensive representations:

```text
T0  no cached definition
T1  deterministic definition cached
T2  geometry/mesh data prepared
T3  render representation active
T4  collision active
T5  interactable/simulation active
T6  local audio/VFX active
```

These tiers may have different activation/release distances and policies.

Exact radii are profiling data, not architecture constants.

The important rule is:

> **A semantic object may exist without a full runtime representation.**

---

## 9. Bounded relevance — LOCKED

Runtime cost should primarily follow the **currently demanded/relevant set**, not total world history.

Forbidden scale pattern:

```text
every frame:
    for every cell ever visited:
        update/release/check something
```

Preferred patterns:
- explicit active/demand membership;
- bounded spatial indices;
- event-driven dirty sets;
- dormant-record eviction where stale-result safety permits;
- local queues;
- bounded cache pruning;
- sleeping/deactivation.

A player exploring for hundreds of hours must not turn every later frame into work over all previously visited cells.

This is a direct requirement of [`10_architecture/PERFORMANCE_AND_SCALABILITY.md`](10_architecture/PERFORMANCE_AND_SCALABILITY.md) and project scale authority #369.

---

## 10. Hysteresis and release margins — LOCKED DIRECTION

Activation and release thresholds should not be identical.

Example:

```text
activate render/collision at R
release at R + margin
```

This prevents boundary thrashing.

Exact distances and time-based retention are tuned by profiling.

---

## 11. Worker/main-thread boundary — LOCKED DIRECTION

Move computational pure-data work away from the main thread where safe.

Worker-safe direction:
- deterministic definition generation;
- topology stages;
- geometry/SDF calculations;
- vertex/index preparation;
- placement planning;
- fingerprints/validation;
- other engine-independent calculations.

Main-thread/runtime boundary:
- SceneTree mutation;
- live Node creation/removal;
- APIs Godot does not guarantee worker-safe;
- final render/collision publication where required by engine ownership.

### Publication budget
Completing work off-thread is insufficient if many results are committed to the SceneTree in one frame.

The runtime scheduler must support bounded publication, conceptually:

```text
worker results ready
      |
      v
commit/publication queue
      |
      v
fixed/controlled per-frame publication budget
```

Generation spikes must not simply become publication spikes.

---

## 12. In-flight request identity and stale-result rejection — LOCKED

Every asynchronous/requested result must carry enough identity to prove it still belongs to the current demand and deterministic source.

Conceptually:

```text
request key
world/domain identity
generator manifest identity
region/cell address
source/provenance identity
requested tier
request generation/token
```

When a result returns, apply it only if current ownership still accepts that exact request/source generation.

A stale result may be placed in a compatible disposable cache if useful, but it must never resurrect an unwanted runtime cell or overwrite newer authority.

Evicting a dormant record must not weaken stale-result rejection. Tombstone/request-generation semantics may be maintained separately from heavy runtime record residency where needed.

---

## 13. Priority scheduling — LOCKED DIRECTION

Prefer work that blocks immediate safe play.

Conceptual priority order inside a domain:
1. collision/readiness immediately required around Player;
2. visible/soon-visible geometry;
3. movement-direction prefetch;
4. nearby interactable/simulation needs;
5. farther render LOD;
6. speculative/background cache work.

Cross-domain transition temporarily raises destination-entry readiness above ordinary background work.

No large distant generation job may starve the bounded destination/collision work needed to restore control.

---

## 14. Cross-domain gateway transition — LOCKED

A gateway is a semantic transition between independent domain runtimes.

Conceptually:

```text
OVERWORLD
  gateway interaction
        |
        v
WorldTransitionService
  validate source + destination identity
  enter transition/loading presentation
  request/prepare destination
  wait for required local readiness
        |
        v
UNDERWORLD
  commit active domain
  place Player at destination-local anchor
  release Player control
  release source runtime when policy allows
```

Return uses the same contract in reverse or an explicitly paired/asymmetric gateway.

### Destination readiness
Player physics/process must not resume until the bounded collision/render support required at the destination is ready.

For Underworld Continue/transition positions near cell boundaries, readiness is based on the Player's required local collision-support envelope, not merely the cell containing the Player origin unless one-cell sufficiency is formally guaranteed.

### Failure
A failed destination preparation cannot leave two authoritative active Player states or a half-committed domain transition.

The source/previous stable route remains authoritative until transition commit, or the application must have an explicit safe rollback/failure state.

---

## 15. Loading screens are valid

This architecture does not require hidden streaming across a cave mouth.

Valid V1:

```text
interact
-> fade/loading
-> source runtime may release
-> destination prepares
-> destination commits
-> fade in
```

A later tunnel/elevator/animation may hide the exact same lifecycle.

Do not increase streaming/system coupling solely to remove a loading screen unless profiling/user experience proves the value.

A loading screen is also not permission for unbounded work. Total latency, memory and worst main-thread hitch remain performance contracts.

---

## 16. Domain-local audio / presentation

`active_domain` is the authoritative coarse semantic for Overworld versus Underworld presentation.

Audio/UI must not infer it from:
- global Y;
- render visibility;
- cell AABB membership;
- camera depth;
- arbitrary mesh presence.

Within a domain, local biome/room/cave semantics may refine ambience and presentation.

No inactive distant domain requires active audio players merely because its deterministic definitions exist.

---

## 17. Persistent deltas and bounded views — LOCKED

Runtime systems query bounded/read-only views of durable changes.

Conceptually:

```text
WorldDeltaStore.query(domain, bounds, identities/categories)
    -> WorldDeltaView
```

Examples:
- harvested trees;
- mined deposits;
- cleared rubble;
- terrain changes;
- player structures;
- special-location state.

Whole-save scans on every runtime cell update are not acceptable at scale.

---

## 18. Buildings and runtime streaming

Placed buildings remain semantic/persistent instances independent of render/collision batching.

Streaming may:
- instance repeated meshes;
- combine compatible static render clusters;
- use LOD/proxies;
- activate collision/interactables only when relevant;
- spatially shard large structures.

These optimizations must not erase logical piece identity needed for damage, deconstruction, support, upgrades, permissions or persistence.

Large player towns are expected scale cases, not unsupported accidents.

---

## 19. Memory-pressure behavior

Prefer evicting reconstructable expensive layers according to relevance:

```text
inactive runtime Nodes / expensive presentation
-> far geometry caches
-> far deterministic definition caches
```

Durable persistence state is never discarded merely as cache pressure relief.

Exact budgets belong to profiling/configuration.

---

## 20. Multiple observers / multiplayer direction

A domain streamer should be able to union demand from multiple observers later.

Conceptually:

```text
observer A demand
UNION
observer B demand
```

World domain is itself an interest-management boundary. Players in different domains do not automatically need each other's live domain-local AI/render/collision/audio state.

No multiplayer implementation is required by this document.

---

## 21. Runtime ownership invariants

Unless explicitly superseded:

1. Overworld and Underworld are independent runtime coordinate/residency domains.
2. The active domain is explicit semantic state, not inferred from geometry.
3. Cross-domain travel is owned by a transition/gateway lifecycle, not by either domain generator.
4. `UnderworldRuntimeStreamer` remains internal Underworld demand/lifecycle authority.
5. Runtime cost follows current relevance/residency, not total explored history.
6. Stale asynchronous results cannot resurrect released runtime state.
7. Worker completion order never changes deterministic world truth.
8. SceneTree publication is bounded independently of worker throughput.
9. Runtime cache eviction cannot delete durable deltas.
10. Domain unload cannot erase player buildings/resources/other persistent state.
11. Player control resumes only after the bounded destination collision support required for safety is ready.
12. A loading screen is valid presentation and does not change gateway/world identity.
13. Surface runtime does not require physical Underworld opening data merely to support an Underworld gateway.
14. Underworld depth/topology remains domain-local and does not require Overworld surface coordinates.
15. Presentation/batching/LOD may change freely without redefining semantic world identity.

---

## Intentionally adjustable decisions

Open/tunable:
- exact cell/chunk sizes;
- render/collision/simulation radii;
- hysteresis margins;
- cache memory budgets;
- number of worker tasks;
- per-frame publication budgets;
- gateway preloading strategy;
- whether source/destination temporarily overlap in memory;
- exact loading-screen presentation;
- exact server/multiplayer observer union;
- exact LOD/proxy technologies.

These values must come from real profiling and player experience rather than invented universal constants.