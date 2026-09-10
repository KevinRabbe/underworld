# Underworld — Bow Ammunition Architecture

Status: **LOCKED DIRECTION for Phase-7 Bow ammunition ownership/consumption semantics; exact arrow recipes, stack sizes, recovery rules, quiver behavior and special ammunition remain OPEN**

This document complements [`COMBAT_BOW_PROJECTILES.md`](COMBAT_BOW_PROJECTILES.md), [`ITEM_INVENTORY_CRAFTING.md`](ITEM_INVENTORY_CRAFTING.md), and [`../40_content/WEAPON_RULEBOOK.md`](../40_content/WEAPON_RULEBOOK.md). It defines how Bow ammunition composes with the shared item/container architecture without introducing a separate hidden ammo counter.

## 1. Bow ammunition is logical inventory state

A Bow requires compatible ammunition to fire. Ammunition is represented through the same semantic item/stack/container architecture used by the rest of the game rather than by a Bow-specific integer owned by the combat controller.

Conceptually:

```text
Bow equipped
+ compatible arrow available
-> draw may begin

release valid shot
-> consume one compatible arrow through inventory authority
-> create authoritative projectile

no compatible arrow
-> shot cannot be released
```

The exact item IDs, categories, capabilities and compatibility schema are content/implementation work. The architectural requirement is that ammunition remains ordinary logical item state with explicit ownership.

## 2. Consumption happens on successful release, not draw start

Beginning or holding a draw should not itself consume ammunition.

```text
start draw
-> no arrow consumed

cancel draw before release
-> no ammunition lost

valid release
-> consume one arrow
-> create projectile
```

This avoids losing ammunition merely because the player cancels a draw, changes intent, or is interrupted before a shot is actually released.

The consume-and-projectile transition must be authoritative enough to avoid duplication or loss states such as `projectile created + arrow not consumed` or `arrow consumed + no valid projectile created` except where an explicitly authored failure rule later requires it.

## 3. Bow and arrow have separate responsibilities

The Bow weapon family and the ammunition item must not be collapsed into one identity.

```text
BOW
-> weapon family / equipment identity
-> authored draw/release behavior
-> weapon-owned combat properties
-> later Bow mastery relationship

ARROW
-> ammunition item identity
-> projectile-related properties where authored
-> material / specialized behavior where later defined
```

Changing to another material/tier Bow remains equipment progression inside the same Bow mastery family. Likewise, introducing a different compatible arrow later does not create a new Bow mastery family.

## 4. Keep the first ammunition loop small

Phase 7 does not require a large ammunition taxonomy.

A single basic physical arrow type is sufficient to prove the foundational loop:

```text
craft / obtain arrows
-> carry compatible stack
-> equip Bow
-> draw
-> release
-> consume one arrow
-> physical projectile travels
-> hit / miss / obstruction resolves
```

Specialized arrows may be added later only when content progression or combat design requires them.

## 5. Fired projectile is no longer inventory state

Once a shot is successfully released, the consumed inventory unit has transitioned into authoritative projectile/world gameplay state.

```text
inventory arrow stack
       |
       | release
       v
consume one logical unit
       |
       v
authoritative projectile runtime state
```

The projectile then follows `COMBAT_BOW_PROJECTILES.md`. Swapping weapons or changing the inventory after release must not retroactively alter that already-created shot.

If an impacted arrow later becomes recoverable, that recovery is a new world-to-inventory ownership transfer rather than the original inventory unit remaining simultaneously owned by both systems.

## 6. Arrow recovery is supported architecturally but not yet locked as a product rule

The architecture should permit an impacted projectile to produce a recoverable world pickup where later design chooses to allow it.

Conceptually:

```text
projectile impact
     |
     +-> destroyed / unrecoverable
     |
     +-> temporary embedded representation
             |
             +-> optionally recoverable world pickup
                     |
                     +-> pickup transaction
                             -> compatible inventory stack
```

However, Phase 7 does **not yet lock** whether ordinary fired arrows are normally recoverable, which impacts are eligible, whether recovery is deterministic, or what proportion of ammunition should survive use.

If recovery is implemented, prefer world-facing recovery from an actual impacted/embedded arrow representation over an invisible arbitrary refund roll where practical.

## 7. Fired arrows must not become permanent world-save baggage by default

A fired arrow is ordinary transient combat/world state unless later explicitly promoted to persistent world state.

```text
shot fired
-> projectile exists while relevant
-> impact may create temporary embedded/recoverable representation
-> unattended representation may later expire / stream out / clean up
```

The world must not accumulate permanent persisted arrow objects simply because the player missed shots during normal exploration.

Exact projectile/embedded lifetime, cleanup distance, streaming behavior and persistence exceptions remain implementation decisions.

## 8. Quiver is optional future design, not required foundation

Phase 7 does not require a dedicated quiver equipment system.

The minimal ammunition-access rule may simply be:

```text
player inventory contains compatible arrow ammunition
-> Bow may resolve that ammunition through inventory authority
```

A future quiver may become presentation, specialized storage, equipment or progression if it adds meaningful value, but the Bow foundation must not depend on inventing that system now.

## 9. Crafting uses the shared recipe/item system

Arrow crafting, if/when authored, uses the same semantic recipe, item and atomic inventory-transaction architecture as other crafted items.

Do not introduce a Bow-specific crafting resource counter or separate ammunition economy subsystem solely for arrows.

Exact recipes, materials, workstation requirements, crafting quantities and progression gates remain content decisions.

## 10. Explicitly open

The following remain implementation/content/playtest decisions:

- exact arrow item identity/schema;
- exact Bow-to-ammunition compatibility schema;
- exact stack size and carry economy;
- arrow recipes/material costs;
- whether ordinary arrows are normally recoverable;
- which world/body impacts may produce recoverable arrows;
- whether recovery is deterministic or probabilistic;
- embedded-arrow lifetime and cleanup policy;
- projectile-to-pickup representation details;
- quiver presentation/equipment/storage behavior;
- special arrow families;
- special arrow penetration/status behavior;
- multiplayer ownership/pickup rules for fired ammunition;
- later mastery interactions.

Do not infer these from genre convention. The locked Phase-7 direction is that Bow ammunition is shared logical inventory state, one unit is consumed on successful release, and the resulting projectile becomes authoritative world combat state.