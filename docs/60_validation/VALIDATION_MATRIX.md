# Project Validation Matrix

Status: **CURRENT VALIDATION INDEX**

This document is the quick-reference index for the repository's current validation surface. It records what each check protects, the real local command used by CI, its approximate cost class, and when exact-head GitHub evidence is required.

It does not define new validation behavior. Workflow YAML, runner scripts, timeouts, and generator contracts remain authoritative for execution semantics.

## Acceptance rule: local evidence vs exact-head CI

A local PASS is useful implementation evidence, but it is not merge acceptance by itself.

For merge/review handoff:

1. validate the scoped change locally with the relevant fast/focused runners when practical;
2. push the candidate head;
3. require the applicable GitHub checks to pass on that **exact PR head SHA**;
4. if the branch head changes, older CI evidence is stale for acceptance and the applicable checks must pass again;
5. a green check proves only the invariant owned by that check. It does not replace architecture or PM review.

Do not manually rerun long deterministic campaigns merely to add documentation evidence. Let the normal PR workflow provide exact-head evidence when it is configured to trigger.

## Current workflow inventory

There are currently five workflow files under `.github/workflows/`. All five are accounted for below.

| Workflow / check | Protects | Local command / runner | Cost class | Run locally when | Exact-head CI before merge |
| --- | --- | --- | --- | --- | --- |
| **Character Validation** (`character-validation.yml`) | Character/player/combat contracts and prototype integration | `godot --headless --path . --quit-after 1 --script res://tests/run_character.gd` | Fast contract | Character, player, combat, animation-action, equipment-socket, or nearby gameplay changes | **Yes.** Currently triggers on every PR. |
| **Deterministic Worldgen Validation — fast** (`foundation-validation.yml`) | Deterministic identity, topology, entrances, connectivity, geometry, provenance/foundation contracts included by `tests/run_validation.gd` fast mode | `godot --headless --path . --quit-after 1 --script res://tests/run_validation.gd -- --mode=fast` | Fast contract | Any worldgen/foundation/persistence change; also before handing off protected deterministic work | **Yes.** The workflow currently triggers on every PR. |
| **Deterministic Worldgen Validation — batch** (`foundation-validation.yml`) | Reproduction/determinism across a broad seed + region campaign | `godot --headless --path . --quit-after 1 --script res://tests/run_validation.gd -- --mode=batch --start-seed=1 --count=250 --region-radius=1` | **Long deterministic campaign** | Only when deterministic/worldgen behavior needs campaign evidence; do not casually rerun for unrelated changes | **Yes when the workflow runs.** This step is part of the same every-PR workflow. |
| **Map Data Serialization Validation** (`map-data-serialization-validation.yml`) | Persistence/map-data serialization contracts under `worldgen/persistence/**` and `tests/persistence/**` | `godot --headless --path . --quit-after 1 --script res://tests/run_map_data_serialization_validation.gd` | Focused contract | Persistence schema, map-data serialization, persistence fixtures, or its runner changes | **Yes when relevant/triggered.** PR paths are filtered to persistence files, tests, runner, or workflow. |
| **Repository Layout Validation** (`repository-layout-validation.yml`) | Canonical roots, retired paths, forbidden dependency directions, explicit migration exceptions | `python3 tools/ci/validate_repository_layout.py` | Structural check | Any file move/addition, dependency-root change, architecture migration, or policy change; cheap enough to run routinely | **Yes.** Currently triggers on every PR. |
| **Worldgen Inspector Validation — inspector contracts** (`worldgen-inspector-validation.yml`) | Deterministic topology-inspector tooling contracts | `godot --headless --path . --quit-after 1 --script res://tools/worldgen/run_topology_inspector_contracts.gd` | Focused contract | `tools/worldgen/**` or inspector-facing worldgen changes | **Yes when relevant/triggered.** |
| **Worldgen Inspector Validation — atlas contracts** (`worldgen-inspector-validation.yml`) | Multi-region atlas tooling contracts | `godot --headless --path . --quit-after 1 --script res://tools/worldgen/run_topology_atlas_contracts.gd` | Focused contract | Atlas/export tooling or worldgen data consumed by the atlas changes | **Yes when relevant/triggered.** |
| **Worldgen Inspector Validation — sample snapshot export** (`worldgen-inspector-validation.yml`) | End-to-end JSON/SVG topology snapshot export | `godot --headless --path . --quit-after 1 --script res://tools/worldgen/export_topology_snapshot.gd -- --seed=12345 --region-x=0 --region-z=0 --out-dir=/tmp/underworld-worldgen-inspector --basename=ci_sample` | Focused export check | Snapshot exporter/schema/rendering changes | **Yes when relevant/triggered.** |
| **Worldgen Inspector Validation — sample 3x3 atlas export** (`worldgen-inspector-validation.yml`) | End-to-end JSON/SVG atlas and elevation exports over a 3x3 region set | `godot --headless --path . --quit-after 1 --script res://tools/worldgen/export_topology_atlas.gd -- --seed=12345 --center-x=0 --center-z=0 --radius=1 --out-dir=/tmp/underworld-worldgen-inspector --basename=ci_atlas` | Focused export check | Atlas/elevation exporter changes or worldgen representation changes consumed by the tool | **Yes when relevant/triggered.** |

