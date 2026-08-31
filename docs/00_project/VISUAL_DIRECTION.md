# Underworld Visual Direction

Status: **LOCKED visual family and production philosophy; production details remain adjustable**

Underworld targets a stylized dark-fantasy 3D survival presentation that looks substantially richer than the raw geometry cost would suggest. The project deliberately prioritizes strong silhouettes, reusable geometry, materials, shaders, lighting, atmosphere and controlled VFX over brute-force geometric detail.

Prototype geometry remains valid while systems are changing. Final architecture/layout/interaction can be stable before final art is produced.

## 1. Visual thesis

Underworld should read as:
- low-to-mid-poly environment geometry with strong silhouettes;
- believable but stylized PBR materials;
- higher detail on player, important creatures, weapons, armor and bosses;
- atmosphere, fog, lighting and VFX carrying a large share of perceived quality;
- modular/reusable asset families rather than one-off assets everywhere;
- a grounded Overworld contrasted with stronger visual identities in the Underworld.

The target is not photorealism, voxel/block rendering, retro PS1 rendering or heavily cartoon-proportioned fantasy.

## 2. Perceptual complexity over invisible complexity

Spend art and runtime complexity on cues the player actually perceives.

A simple asset can read as much richer when it has the correct:
1. silhouette;
2. large structural proportions;
3. material response;
4. normal/AO detail;
5. lighting/shadow response;
6. motion where appropriate;
7. atmospheric integration;
8. controlled surface variation.

Do not model detail merely because it can be modeled.

Model geometry when it materially affects:
- silhouette;
- interaction;
- collision;
- close-range readability;
- animation/deformation.

Prefer shaders/materials/decals/masks/VFX for detail that does not need unique geometry.

## 3. Readability before raw detail

Preferred hierarchy:

```text
large form / silhouette
-> medium structural detail
-> material / normal / decal detail
```

A rock, tree, building, weapon or creature should remain recognizable at gameplay camera distance before fine surface detail is added.

Shaders cannot rescue a fundamentally bad silhouette.

## 4. Detail follows importance and distance

Indicative relative detail priority:

| Asset family | Relative detail |
| --- | --- |
| distant terrain/horizon | low |
| generic rocks/grass/clutter | low-mid |
| common vegetation/buildings | mid |
| common creatures | mid |
| important enemies | mid-high |
| player | high |
| equipped weapons/armor | high |
| bosses/hero assets | high |

These are priorities, not final polygon budgets.

## 5. Presentation is replaceable

Changing a mesh, shader, material, texture, VFX package, LOD, color grade or rendering technique must not silently change:
- world seed identity;
- procedural StableIds;
- semantic content identity;
- durable player/world state;
- gameplay rules;
- logical building/item identity.

Presentation consumes authoritative state; it does not define it.

## 6. Overworld direction

The Overworld should feel familiar, grounded and readable so the Underworld creates meaningful contrast.

Direction:
- natural/desaturated greens;
- gray/brown stone and soil;
- temperate/coniferous forest families where appropriate;
- daylight/overcast lighting that can be beautiful rather than permanently dramatic;
- haze/fog for depth;
- timber, rough stone and iron for grounded structures;
- stronger color reserved for biome accents, unusual resources, magic/corruption and special events.

The Overworld should not be uniformly bleak.

## 7. Underworld direction

The Underworld is a separate procedural world domain and may use more aggressive atmosphere, scale and regional identity.

Possible visual families include:
- dry limestone/stone caverns;
- wet caves and underground water;
- fungal/bioluminescent regions;
- crystal/mineral caverns;
- collapsed mines;
- buried ruins;
- root-infested regions;
- volcanic/deep-hot regions;
- enormous abyssal chambers;
- unusual corrupted/magical/artificial spaces.

These examples are not a locked biome list.

## 8. Lighting and color language

Lighting is a major quality multiplier.

Possible recurring language:

| Source / meaning | Direction |
| --- | --- |
| neutral cave ambient | cool gray / blue-gray |
| fire / settlement | warm orange / yellow |
| fungus / spores | cyan / green family |
| crystals / unusual minerals | blue / violet family |
| corruption / danger | restrained red / magenta |
| ancient sacred/artificial | pale gold / warm white |

Exact values remain adjustable.

Color should support navigation/readability rather than producing constant MMO-style visual noise.

## 9. Environment geometry

Favor:
- large readable planes/forms;
- imperfect natural silhouettes;
- controlled geometry density;
- tiling/reusable materials;
- normal maps, decals and masks for small detail;
- modular families and variants;
- LOD/instancing-friendly topology where practical.

Procedural terrain/cave geometry may stay economical if downstream presentation can create richness without rewriting world truth.

## 10. Vegetation strategy

Vegetation is a primary example of perceptual optimization.

The project does **not** need botanically modeled trees with enormous leaf counts.

A convincing tree may use:
- simple/moderate trunk and main-branch geometry;
- a small number of readable branch forms;
- coarse foliage-volume/cluster meshes;
- leaf/foliage shaders providing breakup;
- modified normals/light response;
- fake translucency/transmission where useful;
- wind deformation;
- per-instance scale/rotation/tint variation;
- multiple LOD tiers;
- far forest proxies/impostors.

The silhouette and canopy mass distribution matter more than individual modeled leaves.

A manageable tree archetype library should be multiplied by procedural/presentation variation instead of hundreds of unique tree meshes.

Large-scale forest/clearing distribution must be proven before expensive vegetation content production.

## 11. Tree LOD direction

Indicative representation tiers:

```text
close
- full trunk/branch/foliage clusters
- best wind/material/shadow response

medium
- reduced branch/foliage complexity
- cheaper wind/shadows

far
- highly simplified canopy/trunk representation

horizon
- impostor / billboard / forest-mass proxy
```

Exact distances depend on profiling.

The same logical vegetation instance may use different representations without changing world identity.

## 12. Modular architecture/building presentation

Building geometry should be designed as reusable modular kits aligned with the logical building system.

Families may share:
- walls/half walls;
- floors/half floors;
- beams/posts;
- braces;
- stairs;
- roof families;
- arches;
- rails;
- doors/windows;
- trims/debris.

The logical grid/socket contract defines compatibility. Art may extend beyond logical bounds where safe so structures do not look like sterile cubes.

A single gameplay-compatible wall geometry may support multiple later visual/material treatments without requiring new placement logic.

## 13. Shape variation before texture explosion

For early building/environment content, prioritize new silhouettes/shapes before dozens of material recolors.

Example:
- several useful beam lengths and roof joins create new architecture;
- six slightly different brown wall textures do not create equivalent gameplay possibility.

Visual/style families can multiply later behind stable geometry/content contracts.

## 14. Materials and texturing

Default direction: stylized PBR.

Use:
- sensible roughness;
- restrained metallic values;
- normal/detail maps;
- AO where useful;
- stylized albedo/palette;
- wetness/moss/dirt/mineral masks;
- trim sheets;
- decals;
- reusable tiling material families.

Avoid dependence on thousands of unique high-resolution texture sets.

A reusable rock material may combine:

```text
base rock
+ hue/value variation
+ roughness variation
+ wetness
+ moss/dirt
+ mineral mask
+ decals
```

## 15. Characters

Characters may use substantially more detail than generic environment assets.

Long-term direction:
- believable proportions;
- recognizable head/face forms;
- useful hand/finger detail when visible;
- layered clothing/armor;
- readable belts/straps/equipment silhouettes;
- good shoulder/elbow/hip/knee deformation;
- distinct leather/textile/wood/metal response;
- modular equipment;
- reusable locomotion/combat animation.

The target remains stylized enough for a small production pipeline.

## 16. Creatures and bosses

Common creatures can remain mid-detail if silhouette and attack poses are strong.

Bosses/important enemies may receive hero-level attention.

Animation timing, silhouette and telegraph readability take priority over ornament.

## 17. Weapons, armor and tools

Equipped assets deserve more detail because they are close to the camera.

Direction:
- strong silhouettes;
- believable construction;
- readable material response;
- modular attachment/equipment compatibility;
- normal/trim/material detail instead of extreme mesh density.

## 18. Animation

Animation should prioritize readable intent and weight.

Combat actions benefit from:

```text
anticipation -> action/contact -> recovery
```

Gameplay timing remains authoritative in gameplay contracts; presentation satisfies semantic action roles.

## 19. VFX

VFX should answer:
- what happened;
- where;
- how important it was.

Useful restrained families include impacts, trails, dust/debris, fire/smoke, cave mist, water effects, spores and unusual mineral/magic effects.

## 20. UI

UI direction remains minimal dark medieval/survival rather than a permanently crowded MMO HUD.

Use reusable theme/9-slice/skin architecture and shared layout primitives. Information-dense screens such as inventory, crafting and especially a future large building catalog may use stronger hierarchy/search/filter structures.

## 21. Alternate visual treatments

Shaders/post-process may substantially alter perceived style without changing logical geometry.

Possible future treatments include:
- cel/banded lighting;
- quantization/posterization;
- pixelation;
- dithering;
- stylized normals;
- outlines;
- alternate filtering/color grading.

True silhouette changes still require alternate geometry/renderer representation.

## 22. Prototype-art policy

Cheap primitives are acceptable when validating:
- world distribution;
- gameplay scale;
- collision/streaming;
- rig/animation contracts;
- equipment sockets;
- building placement;
- procedural generation;
- performance architecture.

Do not replace a useful placeholder merely because it looks unfinished while its underlying system is unstable.

Once a system is stable enough for meaningful visual evaluation, improve presentation behind the same logical contracts.

## 23. Production-efficiency rules

Prefer:
- reusable modular kits;
- shared geometry families;
- material families;
- trim sheets/decals/masks;
- procedural/per-instance variation;
- shaders that create perceived richness;
- LOD/instancing/batching;
- hero detail only where attention/camera distance justifies it.

Avoid:
- unique hero-level asset cost for generic clutter;
- gameplay identity tied to presentation paths;
- final-art production before scale/contracts are stable;
- geometry detail that provides little visible benefit;
- art decisions that force deterministic world-generation rewrites.

## 24. Intentionally adjustable decisions

Not locked:
- exact palettes;
- polygon budgets;
- texture resolutions;
- asset counts per biome;
- final shader stack;
- renderer feature selection;
- LOD distances;
- lighting budgets;
- final vegetation technology;
- final character topology;
- animation production method.

These require tests and profiling.

## Locked direction summary

1. Stylized dark-fantasy 3D remains the target.
2. Environment geometry remains comparatively economical with strong silhouettes.
3. Perceived richness should come heavily from materials, shaders, lighting, atmosphere and VFX.
4. Trees/vegetation use reusable archetypes, foliage clusters, shader variation and LOD rather than brute-force leaf geometry.
5. Player/hero assets may use substantially more detail than generic environment assets.
6. Modular geometry/content is preferred over one-off asset production.
7. Shape vocabulary is generally more valuable early than cosmetic duplication.
8. Prototype geometry remains valid until replacing it materially improves evaluation.
9. Presentation never becomes authoritative gameplay/world/persistence identity.
10. Final technical budgets remain profile-driven.
