# Underworld — Main Merge Gate

Status: **repository-governance contract**

This document defines the intended enforceable merge gate for `main`. It complements the pull task board; it does not replace architecture review, dependency review, protected-roadmap ownership, or exact-head validation.

## Target policy

```text
required broad CI
+ exact-current-head PM acceptance
+ non-draft PR
+ pull-request-only main updates
= merge eligible
```

Green CI is necessary but is never sufficient by itself.

## Required `main` status contexts

Configure the final `main` ruleset to require these exact contexts:

| Source | Required context |
| --- | --- |
| Character Validation | `Godot character contracts` |
| Repository Layout Validation | `Repository layout contracts` |
| Deterministic Worldgen Validation aggregate | `Godot headless contracts` |
| trusted PM acceptance publisher | `PM acceptance` |

The deterministic workflow intentionally runs ten matrix shards, but the ruleset must require the single stable aggregate context `Godot headless contracts`, not shard-specific names.

## Deterministic aggregate contract

`.github/workflows/foundation-validation.yml` preserves the complete deterministic campaign as ten shards:

```text
start seeds: 1, 26, 51, 76, 101, 126, 151, 176, 201, 226
count per shard: 25
region radius: 1 = 3x3 regions
```

Together this remains 250 seeds × 9 regions = 2,250 seed/region cases.

Each shard runs the fast deterministic contracts followed by its 25-seed batch. A final job:

```text
name: Godot headless contracts
needs: deterministic-foundation
if: always()
```

fails unless the matrix result is `success`. This gives branch rules one stable context while preserving all ten shards and fail-fast-disabled campaign execution.

Do not replace the aggregate by requiring every generated matrix check name manually.

## PM acceptance signal

The operational review signal is the pull-request label:

```text
pm-accepted
```

The authoritative status context is:

```text
PM acceptance
```

That status is published directly to the exact current PR-head SHA by trusted `pull_request_target` workflow code from the default branch.

The workflow does not use a PR-head `pull_request` job as the authority for this status.

## Trusted exact-head publisher

`.github/workflows/pm-acceptance-gate.yml` runs only on `pull_request_target` for:

- opened;
- reopened;
- synchronize;
- labeled;
- unlabeled;
- ready-for-review;
- converted-to-draft.

The trusted job:

1. never checks out the PR branch;
2. never executes scripts, actions, binaries, or other content from the PR branch;
3. queries the live pull request through the GitHub API;
4. resolves the live head SHA, draft state, and current labels;
5. ignores an event whose payload head has already been superseded by a newer live head;
6. publishes the `PM acceptance` commit status directly to the exact live PR-head SHA using `statuses: write`;
7. on `synchronize`, removes stale `pm-accepted` and publishes failure immediately in the same trusted job.

The job uses only narrowly scoped permissions:

```text
pull-requests: read
issues: write
statuses: write
```

There is no checkout step.

## Why the superseded-event guard matters

GitHub events and workflow jobs can complete out of order.

For example, a delayed `labeled` event for SHA A must never be able to observe newer SHA B and publish acceptance for B.

The workflow therefore compares:

```text
event head SHA
vs.
live PR head SHA from GitHub API
```

If they differ, that run performs no acceptance mutation and publishes no status. The event belonging to the newer head evaluates that head independently.

This prevents an older event from granting acceptance to a commit it did not represent.

## Synchronize invalidation

For accepted SHA A followed by a pushed SHA B:

```text
SHA A + pm-accepted + PM acceptance=success
        ↓
new commit SHA B pushed
        ↓
pull_request_target:synchronize
        ↓
trusted default-branch workflow queries live SHA B
        ↓
stale pm-accepted removed if present
        ↓
PM acceptance=failure published directly to SHA B
        ↓
PM reviews SHA B and explicitly re-adds pm-accepted
        ↓
pull_request_target:labeled evaluates SHA B
        ↓
PM acceptance may become success
```

The synchronize run does not depend on its label removal recursively starting another workflow. Failure is published directly in the same trusted job.

If GitHub suppresses workflow recursion for changes made with `GITHUB_TOKEN`, the invariant still holds.

## Pass/fail semantics

`PM acceptance` is `failure` when:

- the current PR is draft;
- `pm-accepted` is absent; or
- the event is `synchronize`, because a new commit invalidates prior acceptance.

It is `success` only when the exact evaluated head is current, the PR is non-draft, and `pm-accepted` is present.

