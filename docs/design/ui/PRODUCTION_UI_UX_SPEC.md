# Underworld Production UI / UX Specification

Status: **FROZEN DESIGN AUTHORITY CANDIDATE — UI-UX-002 / #387**  
Accepted runtime UI foundation: **UI-ARCH-001 / #262**  
Accepted architecture authority: **ADR-001 / DOCS-ARCH-001, landed through #428 at `b1974fe8…`**  
Synchronized source base: **`main@5081c556…`**  
Independent design review: **#396**  
Reference logical viewport: **1280 × 720**

This document defines the production UI/UX architecture for Underworld. It freezes layout hierarchy, interaction behavior, focus/input ownership, component boundaries, responsive rules and presentation authority. It deliberately does **not** freeze final artwork.

> **Placeholder art is disposable. Layout, interaction and component contracts are production architecture.**

Final textures, icons, ornaments and typography treatment may be replaced without restructuring screens or changing gameplay authority.

---

## 1. Existing architecture to preserve

The accepted #262 architecture remains authoritative:

- runtime UI is composed with Godot `Control` nodes, anchors and Containers;
- `presentation/ui/theme/underworld_theme.tres` is the semantic screen-facing styling API;
- scalable authored frames use Theme/`StyleBoxTexture` 9-slice resources where useful;
- simple fills, shades, progress tracks and masks prefer `StyleBoxFlat`/native Controls;
- prototype art under presentation assets is replaceable;
- reusable component scenes exist only for genuinely repeated structure or presentation behavior;
- AppRoot/Game/GameFlow/Inventory/Crafting/Persistence/WorldDomain/Building remain their existing authorities;
- UI never becomes durable gameplay truth.

A UI atlas/tilesheet is an **authoring/packaging convenience**, not a runtime `TileMap` layout authority.

---

## 2. Logical canvas, scaling and safe areas

### 2.1 Logical reference

All production UI is designed in one logical **1280 × 720** coordinate space at UI scale 1.0.

The project should use one coherent root UI scaling authority as defined by #423: Canvas Items/stretch behavior + Expand-compatible layout. Individual screens do not invent independent 720p/1080p/1440p scale systems.

### 2.2 Safe-area tokens

Reference safe insets at scale 1.0:

- **HUD:** 24 px minimum;
- **overlay/menu:** 48 px minimum;
- accepted Title/Pause menu-safe margins may remain larger where their Theme role requires it.

Reference geometry is a target envelope, not permission to use absolute-only positioning. Anchors and Containers remain runtime layout authority.

### 2.3 Responsive proof

Validate at minimum:

- 1280×720;
- 1920×1080;
- 2560×1440;
- representative ultrawide;
- representative increased UI scale when #423 exposes a real user preference.

At larger resolutions the UI may gain whitespace; it should not become a different product layout unless a deliberate breakpoint is defined.

Long localized text wraps/reflows rather than shrinking below readable metrics.

---

## 3. Lifetime and layer model

Reuse does not imply one global UI singleton. Components may be reused under different lifetime owners.

### 3.1 Game-route lifetime

Destroyed when the Game route is removed:

- Gameplay HUD / reticle / vitals / Hotbar / Objective;
- contextual InteractionPrompt;
- gameplay notification queue;
- Inventory/Crafting overlays;
- Building Catalog/Placement presentation;
- death/recovery presentation;
- in-Game Overworld↔Underworld `WorldTransitionOverlay`.

### 3.2 AppRoot lifetime

May survive Title/Game route replacement:

- Pause root;
- shared Settings host opened from Title or Pause;
- app-level Modal host for destructive/system decisions;
- #399 focus/input coordinator where composition requires it;
- #427 Title→Game startup loading host.

AppRoot lifetime does not grant gameplay authority.

### 3.3 CanvasLayer ordering convention

Centralize layer constants rather than scattering magic numbers.

Reference bands:

- `10` — Gameplay HUD;
- `20` — gameplay notifications;
- `30–49` — interactive Game overlays;
- `50–59` — Game-local modal surfaces;
- `60–69` — death/recovery;
- `80–89` — in-Game #404 world-domain transition;
- `90–99` — AppRoot #427 Title↔Game startup loading;
- `100` — Pause;
- `110` — AppRoot Settings;
- `120` — app-level Modal;
- Debug uses an explicit separate developer policy and must never collide with Pause.

Layer number is presentation ordering only. It does not grant lifecycle, pause, input or world-transition authority.

