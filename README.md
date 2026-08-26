# Underworld

Procedural survival game prototype built with Godot 4.

## Prototype 0.01 — world streaming

Current goal: prove deterministic chunk generation, streaming, and basic third-person traversal before adding gameplay systems.

Implemented:
- Seeded procedural terrain using `FastNoiseLite`
- 128 m terrain chunks with 65×65 vertices by default
- World-coordinate sampling so neighboring chunks share terrain borders
- Distance-prioritized chunk generation around the player
- Load/unload hysteresis to avoid chunk-edge regeneration thrashing
- Collision only near the player
- Deterministic regeneration from world seed + world coordinates
- Third-person movement with acceleration/deceleration and camera-relative controls
- Smooth character facing, slope snapping, coyote time, and jump buffering
- Spring-arm camera collision and mouse-wheel camera distance
- Fall-respawn safeguard for prototype testing
- F3 debug HUD for FPS, chunk state, player position, speed, and chunk-generation timings
- Main-thread scene/mesh creation kept separate from terrain data generation

Current generation is intentionally simple: macro elevation noise plus smaller detail noise. Terrain quality comes after streaming correctness.

## Controls

- `WASD` — move
- `Shift` — sprint
- `Space` — jump
- Mouse — camera
- Mouse wheel — camera distance
- `Esc` — release mouse
- Click — capture mouse again
- `F3` — toggle streaming/debug HUD

The prototype registers these gameplay input actions at runtime so we can iterate without hand-editing the Input Map during this first pass.

## First playtest checklist

1. Open the project in Godot 4 and run the main scene.
2. Walk and sprint across several chunk boundaries in multiple directions.
3. Cross into negative world coordinates as well as positive coordinates.
4. Look for visible mesh/lighting seams or collision gaps at chunk borders.
5. Watch `Chunk gen` and `Max` in the F3 overlay for frame-spike clues.
6. Hover around a chunk boundary and confirm loaded chunks do not constantly regenerate.
7. Walk away and return to an area; the terrain should regenerate identically.
8. Check slopes, jumping, camera collision, and camera zoom for obvious controller problems.

## Next technical targets

1. Run and profile chunk generation in Godot.
2. Move terrain-data generation to worker threads if measured generation time causes frame spikes.
3. Fix any controller, seam, or collision issues discovered in the first local run.
4. Begin macro terrain shaping only after the streaming foundation is stable.
5. Add vegetation/ground-cover generation after the terrain itself is interesting to traverse.
