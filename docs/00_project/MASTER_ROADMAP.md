# Underworld Master Roadmap

Status: **strategic execution plan; phases/lane dependencies are authoritative planning guidance, individual task cards remain pull-board authority**

Baseline when authored: `main@7d444b3540ee424da67a5b92bb8c50c4a0ae645b`.

This roadmap converts the current game direction into a long-horizon execution model that supports parallel workers without allowing uncontrolled overlap.

It deliberately separates **phases** from **work lanes**:
- a phase defines an integrated capability/exit gate;
- lanes define topics that can often progress in parallel;
- a lane may start early when its dependencies are satisfied;
- workers still self-pull from READY cards and obey WIP/review/integration governance.

The roadmap is not a promise to implement every possible feature before playtesting. It is a dependency map for deciding what can safely be worked on next.

---

# 1. Permanent work lanes

Use these lane prefixes when decomposing roadmap work into pull-board cards.

| Lane | Topic | Typical ownership |
| --- | --- | --- |
| `ARCH` | cross-system architecture | domain boundaries, contracts, dependencies |
| `WORLD-OW` | Overworld | terrain, rivers, biomes, surface streaming |
| `WORLD-UW` | Underworld | cave topology, geometry, depth grammar, underground streaming |
| `GATE` | world transitions | gateways, domain handoff, entrance/exit mapping |
| `BUILD` | player construction | placement, sockets, support, building content/runtime |
| `PERF` | performance/scalability | profiling, budgets, batching, job/commit scheduling |
| `SURV` | survival/production | harvesting, crafting, stations, resources, food/logistics |
| `COMBAT` | combat | weapons, enemies, damage, AI, bosses |
| `CONTENT` | authored definitions | schemas, rulebooks, catalogs, validation |
| `PRES` | art/presentation | meshes, materials, shaders, VFX, animation, environment dressing |
| `UI` | UI/UX | HUD, inventories, build catalog, settings, feedback |
| `PERSIST` | durable state | saves, migrations, world/build deltas |
| `NET` | multiplayer | authority, replication, interest management |
| `TOOLS` | authoring/dev tooling | editors, profilers, generators, content workflows |
| `QA` | validation/release | deterministic tests, integration smoke, performance gates, exports |

## Parallelism rule

Parallel work is encouraged when cards have:
- disjoint production paths or explicitly coordinated shared ownership;
- satisfied dependencies;
- independent acceptance evidence;
- no competing authority over the same canonical state.

Do not create a second implementation of an existing authority simply to make a lane appear parallel.

---

# 2. High-level dependency graph

```text
PHASE 0  Current closeout + two-domain architecture pivot
   |
   +--------------------------+
   |                          |
   v                          v
PHASE 1 Runtime/performance   PHASE 2 Overworld generation foundation
   |                          |
   +-------------+------------+
                 v
           PHASE 3 Building V1
                 |
          +------+-------+
          |              |
          v              v
 PHASE 4 Underworld   PHASE 5 Production/survival depth
 expedition depth        |
          |              |
          +------+-------+
                 v
        PHASE 6 Building scale & advanced construction
                 |
          +------+-------+
          |              |
          v              v
 PHASE 7 Combat depth   PHASE 8 World structures/ecology
          |              |
          +------+-------+
                 v
        PHASE 9 Presentation/world quality
                 |
                 v
        PHASE 10 Multiplayer foundation
                 |
                 v
        PHASE 11 Large-world persistence/network scale
                 |
                 v
        PHASE 12 Content-production platform
                 |
                 v
        PHASE 13 Meta progression/social depth
                 |
                 v
        PHASE 14 Release hardening / Early Access-quality baseline
```

This graph shows integration gates, not a ban on early experiments in later lanes.

---

# PHASE 0 — M3 closeout under the new two-domain decision

## Goal

Finish the current first-playable foundation without spending additional engineering on a physically continuous Overworld-to-Underworld seam that is no longer target architecture.

