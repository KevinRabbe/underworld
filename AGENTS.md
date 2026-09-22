# Underworld — Codex Agent Contract

This file is the persistent execution contract for coding agents working in this repository.

The goal is **maximum tested, accepted, player-reachable progress**, not maximum code volume.

## Required reading

Before starting implementation work, read:

- `docs/DEVELOPMENT_RULEBOOK.md`
- `docs/60_validation/MAIN_MERGE_GATE.md`
- `docs/60_validation/VALIDATION_MATRIX.md`
- `docs/60_validation/TEST_SUITE_INDEX.md`
- `docs/00_project/CODEX_EXECUTION.md`
- `docs/00_project/CODEX_CURRENT_QUEUE.md`

For a numbered task, also read the GitHub issue and its newest controlling PM/source-freeze comments before editing source.

The queue file is a snapshot, not permanent authority. Refresh it against the live issue board whenever `main` advances or a predecessor lands.

## Authority and conflicts

The project has extensive frozen architecture and source-planning decisions.

Do not redesign a subsystem merely because implementation is difficult.

Use this rule:

1. explicit current product authority;
2. current controlling PM ruling for the task;
3. frozen task/source contract that has not been superseded;
4. accepted predecessor interfaces and repository architecture docs;
5. implementation detail chosen locally inside those boundaries.

A newer comment does not automatically erase every older invariant. Treat it as controlling only where it explicitly supersedes, corrects, narrows, or extends prior authority.

If accepted source makes a frozen contract impossible, **STOP only the affected packet** and report the exact contradiction. Continue unrelated lawful work.

## Architecture mode

Default project mode is execution/evidence, not speculative design.

Do not introduce a new manager, registry, service, ownership layer, persistent field, gameplay authority, or generic abstraction unless an accepted source contradiction requires it or the controlling issue explicitly owns it.

Prefer the smallest implementation that realizes the existing contract.

Do not turn an evidence wait into a design task. Values designated for governed measurement/playtest selection stay open until that evidence exists.

## Repository governance

Never push directly to `main`.

Use one isolated branch/draft PR per coherent task packet unless the controlling PM ruling explicitly groups work.

Do not merge your own PR.

Do not apply or manufacture `pm-accepted`.

A new commit invalidates prior PM acceptance for that PR head. This is intentional.

Keep branches synchronized with accepted `main` before final review when required by repository governance.

## Path ownership

Frozen source packets are ceilings, not invitations to widen scope.

Before editing:

1. reread the accepted predecessor;
2. verify every planned path is still necessary;
3. verify another active task does not own the same mutable path;
4. shrink the packet if accepted topology makes a planned edit unnecessary;
5. stop and report if an additional mutable path is semantically required beyond a frozen hard ceiling.

Shared runners, workflows, `Game`, UI architecture tests, persistence files, and similar hotspots are source mutexes. A source mutex does **not** create a semantic dependency between otherwise independent tasks.

Never create a fake dependency just to explain a shared file.

## Implementation discipline

For each packet:

1. establish the exact issue/contract and accepted predecessor head;
2. inspect the files before changing them;
3. implement the smallest legal delta;
4. preserve determinism/currentness/persistence invariants;
5. add or update the focused tests owned by the packet;
6. run the focused validation;
7. run relevant integration/regression validation;
8. inspect the diff for accidental scope;
9. commit a coherent, bisectable unit;
10. leave a concise task report.

Do not perform unrelated cleanup or opportunistic refactoring inside a packet.

Do not weaken, delete, skip, or rewrite an invariant merely to make a test green.

## Determinism and persistence

The locked development rulebook remains mandatory.

In particular:

- no gameplay/generation authority may depend on frame timing, thread scheduling, unordered iteration, or incidental array position;
- persistent identity must use stable semantic addresses/IDs;
- untouched procedural content regenerates from seed;
- persistence remains delta-based unless explicitly revised;
- engine object identity, Node paths, RIDs, and temporary runtime handles are not durable semantic identity;
- fail closed when currentness evidence is incomplete where the owning contract requires it.

## Validation

Repository workflows and runners are executable authority for test commands.

Godot baseline is currently **4.7.2**.

For presentation/App Shell changes, import resources first when the relevant workflow does so:

```bash
godot --headless --editor --path . --quit
```

Examples of focused runners:

```bash
godot --headless --path . --script res://tests/run_app_shell.gd
godot --headless --path . --script res://tests/run_ui_architecture.gd
godot --headless --path . --quit-after 1 --script res://tests/run_inventory.gd
godot --headless --path . --quit-after 1 --script res://tests/run_crafting.gd
godot --headless --path . --quit-after 1 --script res://tests/run_character.gd
```

Use the exact workflow command and PASS marker for the domain you changed. Consult `VALIDATION_MATRIX.md` rather than guessing.

A runner process exiting zero is not sufficient when the workflow also checks for script errors and a domain-specific PASS marker.

Before review, run all feasible required checks triggered by the changed paths. Do not alter workflow path filters or required checks merely to reduce cost.

## Standing mission

The standing autonomous mission is:

```text
CURRENT STATE
-> complete the mandatory Phase-0 tail
-> explicit PHASE-0 EXIT
-> complete Overworld Biome 1
-> earn final #499 Biome-1 acceptance
```

Do not stop merely because one task, review, PR, milestone rung, or implementation packet completes.

After every completion/review/landing/blocker change:

1. refresh accepted `main` and the controlling board comments;
2. identify the nearest incomplete player truth or required Phase-0 predecessor;
3. build the lawful ready set;
4. claim/execute the highest-priority lawful packet within governance;
5. refill immediately when the packet ends;
6. if source work is temporarily blocked, enter BLOCKED / PREFLIGHT delta-only mode;
7. continue until the mission-level stop condition below is reached.

Mission-level stop conditions are only:

```text
A. #499 explicitly accepts complete Overworld Biome 1
OR
B. remaining progress requires a genuine owner/PM/evidence decision
   that cannot be derived from existing authority,
   and no material lawful implementation/review/preflight work remains
OR
C. project owner explicitly changes or pauses the mission
```

A completed intermediate milestone such as Phase-0 EXIT, R1, R1b, R2, V3a, V3b, V3c, V4a, V4b, or V5 is **not** a stop condition. It is a refill event.

The project owner should not need to send repeated "continue" messages between lawful turns.

## Player-visible priority

When two equally lawful tasks contend for finite capacity or the same path, prefer the task that shortens the nearest incomplete ordinary-player truth.

Current serial product spine:

```text
R1    real Inventory visible
R1b   real Equip / Unequip / Select
R2    real Crafting screen
V3a   gather real Fiber
V3b   craft / equip / select Primitive Axe
V3c   real Axe -> Tree -> durable Wood
V4a   Build Tool -> Workbench -> station recipe
V4b   real persistent shelter
V5    Skinning Knife -> real Boar -> Skinning -> Continue
```

Later breadth work does not jump ahead merely because its architecture is already defined.

## Write-first worker policy

Codex worker capacity is for **state-changing implementation work by default**.

Do not allocate a standalone Codex worker merely to:
- reread issues;
- summarize board state;
- enumerate paths already frozen;
- perform broad preflight;
- wait on CI;
- poll a blocker;
- write another planning report.

Read-only work is justified only in two cases:

1. **independent review** required by #281 or equivalent governance;
2. **short targeted diagnosis** needed to identify the exact write/repair that the same execution lane can perform immediately afterward.

For ordinary blocked implementation:

```text
preferred write blocked
-> take another lawful write-capable packet
-> if none exists, do only the minimum diagnosis needed to prove the blocker
-> return the worker slot rather than burning a full Codex run on read-only inventory
```

Do not create dedicated read-only "preflight workers" as latency-hiding work. Prefer implementing a disjoint accepted prerequisite, repair, test-owned source packet, integration adapter, or another player-truth feeder.

Independent reviewers remain read-only by design and must not convert themselves into implementation workers for the candidate they reviewed.

## Autonomous scheduling

Do not idle because the preferred task is blocked.

When a packet cannot lawfully proceed:

- record the blocker;
- release any source claim you do not need;
- choose the nearest lawful disjoint task from the current queue;
- preserve real dependencies and path mutexes;
- continue.

Do not reserve a worker for a future task.

Parallelize only genuinely disjoint work.

## Blocked-run mode

A closed project gate, unavailable reviewer, evidence wait, or blocked preferred packet is **not by itself permission to end a long autonomous run**.

If governance forbids the preferred source mutation, first search for another lawful **write-capable** packet. Use BLOCKED/PREFLIGHT only as a minimal fallback when no lawful write-capable work exists.

In BLOCKED / PREFLIGHT fallback, do not claim or mutate production source. Perform only the minimum read-only work needed to unlock or classify the next write-capable turn:

1. refresh live board / PR / accepted-main state once;
2. identify the exact blocking transition and owner;
3. audit the next blocked source packet against current accepted source;
4. derive the smallest current path set and likely shared-path mutexes;
5. verify focused runners/workflows and PASS markers still exist and cover the packet;
6. inspect active PRs/branches for collision or stale-base risk;
7. precompute both PASS and REPAIR/SYNC continuation plans where the blocker is a review verdict;
8. preflight the next one or two downstream packets that would become READY if the blocker clears;
9. preflight the nearest player-visible post-gate queue and identify any stale issue assumptions;
10. run existing read-only tests/validation where useful to establish baseline health;
11. produce a structured checkpoint with exact facts, not a generic "blocked" message.

Do **not** repeatedly poll the same unchanged gate in a tight loop and call that progress. Once the current blocker is proven unchanged, spend the remaining run on new preflight information that shortens future implementation/review latency.

A blocked run may end only when both are true:

```text
no lawful source mutation is authorized
AND
no material unperformed preflight/audit/test work remains in the current blocked-mode backlog
```

When ending for that reason, enumerate the preflight work completed and the single external transition that will make source execution legal.

## STOP conditions

Stop the affected packet and report instead of improvising when any of these occurs:

- accepted source contradicts a frozen semantic owner;
- the frozen path ceiling cannot implement the required theorem;
- another active immutable claim owns a required path;
- a required evidence-selected product value is not yet authorized;
- satisfying the packet requires a new persistent identity/authority not owned by it;
- a test exposes a genuine architecture contradiction rather than an implementation bug;
- the issue history is materially ambiguous after reading the controlling comments.

A STOP on one packet does not stop the whole autonomous run.

## Task report

Every completed or stopped packet should report:

```text
TASK:
BASE:
BRANCH / PR:
PATHS CHANGED:
CONTRACT IMPLEMENTED:
TESTS RUN:
RESULT:
PLAYER-TRUTH IMPACT:
BLOCKERS / FOLLOW-UPS:
SOURCE-CONTRACT DISCREPANCIES:
```

Keep reports factual. Do not claim a player-visible milestone is complete from source acceptance alone when its acceptance contract requires real production play/evidence.
