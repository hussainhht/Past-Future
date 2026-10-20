# 08 DEVELOPMENT PROGRESS: Evidence-Based Audit & Status

This document provides a realistic, evidence-based audit of development progress across all systems, features, and assets in **Past-Future**.

---

## 1. Feature Progress Matrix

Status definitions:
- **COMPLETE**: Fully implemented, tested, and verified working.
- **PARTIAL**: Implemented in part; functional but missing key components or polish.
- **NOT STARTED**: Designed or planned, but zero functional code exists in the active game.
- **BLOCKED**: Implementation cannot function due to missing assets, dependencies, or compile errors.
- **UNVERIFIED**: Code exists, but has not been verified under real hardware/network conditions.

| Feature / Subsystem | Status | Implemented Functionality | Verification Status | Missing Work | Relevant Files |
|---|---|---|---|---|---|
| **Main Menu & Settings** | **COMPLETE** | Full UI with Host/Join, Settings (Fullscreen, Motion), Credits, Quit confirmation, dynamic styling. | **PASS** (Tested in Godot) | Hook up sound volume sliders when audio is added. | `scenes/menu/main_menu.tscn`, `scripts/menu/main_menu.gd` |
| **ENet LAN Networking** | **COMPLETE** | Host server (Past), Join client (Future), version check ($v2$), ready state handshake, host game start authorization, disconnect cleanup. | **PASS** (Verified via `tests/run_lan_smoke.py`) | Physical two-computer Wi-Fi validation (tested on loopback). | `scripts/network/network_manager.gd`, `tests/lan_peer.gd` |
| **Active 3D Character** | **COMPLETE** | $71\text{k}$ vertex skinned mesh, 23 bones, proportion retarget, runtime material duplication, independent player tints. | **PASS** (Verified via `tests/student_3d.gd` & `student_3d_assets.py`) | Authoring distinct older Professor model. | `assets/characters/student_3d/student.glb`, `scripts/characters/student_3d_player.gd` |
| **Locomotion & Physics** | **COMPLETE** | Camera-relative 8-direction movement, WASD/arrow merging, shift sprint ($1.55\times$), smooth visual rotation, Jolt 3D physics. | **PASS** (Verified via `tests/spawn_area.gd`) | Interaction velocity damping polish. | `scripts/characters/student_3d_player.gd`, `scenes/characters/student_3d_player.tscn` |
| **Animation System** | **COMPLETE** | 77 KayKit animation clips, dynamic looping flags, one-shot action locking, hand prop socket (`handslot.l`). | **PASS** (77/77 clips verified in `tests/student_3d.gd`) | Additional contextual animation triggers (typing, dial turning). | `scripts/characters/student_3d_player.gd`, `scenes/characters/student_3d_studio.tscn` |
| **Fixed Follow Camera** | **COMPLETE** | Fixed $35^\circ$ downward pitch, $48^\circ$ FOV, perspective projection, asymptotic smoothing, forward look-ahead ($2.0\text{ m}$). | **PASS** (Verified via `tests/spawn_area.gd`) | Wall occlusion fading / dither. | `scripts/world/follow_camera.gd` |
| **3D Furniture & Shaders** | **COMPLETE** | Composite 3D box meshes for tables, cabinets, and consoles; unshaded lambertian normal shader; past/future color matrices. | **PASS** (Verified via `tests/spawn_area.gd`) | Interactive UI screens on console monitors. | `scenes/props/lab_prop.tscn`, `shaders/painted_prop.gdshader`, `scripts/world/lab_prop.gd` |
| **Signal Lab Greybox** | **COMPLETE** | $24.8 \times 15.6\text{ m}$ room, low collision boundaries, procedural tile floor shader, spawn point, pause modal. | **PASS** (Verified via `tests/spawn_area.gd`) | Security exit door, interactive equipment, clutter props. | `scenes/world/spawn_area.tscn`, `scripts/world/spawn_area.gd`, `shaders/lab_floor.gdshader` |
| **Character Review Studio** | **COMPLETE** | In-game studio (F2), isolated 3D viewport, 77-clip selector, 4 angle presets, rotation slider, pause, timeline scrubbing, speed control. | **PASS** (Verified in engine & test suite) | None (fully feature-complete). | `scenes/characters/student_3d_studio.tscn`, `scripts/characters/student_3d_studio.gd` |
| **Offline Solo Preview** | **COMPLETE** | "EXPLORE THE LAB" mode runs without network; "VIEW FUTURE" button toggles floor, props, and jacket tints live. | **PASS** (Verified via `tests/spawn_area.gd`) | None. | `scripts/world/spawn_area.gd` |
| **The Professor Character** | **NOT STARTED** | None. Reuses Student 3D model with cyan jacket tint. | N/A | Full model sculpt/mesh authoring, mature face, formal coat. | GDD Section 3 |
| **Puzzle Authority Manager** | **NOT STARTED** | None. No central state dictionary, revision tracker, or validation RPCs exist in code. | N/A | Implement `scripts/puzzles/puzzle_manager.gd` autoload. | GDD Section 9 |
| **Interaction Triggers** | **NOT STARTED** | Keys F/I/E trigger dummy animations in empty space; no `Area3D` proximity detection or prompt UI. | N/A | Build `InteractableArea3D` and player interaction raycast/sphere. | GDD Section 4 |
| **Puzzle 01 (Lost Frequency)**| **NOT STARTED** | None. Communication array cannot be interacted with. | N/A | Console frequency input, log reader, network synchronization. | GDD Section 8 |
| **Puzzle 02 (Broken Corridor)**| **NOT STARTED** | None. Maintenance Corridor scene does not exist. | N/A | Build Corridor room, 3 support jacks, dynamic debris ramp. | GDD Section 8 |
| **Puzzle 03 (Temporal Anchor)**| **NOT STARTED** | None. Temporal Core scene does not exist. | N/A | Build Core room, reactor pedestal, 90s timer, sync logic. | GDD Section 8 |
| **Same-PC Split-Screen** | **NOT STARTED** | Button in menu exists but is disabled; no split viewport setup exists. | N/A | Dual `SubViewportContainer` rig, separate input routing. | GDD Section 9 & 10 |
| **Tailscale Remote WAN** | **UNVERIFIED** | NetworkManager supports arbitrary IP connection on port 7000. | **UNVERIFIED** (Only tested on loopback) | Real multi-network testing over Tailscale VPN. | GDD Section 9 |
| **Legacy 2D Student** | **BLOCKED** | Paper rig code and scenes exist, but PNG atlas assets were deleted in commit `4a1144d`. | **FAIL** (Parse error on preload) | Restore PNGs from `244b42a` or isolate/remove scripts. | `scripts/characters/student_paper_rig.gd`, `tests/student_2d.gd` |
| **Legacy Articulated 3D** | **BLOCKED** | Procedural builder exists, but `student_v2.glb` was deleted in commit `4a1144d`. | **FAIL** (Missing resource dependency) | Regenerate model or deprecate legacy scenes. | `scenes/characters/student_model.tscn`, `tools/build_student_model.py` |

