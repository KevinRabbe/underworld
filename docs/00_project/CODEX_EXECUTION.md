# Underworld — Codex Long-Run Execution Protocol

Status: execution/orchestration guidance for autonomous coding agents.

This document explains **how to work for a long stretch without losing the PM architecture**. It does not replace issue-level source freezes, the Development Rulebook, or the merge gate.

## Objective

Optimize for:

```text
accepted implementation
+ focused proof
+ regression safety
+ ordinary-player reachability
```

Do not optimize for:

```text
lines changed
number of branches
number of partially implemented systems
```

## Multi-agent shape

A long Codex run may use several agents in parallel, but each agent owns one coherent source packet at a time.

Recommended roles:

```text
worker A   nearest player-truth packet
worker B   disjoint sibling packet
worker C   disjoint prerequisite/prepay packet
worker D   disjoint prerequisite/prepay packet

review/integration lane
           PM-reviewed wrappers, accepted-head rebases,
           conflict reconciliation, exact-head verification
```

The role labels are temporary. Refill them continuously; do not reserve a lane for a blocked future task.

## Session bootstrap

At the beginning of a long run:

1. fetch current `main` and record its SHA;
2. read root `AGENTS.md`;
3. read the current queue snapshot;
4. inspect the latest comments on central board issues, especially `#33` and `#886`;
5. inspect the issue for every candidate packet;
6. list active branches/PRs that may own shared paths;
7. determine the nearest incomplete player-visible truth;
8. build a ready set from true semantic predecessors plus current path availability.

Do not start from an old saved prompt when the board has advanced.

## Readiness model

A packet is executable only when all are true:

```text
semantic predecessors accepted
+ required evidence/value already authorized
+ current accepted API can implement the contract
+ all mutable paths available
+ governance permits work
= READY TO IMPLEMENT
```

Do not confuse "definition complete" with source readiness.

Do not confuse "source ready" with milestone acceptance.

## Refill algorithm

Whenever a worker finishes or becomes blocked:

1. identify the nearest incomplete serial player truth;
2. find ready packets that directly shorten that truth;
3. among equal-ready packets, prefer the one with the largest downstream release;
4. if candidates contend on a source mutex, the nearer player truth wins;
5. if the nearer candidate is blocked, do not idle the mutex—take the next lawful candidate;
6. if no direct packet is ready, prepay a disjoint prerequisite for the next one or two player truths;
7. never manufacture semantic edges from runner/workflow/file serialization.

This means a diagram such as `A -> B -> C` is mandatory only when the issue contract says the edges are semantic. A preferred turnover order is not automatically a dependency graph.

## Accepted-head rebasing

Many late project packets are intentionally accepted-head-relative.

At claim time:

```text
read latest accepted predecessor
-> derive smallest legal adapter/composition hunk
-> compare against frozen ownership
-> implement
```

Do not preserve an obsolete file edit merely to match an old packet count.

If accepted topology exposes an existing injection/registration seam, use it and shrink the packet.

## Shared source mutexes

Treat whole-file overlap as a scheduling constraint.

Common hotspots include:

- `tests/run_character.gd`;
- presentation/UI runners and workflows;
- `app/game/game.gd`;
- persistence-state files/tests;
- shared content production tests.

Rules:

- one active immutable owner per shared path;
- siblings may resume parallel execution immediately after the shared turn;
- rebase the later packet on the accepted earlier head;
- never encode the serialization itself as a new semantic prerequisite.

## Branch / PR lifecycle

For one packet:

```text
fresh branch from accepted main
-> implementation
-> focused validation
-> regression validation
-> draft PR
-> CI
-> source/contract handoff
-> synchronize with current main if required
-> PM exact-head review
-> explicit PM acceptance
-> merge
```

Workers do not self-merge.

Workers do not apply `pm-accepted`.

When another PR advances `main`, re-read the accepted source before resolving conflicts. Do not blindly replay a stale patch.

## Validation strategy

Run the cheapest authoritative focused proof first, then expand.

Typical sequence:

```text
parser/import sanity where relevant
-> packet-focused runner
-> owning-domain runner
-> integration runner(s) triggered by changed paths
-> broad required CI for review
```

Use `docs/60_validation/VALIDATION_MATRIX.md` and workflow YAML for exact commands and PASS markers.

Do not rewrite product behavior to satisfy a presentation-only test. Diagnose failures by invariant owner using `TEST_SUITE_INDEX.md`.

## Player-visible acceptance

Source completion is not the end of the chain.

When a milestone contract requires an ordinary-player witness, distinguish:

```text
source landed
integration landed
automated contracts green
production route reachable
ordinary-player witness passed
```

Only the last applicable state earns player-truth credit.

## Architecture contradiction protocol

If implementation uncovers a real contradiction, produce a bounded report:

```text
issue / packet
accepted main SHA
frozen contract
exact required source paths
exact incompatible accepted API/source
why an adapter cannot solve it inside ownership
smallest plausible correction
downstream packets affected
independent work that can continue
```

Do not fix the contradiction by adding a generic manager or bypass.

## Evidence-selected values

Some late Biome-1 values intentionally wait governed evidence, including worldspace, production residency, and Building-pressure selections.

Codex may implement the measurement machinery and candidate matrix when authorized.

Codex must not choose the final product value merely to unblock source.

Continue other source-closed work during evidence waits.

## Long-run completion rule

A productive autonomous run ends with a set of independent facts such as:

```text
N coherent packets implemented
N focused suites passing
draft PRs ready for PM review
specific blocked packets with exact reasons
nearest player-visible milestone measurably closer
```

It should not end with a giant cross-cutting branch that mixes unrelated systems.

## Handoff format

At checkpoints, summarize:

```text
ACCEPTED SINCE START:
READY FOR REVIEW:
ACTIVE:
BLOCKED:
NEXT READY SET:
NEAREST PLAYER TRUTH:
TEST / CI HEALTH:
PM DECISIONS NEEDED:
```

"PM decisions needed" should be empty unless a genuine STOP condition was reached.
