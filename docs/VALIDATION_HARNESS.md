# Underworld — Automated Validation Harness Architecture

## Status

This document defines how deterministic world generation, stable identity, world-domain transitions, streaming ownership and persistence compatibility are validated without requiring manual exploration of every change.

The validation responsibilities are **LOCKED at the architectural level**. Exact test framework, command-line wrapper and CI provider remain implementation choices.

Core principle:

> **Anything that claims to be deterministic or durable world truth must be testable as data. Human playtesting is reserved for feel, readability, pacing and fun — not basic generation, identity, transition or persistence corruption.**

World-domain authority: `20_world/WORLD_DOMAINS_AND_TRANSITIONS.md` / ADR-001.

---

## 1. What the harness must prove

Separate these questions rather than hiding them behind one giant “world generated successfully” test.

### Contract determinism

```text
same canonical inputs
    -> same deterministic values / IDs / fingerprints
```

### Structural validity

```text
generated domain data obeys invariants
```

### Scheduling independence

```text
load order / worker order / neighbor request order
    -> same deterministic truth
```

### World-domain transition correctness

```text
source gateway
    -> bounded destination preparation
    -> destination readiness
    -> atomic active-domain commit
```

Failure must remain fail-closed and must not leave mixed/duplicated authoritative domain state.

### Compatibility safety

```text
old save/manifest
    -> exact support, explicit migration, or explicit incompatibility
```

### Runtime ownership correctness

```text
streaming/caches may appear/disappear
    -> durable state and deterministic truth remain intact
```

### Regression detection

```text
engine/library/refactor change
    -> intentional deterministic change is explicit
       accidental drift fails loudly
```

---

## 2. Test layers

```text
L0  deterministic primitive tests
L1  stable address / StableId tests
L2  domain generator-stage tests
L3  graph/world-definition invariant tests
L4  batch seed/property tests
L5  scheduling/parallel-order tests
L6  persistence/migration tests
L7  runtime streaming + world-domain transition simulation
L8  engine/noise compatibility fingerprints
L9  milestone runtime/playtests
```

`L0` through `L8` should be automatable/headless. `L9` is deliberately human-facing and infrequent.

---

## 3. L0 — deterministic primitive contract tests

Before persistent generation depends on a project-owned seed/RNG contract, freeze hard-coded vectors for:

```text
canonical StableAddress encoding
seed-domain encoding
seed derivation/hash mixing
stateless deterministic values / project PRNG sequence
canonical endpoint ordering
canonical integer serialization
```

The expected outputs are part of compatibility. Do not update vectors merely to make a refactor pass.

An intentional primitive change requires an explicit seed-contract/domain revision decision first.

---

## 4. L1 — stable address and ID tests

At minimum prove:

1. same semantic candidate address -> same StableId;
2. array/dictionary order does not affect identity;
3. rejected siblings do not rename accepted siblings;
4. transient runtime instance/MultiMesh indexes may change without changing StableIds;
5. negative domain-local/global candidate coordinates encode canonically where supported;
6. undirected A-B/B-A endpoints canonicalize;
7. Underworld cross-region ownership resolves identically from either side;
8. child IDs derive from stable parent + fixed local key;
9. duplicate StableIds inside one compatible definition scope are a hard failure.

Readable StableAddresses accompany identity failures.

### Gateway identity is separate

Cross-domain `WorldGatewayDefinition` identity answers which transition mapping this is. It must not be fabricated from:

- Player/world coordinates;
- nearest entry site;
- runtime Node identity;
- Y sign;
- Overworld/Underworld coordinate conversion.

Gateway source/destination identity gets its own contract tests when implemented.

---

## 5. L2 — deterministic generator-stage tests

Every current deterministic stage needs a data-only test entry point.

For the Underworld, authority is `20_world/UNDERWORLD_GENERATION_PIPELINE.md`:

```text
StageInput + UnderworldGenerationContext
    -> StageResult
    -> canonical serialization
    -> fingerprint
```

Coverage includes conceptually:

```text
macro Underworld region planning
primary topology
domain-local entry-site selection/attachment
secondary connectivity
special-location hook reservation
region finalization
base geometry description
```

Historical surface-integration descriptors/entrance fields may remain in legacy generator fixtures where compatibility requires them, but the validation harness does **not** treat physical surface opening integration as current cross-domain architecture.

### Stage fingerprint rule

Canonical fingerprints exclude:

```text
wall-clock timing
pointer/object addresses
thread/task IDs
non-semantic dictionary ordering
runtime Node identity
transient diagnostics unless canonicalized
active runtime-domain state
```

If a final fingerprint changes, stage fingerprints identify where drift began.

---

## 6. L3 — graph/world-definition invariant validators

Determinism and validity are separate.

### Required Underworld graph invariants

Validate at least:

