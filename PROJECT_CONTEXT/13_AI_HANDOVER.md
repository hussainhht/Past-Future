# 13 AI HANDOVER: Master Engineering Briefing & Architecture Invariants

> [!IMPORTANT]
> **READ THIS FIRST IF YOU ARE AN INCOMING AI ASSISTANT STARTING A FRESH SESSION.**  
> This document provides a self-contained, technically precise briefing on **Past-Future**. It assumes you have no access to previous conversation history. Read this document thoroughly before inspecting, proposing, or modifying any code.

---

## 1. Executive Summary: What Past-Future Is

- **Project Name**: **Past-Future**
- **Event**: Reboot CHECKPOINT Game Jam 2026 (Theme: **"TWO"**)
- **Genre**: Two-Player Asymmetric Cooperative Mystery / Puzzle Adventure
- **Format**: Complete 5-to-10 minute vertical slice (*Chapter 0: The First Fracture*)
- **Core Hook**: Two players control different temporal versions of the exact same individual, separated by **31 years**:
  - **The Student (Age 18)**: Investigating an intact university research facility in the **Past**.
  - **The Professor (Age 49)**: Navigating the catastrophic, decayed ruins of the same building in the **Future**.
- **The Core Mystery**: The catastrophic temporal rupture was not an accident—the Professor deliberately activated the experimental core, disabled the containment abort, and initiated the collapse for unknown reasons. The two players must cooperate across time to contain the fracture, culminating in four distinct narrative endings.
- **Asymmetric Principle**: Neither player can solve puzzles alone. The Future player reads surviving logs and structural diagrams; the Past player manipulates intact equipment and hydraulic jacks. Changes in the past physically reshape the future world.

---

## 2. What the Current Build Actually Does

Contrary to older documentation versions, the project is **not** a bare greybox sandbox—it is a **feature-complete 3-room cooperative campaign**:
1. **Room 01: Signal Laboratory** (`scenes/world/spawn_area.tscn`):
   - Assembled 3D lab environment with radio transceiver equipment.
   - Puzzle 01 ("Lost Frequency"): Future player recovers the transmission log; Past player uses the 3D device inspector to tune the physical dials to **67 MHz** and **70% amplitude**.
   - Stabilizing the radio link unlocks character dialogue, records notebook entries, and animates the North security door open.
2. **Room 02: Maintenance Corridor** (`scenes/world/maintenance_corridor.tscn`):
   - Industrial utility passage connecting the lab to the core.
   - Puzzle 02 ("Broken Corridor / What We Leave Standing"): SERVICE bypass electrical isolation, battery crank charging, and structural support reconfiguration (**Circle 3, Triangle 2, Square 1**), physically shifting a collapsed ceiling slab into a walkable bridge in the Future.
   - Personnel records archive, service code `3142`, and two private shortcut dilemmas (Local Reserve allocation and Incident Recorder cell extraction).
3. **Room 03: The Final Fracture / Temporal Research Core** (`scenes/rooms/temporal_core.tscn`):
   - Climax reactor chamber with a **150-second countdown challenge** initiated via ARM REACTOR.
   - West-bank coil cycling (2, 0, 1), receiver battery reconnection, Signal Anchor calibration, and Origin Core stabilization.
   - **5-second phase switch window**: Both players must hit their switches within 5 seconds of each other.
   - **Stage C Identity Terminals**: Origin Terminal (Past) and Continuity Terminal (Future) resolve into **four distinct narrative endings**:
     - `trust` (Last Goodbye): Professor voluntarily fades; world stabilized.
     - `student_override` (Erased Future): Future timeline erased; forbidden protocol exposed.
     - `professor_override` (Stolen Tomorrow): Student fades; altered future and Professor survive.
     - `paradox` (Iteration 02): Both identities dissolve; simulation restarts at first contact.

---

## 3. Technology Stack Reference

| Component | Specification | Repository Source |
|---|---|---|
| **Engine** | Godot Engine `4.7.2.stable.official.ed1daf0bf` | `project.godot` |
| **Renderer** | `gl_compatibility` (D3D12 driver on Windows) | `project.godot` |
| **Physics** | Godot Jolt Physics 3D (`3d/physics_engine="Jolt Physics"`) | `project.godot` |
| **Multiplayer** | High-Level Multiplayer (`ENetMultiplayerPeer`) on UDP port `7000` | `scripts/network/network_manager.gd` |
| **Viewports** | $1600 \times 900$ virtual canvas, $1280 \times 720$ window override | `project.godot` |
| **Scripting** | GDScript 2.0 (Static typing, signals, RPCs) | Entire codebase |
| **Gamepad** | DualSense (PS5) & Xbox auto-detection, glyphs, rumble haptics | `scripts/input/input_manager.gd` |

