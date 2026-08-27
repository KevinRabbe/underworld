# Underworld — Next Development Cycle

## Completed gates

- PR #10: deterministic foundation, migration, headless validation and batch CI.
- PR #11: deterministic macro planning, continuous depth grammar and connected
  primary topology.
- PR #12 / v0.10 branch: deterministic surface sampling, surface-relative depth,
  entrance selection, entrance-path graph data and surface-integration descriptors.
- PR #15 / v0.11 branch: deterministic secondary loops, regional network joins,
  canonical cross-region ownership, external edge references and the 2,250-case
  connectivity validation campaign.

---

# Current cycle: v0.12 cave geometry descriptions

## Goal

Convert the final deterministic cave graph into stable physical-space descriptions
that a later carving/mesh stage can consume without changing topology.

This cycle remains data-only. It describes chambers and tunnel centerlines,
cross-sections and shape tendencies. It does not create mesh vertices, collision,
CSG operations, runtime Nodes or streaming cells.

## Required deliverables

### 1. Chamber geometry descriptors

- emit exactly one stable chamber descriptor for every locally-owned cave graph node;
- preserve the source node position as the chamber anchor;
- derive deterministic dimensions, Y rotation, floor bias, ceiling arch, wall
  roughness and asymmetry from `ug.geometry.shape`;
- classify lightweight chamber families from node semantics and continuous depth
  profile, including entrance vestibules, alcoves, junction vaults, galleries,
  fracture vaults and shallow low-oval chambers;
- retain source node, network, region and profile identity for downstream carving.

### 2. Tunnel geometry descriptors

- emit exactly one stable tunnel descriptor for every graph edge owned by the region;
- cover primary edges, vertical transitions, entrance paths, secondary loops,
  cross-network joins and canonically-owned cross-region connectors through one
  common representation;
- generate a deterministic four-point centerline, width, height, clearance margin,
  roughness, path style and slope class;
- use neighboring primary-topology views only to resolve the remote endpoint of an
  owned cross-region connector;
- never duplicate cross-region tunnel geometry in the non-owner region.

### 3. Stable downstream boundary

- geometry addresses derive from the source node/edge StableAddress rather than
  accepted-array indexes or runtime iteration order;
- geometry generation may not mutate topology, entrance or connectivity data;
- descriptor ordering must be canonical and independent of supplied neighbor order;
- the geometry result retains the source graph bundle plus typed chamber/tunnel
  descriptor collections and exact metrics/fingerprint.

### 4. Validation and reproduction

- repeated geometry requests must produce identical fingerprints;
- reversed neighbor scheduling must not change the result;
- every local node and owned edge must receive exactly one descriptor;
- tunnel endpoints must resolve and centerlines must terminate exactly at the source
  graph-node anchors;
- non-owner external edge references must not produce duplicate tunnel descriptors;
- dimensions/clearance values must remain positive and bounded;
- negative region coordinates must remain valid;
- expose exact geometry fingerprints through `--mode=geometry-repro`;
- promote the 250 seeds × 9 regions CI batch through the full geometry-description
  pipeline.

## Explicitly out of scope

- marching cubes, SurfaceTool meshes, CSG or voxel carving;
- terrain-hole realization for surface entrances;
- physics collision and navigation meshes;
- streaming-cell partitioning and LOD;
- decorative rock noise, materials, props, resources, enemies or ecology;
- special-location room templates;
- final production art dimensions or cave aesthetics.

## Exit criteria

This cycle is complete when:

1. repeated region requests produce identical geometry fingerprints;
2. reversed neighbor input order produces the same geometry result;
3. source graph fingerprints are unchanged by geometry generation;
4. chamber count equals local graph-node count;
5. tunnel count equals locally-owned graph-edge count;
6. non-owner cross-region references never duplicate tunnel geometry;
7. negative-coordinate fixtures pass;
8. Godot 4.7.2 fast contracts and the 2,250-case geometry batch are green.

Only after this gate should cave carving/mesh realization begin.