---

## 2. Summary of Accomplishments

To date, the project has established an **exceptional technical and visual foundation**:
1. **Proprietary 3D Skinned Character Pipeline**: Rather than relying on generic placeholder cubes, the team created a complete procedural mesh generator (`build_student_kaykit.py`), mapped it onto the standard KayKit skeleton, verified zero-distortion bind matrices, resolved floor clipping via automated contact baking, and integrated all 77 animation clips into a responsive character controller.
2. **Robust LAN Multiplayer Core**: Implemented a reliable ENet host-client handshake on UDP 7000 that cleanly handles client registration, role assignment (Past vs. Future), host-confirmed ready states, synchronized scene launching, and graceful disconnect recovery.
3. **Distinct Artistic Identity**: Authored procedural unshaded shaders with normal-based lambertian face lighting, procedural tile grids, and paired Past/Future color palettes that give the 3D greybox an authored low-poly aesthetic without texture map overhead.
4. **Comprehensive Test Automation**: Automated headless verification suites for character bone transforms, 77 animation clips, camera projection, physics collision boundaries, and multi-process LAN connections.

---

## 3. The Unfinished Gap

Despite the strong engine foundation, **Past-Future is not yet a playable puzzle game**:
- **0 out of 3 puzzles are implemented**.
- There is **no interaction system**; players cannot interact with furniture, read clues, or trigger events.
- There is **no authoritative puzzle manager**; game state cannot be synchronized across peers.
- Only **1 out of 3 rooms exists** (`spawn_area.tscn`).
- **Same-PC split-screen is not built**, leaving the game dependent on two computers or virtual networking.

Closing this gap constitutes the immediate roadmap for the Game Jam.

