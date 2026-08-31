# Underworld — Technical Architecture

This document defines the architecture that should exist before substantial procedural-world generation and composition code is expanded. Exact class names may change; the separation of responsibilities should not change casually.

The world-domain relationship is governed by `20_world/WORLD_DOMAINS_AND_TRANSITIONS.md` and ADR-001. This document uses that two-domain model.

## 1. Core separation — LOCKED

The project must separate these concepts:

1. **Root world identity** — one durable world/save identity and deterministic root seed/manifest scope.
2. **Domain definition** — deterministic data describing what exists inside one procedural domain.
3. **Topology** — graph relationships between Underworld regions, networks, chambers, tunnels and domain-local entry sites.
4. **Geometry description** — shapes/paths/volumes derived from accepted topology or other domain definition data.
5. **Runtime representation** — Godot nodes, meshes, collision, AI and audio currently instantiated.
6. **Persistent deltas** — player/world changes relative to deterministic base truth.
7. **World-domain/gateway state** — explicit active domain plus deterministic source-gateway/destination-anchor mapping and transition lifecycle.

Do not collapse these into one generator that creates scene nodes directly. Do not make either procedural generator own cross-domain transition state.

## 2. Domain-local coordinate systems — LOCKED

`OVERWORLD` and `UNDERWORLD` are independent procedural coordinate spaces.

Generated positions/bounds are interpreted together with their owning domain:

```text
DomainPosition = domain + local_transform
```

An Underworld position does not need to map losslessly to an Overworld X/Y/Z value, and Underworld depth is not defined as `surface_height - shared_world_y`.

Within the Underworld, topology, geometry, runtime cells and physics still use a coherent 3D coordinate system. Different domains may use different spatial indexing, scale, origin and streaming policy.

Cross-domain travel resolves through deterministic gateway/source/destination identity rather than coordinate conversion.

## 3. Deterministic staged generation — LOCKED

Persistent generation uses `DETERMINISTIC_SEED_DOMAINS.md`.

Randomness is derived conceptually from:

```text
root world seed
+ seed-schema version
+ immutable named domain ID
+ explicit domain revision
+ semantic StableAddress
+ optional semantic subkey
```

rather than from a mutable chain such as `world RNG -> region RNG -> network RNG -> node RNG`.

Requirements:

- generation order must not change results;
- worker scheduling must not change results;
- loading chunks/regions in a different order must not change results;
- accepted/rejected candidate count must not shift sibling randomness;
- unrelated generator changes should be isolated by independent seed domains;
- topology and detailed geometry randomness are separate compatibility domains;
- generated IDs must not depend on RNG state or accepted-array ordering;
- cross-region candidates use canonical ownership/addressing before seed derivation;
- persistent generation uses a project-owned/frozen deterministic RNG/value contract with hard-coded compatibility vectors before production saves depend on it;
- adding explicit world domains must not repurpose an already-persisted seed-domain identifier to mean something different.

The generator manifest is a compatibility contract and is **not** automatically mixed into every seed. Local domain revisions allow one generation subsystem to change without automatically reshuffling unrelated systems.

## 4. Root world and domain-definition model — DIRECTIONAL

The architecture should support data similar to:

### `WorldDefinition`

- root world seed;
- world ID;
- save/world schema version;
- generator manifest reference;
- seed-schema version;
- addresses/references for Overworld and Underworld definition domains;
- no requirement to materialize either complete domain eagerly.

### `UnderworldDefinitionIndex`

- owning root `WorldId` / manifest identity;
- Underworld-domain generation configuration;
- macro-region addressing configuration;
- optional generated-region cache/index metadata.

### `UndergroundRegionDefinition`

- stable region ID;
- semantic stable address;
- **Underworld-local** bounds/anchor;
- dominant depth profile(s);
- network references;
- domain-local entry-site references;
- high-level special-location references.

### `CaveNetworkDefinition`

- stable network ID;
- graph node IDs;
- graph edge IDs;
- entry-site IDs;
- topology metrics useful for validation/connectivity passes.

