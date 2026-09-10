# Underworld — Healing, Regeneration and Damage-over-Time Interaction

Status: **LOCKED DIRECTION for shared healing/regen/DOT interaction; exact values, tick cadence, anti-heal strength, Ward behavior and later magic tuning remain OPEN**

This document complements [`COMBAT_HEALING_CONSUMABLES.md`](COMBAT_HEALING_CONSUMABLES.md), [`COMBAT_STATUS_EFFECTS.md`](COMBAT_STATUS_EFFECTS.md), and [`COMBAT_FOUNDATION.md`](COMBAT_FOUNDATION.md). It defines how direct healing, regeneration, healing reduction and damage-over-time compose through shared health authority without turning combat into a large MMO-style buff/debuff ruleset.

## 1. One authoritative health-restoration path

All sources that restore health should eventually resolve through one authoritative healing path.

```text
HEALING SOURCE
|
+-> direct heal
|   -> restore health now
|
+-> regeneration
    -> restore health over time

              |
              v
       HEALING RESOLUTION
              |
              v
     target healing modifiers
              |
              v
        restore health
              |
              v
       clamp to max health
```

A consumable, future Life Staff action, food effect or another authored source may have different use/cast semantics, but the final health restoration must not be independently implemented by UI, inventory, animation or presentation code.

## 2. Direct healing and regeneration are different delivery types

Direct healing and regeneration restore the same health resource but use different temporal behavior.

```text
DIRECT HEAL
-> immediate restoration event
-> normally tied to a committed use / cast / authored effect

REGENERATION
-> persistent effect
-> restores health over time
-> may continue after the originating weapon is no longer active
```

This preserves the accepted effect-ownership rule: an already-applied regeneration effect does not disappear merely because the source swaps weapons.

## 3. Taking damage does not universally cancel regeneration

Receiving ordinary damage should not automatically remove every active regeneration effect.

```text
incoming damage
-> damage resolves normally
-> active regeneration remains unless an authored mechanic removes or suppresses it
```

Specific attacks, statuses, hazards or encounter mechanics may interfere with healing where explicitly authored. There is no global `take damage -> cancel all regen` rule.

## 4. Healing reduction modifies restoration rather than dealing damage

Healing reduction is conceptually separate from health damage.

```text
healing event
-> base healing amount
-> healing-received modifiers / reduction
-> final health restoration
```

Healing reduction does not inherently deal damage and does not automatically remove the underlying regeneration status. Instead, each restoration event resolves through the current healing modifier while the reduction is active.

The default design direction is **reduced sustain rather than universal total denial**. Complete healing prevention may exist as a strongly communicated encounter-specific exception, but it is not the ordinary baseline.

Exact percentages, caps, stacking and whether healing reduction affects selected sources differently remain open.

## 5. Wound does not automatically mean anti-heal

`Wound` remains an authored physical persistent-effect concept from `COMBAT_STATUS_EFFECTS.md`.

This document does **not** redefine every Wound as a healing-reduction effect.

```text
Wound
-> persistent physical injury effect
-> exact DOT / healing interaction remains authored/open

healing-reduction effect
-> explicitly modifies incoming health restoration
```

A future authored Wound may interact with healing, but that behavior must be deliberate rather than implied by the status name.

## 6. Damage-over-time and regeneration coexist

Damage-over-time and regeneration should not cancel one another through an unrelated hidden rule. They resolve as separate health events through their respective authorities.

```text
DOT event
-> reduce health

regeneration event
-> restore health
```

This allows readable net outcomes:

```text
strong regeneration + weak DOT
-> health may rise overall

weak regeneration + strong DOT
-> health continues falling, but more slowly

healing reduction + regeneration + DOT
-> regeneration contributes less
-> sustained pressure becomes more dangerous
```

Exact tick ordering for effects resolving on the same simulation step must be deterministic, but the implementation order is a technical contract rather than a combat-balance lock here.

## 7. Periodic lethal damage uses normal death authority

A damage-over-time effect that reduces health to zero must use the same death authority as any other lethal damage source.

```text
periodic damage event
-> health reaches zero
-> normal death state / authority resolves once
```

Do not create a separate poison-death, burn-death or wound-death state machine purely because the final damage came from a persistent effect.

## 8. Source attribution survives effect lifetime

Where progression, kill credit or multiplayer contribution later requires source identity, an applied persistent effect should retain enough attribution for the appropriate authority to evaluate contribution after the source changes weapon or action state.

```text
player applies authored DOT
-> player swaps weapon
-> effect remains on target
-> target later dies from effect
-> valid source attribution remains available
```

Exact contribution and mastery-XP formulas remain separate later decisions.

## 9. Ward / protection is not healing

Temporary protection such as a future `Ward` must remain distinct from health restoration.

```text
HEALING
-> restores missing health

REGENERATION
-> restores missing health over time

WARD / PROTECTION
-> prevents / absorbs / modifies incoming harm
```

A Ward should not be implemented as `take damage, then immediately heal the same amount`, because that would entangle mitigation, death checks, feedback and healing-reduction semantics.

Conceptually:

```text
incoming attack
-> protection / Ward resolution where applicable
-> remaining health damage
-> health

healing
-> separately restores missing health
```

Healing reduction therefore does not automatically weaken Ward/protection unless an authored effect explicitly modifies protection as well.

Exact Ward behavior is intentionally deferred to a separate protection contract.

## 10. Later Life Staff sustain can use distinct verbs

The proposed later Life Staff should be able to compose multiple sustain verbs rather than several copies of immediate `+HP`.

Potential later direction includes:

```text
direct healing
regeneration
Ward / protection
area sustain
cleanse / support where later authored
```

This document does not lock the Life Staff skill list, magic resource, healing numbers, tree layout or implementation phase. It only preserves the shared health/effect boundaries required for those systems to compose safely later.

## 11. Explicitly open

The following remain implementation/playtest or later content decisions:

- exact direct-healing values;
- exact regeneration values;
- periodic tick cadence and same-tick ordering implementation;
- exact healing-reduction percentages and stacking rules;
- whether any authored effect can fully prevent healing;
- whether specific Wound definitions interact with healing;
- overheal behavior, if any;
- cleanse/dispel behavior;
- damage-over-time values and stack policies;
- source-attribution persistence details;
- later Life Staff resource/cast/healing rules;
- Ward/protection formulas, duration, stacking and damage interaction;
- final magic damage/status roster.

Do not infer arbitrary percentages, tick rates or MMO-style buff/debuff conventions. The locked direction is that direct healing, regeneration, DOT and healing reduction remain explicit composable systems while Ward/protection remains a separate mitigation concept.
