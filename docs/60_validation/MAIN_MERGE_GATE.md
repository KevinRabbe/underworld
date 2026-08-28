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

Green CI is necessary but never sufficient by itself.

## Required `main` status contexts

The final `main` ruleset must require these exact live contexts:

| Source | Required context |
| --- | --- |
| Character Validation | `Godot character contracts` |
| Repository Layout Validation | `Repository layout contracts` |
| Deterministic Worldgen aggregate | `Godot headless contracts` |
| trusted PM acceptance publisher | `PM acceptance` |

Do not require workflow display names or individual Worldgen shard names.

## Stable Deterministic Worldgen aggregate

`.github/workflows/foundation-validation.yml` preserves the complete deterministic campaign as ten matrix shards:

```text
start seeds: 1, 26, 51, 76, 101, 126, 151, 176, 201, 226
count per shard: 25
region radius: 1 = 3x3 regions
```

Together this remains 250 seeds × 9 regions = **2,250 deterministic seed/region cases**.

Each shard runs the fast deterministic contracts and its 25-seed batch. A final job runs after the matrix:

```text
name: Godot headless contracts
needs: deterministic-foundation
if: always()
```

The aggregate succeeds only when the matrix result is `success`. A failed or cancelled shard therefore makes the stable aggregate fail.

The ruleset must require only the stable aggregate `Godot headless contracts`; matrix instance names are implementation details.

## PM acceptance signal

The operational PM review signal is the pull-request label:

```text
pm-accepted
```

The authoritative required status context is:

```text
PM acceptance
```

The label itself is not a required status check. Trusted default-branch workflow code publishes the status directly to the exact PR-head SHA.

## Trusted default-branch authority

`.github/workflows/pm-acceptance-gate.yml` uses only `pull_request_target` and listens for:

- `opened`;
- `reopened`;
- `synchronize`;
- `labeled`;
- `unlabeled`;
- `ready_for_review`;
- `converted_to_draft`.

The workflow definition is taken from the base/default branch. Candidate PR workflow code therefore cannot redefine the authoritative gate used to judge that candidate.

The trusted job:

1. never checks out the PR branch;
2. never executes PR-controlled scripts, Actions, binaries, or repository code;
3. queries live PR metadata through the GitHub API;
4. compares the event head SHA with the live PR head SHA before changing acceptance state;
5. publishes `PM acceptance` directly to the exact event/current head using `statuses: write`;
6. removes stale `pm-accepted` on current-head `synchronize`;
7. does not depend on label mutation recursively triggering another workflow.

Its permissions are intentionally narrow:

```text
pull-requests: read
issues: write
statuses: write
```

There is no checkout step and no broad repository write permission.

## Exact-head rule

Acceptance belongs to one exact PR head.

The workflow compares:

```text
event head SHA
vs.
live PR head SHA
```

If they differ, the event is superseded and exits without granting acceptance or intentionally mutating current acceptance metadata. The event for the newer head evaluates the newer head independently.

This prevents an old `labeled` event for SHA A from granting success to SHA B.

Because GitHub events are asynchronous, metadata mutation cannot be treated as a transactional lock across separate workflow runs. The security invariant is therefore conservative: **a stale event must never grant acceptance to a newer head**. A later current-head event may conservatively invalidate acceptance and require re-review; that is safe.

## Only an explicit acceptance event may grant success

A critical rule is that **label presence by itself never grants acceptance on arbitrary lifecycle events**.

`PM acceptance=success` may be published only when all of the following are true:

1. the event action is `labeled`;
2. the label added by that event is exactly `pm-accepted`;
3. the event head is still the exact current PR head;
4. the PR is non-draft; and
5. live PR metadata confirms `pm-accepted` is present.

This means unrelated label changes, reopening, becoming ready for review, or other lifecycle events cannot accidentally reinterpret a stale label as fresh PM approval.

Workers must never add `pm-accepted` merely to make CI green.

## Synchronize invalidation

For accepted SHA A followed by new SHA B:

