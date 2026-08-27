# Underworld — Automated Validation Harness Architecture

## Status

This document defines how deterministic world generation, stable identity, streaming ownership and persistence compatibility are validated without requiring manual exploration of every change.

The validation responsibilities are **LOCKED at the architectural level**. Exact test framework, command-line wrapper and CI provider remain implementation choices.

Core principle:

> **Anything that claims to be deterministic world truth must be testable as data. Human playtesting is reserved for feel, readability, pacing and fun — not for discovering basic generation corruption.**

---

## 1. What the harness must prove

The harness exists to answer several different questions. They must not be collapsed into one giant "world generated successfully" test.

### Contract determinism

```text
same canonical inputs
    -> same deterministic values / IDs / fingerprints
```

### Structural validity

```text
generated graph/data obeys invariants
```

### Scheduling independence

```text
load order / worker order / neighbor request order
    -> same world truth
```

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
       accidental deterministic drift fails loudly
```

---

## 2. Test layers

Use several layers because a failure is much easier to diagnose when the smallest broken contract is already known.

```text
L0  deterministic primitive tests
L1  stable address / ID tests
L2  generator-stage tests
L3  graph/world-definition invariant tests
L4  batch seed/property tests
L5  scheduling/parallel-order tests
L6  persistence/migration tests
L7  streaming-lifetime simulation tests
L8  engine/noise compatibility fingerprints
L9  milestone runtime/playtests
```

`L0` through `L8` should be automatable/headless. `L9` is intentionally human-facing and infrequent.

---

## 3. L0 — deterministic primitive contract tests

Before persistent world generation depends on the project-owned seed/RNG contract, freeze hard-coded test vectors.

Tests cover conceptually:

```text
canonical StableAddress encoding
seed-domain encoding
seed derivation/hash mixing
stateless deterministic value generation
project-owned PRNG sequence, if used
canonical endpoint ordering
canonical integer serialization
```

Example fixture shape:

```text
input:
  world_seed = 123456789
  domain = UG_PRIMARY_TOPOLOGY rev 1
  address = region(4,-2)/network(slot-3)
  subkey = "existence"

expected derived bits/value:
  0x...
```

The expected output is committed as a constant produced by the chosen frozen contract.

### Rule

Do not update expected vectors merely to make a refactor pass.

If the primitive algorithm intentionally changes, that is a seed-contract/domain revision decision and must be reflected in versioning documentation first.

---

## 4. L1 — stable address and ID tests

Tests defined by `STABLE_PROCEDURAL_IDS.md` must include:

1. same semantic candidate address produces the same StableId repeatedly;
2. array/dictionary order does not affect identity;
3. rejected sibling candidates do not rename other candidate IDs;
4. runtime MultiMesh indexes can be reordered without changing StableIds;
5. negative global candidate coordinates encode canonically;
6. undirected endpoints A-B and B-A produce the same connector identity;
7. cross-region canonical ownership resolves identically from either side;
8. child IDs derive from stable parent + fixed local candidate key;
9. duplicate StableIds inside one compatible world-definition scope are a hard failure.

Readable debug StableAddresses should be emitted alongside IDs on failure.

---

## 5. L2 — deterministic generator-stage tests

Every deterministic pipeline stage defined in `GENERATION_PIPELINE_INTERFACES.md` needs a data-only test entry point.

Conceptually:

```text
StageInput + WorldGenerationContext
    -> StageResult
    -> canonical serialization
    -> fingerprint