```text
all referenced node IDs exist or are valid explicit external references
all edges reference valid endpoints
no duplicate StableIds
network ownership is canonical
Underworld cross-region edges have one canonical owner
external references point to expected owner region
entry sites reference valid connected topology
entry paths are traversably connected to target topology
profile weights are finite/normalized as specified
positions/bounds are finite and domain-local
positive dimensions/clearances where required
finalized definitions contain no transient candidates/runtime Nodes
```

Do **not** require an Underworld graph object to carry a valid Overworld coordinate.

### Topology metrics

Collect useful distributions such as:

```text
node/edge counts
connected components
cycle rank / loops
dead-end fraction
branching
vertical span
network diameter
entry-site count/path distances
secondary-connector fraction
profile-weight distribution
```

Statistics detect collapse without forcing every region into one template.

---

## 7. Underworld entry-site validation

Current entry-site validation is domain-local.

For each entry site prove:

```text
stable candidate identity is canonical
owning region/network/node exists
Underworld-local anchor/clearance is finite and valid
entry route reaches connected topology
site contains no runtime-only state
canonical owner/address is stable
```

Regional site-count goals are distribution rules, not universal hard assertions.

### Legacy entrance compatibility

Historical accepted `EntranceDefinition`, surface-reference and `ug.entrance.*` fixtures may remain regression evidence for the generator contract that produced them.

Validation distinguishes:

```text
legacy deterministic compatibility
!=
current cross-domain gateway authority
```

Do not rename/repurpose old persistent seed domains simply to match new terminology.

---

## 8. Gateway mapping validation

When gateway definitions exist, validate independently of cave topology generation:

```text
gateway StableId/semantic identity is stable
source domain + source site identity valid
destination domain + destination site identity valid
pair/return policy deterministic where specified
mapping does not depend on coordinate conversion
mapping contains no runtime Node authority
```

Changing Underworld generation should not silently rename unrelated Overworld gateways; changing Overworld terrain should not silently reseed unrelated Underworld topology unless an explicit compatible contract says so.

---

## 9. Depth-profile validation

Shallow/mid/deep are **Underworld-local** generation grammars.

Tests verify:

```text
profile weights deterministic
weights valid/normalized
profile changes spatially as intended inside Underworld
local exceptions possible
geometry-only revisions do not alter promised topology/profile fingerprints
```

Batch metrics test tendencies rather than literal templates.

No validation invariant defines Underworld depth as `surface_height - shared_world_y`.

---

## 10. Secondary connectivity validation

Validate:

```text
accepted connector identity stable
A-B == B-A for undirected candidates
owner canonical across Underworld region order
no duplicate connector
endpoints exist
connectivity caps respected
accepted connector has defined topology benefit/diagnostic
rejected candidate cannot perturb unrelated identities/randomness
```

Track statistical connector frequency/length/loop effect without turning “~10% Souls-style connectivity” into a literal edge-percentage invariant.

---

## 11. L4 — batch-seed/property campaigns

Use two corpus types.

### Fixed regression corpus

Committed cases cover ordinary and difficult deterministic scenarios:

```text
negative addresses
region boundaries
shallow/mid/deep mixes
Underworld cross-region connectors
rare entry-site layouts
previous failures
legacy compatibility fixtures where supported
```

### Campaign corpus

Large deterministic pseudo-random cases derive from an explicit campaign seed, never wall-clock randomness.

Failures report enough data to reproduce exact campaign index/address.

---

## 12. Failure reproduction record

Every hard deterministic failure reports conceptually:

```text
validation code / reason
root world seed / WorldId
owning domain
generator manifest / revisions
seed schema/domain revisions
stage name/revision
region/network/candidate StableAddress
StableId(s)
neighbor dependencies
expected vs actual fingerprint/value
campaign seed + index if applicable
```

World-domain transition failures additionally report:

```text
source domain
source gateway identity
destination domain
destination site identity
transition phase
readiness state
```

No human should need to search the rendered world to reproduce a deterministic failure.

---

## 13. Failure shrinking — DIRECTIONAL

Prefer isolating:

```text
world -> domain -> region -> network -> stage -> candidate/edge/site
```

Transition failures shrink by phase:

```text
request -> destination definition -> geometry -> collision/readiness -> commit/rollback
```

A sophisticated property framework is optional; separable contracts are not.

---

## 14. L5 — scheduling/order independence

Execute the same deterministic request sets under legal alternate schedules:

```text
ascending/descending region order
deterministically shuffled order
neighbors first/last
owner first/last
single/multiple workers
warm/cold cache variants
```

Completion timing may differ; deterministic truth may not.

---

## 15. Async stale-result tests

Simulate:

```text
request A starts
interest disappears / generation token advances
old result A returns
```

Expected:

```text
stale result cannot resurrect a runtime owner
stale result cannot overwrite a newer incompatible request
compatible result may enter disposable cache if policy permits
no durable delta changes
```

This contract applies independently inside Overworld and Underworld streaming.

---

## 16. L6 — persistence and migration tests

### Modern round-trip

```text
construct deterministic header + gameplay/delta state
serialize
load
validate compatibility
compare canonical semantic state
```

### Domain-qualified Player location

Current target persistence must prove:

```text
PlayerWorldLocation
- active_domain
- domain_local_transform
```

Tests cover:

- Overworld save -> Continue reconstructs Overworld without requiring Underworld runtime;
- Underworld save -> Continue reconstructs Underworld directly;
- exact durable transform preserved after required local collision/readiness is prepared;
- no domain inference from Y sign/nearest entrance;
- legacy schema without domain information follows an explicit migration/compatibility decision rather than guessing.

### Manifest compatibility

Fixtures cover `EXACT`, `SUPPORTED_LEGACY`, `MIGRATION_REQUIRED`, `INCOMPATIBLE`, and corrupt/unknown states.

### Prototype legacy fixtures

Preserve explicit migration tests for historical generated-object IDs/save schemas while those paths remain supported. Failed migration never destroys the only valid old save.

---

## 17. Persistent delta composition tests

Generated base truth and durable deltas remain separate.

Test examples:

```text
base generated object + destroyed delta -> runtime omits it
base collapse + cleared delta -> cleared representation
base deposit + depletion/partial state -> expected representation
unload/reload -> same composed state
cache eviction -> same state
regeneration -> delta still targets same StableId
```

Each delta belongs to explicit world/domain context where spatial interpretation requires it.

---

## 18. L7 — domain-local streaming simulation

Test each domain's runtime lifetime independently with fake observers/services.

For Underworld:

```text
observer moves across many runtime cells
-> demand follows current relevance
-> released cells become dormant/evicted according to policy
-> re-entry reconstructs canonical representation
```

Assert:

- collision requested before Player enters newly required geometry;
- runtime cost/index iteration is bounded by current relevant/resident demand rather than total exploration history;
- one live owner per runtime address;
- stale results cannot resurrect released owners;
- unload does not delete durable `WorldDeltaStore` state;
- caches can be discarded without changing deterministic truth.

Exact radii/budgets are injected configuration, not hard-coded architecture constants.

---

## 19. L7 — explicit world-domain transition simulation

Replace the old continuous-surface-to-cave fake-observer route with the actual architecture:

```text
OVERWORLD active
-> source gateway accepted
-> transition/loading state
-> bounded UNDERWORLD destination preparation
-> required destination render/collision readiness
-> atomic active_domain = UNDERWORLD commit
-> source runtime released according to lifecycle policy
```

Also test paired return.

Required assertions:

- gateway mapping resolves deterministic destination identity;
- no coordinate conversion is used as transition authority;
- Player input/physics cannot resume before destination safety gate;
- failure before commit leaves/returns to coherent source state;
- failure cannot leave two active authoritative domains or duplicate Player/runtime authority;
- inactive full-domain streaming does not continue indefinitely;
- direct Underworld Continue reconstructs Underworld without pretending a gateway traversal occurred;
- warm return/re-entry does not duplicate runtime Nodes/caches.

A loading screen is valid presentation. Validation measures correctness and bounded work; it does not require seamless geometry.

---

## 20. Cache correctness

Deliberately destroy caches under equivalent generation/composition:

```text
warm/cold definition cache
warm/cold geometry cache
forced eviction
leave/re-enter domain/cells
```

Canonical truth and composed durable state remain equal. Performance may differ; semantics may not.

---

## 21. L8 — engine/noise compatibility fingerprints

Maintain representative fingerprints for persistent engine/library-dependent generation inputs/outputs.

Examples:

```text
Overworld surface field samples
legacy generator outputs required for migration
persistent Underworld noise/geometry fields if engine-dependent
```

Engine upgrades must classify deterministic drift explicitly rather than silently updating goldens.

---

## 22. Golden fingerprints vs property assertions

Use frozen goldens for compatibility-critical primitives/fixtures and property assertions for large generated populations.

Do not create giant opaque golden worlds that hide which contract matters.

---

## 23. Expected-change workflow

For intentional generator changes:

1. identify affected domain/stage/profile contract;
2. update architecture/version decision first if compatibility changes;
3. revise the appropriate explicit contract/domain revision;
4. produce before/after fingerprints/metrics;
5. prove unrelated domains/stages remain stable where promised;
6. update only affected goldens;
7. retain a regression for the motivating requirement/bug.

Never repurpose an existing persistent seed-domain ID to mean a new gateway/world-domain decision.

---

## 24. CI / execution tiers — DIRECTIONAL

### Fast gate

