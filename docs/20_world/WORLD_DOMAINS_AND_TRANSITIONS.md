# World Domains and Transitions

Status: **LOCKED architecture direction**

This document defines the relationship between the Overworld and the Underworld. It supersedes earlier architectural assumptions that required the two procedural spaces to form one physically continuous coordinate volume.

Historical milestones that proved continuous cave traversal remain valid as historical implementation evidence. They do not require future world architecture to preserve that representation.

## 1. Core decision

Underworld contains two first-class procedural world domains:

```text
WorldRoot
├─ OVERWORLD
└─ UNDERWORLD
```

The domains are **logically connected but geometrically independent**.

They do not need:
- identical coordinates;
- identical scale;
- identical terrain representation;
- identical streaming topology;
- a shared vertical axis;
- a fixed physical depth relationship;
- continuously visible geometry across a transition.

The player experience is simply that an accepted entrance in one domain can transition to a destination in another domain.

## 2. Root seed and domain seeds

A save/world owns one root world identity and seed. Each procedural domain derives its own deterministic seed namespace from that root rather than sharing mutable RNG state.

Conceptually:

```text
root_world_seed
    ├─ derive("overworld")  -> overworld_seed
    └─ derive("underworld") -> underworld_seed
```

This preserves one reproducible world while allowing the two generators to evolve independently behind explicit generator manifests/revisions.

Changing Overworld generation must not implicitly reseed unrelated Underworld content. Changing Underworld generation must not implicitly move unrelated Overworld content.

## 3. Independent coordinate spaces

`OVERWORLD` and `UNDERWORLD` positions are domain-local positions.

A position such as:

```text
OVERWORLD: (12000, 84, -8000)
```

has no required geometric relationship to:

```text
UNDERWORLD: (430, -120, 960)
```

No formula is required to interpret one as physically beneath the other.

A future gateway mapping may intentionally preserve coarse regional meaning when useful, but this is gameplay/world-design mapping, not coordinate identity.

## 4. Gateway model

Cross-domain travel is owned by an explicit gateway/transition layer.

Conceptually:

```text
WorldGatewayDefinition
- stable gateway identity
- source domain
- source anchor / entrance identity
- destination domain
- destination anchor / arrival identity
- directionality
- transition policy
- optional semantic tags
```

Examples:

```text
surface_cave_014
OVERWORLD -> UNDERWORLD

underworld_exit_014
UNDERWORLD -> OVERWORLD
```

A paired gateway may return the player to the same logical entrance, but the destination is resolved by gateway identity rather than coordinate conversion.

The architecture must also permit future:
- one-way shafts;
- elevators;
- ancient portals;
- exits that return somewhere different;
- progression-gated transitions;
- multiple surface entrances leading to different Underworld regions.

## 5. Transition presentation is replaceable

The architecture does not require a seamless transition.

The initial accepted presentation may be:

```text
interact/enter entrance
-> fade
-> loading screen
-> unload source runtime
-> load destination runtime
-> place player at destination anchor
-> fade in
```

A later implementation may hide the same handoff inside a tunnel, elevator, descent animation, fog volume, door, squeeze passage, or other presentation device.

The gameplay/world contract must remain the same.

**Rule:** never spend system complexity merely to hide a loading boundary unless the resulting player experience justifies it.

## 6. Entrances are gateways, not continuous holes

A major cave entrance intended to reach the Underworld is a modeled/authored/procedurally placed gateway object or entrance site in the Overworld.

It does not need to expose the actual Underworld geometry through the opening.

This means the project no longer requires:
- a surface mesh cutout that joins directly to the Underworld mesh;
- identical collision volumes on both sides of the world boundary;
- an Underworld tunnel whose coordinates line up with the surface opening;
- simultaneous rendering of both procedural domains.

The entrance may still have local Overworld geometry such as a cave mouth, short tunnel, mine door, crypt entrance or fissure for presentation.

## 7. Local Overworld caves remain possible

Not every cave-shaped space must transition to the Underworld.

The Overworld may contain local/shallow caves, overhangs, mines, cellars or authored underground spaces that remain part of the Overworld domain.

A specific entrance becomes an Underworld transition only when it owns or references a valid cross-domain gateway.

This distinction prevents ordinary surface geometry from implicitly becoming a world transition.

## 8. Digging does not reveal the Underworld by coordinate depth

The Underworld is not a mandatory layer beneath the Overworld terrain.

Therefore surface digging/mining rules may be bounded according to Overworld gameplay needs without answering the question "at which Y value does the Underworld begin?"

Digging in the Overworld must not automatically expose Underworld geometry merely because the player excavated deeply enough.

