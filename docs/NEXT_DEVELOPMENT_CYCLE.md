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

# Current cycle: v0.12 finalized cave geometry descriptions

## Goal

Complete the locked pure-data pipeline boundary between connectivity and geometry,
then convert the finalized cave graph into stable physical-space descriptions that
a later carving/mesh stage can consume without changing topology.

This cycle remains data-only. It reserves generic future special-site clearance,
freezes the finalized region snapshot, and describes chambers/tunnel centerlines.
It does not create gameplay content, mesh vertices, collision, CSG operations,
runtime Nodes or streaming cells.

## Required deliverables

### 1. Generic special-location reservation

- consume the completed connectivity graph without mutating it;
- use the existing macro-region special candidate slots and `ug.special.exists`;
- reserve at most two bounded generic `reserved_site` hooks per region;
- anchor reservations to stable local cave nodes;
- reject reused anchors and overlapping reserved bounds;
- do not decide bosses, resources, structures or other gameplay content in this pass.

### 2. Region finalization boundary

- combine the hook-enriched graph, canonical external edge references and surface
  entrance integration descriptors into one finalized region result;
- validate graph membership, external ownership and entrance-integration references;
- canonically order externally referenced data;
- expose exact finalization metrics/fingerprint;
- provide the immutable-by-convention source consumed by geometry generation.

### 3. Chamber geometry descriptors

- emit exactly one stable chamber descriptor for every locally-owned finalized graph node;
- preserve the source node position as the chamber anchor;
- derive deterministic dimensions, Y rotation, floor bias, ceiling arch, wall
  roughness and asymmetry from `ug.geometry.shape`;
- classify lightweight chamber families from node semantics and continuous depth
  profile, including entrance vestibules, alcoves, junction vaults, galleries,
  fracture vaults and shallow low-oval chambers;
- retain source node, network, region and profile identity for downstream carving.

### 4. Tunnel geometry descriptors

- emit exactly one stable tunnel descriptor for every finalized graph edge owned by the region;
- cover primary edges, vertical transitions, entrance paths, secondary loops,
  cross-network joins and canonically-owned cross-region connectors through one
  common representation;
- generate a deterministic four-point centerline, width, height, clearance margin,
  roughness, path style and slope class;
- use neighboring primary-topology views only to resolve the remote endpoint of an
  owned cross-region connector;
- never duplicate cross-region tunnel geometry in the non-owner region.

### 5. Stable downstream boundary and validation

- geometry addresses derive from source node/edge StableAddresses rather than
  accepted-array indexes or runtime iteration order;
- hook reservation, finalization and geometry may not mutate upstream stage data;
- descriptor ordering must be canonical and independent of supplied neighbor order;
- repeated requests must reproduce hook, finalization and geometry fingerprints;
- every local node and owned edge must receive exactly one geometry descriptor;
- tunnel endpoints must resolve and centerlines must terminate exactly at source
  graph-node anchors;
- non-owner external edge references must not produce duplicate tunnel descriptors;
- dimensions/clearance values must remain positive and bounded;
- negative region coordinates must remain valid;
- expose exact geometry fingerprints through `--mode=geometry-repro`;
- promote the 250 seeds × 9 regions CI batch through the full finalized geometry
  description pipeline.

## Explicitly out of scope

- boss/resource/structure selection for reserved special sites;
- marching cubes, SurfaceTool meshes, CSG or voxel carving;
- terrain-hole realization for surface entrances;
- physics collision and navigation meshes;
- streaming-cell partitioning and LOD;
- decorative rock noise, materials, props, resources, enemies or ecology;
- special-location room templates;
- final production art dimensions or cave aesthetics.

## Exit criteria

This cycle is complete when:

1. repeated region requests produce identical hook/finalization/geometry fingerprints;
2. reversed neighbor input order produces the same finalized geometry result;
3. upstream graph fingerprints are unchanged by downstream stages;
4. generic special-site reservations stay bounded and non-overlapping;
5. chamber count equals finalized local graph-node count;
6. tunnel count equals finalized locally-owned graph-edge count;
7. non-owner cross-region references never duplicate tunnel geometry;
8. negative-coordinate fixtures pass;
9. Godot 4.7.2 fast contracts and the 2,250-case finalized geometry batch are green.

Only after this gate should cave carving/mesh realization begin.
