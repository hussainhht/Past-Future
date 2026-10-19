# PAST & FUTURE
## Game Design Document — Version 0.5

**Project:** CHECKPOINT — Reboot Game Jam 2026  
**Status:** Visual Direction Approved / Technical Risk Mitigations Defined\
**Engine:** Godot 4.x  
**Genre:** Cooperative Mystery / Puzzle Adventure  
**Visual Style:** Stylized 2D Art with 2.5D Depth — Inspired by Don't Starve  
**Perspective:** Fixed 3/4 Top-Down View  
**Platform:** Windows PC  
**Multiplayer:** Two-Computer LAN Co-op; Remote Play via Tailscale; Same-PC Split-Screen Fallback\
**Demo Duration:** 5–10 minutes  
**Demo Chapter:** Chapter 0 — The First Fracture

---

## 1. High Concept

Two players control different versions of the same person, separated by 31 years.

One player controls an ambitious 18-year-old university student living in the past. The other controls his 49-year-old future self, a successful professor surrounded by the ruins of the same university.

An experimental device has caused a catastrophic fracture in time.

The professor deliberately activated this device, despite knowing its risks. His reasons remain a mystery.

The two characters must cooperate across different time periods to stabilize reality.

**Core Hook:** Change the past, reshape the future, and discover why your future self caused the catastrophe.

### Game Jam Theme — TWO

The game is built around two playable characters, two timelines, two perspectives, and two people who must cooperate despite being the same individual.

Neither player can complete the game alone.

---

## 2. Visual Direction — NEW

### 2.1 Art Style

The game uses a stylized 2D visual approach presented with simulated depth, inspired by the presentation techniques of Don't Starve.

**Characteristics:**

- Hand-drawn-looking 2D characters.
- Stylized 2D environment assets.
- Angled top-down perspective.
- Layered foreground and background objects.
- Depth sorting so characters can walk behind and in front of furniture.
- Soft shadows and atmospheric lighting.
- Limited character animations.
- Environmental distortion around temporal fractures.

The aesthetic should be mysterious, atmospheric, readable, and distinctive.

The game does not require fully modeled 3D characters, complex 3D environments, or 3D character rigging.

### 2.2 Artistic Identity

The game should have its own visual identity instead of directly copying another game's artwork.

**Suggested identity:**
- Hand-painted, slightly textured surfaces.
- Stylized academic architecture.
- Exaggerated but readable scientific equipment.
- Muted colors combined with glowing energy accents.
- Subtle outlines around important characters and interactive objects.
- A contrast between scientific curiosity and catastrophic consequences.

### 2.3 Past Timeline

**Visual Mood:** Peaceful, curious, academic.

**Color Palette:**
- Warm cream
- Soft green
- Muted teal
- Warm yellow
- Natural brown

**Environment:**
- Functional university laboratories.
- Clean desks and active monitors.
- Books, posters, and research documents.
- Plants and normal campus details.
- Daylight through windows.
- Functional laboratory machinery.

The environment should feel occupied and maintained without requiring active student NPCs in the prototype.

### 2.4 Future Timeline

**Visual Mood:** Dark, mysterious, abandoned.

**Color Palette:**
- Deep blue
- Dark purple
- Desaturated grey
- Cold cyan
- Muted black

**Environment:**
- Cracked floors and walls.
- Broken furniture and monitors.
- Fallen equipment and scattered research papers.
- Damaged support structures.
- Temporal cracks glowing with violet energy.
- Environmental fog, subtle particles, and flickering lights.

The future should still be recognizable as the same university.

### 2.5 Past/Future Asset Reuse

Both timelines share a common underlying floor plan.

Assets are organized into:

1. Shared objects used in both timelines.
2. Past-specific variants.
3. Future-specific damaged variants.
4. Temporal objects linked to puzzle events.

For example, a clean desk in the past becomes a damaged desk in the future. The desk retains approximately the same position, allowing players to recognize corresponding locations.

### 2.6 Perspective and Depth

