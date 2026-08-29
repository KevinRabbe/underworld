# Underground Placement Rulebook

CONTENT-002 defines deterministic authored **base placement truth** for underground encounters and resources. It does not spawn runtime actors and it does not own mutable defeated, depleted, consumed, or collected state.

## Ownership boundary

The placement layer consumes stable world-candidate identity and authored semantic content. Geometry/topology, streaming, collision, runtime realization, AI, depletion, inventory mutation, save orchestration, and Player controls stay in their existing owners.

`UndergroundPlacementCandidate` is a value snapshot. A candidate contains a canonical `sid1:` identity, source kind, region coordinate, depth band, semantic category/trait declarations, and local slot capacity. The accepted CONTENT-001 `ReservedSiteAssignment` adapts into this boundary by copying its procedural StableId and inherited `category_ids`; the assignment itself is never mutated.

`UndergroundPlacementPolicy` is authored placement policy rather than creature/resource schema. It declares a semantic `placement_policy.*` ID, a typed `ContentReference` target, eligible candidate source kinds, required candidate categories/traits, required target categories, depth range, local maximum, and deterministic selection weight. Creature and resource fields remain owned by their accepted rulebooks.

`UndergroundPlacementRecord` is immutable regenerated base truth. It stores only persistent placement identity, candidate identity, slot index, policy identity, target semantic identity/family, and a compatibility fingerprint. Runtime/world-delta state must live elsewhere.

## Persistent identity

A candidate's persistent placement slots are derived through the existing StableAddress grammar:

`<candidate address> -> placement -> slot -> N`

The resulting StableId does not depend on array/request order, runtime object identity, resource paths, or the current rulebook revision. Rulebook/policy/target-definition changes participate in the `upf1:` compatibility fingerprint rather than rewriting the slot address.

This lets persistence address a placement occurrence independently from regenerated authored truth.

## Deterministic planning

`UndergroundPlacementService.plan()`:

1. validates and canonically sorts candidates and policies;
2. resolves every policy target through the accepted `ContentRegistry` and typed `ContentReference`;
3. rejects invalid/missing/wrong-family/wrong-category authored configuration before emitting any placement;
4. evaluates candidate source/depth/category/trait eligibility without mutating world candidates;
5. applies local capacity and per-policy maximums;
6. selects eligible policies from a canonical manifest using deterministic weighted hashing;
7. derives persistent slot StableIds and canonical `upf1:` fingerprints;
8. returns placements sorted by persistent StableId.

Input order therefore has no semantic meaning. Requesting another unrelated candidate cannot change an already addressable candidate's persistent placement result.

## Empty result versus failure

A **valid** candidate for which no authored policy is eligible returns `success = true` with an empty placement list. This is normal deterministic absence.

Malformed candidates, duplicate stable identities/policies, invalid policies, invalid registries, or missing/incompatible semantic targets return `success = false` with diagnostics and **zero** placements. Configuration errors never produce partial base truth.

## Durable delta rule

Defeat, depletion, consumption, collection, remaining capacity, actor state, and similar mutable facts are not fields of CONTENT-002 records and must not be folded into deterministic regeneration. Downstream runtime/persistence systems key their durable deltas by the persistent placement StableId.

## Extension rule

New authored content extends placement by adding semantic content definitions, categories/traits, and placement policies. The planner does not contain encounter/resource type switches and must not be edited merely to add a new creature/resource rulebook entry.

## Explicit exclusions

CONTENT-002 does not implement runtime enemy/resource spawning, RESOURCE-RUNTIME depletion, loot collection, crafting/equipment behavior, presentation assets, cave generation/meshing/collision/streaming, balance tuning, or Player action/input/camera behavior.
