# Underworld Decision Index and ADR Convention

Status: **project-governance index**

[`../DECISION_LOG.md`](../DECISION_LOG.md) preserves the chronological decision history. Newer explicit ADRs may supersede specific historical locked clauses without deleting or rewriting that history.

Current supersession authority:
- [`ADR-001_TWO_WORLD_DOMAINS.md`](ADR-001_TWO_WORLD_DOMAINS.md) — **ACTIVE / LOCKED**, 2026-08-31.

Current master roadmap:
- [`MASTER_ROADMAP.md`](MASTER_ROADMAP.md)

Current milestone history:
- [`MILESTONES.md`](MILESTONES.md)

## Status meanings

- **Active — LOCKED**: current binding architecture/design rule.
- **Active — LOCKED DIRECTION**: binding direction with intentionally open implementation/tuning details.
- **Recorded**: historical/current-at-entry observation, not permanent architecture.
- **Historical milestone**: accepted implementation checkpoint.
- **Open**: intentionally undecided.
- **Superseded**: a later explicit decision names/replaces the old normative rule. Historical text remains preserved.

Never infer supersession from newer code alone. A later decision/ADR must identify what it replaces.

---

# Current high-level decision index

| Domain / topic | Current authority | Status | Current rule |
| --- | --- | --- | --- |
| Overworld / Underworld relationship | [`ADR-001`](ADR-001_TWO_WORLD_DOMAINS.md), [`WORLD_DOMAINS_AND_TRANSITIONS`](../20_world/WORLD_DOMAINS_AND_TRANSITIONS.md) | **Active — LOCKED** | Two independent procedural world domains connected by deterministic gateways; no shared-coordinate/physical-continuity requirement. |
| Cross-domain transition | [`ADR-001`](ADR-001_TWO_WORLD_DOMAINS.md), [`STREAMING_OWNERSHIP`](../STREAMING_OWNERSHIP.md) | **Active — LOCKED** | Explicit transition lifecycle; direct fade/loading is valid V1; destination safety/readiness precedes control. |
| Active surface/Underworld semantic | [`ADR-001`](ADR-001_TWO_WORLD_DOMAINS.md) | **Active — LOCKED** | `active_domain` is authoritative coarse state; UI/audio do not infer from Y/AABB/render visibility. |
| Domain-local persistence | [`PERSISTENCE_AND_VERSIONING`](../PERSISTENCE_AND_VERSIONING.md) | **Active — LOCKED** | Player location is `active_domain + domain_local_transform`; no coordinate conversion/nearest-gateway guessing. |
| Underworld generation pipeline | [`UNDERWORLD_GENERATION_PIPELINE`](../20_world/UNDERWORLD_GENERATION_PIPELINE.md) | **Active — LOCKED** | Pure deterministic domain-local topology/sites/connectivity/hooks/geometry pipeline. |
| Underworld depth grammar | [`UNDERWORLD_GENERATION_PIPELINE`](../20_world/UNDERWORLD_GENERATION_PIPELINE.md) | **Active — LOCKED** | Shallow/mid/deep remain structural grammars but no longer require Overworld surface-relative physical depth. |
| Underworld entry/exit sites | [`UNDERWORLD_GENERATION_PIPELINE`](../20_world/UNDERWORLD_GENERATION_PIPELINE.md) | **Active — LOCKED** | Deterministic Underworld-local sites; gateway linking is a separate semantic layer. |
| Streaming ownership | [`STREAMING_OWNERSHIP`](../STREAMING_OWNERSHIP.md) | **Active — LOCKED** | Independent Overworld/Underworld residency; bounded relevance; explicit world-domain coordinator; stale-result rejection. |
| Performance/scale discipline | [`PERFORMANCE_AND_SCALABILITY`](../10_architecture/PERFORMANCE_AND_SCALABILITY.md) | **Active — LOCKED DIRECTION** | Canonical state separate from runtime representation; static unchanged state approaches zero CPU work; scale by current relevance. |
| Building architecture | [`BUILDING_SYSTEM`](../30_gameplay/BUILDING_SYSTEM.md) | **Active — LOCKED direction** | Modular declarative pieces, arbitrary transforms, grid + sockets, snap escape, overlap, terrain embedding, event-driven structural graph. |
| Visual production strategy | [`VISUAL_DIRECTION`](VISUAL_DIRECTION.md) | **Active — LOCKED visual family** | Silhouette/readability first; economical geometry + materials/shaders/lighting/atmosphere; modular reusable asset families. |
| Long-horizon execution | [`MASTER_ROADMAP`](MASTER_ROADMAP.md) | **Active strategic plan pending PR acceptance** | Topic lanes allow parallel work; phases are integration gates, not one serial worker queue. |

