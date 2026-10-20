# 13 AI HANDOVER: Master Engineering Briefing & Architecture Invariants

> [!IMPORTANT]
> **READ THIS FIRST IF YOU ARE AN AI ASSISTANT STARTING A NEW TURN OR SESSION.**  
> This document is designed to give you a complete, self-contained understanding of **Past-Future** without needing access to previous conversations. Read this document thoroughly before inspecting or writing any code.

---

## 1. Executive Summary: What We Are Building

- **Game Title**: **Past-Future**
- **Event**: Reboot CHECKPOINT Game Jam 2026 (Theme: **"TWO"**)
- **Genre**: Two-player Asymmetric Cooperative Mystery / Puzzle Adventure
- **Duration**: $5 - 10$ minute vertical slice (*Chapter 0: The First Fracture*)
- **Core Hook**: Two players control different temporal versions of the same person separated by **31 years**:
  - **The Student (Age 18)** in the intact, pristine university laboratory of the **Past**.
  - **The Professor (Age 49)** in the decayed, catastrophic ruins of the **Future**.
- **The Mystery**: The experimental core fracture was not an accident—the Professor deliberately triggered it. The players must cooperate across time to stabilize reality before total collapse occurs, culminating in a dramatic cliffhanger reveal.
- **Asymmetric Dynamic**: Neither player has enough information to solve puzzles alone. The Future player reads surviving logs and structural diagrams; the Past player manipulates intact equipment and hydraulic supports. Changes in the past physically reconstruct the future.

---

## 2. Complete Technology Stack Reference

| Layer | Component / Tech | Details / Configuration |
|---|---|---|
| **Engine** | Godot Engine | `4.7.2.stable.official` (Windows x86_64) |
| **Renderer** | `gl_compatibility` | D3D12 driver on Windows (`rendering_device/driver.windows="d3d12"`) |
| **Physics** | Godot Jolt Physics 3D | Configured in `project.godot`: `3d/physics_engine="Jolt Physics"` |
| **Networking** | High-Level Multiplayer (`ENetMultiplayerPeer`) | Raw UDP on port `7000`. Server = Past, Client = Future. |
| **WAN Remote** | Tailscale Virtual Mesh | Relayed/direct UDP 7000 connectivity |
| **Viewport** | $1600 \times 900$ Canvas Items | Window override $1280 \times 720$, min $960 \times 540$ |
| **Scripting** | GDScript 2.0 | Static typing conventions, signals, RPCs |
| **External Tools** | Python 3.11 / 3.13 | `numpy==2.5.4`, `Pillow==13.0.0`, `bpy==5.2.2` (Blender API) |

---

## 3. Current Development State: The Honest Reality

```text
+---------------------------------------------------------------------------------------+
|                                    CURRENT STATE                                      |
+---------------------------------------------------------------------------------------+
|  [WHAT WORKS - 100% VERIFIED]               |  [WHAT IS MISSING - ZERO CODE EXISTS]   |
|  - Title screen, settings, LAN lobby UI     |  - ZERO gameplay puzzles implemented    |
|  - ENet LAN Host/Join & handshake on 7000   |  - NO PuzzleManager or state sync       |
|  - Skinned 3D Student model (71k verts)     |  - NO interaction system (Area3D)       |
|  - 77 imported KayKit animation clips       |  - NO Professor model (reuses Student)  |
|  - Camera-relative 8-direction locomotion   |  - NO split-screen mode (button disabled)|
|  - Fixed perspective camera (pitch 35 deg)  |  - NO Room B (Corridor) or Room C (Core)|
|  - Solid 3D props with painted face shader  |  - NO narrative dialogue UI or ending   |
|  - Greybox testbed room (spawn_area.tscn)   |                                         |
+---------------------------------------------------------------------------------------+
```

You are inheriting a project with a **robust engine foundation** (networking, 3D locomotion, skeletal animation, fixed follow camera, custom shaders, and automated tests), but **zero gameplay mechanics**.

---

## 4. Key Architecture & File Relationships

### 4.1 Autoload Singleton: `NetworkManager`
- **File**: [scripts/network/network_manager.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/network/network_manager.gd)
- **Role**: Registered as global autoload `NetworkManager` in `project.godot`.
- **Key Fields**:
  - `state`: `State.IDLE`, `State.HOSTING`, `State.CONNECTING`, `State.CONNECTED`
  - `role`: `"past"` on Host, `"future"` on Guest
  - `guest_ready`: `bool` indicating client readiness
  - `in_game`: `bool` indicating active gameplay scene
