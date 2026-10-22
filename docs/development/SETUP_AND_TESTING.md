# 10 SETUP AND TESTING: Environment, Execution & Test Suite Verification

> **Snapshot document.** Written on 2026-10-21 as part of the former `PROJECT_CONTEXT/` set, before the repository was reorganized. The code is the final authority; statements here (status, counts, file trees) may be out of date. Current documentation map: [docs/README.md](../README.md).

This document details the development environment prerequisites, execution commands, input bindings, and empirical test suite results for **Past-Future**.

---

## 1. Engine & Environment Prerequisites

### 1.1 Godot Engine
- **Required Version**: **Godot 4.7.2-stable (Official)**
- **Verified Local Executable**:
  `C:\Users\hanwd\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe`
  *(Console binary: `C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`)*
- **Verification Command**:
  ```powershell
  & "C:\Users\hanwd\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe" --version
  # Output: 4.7.2.stable.official.ed1daf0bf
  ```

### 1.2 Python Environment (Offline Tooling & Test Runners)
- **Version**: Python 3.11+
- **Dependencies**: Listed in [tools/requirements-character.txt](../../tools/requirements-character.txt):
  - `numpy==2.5.4`
  - `Pillow==13.0.0`
  - `bpy==5.2.2` (Optional, required only for headless Blender automation)
- **Installation**:
  ```powershell
  pip install -r tools/requirements-character.txt
  ```

### 1.3 Recommended Environment Variables
For automated test runners:
```powershell
$env:GODOT_BIN = "C:\Users\hanwd\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
$env:DISPLAY = "1"   # Required by run_cinematic_tests.py on Windows
```

---

## 2. Running the Game

### 2.1 Launching the Full Game (Main Menu)
```powershell
$Godot = "C:\Users\hanwd\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
& $Godot --path .
```
- **Main Scene**: `res://scenes/menu/main_menu.tscn`
- **Play Menu Options**:
  - `EXPLORE THE LAB (SOLO PREVIEW)`: Launches Level 1 (`spawn_area.tscn`).
  - `PLAY LEVEL 2 — TEST`: Direct offline launch into Level 2 (`maintenance_corridor.tscn`).
  - `PLAY LEVEL 3 — TEST`: Direct offline launch into Level 3 (`temporal_core.tscn`).
  - `LEVEL 3 / MULTIPLAYER TEST`: Launches Level 3 testbed launcher (`temporal_core_sandbox.tscn`).
  - `HOST ON WI-FI`: Starts ENet LAN server on UDP port 7000 (Student / Past).
  - `JOIN ON WI-FI`: Joins LAN server by IP on UDP port 7000 (Professor / Future).

### 2.2 Direct Level Launches (Fast Developer Testing)
```powershell
# Launch Room 01: Signal Laboratory
& $Godot --path . res://scenes/world/spawn_area.tscn

# Launch Room 02: Maintenance Corridor
& $Godot --path . res://scenes/world/maintenance_corridor.tscn

# Launch Room 03: The Final Fracture / Temporal Core
& $Godot --path . res://scenes/rooms/temporal_core.tscn

# Launch Level 3 Sandbox with Command-Line Role
& $Godot --path . res://scenes/testing/temporal_core_sandbox.tscn -- --core-solo future
```

---

## 3. Complete Input Controls Reference

The game supports seamless hot-swapping between Keyboard/Mouse, Sony DualSense (PS5), and Xbox controllers:

| Action | Keyboard / Mouse | DualSense (PS5) | Xbox Controller | In-Engine Behavior |
|---|---|---|---|---|
| **Move** | `W`, `A`, `S`, `D` or Arrows | Left Analog Stick / D-Pad | Left Analog Stick / D-Pad | Camera-relative ground movement ($2.8\text{ m/s}$) |
| **Sprint** | `Shift` (Hold) | `R2` Trigger / `L3` | `RT` Trigger / `LS` | Accelerates travel to $4.34\text{ m/s}$ ($1.55\times$) |
| **Interact** | `F` | Cross (`✕`) | `A` Button | Uses nearest highlighted 3D station / opens device |
| **Inspect** | `I` | Square (`□`) | `X` Button | Inspects item or plays inspection animation |
| **Use Item** | `E` | Triangle (`△`) | `Y` Button | Picks up / puts down hand-held item |
| **Journal** | `J` | Touchpad Click / Select | View / Select Button | Opens Student Notebook or Professor DataPad |
| **Solo Ghost** | `G` | `R1` Bumper | `RB` Bumper | Toggles cyan hologram echo in solo mode ($4.5\text{ m}$ radius) |
| **Switch Role**| `T` | `L1` Bumper | `LB` Bumper | Switches between Student and Professor in offline preview |
| **Studio** | `F2` | — | — | Opens in-game 3D Animation Review Studio |
| **Respawn** | `R` | — | — | Teleports player back to room entry spawn point |
| **Cancel / Pause**| `Escape` | Options / Start | Menu / Start | Closes 3D device inspector or opens Pause menu |
| **Device Click**| Left Mouse Click | Cross (`✕`) | `A` Button | Ray-picks 3D dials, switches, and numeric keypads |
| **Dial Adjust**| Mouse Drag / Wheel | D-Pad Left / Right | D-Pad Left / Right | Rotates frequency/amplitude tuning dials ($5^\circ/\text{MHz}$) |

---

## 4. Empirical Test Suite Audit Results

All test suites were executed on the active repository during this audit using Godot 4.7.2. Below is the verified evidence:

