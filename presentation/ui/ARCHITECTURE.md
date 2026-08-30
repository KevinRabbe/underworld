# Underworld UI Architecture

This directory defines the production UI architecture. The current skin artwork is intentionally provisional.

## Stable boundaries

- Screens use ordinary Godot `Control` nodes, anchors and Containers for layout.
- `underworld_theme.tres` is the semantic styling API. Screens select roles such as `MenuPanel`, `ContentPanel`, `TitleLabel`, and `SectionHeaderLabel`; they do not reference skin texture files directly.
- `theme/styles/*.tres` owns 9-slice `StyleBoxTexture` configuration.
- `assets/skin/prototype/*` is a disposable visual layer. These prototype SVGs may be replaced by PNG/WebP/authored textures later without changing screen hierarchy, routing, or gameplay code.
- `components/*` is reserved for genuinely repeated structure or presentation behavior. Do not wrap every Button, Label, or Panel in a custom scene.
- App routing remains owned by `app/app_root.gd`. UI components do not load gameplay scenes or own persistence/gameplay state.

TileMap is not part of normal menu composition.

## 9-slice contract

The prototype panel source is 96x96 with 24 px protected edges. The prototype button sources are 96x48 with **20 px protected left/right edges and 14 px protected top/bottom edges**. Patch margins live in the corresponding `StyleBoxTexture` resources, not in screens.

Those button values are the authored safe envelope for the current 2 px-stroked corner ornaments: the left ornament reaches x=19 after stroke expansion, the right begins at x=77, the top reaches y=13, and the bottom begins at y=35. The resulting stretchable center is x=20..76 and y=14..34, so no corner-ornament pixel is stretched when buttons grow.

All Button states use identical patch and content geometry. Hover, focus, pressed, disabled, and normal may use different art, but switching state must not move content. Keyboard/controller focus is independently authored from mouse hover.

When final art arrives, artists may change source dimensions. Update the patch margins in `theme/styles/*.tres` **and the authored safe-envelope regression** to match the new protected corners/edges. No screen scene should require structural changes.

## Asset rules

- Never bake dynamic text, quantities, save state, objectives, item names, or semantic identity into runtime panel/button textures.
- Backgrounds, logos, ornaments, icons, frames, fills, and separators may be authored assets.
- Full-screen layout mockups belong in `docs/design/ui/` and are references only.
- Runtime text remains `Label`/`RichTextLabel`; interaction remains native Godot Controls.

## Reusable composition rule

Theme roles are preferred for purely visual reuse. Create a reusable scene component only when multiple screens repeat actual structure or presentation behavior. `section_header/` is the first example: a heading plus extensible divider that can be reused by inventory, crafting, settings, and other content screens while inheriting the active Theme.

## Validation

`tests/presentation/test_ui_architecture_contract.gd` proves:

- panel and button skin roles resolve through `StyleBoxTexture` resources;
- patch margins leave a stretchable center;
- the current prototype button source dimensions and 20x14 protected envelope keep authored corner ornamentation outside the stretch region;
- button states keep identical geometry and focus is independently replaceable from hover;
- tall and wide compositions reuse the same panel skin contract;
- the accepted title screen consumes the reusable Theme without routing changes;
- a structured reusable component remains layout/theme based rather than baked art.
