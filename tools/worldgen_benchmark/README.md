# Deterministic Worldgen Benchmark

Development-only benchmark harness for the accepted deterministic Underworld pipeline through secondary connectivity.

It measures production generators without changing their inputs, RNG, StableIds, fingerprints, or generation decisions.

## Scope

Measured stages:

1. `macro_region`
2. `primary_topology`
3. `entrance_generation`
4. `secondary_connectivity`

Secondary connectivity receives the four cardinal neighboring macro/topology views used by the production connectivity contracts. Neighbor preparation is intentionally performed **outside** the timed connectivity section so the reported stage time measures `SecondaryConnectivityGenerator.generate(...)` itself rather than duplicated setup work.

This harness does **not** benchmark cave meshing, runtime streaming, collision realization, presentation, or gameplay.

## Fixed corpus

The comparison corpus lives in `benchmark_config.gd` and is versioned as:

```text
worldgen-benchmark-corpus-v1
```

v1 contains:
- 4 fixed world seeds;
- 5 fixed target regions per seed;
- positive, mixed-sign and negative coordinates;
- 20 measured target cases total;
- four cardinal neighbor views per connectivity case.

Changing seeds, regions, or neighbor policy requires a corpus revision bump so benchmark results from different workloads are not compared as if they were equivalent.

## Output

Each run emits:
- concise text summary;
- JSON report with every measured case;
- per-stage samples, median, nearest-rank p95, min, max and total elapsed milliseconds;
- network/node/primary-edge/entrance/secondary-connectivity counts;
- stage fingerprints for audit/reproducibility context.

Timings are hardware/runtime dependent diagnostics. They are **not** deterministic fingerprints and no performance threshold fails CI in PERF-055.

## Run locally

```bash
godot --headless --path . --script res://tools/worldgen_benchmark/run_worldgen_benchmark.gd -- \
  --out-dir=/tmp/underworld-worldgen-benchmark \
  --basename=worldgen_benchmark
```

Expected files:

```text
worldgen_benchmark.json
worldgen_benchmark.txt
```

The command exits non-zero only for benchmark/generation/export failures, not because a timing is slower than a budget.

## CI

`.github/workflows/worldgen-benchmark.yml` runs the same fixed corpus headlessly, publishes the text summary to the GitHub Actions job summary, and uploads both reports as an artifact.

The workflow may reveal a performance regression, but PERF-055 deliberately records rather than enforces budgets. Budget selection belongs to later profiling work after measurement evidence exists.
