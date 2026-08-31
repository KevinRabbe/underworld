# Underworld UI / UX — World-Domain Amendment

Status: **UI-UX-002 AMENDMENT — supersedes continuous-cave transition assumptions**  
Parent design authority candidate: `docs/design/ui/PRODUCTION_UI_UX_SPEC.md`  
World architecture dependency: PR #403 / WORLD-DOMAIN-001 #404

This amendment updates the production UI/UX contract for the project's explicit independent `OVERWORLD` and `UNDERWORLD` runtime domains.

It does not replace the general UI architecture, HUD geometry, ItemSlot system, Inventory, Crafting, menu, focus, input-capture or skin contracts defined by UI-UX-002. It only supersedes statements that assumed entering the Underworld meant physically crossing into cave geometry inside one continuous coordinate volume.

The governing rule is:

> **UI presents an explicit world-domain transition. It does not infer world identity from geometry, coordinates, rendered cave cells or depth.**

---

## 1. Authoritative world identity

Player-facing presentation consumes an accepted read-only world-domain value owned by the world/gateway runtime.

Initial semantic values:

- `OVERWORLD`
- `UNDERWORLD`

UI does not derive active domain from:

- Player Y coordinate;
- cave-cell AABB membership;
- render visibility;
- camera position;
- ambience state;
- entrance proximity;
- mesh/collision node names;
- DebugHUD state.

The exact runtime API is owned by #404. Presentation consumes a value/snapshot only.

## 2. Gateway interaction replaces continuous cave-entry semantics

The old conceptual UX chain:

`find cave -> physically descend through shared geometry -> detect cave occupancy`

is superseded for cross-domain Underworld entrances by:

`find accepted Overworld gateway -> interact/enter -> transition begins -> destination becomes ready -> active domain commits to UNDERWORLD -> resume player control`.

A local cave, cellar, mine or overhang that remains in `OVERWORLD` is not an Underworld transition merely because it looks underground.

Therefore UI copy must describe the authored semantic action rather than infer a world transfer from cave-shaped geometry.

Examples:

- `Enter` / `Descend` / context-authored gateway verb;
- `Return to Surface` for a paired Underworld exit where appropriate;
- never generic `You are underground` as world-domain authority.

## 3. M3 objective integration

The production objective seam owned by #220 must update its gateway step to consume #404's accepted read-only state.

Required completion semantics:

1. locate the accepted Overworld gateway/entrance target;
2. request/perform the accepted gateway interaction;
3. transition succeeds;
4. authoritative active domain is `UNDERWORLD`.

Entrance proximity, fade start, loading-screen visibility or destination-cell creation by themselves are insufficient to complete the objective.

On return, authoritative domain `OVERWORLD` is the presentation truth for surface state.

No objective flag is persisted merely to remember that a fade occurred.

## 4. WorldTransitionOverlay becomes a first-class V1 screen

A direct fade/loading boundary is accepted architecture rather than a temporary workaround.

The reusable `WorldTransitionOverlay` should therefore be designed as an intentional production surface.

### Reference states

At minimum:

- `preparing` — accepted gateway request is being validated/prepared;
- `leaving_source` — source-domain handoff is committed/in progress;
- `loading_destination` — destination runtime is preparing required readiness;
- `ready_to_reveal` — destination is ready and presentation may fade in;
- `failed` — transition did not commit successfully and owning lifecycle provides failure result.

These names are conceptual presentation stages. UI must consume the exact lifecycle contract exposed by #404 rather than creating a second state machine.

### Reference copy

Preferred copy is semantic and destination-aware:

- Overworld -> Underworld: `DESCENDING...` or `ENTERING THE UNDERWORLD...`;
- Underworld -> Overworld: `RETURNING TO THE SURFACE...`;
- generic fallback: `TRAVELLING...` / `LOADING...`.

Do not display internal domain enum names if player-facing vocabulary later differs.

### Visual layout — 1280x720

First slice may be deliberately restrained:

- full-screen fade/shade;
- centered compact transition status block;
- optional understated indeterminate activity animation;
- optional single short gameplay/world hint if measured duration warrants it;
- no unrelated HUD, inventory counters or debug information during handoff.

Destination art/background is optional. The transition must remain valid with a flat shade and text.

## 5. Honest progress

The previous UI-UX-002 rule remains and is strengthened:

**Never show a numeric 0–100% progress bar unless #404/runtime exposes a meaningful monotonic progress value.**

World-domain separation makes stage-based progress more plausible, but stage count is not automatically percentage progress.

Allowed first slice:

- indeterminate animation;
- semantic stage text;
- bounded stage indicators only if every stage is authoritative and cannot regress/misrepresent readiness.

Do not estimate progress from elapsed time or average cave-generation duration.

## 6. Readiness and input ownership

The transition overlay does not decide when gameplay resumes.

Player control remains suppressed until the authoritative world/gateway lifecycle confirms the destination domain is safe/ready for Player physics.

