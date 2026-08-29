# Runtime Cave Performance — PERF-001

Status: **measurement contract / repaired acceptance baseline recorded**

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

## Repaired acceptance baseline

The first repaired-head profile was executed by `Runtime Cave Performance Validation` run `33256370650`, job `99110717903`, against PERF source head `01aa6cea76d1b3b765c5fe59f3db2b9b7331c91e` merged for the PR check with then-current main `73a1631f71cdef6cde0725ff498250818d4cc18d`.

Result: **PASS**. The independently staged pipeline and production controller bootstrap agreed on this deterministic fingerprint:

`entrances-sha256:8c11c563b2192f85a78d1760b4d8cb2a686d00e3662a8a9c7db2524d2094b5bc:geometry-sha256:d910dbc179903d8f26c92974f29641aad553c7bba56eb833ebcff6a583aef73a:gpartition-result1:sha256:2747883649716b5c0d3e6906f86308cbae7faa68e19cc4fc7801ff4e9a1183be`

Measured values:

| Metric | Repaired baseline |
| --- | ---: |
| deterministic generation | `296.818 ms` |
| surface handoff + partition | `28.399 ms` |
| staged mesh extraction total | `17234.002 ms` |
| staged mesh extraction, worst cell | `4925.100 ms` |
| collision-face preparation total | `5888.449 ms` |
| collision-face preparation, worst cell | `3064.946 ms` |
| mesh realization total | `9.735 ms` |
| mesh realization, worst cell | `3.298 ms` |
| collision realization total | `12.277 ms` |
| collision realization, worst cell | `4.814 ms` |
| main-thread resource realization total | `22.012 ms` |
| staged extraction + collision preparation | `23122.451 ms` |
| production controller bootstrap | `27237.739 ms` |
| policy-route observer demand update, worst sample | `12.078 ms` |
| controller demand-route update, worst sample | `10.821 ms` |
| mesh-buffer estimate, 8 cells | `621516 bytes` |
| worst-cell mesh-buffer estimate | `218092 bytes` |
| vertices / triangles | `11379 / 21449` |
| scalar samples / cubes | `2163864 / 270483` |
| logical peak geometry/render/collision residency | `186 / 46 / 46` cells |
| stale results | `0` |

Budget exceedances from that repaired run:

- `mesh_extraction_total_ms`: `17234.002 ms` > `1200 ms`;
- `mesh_extraction_cell_max_ms`: `4925.100 ms` > `250 ms`;
- `collision_prepare_cell_max_ms`: `3064.946 ms` > `8 ms`;
- `controller_bootstrap_ms`: `27237.739 ms` > `2000 ms`;
- `observer_update_max_ms`: `12.078 ms` > `4 ms`.

The accepted release-hysteresis residency envelopes were **not** exceeded: measured geometry/render/collision peaks were `186/46/46` against `343/125/125`. Deterministic generation, partitioning, mesh/collision resource realization and mesh-buffer memory were also within their prototype warning budgets.

### Bottleneck conclusion

1. **Primary:** synchronous Marching-Cubes extraction CPU/wall work.
2. **Secondary:** synchronous GDScript collision-face preparation.
3. **Tertiary:** streamer observer demand/release bookkeeping.

This baseline does **not** establish production worker scheduling latency, executor contention, dynamic post-bootstrap cave-cell realization latency, or scene-node reclamation cost. Those remain unmeasured boundaries.

## PERF-002 decision rule

PERF-002 is justified by the repaired measured CPU budget exceedances but remains dependency-blocked until PERF-001 is independently accepted. Every optimization must name the accepted PERF-001 metric it targets, provide before/after profiling on the same fixture, and rerun deterministic validation to prove world truth is unchanged.