### `CaveNodeDefinition`

Represents an abstract chamber/junction/major volume before final mesh construction.

Potential fields:

- stable ID;
- Underworld-local position;
- approximate bounds/radius;
- depth/profile blend;
- semantic type/tags;
- optional cached deterministic local values derived from its stable address/domains.

### `CaveEdgeDefinition`

Represents a connection before detailed tunnel geometry.

Potential fields:

- stable ID;
- endpoints;
- connection class: primary, proximity connection, deliberate topology loop, vertical transition, entry path, etc.;
- path/control information;
- width/verticality tendencies;
- optional cached deterministic local values derived from its stable address/domains.

### `UnderworldEntrySiteDefinition`

A deterministic **Underworld-domain** arrival/exit/topology attachment candidate.

Potential fields:

- stable ID / stable address;
- owning region/network/node;
- Underworld-local anchor/transform;
- entry/arrival profile;
- clearance/geometry requirements local to the Underworld;
- optional semantic tags used by gateway matching/policy.

It does **not** own an Overworld position or require a physical surface opening. A `WorldGatewayDefinition` outside the Underworld generator maps a source gateway in one domain to a destination entry/arrival identity in another domain.

The current codebase may retain historical `EntranceDefinition` names/types for generator compatibility. During migration, treat those as legacy/internal Underworld entry-site data unless an owning contract explicitly says otherwise; do not continue their old shared-coordinate meaning as new architecture.

## 5. Depth profiles — LOCKED ARCHITECTURAL INTERFACE

Shallow, mid and deep are Underworld-local generation profiles rather than scattered shared-world-Y conditionals.

A profile should eventually control distributions such as:

- chamber size/shape;
- tunnel width/length;
- verticality;
- branch/dead-end frequency;
- network size;
- loop/connectivity tendency;
- water/geology tendencies;
- entry-site tendency;
- structure/resource/ecology hooks.

Profiles may blend spatially inside the Underworld domain. A cave may transition continuously across local depth grammar.

A deterministic Overworld reference may only become an input for a specific future design feature through an explicit gateway/world-coordination contract; it is not a required depth formula.

Random variation used by profiles must come from stable-address seed domains rather than shared RNG state.

## 6. Secondary connectivity pass — LOCKED

Primary cave topology is generated first.

A separate analysis pass may propose and score additional connections between existing graph components/branches.

This system must be able to:

- identify close Underworld-local physical approaches;
- identify larger useful loop opportunities;
- reject redundant connections;
- cap connectivity to avoid spaghetti graphs;
- vary behavior by depth/region profile;
- record the resulting edge as a normal stable world-definition object.

Candidate enumeration, random scoring terms and tie resolution must be deterministic and canonical. Cross-region candidates have one owner/address before seed derivation.

Do not bake the ~10% connectivity philosophy into random tunnel generation alone.

## 7. Geometry generation — LOCKED DIRECTION

Initial Underworld geometry is chamber/tunnel based, not unrestricted destructible voxel terrain.

Geometry generation consumes accepted Underworld graph definitions and produces streamable **domain-local** geometry descriptions/runtime meshes.

Structural cave geometry and locally modifiable/excavatable material must be distinguishable at the data level.

Geometry randomness is separated from topology randomness so future remeshing/tunnel-shape changes do not automatically reshuffle graph connectivity.

An entry site may have local cave-mouth/shaft/arrival geometry. Cross-domain mesh continuity is never a geometry-generation invariant.

## 8. Runtime streaming tiers — LOCKED

Each procedural domain owns its own runtime demand and representation tiers. Underworld runtime systems should support progressively more expensive representations:

1. deterministic definition exists only as data/address;
2. geometry description available/cached;
3. rendered mesh loaded;
4. collision loaded nearby;
5. creatures/interactables actively simulated nearby;
6. local audio active only when relevant.

Exact thresholds are **OPEN** and should be measured.