## Architectural migration

### `ARCH/GATE` — P0
- introduce explicit world-domain identity (`OVERWORLD`, `UNDERWORLD`);
- define gateway identity and source/destination anchors;
- make direct loading/fade transition the accepted V1 presentation;
- separate Overworld entrance selection from Underworld destination bootstrap;
- ensure domain-local positions are never converted by assumed shared coordinates;
- define source-runtime unload/destination-runtime preparation lifecycle;
- preserve deterministic gateway mapping.

### Existing cave work reclassification

Keep work that remains domain-internal:
- cave topology;
- Marching Cubes/geometry extraction;
- cave runtime cells;
- observer streaming;
- collision readiness;
- underground Continue reconstruction;
- resource realization.

Stop requiring new work whose sole purpose is:
- physically cutting the surface terrain to the exact cave mesh;
- preserving same-space surface->cave collision continuity;
- proving that Underworld Y is literally below Overworld terrain.

### `WORLD-UW` — P0 parallel
- complete normal observer-generated cave-cell execution;
- preserve stale-result rejection;
- restore underground saves before player physics can enter missing geometry;
- ensure destination bootstrap can request safe initial Underworld cells independently of surface geometry.

### `PERF` — P0 parallel
- keep cold/warm Underworld transition profiling;
- separate generation, extraction, collision preparation and realization timings;
- measure transition after domain separation;
- establish temporary acceptable M3 latency based on real evidence rather than pretending synchronous extraction is cheap.

### `SURV/WORLD-UW` — P0 after resident-cell authority
- compose authored underground iron through real resident-cell realization;
- mine through authoritative resource service;
- apply inventory + WorldDelta atomically;
- prove unload/re-entry/Continue reconstruction.

### `UI/PRES` — parallel
- finish minimum route/objective guidance from semantic state;
- finish character presentation candidate/human visual gate;
- no DebugHUD correctness dependency.

### `QA` — final gate
- update first-playable smoke to use explicit gateway transition;
- prove NEW -> Overworld gameplay -> gateway -> Underworld -> iron/combat -> save/continue -> recovery;
- prove both Overworld and Underworld domain-local Continue;
- exported Windows human campaign.

## Phase 0 exit gate

A real playable build exists where:
- Overworld and Underworld are explicit domains;
- travel works through a simple reliable loading transition;
- cave runtime reconstructs safely;
- one full gather/craft/cave/iron/combat/save/recovery route works;
- performance is measured and not catastrophically blocking;
- obsolete physical-seam requirements are removed from future acceptance.

---

# PHASE 1 — Runtime scheduling and performance foundation

## Goal

Make optimization architecture explicit before world scale and building scale multiply object counts.

## `PERF` lane

### PERF-1A — unified profiling harness
- CPU frame-time capture;
- main-thread stall capture;
- generation/extraction task timing;
- mesh/collision commit timing;
- render/draw statistics;
- memory/cache statistics;
- reproducible ordinary/heavy/stress scenarios.

### PERF-1B — bounded job scheduling
- canonical job request/result identity;
- priority classes;
- cancellation/stale-result handling;
- maximum active worker work;
- no dependence on thread completion order for world truth.

### PERF-1C — main-thread publication budgets
- bounded mesh commits/frame;
- bounded collision commits/frame;
- bounded spawn realization/frame;
- destination safety can override ordinary visual priority;
- telemetry for budget overruns.

### PERF-1D — cache ownership
- deterministic pure-data cache boundaries;
- runtime representation cache boundaries;
- invalidation/revision contracts;
- memory caps/eviction strategy.

## `ARCH` lane — parallel
- canonical state vs runtime representation rule applied across world/building/content;
- define spatial sector abstraction reusable where appropriate;
- formalize event-driven dirty propagation convention.

## `QA` lane — parallel
Create baseline scenarios:
- empty/simple Overworld;
- cold Underworld transition;
- warm Underworld re-entry;
- dense cave cell set;
- save reconstruction.