- **Handshake Flow**:
  - Host binds port 7000 $\rightarrow$ Guest connects $\rightarrow$ `_register_client.rpc_id(1, PROTOCOL_VERSION)` $\rightarrow$ Host acknowledges via `_apply_lobby.rpc_id(guest_id)` $\rightarrow$ Guest requests ready $\rightarrow$ Host calls `start_game()` $\rightarrow$ Host broadcasts `_begin_game.rpc()` $\rightarrow$ Both peers load `scenes/world/spawn_area.tscn`.

### 4.2 The Active Gameplay Scene: `scenes/world/spawn_area.tscn`
- **Script**: [scripts/world/spawn_area.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/world/spawn_area.gd)
- **Node Tree**:
  - `WorldEnvironment`: Cool ambient light (`#d6e6ff`, energy $0.65$).
  - `CharacterKeyLight`: Directional light pitched at $(-40^\circ, -32^\circ, 0^\circ)$, energy $1.15$.
  - `Floor` (`lab_floor.gd`): $24.8 \times 15.6\text{ m}$ plane running `shaders/lab_floor.gdshader`. Sets tile grid and past/future albedo.
  - `Bounds`: `StaticBody3D` with low ($1.0\text{ m}$) perimeter walls on North, South, West, East.
  - `Actors`: Reusable furniture instances (`lab_prop.tscn`) and the player (`student_3d_player.tscn`).
  - `CameraRig` (`follow_camera.gd`): Maintains perspective `Camera3D` at $35^\circ$ downward pitch and smooths following.
  - `HUD`: CanvasLayer with header info, solo preview timeline toggle, and pause modal.

### 4.3 The Active Character Controller: `scenes/characters/student_3d_player.tscn`
- **Script**: [scripts/characters/student_3d_player.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/characters/student_3d_player.gd)
- **Model**: `Visual/Student` instantiating `assets/characters/student_3d/student.glb`.
- **Physics**: `CharacterBody3D` with cylinder collision ($r = 0.28\text{ m}, h = 0.4\text{ m}$).
- **Key Logic**:
  - Input vector from WASD/arrows is unprojected into ground basis of `view_camera`.
  - Velocity calculated with optional sprint (`run_multiplier = 1.55`).
  - Smooth rotation via `rotate_toward(..., delta * 12.0)`.
  - Duplicates `AnimationLibrary` in `_ready()` to isolate per-player animation state.
  - Actions (`interact`, `inspect`, `pick_up`, `put_down`) lock movement until clip finishes.

---

## 5. Non-Negotiable Invariants: WHAT MUST NOT BE BROKEN

When modifying or adding code, you must strictly respect these rules:

1. **Floor-Contact Root Convention ($Y = 0$)**:
   - All character scenes, furniture props, and room boundaries have their root node at floor level ($Y = 0$).
   - Collision shapes and visual meshes are offset upward from this anchor.
   - **Never shift scene roots away from ground level.**

2. **Fixed Perspective Camera**:
   - The game uses a `Camera3D` with **perspective projection**, a **fixed $35^\circ$ downward pitch**, and a **$48^\circ$ field of view**.
   - There are **no camera rotation or projection toggle controls for the player**.
   - Low room perimeter walls ($1.0\text{ m}$) exist specifically to prevent occluding this high-angle view.

3. **Strict Host-Authoritative Puzzle State**:
   - **Clients must NEVER mutate puzzle state optimistically.**
   - All puzzle actions must flow: `Client Request (RPC)` $\rightarrow$ `Host Validation` $\rightarrow$ `Host Canonical Mutation` $\rightarrow$ `Host Broadcast (RPC)` $\rightarrow$ `Both Clients Render`.
   - The host is Peer 1; clients are Peer $> 1$.

4. **Resource Duplication for Multi-Instance Isolation**:
   - When instantiating characters or props, materials and animation libraries must be duplicated (`.duplicate(true)`).
   - In Godot, imported GLBs share resource references across instances by default. If you do not duplicate them, tinting the Future character will inadvertently tint the Past character.

