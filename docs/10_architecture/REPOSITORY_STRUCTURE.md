# Underworld Repository and File Architecture

Status: **LOCKED architectural direction; staged migration**

This document defines the long-term `res://` repository layout for Underworld. The purpose is to let the project grow from a prototype into a large content-driven game without turning the filesystem into a second undocumented architecture.

The folder tree expresses ownership. It is not merely cosmetic organization.

## Core rule

> Put a file where its owning system or authored-content family lives, not where one current caller happens to use it.

A file path is never semantic game identity. Semantic content IDs, procedural StableIds, schema IDs and runtime instance identity remain separate from filesystem layout.

## Two major axes

The repository deliberately separates **systems** from **authored content/presentation**.

### System/runtime roots

```text
core/
gameplay/
world/
worldgen/
app/
```

These contain runtime code, pure-data schema code, services, controllers, generators and reusable runtime scenes owned by systems.

### Authored-data/presentation roots

```text
content/
presentation/
```

`content/` contains semantic game definitions and authored composition data.

`presentation/` contains replaceable visual/audio/animation/UI assets and presentation adapters.

### Support roots

```text
tools/
tests/
docs/
third_party/
addons/
.github/
```

These support development and validation rather than owning game runtime behavior.

---

# 1. Target top-level tree

The intended scalable repository shape is:

```text
res://
├─ app/
├─ core/
├─ gameplay/
├─ world/
├─ worldgen/
├─ content/
├─ presentation/
├─ tools/
├─ tests/
├─ docs/
├─ third_party/
├─ addons/
├─ .github/
├─ project.godot
├─ README.md
└─ .gitignore
```

Not every child folder must exist immediately. Git does not track empty directories, and we do not create meaningless placeholder trees merely to resemble this diagram.

A directory should appear when its first real file is introduced or when a small boundary README is deliberately useful.

---

# 2. `app/` — composition and bootstrap

`app/` is the thin outer shell that composes major systems into the running game.

```text
app/
├─ bootstrap/
│  ├─ bootstrap.gd
│  └─ bootstrap.tscn
├─ game/
│  ├─ game.gd
│  └─ game.tscn
├─ flow/
│  ├─ game_flow_controller.gd
│  └─ world_session_controller.gd
└─ debug/
   └─ debug_bootstrap.gd
```

Responsibilities:
- application/bootstrap composition;
- starting/loading a world session;
- connecting high-level services;
- top-level game-state flow;
- main scene ownership.

Forbidden:
- item-specific behavior;
- creature-specific AI;
- world-generation algorithms;
- content-definition special cases;
- large gameplay managers that belong in a domain.

The current `game/` prototype root is expected to migrate here later.

---

# 3. `core/` — domain-neutral infrastructure

`core/` contains project infrastructure that should not know concrete gameplay members.

```text
core/
├─ content/
│  ├─ identity/
│  ├─ registry/
│  ├─ references/
│  └─ validation/
├─ events/
├─ persistence/
├─ services/
├─ config/
├─ math/
├─ utilities/
└─ diagnostics/
```

Typical future files:

```text
core/content/identity/content_id.gd
core/content/registry/content_registry.gd
core/content/references/content_reference.gd
core/content/validation/content_validation_result.gd
core/persistence/save_schema.gd
core/diagnostics/diagnostic.gd
```

Dependency rule:

```text
core
  ↑
may be used by gameplay/world/worldgen/presentation/app
```

`core/` must not depend on concrete weapons, enemies, biomes or presentation assets.

If a utility is only useful to one domain, keep it in that domain rather than dumping it into `core/utilities`.

---

# 4. `gameplay/` — runtime gameplay rules

`gameplay/` owns player/actor behavior and ordinary gameplay systems.

```text
gameplay/
├─ player/
│  ├─ controllers/
│  ├─ actions/
│  ├─ input/
│  ├─ components/
│  ├─ interaction/
│  └─ adapters/
├─ combat/
│  ├─ attacks/
│  ├─ defense/
│  ├─ damage/
│  ├─ stagger/
│  ├─ targeting/
│  └─ resolution/
├─ creatures/
│  ├─ common/
│  ├─ enemies/
│  ├─ elites/
│  └─ bosses/
├─ items/
│  ├─ inventory/
│  ├─ equipment/
│  ├─ durability/
│  └─ item_runtime/
├─ harvesting/
├─ crafting/
├─ building/
├─ survival/
├─ progression/
├─ interaction/
└─ status_effects/
```

## Player example