## Phase 1 exit gate

No major scalable subsystem is forced to perform unbounded synchronous publication work by architecture.

---

# PHASE 2 — Overworld procedural foundation V1

## Goal

Replace a simplistic noise surface with a controllable semantic terrain pipeline suitable for exploration, forests, resources and future structures.

## `WORLD-OW` lane A — macro fields
- root/domain seed derivation;
- Overworld generator manifest/revisions;
- continental/landmass mask where required by map shape;
- base elevation field;
- mountain/ridge field;
- cliff/steepness field;
- moisture field;
- temperature/biome tendency field;
- local detail field.

Do not let one noise function become the whole world design.

## `WORLD-OW` lane B — rivers/water
Parallel after macro elevation contract:
- deterministic drainage/river candidate network;
- river-carving/deformation stage;
- bank/beach rules;
- sea/water-level contract;
- navigation/structure/resource hooks;
- keep water presentation independent from river world truth.

## `WORLD-OW` lane C — terrain streaming
Parallel after cell/address contract:
- surface cells/sectors;
- prioritized near/medium/far realization;
- collision tiering;
- stale-result rejection;
- player movement prediction/prefetch.

## `CONTENT` lane — parallel
- biome definition schema;
- terrain material family definitions;
- placement-rule schema;
- semantic surface/anchor tags.

## `PRES` lane — parallel
- simple terrain materials;
- fog/horizon integration;
- basic water presentation;
- prototype forest presentation.

## `QA` lane
- deterministic field fingerprints;
- seam/boundary tests;
- negative-coordinate cases;
- large-region generation campaign;
- terrain streaming stress.

## Phase 2 exit gate

Multiple seeds produce controllable, readable terrain with hills/mountains/cliffs/water structure and stable streaming without requiring final art.

---

# PHASE 3 — Building System V1: expressive construction grammar

## Goal

Prove the building system as a core game pillar before producing hundreds of pieces.

## `BUILD` lane A — piece/content contract
- `BuildPieceDefinition` family;
- category/subcategory/tags;
- arbitrary transform support;
- footprint/bounds;
- socket definitions;
- material structural profile;
- resource cost references;
- presentation binding;
- catalog metadata.

## `BUILD` lane B — placement
Parallel after definition core:
- aim/surface selection;
- placement preview;
- rotation;
- canonical construction grid;
- semantic socket snapping;
- snap-point cycling;
- deliberate snap-disable/free placement;
- arbitrary transform commit.

## `BUILD` lane C — permissive geometry rules
Parallel with placement:
- build-piece overlap normally allowed;
- terrain embedding allowed;
- narrow protected-volume rules only;
- accidental exact-duplicate policy if needed;
- non-finite/out-of-world rejection.

## `BUILD/SURV` lane D — transactions/persistence
- atomic resource consumption;
- deconstruction/refund policy placeholder;
- durable `BuildInstance` world delta;
- unload/reload reconstruction;
- world-domain ownership.

## `BUILD` lane E — structural graph
After basic placement:
- terrain/rock structural roots;
- connection graph;
- cached support propagation;
- wood support attenuation;
- stronger stone/iron profiles;
- dirty-subgraph recomputation;
- readable support state.

## `CONTENT/PRES` lane F — initial kit
Keep art simple.

Target a compact but expressive set:
- one wood visual family;
- floors/half floors;
- walls/half walls;
- several beam/post lengths;
- diagonals/braces;
- stairs;
- rails;
- door;
- small roof-angle/join set;
- minimal stone foundation/wall/pillar set;
- minimal iron reinforcement/beam set.

Shape variety outranks texture variety.

## `UI` lane — parallel
- minimal build menu;
- category navigation;
- selected piece preview;
- rotate/snap/free-placement feedback;
- support visualization/debug mode.

