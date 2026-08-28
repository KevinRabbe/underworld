# Underworld — Deterministic Generation Seed Domains

## Status

This document defines how procedural generation obtains deterministic randomness without depending on load order, worker scheduling, accepted-object count, or RNG calls made by unrelated systems.

The architecture is **LOCKED**. Exact low-level hash/PRNG implementation may be finalized during implementation, but it must satisfy the contract and test-vector requirements in this document before it is used for persistent world generation.

The core rule is:

> **Every persistent generation decision receives randomness from a named domain and a stable semantic address. There is no mutable shared world-generation RNG stream.**

This document complements `STABLE_PROCEDURAL_IDS.md`:

```text
StableAddress
    |
    +--> StableId
    |
    +--> SeedDeriver(domain, revision, subkey)
            |
            +--> local deterministic value / local deterministic RNG
```

Identity and randomness share the same stable address, but they are separate concepts.

---

## 1. Why one world RNG is forbidden

A traditional generator can do this:

```text
rng.seed = world_seed

generate terrain
consume 500 random values

generate trees
consume 200 random values

generate caves
consume 600 random values
```

That is deterministic only while the exact call sequence never changes.

If tree generation later consumes one extra value, cave generation receives a different sequence and the entire cave world can reshuffle even though cave code did not change.

This creates unacceptable coupling for a persistent procedural world.

Therefore the project must not use:

```text
one global RNG
one per-world mutable RNG sequence
one per-region mutable RNG shared by unrelated systems
one mutable RNG whose state is advanced by candidate acceptance/rejection
```

for persistent generation.

---

## 2. Seed derivation contract

All persistent procedural randomness derives from a pure function conceptually equivalent to:

```text
derived_seed = SeedDeriver.derive(
    world_seed,
    seed_schema_version,
    domain_id,
    domain_revision,
    stable_address,
    optional_subkey
)
```

Required properties:

1. same inputs always produce the same output;
2. input order is canonical and explicit;
3. changing load order does not change the output;
4. changing thread scheduling does not change the output;
5. another domain consuming more random values does not change the output;
6. rejected sibling candidates do not affect another candidate's seed;
7. a new unrelated generation subsystem can be added without changing existing domains;
8. the implementation is independent of locale/string formatting;
9. the implementation has fixed test vectors so engine/platform changes are detectable;
10. seed derivation never depends on runtime Node instance IDs, array position, dictionary iteration order, wall-clock time, or frame timing.

---

## 3. Root inputs

### 3.1 `world_seed` — LOCKED

The user/world seed is the root entropy input for deterministic world generation.

The same world seed under the same compatible generation contracts produces the same deterministic world definition.

### 3.2 `seed_schema_version` — LOCKED

Seed derivation has its own small compatibility version separate from gameplay save version and global generator version.

Conceptually:

```text
seed_schema_version = 1
```

This changes only if the fundamental canonical encoding/hash/derivation contract changes.

Changing it is a major compatibility boundary because it may alter every derived seed.

Do **not** bump it for ordinary tuning.

### 3.3 Do not automatically mix global `generator_version` into every seed — LOCKED

The global generator version records which generation contracts produced a world, but it must not automatically be part of every derived seed.

If every global generator-version bump changed every seed, changing one subsystem would reshuffle the entire world and defeat domain isolation.

Instead, each generation domain has its own explicit `domain_revision`.

Conceptually:

```text
GeneratorVersion 17
    surface_tree_distribution_revision = 3
    cave_primary_topology_revision = 1
    entrance_selection_revision = 2
    secondary_connectivity_revision = 1
```

A generator version is therefore a compatibility manifest, not a universal RNG salt.

---

## 4. Named generation domains

A **generation domain** is an explicit source of deterministic randomness with one semantic responsibility.

Examples:

```text
surface.height.continental
surface.height.rolling
surface.moisture
surface.tree.exists
surface.tree.offset
surface.tree.shape
surface.rock.exists
surface.pickup.branch.exists

underground.region.layout
underground.network.exists
underground.network.topology
underground.node.position
underground.node.shape
underground.entrance.exists
underground.entrance.profile
underground.secondary_connection.exists
underground.secondary_connection.shape
underground.special_location.exists
```

The exact registry grows with implementation, but the rule is permanent:

> If two random decisions should be able to change independently, they should not be forced through the same mutable RNG stream.

---

## 5. Domain IDs and revisions