```text
gameplay/player/
├─ player.gd
├─ controllers/
│  └─ player_motor.gd
├─ actions/
│  └─ player_action_controller.gd
├─ input/
│  └─ player_input_buffer.gd
├─ components/
│  ├─ stamina_component.gd
│  └─ health_component.gd
└─ adapters/
   └─ player_animation_adapter.gd
```

## Combat example

```text
gameplay/combat/
├─ attacks/
│  ├─ attack_definition.gd
│  ├─ attack_execution.gd
│  ├─ attack_set_definition.gd
│  └─ attack_phase.gd
├─ defense/
│  ├─ defense_result.gd
│  └─ defense_resolver.gd
├─ stagger/
│  └─ stagger_profile.gd
└─ resolution/
   └─ combat_resolver.gd
```

## Creature example

Generic reusable actor behavior lives in `common/`.

Only genuinely species-specific runtime behavior receives a species folder:

```text
gameplay/creatures/enemies/
└─ burrower/
   ├─ burrower_controller.gd
   └─ burrower_behavior.gd
```

Do not create one custom runtime class merely because a new creature definition exists.

---

# 5. `world/` — live world runtime

`world/` owns the loaded/runtime representation of the world. It is distinct from deterministic world truth generation in `worldgen/`.

```text
world/
├─ runtime/
│  ├─ streaming/
│  ├─ cells/
│  └─ observers/
├─ surface/
│  ├─ terrain/
│  ├─ decoration/
│  └─ interactables/
├─ underworld/
│  ├─ runtime_geometry/
│  ├─ streaming/
│  └─ interactables/
├─ spawning/
├─ navigation/
├─ environment/
└─ config/
```

Expected migration direction for the current prototype:

```text
world/chunk_manager.gd
  → world/runtime/streaming/surface_chunk_streamer.gd   (after responsibility split)

world/terrain_chunk.gd
  → world/surface/terrain/terrain_chunk.gd

world/terrain_generator.gd
  → reviewed before move:
     deterministic generation logic belongs in worldgen/surface/
     runtime mesh/build logic belongs in world/surface/terrain/

world/pickup_generator.gd
  → reviewed before move:
     deterministic placement belongs in worldgen/surface/
     runtime spawning belongs in world/spawning/
```

A move may therefore include a responsibility split rather than only a pathname change.

---

# 6. `worldgen/` — deterministic generated world truth

`worldgen/` remains a first-class top-level domain because it has unusually strict determinism, persistence and validation contracts.

The current structure is already close to the desired pattern.

```text
worldgen/
├─ identity/
├─ random/
├─ versioning/
├─ pipeline/
├─ graph/
├─ profiles/
├─ surface/
├─ underworld/
├─ geometry/
├─ services/
├─ persistence/
├─ migration/
└─ validation/
```

Existing good boundaries such as:

```text
worldgen/identity/
worldgen/random/
worldgen/graph/
worldgen/pipeline/
worldgen/profiles/
worldgen/underworld/
worldgen/validation/
```

should be preserved rather than flattened into generic `scripts/` or `data/` directories.

Important rule:

> `worldgen/` creates/validates pure deterministic definitions. `world/` owns live runtime representation.

No runtime Node, loaded terrain chunk, AI actor or presentation asset becomes an input to deterministic world truth.

---

# 7. `content/` — authored semantic definitions

`content/` is the scalable authored-data tree resolved by the future `ContentRegistry`.

It should contain semantic definitions (`.tres` and other deliberate authored data), not gameplay manager code.

```text
content/
├─ items/
│  ├─ resources/
│  ├─ weapons/
│  │  ├─ swords/
│  │  ├─ axes/
│  │  ├─ spears/
│  │  └─ ranged/
│  ├─ tools/
│  ├─ armor/
│  ├─ consumables/
│  └─ deployables/
├─ attacks/
│  ├─ player/
│  └─ creatures/
├─ attack_sets/
├─ creatures/
│  ├─ surface/
│  └─ underworld/
├─ structures/
│  ├─ generated/
│  └─ building/
├─ recipes/
├─ loot_tables/
├─ status_effects/
├─ ai_profiles/
├─ spawn_profiles/
├─ biomes/
├─ worldgen_profiles/
└─ presentation/
   ├─ animation_sets/
   ├─ rig_profiles/
   ├─ audio_sets/
   ├─ vfx_sets/
   └─ visual_profiles/
```

Examples:

```text
content/items/weapons/swords/iron_sword.tres
content/attacks/player/sword_light_01.tres
content/attack_sets/sword_one_handed_basic.tres
content/creatures/underworld/burrower.tres
content/presentation/animation_sets/humanoid_prototype.tres
content/presentation/rig_profiles/humanoid_prototype.tres
```

