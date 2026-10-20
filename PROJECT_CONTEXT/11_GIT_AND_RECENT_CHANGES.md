# 11 GIT AND RECENT CHANGES: Branch, History & Evolution Audit

This document audits the Git repository state, working tree status, commit history, and architectural evolution of **Past-Future**.

---

## 1. Current Git Working Tree Status

- **Current Branch**: `main`
- **Tracking Branch**: `origin/main` (Up to date)
- **Remote URL**: `https://github.com/hussainhht/Past-Future.git`
- **Working Tree State**: Clean (`nothing to commit, working tree clean`).
- **HEAD Commit**: `303fc5bffd19212013e33497a857191180490f13`
- **Rule Verification**: No commits, branches, stashes, or Git state alterations were made during documentation generation.

---

## 2. Commit History Analysis

Below is the chronological sequence of commits recorded on the `main` branch:

```text
303fc5b (HEAD -> main, origin/main) Add tools for student character creation and editing
4a1144d fast
244b42a chore: checkpoint illustrated 2D student prototype
cea18ba docs: describe 3D prototype and current gameplay architecture
4661c77 test(game): cover character motion and LAN gameplay transitions
baac3b8 feat(game): add playable 3D lab and lobby-to-game flow
0292ee9 feat(character): add custom student model and articulated movement
7c6f5f1 feat(network): authorize game start and track active sessions
1fa0913 test(network): cover LAN connection lifecycle with real ENet peers
3054e79 feat(menu): add past-future title screen and LAN host-join flow
553e893 feat(network): add two-player ENet LAN lobby and ready state
0d2c874 docs: define game design and clarify LAN co-op requirements
d03b44b Update Game Design Document to Version 0.3 with revised visual direction...
4070117 first gddd
2391ab8 first commit
```

---

## 3. Detailed Chronology of Development Phases

### Phase 1: Conceptual Foundation & Initial GDD (`2391ab8` $\rightarrow$ `0d2c874`)
- **Key Commits**: `2391ab8`, `4070117`, `d03b44b`, `0d2c874`.
- **Milestones**:
  - Established project repository and initial Godot configuration.
  - Authored initial Game Design Document versions ($0.1$ through $0.3$).
  - Defined the two-timeline premise (18yo student vs 49yo professor) and asymmetric cooperation requirements for the Reboot CHECKPOINT Game Jam.

### Phase 2: Networking & Menu Foundation (`553e893` $\rightarrow$ `7c6f5f1`)
- **Key Commits**: `553e893`, `3054e79`, `1fa0913`, `7c6f5f1`.
- **Milestones**:
  - Built `NetworkManager` autoload (`scripts/network/network_manager.gd`) with ENet peer management on UDP 7000.
  - Implemented the title screen (`scenes/menu/main_menu.tscn`) and animated clock backdrop (`scripts/menu/temporal_backdrop.gd`).
  - Added LAN lobby UI with IP display, role assignment, and ready confirmation.
  - Wrote multi-process headless verification tests (`tests/lan_peer.gd` and `tests/run_lan_smoke.py`).

### Phase 3: The 3D Greybox Environment (`baac3b8` $\rightarrow$ `4661c77`)
- **Key Commits**: `0292ee9`, `baac3b8`, `4661c77`, `cea18ba`.
- **Milestones**:
  - Created `spawn_area.tscn` greybox room with low perimeter walls and procedural tile floor shader.
  - Developed reusable 3D furniture models (`table_visual.tscn`, `cabinet_visual.tscn`, `console_visual.tscn`) with painted lambertian face shading.
  - Added perspective follow camera (`follow_camera.gd`) with fixed $35^\circ$ downward pitch.
  - Implemented the initial articulated 3D student model (`student_v2.glb`) and procedural walking controller (`student_player.gd`).

### Phase 4: The 2D Checkpoint & Rapid Migration (`244b42a` $\rightarrow$ `4a1144d`)
- **Key Commits**: `244b42a`, `4a1144d`.
- **Milestones**:
  - **Commit `244b42a`**: Checkpointed an illustrated 8-direction 2D paper cutout prototype with procedural joints (`student_paper_rig.gd`).
  - **Commit `4a1144d` ("fast")**: Major architectural pivot. Switched the primary gameplay character to a fully skinned 3D mesh (`student.glb`) driven by 77 imported KayKit animation clips (`student_3d_player.gd`).
  - **Critical Asset Cleanout**: In commit `4a1144d`, all 2D directional PNG atlases and the legacy `student_v2.glb` model were deleted from the tree to save disk space, deprecating the 2D prototype and earlier articulated 3D character.

### Phase 5: Skinned Character Tooling & Review Pipeline (`303fc5b`)
- **Key Commit**: `303fc5b` ("Add tools for student character creation and editing").
- **Milestones**:
  - Added `tools/build_student_kaykit.py` for procedural mesh and skin weight authoring.
  - Added `tools/student_rig.py` for KayKit bone proportion retargeting.
  - Added `tools/ground_student_clips.py` for 60 Hz skinned surface floor clearance baking.
  - Added `tools/student_blender.py` for editable Blender file creation (`student.blend`) and Cycles studio renders.
  - Added `tests/student_3d_assets.py` and `tests/student_3d.gd` automated verification suites.
  - Created [assets/characters/student_3d/manifest.json](file:///c:/Users/hanwd/OneDrive/Desktop/past-future/assets/characters/student_3d/manifest.json) recording full geometry provenance, hashes, and retarget curves.

---

## 4. Worktree State Protection Rules

When continuing development on this repository:
1. **Preserve Clean Git State**: Do not commit partial or broken files.
2. **Do Not Reintroduce Deleted 2D PNGs to Active Builds**: Keep the active 3D character pipeline intact. If the 2D prototype is needed for historical review, refer to commit `244b42a`.
3. **Respect `.gitignore` Conventions**: The `.gitignore` file correctly ignores `.godot/`, `.venv/`, `__pycache__/`, `*.blend1`, and `export_presets.cfg`. Do not remove these rules.

