# Typography system

The game is called **THE OTHER ME** (internal paths, classes and the repository keep the old name).

Contrast to preserve: the Student's world (Past, 2026) is handwritten and warm; the Professor's world
(Future, 2057) is electronic and scientific; dialogue is cinematic and readable; menus are clean and consistent.

## Where things live

| What | Path |
|---|---|
| Font files + licenses + sources | `assets/fonts/` (see `assets/fonts/README.md`) |
| Game-wide Theme (project default, `gui/theme/custom`) | `assets/themes/game_ui_theme.tres` |
| One `FontVariation` per role | `assets/themes/typography/*_font.tres` |
| Role table, loader, helpers | `scripts/ui/typography.gd` (`class_name Typography`) |

## Fonts and weights

| Family | File(s) | Weight used | Used for |
|---|---|---|---|
| Hubot Sans | `interface/HubotSans-*.ttf` | Black (title fallback), Bold (headings, room/chapter names), SemiBold (speaker names), Medium (section headings) | names, headings, titles |
| Geist Sans | `interface/GeistSans-*.ttf` | SemiBold (buttons, tabs), Medium (labels), Regular (values, notes, tooltips) | menus, settings, HUD, general UI |
| Mona Sans | `dialogue/MonaSans-*.ttf` | Medium (body), Bold, Medium Italic, Bold Italic | all character dialogue (both characters) |
| To The Point | `handwriting/ToThePoint.ttf` (**not installed yet**) | Regular | Student's notebook, paper documents |
| Departure Mono | `future/DepartureMono-Regular.otf` | Regular | Future journal headings, terminal logs, electronic readouts, in-world keypad/console screens |
| Monaspace Krypton | `future/MonaspaceKrypton-*.otf` | Regular (body), Bold | Future journal paragraphs, terminal sentences; also the last-resort glyph fallback |
| DSEG7 Classic | `future/DSEG7Classic-*.ttf` | Regular | numeric readouts only (waveform frequency/amplitude digits) |
| Broken | `menu/Broken.otf` (**not installed yet**) | Regular | **only** the main-menu title and the four main-menu buttons |

DSEG is never used for paragraphs, menus or dialogue. Broken is never used in Settings, dialogue, journals,
HUD or gameplay.

## Roles (`Typography.ROLES`)

Sizes are starting values for a 1600 x 900 layout.

| Role | Font | Size | Role | Font | Size |
|---|---|---|---|---|---|
| `game_title` | Broken (fallback Hubot Black) | 76, shrinks to fit 640 px | `dialogue_speaker` | Hubot SemiBold | 22 |
| `menu_button` | Broken (fallback Geist SemiBold) | 27 (28 Play, 25 others, shrinks to fit) | `dialogue_body` | Mona Medium | 26 |
| `settings_heading` | Hubot Bold | 36 | `past_journal` / `past_note` | To The Point (fallback: system handwriting) | 26 |
| `settings_label` | Geist Medium | 22 | `future_journal_header` | Departure Mono | 22 (33 for titles) |
| `settings_value` | Geist Regular | 21 | `future_journal_body` | Krypton Regular | 22 |
| `settings_note` | Geist Regular | 18 | `terminal_log` | Departure Mono | 20 |
| `button` | Geist SemiBold | 20 | `digital_display` | DSEG7 Classic | 30 |
| `tooltip` | Geist Regular | 19 | `chapter_name` | Hubot Bold | 30 |

## How to use it

```gdscript
Typography.apply(label, &"settings_heading")            # Label/Button/LineEdit/...: font + size
Typography.apply(label, &"dialogue_body", 24)           # override only the size
Typography.style_rich(rich_text_label, &"future_journal_body")   # sets normal/bold/italic/mono fonts
var f: Font = Typography.font(&"terminal_log")          # raw Font (draw_string, Label3D.font, ...)
var px := Typography.fit_size(f, text, 33, max_width)   # largest size that fits
```