The semantic IDs remain authoritative:

```text
item.weapon.iron_sword
attack.sword.light_01
creature.underworld.burrower
animation_set.humanoid.prototype
```

The file paths above may later change without changing those IDs.

## Complex content packages

Do not automatically make one folder per item. A simple definition may remain one file.

When one authored member gains several tightly related authored files, use a member package:

```text
content/structures/generated/ancient_shrine/
├─ ancient_shrine.tres
├─ ancient_shrine_spawn_profile.tres
└─ README.md                         # only if non-obvious authoring rules exist
```

Do not use member packages to hide arbitrary unrelated assets.

---

# 8. `presentation/` — replaceable art/audio/animation/UI

`presentation/` owns concrete presentation assets and adapters. Gameplay should depend on semantic roles/contracts rather than paths inside this tree.

```text
presentation/
├─ characters/
│  ├─ player/
│  └─ creatures/
├─ items/
│  ├─ weapons/
│  ├─ tools/
│  └─ armor/
├─ world/
│  ├─ vegetation/
│  ├─ rocks/
│  ├─ structures/
│  └─ environment/
├─ animations/
│  ├─ libraries/
│  ├─ retargeting/
│  └─ debug/
├─ rigs/
├─ materials/
├─ textures/
├─ meshes/
├─ shaders/
├─ audio/
│  ├─ music/
│  ├─ ambience/
│  ├─ creatures/
│  ├─ combat/
│  └─ ui/
├─ vfx/
└─ ui/
   ├─ hud/
   ├─ menus/
   ├─ debug/
   └─ icons/
```

Example character package:

```text
presentation/characters/player/prototype_mannequin/
├─ prototype_mannequin.tscn
├─ prototype_mannequin.gd            # presentation-only adapter/rig construction
└─ materials/
```

Example weapon visual:

```text
presentation/items/weapons/swords/iron_sword/
├─ iron_sword_visual.tscn
├─ iron_sword_mesh.res
└─ materials/
```

A content definition may reference the semantic visual role/asset through its validated definition. Gameplay code should not know this concrete folder path.

## Source art

Large raw art-source files that Godot should not import may later live under a dedicated ignored source-art tree or outside the Godot project. If kept under `res://`, use a deliberate `.gdignore` policy.

Do not mix raw DCC working files with runtime-ready imported assets without a documented import workflow.

---

# 9. PackedScene / prefab placement

Godot `PackedScene` files (`.tscn`) are not all one category.

Place them by ownership:

### Runtime system scene

A generic gameplay/world scene belongs with its owning runtime domain.

```text
gameplay/player/player.tscn
world/surface/terrain/terrain_chunk.tscn
```

### Pure or near-pure visual scene

A replaceable visual scene belongs under `presentation/`.

```text
presentation/items/weapons/swords/iron_sword/iron_sword_visual.tscn
```

### Bootstrap/composition scene

A top-level composition scene belongs under `app/`.

```text
app/game/game.tscn
```

### Content-specific gameplay composition

Prefer generic runtime actors + semantic definitions + visual scenes.

Do not create one code-heavy scene per sword/ore/tree when data composition can express the variation.

A content-specific PackedScene is justified when the authored object genuinely has unique scene composition that cannot be represented by an existing generic runtime contract.

---

# 10. `tools/` — project tooling

```text
tools/
├─ editor/
├─ content/
├─ worldgen/
├─ import/
├─ migration/
├─ profiling/
└─ ci/
```

Examples:

```text
tools/content/build_content_manifest.gd
tools/content/validate_content.gd
tools/worldgen/reproduce_case.gd
tools/migration/migrate_save.gd
```

Tools may call runtime/pure-data APIs, but runtime game code must not depend on editor/tooling code.

---

# 11. `tests/` — mirror contracts, not production paths blindly

Tests are grouped first by test purpose/domain, with shared fixtures/runners separated.

Target direction:

```text
tests/
├─ unit/
│  ├─ core/
│  ├─ gameplay/
│  ├─ worldgen/
│  └─ content/
├─ integration/
│  ├─ character/
│  ├─ combat/
│  ├─ world/
│  └─ content/
├─ deterministic/
│  ├─ foundation/
│  ├─ topology/
│  ├─ entrances/
│  └─ connectivity/
├─ campaigns/
│  └─ worldgen/
├─ fixtures/
│  ├─ saves/
│  ├─ content/
│  └─ worldgen/
├─ helpers/
└─ runners/
```