---

# Explicit 2026-08-31 supersessions

[`ADR-001_TWO_WORLD_DOMAINS.md`](ADR-001_TWO_WORLD_DOMAINS.md) explicitly supersedes only the listed old normative clauses. Everything else in the historical checkpoints remains active unless separately changed.

| Historical source/topic | Previous status | Current status | Replacement |
| --- | --- | --- | --- |
| `DECISION_LOG` Architecture/design → World identity: “Surface and Underworld share one real 3D world-coordinate relationship” | LOCKED | **Superseded** | Independent world domains + gateway linkage. |
| `DECISION_LOG` Generation pipeline → physical surface-to-topology entrance integration | LOCKED | **Superseded** | Underworld-local entry sites + separate gateway linking. |
| `DECISION_LOG` Generation pipeline → required deterministic surface-reference depth | LOCKED | **Superseded** | Underworld-domain depth/profile metrics. |
| `DECISION_LOG` Streaming → “One continuous runtime world” / no SURFACE-vs-UNDERWORLD state | LOCKED | **Superseded** | Explicit active world domain + independent runtime residency. |
| `DECISION_LOG` Streaming → mandatory entrance overlap/prefetch for physical traversal | LOCKED DIRECTION | **Superseded** | Destination readiness inside explicit transition/loading lifecycle. |
| old `GENERATION_PIPELINE_INTERFACES.md` physical `SurfaceEntranceIntegrationDescriptor` cross-domain authority | LOCKED | **Superseded** | `20_world/UNDERWORLD_GENERATION_PIPELINE.md`. |
| old `STREAMING_OWNERSHIP.md` one-global-coordinate/runtime ownership | LOCKED | **Superseded** | current rewritten `STREAMING_OWNERSHIP.md`. |

Historical continuous-traversal implementation evidence remains valid as M2/project history and as internal Underworld geometry/runtime evidence. Supersession does not retroactively invalidate completed tests or accepted deterministic topology contracts.

---

# Preserved 2026-08-27 architecture decisions

Unless named above, the following historical decision families remain active and are read from [`../DECISION_LOG.md`](../DECISION_LOG.md).

## World/game design
- surface remains comparatively readable/familiar while Underworld carries primary long-term spatial mystery;
- deterministic world contents exist independently of future player progression/build choices;
- old geography can gain new meaning;
- about 10% Souls-style connectivity remains a design shorthand for occasional meaningful loops/reconnections;
- shallow/mid/deep are overlapping tendencies rather than rigid hard floors;
- underground building is allowed where normal building/world rules permit;
- selective Underworld modification preserves meaningful structural cave material;
- critical boss/encounter geometry may be protected without a universal build ban;
- mining has distinct small-node versus large-deposit interaction goals.

## Deterministic graph/identity
- pure topology data independent of scene Nodes;
- macro region, cave network, geometry/runtime cell are separate concepts;
- stable candidate identity exists before acceptance;
- rejected candidates never renumber later siblings;
- canonical cross-region connector ownership;
- immutable finalized generated definitions;
- StableAddress/StableId are semantic, not runtime index/Node identity;
- generated graphs require canonical fingerprints.

