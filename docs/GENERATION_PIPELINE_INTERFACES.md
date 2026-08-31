# Underworld — Generation Pipeline Interfaces

Status: **SUPERSEDED AS ACTIVE CONTRACT by the two-domain architecture**

This historical root-level document previously defined an Underworld generation pipeline that assumed:
- one shared surface/Underworld coordinate relationship;
- surface-relative Underworld depth;
- physical `SurfaceEntranceIntegrationDescriptor` cutouts joining surface terrain to cave geometry;
- surface-generation dependency on Underworld entrance geometry.

Those cross-domain assumptions were explicitly superseded on 2026-08-31 by:

- [`00_project/ADR-001_TWO_WORLD_DOMAINS.md`](00_project/ADR-001_TWO_WORLD_DOMAINS.md)
- [`20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](20_world/WORLD_DOMAINS_AND_TRANSITIONS.md)
- [`20_world/UNDERWORLD_GENERATION_PIPELINE.md`](20_world/UNDERWORLD_GENERATION_PIPELINE.md)

## Active replacement

The authoritative current generation contract is:

[`docs/20_world/UNDERWORLD_GENERATION_PIPELINE.md`](20_world/UNDERWORLD_GENERATION_PIPELINE.md)

Its core pipeline remains recognizably descended from the accepted architecture:

```text
Macro Region Planning
-> Primary Topology
-> Underworld Entry/Exit Sites
-> Secondary Connectivity
-> Special-Location Hooks
-> Region Finalization
-> Geometry Description
-> Runtime Streaming
```

The important replacement is at the domain boundary:
- Underworld entry/exit sites are domain-local deterministic truth;
- Overworld gateway/source sites are Overworld-domain truth;
- a separate deterministic gateway-linking layer connects them;
- coordinates are not converted or assumed identical;
- Underworld shallow/mid/deep grammar no longer requires Overworld surface height;
- surface terrain no longer needs a matching cave cutout merely to support an Underworld entrance.

## Preserved accepted contracts

The supersession does **not** invalidate:
- pure/headless generation stages;
- stable candidate addresses/StableIds;
- named seed domains/revisions;
- immutable finalized definitions;
- macro region/network/node/edge ownership;
- continuous shallow/mid/deep profile weights inside the Underworld;
- secondary/cross-region connectivity and canonical ownership;
- special-location hooks;
- canonical fingerprints and scheduling-order invariance;
- topology/geometry separation;
- deterministic geometry-cell descriptions;
- runtime streaming as a consumer rather than generator authority.

Historical commits retain the full pre-supersession text for archaeology. New implementation and review work must use the replacement contract above.