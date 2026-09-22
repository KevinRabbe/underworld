# Underworld — Codex Current Queue

Snapshot date: **2026-09-22**

Baseline observed while preparing this handoff:

```text
main = 1c258ab681023d296425a574f769a4f73841ebf9
```

This file is deliberately a **mutable scheduling snapshot**. The live issue board wins when it advances.

Before every long run and after every merge, reread the newest controlling comments on `#33`, `#886`, and the issues for candidate packets.

## Current gate

At snapshot time:

```text
Gate 0 = CLOSED
Phase-0 EXIT = required before implementation launch
```

Therefore do **not** treat the queue below as authorization to mutate production source before the explicit Phase-0 exit.

Preflight/read-only analysis may establish readiness, but do not claim source paths while the controlling board says no claim.

## Current blocked-mode backlog

While Gate 0 remains closed, a long Codex run should **not stop after confirming #539 is still protected**. It should perform read-only work from this backlog without taking source/review ownership.

Current highest-value order:

```text
P0-B1  #539/#433 disposition freshness
       verify exact protected head, current main relation,
       active findings, exact PASS/REPAIR/SYNC/RUNNER branches

P0-B2  paired #807/#601 accepted-head preflight
       re-read current frozen contracts and current main
       derive branch-sensitive 19/20-path shape
       identify exact shared paths, tests, workflow triggers,
       and what changes if #433 is repaired vs lands unchanged

P0-B3  #663 preflight
       derive smallest accepted-#807/#601-relative Surface
       seed-domain / contract-revision packet and test ownership

P0-B4  #718 preflight
       confirm the structural-only TerrainGenerator extraction
       still has the expected source boundary after #663

P0-B5  Phase-0 closeout join audit
       enumerate every remaining required join after #718;
       distinguish already-satisfied evidence from true source debt

P0-B6  post-EXIT reviewed integration freshness
       re-audit #423 + #446-A reviewed blobs against then-current main;
       confirm the smallest #299 wrapper and triggered validation

P0-B7  R1 launch freshness
       verify #446-B / #410-P / #448-A / #400 source packets,
       collisions, runners, and first refill #401-C1
```

Rules for this backlog:

- each item should produce **new exact source/test/scheduling facts**, not duplicate prose;
- skip an item that has already been fully frozen against the same accepted main and no relevant source moved;
- if an audit discovers a real contradiction, record it and continue with independent backlog items;
- do not open production branches, implementation WIP, review takeover, wrappers, or PM acceptance while Gate 0 says no claim;
- existing tests may be run read-only to establish baseline health;
- after finishing P0-B1..B7, stop only if no newer board movement creates another high-value preflight item.

The exact external transition currently expected to resume source execution is:

```text
#539 final #281 classification or explicit REVIEW WIP release
```

## Blocked-mode pass completed — 2026-09-22

A full live-repository blocked-mode pass has now completed against:

```text
main = 1c258ab681023d296425a574f769a4f73841ebf9
```

with P0-B1 through P0-B7 materially exhausted.

Do **not** repeat the whole pass on the same accepted main merely because Gate 0 is still closed. Reopen only the affected item when one of these changes:

- accepted `main`;
- #539 review state / #433 source head;
- a controlling issue comment for the packet;
- active PR/path ownership;
- executable workflow/runner topology.

Current captured results:

```text
P0-B1  #539/#433
        blocker unchanged:
        #539 REVIEW WIP=1
        no final #281 classification / release
        PR #530 frozen at 825f538d...
        9 paths; no direct accepted-main path drift

P0-B2  #807/#601
        one atomic paired candidate
        19-path common lower bound
        + branch-dependent 20th root-package fixture path
        only expected open-PR collision is predecessor #530

P0-B3  #663
        controlling prospective lower bound = 10 paths
        NOT older 9-path shorthand

P0-B4  #718
        controlling prospective lower bound = 5 paths
        #663 semantic-RNG test remains read-only
        no current open-PR collision

P0-B5  Phase-0 closeout
        no hidden source packet after accepted #718
        -> PM/review/train/CI closeout
        -> recheck ten #752 exit criteria
        -> confirm #715/#717 not promoted by a concrete blocker
        -> confirm hotspot fan-out
        -> explicit PHASE-0 EXIT

P0-B6  reviewed post-exit foundations
        #423 f3c84590... / #440 TRAIN-READY remains fresh
        #446-A b8e88184... / #467 PM-LANDING-READY remains fresh
        PR #460 overlap is historical/unreviewed and not landing authority

P0-B7  R1 launch
        #446-B = 7 paths
        #410-P = 4 paths
        #448-A = 4 paths
        #400 early source/data/test = disjoint from shared runner/workflow
        four initial worker packets are mutually path-disjoint
        #397 PM lane remains path-fresh
        #401-C1 = 9 paths; expected inherited structural-test overlap with #397 only
```

