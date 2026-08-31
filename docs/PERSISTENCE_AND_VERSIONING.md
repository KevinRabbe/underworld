# Underworld — Persistence and Generator Versioning Architecture

Status: **LOCKED architecture; updated for explicit world domains**

This document defines how saves reference deterministic generated truth, how durable deltas survive streaming, how Player location is represented across independent world domains, and how generator changes are classified/migrated safely.

Related current architecture:
- [`00_project/ADR-001_TWO_WORLD_DOMAINS.md`](00_project/ADR-001_TWO_WORLD_DOMAINS.md)
- [`20_world/WORLD_DOMAINS_AND_TRANSITIONS.md`](20_world/WORLD_DOMAINS_AND_TRANSITIONS.md)
- [`STREAMING_OWNERSHIP.md`](STREAMING_OWNERSHIP.md)

Core rule:

> **A save stores compact durable semantic state against explicitly identified deterministic generation contracts. Runtime Nodes/caches are reconstructed, not persisted as world truth.**

---

## 1. Root world and domain identity — LOCKED

One save/world owns one root identity, but contains independent procedural domains.

Conceptually:

```text
RootWorld
- world_id
- root seed
- pinned generator manifest/package
- OVERWORLD domain contract/state
- UNDERWORLD domain contract/state
```

`OVERWORLD` and `UNDERWORLD` positions are domain-local. Numeric coordinates are meaningless without the owning domain.

No save/migration code may infer that identical XYZ coordinates in different domains refer to the same physical place.

---

## 2. Domain-qualified Player location — LOCKED

A durable Player location is conceptually:

```text
PlayerWorldLocation
- active_domain
- domain_local_transform
```

The saved domain is authoritative.

Saving in the Underworld does not require an equivalent Overworld position. Saving in the Overworld does not require an equivalent Underworld position.

A gateway/paired-return reference is saved only when gameplay semantics require it; it is never reconstructed by nearest-coordinate guessing.

### Continue

Continue conceptually performs:

```text
read save + active_domain
-> validate pinned domain generator contract
-> reconstruct required deterministic domain truth
-> apply durable domain/player deltas
-> prepare bounded render/collision support around exact saved transform
-> instantiate/activate Player
-> release physics/control only after local safety readiness
```

Loading an Underworld save must not require first constructing the Overworld runtime.

---

## 3. Saved versus regenerated — LOCKED

### Regenerated from pinned deterministic contracts

```text
untouched Overworld terrain/placements
untouched Underworld topology/base geometry
untouched deterministic gateway/source/destination sites
untouched procedural structures/objects
special-location hooks
other deterministic definitions
```

### Saved durable state

```text
Player inventory/equipment/progression
Player active domain + exact domain-local transform
harvested/removed generated StableIds
persistent resource/object state
WorldDelta terrain/material changes
player-built structures
special-location mutable state
required gateway/transition semantic state
other explicit persistent simulation state
```

Do not serialize entire visited regions/networks/cell scenes merely because they were loaded.

---

## 4. `WorldDeltaStore` ownership

`WorldDeltaStore` or the accepted equivalent is the logical authority for persistent generated-world modifications.

Responsibilities include:
- load/validate durable world state;
- expose bounded read-only delta views;
- apply explicit durable mutations;
- track dirty categories/shards;
- serialize safely/atomically;
- run migrations;
- quarantine unresolved references.

Runtime chunks/cells may cache/query deltas but never own them durably.

Domain should be part of spatial/state ownership wherever an identity alone does not already unambiguously encode it.

---

## 5. Version concepts remain separate — LOCKED

Do not overload one `version` integer.

Keep separately identifiable:
- `save_schema_version` — serialized layout;
- `seed_schema_version` — canonical seed derivation;
- stable-address/StableId schema semantics;
- generator stage revisions;
- named seed-domain revisions;
- domain generator configuration revisions;
- root `GeneratorManifest`/manifest package identity.

A save-schema migration need not change generated worlds. A generator change need not imply a save-layout change.

---

## 6. Generator manifest — LOCKED DIRECTION

The root world pins enough immutable configuration to reproduce deterministic truth.

Conceptually:

```text
GeneratorManifest
- manifest schema/id/fingerprint
- seed schema
- stable-address schema
- Overworld stage/domain revisions
- Underworld stage/domain revisions
- persistent noise/algorithm revisions
- profile/config revisions
- gateway-linking revision/config where deterministic
```