```text
SHA A + pm-accepted + PM acceptance=success
        ↓
new commit SHA B
        ↓
pull_request_target:synchronize for SHA B
        ↓
trusted workflow confirms SHA B is current
        ↓
PM acceptance=failure published directly to SHA B
        ↓
stale pm-accepted removed if present
        ↓
label absence verified
        ↓
SHA B remains blocked
        ↓
PM reviews SHA B and explicitly adds pm-accepted
        ↓
labeled(pm-accepted) event may publish success for SHA B
```

Failure is published **before** stale-label cleanup. Cleanup failure therefore cannot leave the synchronized head with a successful PM gate.

The synchronize path does not rely on `GITHUB_TOKEN` label removal triggering an `unlabeled` workflow; GitHub may suppress recursive workflow events from its own token.

## Lifecycle-event semantics

The trusted gate behaves conservatively:

| Event | Can grant success? | Intended result |
| --- | --- | --- |
| `opened` | No | failure / acceptance required |
| `reopened` | No | failure / fresh acceptance required |
| `synchronize` | No | failure first, then stale-label cleanup |
| `labeled: pm-accepted` | **Yes** | success only if exact current head + non-draft |
| `labeled: other` | No | no acceptance change |
| `unlabeled: pm-accepted` | No | failure |
| `unlabeled: other` | No | no acceptance change |
| `ready_for_review` | No | failure / explicit acceptance still required |
| `converted_to_draft` | No | failure |

The consequence is deliberate: moving a PR from draft to ready does not resurrect an older approval. PM must explicitly accept the exact ready head.

## Same-principal limitation

PM and worker activity currently share the same GitHub owner/app permission surface.

Therefore `pm-accepted` is an **operational workflow-control signal**, not cryptographic actor separation. A principal with equivalent issue-write permission could theoretically add the label or alter repository settings.

This mechanism prevents ordinary accidental or automation-driven merges from treating broad CI as sufficient. It is not designed to resist a malicious repository owner or another equally privileged principal.

True actor-separated PM authorization requires a distinct account, GitHub App, team, protected environment, or other owner-controlled credential unavailable to ordinary workers.

## Why there is no required approving review yet

GitHub does not allow a user to approve their own PR. Requiring one approving review while PM and workers share the same principal would deadlock self-authored PRs without creating real separation.

The current enforceable design therefore uses required checks plus the operational `pm-accepted` signal. It should be upgraded when a separate PM identity exists.

## Required `main` ruleset

Create one active ruleset targeting only the default branch / `refs/heads/main`.

Required behavior:

- require a pull request before merging;
- require `Godot character contracts`;
- require `Repository layout contracts`;
- require `Godot headless contracts`;
- require `PM acceptance`;
- block ordinary direct pushes to `main`;
- block force pushes;
- block deletion of `main`;
- do not require impossible same-user self-approval;
- do not grant ordinary workers or Actions workflows permanent bypass rights.

Required checks must apply to the current PR head. Success on an older SHA is never acceptance for a newer SHA.

## Acceptance lifecycle

```text
worker opens draft PR
        ↓
broad CI runs
        ↓
worker hands off to REVIEW
        ↓
PR becomes non-draft when appropriate
        ↓
PM reviews exact current head
        ↓
PM explicitly adds pm-accepted
        ↓
trusted default-branch labeled-event handler
publishes PM acceptance=success on that SHA
        ↓
all other required contexts green on same SHA
        ↓
active ruleset allows merge
```

Any implementation commit or acceptance-invalidating lifecycle transition returns the PR to a state that requires explicit current-head PM acceptance.

## Emergency bypass policy

There is no routine bypass actor.

For an actual repository-blocking emergency:

1. record the reason and affected PR/commit on the PM board;
2. use repository-owner authority to alter only the minimum rule necessary;
3. perform the emergency action;
4. restore the active ruleset immediately;
5. verify `main` protection again;
6. record the verification result.

Emergency bypass is not for skipping architecture review, dependency order, deterministic validation, PM acceptance, or protected-roadmap ownership.

## Required post-merge verification campaign

