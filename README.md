# Past-Future

[![Godot Engine](https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20PC-0078d4?logo=windows&logoColor=white)](https://microsoft.com/windows)
[![License: CC0](https://img.shields.io/badge/License-CC0%20(Audio%20%26%20Animations)-green)](assets/third_party/kaykit_character_animations/License.txt)
[![Game Jam](https://img.shields.io/badge/Game%20Jam-Reboot%20CHECKPOINT%202026-orange)](https://itch.io)

An asymmetric cooperative mystery and puzzle adventure developed in **Godot 4.7.2** for the **Reboot CHECKPOINT Game Jam 2026**, built around the theme **"TWO"**.

Two players control different temporal versions of the exact same individual, separated by an irrevocable gap of **31 years**:
- **The Student (Age 18)**: Conducting research in an intact university laboratory in the **Past**.
- **The Professor (Age 49)**: Standing in the catastrophic, decayed ruins of the same building in the **Future**.

The experimental temporal device has suffered a catastrophic fracture. But this was no accident—the Professor deliberately activated the device and overrode safety containment. Cooperate across time, reshape the environment, and discover why your future self caused the collapse.

---

## Key Features

- **Asymmetric Cooperative Gameplay**: Neither player can solve puzzles alone. The Future player deciphers surviving logs, diagnostic schematics, and rubble paths; the Past player manipulates intact machinery, electrical breakers, and hydraulic supports.
- **Three Playable Chapters**:
  - **Room 01 — Signal Laboratory**: Calibrate radio transceivers and frequency dials (67 MHz / 70% amplitude) to establish a cross-timeline link and unseal the security door.
  - **Room 02 — Maintenance Corridor**: Isolate service electrical loops, hand-crank emergency cells, align hydraulic floor jacks to shift a collapsed ceiling into a walkable bridge, and navigate private shortcut dilemmas.
  - **Room 03 — The Final Fracture**: A climactic 150-second reactor challenge with coil sequencing, anchor calibration, 5-second phase switch synchronization, and Stage C identity choices.
- **Four Branching Narrative Endings**:
  - `trust` (*The Last Goodbye*): The Professor voluntarily fades; reality is stabilized.
  - `student_override` (*Erased Future*): The future timeline is erased; forbidden protocols are exposed.
  - `professor_override` (*Stolen Tomorrow*): The Student fades; the changed future and Professor survive.
  - `paradox` (*Iteration 02*): Both identities dissolve; simulation restarts with `ITERATION 02 DETECTED`.
- **Two Original Skinned 3D Characters**: Both the Student and Professor models share the standard 23-joint KayKit skeleton with 77 genuine animation clips, proportion retargeting, and in-game animation inspection studios (hotkey `F2`).
- **3D Physical Device Inspector**: Smooth camera close-up transitions allowing direct manipulation of ray-picked 3D keypads, switches, and rotatable frequency tuning dials.
- **Investigation Journal & Dialogue**: In-game typewriter dialogue system with character portraits, paired with an asymmetric investigation journal (Student Notebook vs. Professor DataPad) on hotkey `J`.
- **Solo Temporal Ghost Hologram**: Playable offline in single-player preview mode; toggle a translucent cyan hologram echo of the other timeline with `G` to inspect remote changes.
- **Full Controller & Haptics Support**: Plug-and-play support for Sony DualSense (PS5) and Xbox controllers with dynamic glyph adaptation and vibration haptics.
- **5-Bus Audio Subsystem**: Spatial 3D footsteps (tile vs. concrete), ambient timeline soundscapes, and UI cues sourced from Kenney CC0.

---

## Development Status

| Component | Status | Details |
|---|---|---|
| **Campaign Content** | **COMPLETE — VERIFIED** | 3 fully connected rooms (Signal Lab, Maintenance Corridor, Temporal Core) |
| **Puzzles 01, 02, 03** | **COMPLETE — VERIFIED** | All three puzzle sequences implemented and verified with automated test suites |
| **Character Models** | **COMPLETE — VERIFIED** | Both 18yo Student and 49yo Professor models playable with 77 animation clips |
| **Multiplayer (LAN)** | **COMPLETE — VERIFIED** | ENet host/join architecture on UDP port 7000 (verified on loopback test harness) |
| **Multiplayer (WAN)** | **COMPLETE — UNVERIFIED**| Tailscale Virtual Mesh supported; requires multi-device testing |
| **Offline Split-Screen**| **NOT STARTED** | Main menu button is present (`COMING SOON`); implementation in progress |

---

## Technology Stack

- **Game Engine**: Godot Engine 4.7.2-stable official (`GL Compatibility` renderer, D3D12 on Windows)
- **Physics Engine**: Godot Jolt Physics 3D
- **Network Protocol**: Godot High-Level Multiplayer (`ENetMultiplayerPeer`) over UDP port `7000`
- **Resolution**: $1600 \times 900$ base canvas ($1280 \times 720$ window override, minimum $960 \times 540$)
- **Scripting**: GDScript 2.0 with static typing conventions
- **Tooling**: Python 3.11+ (`numpy`, `Pillow`, `bpy` Blender Python API)

---

## Installation & Running Instructions

### Prerequisites
- Windows 10/11 (x86_64)
- [Godot Engine 4.7.2-stable](https://godotengine.org/download)

### Quick Start
```powershell
# Clone the repository
git clone https://github.com/hussainhht/Past-Future.git
cd past-future

# Launch the game with Godot
godot --path .
```

### Direct Scene Launches (Fast Testing)
```powershell
# Explore the Signal Laboratory (Level 1)
godot --path . res://scenes/world/spawn_area.tscn

# Play Level 2 (Maintenance Corridor)
godot --path . res://scenes/world/maintenance_corridor.tscn

# Play Level 3 (The Final Fracture)
godot --path . res://scenes/rooms/temporal_core.tscn

# Launch Level 3 Testing Sandbox (Solo Future role)
godot --path . res://scenes/testing/temporal_core_sandbox.tscn -- --core-solo future
```

---

## Controls

The game automatically detects connected gamepads and swaps button glyphs dynamically:

| Action | Keyboard / Mouse | DualSense (PS5) | Xbox Controller |
|---|---|---|---|
| **Move** | `W`, `A`, `S`, `D` / Arrows | Left Stick / D-Pad | Left Stick / D-Pad |
| **Sprint** | `Shift` (Hold) | `R2` Trigger / `L3` | `RT` Trigger / `LS` |
| **Interact** | `F` | Cross (`✕`) | `A` Button |
| **Inspect** | `I` | Square (`□`) | `X` Button |
| **Use Item** | `E` | Triangle (`△`) | `Y` Button |
| **Journal** | `J` | Touchpad / Select | View / Select Button |
| **Solo Ghost** | `G` | `R1` Bumper | `RB` Bumper |
| **Switch Role** (Offline)| `T` | `L1` Bumper | `LB` Bumper |
| **Animation Studio** | `F2` | — | — |
| **Cancel / Pause** | `Escape` | Options / Start | Menu / Start |
| **Device Click** | Left Mouse Click | Cross (`✕`) | `A` Button |
| **Dial Adjust** | Mouse Drag / Wheel | D-Pad Left / Right | D-Pad Left / Right |

---

## Multiplayer Setup

Past-Future is a two-player cooperative game. Exactly one player is assigned to the Past (Student) and one to the Future (Professor).

### 1. Same Wi-Fi / Local Network (LAN)
1. Connect both computers to the same Wi-Fi router or wired local network.
2. **Player 1 (Host / Past)**: Select `PLAY TOGETHER` $\rightarrow$ `HOST ON WI-FI`. Note the IP address shown in the lobby.
3. **Player 2 (Client / Future)**: Select `PLAY TOGETHER` $\rightarrow$ `JOIN ON WI-FI`, enter the Host's IP address, and click `CONNECT`.
4. Once connected, Player 2 clicks `I'M READY`, and Player 1 clicks `START GAME`.
5. Ensure Windows Firewall permits incoming UDP traffic on port `7000`.

### 2. Remote Internet Play (via Tailscale)
When playing over the internet without router port forwarding:
1. Install [Tailscale](https://tailscale.com) on both PCs and log into the same tailnet (or share machine access).
2. Host selects `HOST ON WI-FI`. Share the host's `100.x.y.z` Tailscale IP address.
3. Client selects `JOIN ON WI-FI`, enters the host's Tailscale IP, and connects.

---

## Repository Structure

```text
past-future/
├── assets/
│   ├── audio/           Kenney CC0 sound effects, footsteps & ambiences
│   ├── characters/      Original Student (18yo) & Professor (49yo) 3D skinned models
│   ├── environments/    Modular laboratory props and textures
│   └── third_party/     KayKit CC0 character animations (77 clips)
├── docs/                Detailed technical specifications, level designs & screenshots
├── PROJECT_CONTEXT/     Master 14-file technical context archive for engineers & AI agents
├── resources/           Dialogue sequences, journal entries, room definitions, and UI themes
├── scenes/
│   ├── characters/      Player character scenes and in-game animation studios
│   ├── cinematic/       Room introduction title cards (CanvasLayer 40)
│   ├── dialogue/        Dialogue overlay and typewriter system
│   ├── environment/     Interactive stations (consoles, keypads, security doors)
│   ├── journal/         Investigation notebook and DataPad interface
│   ├── menu/            Title screen, LAN lobby, settings, and credits
│   ├── rooms/           Level 3 Temporal Research Core scene
│   └── world/           Level 1 (Signal Lab) and Level 2 (Maintenance Corridor)
├── scripts/             Gameplay controllers, autoload singletons, puzzles, and shaders
├── shaders/             Custom unshaded lambertian, procedural tile floor, and ghost shaders
├── tests/               13 automated test suites and headless verification scripts
└── tools/               Python procedural mesh generators and Blender export scripts
```

---

## Testing

To run the automated headless verification suite:
```powershell
$env:GODOT_BIN = "C:\Users\hanwd\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
$env:DISPLAY = "1"

# Run Asset Integrity Check
python tests/student_3d_assets.py
python tests/student_3d_assets.py --character professor

# Run Authoritative Puzzle Synchronization Suite
python tests/run_puzzle_tests.py

# Run Level 1 Frequency Suite
python tests/run_frequency_tests.py

# Run Dialogue System Suite (382 checks)
python tests/run_dialogue_tests.py

# Run Level 3 Final Fracture Suite (Core + 4 Endings over ENet)
python tests/run_level3_tests.py
```

---

## Technical Documentation & References

- [GAME_DESIGN_DOCUMENT.md](GAME_DESIGN_DOCUMENT.md): Game Design Document (v0.17).
- [PROJECT_CONTEXT/00_START_HERE.md](PROJECT_CONTEXT/00_START_HERE.md): Technical entry point and documentation index.
- [PROJECT_CONTEXT/13_AI_HANDOVER.md](PROJECT_CONTEXT/13_AI_HANDOVER.md): Master technical brief and architectural invariants.

---

## Credits & Asset Attribution

- **Game Design & Engineering**: Hussain Ali
- **Character Animations**: [KayKit Character Animations 1.1](https://kaylousberg.itch.io/kaykit-character-animations) by Kay Lousberg (CC0 Public Domain).
- **Environment Props**: [KayKit Space Base & Prototype Bits](https://kaylousberg.itch.io) by Kay Lousberg (CC0 Public Domain).
- **Audio Assets**: [Kenney Game Audio](https://kenney.nl) (Impact Sounds, Interface Sounds, Sci-Fi Sounds) by Kenney (CC0 Public Domain).