Current test folders remain valid during staged migration.

Rules:
- fixtures are immutable test inputs unless deliberately versioned;
- runners own process/CLI orchestration, not domain assertions;
- regression cases promoted from campaigns receive explicit stable fixtures;
- tests should name the contract they protect, not implementation line numbers.

---

# 12. `third_party/` and `addons/`

## `addons/`

Reserved for Godot editor/runtime plugins that follow Godot's addon convention.

## `third_party/`

Reserved for vendored external code/assets that are not ordinary Godot addons.

```text
third_party/
├─ <library_or_asset_pack>/
│  ├─ ...
│  └─ LICENSE
└─ LICENSES.md
```

Rules:
- preserve license/attribution;
- do not edit third-party code casually as if project-owned;
- wrap external APIs behind project-owned adapters when coupling would otherwise spread;
- do not put original Underworld game systems into `third_party/`.

---

# 13. File naming contract

Godot/resource files use lowercase `snake_case` unless an external/imported asset has a justified immutable name.

Examples:

```text
player_action_controller.gd
content_registry.gd
attack_definition.gd
world_generation_context.gd
iron_sword.tres
iron_sword_visual.tscn
humanoid_prototype.tres
```

Preferred semantic suffixes:

```text
*_definition.gd     pure authored-definition schema
*_profile.gd        reusable configuration/profile schema
*_controller.gd     state/input orchestration with clear owner
*_component.gd      reusable actor/object component
*_service.gd        long-lived service boundary
*_resolver.gd       deterministic/explicit resolution logic
*_registry.gd       identity → definition/schema registry
*_store.gd          owned durable/cache storage boundary
*_validator.gd      structural/invariant validation
*_adapter.gd        translation between two contracts
*_factory.gd        controlled runtime construction
*_descriptor.gd     pure description handed between stages/layers
*_request.gd        explicit request data
*_result.gd         explicit result data
*_manifest.gd       versioned/canonical manifest
```

Do not add suffixes merely for style. Use the term that states the object's real ownership/role.

Avoid names such as:

```text
manager2.gd
helper.gd
utils2.gd
data.gd
stuff.gd
new_enemy.gd
final_sword.tres
iron_sword_v3_final.tres
```

Generic `manager`, `helper`, `data` and `utils` names require especially strong justification because they often hide mixed responsibility.

---

# 14. Definition file naming

The **semantic ID is authoritative**, but filenames should mirror the tail of the ID for authoring clarity where practical.

Examples:

```text
item.weapon.iron_sword
→ content/items/weapons/swords/iron_sword.tres

creature.underworld.burrower
→ content/creatures/underworld/burrower.tres

animation_set.humanoid.prototype
→ content/presentation/animation_sets/humanoid_prototype.tres
```

If the file moves later, the content ID does not change.

Do not encode documentation numbers, balancing tier numbers or temporary patch versions into semantic filenames unless they are genuinely part of the content concept.

---

# 15. Local README policy

Do not create README files in every directory.

A local `README.md` is useful only when a folder has:
- non-obvious ownership rules;
- an external import pipeline;
- a complex authored package convention;
- third-party licensing requirements;
- a boundary that developers routinely misunderstand.

Architecture belongs primarily in `docs/`, not scattered duplicate README copies.

---

# 16. Dependency direction by root

Preferred high-level direction:

```text
                         app
                    ↙     ↓      ↘
             gameplay   world   presentation
                 ↑        ↑         ↑
                 └── core ┴─────────┘
                      ↑
                   worldgen
```

This diagram is conceptual, not permission for arbitrary cross-links.

More exact rules:

- `core/` depends on no concrete game domain.
- `worldgen/` may depend on `core/` pure primitives but not runtime world/player/presentation.
- `gameplay/` may depend on `core/` and domain-owned definition schemas.
- `world/` may depend on `core/`, worldgen outputs and narrow gameplay interfaces where runtime world interaction requires them.
- `presentation/` may observe semantic gameplay/world state through adapters; gameplay must not depend on concrete mesh/bone/animation paths.
- `app/` composes domains and may know their public service boundaries.
- `content/` authored files instantiate/reference approved schemas/assets but contain no central runtime behavior.
- `tools/` may depend on project APIs; runtime domains must not depend on tools.
- `tests/` may depend on everything required to test; production code never depends on tests.

Cross-domain references should use public contracts rather than reaching through another domain's internal folder structure.

---

# 17. Public vs internal files

A folder path does not by itself make every script a public API.

Each mature domain should expose a small set of public contracts and keep implementation details internal by convention.

