# 09 BUGS AND TECHNICAL DEBT: Confirmed Issues, Risks & Architecture Debt

This document catalogs confirmed software bugs, broken references, architectural risks, and technical debt present in the repository, along with recommended solutions.

---

## 1. Confirmed Bugs & Broken References

### Bug 01: Missing 2D Character Sprite Atlases
- **Severity**: **Medium** (Breaks legacy test and non-active scenes)
- **Status**: **CONFIRMED**
- **Affected Files**:
  - [scripts/characters/student_paper_rig.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/characters/student_paper_rig.gd#L19-L26)
  - [scenes/characters/student_paper_rig.tscn](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scenes/characters/student_paper_rig.tscn)
  - [scenes/characters/student_2d_player.tscn](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scenes/characters/student_2d_player.tscn)
  - [scenes/characters/student_animation_studio.tscn](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scenes/characters/student_animation_studio.tscn)
  - [tests/student_2d.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/tests/student_2d.gd)
- **Evidence**:
  Running `godot --headless --path . --script res://tests/student_2d.gd` fails immediately with parse errors:
  ```text
  SCRIPT ERROR: Parse Error: Preload file "res://assets/characters/student_2d/east_parts.png" does not exist.
     at: GDScript::reload (res://scripts/characters/student_paper_rig.gd:20)
  ```
  Git log inspection reveals commit `4a1144d` ("fast") deleted `assets/characters/student_2d/*_parts.png` to reduce repository size when switching to the 3D model.
- **Impact**: Any developer or CI system running all tests in `tests/` will encounter a fatal script error.
- **Recommended Fix**:
  Either:
  1. Restore the PNG assets from commit `244b42a` into `assets/characters/student_2d/`.
  2. Or, wrap the preloads in `load()` calls behind existence checks, or deprecate/move the legacy 2D scripts and test into an `archive/` folder excluded from automated test passes.

---

### Bug 02: Missing Legacy 3D Model (`student_v2.glb`)
- **Severity**: **Low / Medium** (Pollutes editor dependency tree)
- **Status**: **CONFIRMED**
- **Affected Files**:
  - [scenes/characters/student_model.tscn](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scenes/characters/student_model.tscn#L3)
  - [scenes/characters/student_player.tscn](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scenes/characters/student_player.tscn#L4)
- **Evidence**:
  `student_model.tscn` contains:
  ```gdscript
  [ext_resource type="PackedScene" path="res://assets/characters/student_v2.glb" id="1"]
  ```
  `assets/characters/student_v2.glb` was deleted in commit `4a1144d`. Opening `scenes/characters/student_model.tscn` or `scenes/characters/student_player.tscn` in Godot editor throws a missing dependency error dialog.
- **Impact**: Confusing for developers opening scenes; broken scene references in Godot's filesystem cache.
- **Recommended Fix**:
  Run `python tools/build_student_model.py` to regenerate `student_v2.glb`, or safely delete `student_model.tscn` and `student_player.tscn` since the project now officially uses `student_3d_player.tscn`.

---

### Bug 03: Hardcoded Input Keys in Player Controller
- **Severity**: **Medium** (Accessibility & Input Customization Debt)
- **Status**: **CONFIRMED**
- **Affected Files**:
  - [scripts/characters/student_3d_player.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/characters/student_3d_player.gd#L117-L121)
  - [scripts/characters/student_3d_player.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/characters/student_3d_player.gd#L139)
  - [project.godot](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/project.godot#L36-L53)
- **Evidence**:
  `project.godot` defines input actions for `move_left`, `move_right`, `move_up`, `move_down`, but **defines no action for sprint or interaction**. In `student_3d_player.gd`:
  ```gdscript
  var running := controls_enabled and not carrying and Input.is_physical_key_pressed(KEY_SHIFT)
  # ...
  match event.physical_keycode:
      KEY_F: action = "interact"
      KEY_I: action = "inspect"
      KEY_E: action = "put_down" if carrying else "pick_up"
  ```
- **Impact**:
  - Players cannot rebind sprint, interact, or inspect keys.
  - Gamepad controllers cannot trigger sprint or interactions.
  - Precludes implementing split-screen input routing (where Player 2 needs arrow keys + Enter).
- **Recommended Fix**:
  Register `sprint`, `interact`, `inspect`, and `pick_up` as proper actions in `project.godot` under `[input]`, and query them via `Input.is_action_pressed()` and `event.is_action_pressed()`.

---

## 2. Technical Risks & Architecture Concerns

### Risk 01: Complete Absence of Puzzle Authority Layer
- **Severity**: **HIGH (Game Jam Blocker)**
- **Status**: **POTENTIAL / ARCHITECTURAL DEBT**
- **Affected Files**: GDD Section 9 & 10 (Not yet created)
- **Description**:
  The game lacks any code representation of game progression, puzzle states, or causality events. Without a central `PuzzleManager` on the host, implementing multiplayer puzzles risks desynchronization, duplicate unlocks, and race conditions.
- **Recommended Mitigation**:
  Implement `scripts/puzzles/puzzle_manager.gd` as an Autoload. Ensure all puzzle changes flow strictly through Host validation (`request_action` $\rightarrow$ `apply_puzzle_state`). Never allow client-side optimistic mutations.

---

### Risk 02: High Vertex Density on Active Character
- **Severity**: **Low / Performance Risk**
- **Status**: **CONFIRMED ARCHITECTURAL CONCERN**
- **Affected Files**: [assets/characters/student_3d/student.glb](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/assets/characters/student_3d/student.glb)
- **Description**:
  The student character contains **$71,806$ vertices** and **$142,519$ triangles**. While running at $>60\text{ FPS}$ on dedicated GPUs, this high poly count on a stylized model with no LODs (Level of Detail) could cause frame drops on older integrated GPUs (Intel UHD graphics) during Game Jam judging.
- **Recommended Mitigation**:
  In a post-jam or polish pass, introduce mesh decimation in `tools/build_student_kaykit.py` or generate LOD0/LOD1 variants. For the jam, ensure the viewport size override remains at $1280 \times 720$ for smooth performance.

---

### Risk 03: WAN NAT Traversal / Tailscale Judging Dependency
- **Severity**: **HIGH (Judging Access Risk)**
- **Status**: **OPERATIONAL RISK**
- **Affected Files**: [scripts/network/network_manager.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/scripts/network/network_manager.gd), GDD Section 9
- **Description**:
  The multiplayer transport uses raw ENet UDP. Without a dedicated relay or STUN/TURN punchthrough server, remote play requires both players to be connected to the same virtual mesh network (Tailscale). If game jam judges cannot or will not install Tailscale, online multiplayer cannot be evaluated.
- **Recommended Mitigation**:
  **Build the Same-PC Split-Screen mode (P0 Task)**. An offline split-screen fallback on a single computer guarantees that judges can experience the full cooperative game regardless of their network security or software restrictions.

---

### Risk 04: Headless CI Failure on Render Review Script
- **Severity**: **Low (Tooling Debt)**
- **Status**: **CONFIRMED**
- **Affected Files**: [tools/render_student_review.gd](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/tools/render_student_review.gd)
- **Description**:
  `render_student_review.gd` relies on `RenderingServer.force_draw()` and active SubViewports to capture character PNGs. Running it with `--headless` results in black frames or crashes.
- **Recommended Mitigation**:
  Keep review render scripts isolated from headless CI passes, as documented in `assets/characters/student_3d/README.md`. Use `tests/student_3d.gd` for automated headless validation.

