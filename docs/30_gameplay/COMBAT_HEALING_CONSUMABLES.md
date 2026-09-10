# Underworld — Combat Healing and Consumable Use

Status: **LOCKED DIRECTION for Phase-7 combat-use semantics; exact items, timings, healing values, interruption rules and food/potion family design remain OPEN**

This document complements [`COMBAT_FOUNDATION.md`](COMBAT_FOUNDATION.md), [`COMBAT_RECOVERY.md`](COMBAT_RECOVERY.md), [`COMBAT_AGGRO_DISENGAGEMENT.md`](COMBAT_AGGRO_DISENGAGEMENT.md), and [`ITEM_INVENTORY_CRAFTING.md`](ITEM_INVENTORY_CRAFTING.md). It defines how healing/consumable use participates in physical combat without making inventory UI or item stacks direct combat authority.

## 1. Combat healing is an action, not an instant inventory effect

Using a healing or other combat-relevant consumable should normally be a visible authored action with commitment.

```text
request consumable use
-> validate actor state + item availability
-> begin authored use action
-> actor is committed / vulnerable according to that action
-> reach authored effect/consume point
-> apply item transaction + gameplay effect
-> finish recovery
```

Opening inventory or pressing a hotbar key must not directly add health. Input/UI requests the action; gameplay authority resolves the use.

The intent is to allow healing during combat while making it a tactical decision rather than instant inventory-spam sustain.

## 2. Healing during combat is allowed but risky

The baseline does **not** require an arbitrary `in combat -> healing disabled` rule.

A player may attempt a valid healing/consumable action while enemies are active if the current action state permits it. The risk comes from commitment, positioning, enemy pressure and interruption rather than from a blanket combat lockout.

```text
create distance / find cover
-> begin healing action
-> enemies can continue acting
-> heal succeeds if use reaches its authored resolution

try to heal directly in front of threatening enemy
-> action is exposed
-> enemy may punish the opening
```

Enemy AI may respond to the visible use action if it can reasonably perceive it, consistent with the no-omniscient-input-reading rule in `COMBAT_GROUP_PRESSURE.md`.

## 3. Consumable use composes with the shared action lifecycle

Consumable use should participate in the same general action-commitment language as attacks rather than creating an unrelated instant-state path.

The exact phase schema may differ from an attack, but the important ownership remains:

```text
input / hotbar / inventory UI
-> requests use

gameplay action authority
-> validates and commits use state

inventory transaction authority
-> removes / changes the logical item at the authored consume point

health / effect authority
-> applies the authored gameplay result

presentation
-> shows the action/effect
```

UI, animation and item presentation must not independently mutate health or inventory state.

## 4. Item consumption and effect resolution must be atomic enough to avoid duplication/loss

The item/inventory architecture already requires atomic logical mutations. Combat-use resolution must compose with that transaction boundary.

At the authored consume/effect point, the system must ensure that the item state and gameplay effect cannot diverge into invalid results such as:

```text
heal applied
+ item not consumed

or

item consumed twice
+ one heal

or

inventory changed after commitment
+ use silently resolves a different item
```

The exact reservation/revalidation implementation remains open. The invariant is that a committed use refers to the intended logical item/effect and resolves through authoritative inventory/effect ownership.

## 5. Interruption must be physical/readable rather than arbitrary

A consumable action may be interruptible where the incoming reaction is strong enough or the authored use state says so.

The project does not yet lock a universal rule such as `any damage cancels healing` or `healing can never be interrupted`.

Instead, interruption should compose with the existing physical reaction language:

```text
minor contact
-> may or may not interrupt depending on authored use/reaction rules

meaningful stagger / knockdown / forced control
-> can interrupt the use action where physically appropriate

actor dies
-> pending use terminates
```

Exact interruption thresholds and whether specific consumables have protected/committed phases remain playtest work.

## 6. Movement during use is authored

Using a consumable should not universally root the player and should not universally allow full sprinting combat mobility.

```text
use action
-> authored locomotion constraint
-> movement may be reduced / limited / allowed depending on item/action
-> dodge, attack, block or sprint transitions follow explicit action legality
```

Exact movement speed, steering and cancel windows are not locked here.

## 7. No required global potion cooldown or toxicity system in Phase 7

Phase 7 does not require a universal consumable cooldown, potion sickness, toxicity meter or diminishing-heal stack purely to stop spam.

The first-line constraints are:

```text
item availability
+ action commitment
+ vulnerability / positioning
+ enemy pressure
+ authored recovery
```

Additional resource/cooldown systems may be introduced later only if playtesting demonstrates that the physical/action economy does not create sufficient tradeoffs.

## 8. Food, potions and other consumable families remain content-open

This document intentionally does **not** decide whether food:

- heals immediately;
- provides regeneration;
- increases maximum resources;
- provides long-duration preparation buffs;
- is primarily out-of-combat preparation;
- or uses another survival-oriented role.

Likewise, it does not require that potions exist as a specific named item family or lock their healing values, stack sizes, crafting path or availability.

Those belong to later item/content rulebooks and balance decisions. The combat contract only establishes how a combat-relevant consumable is used once such an item exists.

## 9. Later Life Staff healing is a separate source, not inventory consumption

The proposed later Life Staff family may provide healing, regeneration, wards or zones through weapon/magic skills. Those actions should compose with the same authoritative health/effect systems, but they are **not consumable-item transactions**.

```text
consumable heal
-> inventory-backed authored use action

Life Staff heal later
-> weapon/skill-backed authored action
```

The two may share effect/status infrastructure without sharing item-consumption ownership.

## 10. Explicitly open

The following remain implementation/content/playtest decisions:

- exact healing consumable roster;
- whether potions exist and their exact family structure;
- food combat/survival role;
- exact healing amounts and regeneration values;
- exact use/startup/recovery timings;
- exact movement allowed during use;
- exact interruption thresholds;
- exact consume/effect frame or event;
- reservation/revalidation implementation for committed items;
- exact cancel rules and whether interrupted use consumes the item;
- stack sizes and inventory availability;
- whether later balancing needs cooldown, sickness, toxicity or diminishing returns;
- status-effect interaction such as poison, corruption, anti-heal or healing reduction;
- multiplayer ally-use/revive consumables;
- Life Staff resource and healing rules.

Do not infer these from genre convention. The locked Phase-7 direction is that combat-use items are authoritative, visible committed actions rather than instant UI-driven health changes.