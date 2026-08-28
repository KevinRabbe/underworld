# Underworld — Main Merge Gate

Status: **repository-governance contract**

This document defines the intended enforceable merge gate for `main`. It complements the pull task board; it does not replace architecture review, dependency review, protected-roadmap ownership, or exact-head validation.

## Target policy

```text
required broad CI
+ explicit exact-head PM acceptance
+ non-draft PR
+ pull-request-only main updates
= merge eligible
```

Green CI is necessary but never sufficient by itself.

## Required `main` status contexts

Configure the final `main` ruleset to require these exact contexts:

| Source | Required context |
| --- | --- |
| Character Validation | `Godot character contracts` |
| Repository Layout Validation | `Repository layout contracts` |
| Deterministic Worldgen aggregate | `Godot headless contracts` |
| Trusted PM Acceptance Gate | `PM acceptance` |

The deterministic workflow intentionally runs ten matrix shards. Branch rules require the single aggregate context `Godot headless contracts`, not generated shard names.

## Deterministic aggregate contract

`.github/workflows/foundation-validation.yml` preserves the complete deterministic campaign as ten shards:

```text
start seeds: 1, 26, 51, 76, 101, 126, 151, 176, 201, 226
count per shard: 25
region radius: 1 = 3x3 regions
```

Together this remains 250 seeds × 9 regions = 2,250 seed/region cases.

Each shard runs the fast deterministic contracts followed by its 25-seed batch. A final job named exactly:

```text
Godot headless contracts
```

uses `if: always()` and fails unless the matrix result is `success`. This gives branch rules one stable context while preserving every shard and fail-fast-disabled campaign execution.

## PM acceptance authority

The operational PM signal is the pull-request label:

```text
pm-accepted
```

The label itself is not the required branch context. The required context is the commit status:

```text
PM acceptance
```

That status is published directly to an exact PR-head SHA by trusted `pull_request_target` workflow code from the default branch.

The candidate PR cannot redefine the authoritative gate used for its own event because `pull_request_target` executes the base/default-branch workflow definition.

## Trusted execution boundary

`.github/workflows/pm-acceptance-gate.yml`:

- never checks out the PR branch;
- never executes PR-controlled scripts, actions, binaries, or repository content;
- queries PR metadata only through the GitHub API;
- has only `pull-requests: read`, `issues: write`, and `statuses: write` permissions;
- binds every decision to the event head and live API head;
- publishes `PM acceptance` manually through the commit-status API.

The trusted workflow listens for:

```text
opened
reopened
synchronize
labeled
unlabeled
ready_for_review
converted_to_draft
```

## Per-PR coordination

Acceptance events for the same PR must not make independent decisions concurrently.

The workflow therefore has a per-PR concurrency group:

```text
pm-acceptance-<repository>-<pr-number>
```

with `cancel-in-progress: true`.

A newer PR-state event supersedes an older in-progress run for that PR. This coordination is combined with live-state rechecks; concurrency alone is not treated as the authorization rule.

If a queued explicit acceptance run is superseded by another event before it grants success, the safe outcome is failure/no grant. PM can explicitly apply acceptance again after state stabilizes.

## Exact-head guard

Every run first compares:

```text
event head SHA
vs.
live PR head SHA from GitHub API
```

If they differ, the run exits without mutating labels and without publishing acceptance state for the newer head.

An event for SHA A therefore cannot grant or revoke acceptance for newer SHA B merely because it completed late.

## Event-specific grant and revoke semantics

The gate is intentionally asymmetric: many events may fail/revoke acceptance, but only one event type may grant it.

### Only explicit `pm-accepted` labeling may grant success

`PM acceptance = success` is possible only when all of these are true at the grant decision point:

1. event action is `labeled`;
2. the event label is exactly `pm-accepted`;
3. event head is still the live current PR head;
4. PR is non-draft;
5. live PR still contains `pm-accepted`.

The workflow publishes success only after re-querying those live facts.

Immediately after publishing success, it queries the PR again. If the head changed, the PR became draft, or `pm-accepted` disappeared during evaluation, the same trusted run overwrites success with failure.

This establishes the intended rule:

```text
success requires an explicit current-head acceptance event
```

rather than:

```text
success whenever a label happens to be present
```

### `synchronize` always invalidates

A current-head `synchronize` event:

- removes stale `pm-accepted` when present;
- verifies the stale label is absent;
- directly publishes `PM acceptance = failure` on that synchronized head.