Equal independently-owned production CanvasLayer indices are not intentional architecture.

---

## 4. Interaction/focus ownership

Interactive UI uses #399's authoritative focus/capture stack. `Control.accept_event()` alone is insufficient because Player also consumes frame-polled input.

### 4.1 Top-surface rule

Only the top interactive surface receives navigation/Confirm/Back.

Required Back precedence:

1. active Modal;
2. nested child such as Settings/rebind capture;
3. Inventory/Crafting/Build Catalog root;
4. Building placement hierarchy where gameplay context owns Back;
5. Pause/GameFlow only when no higher owner consumed it.

Do not depend on arbitrary Godot node callback ordering.

### 4.2 Gameplay suppression

While an interactive gameplay overlay owns capture:

- attack/harvest/hotbar/jump/dodge/parry/block/sprint cannot fire from UI navigation;
- movement resolves according to accepted input-gate policy rather than continuing as an unintended held state;
- mouse-look is suppressed while pointer UI owns the cursor;
- closing UI must not replay `just_pressed` actions from the key/button that closed it.

Simulation pause remains GameFlow/product policy, separate from UI focus ownership.

### 4.3 Paused-tree UI

AppRoot Settings/Modal/focus hosts that must operate while `SceneTree.paused == true` use or inherit `PROCESS_MODE_ALWAYS` as appropriate.

Pause→Settings and Pause→confirmation remain fully interactive and can receive operation completion/failure while gameplay is paused.

### 4.4 System quit intent

Window-manager close / Alt+F4 is a **quit intent**, not Back.

During an active Game it must not bypass `QUIT GAME?` safety. It may temporarily preempt the current UI focus stack with the quit confirmation. Cancel restores the exact prior surface/focus state.

From Title, where no live gameplay progress is at risk, ordinary application quit may remain direct.

---

## 5. Theme, skin and design tokens

Add semantic Theme roles only when consumed.

### 5.1 Shared visual roles

Expected families include:

- menu/overlay/content/modal/toast panels and shades;
- ItemSlot normal/hover/focus/selected/disabled/invalid states;
- health/stamina ResourceBar roles;
- keycap/prompt roles;
- compact/body/heading/status typography;
- Settings category/row states;
- transition/death presentation roles.

Screens never reference atlas coordinates or prototype art filenames directly.

### 5.2 Skin authoring contract

#397 owns the reusable skin atlas/Theme extension contract.

Important fixed reference geometry:

- scalable panel source: 96×96 with 24 px protected edges;
- button source: 96×48 with 20 px horizontal / 14 px vertical protected edges;
- shared ItemSlot frame: **64×64** logical envelope;
- ItemSlot icon safe box: **40×40**, centered;
- all interaction-state variants preserve identical geometry.

Item/content icons are a separate presentation-content domain and are not baked into the UI skin atlas.

---

## 6. Minimal shared structural component set

First shared structures are deliberately bounded:

1. accepted `SectionHeader`;
2. `ItemSlot`;
3. `ResourceBar`;
4. `KeyPrompt` / InteractionPrompt composition;
5. `BoundedScreenShell` for the now-proven repeated large-panel grammar;
6. `NotificationToast` when #415 is implemented;
7. `ModalDialog` when #398/#393 needs it.

Higher-level screen-owned compositions such as Hotbar, ItemGrid, ObjectiveDisplay and recipe lists are extracted only where their owning screen benefits.

Do **not** build generic Tooltip, custom TabBar or generic SelectionDetailsPanel in the first foundation slice merely because names appeared in early planning. Inventory, Crafting, Building and Settings already have persistent details/help regions; extraction requires real repeated behavior.

Native Labels/Buttons/Panels remain native controls unless wrapper behavior is justified.

---

## 7. ItemSlot

One shared ItemSlot is reused by HUD Hotbar and Inventory/loadout contexts.

### 7.1 Logical geometry

Fixed logical envelope at scale 1.0: **64×64**.

Reference internal regions:

- icon: centered 40×40 safe box;
- binding/index presentation: top-left safe corner;
- quantity: bottom-right;
- optional future semantic strip: bottom interior, maximum about 4 px, hidden unless real durability/cooldown semantics exist.

Normal/hover/focus/selected/disabled/invalid states never move these regions or change the control minimum size.

### 7.2 GUI ownership

Exactly one child owns GUI input.

Conceptual structure:

