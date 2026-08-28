# Underworld — Main Merge Gate

Status: **repository-governance contract**

This document defines the intended enforceable merge gate for `main`. It complements the pull task board; it does not replace architecture review, dependency review, protected-roadmap ownership, or exact-head validation.

## Target policy

```text
required broad CI
+ exact-current-main synchronization
+ source-isolated PM acceptance
+ non-draft PR
+ pull-request-only main updates
= merge eligible
```

Green CI is necessary but never sufficient by itself.

## Required `main` contexts

Configure the final `main` ruleset to require:

| Source | Required context |
| --- | --- |
| Character Validation | `Godot character contracts` |
| Repository Layout Validation | `Repository layout contracts` |
| Deterministic Worldgen aggregate | `Godot headless contracts` |
| distinct external PM GitHub App | `PM acceptance` |

The first three contexts may come from GitHub Actions. The `PM acceptance` context **must not** be accepted from the GitHub Actions App. It must be source-bound to a distinct external GitHub App/integration that ordinary repository workflows cannot impersonate.

## Why GitHub Actions cannot own authoritative PM acceptance

A same-repository `pull_request` workflow can request `statuses: write` and post an arbitrary commit status on its PR head.

Therefore a required context name such as:

```text
PM acceptance
```

is not sufficient by itself when both the trusted publisher and untrusted PR workflows use the GitHub Actions App identity.

Binding the required status to the GitHub Actions App also does not solve this: both publishers would have the same source App.

Consequently:

- repository Actions may perform metadata hygiene and diagnostics;
- repository Actions must not be the authoritative source for `PM acceptance`;
- the branch ruleset must bind `PM acceptance` to a distinct external GitHub App/integration;
- credentials for that App must not be exposed to ordinary repository Actions.

## External PM App trust boundary

The authoritative PM publisher must run outside candidate PR-controlled GitHub Actions.

Minimum properties:

1. distinct GitHub App/integration identity from GitHub Actions;
2. App credentials/private key stored outside repository workflows;
3. installed only with the permissions required to read PR state and publish the acceptance status;
4. status context exactly `PM acceptance`;
5. status published on the exact current PR-head SHA;
6. ruleset required-status source explicitly bound to this App/integration;
7. no repository workflow has credentials that allow it to publish as the App;
8. ordinary Actions are not a bypass actor.

The external App should consume pull-request webhook events for:

```text
opened
reopened
synchronize
labeled
unlabeled
ready_for_review
converted_to_draft
```

It must query current PR state at its authoritative decision point instead of trusting stale event snapshots.

## PM approval input

The operational PM signal remains:

```text
pm-accepted
```

Only an explicit `labeled` event for `pm-accepted` may grant `PM acceptance=success`.

The external App should additionally validate the event sender against the configured PM actor/account/team policy and must reject automated label application from `github-actions[bot]` as an authorization event.

Because PM and workers currently share the same repository-owner identity surface in some workflows, this label still does **not** provide cryptographic separation between a malicious worker using that same owner identity and PM. It does, however, separate the required status source from PR-controlled GitHub Actions and prevents ordinary PR workflows from minting the required status directly.

True human-role separation requires a distinct PM account/team/App approval identity.

## Exact-head PM semantics

The external App must be fail-closed.

### Grant

`PM acceptance=success` is allowed only when all are true:

1. webhook/action represents `labeled`;
2. label is exactly `pm-accepted`;
3. label event sender satisfies the configured PM actor policy;
4. event head is still the current live PR head;
5. PR is non-draft;
6. live PR still contains `pm-accepted`;
7. decision is serialized/coordinated per PR so overlapping same-head events cannot leave stale success.

Immediately before status publication, the App must re-query live head/draft/label state.

A post-publication recheck or equivalent transactional/serialized design is recommended so an acceptance removal racing the grant cannot leave final success behind.

### Revoke/fail

The App must publish failure for the exact current head when:

- a new head is synchronized;
- `pm-accepted` is removed;
- the PR becomes draft;
- the PR is reopened;
- a ready-for-review transition occurs without a fresh explicit acceptance action;
- live state is inconsistent with a grant.

A new commit always requires a new explicit PM acceptance action.

## Repository metadata guard

`.github/workflows/pm-acceptance-gate.yml` is intentionally a **non-authoritative metadata guard**.

It runs as trusted `pull_request_target` default-branch code and:

- never checks out or executes PR-controlled content;
- removes stale `pm-accepted` on synchronize/reopen/ready/draft transitions;
- rejects retaining `pm-accepted` on draft PRs;
- guards against superseded-head metadata mutation;
- uses per-PR concurrency;
- has no `statuses: write` permission;
- never publishes the required `PM acceptance` context.

This workflow improves repository hygiene but is not part of the cryptographic/source-isolated authorization boundary. The external PM App must remain correct even if metadata cleanup is delayed or fails.

Do **not** configure the branch ruleset to require the metadata-guard job as a substitute for the external App status.

## Deterministic aggregate contract

`.github/workflows/foundation-validation.yml` preserves the complete deterministic campaign as ten shards:

```text
start seeds: 1, 26, 51, 76, 101, 126, 151, 176, 201, 226
count per shard: 25
region radius: 1 = 3x3 regions
```

Together this remains 250 seeds × 9 regions = 2,250 seed/region cases.

Each shard runs fast deterministic contracts and its 25-seed batch. A final job named exactly:

```text
Godot headless contracts
```

uses `if: always()` and fails unless the entire matrix result is `success`.

The ruleset must require only the stable aggregate, not generated shard names.

## Required `main` ruleset

Create one active branch ruleset targeting only `refs/heads/main` / the default branch.

Required behavior:

- require a pull request before merging;
- require branches to be up to date before merging;
- require `Godot character contracts`;
- require `Repository layout contracts`;
- require stable `Godot headless contracts`;
- require `PM acceptance` **from the distinct external PM App source**;
- block ordinary direct pushes to `main`;
- block force pushes;
- block branch deletion;
- do not require a self-approval rule that the current same-account workflow cannot satisfy;
- do not give ordinary workers or GitHub Actions permanent bypass rights.

The up-to-date requirement is mandatory because exact-head validation against stale `main` is not sufficient for this project. A PR accepted and green at SHA A must synchronize/revalidate if `main` advances before merge.

## Required status-source verification

Before activation is considered complete, verify the ruleset UI/API associates `PM acceptance` with the distinct PM App/integration, not merely the context string and not the GitHub Actions App.

A spoof status with the same context created by GitHub Actions must **not** satisfy the required PM check.

If GitHub cannot source-bind the status to the distinct App under the repository's current plan/features, #118 remains BLOCKED and the project must choose another owner-controlled authorization mechanism rather than claiming enforcement.

## Acceptance lifecycle

```text
worker opens draft PR
        ↓
broad CI runs
        ↓
worker hands off to REVIEW
        ↓
PR synchronized with current main
        ↓
PM reviews exact current head
        ↓
PR becomes non-draft when appropriate
        ↓
PM explicitly applies pm-accepted
        ↓
external PM App validates actor + exact live state
        ↓
external App publishes PM acceptance=success on exact head
        ↓
all required broad contexts green on same exact head
        ↓
ruleset permits merge
```

Any new commit or stale-main condition invalidates merge eligibility until synchronization, validation, and PM acceptance are repeated as required.

## Same-principal limitation

The current operational process may use the same GitHub owner identity for PM and workers.

Therefore:

- source isolation prevents PR-controlled GitHub Actions from spoofing the authoritative required status;
- PM actor allowlisting can reject `github-actions[bot]` and other automation actors;
- it does not distinguish two roles that deliberately operate as the same human/account identity.

Do not describe the label itself as cryptographic authorization.

For full actor separation, use a dedicated PM account/team or another owner-controlled identity ordinary workers cannot use.

## Emergency bypass policy

There is no routine bypass actor.

For a repository-blocking emergency only:

1. record the reason and affected PR/commit on the PM board;
2. temporarily alter/bypass only the minimum rule using repository-owner authority;
3. perform the emergency action;
4. restore the active ruleset immediately;
5. verify source-bound required checks and `main` protection again;
6. record the verification result.

Emergency bypass is not for skipping dependency order, architecture review, deterministic validation, PM acceptance, or protected-roadmap ownership.

## Mandatory owner/external setup

The connected project tooling can read repository protection/rulesets but cannot create the required GitHub App identity or activate the final source-bound ruleset.

Owner/external setup must therefore:

1. create/select a distinct PM GitHub App/integration;
2. host its webhook/status publisher outside repository PR-controlled Actions;
3. keep App credentials outside repository workflow-accessible secrets;
4. configure PM actor/sender policy;
5. install the App with minimal required permissions;
6. observe at least one `PM acceptance` status emitted by that App so GitHub can select it as the expected source;
7. activate the `main` ruleset with required App source binding;
8. enable require-branches-up-to-date;
9. run the verification campaign below.

