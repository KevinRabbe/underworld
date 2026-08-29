# Adding a Gameplay System

Status: **implementation/review checklist derived from locked architecture**

Use this guide when introducing a new gameplay subsystem or a genuinely new reusable mechanic. It does not define a new framework. If this checklist conflicts with an authoritative contract, the authoritative contract wins.

Primary authority:
- [Technical Architecture](../TECHNICAL_ARCHITECTURE.md)
- [Cross-System Ownership Map](../10_architecture/SYSTEM_OWNERSHIP_MAP.md)
- [Dependency Rules](../10_architecture/DEPENDENCY_RULES.md)
- [Persistence and Generator Versioning](../PERSISTENCE_AND_VERSIONING.md)
- [Content Architecture](../10_architecture/CONTENT_ARCHITECTURE.md)
- [Replaceable Presentation Boundary](../10_architecture/PRESENTATION_BOUNDARY.md)
- [Building System Architecture](../30_gameplay/BUILDING_SYSTEM.md)
- [Item, Inventory and Crafting Architecture](../30_gameplay/ITEM_INVENTORY_CRAFTING.md)
- [Content Authoring Contract](AUTHORING_CONTRACT.md)

## 1. Prove that a new system is actually needed

Before creating a new gameplay domain:

- [ ] Confirm this is a reusable mechanic/ownership boundary, not one content member needing special treatment.
- [ ] Check whether an existing gameplay domain, capability, component, profile or definition already owns the behavior.
- [ ] Check whether the request is actually presentation, persistence, worldgen, runtime streaming, tooling or authored-content work instead of gameplay ownership.
- [ ] Avoid creating a new central manager merely because several objects need to call the same helper.

If adding one normal sword, recipe, building piece, creature variant or visual requires a new system, stop and review the existing content/component architecture first.

## 2. Name the owning domain and its responsibility

Write the subsystem boundary before implementation.

- [ ] State what authoritative gameplay decisions/state transitions the subsystem owns.
- [ ] State what it explicitly does **not** own.
- [ ] Identify the existing upstream data/contracts it may consume.
- [ ] Identify downstream runtime/presentation consumers that may observe its output.
- [ ] Identify which other system owns persistence of any durable state.

A gameplay system may own rules such as inventory mutation, combat resolution, harvesting interaction or building placement validation. It must not silently become the owner of procedural world truth, save-file layout, rendering assets or runtime-cell lifetime.

## 3. Separate definitions, state, services and presentation

For every important concept, classify it before coding:

- [ ] **Definition** — stable semantic data describing a game concept.
- [ ] **Persistent instance/stack state** — durable per-instance or aggregate state where required.
- [ ] **Runtime instance/component** — transient live simulation object/state.
- [ ] **Service/system** — reusable logic that interprets definitions and applies state transitions.
- [ ] **Presentation adapter/state** — replaceable visual/audio/UI representation.

Do not combine all five roles into one giant `Node`, `Resource` or manager class.

Definitions describe content; runtime systems interpret them. Presentation observes/represents authoritative state but does not become the source of gameplay truth.

## 4. Choose stable identity before references spread

For any identifier crossing subsystem boundaries:

- [ ] Authored concepts use stable semantic content IDs rather than filenames, scene paths or display names.
- [ ] Generated world objects retain their accepted procedural `StableId`/address identity.
- [ ] Player-created/stateful objects use the persistent instance identity owned by their subsystem when required.
- [ ] Fungible values stay stack/quantity state where per-unit identity is unnecessary.
- [ ] Runtime `Node` instance IDs, array positions and resource memory identity stay transient.

A gameplay object may legitimately carry both a semantic definition ID and a persistent/generated instance ID. Do not collapse those into one identifier.

## 5. Keep dependency direction one-way

Use the established direction:

```text
project rules / schemas
        ↓
content definitions
        ↓
registry / resolvers
        ↓
gameplay systems / factories
        ↓
runtime instances
        ↓
presentation adapters / assets
```

Before implementation:

- [ ] Definitions do not reference live player/AI Nodes, scene-tree managers, save objects, UI controls or transient runtime instances.
- [ ] Gameplay does not depend on internal presentation scene hierarchy or animation/resource filenames.
- [ ] Production runtime does not import developer tooling/tests.
- [ ] The new subsystem does not reach into protected worldgen/runtime internals instead of consuming their published contract.
- [ ] Cross-domain references are typed/semantic enough that validation can explain incompatibility.

If two gameplay domains need each other bidirectionally, first look for a narrower public interface/event/data contract instead of accepting a circular dependency.

## 6. Prefer capabilities/components over deep inheritance and ID switches

When behavior varies by content member:

- [ ] Check whether composition/capabilities/components can express the variation.
- [ ] Keep broad classification in categories/tags and reusable behavior in explicit capabilities/components.
- [ ] Avoid deep inheritance trees that force unrelated variants through one class hierarchy.
- [ ] Avoid central `if content_id == ...` / `match item_id` branches for ordinary content differences.

Infrastructure special cases are justified only when a genuinely new mechanic cannot be represented by an existing contract.

## 7. Define mutations as explicit operations

For state-changing gameplay operations:

- [ ] Inputs/preconditions are explicit.
- [ ] Validation occurs before authoritative mutation.
- [ ] Failure leaves authoritative state unchanged where atomic behavior is required.
- [ ] Multi-owner mutations use an explicit transaction/coordination boundary rather than ad-hoc partial updates.
- [ ] Runtime/presentation side effects occur after the authoritative gameplay result is known.

