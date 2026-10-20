# 00 START HERE: Project Onboarding & Documentation Index

Welcome to **Past-Future**, an asymmetric cooperative mystery/puzzle adventure built in **Godot 4.7** for the **Reboot CHECKPOINT Game Jam 2026**.

This document serves as the primary technical entry point for developers and AI assistants taking over development.

---

## 1. Quick Project Status

| Dimension | Current State | Verification Status |
|---|---|---|
| **Engine & Platform** | Godot 4.7.2 (GL Compatibility, D3D12 on Windows) | Verified working |
| **Active Player Model** | Original 3D student character, 23 bones, 77 KayKit animations | Verified (77/77 clips playable) |
| **Active Environments** | 3D Greybox Signal Laboratory (`spawn_area.tscn`) | Verified |
| **Networking** | ENet LAN multiplayer (Host = Past, Client = Future) on UDP 7000 | Verified via loopback smoke test |
| **Gameplay Puzzles** | Designed in GDD v0.16; **0 implemented in code** | NOT STARTED |
| **Authoritative State** | `PuzzleManager` autoload + `PuzzleBase` framework implemented (see `docs/PUZZLE_SYSTEM.md`); no real puzzles use it yet | Verified (`python tests/run_puzzle_tests.py`) |
| **Local Split-Screen** | Button visible on menu but disabled | NOT STARTED |
| **Professor Model** | Not created; Future timeline currently reuses Student | NOT STARTED |

> [!IMPORTANT]
> The project possesses a **working technical foundation** (multiplayer lobby, 3D locomotion, 77-clip skeletal animation player, follow camera, painted shader props), but has **zero interactive gameplay puzzles**. Your immediate development objective is implementing the interaction system and host-authoritative puzzle manager.

---

## 2. Documentation Map

The documentation in `PROJECT_CONTEXT/` is split into 14 dedicated, cross-referenced Markdown files:

```text
PROJECT_CONTEXT/
├── 00_START_HERE.md                  <- You are here: Executive entry point & index
├── 01_PROJECT_OVERVIEW.md            <- Concept, Game Jam theme ("TWO"), narrative & stack
├── 02_PROJECT_ARCHITECTURE.md        <- Repo structure, Godot configuration, scene graph & data flows
├── 03_GAME_DESIGN.md                 <- GDD v0.16 analysis: mechanics, puzzles & planned vs actual
├── 04_GAMEPLAY_SYSTEMS.md            <- Locomotion, animations, camera, networking & solo preview
├── 05_CHARACTERS_AND_ANIMATIONS.md   <- 3D student mesh, KayKit rig, retargeting & studio tools
├── 06_SCENES_AND_LEVELS.md           <- Scene breakdown, spawn area layout, props & lighting
├── 07_ASSETS_AND_VISUALS.md          <- Shaders, palettes, 3D meshes, 2D art & third-party assets
├── 08_DEVELOPMENT_PROGRESS.md        <- Evidence-based feature progress & completion matrix
├── 09_BUGS_AND_TECHNICAL_DEBT.md     <- Confirmed bugs, missing files, risks & recommended fixes
├── 10_SETUP_AND_TESTING.md           <- Godot version, execution steps, input mappings & test results
├── 11_GIT_AND_RECENT_CHANGES.md      <- Git commit history, recent asset changes & worktree state
├── 12_ROADMAP_AND_NEXT_STEPS.md      <- Prioritized P0/P1/P2 task cards & single best next action
└── 13_AI_HANDOVER.md                 <- Comprehensive handover brief for incoming AI engineers
```

---

## 3. Recommended Reading Order

Depending on your immediate assignment, follow these reading paths:

### Path A: Fast System Handover (For General AI Continuation)
1. [00_START_HERE.md](00_START_HERE.md) (This file)
2. [13_AI_HANDOVER.md](13_AI_HANDOVER.md) (High-density technical briefing & invariants)
3. [08_DEVELOPMENT_PROGRESS.md](08_DEVELOPMENT_PROGRESS.md) (What works and what does not)
4. [12_ROADMAP_AND_NEXT_STEPS.md](12_ROADMAP_AND_NEXT_STEPS.md) (Immediate task definition)

### Path B: Gameplay & Networking Implementation
1. [02_PROJECT_ARCHITECTURE.md](02_PROJECT_ARCHITECTURE.md) (Autoloads, signals, scene relationships)
2. [04_GAMEPLAY_SYSTEMS.md](04_GAMEPLAY_SYSTEMS.md) (Current movement, camera, and network manager)
3. [03_GAME_DESIGN.md](03_GAME_DESIGN.md) (Puzzle specifications and authority flow)
4. [09_BUGS_AND_TECHNICAL_DEBT.md](09_BUGS_AND_TECHNICAL_DEBT.md) (Traps, broken scenes, and constraints)

### Path C: Art & Animation Pipeline
1. [05_CHARACTERS_AND_ANIMATIONS.md](05_CHARACTERS_AND_ANIMATIONS.md) (Mesh construction, retargeting, GLB pipeline)
2. [07_ASSETS_AND_VISUALS.md](07_ASSETS_AND_VISUALS.md) (Shaders, materials, color palettes, prop scenes)
3. [06_SCENES_AND_LEVELS.md](06_SCENES_AND_LEVELS.md) (Room layouts and visual props)

---

## 4. Key Architectural Invariants

When working on this repository, you must adhere to these non-negotiable architectural principles:

1. **Origins at Ground Level**: All character roots, static bodies, and prop roots have their origin at ground contact ($Y=0$). Collision boxes and meshes are positioned upward from this anchor.
2. **Fixed Perspective Camera**: The gameplay camera is a `Camera3D` with perspective projection, fixed $35^\circ$ downward pitch, and $48^\circ$ field of view. There are **no player camera rotation controls**.
3. **Host-Authoritative Puzzle State**: Neither player may mutate puzzle state optimistically. The Host (Past player, Peer 1) is the sole authority. The Client (Future player) requests actions via RPC; the Host validates and broadcasts confirmed state.
4. **Independent Resources**: `AnimationLibrary` and material instances are duplicated in `_ready()` to prevent Past and Future timelines from corrupting each other's visual parameters.
5. **Standard Input Mappings**: Movement uses `move_left`, `move_right`, `move_up`, `move_down` normalized in camera space.

---

## 5. Next Steps

To begin development immediately, proceed to:
- [13_AI_HANDOVER.md](13_AI_HANDOVER.md) for full context.
- [12_ROADMAP_AND_NEXT_STEPS.md](12_ROADMAP_AND_NEXT_STEPS.md) for the active task backlog.

