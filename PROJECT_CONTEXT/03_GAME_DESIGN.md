# 03 GAME DESIGN: Mechanics, Puzzles & Design Reality

## 1. Game Design Document (GDD) Analysis

The authoritative game design reference is [GAME_DESIGN_DOCUMENT.md](../GAME_DESIGN_DOCUMENT.md) (Version 0.16). It outlines a focused, 5-to-10 minute cooperative vertical slice titled **"Chapter 0: The First Fracture"**.

### Design Pillars
1. **Asymmetric Knowledge**: Neither player possesses sufficient information on their own screen to solve obstacles. Communication is required.
2. **Temporal Causality**: Selected actions performed in the pristine Past alter specific, predetermined structures and machinery in the ruined Future.
3. **Low-Stress Investigation**: No combat, no precision platforming, and no reflex-based action. Challenges center on observation, verbal deduction, and temporal sequencing.
4. **Ground-Anchored Readability**: Clean, painted geometry viewed from a fixed perspective high top-down angle ($35^\circ$), allowing immediate spatial awareness across both timelines.

---

## 2. Planned Design vs. Implemented Reality

The following matrix provides an objective audit comparing what is specified in GDD v0.16 against what actually exists in the codebase today:

| System / Feature | GDD v0.16 Specification | Actual Repo Status | Evidence / Files |
|---|---|---|---|
| **Player Roles** | Asymmetric roles: Student (Past) and Professor (Future). | **Partial** | Roles are assigned in lobby (`network_manager.gd`), but both run identical student scripts and character scenes. |
| **Character Models** | Two distinct models with age progression and shared facial structure. | **Partial** | Student 3D model is complete (`student.glb`); Professor model **does not exist** (Student is tinted cyan). |
| **Locomotion** | 8-direction camera-relative ground movement + Shift sprint. | **COMPLETE** | Implemented and verified in `scripts/characters/student_3d_player.gd`. |
| **Perspective Camera** | Fixed $35^\circ$ pitch, $48^\circ$ FOV, smooth following. | **COMPLETE** | Implemented and verified in `scripts/world/follow_camera.gd`. |
| **3D Props** | Solid painted 3D furniture with footprint collision. | **COMPLETE** | Implemented in `scenes/props/` and `shaders/painted_prop.gdshader`. |
| **Timeline Visual Swap** | Dynamic Past/Future shader and color switching. | **COMPLETE** | Implemented via `lab_floor.gdshader` and `lab_prop.gd`. |
| **Multiplayer Lobby** | ENet LAN host/join, ready state, IP display. | **COMPLETE** | Implemented in `network_manager.gd` and `main_menu.gd`. |
| **Same-PC Co-op** | Offline split-screen with dual viewports and split inputs. | **NOT STARTED** | UI button exists but is disabled; no split-screen logic exists. |
| **Interaction System** | `Area3D` proximity triggers, prompts ("F - Use"), item inspection. | **NOT STARTED** | F/I/E keys trigger dummy animation clips; **no `Area3D` interactive objects exist**. |
| **State Authority** | Host-authoritative `puzzle_manager.gd` with RPC validation. | **NOT STARTED** | Architecture is documented, but **no puzzle manager file exists**. |
| **Puzzle 01 (Frequency)** | Signal Lab: sequence exchange and radio tuning. | **NOT STARTED** | Zero puzzle code or interactive console logic. |
| **Puzzle 02 (Corridor)** | Maintenance Corridor: structural support alignment. | **NOT STARTED** | Room does not exist; no support mechanics. |
| **Puzzle 03 (Anchor)** | Temporal Core: reactor stabilization sequence with optional 90s timer. | **NOT STARTED** | Room does not exist; no countdown or stabilization code. |
| **Narrative Dialogue** | In-game opening dialogue, fracture encounters, cliffhanger ending. | **NOT STARTED** | No dialogue UI or narrative triggers exist in runtime scenes. |

---

## 3. The Two Characters: Dynamic & Asymmetry

### Character A — The Student (Past Timeline)
- **Age**: 18
- **Environment**: Functional, brightly lit university laboratory.
- **Role**: Action executor. Has physical access to intact machinery, adjustable structural jacks, functional electrical breaker panels, and active scientific terminals.
- **Limitation**: Lacks historical hindsight. Does not know the final configuration parameters, failure codes, or catastrophic consequences of the experiment.

### Character B — The Professor (Future Timeline)
- **Age**: 49 (31 years later)
- **Environment**: Ruined, fractured, power-starved university laboratory.
- **Role**: Information provider. Has access to surviving incident reports, wall-mounted maintenance schematics, archival logs, and observable structural breaches.
- **Limitation**: Cannot alter decayed physical objects directly. Blocked passages and burnt terminals prevent movement without Past intervention.

