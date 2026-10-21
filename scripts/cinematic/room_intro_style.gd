class_name RoomIntroStyle
extends Resource
## How a room introduction looks and moves. One resource per preset in
## resources/cinematic/presets/ (past_memory, future_signal, neutral, finale).
## Everything a preset can change lives here, so the overlay holds no per-timeline code paths
## beyond switching the effects below on or off.

@export var preset_id: StringName = &"neutral"

@export_group("Palette")
@export var text_color: Color = Color("f2f2ee")
@export var accent_color: Color = Color("b8b8b0")
@export var secondary_color: Color = Color("8a8a84")
## Colour of the edge vignette and the scrim behind the text.
@export var shade_color: Color = Color("111111")
@export var scrim_alpha: float = 0.5
@export var vignette_alpha: float = 0.45

@export_group("Typography")
## Superseded by Typography (assets/themes/typography): the card now uses Hubot Sans / Geist / Departure Mono.
## Kept so existing presets still load.
@export var title_fonts: PackedStringArray = PackedStringArray(["Georgia", "serif"])
@export var label_fonts: PackedStringArray = PackedStringArray(["Segoe UI", "sans-serif"])
## Sizes are for a 1600 x 900 layout and scale with the window; long titles shrink to fit.
@export var title_size: int = 74
@export var label_size: int = 17
@export var detail_size: int = 21
## Letter tracking in em. The title starts at tracking_start and settles at tracking_end.
@export var tracking_start: float = 0.12
@export var tracking_end: float = 0.04

@export_group("Timeline text")
@export var timeline_numeral: String = ""
@export var role_line: String = ""
@export var timeline_line: String = ""

@export_group("Effects")
@export var light_sweep: bool = false
@export var film_grain: bool = false
@export var scanline: bool = false
@export var glitch: bool = false
@export var interface_lines: bool = false
## Height of the temporary letterbox bars as a fraction of the screen height. 0 disables them.
@export_range(0.0, 0.15) var letterbox: float = 0.0

@export_group("Timing (seconds)")
@export var overlay_in: float = 0.25
@export var chapter_start: float = 0.25
@export var chapter_duration: float = 0.4
@export var title_start: float = 0.55
@export var title_duration: float = 0.55
@export var accent_start: float = 0.85
@export var accent_duration: float = 0.45
@export var detail_start: float = 1.0
@export var detail_duration: float = 0.4
@export var out_start: float = 2.2
@export var out_duration: float = 0.8

@export_group("Audio cues")
## Optional sound IDs in the existing AudioDirector catalog. Empty means silent.
@export var audio_start: StringName = &""
@export var audio_title: StringName = &""
@export var audio_end: StringName = &""


func total_duration() -> float:
	return out_start + out_duration
