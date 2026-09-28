# Underworld

Procedural survival game built with Godot 4.

<!-- PROJECT_STATUS_PLAYABLE_STATE: NOT_YET -->
<!-- PROJECT_STATUS_ACCEPTED_MAIN: 1c258ab681023d296425a574f769a4f73841ebf9 -->
<!-- PROJECT_STATUS_WORLD_MODEL: OVERWORLD+UNDERWORLD_CONTINUOUS_BIOMES -->

## Project status

**Playable now? NOT YET — there is no accepted Core Playable build yet.**

The project is currently in **Core Playable integration / two-domain topology rebaseline**. The current product world model is:

```text
OVERWORLD
UNDERWORLD — one continuous generated world/root with multiple biomes/regions
```

The Underworld is not three independent layers/maps. Moving between Underworld biomes is ordinary movement and streaming inside the same world; only Overworld ↔ Underworld travel is a domain transition.

Current scale direction is approximately **40% Overworld / 60% Underworld** by intended exploration allocation. This is not a radius/diameter rule; exact dimensions and budgets remain measured design work.

Current hard gate at the last synchronization is **#539**, the protected independent gateway-definition review. The checked-in status is a snapshot, not a replacement for live GitHub governance.

**Full current-state snapshot:** [`docs/00_project/PROJECT_STATUS.md`](docs/00_project/PROJECT_STATUS.md)  
Machine-readable companion: [`docs/00_project/project_status.json`](docs/00_project/project_status.json)

## Existing runnable prototype surface

The repository also retains the earlier **Prototype 0.02 — generated first biome** playtest surface. That checklist is useful for testing its terrain/streaming behavior, but completing it does **not** mean the current Core Playable milestone has been achieved.

Prototype 0.02 implemented:
- Seeded procedural terrain using `FastNoiseLite`
- 128 m terrain chunks with 65×65 vertices by default
- Worker-thread terrain data generation with main-thread mesh/physics creation
- Height-map terrain collision near the player
- Broad continental elevation
- Rolling terrain separated from macro elevation
- Settlement-friendly flatland patches
- Region-gated ridges and long valley/depression bands
- Configurable sea level plus a prototype water plane
- Procedural spawn search preferring dry/buildable terrain
- Deterministic moisture, forest-potential, rockiness, and buildability masks
- Terrain coloring using moisture, shoreline, and actual slope exposure
- Deterministic prototype tree and rock placement from those masks
- Trees and rocks rendered with per-chunk `MultiMesh` batches
- Third-person movement, sprinting, jumping, slope snapping, camera collision, and zoom
- F3 debug HUD for streaming, surface masks, decoration counts, and chunk-generation timings

The tree cones and box rocks are intentionally placeholder geometry. Their job is to expose whether forest/clearing/rock-field distribution feels natural before real assets or gameplay interactions are added.

## Prototype controls

- `WASD` — move
- `Shift` — sprint
- `Space` — jump
- Mouse — camera
- Mouse wheel — camera distance
- `Esc` — release mouse
- Click — capture mouse again
- `F3` — toggle world/debug HUD

## Prototype 0.02 playtest checklist

1. Confirm spawn is dry and reasonably walkable.
2. Traverse several chunks and look for broad lowlands, hills, ridges, valleys, and shoreline changes.
3. Check that high `Rock` values no longer paint huge smooth areas completely gray.
4. Compare the F3 `Forest` value with visible tree density and look for recognizable clearings/forest patches.
5. Compare `Rock` with physical rock placements and exposed stone on steeper terrain.
6. Cross chunk boundaries and negative coordinates looking for terrain or decoration seams.
7. Record `Data (worker)` and `Build (main)` timings after the direct-mask optimization.
8. Walk away and return; terrain and placeholder decorations should regenerate identically.

For current delivery priorities, blockers and milestone ownership, use the project status snapshot above rather than treating this historical prototype checklist as the active roadmap.
