# Underworld — Deterministic Generation Seed Domains

Status: **LOCKED deterministic-randomness architecture; updated for separate world domains**

This document defines how persistent procedural decisions obtain deterministic randomness without depending on load order, worker scheduling, candidate acceptance count or unrelated RNG calls.

Related:
- [`00_project/ADR-001_TWO_WORLD_DOMAINS.md`](00_project/ADR-001_TWO_WORLD_DOMAINS.md)
- [`20_world/UNDERWORLD_GENERATION_PIPELINE.md`](20_world/UNDERWORLD_GENERATION_PIPELINE.md)
- [`STABLE_PROCEDURAL_IDS.md`](STABLE_PROCEDURAL_IDS.md)

Core rule:

> **Every persistent random decision derives from a named immutable semantic domain/revision and a stable semantic address. There is no shared mutable world-generation RNG stream.**

---

## 1. Seed derivation

Conceptually:

```text
derived_seed = SeedDeriver.derive(
    root_world_seed,
    seed_schema_version,
    domain_id,
    domain_revision,
    stable_address,
    optional_subkey
)
```

Required properties:
1. same inputs -> same output;
2. canonical encoding;
3. load order independent;
4. worker order independent;
5. unrelated RNG consumption independent;
6. rejected siblings cannot shift another candidate;
7. adding unrelated systems cannot perturb existing domains;
8. no locale/float-string ambiguity;
9. fixed test vectors protect compatibility;
10. runtime Node/index/time/frame data never participates.

---

## 2. Root seed and domain namespaces

One root world seed may deterministically derive independent semantic namespaces for Overworld, Underworld and world-level gateway linking.

Conceptually:

```text
root seed
├─ surface.* / overworld.* domains
├─ ug.* / underworld.* domains
└─ gateway.* world-link domains
```

This does **not** mean hashing one mutable domain seed and consuming a long shared sequence. Every persistent decision still uses its own named domain/address.

Changing one Overworld domain must not automatically reshuffle Underworld topology. Changing Underworld geometry must not automatically move Overworld sites.

---

## 3. Version concepts

### `seed_schema_version`
Changes only when the fundamental canonical encoding/derivation algorithm changes. This is a major compatibility boundary.

### domain revision
Each immutable domain ID/name has its own revision.

A deliberate algorithm/output change increments only the affected domain revision where possible.

### generator manifest
Records the compatible collection of domain/stage/config revisions. It is not automatically mixed into every derived seed as universal entropy.

---

## 4. Domain semantic immutability — LOCKED

Once persistent worlds use a domain identifier, its semantic meaning never changes.

Do not:
- reuse an old ID/name for a different decision;
- use insertion-sensitive enum ordinals;
- scatter magic numeric salts;
- reinterpret an old entrance-surface domain as a new cross-domain gateway-link domain.

If architecture changes, **add a new domain** and preserve the old domain for legacy generator contracts/migration.

This rule is critical to the 2026-08-31 two-world transition.

---

## 5. StableAddress is the randomness anchor

Seed derivation consumes semantic StableAddress components, not:
- runtime array index;
- Node ID;
- render/collision handle;
- floating-point formatted position;
- dictionary iteration order;
- readable StableId formatting as accidental entropy.

Example:

```text
surface/tree/cell(401,-73)/slot-0
    + surface.tree.exists
    + surface.tree.offset
    + surface.tree.shape
```

Each concern may evolve independently.

---

## 6. Stateless values and local sequences

Prefer stateless semantic subkeys where practical:

```text
random_unit(address, TREE_SHAPE, "yaw")
random_unit(address, TREE_SHAPE, "scale")
```

A local deterministic RNG sequence is allowed inside one semantic compatibility unit when an algorithm naturally needs many samples.

If one property later needs independent compatibility, split it into its own subkey/domain rather than changing unrelated decisions.

---

## 7. Project-owned deterministic primitive — LOCKED DIRECTION

Persistent generation uses a project-owned/frozen deterministic seed/value/RNG contract with:
- fixed-width integer behavior;
- platform-independent results;
- canonical input encoding;
- hard-coded test vectors;
- explicit versioning before replacement.

Runtime-only cosmetic randomness may use ordinary engine randomness when it has no persistent semantic effect.

---

## 8. Overworld domain examples

Examples of independently versioned persistent decisions:

```text
surface.height.continental
surface.height.rolling
surface.height.ridge
surface.moisture
surface.forest_pattern
surface.tree.exists
surface.tree.offset
surface.tree.shape
surface.rock.exists
surface.pickup.branch.exists
overworld.gateway_site.exists
overworld.gateway_site.family
overworld.gateway_site.local_layout
```

Exact registry entries evolve with implementation.

Candidate rejection never advances sibling randomness because each candidate uses its own address/domain.

---

## 9. Underworld domain examples

Examples:

```text
ug.region.layout
ug.region.depth_bias
ug.network.exists
ug.network.topology
ug.network.depth_grammar
ug.node.exists
ug.node.position
ug.node.profile_blend
ug.primary_edge.exists
ug.primary_edge.geometry
ug.entry_site.exists
ug.entry_site.profile
ug.entry_site.local_layout
ug.secondary.acceptance
ug.secondary.geometry
ug.special.exists
ug.special.kind
```

Topology decisions and detailed geometry remain separate domains so remeshing does not implicitly rewrite cave connectivity.

---

## 10. Gateway-link domains — NEW ACTIVE SEMANTICS

Cross-domain linkage receives **new** domains rather than reusing old physical-entrance domains.

Conceptual examples:

```text
gateway.link.candidate
gateway.link.acceptance
gateway.link.destination_choice
gateway.link.directionality
gateway.link.coarse_region_bias
```

