# Underworld — Main Merge Gate

Status: **repository-governance contract**

This document defines the enforceable merge gate for `main`. It complements the pull task board; it does not replace architecture review, dependency review, or exact-head validation.

## Why this exists

`main` has repeatedly advanced while PM/dependency acceptance was still unresolved because draft state, comments, and green CI were process signals rather than repository-enforced rules.

The target policy is:

```text
required broad CI
+ trusted exact-head PM acceptance status
+ non-draft PR
+ pull-request-only main updates
= merge eligible
```

Green CI is necessary but never sufficient by itself.

## Required status contexts

The active `main` ruleset must require these exact contexts:

| Owner | Required context |
| --- | --- |
| Character Validation | `Godot character contracts` |
| Repository Layout Validation | `Repository layout contracts` |
| Deterministic Worldgen aggregate | `Godot headless contracts` |
| Trusted PM Acceptance Gate | `PM acceptance` |

The ten deterministic Worldgen matrix jobs are intentionally **not** configured individually as required branch contexts. They are covered by the stable aggregate `Godot headless contracts` job.

## Deterministic Worldgen stable aggregate

`.github/workflows/foundation-validation.yml` preserves the full deterministic campaign as ten 25-seed shards starting at:

```text
1, 26, 51, 76, 101, 126, 151, 176, 201, 226
```

Each shard still runs fast foundation contracts and 25 seeds across a 3×3 region neighborhood. Together they preserve the complete 250-seed × 9-region = 2,250-case campaign.

After every shard completes, one `if: always()` aggregator job named exactly:

```text
Godot headless contracts
```

runs and succeeds only when the matrix result is `success`. A cancelled or failed shard therefore makes the stable aggregate fail. The ruleset must require the stable aggregate, not shard-specific names.

## Trusted PM acceptance authority

The machine-readable PM signal is the pull-request label:

```text
pm-accepted
```

The label alone is **not** the required branch context. The required context is the commit status:

```text
PM acceptance
```

That status is published by `.github/workflows/pm-acceptance-gate.yml` from `pull_request_target` default-branch workflow code.

### Security boundary

The trusted workflow:

- runs only from the base/default-branch workflow definition;
- never checks out the pull request;
- never executes PR-controlled scripts, Actions, or repository code;
- uses only GitHub API metadata for the PR;
- has narrowly scoped `pull-requests: read`, `issues: write`, and `statuses: write` permissions;
- publishes `PM acceptance` directly onto `${{ github.event.pull_request.head.sha }}`.

A pull request that edits the gate workflow cannot redefine the authoritative gate used for its own event. Until new gate code is merged to the default branch, the existing default-branch version remains authoritative.

### Event coverage

The trusted workflow reevaluates on:

```text
opened
reopened
synchronize
labeled
unlabeled
ready_for_review
converted_to_draft
```

For non-`synchronize` events, it queries the live PR from GitHub and succeeds only when:

1. the event head is still the exact current PR head;
2. the PR is not a draft; and
3. `pm-accepted` is present on the live PR.

Otherwise it publishes a failing `PM acceptance` status to the event head.

## Exact-head invalidation

A PM acceptance applies only to one exact PR head.

On every `synchronize` event, the trusted workflow does all of the following in the same job:

1. reads the current PR metadata from GitHub;
2. removes stale `pm-accepted` when present;
3. verifies the stale label is absent;
4. directly publishes `PM acceptance = failure` on the synchronized event head;
5. does not rely on label removal recursively triggering a second workflow.

A later explicit `pm-accepted` label event is required before the new current head can receive `PM acceptance = success`.

If another commit races ahead while an older event is running, the older event can only publish failure for its own superseded SHA. The newer synchronize event owns invalidation for the newer head.

## Same-principal limitation

The current PM and worker automation operate through the same GitHub owner/app permission surface.

Therefore `pm-accepted` is an **operational workflow-control signal**, not cryptographic actor separation. Any actor with equivalent issue-write permission could theoretically add the label.

This gate still prevents ordinary automation from treating broad CI alone as merge authorization and exact-head invalidation is machine-enforced. A stronger actor-separated PM authorization boundary requires a distinct GitHub account, App, team, environment, or another owner-controlled mechanism with separate credentials.

Do not describe the current label model as stronger than that.

## Required `main` ruleset

Create one active branch ruleset targeting only the default branch / `refs/heads/main`.

```text
Ruleset name: Underworld main merge gate
Enforcement: Active
Target: default branch (`main`)
```

### Pull request requirement

Enable **Require a pull request before merging**.

Do not require one approving review while PM and workers use the same GitHub identity; GitHub self-approval would deadlock that workflow. The four required status contexts are the first enforceable landing gate.

### Required status checks

Require exactly:

```text
Godot character contracts
Repository layout contracts
Godot headless contracts
PM acceptance
```