```text
ItemSlot (Control 64×64)
├─ BaseFrame            # mouse ignore
├─ Icon                 # mouse ignore
├─ KeyOrIndexLabel      # mouse ignore
├─ QuantityLabel        # mouse ignore
├─ BottomStrip          # mouse ignore
├─ StateOverlays        # mouse ignore
└─ InputSurface         # sole transparent Button/BaseButton owner
```

Passive HUD mode:

- `InputSurface.mouse_filter = IGNORE`;
- `focus_mode = FOCUS_NONE`;
- no activation signal;
- full subtree remains gameplay-mouse-passthrough.

Interactive mode:

- InputSurface owns pointer/focus/activation;
- native Button chrome is visually neutral;
- ItemSlot semantic overlays render selected/focus/hover states;
- parent screen receives a slot intent, never an equip/craft operation directly.

### 7.3 Value-only snapshot

ItemSlot consumes presentation values such as:

- opaque slot id/index;
- kind: empty / hands / item / invalid;
- resolved icon/token;
- quantity text;
- binding/index text;
- selected/unavailable state;
- optional bottom ratio/role;
- player-facing accessibility label.

No gameplay service or mutable container object is passed into ItemSlot.

### 7.4 Binding presentation

Hotbar semantic slot order remains canonical **1..4** today.

The top-left keycap is not permanently hard-coded to physical `1`, `2`, `3`, `4` once rebinding exists. It consumes #410's current binding presentation for the semantic hotbar action. Remapping changes the displayed binding, not equipment order.

---

## 8. ResourceBar

Reusable for health/stamina and later real bounded resources.

Consumes:

- finite ratio 0..1;
- optional formatted current/max text;
- optional label;
- parent-configured semantic Theme role.

Non-finite input fails visibly to a safe empty/error presentation; it is never propagated into layout.

Visual interpolation is allowed but authoritative state always remains the supplied snapshot.

No mutation methods exist.

---

# 9. Gameplay HUD

Implementation owner: **#388 UI-HUD-002**.

The production HUD removes the current text-heavy prototype dashboard and permanent material list.

## 9.1 Reference geometry at 1280×720

### Vitals — top-left

Reference envelope:

- left 24;
- top 24;
- max width about 280;
- normal height about 72–88.

Health is primary; Stamina is subordinate. No permanent developer `Action: Idle/...` state.

### Objective — top-right

- right safe edge 1256;
- top 24;
- max width 360;
- one headline plus at most one subordinate progress/hint line.

#220 provides structured presentation data. UI never persists quest/objective flags.

### Reticle

Exact visible viewport center: `(640, 360)` at the reference canvas.

### InteractionPrompt

- centered below reticle;
- max width about 420;
- nominal y about 398..446;
- hidden completely when no valid semantic contextual action exists.

The prompt consumes #416's read-only contextual-action descriptor and #410's binding presentation. HUD must not perform its own raycast or duplicate harvest/resource/gateway eligibility rules.

A mockup such as `[E] Mine Iron` is illustrative only; physical E is not interaction authority.

### Local discrete action feedback

High-frequency committed hit progress such as `Rock 2/3` or `Tree 1/4` uses one short-lived reticle/prompt-local lane.

It is:

- not a global Toast;
- not a fake continuous hold-progress bar;
- replaced/cleared by subsequent local action state;
- driven by committed semantic hit outcomes.

### Hotbar — bottom-center

- shared 64×64 ItemSlot;
- 6 px reference gap;
- bottom safe inset 24;
- current four semantic slots occupy 274 px centered;
- future nine semantic slots occupy 624 px centered.

Current runtime renders only real semantic 1..4. A nine-slot fixture may prove layout capacity but must not create actionable fake slots 5..9.

### Global notification stack

Anchored bottom-center immediately above Hotbar:

- max width about 480;
- bottom about y=616;
- 12–16 px gap above Hotbar;
- grows upward;
- maximum **3 visible** entries;
- normal row roughly 32–36 px plus 6–8 px separation.

At max three rows the stack occupies roughly y≈492..616, leaving separation from the InteractionPrompt.

The old one-line `y≈545..590` feedback region is obsolete.

### Permanent prototype removals

Normal HUD does not retain:

- permanent material inventory list;
- permanent `_feedback_text`;
- developer action-state string;
- 145×44 text hotbar labels;
- DebugHUD information as a correctness dependency.

---

## 10. InteractionPrompt execution feedback

Preview and execution share gameplay targeting/eligibility authority.

Flow:

