# Repository Layout Validation

Status: **DIRECTIONAL validation contract; implementation deferred**

The repository/file architecture should eventually be partially machine-enforced so structural drift is caught before hundreds of files accumulate in the wrong layer.

This validation complements content, character and deterministic worldgen validation. It does not replace code review or architectural judgment.

## What can be validated mechanically

Future layout validation may check:

- forbidden generic top-level roots such as `scripts/`, `scenes/` or new unreviewed `data/` dumps;
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

The repository currently contains prototype roots such as:

```text
player/
combat/
game/
data/
```

These are explicitly allowed during staged migration.

A layout validator must therefore support a compatibility allowlist/transition policy rather than immediately failing all current paths.

Conceptual migration state:

```text
legacy_allowed
migrating
canonical
forbidden
```

Once one legacy root has been fully migrated and all active branches/reference paths are updated, that root can move from `legacy_allowed` to `forbidden`.

Do not keep legacy paths allowed forever after their migration is complete.

## Import/dependency validation

A future static dependency checker may inspect script preload/load/extends references and flag clearly forbidden root dependencies.

Examples:

```text
runtime gameplay → tests/       ERROR
runtime gameplay → tools/       ERROR
worldgen → player/               ERROR
worldgen → presentation/         ERROR
core → gameplay/                 ERROR
```

Some dependencies require semantic review and should not be guessed by simple path rules.

## Content/path identity check

Content validation should ensure semantic authored identity does not become equivalent to its current path.

A moved `.tres` file with unchanged `content_id` should remain the same game concept.

A semantic ID rename must remain an explicit migration even if the file path did not move.

## Naming diagnostics

Potential lint warnings/errors may include patterns such as:

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

Validation should not require the full destination tree to exist before real files require it.

The architecture defines legal placement; it does not require empty placeholder folders.

## Canonical summary target

A future CI check could report:

```text
[REPOSITORY LAYOUT] PASS
production files: 184
content definitions: 527
presentation assets: 1134
test files: 92
tool files: 14
forbidden root dependencies: 0
legacy path violations: 0
naming errors: 0
```

Exact counts/output are implementation details.

## Staged implementation

Recommended order:

1. document the canonical tree and legacy migration map;
2. implement content-registry/content validation first;
3. add a lightweight root/path policy checker;
4. add forbidden production → tests/tools dependency checks;
5. tighten legacy path rules only after actual domain migrations;
6. add richer static dependency checks only where they produce reliable signal.

## Merge policy

Once repository-layout validation exists and a path family has been declared canonical, new changes should not introduce avoidable files into retired legacy locations.

The validator should prevent drift, not force unnecessary mass renames.