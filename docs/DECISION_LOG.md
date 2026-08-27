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

## Open decisions at this checkpoint

The following remain intentionally open and must not become permanent accidentally:

- exact surface dimensions/shape and final biome count;
- exact numerical depth boundaries;
- exact tree-harvesting interaction;
- exact surface terraforming limits/implementation;
- exact future block/parry/dodge/stamina combat model;
- final creature/resource/boss roster;
- exact underground water/structure/ecology content;
- final logistics/transport systems.