---

## 4. Architectural Hierarchy & Active Autoload Singletons

The engine configuration (`project.godot`) registers **5 global Autoload singletons** in exact execution priority order:

1. **`NetworkManager`** ([scripts/network/network_manager.gd](../scripts/network/network_manager.gd)):
   - ENet multiplayer transport on UDP 7000.
   - Manages connection lifecycle (`IDLE`, `HOSTING`, `CONNECTING`, `CONNECTED`).
   - Host = Peer 1 (Student / Past); Client = Peer > 1 (Professor / Future).
2. **`PuzzleManager`** ([scripts/puzzles/puzzle_manager.gd](../scripts/puzzles/puzzle_manager.gd)):
   - Central host-authoritative state dictionary and monotonic revision tracker.
   - RPC submission pipeline: `submit_action` $\rightarrow$ Host validation $\rightarrow$ confirmed broadcast.
   - Hook `refresh_puzzle(id)` for timed challenges.
3. **`GameFlowManager`** ([scripts/game_flow/game_flow_manager.gd](../scripts/game_flow/game_flow_manager.gd)):
   - Decoupled room transitions, fade-out/fade-in, and multi-peer readiness synchronization.
   - Loads rooms via `RoomDefinition` resources (`resources/levels/room_01.tres`, etc.).
   - Persists network connections and puzzle sessions across room changes.
4. **`JournalManager`** ([scripts/journal/journal_manager.gd](../scripts/journal/journal_manager.gd)):
   - Session-long investigation evidence tracker (`scenes/journal/journal_ui.tscn`).
   - Role-segregated: Student paper notebook vs. Professor electronic DataPad (`J` hotkey).
5. **`CinematicTransitionManager`** ([scripts/cinematic/cinematic_transition_manager.gd](../scripts/cinematic/cinematic_transition_manager.gd)):
   - CanvasLayer 40 room introduction title cards (`scenes/cinematic/cinematic_transition.tscn`).
   - Automated presentation trigger on room arrival.

---

## 5. Non-Negotiable Engineering Invariants

When adding, fixing, or modifying code, you must strictly preserve these principles:

1. **Floor-Contact Root Convention ($Y = 0$)**:
   - All character scenes, static furniture props, and room boundaries have their root node position at floor contact ($Y = 0$).
   - Collision shapes, visuals, and raycasts offset upward from this ground anchor. Never move scene roots away from ground level.
2. **Fixed Perspective Camera**:
   - The camera uses `Camera3D.PROJECTION_PERSPECTIVE` with a fixed $35^\circ$ downward pitch, $48^\circ$ field of view, and smooth asymptotic follow smoothing.
   - **There are no camera rotation controls for players.** Perimeter walls are kept low ($1.0\text{ m}$) specifically to prevent occluding this perspective.
3. **Strict Host-Authoritative Puzzle State**:
   - **Clients must NEVER mutate puzzle or progression state optimistically.**
   - All actions must flow: `Client Action Request (RPC)` $\rightarrow$ `Host Validation` $\rightarrow$ `State Revision Increment` $\rightarrow$ `Broadcast Confirmed State (RPC)`.
4. **Multi-Instance Resource Duplication**:
   - Skinned meshes and furniture duplicate their materials and `AnimationLibrary` instances in `_ready()` (`.duplicate(true)`).
   - In Godot, imported GLBs share resource references across instances. Failure to duplicate results in timeline tints bleeding between the Past and Future characters.
5. **GL Compatibility Constraints**:
   - Do not introduce Vulkan-only or Forward+ features (SDFGI, volumetric fog, GPU compute shaders). All shaders must run in `gl_compatibility`.

---

## 6. Active Characters Reference

- **Student (Age 18)**:
  - Model: `assets/characters/student_3d/student.glb` ($90,881$ vertices, 23 bones, 77 KayKit clips).
  - Scene: `scenes/characters/student_3d_player.tscn`.
  - Landmarks: Ochre jacket, cream shirt, messenger bag on right hip, watch on left wrist.