It does not rely on GitHub recursively emitting an `unlabeled` workflow after a `GITHUB_TOKEN` label mutation.

A later explicit `labeled: pm-accepted` event is required to grant the new head.

### Draft/lifecycle transitions do not manufacture approval

`opened`, `reopened`, `ready_for_review`, and `converted_to_draft` publish failure for the exact head.

They never convert a persisted/stale `pm-accepted` label into a new approval.

In particular, applying `pm-accepted` while a PR is draft cannot be made valid merely by switching the PR to ready-for-review. PM must explicitly accept the resulting current state.

### `unlabeled: pm-accepted` revokes

Removing `pm-accepted` publishes failure for the exact current head.

For unrelated label removals, the workflow rechecks live state. It may publish failure when PM acceptance is no longer valid, but an unrelated event can never grant success.

### Unrelated labels cannot grant

A `labeled` event for any label other than `pm-accepted` cannot publish success.

If live PM state is invalid, it publishes failure. If live PM state is still valid, it leaves the existing PM status unchanged.

This means maintenance labels, priority labels, or automation labels cannot accidentally authorize a merge.

## Same-head race invariant

The gate must remain safe even when events for the **same SHA** are delivered or scheduled in an inconvenient order.

Consider SHA B:

```text
synchronize(B)
pm-accepted labeled(B)
pm-accepted unlabeled(B)
unrelated label events(B)
```

The safety properties are:

- runs for the PR are coordinated through one concurrency group;
- only explicit `labeled: pm-accepted` may grant;
- every grant re-queries live head/draft/label immediately before success;
- success is verified again after publication;
- synchronize and acceptance removal publish failure directly;
- unrelated events cannot grant;
- a superseded run cannot mutate a newer head.

Therefore a stale snapshot taken earlier in a run is never sufficient to grant acceptance.

A temporary success immediately followed by an external label removal is corrected by the coordinated `unlabeled` event; if the removal races the grant itself, the post-publication verification also detects state that changed during evaluation.

## New-head invalidation sequence

For accepted SHA A followed by SHA B:

```text
SHA A + explicit pm-accepted + PM acceptance=success
        ↓
push SHA B
        ↓
trusted synchronize(B)
        ↓
stale acceptance removed
PM acceptance=failure on B
        ↓
PM reviews B
        ↓
explicit labeled:pm-accepted(B)
        ↓
trusted live-state decision
        ↓
PM acceptance may become success on B
```

No opened/reopened/ready/unrelated-label event can substitute for that explicit acceptance action.

## Same-principal limitation

The current repository workflow uses the same GitHub owner/app permission surface for PM and worker activity.

Therefore `pm-accepted` is an **operational workflow-control signal**, not cryptographic actor separation.

A principal with equivalent repository write permissions could theoretically apply the label or alter repository settings. This mechanism protects the normal project process from accidental or automation-driven merges that treat green CI as sufficient; it is not designed to resist a malicious repository owner or another equally privileged principal.

True actor-separated PM authorization requires a distinct account, GitHub App, team, environment approval, or another owner-controlled credential ordinary workers do not possess.

Do not claim stronger security than the current identity model provides.

## Why no required approving review yet

GitHub does not allow a user to approve their own PR. Requiring one approving review while PM and workers share the same principal would deadlock self-authored PRs rather than create meaningful separation.

The initial enforceable design therefore combines required checks with the operational `pm-accepted` signal.

## Required `main` ruleset

Create one active branch ruleset targeting the default branch / `refs/heads/main`.

Required behavior:

- require a pull request before merging;
- require `Godot character contracts`;
- require `Repository layout contracts`;
- require `Godot headless contracts`;
- require `PM acceptance`;
- block ordinary direct pushes to `main`;
- block force pushes;
- block branch deletion;
- do not require a self-approval rule that the current same-account workflow cannot satisfy;
- do not give ordinary workers or Actions workflows permanent bypass rights.

Required checks apply to the current PR head. Success on an older SHA is not acceptance for a newer SHA.

## Acceptance lifecycle

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
trusted labeled event validates live state
        ↓
PM acceptance=success on that exact SHA
        ↓
all required contexts green on same SHA
        ↓