Addressing must use canonical semantic source/destination site identities or candidate slots, not numeric position conversion.

Conceptually:

```text
source Overworld gateway-site address
+ destination Underworld entry-site address/candidate
+ gateway link domain/revision
-> deterministic link decision
```

Gateway randomness must remain independent from presentation such as cave-mouth mesh, loading screen, tunnel animation or portal VFX.

---

## 11. Legacy physical-entrance domains — FROZEN COMPATIBILITY

Historical generator contracts may already contain domains such as:

```text
ug.entrance.exists
ug.entrance.selection
ug.entrance.profile
ug.entrance.surface
ug.entrance.geometry
```

These names/IDs **retain their original semantic meaning** for the generator revisions that used them.

In particular, `ug.entrance.surface` is not renamed or redefined to mean generic cross-domain gateway linkage.

Migration direction:
- legacy worlds reproduce those old decisions with the frozen old revision;
- useful semantic entrance identity may map to a new Underworld entry site through an explicit adapter;
- new worlds/algorithms use new entry-site/gateway-link domains;
- old domain IDs remain reserved forever even after no current generator uses them.

This preserves deterministic compatibility while allowing architecture to evolve.

---

## 12. Domain-local Underworld depth randomness

Shallow/mid/deep grammar randomness derives from Underworld-domain addresses/metrics.

Possible concerns:

```text
ug.region.depth_bias
ug.node.profile_blend
ug.network.depth_grammar
ug.depth.local_exception
```

No persistent random decision requires sampling Overworld surface height after ADR-001.

Gateway-link policy may choose a destination depth/site class deterministically, but that is an explicit gateway-link decision, not shared coordinate geometry.

---

## 13. Secondary/cross-region determinism

A secondary connector candidate uses canonical region/endpoint ownership.

Conceptually:

```text
canonical endpoint pair
+ canonical owner region
+ connector candidate slot
+ ug.secondary.* domain
```

Generating region A then B versus B then A yields the same connector identity/randomness.

Tie/conflict resolution uses canonical deterministic order, not dictionary/worker completion order.

---

## 14. Special-location isolation

Boss/structure/resource/ecology site decisions use separate semantic domains from topology.

Adding a new ore family must not automatically alter which cave networks exist.

Likewise a visual asset variation never consumes persistent topology randomness.

---

## 15. Canonical candidate enumeration

For algorithms comparing multiple candidates:
1. assign stable candidate addresses first;
2. enumerate/sort canonically;
3. derive random terms per candidate address/domain;
4. score deterministically;
5. resolve ties/conflicts canonically;
6. accept/reject without renumbering identities.

This applies to topology, secondary connections, placements and gateway linking.

---

## 16. Engine/noise drift

Named seed domains do not by themselves freeze engine/library noise output.

Persistent terrain/noise algorithms require representative deterministic fingerprints/test vectors so engine upgrades cannot silently reshape old worlds.

If an old algorithm is no longer reproducible, generator compatibility must classify/migrate the world explicitly.

---

## 17. Presentation randomness

Presentation variation that is not persistent world truth may use separate presentation seeds/runtime randomness.

Never let:
- wind phase;
- particle spawn order;
- shader noise;
- animation variation;
- UI effects

become hidden inputs to deterministic world identity.

If a visual variant must be persistent/gameplay-semantic, give it an explicit authored/generated domain instead.

---

## 18. Validation requirements

The seed architecture requires:
- hard-coded SeedDeriver/PRNG vectors;
- representative Overworld domain vectors;
- representative Underworld topology/geometry vectors;
- gateway-link vectors;
- candidate rejection invariance;
- reverse/scheduling-order invariance;
- cross-region connector invariance;
- proof that changing one isolated domain revision does not alter unrelated domain outputs;
- legacy physical-entrance domain fixtures where supported;
- root-world same-seed reproducibility across runs.

For the two-world architecture specifically prove:
1. an Overworld-only compatible change does not change Underworld topology fingerprints;
2. a new gateway-link revision does not silently reseed source/destination site existence;
3. legacy `ug.entrance.surface` vectors remain unchanged for supported legacy manifests;
4. new gateway linking does not depend on shared numeric XYZ coordinates.

---

## 19. Domain registry governance

One authoritative registry owns:

```text
domain_id
readable_name
revision
status: active | legacy-reserved
semantic description
```

Rules:
- no duplicate IDs;
- no semantic reassignment;
- legacy IDs remain reserved;
- new persistent systems register before use;
- arbitrary magic salts in generator code are forbidden;
- revision changes require corresponding deterministic evidence/manifest updates.

---

## Locked invariants

1. No shared mutable persistent world-generation RNG.
2. Stable semantic addresses anchor persistent randomness.
3. Domain IDs never change semantic meaning.
4. Rejected candidates do not perturb siblings.
5. Load/thread order cannot change results.
6. Global generator manifest is not universal RNG salt.
7. Overworld, Underworld and gateway-link decisions can evolve independently.
8. Legacy physical-entrance domains retain their historical semantics and are never repurposed.
9. Underworld topology randomness remains separate from detailed geometry randomness.
10. Persistent engine/noise contracts require drift detection.
11. Runtime/presentation randomness cannot silently become world truth.
12. New cross-domain gateway linking uses explicit new semantic domains rather than coordinate equality or old entrance-surface salts.

## Intentionally open

- exact low-level PRNG/mixer if not already frozen by implementation;
- exact new gateway-link domain numeric IDs;
- exact future entry-site domain split;
- which visual variations are persistent versus presentation-only;
- long-term legacy-domain support policy after public release.

Open values do not permit reusing an existing persistent domain ID for a new meaning.