In scenes, reference a font resource directly (`theme_override_fonts/font = ExtResource(".../heading_font.tres")`)
or use the theme type variations in `game_ui_theme.tres`: `HeadingLabel`, `SectionLabel`, `SpeakerLabel`,
`SettingsLabel`, `SettingsValueLabel` (set `theme_type_variation`). Anything not styled falls back to
Geist Medium from the project theme, so new controls are already consistent.

Adding a font: put the file under `assets/fonts/`, its license under `assets/fonts/licenses/`, wrap it in a
`assets/themes/typography/<id>_font.tres` (`FontVariation`, with `fallbacks` = Geist then Krypton), and add a row
to `Typography.ROLES` if it is a new role.

## Where each font is applied today

| Scene / script | Applied |
|---|---|
| `scenes/menu/main_menu.tscn`, `scripts/menu/main_menu.gd` | Title and 4 main buttons: Broken (fallback Hubot Black / Geist SemiBold), fitted to width. Page headings: Hubot Bold. Other buttons, labels, tooltips: Geist. Title text is "THE OTHER" / "ME". |
| `scripts/ui/settings_content.gd`, `settings_overlay.gd` | Settings heading Hubot Bold; labels Geist Medium; values/notes Geist Regular; tabs Geist SemiBold |
| `scenes/world/spawn_area.tscn` (HUD, pause menu) | Room name + pause title Hubot Bold; everything else Geist (via project theme) |
| `scenes/dialogue/dialogue_box.tscn` | Speaker: Hubot SemiBold, accent colors unchanged (`#E4BF7F` Past, `#86C9D1` Future); body: Mona Medium with bold/italic variants. Typewriter code untouched |
| `scripts/gameplay/radio/radio_dialogue_*.gd` | Radio box inherits the dialogue box fonts; channel label Departure Mono |
| `scripts/journal/journal_ui.gd` | Student's notebook: To The Point throughout (fallback system handwriting); Professor's DataPad: Departure Mono headings, Krypton body |
| `scripts/ui/lab_ui.gd` | Documents: Past = To The Point, Future = Departure title + Krypton body; banner title Hubot Bold; objective/toast Geist; character thoughts Mona Sans |
| `scripts/cinematic/cinematic_transition.gd` | Room-name cards: Hubot Bold titles; labels Geist Medium (Departure Mono for the Future preset) |
| `scripts/gameplay/frequency/*` | Terminal headings/readouts Departure Mono, sentences Krypton, waveform digits DSEG |
| `scripts/gameplay/radio/radio_hud.gd` | Departure Mono |
| `scenes/environment/interactive/door_keypad.tscn`, `console_terminal.tscn` | In-world `Label3D` screens: Departure Mono |
| `scripts/game_flow/transition_overlay.gd`, `scripts/level3/core_launcher.gd` | Titles Hubot Bold |
| Everything else (Character Studio, interaction prompt, level 3 UI, maintenance corridor HUD, LAN lobby) | Geist from the project theme |

The 71 other `Label3D` nodes in the world (room signage, level 3 stations) still use Godot's default 3D font;
they were not restyled.

## Prepared but not yet applied

- **To The Point** and **Broken** files are not installed (see `assets/fonts/README.md`); roles `past_journal`,
  `past_note`, `menu_title`, `menu_button` work through fallbacks until then.
- `Typography` has full roles for dialogue, Past paper notes, the Future journal and numeric displays; any new
  puzzle screen should use `Typography.apply(...)` rather than choosing fonts by hand.

## Accessibility and rendering notes

- Minimum sizes: interactive text is 17 px or larger at 1600 x 900 (the canvas scales with the window).
- The To The Point handwriting has a limited glyph set; characters it lacks come from Mona Sans.
- Do not draw "MHz" or sentences in DSEG.
- Arabic is not covered by any of these fonts; none is currently used in the project.
