# Typography system

The game is called **THE OTHER ME**. Internal project names retain Past-Future.

## Font assignments

| Text | Font |
|---|---|
| Main-menu game name | Broken by Picatype Design Studio |
| Buttons, settings, HUD, headings, subtitles and dialogue | Oxanium, with role-specific weights |
| Past electronic screen words, keypad and dial displays | DSEG14 Classic |
| Past waveform numeric readings | DSEG7 Classic |
| Future screens, logs and waveform readings (including digits) | Monaspace Krypton Regular |
| Student notebook and paper documents | Existing handwriting role (optional To The Point, system fallback) |
| Professor DataPad | Monaspace Krypton heading and body |
| Printed world labels and floating captions | Oxanium |

Broken is reserved for the main-menu game name. Its author requires a usage payment; see
`assets/fonts/licenses/Broken-NOTICE.txt`. Source details and licenses are in `assets/fonts/README.md`.

## Implementation

- `assets/themes/game_ui_theme.tres` supplies the project-wide default.
- `resources/ui/menu_theme.tres` supplies matching Oxanium button fonts for menus and pause/modal controls.
- `assets/themes/typography/*_font.tres` wrap local font files and retain glyph fallbacks.
- `scripts/ui/typography.gd` exposes named roles and font-size fitting.
- `Typography.display_font(future, numeric)` selects the era's electronic display face. Future always uses normal computer text; Past uses DSEG14 letters or DSEG7 numeric digits.
- Console waveforms, in-world console/keypad status, mounted keypads/dials, maintenance status and core electronic readings use that helper. Role changes update shared displays.

```gdscript
Typography.apply(label, &"dialogue_body", 24)
Typography.style_rich(rich_text_label, &"dialogue_body")
label_3d.font = Typography.display_font(future)
var digits := Typography.display_font(future, true)
```

Oxanium uses the bundled variable font with weights 400 (body), 500 (labels/dialogue), 600 (buttons/speakers),
and 700 (headings/bold). It has no separate italic face; italic dialogue variants keep the Oxanium family.
DSEG7 is only used for numeric pieces; words and units use DSEG14 with readable fallback glyphs.
The main-menu title retains width fitting, and waveform rows fit their combined word/digit widths.
All fonts load from local assets; no network requests occur at runtime.
