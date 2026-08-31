# Underworld Cross-System Ownership and Dependency Map

Status: **architecture routing index; linked contracts remain authoritative**

This map tells workers which subsystem owns a concern and which identities may cross a boundary. It does not replace the linked architecture documents.

Current world-domain authority:
- [`../00_project/ADR-001_TWO_WORLD_DOMAINS.md`](../00_project/ADR-001_TWO_WORLD_DOMAINS.md)
- [`../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md)

## Dependency direction

```text
core identity / deterministic primitives
        |
        +-> Overworld deterministic generation
        |
        +-> Underworld deterministic generation
        |       -> geometry descriptions
        |       -> Underworld runtime streaming
        |
        +-> gateway/site definitions
                -> WorldDomainCoordinator / TransitionService

content definitions -> gameplay/simulation -> runtime presentation

persistence / WorldDeltaStore
        -> restoration/composition of domain-local runtime state

presentation/UI/audio
        <- read-only semantic gameplay/domain state

tools/tests
        -> may inspect public contracts
production runtime
        -X-> must not depend on tools/tests
```

Generated base truth is not rewritten by player deltas. Runtime realization is not durable identity.

---

## Ownership matrix

| Layer | Owns | May consume | Must not own | Authority |
| --- | --- | --- | --- | --- |
| **Core identity/determinism** | `WorldId`, StableAddress/StableId primitives, seed derivation, canonical hashing/version primitives | none/upstream platform primitives | gameplay/runtime/presentation state | `STABLE_PROCEDURAL_IDS.md`, `DETERMINISTIC_SEED_DOMAINS.md` |
| **Overworld deterministic generation** | reproducible surface terrain/biomes/placements/source gateway sites | core deterministic primitives, immutable Overworld config | Underworld topology/runtime, player deltas | world/content contracts; roadmap WORLD-OW lane |
| **Underworld deterministic generation** | regions/networks/nodes/edges, Underworld entry/exit sites, hooks, deterministic geometry descriptions/provenance | core deterministic primitives, immutable Underworld config, explicit neighbor stage views | Overworld terrain/runtime, gateway transition lifecycle, player deltas | [`../20_world/UNDERWORLD_GENERATION_PIPELINE.md`](../20_world/UNDERWORLD_GENERATION_PIPELINE.md) |
| **Gateway linking / world-domain coordination** | deterministic source->destination gateway relationship, active-domain transition lifecycle, fail-closed commit/readiness handoff | semantic source/destination sites, domain readiness APIs, persistence location state | terrain/topology algorithms, SAVE codec, Player gameplay rules, UI rendering | [`../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md), [`../STREAMING_OWNERSHIP.md`](../STREAMING_OWNERSHIP.md) |
| **Runtime streaming/realization** | which domain-local representations are live; cell/chunk lifetime; request priority; render/collision realization | deterministic definitions/geometry, bounded delta views, domain-local observer state | generator decisions, durable state, cross-domain gateway identity | [`../STREAMING_OWNERSHIP.md`](../STREAMING_OWNERSHIP.md) |
| **Persistence / durable deltas** | save envelope/schema, active domain + domain-local Player transform, generator compatibility, durable world changes, migration/quarantine | stable generated/content/build identities and generator contracts | runtime Node/cell lifetime, guessed coordinate identity | [`../PERSISTENCE_AND_VERSIONING.md`](../PERSISTENCE_AND_VERSIONING.md), `MAP_DATA_SERIALIZATION_CONTRACT.md` |
| **Authored content** | semantic item/creature/attack/build-piece/profile definitions and typed references | content schemas and approved semantic definitions | runtime instance identity, deterministic generated-instance identity | `CONTENT_ARCHITECTURE.md`, `CONTENT_REGISTRY.md` |
| **Gameplay/simulation** | Player/combat/inventory/equipment/harvest/crafting/building/resource/creature rules and transitions | semantic content, domain/runtime query interfaces, persistence operations where allowed | procedural algorithms, persistence storage internals, presentation asset identity | `DEPENDENCY_RULES.md`, gameplay docs |
| **Presentation/UI/audio/VFX** | replaceable visual/audio/UI rendering and interaction presentation | observable semantic gameplay state, `active_domain`, presentation metadata/roles | gameplay truth, generator truth, persistence identity, gateway commit authority | presentation/UI contracts, `PRESENTATION_BOUNDARY.md` |
| **Tools/validation** | inspectors, validators, fixtures, reproducibility/profiling harnesses, CI | public/pure contracts | production gameplay/world authority | `60_validation/**`, tooling docs |

---

## Critical identity distinctions

### Root world identity
`WorldId` scopes one save/world and may contain both domains.

It does **not** imply that the domains share coordinate space.

### World domain
`OVERWORLD` / `UNDERWORLD` qualifies domain-local spatial state.

A durable Player transform is meaningless without its owning domain.

### Procedural StableId
Answers **which deterministic generated candidate/object/site is this?**

Never replace with:
- runtime Node instance ID;
- array position;
- cell index;
- file path;
- semantic content ID.

### Semantic content ID
Answers **what authored game concept is this?**

One generated resource can have both:

```text
content_id = item.resource.iron_chunk / resource definition
stable_id  = deterministic generated-instance/site identity
```

