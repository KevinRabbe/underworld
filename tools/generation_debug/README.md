# Generation Debug Report

Task: `MAP-007`
Repair: `MAP-007-R1`

This development-only tool exports a deterministic report for the currently merged underground generation pipeline without changing generator behavior.

## Export

```bash
godot --headless --path . \
  --script res://tools/generation_debug/export_generation_debug_report.gd -- \
  --seed=12345 --region-x=0 --region-z=0 \
  --out-dir=user://generation_debug_reports
```

The command writes:

- `.json` — machine-readable deterministic report;
- `.txt` — concise human-readable report.

## Current reported pipeline

The report executes the current merged deterministic target-region path in this order:

1. `macro_region`
2. `primary_topology`
3. `entrance_generation`
4. `secondary_connectivity`

One `DeterministicSurfaceSampler` is created from the report world seed and shared by target/neighbor topology and entrance generation.

Secondary connectivity receives four explicit cardinal neighbor views. Each view is built from that neighbor's macro plan and primary topology, matching the production stage contract; the connectivity generator itself does not secretly generate neighbors. Neighbor coordinates and view count are included in the stage parameters.

## Report contents

The report includes:

- world seed and stable world ID;
- generator manifest fingerprint;
- underground region coordinate;
- stages in exact target-region execution order;
- success/failure state per stage;
- stage fingerprints;
- diagnostics from failed stages;
- explicit retry counts (currently zero for real merged stages, because this task does not add retry behavior);
- important generator constants;
- macro profile/tendency and candidate-slot values;
- primary-topology metrics;
- entrance-generation metrics;
- secondary-connectivity metrics;
- deterministic cardinal neighbor-view coordinates/count;
- entrance candidate count and surface jitter radius;
- connectivity length/score/degree bounds.

No wall-clock timestamp is included, so the same seed, region and generator revision reproduce the same report exactly.

## Scope boundary

This tool is observational only. It does not:

- change seeds or randomness;
- retry failed generation;
- alter generation configuration;
- modify world definitions;
- hide neighbor generation inside production stages;
- touch character/gameplay systems;
- perform map visualization.

Future merged generator stages can append their own stage result and parameters using the same report model without changing the report schema.

## Validation

```bash
godot --headless --path . --quit-after 1 \
  --script res://tools/generation_debug/run_generation_debug_report_contracts.gd
```

The contracts cover the exact four-stage order, stage fingerprints/metrics, four explicit neighbor views, exact deterministic JSON/text reproduction, synthetic connectivity-stage failure diagnostics, explicit retry accounting and negative seed/region coordinates. The dedicated CI workflow also exports a real report and requires both `entrance_generation` and `secondary_connectivity` in JSON and text output.