```text
read-only contextual query
-> value-only prompt descriptor
-> user activates semantic action
-> gameplay revalidates target/state
-> semantic success/rejection result
-> HUD refreshes prompt/local feedback
```

Rejected execution may expose bounded semantic reasons such as missing required tool, stale target or capacity failure. UI does not parse prototype `last_action_message` or developer diagnostics.

Auto-collected loot does not fabricate a manual interaction prompt.

Building placement remains a separate gameplay input context and Placement HUD.

---

# 11. Inventory / Equipment overlay

Implementation owner: **#390 UI-INV-001**.

## 11.1 Shell

Reference 1280×720:

- overlay safe margin 48;
- centered main panel about **1120×620**;
- header about 56;
- content flexible;
- footer about 48 only when real actions require it.

Use the shared `BoundedScreenShell` outer grammar.

## 11.2 Canonical V1 grid

Current production Inventory is a real **16-slot fixed-capacity container**.

V1 reference is therefore **4 columns × 4 rows**, preserving exact canonical slot indices and empty holes.

Rules:

- iterate actual slot space, not a compacted occupied-item list;
- all visible canonical cells participate in deterministic spatial keyboard/controller navigation, including empty holes;
- empty cell activation is a no-op until a real move/place operation exists;
- empty focus clears/shows bounded empty Details state;
- if capacity grows beyond the reference, ItemGrid may reflow/scroll without changing ItemSlot architecture;
- do not hard-code 16 as permanent future capacity authority.

The obsolete generic six-column reference is retired.

## 11.3 Inventory regions

At 720p use roughly:

- inventory/grid region: 680–720 px;
- details/loadout region: 340–380 px;
- gap/divider: 16–24 px.

Do not stretch the 4×4 grid merely to fill empty width. Use remaining space for hierarchy/details rather than oversized slots.

## 11.4 Details

Current canonical item data supports:

- icon/presentation identity;
- display name;
- category/type;
- quantity;
- concise authored description where metadata exists;
- stack/weight information where player-relevant;
- operation actions allowed by real gameplay composition.

There is currently no durable production durability schema; do not ship a durability bar because a test fixture contains a `durability` key.

Do not expose raw ContentIds/StableIds/schema IDs/fingerprints.

## 11.5 Weight

Current default `max_weight == -1` means unlimited weight.

Hide weight-capacity UI while no finite meaningful capacity exists. Do not show a meaningless `0 / ∞` meter.

## 11.6 Equipment/loadout

V1 uses a compact four-entry loadout strip, not an MMO paper doll.

Current semantic vocabulary is `Hands / Axe / Pickaxe / Utility`, bound to hotbar 1..4.

These slot labels are equipment presentation vocabulary. They are **not** #400 ContentIds.

Item names/icons/descriptions resolve through #400; target compatibility comes from #421/gameplay authority.

## 11.7 Equip / Unequip