5. **GL Compatibility Constraints**:
   - The project uses `gl_compatibility`. Do not introduce Vulkan/Forward+ specific rendering features (e.g. SDFGI, volumetric fog, GPU compute shaders, decal nodes) without fallbacks.

---

## 6. Technical Traps & Broken Legacy Areas (DO NOT TOUCH)

1. **DO NOT attempt to use `scenes/characters/student_paper_rig.tscn` or `student_2d_player.tscn`**:
   - Commit `4a1144d` deleted the directional PNG atlases (`east_parts.png`, etc.).
   - These scripts will fail to compile due to missing preloaded assets. The 2D version is preserved in Git commit `244b42a` for historical reference only.
2. **DO NOT attempt to use `scenes/characters/student_model.tscn` or `student_player.tscn`**:
   - `assets/characters/student_v2.glb` was deleted in commit `4a1144d`.
   - The active 3D character is exclusively [scenes/characters/student_3d_player.tscn](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scenes/characters/student_3d_player.tscn).
3. **DO NOT run `tools/render_student_review.gd` with `--headless`**:
   - This script requires a display graphics device to capture subviewport textures. Use `tests/student_3d.gd` for automated headless testing.

---

## 7. How to Verify Your Work

Before declaring any task done, run these four non-destructive verification commands:

```powershell
# 1. Verify 3D Character Asset integrity & inverse bind matrices
python tests/student_3d_assets.py
# Expected: STUDENT 3D ASSETS: PASS

# 2. Verify Godot headless skeletal animation and action locking
& "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/student_3d.gd
# Expected: STUDENT 3D: PASS (0 failures; 77 animation clips)

# 3. Verify Headless Level Simulation & Physics Collisions
& "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/spawn_area.gd
# Expected: SPAWN AREA: PASS (0 failures)

# 4. Verify Multi-Process LAN Host/Join & Loopback Transitions
$env:GODOT_BIN = "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
python tests/run_lan_smoke.py
# Expected: busy: PASS, host: PASS, client: PASS
```

---

## 8. Immediate Next Implementation Task: TASK P0.1

When you are ready to begin writing code, **implement Task P0.1: The Host-Authoritative `PuzzleManager` Autoload**:

### Architectural Blueprints for Task P0.1:
1. Create `scripts/puzzles/puzzle_manager.gd`.
2. Register it as an Autoload named `PuzzleManager` in `project.godot`:
   ```ini
   [autoload]
   NetworkManager="*res://scripts/network/network_manager.gd"
   PuzzleManager="*res://scripts/puzzles/puzzle_manager.gd"
   ```
3. Implement the core state dictionary:
   ```gdscript
   extends Node

   signal puzzle_state_updated(puzzle_id: String, state: Dictionary)

   var puzzle_states: Dictionary = {
       "puzzle_01_frequency": {
           "solved": false,
           "past_frequency": 0.0,
           "target_frequency": 142.8,
           "power_restored": false
       },
       "puzzle_02_corridor": {
           "solved": false,
           "supports": [1, 1, 1], # Jack positions
           "target_supports": [2, 0, 3]
       }
   }
   var state_revision: int = 0

   # Client -> Host action submission
   @rpc("any_peer", "call_remote", "reliable")
   func request_puzzle_action(puzzle_id: String, action: String, payload: Variant) -> void:
       if not multiplayer.is_server():
           return
       var sender_id := multiplayer.get_remote_sender_id()
       if not _validate_action(sender_id, puzzle_id, action, payload):
           return
       _execute_action(puzzle_id, action, payload)
       state_revision += 1
       _broadcast_state.rpc(puzzle_id, puzzle_states[puzzle_id], state_revision)

   # Host -> All peers state broadcast
   @rpc("authority", "call_local", "reliable")
   func _broadcast_state(puzzle_id: String, new_state: Dictionary, revision: int) -> void:
       if revision <= state_revision and multiplayer.get_remote_sender_id() != 1:
           return
       state_revision = revision
       puzzle_states[puzzle_id] = new_state
       puzzle_state_updated.emit(puzzle_id, new_state)
   ```
4. Follow this with **Task P0.2** (`InteractableArea3D` proximity triggers) and **Task P0.3** (Connecting the Console in `spawn_area.tscn` to solve Puzzle 01).

You now possess everything required to carry **Past-Future** forward to a complete, stable, and award-winning Game Jam release!

