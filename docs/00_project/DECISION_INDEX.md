# Underworld Decision Index and ADR Convention

Status: **project-governance index**

[`../DECISION_LOG.md`](../DECISION_LOG.md) remains the authoritative chronological decision history. This file is a navigation/index layer only: it does not rewrite, reclassify or supersede old decisions by itself.

Use this index to answer three questions quickly:

1. Which part of the decision log covers this topic?
2. Is the source explicitly locked/directional/open, or merely a historical/recorded note?
3. Where should a new decision be recorded?

Related governance/ownership references:

- [`DOCUMENTATION_ARCHITECTURE.md`](DOCUMENTATION_ARCHITECTURE.md) — documentation ownership and document types.
- [`../10_architecture/DEPENDENCY_RULES.md`](../10_architecture/DEPENDENCY_RULES.md) — cross-system dependency direction.
- [`../10_architecture/REPOSITORY_STRUCTURE.md`](../10_architecture/REPOSITORY_STRUCTURE.md) — repository/system ownership.
- [`../STREAMING_OWNERSHIP.md`](../STREAMING_OWNERSHIP.md) — world-definition, geometry, runtime and durable-delta ownership.

## How status is represented here

Historical entries predate this index and use their own explicit labels. Do not retrofit newer terminology onto them unless the source supports it.

This index therefore uses:

- **Active — explicit LOCKED**: the source heading/rule says `LOCKED` or `LOCKED ARCHITECTURAL ...`.
- **Active — explicit LOCKED DIRECTION**: the source says `LOCKED DIRECTION`; the direction is binding while some implementation detail remains open.
- **Recorded**: the source explicitly records technical debt/current state without declaring it a permanent rule.
- **Historical milestone**: the source records a completed implementation checkpoint/transition rather than a permanent architecture rule.
- **Open**: the source explicitly lists the subject as intentionally undecided.
- **Superseded**: use only when a later decision explicitly identifies what it replaces. No old entry is marked superseded here merely because implementation has advanced.

If an old entry's current status is ambiguous, treat the ambiguity as **needs clarification** rather than guessing.

## Topic index

All current indexed entries are dated **2026-08-27** in the source log.

