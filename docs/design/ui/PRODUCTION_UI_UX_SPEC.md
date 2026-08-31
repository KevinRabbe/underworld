# Underworld Production UI / UX Specification

Status: **DESIGN AUTHORITY CANDIDATE — UI-UX-002 / #387**  
Accepted runtime UI foundation: **UI-ARCH-001 / #262**  
M3 player-guidance owner: **UX-001 / #220**  
Reference viewport: **1280 × 720**

This document defines the production layout, interaction and reuse contract for Underworld UI. It deliberately does **not** freeze final artwork.

Placeholder icons, textures and ornaments may remain simple. The following are intended to be stable production decisions:

- screen hierarchy and information hierarchy;
- reusable component boundaries;
- semantic Theme/style roles;
- layout geometry and responsive behavior;
- mouse, keyboard and controller focus behavior;
- HUD/overlay/modal input ownership;
- presentation read-model boundaries;
- replacement-safe skin architecture.

The governing principle is:

> **Placeholder art is disposable. Layout, interaction and component contracts are production architecture.**

---

## 1. Existing foundation to preserve

The accepted UI architecture remains authoritative:

- ordinary Godot `Control` nodes and Containers own runtime UI layout;
- `presentation/ui/theme/underworld_theme.tres` is the screen-facing semantic styling API;
- scalable authored surfaces use `StyleBoxTexture` / 9-slice resources;
- prototype skin artwork is replaceable;
- reusable scene components are created only where structure or behavior is genuinely repeated;
- AppRoot/Game/Survival/Inventory/Crafting/Persistence remain gameplay/lifecycle authorities;
- UI does not load gameplay routes or become durable gameplay truth.

A UI atlas or tilesheet may be used as an **asset-authoring convenience**, but a Godot `TileMap` is not the runtime composition system for menus/HUDs.

---

## 2. Reference coordinate system and safe areas

Primary design reference is 1280 × 720.

### Safe-area tokens

Two logical safe-area families are used:

- **HUD safe inset:** 24 px minimum from viewport edge at 720p.
- **Overlay/menu safe inset:** 48 px minimum from viewport edge at 720p.

Title/menu compositions may retain the accepted larger menu margins where appropriate.

These are reference values, not permission for hard-coded absolute-only layout. Controls should use anchors and Containers so larger 16:9 resolutions and reasonable ultrawide layouts remain valid.

### Required layout checks

Any production screen family should be visually validated at minimum at:

- 1280 × 720;
- 1920 × 1080;
- 2560 × 1440;
- one representative ultrawide layout.

The UI may become more spacious at higher resolutions; it must not become structurally different unless a deliberate breakpoint is introduced.

---

## 3. UI layer model

Underworld uses four conceptual presentation layers.

### 3.1 HUD layer

Passive gameplay presentation.

Examples:

- health/stamina;
- current objective;
- reticle;
- contextual interaction prompt;
- hotbar;
- transient pickup/combat/craft feedback.

Requirements:

- recursively `MOUSE_FILTER_IGNORE` during normal gameplay;
- no gameplay mutation authority;
- no modal focus ownership;
- readable with DebugHUD absent.

### 3.2 Overlay layer

Interactive in-game panels.

Examples:

- Inventory;
- Equipment/loadout;
- Crafting;
- later mastery/profession/character panels.

Requirements:

- owns UI focus while active;
- prevents accidental gameplay input passthrough;
- does not invent a second pause/lifecycle authority;
- whether simulation pauses is explicitly owned by GameFlow/input-context policy.

### 3.3 Modal layer

Highest interactive UI authority.

Examples:

- pause menu;
- Settings when opened modally;
- destructive confirmation;
- blocking failure acknowledgement.

Only one modal focus owner may be active at a time.

### 3.4 Notification layer

Transient non-focus-stealing presentation.

Examples:

- pickup toast;
- craft complete;
- inventory full;
- save success/failure;
- objective update.

Notifications are never gameplay event authority.

---

## 4. Design-system primitives

The accepted Theme should be expanded semantically as components are implemented. Do not add unused style vocabulary merely to make the Theme look comprehensive.

