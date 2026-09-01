# Underworld Building UI / UX Specification

Status: **DESIGN AUTHORITY CANDIDATE — UI-BUILD-001 / #407**  
Parent UI authority candidate: **UI-UX-002 / #387**  
Building architecture source: docs PR **#403**, `docs/30_gameplay/BUILDING_SYSTEM.md`  
Reference viewport: **1280 × 720**

This document defines the production UX architecture for player construction.

Final icons, textures, piece thumbnails and ornaments are deliberately provisional. The stable contract is the interaction model, information hierarchy, reusable screen boundaries, authoritative read-model boundaries and content-scaling behavior.

The core principle is:

> **Normal building should be effortless; advanced building should be permissive rather than hidden behind developer-style tools.**

---

## 1. Product requirements inherited from Building architecture

The UI must faithfully represent the following gameplay decisions rather than accidentally contradict them:

- modular declarative pieces rather than voxel-authoritative blocks;
- shape vocabulary before cosmetic/material multiplication;
- grid/socket snapping as assistance, not a placement prison;
- deliberate free placement;
- arbitrary durable transforms;
- intentional overlap and near-overlap;
- valid terrain embedding;
- explicit graph-based structural support;
- material-sensitive support behavior;
- both world domains using one building architecture;
- future 1000+ piece content scale;
- megabuilds as intentional stress cases.

The UI does not calculate or redefine those rules.

---

## 2. Two-surface architecture

Building consists of two connected presentation surfaces.

### 2.1 Build Catalog

Interactive overlay used to discover and select a build-piece definition.

The Catalog owns presentation of:

- taxonomy;
- filtering/search;
- favorites/recent presentation state;
- piece cells;
- selected-piece details;
- resource requirement preview;
- unavailable/locked presentation;
- selection intent.

It does **not**:

- instantiate the candidate piece;
- determine placement validity;
- consume resources;
- create a BuildInstance;
- calculate structural support.

### 2.2 Placement HUD

World-facing minimal HUD used after a piece has been selected.

It presents:

- current piece;
- current placement assistance mode;
- resolved build controls;
- candidate validity;
- authoritative resource availability;
- authoritative support preview where gameplay provides one;
- placement/deconstruction/repair feedback.

The full Catalog normally closes while the Player is positioning a piece.

This preserves the world, candidate ghost, sockets and nearby structure as the primary interface.

---

## 3. Build Catalog layout

Reference screen: 1280×720.

Use the shared Overlay layer, 48 px safe inset and #399 interactive input/focus capture.

Preferred main shell:

- approximately **1120 × 620 px** at reference resolution;
- bounded rather than full ultrawide stretch;
- standard shared OverlayPanel/ContentPanel grammar.