Verify the names from live GitHub output before saving the ruleset. Do not configure obsolete matrix names or workflow display names by assumption.

### Direct update restrictions

Normal project workflow must not be able to push directly to `main`, force-push `main`, or delete `main`. All routine changes land through pull requests.

### Bypass policy

There is no routine bypass actor. Do not grant blanket bypass to all admins, all Actions workflows, or ordinary worker automation merely for convenience.

## Acceptance lifecycle

Normal flow:

```text
worker opens draft PR
        ↓
required broad CI runs
        ↓
worker handoff reaches REVIEW
        ↓
PM reviews scope/dependencies/current exact head
        ↓
PR becomes non-draft when appropriate
        ↓
PM adds pm-accepted
        ↓
trusted default-branch workflow publishes
PM acceptance = success on exact head
        ↓
all four required contexts green
        ↓
merge allowed by active ruleset
```

Any new commit returns to:

```text
PM acceptance = failure
pm-accepted removed
```

until the new head is reviewed and accepted again.

## Emergency bypass policy

Emergency bypass is intentionally explicit and temporary:

1. repository owner identifies an actual repository-blocking emergency;
2. record the reason and affected PR/commit on the PM board;
3. temporarily alter/disable only the minimum ruleset behavior required;
4. perform the emergency action;
5. restore the active ruleset immediately;
6. verify `main` protection again and record the result.

Emergency bypass is not for skipping dependency order, architecture review, long CI, or a failed PM gate.

## Required verification campaign

After the support workflows are merged and the owner activates the ruleset, use a disposable documentation-only PR to verify behavior.

### Case 1 — broad CI green, no PM acceptance

Expected:

```text
Character = green
Repository Layout = green
Godot headless contracts = green
PM acceptance = failing
merge = blocked
```

### Case 2 — accepted current exact head

Mark the PR non-draft and add `pm-accepted`.

Expected:

```text
PM acceptance = success on exact current head
all required contexts = green
merge = allowed
```

### Case 3 — accepted SHA A, then push SHA B

Expected immediately for SHA B:

```text
pm-accepted removed
PM acceptance = failure
merge = blocked
```

Re-acceptance is required for SHA B.

### Case 4 — draft transition

Convert an accepted PR back to draft.

Expected:

```text
PM acceptance = failure
merge = blocked
```

### Case 5 — Worldgen shard failure

Use a controlled validation fixture or intentionally failing temporary test branch that causes one deterministic shard to fail.

Expected:

```text
one or more shard jobs = failure
Godot headless contracts = failure
merge = blocked
```

Do not weaken or skip the remaining shards to make this test convenient.

### Case 6 — direct push

Attempt a harmless normal direct push to `main` without administrative bypass.

Expected:

```text
push rejected
main unchanged
```

## Connector/tooling limitation

The current ChatGPT GitHub connector can read repository rulesets/protection but does not expose a write action for creating or changing them.

Therefore #118 has two phases:

1. **in-repository support** — trusted PM status workflow, stable Worldgen aggregate, and this exact ruleset contract;
2. **repository-owner activation** — create/enable the GitHub ruleset and run the end-to-end campaign.

The task is not DONE until phase 2 is verified.

## Ruleset activation checklist

- [ ] `Underworld main merge gate` exists and is Active
- [ ] target is only default branch / `main`
- [ ] pull request required before merge
- [ ] direct push restricted for normal workflow
- [ ] force push blocked
- [ ] branch deletion blocked
- [ ] `Godot character contracts` required
- [ ] `Repository layout contracts` required
- [ ] `Godot headless contracts` required
- [ ] `PM acceptance` required
- [ ] required context names match live GitHub output
- [ ] no ordinary worker/Actions bypass actor configured
- [ ] no self-approval requirement deadlocks the current same-account model
- [ ] exact-head invalidation campaign passed
- [ ] failed-shard aggregate campaign passed
- [ ] direct-push rejection verified

## Invariants

1. Broad CI is necessary but never sufficient by itself.
2. Authoritative PM status comes from trusted default-branch code, not candidate PR workflow code.
3. `PM acceptance` is bound to one exact PR-head SHA.
4. Every synchronize invalidates acceptance directly and removes stale acceptance metadata.
5. Draft PRs cannot satisfy PM acceptance.
6. The stable Worldgen aggregate covers the complete ten-shard deterministic campaign.
7. Normal updates to `main` use pull requests only.
8. Force pushes and branch deletion are not normal workflow.
9. Same-principal label control is operational, not cryptographic actor separation.
10. Emergency bypass is temporary, explicit, and recorded.
11. Ruleset enforcement never authorizes violating architecture/dependency contracts.
12. No protected MAP-009→MAP-015 production/runtime behavior is changed by this governance mechanism.