If a future mechanic allows a player-created connection between domains, it must create/resolve an explicit gateway under its own rules.

## 9. Generator ownership

The domains may use different generation representations.

Indicative direction:

```text
OVERWORLD
- predominantly X/Z macro planning
- surface terrain/elevation fields
- rivers
- biome/vegetation distribution
- settlements/structures
- local surface caves where desired

UNDERWORLD
- full X/Y/Z spatial planning
- cave/cavern topology
- tunnels/chambers/shafts
- stronger verticality
- underground biomes/geology
- structures/resources/special sites
```

Neither generator directly owns the other generator.

Cross-domain relationships are resolved by gateway/world-coordination services.

## 10. World runtime ownership

Conceptually:

```text
WorldCoordinator
├─ OverworldRuntime
│  ├─ generator/definition services
│  ├─ streamer
│  ├─ presentation
│  └─ domain delta state
├─ UnderworldRuntime
│  ├─ generator/definition services
│  ├─ streamer
│  ├─ presentation
│  └─ domain delta state
└─ GatewayService / WorldTransitionService
```

Only the active/relevant domain needs full runtime realization for a local player unless multiplayer/server requirements demand otherwise.

A generator must not silently instantiate or mutate the other domain.

## 11. Persistence

Durable state must identify its owning domain explicitly.

Conceptually:

```text
SaveState
- root world identity / seed / manifests
- active world domain
- player domain-local transform
- overworld delta
- underworld delta
- gateway/transition state where required
- other gameplay state
```

On Continue:

```text
read active domain
-> reconstruct that domain's required deterministic truth
-> apply that domain's durable deltas
-> prepare destination/runtime safety
-> restore player
```

Loading an underground save must not require first constructing the Overworld.

Loading an Overworld save must not require constructing Underworld runtime geometry that is not currently relevant.

## 12. Multiplayer and interest management

World domain is a first-class replication/interest boundary.

Players in different domains need not continuously replicate irrelevant domain-local:
- transforms;
- AI;
- physics;
- loaded cells;
- particles/audio;
- static building realization.

The server remains authoritative for persistent/shared world state according to the eventual networking architecture, but domain separation should reduce unnecessary runtime and network work.

## 13. Gateway destination policy

The first implementation should keep destination mapping simple and deterministic.

A gateway may map directly to a stable destination anchor/site in the Underworld.

Future generation may derive destination regions from source metadata to create coarse geographic relationships, for example making nearby Overworld entrances more likely to reach related Underworld regions. Such mapping is optional and must not reintroduce geometric continuity as a requirement.

The Underworld is allowed to behave more like a distinct realm/world than a literal one-to-one copy of surface geography.

## 14. Compatibility with accepted cave work

Earlier accepted cave/runtime work remains useful where it owns domain-internal responsibilities such as:
- deterministic cave truth;
- topology;
- geometry extraction;
- runtime cells;
- streaming;
- collision realization;
- persistence identity;
- resource/structure placement.

The superseded part is the assumption that a surface entrance must physically integrate with that cave geometry in one continuous coordinate volume.

In particular, future work should reinterpret or replace old concepts such as:
- surface-relative Underworld depth as a mandatory global rule;
- `SurfaceEntranceIntegrationDescriptor` as a physical mesh-joining requirement;
- direct surface-opening -> immediate underground-cell continuity;
- same-space traversal as the only valid entrance architecture.

Those may remain compatibility implementation details temporarily during migration, but they are no longer target architecture.

## 15. Migration rule

Do not rewrite working Underworld generation merely because the world boundary changed.

Migration should be narrow:
1. introduce explicit world-domain identity;
2. introduce gateway/transition identity;
3. separate source entrance selection from destination Underworld bootstrap;
4. permit explicit load/unload handoff;
5. remove physical continuity requirements from surface generation;
6. preserve existing Underworld topology/streaming contracts where they remain valid;
7. update persistence and smoke tests to prove both domain-local resume and cross-domain travel.

## Locked invariants

1. Overworld and Underworld are independent procedural world domains.
2. Their coordinate spaces do not need to match.
3. Cross-domain travel is owned by explicit gateways/transitions.
4. A direct loading screen is an acceptable first implementation.
5. Seamless transition presentation is optional and replaceable.
6. Digging depth does not implicitly connect the two domains.
7. Each domain owns its own generation/runtime/presentation state.
8. Durable state identifies its owning world domain.
9. Multiplayer may use world domain as an interest-management boundary.
10. Historical continuous-cave milestones remain historical evidence, not a mandate for future physical continuity.