Until those steps are complete, #118 is not DONE.

## Mandatory verification campaign

Use a harmless throwaway documentation PR after the App and ruleset are active.

### Case 1 — broad CI green, no PM acceptance

Expected:

```text
broad CI = green
PM acceptance from external App = failure/missing
merge = blocked
```

### Case 2 — explicit exact-head acceptance

Make the PR non-draft and apply `pm-accepted` through the allowed PM actor.

Expected:

```text
Godot character contracts = success
Repository layout contracts = success
Godot headless contracts = success
PM acceptance (external App source) = success
merge = allowed only if branch is current with main
```

### Case 3 — new-head invalidation

From accepted SHA A, push harmless SHA B.

Expected:

```text
PM acceptance on B = failure before any fresh grant
stale pm-accepted metadata is removed
B cannot merge until revalidated and explicitly re-accepted
```

### Case 4 — same-head event race

Exercise rapid label/synchronize or label/remove transitions for one head.

Expected final invariant:

```text
if live pm-accepted is absent or PR is draft:
PM acceptance final state != success
```

### Case 5 — Actions spoof attempt

On a throwaway PR, run a deliberately scoped test workflow that posts a status named `PM acceptance` using the normal GitHub Actions identity.

Expected:

```text
spoof context may exist in commit status history
ruleset does NOT count it as the required external-App PM acceptance
merge remains blocked
```

Do not retain the spoof workflow after the test.

### Case 6 — stale-main rejection

Accept and green a throwaway PR, then advance `main` independently.

Expected:

```text
PR becomes non-merge-eligible until updated with current main
required checks rerun on synchronized head
```

### Case 7 — deterministic aggregate

Confirm all ten shards execute and stable:

```text
Godot headless contracts
```

passes only when the complete matrix succeeds.

### Case 8 — direct push

Attempt a harmless normal direct push to `main` without administrative bypass.

Expected:

```text
push rejected
main unchanged
```

## Owner activation checklist

- [ ] distinct external PM GitHub App/integration exists;
- [ ] App publisher is outside PR-controlled repository Actions;
- [ ] App credentials are not available to ordinary repository workflows;
- [ ] PM actor/sender policy configured;
- [ ] `Underworld main merge gate` ruleset exists and is Active;
- [ ] target is only default branch / `main`;
- [ ] pull request required before merge;
- [ ] branches must be up to date before merge;
- [ ] direct push restricted;
- [ ] force push blocked;
- [ ] branch deletion blocked;
- [ ] `Godot character contracts` required;
- [ ] `Repository layout contracts` required;
- [ ] stable `Godot headless contracts` required;
- [ ] `PM acceptance` required from the distinct PM App source;
- [ ] GitHub Actions App is not accepted as PM-status source;
- [ ] no ordinary Actions/worker bypass configured;
- [ ] no self-approval rule that deadlocks same-account workflow;
- [ ] Actions spoof attempt does not satisfy PM requirement;
- [ ] synchronize invalidation observed;
- [ ] same-head race invariant observed;
- [ ] stale-main rejection observed;
- [ ] draft behavior observed;
- [ ] direct-push rejection observed.

## Invariants

1. Green CI is necessary but never sufficient.
2. Required `PM acceptance` is source-bound to a distinct external PM App, not GitHub Actions.
3. Candidate PR workflows cannot satisfy the source-bound PM requirement by posting the same context name.
4. Repository Actions never hold credentials that let them publish as the external PM App.
5. Only explicit current-head PM acceptance may grant success.
6. New heads require revalidation and re-acceptance.
7. Draft/lifecycle transitions cannot manufacture approval.
8. Same-head event races cannot leave authoritative success when live approval state is invalid.
9. `pm-accepted` remains an operational signal under the current same-principal human-role model.
10. The full deterministic campaign remains ten shards covering 2,250 seed/region cases.
11. `Godot headless contracts` is the stable deterministic aggregate.
12. Branches must be up to date with `main` before merge.
13. Normal `main` updates use pull requests only.
14. Force pushes and branch deletion are not normal workflow.
15. Emergency bypass is temporary, explicit, narrow, and recorded.
16. Governance rules never authorize violating architecture, dependency, or protected-roadmap contracts.
17. No MAP-009→MAP-015 production/runtime contract is changed by this governance mechanism.
