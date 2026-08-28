# Underworld — Main Merge Gate

Status: **repository-governance contract**

This contract defines the deployable merge discipline for `main`. It complements the pull task board and architecture review; it does not replace either.

## Current phase

The project currently uses a **same-principal operational PM guard**.

This phase is intentionally designed to stop ordinary accidental or automation-driven merges that treat green CI as sufficient. It is **not** a cryptographic authorization boundary against a malicious actor who has equivalent repository/GitHub Actions permissions.

A future distinct PM GitHub App/account/team may replace this operational signal when actor-separated authorization is required. That hardening is Phase 2; it is not a prerequisite for deploying the current process guard.

## Target policy

```text
required broad CI
+ branch synchronized with current main
+ exact-current-head operational PM acceptance
+ non-draft PR
+ pull-request-only main updates
= merge eligible
```

Green CI is necessary but never sufficient by itself.

## Required `main` status contexts

Configure the `main` ruleset to require these exact contexts:

| Source | Required context |
| --- | --- |
| Character Validation | `Godot character contracts` |
| Repository Layout Validation | `Repository layout contracts` |
| Deterministic Worldgen aggregate | `Godot headless contracts` |
| Operational PM acceptance workflow | `PM acceptance` |

The deterministic workflow runs ten shards, but branch rules must require only the stable aggregate `Godot headless contracts`.

## Operational PM acceptance

The human/process signal is the PR label:

```text
pm-accepted
```

The machine-readable status is:

```text
PM acceptance
```

`.github/workflows/pm-acceptance-gate.yml` owns this status in the current phase. It runs under `pull_request_target`, so its workflow definition comes from the trusted default branch rather than the candidate PR.

The workflow must never checkout or execute PR-controlled code.

## Security boundary — important

The current workflow is an **operational same-principal guard**, not source-isolated authorization.

Same-repository GitHub Actions workflows run as the GitHub Actions App. A sufficiently privileged PR-controlled workflow may be able to request `statuses: write` and mint a status with the same context name. Therefore:

- do not describe `PM acceptance` as cryptographically source-isolated;
- do not claim this mechanism protects against a malicious repository owner or another principal with equivalent workflow/write authority;
- do use it to prevent normal automation from merging a branch simply because broad CI is green;
- treat a distinct trusted App/account/team as future hardening if stronger separation is needed.

This limitation is explicit rather than hidden.

## Exact-head acceptance invariant

For normal project operation, the invariant is:

```text
PM acceptance=success
=> current PR head is exactly the reviewed head
=> PR is non-draft
=> pm-accepted is currently present
=> a fresh explicit acceptance action occurred for this head
```

Any new commit invalidates acceptance status immediately.

Acceptance from SHA A is never acceptance for SHA B, even if the `pm-accepted` label happens to remain visible as stale metadata after the head changes.

## Trusted workflow events

The operational PM workflow listens to:

- `opened`
- `reopened`
- `synchronize`
- `labeled`
- `unlabeled`
- `ready_for_review`
- `converted_to_draft`

It uses per-PR concurrency so overlapping state events cannot independently race status decisions.

## Grant semantics

Only an explicit event:

```text
labeled: pm-accepted
```

may grant `PM acceptance=success`.

Before granting success, the workflow must re-query the live PR and verify:

1. event head still equals the current head;
2. PR is non-draft;
3. `pm-accepted` is still present.

After success publication, it re-queries live state again. If the head, draft state, or label changed during evaluation, it immediately overwrites the success with failure.

Unrelated label events never grant acceptance.

## Revoke/fail semantics

The workflow publishes failure for the exact current head when:

- a new commit is synchronized;
- `pm-accepted` is removed;
- the PR becomes draft;
- the PR is reopened;
- a PR is moved to ready-for-review without a fresh acceptance event;
- live acceptance state is inconsistent.

On `synchronize`, the new head receives `PM acceptance=failure` directly. Exact-head safety does **not** depend on the workflow mutating PR labels.

