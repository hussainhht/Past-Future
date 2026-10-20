# 01 PROJECT OVERVIEW: Concept, Theme & Technology

## 1. High Concept & Story

**Past-Future** is an asymmetric cooperative puzzle adventure developed for the **Reboot CHECKPOINT Game Jam 2026**.

The core conceit centers on two players controlling different temporal versions of the same individual, separated by a gap of **31 years**:
- **The Student (Age 18)**: An ambitious, curious university student living in an intact, occupied research laboratory in the **Past**.
- **The Professor (Age 49)**: His older self, a mature, guarded scientist standing inside the ruinous, abandoned remains of the exact same facility in the **Future**.

### The Narrative Hook
An experimental temporal core reactor has suffered a catastrophic event known as "The First Fracture". As the two characters establish an impossible audio-visual link across time, they discover that the catastrophe was not an accident: **the Professor deliberately activated the experimental device**, fully aware of the consequences, for reasons he refuses to disclose.

To stabilize reality and prevent total collapse, the two must cooperate across time: the past student manipulates objects and configurations to alter the environment, while the future professor deciphers the surviving historical logs, structural blueprints, and ruined machine states to guide his younger self.

---

## 2. Game Jam Theme: "TWO"

The game integrates the Reboot CHECKPOINT theme **"TWO"** at every layer of design and architecture:

| Level | Manifestation of "TWO" |
|---|---|
| **Characters** | Two versions of the same person: 18-year-old student and 49-year-old professor. |
| **Timelines** | Two distinct temporal planes: The pristine academic Past and the decayed Future. |
| **Players** | Exactly two players cooperating; asymmetric roles where neither can finish alone. |
| **Perspectives** | Two independent viewports/devices observing the same physical rooms separated by time. |
| **Hardware** | Two-computer LAN/remote play or dual-viewport split-screen on one machine. |

---

## 3. Visual Tone & Atmospheric Identity

The game avoids generic photorealism or flat cartoon tropes in favor of an **atmospheric painted low-poly style**:
- **Perspective**: Fixed-angle high top-down perspective ($35^\circ$ downward pitch) with perspective projection.
- **Characters**: Original stylized low-poly 3D models with large expressive heads, rounded facial features, and readable asymmetric accessories (messenger bag on right hip, watch on left wrist). Driven by 77 imported KayKit animation clips.
- **Environments**: Modular 3D laboratory furniture with flat-shaded painted faces and subtle lambertian normal shading.
- **Past Mood**: Warm, academic, curious, functional. Color palette: warm cream (`#f0e2c7`), ochre yellow (`#e4bf7f`), olive/khaki (`#575c4a`), natural brown (`#70442c`).
- **Future Mood**: Dark, ruined, abandoned, melancholic. Color palette: cold cyan (`#86c9d1`), deep navy slate (`#15242b`), dark purple, desaturated teal.

---

## 4. Technology Stack & Platform Targets

| Component | Technology / Library | Version / Specifications |
|---|---|---|
| **Game Engine** | Godot Engine | `4.7.2.stable.official` |
| **Rendering Backend** | GL Compatibility (`gl_compatibility`) | D3D12 driver on Windows (`rendering_device/driver.windows="d3d12"`) |
| **Physics Engine** | Godot Jolt Physics | Jolt 3D physics integration (`3d/physics_engine="Jolt Physics"`) |
| **Target Platform** | Windows PC (x86_64) | Tested on Windows 11 |
| **Base Resolution** | $1600 \times 900$ viewport | $1280 \times 720$ window override, min $960 \times 540$, `canvas_items` stretch |
| **Multiplayer Transport** | Godot High-Level Multiplayer (`ENetMultiplayerPeer`) | Raw UDP on port `7000`, 2 peers (Host + 1 Client) |
| **WAN Remote Play** | Tailscale Mesh VPN | Virtual private tailnet over UDP 7000 |
| **Scripting** | GDScript 2.0 | Static typing conventions, signals, RPCs |
| **Offline Tooling** | Python 3.11 / 3.13 | `numpy==2.5.4`, `Pillow==13.0.0`, `bpy==5.2.2` (Blender Python API) |

---

## 5. Scope & Demo Duration

- **Format**: Vertical slice demo for Game Jam evaluation.
- **Playtime**: **5 to 10 minutes** start to finish.
- **Chapter**: *Chapter 0: The First Fracture*.
- **Rooms in Scope**:
  1. *Signal Laboratory*: Communication stabilization puzzle (Puzzle 01).
  2. *Maintenance Corridor*: Structural reconfiguration puzzle (Puzzle 02).
  3. *Temporal Research Core*: Stabilization sequence and narrative cliffhanger (Puzzle 03 / Ending).

---

## 6. Core Objective & Win/Lose Conditions

- **Core Gameplay Loop**:
  $$\text{Explore Room} \longrightarrow \text{Discover Obstacle} \longrightarrow \text{Find Temporal Clue} \longrightarrow \text{Exchange Info via Voice} \longrightarrow \text{Past Action Alteration} \longrightarrow \text{Future Physical Update} \longrightarrow \text{Advance}$$
- **Win Condition**: Successfully synchronize the temporal stabilizers in the Temporal Core, stabilizing the primary rift and triggering the narrative ending reveal.
- **Lose Condition**: 
  - For Puzzles 01 & 02: No hard death or fail states; players can retry puzzle configurations freely.
  - For Puzzle 03 (optional countdown): If the proposed 90-second stabilization timer runs out, only the final core reset occurs without punishing earlier room progress.
  - Connection Loss: If a peer disconnects, the active game pauses and prompts players to return to the main menu.

