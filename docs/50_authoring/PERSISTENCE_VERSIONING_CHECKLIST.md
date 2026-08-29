# Persistence and Versioning Implementation Checklist

Status: **implementation/review checklist derived from locked architecture**

Use this checklist when adding or changing gameplay state that may survive reloads, world streaming, definition changes, or generator revisions. It does not define a new save format. The authoritative persistence contract remains [Persistence and Generator Versioning](../PERSISTENCE_AND_VERSIONING.md).

Related authority:
- [Technical Architecture](../TECHNICAL_ARCHITECTURE.md)
- [Building System Architecture](../30_gameplay/BUILDING_SYSTEM.md)
- [Item, Inventory and Crafting Architecture](../30_gameplay/ITEM_INVENTORY_CRAFTING.md)
- [Replaceable Presentation Boundary](../10_architecture/PRESENTATION_BOUNDARY.md)
- [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md)

## 1. Classify the state before storing it

Before adding a field to durable state, answer:

- [ ] Is this **deterministic base truth** that should be regenerated from the pinned world/generator contract instead of saved?
- [ ] Is this an explicit **player/world delta** that must survive reload and streaming?
- [ ] Is this **player-created persistent state** with its own instance identity?
- [ ] Is this only a **runtime cache/handle/view** that should be rebuilt and never serialized as authority?
- [ ] Is this only **presentation state** that may change when assets/rendering change?

Examples of regenerated truth include untouched terrain, cave topology, base geometry, procedural placements and entrances. Examples of durable state include harvested/removed generated objects, mutable persistent object state, terrain/deformation deltas, inventory/progression and player-built structures.

**Reject the design if a runtime cell/chunk/Node is becoming the owner of durable state.**

## 2. Choose the correct identity category

For every persisted reference, identify what kind of identity it is.

- [ ] Procedurally generated world objects use the accepted deterministic `StableId` / stable-address ownership contract.
- [ ] Authored definitions use stable semantic content IDs rather than file paths or display names.
- [ ] Individually stateful owned items use their persistent item-instance identity only when per-copy state requires it.
- [ ] Fungible resources remain stack state rather than receiving one persistent ID per unit.
- [ ] Player-created objects such as placed building pieces use a separate persistent instance identity rather than pretending to be procedural candidates.
- [ ] Runtime indexes, array positions, `Node` instance IDs, `MultiMesh` indexes and memory/resource identities are not durable IDs.

If a reference is persisted, it must still identify the same logical thing after unloading/reloading its runtime representation.

## 3. Keep definitions, instances and presentation separate

When persisting gameplay objects:

- [ ] Store the semantic definition identity needed to reconstruct the object.
- [ ] Store only mutable instance/stack state that must survive.
- [ ] Keep meshes, materials, shaders, icons, animation clips, scene paths and runtime presentation handles out of authoritative save identity.
- [ ] Ensure presentation can be replaced or rebuilt without migrating the logical object merely because an asset changed.

For building state, preserve logical placed-instance identity, transform/connections and explicitly durable gameplay state as required by the building contract—not render batches or active streaming-cell state.

For item/container state, persist semantic item identity, quantity and required stack/per-instance state—not UI widgets, slot-view objects, mesh paths or runtime Nodes.

## 4. Declare version ownership explicitly

Before introducing a persisted structure or changing an existing one, identify which compatibility concept owns the change.

- [ ] `save_schema_version` covers serialized layout/schema changes.
- [ ] `seed_schema_version` covers the fundamental deterministic seed-derivation contract.
- [ ] stable-address schema/version semantics cover persistent generated-address identity changes where applicable.
- [ ] `GeneratorManifest` / stage/domain/config revisions cover deterministic generation compatibility.
- [ ] Definition/content schema revisions are not silently conflated with generator or save-schema versions.

Do not introduce a generic `version` field whose meaning mixes serialization layout, definition revision and generator compatibility.

## 5. Decide whether a definition change preserves logical identity

For a persisted authored definition change:

- [ ] Is the semantic definition still the same logical concept?
- [ ] Can existing persisted instances/stacks safely resolve the new definition without reinterpretation?
- [ ] If fields changed incompatibly, is there an explicit state/schema migration?
- [ ] If a persistent semantic ID is renamed/replaced, is that treated as migration rather than cosmetic refactoring?
- [ ] If an upgrade is intended to preserve instance continuity, does the owning gameplay contract explicitly permit preservation of identity/state?

For building upgrades, preserve placed-instance continuity only where the approved upgrade-family rules allow it. For item changes, first decide whether a property belongs to the definition, stack, or individual instance before changing persistence.

## 6. Validate the world/generator contract before applying deltas

On load or migration:

- [ ] Identify the save schema and pinned generator contract.
- [ ] Classify compatibility explicitly (`EXACT`, `SUPPORTED_LEGACY`, `MIGRATION_REQUIRED`, `INCOMPATIBLE`, or unknown/corrupt equivalent).
- [ ] Never interpret old deltas under current generator defaults merely because the new code can load them.
- [ ] Verify required manifest/config/stage/domain contracts are available before regenerating deterministic truth.
- [ ] Treat unresolved generated-object IDs under an expected exact contract as a bug/diagnostic, not a reason to guess another target.

Do not use nearest-position matching as a generic recovery path for missing generated identities.

## 7. Make migrations explicit and transactional

Every incompatible supported change needs a deliberate migration path.

Before shipping one:

- [ ] Parse and validate the old save without mutating it.
- [ ] Identify the old schema/generator/definition contract precisely.
- [ ] Convert to a known intermediate/new representation deterministically where required.
- [ ] Validate all migrated persistent references before activation.
- [ ] Write the migrated save separately/atomically enough that failure cannot destroy the only known-good old save.
- [ ] Quarantine/report unresolved references instead of applying them to guessed objects.
- [ ] Preserve player-owned quantities/state unless the migration explicitly and validly transforms them.

A migration is not complete merely because the new serializer can write the result.

## 8. Add migration and compatibility fixtures

For each supported migration or compatibility boundary:

- [ ] Keep reproducible fixture saves or equivalent deterministic test inputs.
- [ ] Cover empty/minimal state and representative populated state.
- [ ] Include negative/edge coordinates when spatial/generated identities are involved.
- [ ] Verify expected modern IDs/state are produced.
- [ ] Verify no delta is reassigned to the wrong object.
- [ ] Verify the migrated save round-trips under the new schema.
- [ ] Verify an incompatible/unknown contract fails explicitly rather than silently falling back.

If deterministic generated truth is expected to remain compatible, preserve relevant vectors/fingerprints/StableIds as regression evidence.

## 9. Keep streaming and caches disposable

For any runtime cache, geometry representation, streamed cell or presentation resource:

- [ ] Can it be dropped and rebuilt without losing durable player/world state?
- [ ] Does its cache key include enough world/generator/stage/dependency identity to avoid serving data from the wrong contract?
- [ ] Does unloading a cell leave `WorldDeltaStore`-owned state intact?
- [ ] Are stale runtime handles/results rejected without mutating durable identity?

Disposable caches may usually be discarded on incompatibility instead of migrated.

## 10. Review cross-system persistent ownership

Before merge, verify ownership for each relevant subsystem.

### Inventory / equipment / storage
- [ ] Shared container state owns logical contents; UI does not.
- [ ] Stack vs persistent-item-instance state is explicit.
- [ ] Cross-container mutations remain atomic.

### Crafting / processing stations
- [ ] Persist only queues/progress/state that gameplay requires across reloads.
- [ ] Station scene/resource identity is not the persisted semantic station identity.

### Buildings
- [ ] Player construction is saved as durable world delta/placed-instance state.
- [ ] Runtime Nodes, batching, LOD and streaming-cell ownership are not persisted as building identity.
- [ ] Definition upgrades preserve placed identity only when explicitly compatible.

### Generated world state
- [ ] Untouched deterministic data is regenerated from the pinned contract.
- [ ] Player-caused changes reference stable generated identity/spatial ownership as required.

## 11. Presentation-change safety check

For a change claimed to be presentation-only:

- [ ] No world seed or generator contract changes solely because visual assets changed.
- [ ] No procedural StableId or semantic content ID changes solely because a mesh/scene/material path changed.
- [ ] Existing durable item/build/player/world state remains interpretable without migration unless logical semantics actually changed.
- [ ] Runtime/presentation caches may rebuild freely without touching durable state.

If changing visuals requires rewriting persistent identity, the boundary is wrong or the change is not presentation-only.

## 12. Pull-request persistence review

Before handing a persistence-affecting change to review, be able to answer:

- [ ] What is regenerated, what is saved, and who owns each durable mutation?
- [ ] What stable identity is persisted, and why is it stable across runtime reloads?
- [ ] Which version/revision concept changes, if any?
- [ ] Is the change compatible, migration-required, or intentionally incompatible?
- [ ] What happens when a saved reference cannot be resolved?
- [ ] Can a failed migration/save leave the previous valid state intact?
- [ ] What automated fixture/negative test protects the compatibility claim?
- [ ] Can presentation/streaming implementation change without invalidating the persisted logical state?

## Stop conditions

Do not proceed as a routine implementation if any of these are true:

- a runtime Node/path/index is proposed as durable identity;
- an old save would be silently interpreted using newer generator defaults;
- an incompatible definition ID/schema change has no migration or explicit incompatibility decision;
- unresolved generated references are reassigned by guess/nearest position;
- migration mutates the only valid old save before validation succeeds;
- a presentation-only change would invalidate logical saves/world identity;
- a streamed runtime owner would become the sole owner of durable state.

Route those cases back through the owning persistence/gameplay/world architecture before implementation continues.
