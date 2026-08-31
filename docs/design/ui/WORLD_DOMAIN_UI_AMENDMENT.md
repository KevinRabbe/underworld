# Underworld UI / UX — World-Domain Amendment

Status: **FROZEN DESIGN AUTHORITY CANDIDATE — UI-UX-002 / #387**  
Accepted architecture authority: **ADR-001 / DOCS-ARCH-001, landed through #428 at `b1974fe8…`**  
World-domain runtime owner: **#404 WORLD-DOMAIN-001**  
Application startup-loading owner: **#427 APP-LOAD-001**  
Performance owners: **#364 PERF-003 / #369 SCALE-001**  
Reference logical viewport: **1280 × 720**

This amendment adapts the production UI/UX specification to the accepted architecture in which **OVERWORLD** and **UNDERWORLD** are independent procedural world domains connected by explicit semantic gateways.

It supersedes any earlier UI assumption that cave entry must be detected through shared Y, physical mesh continuity, cave AABB membership or camera depth.

The core presentation rule is:

> **The player experiences one coherent journey; presentation consumes explicit domain/transition truth and never reconstructs it from geometry.**

---

## 1. Accepted world-domain model

UI must assume:

- `OVERWORLD` and `UNDERWORLD` are explicit independent domains;
- each domain uses domain-local transforms/depth;
- matching XYZ is neither required nor authoritative;
- a semantic gateway links source-domain gateway identity to destination-domain entry-site identity;
- direct fade/loading is intentional valid V1 UX;
- only committed `active_domain` is normal gameplay domain truth;
- destination readiness precedes release of Player control;
- inactive full-domain runtime is not required to remain live;
- SAVE/Continue preserve active domain + domain-local position/state according to #404/Persistence authority.

UI does not reinterpret historical `EntranceDefinition`, `ug.entrance.*`, Underworld StableIds or old physical-seam language as cross-domain authority.

---

## 2. Presentation must not infer domain state

Forbidden presentation authority includes:

- Player Y sign;
- distance below surface terrain;
- cave mesh visibility;
- camera position;
- collision AABB membership;
- proximity to an old entrance Node;
- whether an Underworld cell happens to exist in memory;
- ambience/acoustic state;
- loading-screen text itself.

Player-facing state consumes explicit read-only domain/gateway/lifecycle data from #404/AppRoot composition.

This applies to:

- objectives;
- global ambience presentation;
- transition labels;
- HUD suppression;
- Continue reconstruction messaging;
- death/recovery narrative;
- readiness/loading completion.

---

# 3. Two distinct loading surfaces

There are **two** reusable-looking but separately-owned loading surfaces.

## 3.1 In-Game WorldTransitionOverlay — Game lifetime

Owner: #404/Game route.

Used for:

- Overworld → Underworld gateway transition;
- Underworld → paired/authorized Overworld return;
- cross-domain recovery where accepted recovery policy uses #404.

It exists inside an already-live Game route.

## 3.2 AppStartupLoading — AppRoot lifetime

Owner: #427/AppRoot.

Used for:

- Title → NEW Game startup;
- Title → CONTINUE startup;
- future major AppRoot route loading only where explicitly adopted.

It exists **before** a new Game can be considered safe/active.

## 3.3 Reuse rule

Both may share:

- shade treatment;
- status typography;
- indeterminate activity animation;
- timing grammar;
- reduced-motion behavior.

They do **not** share:

- lifecycle owner;
- readiness authority;
- transaction state;
- rollback semantics;
- one repository-global loading singleton.

AppRoot loading does not become WorldDomain authority. Game-local transition loading does not become AppRoot route authority.

---

# 4. CanvasLayer ordering

Reference ordering from the core spec:

- `80–89` — Game-owned WorldTransitionOverlay;
- `90–99` — AppRoot startup loading;
- `100` — Pause;
- `110` — Settings;
- `120` — app-level Modal.

A staging Game/HUD cannot visually cover AppRoot startup loading merely because it selected a high local CanvasLayer.

Ordinary user Pause cannot be opened during a startup operation simply because its layer is numerically higher. Layering is not permission/state authority.

---

# 5. Gateway interaction UX

## 5.1 Discovery / prompt

When gameplay exposes a valid gateway through #416/#404 contextual query, HUD may show one primary semantic action such as:

