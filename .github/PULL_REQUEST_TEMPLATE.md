## Task

- Issue / ID: <!-- e.g. #123 / MAP-016 -->
- Handoff state: <!-- DRAFT / REVIEW / DEFERRED / other explicit state -->

## Goal and scope

<!-- What does this PR accomplish? Keep this specific. -->

### Files / systems touched

<!-- List the intentional files, folders, or subsystem boundaries. -->

### Intentionally excluded / do-not scope

<!-- Name nearby work this PR deliberately does not enter. Use `None` when truly unnecessary. -->

## Dependencies and base assumptions

- Base / expected parent: <!-- branch or exact commit when sequencing matters -->
- Depends on: <!-- issues, PRs, contracts, or `None` -->
- Blocks / unlocks: <!-- if applicable -->
- Draft or deferred reason: <!-- required when intentionally draft/deferred; otherwise `N/A` -->

## Protected-scope check

- [ ] I verified this PR does not enter another worker's/reserved scope, or the owning task explicitly authorizes the overlap.
- [ ] Any protected-contract discovery is reported to the owning card instead of being silently expanded here.

## Validation

### Local / focused evidence

<!-- Commands/runners and results. Do not claim checks that were not run. -->

### Exact-head CI

- Head SHA: <!-- exact commit under review -->
- Checks: <!-- PASS / RUNNING / NOT REQUIRED, with names when relevant -->

> Green CI is necessary but not sufficient when a dependency, protected-roadmap, or PM review gate exists. Do not merge past an explicit gate solely because checks are green.

## Discoveries / follow-ups

<!-- New defects, deferred work, migration notes, or `None`. -->
