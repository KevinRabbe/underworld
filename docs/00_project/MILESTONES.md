# Underworld Milestones and Accepted Baselines

Status: **project-history index**

This document records accepted project baselines and milestone boundaries. It is intentionally smaller and more stable than the live task board: use it to answer **what was accepted, at which repository baseline, and what was explicitly deferred**.

It does not replace architecture or decision sources. Normative design decisions remain in [`DECISION_LOG.md`](../DECISION_LOG.md) and are indexed by [`DECISION_INDEX.md`](DECISION_INDEX.md). Current work state remains on [PM-000 / issue #33](https://github.com/KevinRabbe/underworld/issues/33).

## Pre-M2 foundation history

Before the numbered M2 runtime-cave milestone, the project completed an architecture-first foundation cycle and then moved through deterministic identity, seed-domain, graph/topology, entrance and connectivity implementation. This established the project-owned deterministic world-definition model that later M2 work consumed rather than replacing.

For the authoritative architectural history and the transition from architecture to implementation, see the historical milestone entries indexed in [`DECISION_INDEX.md`](DECISION_INDEX.md), especially the architecture-foundation and deterministic-foundation/topology transitions. This section is historical context only; it does not invent a separate numbered milestone or reconstruct every early PR.

## M2 — Procedural World Foundation -> first traversable runtime cave

**Status:** DONE  
**Accepted baseline:** `3f8fa4fcb1f688d90ee4e7b1409b9638162a8b63`  
**Completion authority:** [MAP-015 / issue #46](https://github.com/KevinRabbe/underworld/issues/46)

### Goal

Carry the deterministic Underworld foundation through a real runtime vertical slice: generated cave truth partitions into runtime geometry cells, those cells stream from observer demand, surface entrances request the correct underground cells, collision readiness gates traversal, and a reproducible fixture can be traversed through the production integration path.

### Accepted protected sequence

The milestone was accepted through this dependency sequence:

`MAP-009 -> WORLDGEN-055 -> MAP-010 -> MAP-012 -> MAP-011 -> MAP-013 -> MAP-014 -> MAP-015`

| Stage | Accepted responsibility |
| --- | --- |
| [MAP-009 / #40](https://github.com/KevinRabbe/underworld/issues/40) | Geometry-cell partition and fragment contract, including canonical cell identity and cross-cell continuation invariants. |
| [WORLDGEN-055 / #65](https://github.com/KevinRabbe/underworld/issues/65) | Stage-result provenance and generation-context coherence across authoritative inputs and causal neighbors. |
| [MAP-010 / #41](https://github.com/KevinRabbe/underworld/issues/41) | Runtime cave-mesh builder baseline with deterministic/content-sensitive mesh identity and worker/main-thread separation. |
| [MAP-012 / #43](https://github.com/KevinRabbe/underworld/issues/43) | Canonical underground runtime-cell lifecycle, observer demand, hysteresis, stale-result rejection and streaming ownership. |
| [MAP-011 / #42](https://github.com/KevinRabbe/underworld/issues/42) | Surface entrance integration and exact immediate underground-cell demand, including boundary and negative-coordinate cases. |
| [MAP-013 / #44](https://github.com/KevinRabbe/underworld/issues/44) | Real cave collision realization and fail-closed traversal-readiness gating. |
| [MAP-014 / #45](https://github.com/KevinRabbe/underworld/issues/45) | Production-path runtime geometry/streaming validation harness and deterministic integration evidence. |
| [MAP-015 / #46](https://github.com/KevinRabbe/underworld/issues/46) | First reproducible traversable underground vertical slice and final M2 acceptance. |

### What M2 completion means

At the accepted baseline, the project had proven the architecture and lifecycle needed for a traversable runtime cave: deterministic world/provenance truth, cell partitioning, runtime mesh preparation/realization, streaming, entrance demand, collision readiness and an integrated traversal fixture all worked together under the accepted validation gates.

Milestone completion means those contracts became the compatibility baseline for later work. Later representation, presentation, profiling or content work can improve what the cave looks like or contains without retroactively making M2 incomplete.

### Explicit representation deferral

M2 intentionally accepted a **replaceable placeholder cave mesh** as sufficient to prove runtime traversal and lifecycle integration. The placeholder was an accepted representation choice, not an accidentally unfinished milestone requirement.

Full deterministic voxel/Marching-Cubes extraction was explicitly deferred to [MAP-016 / issue #159](https://github.com/KevinRabbe/underworld/issues/159). MAP-016 is a **post-M2 runtime-geometry representation replacement**: it must preserve the accepted M2 identity, provenance, streaming, collision and save boundaries while replacing only the cave realization layer.

A defect found by later work can still require repair of an accepted contract, but ordinary post-M2 polish or representation replacement does not reopen the milestone by itself.

## Accepted history vs current roadmap

This file records **accepted history**. It does not mirror READY/IN PROGRESS/REVIEW state from the pull board and must not be used to infer that an unlisted follow-up is cancelled or complete.

Use:
- this document for milestone boundaries and accepted baseline SHAs;
- [`DECISION_LOG.md`](../DECISION_LOG.md) and [`DECISION_INDEX.md`](DECISION_INDEX.md) for architecture/design decisions and their status;
- [PM-000 / issue #33](https://github.com/KevinRabbe/underworld/issues/33) for the live roadmap, dependencies and worker state;
- the milestone's completion issue for detailed acceptance evidence.

## Convention for future milestone entries

Add a new entry only after the milestone has an explicit accepted baseline. Keep each entry compact and record:

1. **Name and status** — use the project-supported milestone name; do not invent a retrospective one.
2. **Goal** — one short statement of the integrated capability the milestone proved.
3. **Accepted baseline SHA** — the exact repository commit that represents completion.
4. **Key accepted contracts** — the minimal dependency sequence or major invariants needed to understand the baseline.
5. **Explicit deferrals/follow-ups** — work intentionally left for later, especially where it could otherwise be mistaken for unfinished milestone scope.
6. **Authority** — link the completion issue and relevant durable architecture/decision documents.

Do not turn milestone entries into per-commit release notes or copies of the live task board. If a later decision changes an accepted architecture rule, record that change through the project's decision/supersession process and link it here only when it changes how the milestone baseline should be interpreted.
