# Underworld Generation Pipeline

Status: **LOCKED architecture**

This is the authoritative deterministic generation contract for the **Underworld world domain** after [`ADR-001`](../00_project/ADR-001_TWO_WORLD_DOMAINS.md).

The Underworld generator produces deterministic topology, domain-local entry/exit sites, special hooks and bounded geometry descriptions. It does not own Overworld terrain and does not require a physical surface opening.

## Pipeline

```text
UnderworldGenerationContext
        |
        v
1. Macro Region Planning
        |
        v
2. Primary Topology
        |
        v
3. Underworld Entry/Exit Sites
        |
        v
4. Secondary Connectivity
        |
        v
5. Special-Location Hooks
        |
        v
6. Region Finalization
        |
        v
7. Geometry Description
        |
        v
8. Runtime Streaming / Realization
```

Cross-domain gateway linking is a separate world-level composition step.

## 1. Pure deterministic stages

A generation stage is conceptually:

```text
result = stage.generate(immutable_context, immutable_input)
```

Stages must not depend on:
- SceneTree/runtime Nodes;
- current Player position/progression;
- player buildings or save deltas;
- active Overworld runtime;
- wall-clock time;
- mutable shared RNG;
- worker completion order.

Generation must run headlessly and reproducibly.

## 2. Underworld generation context

Conceptual context:

```text
UnderworldGenerationContext
- root world identity/seed
- UNDERWORLD domain seed namespace
- generator manifest + stage revisions
- seed-schema/stable-address contracts
- stable address / StableId factories
- seed deriver
- Underworld depth/profile registry
- immutable Underworld generation settings
```

Overworld runtime/heightfield data is not a required context member.

## 3. Manifest/version isolation

The root world may reference both domain contracts, but Overworld and Underworld stage/domain revisions remain separately identifiable.

Changing Overworld presentation or a disjoint Overworld generator domain must not automatically reseed Underworld topology.

Manifest identity is compatibility/cache identity, not a universal RNG salt.

## 4. Scheduler ownership

The scheduler owns:
- stage dependency resolution;
- worker scheduling;
- pure-data caches;
- neighboring-data collection;
- prioritization/cancellation;
- runtime handoff.

Stages own deterministic transformations only.

A stage must not secretly recurse into neighboring regions or mutate global state.

## 5. Macro region planning

Input:

```text
MacroRegionRequest
- stable region address
- canonical Underworld-domain bounds
```

Output includes:
- region identity/bounds;
- profile/geology/topology tendencies;
- fixed network candidate slots;
- entry/exit-site candidate budget;
- special-location candidate budget;
- boundary/proximity metadata;
- canonical diagnostics/fingerprint.

Candidate slots exist before acceptance so rejected candidates never renumber later accepted identities.

## 6. Depth/profile grammar

Shallow/mid/deep are **Underworld-domain generation grammars**.

The old mandatory formula:

```text
overworld_surface_height(x,z) - underworld_y
```

is superseded.

A deterministic profile may instead use versioned combinations of:
- domain-local Underworld Y/depth;
- macro-region depth bands;
- topology/graph distance from entry sites;
- geology layers;
- explicit site/depth tags;
- deterministic local exceptions.

Conceptual result:

```text
DepthProfileSample
- shallow_weight
- mid_weight
- deep_weight
- domain-local depth/region metrics
- local deterministic bias
```

The exact formula is tunable/versioned data. It must be reproducible without loading Overworld terrain.

## 7. Primary topology

Primary topology creates stable:
- cave networks;
- nodes/chambers;
- primary edges/tunnels;
- boundary/proximity candidates.

Rules:
- stable candidate addresses before acceptance;
- rejection cannot compact identity;
- depth grammar participates while topology is created;
- no secondary-loop logic hidden here;
- no Overworld surface cutout generation;
- no runtime meshes/AI/resources.

Validate StableIds, ownership, finite positions/bounds, endpoints, connectivity rules, profile values and deterministic fingerprints before downstream use.

## 8. Underworld entry/exit sites

Stage 3 creates deterministic **Underworld-local** gateway destination/source sites.

Conceptually:

```text
UnderworldEntrySiteDefinition
- stable site identity
- owning region/network/node
- domain-local arrival transform
- safe-arrival/clearance metadata
- directionality/capability tags
- optional site family/depth tags
```

These sites do not contain an Overworld mesh/chunk position and do not imply physical surface continuity.

Sites may be shallow, mid or deep according to Underworld generation policy.

## 9. Gateway linking is separate

Cross-domain linking conceptually consumes:

```text
OverworldGatewaySiteDefinition
        +
UnderworldEntrySiteDefinition
        |
        v
GatewayLinkingService
        |
        v
WorldGatewayDefinition
```

Linking may preserve coarse regional relationships if useful, but it must never assume numeric coordinate equality or a global Y offset.

Gateway identity is semantic/stable and independent of runtime Node identity.

Paired return is resolved by gateway/site identity, not nearest-position guessing.

## 10. Surface generation independence