## `QA/PERF` lane
- placement transaction tests;
- persistence reconstruction;
- arbitrary transform regression;
- overlap/terrain embedding regressions;
- structural graph determinism;
- 500/1k/5k piece early stress fixtures.

## Phase 3 exit gate

Players can build genuinely creative structures with a small kit, including intentional overlap, buried pieces and off-grid combinations, without bespoke code per piece.

---

# PHASE 4 — Underworld expedition depth V2

## Goal

Spend the complexity saved by domain separation on making the Underworld itself substantially better.

## `WORLD-UW` lane A — domain-local depth grammar
- remove dependence on literal Overworld surface height;
- define Underworld-local depth/reference metrics;
- shallow/mid/deep blended profiles;
- profile-dependent chamber scale;
- tunnel dimensions;
- verticality;
- branching/dead ends;
- connectivity tendencies.

## `WORLD-UW` lane B — topology diversity
Parallel:
- large chambers;
- vertical shafts;
- multi-level routes;
- deliberate reconnection/loops;
- rare giant caverns;
- local exceptions;
- bounded cross-region links.

## `WORLD-UW` lane C — underground environment systems
- water/lakes/rivers where appropriate;
- geology/material regions;
- cave decoration placement hooks;
- special-site reservation;
- safe gateway arrival sites.

## `CONTENT` lane — parallel
- first meaningful underground biome/region families;
- resource-placement profiles;
- structure/site hooks;
- enemy ecology hooks.

## `PERF` lane — parallel
- extraction priority improvements;
- LOD/proxy options for distant cave visibility if required;
- collision realization budgets;
- memory/cache profiling for deep traversal.

## `QA`
- deterministic topology campaigns;
- gateway destination safety;
- long traversal/backtrack stress;
- vertical streaming stress;
- deep Continue reconstruction.

## Phase 4 exit gate

The Underworld feels like a distinct procedural realm with meaningful vertical/topological variety rather than a repeated cave tunnel generator.

---

# PHASE 5 — Repeatable survival and production depth

## Goal

Create enough real production choices that exploration has repeated purpose before adding heavy meta-progression.

## `SURV` lane A — workstation capabilities
- bounded station capability architecture;
- avoid station-specific duplicate crafting systems;
- proximity/availability semantics;
- UI exposure through semantic capability state.

## `SURV` lane B — resource chains
- second and third meaningful resource families;
- refining/processing;
- material tiers only when they create gameplay choice;
- world-delta depletion/reconstruction;
- production costs tuned through playtests.

## `SURV` lane C — equipment production
- additional tool/armor utility where route depth requires it;
- repair loop;
- meaningful logistics/carry decisions;
- avoid variant spam.

## `CONTENT` lane — parallel
- resource definitions;
- recipe families;
- station capability definitions;
- item/tool/equipment rules;
- production content validation.

## `UI` lane — parallel
- station/crafting UX refinement;
- recipe filters/search when needed;
- clear missing-requirement feedback;
- inventory/hotbar workflow polish.

## `QA`
- full resource -> refine -> craft -> use route;
- save/reload at every stage;
- no duplicate transaction authority;
- deterministic resource regeneration/depletion policy.

## Phase 5 exit gate

Players have repeatable reasons to travel, extract, process and return rather than completing one linear iron route once.

---

# PHASE 6 — Building scale, advanced construction and catalog

## Goal

Turn the proven V1 construction grammar into a system that can eventually support hundreds/1000+ pieces and extreme player builds.

## `PERF/BUILD` lane A — spatial building sectors
- sector membership/index;
- local dirty rebuilds;
- stable cross-sector logical identity;
- sector visibility/activity tiers.

## `PERF/BUILD` lane B — rendering scale
Parallel:
- GPU instancing/MultiMesh candidates;
- repeated-piece batches;
- spatial render clusters;
- near/medium/far structure representations;
- building LOD/proxy generation.