```

Initial stage coverage:

```text
macro underground-region plan
primary topology
entrance selection/integration descriptors
secondary connectivity
special-location hook reservation
finalized region definition
base geometry description
```

### Stage fingerprint rule

Each result has canonical sorted serialization that excludes:

```text
wall-clock timing
pointer/object addresses
thread/task IDs
non-semantic dictionary ordering
runtime Node identity
transient diagnostic ordering unless canonicalized
```

The fingerprint represents deterministic semantic output only.

### Why stage fingerprints matter

If a final world fingerprint changes, stage fingerprints show whether drift began in:

```text
seed/address layer
primary topology
entrances
connectivity
geometry
```

instead of forcing us to inspect a rendered cave manually.

---

## 6. L3 — graph/world-definition invariant validators

A generated result can be deterministic and still be invalid. Determinism and validity are separate checks.

### Required graph invariants

At minimum validate:

```text
all referenced node IDs exist or are valid explicit external references
all primary edges reference valid endpoints
all secondary edges reference valid canonical endpoints
no duplicate stable IDs
network ownership is canonical
cross-region edges have one owner
external references point to the expected owner region
entrances reference valid connected topology
required entrance path is traversably connected to its target node
node/profile weights are finite and normalized/tolerant as specified
positions/bounds contain no NaN/Inf
radii/widths/clearances are positive where required
finalized definitions contain no transient candidate objects
```

### Topology sanity metrics

Collect, but do not necessarily hard-fail on every numeric range initially:

```text
node count
edge count
connected component count
cycle rank / loop count
dead-end fraction
branching distribution
vertical span
network diameter / approximate travel distance
entrance count
entrance-to-entrance path distances
secondary-connector fraction
profile-weight distribution
```

These metrics allow us to detect generator collapse statistically before subjective playtesting.

---

## 7. Entrance validation

Because entrances connect surface generation and underground definitions, they need dedicated validation.

For every entrance:

```text
surface position resolves to valid deterministic surface reference data
entrance integration descriptor has valid bounds
connected underground node exists
entrance route reaches its connected topology
entrance does not reference runtime-only state
canonical owner/address is stable
```

Regional entrance-count expectations are **distribution rules**, not universal hard assertions.

The design target of roughly 1–3 entrances where appropriate should therefore be tested statistically over a corpus rather than forcing every region to satisfy `1 <= count <= 3`.

Rare valid zero-entrance or unusual systems must remain possible where generation rules allow them.

---

## 8. Depth-profile validation

Shallow/mid/deep are continuous generation grammars.

Tests should verify:

```text
profile weights are deterministic
weights remain valid/normalized within defined tolerance
profile sampling changes smoothly enough across intended transitions
local exceptions are possible
changing geometry-only domains does not alter profile/topology fingerprints
```

Batch metrics should compare structural tendencies rather than hard templates.

Examples:

```text
shallow-biased corpus tends toward smaller/local networks
mid-biased corpus tends toward more loops/regional joining
deep-biased corpus permits larger vertical/network spans
```

Exact target ranges remain tuning data and can evolve without changing this architecture.

---

## 9. Secondary connectivity validation

The ~10% Souls-style connectivity philosophy must not become an unbounded random-tunnel pass.

Validate:

```text
accepted connector ID is stable
A-B equals B-A for undirected candidates
owner is canonical across region order
no duplicate connector for same canonical candidate
connectors do not reference missing endpoints
connectivity caps are respected
accepted connector improves/changes graph according to defined acceptance diagnostics
rejected candidate cannot perturb unrelated accepted identities/randomness
```

Batch statistics should track:

```text
secondary edges / total edges
loop-rank increase
connector lengths
cross-region connector frequency
regions with zero deliberate connectors
regions with unusually high connectivity
```

A statistical alert is preferable to encoding "10%" as a literal required edge percentage.

---

## 10. L4 — batch-seed/property test campaigns

The harness must generate many worlds/regions automatically.

### Two corpus types

#### Fixed regression corpus

A committed list of seeds/region addresses selected to cover:

```text
ordinary cases
negative coordinates
region boundaries
very shallow/deep profile mixes
cross-region connectors
rare entrance layouts
previously failing seeds
```

These are stable over time and useful for deterministic regression fingerprints.

#### Campaign corpus

A much larger deterministic pseudo-random test corpus derived from a **test campaign seed**, not from wall-clock randomness.

Example concept:

```text
campaign_seed = 20260827
regions = 10_000
```

The campaign itself must be reproducible.

If campaign entry `7314` fails, we can reproduce exactly that same seed/address.

### Rule

Never report only:

```text
random seed failed
```

Report enough to recreate the exact case.

---

## 11. Failure reproduction record

Every deterministic-generation failure should emit a compact reproduction record conceptually containing:

```text
validation code / reason
world seed
WorldId where relevant
GeneratorManifest ID / contract revisions
seed schema/domain revisions
stage name + stage revision
region/network/candidate StableAddress
StableId(s) involved
neighbor dependency addresses where relevant
expected fingerprint/value
actual fingerprint/value
campaign seed + campaign index if applicable
```

Optional diagnostics may include:

```text
canonical stage JSON/text dump
small graph summary
metrics
```

The output should be copyable into a single-case test command later.

---

## 12. Failure shrinking / minimization — DIRECTIONAL

For complex property failures, the harness should try to isolate the smallest useful reproduction where practical.

Examples:

```text
whole world failed
    -> identify region
    -> identify network
    -> identify stage
    -> identify candidate/edge
