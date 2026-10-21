# 06 SCENES AND LEVELS: Environments, Props & Level Architecture

This document catalogs all Godot scenes (`.tscn`), playable room layouts, physical boundaries, interactive equipment, and level progression flows in **Past-Future**.

---

## 1. Complete Scene Inventory

### 1.1 Menus & Global Overlays
| Scene Path | Root Node | Script / Controller | Description & State |
|---|---|---|---|
| [scenes/menu/main_menu.tscn](../scenes/menu/main_menu.tscn) | `Control` | [main_menu.gd](../scripts/menu/main_menu.gd) | **ACTIVE**. Title screen, play mode selectors, ENet LAN lobby, settings, credits, and exit confirmation. |
| [scenes/ui/settings_overlay.tscn](../scenes/ui/settings_overlay.tscn) | `Control` | [settings_overlay.gd](../scripts/ui/settings_overlay.gd) | **ACTIVE**. Shared settings modal (fullscreen, reduced motion, master/sfx/ui/ambience/music volume sliders). |
| [scenes/game_flow/transition_overlay.tscn](../scenes/game_flow/transition_overlay.tscn) | `CanvasLayer` | [transition_overlay.gd](../scripts/game_flow/transition_overlay.gd) | **ACTIVE**. Layer 100 screen fade overlay used by `GameFlowManager` during room transitions. |
| [scenes/cinematic/cinematic_transition.tscn](../scenes/cinematic/cinematic_transition.tscn) | `CanvasLayer` | [cinematic_transition.gd](../scripts/cinematic/cinematic_transition.gd) | **ACTIVE**. Layer 40 cinematic room introduction title card overlay. |
| [scenes/dialogue/dialogue_box.tscn](../scenes/dialogue/dialogue_box.tscn) | `Control` | [dialogue_box.gd](../scripts/dialogue/dialogue_box.gd) | **ACTIVE**. Dialogue overlay with portrait badges, typewriter text, and click/key advance. |
| [scenes/journal/journal_ui.tscn](../scenes/journal/journal_ui.tscn) | `CanvasLayer` | [journal_ui.gd](../scripts/journal/journal_ui.gd) | **ACTIVE**. Layer 90 investigation journal (Student Notebook vs. Professor DataPad). |
| [scenes/ui/interaction_prompt.tscn](../scenes/ui/interaction_prompt.tscn) | `Control` | [interaction_prompt.gd](../scripts/ui/interaction_prompt.gd) | **ACTIVE**. Contextual interaction prompt widget with dynamic controller glyphs. |

### 1.2 Playable Levels
| Scene Path | Root Node | Script / Controller | Description & State |
|---|---|---|---|
| [scenes/world/spawn_area.tscn](../scenes/world/spawn_area.tscn) | `Node3D` | [spawn_area.gd](../scripts/world/spawn_area.gd) | **ACTIVE (Room 01)**. Signal Laboratory: starting area, radio acquisition, frequency puzzle, and exit door. |
| [scenes/world/maintenance_corridor.tscn](../scenes/world/maintenance_corridor.tscn) | `Node3D` | [maintenance_corridor.gd](../scripts/world/maintenance_corridor.gd) | **ACTIVE (Room 02)**. Maintenance Corridor: service loop, battery crank, dynamic support bridge, archive code 3142. |
| [scenes/rooms/temporal_core.tscn](../scenes/rooms/temporal_core.tscn) | `Node3D` | [temporal_core.gd](../scripts/level3/temporal_core.gd) | **ACTIVE (Room 03)**. The Final Fracture: 150s reactor challenge, coils, anchor alignment, phase switch, Stage C endings. |

### 1.3 Characters & Animation Studios
| Scene Path | Root Node | Script / Controller | Description & State |
|---|---|---|---|
| [scenes/characters/student_3d_player.tscn](../scenes/characters/student_3d_player.tscn) | `CharacterBody3D` | [student_3d_player.gd](../scripts/characters/student_3d_player.gd) | **ACTIVE**. Playable 18yo Student model with KayKit animations. |
| [scenes/characters/professor_3d_player.tscn](../scenes/characters/professor_3d_player.tscn) | `CharacterBody3D` | [student_3d_player.gd](../scripts/characters/student_3d_player.gd) | **ACTIVE**. Playable 49yo Professor model with KayKit animations. |
| [scenes/characters/student_3d_studio.tscn](../scenes/characters/student_3d_studio.tscn) | `Control` | [student_3d_studio.gd](../scripts/characters/student_3d_studio.gd) | **ACTIVE**. In-game animation review studio for Student model (F2). |
| [scenes/characters/professor_3d_studio.tscn](../scenes/characters/professor_3d_studio.tscn) | `Control` | [student_3d_studio.gd](../scripts/characters/student_3d_studio.gd) | **ACTIVE**. In-game animation review studio for Professor model. |

