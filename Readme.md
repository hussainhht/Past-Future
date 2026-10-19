# PAST & FUTURE
## Game Design Document — Version 0.3

**Project:** CHECKPOINT — Reboot Game Jam 2026  
**Status:** Visual Direction Approved / Production Design Updated  
**Engine:** Godot 4.x  
**Genre:** Cooperative Mystery / Puzzle Adventure  
**Visual Style:** Stylized 2D Art with 2.5D Depth — Inspired by Don't Starve  
**Perspective:** Fixed 3/4 Top-Down View  
**Platform:** Windows PC  
**Multiplayer:** Online Co-op, Exactly 2 Players  
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
- Each device displays its own timeline.
- The host manages authoritative puzzle state.

### Engine Technology

Godot 4 high-level multiplayer with `ENetMultiplayerPeer` and RPC communication.

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

The host validates puzzle actions and broadcasts accepted state changes.

### Internet Connectivity

Host/Join must be tested between the intended computers.

Internet play across different networks requires a reachable host, suitable network configuration, or relay/tunnel solution.

Use an external voice call for cooperative communication.

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

Add collision shapes only where necessary.

**Step 5 — Atmosphere**

Use lighting, overlays, particles, and sound to differentiate the timelines.

### Asset Guidelines

- Maintain a consistent viewing angle.
- Maintain consistent proportions and pixel density.
- Use transparency for standalone props.
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
- Two-player Host/Join multiplayer.
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
- Player controller.
- Interaction mechanics.
- Puzzle logic.
- Timeline event synchronization.
- Game progression and ending logic.

### Developer B — Visuals and World

**Responsibilities:**
- AI-assisted asset generation.
- Sprite preparation.
- Past/future room layouts.
- Lighting and visual effects.
- UI and dialogue presentation.
- Audio integration.

**Both Developers:**
- Review asset consistency.
- Integrate systems.
- Test online connectivity.
- Fix critical bugs.
- Package the final demo.

---

## 16. Three-Day Development Plan

### Day 1 — Technical Foundation

- Create a clean Godot 2D project.
- Implement basic player movement.
- Build the main Host/Join menu.
- Test connection between two clients.
- Create two placeholder rooms.
- Synchronize one past-to-future state change.

**Milestone:** Both players connect and observe the first temporal interaction.

### Day 2 — Playable Experience

- Finish the first cooperative puzzle.
- Build the maintenance corridor.
- Implement the second cooperative puzzle.
- Replace critical placeholders with generated sprites.
- Integrate the required Game Jam modifier.
- Create a basic complete start-to-finish gameplay path.

**Milestone:** Playable demo with two functional cooperative puzzles.

### Day 3 — Visual Polish and Release

- Complete remaining art integration.
- Add timeline-specific lighting.
- Add basic visual and audio effects.
- Implement the narrative ending.
- Add optional third puzzle only if time permits.
- Test failure cases and network synchronization.
- Export and validate the Windows build.

**Milestone:** Stable demo playable from start to finish.

---

## 17. Acceptance Criteria

The demo is complete when:

1. Exactly two players can connect on separate computers.
2. Each player controls the correct character.
3. Characters move smoothly in the 2D world.
4. The past and future clearly look different.
5. Interactive objects provide understandable feedback.
6. Both players are required to solve the puzzles.
7. Changes in the past visibly affect the future.
8. Puzzle states remain synchronized.
9. Both players reach the ending.
10. The ending reveals the professor's intentional role while keeping his motive mysterious.
11. The game can be completed in approximately 5–10 minutes.

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

**Document Version:** 0.3  
**Narrative:** Approved  
**Visual Direction:** 2D Art with 2.5D Depth — Approved  
**Gameplay and Level Scope:** Updated for Two Developers  
**Next Milestone:** Build the Godot 2D Prototype and Establish the AI Art Pipeline