Reference layout:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ BUILD                                             Search [________] │
├──────────────┬──────────────────────────────────────┬───────────────┤
│ Categories   │ Piece Browser                        │ Piece Details │
│              │                                      │               │
│ Recent       │ [ ][ ][ ][ ][ ]                      │ preview       │
│ Favorites    │ [ ][ ][ ][ ][ ]                      │ name          │
│ Foundations  │ [ ][ ][ ][ ][ ]                      │ category      │
│ Floors       │ [ ][ ][ ][ ][ ]                      │ material      │
│ Walls        │ ...                                  │ requirements  │
│ Beams        │                                      │ description   │
│ Stairs       │                                      │               │
│ Roofs        │                                      │ [SELECT]      │
└──────────────┴──────────────────────────────────────┴───────────────┘
```

Reference widths:

- taxonomy rail: 190–220 px;
- browser: flexible, approximately 560–650 px;
- details: 260–300 px;
- header/search row: 52–60 px.

The right details region may collapse/reflow only at a deliberate future breakpoint. It is not allowed to disappear merely because artwork changes.

---

## 4. Taxonomy and 1000-piece scalability

A large build library cannot become a single icon list.

Primary discovery metadata comes from BuildPieceDefinition/presentation data:

- category/subcategory;
- shape/role;
- material/style;
- unlocked/available state;
- search tags/text;
- favorite state;
- recent state;
- contextual related variants when gameplay/content actually exposes them.

### Shape-first navigation

The primary navigation follows construction role rather than multiplying the same tree for each material.

Candidate categories as content exists:

- Foundations;
- Floors;
- Walls;
- Beams & Posts;
- Stairs & Ladders;
- Roofs;
- Doors & Frames;
- Rails & Fences;
- Structural / Utility;
- Furniture / Decoration only when real content warrants it.

Material is normally a filter/facet.

Do not create top-level branches such as:

- Wood Walls;
- Stone Walls;
- Iron Walls;
- Wood Floors;
- Stone Floors;
- Iron Floors;

unless future content testing demonstrates a concrete navigation benefit.

This keeps the UI aligned with the product principle **shape vocabulary before material/cosmetic variants**.

### Fast-entry views

Architecture reserves:

- Recent;
- Favorites;
- Search.

They may remain hidden for the tiny initial kit.

The data model should not require a redesign when they become useful.

---

## 5. Search

Search operates over authored semantic catalog metadata.

It does not inspect:

- mesh filenames;
- texture filenames;
- runtime Node names;
- internal StableIds.

Keyboard/mouse users may focus a normal search field.

Controller users must remain able to browse the complete normal taxonomy without needing an on-screen keyboard.

Large-catalog implementation should filter/rebuild only when search/filter state changes rather than every frame.

---

## 6. Piece browser cells

Building cells may reuse the visual grammar of ItemSlot but are not inventory items.

Reference logical envelope: **72–88 px** per cell depending final density.

A cell may show:

- piece thumbnail/preview;
- favorite marker;
- unavailable/locked state;
- compact short name where readability requires it.

Costs should not be repeated as dense numbers on every cell by default.

The selected Details region owns full requirement presentation.

Focus, hover, selection and unavailable states preserve identical content geometry.

A dedicated BuildPieceCell component should be extracted only when real repeated behavior proves it is materially different from ItemSlot.

---

## 7. Selected-piece details

The details region composes two authorities.

### Presentation metadata

- display name;
- thumbnail/icon;
- short description;
- category label;
- material/style label.

### Gameplay/build read data

- actual construction requirements;
- owned/required quantities;
- placement capability summary;
- unavailable reason;
- structural/material role summary where gameplay exposes a meaningful player-facing value.

Do not duplicate construction requirements inside presentation metadata.

Avoid dense engineering stats in the first slice.

Useful example:

```text
WOOD BEAM — LONG
Structural

Wood   12 / 8

Long structural member used for spans and framing.
```

---

## 8. Catalog -> Placement transition

Selecting a piece emits selection intent to the owning build controller.

On accepted transition into placement:

1. Catalog becomes inactive/hidden;
2. #399 relinquishes interactive Catalog focus without releasing inappropriate gameplay actions;
3. build-placement input context becomes active through gameplay/application authority;
4. candidate ghost appears from gameplay/building presentation;
5. Placement HUD renders the current candidate snapshot.

The same confirm button/key used to select the piece must not leak into an immediate accidental placement.

---

## 9. Placement HUD layout

Placement UI stays sparse.

Reference composition:

```text
                         world candidate ghost
                                +

                       concise failure reason
                           only if needed

┌───────────────────────┐                     ┌───────────────────────┐
│ WOOD BEAM — LONG      │                     │ Rotate                │
│ Wood 12 / 8           │                     │ Snap / Free           │
│ STRONG                │                     │ Cycle Snap            │
│ SNAP                  │                     │ Place                 │
└───────────────────────┘                     │ Back                  │
                                              └───────────────────────┘
