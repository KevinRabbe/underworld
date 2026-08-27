# Underworld — Decision Log

This file records explicit design/architecture decisions. It is append-oriented: when a locked rule changes, add a new entry explaining the replacement rather than silently rewriting history.

## 2026-08-27 — Architecture/design checkpoint

### World identity — LOCKED

- Surface is comparatively smaller/readable; Underworld is substantially larger in meaningful traversable space.
- Surface and Underworld share one real 3D world-coordinate relationship.
- Important underground content exists independently of player progression and future building choices.
- Old surface locations can gain new meaning when deeper underground relationships are discovered later.

### Cave systems and entrances — LOCKED

- Underground is hierarchical procedural topology, not uniform random cave noise.
- Regional systems generally expose roughly 1–3 surface entrances where appropriate.
- Entrances may connect to different depths of the same cave/network.
- An apparently easy entrance may lead unexpectedly deep; the game does not guarantee progression-safe entrances.

### Depth structure — LOCKED

- Three broad depth grammars: shallow, mid and deep.
- They differ structurally/topologically, not only by visuals and enemy strength.
- Boundaries are continuous/overlapping tendencies, not rigid floors.
- Local exceptions are allowed.

### Connectivity — LOCKED

- Design shorthand: about 10% Souls-style connectivity.
- This means occasional meaningful procedural loops/reconnections/spatial revelations, not copying authored shortcut mechanics.
- Nearby cave systems may connect naturally.
- A secondary topology pass may also create longer connections when they add strong loop/network value.
- Not every layer/region needs deliberate connections.

### Building — LOCKED

- Underground building is allowed wherever ordinary placement/geometry rules permit.
- Underground settlement should be difficult because of geography, access, limited space and creatures rather than a blanket build prohibition.

### Terrain modification — LOCKED

- Surface receives the greatest terrain-modification freedom.
- Underworld is only selectively modifiable so cave topology remains meaningful and the game does not become unrestricted Minecraft-style tunneling.
- Structural cave bedrock is normally permanent; rubble, deposits and designated local material may be removable.

### Boss/special areas — LOCKED

- Do not universally disable building/terraforming around bosses.
- Protect critical encounter geometry where required.
- A small number of encounters may intentionally allow major environmental preparation/modification as part of their identity.
- Players may repurpose suitable old boss locations when this does not break required state.

### Audio — LOCKED

- Creature audio has finite local 3D relevance and must not leak through arbitrary vertical distance/solid rock to reveal hidden underground content.
- Open shafts/tunnels/entrances may allow sound to travel farther when physically appropriate.

### Mining — LOCKED

- Small resource nodes emphasize fast, active, satisfying hit/feedback rhythm influenced by the strengths of Rust-style stone harvesting.
- Large deposits are excavation locations/operations influenced by the strengths of Valheim copper/silver mining.
- Large deposits are not simply small nodes with huge HP pools.
- Tree harvesting remains intentionally undecided.

### Development process — LOCKED

- Stop requiring manual playtests for every small addition.
- Architecture is designed before substantial subsystem code.
- Implementation proceeds in meaningful batches with automated/headless/simple validation.
- Human playtests are reserved for milestone-level questions of feel, pacing, readability and fun.
- Procedural systems require deterministic reproducible tests across many seeds.
- Stable procedural IDs and delta persistence are architectural requirements.

### Current known technical debt — RECORDED

- Prototype procedural surface objects/pickups have relied on accepted-array-index identities in places. This must be migrated toward stable generation-address IDs before future density/distribution tuning can invalidate persistent saves.

## 2026-08-27 — Underground graph schema checkpoint

### Pure topology data — LOCKED

- Underground graph definitions exist independently of Godot scene nodes, meshes, collision, AI and audio.
- The first implementation should use data-only `RefCounted`-style objects or an equivalent scene-independent representation.
- Generation and validation must work without entering the scene tree.

### Region/network ownership — LOCKED

- Macro generation regions, cave networks and runtime streaming cells are separate concepts.
- A cave network keeps its stable identity after a secondary connection links it to another network.
- Secondary connectivity must not merge/renumber existing networks and thereby invalidate persistent IDs.

### Continuous depth representation — LOCKED

- Nodes carry continuous shallow/mid/deep profile weights rather than relying only on one hard depth enum.
- Exact meter ranges and blend curves remain open.

### Secondary edges — LOCKED