`pull_request_target` candidate changes cannot exercise their own trusted logic before that workflow exists on the default branch. Static review and ordinary exact-head CI are therefore the pre-landing evidence for the support PR.

After support code is accepted and merged, and after the repository owner activates the ruleset, use a throwaway documentation-only PR for end-to-end verification.

### Case 1 — broad CI green, no PM acceptance

Expected:

```text
Godot character contracts = success
Repository layout contracts = success
Godot headless contracts = success
PM acceptance = failure
merge = blocked
```

### Case 2 — explicit exact-head acceptance

Make the PR non-draft, review the current head, and add `pm-accepted`.

Expected:

```text
PM acceptance = success on exact current head
all required checks = success
merge = allowed
```

### Case 3 — push after acceptance

From accepted SHA A, push harmless SHA B.

Expected:

```text
PM acceptance=failure appears on SHA B
stale pm-accepted is removed
SHA B remains blocked until explicit re-acceptance
```

### Case 4 — unrelated labels cannot grant acceptance

While the current head is unaccepted, add or remove an unrelated label.

Expected:

```text
PM acceptance does not become success
```

### Case 5 — ready/draft transitions

Convert an accepted PR to draft, then later mark it ready.

Expected:

```text
draft => PM acceptance=failure
ready => still failure until explicit pm-accepted label event
```

### Case 6 — deterministic aggregate

Confirm all ten shard jobs execute and the exact stable context:

```text
Godot headless contracts
```

succeeds only when the entire matrix succeeds. A controlled failed-shard test must make the aggregate fail.

### Case 7 — direct push

Attempt a harmless normal direct push to `main` without administrative bypass.

Expected:

```text
push rejected
main unchanged
```

## Connector limitation

The connected GitHub tooling can read repository rulesets and branch protection but does not expose a write action for creating or activating them.

Therefore #118 has two layers:

1. in-repository workflow/documentation support;
2. repository-owner ruleset activation plus the end-to-end verification campaign.

The task is not DONE until layer 2 is verified.

## Owner activation checklist

- [ ] `Underworld main merge gate` exists and is Active;
- [ ] target is only default branch / `main`;
- [ ] pull request required before merge;
- [ ] direct pushes blocked for normal workflow;
- [ ] force pushes blocked;
- [ ] branch deletion blocked;
- [ ] `Godot character contracts` required;
- [ ] `Repository layout contracts` required;
- [ ] stable `Godot headless contracts` required;
- [ ] trusted `PM acceptance` required;
- [ ] required context names match live GitHub output;
- [ ] no ordinary worker/Actions bypass configured;
- [ ] no self-approval rule deadlocks the same-account workflow;
- [ ] exact-head synchronize invalidation verified;
- [ ] only explicit `labeled: pm-accepted` can restore success;
- [ ] unrelated labels and ready/draft transitions verified;
- [ ] failed-shard aggregate behavior verified;
- [ ] direct-push rejection verified.

## Invariants

1. Green CI is necessary but never sufficient by itself.
2. `PM acceptance` is published only by trusted default-branch `pull_request_target` code.
3. The trusted workflow never checks out or executes PR-controlled code.
4. Acceptance belongs to one exact current PR head.
5. Only an explicit current-head `labeled: pm-accepted` event may grant success.
6. Unrelated label events can never grant PM acceptance.
7. Reopen/ready/draft events can never resurrect an old acceptance.
8. Every current-head synchronize publishes failure directly before stale-label cleanup.
9. Stale-label removal does not depend on recursive workflow events.
10. Superseded old-head events can never grant acceptance to a newer head.
11. `pm-accepted` is operational, not actor-separated security under the current same-principal model.
12. The complete deterministic campaign remains ten 25-seed shards covering 2,250 cases.
13. `Godot headless contracts` is the stable aggregate required by branch rules.
14. Normal updates to `main` use pull requests only.
15. Force pushes and branch deletion are not normal workflow.
16. Emergency bypass is temporary, explicit, narrow, and recorded.
17. Governance rules never authorize violating architecture, dependency, or protected-roadmap contracts.
18. No MAP-009→MAP-015 production/runtime behavior is changed by this governance mechanism.
