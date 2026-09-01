# Underworld — Game Pillars

Status: **LOCKED high-level design direction**

## 1. Core identity — LOCKED

Underworld is a survival/exploration game built around two substantial procedural world domains:

- a comparatively readable, grounded **Overworld** that supports long-term settlement, exploration, resources, combat and world familiarity;
- a larger, deeper, stranger **Underworld** that is the primary long-term exploration space and the main source of spatial mystery.

The player may establish a home/base almost anywhere normal building rules permit. The Overworld therefore does not depend on large authored towns or fixed home hubs to feel inhabited; player construction supplies much of that habitation.

The Underworld is not required to be the literal continuous geometry beneath the Overworld. The two domains are connected through explicit entrances/gateways and may use different coordinate spaces, scales and generation rules.

See [`20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](20_world/WORLD_DOMAINS_AND_TRANSITIONS.md).

## 2. Current playable scope — HARD GATE

The current vertical slice needs exactly:

- **one Overworld biome**;
- **one biome in the first accessible Underworld layer**;
- a working transition between them;
- the core survival/building/combat/exploration loop functioning across both.

Do **not** design or implement additional Overworld biomes, deeper Underworld biomes/layers, or late-game systems merely because they are interesting future ideas.

Future biome slots may be acknowledged at a roadmap level, but their theme, art, mechanics and content remain intentionally open until the current two-biome foundation is genuinely playable and validated.

## 3. Both worlds exist independently of player choices — LOCKED

Important procedural content is generated from the world seed independently of future player progression, building and route choices.

A rare boss site, structure, cavern, resource region or cave junction may exist in the Underworld regardless of what the player later builds in the Overworld. Progression changes what the player can realistically survive and exploit; it does not decide what procedural world truth is allowed to exist.

The Overworld and Underworld derive deterministic domain truth from the same root world identity without requiring one-to-one geometry.

## 4. Geography should remain meaningful — LOCKED

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

## 5. Player freedom with consequences — LOCKED

Do not forbid reasonable player solutions unless a hard technical, persistence, multiplayer or encounter requirement demands it.

Examples:
- bases are allowed in both domains wherever normal building rules permit;
- building pieces may overlap or embed into terrain when that does not violate a hard gameplay restriction;
- snapping is a convenience, not a prison;
- players may repurpose structures and encounter spaces when the owning gameplay rules allow it;
- environment, logistics, structural support and hostile creatures should create difficulty naturally;
- critical/protected geometry may be restricted only where there is a concrete reason.

## 6. Building is a core creative pillar — LOCKED

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

Reference images from Valheim or other games specify the **freedom and complexity players should be able to achieve**, not the project's architectural/cultural theme.

See [`30_gameplay/BUILDING_SYSTEM.md`](30_gameplay/BUILDING_SYSTEM.md).

## 7. Procedural first, intelligently connected — LOCKED

The world should remain procedural and unpredictable. It should not become a hand-authored Souls map.

The Underworld generator should deliberately create a minority of high-value spatial connections and loops. The design shorthand remains **about 10% Souls-style connectivity**: enough for occasional "wait, this connects back THERE" moments, not enough to turn the world into a tightly authored shortcut puzzle.

This applies to domain-internal topology. Cross-domain travel is handled through explicit gateways.

## 8. Depth changes Underworld generation grammar — LOCKED

Shallow, mid and deep Underworld are not identical caves with different textures and enemy stats.

Depth changes topology, geometry, connectivity, ecology and gameplay tendencies. Local exceptions are allowed so the layers remain unpredictable.

Depth is an Underworld-local generation concept and does not need to equal literal meters beneath the Overworld surface.

## 9. Biome identity is local, not universal — LOCKED

The game may eventually contain multiple dramatically different biomes in both domains, with the Underworld intended to have the larger long-term biome/content space.

No biome-specific visual, ecological, combat or mood rule should automatically become a universal world rule.

In particular, future biomes are explicitly allowed to **break every biome-specific rule established for the current vertical slice**. A later biome may reverse the current palette, climate, enemy behavior, density, traversal style, lighting, resource logic or mood if that gives it a stronger identity.

This freedom does not supersede global architecture, persistence, readability, scalability or production constraints.

## 10. Current first Underworld biome — "This biome hates you" — LOCKED DIRECTION

The first accessible Underworld biome is a hostile entrance/outer layer whose central identity is:

> **This biome hates you.**

It is the first region where the player should feel that the environment's inhabitants actively reject their presence rather than merely behaving like wildlife or passive territorial enemies.

Its combat identity should favor:
- immediate aggression;
- fast engagement;
- packs and simultaneous pressure;
- relatively low-HP common enemies;
- short kill times when the player lands clean attacks;
- difficulty created through speed, numbers, positioning and pressure rather than health inflation.

Hell-hound/hell-dog-like enemies and other lesser demon/Underworld/Hades-inspired creatures fit this layer well.

Do not spend the layer's difficulty budget on routine HP sponges. A larger enemy may hit extremely hard or have a dangerous moveset while still dying relatively quickly when handled correctly.

This **does not** mean every future Underworld biome is Hell. The Hell-Entrance identity belongs to this biome only.

## 11. Combat direction — DIRECTIONAL

Combat should be more active and readable than baseline survival-game combat, but it should not drift into an MMO ability-bar system.

Universal actions and weapon properties should carry most of the depth. Enemy behavior, telegraphs, spacing, timing and player execution matter more than simply increasing stats.

Weapons may express skill differently. In particular, projectile/bow play should preserve meaningful player-owned aiming, release timing, lead/drop judgment and other execution rather than replacing skill with mastery-driven automation.

Exact future defensive mechanics, weapons and moves remain open until needed.

## 12. Mining should be intrinsically satisfying — LOCKED

Repeated resource gathering must feel good mechanically because resource extraction, especially underground, will be a major long-term activity.

Small nodes and large deposits intentionally provide different experiences; see [`MINING_AND_RESOURCES.md`](MINING_AND_RESOURCES.md).

## 13. Overworld craftsmanship vs Ancient Technology — LOCKED LONG-TERM DIRECTION

The current high-level visual/progression contrast is:

- the Overworld is generally grounded **Bronze-Age fantasy** in its craftsmanship, tools, structures and materials;
- the Underworld eventually becomes the source of a visually and mechanically distinct **Ancient Technology** layer.

The surface baseline emphasizes practical wood, rough stone, bronze/metal, cloth and other handmade materials rather than a technology-heavy world from the beginning.

Ancient Technology is **late-game direction**, not current vertical-slice implementation scope.

A signature future concept is an ancient stabilization network in which a deep exotic material is unusable outside an active field; a core/generator creates the stabilizing state, portals transmit it, and local anchors/projectors extend it. Mining, storage, processing, transport and construction with that material must remain inside the active network.

Do not implement or prototype that system until later progression actually needs it.

## 14. Perceived quality over invisible complexity — LOCKED

Spend engineering and art complexity where the player can perceive it.

A seamless world transition is not inherently better than a loading screen if both create the intended experience. Likewise, environment assets may use economical geometry when silhouette, materials, shaders, lighting, fog, animation and VFX create the desired visual result.

This principle should reduce unnecessary:
- world-integration complexity;
- runtime cost;
- 3D modeling workload;
- bespoke asset count.

It must not be used to excuse poor silhouettes, unreadable gameplay or visibly broken presentation.

## 15. Solo-production economics are a design constraint — LOCKED

The project is being built by a solo developer with substantial AI assistance. Theme and content choices must therefore respect what scales efficiently.

Prefer content whose value can be multiplied through code and reuse:
- procedural world generation;
- procedural placement;
- modular kits;
- reusable materials/shaders;
- deterministic variation;
- simple reusable spawned structures.

Avoid themes that require their identity to come from:
- recurring colossal handcrafted structures;
- giant bespoke cities;
- thousands of manually placed building pieces;
- enormous unique prop catalogs;
- months of authored spectacle with little gameplay return.

Wild-spawned buildings/ruins/settlements should generally stay relatively simple, bounded, sparse or assembled from a small reusable kit. Exceptional authored locations are allowed when their gameplay value actually justifies the cost.

This restriction applies to developer-authored world content, not to what players may construct themselves.

## 16. Scalability is architecture, not late polish — LOCKED

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

## 17. Do not design by feature accumulation — LOCKED

New features require a reason tied to the pillars above or to a current development milestone.

A feature being interesting is not enough reason to add it immediately.

Prefer proving one strong version of a system before multiplying cosmetic/content variants. In particular:
- one good weapon of a type before many variants;
- one strong forest system before many tree skins;
- one expressive construction grammar before hundreds of cosmetic building variants;
- one playable Overworld biome and one playable first-layer Underworld biome before designing future biome families;
- no late-game Ancient Technology implementation before the current core loop is proven.