The world is implemented with Godot's 2D rendering system.

- The camera views an illustrated three-quarter perspective.
- Movement occurs on a flat 2D gameplay plane.
- Characters can move around tables and machinery.
- The player is drawn in front of or behind objects based on their vertical screen position.
- Important equipment receives clearly defined collision shapes.

This produces visual depth without requiring true 3D geometry.

---

## 3. Character Design

### Character A — The Student

**Age:** 18  
**Timeline:** Past  
**Role:** University student  
**Personality:** Curious, optimistic, intelligent, ambitious.

**Appearance:**
- Young adult male.
- Short, dark hair.
- Casual university clothing.
- Backpack or student identification.
- Expressive but stylized face.
- Recognizable features shared with the professor.

**Animation Requirements:**
- Idle.
- Walk.
- Interact.

The minimum version uses a small directional sprite set and horizontal flipping where appropriate.

### Character B — The Professor

**Age:** 49  
**Timeline:** Future  
**Role:** University professor and researcher  
**Personality:** Serious, mature, experienced, guarded.

**Appearance:**
- Older version of the student.
- Similar facial structure.
- Darker, more formal clothing.
- Visible signs of age.
- Optional glasses, beard, or research coat.

**Animation Requirements:**
- Idle.
- Walk.
- Interact.

Both characters should have recognizable silhouettes and related facial characteristics.

### Character Production

Characters will be created using AI-assisted 2D artwork and prepared as transparent PNG sprites.

Complex skeletal animation is not required for the prototype.

---

## 4. Camera and Movement — UPDATED

### Camera

Use `Camera2D` with a fixed viewing angle represented directly in the artwork.

The camera follows the local player inside each research area.

In local split-screen mode, each timeline has its own viewport and camera on the same PC.

### Movement

The player moves in eight directions using the WASD keys.

| Key | Action |
|---|---|
| W | Move upward |
| A | Move left |
| S | Move downward |
| D | Move right |
| E | Interact with nearby object |
| Tab | Show available clues, if implemented |
| Esc | Open pause menu |

Diagonal movement should be normalized to prevent faster diagonal travel.

Local split-screen uses separate input actions: Past uses WASD + E; Future uses arrow keys + Enter. Each viewport routes interaction UI input only to its assigned player. Verify simultaneous movement and interaction on the judging keyboard during Day 1.

### Interactions

Interactive equipment uses `Area2D` detection.

When a player approaches an object, an interaction prompt appears.

Examples:
- E — Use Terminal
- E — Read Document
- E — Activate Machine
- E — Adjust Support

Character sprites and props use depth sorting, while walls, blocked passages, and machines use 2D collision.

No jumping, combat, or precision platforming is required.

---

## 5. Setting

### Main Location

A fictional university with advanced research laboratories and an experimental temporal-energy project.

The complete game may include classrooms, libraries, lecture halls, research facilities, student areas, and surrounding locations.

The Game Jam demo focuses on a single research wing.

### Research Wing Layout

**Area A — Signal Laboratory**

A small research room containing communication equipment.

**Area B — Maintenance Corridor**

A connecting university passage containing structural supports and technical equipment.

**Area C — Temporal Research Core**

The experimental laboratory where the temporal device is located.

Each area has a past and future visual state.

The prototype uses compact connected rooms rather than a large open world.

---

## 6. Core Gameplay Loop

1. Enter a new university area.
2. Explore the surroundings.
3. Discover a puzzle or inaccessible passage.
4. Identify clues available only in one timeline.
5. Share information with the other player.
6. Coordinate actions.
7. Change an object or event in the past.
8. Observe the consequences in the future.
9. Advance and discover more about the catastrophe.

The two players should regularly have different information and different responsibilities.

---

## 7. Temporal Causality System

### Main Principle

Selected actions in the past change explicitly defined objects in the future.

The game does not simulate an entire changing universe.

Instead, linked objects have predetermined states.

### Temporal Interaction Types

**Instant Change**

An event in the past immediately changes a corresponding object in the future.

