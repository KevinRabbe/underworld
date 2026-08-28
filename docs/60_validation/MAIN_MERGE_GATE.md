# Underworld — Main Merge Gate

Status: **repository-governance contract**

This document defines the enforceable merge gate for `main`. It complements the pull task board; it does not replace architecture review, dependency review or exact-head validation.

## Why this exists

GitHub currently reports `main` as unprotected and the repository has no active rulesets. That allowed protected-roadmap PRs to merge even while the PM board still recorded unresolved dependency/review gates.

Green CI is necessary, but green CI alone must not authorize a merge.

The target policy is:

```text
required broad CI
+ explicit PM acceptance
+ non-draft PR
+ pull-request-only main updates
= merge eligible
```

## Required PR checks

The `main` ruleset must require these check-run contexts on every pull request:

| Workflow | Required check-run context |
| --- | --- |
| Character Validation | `Godot character contracts` |
| Repository Layout Validation | `Repository layout contracts` |
| Deterministic Worldgen Validation | `Godot headless contracts` |
| PM Acceptance Gate | `PM acceptance` |

The existing three validation workflows already run for every pull request. The PM Acceptance Gate is defined in `.github/workflows/pm-acceptance-gate.yml`.

Do not configure only the workflow display names when GitHub asks for a required status-check context; select the actual check-run contexts shown above.

## PM acceptance signal

The explicit machine-readable acceptance signal is the pull-request label:

```text
pm-accepted
```

The `PM acceptance` check fails when either:

- the PR is still a draft; or
- the `pm-accepted` label is absent.

It reruns when the PR is opened/reopened, synchronized, labeled/unlabeled, marked ready for review, or converted back to draft.

### Operational ownership

Workers must never add `pm-accepted` to their own handoff PRs merely to make CI green.

The label means the PM has reviewed the current handoff state and accepts the PR for landing, subject to the required checks remaining green.

Because PM and worker activity currently use the same GitHub account, GitHub review identity cannot distinguish those roles. Requiring an approving review would deadlock self-authored PRs because GitHub does not allow self-approval. The label/check mechanism therefore represents the role transition without relying on a separate reviewer identity.

This is a workflow-control boundary, not a cryptographic separation between two GitHub users. If the project later moves PM approval to a distinct GitHub App/account/team, the acceptance signal should be upgraded accordingly.

## Required `main` branch ruleset

Create one active branch ruleset targeting the default branch / `refs/heads/main` with the following behavior.

### Target

```text
Ruleset name: Underworld main merge gate
Enforcement: Active
Target: default branch (`main`)
```

### Pull request requirement

Enable **Require a pull request before merging**.

Do not require one approving review while the repository uses the same GitHub identity for PM and worker PRs. The four required checks, including `PM acceptance`, are the enforceable landing gate.

If GitHub offers a setting to require conversation resolution, enable it once the project starts using blocking inline review threads consistently. It is not required for this first gate.

### Required status checks

Require all four contexts:

```text
Godot character contracts
Repository layout contracts
Godot headless contracts
PM acceptance
```

Required checks must pass on the current PR head. Stale success from an earlier head is not acceptance.

Do not enable a broad bypass that allows ordinary automation to merge with required checks pending or failing.

### Direct update restrictions

Enable protections that prevent normal workflow from:

- pushing directly to `main`;
- force-pushing `main`;
- deleting `main`.

All routine changes land through pull requests.

### Draft behavior

GitHub already prevents ordinary merging of draft PRs. The PM Acceptance Gate independently fails for draft PRs so the required check state also makes the rule explicit and testable.

A PR converted back to draft must lose merge eligibility immediately even if it still carries `pm-accepted`; the gate fails until it is ready for review again.

## Acceptance lifecycle

Normal worker/PM flow:

```text
worker opens draft PR
        ↓
required CI runs
        ↓
worker handoff reaches REVIEW
        ↓
PM reviews scope/dependencies/content
        ↓
PR marked ready for review when appropriate
        ↓
PM adds pm-accepted
        ↓
PM acceptance check passes
        ↓
all required checks green on exact head
        ↓
merge allowed by ruleset
```