```

This does not require a sophisticated property-testing framework initially.

The architecture requirement is simply that stages and addresses are separable enough that we do not need to launch the complete game to diagnose one bad connector.

---

## 13. L5 — scheduling/order independence tests

The same deterministic request set must be executed under different legal schedules.

Examples:

```text
regions ascending
regions descending
randomized deterministic order
neighbors first
owner region first
owner region last
single worker
multiple workers where test environment permits
```

Final canonical fingerprints must match.

### Important distinction

Completion timing may differ.

```text
A ready before B
```

is allowed.

World truth differing because A completed before B is a hard failure.

---

## 14. Async stale-result tests

Streaming/service tests should simulate:

```text
request A starts
interest in A disappears
request token changes / cell unloads
old result A returns
```

Expected behavior:

```text
stale result does not resurrect runtime owner
stale result does not overwrite newer incompatible request
compatible deterministic result may enter disposable cache if policy permits
no durable delta is lost/changed
```

This can be tested with fake/deterministic jobs before full 3D runtime content exists.

---

## 15. L6 — persistence and migration tests

Persistence tests are data tests, not playtests.

### Modern save round-trip

```text
construct deterministic header + deltas
serialize
load
validate compatibility
compare canonical semantic state
```

### Manifest compatibility classification

Fixtures cover:

```text
EXACT
SUPPORTED_LEGACY
MIGRATION_REQUIRED
INCOMPATIBLE
UNKNOWN/CORRUPT
```

No test may allow an incompatible manifest to silently fall back to current generator defaults.

### Prototype-v2 migration fixtures

At minimum:

```text
empty world modifications
harvested trees
harvested rocks
collected branches
collected loose stones
negative chunk coordinates
multiple destroyed objects in one chunk
wood/stone/tool/hotbar state
```

Assert:

```text
legacy accepted-index resolves to expected candidate address
modern StableId is correct
resources/tools remain correct
unresolved legacy IDs are quarantined/reported
new save round-trips
old input fixture remains untouched if migration fails
```

---

## 16. Persistent delta composition tests

Generated base truth and player deltas are separate.

Tests should cover:

```text
base object exists + destroyed delta -> runtime view omits it
base collapse exists + cleared delta -> cleared representation
base deposit exists + partial state -> expected modified representation
unload/reload -> same composed state
cache eviction -> same composed state
regenerate base from seed -> same delta still targets same StableId
```

Later terrain/building systems extend this suite rather than changing the ownership model.

---

## 17. L7 — streaming-lifetime simulation tests

Before relying on rendered scenes, test the streaming coordinator with a fake observer and fake runtime owners/services.

Example path:

```text
surface position
-> approach entrance
-> cross entrance
-> descend
-> backtrack
-> return to surface
```

Assert demand/lifetime transitions such as:

```text
surface + first underground cells overlap near entrance
collision requested before traversal into newly required geometry
far surface demand releases deep underground
backtracking can reuse cached geometry if still retained
one runtime owner per cell/chunk
unloading cell does not remove WorldDeltaStore state
```

Exact distance thresholds are configuration/tuning and should be injected into tests rather than hard-coded into architecture tests.

---

## 18. Cache correctness tests

Because caches are disposable, tests should deliberately destroy them.

Run equivalent generation/composition with:

```text
warm definition cache
cold definition cache
warm geometry cache
cold geometry cache
forced eviction between requests
```

Canonical world truth and final composed state must remain equal.

Performance may differ; semantics may not.

---

## 19. L8 — engine/noise compatibility fingerprints

The project may depend on Godot/FastNoiseLite or other engine algorithms whose output can change between versions.

Maintain representative fingerprints for persistent engine-dependent generation inputs/outputs.

Examples:

```text
surface height samples at fixed world coordinates
moisture/forest/rock fields
legacy-v2 decoration candidate output used by migration
future persistent noise fields used by Underworld generation, if any
```

### Engine upgrade rule

Before upgrading an engine/library that participates in persistent generation:

1. run compatibility fingerprints;
2. if unchanged, treat as deterministic-compatible evidence;
3. if changed, classify the affected generator contracts deliberately;
4. do not update goldens silently and call the upgrade harmless.

---

## 20. Golden fingerprints versus property assertions

Use both.

### Golden/frozen fingerprints

Best for:

```text
seed/RNG primitive contracts
known stable IDs
fixed representative stage results
engine/noise compatibility
migration fixtures
```

### Property/invariant assertions

Best for:

```text
thousands of generated seeds
valid references
bounded connectivity
finite geometry values
canonical ownership
statistical distributions
```

Do not create a giant golden file for every generated world. That becomes brittle and hides which semantic rule matters.

---

## 21. Expected-change workflow

Sometimes a generator change is intentional.

The workflow is:

```text
1. identify affected generation domain/stage/profile contract
2. update architecture/version decision first if compatibility changes
3. increment the appropriate explicit revision(s)
4. generate before/after fingerprints and metrics
5. review that unrelated domains/stages remain stable where promised
6. update only the goldens that belong to the intentionally changed contract
7. add/retain a regression test for the previous bug or design requirement
```

Do not mass-regenerate all expected outputs without examining which contracts changed.

---

## 22. CI / execution tiers — DIRECTIONAL

Use different test budgets so validation remains practical.

### Fast gate

Runs on normal development/PR work.

Conceptually:

```text
primitive vectors
stable-ID tests
small fixed stage corpus
graph invariants
modern save round-trip
small legacy migration fixtures
small scheduling-order corpus
```

Target: seconds to a few minutes once implemented.

### Full deterministic suite

Runs before architecture/generator merges/releases or manually as needed.

Conceptually:

```text
larger fixed corpus
hundreds/thousands of regions
parallel-order variants
streaming fake-observer scenarios
engine/noise fingerprints
all migration fixtures
```

### Stress/campaign suite

Potentially larger local/nightly/manual run:

```text
10k+ regions/world cases
rare-topology search
memory/performance telemetry
long streaming simulated traversal
```

Exact cadence depends on available CI/runtime resources.

---

## 23. Performance telemetry is separate from correctness

The harness should record useful performance metrics such as:

```text
stage generation time
node/edge counts
geometry-description size
cache hit rate in streaming simulation
peak queued requests
```

Early in development these are observational, not strict pass/fail budgets unless a clear regression threshold is established.

A slow valid seed is different from a structurally invalid seed.

Do not hide correctness failures inside performance reports.

---

## 24. Test code must not change generator behavior

Avoid generator branches such as:

```text
if testing:
    use simpler topology