Example:

```text
gameplay/combat/
├─ attacks/attack_definition.gd      # public data contract
├─ resolution/combat_resolver.gd     # public service boundary
└─ resolution/internal/...           # internal implementation if complexity warrants it
```

Do not create `internal/` folders preemptively everywhere. Add them only when a domain becomes large enough that the distinction has real value.

---

# 18. Current → target migration map

No mass move occurs in this architecture PR.

Directional migration:

```text
game/game.gd
  → app/game/game.gd

game/game.tscn
  → app/game/game.tscn

game/debug_hud.gd
  → presentation/ui/debug/debug_hud.gd

player/player.gd
  → gameplay/player/player.gd

player/player_action_controller.gd
  → gameplay/player/actions/player_action_controller.gd

player/player_input_buffer.gd
  → gameplay/player/input/player_input_buffer.gd

player/stamina_component.gd
  → gameplay/player/components/stamina_component.gd
  or a shared actor component only when a second real consumer justifies generalization

player/prototype_mannequin.gd
  → presentation/characters/player/prototype_mannequin/

combat/player_attack_definition.gd
  → gameplay/combat/attacks/attack_definition.gd

combat/player_attack_catalog.gd
  → temporary prototype catalog; retire after semantic authored attack definitions/registry exist

combat/combat_manager.gd
  → gameplay/combat/resolution/ after responsibility/name review

combat/enemy.gd
  → gameplay/creatures/... after enemy architecture establishes generic vs Burrower-specific responsibility

data/world_settings.gd
  → world/config/world_settings.gd or another explicit owner after settings responsibility review

world/*.gd
  → split/move by runtime versus deterministic-generation ownership

worldgen/*
  → mostly preserve existing subdomain structure

tests/*
  → staged migration toward unit/integration/deterministic/fixtures/runners as test volume grows
```

Migration is done **domain by domain**, usually when that domain is already being changed for architectural reasons.

Do not create a giant rename PR that changes hundreds of resource paths without functional benefit.

---

# 19. Path migration rules

Godot scene/resource paths are real technical dependencies even though they are not semantic game identity.

When moving an existing file:

1. identify all script/resource/scene references;
2. update references in the same change;
3. run relevant headless tests on a clean Godot import;
4. preserve semantic content IDs and procedural IDs;
5. do not combine unrelated behavior rewrites with a huge path move unless required;
6. update documentation/authoring references;
7. verify import/scene loading on CI.

If a path move would collide with an active feature branch, defer it.

---

# 20. Folder-growth rules

A folder should represent a real ownership/category boundary.

Create a new subfolder when at least one is true:
- the domain has several files with one clear shared responsibility;
- the folder maps to an established content category/family;
- different validation/authoring rules apply;
- the distinction substantially improves navigation.

Do not create five directory levels for one file without a strong architecture reason.

Do not keep fifty unrelated files flat merely to avoid folders.

The filesystem should grow with the architecture, not ahead of it and not years behind it.

---

# 21. Content scaling test

For an established family, the ordinary authoring path should look like:

```text
new semantic definition under content/
        +
replaceable assets under presentation/
        +
existing runtime contracts under gameplay/world
        ↓
content validation
        ↓
usable new member
```

If adding the tenth sword requires editing `app/`, `CombatManager`, player input, inventory, animation filenames and multiple unrelated runtime folders, stop and review the architecture.

---

# 22. Repository anti-patterns

Forbidden or strongly discouraged patterns:

- one global `scripts/` folder;
- one global `scenes/` folder with no ownership meaning;
- one global `data/` folder containing unrelated schemas and content;
- file paths used as stable content identity;
- gameplay code under `content/`;
- concrete art/bone/clip paths hard-coded through gameplay code;
- content-specific branches in bootstrap/core managers;
- circular root dependencies;
- test helpers imported by production code;
- editor/tool scripts imported by runtime systems;
- mass folder moves while active branches depend on old paths;
- duplicate copies of the same definition in code and `.tres` assets.

---

# 23. Definition of done for repository architecture

This architecture is functioning as intended when:

- every new subsystem has one obvious owning root/domain;
- every new authored content member has one obvious content-family location;
- replaceable presentation assets have one obvious presentation location;
- deterministic world truth and runtime world representation remain separated;
- tests mirror contract ownership clearly;
- tool/editor code cannot leak into runtime dependencies;
- a new developer can decide where a file belongs without guessing from historical accident;
- path moves do not redefine semantic game identity;
- ordinary content growth adds files/data rather than central special cases.
