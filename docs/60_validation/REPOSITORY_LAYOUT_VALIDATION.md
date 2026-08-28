# Repository Layout Validation

Status: **STAGE 1 IMPLEMENTED AND ENFORCED IN CI**

The repository/file architecture is partially machine-enforced so structural drift is caught before many files accumulate in the wrong layer.

This validation complements content, character and deterministic worldgen validation. It does not replace code review or architectural judgment.

## Current implementation

The executable policy lives in:

```text
tools/ci/repository_layout_policy.json
tools/ci/validate_repository_layout.py
.github/workflows/repository-layout-validation.yml
```

The policy file is the migration-state source of truth for root placement. A root may be canonical, temporarily legacy-allowed, or forbidden.

Current migration state:

```text
canonical:
  .github/
  addons/
  app/
  content/
  core/
  docs/
  gameplay/
  presentation/
  tests/
  third_party/
  tools/
  world/
  worldgen/

legacy_allowed:
  data/

forbidden:
  combat/
  game/
  player/
  scenes/
  scripts/
```

`game/`, `player/` and `combat/` became forbidden after their staged migrations completed. `data/` remains the only temporary top-level compatibility root until its prototype settings/data responsibilities are split and migrated deliberately.

Stage 1 CI currently enforces:

- tracked files may only enter reviewed top-level ownership roots;
- retired `combat/`, `game/` and `player/` roots may not return;
- Godot resource references may not use `res://combat/`, `res://game/` or `res://player/`;
- production/runtime roots may not import from `tests/` or `tools/`;
- `worldgen/` may not import concrete runtime/app/presentation domains;
- `core/` may not import concrete game domains;
- the validator reports which temporary legacy roots are still present.

The checker intentionally uses simple path/reference rules. It does not attempt to parse architectural intent from class names or infer ownership from implementation details.

## Named migration exceptions

Dependency exceptions must be explicit, file-specific, prefix-specific and carry a reason in `repository_layout_policy.json`. The validator checks that every exception references a real source file and a real forbidden prefix.

Current exception:

```text
worldgen/migration/legacy_v2_surface_resolver.gd
  may reference res://world/
```

Reason: the frozen prototype-v2 save migration must replay the legacy terrain and pickup generators exactly to map old accepted-index IDs to stable semantic IDs. This exception does **not** permit other `worldgen/` files to depend on `world/`, and it does not permit that resolver to import gameplay, presentation, combat or app code.

Remove the exception when the legacy-v2 replay path is retired or isolated behind a pure compatibility package.

## What can be validated mechanically

The validator may grow to check:

- expected top-level ownership roots;
- content-definition files remain under approved `content/` families;
- production/runtime code does not live under `tests/` or `tools/`;
- runtime project code does not import from `tests/`;
- runtime project code does not import from editor-only `tools/`;
- `third_party/` packages preserve license metadata;
- known authored content files do not use patch/final-copy naming conventions;
- no documentation ordering prefix is used as a semantic content namespace;
- no duplicate canonical file-placement conventions exist for the same family after migration is complete;
- test runners/fixtures follow their owned roots where practical.

## What should not be reduced to a filename linter

Do not pretend automated layout checks can prove:

- whether a new mechanic belongs in `core/` or `gameplay/`;
- whether a class is genuinely reusable;
- whether one content family deserves another category;
- whether a PackedScene is pure presentation or unique gameplay composition;
- whether a domain should be split for maintainability.

Those remain architecture-review decisions.

## Migration-aware validation

The validator supports staged migration instead of requiring a mass rename.

Conceptual migration state:

```text
legacy_allowed
migrating
canonical
forbidden
```

The current machine policy represents `canonical`, `legacy_allowed`, and `forbidden` directly. A `migrating` state is represented operationally by a dedicated migration branch/PR while the source root remains legacy-allowed until the atomic move is complete.

Once one legacy root has been fully migrated and all active references are updated, move that root from `legacy_allowed_roots` to `forbidden_roots` in the policy.

Do not keep legacy paths allowed after their migration is complete.

## Import/dependency validation

Static dependency checking inspects resource-path references in Godot text resources and flags only clearly forbidden root dependencies.

Examples:

```text
runtime gameplay → tests/       ERROR
runtime gameplay → tools/       ERROR
worldgen → gameplay/             ERROR
worldgen → presentation/         ERROR
core → gameplay/                 ERROR
```

Some dependencies require semantic review and should not be guessed by simple path rules. Required compatibility exceptions must be encoded narrowly rather than weakening an entire dependency rule.

## Content/path identity check

Content validation should ensure semantic authored identity does not become equivalent to its current path.

A moved `.tres` file with unchanged `content_id` should remain the same game concept.

A semantic ID rename must remain an explicit migration even if the file path did not move.

## Naming diagnostics

Potential future lint warnings/errors may include patterns such as:

```text
*_final.*
*_final2.*
*_v3_final.*
manager2.gd
helper.gd
stuff.gd
new_*.tres
copy_of_*.tres
```

These should begin as warnings where false positives are plausible.

## Empty-directory policy

Git does not track empty directories.

Validation must not require the full destination tree to exist before real files require it.

The architecture defines legal placement; it does not require empty placeholder folders.

## CI output

A successful run reports a compact summary similar to:

```text
[REPOSITORY LAYOUT] PASS
  policy version: 1
  tracked files: 184
  production files: 84
  test files: 42
  tool files: 2
  legacy roots present: data
  dependency exceptions used: 1
  forbidden root dependencies: 0
  retired path violations: 0
```

Exact counts are informational and are not compatibility contracts.

## Staged implementation

Current progress:

1. canonical tree and legacy migration map — **done**;
2. lightweight root/path policy checker — **done**;
3. forbidden production → tests/tools dependency checks — **done**;
4. narrow, validated migration exceptions — **done**;
5. tighten legacy path rules after actual domain migrations — **active, domain by domain**;
6. content-registry/content validation — **future family cycle**;
7. richer static dependency checks — **only where they produce reliable signal**.

## Merge policy

Once a path family has been declared canonical and the old root is marked forbidden, new changes must not reintroduce that retired location.

The validator prevents structural drift. It must not be used to force unrelated mass renames or to replace architecture review.