```

At 1280×720:

- bottom-left: current piece / cost / mode / support summary;
- bottom-right: contextual KeyPrompt stack;
- center near reticle: only short current hard-failure/context message;
- bottom-center gameplay hotbar remains unobscured by default.

Do not surround the candidate with permanent large panels.

---

## 10. Placement snapshot boundary

The UI consumes a value-only candidate snapshot.

Conceptually:

```text
piece_id
candidate_transform_presentation
placement_mode
snap_state
active_snap_presentation
validation_state
validation_reason
resource_state
support_state
can_commit
```

Exact schema belongs to the build system.

The UI may format values; it must not run authoritative:

- overlap checks;
- socket ranking;
- protected-zone checks;
- resource pre-consumption;
- structural graph evaluation.

---

## 11. Hard invalid vs unusual-but-valid

This distinction is a production UX invariant.

### Hard-invalid

Candidate cannot commit because gameplay rejects it.

Examples may include:

- non-finite/invalid transform;
- protected world volume;
- permission restriction;
- missing resources;
- special mandatory anchor failure;
- other explicit hard build rule.

UI shows clear invalid presentation plus a concise reason when available.

### Unconventional but valid

Candidate remains legal even if it is:

- off-grid;
- unsnapped;
- partially overlapping;
- substantially embedded in another piece;
- embedded in terrain;
- nearly coincident with another piece;
- rotated unexpectedly.

These states **must not use the generic invalid treatment**.

The UI is not allowed to psychologically turn soft assistance into a hidden hard restriction.

---

## 12. Snap / Free placement

Current assistance mode must always be legible during placement.

Initial vocabulary:

- `SNAP` — grid/socket assistance active;
- `FREE` — deliberate snap assistance disabled.

A future distinct precision/fine-transform mode may add a third label only after gameplay actually implements it.

The UI receives resolved binding information through KeyPrompt.

It never assumes the physical key is Shift.

If gameplay uses hold-to-disable snap:

- mode visibly changes while held;
- release restores SNAP;
- UI does not itself move/recompute the candidate.

If gameplay later uses a toggle, the same visual mode indicator remains valid.

---

## 13. Snap visualization

World presentation should remain bounded.

Priority:

1. candidate ghost;
2. active snap/socket marker;
3. a small number of alternative nearby sockets only when cycling/selection requires them;
4. no global display of every socket in a large structure.

Raw authored socket IDs are not normal player copy.

`Cycle Snap` is shown only when more than one meaningful candidate exists or gameplay exposes the action as available.

---

## 14. Rotation / transform UI

Placement controls present semantic actions:

- Rotate;
- alternate/reverse rotation where supported;
- Snap/Free;
- Cycle Snap;
- Place;
- Cancel/Back.

Fine offset, local/global axes and precision movement are not shown until actual gameplay supports them.

If a human-readable angle is useful, show degrees such as `45°` or `90°`.

Do not show raw quaternion/basis/XYZ debugging in the ordinary build HUD.

---

## 15. Overlap and terrain embedding

The candidate ghost does not become invalid-colored merely because it intersects another build piece or terrain.

Allowed overlap:

- ordinary valid treatment.

Allowed terrain embedding:

- ordinary valid treatment.

Unsnapped/free placement:

- mode indication may differ subtly;
- it is not an error.

Only the authoritative validator determines hard failure.

Coplanar visual/z-fighting warnings may be added later as non-blocking presentation only if valuable.

---

## 16. Structural support feedback

The support system should be understandable without exposing formulas.

Candidate categories may eventually include gameplay-authored values such as:

- Rooted / Grounded;
- Strong;
- Stable / Moderate;
- Weak;
- Near Limit;
- Unsupported.

Exact thresholds/names remain gameplay/content/profile-owned until implemented.

UI may map those semantic values to visual roles.

### Non-color-only rule

Any support color treatment is paired with at least one of:

- short label;
- icon/symbol;
- outline/pattern difference;
- explicit reason for hard unsupported placement.

Normal placement should not display structural equations or graph topology.

A later inspection mode may visualize nearby support state, but it must be spatially bounded.

Never instantiate a floating label for every piece in a megabuild.

---

## 17. Resource requirement presentation

Current-piece card may show owned / required counts.

Example:

```text
Wood 12 / 8
```

Values come from canonical inventory/build preflight snapshots.

The UI does not decrement the count when the Player clicks Place.

After an accepted commit:

- inventory/read model refreshes;
- displayed quantities refresh;
- if continued placement is supported, the same selected piece stays active;
- insufficient resources produce an authoritative hard-invalid state.

---

## 18. Repeated construction

Building the same piece repeatedly should not require reopening the Catalog.

Preferred architecture:

```text
successful commit
-> same definition remains selected
-> next candidate ghost becomes active
-> resource/support state refreshes
```

Whether gameplay exits on failure/resource exhaustion remains gameplay policy.

High-value future actions that fit this architecture:

- duplicate targeted piece;
- pick/eyedrop existing piece definition;
- repeat last piece;
- favorites quick access.

Do not implement fake UI commands before gameplay owns them.

---

## 19. Build tool modes

As gameplay expands, the build tool may expose explicit submodes:

- Place;
- Deconstruct / Remove;
- Repair;
- Upgrade / Replace.

Current mode must be clearly visible.

Do not overload one ghost color to mean both `invalid placement` and `remove target`.

Refunds, damage, upgrade compatibility and preserved identity come from building/gameplay services.

Normal low-risk deconstruction should remain fast if gameplay makes it safely reversible/refundable; do not force confirmation dialogs on every wall removal.

---

## 20. World-domain behavior

The same Build Catalog and Placement HUD operate in both world domains.

Domain restrictions are supplied by build validation/content metadata.

UI does not expose an `Overworld / Underworld` manual selector.

A BuildInstance belongs to the currently authoritative domain through gameplay/building state.

Cross-domain gateways are not ordinary build pieces unless a later system explicitly makes them constructible.

---

## 21. Input contexts

Build Catalog and placement have different input needs.

### Catalog

Interactive UI context:

- #399 suppresses ordinary gameplay input;
- mouse/controller/keyboard focus belongs to Catalog;
- closing returns to build/gameplay context safely.

### Placement

World interaction context:

- Player/build-placement controller receives placement actions;
- ordinary combat/harvest inputs that conflict with build actions must not remain simultaneously active by accident;
- presentation renders resolved actions only.

This implies an eventual gameplay-owned input/action context for Build mode or a compatible extension of the centralized input gate.

UI does not scatter `if building` checks through Player.

### Back precedence

While building:

1. Modal child;
2. search/child interactive surface;
3. precision submode if one exists;
4. current placement -> Build Catalog or documented root;
5. Build Catalog -> leave Build mode;
6. only then ordinary GameFlow Pause.

A single Back press must not both cancel placement and pause.

---

## 22. Controller requirements

Controller navigation is first-class.

Catalog:

- deterministic 2D piece-cell navigation;
- deterministic category navigation;
- no pointer-hover-only information;
- search invocation is explicit rather than mandatory.

Placement:

- semantic actions match keyboard/mouse capabilities;
- button glyphs are resolved through KeyPrompt;
- socket cycling does not require pixel-accurate cursor selection;
- rotation defaults to predictable discrete actions.

Advanced free placement must not become mouse-exclusive.

---

## 23. Accessibility / readability

- valid/invalid distinction is not hue-only;
- structural state is not hue-only;
- selected/focused state is independent of hover;
- world-facing text uses panel/shadow treatment sufficient for bright Overworld and dark Underworld scenes;
- ghost/outline style must remain legible in both domains;
- UI scaling cannot depend on text baked into atlas art;
- reduced-motion settings must remain compatible with future ghost/transition animation.

---

## 24. Performance requirements

The UI must not undermine megabuild scalability.

Forbidden patterns:

- one UI node/label per BuildInstance;
- every socket permanently visualized;
- catalog recreated every frame;
- full 1000-piece catalog rebuilt when one inventory quantity changes;
- support overlay across an entire town by default.

Preferred patterns:

- recycled/virtualized catalog cells when content count warrants it;
- bounded nearby socket visuals;
- one current candidate snapshot;
- event-driven resource/support refresh;
- spatially scoped inspection mode;
- presentation caches for static catalog metadata.

---

## 25. First implementation slice

Do not build the 1000-piece experience before the initial kit exists.

First implementation proves the architecture with simple placeholder art:

1. Catalog shell;
2. actual categories only;
3. piece browser grid;
4. selected name/thumbnail/requirements;
5. piece selection intent;
6. Catalog -> Placement transition;
7. candidate validity/reason;
8. Place / Rotate / Snap-Free / Cancel prompts;
9. visible SNAP/FREE state;
10. compact support state when authoritative data exists;
11. repeated placement of one selected piece;
12. clean return to Catalog with previous selection/focus restored.

Search, Favorites and Recent can become visible later without architectural redesign.

---

## 26. Acceptance contract

A production implementation must prove:

1. the same Catalog architecture remains usable with a tiny initial kit and a simulated large catalog;
2. filtering/category/search changes presentation only, never persistent piece identity;
3. piece selection does not commit construction;
4. Catalog -> Placement does not leak confirm input into an accidental placement;
5. hard-invalid and unconventional-but-valid states are distinct;
6. allowed overlap and terrain embedding never receive generic invalid presentation;
7. SNAP/FREE is always readable and binding-independent;
8. validity/resources/support come from authoritative read data, not UI-side simulation;
9. support state works without color alone;
10. repeated placement does not force Catalog reopening;
11. one UI works in Overworld and Underworld;
12. mouse/keyboard/controller have complete paths;
13. Catalog input does not leak movement/combat through gameplay;
14. no persistent UI object exists per placed BuildInstance;
15. final art/thumbnail replacement does not change construction/controller architecture.

---

## 27. Explicit non-goals

Do not:

- flatten a large library into one scrolling list;
- make material the sole top-level taxonomy;
- reinterpret overlap as an error;
- make terrain embedding look invalid;
- derive support from ghost color/collision locally;
- hard-code Shift/E/Q/etc. into UI logic;
- consume resources from Catalog/Placement UI;
- create BuildInstances from presentation;
- expose raw socket IDs, transforms or StableIds to normal players;
- create separate Overworld and Underworld building menus;
- require final build-piece artwork for UI architecture acceptance.