Presentation submits intents through the live gameplay command seam (#422). It never instantiates EquipmentService or mutates containers itself.

A bounded machine-readable failure kind must distinguish cases such as:

- source empty/stale;
- no compatible target;
- displaced-item inventory capacity failure;
- invalid equipment state.

Player-facing UI maps semantic kinds, never diagnostic-string wording.

Do not add Drop, Split, arbitrary drag-reorder or merge actions before accepted services exist.

---

# 12. Crafting overlay

Implementation owner: **#391 UI-CRAFT-002**.

Crafting reuses `BoundedScreenShell`, ItemSlot visual grammar and the same overall details hierarchy, but not inventory transaction authority.

## 12.1 Honest V1 breadth

Current production catalog contains only three hand recipes:

1. Stone Axe;
2. Stone Pickaxe;
3. Iron Sword.

V1 therefore uses a compact vertical recipe list around **280–320 px** rather than pretending to need a large MMO crafting browser.

Hide until real breadth exists:

- category rail;
- search;
- favorites/recent;
- station tabs;
- queue/batch system.

The shell can grow later without redesign.

## 12.2 Recipe discovery

Enumerate accepted recipe definitions semantically from ContentRegistry (`definition_ids_for_family("recipe")` or accepted equivalent).

Do not build a hard-coded list of resource `.tres` paths.

A stable presentation order may prioritize Stone Axe → Stone Pickaxe → Iron Sword while unknown/new recipes append deterministically.

## 12.3 Recipe details

Show:

- output icon/name/description;
- output count;
- ingredients as `owned / required`;
- station/capability requirement only when real;
- Craft action;
- concise disabled reason where semantic preflight provides one.

## 12.4 Craftability authority

#414 exposes authoritative **non-mutating preflight** composed from the real transaction validator.

UI uses its machine-readable availability/failure classification for button state/reason. It never parses human diagnostic strings.

Possible bounded classes include missing ingredients, missing context/capability, output capacity, weight capacity or invalid recipe/content.

Preflight does not reserve resources. On activation `craft(...)` revalidates and commits atomically.

No optimistic ingredient removal/output animation before accepted commit.

Once this screen becomes the production crafting route, prototype direct C/V recipe shortcuts are retired rather than remaining a second player-facing authority.

---

# 13. Title menu

Implementation owner: **#398 UI-MENU-002**.

Preserve the accepted centered MenuPanel architecture.

Reference panel width: about 460 px.

Visual action order:

1. Continue;
2. New Game;
3. Settings;
4. Quit.

Continue remains in the layout even when disabled so availability does not move other actions.

When Continue is unavailable (`checking`, `none`, `incompatible` or `invalid`), its control is disabled and explicitly **non-focusable (`FOCUS_NONE`)**. Keyboard/controller navigation must never land on an unavailable Continue action.

## 13.1 Continue state

Presentation consumes a bounded persistence/AppRoot classification, conceptually:

- `checking`;
- `available`;
- `none`;
- `incompatible`;
- `invalid`.

UI never probes `user://`, schema files or raw save diagnostics itself.

`none` is quiet. `incompatible`/`invalid` may show concise player-safe status text without raw technical diagnostics.

## 13.2 Initial focus and async availability

If availability is already resolved:

- `available` → Continue initial focus;
- otherwise → New Game.

If availability is still `checking`:

- New Game may hold **provisional** initial focus so the menu is immediately usable;
- if Continue resolves available before the user has navigated/activated anything, Continue may take initial focus exactly once;
- the first real user navigation/activation or explicit focus-finalization closes this provisional window;
- after that, availability refresh never steals focus;
- disabling currently focused Continue moves to deterministic safe fallback New Game.

## 13.3 New Game and overwrite truth

Starting New Game does not itself delete the existing slot; do not present it as destructive.

#424 owns confirmation at the actual overwrite-capable Save boundary when a separately started NEW lineage would replace an existing valid Continue slot.

Normal CONTINUE→Save remains frictionless.

---

# 14. Pause menu

Reference panel width: about 460 px over the frozen gameplay view.

Order:

1. Resume;
2. Settings;
3. Save & Quit to Title;
4. Quit Game;
5. bounded operation/failure region only when needed.

Initial focus: Resume.

## 14.1 Settings

Pause remains GameFlow-paused. Settings becomes top focus; Back closes Settings only and restores focus to Pause Settings.

## 14.2 Save & Quit

Root button emits user intent.

Flow:

```text
Save & Quit intent
-> #424 overwrite preflight
-> if confirmation needed: Modal, safe default CANCEL
-> if authorized: GameFlow operation lock
-> Pause-local SAVING... indeterminate state
-> accepted SAVE exactly once
-> accepted Title route
```

No fake percentage. No duplicate dispatch while operation active.

SAVE failure remains Pause-local, keeps gameplay paused and restores usable focus.

If SAVE succeeds but Title routing fails, the newly successful durable slot remains committed according to accepted GameFlow policy.

## 14.3 Quit Game

Always uses:

- title `QUIT GAME?`;
- safe/default `CANCEL`;
- destructive `QUIT WITHOUT SAVING`.

Modal returns intent; it never calls FileAccess, SAVE or `quit()` itself.

Window-manager quit from an active Game uses the same safety policy.

---

# 15. Settings

Implementation owner: **#412 UI-SETTINGS-001**, consuming #409/#410/#399.

Reference panel: about **1050×620**, bounded and centered.

Reference structure:

- header about 56;
- category rail 220–260 when multiple real categories exist;
- scrollable content;
- footer about 48 only when a real deferred Apply policy requires it.

## 15.1 Capability-driven categories

Never display empty categories merely to mimic a large game.

Current first legitimate preference is:

- **Audio → Mute** (`audio.muted`) once #409 is implemented.

Controls appears when #410 is accepted.

Do not fabricate Master/Music/SFX sliders, Video settings, UI Scale row or Accessibility rows before corresponding authorities exist.

## 15.2 Preference lifetime

Application preference authority lives above the Game route.

- Title can change/persist Mute with no active Game audio controller;
- new Game initializes its Game-local audio controller from current preference;
- Pause Settings updates the active controller immediately through accepted authority;
- Settings never writes ConfigFile/user paths directly.

## 15.3 Apply policy

Settings respects each preference descriptor:

- safe immediate setting (e.g. Mute) applies/validates immediately;
- deferred settings create Apply/Cancel only when a real preference needs them;
- risky future display settings may use Keep/Revert modal only after a real display authority exists.

There is no fake global Apply transaction.

## 15.4 Rebinding

Rebind capture is a top interactive surface.

- opening input cannot become the captured binding;
- Back/Escape cancels by default;
- gameplay remains suppressed;
- conflict policy comes from #410;
- binding presentation everywhere refreshes from the same authority.

---

# 16. ModalDialog

Shared reusable intent-only component.

Reference width: 440–600 px, content-driven height with viewport-safe clamp.

Structure:

- shade;
- title;
- concise body;
- optional detail region;
- actions.

Rules:

- captures top focus through #399;
- background controls inert;
- destructive decisions default to safe action;
- Back policy explicit;
- emits semantic intent id only;
- never performs gameplay/persistence/application mutation itself.

### Responsive actions

Two actions may render horizontally when they fit.

With long localization or large UI scale they may reflow to a vertical stack while preserving:

- semantic action order;
- safe/default focus;
- destructive distinction;
- full readable labels.

Do not shrink buttons/fonts below readable metrics just to preserve one row.

---

# 17. Notifications / Toasts

Implementation owner: **#415 UI-FEEDBACK-001**.

Notifications are event-driven presentation of already committed semantic outcomes.

They are never inferred by polling Inventory changes and never become a gameplay event bus.

## 17.1 Queue bounds

Reference:

- max visible: 3;
- max pending: 8;
- normal lifetime about 2–3 s;
- warning lifetime about 3–4 s;
- deterministic order;
- no permanent gameplay Toast.

## 17.2 Coalescing

Presentation may combine independently committed compatible outcomes, e.g. repeated `+1 Iron` into `+3 Iron` inside a bounded window.

Coalescing never alters inventory/event truth.

## 17.3 Priority admission

When visible capacity is full, a newly admitted high-priority warning may presentation-evict an older lower-priority acquisition Toast.

This changes only presentation residency; gameplay event/order/state remains untouched.

Important failure must not sit invisibly behind pickup spam.

## 17.4 Overlay suppression

While Inventory/Crafting/Build Catalog is open:

- canonical state still updates;
- low-priority acquisition messages already obvious in the open surface may be dropped/suppressed presentation-only;
- do not build a historical hidden backlog and replay it on close;
- queue size remains bounded.

## 17.5 Pause timing

Toast lifetime is presentation time, not paused gameplay time.

Either use an appropriate `PROCESS_MODE_ALWAYS` presentation clock or monotonic timestamps so a 2.5 s Toast covered by a >2.5 s Pause is gone on resume.

Continuing Toast timing does not unpause or generate gameplay events.

## 17.6 Producer mapping

- acquisition/resource/loot success: global Toast when useful;
- `harvest.hit_registered`: local action lane, not global queue;
- hotbar selection: no global Toast once ItemSlot state is obvious;
- `Inventory Full` auto-pickup rejection: consume #426 semantic rejection and bounded cooldown/coalescing; never infer by polling;
- craft success/equip partial failure: accurate semantic presentation;
- Save & Quit: Pause-local, not gameplay Toast;
- death: death overlay;
- world-domain transition: transition overlay.

---

# 18. BoundedScreenShell

Repeated large interactive panel structure is now proven across Inventory, Crafting, Building Catalog and Settings.

Shared shell owns only:

```text
full-rect Control
├─ semantic Shade
└─ SafeMargin
   └─ Center
      └─ semantic Panel
         └─ VBox
            ├─ HeaderHost
            ├─ ContentHost
            └─ FooterHost (optional)
```

Parent supplies only actual geometry/Theme configuration and fills hosts.

The shell does **not** own:

- CanvasLayer/lifetime;
- process mode;
- Back routing;
- #399 capture;
- pause state;
- gameplay service/controller references;
- screen-specific actions.

Title/Pause keep their simpler accepted MenuPanel shell.

---

# 19. World transitions and startup loading

Full domain-specific contract is in `WORLD_DOMAIN_UI_AMENDMENT.md`.

Important split:

- in-Game #404 Overworld↔Underworld transition is Game-owned;
- #427 Title→New/Continue startup loading is AppRoot-owned.

They may share visual grammar but not lifetime/authority.

Both use honest indeterminate presentation unless a runtime exposes meaningful monotonic progress.

A loading screen never hides an unbounded performance defect from #364/#369.

---

# 20. Death / recovery presentation

Minimal bounded narrative:

- impact/fade;
- `YOU FELL`;
- optional `Recovering...` while accepted recovery/world-transition authority operates;
- clear only after accepted recovery commit.

UI does not select checkpoint/domain/coordinate, call SAVE, heal Player or invoke respawn itself.

Cross-domain recovery uses #404 transition semantics; presentation remains one narrative rather than exposing internal route machinery.

---

# 21. Building UI

Detailed authority candidate: `BUILDING_UI_UX_SPEC.md` / #407.

Core invariants:

- Build Catalog and Placement HUD are separate surfaces;
- shape/category-first discovery scales toward 1000+ pieces;
- material normally acts as facet/filter;
- grid/socket snapping is assistance, not authority;
- deliberate FREE placement is first-class;
- overlap/near-overlap/terrain embedding may be valid and must not look like generic errors;
- hard-invalid comes only from authoritative Building validation;
- support readability is not color-only;
- repeated placement does not reopen Catalog after every piece;
- one UI serves both world domains;
- Phase-3 V1 proves a small real kit; Search/Favorites/Recent/virtualization activate only when scale warrants them;
- placement semantic actions come from #408/#410, never hard-coded physical keys.

---

# 22. Presentation-data boundaries

## 22.1 Content presentation — #400

#400 resolves player-facing metadata for semantic content identities such as items/recipes/build pieces:

- display name;
- icon/preview token;
- concise description;
- presentation category/tags where appropriate.

Screens do not title-case ContentId suffixes as production authority and do not maintain duplicate dictionaries.

## 22.2 Non-content vocabularies

Not every semantic key is a ContentId.

Examples such as equipment-slot labels (`Hands`, `Axe`, `Pickaxe`, `Utility`) use their owning presentation adapter/vocabulary, not #400.

## 22.3 Machine-readable operation failures

Operation-facing UI consumes small semantic result classes/codes rather than parsing developer diagnostic strings.

Required examples include:

- Crafting preflight #414;
- Equip/Unequip #422;
- contextual interaction #416;
- pickup rejection #426;
- slot/save classifications at AppRoot/Persistence boundaries.

Raw diagnostic arrays remain logging/test evidence.

---

# 23. Accessibility baseline

First production baseline requires:

- focus visually distinct from hover;
- focus + selection simultaneously legible;
- selected/disabled/destructive/valid-invalid state not hue-only where practical;
- health/stamina distinguishable by more than hue;
- long text wraps/clamps;
- no essential information depends on DebugHUD;
- no flashing requirement;
- no critical information only available by mouse hover;
- deterministic controller/keyboard navigation;
- architecture compatible with future UI scaling/reduced-motion preferences.

Do not fabricate a complete screen-reader/subtitle/accessibility subsystem before real product requirements exist, but preserve semantic labels and clean structure.

---

# 24. Implementation sequencing and parallel path ownership

Broad UI implementation remains controlled and should not become an M3 feature-expansion blocker.

After #396 PASS, dependency-closed execution is:

1. **Foundation authorities** — #397 Theme/skin plus path-disjoint #400 ContentId presentation metadata, #399 UI input/focus arbitration, #410 binding presentation, and #423 root scale policy as applicable. These may proceed in parallel only where file ownership is disjoint.
2. **#401 UI-COMP-001** — ItemSlot, ResourceBar, KeyPrompt and BoundedScreenShell consume those accepted foundation contracts; Toast/Modal are added only when a real consumer requires them.
3. **Semantic/read-model handoff** — #220 structured objective/HUD semantics and #404 world-domain/readiness semantics must be accepted before the corresponding production HUD/domain surfaces claim those truths.
4. **Feedback/prompt adapters** — #415 global committed-outcome notifications and #416 non-mutating contextual interaction query/execution feedback land before production HUD claims those lanes.
5. **Inventory interaction prerequisites** — #421 target resolution and #422 live equipment command composition land before #390 exposes interactive Equip/Unequip.
6. **Crafting interaction prerequisites** — #414 authoritative non-mutating craftability preflight and #417 production recipe/read-model composition land before #391 becomes the full data-driven Crafting surface.
7. **Screen/system implementation** — #388 HUD, #390 Inventory, #391 Crafting, #398 menus, #412 Settings/#393 system UI and #407 Building proceed only when their specific prerequisite seams above are accepted.

Parallelism remains encouraged across genuinely disjoint paths, but screen implementation must not outrun required semantic, input, binding, scale, metadata or command authorities.

### Shared-path serialization

Treat these as collision hotspots:

- `presentation/ui/theme/underworld_theme.tres` → one Theme owner at a time;
- `presentation/ui/hud/**` → serialize #220/#388 migration;
- `app/app_root.gd` / AppRoot scenes → serialize Settings/startup/quit/lifecycle work;
- Player/Game input paths → serialize #399/#408/#410/gameplay composition;
- central validation runners/workflows → one owner per hunk.

New component directories under `presentation/ui/components/**` can otherwise be cleanly split by component ownership.

---

# 25. Validation contract

Production UI acceptance should extend existing UI/HUD/App Shell validation rather than create redundant workflow families.

**#413 owns the shared UI validation/path-trigger envelope.** The UI workflow must trigger when screens consume or when a change modifies shared component paths, semantic Theme/style assets, or root UI scale/project settings such as `project.godot`. Trigger coverage must follow the real shared dependency graph rather than only individual screen paths.

Renderer/scene tests should preserve read-model and authority semantics without freezing prototype copy or obsolete prototype layout. In particular they must not make permanent `_feedback_text`, permanent material-list text, or exact provisional player-facing strings into production architecture.

At minimum prove:

### Structure / geometry

- ItemSlot remains 64×64 across all states;
- icon/key/quantity rects are invariant;
- 4-slot and fixture 9-slot Hotbars fit reference canvas;
- Inventory canonical 4×4 grid preserves exact slot holes/index navigation;
- notification stack does not collide with Hotbar/InteractionPrompt;
- modal action reflow remains readable;
- representative resolutions/UI scale preserve bounded shell geometry.

### Input / focus

- HUD/passive Toasts recursively mouse-ignore;
- one ItemSlot InputSurface owns GUI interaction;
- nested UI Back precedence is deterministic;
- UI capture suppresses event-driven and frame-polled gameplay input;
- closing UI does not leak `just_pressed` gameplay actions;
- Settings/Modal operate while GameFlow Pause is active;
- WM-close active-Game flow cannot bypass quit confirmation and Cancel restores prior focus stack;
- provisional Title focus never steals focus after real user interaction.

### Authority / non-mutation

- presentation rendering does not mutate Inventory/Equipment/Crafting/Persistence/WorldDomain/Building truth;
- Content presentation comes from #400 rather than ID suffix formatting;
- equipment vocabulary remains separate from ContentId metadata;
- machine-readable result codes, not diagnostic text parsing, drive player-facing failures;
- InteractionPrompt preview is read-only and execution revalidates;
- Toasts originate from committed semantic outcomes, not Inventory polling;
- restored Continue state does not replay historical acquisition toasts.

### Lifecycle

- Game-owned UI dies with Game route;
- AppRoot Settings/Modal/startup hosts do not leak stale origin state across route changes;
- in-Game world transition cannot be covered/overridden by lower Game UI;
- Pause/Settings/Modal remain above Game surfaces;
- startup loading and world-domain loading retain separate lifetime owners.

---

# 26. Explicit non-goals

This production design does **not** require:

- final UI art/icons;
- runtime TileMap UI composition;
- minimap;
- quest framework/log;
- MMO dashboard chrome;
- 9 semantic hotbar slots today;
- paper-doll armor system before real armor breadth;
- crafting queue/category/search for three recipes;
- generic Tooltip framework;
- fake Settings categories;
- fake progress percentages;
- hard-coded physical interaction/build keys;
- UI-owned save/inventory/crafting/build/world-domain logic;
- a repository-global Toast/Modal singleton;
- broad character creation/mastery/profession UI before their gameplay systems exist.

---

# 27. Design acceptance condition

This document is safe to become shared implementation authority only when independent #396 verifies it together with:

- `WORLD_DOMAIN_UI_AMENDMENT.md`;
- `BUILDING_UI_UX_SPEC.md`;
- accepted ADR-001/two-domain architecture;
- accepted #262 UI foundation;
- the explicit child-card ownership boundaries referenced above.

A PASS freezes the **UI architecture and UX behavior**, not final visual art.