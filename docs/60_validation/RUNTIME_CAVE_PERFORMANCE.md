# Runtime Cave Performance — PERF-001

Status: **measurement contract / repaired baseline pending exact-head run**

PERF-001 measures the accepted MAP-016 runtime cave vertical slice before any optimization work changes cell size, voxel pitch, streaming radii, collision detail or presentation quality.

## Ownership boundary

Performance instrumentation is observational only.

- deterministic generators, geometry descriptors, StableIds, StableAddresses and mesh buffers remain world truth;
- wall-clock timings, process-local memory estimates and warning results are diagnostics;
- timing fields must never participate in deterministic fingerprints;
- performance warnings do not make deterministic content invalid;
- PERF-002 may optimize only a measured bottleneck and must preserve the accepted deterministic contracts.

`CaveMeshData` excludes `*_ms` / `*_usec` metrics from identity. `test_runtime_performance_contract.gd` locks this invariant by changing timing observations while requiring the same mesh and CaveMeshData fingerprints.

## Repeatable primary fixture

The primary end-to-end profile is the accepted MAP-015/MAP-016 traversal fixture:

- seed `1`;
- region `(0, -1)`;
- entrance slot `2`;
- entrance StableId `sid1:sa1|2:ug|6:region|1:0|2:-1|8:entrance|4:slot|1:2`.

`tests/run_performance.gd` runs the fixture through `UnderworldRuntimeCaveProfiler.run_map015()` and prints a machine-readable `metric.*` report plus scenario snapshots. The profiler independently builds the deterministic generation/partition/mesh/collision pipeline, then runs the production `UnderworldCaveRuntimeController.bootstrap_fixture()` path and requires both paths to produce the same deterministic bootstrap fingerprint.

The controller-route cave-cell centers are derived from `controller.streamer.cell_size`; PERF instrumentation does not own a duplicate cell-size constant.

## Measurement semantics

The report deliberately separates these costs:

| Metric family | Owner / meaning |
| --- | --- |
| `deterministic_generation_ms` | macro/topology/entrance/connectivity/hook/finalized cave geometry generation |
| `surface_partition_ms` | surface handoff plus geometry-cell partition preparation |
| `mesh_extraction_total_ms` / `mesh_extraction_cell_max_ms` | synchronous staged `VoxelMesher.build()` extraction cost; worker-eligible CPU/wall work, **not** production executor scheduling/queue latency |
| `mesh_realization_*` | `ArrayMesh` realization at the main-thread resource boundary |
| `collision_prepare_*` | synchronous conversion of deterministic mesh indices into collision-face data |
| `collision_realization_*` | `ConcavePolygonShape3D` realization at the main-thread physics-resource boundary |
| `staged_processing_total_ms` | staged extraction + collision-face preparation; **not** measured worker-thread/scheduler time |
| `controller_bootstrap_ms` | end-to-end synchronous production fixture bootstrap including scene-node attachment |
| mesh vertex/triangle/sample/cube counts | geometry density / extraction work indicators |
| mesh memory estimates | deterministic mesh-buffer residency estimate, not total engine heap usage |
| streaming scenario snapshots | logical demand/residency and release pressure under observer movement |

PERF-001 does **not** instrument production executor queueing, worker scheduling, contention, or worker/main-thread handoff latency. It measures the CPU/wall work of the worker-eligible stages synchronously so expensive stage ownership can be identified without inventing scheduler evidence.

## Streaming scenarios

The production controller route covers surface approach, each required entrance/cave cell, and return to the same surface entrance. Those `update_player_position()` samples measure **demand/gate update cost only**. `bootstrap_fixture()` pre-realizes the fixture; observer movement does not dynamically generate/realize newly demanded cave cells.

A policy-only streamer route covers surface approach, entrance transition, shallow/mid/deep cave positions, a negative-coordinate position, and surface return. It measures demand/release bookkeeping and logical residency, not dynamic scene loading latency.

### Logical release versus realized-node residency

`UnderworldRuntimeStreamer` owns demand/release state and can release cell runtime handles. The accepted cave controller has attach paths for `MeshInstance3D` and collision `StaticBody3D` nodes but no corresponding dynamic scene-node realization/reclamation path driven by observer movement.

PERF-001 therefore treats these as separate observations:

- **logical streaming residency** — demanded/active streamer cells;
- **realized runtime residency** — fixture-attached render/collision nodes;
- **record retention** — streamer records remain as dormant bookkeeping after logical release.

Dynamic post-bootstrap cave-cell realization and scene-node reclamation latency are currently **absent/unmeasured**. PERF-001 reports that boundary instead of calling demand-update samples load/unload latency.

## Prototype warning budgets

Budgets live in `worldgen/runtime/runtime_performance_budget.gd`, revision `3`. They are warning thresholds, not hard correctness gates.

| Metric | Warning threshold |
| --- | ---: |
| controller bootstrap | `2000 ms` |
| deterministic generation | `500 ms` |
| surface handoff + partition | `150 ms` |
| staged mesh extraction total | `1200 ms` |
| staged mesh extraction, worst cell | `250 ms` |
| mesh realization, worst cell | `8 ms` |
| collision preparation, worst cell | `8 ms` |
| collision realization, worst cell | `8 ms` |
| streamer observer demand update | `4 ms` |
| total mesh-buffer estimate | `256 MiB` |
| worst cell mesh-buffer estimate | `8 MiB` |
| logical geometry residency | `343 cells` |
| logical render residency | `125 cells` |
| logical collision residency | `125 cells` |

Streaming uses hysteresis. Residency is budgeted against the accepted **release** envelopes rather than the smaller activation cubes: geometry release radius `3` gives `7^3 = 343`; render/collision release radius `2` gives `5^3 = 125`.

## Running the profile

```bash
godot --headless --path . --quit-after 1 --script res://tests/run_performance.gd
```

The dedicated `Runtime Cave Performance Validation` workflow runs the same command and stores `runtime-cave-performance.log` as an artifact. Timing-budget warnings are printed but do not fail the workflow; structural errors, deterministic fingerprint drift and invalid profiling contracts do fail it.

## Pre-repair exploratory result

An earlier architecture-validation run on profiler head `0b57b764db5218951b420c5db8d8b9b54564bc35` confirmed the manual slow-build hypothesis, but its values are **not PERF-001 acceptance evidence** because PM review subsequently required the measurement-semantic repairs above. Do not use that run as the canonical baseline.

## Acceptance baseline

Populate this section only from the first exact repaired-head performance run after:

1. controller route centers derive from runtime `cell_size`;
2. extraction metrics are named/declared as synchronous staged extraction rather than worker scheduler latency;
3. demand-update scenarios are explicitly distinguished from dynamic load/unload latency;
4. revision-3 release-hysteresis budgets are active.

The exact run/head/fingerprint and measured budget exceedances will be recorded in the PR/issue handoff without changing world truth.

## PERF-002 decision rule

PERF-002 becomes justified only by the repaired measured CPU budget exceedances and remains dependency-blocked until PERF-001 is independently accepted. Every optimization must name the accepted PERF-001 metric it targets, provide before/after profiling, and rerun deterministic validation to prove world truth is unchanged.
