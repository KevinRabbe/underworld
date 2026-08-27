# Underworld — Mining and Resource Rules

## 1. Two mining experiences — LOCKED

Small resource nodes and large deposits are intentionally different gameplay systems.

### Small nodes = harvesting objects

Design goal: fast, rhythmic, satisfying interaction inspired by the strengths of Rust-style stone harvesting without directly copying its exact marker mechanic.

Expected qualities:

- short interaction time;
- strong impact/audio/debris feedback;
- active aiming or fracture/weak-point participation;
- correct hits feel better and/or improve efficiency;
- misses still make progress so the system does not become an aim-training chore;
- quick break and move-on rhythm.

Exact weak-point visualization and tree-harvesting model remain **OPEN**.

### Large deposits = locations/mining operations

Design goal: excavation and discovery inspired by the strengths of Valheim-style copper/silver mining.

Expected qualities:

- deposit consists of multiple connected sections or a larger embedded body;
- only part of the deposit may initially be exposed;
- mining reveals that the resource continues through surrounding material;
- the player works around/through the deposit rather than draining one giant HP pool;
- large deposits can influence routes, storage, temporary outposts and logistics;
- the total size/shape should not always be obvious from first contact.

Rule of thumb:

> Small nodes are harvesting objects. Large deposits are locations.

## 2. Deposit archetypes — DIRECTIONAL

The architecture should support multiple large-deposit forms rather than one scaled-up rock:

- compact/boulder body;
- buried body;
- vein;
- seam/layer;
- connected cluster;
- rare giant deposit.

Exact ores and biome/depth distribution remain **OPEN**.

## 3. Material-specific interaction — DIRECTIONAL

Different resources may eventually modify the mining interaction itself rather than only changing HP/yield.

Possible dimensions include:

- fracture size;
- precision requirement;
- brittleness;
- tool impact requirement;
- risk of losing yield through poor extraction;
- exposed weak-area behavior.

Do not commit to specific material gimmicks until the base mining interaction exists and is proven.

## 4. Tool progression — DIRECTIONAL

Mining-tool upgrades should ideally change feel as well as speed.

Examples of useful progression dimensions:

- larger fractures;
- stronger impact;
- different swing commitment;
- faster section removal;
- access to harder resource-bearing material.

Avoid relying exclusively on percentage damage increases.

## 5. World relationship — LOCKED

Large deposits must respect the world-modification rules in `WORLD_ARCHITECTURE.md`.

On the surface, excavation can be relatively permissive.

In the Underworld, deposits may be excavated from designated material volumes, but mining must not allow arbitrary tunneling through structural cave bedrock. Large-deposit gameplay cannot undermine cave topology.

## 6. Trees — OPEN

Tree harvesting is intentionally undecided.

Potential reference strengths include physics/falling-tree interaction and active-hit harvesting, but no permanent tree model should be locked until a later development cycle requires it.