A live post-merge probe demonstrated that workflow-owned label deletion can return HTTP 403 even when the job reports issue-write permission. Therefore `pm-accepted` may remain visible after a synchronize event as **stale metadata only**. Its presence cannot grant success because only a fresh explicit `labeled: pm-accepted` event is a grant path.

To accept the new head after synchronization, PM must review the new exact head, remove any stale `pm-accepted` label if it is still present, and explicitly add it again. That remove/re-add cycle produces the fresh acceptance event for the new SHA.

## Superseded-event safety

Every event compares its payload head SHA to the current live PR head before changing acceptance status.

If the event belongs to an older head, it exits without changing the newer head.

Same-PR runs share one concurrency group, preventing two active acceptance runs from independently publishing conflicting final state for the same PR.

## Draft behavior

Draft PRs cannot satisfy PM acceptance.

Applying `pm-accepted` to a draft must not produce success. A fresh explicit acceptance action is required after the PR is ready and PM review is complete.

## Deterministic Worldgen aggregate

`.github/workflows/foundation-validation.yml` preserves the complete campaign as ten shards:

```text
start seeds: 1, 26, 51, 76, 101, 126, 151, 176, 201, 226
count per shard: 25
region radius: 1 = 3x3 regions
```

Total coverage remains:

```text
250 seeds × 9 regions = 2,250 cases
```

Each shard runs the deterministic contracts and its seed batch. A final job named exactly:

```text
Godot headless contracts
```

runs with `if: always()` and fails unless the whole matrix result is `success`.

Do not replace the aggregate with ten brittle required matrix names and do not weaken the campaign to simplify branch rules.

## Required `main` ruleset

Create one active branch ruleset targeting `refs/heads/main` / the default branch.

Required behavior:

- require a pull request before merging;
- require branches to be up to date before merging;
- require `Godot character contracts`;
- require `Repository layout contracts`;
- require `Godot headless contracts`;
- require `PM acceptance`;
- block ordinary direct pushes to `main`;
- block force pushes;
- block branch deletion;
- do not require a self-approval rule that the current same-account workflow cannot satisfy;
- do not give ordinary workers or Actions a routine bypass.

The up-to-date requirement is mandatory. A green/accepted PR becomes stale when `main` advances and must synchronize, rerun required CI, and receive new PM acceptance for its new head.

## Expected lifecycle

```text
worker opens draft PR
        ↓
broad CI runs
        ↓
worker hands off to REVIEW
        ↓
branch synchronized with current main
        ↓
required CI green on exact head
        ↓
PM reviews exact head
        ↓
PR becomes non-draft
        ↓
PM explicitly applies pm-accepted
        ↓
trusted pull_request_target workflow validates live state
        ↓
PM acceptance=success on exact head
        ↓
ruleset permits merge only if every required context is green
```

Any implementation commit returns the head to unaccepted state.

If `pm-accepted` remains visible after that commit, it is stale metadata. PM must remove it and explicitly add it again only after reviewing the new exact head.

## PM operating rule

The `pm-accepted` label is not a worker completion signal.

Workers must not apply it merely to make the gate green. The PM applies it only after exact-head review and dependency review are complete.

After a synchronized head invalidates prior acceptance, a surviving `pm-accepted` label must be treated as stale. Re-acceptance requires an explicit PM remove/re-add cycle so a new `labeled: pm-accepted` event is generated for the current head.

Because the current repository may use the same GitHub account/App surface for multiple roles, this is a process rule rather than actor-separated cryptographic enforcement.

## Post-merge activation campaign

The workflow cannot be end-to-end validated as trusted default-branch `pull_request_target` code until it exists on `main`, and branch protection/rulesets must be activated separately by the repository owner.

After support code lands and the ruleset is enabled, use a throwaway documentation-only PR to prove the following.

### Case 1 — green CI without PM acceptance

Expected:

```text
broad CI = success
PM acceptance = failure
merge = blocked
```

### Case 2 — exact current head accepted

After PM review, make the PR non-draft and explicitly apply `pm-accepted`.

Expected:

```text
Godot character contracts = success
Repository layout contracts = success
Godot headless contracts = success
PM acceptance = success
merge = allowed
```

### Case 3 — new commit invalidates acceptance

Start from accepted SHA A and push harmless SHA B.

Expected:

```text
PM acceptance=failure on SHA B
merge blocked
pm-accepted may remain visible only as stale metadata
```

SHA B must require fresh CI and fresh PM acceptance. If the label remains present, remove it and explicitly add it again only after the new head has been reviewed.

### Case 4 — same-head event ordering

Exercise acceptance/removal and synchronize/labeled timing as closely as practical.

Expected invariants:

```text
synchronize => final PM acceptance on the new head is failure
live pm-accepted absent => final PM acceptance is not success
```

No delayed event for an old head may change the newer head. A stale label that survives synchronization must never turn the new head green without a fresh explicit label event.

### Case 5 — draft transition

Convert an accepted PR back to draft.

Expected:

```text
PM acceptance = failure
merge = blocked
```

### Case 6 — remove acceptance

Remove `pm-accepted` from an accepted PR.

Expected:

```text
PM acceptance = failure
merge = blocked
```

### Case 7 — deterministic aggregate

Confirm all ten shards run and the exact stable context `Godot headless contracts` succeeds only when the matrix succeeds.

### Case 8 — stale-main protection

Accept a PR, then advance `main` through another PR.

Expected: the accepted branch must synchronize and rerun required checks before merge eligibility returns.

### Case 9 — direct push

Attempt a harmless normal direct push to `main` without administrative bypass.

Expected:

```text
push rejected
main unchanged
```

## Emergency bypass

There is no routine bypass actor.

For a genuine repository-blocking emergency:

1. record the reason and affected PR/commit on the PM board;
2. alter/bypass only the minimum rule needed using owner authority;
3. perform the emergency action;
4. restore the ruleset immediately;
5. verify protection is active again;
6. record the verification result.

Emergency bypass is not for skipping architecture review, dependency order, deterministic validation, or PM acceptance.

## Phase 2 — actor-separated hardening

If the project later needs protection against malicious same-repository Actions or stronger human-role separation, replace the operational publisher with a distinct trusted authorization identity, for example:

- dedicated GitHub App whose credentials are unavailable to repository Actions;
- distinct PM account/team with enforceable review policy;
- another owner-controlled external approval service.

At that point the ruleset should source-bind the required approval signal to the distinct identity where GitHub supports it.

Phase 2 must not be described as already present.

## Connector limitation

The connected repository tooling can inspect branch protection/rulesets but does not expose creation/activation of the final `main` ruleset.

Therefore merging the support workflow does **not** by itself mean `main` is protected.

Repository-owner activation plus the verification campaign above are required before REPO-GOV-001 is DONE.

## Acceptance criteria

- [ ] trusted acceptance workflow comes from default-branch `pull_request_target` code;
- [ ] workflow never checks out or executes PR-controlled content;
- [ ] per-PR concurrency exists;
- [ ] only explicit `pm-accepted` label event grants success;
- [ ] success is exact-head and non-draft;
- [ ] new commits revoke acceptance status even if label metadata persists;
- [ ] acceptance removal/draft/reopen/ready transitions fail closed;
- [ ] same-head and superseded-head event races cannot leave stale success during normal operation;
- [ ] full ten-shard 2,250-case deterministic campaign remains intact;
- [ ] stable `Godot headless contracts` aggregate exists;
- [ ] ruleset requires branch up-to-date state;
- [ ] main requires PR + broad checks + operational PM acceptance;
- [ ] ordinary direct/force push and deletion are blocked;
- [ ] same-principal limitation is explicitly documented;
- [ ] post-activation verification campaign passes.