- `Enter Underworld`;
- `Return to Overworld`.

Binding presentation comes from #410.

UI does not show raw gateway ID, source-site ID, StableId or destination coordinates.

## 5.2 Activation

Gateway activation submits a semantic intent to #404.

UI never:

- chooses the destination domain independently;
- converts coordinates;
- creates destination runtime cells;
- decides readiness;
- commits `active_domain`.

## 5.3 Objective completion

The M3 world-entry objective completes only after:

1. the intended gateway transition succeeds; and
2. committed `active_domain == UNDERWORLD`.

Starting a fade, seeing Underworld geometry or crossing a geometric threshold is insufficient.

---

# 6. In-Game transition transaction

Presentation mirrors #404's atomic transaction; it does not invent a parallel one.

Conceptual lifecycle:

```text
OVERWORLD committed
-> gateway intent accepted
-> PREPARING destination
-> destination readiness satisfied
-> COMMITTING
-> UNDERWORLD committed
-> control released
```

Return is equivalent in the opposite semantic direction.

### During PREPARING / COMMITTING

- ordinary gameplay input is suppressed by accepted lifecycle/input authority;
- normal HUD/prompts/toasts may be visually suppressed;
- Pause/Save & Quit cannot nest into the transition operation;
- destination presentation may be staged but is not gameplay-authoritative;
- source truth needed for rollback remains owned by #404;
- UI never treats staged destination existence as commit.

### Commit

Only #404 changes active-domain truth.

Transition overlay disappears only after the owning lifecycle reports the destination is ready and the commit/control-release boundary is satisfied.

No timer-only dismissal.

---

# 7. Transition failure / rollback

Failure is fail-closed.

Presentation must not:

- reveal an unready destination as playable;
- remove the shade because an animation timer ended;
- infer rollback completion from source mesh visibility;
- leave mixed Overworld/Underworld HUD state.

Reference behavior:

1. transition remains visually controlled while #404 resolves failure;
2. source committed truth remains/restores according to authority;
3. Player control returns only when rollback/source state is safe;
4. bounded player-facing failure appears in the transition/modal owner when action is required;
5. raw diagnostics remain logs/test evidence.

A failed transition does not falsely complete #220 objective progression.

---

# 8. Honest loading presentation

## 8.1 No fake percentage

Do **not** show `0–100%` unless runtime exposes a meaningful monotonic progress contract.

Current safe first slice uses:

- shade/fade;
- semantic status;
- indeterminate activity.

Examples where accurate:

- `DESCENDING...`;
- `RETURNING TO SURFACE...`;
- `LOADING WORLD...`;
- `CONTINUING...`.

Copy is presentation, not lifecycle authority.

## 8.2 Fast/slow timing

To avoid one-frame spinner flashes while still presenting before expensive work:

- shade/fade may begin immediately after accepted operation intent;
- verbose status/spinner may appear after roughly **150–250 ms** if the operation is still active;
- never impose an artificial multi-second minimum;
- if readiness completes quickly, reveal promptly;
- animations must not delay control after authority says the destination/startup is safe.

Exact threshold may be tuned from human testing; the behavioral rule is stable.

## 8.3 Performance truth

A loading screen is not permission for uncontrolled synchronous work.

#364/#369 remain responsible for:

- total cold/warm latency;
- worst main-thread hitch;
- bounded relevance/work queues;
- avoiding history-proportional work.

If the main thread stalls after static loading presentation appeared, that remains a performance defect even though the player did not see an unpainted frame.

---

# 9. AppRoot Title → Game startup

The earlier Game-local transition overlay cannot honestly cover startup work that occurs before the Game's presentation surfaces exist. #427 therefore owns AppRoot startup loading.

## 9.1 NEW startup

Reference flow:

```text
Title NEW intent
-> AppRoot startup operation accepted
-> AppStartupLoading shown/armed
-> prepare new Game off the current route authority boundary
-> root world seed/config fixed before generation
-> required initial world/domain readiness
-> Game reports startup-ready
-> AppRoot activates/commits Game route
-> startup loading removed
```

The old Title remains the recoverable source surface until the startup transaction reaches the accepted route-commit boundary.

## 9.2 CONTINUE startup

Reference flow:

```text
Title CONTINUE intent
-> AppRoot startup operation accepted
-> AppStartupLoading shown/armed
-> durable slot load/decode
-> explicit saved active_domain resolved
-> required saved-domain runtime reconstructed
-> exact saved transform readiness satisfied
-> Game reports startup-ready
-> AppRoot activates/commits Game route
-> startup loading removed
```

Continue must not briefly present an unrelated Overworld session before reconstructing a saved Underworld state.

---

# 10. Presentation-before-work requirement

When startup may perform synchronous/expensive work, the loading surface must be installed/armed before that work begins so the app has an honest visual state rather than a frozen Title click.

Implementation may require a deferred frame/paint boundary before expensive startup.

This rule does not authorize fake progress or artificial delay.

---

# 11. Staged Game inactivity

Merely adding/preparing a Game Node is not startup commit.

Before AppRoot activates the new Game:

- Player input/physics is inactive;
- camera/mouse gameplay control is inactive;
- Game HUD is not allowed to become the player's interactive surface;
- gameplay producers do not run as an authoritative session;
- #399/accepted input-gate architecture is reused rather than inventing a second Player-specific loading boolean where possible.

Startup readiness is a lifecycle state, not a visual opacity trick.

---

# 12. Startup failure

If NEW/CONTINUE preparation fails before route commit:

- previous Title remains/restores as active route;
- startup loading closes only after failure resolution is safe;
- bounded player-facing error is shown through Title/app modal/status owner;
- Continue state may refresh if persistence classification changed;
- no half-live Game remains behind Title;
- no Player/camera input leaks from a failed staged Game.

Presentation does not delete/repair slots itself.

---

# 13. Direct Underworld Continue

Saved `active_domain == UNDERWORLD` means startup reconstructs Underworld directly.

#404/#372 determine the required bounded readiness around the exact durable Player support envelope.

UI requirements:

- use startup/loading language, not gateway-traversal fiction;
- do not play an `Entered Underworld` objective completion as though a gateway was just used;
- do not construct Overworld solely to make the loading presentation feel continuous;
- restore ordinary shared HUD after Game startup commits.

The same principle applies to saved Overworld Continue.

---

# 14. Save state and transition exclusion

While #404 owns PREPARING/COMMITTING:

- ordinary Pause/Save & Quit is unavailable;
- UI must not offer an operation that persistence authority rejects as ambiguous transition state;
- no save UI can infer a safe boundary from fade progress.

Once a domain commit/rollback settles, ordinary GameFlow policy resumes.

AppRoot startup similarly owns its route transaction until Game activation or rollback-to-Title finishes.

---

# 15. HUD behavior across domains

Default production rule: **one shared Gameplay HUD** in both domains.

Do not create a separate Underworld HUD theme/layout merely because the environment changes.

The following remain in stable positions:

- vitals;
- objective;
- reticle;
- InteractionPrompt;
- Hotbar;
- notifications.

Content/action state changes semantically through normal read models.

A future environment-specific ornament treatment may be Theme/presentation-only if it does not change hierarchy or authority.

---

# 16. Global ambience presentation

Global world ambience follows committed `active_domain`, not Y/AABB/mesh presence.

Local cave acoustics may refine sound **inside the active Underworld** according to their own accepted presentation authority.

During transition PREPARING, ambience staging/crossfade may occur, but ordinary player-facing domain truth remains the committed domain until #404 commit.

UI should not use audio state to decide which domain is active.

---

# 17. Notifications during transition/startup

### In-Game world transition

Normal low-priority gameplay Toasts may be suppressed while WorldTransitionOverlay owns presentation. Do not replay a stale acquisition backlog after the transition.

Critical lifecycle failure belongs to transition/modal presentation, not hidden Toasts.

### App startup

Game-owned notification queues do not exist as a cross-route history source. Continue must not replay pickups/crafts merely because restored canonical state contains them.

---

# 18. Interaction prompts near gateways

Before activation:

- one valid semantic gateway action may be displayed.

After transition intent is accepted:

- ordinary InteractionPrompt is suppressed;
- repeated activation cannot create duplicate transition attempts;
- status comes from the transition overlay.

On rollback:

- contextual query refreshes from current authoritative source state;
- gateway prompt returns only if the action is again valid.

---

# 19. Death / recovery across domains

The UI presents one coherent recovery narrative regardless of whether recovery remains in-domain or returns to Overworld.

