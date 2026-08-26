# Underworld

Procedural survival game prototype built with Godot 4.

## Prototype 0.02 — first generated biome

Current goal: turn the proven chunk-streaming foundation into a world that already has readable geography and reusable environmental rules.

### Streaming foundation from 0.01

- Seeded deterministic terrain
- 128 m terrain chunks with 65×65 vertices by default
- Seamless world-coordinate sampling across chunk borders
- Distance-prioritized chunk loading with unload hysteresis
- Height-map terrain collision near the player
- Worker-thread terrain-data generation
- Main-thread-only mesh, physics, and scene-tree creation
- Third-person traversal with sprint, jump, slopes, camera collision, and zoom
- F3 profiling/debug overlay

### Added in 0.02

- Broad continental elevation instead of uniform rolling noise
- Separate rolling-hill layer
- Large deterministic flatland patches intended for future settlement placement
- Region-gated ridges rather than ridges everywhere
- Long valley/depression bands that can cut below sea level
- Smaller surface-detail layer
- Prototype sea surface at a configurable sea level
- Procedural spawn search that avoids water and strongly prefers buildable ground
- Per-vertex moisture mask
- Per-vertex forest-potential mask
- Per-vertex rockiness mask
- Per-vertex buildability mask
- Terrain vertex coloring driven by moisture, rockiness, and shoreline height
- F3 readout for the environmental masks under the player

The masks are generated data, not just visuals. Future trees, exposed rocks, creature territories, resources, and cave-surface clues should consume these same deterministic values rather than scatter independently.

## Controls

- `WASD` — move
- `Shift` — sprint
- `Space` — jump
- Mouse — camera
- Mouse wheel — camera distance
- `Esc` — release mouse
- Click — capture mouse again
- `F3` — toggle world/debug HUD

## 0.02 playtest checklist

1. Run the main scene and confirm the procedural spawn is on dry, walkable ground.
2. Look for terrain that reads at multiple scales: broad lowlands, rolling areas, ridges, and valleys.
3. Check whether there are useful flatter areas rather than constant rolling terrain.
4. Find water and verify shorelines come from terrain crossing the fixed sea level rather than a separate handcrafted basin.
5. Walk across multiple chunks and confirm macro features continue seamlessly across chunk boundaries.
6. Cross into negative world coordinates and verify generation remains stable.
7. Watch the F3 `Moist`, `Forest`, `Rock`, and `Build` values while moving between visibly different terrain.
8. Check that collision still matches the reshaped visual terrain.
9. Watch worker timings; the richer generator may cost more CPU per chunk, but it should remain off the main thread.
10. Note seeds/locations where the landforms look especially good or obviously artificial so we can tune the shaping rules rather than hand-edit maps.

## Next targets after 0.02 terrain is approved

1. Tune macro landform frequencies and amplitudes from actual playtest screenshots.
2. Generate trees and rocks from the existing forest/rock masks.
3. Introduce clearings and denser woodland as micro-regions within the same first biome.
4. Add the first simple surface creature only after the environment is interesting to traverse.
5. Begin cave-entrance placement from terrain/slope/rock rules, keeping the underground hook connected to the generated surface.
