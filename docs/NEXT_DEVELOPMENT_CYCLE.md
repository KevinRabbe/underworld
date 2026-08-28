# Underworld — Next Development Cycle

## Completed gates

- PR #10: deterministic foundation, migration, headless validation and batch CI.
- PR #11: deterministic macro planning, continuous depth grammar and connected
  primary topology.
- PR #12 / v0.10 branch: deterministic surface sampling, surface-relative depth,
  entrance selection, entrance-path graph data and surface-integration descriptors.

---

# Current cycle: v0.11 secondary connectivity

## Goal

Add a selective deterministic post-topology connection pass after entrances exist.
The pass may create useful local loops, join separate networks, and reconcile rare
cross-region connectors without modifying the primary tree or turning the
Underworld into spaghetti.

This cycle remains pure data. It creates graph edges and external references, not
cave meshes, collision or runtime Nodes.

## Required deliverables

### 1. Local secondary candidate analysis

- enumerate stable node-pair candidates independently of iteration order;
- reject already-connected endpoint pairs and trivial same-network shortcuts;
- score physical distance, topology improvement, entrance usefulness, vertical
  variation and continuous shallow/mid/deep profile tendency;
- use the existing `ug.secondary.exists` and `ug.secondary.shape` seed domains;
- preserve primary topology and entrance-path edges unchanged.

### 2. Bounded useful loops and network joins

- allow `secondary_loop` edges inside a network when they materially shorten a
  branch relationship;
- allow `cross_network_connection` edges between separate regional networks;
- keep shallow connectivity sparse, emphasize mid-depth opportunities, and allow
  deep regions to vary between isolation and stronger interconnection;
- cap accepted local connectors and secondary degree per node so candidate density
  cannot create spaghetti.

### 3. Canonical cross-region reconciliation

- consume explicitly supplied neighboring primary-topology views;
- only analyze cardinally adjacent macro regions;
- use the precomputed boundary-candidate metadata from primary topology;
- derive one canonical connector address and owner from the region pair and endpoint
  pair;
- allow at most one accepted connector per adjacent region pair in this cycle;
- owner region stores the `cross_region_connection` edge;
- non-owner region emits an external edge reference with the same StableId.

### 4. Validation and reproduction

- deterministic replay must be independent of supplied neighbor ordering;
- secondary connectors may not duplicate existing endpoint pairs;
- local secondary degree stays bounded;
- cross-region owner/non-owner results must agree on connector identity;
- negative coordinates must remain valid;
- expose exact connectivity fingerprints and a connectivity reproduction CLI mode;
- promote the 250 seeds × 9 regions CI batch to the full connectivity pipeline.

## Explicitly out of scope

- chamber/tunnel volume descriptions;
- cave meshes, carving, collision and runtime streaming cells;
- special-location hooks, resources, enemies, bosses or ecology;
- final geometry style for accepted connectors;
- player progression or save deltas;
- final connectivity probabilities or geometry dimensions.

## Exit criteria

This cycle is complete when:

1. repeated region requests produce identical connectivity fingerprints;
2. reversed neighbor input order produces the same result;
3. primary and entrance stage inputs remain unchanged;
4. no accepted local node exceeds the secondary-degree cap;
5. cross-region connectors have exactly one canonical owner and one matching
   non-owner reference;
6. local accepted connectivity remains bounded across the seed campaign;
7. negative-coordinate fixtures pass;
8. Godot 4.7.2 fast contracts and the 2,250-case connectivity batch are green.

Only after this gate should base cave geometry-description generation begin.
