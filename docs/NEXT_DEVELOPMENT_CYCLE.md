# Underworld — Next Development Cycle

## Completed gates

- PR #10: deterministic foundation, migration, headless validation and batch CI.
- PR #11: deterministic macro planning, continuous depth grammar and connected
  primary topology.

---

# Current cycle: v0.10 deterministic entrance generation

## Goal

Generate deterministic, data-only connections from the sampled surface world to
existing primary cave topology. This stage runs after primary topology and before
secondary connectivity. It does not create meshes or runtime Nodes.

## Required deliverables

### 1. Deterministic surface sampling boundary

- expose height, normal, slope and viability signals from world seed and world XZ;
- reuse the surface terrain generation contract without loaded chunks or scene Nodes;
- measure depth against the sampled local surface, never an arbitrary global Y plane.

### 2. Stable entrance selection

- create fixed entrance candidate slots before acceptance;
- score topology usefulness, surface viability and surface-relative depth;
- treat roughly 1–3 entrances as a distribution tendency, allowing valid zero cases;
- preserve stable entrance identity independently of accepted-array order;
- select deterministic gradual, steep and crevice descent profiles.

### 3. Pure entrance graph data

- produce `EntranceDefinition` objects;
- add entrance-anchor nodes and `entrance_path` graph edges without changing the
  primary tree-edge set;
- produce `SurfaceEntranceIntegrationDescriptor` objects containing surface
  position, orientation, required opening bounds, clearance, topology target,
  underground anchor and descent profile;
- keep the primary topology input unchanged.

### 4. Validation and reproduction

- prove every accepted entrance owns one traversable route to its declared target;
- validate descriptor bounds, orientation, clearance and ownership;
- cover deterministic replay, negative coordinates and statistical count/profile rules;
- expose exact seed/region entrance fingerprints;
- run the full entrance pipeline over 250 seeds × 9 regions in CI.

## Explicitly out of scope

- secondary loops and cross-region connections;
- cave or surface meshes, collision and runtime streaming cells;
- carving visible surface openings;
- special-location content, enemies, resources, bosses or ecology;
- final entrance scoring weights, candidate budgets or geometry tuning.

## Exit criteria

This cycle is complete when:

1. surface samples are deterministic and require no loaded terrain chunks or Nodes;
2. depth profiles use the sampled surface height at each world XZ;
3. all fixed entrance slots remain represented before acceptance;
4. repeated requests produce identical entrance fingerprints;
5. every accepted entrance has a valid descriptor and connected entrance-path edge;
6. count expectations are validated statistically rather than as a universal law;
7. negative-coordinate fixtures pass;
8. the Godot 4.7.2 fast and 2,250-case batch CI gate is green.

Only after this gate should secondary and cross-region connectivity begin.