```

The harness calls the same deterministic generation code used by the game.

Debug serialization/diagnostics may be enabled for tests, but semantic output must be the same.

---

## 25. Headless execution — LOCKED DIRECTION

The deterministic architecture must be runnable without rendering or manual input.

Godot headless execution is the likely first implementation path, but the architecture does not depend on a particular third-party test framework.

A future command should support concepts like:

```text
run all fast tests
run fixed seed corpus
run campaign with N cases
reproduce one world/region/stage failure
run migration fixtures
print canonical fingerprint/metrics
```

Exact CLI syntax is an implementation decision.

---

## 26. Test fixture ownership

Test fixtures belong in version control when they define compatibility promises.

Examples:

```text
seed/RNG vectors
fixed StableAddress -> StableId vectors
representative generator manifests
prototype-v2 save fixtures
fixed regression seed corpus
engine/noise compatibility fingerprints
```

Large disposable campaign outputs do not belong in the repository unless they become a named regression fixture.

When a previously failing campaign case is important, promote its seed/address into the fixed regression corpus.

---

## 27. Diagnostic severity

Classify failures so large campaigns remain useful.

Conceptually:

```text
FATAL
    broken reference, duplicate ID, NaN, incompatible save interpreted as current, determinism mismatch

ERROR
    violated generator invariant / unreachable required entrance / ownership contradiction

