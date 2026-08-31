# Underworld — Game Pillars

Status: **LOCKED high-level design direction**

## 1. Core identity — LOCKED

Underworld is a survival/exploration game built around two substantial procedural world domains:

- a comparatively readable, grounded **Overworld** that supports long-term settlement, exploration, resources, combat and world familiarity;
- a larger, deeper, stranger **Underworld** that is the primary long-term exploration space and the main source of spatial mystery.

The Underworld is not required to be the literal continuous geometry beneath the Overworld. The two domains are connected through explicit entrances/gateways and may use different coordinate spaces, scales and generation rules.

See [`20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](20_world/WORLD_DOMAINS_AND_TRANSITIONS.md).

## 2. Both worlds exist independently of player choices — LOCKED

Important procedural content is generated from the world seed independently of future player progression, building and route choices.

A rare boss site, structure, cavern, resource region or cave junction may exist in the Underworld regardless of what the player later builds in the Overworld. Progression changes what the player can realistically survive and exploit; it does not decide what procedural world truth is allowed to exist.

The Overworld and Underworld derive deterministic domain truth from the same root world identity without requiring one-to-one geometry.

## 3. Geography should remain meaningful — LOCKED

Old regions should not become irrelevant simply because the player progressed past their original enemies.

Overworld and Underworld geography can gain new meaning through:
- discovered gateways and exits;
- deeper routes;
- hidden structures;
- rare resources;
- lairs;
- shortcuts and loops;
- settlements and player construction.

The game should prefer spatial relevance over universal enemy level scaling.

Cross-domain gateway mapping may create coarse geographic relationships where useful, but coordinate parity is not a requirement.

## 4. Player freedom with consequences — LOCKED

Do not forbid reasonable player solutions unless a hard technical, persistence, multiplayer or encounter requirement demands it.

Examples:
- bases are allowed in both domains wherever normal building rules permit;
- building pieces may overlap or embed into terrain when that does not violate a hard gameplay restriction;
- snapping is a convenience, not a prison;
- players may repurpose structures and encounter spaces when the owning gameplay rules allow it;
- environment, logistics, structural support and hostile creatures should create difficulty naturally;
- critical/protected geometry may be restricted only where there is a concrete reason.

## 5. Building is a core creative pillar — LOCKED

Player construction is not a minor housing feature. It is a long-term creative system expected to support expressive Valheim-like modular building and large community-created structures.

The building system should favor:
- modular structural pieces rather than voxel-authoritative blocks;
- broad **shape vocabulary before cosmetic/material variety**;
- grid/socket snapping for convenience;
- deliberate snap escape/free placement;
- permissive overlap and terrain embedding;
- understandable structural support;
- material-dependent support behavior;
- architecture that can scale from ordinary houses to megabuilds.

The initial content set should stay small and coherent—e.g. one basic wood appearance plus stone and iron structural expansion—while proving the construction grammar first.

See [`30_gameplay/BUILDING_SYSTEM.md`](30_gameplay/BUILDING_SYSTEM.md).

## 6. Procedural first, intelligently connected — LOCKED

The world should remain procedural and unpredictable. It should not become a hand-authored Souls map.

The Underworld generator should deliberately create a minority of high-value spatial connections and loops. The design shorthand remains **about 10% Souls-style connectivity**: enough for occasional "wait, this connects back THERE" moments, not enough to turn the world into a tightly authored shortcut puzzle.

This applies to domain-internal topology. Cross-domain travel is handled through explicit gateways.

## 7. Depth changes Underworld generation grammar — LOCKED

Shallow, mid and deep Underworld are not identical caves with different textures and enemy stats.

Depth changes topology, geometry, connectivity, ecology and gameplay tendencies. Local exceptions are allowed so the layers remain unpredictable.

Depth is an Underworld-local generation concept and does not need to equal literal meters beneath the Overworld surface.

## 8. Combat direction — DIRECTIONAL

Combat should be more active and readable than baseline survival-game combat, but it should not drift into an MMO ability-bar system.

Universal actions and weapon properties should carry most of the depth. Enemy behavior, telegraphs, spacing, timing and player execution matter more than simply increasing stats.

Weapons may express skill differently. In particular, projectile/bow play should preserve meaningful player-owned aiming, release timing, lead/drop judgment and other execution rather than replacing skill with mastery-driven automation.

Exact future defensive mechanics, weapons and moves remain open until needed.

## 9. Mining should be intrinsically satisfying — LOCKED

Repeated resource gathering must feel good mechanically because resource extraction, especially underground, will be a major long-term activity.

Small nodes and large deposits intentionally provide different experiences; see [`MINING_AND_RESOURCES.md`](MINING_AND_RESOURCES.md).

## 10. Perceived quality over invisible complexity — LOCKED

Spend engineering and art complexity where the player can perceive it.

A seamless world transition is not inherently better than a loading screen if both create the intended experience. Likewise, environment assets may use economical geometry when silhouette, materials, shaders, lighting, fog, animation and VFX create the desired visual result.

This principle should reduce unnecessary:
- world-integration complexity;
- runtime cost;
- 3D modeling workload;
- bespoke asset count.

It must not be used to excuse poor silhouettes, unreadable gameplay or visibly broken presentation.

## 11. Scalability is architecture, not late polish — LOCKED

Optimization-sensitive systems must be designed to scale from the beginning.

Important targets include:
- procedural world streaming;
- cave extraction/loading;
- vegetation;
- player construction;
- persistence reconstruction;
- eventual multiplayer interest management.

Static unchanged logical state should perform minimal CPU work. Rendering, collision, simulation, persistence and networking may use different runtime representations of the same canonical state.

Player megabuilds are intentional stress cases rather than unsupported accidents.

See [`10_architecture/PERFORMANCE_AND_SCALABILITY.md`](10_architecture/PERFORMANCE_AND_SCALABILITY.md).

## 12. Do not design by feature accumulation — LOCKED

New features require a reason tied to the pillars above or to a current development milestone.

A feature being interesting is not enough reason to add it immediately.

Prefer proving one strong version of a system before multiplying cosmetic/content variants. In particular:
- one good weapon of a type before many variants;
- one strong forest system before many tree skins;
- one expressive construction grammar before hundreds of cosmetic building variants.
