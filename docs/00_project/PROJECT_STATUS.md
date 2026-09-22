# Underworld — Project Status

<!-- PROJECT_STATUS_PLAYABLE_STATE: NOT_YET -->
<!-- PROJECT_STATUS_ACCEPTED_MAIN: 1c258ab681023d296425a574f769a4f73841ebf9 -->
<!-- PROJECT_STATUS_WORLD_MODEL: OVERWORLD+UNDERWORLD_CONTINUOUS_BIOMES -->

Last synchronized: **2026-09-17**  
Accepted main at synchronization: **`1c258ab681023d296425a574f769a4f73841ebf9`**

> This file is a checked-in snapshot for quick orientation. Live GitHub authority in #33, #281, #299 and the linked milestone issues supersedes it when newer.

## Playable state

**Playable now? NOT YET — no accepted Core Playable build exists yet.**

The repository contains substantial production-facing foundations and older prototype playtest surfaces, but the current delivery target is the first accepted **Core Playable** production loop, not the historical `Prototype 0.02` milestone.

Current mode: **Core Playable integration / two-domain topology rebaseline**.

## Current hard gate

**#539 — protected independent review of the frozen gateway-definition source (`REVIEW WIP=1`).**

The next controlling transition is:

```text
consumable #539 verdict
-> accepted #433 disposition
-> re-derive/lock downstream geometry work
-> topology-critical Core implementation can advance under normal ownership/review
```

The status surface must not pre-judge the #539 review outcome.

## Current world model

The game world has exactly two gameplay domains:

```text
OVERWORLD
UNDERWORLD
```

The **Underworld is one continuous generated world/root containing multiple biomes/regions**. It is not three independent Underworld maps, domains, save spaces or generation roots.

Moving from one Underworld biome to another is ordinary movement/streaming inside the same world. Only `OVERWORLD <-> UNDERWORLD` travel is a domain transition.

Current scale direction is approximately:

```text
Overworld  ~40% of intended combined exploration allocation
Underworld ~60%
```

That split is a product-direction target, **not** a literal radius or diameter rule. #874 owns the measured definition, dimensions and performance budgets.

## Delivery ladder

| Milestone | State | Authority | Meaning |
| --- | --- | --- | --- |
| Phase 0 architecture exit | **IN PROGRESS** | #752 | Architecture/world-runtime exit conditions are not all accepted yet. |
| Core Playable | **NOT ACHIEVED** | #752 / #754 | Smallest complete production loop is not yet accepted. |
| First Playable | **NOT ACHIEVED** | #586 | Broader product breadth, biome traversal and scale follow Core. |

No arbitrary overall percentage is reported. A numeric progress value is allowed only when it is mechanically derived from an explicit finite gate set committed beside this status data.

## Continuous-Underworld topology program

The current topology umbrella is **#871**. Its Core-facing migration packet is:

| Issue | Responsibility | Current snapshot state |
| --- | --- | --- |
| #872 | deterministic continuous biome regions/transitions | PLANNED |
| #873 | remove/migrate obsolete discrete layer identity | PLANNED |
| #875 | map gateways into one continuous Underworld root | PLANNED |
| #876 | version manifest/root/SAVE compatibility | PLANNED |
| #877 | minimum biome-aware encounter/resource placement | PLANNED |
| #878 | production-route continuity + Save/Continue proof | PLANNED |

**#874** is split by milestone: Core needs only a bounded representative production profile; final 40/60 dimensions, large-world traversal and stress evidence belong to First Playable/#586.

Existing **#807/#601** cave geometry correctness remains relevant inside the continuous Underworld. Their exact downstream packet remains conditional on the accepted #539/#433 disposition.

## What Core Playable must prove

The current Core Underworld proof is conceptually:

```text
ordinary OVERWORLD gameplay
-> semantic gateway
-> committed UNDERWORLD
-> one continuous Underworld root/context
-> traverse generated cave cells
-> cross/observe at least one biome transition
-> no domain/root/gateway transition at the biome boundary
-> one accepted Underworld resource/encounter path
-> Save & Quit while UNDERWORLD
-> direct Continue in the same Underworld state
-> paired semantic return to OVERWORLD
```

The amount of biome traversal remains deliberately small for Core. Broad exploration and final-scale tuning are First Playable work.

## Where to look for live authority

- **#33** — board / PM synchronization
- **#281** — independent review governance
- **#299** — integration/landing authority
- **#752** — Core Playable definition
- **#754** — Core gap audit / finite gate definition
- **#586** — First Playable
- **#871** — two-domain continuous-Underworld topology
- **#879** — repository-visible status implementation

Machine-readable companion: [`project_status.json`](project_status.json).

## Updating this status

1. Reread the live controlling issues before changing the snapshot.
2. Update `project_status.json` first.
3. Update this file and the README status markers to match it.
4. Run `python3 tools/ci/validate_project_status.py`.
5. Review the status change like ordinary source. Do not make gameplay runtime depend on these PM files.
