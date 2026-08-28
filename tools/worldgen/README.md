# Worldgen Topology Inspector

This directory contains development-only inspection tools for deterministic world generation.

The inspector is deliberately downstream of production worldgen code. Files under `worldgen/` do not import this tooling, and generating a snapshot or atlas does not mutate the generated world definition.

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

## Export a multi-region atlas

For broader map review, export a deterministic square atlas around one region:

```bash
godot --headless --path . \
  --script res://tools/worldgen/export_topology_atlas.gd -- \
  --seed=12345 --center-x=0 --center-z=0 --radius=1 \
  --out-dir=user://worldgen_snapshots
```

`radius=1` produces a 3×3 atlas. `radius=0` produces one region and the current safety cap is `radius=4`, which produces a 9×9 atlas.

One atlas command emits four artifacts from the exact same deterministic region data:

- `.json` — canonical multi-region topology data;
- `.svg` — top-down X/Z atlas;
- `.elevation_x.svg` — X versus world-Y depth view;
- `.elevation_z.svg` — Z versus world-Y depth view.

The atlas JSON contains:

- canonical row-major region snapshots;
- every region's topology fingerprint;
- aggregate region/network/node/edge/boundary-candidate counts;
- the seed, center coordinate, radius and grid dimensions.

### Top-down atlas

The top-down SVG preserves the same node depth-profile colors and vertical-transition dashes as the single-region view. Each region is drawn in its own fixed cell and boundary candidates receive cyan directional ticks. This makes it easier to inspect broad cave distribution and potential cross-region relationships without changing or querying production generators differently.

### Elevation atlases

The two elevation SVGs preserve the same region-cell layout as the top-down atlas while changing the projection inside each cell:

- `elevation_x` plots world X horizontally and world Y vertically;
- `elevation_z` plots world Z horizontally and world Y vertically.

This makes vertical topology visible without collapsing neighboring regions into one ambiguous side projection. Nodes retain their shallow/mid/deep dominant-profile colors, vertical-transition edges remain dashed and slightly heavier, and hover metadata includes full XYZ world coordinates.

Each cell also shows three faint geometric depth bands. These bands divide the region's vertical bounds into equal thirds for visual orientation only; they do not redefine the production shallow/mid/deep grammar or consume any generation data.

Optional atlas arguments:

```text
--basename=my_atlas
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

The single-region SVG projects world X/Z into the region square while preserving node Y in hover/debug metadata. Network membership is separated visually, vertical-transition edges are dashed, and node fill indicates the dominant depth profile.

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

Run the single-region contracts:

```bash
godot --headless --path . --quit-after 1 \
  --script res://tools/worldgen/run_topology_inspector_contracts.gd
```

Run the multi-region atlas contracts:

```bash
godot --headless --path . --quit-after 1 \
  --script res://tools/worldgen/run_topology_atlas_contracts.gd
```

The contracts check deterministic JSON/SVG output, topology metric coverage, canonical ordering, edge/node references, region bounds, normalized profile weights, atlas aggregate counts, radius limits, negative seed/region coordinates, deterministic X/depth and Z/depth rendering, complete node coverage and valid elevation axes.

A dedicated `Worldgen Inspector Validation` workflow exports a real single-region snapshot plus a 3×3 top-down/X-depth/Z-depth atlas on GitHub Actions.

## Future extension

After entrance, secondary-connectivity and finalized-geometry stages are merged into `main`, the inspector can add additional optional views. Those extensions should continue to consume public pure-data stage results rather than reaching into generator internals or changing production behavior.
