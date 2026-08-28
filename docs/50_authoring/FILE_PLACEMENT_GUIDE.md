# File Placement Guide

Status: **LOCKED authoring workflow direction**

Use this guide whenever a new file, scene, definition, asset, test or tool is added to Underworld.

The detailed repository contract is `docs/10_architecture/REPOSITORY_STRUCTURE.md`.

## First question: what owns this file?

Choose the owner before choosing the filename.

```text
application/bootstrap composition      → app/
domain-neutral infrastructure          → core/
player/combat/items/etc runtime logic  → gameplay/
live world/runtime streaming           → world/
deterministic generated world truth    → worldgen/
authored semantic definitions          → content/
visual/audio/animation/UI assets        → presentation/
development/editor/CI tooling           → tools/
automated tests/fixtures                → tests/
architecture/design guidance            → docs/
external vendored material              → third_party/ or addons/
```

If two roots both seem equally correct, the responsibility is probably not yet separated clearly enough.

## Second question: system code or authored variation?

Ask whether the file defines **how a system works** or **one member/configuration used by the system**.

Example:

```text
gameplay/combat/attacks/attack_definition.gd
```
contains the schema/contract for attacks.

```text
content/attacks/player/sword_light_01.tres
```
is one authored attack definition.

Do not create `iron_sword_attack.gd` simply to hold values that belong in an authored definition.

## Third question: gameplay or presentation?

If replacing the model/texture/animation/audio should leave gameplay behavior unchanged, the concrete asset belongs under `presentation/`.

Example:

```text
presentation/items/weapons/swords/iron_sword/iron_sword_visual.tscn
```

The sword's semantic gameplay definition remains under `content/`.

## PackedScene decision

A `.tscn` belongs according to ownership, not because all scenes belong together.

```text
app/game/game.tscn
```
Top-level composition.

```text
gameplay/player/player.tscn
```
Generic runtime gameplay actor.

```text
presentation/items/weapons/swords/iron_sword/iron_sword_visual.tscn
```
Replaceable visual asset.

Avoid creating a generic top-level `scenes/` dump.

## Definition decision

Schema/class:

```text
*_definition.gd
*_profile.gd
```

belongs with the system that interprets that schema.

Authored instance:

```text
*.tres
```

belongs under the matching `content/` family.

Example:

```text
gameplay/items/equipment/weapon_definition.gd
content/items/weapons/swords/iron_sword.tres
```

## New content member checklist

For an ordinary established content member:

1. find the correct family under `content/`;
2. assign a stable semantic content ID;
3. create/duplicate the definition asset;
4. assign categories/capabilities/references;
5. add presentation assets under `presentation/` where needed;
6. do not add content-ID branches to central systems;
7. run content validation when available;
8. run family integration tests.

## New runtime system checklist

1. identify the owning runtime domain;
2. check whether the system is domain-neutral enough for `core/`;
3. define public contracts separately from implementation details;
4. do not depend on concrete authored content IDs unless the mechanic truly requires one canonical special object;
5. add tests under the matching test purpose/domain;
6. document new dependency direction if it changes architecture.

## New test checklist

Place by contract/purpose:

```text
pure isolated contract                 → tests/unit/
cross-system/runtime interaction        → tests/integration/
deterministic world truth              → tests/deterministic/
large seed/statistical campaign         → tests/campaigns/
immutable inputs/expected old saves     → tests/fixtures/
CLI/headless process entrypoint          → tests/runners/
```

Do not put production utilities in `tests/helpers` and then import them into runtime code.

## New tool checklist

Development-only/editor/import/migration utilities go under `tools/`.

Runtime systems may not depend on them.

If a useful algorithm is required by both tooling and runtime, move the reusable pure contract to its true runtime/core owner and let the tool consume that contract.

## Folder creation checklist

Create a new directory when it expresses a real boundary.

Good reasons:
- several files share one responsibility;
- a registered content family/category needs an authoring home;
- validation rules differ;
- navigation materially improves.

Bad reason:
- one file might theoretically have siblings someday.

## Naming checklist

Prefer lower `snake_case`.

Use role suffixes when they clarify ownership:

```text
_definition
_profile
_controller
_component
_service
_resolver
_registry
_store
_validator
_adapter
_factory
_descriptor
_request
_result
_manifest
```

Avoid vague names:

```text
helper.gd
utils.gd
data.gd
manager2.gd
thing.gd
final_v3.tres
```

## Moving an existing file

Moving files is architecture work because Godot paths may be referenced by scenes/resources/scripts.

Before moving:

1. search all references;
2. avoid collision with active feature branches;
3. move a coherent domain slice, not random individual files for appearance;
4. update references in the same change;
5. preserve semantic IDs;
6. run clean headless CI/import tests;
7. update docs if the ownership boundary changed.

## Generalization rule

Do not generalize a file merely because it *might* be reusable.

Example:

`stamina_component.gd` may remain player-owned until another real actor uses the same contract. At that point, move/generalize it deliberately.

Premature shared folders become dumping grounds just as easily as flat prototype folders.

## Fast decision table

| File you are adding | Default location |
| --- | --- |
| new sword values | `content/items/weapons/...` |
| sword mesh/visual scene | `presentation/items/weapons/...` |
| generic weapon schema | `gameplay/items/equipment/...` |
| attack resolution algorithm | `gameplay/combat/resolution/...` |
| Burrower-specific AI code | `gameplay/creatures/enemies/burrower/...` |
| Burrower authored stats/attack refs | `content/creatures/underworld/...` |
| cave topology algorithm | `worldgen/underworld/...` |
| loaded cave mesh streamer | `world/underworld/...` |
| content registry | `core/content/registry/...` |
| animation set definition asset | `content/presentation/animation_sets/...` |
| actual animation library/clip assets | `presentation/animations/...` |
| debug HUD | `presentation/ui/debug/...` |
| save migration tool | `tools/migration/...` |
| save migration fixture | `tests/fixtures/saves/...` |
| architecture document | `docs/10_architecture/...` |

When the table and actual responsibility disagree, responsibility wins.