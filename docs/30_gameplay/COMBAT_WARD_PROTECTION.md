# Underworld — Ward and Temporary Protection

Status: **LOCKED DIRECTION for temporary protection semantics; exact capacity, duration, stacking, mitigation ordering and later Life Staff tuning remain OPEN**

This document complements [`COMBAT_FOUNDATION.md`](COMBAT_FOUNDATION.md), [`COMBAT_STATUS_EFFECTS.md`](COMBAT_STATUS_EFFECTS.md), and [`COMBAT_HEALING_INTERACTIONS.md`](COMBAT_HEALING_INTERACTIONS.md). It defines how a future Ward/protection layer can improve survivability without replacing physical defense, armor, posture, impact, or healing authority.

## 1. Ward is temporary protection, not healing

A Ward is a temporary protective layer that absorbs or prevents some incoming health damage before that remaining health damage reaches the target's Health resource.

Conceptually:

```text
incoming valid health damage
-> Ward / temporary protection may absorb some amount
-> remaining health damage reaches Health
```

A Ward must not be implemented as `take damage and immediately heal the same amount`. Healing and protection remain different systems.

## 2. Ward does not replace physical defense

Ward is not another name for block, parry, armor, or healing.

```text
Parry
-> timing-based deflection / avoidance of the attack

Block
-> physical interception with weapon / Shield
-> stamina and guard/posture consequences

Armor
-> persistent resistance / health-damage mitigation

Ward
-> temporary absorbable protection

Healing
-> restoration of Health already lost
```

These layers may compose, but one must not silently take ownership of the others.

## 3. Ward normally protects Health, not impact or posture

The baseline direction is that Ward primarily modifies the health-damage channel. It does **not** automatically erase the physical force of a valid hit.

```text
heavy attack reaches warded target
-> Ward may absorb some or all resulting health damage
-> impact / interruption still resolves through normal combat authority
-> posture pressure still resolves through normal combat authority
```

This keeps blocking, parrying, dodging, spacing, and posture management relevant even for highly defensive sustain builds.

A later authored protection effect may explicitly modify another channel, but that must be a deliberate effect rather than the default meaning of Ward.

## 4. Ward has finite authored protection

Ward should provide bounded protection rather than permanent or infinitely accumulating mitigation.

Conceptually:

```text
Ward active
-> protection capacity remains

incoming health damage
-> protection absorbs an authored amount
-> protection capacity decreases

capacity reaches zero
-> Ward breaks / expires
-> any unabsorbed health damage continues normally
```

Example only, not a balance lock:

```text
incoming health damage: 40
Ward remaining: 25

-> Ward absorbs 25
-> Ward breaks
-> remaining 15 continues toward Health
```

Exact capacity formulas and whether protection is flat absorption, percentage-based, mixed, or another bounded model remain open.

## 5. Duration and capacity are separate concepts

A Ward may end because its lifetime expires or because its protection is consumed.

```text
Ward lifetime expires
-> protection ends even if capacity remains

Ward capacity reaches zero first
-> Ward breaks before duration expires
```

Exact duration, decay behavior, recharge behavior, and whether any Ward can persist indefinitely under a maintained condition remain later decisions.

## 6. Reapplication and stacking are authored

Repeated Ward applications must use an explicit policy. There is no global assumption that Wards stack infinitely.

A Ward definition may later be authored to:

```text
refresh duration
replace a weaker Ward
restore some protection capacity
increase protection within a bounded cap
coexist with a meaningfully different protection effect
or use another explicit rule
```

The status/effect framework owns the lifetime and stacking policy. Exact stacking caps and conflict resolution remain open.

## 7. Ward state must be readable

A meaningful Ward should communicate its state through gameplay-facing presentation rather than only a small UI icon.

Useful readability states may include:

```text
Ward active
-> visible protective state

Ward absorbs a hit
-> clear absorption response

Ward heavily depleted
-> presentation may visibly weaken where useful

Ward breaks
-> unmistakable break / collapse cue
```

Exact VFX, SFX, UI meter, opacity changes, and presentation language remain open.

## 8. Healing reduction does not automatically weaken Ward

Generic healing reduction modifies health restoration. Ward is protection, not healing.

```text
healing reduction
-> modifies direct healing / regeneration

Ward
-> remains protection
```

A future corruption, curse, boss mechanic, or other authored effect may explicitly weaken both healing and protection if desired, but that interaction must be separately defined.

## 9. Ward composes with armor and interception without owning their order

The combat pipeline must preserve the distinction between:

```text
attack interception / block / parry
physical damage typing and armor/resistance
Ward / temporary protection
remaining health damage
Health
```

The exact ordering between armor/resistance mitigation and Ward absorption is **not locked here**. It must be deterministic and consistently owned by the combat-damage authority, but final ordering should be selected during implementation/playtesting rather than inferred from this document.

Impact and posture remain separate channels regardless of that health-damage ordering.

## 10. Life Staff + Sword sustain direction

A later Life Staff can use Ward as one layer in a highly survivable but still interactive build.

Conceptually:

```text
Life Staff
-> apply Ward
-> apply regeneration

swap to Sword
-> block / parry / fight normally
-> Ward absorbs some health-damage mistakes
-> regeneration restores Health that gets through

pressure continues
-> posture can still break
-> impact can still stagger / displace
-> Ward can be consumed
-> healing can be reduced by authored counters
```

This supports the intended low-damage, high-survivability playstyle without granting blanket immunity to physical combat.

## 11. Explicitly open

The following remain implementation/playtest or later magic decisions:

- exact Ward capacity values and formulas;
- exact Ward duration and expiry behavior;
- armor/resistance vs Ward mitigation ordering;
- reapplication, refresh, replacement, and stacking rules;
- whether any Ward regenerates or recharges while active;
- whether different Ward categories can coexist;
- break VFX/SFX/UI presentation;
- whether any authored protection modifies impact or posture;
- interactions with corruption, curse, anti-protection, dispel, or cleanse mechanics;
- multiplayer source attribution and ally-target rules;
- Life Staff resource cost, cast rules, skill list, and mastery interactions.

Do not infer arbitrary barrier formulas or MMO-style shield stacking. The locked direction is a bounded, readable temporary health-protection layer that composes with physical combat instead of replacing it.
