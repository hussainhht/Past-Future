# 03 GAME DESIGN: Mechanics, Puzzles & Design Reality

> **Historical document (internal).** Kept from the former `PROJECT_CONTEXT/` set for engineering context only. It describes the project as of 2026-10-21 and is not kept up to date. Current documentation map: [docs/README.md](../../README.md).

## 1. Game Design Document (GDD) Analysis

The authoritative game design specification is [GAME_DESIGN_DOCUMENT.md](../../design/GAME_DESIGN_DOCUMENT.md) (Version 0.17). It specifies a complete, 5-to-10 minute cooperative vertical slice titled **"Chapter 0: The First Fracture"**, centered around the Reboot CHECKPOINT Game Jam theme **"TWO"**.

### Design Pillars
1. **Asymmetric Knowledge**: Neither player possesses sufficient information on their screen to solve obstacles alone. Constant verbal communication is required.
2. **Deterministic Temporal Causality**: Actions performed in the pristine Past alter predetermined structures, electrical conduits, and machinery in the ruined Future.
3. **Investigative Observation**: No combat, no precision platforming, and no reflex-based action. Challenges center on observation, deduction, and temporal coordination.
4. **Physical Ground-Anchored Readability**: Clean, painted geometry viewed from a fixed perspective high top-down angle ($35^\circ$), allowing clear spatial awareness across both timelines.
5. **Private Dilemmas with Persistent Consequences**: Players are presented with private mechanical choices that shape the narrative resolution and surviving evidence without permanently breaking cooperation.

---

## 2. Planned Design vs. Implemented Reality Matrix

| Subsystem / Feature | GDD v0.17 Specification | Repository Implementation Status | Supporting Evidence & Files |
|---|---|---|---|
| **Player Roles** | Asymmetric roles: Student (Past) and Professor (Future). | **COMPLETE — VERIFIED** | [network_manager.gd](../../../scripts/network/network_manager.gd), [maintenance_corridor.gd](../../../scripts/world/maintenance_corridor.gd) |
| **Character Models** | Two distinct 3D models with age progression, shared rig, and shared facial landmarks. | **COMPLETE — VERIFIED** | [student.glb](../../../assets/characters/student_3d/student.glb), [professor.glb](../../../assets/characters/professor_3d/professor.glb), [manifest.json](../../../assets/characters/professor_3d/manifest.json) |
| **Locomotion** | 8-direction camera-relative ground movement + Shift sprint. | **COMPLETE — VERIFIED** | [student_3d_player.gd](../../../scripts/characters/student_3d_player.gd), `tests/spawn_area.gd` |
| **Perspective Camera** | Fixed $35^\circ$ downward pitch, $48^\circ$ FOV, follow smoothing. | **COMPLETE — VERIFIED** | [follow_camera.gd](../../../scripts/world/follow_camera.gd) |
| **3D Props & Shaders** | Solid painted furniture with footprint collision and lambertian normal shading. | **COMPLETE — VERIFIED** | [scenes/props/lab_prop.tscn](../../../scenes/props/lab_prop.tscn), [painted_prop.gdshader](../../../shaders/painted_prop.gdshader) |
| **Timeline Visual Swap** | Dynamic Past/Future shader and color switching. | **COMPLETE — VERIFIED** | [lab_floor.gdshader](../../../shaders/lab_floor.gdshader), [lab_prop.gd](../../../scripts/world/lab_prop.gd) |
| **Multiplayer Lobby** | ENet LAN host/join, ready state, IP display, UDP port 7000. | **COMPLETE — VERIFIED** | [network_manager.gd](../../../scripts/network/network_manager.gd), `tests/run_lan_smoke.py` |
| **Same-PC Split-Screen** | Offline split-screen with dual viewports and separate input actions. | **NOT STARTED** | Button in [main_menu.tscn](../../../scenes/menu/main_menu.tscn) is disabled (`COMING SOON`) |
| **Interaction System** | `Interactable3D` layer 4, dynamic prompt, `DeviceInspector3D` ray-picked physical parts. | **COMPLETE — VERIFIED** | [interactable_3d.gd](../../../scripts/interaction/interactable_3d.gd), [device_inspector_3d.gd](../../../scripts/gameplay/devices/device_inspector_3d.gd) |
| **Puzzle Authority** | Host-authoritative `PuzzleManager` with RPC validation and monotonically increasing revisions. | **COMPLETE — VERIFIED** | [puzzle_manager.gd](../../../scripts/puzzles/puzzle_manager.gd), `tests/run_puzzle_tests.py` |
| **Puzzle 01: Lost Frequency** | Signal Lab: frequency/amplitude dial calibration, transmission log, radio link, security door. | **COMPLETE — VERIFIED** | [frequency_puzzle.gd](../../../scripts/puzzles/implementations/frequency_puzzle.gd), `tests/run_frequency_tests.py` |
| **Puzzle 02: Broken Corridor** | Maintenance Corridor: Service bypass isolation, battery crank, BRACE/PIN/RETRACT bridge, archive code 3142. | **COMPLETE — VERIFIED** | [maintenance_corridor_puzzle.gd](../../../scripts/puzzles/implementations/maintenance_corridor_puzzle.gd), `tests/run_maintenance_tests.py` |
| **Level 02 Private Choices** | Local Reserve allocation and Incident Recorder cell extraction affecting audit evidence. | **COMPLETE — VERIFIED** | [maintenance_corridor.gd](../../../scripts/world/maintenance_corridor.gd), [docs/design/LEVEL_02.md](../../design/LEVEL_02.md) |
| **Puzzle 03: The Final Fracture** | Temporal Core: 150s countdown, 3 coils, receiver battery, anchor calibration, 5s phase switch, Stage C terminals. | **COMPLETE — VERIFIED** | [temporal_core.gd](../../../scripts/level3/temporal_core.gd), [core_rules.gd](../../../scripts/level3/core_rules.gd), `tests/run_level3_tests.py` |
| **Narrative Endings** | 4 distinct outcomes (`trust`, `student_override`, `professor_override`, `paradox`). | **COMPLETE — VERIFIED** | [scripts/level3/core_rules.gd](../../../scripts/level3/core_rules.gd) (tested in `level3_peer.gd`) |
| **Dialogue System** | Typewriter dialogue box, click/key advance, queue management, blocking/non-blocking modes. | **COMPLETE — VERIFIED** | [dialogue_director.gd](../../../scripts/dialogue/dialogue_director.gd), [dialogue_box.gd](../../../scripts/dialogue/dialogue_box.gd) |
| **Investigation Journal** | Role-segregated evidence tracker (Student notebook / Professor DataPad), hotkey `J`. | **COMPLETE — VERIFIED** | [journal_manager.gd](../../../scripts/journal/journal_manager.gd), `tests/journal_system.gd` |
| **Solo Ghost Prototype** | Cyan translucent hologram echo of other timeline within 4.5m radius, toggleable via `G`. | **COMPLETE — VERIFIED** | [temporal_ghost.gd](../../../scripts/world/temporal_ghost.gd), [temporal_ghost.gdshader](../../../shaders/temporal_ghost.gdshader) |
| **Audio Subsystem** | 5 audio buses, 3D footsteps, timeline ambiences, sound catalog, UI sound stings. | **COMPLETE — VERIFIED** | [audio_director.gd](../../../scripts/audio/audio_director.gd), `tests/audio_system.gd` |