### 5.1 Domain IDs are permanent identifiers — LOCKED

Every persistent generation domain has one canonical immutable identifier.

Implementation options include explicit numeric constants paired with readable names, for example:

```text
0x0101  surface.tree.exists
0x0102  surface.tree.offset
0x0201  underground.network.topology
```

The exact values are implementation detail, but once persistent worlds use a domain ID, its semantic meaning must never be reassigned.

Do not use implicit enum ordinals where inserting a new enum member renumbers later domains.

### 5.2 Domain revision — LOCKED

Each domain has an explicit revision number.

```text
(domain_id, domain_revision)
```

Changing the algorithm for one domain may increment only that domain revision when a different deterministic result is intended.

Examples:

```text
surface.tree.shape rev 1 -> rev 2
```

may alter tree variation without changing:

```text
surface.tree.exists
underground.network.topology
underground.entrance.profile
```

Whether an existing save/world is allowed to adopt the new revision is decided by generator-version policy later. The important architectural point is that unrelated randomness is not automatically changed.

### 5.3 Domain registry

The implementation should have one authoritative registry, conceptually:

```text
SeedDomains
    SURFACE_TREE_EXISTS
    SURFACE_TREE_OFFSET
    SURFACE_TREE_SHAPE
    UG_REGION_LAYOUT
    UG_NETWORK_TOPOLOGY
    UG_NODE_SHAPE
    UG_ENTRANCE_SELECTION
    UG_SECONDARY_CONNECTIVITY
    ...
```

Every entry defines:

```text
domain_id
readable_name
revision
```

Generator code must not invent ad-hoc salts such as `+ 12345` throughout the codebase.

---

## 6. Stable address is the randomness anchor

Seed derivation consumes the semantic `StableAddress`, not the final readable `StableId` string and not runtime position.

Example surface candidate:

```text
address:
    surface/tree/cell(401,-73)/slot-0

domains:
    surface.tree.exists
    surface.tree.offset
    surface.tree.shape
```

The same candidate may therefore have independent deterministic random sources:

```text
exists_seed = derive(address, SURFACE_TREE_EXISTS)
offset_seed = derive(address, SURFACE_TREE_OFFSET)
shape_seed  = derive(address, SURFACE_TREE_SHAPE)
```

Adding another visual property later does not need to advance `exists_seed` or `offset_seed`.

---

## 7. Property-level isolation versus local sequences

We do not need one seed domain for every single float in the game. That would become unmanageable.

Use this rule:

### Separate domains when a change should not perturb another semantic decision

Examples:

```text
tree existence      separate from tree appearance
entrance existence  separate from entrance descent shape
network topology    separate from detailed tunnel geometry
special-location placement separate from its visual variation
```

### Local deterministic RNG sequences are allowed inside one compatibility unit

For example, `surface.tree.shape` may use one local deterministic RNG to choose:

```text
scale
trunk proportion
rotation
variant
```

If the shape algorithm later changes its call sequence, only that candidate's shape domain changes; tree existence and caves remain unaffected.

If one of those properties later needs independent compatibility, split it into a new named domain.

---

## 8. Stateless values are preferred where practical

For simple decisions, prefer deriving a deterministic value directly from:

```text
(world_seed, domain, revision, address, subkey)
```

rather than creating a mutable RNG and consuming a sequence.

Conceptually:

```text
exists_roll = random_unit(address, TREE_EXISTS, "roll")
yaw         = random_unit(address, TREE_SHAPE, "yaw") * TAU
scale       = map_range(random_unit(address, TREE_SHAPE, "scale"), ...)
```

This gives maximum isolation.

For algorithms that naturally need many random samples, a local deterministic RNG seeded from the domain/address is acceptable.

---

## 9. Subkeys / forks

A domain may expose deterministic subkeys for multiple independent values without creating a new global domain.

Example:

```text
seed(address, SURFACE_TREE_SHAPE, "yaw")
seed(address, SURFACE_TREE_SHAPE, "scale")
seed(address, SURFACE_TREE_SHAPE, "variant")
```

Subkeys are semantic constants, not sequential counters derived from accepted-object order.

For fixed repeated candidate slots, the slot belongs in the stable address.

For local semantic properties, the property belongs in the subkey.

---

## 10. Project-owned deterministic PRNG contract — LOCKED DIRECTION

Persistent world generation must not depend on unspecified global engine RNG state.