### 4.1 Core surface roles

Planned roles include:

- `OverlayShade`;
- `OverlayPanel`;
- `DetailsPanel`;
- `TooltipPanel`;
- `ModalShade`;
- `ModalPanel`;
- `ToastPanel`.

Simple shades and fills should normally use `StyleBoxFlat`. Authored textures are reserved for frames, ornaments and surfaces where the artwork provides actual visual value.

### 4.2 Typography roles

The current Title/Subtitle/SectionHeader/Status roles remain valid.

Production UI should converge on a small hierarchy:

- display/title;
- screen heading;
- section heading;
- normal body;
- compact/supporting text;
- quantity/input/status text.

Do not create a separate font role for every screen.

### 4.3 Interaction states

Reusable interactive presentation must support distinct:

- normal;
- hover;
- keyboard/controller focus;
- pressed/active;
- selected where selection differs from focus;
- disabled/unavailable.

Changing state may alter frame, ornament, brightness or other presentation, but **must not shift content geometry**.

Focus is not mouse hover.

---

## 5. Shared structural components

Target reusable component set:

- `ItemSlot`;
- `ItemGrid`;
- `Hotbar`;
- `ResourceBar`;
- accepted `SectionHeader`;
- `SelectionDetailsPanel`;
- `InteractionPrompt`;
- `ObjectiveDisplay`;
- `NotificationToast`;
- `KeyPrompt`;
- `ModalDialog`;
- `WorldTransitionOverlay`.

Native Godot Controls remain preferred where they already satisfy the behavior. Do not wrap ordinary Labels, Buttons or Panels solely for naming consistency.

---

# 6. Gameplay HUD

Implementation planning authority: **UI-HUD-002 / #388**.

The current HUD is functionally useful but visually prototype-level: large framed vitals, permanent material counts, action-state text and four wide text hotbar labels. Production HUD should be substantially quieter.

## 6.1 Reference layout at 1280 × 720

```text
┌────────────────────────────────────────────────────────────────────┐
│  HEALTH / STAMINA                              CURRENT OBJECTIVE    │
│                                                                    │
│                                                                    │
│                              +                                     │
│                         [E] Mine Iron                              │
│                                                                    │
│                                                                    │
│                         +2 Iron Chunk                              │
│                                                                    │
│                  [1][2][3][4] ... future ...                      │
└────────────────────────────────────────────────────────────────────┘
```

## 6.2 Vitals

Top-left target envelope:

- x ≈ 24..300;
- y ≈ 24..112.

Health is primary. Stamina is subordinate.

Avoid a large dashboard frame unless later visual art requires one. Persistent `Action: Idle`, internal state names and similar engineering readouts do not belong on the production HUD.

## 6.3 Current objective

Top-right, max width approximately 360 px at 720p.

Shows:

- one current objective;
- optional one-line progress/subhint.

M3 objective truth belongs to #220 and is derived from authoritative semantic state. The HUD does not persist objective completion flags.

## 6.4 Reticle

True viewport center.

The reticle is a presentation aid, not hit authority.

## 6.5 Interaction prompt

Centered below reticle, nominal vertical zone y ≈ 395..440 at 720p.

Example:

`[ E ]  Mine Iron`

Key/glyph presentation and action/target copy are separate regions so future remapping/controller glyphs do not change interaction semantics.

Hide the entire prompt when no valid semantic interaction exists.

## 6.6 Feedback

Transient center-bottom feedback above Hotbar, nominal y ≈ 545..590.

Examples:

- `+2 Iron Chunk`;
- `Inventory Full`;
- `Crafted Iron Sword`;
- `Parry`.

Messages expire and may coalesce visually. Gameplay state is never inferred from rendered text.

The permanent top-right material list should disappear from normal HUD once Inventory + transient feedback provide sufficient visibility.

## 6.7 Hotbar

Bottom-center, minimum 24 px bottom safe inset.

Visual slot content target:

- 52–56 px square content;
- 60–64 px full state envelope;
- 6–8 px gap.

