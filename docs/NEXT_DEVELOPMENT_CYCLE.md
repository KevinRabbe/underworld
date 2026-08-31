# Underworld — Next Development Cycle

Status: **HISTORICAL IMPLEMENTATION CHECKPOINT — NOT CURRENT ROADMAP AUTHORITY**

This document preserves the v0.10–v0.12 development sequence as project history. It is not the current execution plan and must not override the 2026-08-31 two-domain architecture.

Current authority:
- [`00_project/MASTER_ROADMAP.md`](00_project/MASTER_ROADMAP.md) for current long-horizon execution;
- [`00_project/ADR-001_TWO_WORLD_DOMAINS.md`](00_project/ADR-001_TWO_WORLD_DOMAINS.md) and [`20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](20_world/WORLD_DOMAINS_AND_TRANSITIONS.md) for world-domain architecture;
- [`20_world/UNDERWORLD_GENERATION_PIPELINE.md`](20_world/UNDERWORLD_GENERATION_PIPELINE.md) for current Underworld generation semantics.

Historical phrases below such as **surface-relative depth**, **surface-integration descriptors**, or physical entrance paths describe the accepted generator implementation at that time. Their cross-domain/shared-coordinate interpretation is **superseded**. Existing deterministic artifacts may remain compatibility evidence, but new work must not treat them as requirements for Overworld/Underworld physical continuity.

---

## Completed historical gates

- PR #10: deterministic foundation, migration, headless validation and batch CI.
- PR #11: deterministic macro planning, continuous depth grammar and connected primary topology.
- PR #12 / v0.10 branch: deterministic surface sampling, surface-relative depth, entrance selection, entrance-path graph data and surface-integration descriptors.
- PR #15 / v0.11 branch: deterministic secondary loops, regional network joins, canonical cross-region ownership, external edge references and the 2,250-case connectivity validation campaign.

These remain valid implementation-history evidence where still compatible. They no longer define the relationship between Overworld and Underworld domains.

---

# Historical cycle: v0.12 finalized cave geometry descriptions

## Goal at the time

Complete the pure-data pipeline boundary between connectivity and geometry, then convert the finalized cave graph into stable physical-space descriptions that a later carving/mesh stage could consume without changing topology.

This cycle was data-only. It reserved generic future special-site clearance, froze finalized region snapshots, and described chambers/tunnel centerlines. It did not create gameplay content, mesh vertices, collision, CSG operations, runtime Nodes or streaming cells.

## Historical deliverables

### 1. Generic special-location reservation

- consume the completed connectivity graph without mutating it;
- use macro-region special candidate slots and `ug.special.exists`;
- reserve bounded generic `reserved_site` hooks per region;
- anchor reservations to stable local cave nodes;
- reject reused anchors and overlapping reserved bounds;
- do not decide bosses, resources, structures or other gameplay content in topology generation.

### 2. Region finalization boundary

- combine the hook-enriched graph, canonical external edge references and then-current entrance compatibility data into one finalized region result;
- validate graph membership, external ownership and relevant references;
- canonically order externally referenced data;
- expose exact finalization metrics/fingerprint;
- provide immutable-by-convention source consumed by geometry generation.

Under current architecture, finalization is **Underworld-domain local** and does not require physical Overworld surface-integration descriptors as cross-domain truth.

### 3. Chamber geometry descriptors

- emit stable chamber descriptors for locally-owned finalized graph nodes;
- preserve source-node local position as chamber anchor;
- derive deterministic dimensions/shape variation from registered geometry domains;
- classify lightweight chamber families from node semantics and continuous Underworld depth profile;
- retain source node/network/region/profile identity for downstream geometry.

### 4. Tunnel geometry descriptors

- emit stable tunnel descriptors for finalized graph edges owned by the region;
- cover primary edges, vertical transitions, domain-local entry paths, secondary loops, cross-network joins and canonically-owned cross-region connectors through one representation;
- use neighboring primary-topology views only to resolve remote endpoints of owned **Underworld cross-region** connectors;
- never duplicate cross-region tunnel geometry in non-owner regions.

### 5. Stable downstream boundary and validation

- geometry addresses derive from source StableAddresses rather than accepted-array indexes/runtime iteration order;
- downstream stages do not mutate upstream data;
- descriptor ordering is canonical and independent of supplied neighbor order;
- repeated requests reproduce fingerprints;
- local nodes/owned edges receive exactly the expected geometry descriptors;
- endpoints resolve exactly;
- non-owner external references do not duplicate geometry;
- dimensions/clearance values remain finite, positive and bounded where required;
- negative domain-local region coordinates remain valid;
- deterministic campaigns cover finalized geometry descriptions.

## Historical out-of-scope list

The v0.12 cycle explicitly excluded:
- boss/resource/structure selection for reserved special sites;
- marching cubes, SurfaceTool meshes, CSG or voxel carving;
- terrain-hole realization for surface entrances;
- physics collision/navigation;
- streaming-cell partitioning and LOD;
- decorative materials/props/resources/enemies/ecology;
- final production art dimensions.

The old exclusion of terrain-hole realization is historical; current architecture goes further and does **not require** a physical cross-domain terrain hole at all.

## Historical exit criteria

The cycle targeted deterministic reproduction, neighbor-order independence, immutable upstream fingerprints, bounded reservations, complete local node/edge geometry coverage, canonical cross-region ownership, negative-coordinate fixtures and green Godot/headless deterministic campaigns.

Those deterministic-quality goals remain useful. This file itself is not a READY-work source.

## Current execution note

Do not self-pull work from this historical cycle document. Use the live pull board (#33), milestone authority (#207) and `00_project/MASTER_ROADMAP.md` for current work.