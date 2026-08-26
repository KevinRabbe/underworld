# Underworld

Procedural survival game prototype built with Godot 4.

## Prototype 0.01 — world streaming

Current goal: prove deterministic chunk generation and streaming before adding gameplay systems.

Implemented:
- Seeded procedural terrain using `FastNoiseLite`
- 128 m terrain chunks with 65×65 vertices by default
- World-coordinate sampling so neighboring chunks share terrain borders
- Chunk loading/unloading around the player
- Collision only near the player
- Deterministic regeneration from world seed + world coordinates
- Basic third-person capsule controller
- Main-thread scene/mesh creation kept separate from terrain data generation

Current generation is intentionally simple: macro elevation noise plus smaller detail noise. Terrain quality comes after streaming correctness.

## Controls

- `WASD` — move
- `Shift` — sprint
- `Space` — jump
- Mouse — camera
- `Esc` — release mouse
- Click — capture mouse again

## Next technical targets

1. Run and profile chunk generation in Godot.
2. Move terrain-data generation to a worker thread if per-chunk generation causes frame spikes.
3. Add debug visualization for chunk coordinates/load state.
4. Verify seamless regeneration across positive and negative world coordinates.
5. Begin macro terrain shaping only after the streaming foundation is stable.