### Long deterministic campaign warning

The batch command in `foundation-validation.yml` uses `--count=250 --region-radius=1`. Radius 1 evaluates a 3x3 region neighborhood, so the configured campaign covers **250 × 9 = 2,250 seed/region cases**.

Treat this as expensive integration evidence, not a default edit-compile loop. Prefer the fast mode while iterating, then rely on the configured exact-head campaign when the candidate is ready for review.

## Workflow trigger notes

Current PR behavior matters when planning evidence:

- `character-validation.yml`: every pull request.
- `foundation-validation.yml`: every pull request; includes both fast and 2,250-case batch steps.
- `repository-layout-validation.yml`: every pull request.
- `map-data-serialization-validation.yml`: PR path-filtered to persistence implementation/tests/runner/workflow.
- `worldgen-inspector-validation.yml`: PR path-filtered to `tools/worldgen/**`, `worldgen/**`, or its workflow file.

Because several workflows are broad, a docs-only PR can still receive unrelated-but-required repository integration checks. Do not interpret that as a reason to manually run every expensive check before writing docs.

## Change type → recommended gates

This matrix describes practical worker evidence. The actual workflow trigger plus PM/reviewer instructions remain authoritative if they require more.

| Change type | Recommended local evidence | Expected/relevant exact-head CI |
| --- | --- | --- |
| **Docs-only** | Usually no Godot runner needed. Run repository-layout validation if adding/moving paths or architecture references. | Character Validation, Deterministic Worldgen Validation, and Repository Layout currently trigger on every PR. Additional path-filtered checks only if their paths are touched. |
| **Gameplay / character** | Character Validation; Repository Layout when dependencies/paths change | Character + broad Deterministic Worldgen + Repository Layout. Add specialized checks if persistence/worldgen/tooling is also touched. |
| **Persistence / serialization** | Map Data Serialization + deterministic fast mode; Repository Layout | Map Data Serialization when path-filtered, plus broad Character + Deterministic Worldgen + Repository Layout. |
| **Worldgen / deterministic generation** | Deterministic fast mode first. Add focused inspector contracts when the change affects inspector-consumed structures. Use the batch campaign only for candidate/integration evidence, not every edit. | Deterministic Worldgen + Repository Layout + Character; Worldgen Inspector when its path filter matches. |
| **Repository layout / architecture migration** | `python3 tools/ci/validate_repository_layout.py`; run subsystem contracts for any moved production code | Repository Layout + broad Character + Deterministic Worldgen; any relevant path-filtered suite. |
| **Developer tooling / worldgen inspector** | Inspector and/or atlas contracts plus the relevant sample export; Repository Layout | Worldgen Inspector + broad Character + Deterministic Worldgen + Repository Layout. |

## Specialized validation documents

Use these for the detailed contract instead of duplicating their contents here:

- [`REPOSITORY_LAYOUT_VALIDATION.md`](REPOSITORY_LAYOUT_VALIDATION.md) — repository roots, dependency direction, migration exceptions, and structural policy.
- [`CONTENT_VALIDATION.md`](CONTENT_VALIDATION.md) — **future/deferred** authored-content validation architecture. It is not a current workflow and must not be mistaken for an implemented CI check.

## Worker handoff checklist

Before moving a task to REVIEW:

- identify which subsystem/invariant the change actually touches;
- run the relevant local fast/focused checks where practical;
- do not substitute an unrelated green suite for the owning suite;
- do not manually rerun the 2,250-case campaign without a deterministic/integration reason;
- verify the PR contains only scoped files;
- record the exact candidate head SHA;
- ensure the applicable GitHub checks pass on that exact head;
- report broken/duplicate workflow behavior as a discovery rather than silently changing CI inside an unrelated task.

## Updating this index

Update this document when a workflow is added, removed, renamed, materially changes its runner/trigger, or when a new implemented validation family becomes part of merge acceptance. Copy commands from the executable workflow/runner; do not guess them from memory or from planned architecture documents.
