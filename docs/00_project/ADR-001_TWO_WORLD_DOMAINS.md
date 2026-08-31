# ADR-001 — Separate Overworld and Underworld Domains

Date: **2026-08-31**  
Status: **ACTIVE — LOCKED ARCHITECTURE**

## Decision

The **Overworld** and **Underworld** are two independent procedural world domains connected by explicit deterministic gateways/transitions.

They belong to one save/world identity but do **not** require:
- one shared runtime coordinate system;
- literal vertical/geometric continuity;
- matching X/Y/Z positions;
- a physical surface opening joined to Underworld geometry;
- simultaneous runtime residency/rendering;
- surface-relative Underworld depth;
- a hidden or seamless loading boundary.

A direct fade/loading screen is a valid first implementation.

Within each domain, deterministic generation, StableIds, WorldDelta composition, streaming and runtime readiness remain authoritative according to that domain's own contracts.

## Rationale

The earlier continuous-world architecture spent substantial complexity on a seam the player does not need to perceive directly. It also coupled otherwise independent systems:
- Overworld terrain generation to Underworld entrances;
- surface collision to cave collision;
- surface depth to Underworld topology;
- streaming residency across both spaces;
- cave excavation depth to a global Y relationship;
- Continue/startup safety to a physical cross-domain seam.

The separate-domain model preserves the intended experience — the player finds an entrance and enters the Underworld — while freeing engineering complexity for the systems that materially affect play:
- richer Underworld generation and verticality;
- scalable streaming;
- better performance isolation;
- safer persistence/Continue reconstruction;
- building scale;
- content depth and presentation quality.

The Minecraft Overworld/Nether relationship is a useful conceptual analogy: two deterministic spaces can belong to one world and be meaningfully connected without being the same geometry.

## Supersedes

This ADR explicitly supersedes the following **normative portions** of the 2026-08-27 decision history and associated architecture documents. Historical text remains preserved as project history.

### `docs/DECISION_LOG.md` — 2026-08-27 Architecture/design checkpoint
Superseded clause:
- `World identity — LOCKED`: **"Surface and Underworld share one real 3D world-coordinate relationship."**

Still active from that section:
- surface remains comparatively familiar/readable;
- Underworld remains substantially larger in meaningful exploration space;
- generated content remains independent of later progression/build choices;
- geography can gain new meaning through discovered gateway relationships.

### `docs/DECISION_LOG.md` — Generation pipeline interface checkpoint
Superseded requirements:
- entrance generation must physically create surface-to-topology openings;
- surface geometry must consume Underworld opening descriptors;
- Underworld depth must be evaluated from deterministic surface height.

Replacement:
- Underworld generation owns deterministic internal entry/exit sites;
- gateway linking maps a source-domain gateway to a destination-domain entry site;
- Underworld shallow/mid/deep grammar uses Underworld-domain metrics/configuration and does not require Overworld surface coordinates.

### `docs/DECISION_LOG.md` — Streaming ownership checkpoint
Superseded requirements:
- one continuous runtime world;
- no hard `SURFACE` / `UNDERGROUND` domain state;
- surface and Underworld runtime must overlap around an entrance;
- entrance prefetch is required to make one physical traversal seam continuous.

Replacement:
- one `WorldDomainCoordinator`/equivalent owns active-domain transition lifecycle;
- Overworld and Underworld have independent streamer/residency budgets;
- destination readiness is required before Player control resumes;
- source and destination may overlap temporarily as an implementation optimization, but overlap is not required by architecture.

### `docs/STREAMING_OWNERSHIP.md`
Superseded:
- one-global-coordinate-space runtime assumptions;
- physical entrance overlap as a locked invariant;
- surface entrance cutout/integration query as a required cross-streamer dependency.

### `docs/GENERATION_PIPELINE_INTERFACES.md`
Superseded:
- physical `SurfaceEntranceIntegrationDescriptor` as the required domain-link object;
- surface-relative depth as a required Underworld generation input.

## Preserved architecture

This decision does **not** discard the accepted Underworld work already completed.

Still preserved:
- deterministic Underworld region/network/node/edge identity;
- named seed domains and generator manifests;
- stable topology and canonical fingerprints;
- shallow/mid/deep Underworld generation grammar;
- secondary/cross-region connectivity;
- special-location hooks;
- geometry-cell partitioning;
- worker/main-thread separation;
- `UnderworldRuntimeStreamer` lifecycle and bounded observer-demand architecture;
- stale-result rejection;
- collision-readiness requirements;
- deterministic regeneration + durable player/world deltas.