The manifest must pin generation configuration, not merely code labels.

Old worlds must not silently read today's mutable defaults if those defaults changed.

Manifest identity is compatibility/cache identity, not a universal RNG salt.

---

## 7. Domain generator isolation

A compatible/disjoint change in one domain must not automatically reshuffle the other domain.

Examples:
- changing an Overworld tree-shape seed domain should not move Underworld cave networks;
- changing Underworld mesh extraction should not move Overworld gateways unless the semantic gateway-link contract itself changed;
- presentation changes never revise deterministic world identity.

Root manifest changes may reference updated component revisions while preserving unaffected domains byte-for-byte.

---

## 8. Modern save header direction

Conceptually:

```text
WorldSaveHeader
- save_schema_version
- world_seed
- world_id
- generator_manifest_id
- manifest/config snapshot or immutable reference
```

Player section conceptually includes:

```text
player
- active_domain
- domain_local_transform
- inventory/equipment/progression
- other accepted durable player state
```

Exact physical JSON/binary layout is not locked.

---

## 9. Durable delta categories

### Generated-object state

```text
destroyed_objects : Set<StableId>
object_state       : Map<StableId, state>
```

### Special-location state

```text
special_location_state : Map<StableId, state>
```

### Terrain/material changes
Domain-qualified spatial modifications against deterministic base geometry.

### Player-created objects
Player-built pieces are a distinct identity family; they are not procedural candidate StableAddresses.

A placed building record persists compact semantic identity/state such as:
- build instance ID;
- piece definition ID;
- domain-local transform;
- mutable durability/permissions/customization state;
- logical connection data only where required.

Render batches, runtime Nodes and LODs are not saved identity.

---

## 10. Logical store may be physically sharded

A small prototype may use one file. Long-lived worlds may use:

```text
header/index
player state
Overworld region delta shards
Underworld region/cell delta shards
construction shards
special-state shards
```

Runtime callers should see one logical persistence API regardless of physical sharding.

---

## 11. Bounded spatial queries — LOCKED DIRECTION

As worlds grow, runtime streaming must not scan the complete save for every active cell.

Conceptually:

```text
WorldDeltaStore.query(domain, bounds, identities/categories)
    -> WorldDeltaView
```

Runtime cost should follow current relevance, not total accumulated world history.

This is required for large player constructions, harvested worlds and long Underworld exploration histories.

---

## 12. Compatibility classification — LOCKED

Loading classifies generation compatibility explicitly:

```text
EXACT
SUPPORTED_LEGACY
MIGRATION_REQUIRED
INCOMPATIBLE
UNKNOWN/CORRUPT
```

Never silently interpret `INCOMPATIBLE`/unknown state under today's generator.

Compatible refactors require unchanged deterministic vectors/fingerprints/StableIds for the affected contract.

---

## 13. Intentional generator changes

Local changes revise only the contracts they actually alter.

A fundamental change such as:
- seed-schema replacement;
- stable candidate lattice change;
- topology identity rewrite;
- gateway-link identity change;
- obsolete algorithm becoming unreproducible

creates an explicit compatibility boundary.

Possible policy:
- retain legacy generator;
- deterministic migration;
- selective regeneration with mapped deltas;
- require a new world / mark incompatible.

Arbitrary future generators are not promised perfect migration; incompatibility must simply be explicit and safe.

---

## 14. Migration pipeline — LOCKED

Conceptually:

```text
1. parse/validate old envelope
2. identify old save schema + generator contract
3. migrate serialization to canonical intermediate
4. classify generation compatibility
5. run explicit identity/domain/delta migration adapters
6. validate migrated references/state
7. write new save atomically
8. activate only after success
```

Never partially mutate the only valid save while migration is incomplete.

---

## 15. One-world -> two-domain migration direction

The 2026-08-31 ADR changes the meaning of player/world coordinates at the domain boundary.

Migration must therefore be explicit when older saves encode one global Player position.

Rules:
- never guess domain from numeric Y alone;
- use trustworthy accepted semantic/runtime history available in the old save/schema where possible;
- prototype/unsupported saves may be declared incompatible if no safe deterministic mapping exists;
- where old accepted Underworld position data is known to represent a real Underworld runtime position, migrate it into `active_domain=UNDERWORLD` + unchanged Underworld-local transform only through a versioned tested adapter;
- Overworld saves become `active_domain=OVERWORLD` with their Overworld-local transform;
- physical entrance cutout data is not required as durable gateway identity;
- gateway pairing/source/destination identity is migrated only from explicit semantic evidence, never nearest-coordinate inference.