## `PERF/BUILD` lane C — collision scale
- static collision aggregation experiments;
- interaction/damage mapping back to logical pieces;
- local rebuild only;
- near/far activation rules.

## `BUILD` lane D — advanced placement
Parallel:
- fine offsets;
- rotation increments;
- local/global transforms;
- duplicate piece;
- replace while preserving transform;
- better snap candidate cycling;
- precision controls.

## `BUILD` lane E — shape expansion
- deeper wood kit;
- stone architecture family;
- iron structural family;
- arches/corners/roof joins;
- larger gates/bridges;
- decoration only after structural vocabulary is strong.

## `UI` lane F — scalable build browser
- hierarchical categories;
- search;
- favorites;
- recent pieces;
- material/style filters;
- related shapes/variants;
- controller/keyboard usability.

## `BUILD/TOOLS` lane G — blueprints
After stable arbitrary-transform persistence:
- relative-transform blueprint format;
- player save/load blueprint;
- developer/procedural consumer boundary;
- validation/versioning.

## `QA/PERF` lane H — megabuild campaign
Create reproducible stress scenes:
- 1k pieces;
- 5k pieces;
- 10k pieces;
- 25k+ experimental ceiling tests;
- dense overlap wall/beam art;
- three tall stone towers connected with iron spans and an elevated town/platform;
- many lights/doors/containers.

Measure graceful degradation rather than locking arbitrary promises before evidence.

## Phase 6 exit gate

Ordinary construction is cheap, advanced builders have precision freedom, and large settlements no longer map one-to-one onto expensive per-piece runtime objects.

---

# PHASE 7 — Combat depth and skill-expression

## Goal

Expand combat breadth without turning the game into an MMO ability system or producing weapon variants before each archetype is good.

## `COMBAT` lane A — bow family
- deterministic projectile/ballistic model;
- draw state;
- player-owned aim;
- lead/drop judgment;
- release timing;
- meaningful draw-speed/damage relationship;
- no mastery auto-aim;
- clear hit feedback;
- one or very few arrow types initially.

## `COMBAT` lane B — weapon archetypes
Add one strong representative of missing major weapon types only when its gameplay identity is clear.

Do not multiply skins/stat variants as substitute for mechanics.

## `COMBAT` lane C — enemy families
Parallel:
- second/third cave enemy families;
- surface enemy family expansion;
- readable telegraphs;
- distinct spacing/behavior problems;
- reward identity.

## `COMBAT` lane D — bosses/special encounters
After ordinary combat vocabulary is proven:
- encounter hooks from procedural world truth;
- arena/clearance rules;
- no relocation based on player progression;
- recoverable failure state.

## `PRES` lane — parallel
- weapon animations;
- projectile trails/impact feedback;
- creature animation/telegraphs;
- audio semantic coverage.

## `QA`
- deterministic combat regressions;
- projectile consistency;
- save/loot exactly-once behavior;
- performance with multiple enemies/projectiles.

## Phase 7 exit gate

Combat supports multiple genuinely different skill problems, including a bow whose effectiveness depends strongly on player execution.

---

# PHASE 8 — World structures, settlements and ecology

## Goal

Make both world domains contain authored-feeling content assembled from procedural systems and reusable content definitions.

## `WORLD-OW` lane
- settlement/site distribution;
- roads/path hooks where useful;
- resource/ecology response to biome fields;
- local caves/overhangs distinct from Underworld gateways.

## `WORLD-UW` lane
- ruins;
- mines;
- large special chambers;
- ancient complexes;
- boss sites;
- resource/geology landmarks.

## `BUILD/TOOLS` lane — parallel
- allow procedural structures to consume modular building/blueprint language where beneficial;
- preserve hero/special one-off assets where modular construction is insufficient.

## `CONTENT` lane
- structure/site definition families;
- biome/ecology population rules;
- deterministic placement validation;
- reserved-clearance contracts.