WARNING / STATISTICAL ALERT
    unusual but possibly valid topology distribution, outlier connector length, extreme node count

INFO
    performance/metric observation
```

Warnings should not become a reason to make the generator uniform merely to silence statistics.

---

## 28. Initial validation report

A batch run should summarize conceptually:

```text
cases executed
cases passed/failed
first failure reproduction command/data
seed/stage fingerprint mismatches
invariant counts
metric distributions
outliers/warnings
execution time
```

When failures exist, prioritize deterministic reproduction information over pretty reports.

---

## 29. Architecture-cycle implementation order

When we begin foundational code, the validation infrastructure should grow alongside it rather than being postponed until the cave generator is finished.

Recommended order:

```text
1. canonical StableAddress/StableId primitives + tests
2. seed-domain registry/deriver + frozen vectors
3. generator manifest primitives + tests
4. pure graph data classes + invariant validator
5. deterministic stage interface skeleton + fingerprint serializer
6. first primary-topology implementation + batch tests
7. entrances/connectivity + their validators
8. geometry description + finite/bounds/fingerprint tests
9. streaming services/coordinator + fake-observer lifetime tests
10. modern persistence + v2 migration fixtures
```

The exact commit breakdown may differ, but validation should not lag several milestones behind world generation.

---

## 30. What automated tests do not replace

Automated validation cannot answer:

```text
is mining satisfying?
is combat readable/fun?
do caves feel mysterious rather than annoying?
is traversal too slow?
does a huge cavern feel impressive?
is the ~10% connectivity noticeable in a good way?
```

Those remain milestone playtest questions.

The harness exists so a human playtest is not wasted discovering:

```text
entrance references a missing node
seed changes when worker order changes
old save destroys the wrong tree
cave graph contains NaN coordinates
streaming unload deleted durable state
```

---

## 31. Validation invariants — LOCKED

1. Every persistent deterministic primitive has fixed reproducibility tests before release use.
2. Every deterministic generation stage is independently callable/fingerprintable as data.
3. Determinism tests vary legal execution/load/scheduling order.
4. Structural validity is tested separately from determinism.
5. Stable IDs are checked for uniqueness/canonical ownership.
6. Save compatibility is classified explicitly and migration paths have fixtures.
7. Caches/runtime lifetime may be destroyed/reordered in tests without changing durable truth.
8. Engine/noise upgrades cannot silently alter persistent generation fingerprints.
9. Batch campaigns are reproducible from a campaign seed/index.
10. Every hard failure provides enough information to reproduce the case without manually searching the world.
11. Statistical generator targets are validated as distributions rather than forcing every region into the same template.
12. Human playtesting is reserved for experiential quality after automated correctness checks pass.

---

## 32. Intentionally open implementation choices

- exact Godot test runner / third-party framework;
- exact CLI syntax;
- exact canonical fingerprint algorithm/encoding;
- exact fixed regression corpus size;
- exact CI provider and job cadence;
- exact stress-campaign case count;
- exact metric thresholds and performance budgets;
- exact graph-visualization/debug artifact format;
- whether failure shrinking becomes automated beyond stage/address isolation.

These choices can evolve without weakening the requirement that deterministic world architecture is mechanically testable and reproducible.