| Domain / topic | Source checkpoint | Source-backed status | What to look for |
| --- | --- | --- | --- |
| World identity / surface–Underworld relationship | [Architecture/design checkpoint](../DECISION_LOG.md#2026-08-27--architecturedesign-checkpoint) | Active — explicit LOCKED | One continuous 3D world relationship; underground content independent of progression/building choices. |
| Cave systems / entrances | [Architecture/design checkpoint](../DECISION_LOG.md#2026-08-27--architecturedesign-checkpoint) | Active — explicit LOCKED | Hierarchical topology, entrance tendencies, deep/unexpected connections. |
| Depth structure | [Architecture/design checkpoint](../DECISION_LOG.md#2026-08-27--architecturedesign-checkpoint) | Active — explicit LOCKED | Shallow/mid/deep grammars, continuous overlap and exceptions. |
| Secondary connectivity design | [Architecture/design checkpoint](../DECISION_LOG.md#2026-08-27--architecturedesign-checkpoint) | Active — explicit LOCKED | Rough 10% connectivity philosophy, meaningful loops/reconnections. |
| Underground building / terrain modification | [Architecture/design checkpoint](../DECISION_LOG.md#2026-08-27--architecturedesign-checkpoint) | Active — explicit LOCKED | Build freedom, selective cave modification, structural bedrock. |
| Boss/special-area environment rules | [Architecture/design checkpoint](../DECISION_LOG.md#2026-08-27--architecturedesign-checkpoint) | Active — explicit LOCKED | No universal build/terraform ban; protect only required encounter geometry. |
| Creature/world audio | [Architecture/design checkpoint](../DECISION_LOG.md#2026-08-27--architecturedesign-checkpoint) | Active — explicit LOCKED | Finite local 3D relevance and physical propagation. |
| Mining / resource interaction | [Architecture/design checkpoint](../DECISION_LOG.md#2026-08-27--architecturedesign-checkpoint) | Active + Open subset | Small-node and large-deposit direction is locked; tree harvesting remains explicitly undecided. |
| Development/testing process | [Architecture/design checkpoint](../DECISION_LOG.md#2026-08-27--architecturedesign-checkpoint) | Active — explicit LOCKED | Architecture-first batches, automated validation, milestone playtests. |
| Prototype surface-ID technical debt | [Architecture/design checkpoint](../DECISION_LOG.md#2026-08-27--architecturedesign-checkpoint) | Recorded | Accepted-array-index identity debt and migration need. Do not infer current completion from this old note alone. |
| Pure graph/topology data | [Underground graph schema checkpoint](../DECISION_LOG.md#2026-08-27--underground-graph-schema-checkpoint) | Active — explicit LOCKED | Scene-independent graph definitions and headless generation/validation. |
| Region/network ownership | [Underground graph schema checkpoint](../DECISION_LOG.md#2026-08-27--underground-graph-schema-checkpoint) | Active — explicit LOCKED | Macro region, cave network and runtime cell are separate concepts. |
| Depth weights in graph data | [Underground graph schema checkpoint](../DECISION_LOG.md#2026-08-27--underground-graph-schema-checkpoint) | Active — explicit LOCKED | Continuous profile weights; exact meter curves remain open. |
| Secondary/cross-region edge ownership | [Underground graph schema checkpoint](../DECISION_LOG.md#2026-08-27--underground-graph-schema-checkpoint) | Active — explicit LOCKED | Stable edges, canonical cross-region owner, no network renumbering. |
| Immutable generated definitions / durable deltas | [Underground graph schema checkpoint](../DECISION_LOG.md#2026-08-27--underground-graph-schema-checkpoint) | Active — explicit LOCKED | Finalized definitions are deterministic base truth; player changes are deltas. |
| Future special-location hooks | [Underground graph schema checkpoint](../DECISION_LOG.md#2026-08-27--underground-graph-schema-checkpoint) | Active — explicit architectural interface | Stable anchors reserve future content without implementing that content in topology. |
| Canonical graph fingerprints | [Underground graph schema checkpoint](../DECISION_LOG.md#2026-08-27--underground-graph-schema-checkpoint) | Active — explicit LOCKED | Canonical sorted debug serialization/fingerprints for deterministic comparison. |
| Procedural candidate identity / WorldId / StableAddress / StableId | [Stable procedural ID checkpoint](../DECISION_LOG.md#2026-08-27--stable-procedural-id-checkpoint) | Active — explicit LOCKED | Candidate-address identity, world scoping, stable lineage and no runtime/index identity. |
| Surface candidate addressing | [Stable procedural ID checkpoint](../DECISION_LOG.md#2026-08-27--stable-procedural-id-checkpoint) | Active — explicit LOCKED DIRECTION | Global candidate domains/cells and fixed semantic slots. |
| Legacy prototype-v2 identity migration | [Stable procedural ID checkpoint](../DECISION_LOG.md#2026-08-27--stable-procedural-id-checkpoint) | Active — explicit LOCKED DIRECTION | Frozen legacy regeneration/mapping; unresolved IDs must not be guessed. |
| Seed domains / no shared RNG | [Deterministic seed-domain checkpoint](../DECISION_LOG.md#2026-08-27--deterministic-seed-domain-checkpoint) | Active — explicit LOCKED | Named domain/revision randomness independent of order/scheduling. |
| Generator version vs domain revision | [Deterministic seed-domain checkpoint](../DECISION_LOG.md#2026-08-27--deterministic-seed-domain-checkpoint) | Active — explicit LOCKED | Manifest is compatibility identity, not universal RNG salt. |
| Topology/geometry RNG separation | [Deterministic seed-domain checkpoint](../DECISION_LOG.md#2026-08-27--deterministic-seed-domain-checkpoint) | Active — explicit LOCKED | Geometry randomness cannot implicitly reshuffle graph topology. |
| Project-owned deterministic RNG | [Deterministic seed-domain checkpoint](../DECISION_LOG.md#2026-08-27--deterministic-seed-domain-checkpoint) | Active — explicit LOCKED DIRECTION | Frozen/project-owned deterministic primitive plus hard-coded vectors. |
| Engine/noise drift detection | [Deterministic seed-domain checkpoint](../DECISION_LOG.md#2026-08-27--deterministic-seed-domain-checkpoint) | Active — explicit LOCKED | Representative persistent fingerprints guard upgrades. |
| Current surface RNG implementation note | [Deterministic seed-domain checkpoint](../DECISION_LOG.md#2026-08-27--deterministic-seed-domain-checkpoint) | Recorded | Historical/current-at-entry prototype behavior; do not treat as permanent architecture. |
| Pure generation stages / scheduler boundary | [Generation pipeline interface checkpoint](../DECISION_LOG.md#2026-08-27--generation-pipeline-interface-checkpoint) | Active — explicit LOCKED | Typed pure stages; scheduler owns dependency resolution and worker orchestration. |
| Generation stage order | [Generation pipeline interface checkpoint](../DECISION_LOG.md#2026-08-27--generation-pipeline-interface-checkpoint) | Active — explicit architectural order | Macro → topology → entrances → connectivity → hooks → finalization → geometry → runtime. |
| Depth profiles as generation input | [Generation pipeline interface checkpoint](../DECISION_LOG.md#2026-08-27--generation-pipeline-interface-checkpoint) | Active — explicit LOCKED | Depth grammar participates during generation, not as cosmetic post-processing. |
| Surface entrance dependency | [Generation pipeline interface checkpoint](../DECISION_LOG.md#2026-08-27--generation-pipeline-interface-checkpoint) | Active — explicit LOCKED | Surface may need pure underground definitions/descriptors, never live cave runtime state. |
| Base geometry vs player deltas | [Generation pipeline interface checkpoint](../DECISION_LOG.md#2026-08-27--generation-pipeline-interface-checkpoint) | Active — explicit LOCKED | Untouched geometry is deterministic base data; player changes compose later. |
| Typed stage data / stage revisions | [Generation pipeline interface checkpoint](../DECISION_LOG.md#2026-08-27--generation-pipeline-interface-checkpoint) | Active — explicit LOCKED DIRECTION | Typed request/result contracts and manifest stage revisions. |
| Continuous runtime world / streaming ownership | [Streaming ownership checkpoint](../DECISION_LOG.md#2026-08-27--streaming-ownership-checkpoint) | Active — explicit LOCKED | No surface/cave mode split; services, streamers and delta store have separate lifetimes. |
| Runtime tiers and 3D underground cells | [Streaming ownership checkpoint](../DECISION_LOG.md#2026-08-27--streaming-ownership-checkpoint) | Active — explicit LOCKED | Definition → geometry → render → collision → simulation/audio tiers. |
| Async stale-result rejection | [Streaming ownership checkpoint](../DECISION_LOG.md#2026-08-27--streaming-ownership-checkpoint) | Active — explicit LOCKED | Request identity prevents stale workers resurrecting/overwriting runtime state. |
| Entrance prefetch | [Streaming ownership checkpoint](../DECISION_LOG.md#2026-08-27--streaming-ownership-checkpoint) | Active — explicit LOCKED DIRECTION | Entrance proximity may prefetch connected underground data. |
| Saved vs regenerated state | [Persistence and generator-version checkpoint](../DECISION_LOG.md#2026-08-27--persistence-and-generator-version-checkpoint) | Active — explicit LOCKED | Untouched truth regenerates; player/persistent changes are durable state. |
| Version concepts / generator manifest | [Persistence and generator-version checkpoint](../DECISION_LOG.md#2026-08-27--persistence-and-generator-version-checkpoint) | Active + LOCKED DIRECTION | Separate schema/seed/address/manifest concepts; pin reproducible generation configuration. |
| Compatibility / migration safety | [Persistence and generator-version checkpoint](../DECISION_LOG.md#2026-08-27--persistence-and-generator-version-checkpoint) | Active — explicit LOCKED | Explicit compatibility classes, transactional migrations, no guessed references. |
| Prototype-v2 migration order | [Persistence and generator-version checkpoint](../DECISION_LOG.md#2026-08-27--persistence-and-generator-version-checkpoint) | Active — explicit LOCKED | Identity migration precedes later generator-contract change. |
| Automated validation strategy | [Automated validation checkpoint](../DECISION_LOG.md#2026-08-27--automated-validation-checkpoint) | Active — explicit LOCKED | Headless/data validation before experiential testing. |
| Batch campaigns / schedule independence | [Automated validation checkpoint](../DECISION_LOG.md#2026-08-27--automated-validation-checkpoint) | Active — explicit LOCKED | Fixed + campaign corpora and legal scheduling-order equivalence. |
| Reproducible failures / expected deterministic changes | [Automated validation checkpoint](../DECISION_LOG.md#2026-08-27--automated-validation-checkpoint) | Active — explicit LOCKED | Reproduction metadata and constrained golden-output updates. |
| Architecture foundation cycle complete | [Architecture foundation cycle complete](../DECISION_LOG.md#2026-08-27--architecture-foundation-cycle-complete) | Historical milestone | Marks transition from pre-implementation architecture to foundation implementation. |
| Primary topology / entrance cycle transitions | [Primary topology complete; deterministic entrance cycle begins](../DECISION_LOG.md#2026-08-27--primary-topology-complete-deterministic-entrance-cycle-begins) | Historical milestone | Records PR/cycle sequencing at that time; not a permanent current task board. |
| Deterministic foundation / topology cycle transition | [Deterministic foundation merged; primary topology cycle begins](../DECISION_LOG.md#2026-08-27--deterministic-foundation-merged-primary-topology-cycle-begins) | Historical milestone | Records completed foundation gate and then-next implementation cycle. |
| Explicitly undecided implementation/tuning topics | [Current intentionally open implementation/tuning decisions](../DECISION_LOG.md#current-intentionally-open-implementationtuning-decisions) | Open | Numerical tuning, final algorithms/content, cell sizes, storage format and other listed undecided details. |

## Supersession policy

Do not delete or silently rewrite an old decision when a locked rule changes.

A replacement decision should:

1. create a new dated decision entry;
2. state the old stable heading/decision ID it supersedes;
3. state why the old decision is insufficient;
4. identify the new rule;
5. link/update affected authoritative contracts;
6. mark the old entry as superseded only through an explicit cross-reference, preserving its historical text.

Until that explicit relationship exists, this index must not infer supersession from newer code, newer task status or a similar-looking later paragraph.

## Future decision-entry convention

New durable decisions should use a stable heading/ID and a small metadata block so they remain indexable.

Recommended form:

```markdown
## YYYY-MM-DD — DEC-### — Short decision title

Status: active | superseded | historical

Decision:
- concise normative choice

Rationale:
- why this choice was made and the important trade-off

Affected contracts:
- path/to/authoritative_contract.md

Supersedes: DEC-### | None
Superseded by: DEC-### | None
```

Rules:

- Use **active** for a currently governing decision.
- Use **superseded** only with an explicit replacement link.
- Use **historical** for a preserved implementation/process milestone that no longer claims to be the current governing rule.
- A stable descriptive heading is acceptable where a numeric ID has not yet been allocated; never renumber old decisions just to make the file look uniform.
- Existing 2026-08-27 history is grandfathered. Do not bulk-rewrite it into the new form.

### When a dedicated ADR is warranted

Keep ordinary durable decisions in the decision log. A dedicated architecture decision record is justified only when one decision has substantial alternatives/trade-offs, cross-system consequences or a long supersession/migration story that would make a concise log entry hard to review.

If a dedicated ADR is introduced:

- keep the same date/status/decision/rationale/affected-contract/supersession metadata;
- add a short entry in `DECISION_LOG.md` linking to it so chronological history remains complete;
- let the ADR explain alternatives and consequences, while the authoritative architecture contracts still contain the normative system rules;
- do not create ADRs for routine implementation choices, small refactors or task sequencing.

This task defines the convention only; it does not retroactively split existing history into ADR files.

## Where should a change be recorded?

| Change type | Record it in | Why |
| --- | --- | --- |
| Durable design/architecture choice or deliberate replacement of a locked rule | `DECISION_LOG.md` (and optional dedicated ADR when warranted) | Preserves chronological rationale and supersession history. |
| Normative system ownership, schema, invariant or dependency rule | The owning architecture/contract document | This is the operational source of truth implementation must follow. |
| Work item, dependency, blocker, claim or acceptance criteria | Task/PM issue | Task state is project execution metadata, not permanent architecture. |
| Concrete implementation plus tests/evidence | Pull request | PRs implement/review decisions; they should not be the only permanent record of architecture. |
| Routine implementation detail with no durable architectural consequence | Code/tests/PR only | Avoid turning every small choice into governance ceremony. |
| Unresolved architecture question | Owning issue/design discussion, marked open | Do not manufacture a decision-log entry until a decision actually exists. |

## Maintenance rule

When a new durable decision is added or explicitly superseded, update this index in the same documentation/governance change when practical. If the source decision is ambiguous, add a clarification follow-up rather than silently resolving ambiguity in this index.