## `PRES` lane
- modular ruin kits;
- settlement architecture kits;
- decals/clutter/material variation;
- world landmarks for navigation.

## Phase 8 exit gate

Procedural exploration regularly produces recognizable places and landmarks rather than only terrain/cave geometry plus scattered resources.

---

# PHASE 9 — Environment presentation and perceptual-quality pass

## Goal

Turn stable world systems into the intended semi-realistic/stylized visual experience without exploding asset-production cost.

## `PRES` lane A — vegetation
- small reusable tree archetype library;
- strong silhouettes;
- foliage cluster meshes;
- leaf-lighting/transmission shader;
- wind;
- instance variation;
- LODs;
- forest proxies/impostors.

## `PRES` lane B — terrain/materials
Parallel:
- stylized PBR terrain materials;
- stochastic/anti-repetition techniques where beneficial;
- rock/soil/wetness/moss/mineral material families;
- decals/trim/masks.

## `PRES` lane C — water/atmosphere
- water shader;
- fog/haze;
- Underworld atmosphere;
- controlled volumetric/god-ray alternatives if performant;
- day/night integration.

## `PRES` lane D — caves
- rock material families;
- stalactite/stalagmite/formation kits;
- biome-specific dressing;
- light/fog language;
- simple geometry with strong presentation.

## `PERF` lane — parallel
- vegetation render budgets;
- shadow budgets;
- light budgets;
- far representation validation;
- shader cost profiling.

## `QA/UI` lane
- accessibility/readability in darkness;
- graphics quality settings;
- LOD/view-distance controls;
- screenshot/visual regression references where useful.

## Phase 9 exit gate

Representative Overworld and Underworld scenes approach target quality while remaining scalable and using a manageable reusable asset library.

---

# PHASE 10 — Multiplayer authority foundation

## Goal

Add multiplayer without synchronizing entire procedural worlds or making every runtime object network-authoritative.

## `NET` lane A — session/authority
- server-authoritative shared world mutation;
- player identity/session lifecycle;
- join/leave;
- domain ownership/state.

## `NET` lane B — deterministic world bootstrap
Parallel:
- transmit root world/generator manifest identity;
- clients regenerate deterministic base truth;
- server sends durable deltas and dynamic authoritative state;
- compatibility/version rejection.

## `NET` lane C — interest management
- world domain as first boundary;
- spatial cells/sectors as second boundary;
- dynamic entity relevance;
- building-sector relevance;
- no continuous replication of unchanged static pieces.

## `NET/BUILD` lane D
- authoritative placement requests;
- validation/resource transaction server-side;
- building delta replication;
- concurrent edit/conflict behavior.

## `NET/GATE` lane E
- cross-domain transition synchronization;
- player domain changes;
- destination readiness;
- party members may exist in different domains.

## `QA`
- deterministic seed compatibility;
- late join near large settlement;
- two players in separate domains;
- save/restart server reconstruction;
- disconnect during transition/build transaction.

## Phase 10 exit gate

Multiple players can explore/build across both domains without transmitting the complete generated world or continuously replicating static content.

---

# PHASE 11 — Large-world persistence and network scale

## Goal

Prove long-lived worlds with extensive deltas, settlements and cross-domain play.

## `PERSIST` lane
- per-domain delta partitioning;
- building-sector persistence;
- large-save indexing;
- corruption/failure handling;
- migrations;
- atomic commit boundaries;
- snapshot/backup strategy.

## `NET` lane — parallel
- delta compaction/streaming;
- join-time prioritization;
- bandwidth profiling;
- large settlement replication;
- reconnection/resync.

## `PERF` lane
- huge-save load timing;
- incremental/lazy reconstruction;
- memory footprint;
- cache pressure;
- server tick cost.

## `QA`
Stress worlds containing:
- long Underworld exploration history;
- many depleted resources;
- multiple settlements;
- large megabuild;
- players in both domains;
- save/load across version migration fixtures.