### New commits after PM acceptance

A new commit must be treated as a new exact-head review state.

Operational rule: remove `pm-accepted` before or immediately when additional implementation commits are pushed after acceptance. The PM may re-add it after reviewing the new head.

The workflow reruns on `synchronize`; however a GitHub label remains attached across commits. Therefore the human/automation process must remove stale acceptance when a previously accepted PR changes materially.

A future stronger implementation may automate label removal on synchronize if a separate trusted PM identity/app becomes available. Do not let an untrusted PR workflow mutate the acceptance label.

## Emergency bypass policy

There is no routine bypass actor.

Do **not** give all repository admins, all Actions workflows or the ordinary worker account a permanent ruleset bypass merely for convenience.

Emergency procedure is intentionally explicit:

1. repository owner identifies an actual repository-blocking emergency;
2. record the reason and affected PR/commit on the PM board;
3. temporarily alter/disable the ruleset only for the minimum action required;
4. perform the emergency change;
5. restore the active ruleset immediately;
6. verify `main` is protected again and record the result.

Emergency bypass is not for skipping architecture review, long CI, dependency order or a failed PM gate.

## Required verification campaign

After the in-repo gate workflow is merged and the owner activates the GitHub ruleset, verify behavior rather than assuming configuration is correct.

Use a throwaway branch/PR with a documentation-only change so no protected production behavior is involved.

### Case 1 — green CI without PM acceptance

Expected:

```text
broad CI = green
PM acceptance = failing (no pm-accepted label)
merge = blocked
```

### Case 2 — PM accepted and green

Mark the PR ready for review and add `pm-accepted`.

Expected:

```text
broad CI = green
PM acceptance = green
merge = allowed
```

Do not actually merge the throwaway PR if the test can be completed by observing merge eligibility.

### Case 3 — draft PR

Convert the PR to draft.

Expected:

```text
PM acceptance = failing
merge = blocked
```

### Case 4 — direct push

Attempt a harmless normal direct push to `main` from the ordinary workflow identity only after preserving the branch state locally/remotely.

Expected:

```text
push rejected by GitHub ruleset
main unchanged
```

Do not use an administrative bypass for this test.

## Connector/tooling limitation

The current ChatGPT GitHub connector can read repository rulesets but does not expose a write action for branch protection/ruleset settings.

Therefore this task has two distinct parts:

1. **in-repository support** — workflow + documented exact configuration; can be implemented through the connector;
2. **repository-owner activation** — create/enable the ruleset in GitHub settings and run the verification campaign; cannot be completed through the currently exposed connector actions.

Until owner activation is complete, the PM board remains authoritative but technically non-enforceable.

## Ruleset activation checklist

Repository owner should verify all of the following in GitHub settings:

- [ ] ruleset `Underworld main merge gate` exists and is Active;
- [ ] target is only the default branch / `main`;
- [ ] pull request required before merge;
- [ ] direct push restricted for normal workflow;
- [ ] force push blocked;
- [ ] branch deletion blocked;
- [ ] `Godot character contracts` required;
- [ ] `Repository layout contracts` required;
- [ ] `Godot headless contracts` required;
- [ ] `PM acceptance` required;
- [ ] no ordinary Actions/worker bypass actor configured;
- [ ] no self-approval review requirement that deadlocks the current account model;
- [ ] four verification cases above observed and recorded.

## Invariants

1. Green CI is necessary but never sufficient by itself.
2. Draft PRs cannot satisfy PM acceptance.
3. `pm-accepted` represents explicit PM landing approval, not worker implementation completion.
4. Required checks apply to the exact current PR head.
5. Normal updates to `main` use pull requests only.
6. Force pushes and branch deletion are not part of normal workflow.
7. Emergency bypass is temporary, explicit and recorded.
8. Ruleset enforcement does not authorize violating architecture or dependency contracts.
9. No protected MAP-009→MAP-015 production/runtime contract is changed by this governance mechanism.
