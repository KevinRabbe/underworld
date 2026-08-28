# Underworld — Main Merge Gate

Status: **repository-governance contract**

This document defines the enforceable merge gate for `main`. It complements the pull task board; it does not replace architecture review, dependency review, protected-roadmap ownership, or exact-head validation.

## Why this exists

GitHub has allowed `main` to advance while PM/dependency gates were still unresolved because those gates were process signals rather than repository rules.

Green CI is necessary, but green CI alone must not authorize a merge.

The target policy is:

```text
required broad CI
+ exact-current-head PM acceptance
+ non-draft PR
+ pull-request-only main updates
= merge eligible
```

## Required PR checks

The `main` ruleset must require these check-run contexts:

| Workflow | Required check-run context |
| --- | --- |
| Character Validation | `Godot character contracts` |
| Repository Layout Validation | `Repository layout contracts` |
| Deterministic Worldgen Validation | `Godot headless contracts` |
| PM Acceptance Gate | `PM acceptance` |

Do not configure only workflow display names when GitHub asks for required status-check contexts; select the check-run contexts above.

## PM acceptance signal

The machine-readable operational signal is the pull-request label:

```text
pm-accepted
```

The `PM acceptance` check fails when any of the following is true:

- the PR is a draft;
- `pm-accepted` is absent; or
- the triggering action is `synchronize`, meaning the PR head changed.

A new commit therefore cannot inherit a passing PM-acceptance check from an earlier head.

## Exact-head invalidation

`.github/workflows/pm-acceptance-gate.yml` deliberately uses two event boundaries in one workflow.

### PR-head gate — `pull_request`

The required `PM acceptance` check runs on the pull-request head for:

- opened;
- reopened;
- synchronize;
- labeled;
- unlabeled;
- ready-for-review;
- converted-to-draft.

On every `synchronize` event it fails **unconditionally**, even if the event payload still contains `pm-accepted`.

This prevents event-ordering from leaving the new head with a passing required check merely because GitHub labels persist across commits.

### Trusted invalidator — `pull_request_target`

A separate job runs only for `pull_request_target: synchronize`.

It:

- uses the workflow definition from the trusted default branch;
- receives only the permissions needed to read repository metadata and mutate issue/PR labels;
- does **not** check out PR code;
- does **not** execute scripts, actions, binaries, or other content from the PR branch;
- removes `pm-accepted` if it survived the head change;
- verifies the label is absent after invalidation.

The invalidator's label removal triggers an `unlabeled` PR event, so the PR-head gate evaluates the same current head again and remains failing because acceptance is absent.

Only a later explicit re-addition of `pm-accepted` may make the current head pass.

### Event-order invariant

For an accepted SHA A followed by a pushed SHA B:

```text
SHA A + pm-accepted
        ↓
new commit pushed
        ↓
pull_request:synchronize on SHA B
        ↓
PM acceptance = FAIL regardless of label state
        ↓
pull_request_target:synchronize removes stale pm-accepted
        ↓
pull_request:unlabeled on SHA B
        ↓
PM acceptance = FAIL
        ↓
PM reviews SHA B and re-adds pm-accepted
        ↓
pull_request:labeled on SHA B
        ↓
PM acceptance may PASS
```

This is the required exact-current-head behavior.

## Operational ownership and security boundary

Workers must never add `pm-accepted` to their own handoff PRs merely to make CI green.

The label means the PM role has reviewed the current head and accepts it for landing, subject to every other required check and dependency gate remaining satisfied.

However, this repository currently uses the same GitHub owner/app permission surface for PM and worker activity. Therefore:

- `pm-accepted` is an **operational workflow-control signal**;
- it is **not** a cryptographic or actor-separated authorization boundary;
- any principal with sufficient issue/PR-write permission could theoretically apply the label;
- the mechanism prevents ordinary automated or accidental merges from treating green CI alone as acceptance, but it does not defend against a malicious repository owner or another equally privileged principal.

True actor-separated PM authorization requires a distinct GitHub account, App, team, environment approval, or another owner-controlled mechanism whose credentials ordinary workers do not possess.

The project should upgrade to such a boundary if/when separate identities are available.

## Why no required approving review yet

GitHub does not permit a user to approve their own PR. With the present same-account workflow, requiring one approving review would deadlock self-authored PRs rather than establish meaningful role separation.

Therefore this first enforceable gate uses required status checks plus the operational `pm-accepted` signal.

## Required `main` ruleset

Create one active branch ruleset targeting only `refs/heads/main` / the default branch.

### Target

```text
Ruleset name: Underworld main merge gate
Enforcement: Active
Target: default branch (`main`)
```

### Pull request requirement

Enable **Require a pull request before merging**.

Do not require one approving review while PM and workers share the same GitHub principal.

If GitHub conversation-resolution requirements become part of the review process later, enable them as a separate deliberate decision.

### Required status checks

Require all four contexts:

```text
Godot character contracts
Repository layout contracts
Godot headless contracts
PM acceptance
```

Required checks must pass on the current PR head. Success from an earlier SHA is never acceptance for a later SHA.

### Direct update restrictions

Normal workflow must not be able to:

- push directly to `main`;
- force-push `main`;
- delete `main`.

All routine updates land through pull requests.

### Bypass policy

Do not give ordinary workers, ordinary Actions workflows, or broad automation identities a permanent ruleset bypass.

Repository-owner administrative capability remains inherently powerful; treat its use as emergency authority, not normal merge flow.

## Acceptance lifecycle

```text
worker opens draft PR
        ↓
required CI runs
        ↓
worker handoff reaches REVIEW
        ↓
PM reviews exact current head
        ↓
PR marked ready for review when appropriate
        ↓
PM adds pm-accepted
        ↓
PM acceptance passes for that head
        ↓
all other required checks green on same head
        ↓
merge allowed by active ruleset
```

If any implementation commit is pushed after acceptance, the synchronize path invalidates acceptance automatically. Manual label-removal discipline is not relied upon.

## Draft behavior

Draft PRs cannot satisfy the PM gate even if `pm-accepted` is present.

Converting an accepted PR back to draft therefore immediately removes merge eligibility at the required-check level.

## Emergency bypass policy

There is no routine bypass actor.

Emergency procedure:

1. repository owner identifies an actual repository-blocking emergency;
2. record the reason and affected PR/commit on the PM board;
3. temporarily alter or disable only the minimum rule necessary;
4. perform the emergency action;
5. restore the active ruleset immediately;
6. verify `main` is protected again;
7. record the verification result.

Emergency bypass is not for skipping architecture review, dependency order, long CI, a failed PM gate, or protected-roadmap ownership.

## Required verification campaign

The trusted `pull_request_target` invalidator cannot be fully exercised until its workflow exists on the default branch, because `pull_request_target` deliberately uses default-branch workflow code.

After this support is merged and the repository owner activates the ruleset, use a throwaway documentation-only PR for the complete campaign.

### Case 1 — green broad CI without acceptance

Expected:

```text
broad CI = green
PM acceptance = failing
merge = blocked
```

### Case 2 — PM accepted current head

Make the PR non-draft and add `pm-accepted` after review.

Expected:

```text
broad CI = green
PM acceptance = green
merge = allowed
```

### Case 3 — exact-head invalidation

From the accepted state, push a harmless new commit.

Expected:

```text
pull_request:synchronize = PM acceptance FAIL on new head
pull_request_target:synchronize = stale pm-accepted removed
new head remains blocked until explicit re-acceptance
```

Verify the final current-head required context cannot remain green because of event ordering.

### Case 4 — draft transition

Convert an accepted PR back to draft.

Expected:

```text
PM acceptance = failing
merge = blocked
```

### Case 5 — direct push

Attempt a harmless normal direct push to `main` without administrative bypass.

Expected:

```text
push rejected by GitHub ruleset
main unchanged
```

## Connector/tooling limitation

The current connected GitHub tooling can read repository rulesets and protection state but does not expose a write action for creating/enabling those settings.

Therefore #118 has two layers:

1. **in-repository support** — exact-head workflow and documented configuration;
2. **repository-owner activation** — enable the actual GitHub ruleset and run the end-to-end campaign.

Until owner activation is complete, PM/dependency policy remains operational rather than technically enforced on `main`.

## Ruleset activation checklist

- [ ] `Underworld main merge gate` exists and is Active;
- [ ] target is only default branch / `main`;
- [ ] pull request required before merge;
- [ ] direct push restricted for normal workflow;
- [ ] force push blocked;
- [ ] branch deletion blocked;
- [ ] `Godot character contracts` required;
- [ ] `Repository layout contracts` required;
- [ ] `Godot headless contracts` required;
- [ ] `PM acceptance` required;
- [ ] no ordinary Actions/worker bypass configured;
- [ ] no self-approval rule that deadlocks the same-account workflow;
- [ ] exact-head invalidation campaign observed successfully;
- [ ] draft and direct-push cases observed successfully.

## Invariants

1. Green CI is necessary but never sufficient by itself.
2. Draft PRs cannot satisfy PM acceptance.
3. Every synchronize event invalidates acceptance for the new head.
4. Stale `pm-accepted` is removed by trusted default-branch workflow code without executing PR-controlled code.
5. Re-acceptance is explicit and applies only to the then-current head.
6. `pm-accepted` is an operational signal, not actor-separated security under the current same-principal model.
7. Normal updates to `main` use pull requests only.
8. Force pushes and branch deletion are not normal workflow.
9. Emergency bypass is temporary, explicit, narrow, and recorded.
10. Ruleset enforcement never authorizes violating architecture, dependency, or protected-roadmap contracts.
11. No MAP-009→MAP-015 production/runtime contract is changed by this governance mechanism.
