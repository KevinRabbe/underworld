# Underworld Visual Direction

Status: **LOCKED visual family; production details remain adjustable**

This document records the current visual target for Underworld. It guides future art, presentation, UI, VFX and asset decisions without making presentation assets part of world, gameplay or persistence identity.

The project is deliberately using cheap prototype geometry while core systems are still being proven. Prototype appearance is not the final art target.

## Visual thesis

Underworld should read as a **stylized dark-fantasy 3D survival game** with:

- low-to-mid-poly environment geometry with strong readable silhouettes;
- believable but stylized PBR materials;
- substantially higher detail on the player, important creatures, weapons, armor and bosses;
- atmospheric lighting, fog and VFX carrying a large share of perceived quality;
- modular/reusable asset families rather than unique high-cost assets everywhere;
- a grounded surface world contrasted by stronger visual identities underground.

The target is not photorealism, Minecraft-style block geometry, retro PS1 rendering, or heavily cartoon-proportioned fantasy. Those may be useful experimental presentation modes later, but they are not the current production target.

## Core principles

### 1. Readability before raw detail

Large shapes and silhouettes should communicate first. Fine detail supports the shape instead of compensating for an unreadable base model.

Preferred hierarchy:

```text
large form
  -> medium silhouette/detail
      -> material/detail normal/decal
```

A rock, weapon, creature or building should remain recognizable at gameplay camera distance before small surface detail is considered.

### 2. Detail budget follows importance and camera distance

Not every asset family needs the same geometric or texture density.

Indicative relative targets:

| Asset family | Relative detail target |
| --- | --- |
| distant terrain / background forms | low |
| generic rocks, grass and clutter | low to mid |
| common vegetation / buildings | mid |
| common creatures | mid |
| important enemies | mid to high |
| player character | high |
| equipped weapons and armor | high |
| bosses / hero assets | high |

These are relative priorities, not final polygon or texture budgets.

### 3. Presentation is replaceable

Visual assets must remain downstream of authoritative world/gameplay state.

Changing a mesh, shader, material, texture, VFX package, LOD, color grade or rendering technique must not silently change:

- world seed identity;
- procedural StableIds;
- semantic authored content identity;
- durable player/world state;
- gameplay rules;
- logical building/item identity.

See the project content and persistence architecture for the owning identity rules:
- [`../10_architecture/CONTENT_ARCHITECTURE.md`](../10_architecture/CONTENT_ARCHITECTURE.md)
- [`../PERSISTENCE_AND_VERSIONING.md`](../PERSISTENCE_AND_VERSIONING.md)
- [`GLOSSARY.md`](GLOSSARY.md)

## Surface world

The surface should feel comparatively familiar, grounded and readable so entering the Underworld creates a meaningful contrast.

General direction:
- natural/desaturated greens rather than constant saturated fantasy color;
- gray/brown exposed stone and soil;
- dark coniferous/temperate forest families where appropriate;
- fog/haze used for depth and atmosphere;
- believable daylight/overcast lighting rather than permanently dramatic colored lighting;
- timber, rough stone, iron and weathered materials for grounded settlements/ruins;
- occasional stronger color from biome accents, flowers, ores, magic, corruption or seasonal/environmental variation.

The surface should not be uniformly bleak. Calm, beautiful and recognizable places make dangerous underground transitions more effective.

## Underworld regions

Underground areas should carry stronger visual identities than the surface. The generator provides space and world structure; presentation/content determines the visual vocabulary layered onto that space.

Potential visual families may include:
- dry stone/limestone caverns;
- wet caves and underground rivers;
- fungal or bioluminescent regions;
- crystal/mineral caverns;
- collapsed mines or excavated spaces;
- buried ruins and ancient architecture;
- root-infested caves under forests;
- volcanic/deep-hot regions;
- enormous dark abyssal chambers;
- special corrupted, magical or civilization-specific locations.

These examples are direction, not a locked biome list.

A cave region should not become visually distinct by changing deterministic topology identity. Visual/content selection remains a downstream concern unless an owning world/content contract explicitly says otherwise.

## Lighting and color language

Lighting is one of the primary quality multipliers for the chosen geometry style.

The project should use controlled contrast and color intentionally rather than filling every scene with unrelated saturated lights.

Useful recurring language may include:

| Source / meaning | Direction |
| --- | --- |
| neutral cave ambient | cool gray / blue-gray |
| fire / torch / settlement | warm orange / yellow |
| fungus / spores | cyan / green family |
| crystals / unusual minerals | blue / violet family |
| corruption / high danger | restrained red / magenta family |
| ancient sacred/artificial spaces | pale gold / warm white family |

Exact hues are not locked.

Color can support navigation and environmental storytelling. A distant warm light can imply construction or safety; a strange cold glow can imply unusual natural content; a dangerous color accent can communicate risk before UI text is required.

## Environment geometry