active ruleset allows merge
```

Any new implementation commit returns the new head to failure until explicit re-acceptance.

## Emergency bypass policy

There is no routine bypass actor.

For an actual repository-blocking emergency:

1. record the reason and affected PR/commit on the PM board;
2. temporarily alter or bypass only the minimum rule necessary using repository-owner authority;
3. perform the emergency action;
4. restore the active ruleset immediately;
5. verify `main` is protected again;
6. record the verification result.

Emergency bypass is not for skipping architecture review, dependency order, deterministic validation, PM acceptance, or protected-roadmap ownership.

## Required post-merge verification campaign

The trusted `pull_request_target` workflow cannot be fully exercised until its workflow file exists on the default branch. After the support PR is accepted and merged, and after the repository owner activates the ruleset, use a disposable documentation-only PR.

### Case 1 — broad CI green, no PM acceptance

Expected:

```text
broad CI = green
PM acceptance = failure
merge = blocked
```

### Case 2 — explicit accepted current head

Make the PR non-draft and explicitly add `pm-accepted` after review.

Expected:

```text
Godot character contracts = success
Repository layout contracts = success
Godot headless contracts = success
PM acceptance = success
merge = allowed
```

### Case 3 — accepted SHA A, then push SHA B

Expected:

```text
synchronize(B) invalidates acceptance
PM acceptance = failure on B
B remains blocked until explicit labeled:pm-accepted(B)
```

### Case 4 — same-head reordered events

Exercise acceptance and revocation around one head so synchronize/labeled/unlabeled runs overlap or queue in different orders.

Required invariant after events settle:

```text
pm-accepted absent => PM acceptance is not success
```

Also verify a delayed event for an older head cannot mutate the newer head.

### Case 5 — draft transition

Convert an accepted PR back to draft.

Expected:

```text
PM acceptance = failure
merge = blocked
```

Switching back to ready must not auto-grant from a persisted label; explicit acceptance is required again.

### Case 6 — unrelated labels

Add/remove an unrelated label before and after PM acceptance.

Expected:

```text
unrelated label events never create PM acceptance=success
```

### Case 7 — deterministic aggregate

Confirm all ten deterministic shard jobs execute and the stable context:

```text
Godot headless contracts
```

is successful only when the whole matrix succeeds. A controlled failed shard must make the aggregate fail.

### Case 8 — direct push

Attempt a harmless normal direct push to `main` without administrative bypass.

Expected:

```text
push rejected
main unchanged
```

## Connector limitation

The connected GitHub tooling can read rulesets/protection but does not expose a write action for creating or activating the final repository ruleset.

Therefore #118 has two layers:

1. in-repository workflow/documentation support;
2. repository-owner ruleset activation plus the verification campaign above.

The task is not DONE until owner activation is verified.

## Owner activation checklist

- [ ] `Underworld main merge gate` exists and is Active;
- [ ] target is only default branch / `main`;
- [ ] pull request required before merge;
- [ ] direct push restricted for normal workflow;
- [ ] force push blocked;
- [ ] branch deletion blocked;
- [ ] `Godot character contracts` required;
- [ ] `Repository layout contracts` required;
- [ ] stable `Godot headless contracts` aggregate required;
- [ ] trusted `PM acceptance` required;
- [ ] no ordinary Actions/worker bypass configured;
- [ ] no self-approval rule that deadlocks the same-account workflow;
- [ ] exact-head invalidation observed;
- [ ] same-head reordered-event campaign observed;
- [ ] unrelated labels proven unable to grant;
- [ ] draft behavior observed;
- [ ] failed-shard aggregate behavior observed;
- [ ] direct-push rejection observed.

## Invariants

1. Green CI is necessary but never sufficient by itself.
2. `PM acceptance` is published only by trusted default-branch `pull_request_target` code.
3. The trusted workflow never checks out or executes PR-controlled code.
4. Only explicit `labeled: pm-accepted` may grant success.
5. Draft/lifecycle/unrelated-label events cannot manufacture acceptance.
6. Every current-head synchronize invalidates prior acceptance.
7. Removing `pm-accepted` revokes acceptance.
8. Same-PR workflow runs are coordinated and live state is rechecked at the grant decision point.
9. A successful grant is verified again after publication.
10. Superseded old-head events cannot mutate or grant the newer head.
11. `pm-accepted` is an operational signal, not actor-separated security under the current same-principal model.
12. The deterministic campaign remains ten 25-seed shards covering 2,250 seed/region cases.
13. `Godot headless contracts` is the stable aggregate required by branch rules.
14. Normal updates to `main` use pull requests only.
15. Force pushes and branch deletion are not normal workflow.
16. Emergency bypass is temporary, explicit, narrow, and recorded.
17. Governance rules never authorize violating architecture, dependency, or protected-roadmap contracts.
18. No MAP-009→MAP-015 production/runtime contract is changed by this governance mechanism.
