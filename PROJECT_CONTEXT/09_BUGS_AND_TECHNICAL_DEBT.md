# 09 BUGS AND TECHNICAL DEBT: Confirmed Issues, Risks & Architecture Debt

This document catalogs confirmed software bugs, test regressions, architectural risks, and technical debt present in **Past-Future**, along with verified evidence and recommended fixes.

---

## 1. Issue Status Classification Summary

- **FIXED**: Previously reported issue has been completely resolved in the active codebase.
- **OPEN**: Confirmed active issue verified during empirical repository audit.
- **PARTIALLY FIXED**: Progress has been made, but secondary edge cases or tests remain affected.
- **UNVERIFIED**: Reported condition requires external hardware or multi-computer testing.
- **DEFERRED**: Intentionally postponed or retained as historical reference; does not block the active game.

---

## 2. Active Confirmed Issues (OPEN)

### Issue 01: Child-Count Test Assertion Discrepancy in `game_flow_system.gd`
- **Severity**: **Medium** (Automated Test Regression)
- **Status**: **OPEN**
- **Affected Files**: [tests/game_flow_system.gd](../tests/game_flow_system.gd#L277)
- **Evidence**:
  Running `python tests/run_game_flow_tests.py` fails with:
  ```text
  ERROR: FAILED: Only the autoloads and the room are under root, got 6
     at: check (res://tests/game_flow_system.gd:40)
  ```
- **Root Cause**:
  When `game_flow_system.gd` was originally authored, `project.godot` contained 4 Autoloads (`NetworkManager`, `PuzzleManager`, `GameFlowManager`, `JournalManager`). In commit `68e6272`, `CinematicTransitionManager` was registered as a 5th Autoload. Line 277 asserts `root.get_child_count() == 5` (expecting 4 autoloads + 1 room scene). With 5 autoloads present, `root.get_child_count()` is now 6.
- **Impact**: `run_game_flow_tests.py` reports 10 failures during transition cleanup checks despite room flow working correctly in gameplay.
- **Recommended Fix**:
  Update `tests/game_flow_system.gd` line 277 (and related trip assertions) to check for 6 children under root (5 autoload singletons + 1 active room), or query room validity dynamically.

---

### Issue 02: LAN Timeout & Missing `%TimelineButton` in `maintenance_peer.gd`
- **Severity**: **Medium** (Multi-Process LAN Test Failure)
- **Status**: **OPEN**
- **Affected Files**: [tests/maintenance_peer.gd](../tests/maintenance_peer.gd#L52), [scripts/gameplay/laboratory_gameplay.gd](../scripts/gameplay/laboratory_gameplay.gd#L211)
- **Evidence**:
  Running `python tests/run_maintenance_tests.py` passes all single-scene checks (`maintenance_rules.gd`, `maintenance_corridor.gd`, `temporal_ghost.gd`, `text_layout.gd`), but fails during `lan(folder)`:
  ```text
  SCRIPT ERROR: Trying to call an async function without "await".
     at: run (res://tests/maintenance_peer.gd:52)
  ERROR: Node not found: "%TimelineButton" (relative to "/root/SpawnArea").
     at: _sync_controls (res://scripts/gameplay/laboratory_gameplay.gd:211)
  ```
- **Root Cause**:
  1. `maintenance_peer.gd` line 14 declares `func wait_for(...) -> bool:`. Because it uses `await process_frame`, GDScript treats it as an async coroutine. Calling it on line 52 inside an unawaited block triggers a GDScript engine warning.
  2. The test times out waiting for the radio prerequisite because Signal Lab now requires device inspector interaction steps.
  3. When the test fails and cleans up the dialogue box, `laboratory_gameplay.gd` line 211 calls `room.get_node("%TimelineButton")`. In recent theme refactors of `spawn_area.tscn`, `%TimelineButton` node hierarchy was modified, throwing a null reference error.
- **Impact**: Offline Level 02 gameplay and rules work cleanly; multi-process loopback LAN runner for Level 02 exits with failure.
- **Recommended Fix**:
  1. Add `await` to line 52 in `tests/maintenance_peer.gd`.
  2. Update `laboratory_gameplay.gd:211` to use `room.get_node_or_null("%TimelineButton")` with null guard.

---

### Issue 03: Unchecked Null `current_scene` in `lan_peer.gd`
- **Severity**: **Low** (Harmless Engine Warning Causing Test Failure)
- **Status**: **OPEN**
- **Affected Files**: [tests/lan_peer.gd](../tests/lan_peer.gd#L127)
- **Evidence**:
  Running `python tests/run_lan_smoke.py` reports:
  ```text
  SCRIPT ERROR: Invalid access to property or key 'scene_file_path' on a base object of type 'null instance'.
     at: <anonymous lambda> (res://tests/lan_peer.gd:127)
  ```
- **Root Cause**:
  After disconnecting, `current_scene._return_to_menu()` initiates asynchronous scene unloading. In the lambda on line 127:
  ```gdscript
  if not await wait_for(func() -> bool: return current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn", ...):
  ```
  `current_scene` is temporarily `null` for one frame during scene loading, throwing an engine script error that fails `run_lan_smoke.py`.
- **Impact**: The test actually passes functionally, but `run_lan_smoke.py` catches the `SCRIPT ERROR` in stderr and exits with error.
- **Recommended Fix**:
  Guard with `is_instance_valid(current_scene)`:
  ```gdscript
  return is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn"
  ```

---

### Issue 04: `run_cinematic_tests.py` Requires `DISPLAY` on Windows
- **Severity**: **Low** (Tooling / Test Harness Platform Assumption)
- **Status**: **OPEN**
- **Affected Files**: [tests/run_cinematic_tests.py](../tests/run_cinematic_tests.py#L27)
- **Evidence**:
  Running `python tests/run_cinematic_tests.py` directly on Windows without `$env:DISPLAY` throws:
  ```text
  FileNotFoundError: [WinError 2] The system cannot find the file specified ('xvfb-run')
  ```
- **Root Cause**:
  Line 27 defaults to `["xvfb-run", "-a", "-s", "-screen 0 1600x900x24"]` if `DISPLAY` is not found in `os.environ`, assuming a Linux environment.
- **Impact**: Fails when executed out-of-the-box on Windows unless `$env:DISPLAY = "1"` is set.
- **Workaround / Fix**:
  On Windows, set `$env:DISPLAY = "1"` before running, or update `run_cinematic_tests.py` to check `os.name != "nt"` before invoking `xvfb-run`.

---

### Issue 05: High Vertex Density on Active Characters
- **Severity**: **Low** (Performance Risk for Low-End Hardware)
- **Status**: **OPEN**
- **Affected Files**: [assets/characters/student_3d/student.glb](../assets/characters/student_3d/student.glb), [assets/characters/professor_3d/professor.glb](../assets/characters/professor_3d/professor.glb)
- **Description**:
  The Student model contains **$90,881$ vertices**; the Professor model contains **$113,143$ vertices**. While running at $\ge 60\text{ FPS}$ on modern dedicated GPUs (D3D12/GL Compatibility), this vertex density could cause frame rate dips on low-end integrated laptop GPUs (e.g. older Intel UHD) without Level of Detail (LOD) meshes.
- **Recommended Mitigation**:
  Ensure window size override remains at $1280 \times 720$ for judging. Author decimation passes in `tools/build_student_kaykit.py` and `tools/build_professor.py` post-jam.

---

### Issue 06: Missing Same-PC Split-Screen Mode
- **Severity**: **HIGH (Game Jam Judging Access Risk)**
- **Status**: **OPEN**
- **Affected Files**: [scenes/menu/main_menu.tscn](../scenes/menu/main_menu.tscn)
- **Description**:
  The GDD specifies an offline split-screen fallback for two players on one computer. Currently, the menu button displays `SAME-PC SPLIT-SCREEN / COMING SOON` with `disabled = true`. If judges are on separate networks and unable to configure Tailscale VPN, online play cannot be evaluated.
- **Recommended Fix**:
  Implement Task P0: Dual `SubViewportContainer` rig with split input routing (Player 1 = WASD + F; Player 2 = Arrows + Enter).

---

## 3. Resolved Issues (FIXED)

| Issue | Original Severity | Resolution Evidence |
|---|---|---|
| **Absence of Puzzle Authority Layer** | **HIGH** | **FIXED**. `PuzzleManager` autoload (`scripts/puzzles/puzzle_manager.gd`) implemented with full state dictionary, monotonic revisions, RPC replication, and validated in `tests/run_puzzle_tests.py` (**PASS: 131 checks**). |
| **Missing Interaction Architecture** | **HIGH** | **FIXED**. Spatial interaction system (`Interactable3D`, `InteractionDetector`, `InteractionController`, `DeviceInspector3D`) implemented and verified in `tests/interaction_system.gd` (**PASS: 54 checks**). |
| **Missing Professor Model** | **HIGH** | **FIXED**. Fully authored 3D Professor character (`assets/characters/professor_3d/professor.glb`, 23 joints, 77 clips, formal coat, mature face) implemented and verified in `tests/student_3d_assets.py --character professor`. |
| **Hardcoded Input Keys in Controller** | **Medium** | **FIXED**. InputMap actions (`move_*`, `interact`, `inspect`, `use_item`, `sprint`, `journal`, `cancel`, `pause`) registered in `project.godot`; `InputManager` supports DualSense/Xbox gamepads with dynamic glyphs and haptics. |
| **Missing Room 02 & Room 03** | **HIGH** | **FIXED**. Level 02 (`maintenance_corridor.tscn`) and Level 03 (`temporal_core.tscn`) fully built, playable, and connected with tests passing. |

---

## 4. Deferred Historical Debt (DEFERRED)

### Legacy 2D Paper Rig (`student_paper_rig.gd`, `tests/student_2d.gd`)
- **Status**: **DEFERRED**
- Directional PNG atlases were deleted in commit `4a1144d` when migrating to the 3D pipeline. Running `student_2d.gd` fails on preload. Preserved in Git commit `244b42a` for historical reference only.

### Legacy Articulated 3D Model (`student_model.tscn`, `student_player.gd`)
- **Status**: **DEFERRED**
- `assets/characters/student_v2.glb` was deleted in commit `4a1144d`. Fully superseded by `student_3d_player.tscn`.