Environment assets should favor:
- large readable planes and facets;
- imperfect natural silhouettes;
- controlled geometric density;
- tiling/reusable material systems;
- normal maps, decals and masks for smaller detail;
- reusable variants rather than dozens of nearly identical unique meshes.

The target is **stylized low-to-mid-poly**, not visibly crude triangles everywhere.

Procedural cave and terrain geometry may remain relatively economical as long as presentation can layer materials, decals, props, vegetation, lighting and effects without rewriting world truth.

## Characters

Characters are allowed to be substantially more detailed than the environment.

The eventual player target is **higher-detail stylized realism**:
- believable human proportions;
- recognizable face/head forms;
- modeled hands/fingers where camera distance justifies them;
- layered clothing and armor;
- clear belts, straps, pouches and equipment silhouettes;
- better deformation around shoulders, elbows, hips and knees;
- distinct leather, textile, wood and metal material response;
- reusable modular equipment;
- higher-quality reusable locomotion/combat animation than the current procedural posing.

The target is still stylized enough to be feasible for a small production pipeline. Full photorealistic character requirements are not assumed.

The current box mannequin remains a valid rig/gameplay test representation until replacing it produces more value than continuing systems work.

### Voxel character pipeline evaluation

CHAR-PRESENT-001 evaluates a high-quality modular voxel player presentation while preserving the same semantic humanoid rig, equipment sockets, gameplay collision and animation-role contracts. The voxel survivor is a character-pipeline experiment, not an environment-wide renderer decision. Its internal module, palette and compiled-mesh boundaries are deliberately replaceable so an authored voxel source or a different compatible character presentation can later use the same gameplay contract.

The working character theme is **Frontier Underworld Expedition**. It is a reversible art-direction choice rather than permanent world lore. The baseline survivor uses practical layered canvas, leather, rugged trousers, boots, a compact field pack, pouches, restrained teal identification accents and chunky cave-working tools. The silhouette should communicate a capable explorer at normal gameplay distance without borrowing a specific historical culture, religion or mythology.

The approved first-pass turnaround and action reference is [Frontier Underworld Expedition character reference v1](reference/frontier_underworld_expedition_character_reference_v1.png). It guides proportions, palette, module layering and pose readability; it is preview/reference material and is not loaded by the runtime.

The isolated authoring scene at `res://tools/character_preview/voxel_character_preview.tscn` provides a neutral-lit character review environment. It can exercise directional locomotion, airborne poses, dodges, light/heavy attacks, block, parry, hit, death, tool use, equipment visibility and manual turntable rotation without changing the gameplay scene.

For repeatable visual review, the scene also accepts user arguments such as `--preview-capture=<absolute PNG path>`, `--preview-state=attack_heavy`, `--preview-pose-time=0.38`, and `--preview-angle=-33`. Capture mode freezes the requested clip at the normalized pose time after compiling the real runtime modules; it is evidence of the implemented presentation rather than a separate mockup.

## Creatures and bosses

Common creatures can use mid-detail assets with strong silhouettes and readable attack poses.

Bosses and important enemies may receive player-character-level or greater presentation attention because they are focal assets and are observed at close range.

Creature detail must not make combat cues harder to read. Animation timing, silhouette and pose clarity take priority over surface ornament.

## Weapons, armor and tools

Equipped assets sit close to the camera and deserve higher detail than generic environment props.

Direction:
- strong recognizable silhouettes;
- slightly exaggerated thickness/major shapes where needed for third-person readability;
- believable construction and material response;
- modular attachment/equipment compatibility;
- clear differences between wood, stone, leather, bronze/iron/steel-like metals and special materials;
- detail through normal maps, trims and material variation rather than extreme mesh density everywhere.

Weapons should not become cartoonishly oversized, but strict real-world proportions may be adjusted where gameplay readability benefits.

## Buildings and architecture

Architecture should use modular kits and readable chunky construction.

A structure family may use reusable parts such as:
- straight/broken walls;
- corners;
- arches/doorways/windows;
- floors and stairs;
- beams and supports;
- roof pieces;
- columns;
- debris/trim variants.

Modular composition is preferred over making every structure a unique one-off asset.

Player-built structures must also remain compatible with the logical building-piece architecture: presentation detail may improve substantially later without changing logical snap/placement identity.

## Materials and texturing

The default direction is **stylized PBR**, not totally flat unlit color and not high-cost photogrammetric realism.

Use physically sensible material response where it helps readability:
- appropriate roughness ranges;
- restrained metallic values;
- useful normal/detail maps;
- AO/detail where appropriate;
- stylized albedo and controlled palettes;
- wetness/moss/dirt/mineral masks;
- decals and trim sheets;
- reusable tiling material families.

Avoid making the game dependent on thousands of unique high-resolution texture sets.

A reusable rock material family, for example, may combine:

```text
base rock
+ hue/value variation
+ roughness variation
+ wetness
+ moss/dirt mask
+ mineral vein mask
+ decals
```

