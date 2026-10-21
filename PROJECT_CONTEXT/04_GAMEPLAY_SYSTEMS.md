# 04 GAMEPLAY SYSTEMS: Controls, Physics, Cameras & Gameplay Subsystems

This document provides a comprehensive technical breakdown of all active gameplay systems implemented in **Past-Future**.

---

## 1. Character Locomotion & Physics Simulation

- **Source Code**: [scripts/characters/student_3d_player.gd](../scripts/characters/student_3d_player.gd)
- **Scene Files**: [scenes/characters/student_3d_player.tscn](../scenes/characters/student_3d_player.tscn), [scenes/characters/professor_3d_player.tscn](../scenes/characters/professor_3d_player.tscn)
- **Base Node**: `CharacterBody3D`
- **Physics Engine**: Godot Jolt Physics 3D (`3d/physics_engine="Jolt Physics"`)
- **Status**: **COMPLETE — VERIFIED**

### 1.1 Collision Footprint & Ground Contact Anchor
All characters and physical entities maintain their root origin at floor level ($Y = 0$):
- **Collision Shape**: Cylinder shape with radius $0.28\text{ m}$ and height $0.4\text{ m}$, centered at $Y = 0.2\text{ m}$.
- **Floor Snapping**: `floor_snap_length = 0.25` ensures smooth traversal over minor seams and dynamic geometry ramps.
- **Faux Shadow**: A flat circular mesh ($r = 0.43\text{ m}, h = 0.006\text{ m}$) at $Y = 0.012\text{ m}$ casts a lightweight floor shadow without runtime dynamic shadow map cost.

### 1.2 Movement Calculation & Camera-Relative Vectors
Movement is processed in `_physics_process(delta)`. Input from WASD and arrow keys is unprojected into the camera's ground basis:
```gdscript
var right := view_camera.global_basis.x
right.y = 0.0
right = right.normalized()

var down := view_camera.global_basis.z
down.y = 0.0
down = down.normalized()

var ground_direction := right * direction.x + down * direction.y
```

### 1.3 Velocity, Sprinting & Turning
- **Base Walk Speed**: $2.8\text{ m/s}$.
- **Sprint Modifier**: Sprinting is activated via `sprint` action (`Shift` or gamepad trigger), increasing speed to $\approx 4.34\text{ m/s}$ ($1.55\times$). Sprinting is disabled while carrying items.
- **Smooth Visual Rotation**: The visual child node (`$Visual`) smoothly interpolates toward the travel heading:
  ```gdscript
  if not ground_direction.is_zero_approx():
      $Visual.rotation.y = rotate_toward($Visual.rotation.y, atan2(ground_direction.x, ground_direction.z), delta * 12.0)
  ```

---

## 2. Animation System & Action State Machine

- **Source Code**: [scripts/characters/student_3d_player.gd](../scripts/characters/student_3d_player.gd)
- **Models**: [student.glb](../assets/characters/student_3d/student.glb), [professor.glb](../assets/characters/professor_3d/professor.glb)
- **Status**: **COMPLETE — VERIFIED**

### 2.1 Multi-Instance Animation Isolation
To prevent shared GLB resources from cross-contaminating between timelines, `student_3d_player.gd` duplicates the animation library at runtime:
```gdscript
var library: AnimationLibrary = animator.get_animation_library("").duplicate(true)
animator.remove_animation_library("")
animator.add_animation_library("", library)
```
Looping properties are set dynamically: locomotion clips (`Idle_A`, `Walking_A`, `Running_A`, `Holding_A`) loop linearly, while action clips loop none.

### 2.2 Locomotion Blending & One-Shot Action Locking
- Stationary character blends smoothly to `Idle_A` (crossfade $0.12\text{ s}$).
- Moving character plays `Walking_A` or `Running_A`.
- One-shot actions (`interact`, `inspect`, `pick_up`, `put_down`, `wave`) lock player locomotion until `animation_finished` fires, clearing `_action` and emitting `action_finished`.