### #663 controlling 10-path packet

Current authority is #663 comment `5722151418`, reinforced by later #663 comments.

```text
1.  worldgen/surface/terrain_generator.gd
2.  worldgen/surface/pickup_generator.gd
3.  worldgen/versioning/generator_manifest.gd
4.  worldgen/migration/legacy_v2_surface_resolver.gd
5.  worldgen/migration/prototype_v2_save_migrator.gd
6.  NEW tests/surface_contract/test_surface_semantic_rng_contract.gd
7.  tests/run_surface_contract.gd
8.  tests/foundation/test_legacy_v2_migration.gd
9.  tests/generator_manifest/test_root_identity_package.gd
10. tests/foundation/test_manifest_and_graph.gd
```

The extra migrator path preserves frozen historical candidate-capacity / replay semantics instead of letting current Surface defaults become legacy-v2 authority.

### Validation-index drift discovered

Accepted `docs/60_validation/VALIDATION_MATRIX.md` currently says there are **five** workflow files, but live accepted `.github/workflows/` contains **31** workflow files.

Therefore:

```text
workflow YAML + runner scripts = executable authority
VALIDATION_MATRIX.md          = stale quick-reference for inventory/count coverage
```

Do not use the document's five-workflow inventory to under-run CI or infer trigger coverage. For a candidate, inspect the actual changed paths against live workflow YAML and use the owning runner/PASS markers.

This documentation drift is real debt but is not permission to mutate validation docs inside an unrelated production packet.

### Current blocked-mode stop condition

At this snapshot, material P0-B1..B7 preflight is exhausted.

The next source-execution transition still requires:

```text
#539 final #281 classification
OR
explicit REVIEW WIP=0 release
```

Until that state changes, a new long run should perform **delta-only** audits rather than replay this completed pass.

## Review-pool state changed — #539 is now claimable

Project staffing is now the active PM context plus the active Codex worker context.

The historical #539 reviewer context is unavailable and was administratively released under #281 continuity rule `5769754751`.

Current authoritative state:

```text
#539
  REVIEW WIP=0
  ORPHANED-RELEASED
  READY for exactly one new independent reviewer

review target:
  PR #530
  825f538d9da0c67f7691f7ffb0a6830286286ee5
  9 paths
```

Therefore the active Codex context should **not** remain in blocked preflight merely because #539 used to be protected.

If the active Codex context did not implement any part of frozen #433 source, the next lawful action is:

```text
claim #539 under #281
-> REVIEW WIP=1
-> independently review exact frozen #433 source
-> consume accumulated findings as evidence, not verdict
-> return one final #281 classification
-> REVIEW WIP=0
```

The reviewer must not edit/rebase/merge PR #530.

After the classification:

```text
PM-LANDING-READY / TRAIN-READY
  -> PM/#299 latest-main wrapper and acceptance flow

REPAIR-REQUIRED
  -> same #433 branch / PR #530 resumes for bounded repair
  -> new freeze
  -> same #539 rereview

SYNC-ONLY
  -> same #433 branch absorbs only identified semantic overlap
  -> new freeze / same #539 rereview

RUNNER-PENDING
  -> keep source immutable; complete exact-head evidence
```

This replaces the prior blocked-mode stop condition that required an external #539 reviewer event.

## First post-EXIT integration car

The controlling R1 execution handoff currently starts with:

```text
PM / reviewed integration
  #423
  + #446-A
-> accepted #423 + #446-A
```

This is not a reason for workers to start later packets from a pre-wrapper head.

## Initial four-worker pack

After explicit Phase-0 EXIT and accepted `#423 + #446-A`, the preferred full-capacity implementation set is:

```text
#446-B
|| #410-P
|| #448-A
|| #400 early source/data
```

At the same time, the PM/integration lane may land the reviewed `#397` Theme wrapper.

These four workers are preferred when all are lawful. They are **not reserved slots**.

If one is blocked at claim time:

```text
take another lawful direct-R1 packet
else nearest lawful disjoint R1b/R2/V3 prepay
```

Do not idle.

## R1 refill after #397

When `#397` is accepted:

```text
#397
-> #401-C1
```

If `#401-C1` is source-ready, it should take the first normal freed worker slot while R1 remains incomplete.

Do not preempt an existing immutable claim.

Do not hold a worker idle waiting for `#397`.

## R1 host braid

Current host-side progression is:

```text
#446-B
+ #410-P
-> #446-C
-> #410-R
-> #455
-> O1
```

Read each issue before implementing; the diagram is a scheduling summary, not a substitute for its frozen contract.

