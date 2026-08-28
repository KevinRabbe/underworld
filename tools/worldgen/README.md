# Worldgen Topology Inspector

This directory contains development-only inspection tools for deterministic world generation.

The inspector is deliberately downstream of production worldgen code. Files under `worldgen/` do not import this tooling, and generating a snapshot does not mutate the generated world definition.

## Export a topology snapshot

From the repository root with Godot 4.7.2 available:

```bash
godot --headless --path . \
  --script res://tools/worldgen/export_topology_snapshot.gd -- \
  --seed=12345 --region-x=0 --region-z=0 \
  --out-dir=user://worldgen_snapshots
```

The command writes two files with the same base name:

- `.json` — machine-readable deterministic topology snapshot;
- `.svg` — lightweight top-down visualization for human inspection.

Optional arguments:

```text
--basename=my_snapshot
--out-dir=/absolute/or/godot/path
--help
```

## Snapshot contents

The v1 snapshot exports the currently merged primary-topology contract:

- world seed and region coordinate;
- macro and topology fingerprints;
- region world bounds and profile bias;
- accepted cave networks;
- cave nodes with XYZ positions, approximate sizes, semantic types and shallow/mid/deep profile weights;
- primary and vertical-transition edges;
- boundary candidates used by later cross-region analysis;
- topology metrics.

The SVG projects world X/Z into the region square while preserving node Y in hover/debug metadata. Network membership is separated visually, vertical-transition edges are dashed, and node fill indicates the dominant depth profile.

## Why this is a tool, not a generator stage

The inspector must remain observational. It must not:

- decide which caves exist;
- consume new randomness;
- change StableIds;
- mutate topology;
- become a dependency of production worldgen;
- create runtime meshes, collision or scene-tree Nodes.

This keeps map visualization safe to iterate independently from generation work.

## Validation

Run:

```bash
godot --headless --path . --quit-after 1 \
  --script res://tools/worldgen/run_topology_inspector_contracts.gd
```

The contracts check deterministic JSON/SVG output, topology metric coverage, canonical ordering, edge/node references, region bounds, normalized profile weights and negative seed/region coordinates.

A dedicated `Worldgen Inspector Validation` workflow also exports a real sample JSON/SVG pair on GitHub Actions.

## Future extension

After entrance, secondary-connectivity and finalized-geometry stages are merged into `main`, the inspector can add additional optional views. Those extensions should continue to consume public pure-data stage results rather than reaching into generator internals or changing production behavior.