This should allow many procedural/reused forms to remain visually related without each requiring a unique texture package.

## Vegetation

Prototype cone trees and simple ground objects are distribution tests, not art targets.

Future vegetation should favor a manageable archetype library plus procedural variation:
- several tree forms per appropriate biome rather than hundreds of unique trees;
- scale/rotation/tint variation;
- canopy/trunk/dead variants;
- reusable bushes, grass, ferns, mushrooms, flowers, branches and rocks;
- LOD/impostor strategies when profiling shows they are needed.

Large-scale forest/clearing distribution should be proven before expensive vegetation content is produced.

## Animation

Animation should prioritize readable intent and weight over trying to imitate raw mocap everywhere.

Combat actions benefit from clear phases:

```text
anticipation -> action/contact -> recovery
```

Parry, dodge, heavy attack, hit reactions and creature telegraphs should communicate clearly at gameplay camera distance.

Gameplay timing remains owned by gameplay action contracts. Presentation animation should satisfy semantic/action roles rather than becoming the source of combat authority.

## VFX

VFX should be stylized but restrained.

Useful families include:
- weapon trails;
- impact sparks/dust/debris;
- torch smoke/fire;
- cave mist;
- water droplets/splash;
- spores;
- subtle magical/mineral effects;
- material-specific hit feedback.

Effects should primarily answer **what happened, where, and how important was it?** Avoid constant MMORPG-style rainbow noise that hides combat or environment readability.

## UI

The current direction is a minimal dark medieval/survival interface rather than a permanently crowded MMO HUD.

Possible language:
- dark/charcoal translucent panels;
- warm off-white readable text;
- restrained iron/bronze-like accents;
- clear icons;
- limited persistent HUD clutter;
- stronger structure in inventory/crafting/building screens where information density requires it.

Exact typography, icon set, layout and accessibility options are future UI work.

## Shaders and alternate visual treatments

Shaders can change the perceived art style dramatically without changing logical geometry.

Possible shader/post-process treatments include:
- flat or banded/cel lighting;
- color quantization/posterization;
- pixelation or low-resolution presentation;
- dithering;
- vertex/normal stylization;
- outlines;
- texture filtering changes;
- color grading;
- stylized shadow response.

However, shaders do not generally turn a smooth silhouette into genuinely block/voxel geometry.

A true blocky or alternate silhouette requires a different mesh/renderer representation. The project architecture should permit alternate presentations to consume the same authoritative world/gameplay data where technically compatible.

Therefore:

```text
same logical world
      |
      +--> stylized smooth/PBR presentation
      +--> cel/pixel shader treatment
      +--> future alternate geometry renderer
```

The current production target remains stylized dark-fantasy PBR; alternate renderers are optional future experiments, not current scope.

## Prototype-art policy

Cheap primitives are acceptable when their purpose is to validate:
- world distribution;
- gameplay scale;
- collision/streaming;
- animation/rig contracts;
- equipment sockets;
- building placement;
- procedural generation;
- performance architecture.

Do not replace a useful placeholder merely because it is ugly if the underlying system is still changing rapidly.

Conversely, once a system is stable enough for meaningful visual evaluation, presentation work should progressively replace placeholders behind the same logical contracts.

## Production-efficiency rules

Prefer:
- reusable modular kits;
- material families;
- trim sheets/decals/masks;
- asset variants;
- LODs/instancing/batching where measured useful;
- high detail where the camera/player attention justifies it.

Avoid:
- unique hero-level asset cost for generic clutter;
- presentation file paths becoming gameplay identity;
- final-art production before scale/distribution/contracts are stable;
- visual complexity that destroys gameplay readability;
- art changes that require rewriting deterministic world generation.

## Intentionally adjustable decisions

This document does **not** lock:
- exact color palette values;
- exact polygon/triangle budgets;
- exact texture resolutions;
- exact asset counts per biome;
- final shader stack;
- final renderer features;
- final LOD distances;
- final lighting performance budgets;
- final UI typography/layout;
- final character topology/face system;
- final animation production method;
- final vegetation technology.

Those require later profiling, art tests and production experience.

## Locked direction summary

Unless explicitly superseded by a later project/art decision:

1. Underworld targets stylized dark-fantasy 3D.
2. Environment geometry stays comparatively economical and readable.
3. Player, bosses, important creatures, weapons and armor may use substantially higher detail.
4. Stylized PBR materials, atmosphere, lighting and restrained VFX are major quality pillars.
5. Surface presentation remains more grounded; underground regions may use stronger controlled visual identities.
6. Modular/reusable assets are preferred over one-off production everywhere.
7. Prototype primitives remain valid until replacing them materially helps evaluation or production.
8. Visual assets and render techniques never become world/gameplay/persistence identity.
9. Shader treatments may change perceived style; true silhouette changes require alternate geometry/renderer representation.
10. Final technical budgets remain open until measured and profiled.
