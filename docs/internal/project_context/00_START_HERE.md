# 00 START HERE: Project Onboarding & Documentation Index

> **Historical document (internal).** Kept from the former `PROJECT_CONTEXT/` set for engineering context only. It describes the project as of 2026-10-21 and is not kept up to date. Current documentation map: [docs/README.md](../../README.md).

Welcome to **Past-Future**, an asymmetric cooperative mystery/puzzle adventure built in **Godot 4.7.2** for the **Reboot CHECKPOINT Game Jam 2026** (Theme: **"TWO"**).

This document serves as the primary technical entry point for developers and AI engineers auditing, testing, or continuing development on the repository.

---

## 1. Quick Project Status (Audited & Verified)

| Dimension | Current Implementation State | Verification Status | Primary Source Files |
|---|---|---|---|
| **Engine & Platform** | Godot 4.7.2 (`GL Compatibility`, D3D12 on Windows, Jolt 3D Physics) | **COMPLETE — VERIFIED** | [project.godot](../../../project.godot) |
| **Player Models** | 2 Skinned 3D Characters: Student (Age 18) & Professor (Age 49), 23 bones, 77 KayKit animations each | **COMPLETE — VERIFIED** | [student.glb](../../../assets/characters/student_3d/student.glb), [professor.glb](../../../assets/characters/professor_3d/professor.glb) |
| **Core Architecture** | 5 Autoload Singletons: `NetworkManager`, `PuzzleManager`, `GameFlowManager`, `JournalManager`, `CinematicTransitionManager` | **COMPLETE — VERIFIED** | [scripts/network/network_manager.gd](../../../scripts/network/network_manager.gd), [scripts/puzzles/puzzle_manager.gd](../../../scripts/puzzles/puzzle_manager.gd), [scripts/game_flow/game_flow_manager.gd](../../../scripts/game_flow/game_flow_manager.gd) |
| **Interaction System** | `Interactable3D` layer 4, `InteractionDetector`, `InteractionController`, `DeviceInspector3D` (3D ray-picked keypads & rotatable dials) | **COMPLETE — VERIFIED** | [scripts/interaction/](../../../scripts/interaction/), [scripts/gameplay/devices/device_inspector_3d.gd](../../../scripts/gameplay/devices/device_inspector_3d.gd) |
| **Playable Level 1** | **Signal Laboratory** (`spawn_area.tscn` / `signal_lab.tscn`): 3D environment, radio pickup, audio cues, exit security door | **COMPLETE — VERIFIED** | [scenes/world/spawn_area.tscn](../../../scenes/world/spawn_area.tscn), [scripts/world/spawn_area.gd](../../../scripts/world/spawn_area.gd) |
| **Puzzle 01** | **Lost Frequency** (Past tunes 67 MHz / 70% amplitude; Future recovers transmission log; stabilizes radio link & unseals door) | **COMPLETE — VERIFIED** | [scripts/puzzles/implementations/frequency_puzzle.gd](../../../scripts/puzzles/implementations/frequency_puzzle.gd), `run_frequency_tests.py` |
| **Playable Level 2** | **Maintenance Corridor** (`maintenance_corridor.tscn` / `maintenance_layout.tscn`): industrial gallery, power bay, bridge crossing, records archive | **COMPLETE — VERIFIED** | [scenes/world/maintenance_corridor.tscn](../../../scenes/world/maintenance_corridor.tscn), [scripts/world/maintenance_corridor.gd](../../../scripts/world/maintenance_corridor.gd) |
| **Puzzle 02** | **Broken Corridor** (Phase 1: Service loop isolate & battery crank; Phase 2: BRACE/PIN/RETRACT Circle 3 / Triangle 2 / Square 1 dynamic bridge; Phase 3: Archive code 3142 & Core release; 2 private shortcut choices) | **COMPLETE — VERIFIED** | [scripts/puzzles/implementations/maintenance_corridor_puzzle.gd](../../../scripts/puzzles/implementations/maintenance_corridor_puzzle.gd), `run_maintenance_tests.py` |
| **Playable Level 3** | **The Final Fracture** (`temporal_core.tscn` / `temporal_core_sandbox.tscn`): 150-second reactor challenge, coil cycling, receiver battery, 5s phase synchronization | **COMPLETE — VERIFIED** | [scenes/rooms/temporal_core.tscn](../../../scenes/rooms/temporal_core.tscn), [scripts/level3/temporal_core.gd](../../../scripts/level3/temporal_core.gd), [scripts/level3/core_rules.gd](../../../scripts/level3/core_rules.gd) |
| **Narrative Endings** | 4 Distinct Resolution Endings: `trust` (Last Goodbye), `student_override` (Erased Future), `professor_override` (Stolen Tomorrow), `paradox` (Iteration 02) | **COMPLETE — VERIFIED** | [scripts/level3/core_rules.gd](../../../scripts/level3/core_rules.gd), `run_level3_tests.py` |
| **Investigation / Journal** | Role-segregated evidence tracker (Student notebook vs. Professor DataPad), hotkey `J`, persists across rooms | **COMPLETE — VERIFIED** | [scripts/journal/journal_manager.gd](../../../scripts/journal/journal_manager.gd), [scenes/journal/journal_ui.tscn](../../../scenes/journal/journal_ui.tscn) |
| **Dialogue & Narrative** | Typewriter dialogue system, click/action advance, line queues, blocking/non-blocking modes, character portraits | **COMPLETE — VERIFIED** | [scripts/dialogue/dialogue_director.gd](../../../scripts/dialogue/dialogue_director.gd), [scenes/dialogue/dialogue_box.tscn](../../../scenes/dialogue/dialogue_box.tscn) |
| **Cinematic Transitions** | Room introduction title cards (`CinematicTransitionManager`, CanvasLayer 40, timeline-specific presets) | **COMPLETE — VERIFIED** | [scripts/cinematic/cinematic_transition_manager.gd](../../../scripts/cinematic/cinematic_transition_manager.gd) |
| **Solo Ghost Prototype** | Cyan hologram echo of other timeline within 4.5m radius, toggled via `G` or gamepad bumper | **COMPLETE — VERIFIED** | [scripts/world/temporal_ghost.gd](../../../scripts/world/temporal_ghost.gd), [shaders/temporal_ghost.gdshader](../../../shaders/temporal_ghost.gdshader) |
| **Audio Subsystem** | 5-bus system (`Master`, `SFX`, `UI`, `Ambience`, `Music`), 3D spatial footsteps, timeline ambiences, UI stings | **COMPLETE — VERIFIED** | [scripts/audio/audio_director.gd](../../../scripts/audio/audio_director.gd), [scenes/audio/audio_system.tscn](../../../scenes/audio/audio_system.tscn) |
| **Controller Support** | DualSense & Xbox gamepad input mapping, device auto-detection, contextual button glyphs, vibration/haptics | **COMPLETE — VERIFIED** | [scripts/input/input_manager.gd](../../../scripts/input/input_manager.gd), `run_controller_tests.py` |
| **Multiplayer Transport** | ENet LAN host/join (UDP 7000), host authority, monotonic state replication, snapshot synchronization | **COMPLETE — VERIFIED** (Loopback) | [scripts/network/network_manager.gd](../../../scripts/network/network_manager.gd) |
| **Remote WAN Play** | Documented Tailscale Virtual Mesh setup on port 7000 | **COMPLETE — UNVERIFIED** (Requires multi-PC test) | [GAME_DESIGN_DOCUMENT.md](../../design/GAME_DESIGN_DOCUMENT.md#9-multiplayer-architecture) |
| **Same-PC Split-Screen** | Menu button exists but is currently disabled (`COMING SOON`) | **NOT STARTED** | [scenes/menu/main_menu.tscn](../../../scenes/menu/main_menu.tscn) |

> [!NOTE]
> The game is a **fully playable 3-level vertical slice** spanning Chapter 0 ("The First Fracture"). All three planned cooperative puzzle sequences, both character models, the narrative investigation journal, dialogue sequences, audio, and all four narrative endings are fully implemented and verified by automated test suites.

---

## 2. Documentation Map

The technical context archive in `PROJECT_CONTEXT/` contains 14 synchronized Markdown documents:

```text
PROJECT_CONTEXT/
├── 00_START_HERE.md                  <- You are here: Executive entry point & status summary
├── 01_PROJECT_OVERVIEW.md            <- Concept, theme ("TWO"), narrative arc & full technology stack
├── 02_PROJECT_ARCHITECTURE.md        <- Codebase tree, Godot configuration, Autoloads, scene flows & RPCs
├── 03_GAME_DESIGN.md                 <- GDD v0.17 analysis: causality principles, puzzles, private choices & endings
├── 04_GAMEPLAY_SYSTEMS.md            <- Locomotion, 3D interaction, device inspection, audio, ghost & controllers
├── 05_CHARACTERS_AND_ANIMATIONS.md   <- Student and Professor 3D models, KayKit rig retargeting, 77 clips & studios
├── 06_SCENES_AND_LEVELS.md           <- Inventory of all scenes, Room 01, Room 02, Room 03, props & transitions
├── 07_ASSETS_AND_VISUALS.md          <- Shaders, palettes, 3D prop library, audio provenance & licenses
├── 08_DEVELOPMENT_PROGRESS.md        <- Comprehensive feature matrix, verification evidence & test counts
├── 09_BUGS_AND_TECHNICAL_DEBT.md     <- Rigorous audit of bugs (OPEN, FIXED, DEFERRED) & architectural debt
├── 10_SETUP_AND_TESTING.md           <- Execution commands, test suite runner documentation & audit results
├── 11_GIT_AND_RECENT_CHANGES.md      <- Git branch, HEAD snapshot, uncommitted working tree diff & commit chronology
├── 12_ROADMAP_AND_NEXT_STEPS.md      <- Prioritized task backlog (P0/P1/P2) & highest-impact next task
└── 13_AI_HANDOVER.md                 <- Master technical briefing and invariant manual for new AI agents
```

---

## 3. Recommended Reading Order

### Path A: Comprehensive Onboarding (New Developers & AI Agents)
1. [00_START_HERE.md](00_START_HERE.md) (This overview)
2. [13_AI_HANDOVER.md](13_AI_HANDOVER.md) (Architecture invariants, critical caveats & next steps)
3. [08_DEVELOPMENT_PROGRESS.md](../../development/DEVELOPMENT_PROGRESS.md) (Empirical implementation status)
4. [12_ROADMAP_AND_NEXT_STEPS.md](../../development/ROADMAP.md) (Prioritized backlog)

### Path B: Gameplay, Networking & Level Mechanics
1. [02_PROJECT_ARCHITECTURE.md](../../technical/ARCHITECTURE.md) (Autoloads, signals, RPC state synchronization)
2. [04_GAMEPLAY_SYSTEMS.md](../../technical/GAMEPLAY_SYSTEMS.md) (Interactions, device inspector, audio, camera)
3. [06_SCENES_AND_LEVELS.md](../../technical/SCENES_AND_LEVELS.md) (Room 01, Room 02, Room 03 layouts & transitions)
4. [03_GAME_DESIGN.md](03_GAME_DESIGN.md) (Puzzles 01, 02, 03, choice dilemmas & 4 endings)

### Path C: Art, Characters & Asset Pipeline
1. [05_CHARACTERS_AND_ANIMATIONS.md](../../technical/CHARACTERS_AND_ANIMATIONS.md) (Student & Professor models, KayKit animations)
2. [07_ASSETS_AND_VISUALS.md](../../technical/ASSETS_AND_VISUALS.md) (Shaders, materials, audio catalog, Kenney CC0 licenses)
3. [09_BUGS_AND_TECHNICAL_DEBT.md](../../development/KNOWN_ISSUES_AND_TECHNICAL_DEBT.md) (Legacy deprecated files, known test issues)

---

## 4. Key Architectural Invariants

When working on this codebase, adhere strictly to these non-negotiable principles:

1. **Ground-Level Contact Anchor ($Y=0$)**: All character root origins, furniture footprints, wall collision bodies, and interactive stations are anchored at floor contact ($Y = 0$). Collision shapes and visuals extend upward from this plane.
2. **Fixed Perspective Camera**: The gameplay camera uses `Camera3D.PROJECTION_PERSPECTIVE` with a fixed $35^\circ$ downward pitch, $48^\circ$ FOV, and smooth tracking. There are **no player camera rotation controls**.
3. **Host-Authoritative Puzzle State**: Clients **never** mutate puzzle or room progression optimistically. All actions follow the RPC pipeline:
   $$\text{Client Action Request} \longrightarrow \text{Host Validation} \longrightarrow \text{Host State Commit} \longrightarrow \text{Broadcast Confirmed State}$$
   The Host (Student / Past, Peer 1) is the sole authority; the Client (Professor / Future) renders confirmed states.
4. **Independent Resources Across Instances**: Characters and props duplicate materials and `AnimationLibrary` instances in `_ready()` (`.duplicate(true)`). This guarantees that timeline tints and animation states do not cross-contaminate.
5. **No Code Modification During Documentation Audits**: Documentation updates must never modify game logic or assets; uncommitted working tree edits must be preserved.

---

## 5. Next Steps

- Consult [13_AI_HANDOVER.md](13_AI_HANDOVER.md) for the master architectural handover.
- Check [10_SETUP_AND_TESTING.md](../../development/SETUP_AND_TESTING.md) for instructions to run the game and execute the automated test suites.
- Review [12_ROADMAP_AND_NEXT_STEPS.md](../../development/ROADMAP.md) for the prioritized backlog (implementing the Same-PC Split-Screen mode is the highest-impact remaining task).
