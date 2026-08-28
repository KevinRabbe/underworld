# Underworld — Main Merge Gate

Status: **repository-governance contract / operational same-principal guard**

This document defines the repository merge-control baseline for `main`.

It does **not** claim source-isolated PM authorization under the current GitHub identity model. The current `PM acceptance` status is useful as an operational workflow guard, but ordinary same-repository GitHub Actions can run as the same GitHub Actions App and can request `statuses: write`. A PR-controlled workflow could therefore publish the same commit-status context name.

That limitation is explicit and must not be hidden by wording such as “trusted authorization” or “cryptographically enforced PM approval.”

## Current policy

Normal merge eligibility is intended to require:

```text
required broad CI
+ operational exact-head PM acceptance signal
+ non-draft pull request
+ branch up to date with protected main
+ pull-request-only main updates
= operationally merge eligible
```

Green CI is necessary but never sufficient by project policy.

The repository-owner ruleset must also require the PR branch to be up to date before merge. A reviewed/green SHA must not land after `main` has advanced without being synchronized and revalidated.

## Required status contexts

The final `main` ruleset should require these exact stable contexts:

| Purpose | Required context |
| --- | --- |
| Character validation | `Godot character contracts` |
| Repository layout validation | `Repository layout contracts` |
| Deterministic Worldgen aggregate | `Godot headless contracts` |
| Operational PM gate | `PM acceptance` |

The first three contexts are normal CI evidence.

`PM acceptance` is an **operational process-control context**, not source-isolated authorization while it is emitted by the same GitHub Actions identity available to ordinary repository workflows.

Do not configure individual deterministic matrix shard names as branch requirements. Require only the stable aggregate `Godot headless contracts`.

## Deterministic Worldgen aggregate

`.github/workflows/foundation-validation.yml` preserves the complete deterministic campaign as ten shards:

```text
start seeds: 1, 26, 51, 76, 101, 126, 151, 176, 201, 226
count per shard: 25
region radius: 1 = 3x3 regions
```

Together this remains:

```text
250 seeds × 9 regions = 2,250 seed/region cases
```

Each shard runs the fast deterministic contracts followed by its 25-seed batch.

A final job named exactly:

```text
Godot headless contracts
```

runs with `if: always()` after the matrix and fails unless the matrix result is `success`.

This gives branch rules one stable required context while preserving every shard.

## Operational PM acceptance workflow

The project workflow is `.github/workflows/pm-acceptance-gate.yml`.

It runs from `pull_request_target`, which means the workflow definition comes from the trusted base/default branch rather than from the candidate PR branch.

The workflow itself therefore has an important execution-safety boundary:

- it never checks out the PR branch;
- it never executes PR-controlled repository code;
- it queries PR metadata through the GitHub API;
- it binds decisions to the event head and live PR head;
- it uses per-PR concurrency;
- it rechecks live state before granting success;
- it rechecks state after publishing success;
- only an explicit `labeled: pm-accepted` event may grant success;
- synchronize, draft transitions, and acceptance removal fail/revoke;
- unrelated label events cannot grant acceptance.

Those properties protect the normal project process against stale events, accidental acceptance reuse, and event-order races.

They do **not** source-isolate the status context from another same-repository GitHub Actions workflow.

## Source-isolation limitation

The remaining trust limitation is external to the workflow logic itself.

A same-repository PR can modify or add a normal GitHub Actions workflow. If repository policy allows that workflow to request:

```yaml
permissions:
  statuses: write
```

then that workflow executes as the same GitHub Actions App identity used by the operational PM workflow and can call the commit-status API with:

```text
context = PM acceptance
```

Therefore the context name alone does not prove that the status came from the intended `pull_request_target` workflow.

Binding the required status to the GitHub Actions App does not fix this, because both the intended workflow and a PR-controlled workflow use the same App identity.

### Consequence

Under the current identity model:

```text
PM acceptance = operational same-principal guard
```

It is **not**:

```text
PM acceptance = actor-separated authorization boundary
```

The current mechanism is still useful for preventing ordinary accidental merges and for making the intended PM lifecycle machine-readable, but it must not be represented as resistant to a malicious or intentionally bypassing same-repository workflow with equivalent Actions permissions.

## Path to true PM authorization

True source-isolated PM authorization requires a source ordinary PR workflows cannot mint.