## Seed domains/versioning
- no shared mutable generation RNG;
- named domains/revisions + semantic stable addresses;
- generator manifest is compatibility identity, not universal RNG salt;
- topology/geometry randomness separated;
- engine/noise drift protected by deterministic fingerprints;
- old incompatible generation is migrated/classified explicitly rather than silently reinterpreted.

## Generation internals
- explicit pure stage boundaries;
- scheduler owns dependencies/worker orchestration;
- secondary connectivity remains post-primary analysis;
- special-location hooks reserve future content without owning gameplay;
- base generated geometry and player-caused deltas remain separate.

## Runtime/persistence
- runtime tiers and caches are replaceable representations;
- stale asynchronous results cannot resurrect stale runtime owners;
- durable deltas are not owned by runtime cells;
- generated untouched truth is regenerated under pinned contracts;
- migration is explicit/transactional;
- unresolved references fail visibly/quarantine rather than nearest-object guessing.

## Validation/process
- deterministic reproducible tests across many seeds;
- schedule/order independence where legal;
- reproducible failure metadata;
- architecture-first meaningful batches;
- human playtests reserved for milestone feel/readability/fun rather than every small change.

---

# Historical milestone/checkpoint index

The full chronology remains in [`../DECISION_LOG.md`](../DECISION_LOG.md). Major 2026-08-27 checkpoint families include:

1. Architecture/design checkpoint
2. Underground graph schema checkpoint
3. Stable procedural ID checkpoint
4. Deterministic seed-domain checkpoint
5. Generation pipeline interface checkpoint
6. Streaming ownership checkpoint
7. Persistence/generator-version checkpoint
8. Automated validation checkpoint
9. Architecture-foundation completion / deterministic-foundation / topology / entrance-cycle transitions

These headings remain useful historical anchors even where ADR-001 supersedes specific clauses within them.

---

# Current open/tunable topics

Architecture intentionally does not lock arbitrary numeric values that require profiling or gameplay testing, including:
- exact Underworld depth curves;
- exact cell/chunk dimensions;
- render/collision/simulation radii;
- cache/publication budgets;
- final gateway-linking geographical policy;
- exact building grid dimensions/rotation increments/support values;
- final art/texture/poly budgets;
- exact persistence physical format/sharding;
- long-term legacy support window;
- final multiplayer replication budgets.

Open tuning must not be mistaken for permission to violate the current ownership/identity boundaries.

---

# Decision recording convention

Ordinary durable decisions should normally be recorded chronologically in `DECISION_LOG.md`.

A dedicated ADR is warranted when one decision has substantial alternatives, cross-system consequences or an important supersession/migration story.

Recommended ADR metadata:

```markdown
# ADR-### — Short title
Date: YYYY-MM-DD
Status: ACTIVE | SUPERSEDED | HISTORICAL

Decision:
- normative choice

Rationale:
- trade-off / why

Supersedes:
- exact prior decisions/clauses

Affected contracts:
- authoritative docs
```

## Supersession rules

When a locked rule changes:
1. preserve the historical text;
2. create a later explicit decision/ADR;
3. identify the exact old clause(s) replaced;
4. update owning architecture contracts;
5. update this index;
6. do not infer additional supersessions that were not named.

A supersession is narrow: untouched portions of the historical checkpoint remain active.

## Where changes belong

| Change | Primary record |
| --- | --- |
| Durable architecture/product decision | `DECISION_LOG.md` and/or dedicated ADR when warranted |
| Normative system ownership/invariant | Owning architecture document |
| Work item/blocker/dependency/status | PM/task issue |
| Implementation + test evidence | PR / test suite |
| Accepted milestone baseline | `MILESTONES.md` |
| Unresolved question | Owning issue/design discussion marked open |

## Maintenance rule

Whenever a new decision explicitly supersedes an old one, update this index in the same documentation/governance change where practical. Never let an older locked clause remain displayed here as current after a known explicit supersession.