- Accepted proximity connections and deliberate topology loops become normal stable graph-edge definitions.
- Candidate-connection scoring data is transient and is not part of the final world definition unless the connection is accepted.

### Cross-region determinism — LOCKED

- Cross-region connections have one canonical deterministic owner.
- Generation/load order must not produce duplicate or differently identified cross-region connections.

### Immutable generated definitions — LOCKED

- Generation may use mutable builders, but finalized graph definitions are treated as immutable world truth for the current seed/generator version.
- Player-caused changes are saved as deltas referencing stable IDs rather than by mutating/re-saving the generated graph.

### Future content hooks — LOCKED ARCHITECTURAL INTERFACE

- Structures, large deposits, boss lairs and other future special locations can reserve stable graph/world anchors through special-location hooks.
- The topology generator does not implement those gameplay systems itself.

### Deterministic validation representation — LOCKED

- Generated graphs require canonical sorted debug serialization/fingerprints so identical seed/version input can be compared automatically across runs, load order and thread scheduling.

## 2026-08-27 — Stable procedural ID checkpoint

### Candidate identity — LOCKED

- Persistent generated identity belongs to a deterministic candidate/address, not to accepted-array index, runtime Node, MultiMesh instance index or RNG-consumption order.
- Rejected candidates must not renumber accepted sibling identities.
- Runtime indexes may be used as transient lookup caches but are never persisted as world identity.

### World scope and stable addresses — LOCKED

- `WorldId`, semantic `StableAddress` and persisted `StableId` are separate concepts.
- Save-local stable IDs do not need to repeat the world seed; references outside one world/save are scoped by `(WorldId, StableId)`.
- Identity components use integer/categorical generation addresses rather than floating-point world position.

### Surface addressing — LOCKED DIRECTION

- Persistent surface objects use deterministic global candidate domains/cells plus fixed semantic candidate slots.
- Surface chunks remain streaming/storage boundaries rather than fundamental object identity.
- Tree/rock and loose-pickup candidate domains may use different lattices without sharing indexes.

### Underground addressing — LOCKED

- Underground identities follow deterministic region -> network candidate -> node/edge/entrance/special-location ownership/lineage.
- Network IDs are based on fixed candidate slots, not accepted network order.
- Node child identities use fixed generation candidate slots/lineage rather than compact accepted sibling indexes.
- Undirected connector endpoint order is canonicalized.
- Cross-region connectors use exactly one canonical deterministic owner.

### Stable IDs and RNG — LOCKED

- IDs do not come from mutable RNG state.
- The preferred dependency direction is stable address -> stable ID and stable address -> named-domain local RNG seed.

### Legacy prototype migration — LOCKED DIRECTION

- Save version 2 legacy IDs are `chunk_x:chunk_z:type:accepted_index` and must not be reinterpreted directly after generation changes.
- Before incompatible surface decoration/pickup tuning, implement a one-time migration adapter that regenerates referenced chunks under the frozen legacy-v2 generation contract, maps accepted indexes back to deterministic candidate addresses, and writes upgraded stable IDs.
- Unresolvable legacy IDs are reported/skipped rather than applied to a possibly wrong object.

## 2026-08-27 — Deterministic seed-domain checkpoint

### No shared generation RNG — LOCKED

- Persistent procedural generation must not use one mutable world RNG or one shared per-region RNG across unrelated systems.
- Every persistent random decision derives from world seed + seed-schema contract + named domain/revision + semantic stable address + optional semantic subkey.
- Load order, worker scheduling, accepted/rejected candidate count and unrelated RNG consumption must not alter a candidate's randomness.

### Generator version is not a universal salt — LOCKED

- Global `generator_version`/manifest records the compatible collection of generation contracts.
- It is not automatically mixed into every derived seed.
- Individual persistent generation domains have immutable domain IDs and explicit domain revisions.
- A local generator change can therefore revise one domain without automatically reshuffling unrelated domains.

### Domain semantics — LOCKED

- Domain IDs never change semantic meaning after use in persistent generation.
- Do not use insertion-sensitive implicit enum ordinals as persisted domain IDs.
- Ad-hoc magic-number salts scattered through generator files are forbidden; one authoritative seed-domain registry owns domain IDs/names/revisions.
- If two decisions should be able to evolve independently, they should not depend on the same mutable RNG sequence.

### Stable address as seed anchor — LOCKED

