# Underworld

Procedural survival game prototype built with Godot 4.

## Prototype 0.02 — generated first biome

Current goal: turn the proven v0.01 chunk-streaming foundation into a world that already has recognizable large-scale geography and deterministic environmental structure.

Implemented:
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

## Controls

- `WASD` — move
- `Shift` — sprint
- `Space` — jump
- Mouse — camera
- Mouse wheel — camera distance
- `Esc` — release mouse
- Click — capture mouse again
- `F3` — toggle world/debug HUD

## v0.02 playtest checklist

1. Confirm spawn is dry and reasonably walkable.
2. Traverse several chunks and look for broad lowlands, hills, ridges, valleys, and shoreline changes.
3. Check that high `Rock` values no longer paint huge smooth areas completely gray.
4. Compare the F3 `Forest` value with visible tree density and look for recognizable clearings/forest patches.
5. Compare `Rock` with physical rock placements and exposed stone on steeper terrain.
6. Cross chunk boundaries and negative coordinates looking for terrain or decoration seams.
7. Record `Data (worker)` and `Build (main)` timings after the direct-mask optimization.
8. Walk away and return; terrain and placeholder decorations should regenerate identically.

## Next targets after this pass

1. Tune macro terrain and environmental thresholds from screenshots/playtests.
2. Replace placeholder distribution rules only if forests or rock fields look artificial.
3. Add simple grass/ground cover after large vegetation placement is convincing.
4. Begin cave-entrance candidate generation once the surface biome itself is interesting to traverse.
5. Add actual gathering/combat interactions only after the generated environment is stable enough to play in.
