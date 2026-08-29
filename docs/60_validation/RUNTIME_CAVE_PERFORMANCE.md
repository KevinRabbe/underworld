# Runtime Cave Performance — PERF-001

Status: **measurement contract / prototype budgets**

PERF-001 measures the accepted MAP-016 runtime cave vertical slice before any optimization work changes cell size, voxel pitch, streaming radii, collision detail or presentation quality.

## Ownership boundary

Performance instrumentation is observational only.

- deterministic generators, geometry descriptors, StableIds, StableAddresses and mesh buffers remain world truth;
- wall-clock timings, process-local memory estimates and warning results are diagnostics;
- timing fields must never participate in deterministic fingerprints;
- performance warnings do not make deterministic content invalid;
- PERF-002 may optimize only a measured bottleneck and must preserve the accepted deterministic contracts.

`CaveMeshData` already excludes `*_ms` / `*_usec` metrics from identity. `test_runtime_performance_contract.gd` locks this invariant by changing timing observations while requiring the same mesh and CaveMeshData fingerprints.

## Repeatable primary fixture

The primary end-to-end profile is the accepted MAP-015/MAP-016 traversal fixture:

- seed `1`;
- region `(0, -1)`;
- entrance slot `2`;
- entrance StableId `sid1:sa1|2:ug|6:region|1:0|2:-1|8:entrance|4:slot|1:2`.

`tests/run_performance.gd` runs the fixture through `UnderworldRuntimeCaveProfiler.run_map015()` and prints a machine-readable `metric.*` report plus scenario snapshots.

The profiler independently builds the deterministic generation/partition/mesh/collision pipeline, then runs the production `UnderworldCaveRuntimeController.bootstrap_fixture()` path and requires both paths to produce the same deterministic bootstrap fingerprint.

## Cost separation

The report deliberately separates these costs:

| Metric family | Owner / meaning |
| --- | --- |
| `deterministic_generation_ms` | macro/topology/entrance/connectivity/hook/finalized cave geometry generation |
| `surface_partition_ms` | surface handoff plus geometry-cell partition preparation |
| `mesh_worker_total_ms` / `mesh_worker_cell_max_ms` | accepted Marching-Cubes extraction; sourced from mesh observational metrics |
| `mesh_realization_*` | `ArrayMesh` realization at the main-thread resource boundary |
| `collision_prepare_*` | conversion of deterministic mesh indices into collision-face data |
| `collision_realization_*` | `ConcavePolygonShape3D` realization at the main-thread physics-resource boundary |
| `controller_bootstrap_ms` | end-to-end production bootstrap including scene-node attachment |
| mesh vertex/triangle/sample/cube counts | geometry density / extraction work indicators |
| mesh memory estimates | deterministic mesh-buffer residency estimate, not total engine heap usage |
| streaming scenario snapshots | logical demand/residency and release pressure under observer movement |

This distinction prevents a long total load from being misattributed to Marching Cubes when the dominant cost is generation, realization, collision, or runtime attachment.

## Streaming scenarios

The profiling route contains both an actual accepted controller route and a policy-only streamer route.

Production controller route:

1. surface approach;
2. every required entrance/cave cell in the committed fixture;
3. return to the same surface entrance.

Streaming-policy route:

1. surface approach;
2. entrance transition;
3. shallow cave cell;
4. mid-depth cave cell;
5. deep cave cell;
6. negative-coordinate cell;
7. return to the surface origin.

The policy route records observer update time, demanded definition/geometry/render/collision cells, active runtime owners, retained record count, and released-cell count. Negative coordinates explicitly verify floor-based cell addressing.

### Logical release versus realized-node residency

`UnderworldRuntimeStreamer` owns demand/release state and can release unowned cell records. The current accepted cave controller, however, has attach paths for `MeshInstance3D` and collision `StaticBody3D` nodes but no corresponding scene-node reclamation path yet.

PERF-001 therefore treats these as separate observations:

- **logical streaming residency** — demanded/active streamer cells;
- **realized runtime residency** — attached render/collision nodes.

This card measures and reports that distinction. It does not implement unload/reclamation policy.

## Prototype warning budgets

Budgets live in `worldgen/runtime/runtime_performance_budget.gd`, revision `1`. They are warning thresholds, not hard correctness gates.

| Metric | Warning threshold |
| --- | ---: |
| controller bootstrap | `2000 ms` |
| deterministic generation | `500 ms` |
| surface handoff + partition | `150 ms` |
| mesh extraction total | `1200 ms` |
| mesh extraction, worst cell | `250 ms` |
| mesh realization, worst cell | `8 ms` |
| collision preparation, worst cell | `8 ms` |
| collision realization, worst cell | `8 ms` |
| streamer observer update | `4 ms` |
| total mesh-buffer estimate | `256 MiB` |
| worst cell mesh-buffer estimate | `8 MiB` |
| geometry activation envelope | `125 cells` |
| render activation envelope | `27 cells` |
| collision activation envelope | `27 cells` |

The three residency thresholds correspond to the accepted default activation radii (`2` for geometry and `1` for render/collision): `5^3 = 125`, `3^3 = 27`.

Timing budgets are deliberately conservative prototype warning lines. The measured baseline below determines whether PERF-002 is warranted and which subsystem it may touch.

## Running the profile

```bash
godot --headless --path . --quit-after 1 --script res://tests/run_performance.gd
```

The dedicated `Runtime Cave Performance Validation` workflow runs the same command and stores `runtime-cave-performance.log` as an artifact. Timing-budget warnings are printed but do not fail the workflow; structural errors, deterministic fingerprint drift and invalid profiling contracts do fail it.

## Measured baseline

The initial checked-in measurement is populated from the PERF-001 review-head CI run after the profiler itself is green. Do not copy timings from a different machine and present them as the canonical baseline.

Until that exact-head run completes, the manual observation remains only a hypothesis: cave geometry/build latency is visibly high on seed `1`, region `(0,-1)`, entrance slot `2`.

## PERF-002 decision rule

Open or activate PERF-002 only when the measured report identifies a concrete budget exceedance or residency/reclamation problem. The optimization card must name the measured metric it intends to improve and must rerun deterministic validation to prove that performance work did not change world truth.