```text
primitive vectors
StableId tests
small fixed stage corpus
graph invariants
persistence round-trip
small migration fixtures
small scheduling-order corpus
world-domain transition contract smoke when affected
```

### Full deterministic suite

```text
larger fixed corpus
hundreds/thousands of regions
parallel-order variants
domain-local streaming simulations
world-domain transition/rollback/readiness scenarios
engine/noise fingerprints
all supported migration fixtures
```

### Stress/campaign suite

```text
large generated-world corpus
rare-topology search
long exploration/re-entry history
mixed runtime/persistence load
memory/performance telemetry
```

Exact cadence follows available CI resources.

---

## 25. Performance telemetry is separate from correctness

Useful metrics include:

```text
stage generation time
node/edge/site counts
geometry-description size
active/resident/dormant record counts
cache hit rate
peak queued work
worst main-thread publication/hitch
gateway cold/warm transition time
```

Hardware-sensitive budgets require evidence. Correctness failures are never hidden inside performance reports.

---

## 26. Test code must not change production semantics

No generator/runtime branch such as:

```text
if testing:
    use simpler topology or fake gateway
```

The harness calls production deterministic/runtime authorities. Test-only diagnostics/fixtures may expose inputs and inspect outputs without becoming product behavior.

---

## 27. Headless execution — LOCKED DIRECTION

Deterministic architecture must run without rendering/manual input where the contract is data/runtime-lifecycle testable.

A future/current runner may support:

```text
fast contracts
fixed seed corpus
campaign N cases
single failure reproduction
migration fixtures
world-domain transition scenarios
canonical fingerprint/metrics
```

CLI syntax is implementation detail.

---

## 28. Test fixture ownership

Version-control fixtures define compatibility promises, including:

```text
seed/RNG vectors
StableAddress -> StableId vectors
generator manifests
legacy save fixtures
fixed regression corpus
engine/noise fingerprints
```

Large disposable campaign outputs stay out of the repository unless promoted to named regressions.

---

## 29. Diagnostic severity

Conceptually:

```text
FATAL
    broken reference, duplicate ID, NaN/Inf, determinism mismatch,
    incompatible save interpreted as current, incoherent active-domain commit

ERROR
    generator/runtime invariant violation, missing required entry topology,
    gateway mapping/readiness/rollback contradiction

WARNING / STATISTICAL ALERT
    unusual but potentially valid topology distribution or performance outlier

INFO
    metrics/telemetry
```

Warnings must not force the generator into uniformity merely to silence statistics.

---

## 30. Validation report

A batch report summarizes:

```text
cases executed/pass/fail
first failure reproduction data
fingerprint mismatches
invariant counts
metric distributions
outliers/warnings
execution time
```

Prioritize deterministic reproduction information over pretty reports.

---

## 31. Architecture-cycle implementation rule

Validation grows with the architecture. Do not leave stable identity, generator stages, world-domain transitions or persistence migrations several milestones ahead of their mechanical proofs.

New work extends the existing validation ownership structure rather than creating competing test-only gameplay/generator authorities.

---

## 32. What automated tests do not replace

Automation cannot answer whether mining is satisfying, combat is readable, caves feel mysterious, transitions feel polished, or traversal pacing is fun.

Those remain milestone human tests after correctness is mechanically established.

---

## 33. Validation invariants — LOCKED

1. Persistent deterministic primitives have fixed reproducibility tests before release use.
2. Every deterministic generation stage is independently callable/fingerprintable as data.
3. Determinism tests vary legal execution/load/scheduling order.
4. Structural validity is separate from determinism.
5. Stable IDs are checked for uniqueness/canonical ownership.
6. Overworld/Underworld domain identity is explicit in tests; no coordinate-sign inference.
7. Cross-domain gateways are validated as semantic mappings, not mesh/coordinate continuity.
8. Destination safety/readiness is proved before transition control release.
9. Transition failure/rollback cannot leave mixed authoritative state.
10. Save compatibility is explicit and migrations have fixtures.
11. Caches/runtime lifetime may be destroyed/reordered without changing durable truth.
12. Inactive/historical runtime state cannot make ordinary update work grow without bound.
13. Engine/noise upgrades cannot silently change persistent fingerprints.
14. Batch campaigns are reproducible.
15. Every hard failure provides exact reproduction data.
16. Statistical generator targets are distributions, not universal templates.
17. Human playtesting is reserved for experiential quality after automated correctness checks.

---

## 34. Intentionally open implementation choices

- exact test runner/framework;
- exact CLI syntax;
- canonical fingerprint encoding;
- fixed corpus size;
- CI provider/cadence;
- stress campaign size;
- measured performance budgets;
- debug visualization format;
- automated shrinking sophistication.

These may evolve without weakening deterministic, domain, transition, persistence or runtime-lifetime correctness.