### 1.4 Interactive Environment Props & Audio
| Scene Path | Root Node | Script / Controller | Description & State |
|---|---|---|---|
| [scenes/environment/rooms/signal_lab.tscn](../scenes/environment/rooms/signal_lab.tscn) | `Node3D` | None | Assembled 3D Signal Laboratory room geometry and furniture. |
| [scenes/environment/rooms/maintenance_layout.tscn](../scenes/environment/rooms/maintenance_layout.tscn) | `Node3D` | None | Assembled 3D Maintenance Corridor industrial layout and stations. |
| [scenes/environment/effects/temporal_rift.tscn](../scenes/environment/effects/temporal_rift.tscn) | `Node3D` | [temporal_rift.gd](../scripts/environment/temporal_rift.gd) | Animated temporal distortion rift with particle energy. |
| [scenes/environment/interactive/console_terminal.tscn](../scenes/environment/interactive/console_terminal.tscn) | `StaticBody3D` | None | Interactive scientific terminal stand with inspection target. |
| [scenes/environment/interactive/security_door.tscn](../scenes/environment/interactive/security_door.tscn) | `Node3D` | None | Electronic sliding security exit door between rooms. |
| [scenes/environment/interactive/radio_pickup_past.tscn](../scenes/environment/interactive/radio_pickup_past.tscn) | `Node3D` | None | Past radio transceiver equipment pickup station. |
| [scenes/environment/interactive/radio_pickup_future.tscn](../scenes/environment/interactive/radio_pickup_future.tscn) | `Node3D` | None | Future radio transceiver equipment pickup station. |
| [scenes/environment/interactive/research_notebook.tscn](../scenes/environment/interactive/research_notebook.tscn) | `Node3D` | None | Student research notebook evidence pickup. |
| [scenes/environment/interactive/lab_memo.tscn](../scenes/environment/interactive/lab_memo.tscn) | `Node3D` | None | Wall memo and document inspection target. |
| [scenes/environment/interactive/door_keypad.tscn](../scenes/environment/interactive/door_keypad.tscn) | `StaticBody3D` | None | 3D numeric keypad station for access codes. |
| [scenes/environment/interactive/junction_box.tscn](../scenes/environment/interactive/junction_box.tscn) | `StaticBody3D` | None | Electrical breaker junction box with switches. |
| [scenes/props/lab_prop.tscn](../scenes/props/lab_prop.tscn) | `StaticBody3D` | [lab_prop.gd](../scripts/world/lab_prop.gd) | Modular prop base: footprint collision + dynamic visual mesh. |
| [scenes/props/table_visual.tscn](../scenes/props/table_visual.tscn) | `Node3D` | None | 3D painted workbench model. |
| [scenes/props/cabinet_visual.tscn](../scenes/props/cabinet_visual.tscn) | `Node3D` | None | 3D painted storage cabinet model. |
| [scenes/props/console_visual.tscn](../scenes/props/console_visual.tscn) | `Node3D` | None | 3D painted scientific computer console model. |
| [scenes/audio/audio_system.tscn](../scenes/audio/audio_system.tscn) | `Node` | [audio_director.gd](../scripts/audio/audio_director.gd) | Audio subsystem: 2D/3D audio poolers and ambient controller. |
| [scenes/audio/footstep_emitter_3d.tscn](../scenes/audio/footstep_emitter_3d.tscn) | `Node3D` | [footstep_emitter_3d.gd](../scripts/audio/footstep_emitter_3d.gd) | Cadence-based 3D footstep emitter attached to characters. |

