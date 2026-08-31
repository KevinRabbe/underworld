# Underworld — World Architecture

Status: **LOCKED high-level world architecture**

Current cross-domain authority:
- [`00_project/ADR-001_TWO_WORLD_DOMAINS.md`](00_project/ADR-001_TWO_WORLD_DOMAINS.md)
- [`20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](20_world/WORLD_DOMAINS_AND_TRANSITIONS.md)
- [`20_world/UNDERWORLD_GENERATION_PIPELINE.md`](20_world/UNDERWORLD_GENERATION_PIPELINE.md)

## 1. Two procedural world domains — LOCKED

The game contains one root seeded world with two first-class procedural domains:

```text
OVERWORLD
UNDERWORLD
```

They are logically connected by deterministic gateways but geometrically independent.

They do not require:
- one shared X/Y/Z coordinate system;
- literal vertical continuity;
- identical spatial scale;
- a physical surface hole joined to an Underworld mesh;
- simultaneous rendering/residency;
- Overworld digging to reach the Underworld by depth.

This supersedes the old one-global-world-coordinate assumption.

## 2. Relative world roles — LOCKED

The Overworld is comparatively familiar/readable and supports:
- long-term settlement;
- surface exploration;
- resources/combat;
- world familiarity and landmarks;
- gateway discovery.

The Underworld supplies substantially more meaningful long-term exploration space through:
- verticality;
- overlapping networks;
- branching topology;
- large chambers/shafts;
- deeper regional structure;
- unusual resources/structures/ecology.

Exact kilometer dimensions and area ratios remain open until traversal/content-density tests justify them.

## 3. Gateway relationship — LOCKED

Cross-domain travel is semantic, not coordinate conversion.

Conceptually:

```text
OverworldGatewaySite
      |
      v
WorldGatewayDefinition
      |
      v
UnderworldEntrySite
```

A paired gateway may return to the same logical source entrance. Other future gateway types may be one-way, asymmetric or destination-changing.

Direct fade/loading is valid V1 presentation.

A modeled cave mouth, mine door, crypt or fissure may make the source look physically plausible without exposing actual Underworld geometry.

## 4. Underworld macro topology — LOCKED

The Underworld is hierarchical procedural topology, not uniform cave noise.

Current conceptual pipeline:
1. root world/domain generation identity;
2. Underworld macro regions;
3. regional cave/network graphs;
4. chambers/tunnels/vertical transitions;
5. shallow/mid/deep grammar blending;
6. Underworld-local entry/exit sites;
7. secondary topology/connectivity analysis;
8. special locations/resources/ecology hooks;
9. bounded geometry descriptions;
10. runtime streaming/realization.

Gateway linking happens outside the Underworld topology generator.

Topology and geometry remain separate concepts.

## 5. Underworld entry/exit sites — LOCKED

The Underworld generator may expose deterministic local sites suitable for gateway arrival/exit.

A site owns domain-local topology/arrival information, not an Overworld surface coordinate.

The old design tendency of roughly 1–3 useful entrances for suitable regional systems may still inform site/gateway availability, but it is not a universal hard count.

Potential arrival/site forms include:
- gradual cave chamber;
- steep/vertical descent endpoint;
- constructed mine/tunnel endpoint;
- crevice/fissure endpoint;
- other semantic site families.

An apparently safe source gateway may still lead to a dangerous/deep destination if deterministic world design permits it.

## 6. Three Underworld depth grammars — LOCKED

Shallow/mid/deep are continuous Underworld-domain tendencies, not mandatory physical meters beneath Overworld terrain.

### Shallow
Biases may include:
- smaller/local networks;
- tighter chambers/passages;
- more roots/soil/groundwater-like presentation hooks where semantically appropriate;
- more accessible entry-site possibilities;
- lower deliberate long-range connectivity;
- more practical settlement pockets.

### Mid
Biases may include:
- larger chambers/longer tunnels;
- stronger verticality;
- water systems;
- more inter-network relationships/loops;
- larger resource zones and structures.

### Deep
Biases may include:
- very large spaces/extreme verticality;
- stranger geology/ecology;
- rare large-scale structures/boss sites/resources;
- long branches/dangerous isolated pockets;
- settlement possible but logistically difficult.

Local exceptions are expected. Profiles describe distributions, not templates.

Exact domain-local depth metric/blend curves remain versioned/tunable.

## 7. Connectivity philosophy — LOCKED

Design shorthand remains roughly **10% Souls-style connectivity**: occasional strong spatial revelations and useful loops without turning procedural topology into spaghetti.

Mechanisms include:
- natural proximity connectors;
- deliberate topology loops;
- cross-network/cross-region connectors;
- vertical reconnections.

Connection scoring may consider topology gain, depth variety, useful sites/regions, plausibility, connector cost and redundancy.

This is an **Underworld-internal** topology principle. Cross-domain gateway travel is separate.

## 8. Building — LOCKED

Building is permitted in both domains wherever normal building/world rules allow it.

One building architecture serves both domains.

Difficulty emerges from:
- irregular terrain/space;
- access/logistics;
- hostile ecology;
- structural support;
- resource availability;
- protected/immutable critical geometry.

Good underground building geography should be a valuable discovery, not universally available flat space.

See [`30_gameplay/BUILDING_SYSTEM.md`](30_gameplay/BUILDING_SYSTEM.md).

## 9. Terrain modification — LOCKED DIRECTION

### Overworld
The Overworld can support relatively broad local settlement-focused terrain modification such as flattening, shallow excavation, roads/paths, trenches and foundations according to eventual technical budgets.

### Underworld
Modification remains selective so structural topology cannot be bypassed by unrestricted tunneling.

Expected categories:
- structural bedrock: normally permanent;
- rubble/collapses: selectively removable;
- resource-bearing material: mineable;
- designated modifiable volumes: allowed;
- local obstructions: potentially removable.

Overworld excavation does not automatically intersect Underworld geometry merely because numeric coordinates overlap.

Any future player-created cross-domain connection requires an explicit gateway mechanic.

## 10. Boss/special-location modification — LOCKED

Protect only what requires protection.

Critical encounter geometry may be immutable/restricted; other areas may allow building/terrain preparation where doing so does not break required state.

A small number of encounters may intentionally make environmental preparation part of their identity.

## 11. Audio locality — LOCKED

World domain is the coarse surface/Underworld semantic.

Within a domain, sound has finite relevance and may use 3D distance/occlusion/portal/tunnel approximations.

Inactive Underworld content does not leak sound into the Overworld simply because old shared coordinates would have placed it vertically below the player.

Only relevant runtime audio needs active players/processors.

## 12. Streaming — LOCKED

The generated world may be far larger than the live runtime scene.

Architecture separates:
- deterministic definitions;
- geometry descriptions/caches;
- render representation;
- collision representation;
- simulation/interactables;
- audio/VFX;
- durable deltas.

Overworld and Underworld have independent runtime residency/budget decisions under one transition coordinator.

A cave region can exist deterministically with zero live Godot Nodes.

Runtime work follows current relevance, not total explored history.

See [`STREAMING_OWNERSHIP.md`](STREAMING_OWNERSHIP.md).

## 13. Persistence — LOCKED

Modern durable Player location is:

```text
active_domain + domain_local_transform
```

Untouched procedural truth is regenerated from pinned compatible contracts. Persistent changes are saved as compact semantic deltas.

A saved Underworld position does not need an equivalent Overworld coordinate and vice versa.

See [`PERSISTENCE_AND_VERSIONING.md`](PERSISTENCE_AND_VERSIONING.md).

## 14. Scalability — LOCKED DIRECTION

The world architecture is designed for:
- long exploration histories;
- large procedural populations;
- megabuilds;
- future multiplayer interest management;
- independent domain streaming;
- bounded worker/main-thread publication.

Static unchanged state should approach minimal CPU work.

See [`10_architecture/PERFORMANCE_AND_SCALABILITY.md`](10_architecture/PERFORMANCE_AND_SCALABILITY.md).

## Locked invariants

1. Overworld and Underworld are independent procedural domains inside one root world.
2. Cross-domain relationship is explicit gateway identity, not XYZ equivalence.
3. Underworld topology is hierarchical pure deterministic truth before geometry/runtime.
4. Shallow/mid/deep are Underworld-domain grammars.
5. Underworld connectivity remains bounded and intentional.
6. Building is allowed in both domains under one modular architecture.
7. Underworld modification remains selective enough to preserve topology.
8. Runtime representation never defines deterministic existence.
9. Persistence is domain-qualified and delta-based.
10. Loading screens are valid transition presentation.
11. Overworld digging does not implicitly reveal the Underworld.
12. Performance work scales with current relevance/residency rather than total world history.

## Intentionally open

- exact domain sizes;
- exact Underworld depth curves;
- gateway geographic mapping policy;
- terrain deformation limits;
- world streaming radii/cell sizes;
- final ecology/biome roster;
- exact gateway presentation;
- future player-created gateway mechanics.