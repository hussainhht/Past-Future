# 01 PROJECT OVERVIEW: Concept, Theme & Technology

> **Snapshot document.** Written on 2026-10-21 as part of the former `PROJECT_CONTEXT/` set, before the repository was reorganized. The code is the final authority; statements here (status, counts, file trees) may be out of date. Current documentation map: [docs/README.md](../README.md).

## 1. High Concept & Story

**Past-Future** is an asymmetric cooperative puzzle adventure developed for the **Reboot CHECKPOINT Game Jam 2026**.

The core premise centers on two players controlling different temporal versions of the exact same person, separated by an irrevocable gap of **31 years**:
- **The Student (Age 18)**: An ambitious, curious university student conducting research in an intact, occupied scientific facility in the **Past**.
- **The Professor (Age 49)**: His older self, a guarded, experienced researcher standing inside the catastrophic, decayed ruins of the exact same university wing in the **Future**.

### The Narrative Hook
An experimental temporal device located in the university's research core has suffered a catastrophic temporal rupture known as **"The First Fracture"**. As the two characters establish an impossible audio-visual radio link across time (calibrated to 67 MHz), they begin uncovering the truth: **the catastrophe was not an accident—the Professor deliberately activated the experimental core**, acknowledged containment failure warnings, and disabled the automatic safety abort.

His true motives remain an enigma. To stabilize reality, contain the spreading fracture, and discover why their future self initiated the catastrophe, the two must cooperate across time:
- The past student adjusts machinery, restores electrical circuits, and reconfigures structural hydraulic supports.
- The future professor guides his younger self using surviving blueprints, equipment diagnostic diagrams, and historical service archives.
- As changes in the past physically reshape the future, the two characters uncover personal records, confronting the moral choices and consequences that bridge their 31-year divide.

---

## 2. Game Jam Theme: "TWO"

The game embodies the Reboot CHECKPOINT theme **"TWO"** at every layer of game design, narrative, and architecture:

| Dimension | Manifestation of "TWO" in Past-Future |
|---|---|
| **Characters** | Two versions of the same person: 18-year-old Student and 49-year-old Professor. |
| **Timelines** | Two distinct temporal worlds: The pristine academic Past and the decayed Future. |
| **Players** | Exactly two players cooperating; asymmetric information where neither can solve obstacles alone. |
| **Perspectives** | Two independent viewports/devices observing the same physical rooms separated by 31 years. |
| **Mechanics** | Dual-switch temporal synchronization (e.g. 5-second phase switch window, simultaneous confirmations). |
| **Dilemmas** | Two private shortcut decisions in Level 2: Local Reserve allocation and Incident Recorder cell extraction. |
| **Network Roles** | Host (Peer 1) = Student / Past; Client (Peer > 1) = Professor / Future. |

Neither player can complete the vertical slice alone.

---

## 3. Visual Tone & Atmospheric Identity

The game employs an **atmospheric painted low-poly style** that maximizes readability and aesthetic distinction without heavy texture overhead:
- **Perspective**: Fixed-angle high top-down perspective ($35^\circ$ downward pitch) with perspective projection (`Camera3D.PROJECTION_PERSPECTIVE`, $48^\circ$ FOV).
- **Characters**: Two original stylized low-poly 3D characters sharing the standard KayKit 23-joint skeleton and 77 genuine animation clips:
  - *Student*: Rounded low-poly features, swept dark hair, ochre jacket (`#b18145`), cream shirt, charcoal trousers, boots, messenger bag on right hip, and watch on left wrist.
  - *Professor*: Mature facial structure, subtle age lines, gray hair at temples, short beard and moustache, long dark navy academic coat with notched lapels and pocket pens, dark waistcoat, and the same original watch on his left wrist.
- **Environments**: Modular 3D laboratory furniture and industrial structures rendered using custom unshaded lambertian face shaders (`shaders/painted_prop.gdshader`).
- **Past Mood**: Warm, functional, academic, peaceful. Palette: warm cream (`#f0e2c7`), ochre yellow (`#e4bf7f`), warm olive/sage (`#575c4a`), natural wood brown (`#70442c`).
- **Future Mood**: Dark, ruined, abandoned, melancholic. Palette: cold cyan (`#86c9d1`), deep navy slate (`#15242b`), cold teal (`#263d45`), flickering violet energy accents.
- **Atmospheric Effects**: Cyan temporal ghost hologram echoes (`shaders/temporal_ghost.gdshader`), glowing temporal rift anomalies (`shaders/temporal_rift.gdshader`), procedural tile grout grids (`shaders/lab_floor.gdshader`).

---

## 4. Technology Stack & Platform Targets