M2 remains valid historical evidence that these components could generate, stream and traverse cave geometry. The later domain-boundary decision changes how the player reaches that runtime; it does not retroactively erase the accepted internal contracts.

## Gateway contract

Cross-domain linkage is explicit semantic data, conceptually:

```text
WorldGatewayDefinition
- stable gateway identity
- source_domain
- source_anchor / source site identity
- destination_domain
- destination_anchor / entry-site identity
- directionality / pair identity
- transition policy
```

A gateway is not a coordinate conversion.

Two nearby Overworld gateways may intentionally map to nearby Underworld regions if future world design wants that relationship, but such mapping is semantic/deterministic policy rather than shared-space identity.

## Runtime contract

Conceptually:

```text
OverworldRuntime
      |
      | gateway request
      v
WorldDomainCoordinator / TransitionService
      |
      | load / prepare destination
      v
UnderworldRuntime
```

The transition owner must ensure:
1. the source transition request is valid;
2. destination identity is resolved deterministically;
3. destination runtime reaches required render/collision readiness;
4. Player control/physics does not resume in an unsafe/unready destination;
5. source runtime can then release according to residency policy;
6. failure is fail-closed and cannot commit a half-transitioned authoritative state.

## Persistence contract

A durable Player location is a **domain-qualified transform**, conceptually:

```text
PlayerWorldLocation
- active_domain
- domain_local_transform
```

Saving in the Underworld does not require an equivalent Overworld coordinate.

Continue reconstructs the saved active domain directly, regenerates required deterministic truth, applies that domain's deltas and releases Player control only after safe local readiness.

Gateway/paired-return identity is persisted only when gameplay semantics require it; it must not be reconstructed by guessing coordinates.

## Audio / UI semantic consequence

`active_domain` is the authoritative coarse semantic for "surface versus Underworld" presentation.

Audio/UI must not infer cross-domain state from:
- camera height;
- mesh visibility;
- a cave-cell AABB;
- global Y;
- raw render-node presence.

Within the Underworld, local cave/biome/room semantics may still refine ambience and presentation.

## Digging consequence

Overworld terrain modification is domain-local.

No amount of ordinary Overworld digging implicitly intersects the Underworld unless a future gameplay mechanic explicitly creates/resolves a cross-domain gateway.

This lets Overworld excavation depth be designed for Overworld gameplay and lets Underworld vertical scale be designed independently.

## Multiplayer consequence

World domain becomes a first-class interest-management boundary.

Players in separate domains do not inherently need each other's domain-local render/collision/AI/audio/streaming state. Server authority and eventual network replication rules remain separate future contracts.

## Transition presentation

V1 may be simply:

```text
interact with entrance
-> fade / loading screen
-> prepare destination
-> activate destination
-> restore control
```

Later presentation may hide the same semantic handoff with a tunnel, elevator, squeeze passage, door, fog, animation or other device without changing world identity.

## Consequences / trade-offs

### Benefits
- removes physical seam/cutout/collision-composition complexity;
- removes mandatory cross-generator coordinate coupling;
- improves performance isolation and memory control;
- simplifies deep-domain Save/Continue semantics;
- allows much larger/more vertical Underworld spaces;
- permits independent generator evolution;
- allows transition UX to evolve without rewriting world truth.

### Costs
- cross-domain travel becomes an explicit lifecycle that must be robustly saved/tested;
- gateway pairing/destination identity becomes durable semantic data;
- systems that previously inferred underground state from coordinates must consume active-domain state instead;
- accepted continuous-entrance tests become historical/internal coverage rather than final player-route authority.

## Validation requirements

Architecture/implementation changes derived from this ADR must prove:
- deterministic gateway mapping;
- no implicit shared-coordinate dependency;
- safe destination readiness;
- paired return correctness where applicable;
- domain-local Save/Continue from both domains;
- failure cannot leave two authoritative active Player states;
- Underworld internal deterministic fingerprints remain stable unless separately revised;
- surface generation no longer requires physical Underworld opening geometry merely to support a gateway.

## Affected authoritative contracts

- `docs/20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`
- `docs/STREAMING_OWNERSHIP.md`
- `docs/GENERATION_PIPELINE_INTERFACES.md`
- `docs/PERSISTENCE_AND_VERSIONING.md`
- `docs/00_project/DECISION_INDEX.md`
- `docs/GAME_PILLARS.md`
- `docs/30_gameplay/BUILDING_SYSTEM.md`
- `docs/10_architecture/PERFORMANCE_AND_SCALABILITY.md`

Supersedes: specified 2026-08-27 one-world/physical-entrance clauses above.  
Superseded by: **None**.