- Seed derivation consumes the semantic stable generation address, not runtime array index, Node identity, float-formatted world position or readable StableId string formatting.
- Rejected sibling candidates do not advance or perturb another candidate's random stream.
- Cross-region connector randomness derives from the same canonical owner/endpoint address used by its identity.

### Topology/geometry RNG separation — LOCKED

- Randomness that decides cave existence/connectivity is separated from randomness that controls detailed tunnel/chamber geometry.
- A future geometry/remeshing revision must not automatically change cave graph topology merely because its random call sequence changed.

### Local sequences and subkeys — LOCKED DIRECTION

- Stateless deterministic values/subkeys are preferred for simple independent decisions.
- A local deterministic RNG sequence is allowed inside one semantic compatibility unit such as tree shape or one tunnel geometry calculation.
- If properties later need independent compatibility, they are split into separate domains/subkeys rather than extending a shared world RNG.

### Project-owned deterministic RNG contract — LOCKED DIRECTION

- Persistent world generation will use a project-owned/frozen deterministic RNG or stateless deterministic-value contract seeded only through the central seed deriver.
- Its exact low-level algorithm is chosen during implementation, documented, and protected with hard-coded platform-independent test vectors before persistent worlds depend on it.
- Runtime-only cosmetic randomness may use ordinary engine randomness when it does not define persistent world truth.

### Engine/noise drift detection — LOCKED

- Seed isolation does not by itself guarantee noise output compatibility across engine/library changes.
- Representative persistent terrain/noise fingerprints must be part of validation so engine upgrades cannot silently reshape existing deterministic worlds without being detected.

### Current surface prototype — RECORDED

- The current prototype uses deterministic fixed noise offsets plus mutable per-chunk RNG sequences for decoration/pickups.
- The legacy algorithm remains frozen as needed for v2 save-ID migration before incompatible generation changes.
- Moving existing surface terrain/noise to the new seed-domain system is a generator-compatibility decision, not automatically a harmless refactor.

## 2026-08-27 — Generation pipeline interface checkpoint

### Pure stage contracts — LOCKED

- Deterministic world generation is decomposed into explicit pure-data stages rather than one monolithic cave generator.
- A generation stage receives immutable context + typed immutable input and returns typed deterministic data/diagnostics.
- Player state, progression, buildings, save deltas, runtime scene state and loaded assets are not inputs to deterministic world truth generation.

### Scheduler versus generator — LOCKED

- The pipeline scheduler owns dependency resolution, worker scheduling, cache lookup, prioritization/cancellation and main-thread handoff.
- Generator stages do not secretly fetch/generate neighbor regions or mutate global runtime state.
- Neighbor primary-topology/entrance views required for cross-region analysis are resolved by the scheduler and passed explicitly in canonical order.

### Stage sequence — LOCKED ARCHITECTURAL ORDER

- Macro region planning creates stable candidate budgets/biases.
- Primary topology creates local networks/nodes/primary edges.
- Entrance generation selects viable surface-to-topology connections and emits pure surface-integration descriptors.
- Secondary connectivity runs after primary topology/entrances so topology usefulness and entrance relationships can influence reconnection decisions.
- Special-location hook reservation consumes the resulting topology but does not implement bosses/resources/structures itself.
- Region finalization validates and freezes deterministic definitions.
- Base geometry-description generation consumes finalized topology later; runtime scene construction remains a separate stage.

### Depth profiles are generation input — LOCKED

- Shallow/mid/deep profile evaluation is used while topology is generated, not merely applied as a cosmetic label afterward.
- A deterministic depth-profile service returns continuous profile weights/grammar parameters from world position, region bias and deterministic surface reference data.
- Exact depth curves remain tuning data rather than scattered hard-coded conditionals.

### Entrances and surface dependency — LOCKED

- Entrances are generated from existing underground topology plus deterministic surface data, not placed randomly before cave networks exist.
- Entrance generation emits pure surface-integration descriptors so surface geometry can integrate an opening even when underground runtime geometry is not loaded.
- Generating a surface chunk may therefore require underground definition data, but never underground runtime meshes/AI/audio.

### Cross-region secondary connectivity — LOCKED

- Cross-region candidate analysis uses canonical endpoint/region ownership and deterministic stage inputs.
- The owner region stores the actual secondary edge definition; non-owner regions may retain external stable references.
- Region scheduling order cannot alter connection identity, acceptance or ownership.

### Base geometry versus deltas — LOCKED