**Delayed Change**

A past action updates the future only after a confirmation or activation sequence.

**Information Transfer**

The future contains information required for solving a problem in the past.

### Visual Feedback

A timeline change can trigger:
- A short energy flash.
- Distortion particles.
- An object fading into its updated state.
- A distinct sound effect.
- A brief camera emphasis.

These effects should be short and should not interrupt player control unnecessarily.

---

## 8. Puzzle Design

### Puzzle 01 — Lost Frequency

**Location:** Signal Laboratory  
**Estimated Duration:** 1–2 minutes

**Past Player:**
- Finds a functional communication transmitter.
- Examines its calibration controls.
- Inputs a sequence received from the future.

**Future Player:**
- Restores power to a damaged receiver.
- Reads a surviving transmission log.
- Finds the required sequence.
- Confirms the connection.

**Result:**
The communication system stabilizes and the next area unlocks.

**Purpose:**
Teach asymmetric cooperation and information exchange.

### Puzzle 02 — Broken Corridor

**Location:** Maintenance Corridor  
**Estimated Duration:** 2–3 minutes

**Past Player:**
- Finds three adjustable support mechanisms.
- Changes their configuration.
- Confirms the maintenance setup.

**Future Player:**
- Finds a structural diagram showing the correct configuration.
- Communicates the sequence to the past.
- Watches the collapsed corridor change.
- Crosses the restored passage.
- Finds an access code required by the past player.

**Result:**
Both players gain access to the Temporal Research Core.

**Purpose:**
Introduce delayed environmental changes with a visible consequence.

### Puzzle 03 — Temporal Anchor

**Location:** Temporal Research Core  
**Estimated Duration:** 2–3 minutes

**Past Player:**
- Configures energy output.
- Activates the experimental prototype.

**Future Player:**
- Repairs the temporal stabilizer.
- Reads the correct activation sequence.
- Coordinates final synchronization.

**Challenge:**
A proposed 90-second countdown begins when the final stabilization attempt starts.

Both players must coordinate their actions before time expires.

**Result:**
The temporal fracture stabilizes.

**Failure:**
Reset only the final puzzle.

**Scope Classification:**
Optional for the Game Jam if the first two puzzles and the ending are not fully stable.

---

## 9. Multiplayer Architecture

### Network Structure

- Two-player Host/Join system.
- Exactly one player is assigned to the Past.
- Exactly one player is assigned to the Future.
- In online mode, each device displays its own timeline.
- The host is the sole authority for puzzle state in both timelines, regardless of its player's role.
- In local mode, both timelines run on one PC and share the same authoritative puzzle manager.

### Engine Technology

Godot 4 high-level multiplayer with `ENetMultiplayerPeer` and RPC communication, using Tailscale for remote connectivity.

Keep network transport separate from puzzle rules so local play uses the same validation and state transitions.

### Same-Wi-Fi / LAN Play

**LAN co-op** means two computers on the same Wi-Fi or wired local network. **Same-PC co-op** means two players sharing one computer in split-screen. These are separate modes; use these explicit labels in menus and release instructions.

LAN play uses the Host/Join flow with ENet directly, without Tailscale or router port forwarding. One player hosts as the Student/Past, and the other joins as the Professor/Future using the host's LAN address and UDP port `7000`. Godot documents this use of an internal IP address for [LAN hosting](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#hosting-considerations).

**Player Setup:**

1. Connect both computers to the same normal Wi-Fi or wired LAN and launch the same game build.
2. On the first computer, choose Play Together → Host on Wi-Fi. Share the Wi-Fi adapter address shown in the lobby.
3. On the second computer, choose Play Together → Join on Wi-Fi, enter that address, and select Join Game.
4. Confirm the Student and Professor appear connected. The Professor can mark ready; the host confirms and synchronizes that state.
5. Allow the game through the host's firewall on UDP `7000` if prompted. Guest networks or client isolation can block device-to-device traffic even when the Wi-Fi name matches.
6. Leaving the session closes its network connection. If the guest leaves, the host stays available for a replacement; if the host leaves, the guest can retry or return to the menu.