No design should require all underground networks to exist as live Godot nodes simultaneously. An inactive domain must not remain fully streamed merely because the other domain is active.

During a gateway transition, bounded destination preparation may run while source state is retained for rollback; `STREAMING_OWNERSHIP.md` owns the runtime lifetime rules.

## 9. Stable procedural identities — LOCKED

Persistent procedural objects use `STABLE_PROCEDURAL_IDS.md`.

Identity derives from stable candidate/generation addresses, not accepted-array indexes, runtime nodes, runtime positions or RNG-call order.

Conceptual hierarchy inside the Underworld:

```text
underworld / region / network / node-or-edge / local-object-key
```

A generator density change must not silently rename unrelated persistent objects.

The same identity discipline applies to Overworld procedural objects. Existing prototype index-based IDs must be migrated before incompatible generator tuning makes the legacy mapping unsafe.

Gateway identity is a separate cross-domain semantic identity and must not be fabricated from coordinate conversion or runtime Node identity.

## 10. Persistence model — LOCKED

Untouched procedural world data is regenerated from the root world identity plus compatible domain generation contracts.

Save data stores durable state such as:

- `active_domain`;
- Player domain-local transform/state;
- removed/harvested stable object IDs;
- inventory/progression;
- player-built structures;
- modifiable-terrain deltas;
- cleared collapses/changed structures;
- boss/special-location state;
- gateway/transition state only where durability actually requires it;
- other explicit player/world-state changes.

Do not save complete untouched cave networks/chunks merely because they were visited.

Save migrations must be versioned and testable. Legacy saves without explicit domain state must follow an explicit compatibility/migration policy; domain must not be inferred from Y sign or nearest entrance.

`PERSISTENCE_AND_VERSIONING.md` owns the detailed compatibility contract.

## 11. World-domain / gateway ownership — LOCKED

Neither `OverworldGenerator` nor `UnderworldGenerator` owns cross-domain travel.

Conceptually:

```text
source domain runtime
    -> WorldGatewayDefinition / GatewayService
    -> WorldTransitionService
    -> destination domain preparation/readiness
    -> atomic active-domain commit
```

The gateway layer owns:

- source gateway identity;
- destination domain;
- destination entry/arrival identity;
- paired/asymmetric return policy where applicable;
- transition lifecycle and failure handling.

The destination generator/streamer only answers domain-local definition/readiness requests. It does not know the source domain's coordinates.

## 12. Threading boundary — LOCKED DIRECTION

Pure deterministic generation/data work may run on worker threads.

Godot scene-tree mutation, node creation and physics-server-facing scene setup must remain on the appropriate main-thread boundary unless Godot explicitly guarantees otherwise.

No shared mutable generation RNG crosses worker boundaries. Each generation task derives local randomness from stable addresses/domains.

Transition scheduling may request worker-safe destination generation, but active-domain commit and scene/runtime ownership changes remain explicit runtime lifecycle operations.

## 13. Validation hooks — LOCKED

Every generated graph/data object should expose enough information for headless validation without rendering.

A failing generation test must be reproducible from at least:

- root world seed / `WorldId`;
- owning world domain;
- seed-schema version;
- generator manifest;
- relevant seed domain/revision where applicable;
- region/network/object stable ID/address;
- validation failure reason.

Cross-domain tests additionally report source gateway identity, destination domain and destination anchor identity without assuming coordinate parity.

Canonical generation fingerprints and fixed seed/RNG test vectors are part of the compatibility suite.

Architecture is incomplete if correctness can only be checked by manually walking through the rendered world.

## 14. Supersession note

Earlier revisions of this document locked one shared global surface/Underworld coordinate system and gave `EntranceDefinition` a physical surface position. Those clauses are superseded by ADR-001 and the 2026-08-31 two-domain decision.

Still-valid portions—pure deterministic data, stable identity, staged generation, topology/geometry separation, runtime tiers, worker/main-thread boundaries and delta persistence—remain governing architecture.