Existing examples include transactional inventory/crafting/build-resource changes and building placement's request -> validation -> commit flow.

## 8. Declare persistence ownership

If any state survives reload:

- [ ] State exactly what is durable and which logical store/subsystem owns it.
- [ ] Persist semantic/generated/persistent-instance identity, not runtime scene identity.
- [ ] Keep runtime Nodes, render handles, LOD/batch state and UI state out of durable authority.
- [ ] Decide whether the change is save-schema compatible, migration-required or intentionally incompatible.
- [ ] Provide migration/fixture coverage when existing durable state is reinterpreted.

Use [Persistence and Generator Versioning](../PERSISTENCE_AND_VERSIONING.md) for the authoritative compatibility rules. Do not invent subsystem-local silent migration behavior.

## 9. Keep presentation replaceable

Before wiring visuals/UI/audio:

- [ ] Gameplay communicates semantic roles/state rather than concrete scene hierarchy where practical.
- [ ] Replacing a mesh, material, shader, animation/audio set or UI implementation does not alter logical gameplay identity.
- [ ] Presentation callbacks cannot bypass authoritative validation/state transitions.
- [ ] A missing/unloaded presentation object does not erase authoritative gameplay state.

If a visual-only asset replacement changes save identity or core gameplay semantics, the presentation boundary has leaked.

## 10. Define extension points before adding many content members

For a subsystem expected to scale:

- [ ] Document which definitions/profiles/components/capabilities normal variants provide.
- [ ] Ordinary new members should usually require data/content additions, not edits to several central managers.
- [ ] Define typed references/roles that validators can resolve.
- [ ] Keep reusable variation out of one-off content-ID branches.
- [ ] Identify which genuinely new behavior would justify extending code/schema later.

Do not duplicate or prematurely implement future `ContentRegistry` work merely to finish this checklist or one gameplay feature. Consume the approved registry/content architecture when that infrastructure is available.

## 11. Define runtime/world boundaries explicitly

If the gameplay system interacts with generated or streamed world state:

- [ ] Consume deterministic world definitions/StableIds through the owning public service/interface.
- [ ] Do not regenerate or redefine topology inside gameplay code.
- [ ] Treat runtime chunk/cell/mesh/physics handles as transient representation/lifetime state.
- [ ] Apply durable player-caused world changes through the persistence/delta ownership boundary.
- [ ] Do not make player progression/building state an input that rewrites deterministic base world truth unless a future explicit architecture decision says otherwise.

A gameplay subsystem may act on a generated object. That does not transfer ownership of the generated object's deterministic identity to gameplay.

## 12. Design validation with the system

Before considering implementation complete:

- [ ] Add focused positive contracts for valid operations/state transitions.
- [ ] Add negative tests for invalid inputs, wrong ownership/identity and forbidden mutations.
- [ ] Test idempotence/retry behavior where operations may be repeated.
- [ ] Test transaction rollback/no-partial-mutation where atomic behavior is required.
- [ ] Test persistence round-trip/migration when durable state changes.
- [ ] Test presentation absence/replacement where the boundary matters.
- [ ] Keep structural correctness automated; use human playtesting for feel, pacing, readability and fun.

Do not weaken an architecture test merely because a new subsystem conflicts with an established ownership rule; determine whether the implementation or the architecture decision must change explicitly.

## 13. Document integration surfaces

A new reusable gameplay subsystem should leave enough documentation that another worker can add normal content without reverse-engineering it.

Record, as applicable:

- [ ] owning directory/domain;
- [ ] semantic definitions/profiles/components it consumes;
- [ ] public operations/events/interfaces;
- [ ] persistent state owner and identity types;
- [ ] presentation adapter/semantic roles;
- [ ] validation suite/runner;
- [ ] extension path for ordinary new content variants;
- [ ] forbidden dependency shortcuts.

If the subsystem establishes a durable new architecture decision, route that through the project Decision Log/ADR process rather than hiding it only in implementation code.

## Pull-request review questions

Before handoff, reviewers should be able to answer:

- [ ] Which domain owns this mechanic and why?
- [ ] Which responsibilities are deliberately outside the subsystem?
- [ ] What definition/state/runtime/presentation layers exist?
- [ ] Which identities cross boundaries, and are they authoritative or transient?
- [ ] Does dependency direction follow the published architecture?
- [ ] Could an ordinary new content member be added without central-manager special casing?
- [ ] Who owns durable state and migrations?
- [ ] Can presentation be replaced without changing gameplay/save identity?
- [ ] Are invalid/wrong-identity/partial-failure cases tested?
- [ ] Does the subsystem avoid duplicating worldgen, streaming, registry, persistence or presentation ownership?

## Stop conditions

Stop and route the design back through architecture review if any of these appear:

- a definition needs direct access to live scene/runtime state;
- a central manager needs a growing list of concrete content IDs;
- a file/scene path or runtime Node ID becomes authoritative gameplay/save identity;
- gameplay starts owning deterministic generator decisions or runtime-cell lifetime;
- UI/presentation state becomes the only authoritative gameplay state;
- durable state has no clear persistence owner/versioning story;
- adding ordinary variants requires unrelated subsystem edits;
- two domains require circular internal access instead of a public contract;
- a protected subsystem must be modified merely to work around its published interface.

Resolve the ownership/interface problem before implementation expands around it.