## Phase 11 exit gate

World longevity and player creativity no longer make save/load/network behavior scale linearly in the most naive possible way.

---

# PHASE 12 — Content-production platform

## Goal

Make adding large amounts of validated game content safe and fast.

## `CONTENT` lane A — rulebooks
Complete/expand rulebooks for:
- building pieces;
- items/tools/weapons;
- recipes/stations;
- resources;
- enemies;
- attacks;
- structures/sites;
- biome/ecology rules;
- VFX/audio/presentation bindings.

## `TOOLS` lane B — authoring workflows
Parallel:
- add-building-piece workflow;
- add-weapon workflow;
- add-enemy workflow;
- add-resource chain workflow;
- add-biome/placement profile workflow;
- validation feedback optimized for content authors.

## `TOOLS` lane C — bulk generation/import
- schema-aware content generators where useful;
- automatic StableId/reference checks;
- preview tooling;
- build-kit socket visualization;
- placement-rule visualization.

## `QA` lane
- dependency-closed validation;
- stale evidence/revision checks;
- deterministic content shards;
- migration fixtures;
- large catalog load/performance tests.

## Phase 12 exit gate

Adding the 101st or 1001st building/content definition is primarily an authoring task, not a reason to rewrite infrastructure.

---

# PHASE 13 — Meta progression and long-term social depth

## Goal

Only after sufficient real gameplay breadth exists, add systems that reward long-term play without replacing player skill or making old geography irrelevant.

## Candidate `SURV/COMBAT` lanes
- weapon mastery with restrained bonuses that preserve player execution;
- professions only if they create meaningful production choices;
- character creation/customization;
- trophies/housing rewards;
- long-term unlocks;
- settlement utility progression.

## Design constraints
- no mastery-driven auto-aim for skill weapons;
- avoid universal enemy level scaling;
- do not turn progression into endless percentage inflation;
- cosmetic/building rewards are high-value because construction is a core pillar;
- progression should send players back into meaningful world geography rather than only menus.

## `UI/CONTENT` lanes — parallel
- progression presentation;
- unlock discovery;
- trophy/building catalog integration;
- scalable content taxonomy.

## Phase 13 exit gate

Long-term systems deepen existing gameplay instead of compensating for missing expedition/combat/building content.

---

# PHASE 14 — Release hardening / Early Access-quality baseline

## Goal

Convert the broad production game into a stable, understandable, scalable public-quality baseline.

## `PERF`
- optimize measured worst cases;
- eliminate avoidable main-thread hitches;
- megabuild profiling;
- dense forest profiling;
- deep Underworld streaming;
- multiplayer settlement profiling;
- quality presets.

## `QA`
- long soak tests;
- save corruption/recovery campaign;
- migration campaign;
- multiplayer reconnect/late-join campaign;
- ordinary + extreme procedural seed campaigns;
- exported builds on representative hardware;
- controller/input campaigns.

## `UI`
- accessibility;
- rebinding;
- graphics/performance settings;
- scalable build catalog polish;
- tutorial/onboarding that does not require external knowledge;
- readable failure/placement/support feedback.

## `PRES`
- replace remaining evaluation-blocking placeholders;
- visual consistency pass;
- audio coverage;
- VFX/readability pass;
- animation polish where player attention justifies it.

## `CONTENT`
- balance breadth against quality;
- remove duplicate/filler variants;
- ensure each major weapon/resource/enemy/building family has a reason to exist.

## Phase 14 exit gate

The game can survive ordinary play, extreme builders, long-lived saves and multiplayer sessions with known measured limits and without relying on developer knowledge or DebugHUD correctness.

---

# 3. Cross-phase priorities

Some concerns remain active through many phases.

## Performance is continuous

Do not defer all optimization to Phase 14.

Every scalable feature should introduce its own ordinary/heavy/stress evidence when it becomes production-relevant.

## Building receives unusually high priority