Example:

```text
YOU FELL
Recovering...
```

If Underworld defeat requires Overworld recovery:

- #381 determines a safe recovery target;
- #404 performs the cross-domain transition/commit ordering;
- Player respawn commit remains gameplay authority;
- UI does not expose an internal teleport coordinate or treat shared XYZ as conversion.

Overlay clears only after accepted recovery commit/control state.

---

# 20. Building across domains

The same Build Catalog and Placement HUD serve both domains.

UI does not expose a manual `Overworld / Underworld` build selector.

Building validation/content authority may report domain-specific availability/restrictions, but presentation consumes those semantic results.

A gateway is not an ordinary constructible build piece unless a future gameplay system explicitly defines one.

---

# 21. Objective reconstruction

#220 objective progression remains derived, not persisted UI state.

Relevant world-domain rules:

- locating a gateway may be based on accepted semantic discovery/availability;
- entering Underworld completes only after transition success + committed active domain;
- Continue reconstructs the correct current objective from durable gameplay state and saved active domain;
- loading/fade text is never parsed as progression truth;
- direct Underworld Continue must not fabricate a fresh gateway-entry milestone.

---

# 22. Accessibility / reduced-motion compatibility

Transition/startup visual grammar must support future reduced-motion preference without changing lifecycle semantics.

Safe fallback can be:

- immediate shade/cut instead of animated fade;
- static activity glyph/text instead of moving spinner;
- identical semantic status and readiness rules.

No flashing effect is required.

Status remains readable independently of environment brightness because the loading/transition surface supplies its own contrast.

---

# 23. Validation contract

At minimum prove:

## World-domain truth

1. HUD/objective/domain presentation uses explicit active-domain/gateway state, never Y/AABB/render heuristics;
2. gateway objective completes only after successful commit to UNDERWORLD;
3. failed transition does not advance objective/domain presentation;
4. direct Underworld Continue does not masquerade as gateway traversal.

## Transition lifecycle

5. ordinary world input is suppressed during PREPARING/COMMITTING;
6. Pause/Save & Quit cannot nest during in-flight domain transition;
7. overlay does not disappear before authoritative readiness/commit;
8. failure rollback leaves exactly one coherent committed source/destination presentation state;
9. duplicate gateway activation cannot create duplicate transition overlays/commits.

## Startup lifecycle

10. AppRoot startup surface becomes present/armed before expensive NEW/CONTINUE work;
11. staged Game cannot run Player physics/input/camera as authoritative gameplay before activation;
12. failed startup restores Title without stale staged Game input/UI;
13. saved active-domain reconstruction chooses required domain directly;
14. AppRoot loading and Game-local WorldTransitionOverlay remain separate lifetime owners.

## Timing / performance presentation

15. quick operations do not require an artificial minimum loading duration;
16. slow operations show bounded indeterminate status without fake percentage;
17. static loading presentation does not convert unbounded/hitching work into accepted performance;
18. ready state is revealed promptly after authoritative readiness.

## Ordering / focus

19. Game-local transition layer is below AppRoot startup/Pause/Settings/Modal according to shared band policy;
20. lower gameplay UI cannot become interactive through the transition/loading shade;
21. route/domain rollback restores deterministic focus/mouse/input ownership.

---

# 24. Explicit non-goals

This amendment does **not** authorize:

- physically continuous Overworld/Underworld mesh requirements;
- coordinate conversion between domains;
- domain inference from depth/Y;
- seamless/no-loading presentation as an M3 requirement;
- fake percent progress;
- permanent simultaneous full-domain residency;
- AppRoot becoming world generation authority;
- WorldTransitionOverlay becoming a global route loader;
- one global loading singleton owning all transitions;
- UI-owned SAVE/Continue migration;
- performance debt hidden behind long forced loading animations.

---

# 25. Design acceptance condition

Independent #396 should verify this amendment together with:

- `PRODUCTION_UI_UX_SPEC.md`;
- `BUILDING_UI_UX_SPEC.md`;
- accepted ADR-001 and current architecture docs;
- #404/#427 ownership boundaries;
- #399 input/focus rules;
- #364/#369 performance/scale constraints.

PASS freezes the presentation contract around explicit world domains and loading lifetimes while leaving final visual art replaceable.