| Component | Technology / Library | Version / Specifications | Evidence in Repo |
|---|---|---|---|
| **Game Engine** | Godot Engine | `4.7.2.stable.official.ed1daf0bf` | `project.godot` |
| **Rendering Backend** | GL Compatibility (`gl_compatibility`) | D3D12 driver on Windows (`rendering_device/driver.windows="d3d12"`) | `project.godot` |
| **Physics Engine** | Godot Jolt Physics 3D | `3d/physics_engine="Jolt Physics"` | `project.godot` |
| **Target Platform** | Windows PC (x86_64) | Tested on Windows 11 | Verified locally |
| **Base Resolution** | $1600 \times 900$ viewport | $1280 \times 720$ window override, min $960 \times 540$, `canvas_items` stretch | `project.godot` |
| **Multiplayer Transport** | Godot High-Level Multiplayer (`ENetMultiplayerPeer`) | Raw UDP on port `7000`, 2 peers (Host + 1 Client) | `scripts/network/network_manager.gd` |
| **WAN Remote Play** | Tailscale Virtual Mesh | Relayed/direct UDP 7000 connectivity over Tailscale VPN | GDD Section 9 |
| **Audio Subsystem** | 5 Audio Buses in Godot AudioServer | `Master`, `SFX`, `UI`, `Ambience`, `Music` | `scripts/audio/audio_director.gd` |
| **Input / Gamepad** | Godot InputMap + Custom Device Manager | Keyboard/Mouse + DualSense/Xbox controller auto-detection, rumble haptics | `scripts/input/input_manager.gd` |
| **Scripting Language** | GDScript 2.0 | Static typing conventions, signals, RPC annotations (`@rpc`) | Full codebase |
| **Offline Tooling** | Python 3.11+ | `numpy==2.5.4`, `Pillow==13.0.0`, `bpy==5.2.2` (Blender API) | `tools/` |

---

## 5. Scope & Demo Structure

- **Format**: Complete vertical slice demo for Game Jam evaluation.
- **Estimated Playtime**: **5 to 10 minutes** start to finish.
- **Demo Chapter**: *Chapter 0: The First Fracture*.
- **Rooms Implemented & Playable**:
  1. **Room 01: Signal Laboratory** (`scenes/world/spawn_area.tscn`): Communication stabilization, radio acquisition, frequency and amplitude calibration (67 MHz / 70%), investigation notebook/DataPad discovery, exit security door unsealing.
  2. **Room 02: Maintenance Corridor** (`scenes/world/maintenance_corridor.tscn`): Industrial utility gallery, service loop circuit isolation, emergency crank battery charging, BRACE/PIN/RETRACT (Circle 3, Triangle 2, Square 1) hydraulic bridge stabilization, personnel records archive (service code 3142), private shortcut choices (Local Reserve vs. Recorder Cell extraction), Core entrance release.
  3. **Room 03: The Final Fracture / Temporal Research Core** (`scenes/rooms/temporal_core.tscn`): High-stakes reactor chamber, 150-second countdown challenge initiated via ARM REACTOR, coil cycling (2, 0, 1), receiver battery reconnection, Signal Anchor and Origin Core stabilization, 5-second phase switch synchronization, and Stage C identity terminal choices.

---

## 6. Core Gameplay Loop & Win/Lose Conditions

### Core Gameplay Loop
$$\text{Enter Room} \longrightarrow \text{Explore & Inspect} \longrightarrow \text{Discover Asymmetric Clues} \longrightarrow \text{Exchange Info (Voice/LAN)} \longrightarrow \text{Past Physical Action} \longrightarrow \text{Future Environment Shift} \longrightarrow \text{Advance}$$

### Win Condition & Narrative Endings
Players successfully resolve Stage C at the Origin and Continuity terminals in the Temporal Core, unlocking one of **four distinct narrative endings**:
1. **`trust` (The Last Goodbye)**: Student chooses *GROUND THE CORE*, Professor chooses *RELEASE THE ECHO*. Core glows green; the Professor peacefully dissolves; the Student and world survive.
2. **`student_override` (Erased Future)**: Student chooses *CLAIM ORIGIN*, Professor chooses *RELEASE THE ECHO*. Core rings reverse with amber rotation; the future timeline is erased; the forbidden protocol signature is exposed.
3. **`professor_override` (Stolen Tomorrow)**: Student chooses *GROUND THE CORE*, Professor chooses *PRESERVE ECHO*. Cold blue anchor locks; the Student fades; the changed future and anchored Professor survive.
4. **`paradox` (Iteration 02)**: Student chooses *CLAIM ORIGIN*, Professor chooses *PRESERVE ECHO*. Violet counter-rotation; both identities dissolve; the system resets to first contact with `"ITERATION 02 DETECTED"`.

### Fail States & Recovery
- **Puzzles 01 & 02**: No game-over or death states. Unsafe support configurations or mismatched frequencies simply reject action without resetting earlier progress.
- **Puzzle 03 (150-Second Countdown)**: If the 150-second timer expires during active reactor stabilization, the system enters a 3-second `OVERLOAD` substate and resets to `DISCOVERY` (Attempt incremented, hardware and phase switches reset, positions reset to safe entrance landing). It is a challenge retry, not a permanent game over or session wipe.
- **Connection Loss**: If either peer disconnects, player movement and interactions are frozen, open evidence panels close, and a modal displays `"The connection was lost"`, allowing a clean return to the main menu.