A nine-slot visual arrangement fits 1280 width comfortably: nine 60 px envelopes plus eight 6 px gaps ≈ 588 px.

### Important authority boundary

Current gameplay/equipment semantic hotbar is **1..4**. The visual component may support nine slots, but presentation must not manufacture selectable 5..9 slots.

A later gameplay/equipment task may expand the semantic model. The UI should then consume the expanded snapshot without redesign.

---

# 7. ItemSlot component

`ItemSlot` is the core repeated visual primitive for Hotbar and Inventory.

## 7.1 Geometry

Conceptual regions:

```text
┌─────────┐
│1        │  input/index
│         │
│  ICON   │
│      12 │  quantity
└─────────┘
```

Optional durability/cooldown strip may occupy the bottom edge once real semantics exist.

Icon placement, quantity placement and input-label placement remain invariant across selection/hover/focus states.

## 7.2 Presentation states

Minimum first set:

- empty;
- hands;
- item;
- selected;
- hover;
- focus;
- disabled/unavailable;
- invalid/error fallback.

Future states may be added only when gameplay actually exposes the meaning:

- cooldown;
- durability-low;
- new-item marker.

## 7.3 Data boundary

`ItemSlot` receives value-only presentation data. It does not receive InventoryService/CraftingService/EquipmentState as behavioral dependencies.

The presentation adapter may supply:

- display label/index;
- icon/presentation token;
- quantity;
- selected/focused/disabled state;
- optional ratios/markers;
- display kind.

Semantic item identity remains gameplay/content truth outside the component.

---

# 8. Inventory / Equipment overlay

Implementation planning authority: **UI-INV-001 / #390**.

## 8.1 Reference panel

At 1280 × 720:

- full-screen dim/transparent overlay;
- safe margin ≈ 48 px;
- primary panel ≈ 1120 × 620 centered.

Structure:

```text
┌───────────────────────────────────────────────────────────────┐
│ INVENTORY                                      capacity/close │
├───────────────────────────────────┬───────────────────────────┤
│                                   │                           │
│ [ ][ ][ ][ ][ ][ ]                │       ITEM DETAILS        │
│ [ ][ ][ ][ ][ ][ ]                │                           │
│ [ ][ ][ ][ ][ ][ ]                │       Item name           │
│ [ ][ ][ ][ ][ ][ ]                │       Description         │
│                                   │       Relevant stats      │
│                                   │       Equip / Drop ...    │
├───────────────────────────────────┴───────────────────────────┤
│ contextual controls / controller hints                       │
└───────────────────────────────────────────────────────────────┘
```

Suggested vertical structure:

- Header ≈ 56 px;
- Content flexible ≈ 490 px;
- Footer ≈ 48 px.

Suggested horizontal content split:

- inventory area ≈ 680–720 px;
- details area ≈ 340–380 px;
- gap/divider ≈ 16–24 px.

## 8.2 ItemGrid

Initial visual reference: six columns at approximately 72–80 px pitch.

The visible grid is not inventory capacity authority. When the canonical container exceeds visible rows, scroll.

Required behavior:

- deterministic ordering from presentation adapter;
- 2D keyboard/controller navigation;
- mouse click selection;
- stable focus during scrolling where practical;
- no direct mutation.

## 8.3 Details panel

Selected item details include only player-relevant authored information:

- icon/placeholder;
- name;
- category/type;
- quantity where relevant;
- short description;
- relevant stats/capabilities;
- valid contextual actions.

Do not expose ContentId, StableId, schema IDs, source fingerprints or internal descriptor data in ordinary UI.

## 8.4 Equipment

Do not prematurely build a large MMO paper-doll screen.

First slice uses a compact loadout/equipment section inside the details side. As real armor/equipment breadth increases, a later dedicated layout may reuse the same ItemSlot/details components.

---

# 9. Crafting overlay

Implementation planning authority: **UI-CRAFT-002 / #391**.

Crafting uses the same overall overlay shell and details grammar as Inventory.

## 9.1 Reference layout

At 1280 × 720:

- primary panel ≈ 1120 × 620;
- header ≈ 56 px;
- left recipe list ≈ 320–360 px;
- right recipe details ≈ 700–740 px;
- footer ≈ 48 px.

```text
┌───────────────────────────────────────────────────────────────┐
│ CRAFTING                                             close    │
├───────────────────────┬───────────────────────────────────────┤
│ RECIPE LIST           │ RECIPE DETAILS                        │
│                       │                                       │
│ Stone Axe             │ [icon] STONE AXE                      │
│ Stone Pickaxe         │                                       │
│ Iron Sword            │ Requires                              │
│                       │ Wood        4 / 4                      │
│                       │ Iron        3 / 4                      │
│                       │                                       │
│                       │                         [ CRAFT ]      │
└───────────────────────┴───────────────────────────────────────┘
```

## 9.2 Recipe list

Use a vertical list rather than ItemGrid by default.

Each row may show:

- output icon;
- recipe/output name;
- compact availability marker.

Ingredient detail belongs in the details pane.

## 9.3 Recipe details

Show:

- output presentation;
- name/description;
- required ingredients with `owned / required`;
- station/capability requirement when real semantics exist;
- output quantity;
- Craft action.

The UI may predict availability for convenience, but CraftingService remains final transaction authority and must revalidate.

No optimistic ingredient removal before successful commit.

---

# 10. Title and Pause

Existing structure is retained.

## 10.1 Title target

Eventually:

1. Continue;
2. New Game;
3. Settings;
4. Quit.

Continue is disabled/omitted according to accepted slot probe semantics.

## 10.2 Pause target

1. Resume;
2. Settings;
3. Save & Quit;
4. Quit Game.

Destructive quit paths use the generic modal contract where confirmation is required.

UI does not perform SAVE directly; it dispatches intent to accepted GameFlow/AppRoot authority.

---

# 11. Settings

System planning authority: **UI-SYS-001 / #393**.

## 11.1 Reference layout

At 1280 × 720:

- centered panel ≈ 1050 × 620;
- left category navigation ≈ 220–260 px;
- right settings content flexible and scrollable;
- header/footer ≈ 56/48 px.

Initial categories only when populated:

- Gameplay;
- Video;
- Audio;
- Controls;
- Accessibility.

Do not create empty categories for visual scale.

Keyboard/controller focus order follows visual order. Risky display settings may require revert confirmation once those settings exist.

---

# 12. Modal dialog

One reusable modal shell.

Reference width ≈ 440–600 px depending copy.

Structure:

- title;
- concise body;
- optional detail;
- primary/secondary actions.

Rules:

- captures focus;
- background controls cannot activate;
- destructive dialog default focus is safe;
- Back/Escape behavior is explicit;
- presentation returns user intent to owner and does not mutate gameplay/persistence by itself.

---

# 13. Notifications / toasts

Use a bounded presentation queue.

Typical message classes:

- pickup/resource;
- craft/equip;
- capacity warning;
- save result;
- objective update;
- combat feedback.

Repeated low-priority events may coalesce visually. Important failure must not be buried behind pickup spam.

No toast may become gameplay event authority.

---

# 14. World transition overlay

System planning authority: **#393**. Runtime readiness/performance truth remains owned by cave/AppRoot/PERF work.

The current cold cave route has measured multi-second generation/extraction cost. The player should receive deliberate transition presentation instead of a frozen-looking screen.

## 14.1 First version

- full-screen or near-full-screen fade/shade;
- centered semantic status such as `DESCENDING...`, `RETURNING TO SURFACE...`, or `LOADING WORLD...` where accurate;
- subtle indeterminate activity indicator.

### Hard rule

> **Never display a fake 0–100% progress percentage unless runtime exposes a meaningful monotonic progress contract.**

If runtime later exposes real stage/progress semantics, the same overlay may render them.

The overlay disappears only when the owning runtime/lifecycle authority reports readiness. Timer-only guesses are not readiness authority.

---

# 15. Death / recovery presentation

Minimal overlay; lifecycle remains outside UI.

First slice:

- impact/fade presentation;
- short `YOU FELL` status;
- optional `Recovering...` while accepted recovery authority resolves/commits;
- fade back to gameplay after accepted recovery.

No checkpoint calculation, teleport selection or SAVE behavior in presentation.

---

# 16. Input and focus rules

## 16.1 Mouse

- hover is visual only unless an explicit tooltip delay exists;
- click selects/activates according to component semantics;
- scrolling affects the focused/hovered scroll region only.

## 16.2 Keyboard/controller

All interactive screens require deterministic focus order.

- grid screens: spatial 2D navigation;
- list screens: vertical navigation;
- top-level categories/tabs: explicit directional/shoulder navigation where needed;
- Confirm invokes the current safe primary action;
- Back closes current sublayer/modal according to explicit hierarchy.

Focus indicator must remain distinct from selected state when both can exist.

## 16.3 Gameplay passthrough

HUD is passive and mouse-passthrough.

Interactive Overlay/Modal focus must prevent unintended gameplay actions. Do not solve this by letting every screen independently disable Player; use accepted input/GameFlow context ownership.

---

# 17. Accessibility baseline

First production baseline:

- visible keyboard/controller focus;
- selected/focus/disabled states not distinguishable by hue alone;
- health/stamina differentiated by more than color where practical;
- text wraps/clamps at 720p;
- key prompts are replaceable by remapped keyboard/controller display;
- no essential information depends on DebugHUD;
- transition presentation does not require flashing;
- architecture leaves room for UI scale without baking critical information into fixed textures.

Do not claim full accessibility support before corresponding systems exist; preserve clean semantic labels and component boundaries so later accessibility work is possible without a rewrite.

---

# 18. UI skin / atlas authoring set

The reusable authored art set should remain intentionally small.

Suggested source families:

- scalable panel frame;
- inset/details panel frame if visually distinct;
- button normal / hover / focus / pressed / disabled;
- item slot normal / hover / focus / selected / disabled;
- tooltip/modal frame;
- tab normal / selected / focus where needed;
- separators/ornaments;
- optional generic keycap frame;
- generic placeholder icon.

Bars, simple fills and shades should normally remain Theme/StyleBox resources rather than consuming texture assets.

Dynamic names, quantities, recipe costs, objective text and semantic identity are never baked into runtime textures.

---

# 19. Implementation sequencing

Recommended order once ownership/dependencies permit:

1. #220 M3 objective/feedback semantics stabilize.
2. #388 reusable ItemSlot + ResourceBar + Hotbar and production HUD layout.
3. #390 Inventory/Equipment overlay using shared ItemSlot/Details components.
4. #391 Crafting overlay using shared shell/details grammar.
5. #393 modal/toast/key-prompt/transition slices according to immediate need.
6. Settings expands as real settings breadth appears.
7. Later character creation/mastery/profession UI consumes these primitives rather than creating parallel design systems.

M3 closeout remains protected: broad post-M3 screens do not become reasons to delay the First Real Playable unless a missing UI piece is truly required by acceptance.

---

# 20. Validation contract

Implementing cards should extend current UI/HUD validation wherever practical.

Prove:

- geometry/state invariance;
- semantic Theme reuse;
- correct safe-area/resolution behavior;
- deterministic keyboard/controller focus;
- HUD recursive mouse passthrough;
- Overlay/Modal focus capture;
- canonical read-only rendering does not mutate inventory/equipment/world/save state;
- failed actions refresh from canonical state and do not leave optimistic UI truth;
- replacement skin assets do not require screen hierarchy/gameplay changes.

---

# 21. Explicit non-goals

This specification does not authorize:

- a minimap;
- a quest framework/database;
- MMO-style permanent material/stat dashboards;
- a giant paper-doll inventory before equipment breadth exists;
- an MMO-scale crafting browser for the current small recipe set;
- final icon production;
- final typography/art polish;
- hotbar gameplay expansion from 1..4 to 1..9;
- a second inventory/crafting/equipment/save authority;
- durable screen-local progression flags.

Future gameplay systems may extend the UI, but they should reuse this design grammar unless a concrete product reason requires a new one.