Workers must never add `pm-accepted` to their own handoff PR merely to make the gate green.

## Same-principal limitation

The current repository workflow uses the same GitHub owner/app permission surface for PM and worker activity.

Therefore `pm-accepted` is an **operational workflow-control signal**, not cryptographic actor separation.

A principal with equivalent repository write permissions could theoretically apply the label or alter repository settings. This mechanism protects normal process from accidental or automation-driven merges that treat green CI as sufficient; it is not designed to resist a malicious repository owner or another equally privileged principal.

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

Required checks must apply to the current PR head. Success on an older SHA is not acceptance for a newer SHA.

## Draft behavior

Draft PRs cannot satisfy `PM acceptance`, even if the label is present.

GitHub also treats draft PRs as non-merge-ready. The explicit failing PM status makes the repository's own acceptance state visible and machine-readable.

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
PM adds pm-accepted
        ↓
trusted default-branch workflow publishes PM acceptance=success on that SHA
        ↓
all other required contexts green on same SHA
        ↓
active ruleset allows merge
```

Any new implementation commit returns the current head to failure until it is explicitly reviewed again.

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

The trusted `pull_request_target` workflow cannot be fully exercised until its workflow file exists on the default branch, because GitHub deliberately executes the default-branch version of that workflow.

After the support PR is accepted and merged, and after the repository owner activates the ruleset, use a throwaway documentation-only PR.

### Case 1 — broad CI green, no PM acceptance

Expected:

```text
broad CI = green
PM acceptance = failure
merge = blocked
```

### Case 2 — accepted current head

Make the PR non-draft and apply `pm-accepted` after review.

Expected:

```text
Godot character contracts = success
Repository layout contracts = success
Godot headless contracts = success
PM acceptance = success
merge = allowed
```

### Case 3 — exact-head invalidation

From accepted SHA A, push harmless SHA B.

Expected:

```text
trusted synchronize job removes stale pm-accepted
PM acceptance=failure is published directly to SHA B
SHA B remains blocked until explicit re-acceptance
```

Also confirm no delayed event for SHA A can publish acceptance to SHA B.

### Case 4 — draft transition

Convert an accepted PR back to draft.

Expected:

```text
PM acceptance = failure
merge = blocked
```

### Case 5 — direct push

Attempt a harmless normal direct push to `main` without administrative bypass.

Expected:

```text
push rejected
main unchanged
```

### Case 6 — deterministic aggregate

Confirm all ten deterministic shard jobs execute and the exact stable context:

```text
Godot headless contracts
```

is successful only when the matrix succeeds.

## Connector limitation

The connected GitHub tooling can read rulesets/protection but does not expose a write action for creating or activating the repository ruleset.

Therefore #118 has two layers:

1. in-repository workflow/documentation support;
2. repository-owner ruleset activation plus the verification campaign above.

Until owner activation is complete, policy remains operational rather than technically enforced on `main`.

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
- [ ] `PM acceptance` required;
- [ ] no ordinary Actions/worker bypass configured;
- [ ] no self-approval rule that deadlocks the same-account workflow;
- [ ] synchronize invalidation observed successfully;
- [ ] superseded-event guard observed or inspected;
- [ ] draft behavior observed;
- [ ] direct-push rejection observed.

## Invariants

1. Green CI is necessary but never sufficient by itself.
2. `PM acceptance` is published only by trusted default-branch `pull_request_target` code.
3. The trusted workflow never checks out or executes PR-controlled code.
4. Draft PRs cannot satisfy PM acceptance.
5. Every current-head synchronize invalidates prior PM acceptance directly.
6. Stale label removal does not depend on recursive workflow events.
7. Superseded old-head events cannot publish success onto a newer head.
8. Re-acceptance is explicit and applies only to the then-current head.
9. `pm-accepted` is an operational signal, not actor-separated security under the current same-principal model.
10. The full deterministic campaign remains ten 25-seed shards covering 2,250 seed/region cases.
11. `Godot headless contracts` is the stable aggregate required by branch rules.
12. Normal updates to `main` use pull requests only.
13. Force pushes and branch deletion are not normal workflow.
14. Emergency bypass is temporary, explicit, narrow, and recorded.
15. Governance rules never authorize violating architecture, dependency, or protected-roadmap contracts.
16. No MAP-009→MAP-015 production/runtime contract is changed by this governance mechanism.