Supporting an Underworld gateway does **not** require the Overworld terrain generator to carve a hole matching Underworld geometry.

An Overworld source site may present as:
- modeled cave mouth;
- mine door/tunnel;
- crypt;
- fissure;
- portal;
- other local structure.

Its terrain/site placement belongs to the Overworld domain contract.

## 11. Secondary connectivity

Runs after primary topology and entry sites exist.

May add bounded:
- proximity connections;
- meaningful loops;
- cross-network edges;
- cross-region edges;
- vertical reconnections.

Candidate enumeration/worker order cannot decide results. Equal scores use canonical tie-breaking.

Cross-region edges have one canonical owner; non-owner regions may retain stable external references.

## 12. Special-location hooks

Reserve deterministic anchors/clearance for future:
- large deposits;
- structures/ruins;
- bosses;
- collapsed areas;
- special ecology/biomes;
- other content sites.

Topology owns the stable hook, not the gameplay system that later consumes it.

Player progression/building does not decide whether a deterministic hook exists.

## 13. Region finalization

Finalization canonically combines:
- MacroRegionPlan;
- PrimaryTopologyResult;
- EntrySiteGenerationResult;
- SecondaryConnectivityResult;
- SpecialLocationHookResult.

Output is immutable-by-convention `UndergroundRegionDefinition` data plus canonical indexes/metrics/fingerprint.

No runtime Nodes and no player save deltas are applied here.

## 14. Geometry descriptions

Geometry generation consumes finalized Underworld topology and emits bounded deterministic geometry-cell descriptions.

Conceptually:

```text
GeometryDescriptionRequest
- geometry cell address/bounds
- intersecting finalized topology fragments
- geometry/profile configuration
- source/provenance identities
```

Output may feed voxel/SDF/Marching-Cubes or later representations.

Topology identity is not redefined by mesh extraction, LOD or runtime batching.

## 15. Runtime boundary

Streaming/runtime owns:
- observer demand;
- cache/residency;
- generation/extraction execution;
- stale-result rejection;
- render/collision publication;
- simulation activation;
- release/re-entry.

See [`../STREAMING_OWNERSHIP.md`](../STREAMING_OWNERSHIP.md).

Generated sites/topology exist even when no runtime cell is loaded.

## 16. Base world versus deltas

Untouched geometry/topology/placements regenerate from pinned deterministic contracts.

Player-caused state composes later:
- mining/resource depletion;
- cleared rubble;
- terrain modifications where supported;
- player buildings;
- special-location state.

Runtime/geometry-cell indexes are never durable gameplay identity.

## 17. Deterministic randomness

Persistent random decisions use named seed domains/revisions + semantic stable addresses.

Forbidden:
- one mutable world RNG across unrelated stages;
- worker-order RNG consumption;
- accepted-array index identity;
- mesh iteration order changing topology.

Geometry randomness remains isolated from topology randomness.

## 18. Historical entrance compatibility

Existing accepted `EntranceDefinition` / physical-integration descriptor data may remain temporarily during migration.

Direction:
- preserve useful existing StableIds/fingerprints where they already represent semantic Underworld entry identity;
- stop treating physical surface-cutout fields as mandatory cross-domain truth;
- adapt old entrance/site records to explicit gateway destination/source semantics through versioned composition;
- never reinterpret old coordinates as automatically shared domain coordinates;
- keep historical tests where they still protect deterministic Underworld internals;
- final player-route acceptance moves to explicit gateway/domain-transition tests.

## 19. Validation

Representative deterministic campaigns must prove:
1. same root world + same pinned Underworld contract -> same Underworld fingerprints independent of active Overworld runtime;
2. entry-site identity is stable without a surface-height sample;
3. source/destination domain coordinates may differ without affecting gateway identity;
4. gateway linking is deterministic from semantic site data;
5. scheduling/reverse-order execution does not change output;
6. cross-region ownership remains canonical;
7. all positions/numerics remain finite;
8. generated definitions remain scene-independent.

## Locked invariants

1. Underworld generation is pure-data and domain-local.
2. Overworld terrain/runtime is not a required Underworld generator input.
3. Shallow/mid/deep do not require Overworld-relative physical depth.
4. Underworld entry/exit sites and cross-domain gateway links are separate semantic layers.
5. Source/destination coordinates are independent.
6. Stable candidate identity exists before acceptance.
7. Load/worker order cannot change world truth.
8. Cross-region connectors have one canonical owner.
9. Player progression/buildings/deltas do not decide deterministic topology existence.
10. Finalized definitions are immutable for the pinned contract.
11. Geometry/runtime representation cannot redefine semantic topology identity.
12. Surface mesh cutouts are not required merely to support an Underworld gateway.
13. Existing accepted Underworld deterministic evidence remains valid unless a deliberate generator revision changes it.

## Intentionally open

- exact domain-local depth formula;
- entry-site frequency/distribution;
- gateway-linking policy;
- macro-region/cell sizes;
- topology algorithms;
- geometry extraction representation;
- how strongly gateways preserve coarse regional relationships;
- future player-created gateway mechanics.