Acceptable future mechanisms include one of the following:

1. a distinct GitHub App whose private key/installation credentials are unavailable to ordinary repository workflows;
2. an external CI/service identity that publishes the required status and is source-bound in the branch ruleset;
3. an owner-controlled approval mechanism whose credentials or approval authority are unavailable to worker/PR workflows;
4. another GitHub-supported authorization primitive that provides equivalent actor separation.

When such a mechanism exists, update this document and the ruleset so the required PM gate is tied to that isolated source.

Until then, do not claim technical authorization against ordinary GitHub Actions.

## Exact-head operational semantics

Even though the status is not source-isolated, the intended PM workflow still enforces exact-head lifecycle semantics for normal project operation.

### Per-PR coordination

Runs use one concurrency group per PR:

```text
pm-acceptance-<repository>-<pr-number>
```

with `cancel-in-progress: true`.

Newer PR-state events supersede older in-progress runs for the same PR.

### Superseded-head guard

Every run compares:

```text
event head SHA
vs.
live PR head SHA
```

A delayed event for SHA A exits without mutating acceptance state for newer SHA B.

### Only explicit acceptance may grant

Success is possible only for:

```text
event action = labeled
event label = pm-accepted
```

and only when the live PR still satisfies all of:

- event head equals current head;
- PR is non-draft;
- `pm-accepted` is currently present.

The workflow re-reads the PR immediately before the grant decision and again after success publication.

### Synchronize invalidates

A current-head synchronize event:

- removes stale `pm-accepted` when present;
- verifies it is absent;
- publishes `PM acceptance = failure` on the synchronized head.

A later explicit acceptance action is required for the new head.

### Lifecycle events cannot resurrect acceptance

`opened`, `reopened`, `ready_for_review`, and `converted_to_draft` do not reinterpret a persisted label as a new approval.

They publish failure for the exact current head.

### Acceptance removal revokes

Removing `pm-accepted` publishes failure for the exact current head.

Unrelated label changes cannot grant success.

## Required `main` ruleset

Create one active branch ruleset targeting only the default branch / `refs/heads/main`.

Required behavior:

- require a pull request before merging;
- require branches to be up to date before merging;
- require `Godot character contracts`;
- require `Repository layout contracts`;
- require stable `Godot headless contracts`;
- require operational `PM acceptance` if the team chooses to keep this same-principal process guard;
- block ordinary direct pushes to `main`;
- block force pushes;
- block branch deletion;
- do not require impossible same-user self-approval;
- do not grant ordinary workers or broad Actions workflows permanent bypass rights.

### Why “up to date” is mandatory

Suppose SHA A is fully reviewed and green, then `main` advances to SHA M.

Without an up-to-date requirement, A could potentially merge without validating the combined A+M state.

Required behavior is:

```text
reviewed PR head A
        ↓
main advances to M
        ↓
PR becomes out of date
        ↓
synchronize/rebase/merge current main
        ↓
new exact PR head B
        ↓
rerun required CI
        ↓
repeat PM review/acceptance for B
```

A stale reviewed head must never remain merge-eligible solely because its earlier checks were green.

## Normal acceptance lifecycle

```text
worker opens draft PR
        ↓
broad CI runs
        ↓
worker hands off to REVIEW
        ↓
PM reviews exact current head
        ↓
PR becomes non-draft when appropriate
        ↓
PM explicitly adds pm-accepted
        ↓
operational gate checks exact live state
        ↓
PM acceptance may become success
        ↓
branch must also be current with main
        ↓
all required checks green on current head
        ↓
ruleset permits merge
```

If `main` moves or the PR head changes, synchronize and revalidate.

## Same-principal limitation

The current PM and worker automation share the repository owner/App permission surface.

Therefore:

- `pm-accepted` is an operational role signal;
- `PM acceptance` is an operational status signal;
- neither is cryptographic actor separation;
- a principal with equivalent write permission can apply the label;
- a same-repository GitHub Actions workflow with `statuses: write` can mint the same status context;
- the current mechanism is not intended to resist an intentionally malicious equally privileged actor.

This limitation is architectural, not a bug in the event-order workflow logic.

## Post-landing verification campaign

After the support PR lands and the owner activates the ruleset, use a disposable documentation-only PR.