- **Professor (Age 49)**:
  - Model: `assets/characters/professor_3d/professor.glb` ($113,143$ vertices, 23 bones, 77 KayKit clips).
  - Scene: `scenes/characters/professor_3d_player.tscn`.
  - Landmarks: Long dark navy formal coat, dark waistcoat, slate shirt, gray hair temples, short beard, same watch on left wrist.
- **In-Game Studios**: Press `F2` to open the 3D Animation Review Studio (`scenes/characters/student_3d_studio.tscn` or `professor_3d_studio.tscn`).

---

## 7. Known Issues & Test Caveats

1. **`tests/game_flow_system.gd` Assertion Mismatch**:
   - Line 277 asserts `root.get_child_count() == 5` (expecting 4 autoloads + 1 room). Because `CinematicTransitionManager` was added as a 5th autoload, `root.get_child_count()` is 6. Needs assertion update to 6.
2. **`tests/maintenance_peer.gd` LAN Timeout**:
   - In `run_maintenance_tests.py`, the single-process checks pass 100%, but the two-peer LAN check times out waiting for the radio prerequisite because the laboratory now requires device inspector interaction steps. Line 52 also needs an `await` on the async `wait_for`.
3. **`tests/lan_peer.gd` Transient Null Reference**:
   - Line 127 checks `current_scene.scene_file_path` during async scene unloading before checking `is_instance_valid(current_scene)`.
4. **`tests/run_cinematic_tests.py` on Windows**:
   - Requires `$env:DISPLAY = "1"` in PowerShell to prevent it from attempting to invoke `xvfb-run`.
5. **Legacy Deprecated Files (Do Not Touch)**:
   - `student_paper_rig.gd` and `tests/student_2d.gd`: Legacy 2D prototype (PNG atlases deleted in `4a1144d`; preserved in `244b42a`).
   - `student_model.tscn`: Legacy articulated 3D model (Missing deleted `student_v2.glb`).

---

## 8. Verification & Test Commands

Before committing or declaring a task complete, run these verified commands:

```powershell
# Set environment
$env:GODOT_BIN = "C:\Users\hanwd\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
$env:DISPLAY = "1"

# 1. Verify Character Asset Provenance & Rig Bindings
python tests/student_3d_assets.py
python tests/student_3d_assets.py --character professor

# 2. Verify Main Menu Navigation
python tests/run_menu_tests.py

# 3. Verify Authoritative Puzzle System
python tests/run_puzzle_tests.py

# 4. Verify Level 1 Frequency Puzzle
python tests/run_frequency_tests.py

# 5. Verify Dialogue System (382 checks)
python tests/run_dialogue_tests.py

# 6. Verify Gamepad Controllers & Haptics
python tests/run_controller_tests.py

# 7. Verify Cinematic Room Introductions
python tests/run_cinematic_tests.py

# 8. Verify Level 3 The Final Fracture Suite (101 core checks, 4 endings across ENet peers)
python tests/run_level3_tests.py

# 9. Verify Audio, Journal, Settings, and Interaction
& $env:GODOT_BIN --headless --path . --script res://tests/audio_system.gd | Out-String
& $env:GODOT_BIN --headless --path . --script res://tests/journal_system.gd | Out-String
& $env:GODOT_BIN --headless --path . --script res://tests/interaction_system.gd | Out-String
```

---

## 9. Immediate Recommended Next Task

```text
================================================================================
>>> RECOMMENDED NEXT TASK: IMPLEMENT SAME-PC SPLIT-SCREEN MODE (TASK P0.1)
================================================================================
Enable the disabled `SAME-PC SPLIT-SCREEN` button on `scenes/menu/main_menu.tscn`.
Create `scenes/world/split_screen_game.tscn` using dual `SubViewportContainer`
nodes (Left = Past / Student, Right = Future / Professor) and route input
locally to `PuzzleManager`.

WHY THIS IS CRITICAL:
The game already has 3 fully playable rooms, 2 complete character models, and
4 narrative endings. However, it requires two PCs or Tailscale networking to play.
Building the offline Same-PC Split-Screen mode guarantees that any Game Jam
judge can experience the full cooperative campaign on a single computer.
================================================================================
```