---

## 3. Fixed Perspective Follow Camera

- **Source Code**: [scripts/world/follow_camera.gd](../scripts/world/follow_camera.gd)
- **Status**: **COMPLETE — VERIFIED**

### 3.1 Projection & Framing Geometry
- **Projection**: `Camera3D.PROJECTION_PERSPECTIVE`
- **Field of View (FOV)**: $48^\circ$
- **Pitch**: Fixed at $35^\circ$ downward pitch (`rotation.x = -deg_to_rad(35.0)`).
- **Distance**: $20.0\text{ m}$ along viewing vector.
- **Tracking**: Tracks player target smoothly via asymptotic exponential smoothing (`1.0 - exp(-8.0 * delta)`), with a forward look-ahead offset of $2.0\text{ m}$.

---

## 4. Spatial Interaction System

- **Source Code**: [scripts/interaction/](../scripts/interaction/)
- **Components**: `Interactable3D`, `InteractionDetector`, `InteractionController`, `InteractionPrompt`
- **Collision Layer**: Layer 4 (`Interaction`)
- **Status**: **COMPLETE — VERIFIED**

### 4.1 Architecture
1. **`Interactable3D`**: Attached to interactive objects. Defines interaction distance ($1.5\text{ m}$), allowed timelines (`PAST`, `FUTURE`, `BOTH`), priority, and action prompt text.
2. **`InteractionDetector`**: Attached to player. Queries layer 4 via shape casting/overlaps; selects highest-priority target with distance hysteresis to prevent prompt flickering.
3. **`InteractionController`**: Processes `interact` input (`F` / button A), verifies target validity, triggers character animation locking, and dispatches the action.
4. **`InteractionPrompt`**: Dynamic floating/HUD widget displaying contextual action labels and device-specific button glyphs (keyboard `[F]`, PlayStation `[✕]`, Xbox `[A]`).

---

## 5. 3D Physical Device Inspector

- **Source Code**: [scripts/gameplay/devices/device_inspector_3d.gd](../scripts/gameplay/devices/device_inspector_3d.gd)
- **Status**: **COMPLETE — VERIFIED**

### 5.1 Real Equipment Close-Up Interaction
When inspecting equipment (such as the Signal Lab frequency console or the Maintenance Corridor keypads):
- The camera smoothly tweens from the follow rig to an authored inspection viewpoint.
- Interactive components (rotatable dials, buttons, levers, numeric keypads) use ray-picked collision on layer 32.
- The frequency dial can be dragged via mouse or rotated via scroll wheel and arrow keys ($5^\circ$ per MHz), displaying live frequency readouts on a 3D label.
- Accompanying story records and technical logs display in a readable, scrollable side card formatted by `world_text_layout.gd`.
- Pressing `Escape` or backing out restores the follow camera and releases player input.

---

## 6. Narrative Dialogue System

- **Source Code**: [scripts/dialogue/dialogue_director.gd](../scripts/dialogue/dialogue_director.gd), [scripts/dialogue/dialogue_box.gd](../scripts/dialogue/dialogue_box.gd)
- **Status**: **COMPLETE — VERIFIED**

### 6.1 Features
- Data-driven dialogue sequences (`DialogueSequence` and `DialogueLine` resources).
- Typewriter character rollout with customizable speed (default 40 char/s).
- Player advance via action key (`F`, `Space`, `Enter`) or mouse click.
- Speaker portraits (Student, Professor, Radio, System) and timeline badge styling.
- Non-blocking ambient dialogue vs. blocking story sequences (temporarily locks player input).
- Line queues, duplicate rejection, and narrative event request dispatching.

---

## 7. Investigation Journal System

- **Source Code**: [scripts/journal/journal_manager.gd](../scripts/journal/journal_manager.gd), [scenes/journal/journal_ui.tscn](../scenes/journal/journal_ui.tscn)
- **Status**: **COMPLETE — VERIFIED**