The implementation should provide a small project-owned deterministic RNG/value interface with a frozen algorithm and fixed test vectors.

Conceptually:

```text
DeterministicRng(seed)
    next_u32()
    next_u64()
    unit_float()
    range_float(min, max)
    range_int(min, max)
```

or stateless equivalent functions.

Reasons:

- generation must remain reproducible across worker scheduling;
- engine RNG implementation changes should not silently regenerate worlds differently;
- deterministic tests need known input/output vectors;
- seed behavior becomes part of our world-generation contract rather than an undocumented engine detail.

The exact PRNG/hash algorithm is **OPEN until implementation**, but once selected for persistent generation it must be:

- explicitly documented;
- fixed-width integer based;
- platform-independent;
- tested with hard-coded vectors;
- versioned before replacement.

Runtime-only cosmetic randomness that is not persistent world truth may continue to use ordinary Godot randomness where appropriate.

---

## 11. Hash/seed derivation implementation requirements

The exact hash/mixer is not chosen in this document, but implementation must use one central `SeedDeriver` rather than scattered arithmetic.

Required properties:

```text
SeedDeriver
    canonical_encode(...)
    derive_seed(...)
    derive_value(... optional)
```

The canonical encoder must define the byte/integer representation of:

- signed coordinates;
- fixed semantic tags;
- stable candidate slots;
- endpoint IDs/addresses where required;
- subkeys;
- domain ID and revision;
- seed-schema version.

No locale-dependent decimal strings or floating-point formatting may participate.

Before any persistent world uses the new derivation implementation, commit test vectors such as:

```text
world_seed = 123456
address = surface/tree/cell(10,-4)/slot-0
domain = surface.tree.exists rev 1
expected derived seed = <fixed value>
```

Those vectors become compatibility tests.

---

## 12. Surface seed-domain model

### 12.1 Macro terrain/noise fields

Each persistent surface field has its own seed domain.

Conceptually:

```text
surface.height.continental
surface.height.rolling
surface.height.flatland
surface.height.ridge
surface.height.ridge_region
surface.height.valley
surface.height.detail
surface.moisture
surface.forest_pattern
surface.rock_pattern
```

These world-scale fields may derive one field seed from the world address/root plus their domain and then sample world coordinates continuously.

Adding a new noise field must not change existing field seeds.

### 12.2 Surface object candidates

Each stable candidate gets independent local decisions.

Tree example:

```text
StableAddress = surface/tree/cell(x,z)/slot-0

TREE_EXISTS -> spawn roll
TREE_OFFSET -> jitter inside candidate cell
TREE_SHAPE  -> scale/yaw/variant
```

Rock and pickup candidates use their own domains.

### 12.3 Candidate rejection does not advance siblings

Wrong:

```text
for cells:
    x = rng.randf()
    if rejected:
        continue
    yaw = rng.randf()
```

because one rejection changes every later call.

Correct:

```text
for candidate_address in canonical candidate cells:
    local = derive(candidate_address, relevant domain)
```

Each candidate is independent.

---

## 13. Underground seed-domain model

The Underworld uses the same principle at each hierarchy level.

### 13.1 Macro region

Conceptual domains:

```text
ug.region.exists/layout
ug.region.depth_bias
ug.region.network_candidate_count_or_slots
ug.region.special_candidate_slots
```

Address anchor:

```text
underground/region(rx,rz)
```

### 13.2 Network candidate

Conceptual domains:

```text
ug.network.exists
ug.network.topology
ug.network.depth_grammar
ug.network.anchor_position
```

Address anchor:

```text
region/.../network(slot-N)
```

A rejected network slot does not shift later network seeds.

### 13.3 Node candidate

Conceptual domains:

```text
ug.node.exists
ug.node.position
ug.node.profile_blend
ug.node.semantic_type
ug.node.geometry_tendency
```

Address anchor is the node candidate lineage defined in `STABLE_PROCEDURAL_IDS.md`.

### 13.4 Primary edge

Conceptual domains:

```text
ug.primary_edge.exists
ug.primary_edge.topology_parameters
ug.primary_edge.geometry_tendency
```

Topology decisions and detailed geometry are separate domains so remeshing/tunnel-shape changes do not necessarily change graph connectivity.

### 13.5 Entrances

Conceptual domains:

```text
ug.entrance.exists
ug.entrance.surface_candidate
ug.entrance.connected_depth
ug.entrance.descent_profile
ug.entrance.geometry_tendency
```

The same stable entrance slot can keep its identity even if some generated properties are revised under an intentional generator update.

The v0.10 registry implements these concerns as `ug.entrance.selection`,
`ug.entrance.profile`, `ug.entrance.surface` and `ug.entrance.geometry` domains.
Topology target/depth scoring is part of selection; surface candidate variation
is isolated from descent-profile selection.

### 13.6 Secondary connectivity

A secondary connector candidate uses its canonical ordered endpoints/owner address.

Conceptual domains:

```text
ug.secondary.score_variation
ug.secondary.acceptance
ug.secondary.connection_class
ug.secondary.geometry_tendency
```

Generating region A before B or B before A must derive identical connector randomness.

### 13.7 Special-location hooks

Conceptual domains:

```text
ug.special.exists
ug.special.kind
ug.special.anchor_adjustment
ug.special.local_layout
```

Boss, structure, ore and ecology systems may later introduce their own domains without changing topology domains.

---

## 14. Topology randomness and geometry randomness must be separated

This is a critical rule for the Underworld.

```text
TOPOLOGY DOMAINS
    decide what exists / what connects

GEOMETRY DOMAINS
    decide detailed shape of already-defined topology
```

Example:

```text
network topology says:
Node A -- Edge E -- Node B
```

A later tunnel-meshing improvement may alter curvature, cross-section or wall noise using geometry-domain revisions without silently deciding that Node B no longer exists.

Topology compatibility remains independently testable.

---

## 15. Depth-profile randomness

Shallow/mid/deep profile weights are generated data, not one shared random stream.

The architecture should support deterministic functions/domains for:

```text
regional depth bias
node depth/profile blend
local exception probability
network grammar variation
```

A profile uses those deterministic inputs to parameterize generation distributions.

The exact depth curves remain open, but their randomness must be address/domain derived.

---

## 16. Canonical candidate enumeration

Some algorithms need to inspect a set of candidates together—for example secondary cave connections.

The rule is:

1. candidates have stable addresses before scoring;
2. enumerate/sort them canonically by stable address or another explicitly deterministic key;
3. derive each candidate's random terms from its own address/domain;
4. score deterministically;
5. resolve conflicts/ties with canonical deterministic rules, not dictionary order.

If two candidates have identical numeric score, use a stable tiebreaker such as canonical stable-address ordering or a dedicated deterministic tiebreak domain.

Do not resolve ties by "whichever thread finished first."

---

## 17. Parallel generation

Seed domains make generation naturally parallel-safe at the randomness layer.

Worker tasks may generate:

```text
region A
region B
surface chunk C
surface chunk D
```

in any order because each local decision derives its own seed.

Shared mutable RNG objects must not cross worker boundaries.

This does not remove the need for deterministic ownership/conflict-resolution rules when generated definitions interact across regions. Those are handled by graph/ownership architecture.

---

## 18. Cross-region deterministic ownership

For a cross-region candidate connection:

```text
canonical_region_pair = sort(region_A, region_B)
canonical_endpoints = sort(endpoint_A, endpoint_B)
owner = canonical owner rule
address = owner + endpoint pair + connector slot/class
```

All randomness derives from that canonical address.

Therefore:

```text
generate A then B
```

and:

```text
generate B then A
```

must produce the same candidate identity, seed, acceptance result and final connector definition.

---

## 19. Generator compatibility and domain revisions

Seed isolation does not mean every generation update can transparently modify an existing world.

There are three broad cases:

### Compatible implementation refactor

Algorithm/output unchanged.

```text
no domain revision change
no generator compatibility change
```

### Intentional local generation change

Example: tree visual distribution changes.

```text
increment only SURFACE_TREE_SHAPE revision
record in generator-version manifest
```

Whether existing worlds adopt it depends on persistence/version policy.

### Fundamental seed-contract change

Example: canonical address encoding or project PRNG changes incompatibly.

```text
seed_schema_version changes
major generator compatibility boundary
```

This should be rare.

---

## 20. Current prototype migration considerations

The existing surface prototype currently uses several seed styles:

```text
world_seed + fixed noise offsets
chunk-mixed RNG for trees/rocks
separate chunk-mixed RNG for loose pickups
```

Those are deterministic today but not the final architecture because some candidate properties share mutable per-chunk RNG sequences.