### Communication Dependency
Because the game does not include in-engine voice chat, players are expected to communicate via an external voice call (Discord, etc.) or across the room during LAN play. Information asymmetry forces constant verbal communication:
- Future player reads an encrypted sequence from an old terminal $\longrightarrow$ dictates it to Past player.
- Past player reconfigures a hydraulic support $\longrightarrow$ Future player watches a collapsed doorway reconstruct itself.

---

## 4. Temporal Causality Mechanics

The game operates under **deterministic, discrete causality**, not a continuous time simulation:

```mermaid
sequenceDiagram
    autonumber
    actor Past as Student (Past Player)
    participant Host as Host Authority (Peer 1)
    participant Dict as State Dictionary
    actor Future as Professor (Future Player)

    Past->>Host: request_action(puzzle_id, "tune_dial", 142.8)
    Note over Host: Host validates sender, role,<br/>prerequisites & bounds
    Host->>Dict: state["freq_locked"] = true; rev++
    par Broadcast Confirmed State
        Host-->>Past: apply_puzzle_state(puzzle_id, state, rev)
        Host-->>Future: apply_puzzle_state(puzzle_id, state, rev)
    end
    Note over Past: Past updates radio LED & unlocks door
    Note over Future: Future receives transmission audio & unlocks door
```

### 4.1 Temporal Interaction Types
1. **Instant Direct Change**: Modifying an object in the past immediately updates its counterpart in the future (e.g. clearing a debris table in the past causes the table in the future to become unblocked).
2. **Delayed Structural Consequence**: Activating a support jack in the past alters how the building collapsed decades later, opening a navigable path in the future corridor.
3. **Information Transfer (Retrocausality)**: Surviving documents and logs in the future contain calibration frequencies and access keys required by the student in the past.

### 4.2 Visual & Audio Feedback Rules
When a temporal change occurs:
- A distinct audio chime and subtle energy surge sound must play.
- Distortion particles or shader flickers should occur on the affected object.
- **Crucial Rule**: Cutscenes must not take away player control; changes occur organically in the environment while players remain mobile.

---

## 5. Puzzle Specifications (Planned)

### Puzzle 01: "Lost Frequency"
- **Location**: Signal Laboratory (Room A).
- **Duration**: $1 - 2$ minutes (Introductory / Tutorial puzzle).
- **Past Role**: Approaches the communication console (`console_visual.tscn`). Inputs calibration numbers or aligns tuning dials.
- **Future Role**: Restores emergency battery power to a burnt receiver. Reads a surviving printout or transmission log showing the required frequency (e.g. `142.8 MHz`).
- **Resolution**: Both communication arrays synchronize. The electronic security door unlocking the Maintenance Corridor opens.

### Puzzle 02: "Broken Corridor"
- **Location**: Maintenance Corridor (Room B).
- **Duration**: $2 - 3$ minutes (Spatial / Structural puzzle).
- **Future Role**: Discovers a collapsed ceiling section blocking access to Room C. Finds an architectural maintenance diagram on the wall detailing 3 support load points. Tells Past player which supports must be engaged.
- **Past Role**: Locates 3 hydraulic floor jacks. Reconfigures their heights to match the blueprint.
- **Resolution**: In the Future, the structural collapse pattern changes; the fallen ceiling slab shifts into a stable ramp, allowing the Professor to cross and retrieve the master access keycard.

### Puzzle 03: "Temporal Anchor"
- **Location**: Temporal Research Core (Room C).
- **Duration**: $2 - 3$ minutes (Climax / Synchronization puzzle).
- **Past Role**: Configures core power output coils and initiates the stabilization sequence.
- **Future Role**: Repairs the receiver anchor and reads dynamic synchronization intervals.
- **Mechanic**: Proposed 90-second countdown once initiated. Both players must press corresponding switches within a narrow synchronization window.
- **Resolution**: Stabilizes the fracture, halts the facility collapse, and triggers the narrative cliffhanger.
- **Scope Note**: GDD classifies Puzzle 03 as **optional for the Game Jam** if Puzzles 01 and 02 require additional stabilization.

---

## 6. Narrative Progression & Cliffhanger Ending

- **Opening**: Student is in the lab; receives a transmission from 31 years ahead. A spatial ripple reveals the Professor.
- **Discovery**: Realization that they are the same person; agreement to stabilize the facility.
- **Escalation**: Corridor collapse threatens to sever the link. Environmental instability increases.
- **Climax**: Stabilization of the primary fracture in the Temporal Core.
- **Cliffhanger**: An archived research terminal reveals that **the Professor deliberately initiated the catastrophic experiment** with full foreknowledge. The student confronts him: *"Why did you do this to us?"* The Professor remains silent as secondary fractures erupt on monitoring screens.
- **Screen cuts to black: "END OF CHAPTER 0"**.