**Current Implementation:** The LAN lobby supports hosting, joining by IP, role assignment, host-confirmed ready status, connection timeout, and disconnection/rejoin handling. Launching Chapter 0 and same-PC split-screen remain future work. Cross-device testing on the intended Wi-Fi is still required; two-process loopback testing alone does not verify a real Wi-Fi network.

### Synchronized Information

- Player role assignment.
- Puzzle input events.
- Puzzle completion.
- Linked environmental states.
- Shared progression.
- Temporal Anchor timer, if implemented.
- Ending trigger.

The players do not need to see each other's regular movement in their respective worlds.

Each device can handle local character movement and rendering independently.

### Critical Risk 3 — State Authority and Desynchronization

**Problem:** Giving Past and Future players independent authority over their own puzzles can produce conflicting progression and linked environment states.

Neither player owns puzzle state, including puzzles located in their own timeline. A central dictionary in `puzzle_manager.gd` holds the authoritative puzzle and linked environment states on the host.

```text
[Either Player Interacts]
    -> request_action(puzzle_id, action, payload)
[Host Validates Sender, Role, Action, and Prerequisites]
    -> Update Central State Dictionary
    -> Increment State Revision
[Host Broadcasts]
    -> apply_puzzle_state(puzzle_id, new_state, revision)
[Both Timelines Render the Confirmed State]
```

- Clients send action requests to host peer 1 using a reliable RPC. Resolve the sender from the RPC context; do not trust a client-supplied role or peer ID.
- The host player's actions enter the same validation function locally. In local split-screen, the input router supplies the assigned local player role to that function.
- Validate the puzzle ID, allowed action, assigned timeline, payload, prerequisites, and current state before accepting a request. Use host-verifiable interaction conditions; movement stays local in this MVP, so client-reported proximity is not authoritative.
- Only the host mutates canonical puzzle state, progression, ending triggers, and the optional final countdown. Clients display those confirmed values.
- Only accept `apply_puzzle_state` from the host. Client copies of the state are read-only for gameplay purposes.
- Apply accepted changes to the host's own world as well as the remote client; a broadcast must not leave the host's presentation stale.
- Neither player changes puzzle state optimistically. A pending indicator is allowed; doors, machinery, puzzle solutions, and timeline effects wait for confirmation.
- Treat state application as idempotent and discard older or duplicate revisions. Validate repeated requests against current state to prevent duplicate unlocks or completion effects.
- Send a full state snapshot after role assignment and before enabling client interactions. Publish every linked change from one accepted action under the same revision.
- On disconnect, stop puzzle interactions and offer a return to the menu. Starting Local Co-op creates a fresh session; live host migration and seamless session conversion are outside the jam scope.

### Critical Risk 1 — WAN Connectivity and Judging Access

**Problem:** Successful loopback (`127.0.0.1`) or LAN tests do not prove internet connectivity. Raw ENet uses UDP and does not provide a complete NAT traversal or relay service. A public IP/port field alone is insufficient for judges on different networks.

