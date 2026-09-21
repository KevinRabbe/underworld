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
