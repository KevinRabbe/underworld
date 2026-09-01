# Underworld Visual Direction

Status: **LOCKED production philosophy and current vertical-slice direction; future biome identities intentionally open**

Underworld targets a stylized dark-fantasy 3D survival presentation that looks substantially richer than the raw geometry cost would suggest. The project deliberately prioritizes strong silhouettes, reusable geometry, materials, shaders, lighting, atmosphere and controlled VFX over brute-force geometric detail.

Prototype geometry remains valid while systems are changing. Final architecture/layout/interaction can be stable before final art is produced.

This document deliberately distinguishes **project-wide production rules** from **current-biome art direction**. Current biome rules are not a promise that future biomes must look, sound, behave or play the same way.

## 1. Visual thesis

Underworld should read as:
- low-to-mid-poly environment geometry with strong silhouettes;
- believable but stylized PBR materials;
- higher detail on player, important creatures, weapons, armor and bosses;
- atmosphere, fog, lighting and VFX carrying a large share of perceived quality;
- modular/reusable asset families rather than one-off assets everywhere;
- a grounded Overworld contrasted with stronger and potentially radically different identities in the Underworld.

The target is not photorealism, voxel/block rendering, retro PS1 rendering or heavily cartoon-proportioned fantasy.

## 2. Hard production constraint — solo developer + AI assistance

The project is built by one developer with substantial AI assistance. Art/world direction must therefore be selected partly by **value per development time**.

Code-scalable content is high value:
- procedural terrain;
- procedural caves;
- vegetation distribution;
- resource distribution;
- weather;
- reusable encounter/spawn systems;
- reusable materials/shaders;
- modular asset families;
- deterministic variation.

Authored constructed-world content is expensive:
- giant bespoke settlements;
- colossal monuments as a recurring theme requirement;
- thousands of manually placed building pieces;
- enormous one-off ruins;
- huge unique prop catalogs;
- environment spectacle that requires months of handcrafted work but adds little gameplay value.

Therefore, the world theme must **not depend on large quantities of complex authored architecture** to work visually.

Wild-spawned constructed content should usually remain relatively simple, sparse, modular and reusable: small houses, camps, workshops, compact ruins, entrances, portal sites, towers or similarly bounded structures when they add clear value.

This constraint applies to developer-authored world content, **not to player creativity**. The existing building system may support far more complex player-created settlements and megabuilds.

## 3. Reference-image policy

Valheim and similar reference images may be used to specify:
- building freedom;
- settlement complexity achievable by players;
- atmosphere/lighting quality;
- material readability;
- vegetation density;
- the visual quality ceiling obtainable from economical geometry.

They do **not** define the game's Nordic theme, architecture, culture or asset style.

The target is the **possibility of creating complex structures**, not copying the structures shown in the references.

## 4. Perceptual complexity over invisible complexity

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

## 5. Readability before raw detail

Preferred hierarchy:

```text
large form / silhouette
-> medium structural detail
-> material / normal / decal detail
```

A rock, tree, building, weapon or creature should remain recognizable at gameplay camera distance before fine surface detail is added.

Shaders cannot rescue a fundamentally bad silhouette.

## 6. Detail follows importance and distance

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

## 7. Presentation is replaceable

Changing a mesh, shader, material, texture, VFX package, LOD, color grade or rendering technique must not silently change:
- world seed identity;
- procedural StableIds;
- semantic content identity;
- durable player/world state;
- gameplay rules;
- logical building/item identity.

Presentation consumes authoritative state; it does not define it.

## 8. Current vertical-slice world scope — HARD GATE

Until the core game is genuinely playable, art/world design is scoped to exactly:
- **one Overworld biome**;
- **one biome in the first accessible Underworld layer**;
- the transition between them.

Do not spend design or implementation time defining additional Overworld biomes, deeper Underworld biomes/layers or their content before this two-biome foundation is playable and validated.

The long-term game may contain many additional biomes in both domains, with the Underworld intended to be the larger long-term world space. Their identities remain intentionally undefined.

## 9. Current Overworld direction — grounded Bronze-Age fantasy

The current Overworld baseline is a **grounded Bronze-Age-fantasy** visual language rather than Nordic/medieval fantasy.