### 7.1 Features
- Accessible via hotkey `J` (or controller Touchpad / Select).
- Timeline-segregated evidence:
  - *Student*: Spiral paper notebook skin with handwritten lab notes and observations.
  - *Professor*: Ruggedized electronic DataPad skin with terminal logs and diagnostic records.
- Clues discovered by one role are **not** automatically shown to the other, preserving the asymmetric information requirement.
- Displays unlock toasts upon discovery; persists across room transitions; clears cleanly on session reset.

---

## 8. Solo Temporal Ghost Hologram

- **Source Code**: [scripts/world/temporal_ghost.gd](../scripts/world/temporal_ghost.gd)
- **Shader**: [shaders/temporal_ghost.gdshader](../shaders/temporal_ghost.gdshader)
- **Status**: **COMPLETE — VERIFIED**

### 8.1 Offline Co-op Assistance
In solo testing modes, the player can toggle a translucent cyan hologram of the opposite character and their immediate surroundings:
- Toggle key: `G` or gamepad bumper (`R1` / `RB`).
- Radius: $4.5\text{ m}$ circular area around the inactive character's position.
- Renders opposite-timeline geometry (such as the adjusted bridge slab or hydraulic supports) using soft silhouette fading.
- Geometrically clipped and cached to minimize draw call overhead ($\approx 3 - 4$ additional draw calls).

---

## 9. Audio Subsystem

- **Source Code**: [scripts/audio/audio_director.gd](../scripts/audio/audio_director.gd)
- **Scene**: [scenes/audio/audio_system.tscn](../scenes/audio/audio_system.tscn)
- **Assets**: Kenney CC0 sound effects and ambient tracks in `assets/audio/`
- **Status**: **COMPLETE — VERIFIED**

### 9.1 Audio Architecture
- **5 Audio Buses**: `Master`, `SFX`, `UI`, `Ambience`, `Music`.
- **`SoundCatalog`**: Dictionary-driven sound mapping supporting pitch variation and randomized sample selection.
- **`FootstepEmitter3D`**: Cadence-based surface footsteps (tile in Past, concrete in Future) that automatically scale with walk/run velocity and silence while airborne.
- **`AmbientAudioController`**: Looping atmospheric background sounds with smooth crossfading between Past and Future rooms.

---

## 10. Gamepad & Controller Support

- **Source Code**: [scripts/input/input_manager.gd](../scripts/input/input_manager.gd)
- **Documentation**: [docs/CONTROLLER_SUPPORT.md](../docs/CONTROLLER_SUPPORT.md)
- **Status**: **COMPLETE — VERIFIED**

### 10.1 Multi-Device Input Management
- Real-time device detection: Keyboard/Mouse, Sony DualSense (PS5), and Xbox controllers.
- Automatic prompt glyph adaptation (e.g. switching from `[F]` to `[✕]` or `[A]`).
- Haptic vibration patterns (`rumble_gentle`, `rumble_heavy`, `rumble_pulse`, `temporal_heartbeat`, `device_tick`).
- Configurable analog deadzones ($0.20$ default) and stick noise filtering.

---

## 11. Multiplayer Network Session Management

- **Source Code**: [scripts/network/network_manager.gd](../scripts/network/network_manager.gd)
- **Transport**: `ENetMultiplayerPeer` over UDP port `7000`.
- **Status**: **COMPLETE — VERIFIED**

### 11.1 Topology & Role Handshake
- **Host**: Always Peer 1 = Student / Past Timeline.
- **Client**: Peer $> 1$ = Professor / Future Timeline.
- Handshake protocol: `_register_client` $\rightarrow$ `_apply_lobby` $\rightarrow$ `_request_ready` $\rightarrow$ `_begin_game`.
- Disconnect handling: Halts character input, closes open modals, and displays connection recovery prompt.