### 4.1 Asset Integrity Tests
```powershell
python tests/student_3d_assets.py
# Result: STUDENT 3D ASSETS: PASS (90881 skinned vertices, 23 rebuilt bind transforms, 77 clips, 5011 source/retargeted samplers)

python tests/student_3d_assets.py --character professor
# Result: PROFESSOR 3D ASSETS: PASS (113143 skinned vertices, 23 rebuilt bind transforms, 77 clips, 5011 source/retargeted samplers)
```
- **Status**: **PASS (100% verified)**

### 4.2 Main Menu Navigation Suite
```powershell
python tests/run_menu_tests.py
# Result: MENU BUTTONS: PASS (89 checks, 0 failures)
```
- **Status**: **PASS (100% verified)**

### 4.3 Authoritative Puzzle Replication Suite
```powershell
python tests/run_puzzle_tests.py
# Result: PUZZLE SYSTEM: PASS (131 checks, 0 failures)
#         puzzle sync host: PASS
#         puzzle sync client: PASS
```
- **Status**: **PASS (100% verified)**

### 4.4 Puzzle 01: Signal Laboratory & Frequency Suite
```powershell
python tests/run_frequency_tests.py
# Result: FREQUENCY RULES: PASS (72 checks)
#         FREQUENCY INTEGRATION: PASS (67 checks)
#         FREQUENCY host: PASS (17 checks)
#         FREQUENCY client: PASS (24 checks)

python tests/run_signal_lab_tests.py
# Result: SIGNAL LAB: PASS (0 failures)
#         signal lab host: PASS
#         signal lab client: PASS
```
- **Status**: **PASS (100% verified)**

### 4.5 Narrative Dialogue Suite
```powershell
python tests/run_dialogue_tests.py
# Result: DIALOGUE SYSTEM: PASS (382 checks, 0 failures)
```
- **Status**: **PASS (100% verified)**

### 4.6 Gamepad Controller Suite
```powershell
python tests/run_controller_tests.py
# Result: PS5 CONTROLLER SYSTEM: PASS (79 checks, 0 failures)
```
- **Status**: **PASS (100% verified)**

### 4.7 Cinematic Room Introduction Suite
```powershell
$env:DISPLAY = "1"
python tests/run_cinematic_tests.py
# Result: CINEMATIC: PASS (screenshots captured across all rooms)
```
- **Status**: **PASS (100% verified)**

### 4.8 3D Device Inspection & Solo Gameplay Suite
```powershell
python tests/run_gameplay_tests.py
# Result: GAMEPLAY SOLO: PASS (113 checks)
#         GAMEPLAY host: PASS (35 checks)
#         GAMEPLAY client: PASS (39 checks)
```
- **Status**: **PASS (100% verified)**

### 4.9 Puzzle 02: Maintenance Corridor Suite
```powershell
python tests/run_maintenance_tests.py
# Result: MAINTENANCE RULES: PASS (133 rule checks)
#         MAINTENANCE SCENE: PASS (104 scene checks)
#         TEMPORAL GHOST: PASS (All checks)
#         TEXT LAYOUT: PASS (All checks)
```
- **Status**: **PARTIAL** (Single-process rules, scene, ghost, and text layout pass; multi-process LAN test timed out on radio prerequisite).

### 4.10 Puzzle 03: The Final Fracture Suite
```powershell
python tests/run_level3_tests.py
# Result: LEVEL3 CORE: PASS (101 checks, 0 failures)
#         CORE_CASE host trust revision=69
#         CORE_CASE host student_override revision=137
#         CORE_CASE host professor_override revision=205
#         CORE_CASE host paradox revision=273
#         LEVEL3 host: PASS (38 checks, 0 failures)
#         LEVEL3 client: PASS (38 checks, 0 failures)
#         LEVEL3 ENet: PASS (all four endings agree; replay, role security and disconnect)
```
- **Status**: **PASS (100% verified)**

### 4.11 Standalone Engine Subsystem Tests
```powershell
& $Godot --headless --path . --script res://tests/interaction_system.gd | Out-String
# Result: INTERACTION SYSTEM: PASS (54 checks, 0 failures)

& $Godot --headless --path . --script res://tests/audio_system.gd | Out-String
# Result: AUDIO SYSTEM TESTS: ALL PASS (271 checks passed)

& $Godot --headless --path . --script res://tests/journal_system.gd | Out-String
# Result: JOURNAL CHECK OK (All role segregation and clue unlock checks passed)

& $Godot --headless --path . --script res://tests/settings_ui.gd | Out-String
# Result: SETTINGS UI: PASS (58 checks, 0 failures)

& $Godot --headless --path . --script res://tests/spawn_area.gd | Out-String
# Result: SPAWN AREA: PASS (0 failures)

& $Godot --headless --path . --script res://tests/student_3d.gd | Out-String
# Result: STUDENT 3D: PASS (0 failures; 77 animation clips)
```
- **Status**: **PASS (100% verified)**

### 4.12 Failing Tests & Regressions
1. **`python tests/run_game_flow_tests.py`**:
   - **FAIL**: Line 277 asserts `root.get_child_count() == 5` (expecting 4 autoloads + 1 room). Because `CinematicTransitionManager` was added as a 5th autoload, `root.get_child_count()` is 6.
2. **`python tests/run_lan_smoke.py`**:
   - **FAIL**: Line 127 checks `current_scene.scene_file_path` during async menu return when `current_scene` is briefly null.
3. **`tests/student_2d.gd`**:
   - **FAIL**: Legacy 2D prototype test fails on preload because directional PNG atlases were deleted in commit `4a1144d`.
