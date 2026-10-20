# 10 SETUP AND TESTING: Environment, Execution & Test Suite Verification

This document details the development environment prerequisites, execution instructions, input configurations, and empirical verification procedures for **Past-Future**.

---

## 1. Engine & Environment Prerequisites

### 1.1 Godot Engine
- **Required Version**: **Godot 4.7.2-stable (Official)**
- **Binary Location on Local System**:
  `C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- **Verification Command**:
  ```powershell
  & "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --version
  # Output: 4.7.2.stable.official.ed1daf0bf
  ```

### 1.2 Python Environment (for Tooling and Asset Verification)
- **Required Version**: Python 3.11+ (Python 3.11.9 or 3.13)
- **Dependencies**: Listed in [tools/requirements-character.txt](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/tools/requirements-character.txt):
  - `numpy==2.5.4`
  - `Pillow==13.0.0`
  - `bpy==5.2.2` (optional, needed only for Blender automation)
- **Installation**:
  ```powershell
  pip install -r tools/requirements-character.txt
  ```

---

## 2. Running the Game

### 2.1 Launching the Full Game (Main Menu)
From the repository root:
```powershell
$Godot = "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
& $Godot --path .
```
- **Main Scene**: `res://scenes/menu/main_menu.tscn`
- **Expected Behavior**: Opens the title screen with animated background clock hands and dust particles. From here you can host a LAN game, join a game, or select "EXPLORE THE LAB / SOLO PREVIEW".

### 2.2 Launching the Lab Directly (Fast Level Testing)
```powershell
& $Godot --path . res://scenes/world/spawn_area.tscn
```
- **Expected Behavior**: Spawns directly into the Signal Laboratory greybox in Past mode. You can move, run, trigger animations, open the character studio with `F2`, or click "VIEW FUTURE" to toggle the timeline.

### 2.3 Opening in the Godot Editor
```powershell
& $Godot --editor --path .
```

---

## 3. Input Controls Reference

### 3.1 Movement & Locomotion
| Key / Input | Action | Logic / Code Location |
|---|---|---|
| `W` / `Up Arrow` | Move forward / upward ($-Z$) | `Input.get_vector("move_left", "move_right", "move_up", "move_down")` |
| `A` / `Left Arrow` | Move left ($-X$) | In `scripts/characters/student_3d_player.gd` |
| `S` / `Down Arrow` | Move backward / downward ($+Z$) | Unprojected into camera space |
| `D` / `Right Arrow`| Move right ($+X$) | Normalized diagonal velocity |
| `Shift` (Hold) | Sprint ($1.55\times$ speed) | `Input.is_physical_key_pressed(KEY_SHIFT)` |

### 3.2 Actions & Animations
| Key / Input | Action | Behavior |
|---|---|---|
| `F` | Interact | Plays `Interact` animation; locks movement until finish |
| `I` | Inspect / Use Item | Plays `Use_Item` animation; locks movement |
| `E` | Pick Up / Put Down | Plays `PickUp` clip; attaches/detaches demonstration document on hand |
| `R` | Respawn | Teleports player back to `SpawnPoint` marker $(0, 0, 3.7)$ |
| `F2` | Character Studio | Opens in-game 3D character review studio (`student_3d_studio.tscn`) |
| `Esc` | Pause / Menu | Toggles in-game pause modal; closes open studio |

---

## 4. Test Suite Execution & Empirical Results

The project contains four automated verification scripts. All tests were executed and validated on the local machine:

### 4.1 Asset Integrity & Provenance Check (`tests/student_3d_assets.py`)
- **Command**:
  ```powershell
  python tests/student_3d_assets.py
  ```
- **Scope**: Evaluates binary glTF structures, bind matrix inversion tolerances, normal unit lengths, non-negative skin weights, and bit-exact rotation/timing match against original KayKit source GLBs.
- **Empirical Output**:
  ```text
  STUDENT 3D ASSETS: PASS (71806 skinned vertices, 23 rebuilt bind transforms, 77 clips, 5011 source/retargeted samplers)
  ```
- **Status**: **PASS (100% verified)**

---

### 4.2 Headless Skeletal Animation Verification (`tests/student_3d.gd`)
- **Command**:
  ```powershell
  & "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/student_3d.gd
  ```
- **Scope**: Instantiates `scenes/characters/student_3d_player.tscn` in Godot headless mode; verifies finite bone transforms across all 77 clips, independent player material tints, one-shot action recovery, hand prop attachment, and pause freeze.
- **Empirical Output**:
  ```text
  Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
  STUDENT 3D: PASS (0 failures; 77 animation clips)
  ```
- **Status**: **PASS (100% verified)**

---

### 4.3 Headless Scene Simulation & Physics Test (`tests/spawn_area.gd`)
- **Command**:
  ```powershell
  & "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/spawn_area.gd
  ```
- **Scope**: Loads `scenes/world/spawn_area.tscn`; simulates 8-direction character travel, collision boundary stoppage against walls and furniture, camera follow smoothing, perspective projection ratios, timeline visual switching, and pause menu navigation.
- **Empirical Output**:
  ```text
  Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
  SPAWN AREA: PASS (0 failures)
  ```
- **Status**: **PASS (100% verified)**

---

### 4.4 Multi-Process LAN ENet Smoke Test (`tests/run_lan_smoke.py`)
- **Command**:
  ```powershell
  $env:GODOT_BIN = "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
  python tests/run_lan_smoke.py
  ```
- **Scope**: Launches multiple concurrent Godot processes executing `tests/lan_peer.gd` over loopback:
  1. Verifies that an occupied UDP port properly rejects a duplicate host.
  2. Launches a Host peer (Past).
  3. Launches a Client peer (Future); connects to Host via loopback.
  4. Tests ready/unready requests, client disconnect and reconnect, host game start authorization, and transition to `spawn_area.tscn`.
- **Empirical Output**:
  ```text
  busy: PASS
  host: PASS
  client: PASS
  LAN smoke check passed. Test on two Wi-Fi computers before release.
  ```
- **Status**: **PASS (100% verified)**

---

### 4.5 Legacy 2D Prototype Test (`tests/student_2d.gd`)
- **Command**:
  ```powershell
  & "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/student_2d.gd
  ```
- **Status**: **KNOWN FAILURE** (Fails on preload because directional PNG atlases were deleted in commit `4a1144d`). See [09_BUGS_AND_TECHNICAL_DEBT.md](09_BUGS_AND_TECHNICAL_DEBT.md) for details.