---

## 3. The Two Characters: Dynamic & Asymmetry

### Character A — The Student (Past Timeline)
- **Age**: 18
- **Environment**: Functional, brightly lit, occupied university research wing.
- **Physical Capabilities**: Direct access to intact electrical panels, functional machine switches, movable hydraulic jacks, and active scientific terminals.
- **Limitation**: Lacks hindsight. Does not know the catastrophic failure codes or the disastrous consequence of the experiment.
- **Investigation Tool**: Spiral-bound paper notebook with handwritten sketches and notes.

### Character B — The Professor (Future Timeline)
- **Age**: 49 (31 years later)
- **Environment**: Decayed, dark, ruined facility with shattered walls and structural breaches.
- **Physical Capabilities**: Access to surviving archival incident reports, diagnostic load diagrams, burnt terminal displays, and physical rubble bridges.
- **Limitation**: Cannot alter decayed machinery directly; blocked by fallen slabs and damaged doors unless repaired in the past.
- **Investigation Tool**: Ruggedized electronic DataPad with recovered terminal logs and diagnostic graphs.

---

## 4. Temporal Causality Mechanics

```mermaid
sequenceDiagram
    autonumber
    actor Past as Student (Past Player)
    participant Host as Host Authority (Peer 1)
    participant Dict as State Dictionary (PuzzleManager)
    actor Future as Professor (Future Player)

    Note over Past, Future: Level 01: Lost Frequency
    Future->>Host: Read ruined terminal log (shows 67 MHz / 70% amp)
    Future-->>Past: Relays frequency over voice: "Tune to 67 MHz!"
    Past->>Host: submit_action("tune_frequency", 67)
    Host->>Dict: state["frequency"] = 67; rev++
    Host-->>Past: apply_puzzle_state(rev) -> Green signal LED
    Host-->>Future: apply_puzzle_state(rev) -> Radio link establishes & door unlocks

    Note over Past, Future: Level 02: Broken Corridor
    Future->>Host: Reads diagnostic diagram: BRACE / PIN / RETRACT
    Future-->>Past: Relays support plan: "Circle 3, Triangle 2, Square 1"
    Past->>Host: submit_action("set_supports", [3, 2, 1])
    Host->>Dict: state["supports"] = [3, 2, 1]; rev++
    Host-->>Past: apply_puzzle_state(rev) -> Support jacks lock
    Host-->>Future: apply_puzzle_state(rev) -> Fallen slab shifts into walkable bridge!
```

