# Runtime Cave Performance — PERF-001

Status: **measured prototype baseline / warning budgets**

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

## Cost separation

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

## Streaming scenarios

The production controller route covers surface approach, each required entrance/cave cell, and return to the same surface entrance. A policy-only streamer route covers surface approach, entrance transition, shallow/mid/deep cave positions, a negative-coordinate position, and surface return.

### Logical release versus realized-node residency

`UnderworldRuntimeStreamer` owns demand/release state and can release cell runtime handles. The accepted cave controller has attach paths for `MeshInstance3D` and collision `StaticBody3D` nodes but no corresponding scene-node reclamation path yet.

PERF-001 therefore treats these as separate observations:

- **logical streaming residency** — demanded/active streamer cells;
- **realized runtime residency** — attached render/collision nodes;
- **record retention** — streamer records remain as dormant bookkeeping after logical release.

This card measures those distinctions. It does not implement unload/reclamation policy.

## Prototype warning budgets

Budgets live in `worldgen/runtime/runtime_performance_budget.gd`, revision `2`. They are warning thresholds, not hard correctness gates.

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
| logical geometry residency | `343 cells` |
| logical render residency | `125 cells` |
| logical collision residency | `125 cells` |

Streaming uses hysteresis. Residency is therefore budgeted against the accepted **release** envelopes rather than the smaller activation cubes: geometry release radius `3` gives `7^3 = 343`; render/collision release radius `2` gives `5^3 = 125`.

## Running the profile

```bash
godot --headless --path . --quit-after 1 --script res://tests/run_performance.gd
```

The dedicated `Runtime Cave Performance Validation` workflow runs the same command and stores `runtime-cave-performance.log` as an artifact. Timing-budget warnings are printed but do not fail the workflow; structural errors, deterministic fingerprint drift and invalid profiling contracts do fail it.

## Measured baseline

Measurement source:

- profiler implementation head: `0b57b764db5218951b420c5db8d8b9b54564bc35`;
- dedicated workflow run: `33255875862`;
- job: `99109361555`;
- Godot: `4.7.2`;
- hosted runner: Ubuntu 24.04;
- result: `[PERF-001] PASS`;
- deterministic fingerprint: `entrances-sha256:8c11c563b2192f85a78d1760b4d8cb2a686d00e3662a8a9c7db2524d2094b5bc:geometry-sha256:d910dbc179903d8f26c92974f29641aad553c7bba56eb833ebcff6a583aef73a:gpartition-result1:sha256:2747883649716b5c0d3e6906f86308cbae7faa68e19cc4fc7801ff4e9a1183be`.

The measurement was taken before the subsequent revision-2 **budget-only** correction from activation envelopes to release-hysteresis envelopes. That correction changes warning classification only; it does not change the profiler, runtime path, measured values, or deterministic fingerprint. A final current-head run is still required for REVIEW.

### Timing and work metrics

| Metric | Measured |
| --- | ---: |
| deterministic generation | `286.220 ms` |
| surface handoff + partition | `27.947 ms` |
| Marching-Cubes extraction total | `17165.667 ms` |
| Marching-Cubes worst cell | `4971.129 ms` |
| collision-face preparation total | `4596.272 ms` |
| collision-face preparation worst cell | `2337.389 ms` |
| mesh realization total | `9.575 ms` |
| mesh realization worst cell | `3.330 ms` |
| collision realization total | `12.396 ms` |
| collision realization worst cell | `5.092 ms` |
| staged worker total (mesh + collision preparation) | `21761.939 ms` |
| main-thread resource realization total | `21.971 ms` |
| production controller bootstrap | `26541.944 ms` |
| streamer observer update worst sample | `10.865 ms` |
| controller-route observer update worst sample | `9.936 ms` |

### Geometry / memory metrics

Eight fixture cells produced:

- vertices: `11,379`;
- triangles: `21,449`;
- lattice samples: `2,163,864`;
- cubes evaluated: `270,483`;
- estimated mesh-buffer memory total: `621,516 bytes` (~`0.59 MiB`);
- worst cell mesh-buffer estimate: `218,092 bytes` (~`0.21 MiB`).

Mesh-buffer memory is therefore not the current bottleneck.

### Streaming observations

- logical residency peak: geometry `186`, render `46`, collision `46` — all inside revision-2 release-envelope budgets;
- peak active streamer owners: `470` in the policy route;
- peak retained streamer records: `928`;
- explicit logical releases during the route: `776`;
- stale-result count: `0`;
- at surface return the policy route still held `431` active owners and `928` records because release hysteresis and dormant-record bookkeeping are distinct from record deletion;
- production controller route kept exactly `8` realized render nodes and `8` realized collision nodes throughout traversal/return; no scene-node reclamation path exists yet;
- negative-coordinate addressing reproduced `(-2, -3, -2)` correctly.

## Bottleneck conclusion

The manual “cave build is slow” observation is confirmed, but the cost is now separated precisely:

1. **Primary bottleneck — Marching-Cubes extraction:** `17.17 s` across eight cells, worst cell `4.97 s`. This exceeds both mesh CPU warning budgets by more than an order of magnitude.
2. **Secondary bottleneck — collision-face preparation:** `4.60 s` total, worst cell `2.34 s`. `ConcavePolygonShape3D` realization itself is only `12.4 ms` total, so the expensive portion is the GDScript face-array preparation, not physics-resource creation.
3. **End-to-end symptom — controller bootstrap:** `26.54 s`, consistent with the two worker-side costs dominating the load.
4. **Tertiary runtime cost — observer streaming update:** about `10–11 ms` at the sampled peaks, above the `4 ms` warning line. This is meaningful but much smaller than initial cave construction.
5. **Not current bottlenecks:** deterministic world generation (`286 ms`), partitioning (`28 ms`), main-thread mesh/collision realization (`22 ms` total), and mesh-buffer memory (~`0.59 MiB`).

The profile therefore does **not** justify broad LOD/cell-size/radius changes yet. PERF-002 should first target the measured extraction and collision-preparation CPU paths while preserving MAP-016 seam/fingerprint/collision contracts. Streaming record/node reclamation should remain a separately measured follow-up unless memory/residency evidence shows it is material.

## PERF-002 decision rule

PERF-002 is justified by the measured CPU budget exceedances above, but remains dependency-blocked until PERF-001 is independently accepted. Every optimization must name the measured metric it targets, provide before/after profiling, and rerun deterministic validation to prove world truth is unchanged.