Core material cues:
- wood;
- rough stone;
- bronze and other practical metal use;
- cloth;
- leather/hide where useful;
- handmade, imperfect construction and tools.

This is a fantasy baseline, not a requirement for strict historical Bronze-Age reconstruction.

The Overworld should feel understandable, practical and grounded. Player habitation is especially important because the player may establish a home/base almost anywhere normal building rules permit. The authored world does not need large cities to provide its sense of habitation.

Avoid making ceramics a defining material cue; rough stone is preferred for the current surface identity.

## 10. Current first Underworld biome — "This biome hates you"

The first accessible Underworld biome is currently conceived as a **Hell Entrance / outer hostile layer**.

Its core identity is not simply visual hell imagery. Its design sentence is:

> **This biome hates you.**

The player has crossed into a place whose inhabitants actively reject their presence.

Combat/environmental implications:
- many enemies are immediately aggressive;
- threats seek out or pressure the player rather than behaving mainly as passive wildlife;
- danger comes heavily from speed, numbers, positioning and sustained pressure;
- common enemies should generally be relatively low-HP rather than health sponges;
- clean successful attacks should kill ordinary enemies reasonably quickly;
- packs and simultaneous threats create difficulty;
- hell-hound/hell-dog-like creatures and other low-level demon/Underworld/Hades-inspired creatures are suitable archetypes;
- stronger creatures in this layer should preferably be dangerous because of attacks, mobility or behavior rather than inflated HP.

This layer may be visually infernal if that serves the final art pass, but the behavioral identity above is more important than simply making everything red.

## 11. Underworld is not synonymous with Hell — HARD WORLD RULE

The first Underworld biome being a Hell Entrance does **not** define the entire Underworld.

"Underworld" describes the larger world domain, not one mandatory aesthetic.

Future Underworld biomes may be peaceful, eerie, beautiful, wet, dry, fungal, mineral, ancient, cold, artificial, lush, empty, violent, bright, dark or something not yet conceived.

Do not extrapolate the first biome's hell imagery, aggression, enemy density, palette or ecology into a universal Underworld rule.

## 12. Future-biome freedom — HARD RULE

Future biomes are explicitly allowed to **break every biome-specific rule established for the current two-biome vertical slice**.

A future biome does not need to preserve the current:
- palette;
- lighting model;
- climate;
- vegetation density;
- enemy temperament;
- enemy HP philosophy;
- environmental mood;
- material emphasis;
- traversal rhythm;
- settlement frequency;
- visual symbolism;
- Hell-Entrance identity;
- current Overworld-biome identity.

Biome diversity should be allowed to become extreme when future development reaches those biomes.

What future biomes may **not** casually break are project-wide technical/production contracts such as deterministic world identity, persistence semantics, core readability, performance/scalability requirements and the production-efficiency rule above.

In short: **current biome rules are local, not universal.**

## 13. Ancient Technology — long-term signature layer, NOT current implementation scope

The current leading long-term world contrast is:

- **Overworld:** grounded Bronze-Age fantasy craftsmanship;
- **Underworld progression:** eventual discovery/unlocking of a visually separate lost Ancient Technology layer.

Ancient Technology should feel clearly distinct from normal surface craftsmanship: more precise, strange and difficult to reproduce, while avoiding generic neon/holographic science-fiction presentation.

A signature late-game concept is the **Ancient Stabilization Technology** network:
- a deep exotic material is unusable outside active stabilization;
- a central ancient core/generator creates the stabilizing state;
- portals transmit that state across distance;
- local anchors/field projectors extend stabilization where needed;
- mining, storage, processing, transport and construction with that material must remain inside the active network;
- the material enables exceptional structural possibilities without replacing ordinary wood/stone/metal.

This is **late-game direction only**. Do not implement or prototype the stabilization network, its deep material, or broader Ancient Technology progression in the current playable milestone.

Exact device names, power values, visuals, variants, lore and late-game biome context remain open.

## 14. Environment geometry

Favor:
- large readable planes/forms;
- imperfect natural silhouettes;
- controlled geometry density;
- tiling/reusable materials;
- normal maps, decals and masks for small detail;
- modular families and variants;
- LOD/instancing-friendly topology where practical.

Procedural terrain/cave geometry may stay economical if downstream presentation can create richness without rewriting world truth.

## 15. Vegetation strategy

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