**Selected Jam Solution:** ENet over Tailscale, plus a required local split-screen fallback. Tailscale can use relayed connections when a direct connection is unavailable. Both remote players must install and connect Tailscale; this is a documented setup dependency, not installation-free matchmaking. See [Tailscale connection types](https://tailscale.com/docs/reference/connection-types).

**Remote Play Guide to Ship with the Build:**

1. Install Tailscale on both computers and join the same authorized tailnet, or share access to the host device.
2. Confirm the tailnet policy and host firewall permit the game's UDP port. Use one fixed port, `7000`, for the jam build.
3. The Past player selects Host. Show the host's Tailscale address and the game port in the lobby.
4. The Future player selects Join and enters the host's Tailscale address. The game uses port `7000` by default.
5. Confirm both roles appear, then complete a cross-timeline interaction before starting the demo.
6. If connection fails or installing Tailscale is unavailable, return to the menu and choose Local Co-op on one PC.

Do not require judges to configure router port forwarding. Test the exported build across two independent internet connections by the end of Day 1, including a relayed connection when possible. Record the tested setup and keep a copy of these instructions with the release.

GodotSteam/Steam P2P is an alternative only if selected, integrated, and verified early. Do not switch networking stacks during final-day polish. Any alternative tunnel must explicitly support the UDP traffic ENet requires.

### Required Same-PC Co-op Fallback

- Add a Same-PC Split-Screen option alongside Host on Wi-Fi and Join on Wi-Fi in the main menu. Earlier references to "Local Co-op" in this document refer to this same-PC fallback, not LAN play.
- Display Past and Future side by side using two `SubViewportContainer` / `SubViewport` pairs, each with an isolated `World2D`, its own player, camera, and puzzle UI.
- Both players submit actions to the same local authoritative puzzle manager. Reuse online puzzle rules and confirmed state notifications without requiring a network connection.
- Preserve both player roles, clue exchange, and all required puzzle logic. Scope the fallback to simultaneous split-screen; hotseat is not required.
- Keep the fallback playable without Steam, Tailscale, or internet access. Verify it by Day 2 and rehearse switching to it from the menu before judging.

Use an external voice call for online cooperative communication.

---

## 10. Godot 2D Architecture — UPDATED

The project uses native 2D nodes rather than a 3D scene hierarchy.

### Main Nodes

- `Node2D` — World organization.
- `CharacterBody2D` — Player movement.
- `AnimatedSprite2D` — Character animation.
- `CollisionShape2D` — Character and object collisions.
- `Camera2D` — Camera following.
- `TileMapLayer` — Floors and structural layouts.
- `Sprite2D` — Furniture and decorations.
- `Area2D` — Interactive objects.
- `PointLight2D` — Local atmospheric lighting.
- `CanvasModulate` — Global timeline tint.
- `GPUParticles2D` — Temporal effects.
- `CanvasLayer` — UI and dialogue.
- `SubViewportContainer` / `SubViewport` — Local split-screen timeline views.

### Critical Risk 2 — Y-Sorting, Sprite Anchors, and Collision

**Problem:** Godot's Y-sorting uses node positions, not the apparent base of a texture. A sprite centered on the sorting origin can overlap tables and walls incorrectly.

**Required Scene Convention:**

- Enable `y_sort_enabled` on each world's actor-and-prop sorting parent. Keep objects that sort against one another in the same sorting context and at the same `z_index`.
- Place each sorted character or prop scene root at its ground contact point: feet for characters, base contact for furniture. Offset the child `Sprite2D` or `AnimatedSprite2D` so the visible contact point aligns with the root's local `(0, 0)`.
- Godot's `Sprite2D.centered` is a boolean; use pixel offsets or child positioning to align the artwork. Do not treat `(0.5, 0.5)` as a Godot pivot property.
- Anchor to the visible contact point, not the bottom of transparent padding or a painted shadow. Keep this anchor consistent across animation frames and past/future variants.
- For characters and freestanding props, start collision shapes around the bottom 15–25% of the visible sprite height and fit them to the ground footprint. Interaction areas may be larger. Walls and solid barriers must retain collision shapes that block their full intended gameplay footprint.
- Keep floors below the sorted actors and props. Split tall wall or foreground artwork into separate pieces when a single sorting origin cannot represent the intended overlap.

**Owner:** Developer B supplies correctly anchored sprite scenes and footprint collisions; Developer A verifies movement and interaction against them.

**Visual Check:** Walk in front of, behind, and around every table, machine, and wall edge with both characters in both timelines. Check animation frames for anchor drift and ensure switching to a damaged variant preserves its base position.

### Recommended Project Structure

```text
res://
├── scenes/
│   ├── menu/
│   │   └── main_menu.tscn
│   ├── multiplayer/
│   │   └── lobby.tscn
│   ├── characters/
│   │   ├── student.tscn
│   │   └── professor.tscn
│   ├── world/
│   │   ├── past_world.tscn
│   │   └── future_world.tscn
│   ├── rooms/
│   │   ├── signal_lab.tscn
│   │   ├── corridor.tscn
│   │   └── research_core.tscn
│   ├── puzzles/
│   │   ├── frequency_puzzle.tscn
│   │   ├── corridor_puzzle.tscn
│   │   └── temporal_anchor.tscn
│   └── ui/
│       └── dialogue_box.tscn
│
├── scripts/
│   ├── player_controller.gd
│   ├── network_manager.gd
│   ├── game_manager.gd
│   ├── puzzle_manager.gd
│   └── temporal_event_manager.gd
│
├── assets/
│   ├── characters/
│   │   ├── student/
│   │   └── professor/
│   ├── environments/
│   │   ├── shared/
│   │   ├── past/
│   │   └── future/
│   ├── effects/
│   ├── ui/
│   └── audio/
│
└── project.godot
```

The project should use scene instances and reusable scripts to avoid duplicating core gameplay logic between the two timelines.

---

## 11. Art Production Pipeline — UPDATED

### Production Goal

Produce the necessary assets without requiring the team to learn traditional 3D modeling.

### Recommended Workflow

**Step 1 — Visual References**

Use AI image generation to establish:
- Character appearance.
- Art style.
- Laboratory furniture.
- Research equipment.
- Past and future environments.

**Step 2 — Sprite Production**

Generate individual objects with clean silhouettes and transparent backgrounds.

Examples:
- Laboratory desk.
- Computer.
- Bookshelf.
- Radio transmitter.
- Electrical console.
- Door.
- Structural support.
- Temporal machine.

**Step 3 — Past/Future Variations**

Produce two variants of selected objects.

Maintain matching proportions and silhouettes.

The future variant may contain cracks, damage, broken screens, and missing components.

**Step 4 — Godot Integration**

Import PNG sprites into Godot.

Arrange objects using `Sprite2D`, `TileMapLayer`, and scene instances.

Set each scene root to the visible ground contact point and offset the sprite to match. Preserve matching anchors across animation frames and past/future variants.

Add ground-footprint collision shapes as specified in Section 10. For characters and freestanding props, begin with the bottom 15–25% of visible sprite height rather than the full image rectangle.

Developer B must complete the front/behind overlap check before marking an asset ready for integration.

**Step 5 — Atmosphere**

Use lighting, overlays, particles, and sound to differentiate the timelines.

### Asset Guidelines

- Maintain a consistent viewing angle.
- Maintain consistent proportions and pixel density.
- Use transparency for standalone props.
- Align every sprite scene to its visible feet or base contact point; transparent padding and shadows do not define the anchor.
- Keep contact anchors consistent across all frames and timeline variants.
- Deliver props with ground-footprint collisions and verified Y-sorting, following Section 10.
- Avoid inconsistent realistic and cartoon styles.
- Keep interaction targets visually recognizable.
- Prefer reusable sprite variations over generating every room as a single flat image.

### Minimum Sprite Requirements

**Characters:**
- Young student.
- Older professor.
- Basic idle and walk animations.

**Environment:**
- Floor and wall tiles.
- Laboratory desk.
- Chairs.
- Computers.
- Door.
- Research equipment.
- Maintenance supports.
- Reactor or temporal device.

**Future Variants:**
- Damaged wall.
- Broken furniture.
- Ruined machinery.
- Rubble.
- Temporal cracks.

**UI:**
- Interaction prompt.
- Puzzle interface.
- Dialogue box.
- Main menu.
- Timeline indicators.

---

## 12. Narrative Structure

### Opening — The Signal

The student is studying in the university research wing when an unusual signal appears on a nearby instrument.

The professor receives the same signal from the destroyed future laboratory.

The characters begin communicating.

A temporal fracture briefly allows them to see one another.

### Discovery

The players discover that they are the same individual at different points in time.

They begin using information from the future and objects in the past to move through the university.

### Escalation

The environment becomes increasingly unstable.

The professor insists that restoring the temporal system is necessary.

He avoids revealing the full history of the experiment.

### Climax

The players stabilize the first temporal fracture.

### Cliffhanger

A recovered research record identifies the professor as the person who deliberately activated the original device.

The record indicates that he understood the risks.

However, the section explaining his motive is missing or encrypted.

The young student confronts his future self.

The professor does not explain.

Additional fractures appear on the remaining monitoring system.

**End of Demo.**

The professor's reason for activating the device remains a mystery for the full game.

---

## 13. Audio Direction

### Past

- Quiet university ambience.
- Electrical equipment hum.
- Distant campus sounds.
- Calm ambient music.

### Future

- Environmental silence.
- Damaged electrical systems.
- Distant structural sounds.
- Intermittent temporal interference.
- Dark ambient music.

### Shared Events

- Radio connection sound.
- Puzzle interaction cues.
- Temporal synchronization effect.
- Countdown warning.
- Final revelation sound cue.

Audio should provide clear feedback without overpowering player-to-player communication.

---

## 14. MVP Scope

### Required

- 2D sprites with a 2.5D visual presentation.
- Two controllable characters.
- Eight-direction movement.
- Simple interaction system.
- Separate past and future visuals.
- Two-player Host/Join multiplayer with a documented, tested Tailscale setup.
- Offline local split-screen for two players on one PC.
- Host-authoritative puzzle state for both timelines with no optimistic puzzle changes.
- Verified ground-contact anchors, Y-sorting, and footprint collisions.
- Two complete cooperative puzzles.
- A visible change between timelines.
- Short opening and cliffhanger ending.
- Windows export.

### Optional

- Third timed puzzle.
- Advanced sprite animations.
- Additional fracture particles.
- Dynamic lighting transitions.
- Animated cutscene elements.
- Interactive journal.

### Excluded from the Game Jam

- Full 3D models and environments.
- Large open-world campus.
- Complex skeletal animations.
- Combat.
- Full timeline simulation.
- In-game voice chat.
- Multiple endings.
- Extensive dialogue trees.

---

## 15. Development Team — Two People

### Developer A — Systems and Gameplay

**Responsibilities:**
- Multiplayer.
- Tailscale connection flow, setup guide, and connection failure handling.
- Local split-screen input routing and shared puzzle authority.
- Player controller.
- Interaction mechanics.
- Puzzle logic.
- Host validation, confirmed state broadcasts, state snapshots, and duplicate-action handling.
- Timeline event synchronization.
- Game progression and ending logic.

### Developer B — Visuals and World

**Responsibilities:**
- AI-assisted asset generation.
- Sprite preparation.
- Ground-contact anchors, consistent animation/variant offsets, footprint collision shapes, and Y-sorting checks.
- Past/future room layouts.
- Lighting and visual effects.
- UI and dialogue presentation.
- Local split-screen layout and readable per-player puzzle UI.
- Audio integration.

**Both Developers:**
- Review asset consistency.
- Integrate systems.
- Test online connectivity across independent networks and rehearse the offline fallback.
- Verify both timelines remain synchronized and sprites overlap correctly.
- Fix critical bugs.
- Package the final demo.

---

## 16. Three-Day Development Plan

### Day 1 — Technical Foundation

- Create a clean Godot 2D project.
- Implement basic player movement.
- Build the main Host/Join menu.
- Add Local Co-op to the menu and establish separate timeline views and input actions.
- Configure ENet over Tailscale and document the remote setup steps.
- Test an exported host/client build across two independent internet connections; loopback and LAN alone do not satisfy this check.
- Create two placeholder rooms.
- Establish ground-contact roots, a shared Y-sorting convention, and footprint collisions with placeholder sprites.
- Implement the central authoritative state dictionary and request/validate/broadcast flow.
- Synchronize one past-to-future state change, including host-side presentation and client snapshot initialization.

**Milestone:** Both players connect across separate networks and observe the first host-confirmed temporal interaction. The local mode skeleton uses the same puzzle validation path.

### Day 2 — Playable Experience

- Finish the first cooperative puzzle.
- Build the maintenance corridor.
- Implement the second cooperative puzzle.
- Replace critical placeholders with generated sprites.
- Verify contact anchors, footprint collisions, and front/behind sorting in both timelines.
- Complete local split-screen with both required puzzles and separate input/UI routing.
- Integrate the required Game Jam modifier.
- Create a basic complete start-to-finish gameplay path.

**Milestone:** Playable demo with two functional cooperative puzzles in both remote and offline local co-op.

### Day 3 — Visual Polish and Release

- Complete remaining art integration.
- Add timeline-specific lighting.
- Add basic visual and audio effects.
- Implement the narrative ending.
- Add optional third puzzle only if time permits.
- Test rejected and repeated actions, stale state updates, disconnect handling, and host/client state agreement.
- Verify simultaneous interactions cannot unlock progression twice or split the two timelines' state.
- Rehearse the judging setup on separate networks, then restart in Local Co-op with internet disabled.
- Package the Tailscale setup guide and local controls with the demo.
- Export and validate the Windows build.

**Milestone:** Stable demo playable from start to finish.

---

## 17. Acceptance Criteria

The demo is complete when:

1. Exactly two players can connect on separate computers across independent internet connections using the documented Tailscale setup, without router port forwarding.
2. Each player controls the correct character.
3. Characters move smoothly in the 2D world.
4. The past and future clearly look different.
5. Interactive objects provide understandable feedback.
6. Both players are required to solve the puzzles.
7. Changes in the past visibly affect the future.
8. The host alone validates and commits puzzle changes for both timelines; all views apply confirmed state, with no optimistic puzzle mutations.
9. Both players reach the ending.
10. The ending reveals the professor's intentional role while keeping his motive mysterious.
11. The game can be completed in approximately 5–10 minutes.
12. Both required puzzles and the ending are playable in local split-screen on one PC with internet disabled.
13. Local input and puzzle UI are routed to the correct player; both players can move and interact simultaneously.
14. Character feet and prop bases define sorting origins; both characters render correctly around furniture and wall edges in both timelines without anchor drift.
15. Character and freestanding-prop collisions follow their ground footprint, starting around the bottom 15–25% of visible sprite height; walls block their intended full gameplay footprint.
16. Invalid or repeated requests cannot corrupt progression; stale updates are ignored, host and client state agree, and initial snapshots restore the correct client view before interaction.
17. Connection failures return players to a usable menu with a clear Local Co-op option, and the release includes tested remote setup instructions and local controls.

---

## 18. Future Expansion

The full release may include:

- More university buildings.
- Additional historical periods.
- New temporal interaction mechanics.
- Character-specific abilities.
- More complex environmental changes.
- Larger research mysteries.
- Additional cinematic story sequences.
- The professor's complete backstory.
- A final explanation of the catastrophe.

The Game Jam prototype is the opening chapter of a larger story.

---

## 19. Technical References

- [Godot high-level multiplayer: ENet, RPCs, and authority](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html).
- [Godot CanvasItem: Y-sorting and draw order](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html).
- [Godot Sprite2D: centered and offset properties](https://docs.godotengine.org/en/stable/classes/class_sprite2d.html).
- [Tailscale connection types: direct and relayed connections](https://tailscale.com/docs/reference/connection-types).
- [Tailscale private game server setup](https://tailscale.com/docs/use-cases/personal-or-at-home-use/share-private-game-server).

---

**Document Version:** 0.5\
**Narrative:** Approved  
**Visual Direction:** 2D Art with 2.5D Depth — Approved  
**Gameplay and Level Scope:** Updated for Two Developers  
**Technical Risk Plan:** Tailscale Remote Play / Required Local Split-Screen / Ground-Contact Sprite Anchors / Host-Authoritative Puzzle State\
**Next Milestone:** Verify Cross-Network Play, Shared Puzzle Authority, and the Local Co-op Foundation