- Base geometry descriptions represent untouched deterministic world geometry derived from finalized definitions.
- Player digging, cleared collapses, mined deposits and buildings remain persistent deltas composed later.
- Splitting one tunnel/chamber across geometry/runtime cells does not create new persistent gameplay identities merely because runtime mesh fragments differ.

### Typed stage data — LOCKED DIRECTION

- Prefer typed request/result/data-only classes for macro plans, topology, entrances, connectivity, hooks, finalization and geometry descriptions.
- Avoid one giant mutable dictionary with undocumented keys passed through every generator stage.
- Each deterministic stage must be independently fingerprintable/testable without rendering.

### Stage revisions — LOCKED DIRECTION

- Generator compatibility manifests need stage revisions in addition to seed-domain revisions because deterministic logic can change without changing random-domain IDs.

## 2026-08-27 — Streaming ownership checkpoint

### One continuous runtime world — LOCKED

- Streaming is not implemented as a hard `SURFACE` versus `UNDERGROUND` mode switch.
- Near an entrance, surface and nearby Underworld render/collision representations may be active simultaneously.
- Deep underground, surface runtime content may release because demand is gone, not because the player entered a separate world instance.

### Ownership boundaries — LOCKED

- `WorldDefinitionService` owns/accesses regenerable deterministic finalized definitions and entrance descriptors.
- `GeometryDescriptionService` owns regenerable/evictable base-geometry descriptions.
- `WorldStreamingCoordinator` computes current demand and priorities; it does not decide deterministic world truth.
- Surface and Underworld runtime streamers own live Nodes/meshes/collision for their current cells/chunks only.
- `WorldDeltaStore` owns durable player-caused world modifications independently of runtime cells/caches.

### Runtime tiers — LOCKED

- World representations progress from address/definition to geometry description, render, collision, simulation/interactables and local audio.
- These tiers may use different activation/release thresholds and hysteresis.
- Macro regions, cave networks, geometry cells and runtime streaming cells remain separate concepts.
- The Underworld runtime index is 3D-capable because multiple cave areas can overlap at the same X/Z at different Y/depths.

### Async lifetime — LOCKED

- In-flight requests carry enough request identity/token data to reject stale results.
- A stale worker result cannot resurrect an unwanted runtime cell or overwrite a newer incompatible request.
- Worker completion order can affect readiness timing but never deterministic world contents.

### Entrance overlap/prefetch — LOCKED DIRECTION

- Approaching an entrance may pin/request connected underground definitions and prefetch initial geometry/collision while surface runtime remains active.
- Surface entrance integration depends on pure deterministic entrance descriptors, never on live underground Nodes.

### Durable deltas are not cell-owned — LOCKED

- Runtime cells query/apply bounded delta views but unloading a cell cannot delete harvested/mined/cleared/built persistent state.
- Definition/geometry caches are disposable; durable deltas are not.

## 2026-08-27 — Persistence and generator-version checkpoint

### Saved versus regenerated — LOCKED

- Untouched surface terrain, cave topology, base geometry, procedural placements, entrances and other deterministic definitions are regenerated from pinned generation contracts.
- Player inventory/progression, removed generated objects, persistent object state, terrain/deformation deltas, player structures and other explicit persistent changes are saved as durable state.
- Visited deterministic cave networks are not serialized wholesale merely because they were loaded.

### Separate version concepts — LOCKED

- `save_schema_version`, `seed_schema_version`, stable-address schema/version semantics and `GeneratorManifest` remain distinct concepts.
- One integer called `version` must not silently stand for serialization layout, RNG contract and world-generator compatibility at once.

### Generator manifest — LOCKED DIRECTION

- A world pins a canonical generator manifest/configuration sufficient to reproduce deterministic truth.
- The manifest records the relevant stage revisions, seed-domain revisions, profile/config revisions and persistent algorithm/noise contracts.
- Mutable current defaults are not silently substituted for an old world's pinned generation parameters.
- Manifest identity/fingerprint is for compatibility/cache identity and is not a universal RNG salt.

### Compatibility classification — LOCKED

- World load classifies generation compatibility explicitly as `EXACT`, `SUPPORTED_LEGACY`, `MIGRATION_REQUIRED`, `INCOMPATIBLE`, or unknown/corrupt equivalent.
- Incompatible/unknown worlds are never silently interpreted using the newest generator.
- Compatible refactors must preserve deterministic vectors/fingerprints/StableIds; unexpected output drift is a failing regression, not an implicit upgrade.

### Migration safety — LOCKED