## 16. Tree LOD direction

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

## 17. Modular architecture/building presentation

Building geometry should be designed as reusable modular kits aligned with the already-decided logical building system.

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

Do not use the current art-direction discussion to redesign the building-piece grammar; that system is already owned elsewhere.

## 18. Shape variation before texture explosion

For early building/environment content, prioritize useful silhouettes/shapes before dozens of material recolors.

Visual/style families can multiply later behind stable geometry/content contracts.

## 19. Materials and texturing

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

## 20. Characters

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

## 21. Creatures and bosses

Common creatures can remain mid-detail if silhouette and attack poses are strong.

Bosses/important enemies may receive hero-level attention.

Animation timing, silhouette and telegraph readability take priority over ornament.

For the first Underworld biome specifically, avoid using HP inflation as the default way to communicate danger.

## 22. Weapons, armor and tools

Equipped assets deserve more detail because they are close to the camera.

Direction:
- strong silhouettes;
- believable construction;
- readable material response;
- modular attachment/equipment compatibility;
- normal/trim/material detail instead of extreme mesh density.

## 23. Animation

Animation should prioritize readable intent and weight.

Combat actions benefit from:

```text
anticipation -> action/contact -> recovery
```

Gameplay timing remains authoritative in gameplay contracts; presentation satisfies semantic action roles.

## 24. VFX

VFX should answer:
- what happened;
- where;
- how important it was.

Useful restrained families include impacts, trails, dust/debris, fire/smoke, cave mist, water effects and biome-specific effects when later justified.

Do not pre-commit future biomes to the current effect palette.

## 25. UI

UI should remain reusable and information-efficient rather than a permanently crowded MMO HUD.

Use reusable theme/9-slice/skin architecture and shared layout primitives. Information-dense screens such as inventory, crafting and a future large building catalog may use stronger hierarchy/search/filter structures.

Final cultural ornamentation of the UI should follow the game's later finalized visual identity rather than forcing a Nordic/medieval skin now.

## 26. Prototype-art policy

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

## 27. Production-efficiency rules

Prefer:
- reusable modular kits;
- shared geometry families;
- material families;
- trim sheets/decals/masks;
- procedural/per-instance variation;
- shaders that create perceived richness;
- LOD/instancing/batching;
- hero detail only where attention/camera distance justifies it;
- procedural natural environments over large amounts of hand-placed authored spectacle.

Avoid:
- unique hero-level asset cost for generic clutter;
- themes that require colossal handcrafted structures to communicate their identity;
- giant bespoke settlements as routine world content;
- gameplay identity tied to presentation paths;
- final-art production before scale/contracts are stable;
- geometry detail that provides little visible benefit;
- art decisions that force deterministic world-generation rewrites.

## 28. Intentionally adjustable decisions

Not locked:
- exact palette of the first Overworld biome;
- exact visual treatment of the Hell Entrance biome;
- final architecture ornament/style vocabulary;
- final clothing motifs;
- exact Bronze-Age cultural inspiration;
- exact Ancient Technology visual language;
- exact palettes of future biomes;
- future biome identities;
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

These require tests, profiling or later design work.

## Locked direction summary

1. Stylized dark-fantasy 3D remains the broad rendering target.
2. Perceived richness should come heavily from silhouettes, materials, shaders, lighting, atmosphere and VFX rather than brute-force asset complexity.
3. Solo-developer production economics are a hard art-direction constraint; avoid themes that require huge amounts of bespoke constructed-world content.
4. Valheim references specify building possibility/quality, not Nordic identity.
5. Current playable art scope is one Overworld biome plus one first-layer Underworld biome only.
6. Current Overworld baseline is grounded Bronze-Age fantasy using wood, rough stone, bronze/metal, cloth and practical handmade materials.
7. The first Underworld biome's core identity is **"This biome hates you"**: aggressive pressure, many relatively fragile enemies, no default HP-sponging.
8. The Underworld as a whole is **not Hell**; later biomes can have radically different identities.
9. Future biomes may intentionally break every current biome-specific visual/combat/ecology rule.
10. Ancient Technology is a long-term Underworld progression layer; the stabilization network/deep material are late-game direction and are not current implementation scope.
11. Presentation never becomes authoritative gameplay/world/persistence identity.
12. Final technical budgets remain profile-driven.
