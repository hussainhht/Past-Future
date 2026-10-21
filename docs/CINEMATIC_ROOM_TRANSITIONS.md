# Cinematic Room Transitions

Normal level entry goes straight to gameplay, without cinematic title cards or animated fades.
Room changes use a plain loading cover only while loading and synchronising peers.

The title-card system remains available for explicit previews, with `CinematicTransitionManager.enabled`
defaulting to `false`. The API and automatic behaviour below apply only after enabling it.
Its cards show the chapter label, room title, accent line, timeline identity and coordinates.
The Student sees the warm Past card, the Professor the cold Future card.
Verified against Godot 4.7.2, GL Compatibility.

## 1. Architecture

```text
GameFlowManager.room_changed / transition_completed        (existing signals, unchanged)
        |
        v
CinematicTransitionManager (autoload)   picks data + preset, decides *when*, dedupes, cleans up
        |  instantiates one per introduction
        v
CinematicTransition (CanvasLayer 40)    builds the look from a RoomIntroStyle, runs one Tween
```

* Presentation only. No RPC, no puzzle state, no input lock, no pause, no role change. Each peer decides
  from `PuzzleManager.get_local_role()`, so the same room shows "I / PAST" on one screen and
  "II / FUTURE" on the other, with no network traffic.
* The overlay ignores the mouse, sits above gameplay HUDs and below the Journal and the level-transition
  fade (both layer 100), and frees itself when it ends.
* Rooms and themes are data: `RoomIntroData` (words) and `RoomIntroStyle` (look and timing).

## 2. Files

```text
scripts/cinematic/cinematic_transition_manager.gd   autoload "CinematicTransitionManager"
scripts/cinematic/cinematic_transition.gd           class CinematicTransition (CanvasLayer): layout + animation
scripts/cinematic/room_intro_data.gd                class RoomIntroData (Resource)
scripts/cinematic/room_intro_style.gd               class RoomIntroStyle (Resource)
scripts/cinematic/timeline_marker.gd                "I / PAST --- 31 YEARS APART --- II / FUTURE" drawing
scenes/cinematic/cinematic_transition.tscn          the overlay's node tree
resources/cinematic/rooms/{signal_laboratory,maintenance_corridor,temporal_core}.tres
resources/cinematic/presets/{past_memory,future_signal,neutral,finale}.tres
tests/cinematic_system.gd, tests/run_cinematic_tests.py
project.godot                                       one added line: the autoload
```

## 3. Public API (`CinematicTransitionManager`)

```gdscript
show_room_intro(room_id: String, timeline: String = "", force: bool = false) -> bool
dismiss()                          # short fade-out of the running intro
is_playing() -> bool
reset_history()                    # let the current room entry introduce itself again

register_intro(data: RoomIntroData, replace := false) -> bool
register_style(style: RoomIntroStyle, replace := false) -> bool
has_intro(room_id) / get_intro(room_id) / get_style(preset_id)

var enabled: bool                  # master switch
var time_scale: float              # 2.0 = twice as fast
var reduced_motion_override        # null = follow the menu setting, true/false = force

signal intro_started(room_id, timeline)
signal intro_finished(room_id, completed)
signal audio_cue_requested(cue, timeline, room_id)
```

`timeline` is `"past"` or `"future"`; empty uses the local role.

### When it plays automatically

The manager listens to `GameFlowManager`:

| Event | Behaviour |
|---|---|
| `room_changed` outside a transition (`start_room`, `attach_room`: the menu's `change_scene`, F6 runs) | plays two frames later, once the room finished its own `_ready` |
| `room_changed` during a transition | waits for `transition_completed` (the screen is black until then) |
| `transition_failed` | cancels the pending intro, nothing plays for the rolled-back room |
| `transition_started` | dismisses a running intro |
| Journal or pause menu open | the intro waits (up to 8 s) so it is not hidden behind them |
| the room is freed (menu, disconnect) | the intro is dismissed |

One room entry plays once: the key is the room ID plus the room node instance, so closing the Journal,
refreshing HUDs or re-attaching the same room never replays it, while a real room change (a new node) does.
Only rooms that have a `RoomIntroData` are introduced.

## 4. Adding a room

Create `resources/cinematic/rooms/<name>.tres` (it is picked up automatically):

```text
[gd_resource type="Resource" script_class="RoomIntroData" format=3]

[ext_resource type="Script" path="res://scripts/cinematic/room_intro_data.gd" id="1"]

[resource]
script = ExtResource("1")
room_id = "room_04"                 ; the GameFlowManager room ID
chapter_label = "CHAPTER 1"
chapter_title = "THE SECOND SIGNAL"
room_title = "ARCHIVE VAULT"
location_index = 4                  ; "TEMPORAL COORDINATES / 04"
past_preset = &"past_memory"
future_preset = &"future_signal"
```

Long titles shrink to fit the screen. Or register at runtime: `CinematicTransitionManager.register_intro(data)`.

## 5. Themes and presets

A preset is a `RoomIntroStyle` in `resources/cinematic/presets/`: palette, fonts, sizes, tracking, the
timeline strings ("PAST — THE STUDENT", "01 / PAST — 31 YEARS BEFORE"), effect switches and all timings.

| Preset | Use | Effects |
|---|---|---|
| `past_memory` | Student | warm light sweep, paper grain, rising serif title, gold line |
| `future_signal` | Professor | cyan scan pass, typed chapter label, wipe reveal with three decaying offset fragments, interface lines |
| `neutral` | fallback / unknown preset | text only |
| `finale` | opt-in for the last room | slower, letterbox bars, no timeline strings |

Past palette `#F0E2C7 #E4BF7F #C69C55 #302820`; Future palette `#CEDFE2 #86C9D1 #80D9E4 #15242B`.
Change a colour or font by editing the `.tres`. To use the finale card for a room, set `past_preset` /
`future_preset` to `&"finale"` in its `RoomIntroData`; nothing else changes.

## 6. Timing

All in seconds in the preset (`overlay_in`, `chapter_start/duration`, `title_start/duration`,
`accent_start/duration`, `detail_start/duration`, `out_start/out_duration`). Defaults total about 3.0 s
(Past), 3.0 s (Future). `time_scale` speeds every intro up or down globally.

## 7. Audio hooks

Silent by default; no sound files are added. A preset may set `audio_start`, `audio_title`, `audio_end`
to sound IDs. When reached, the manager emits `audio_cue_requested(cue, timeline, room_id)` and, if an
`AudioDirector` in group `lab_audio` has that sound (`has_sound`), plays it with `play_ui`, so the
existing UI bus and volume settings apply. A competing audio system is never created.

## 8. Reduced motion

The manager follows the main menu's "ambient motion" toggle (`user://menu_settings.cfg`,
`display/ambient_motion`). When it is off, or `reduced_motion_override = true`, the card shows its final
layout with plain fades only: no slide, sweep, scan, glitch, letterbox, pulse or drift. Information is
identical. The glitch is also bounded in the normal mode: three low-alpha offsets, no brightness flashes.

## 9. Multiplayer

Local presentation only. It runs on each peer from that peer's own role after the room is in the tree and
(during transitions) after the fade-in. It never calls an RPC, so ENet, the host-authoritative flow, puzzle
state and roles are untouched. Gameplay and input stay live while the card plays.

## 10. Testing

```text
GODOT_BIN=/path/to/godot python tests/run_cinematic_tests.py [--out DIR]
```

Runs on a real renderer (xvfb-run if there is no display): data, real Room 01 entry, a real Room 01 →
Room 02 transition, no replay, Future role, dismiss, long title, `finale`, reduced motion, 1920×1080 /
1280×720 / 960×540, and a menu-style `change_scene` entry. Prints `CINEMATIC: PASS` and saves screenshots.

Known unrelated failures in `tests/run_game_flow_tests.py`: its checks `root.get_child_count() == 4`
predate the Journal autoload and already fail without this feature (5 vs 4); with this autoload the count
is 6. Everything else in that suite passes.

## 11. Room 03 integration

Nothing needs to change in the Room 03 scene. `room_03` already has data (`TEMPORAL CORE`, location 03). When
the Room 03 definition is registered in `GameFlowManager` and entered through a transition,
`start_room` or `attach_room("room_03", self)`, its card plays automatically. Optional manual call:

```gdscript
CinematicTransitionManager.show_room_intro("room_03")
```

Room 03 can set `past_preset` / `future_preset` to `&"finale"` in
`resources/cinematic/rooms/temporal_core.tres` when the ending agent wants the heavier card.