Because construction is a core player-expression pillar, building begins early and receives a dedicated scale phase before late meta-progression.

## Content variants remain deliberately late

Prefer:
- one good weapon archetype before many versions;
- one good tree/forest system before many cosmetic tree packs;
- one strong wood/stone/iron construction language before hundreds of skins;
- one meaningful enemy family before recolored stat variants.

## World-domain separation is permanent

Do not reintroduce Overworld/Underworld geometric continuity accidentally through:
- save coordinates;
- entrance generation;
- depth calculations;
- multiplayer replication;
- building assumptions.

## Presentation remains downstream

A visual replacement must not silently redefine deterministic identity or durable state.

---

# 4. Recommended worker concurrency by phase

The following is a *maximum useful topology*, not a requirement to keep every lane occupied.

| Phase | Useful parallel lanes |
| --- | --- |
| 0 | GATE/ARCH, WORLD-UW, PERF, PRES, UI; SURV after cave residency |
| 1 | PERF scheduler, PERF profiling, ARCH representation, QA benchmarks |
| 2 | WORLD-OW fields, rivers, streaming, CONTENT, PRES, QA |
| 3 | BUILD placement, BUILD content contract, BUILD persistence, CONTENT/PRES kit, UI; structure after placement |
| 4 | WORLD-UW topology, WORLD-UW environment, CONTENT, PERF, QA |
| 5 | SURV stations, SURV resources, CONTENT, UI, QA |
| 6 | BUILD sectors, render scale, collision scale, advanced controls, UI catalog, content expansion, QA stress |
| 7 | bow, enemy family, presentation, content; bosses after ordinary combat contract |
| 8 | Overworld sites, Underworld sites, building/blueprints, content, presentation |
| 9 | vegetation, terrain materials, water/atmosphere, cave dressing, performance/settings |
| 10 | NET authority, deterministic bootstrap, interest management, building networking, gateway networking, QA |
| 11 | persistence scale, network scale, performance, QA |
| 12 | rulebooks, authoring workflows, tooling, validation |
| 13 | mastery/professions/character/trophies only as individually justified lanes |
| 14 | PERF, QA, UI/accessibility, PRES, CONTENT balance |

---

# 5. Card decomposition rule

Do not create one issue named `Implement Phase 6`.

Each implementation card should have:
1. one owning lane;
2. explicit production paths/authority;
3. dependency list;
4. acceptance criteria;
5. deterministic/persistence implications;
6. performance implications where scalable;
7. required automated/manual evidence;
8. forbidden duplicate authorities;
9. clear handoff condition for downstream cards.

Good decomposition example:

```text
BUILD-PLACEMENT-001 arbitrary transform request/preview
BUILD-SNAP-001 semantic socket model
BUILD-FREE-001 snap-disable/free placement
BUILD-PERSIST-001 durable BuildInstance delta
BUILD-STRUCT-001 terrain-root support graph
BUILD-PERF-001 building sector index
BUILD-PERF-002 repeated-piece render batching
BUILD-UI-001 scalable catalog taxonomy
```

This keeps workers parallel without creating overlapping mega-branches.

---

# 6. Strategic end state

The intended architecture should eventually support:
- two independent large procedural worlds;
- explicit reliable travel between them;
- strong surface exploration and settlement;
- deep vertical Underworld exploration;
- expressive Valheim-like construction;
- thousands of buildable content definitions without bespoke code;
- extreme player megabuilds with graceful performance scaling;
- skill-expressive combat;
- repeatable resource/production expeditions;
- modular low-cost environment art that looks richer through presentation;
- deterministic base worlds plus compact durable deltas;
- multiplayer that synchronizes changes/relevant state rather than whole generated worlds;
- tooling/validation that allows content volume to grow without infrastructure collapse.

The roadmap should be revisited whenever profiling or real play demonstrates that a different ordering produces more player value. Architectural invariants should only be superseded explicitly, not eroded by convenience implementations.