## R1 screen braid

Current screen-side progression is:

```text
#397
-> #401-C1

#400 source/data
+ #401-C1
-> I0A
```

For `#400`, keep the early packet source/data-only. Shared runner/workflow registration remains accepted-head-relative after `#448-A`; add only the smallest registration delta actually required.

Do not force a historical runner/workflow edit if accepted discovery already reaches the focused test.

## R1 rejoin

Current product rejoin:

```text
O1
+ I0A
-> I0B
-> R1 ordinary-player witness
```

Preferred `I0B` production home is the already-existing:

```text
app/game/composition/interface_composition.gd
tests/presentation/test_app_shell_contract.gd
```

Do not pre-author a new AppRoot/Game fallback, UI registry, or inventory composition manager.

If accepted O1 topology cannot expose a lawful registration seam, STOP/re-audit instead of widening by default.

## R1 acceptance truth

R1 credit requires the actual production route:

```text
AppRoot NEW / Continue
-> semantic inventory_toggle
-> real Inventory screen
-> canonical carried items visible
-> close / reopen coherent
```

Source acceptance alone is not R1.

## Spare / disjoint prepay while R1 executes

Direct R1 work wins equal-ready contention.

When capacity is genuinely disjoint, current board authority allows preparation of later work such as:

- the R1b Equipment braid;
- Crafting C1 / direct R2 prerequisites;
- `#564`, `#585`, `#490`, `#489-BT` where their exact issue contracts and paths are ready;
- V3a query/terrain foundations.

Do not use this list as blanket authorization. Re-read the live `#33` comments and each target issue.

## Current R1b cross-milestone mutex

The current board records a real shared test collision between `#657-EQ-S` and `#657-S` at:

```text
tests/content/test_weapon_runtime_production.gd
```

While R1b is incomplete, equal-ready contention currently prefers `#657-EQ-S`.

After that shared turn, `#657-EQ` and `#657-S` may proceed independently when their own predecessors/paths allow.

Do not turn this one test-file serialization into a semantic dependency between the two rails.

## Current V3a Surface braid

The current controlling scheduling shape is approximately:

```text
#513
-> #564

S0
-> SB || SP

if SB + SP and SQ / #512-T are both ready:
  SQ first
  -> SR || #512-T

generated branch:
  #565 -> #566
  interleaves on free Surface turns

pristine physical join:
  SB + #512-T PASS + #566
  -> SC
```

At Fiber visibility, current terrain semantic evidence and coherent physical/currentness authority must both be present together with generated occluders and the current clear-segment reducer.

Do not invent a Fiber-specific terrain solver.

## Post-R1 priority spine

When R1 is genuinely complete, continue nearest-player scheduling:

```text
R1b
-> R2
-> V3a
-> V3b
-> V3c
-> V4a
-> V4b
-> V5
```

Do not jump to V6 breadth because its architecture is interesting or already source-shaped.

## Later runtime planning already frozen

A large amount of later creature/runtime architecture is already definition-complete.

Important interpretation:

- `#488-RR` owns LIVE publication/currentness;
- sensing, behavior, route sessions, and motion are downstream consumers rather than one giant publication prerequisite;
- shared `tests/run_character.gd` use creates a source mutex, not a fake semantic chain;
- final production Game chronology is a later composition concern.

When those packets become near-term work, reread their latest issue comments rather than redesigning them.

## Evidence-only waits

Do not choose placeholder product values for branches whose current board status is evidence-selected.

Current examples include:

- worldspace/global relationship and classifier values;
- production residency `RP_prod`;
- Building-pressure integrity/impact/grace values;
- final physical envelope / presentation-performance evidence where designated.

Implement lawful measurement/support work, then continue elsewhere until selection authority exists.

## Controlling PM references at snapshot

Useful central comments at the time this file was created:

```text
#33
  5768406748  R1 source-topology closeout
  5768421884  reviewed-integration pipeline
  5768428349  post-wrapper-1 full-capacity pack
  5768501152  R1 execution handoff

#886
  5766674815  Player-truth scoreboard V4
  5767671842  late-project architecture freeze
  5767966514  acceptance-coverage audit
```

These identifiers help locate the handoff. They are not a substitute for checking whether newer comments superseded them.

## Refresh procedure

At the start of a Codex work period:

1. compare current `main` to the baseline above;
2. fetch latest `#33` and `#886` comments;
3. mark already accepted packets as complete;
4. recalculate path mutexes from actual accepted source and active PRs;
5. identify the nearest incomplete player truth;
6. form a new ready set;
7. update this file only when the scheduling snapshot itself is intentionally being revised.

If the live board disagrees with this file, follow the live board and report the stale queue document.