### Causality Modes
1. **Instant Direct Change**: Modifying an intact object in the past immediately updates the counterpart state in the future (e.g. restoring the SERVICE bypass circuit in the Past immediately energizes the Future auxiliary bus).
2. **Delayed Structural Consequence**: Reconfiguring structural hydraulic floor jacks in the Past alters how the ceiling collapsed 31 years later, transforming an impassable chasm into a walkable ramp.
3. **Retrocausality / Information Transfer**: Historical incident archives and diagnostic printouts surviving in the Future supply calibration frequencies and override access codes (e.g. service code `3142`) required in the Past.
4. **Persistent Private Dilemmas**:
   - *Local Reserve*: Diverting emergency reserve power benefits the local player while dropping the partner's auxiliary feed (requiring bypass repair).
   - *Incident Recorder Cell*: The Professor can extract the recorder battery to power the door immediately, but doing so erases the authorization evidence and triggers a confrontation ending.

---

## 5. Comprehensive Puzzle Specifications

### Puzzle 01: "Lost Frequency" (Signal Laboratory)
- **Location**: Signal Laboratory (`spawn_area.tscn`).
- **Duration**: 1–2 minutes.
- **Mechanics**:
  - Future player searches damaged equipment, locates the transmission terminal, and reads the surviving calibration log: **67 MHz**, **70% amplitude**.
  - Past player inspects the active console using `DeviceInspector3D`, rotating the physical 3D frequency dial to 67 and amplitude to 70.
  - Both players pick up their respective radio items.
  - Host validates settings $\longrightarrow$ communication stabilizes with an audio chime $\longrightarrow$ North security door unseals.

### Puzzle 02: "Broken Corridor / What We Leave Standing" (Maintenance Corridor)
- **Location**: Maintenance Corridor (`maintenance_corridor.tscn`).
- **Duration**: 3–4 minutes.
- **Three Cooperative Phases**:
  1. *Restore Service Power*: Professor reads the isolation plate; Student isolates the SERVICE circuit on the entry cabinet; Professor manually charges the emergency cell via a hand crank.
  2. *Brace the Future*: Professor inspects the diagnostic diagram; Student sets the three support controls to **Circle 3, Triangle 2, Square 1** and commits the plan. The fallen slab shifts into a guarded bridge in the Future.
  3. *Recover Core Access*: Professor crosses to the archive, reads service code **3142**, and discovers the shared watch detail confirming they are the same individual. Student enters 3142 at the console; Professor operates the manual wheel release.
- **Private Choices**: Engaging the Local Reserve or releasing the Backup Cell trades evidence preservation for early convenience.

### Puzzle 03: "The Final Fracture" (Temporal Research Core)
- **Location**: Temporal Research Core (`temporal_core.tscn`).
- **Duration**: 2–3 minutes.
- **Challenge**:
  1. *Discovery*: Reading authorization sheets and continuity recordings before arming the core.
  2. *Arming*: Using ARM REACTOR initiates the **150-second countdown**.
  3. *Stage A (Power)*: Future restores receiver battery and reads routing diagram (**coil 1 = 2, coil 2 = 0, coil 3 = 1**). Past cycles coils on the west bank $\longrightarrow$ opens the collapsed north conduit.
  4. *Stage B (Alignment)*: Future calibrates Signal Anchor; Past stabilizes Origin Core. Both players must hit their phase switches within a **5-second synchronization window**.
  5. *Stage C (Identity Terminals)*: Past uses Origin Terminal (*GROUND THE CORE* or *CLAIM ORIGIN*); Future uses Continuity Terminal (*RELEASE THE ECHO* or *PRESERVE ECHO*).
- **Four Distinct Endings**:
  - `trust` (Last Goodbye): Professor fades peacefully; world stabilized.
  - `student_override` (Erased Future): Future timeline erased; forbidden protocol signature exposed.
  - `professor_override` (Stolen Tomorrow): Student fades; Professor and altered future survive.
  - `paradox` (Iteration 02): Both identities dissolve; simulation restarts at first contact with `"ITERATION 02 DETECTED"`.