Before public/stable release, this migration policy must be covered by fixtures for every supported old schema.

---

## 16. Existing prototype-v2 migration

Historical `version=2` surface IDs such as:

```text
chunk_x:chunk_z:type:accepted_index
```

remain a known legacy contract.

Before incompatible surface candidate tuning, map these through the frozen legacy generator to modern semantic addresses/StableIds. Unresolvable IDs are diagnostic/quarantined, not assigned to a nearby object.

The two-domain decision does not make unsafe legacy identity guessing acceptable.

---

## 17. Position is not generic identity recovery — LOCKED

Never recover StableIds/gateway identity by "closest object" as a generic fallback.

Position may participate only in an explicitly designed/tested migration for a specific old contract.

Different domains make nearest-position guessing even less meaningful because their coordinates are independent.

---

## 18. Terrain/deformation compatibility

Terrain/material deltas are spatial changes against deterministic base geometry and must carry enough domain/base-contract context to reject incompatible application.

Conceptually:

```text
domain
world/manifest identity
surface/geometry cell address
base geometry revision/fingerprint where useful
```

Do not apply old excavation bytes to unrelated regenerated geometry.

Overworld excavation never implicitly modifies Underworld geometry merely because numeric coordinates overlap.

---

## 19. Cache versioning

Caches are disposable but cannot serve the wrong deterministic contract.

Keys/headers include sufficient identity, e.g.:

```text
WorldId
WorldDomain
GeneratorManifest/domain revision
region/cell address
dependency fingerprint
```

Incompatible cache data is discarded/regenerated.

---

## 20. Save write safety — LOCKED DIRECTION

A failed save must not destroy the previous valid save.

Simple single-file direction:

```text
serialize new payload
-> write temporary
-> flush/close
-> validate required envelope/checksum
-> safely replace active save
```

Future sharded storage uses indexed/transactional commit semantics.

---

## 21. Migration fixtures

Every supported migration path needs deterministic fixtures.

For domain migration include at least:
- Overworld save/Continue;
- Underworld save/Continue;
- exact domain-local position preservation;
- near-boundary Underworld position requiring bounded collision support;
- world deltas in both domains;
- unresolved/invalid gateway reference;
- paired gateway state where durable semantics require it.

A successful migration must never create two active Player states or silently relocate to an unrelated gateway.

---

## 22. Exploration state is not generation state

Future map discovery, known gateways, fog-of-war and markers are player metadata/deltas.

They do not become deterministic generator input merely because they reference world sites.

---

## 23. Runtime modification flow

Conceptually:

```text
player action
-> gameplay validates
-> durable semantic delta committed
-> relevant runtime representation notified/rebuilt
-> save transaction according to policy
```

The runtime chunk/cell/Node never becomes the save authority.

---

## 24. Persistence invariants

1. Save schema and generator contracts are separately identifiable.
2. Player location is always domain-qualified in modern architecture.
3. Overworld and Underworld transforms are domain-local and never implicitly converted.
4. Continue reconstructs the saved active domain directly.
5. Player physics/control waits for required local destination collision readiness.
6. Untouched deterministic truth regenerates rather than serializing visited runtime scenes.
7. Generated-object deltas use stable semantic identity.
8. Player-created objects use their own persistent identity family.
9. Runtime/cell/instance indexes never enter durable identity.
10. Cache eviction cannot erase durable state.
11. Old/incompatible deltas are never silently interpreted under a different generator.
12. Migration failures preserve the previous good save.
13. Unresolved references are diagnostic/quarantined, not guessed.
14. Cross-domain gateway identity is semantic, not nearest-coordinate reconstruction.
15. Overworld changes never implicitly mutate Underworld state merely because coordinates overlap numerically.

---

## 25. Intentionally open

- exact save file/database format;
- physical sharding/index strategy;
- compression/checksums/backups;
- exact user-created build-instance ID format;
- exact terrain deformation representation;
- long-term legacy generator support window;
- autosave policy/UI;
- manifest canonical serialization;
- final gateway-state persistence fields beyond active domain + Player transform.

These may evolve without weakening the locked domain-qualified persistence and explicit compatibility rules.