### 1.5 Testing & Sandbox Scenes
| Scene Path | Root Node | Purpose |
|---|---|---|
| [scenes/testing/temporal_core_sandbox.tscn](../scenes/testing/temporal_core_sandbox.tscn) | `Control` | Standalone Level 3 testbed with dev timeline switcher and launcher buttons. |
| [scenes/testing/transition_flow_sandbox.tscn](../scenes/testing/transition_flow_sandbox.tscn) | `Node` | Test harness for verifying room transitions between mock rooms A and B. |
| [scenes/testing/audio_sandbox.tscn](../scenes/testing/audio_sandbox.tscn) | `Node3D` | Interactive sound testing sandbox for footsteps, ambience, and UI cues. |
| [scenes/testing/controller_sandbox.tscn](../scenes/testing/controller_sandbox.tscn) | `Node` | Gamepad controller and DualSense haptic testing sandbox. |
| [scenes/testing/dialogue_sandbox.tscn](../scenes/testing/dialogue_sandbox.tscn) | `Control` | Dialogue sequence auditioning and typewriter testbed. |
| [scenes/testing/frequency_puzzle_sandbox.tscn](../scenes/testing/frequency_puzzle_sandbox.tscn) | `Node3D` | Standalone test environment for the 3D frequency tuning dial. |
| [scenes/testing/interaction_sandbox.tscn](../scenes/testing/interaction_sandbox.tscn) | `Node3D` | Sandbox verifying proximity detection and priority selection. |

### 1.6 Legacy Deprecated Scenes (Historical Artifacts)
- `scenes/characters/student_player.tscn` / `student_model.tscn`: Legacy articulated 3D model (Missing `student_v2.glb`).
- `scenes/characters/student_2d_player.tscn` / `student_paper_rig.tscn` / `student_animation_studio.tscn`: Legacy 2D paper rig (Missing deleted PNG atlases).

---

## 2. Room 01: Signal Laboratory (`spawn_area.tscn`)

- **Floor Dimensions**: $24.8\text{ m} \times 15.6\text{ m}$ on the X/Z ground plane ($Y=0$).
- **Perimeter Bounds**: Low $1.0\text{ m}$ collision walls on North, South, West, East to keep the fixed-angle perspective camera view unobstructed.
- **Lighting**:
  - `WorldEnvironment`: Ambient fill light `#d6e6ff` (energy 0.65).
  - `CharacterKeyLight`: DirectionalLight3D pitched at $(-40^\circ, -32^\circ, 0^\circ)$, energy 1.15.
- **Stations & Interactables**:
  - `RadioPickup`: Transceiver equipment required to establish the cross-timeline radio link.
  - `ConsoleTerminal`: Active console in Past with rotatable frequency and amplitude dials; ruined log terminal in Future showing 67 MHz / 70% amplitude.
  - `ResearchNotebook`: Clue pickup unlocking initial journal notes.
  - `SecurityDoor`: North exit door that unlocks once the 67 MHz frequency link is established.

---

## 3. Room 02: Maintenance Corridor (`maintenance_corridor.tscn`)

- **Layout**: Industrial service gallery authored via `scenes/environment/rooms/maintenance_layout.tscn` (generated by `tools/build_maintenance_map.py`).
- **Pioneering Features**:
  - *Power Bay*: Entry cabinet with SERVICE circuit isolator lever and emergency battery crank.
  - *Support Crossing*: A physical chasm in the Future. The Student manipulates three hydraulic floor jacks; when configured to **Circle 3, Triangle 2, Square 1**, the collapsed ceiling slab in the Future shifts into a guarded walkable bridge.
  - *Records Archive*: Future records room containing personnel history confirming the Professor is the Student 31 years later, plus service override code **3142**.
  - *Private Dilemma Stations*: Local Reserve lever (diverts power locally at partner's expense) and Incident Recorder (extracting the cell provides early door power but erases authorization proof).

---

## 4. Room 03: The Final Fracture (`temporal_core.tscn`)

- **Dimensions**: $18.0\text{ m} \times 14.0\text{ m}$ central reactor chamber.
- **Components**:
  - Central reactor ring assembly, energetic temporal core pylon, and illuminated conduits.
  - West-bank coils 1, 2, 3 (configured to 2, 0, 1).
  - Future emergency receiver battery and collapsed north conduit.
  - Signal Anchor calibration station and Origin Core stabilizer.
  - Dual phase synchronization switches (requires simultaneous activation within 5 seconds).
  - Stage C Identity Terminals: Origin Terminal (Past) and Continuity Terminal (Future).
- **Audio & Visual Feedback**: Reactor clock countdown HUD, conduit energization lights, reactor core ring rotation speed/direction, and ending fade-out effects.