This composes with UI-INPUT-001/#399:

- transition captures/blocks ordinary gameplay interaction;
- UI focus is not required for a non-interactive loading surface;
- `ui_cancel` does not cancel a transition unless #404 explicitly exposes a cancellable transition policy;
- presentation timers/animations cannot release gameplay input by themselves.

If failure returns the player to the source domain, source-domain readiness and input restoration are also lifecycle-owned.

## 7. HUD domain behavior

Ordinary GameplayHUD layout remains the same in both domains unless a later product decision adds domain-specific information.

The HUD should not maintain separate OverworldHUD and UnderworldHUD implementations merely because runtime domains differ.

Shared elements remain:

- health/stamina;
- reticle;
- interaction prompt;
- objective display;
- transient feedback;
- hotbar.

Domain-specific objective/action copy may differ through supplied semantic snapshots.

Do not permanently display `OVERWORLD` / `UNDERWORLD` as HUD chrome without a demonstrated player need.

## 8. Audio/UI separation

Audio may consume the same authoritative world-domain identity for ambience selection, but UI does not infer active domain from currently playing ambience.

Likewise Audio does not infer domain from loading-overlay visibility.

Both consume the world/gateway authority independently.

## 9. Save / Continue presentation

Persistence now restores an explicit active world domain with a domain-local player transform.

Title Continue remains a simple availability action; the Title screen does not need to expose coordinates/domain internals.

If future save-slot presentation shows location, it must use a player-facing resolved location/domain label supplied from persistence/presentation metadata rather than formatting internal runtime identifiers.

Continue behavior relevant to UI:

- loading an Overworld save may show the transition/loading surface while Overworld runtime is prepared;
- loading an Underworld save may directly prepare Underworld without constructing Overworld first;
- the overlay copy should describe loading/resuming rather than falsely claiming the Player is currently travelling through a gateway when Continue is direct reconstruction.

Suggested generic Continue copy while preparing:

`LOADING WORLD...`

Destination-specific flavour may appear only when the loaded active domain is authoritatively known.

## 10. Failure UX

World-transition failure must remain fail-closed.

Presentation responsibilities:

- keep the transition surface active while lifecycle outcome is unresolved;
- on recoverable failure, show concise player-facing failure copy and return to the lifecycle-provided safe UI/world state;
- on fatal failure, use the shared ModalDialog/error surface;
- never place the player into a partially ready destination merely to remove the loading screen.

Raw gateway IDs, StableIds, fingerprints, seed values and internal cell addresses are not normal player copy.

## 11. Gateway interaction prompt

`InteractionPrompt` / `KeyPrompt` consumes an already-resolved gateway interaction snapshot.

Examples:

`[E] Enter`

`[E] Descend`

`[E] Return to Surface`

The prompt does not decide whether the gateway is valid/ready and does not compute destination domain.

If the gateway is temporarily unavailable and gameplay exposes an authored reason, presentation may show bounded feedback such as `Passage unavailable` rather than silently accepting input.

## 12. No coordinate-continuity UI

The following UI concepts are explicitly forbidden as architecture assumptions:

- depth meters whose meaning is `distance below the Overworld` for world-domain identity;
- transition progress derived from Player Y;
- minimap stitching between Overworld and Underworld coordinate spaces;
- arrows that assume an Underworld destination is directly beneath its Overworld gateway;
- save/location labels derived by converting positions between domains.

Future maps may represent each domain separately and represent gateways as logical links.

## 13. Building/UI interaction

Building is domain-local unless gameplay later introduces explicit cross-domain construction semantics.

The UI should therefore treat the currently active domain as context supplied by gameplay/world authority, not as an extra build-piece property the player manually selects.

Cross-domain gateway objects are not ordinary building pieces unless a future gameplay system explicitly says otherwise.

## 14. Validation additions

Any implementation of the transition/domain UI must prove:

1. Overworld -> Underworld overlay begins from an accepted gateway transition request, not entrance proximity alone;
2. overlay cannot declare success before authoritative destination readiness/domain commit;
3. active `UNDERWORLD` domain drives the #220 gateway-objective completion seam;
4. returning commits `OVERWORLD` and does not depend on coordinate conversion;
5. local Overworld cave-shaped geometry does not falsely set Underworld presentation state;
6. HUD remains the same reusable system in both domains;
7. direct Underworld Continue uses loading/reconstruction presentation without pretending a gateway traversal occurred;
8. no fake numeric progress is shown without real monotonic runtime progress;
9. transition failure cannot release gameplay into a partially prepared destination;
10. presentation contains no world-coordinate conversion or geometry-derived domain detector.

## 15. Review/acceptance dependency

UI-UX-002 must not be accepted as final design authority against the obsolete continuous-world assumption.

Independent review #396 should review:

- the original production UI/UX specification;
- this amendment;
- accepted/final world-domain architecture from #403/#404.

If #403 changes materially before acceptance, this amendment must be rechecked and updated before UI-UX-002 can become implementation authority.
