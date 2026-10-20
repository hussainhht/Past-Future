# Past-Future Audio Subsystem Architecture & Integration Guide

Production-ready, modular audio implementation for **Past-Future** (Reboot CHECKPOINT Game Jam 2026, Godot 4.7.2).

---

## 1. Subsystem Overview

The audio subsystem provides responsive, physically grounded character audio, a centralized sound effects catalog, 3D spatialized environmental playback, and seamless ambient soundscapes for the Past (active laboratory) and Future (abandoned laboratory) timelines.

Key principles:
- **Zero modification of protected files**: The subsystem exists entirely in independent files and attachable components.
- **Physical movement grounding**: Footstep cadence responds dynamically to resolved character velocity, grounded state, and stride distance rather than raw inputs or fixed timers.
- **Bounded resource consumption**: Non-positional SFX and 3D world emitters use bounded object pools, preventing node explosion during rapid interactions.
- **Dynamic safe bus routing**: Audio categories (`Master`, `Music`, `SFX`, `UI`, `Ambience`) are routed dynamically without modifying global `project.godot`.

---

## 2. Architecture & Ownership

```text
res://
├── scripts/audio/
│   ├── footstep_emitter_3d.gd        # Attachable 3D footstep emitter component
│   ├── audio_director.gd             # Central audio coordinator, catalog & pools
│   └── ambient_audio_controller.gd   # Crossfading timeline ambient loop controller
├── scenes/audio/
│   ├── footstep_emitter_3d.tscn      # Reusable 3D footstep component scene
│   └── audio_system.tscn             # Composite scene (AudioDirector + AmbientController)
├── scenes/testing/
│   └── audio_sandbox.tscn            # Independent standalone testing sandbox
├── scripts/testing/
│   └── audio_sandbox.gd              # Controller for sandbox preview UI
├── assets/audio/
│   ├── footsteps/                    # Hard-floor footsteps (5 variations)
│   ├── ui/                           # UI clicks, hovers, confirmations, back cues
│   ├── interaction/                  # Interaction feedback (click, success, denied)
│   ├── environment/                  # 3D doors, locks, switches, terminal beeps
│   └── ambience/                     # Seamless Past and Future laboratory loops
├── docs/
│   ├── AUDIO_SYSTEM.md               # This documentation
│   └── AUDIO_ASSET_CREDITS.md        # Provenance, synthesis algorithms & licensing
└── tests/
    └── audio_system.gd               # Headless automated verification suite (80 checks)
```

---

## 3. Sound Catalog IDs

All sound IDs are identified by `StringName` keys in `AudioDirector`:

| Category | Sound ID | Type | Default Bus | Description |
|---|---|---|---|---|
| **UI** | `&"ui_click"` | 2D | UI | Restrained tactile click |
| **UI** | `&"ui_hover"` | 2D | UI | Micro high-frequency hover blip |
| **UI** | `&"ui_confirm"` | 2D | UI | Positive ascending two-tone confirmation |
| **UI** | `&"ui_back"` | 2D | UI | Soft descending cancellation cue |
| **Interaction** | `&"interaction_click"` | 2D | SFX | Tactile equipment switch engagement |
| **Interaction** | `&"interaction_success"`| 2D | SFX | Harmonic sci-fi success triad (C-E-G) |
| **Interaction** | `&"interaction_denied"` | 2D | SFX | Restrained double low pulse rejection |
| **Environment** | `&"door_open"` | 3D | SFX | Pneumatic sliding door with release transient |
| **Environment** | `&"door_locked"` | 3D | SFX | Heavy solenoid latch rejection |
| **Environment** | `&"computer_beep"` | 3D | SFX | Lab terminal telemetry chirp |
| **Environment** | `&"switch_toggle"` | 3D | SFX | High-precision relay toggle |
| **Environment** | `&"rift_hum"` | 2D/3D | Ambience | Low 55 Hz drone with 1.0 Hz beating LFO |
| **Ambience** | `&"lab_ambience_past"` | 2D Loop | Ambience | Operational lab (60 Hz hum, filtered air, servers) |
| **Ambience** | `&"lab_ambience_future"` | 2D Loop | Ambience | Abandoned lab (cold air, 42 Hz drone, tube resonance) |

---

## 4. Usage Guidelines

### 4.1 AudioDirector Usage

In any level or gameplay controller, obtain a reference to the `AudioDirector` instance (e.g. from `AudioSystem` placed in the scene tree):

```gdscript
@onready var audio_director: AudioDirector = $AudioSystem

# Playing UI sounds
func _on_button_pressed() -> void:
    audio_director.play_ui(&"ui_click")

# Playing confirmed interaction feedback
func _on_interaction_success() -> void:
    audio_director.play_sfx(&"interaction_success")

# Playing spatialized 3D world sounds (doors, terminals, levers)
func _on_terminal_activated(terminal_node: Node3D) -> void:
    audio_director.play_world_sfx(&"computer_beep", terminal_node.global_position)

func _on_door_opened(door_node: Node3D) -> void:
    audio_director.play_world_sfx(&"door_open", door_node.global_position)
```

### 4.2 Attaching FootstepEmitter3D to Characters