- Save/generator migration is staged and transactional; do not destroy the only valid old save before a new migrated save validates.
- Unresolved generated-object references are quarantined/reported rather than guessed by nearest object/position.
- Disposable caches are versioned sufficiently to avoid serving wrong-contract data and may simply be discarded/regenerated.

### Prototype-v2 implementation order — LOCKED

- Current `version=2` saves are treated as one explicit legacy generation contract.
- First map accepted-index IDs to modern stable candidate identities while the old surface generator remains reproducible.
- Initially preserve the corresponding legacy surface-generation result where needed.
- Moving surface generation to the new seed-domain architecture is a later explicit generator-contract decision, not hidden inside the ID migration.

## 2026-08-27 — Automated validation checkpoint

### Automated correctness before experiential testing — LOCKED

- Deterministic architecture correctness is validated headlessly/as data wherever possible.
- Human playtesting is reserved for feel, pacing, readability and fun rather than basic graph/reference/determinism corruption.

### Validation layers — LOCKED

- Persistent deterministic primitives receive frozen test vectors.
- Stable addresses/IDs receive canonicalization and uniqueness tests.
- Every deterministic generator stage is independently callable, canonically serializable and fingerprintable.
- Graph/world-definition validity is checked separately from determinism.
- Persistence/migration has fixture-based tests.
- Streaming ownership/lifetime can be tested with fake observers/services without rendering a full game world.
- Engine/noise dependencies receive representative compatibility fingerprints so upgrades cannot silently reshape persistent worlds.

### Batch campaigns — LOCKED

- Use a fixed regression seed/address corpus plus larger deterministic campaign corpora derived from an explicit campaign seed.
- Statistical design targets such as entrance/connectivity tendencies are tested as distributions rather than forcing every region into one template.
- Previously important failing campaign cases are promoted into the fixed regression corpus.

### Scheduling independence — LOCKED

- The same deterministic request set is tested under different legal generation/load/worker orders.
- Final canonical fingerprints must match even if task completion timing differs.
- Cache warm/cold/eviction variants may change performance but not semantic world truth.

### Reproducible failures — LOCKED

- Hard generation failures report enough information to reproduce the exact case: world seed, manifest/contracts, stage, region/network/candidate address, involved StableIds, fingerprints and campaign index where relevant.
- A failure should be reproducible without manually searching a rendered world.

### Expected deterministic changes — LOCKED PROCESS

- Intentional generator changes identify the affected domain/stage/profile contract, revise compatibility metadata first where needed, and update only the expected outputs belonging to that contract.
- Do not mass-update golden fingerprints merely to make a changed generator pass.

## 2026-08-27 — Architecture foundation cycle complete

The pre-implementation architecture cycle is complete at the documented semantic level.

The next development cycle is deliberately narrower: implement the tested deterministic foundation primitives — stable addresses/IDs, seed domains, generator manifests, pure graph data, canonical fingerprints/invariant validation, headless test runner and prototype-v2 migration adapter — before implementing the first real Underworld topology generator.

## 2026-08-27 — Deterministic foundation merged; primary topology cycle begins

PR #10 completed the deterministic foundation gate under Godot 4.7.2 headless
validation, including the fast contract suite and 2,250 deterministic region
probes.

The next implementation cycle is the first data-only primary Underworld topology
generator. It includes the macro-region plan and continuous depth grammar required
by the locked Stage 2 input contract, then produces region-owned primary networks,
nodes and connected primary edges with stable candidate identities.

Entrances, secondary/cross-region connectivity, special content, geometry and
runtime construction remain later stages and must not be folded into this cycle.

## Current intentionally open implementation/tuning decisions

The following remain intentionally open and must not become accidental permanent rules during implementation:

- exact surface dimensions/shape and final biome count;
- exact numerical depth boundaries/profile blend curves;
- exact tree-harvesting interaction;
- exact surface terraforming implementation/limits;
- exact future combat defense/stamina model;
- final creature/resource/boss roster;
- exact underground water/structure/ecology content;
- final logistics/transport systems;
- exact macro underground region dimensions;
- exact cave topology algorithm/candidate budgets;
- exact entrance/connectivity scoring weights/caps;
- exact cave geometry/spline/meshing algorithm;
- exact geometry/runtime streaming-cell dimensions and cache budgets;
- exact save file/sharding/compression format;
- exact terrain/deformation delta representation;
- exact performance budgets/statistical tuning thresholds.
