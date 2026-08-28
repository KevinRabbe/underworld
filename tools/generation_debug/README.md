# Generation Debug Report

Task: `MAP-007`

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

## Report contents

The report includes:

- world seed and stable world ID;
- generator manifest fingerprint;
- underground region coordinate;
- stages in execution order;
- success/failure state per stage;
- stage fingerprints;
- diagnostics from failed stages;
- explicit retry counts (currently zero for the merged generator, because this task does not add retry behavior);
- important generator constants;
- macro profile/tendency values;
- primary-topology metrics.

No wall-clock timestamp is included, so the same seed, region and generator revision reproduce the same report exactly.

## Scope boundary

This tool is observational only. It does not:

- change seeds or randomness;
- retry failed generation;
- alter generation configuration;
- modify world definitions;
- touch character/gameplay systems;
- perform map visualization.

Later generator stages can append their own stage result and parameters using the same report model without changing the report schema.

## Validation

```bash
godot --headless --path . --quit-after 1 \
  --script res://tools/generation_debug/run_generation_debug_report_contracts.gd
```

The contracts cover successful reports, exact deterministic reproduction, synthetic failure diagnostics, explicit retry accounting and negative seed/region coordinates.