`FootstepEmitter3D` can be attached directly as a child of any `CharacterBody3D` (such as `Student3DPlayer`), or instantiated in code:

#### In Scene Editor:
1. Open the character or level scene.
2. Add an instance of `res://scenes/audio/footstep_emitter_3d.tscn` as a child of the `CharacterBody3D`.
3. If placed as a child, it automatically assigns `character = get_parent() as CharacterBody3D`.

#### In Script / Dynamic Instantiation:
```gdscript
var emitter := preload("res://scenes/audio/footstep_emitter_3d.tscn").instantiate()
player.add_child(emitter)
# Emitter automatically binds to 'player' and tracks real velocity and floor state.
```

### 4.3 Cadence and Variation Mechanics

- **Speed Accumulator**: Grounded horizontal velocity ($v_{xz}$) is accumulated over time ($\Delta d = v_{xz} \cdot \Delta t$).
- **Walking Cadence**: When walking ($v \approx 2.8\text{ m/s}$), stride distance is $1.35\text{ m}$, yielding $\approx 2.07\text{ steps/sec}$ ($0.48\text{ s}$ interval).
- **Running Cadence**: When running ($v \ge 3.6\text{ m/s}$), stride distance is $1.38\text{ m}$, yielding $\approx 3.14\text{ steps/sec}$ ($0.31\text{ s}$ interval).
- **Idle / Stopping**: When horizontal speed drops below `movement_threshold` ($0.15\text{ m/s}$), the accumulator immediately resets, preventing trailing steps after movement stops.
- **Airborne State**: When `is_on_floor()` is false, distance accumulation is paused.
- **Teleport Protection**: A single-frame position jump $> 2.5\text{ m}$ is identified as a teleport/respawn; the accumulator resets without triggering step bursts.
- **Repeat Avoidance**: Emitter maintains `_last_sample_index` and randomly selects from remaining variants so the exact same sample is never played consecutively.
- **Pitch Micro-Variation**: Applies random pitch variation ($\pm 4\%$) per step to eliminate repetitive acoustic fatigue.

---

## 5. Timeline Ambience Control

`AmbientAudioController` coordinates crossfading between Past and Future atmospheres:

```gdscript
@onready var ambient: AmbientAudioController = $AudioSystem/AmbientAudioController

# Start Past ambience with a 1.2-second crossfade
ambient.start_ambience(&"lab_ambience_past", 1.2)

# Switch to Future timeline
ambient.switch_timeline(&"Future", 1.0)

# Stop ambience
ambient.stop_ambience(1.0)
```

The controller guarantees that:
- Starting an already active ambience is idempotent (no duplicate overlapping players).
- Two internal players (`AmbiencePlayerA`, `AmbiencePlayerB`) perform smooth parallel volume tweens.
- Stopped players are terminated cleanly upon completion of the fade-out.

---

## 6. Audio Buses and Volume Control

`AudioDirector` automatically provisions category buses (`Master`, `Music`, `SFX`, `UI`, `Ambience`) in `AudioServer` at runtime without altering `project.godot`.

```gdscript
# Set linear volume between 0.0 (muted) and 1.0 (full)
audio_director.set_category_volume_linear(&"SFX", 0.8)
audio_director.set_category_volume_linear(&"UI", 0.6)

# Volume <= 0.0001 automatically mutes the bus
audio_director.set_category_volume_linear(&"Ambience", 0.0) # Muted

# Query current volume
var master_vol := audio_director.get_category_volume_linear(&"Master")
```

---

## 7. Future System Integration Hook Points

### 7.1 Modular Interaction System Integration
When the Interaction System agent finalizes `InteractionController`, connect audio callbacks without modifying core logic:
- `interactable_focused` -> `audio_director.play_ui(&"ui_hover")`
- `interaction_started` -> `audio_director.play_sfx(&"interaction_click")`
- `interaction_completed` -> `audio_director.play_sfx(&"interaction_success")`
- `interaction_failed` / `locked` -> `audio_director.play_sfx(&"interaction_denied")`

### 7.2 Host-Authoritative Puzzle State Integration
Under the network architecture:
1. Client requests action -> **Do not trigger completion audio**.
2. Host validates action and updates `PuzzleManager`.
3. Host broadcasts confirmed state via RPC.
4. Client receives confirmation -> call `audio_director.play_sfx(&"interaction_success")`.

### 7.3 Multiplayer / Split-Screen Considerations
- UI audio is strictly local.
- Ambience is selected based on each player's local timeline role (`Past` or `Future`).
- Footsteps are driven by local character movement. For remote characters in networked sessions, ensure velocity is replicated, or bind `FootstepEmitter3D` to the remote proxy node once position replication is active.
- For future local split-screen, each viewport requires an active `AudioListener3D` properly configured on its respective camera.

---

## 8. Verification and Test Suite Execution

### 8.1 Automated Headless Tests
Run the complete automated test suite (80 checks covering assets, catalog resolution, bounded player pools, volume attenuation, footstep cadence, and scene loading):

```powershell
& "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/audio_system.gd
```

### 8.2 Interactive Audio Sandbox
Launch the standalone testing sandbox to test movement, 3D spatial attenuation, and UI preview controls:

```powershell
& "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path . res://scenes/testing/audio_sandbox.tscn
```

