# Underworld — Next Development Cycle

## Deterministic foundation status — COMPLETE

The deterministic foundation was merged through PR #10 after the Godot 4.7.2
headless contracts and 2,250-case batch probe completed successfully.

The project now has tested contracts for stable identity, named seed domains,
generator manifests, pure graph definitions, canonical fingerprints, graph
validation, reproduction probes, persistence boundaries and prototype-v2 save
migration.

---

# Current cycle: first primary Underworld topology generator

## Goal

Implement the first deterministic data-only generator for local cave networks,
nodes and primary edges. This cycle proves the macro-plan -> depth grammar ->
primary-topology path before entrances, secondary connectivity or geometry.

The result is an abstract graph definition, not a rendered cave.

## Required deliverables

### 1. Deterministic macro-region plan

- derive one canonical region address, ownership bounds and profile bias;
- expose fixed network candidate slots before acceptance;
- carry regional branching/verticality tendencies as pure data;
- produce a canonical stage fingerprint.

### 2. Continuous depth-profile grammar

- sample normalized shallow/mid/deep weights from deterministic region/depth data;
- blend topology parameters from those weights;
- keep exact curves explicit and revisable rather than scattering depth checks.

### 3. Primary topology generation

- accept/reject stable network and node candidate slots independently;
- generate at least one connected primary network per region;
- create pure `CaveNetworkDefinition`, `CaveNodeDefinition` and
  `CaveEdgeDefinition` data;
- keep primary topology region-owned and loop-free in this stage;
- emit canonical transient boundary candidates for later connectivity analysis.

### 4. Validation and reproduction

- reject disconnected primary networks and duplicate undirected primary edges;
- verify stable candidate identity, normalized profiles and valid graph ownership;
- produce exact seed/region topology fingerprints;
- run deterministic batch validation across positive and negative region coordinates.

## Explicitly out of scope

- entrances and surface integration;
- secondary loops or cross-region connections;
- special-location content;
- cave meshes, collision or runtime streaming cells;
- enemies, resources, bosses or ecology;
- player progression, save deltas or runtime scene state;
- final tuning of region size, depth curves or cave-shape distributions.

## Exit criteria

This cycle is complete when:

1. the same context and macro request produce the same macro fingerprint;
2. the same macro plan produces the same topology fingerprint;
3. candidate rejection never renumbers network or node candidate identities;
4. every generated primary network is internally reachable;
5. generated definitions pass the graph invariant validator;
6. shallow/mid/deep grammar materially changes topology tendencies;
7. an exact seed/region topology failure can be reproduced from the CLI;
8. the full headless and batch CI gate is green.

Only after this gate should entrance generation or secondary connectivity begin.