Those identities must remain separate.

### Gateway identity
Answers **which semantic cross-domain connection is this?**

Conceptually references:
- source domain/site identity;
- destination domain/site identity;
- pair/directionality policy.

It is not `source_position -> destination_position` coordinate conversion.

### Geometry/runtime-cell address
Identifies a bounded work/lifetime partition. It is not the persistent identity of the cave network/tunnel/object inside it.

### Build instance identity
Player-created structures use their own persistent identity family + semantic piece-definition ID + domain-local transform.

They are not procedural StableAddresses and not runtime render-batch indexes.

### Generator provenance
Binds deterministic output to exact world/domain/manifest/stage/source fingerprints. Runtime load order does not mint substitute provenance.

### Persistent delta
Owned by persistence/WorldDelta. Runtime cells may apply/query it but unload cannot delete it.

### Asset/scene path
Answers where a replaceable implementation asset currently lives. Never use it as durable gameplay/world identity.

---

## Easy ownership mistakes

### Wrong: Underworld generator chooses Overworld terrain opening

Correct:

```text
Overworld generator -> source gateway site
Underworld generator -> destination entry site
Gateway linker       -> semantic connection
```

### Wrong: streamer decides active world by checking Player Y

Correct:

```text
WorldDomainCoordinator owns active_domain
Domain streamer consumes only its domain-local observer/demand
```

### Wrong: UI decides the transition is complete because cave mesh is visible

Correct:

```text
TransitionService commits active_domain after destination readiness
UI/audio observe committed domain semantic
```

### Wrong: Save stores one global position and guesses which domain it belongs to

Correct:

```text
active_domain + domain_local_transform
```

### Wrong: runtime cell owns mined/harvested/built persistence

Correct:

```text
WorldDelta / build persistence owns durable semantic state
cell loads -> query/apply
cell unloads -> durable state remains
```

### Wrong: render batching merges building identity

Correct:

```text
many logical BuildInstances
-> one/more optimized render/collision representations
```

Logical pieces remain independently addressable where gameplay needs them.

---

## Where should a new feature live?

Ask in order:

1. **Does it decide reproducible Overworld truth?** -> Overworld deterministic generation.
2. **Does it decide reproducible Underworld topology/sites/geometry?** -> Underworld generation.
3. **Does it map a source gateway to another domain or commit active-domain travel?** -> gateway/world-domain coordination.
4. **Does it decide which local representation is resident/rendered/collidable now?** -> domain runtime streamer.
5. **Must it survive unload/restart because world/player state changed?** -> persistence/WorldDelta/build state.
6. **Is it a reusable authored concept?** -> content definition architecture.
7. **Is it a gameplay rule/state transition?** -> owning gameplay subsystem.
8. **Is it replaceable visuals/audio/UI?** -> presentation.
9. **Is it only inspection/testing/profiling/migration tooling?** -> tools/tests.
10. **Would the proposed change require another layer to own state it currently only references?** -> stop; this is an architecture decision/review first.

---

## Cross-domain runtime sequence

```text
Overworld gateway interaction
        |
        v
Gateway / WorldDomainCoordinator
  validate source/destination
        |
        v
request Underworld readiness
        |
        v
UnderworldRuntimeStreamer
  definition/geometry/render/collision
        |
        v
bounded safety-ready signal
        |
        v
WorldDomainCoordinator commits UNDERWORLD
        |
        v
Player physics/control resumes
```

Neither UI nor the Underworld streamer commits the cross-domain state by itself.

---

## Performance ownership

Performance does not create a separate gameplay authority.

The scheduler/streamers own bounded runtime work. Profiling/QA prove:
- work follows active/relevant populations;
- stale results cannot resurrect state;
- worker throughput cannot create unbounded main-thread publication bursts;
- historical exploration/build counts do not become per-frame scan counts;
- cross-domain loading waits only for the bounded destination safety set.

See `PERFORMANCE_AND_SCALABILITY.md` and project scale card #369.

---

## Authoritative reference set

- [`../00_project/ADR-001_TWO_WORLD_DOMAINS.md`](../00_project/ADR-001_TWO_WORLD_DOMAINS.md)
- [`../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md)
- [`../20_world/UNDERWORLD_GENERATION_PIPELINE.md`](../20_world/UNDERWORLD_GENERATION_PIPELINE.md)
- [`../STREAMING_OWNERSHIP.md`](../STREAMING_OWNERSHIP.md)
- [`../PERSISTENCE_AND_VERSIONING.md`](../PERSISTENCE_AND_VERSIONING.md)
- [`../STABLE_PROCEDURAL_IDS.md`](../STABLE_PROCEDURAL_IDS.md)
- [`../DETERMINISTIC_SEED_DOMAINS.md`](../DETERMINISTIC_SEED_DOMAINS.md)
- [`CONTENT_ARCHITECTURE.md`](CONTENT_ARCHITECTURE.md)
- [`CONTENT_REGISTRY.md`](CONTENT_REGISTRY.md)
- [`DEPENDENCY_RULES.md`](DEPENDENCY_RULES.md)
- [`REPOSITORY_STRUCTURE.md`](REPOSITORY_STRUCTURE.md)

This file is a routing index. If it conflicts with an owning contract, fix this map rather than treating it as a competing source of truth.