### Case 1 — broad CI green, no operational acceptance

Expected:

```text
broad CI = green
PM acceptance = failure
merge = blocked by configured project rules
```

### Case 2 — explicit current-head acceptance

Expected under normal project operation:

```text
non-draft current head
+ explicit pm-accepted event
+ broad CI green
+ branch current with main
=> operational merge gate may pass
```

### Case 3 — accepted SHA A, then push SHA B

Expected:

```text
PM acceptance = failure on B
stale pm-accepted removed
B blocked until explicit re-acceptance
```

### Case 4 — main advances while PR is green

Expected:

```text
PR becomes out of date
merge blocked
synchronize required
all required checks rerun on new head
```

### Case 5 — reordered same-head events

Exercise labeled/unlabeled/synchronize ordering around one SHA.

After events settle:

```text
pm-accepted absent => intended operational PM acceptance is not success
```

### Case 6 — unrelated labels

Unrelated label events must never grant operational acceptance.

### Case 7 — draft transition

An accepted PR converted back to draft must fail the operational PM gate and require fresh acceptance after returning to ready.

### Case 8 — deterministic aggregate

All ten deterministic shards must run. One controlled shard failure must cause:

```text
Godot headless contracts = failure
```

### Case 9 — direct push

A normal direct push to `main` without administrative bypass must be rejected.

### Case 10 — trust-boundary assertion

Explicitly record that the current campaign does **not** prove source-isolated PM authorization while ordinary repository Actions can mint the same status context.

Do not mark that stronger property as tested or satisfied until a distinct trusted identity exists.

## Connector limitation

The connected GitHub tooling can read rulesets/protection but does not expose a write action for creating or activating the final repository ruleset.

Therefore #118 has two practical layers:

1. in-repository operational workflow/documentation support;
2. repository-owner ruleset activation and verification.

A future source-isolated PM authorization mechanism is a separate trust-boundary upgrade unless an external identity is supplied during this task.

## Owner activation checklist

- [ ] `Underworld main merge gate` exists and is Active
- [ ] target is only default branch / `main`
- [ ] pull request required before merge
- [ ] branch required to be up to date before merge
- [ ] direct push restricted for normal workflow
- [ ] force push blocked
- [ ] branch deletion blocked
- [ ] `Godot character contracts` required
- [ ] `Repository layout contracts` required
- [ ] stable `Godot headless contracts` required
- [ ] operational `PM acceptance` configured if retaining the same-principal guard
- [ ] no ordinary worker/Actions bypass actor configured
- [ ] no self-approval rule that deadlocks the current same-account model
- [ ] exact-head invalidation campaign passed
- [ ] out-of-date branch rejection verified
- [ ] same-head reordered-event campaign passed
- [ ] unrelated labels proven unable to grant through the intended workflow
- [ ] draft behavior verified
- [ ] failed-shard aggregate behavior verified
- [ ] direct-push rejection verified
- [ ] limitation that same-repo Actions can mint the same status context is explicitly recorded

## Invariants

1. Green CI is necessary but not sufficient by project policy.
2. The intended PM workflow executes only trusted default-branch workflow code and never PR-controlled code.
3. Only explicit `labeled: pm-accepted` may grant success through the intended workflow.
4. Synchronize and acceptance removal revoke/fail through the intended workflow.
5. Same-PR workflow runs are coordinated and live state is rechecked at the grant decision point.
6. Superseded old-head events do not mutate the newer head through the intended workflow.
7. The `PM acceptance` context is **not source-isolated** from other same-repository GitHub Actions under the current identity model.
8. Required-status App binding to the shared GitHub Actions App does not create actor separation.
9. True PM authorization requires a distinct trusted identity or equivalent owner-controlled mechanism.
10. The deterministic campaign remains ten 25-seed shards covering 2,250 seed/region cases.
11. `Godot headless contracts` is the stable deterministic aggregate required by branch rules.
12. Merge eligibility requires the PR branch to be up to date with `main`.
13. Normal updates to `main` use pull requests only.
14. Force pushes and branch deletion are not normal workflow.
15. Emergency bypass is temporary, explicit, narrow, and recorded.
16. Governance rules never authorize violating architecture, dependency, or protected-roadmap contracts.
17. No MAP-009→MAP-015 production/runtime contract is changed by this governance mechanism.