Do not destroy the legacy mapping before save migration described in `STABLE_PROCEDURAL_IDS.md` is implemented.

The migration adapter may retain/freeze the old RNG behavior solely to reconstruct old accepted indexes.

After migration, new persistent generation should use stable-address seed domains.

Changing legacy surface terrain/noise fields to the new domain system is a separate generator-compatibility decision. It must not be treated as a harmless refactor if it changes existing terrain output.

---

## 21. Noise-generator compatibility

Seed domains solve **seed isolation**, not every possible source of generator drift.

If a persistent world field uses FastNoiseLite or another algorithm, deterministic output also depends on:

```text
noise algorithm
configuration
engine/library behavior
sampling coordinates
```

Therefore generation fingerprints/tests must detect output changes after engine upgrades.

If an engine/library upgrade changes persistent world output unexpectedly, treat that as a generator compatibility issue rather than silently accepting it.

We do not need to vendor/custom-build every noise algorithm now; we do need tests that tell us when output changed.

---

## 22. Runtime randomness is a separate category

Not every random event needs persistent seed-domain identity.

Examples that may use runtime randomness depending on gameplay design:

```text
purely cosmetic particles
nonpersistent sound variation
camera shake variation
temporary visual debris
```

Examples that require deterministic/persisted handling when generated as world truth:

```text
cave topology
generated entrances
ore-deposit placement
permanent structures
persistent resource nodes
persistent special locations
```

Creature simulation/combat RNG will receive its own gameplay architecture if needed; it does not belong in the world-generation seed registry merely because it is random.

---

## 23. Initial implementation interfaces

The first implementation should converge on three small pieces rather than spreading seed logic through generators.

### `SeedDomains`

Authoritative domain registry:

```text
domain ID
readable name
revision
```

### `SeedDeriver`

Pure deterministic functions:

```text
derive_seed(world_seed, stable_address, domain, subkey?)
derive_unit_value(... optional)
```

### `DeterministicRng`

Frozen local PRNG for algorithms that need a sequence:

```text
seeded only from SeedDeriver
never shared between unrelated candidates/systems
```

Generator modules depend on these interfaces; they do not invent their own seed mixing.

---

## 24. Validation requirements

The automated harness must test seed architecture before large cave generation lands.

Required tests:

1. same input tuple produces identical derived seed;
2. fixed hard-coded test vectors pass;
3. generation order does not alter candidate seeds;
4. worker scheduling does not alter candidate seeds;
5. adding/consuming random values in one domain does not alter another domain;
6. rejecting candidate N does not alter candidate N+1;
7. adding a new domain does not renumber/change existing domain IDs;
8. changing one domain revision changes that domain while unrelated domains remain identical;
9. canonical cross-region endpoint order produces the same seed from either direction;
10. stable-address canonical encoding is identical for negative coordinates and boundary cases across supported platforms;
11. canonical graph fingerprints remain identical across repeated runs;
12. engine upgrades are checked against representative terrain/noise fingerprints.

Useful failure output:

```text
seed_schema_version
world_seed
domain_id/domain_name/domain_revision
stable_address
subkey
expected_seed
actual_seed
generator_version
```

---

## 25. Anti-patterns — FORBIDDEN

Do not introduce any of these into persistent procedural generation:

```text
RandomNumberGenerator.randomize()
Time.get_ticks_* as generation entropy
OS time/date as generation entropy
runtime Node instance ID as a seed
array index of accepted objects as a seed
shared RNG passed through multiple unrelated generators
implicit enum ordinal as persistent domain ID
ad-hoc world_seed + magic_number salts scattered across files
dictionary iteration order deciding random sequence or tie result
thread completion order deciding generation result
float-formatted position strings as canonical seed addresses
```

A local prototype may use temporary randomness only if it cannot enter persistent world truth. Otherwise it must use the deterministic architecture.

---

## 26. What is intentionally still open

The following are **OPEN until implementation**, but must be frozen with test vectors before persistent generation depends on them:

- exact project-owned hash/mixing algorithm;
- exact project-owned PRNG algorithm;
- exact numeric domain IDs;
- exact canonical binary encoding of `StableAddress` components;
- exact domain granularity for systems not yet implemented;
- exact generator-version manifest format.

These are low-level representation choices. The architectural contract—stable address + named domain + explicit revision + no shared mutable RNG—is locked.
