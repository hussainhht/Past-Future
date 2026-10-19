
# PAST & FUTURE

## Game Design Document — Version 0.2

**Project:** CHECKPOINT — Reboot Game Jam 2026
**Status:** Core Narrative Approved / Level Design Proposed
**Engine:** Godot 4
**Platform:** Windows PC
**Genre:** Mystery, Cooperative Puzzle Adventure
**Presentation:** 2.5D, side-view movement with 3D environments
**Players:** Exactly 2 — Online Co-op
**Target Demo Length:** 5–10 minutes
**Demo Chapter:** Chapter 0 — The First Fracture

---

## 1. High Concept

Two players control different versions of the same individual, separated by 31 years.

The first is an ambitious 18-year-old university student, passionate about research and scientific discovery.

The second is his 49-year-old future self, now a successful and experienced professor.

An experimental device is deliberately activated by the professor in the future, triggering a catastrophic temporal fracture that reaches into the past. The university, once full of life and scientific activity, becomes a devastated landscape.

The two versions establish contact and must work together across time to repair the fracture.

However, the professor knows more than he is willing to explain.

**Core Hook:** Two versions of one person must collaborate across time, changing the past to repair the future, while one of them hides a dangerous truth.

## 2. Narrative Rules

### Confirmed Decisions

- The professor deliberately activated the experimental device.
- He understood that the experiment involved serious risks.
- His true motive is unknown.
- The student is unaware of the professor's responsibility.
- The professor's involvement is revealed at the end of the demo.
- The full mystery remains unresolved for the complete game.

### Temporal Rules — Proposed

- The two characters are 31 years apart.
- The fracture connects corresponding locations inside the university.
- Selected actions in the past cause predefined changes in the future.
- Some effects occur immediately; others require explicit synchronization.
- Both characters retain their memories when their local environment changes.
- Temporal fractures occasionally allow the characters to see each other.
- Neither character physically travels to the other's era during the demo.

These rules keep the experience understandable and technically manageable.

## 3. Characters

### Character A — The Student

**Age:** 18
**Era:** Past
**Occupation:** University student and research assistant
**Personality:** Curious, intelligent, optimistic, ambitious.

**Gameplay Responsibilities:**

- Calibrate working equipment.
- Manipulate mechanical components.
- Change selected historical object states.
- Activate prototype systems.
- Use information obtained from the future.

### Character B — The Professor

**Age:** 49
**Era:** Future
**Occupation:** University professor and researcher
**Personality:** Serious, mature, experienced, guarded.

**Gameplay Responsibilities:**

- Explore damaged research facilities.
- Restore surviving technology.
- Recover information from old records.
- Interpret technical clues.
- Operate the temporal stabilizer.

The professor knows the truth about his role in the catastrophe, but the game does not reveal that information to his player until the ending. Private clues can suggest that something is being concealed.

## 4. World and Setting

**Location:** A fictional university research campus.

### Past Environment

- Modern laboratories and classrooms.
- Clean study spaces.
- Functional research equipment.
- Natural daylight and ordinary campus lighting.
- Evidence of active student life.
- A functioning prototype experimental facility.

### Future Environment

- Abandoned and destroyed laboratory buildings.
- Collapsed corridors and damaged equipment.
- Dark skies and unstable lighting.
- Temporal energy leaking through fractures.
- Research logs and physical evidence of the catastrophe.
- A damaged version of the same experimental facility.

**Visual Rule:** Corresponding rooms should retain recognizable structural landmarks across both eras.

## 5. Design Pillars

1. **Asymmetric Cooperation:** Both players contribute unique information and actions.
2. **Temporal Cause and Effect:** Player actions have visible consequences across timelines.
3. **Environmental Mystery:** The university communicates the story through its changing condition.
4. **Accessible Puzzle Design:** The game prioritizes reasoning, observation, and communication.
5. **Narrative Suspense:** The demo ends with a meaningful revelation and a larger unanswered question.

## 6. Player Controls

**Movement Model:** Side-view 2.5D using 3D assets and constrained horizontal movement.

| Input | Action                       |
| ----- | ---------------------------- |
| A / D | Move left and right          |
| E     | Interact                     |
| Tab   | Open journal / current clues |
| Esc   | Pause menu                   |

No combat, advanced movement, or precision platforming is required in the MVP.

The camera follows the local character and uses scripted framing for major environmental changes.

## 7. Core Gameplay Loop

1. Explore the active section of the university.
2. Encounter an environmental or technical obstacle.
3. Investigate clues unique to the current timeline.
4. Communicate with the other player.
5. Coordinate interactions across the two worlds.
6. Trigger a temporal consequence.
7. Advance to the next university section.
8. Uncover more information about the catastrophe.

## 8. Level 01 — University Research Wing

**Total Area:** One connected research wing, represented in two eras.

### Area A — Signal Lab

**Past State:** Clean laboratory with functional transmitter and three calibration dials.

**Future State:** Destroyed laboratory containing a damaged receiver and surviving records.

**Puzzle:** Lost Frequency

- Future player restores receiver power.
- Future player discovers the required signal sequence.
- Past player enters the sequence into the transmitter.
- Future player confirms the signal.
- The connection stabilizes and access to Area B is unlocked.

**Success State:** `puzzle_01_complete`

### Area B — Maintenance Corridor

**Past State:** Functional corridor with three adjustable structural supports.

**Future State:** Collapsed corridor with inaccessible passage.

**Puzzle:** Broken Corridor

- Future player retrieves structural maintenance information.
- Past player positions three supports correctly.
- Past player confirms the maintenance configuration.
- The future corridor updates into a repaired state.
- Future player crosses and finds a laboratory access code.
- Past player uses the code to open the corresponding laboratory entrance.

**Success State:** `puzzle_02_complete`

**Temporal Update:** Deferred until maintenance confirmation.

### Area C — Research Core

**Past State:** Working experimental prototype with adjustable power controls.

**Future State:** Damaged temporal reactor and unstable containment equipment.

**Puzzle:** Temporal Anchor

- Both players enter their corresponding research rooms.
- Future player initiates stabilization.
- A shared 90-second countdown begins.
- Past player configures the prototype's energy sequence.
- Future player restores the damaged receiver connections.
- Both players trigger synchronized activation within a short coordination window.
- Temporal instability stops.

**Success State:** `puzzle_03_complete`

**Failure State:** Reset the final puzzle only.

## 9. Temporal Interaction System

Each linked object has explicitly authored states in the relevant timeline.

Examples:

| Linked Element         | Past Interaction                      | Future Consequence               |
| ---------------------- | ------------------------------------- | -------------------------------- |
| Transmitter            | Correctly calibrate signal            | Future receiver reconnects       |
| Structural supports    | Set correct configuration and confirm | Collapsed passage becomes stable |
| Prototype power supply | Configure energy output               | Stabilizer becomes ready         |
| Temporal Anchor        | Complete synchronized activation      | Fracture stabilizes              |

There will be no generalized time simulation, destructible world system, or arbitrary object-history generation in the Game Jam version.

## 10. Multiplayer Design

### Session Structure

- Main Menu → Host Game / Join Game.
- Exactly two connected players.
- One player receives the Past role.
- The other receives the Future role.
- Both players confirm readiness.
- Each player loads their timeline version of the Research Wing.

### Proposed Technical Architecture

**Godot Networking:** `ENetMultiplayerPeer` with Godot's high-level multiplayer API and RPCs.

**Authority:** The host maintains authoritative puzzle states, role assignments, timer state, and level progression.

**Synchronization:**

- Reliable network messages for puzzle interactions and state changes.
- Independent local camera and character movement.
- Shared puzzle progression controlled by the host.
- Late or repeated event messages must not trigger duplicate puzzle completion.

**Connectivity:** Cross-network internet testing must occur early. A reachable host, suitable tunnel, or relay solution is required when direct peer connectivity is unavailable.

**Disconnect Handling:** The MVP may pause gameplay and return both players to the lobby if either player disconnects. Full reconnection is outside scope.

**Communication:** Players communicate through an external voice call. Built-in voice chat is not part of the MVP.

## 11. Narrative Events

### Opening — First Contact

The student is conducting research when the university's equipment receives an impossible signal.

The professor, in the ruined future laboratory, establishes contact with his younger self.

A brief temporal fracture allows them to see each other.

### Investigation

The players restore their connection, reconstruct a destroyed path, and reach the experimental core.

Each solved puzzle provides evidence that the two environments are linked.

### Climax

The players stabilize the first Temporal Anchor moments before the surrounding reality collapses.

### Ending — Confirmed Narrative Reveal

After stabilization, a hidden research record becomes accessible.

It identifies the professor as the authorized researcher who deliberately initiated the experiment.

The record confirms intentional activation, but the motive section is missing or encrypted.

The student realizes that his future self has withheld the truth.

The professor refuses to reveal his reason.

The connection begins to distort.

A final display indicates that additional temporal fractures remain.

**End of Demo.**

## 12. Visual Direction

### Past

- Warm natural lighting.
- Green environmental accents.
- Clean surfaces and recognizable campus materials.
- Subtle scientific instrumentation.
- Peaceful research-campus ambience.

### Future

- Desaturated colors with blue and violet highlights.
- Darkened interiors.
- Damaged materials and abandoned equipment.
- Fractured light and distortion effects.
- Low-frequency electrical and environmental ambience.

### Shared Visual Language

Linked objects should have recognizable shapes in both timelines. Successful time changes should include a clear animation or sound cue.

## 13. Audio Direction

- Ambient university sounds in the past.
- Environmental silence, mechanical hum, and temporal interference in the future.
- Unique interaction sounds for clues and terminals.
- Increasing audio tension in the final timed puzzle.
- A distinct sound when temporal changes are synchronized.
- Audio distortion during the final revelation.

## 14. Technical Scene Structure — Proposed

```text
res://
├── scenes/
│   ├── main_menu.tscn
│   ├── lobby.tscn
│   ├── player.tscn
│   ├── past_research_wing.tscn
│   ├── future_research_wing.tscn
│   ├── puzzle_01_ui.tscn
│   ├── puzzle_02_ui.tscn
│   ├── puzzle_03_ui.tscn
│   └── ending.tscn
├── scripts/
│   ├── network_manager.gd
│   ├── game_state.gd
│   ├── player_controller.gd
│   ├── interaction_component.gd
│   ├── puzzle_manager.gd
│   └── temporal_event_manager.gd
├── assets/
│   ├── models/
│   ├── materials/
│   ├── audio/
│   └── ui/
└── project.godot
```

The shared game state should track:

- Connected players and assigned roles.
- Puzzle progression.
- Individual linked-object states.
- Final puzzle timer.
- Temporal fracture stability.
- Demo completion.

## 15. MVP Scope

### Must Have

- Two-player host/join functionality.
- Separate past and future environments.
- Basic movement and interaction.
- Three complete cooperative puzzles.
- State synchronization across players.
- At least one clearly visible past-to-future environment change.
- Final timed sequence.
- Short opening and ending presentation.

### Should Have

- Brief fracture visual effects.
- Character dialogue and subtitle text.
- Basic journal or clue display.
- Music and interaction sounds.
- Visual distinctions between the eras.

### Outside MVP

- Full university campus.
- NPCs and dialogue trees.
- Combat systems.
- Dynamic timeline simulation.
- Multiple branching endings.
- Full voice acting.
- In-game voice chat.
- Advanced cinematics.
- Matchmaking and persistent servers.

## 16. Development Plan — Three-Day Game Jam

### Day 1 — Playable Foundation

- Initialize Godot project and Git repository.
- Create prototype player movement.
- Set up Host/Join networking.
- Verify connection between two separate devices.
- Create greybox versions of the three university areas.
- Implement a simple synchronized interaction.
- Complete the first puzzle's functional logic.

### Day 2 — Core Experience

- Implement the second puzzle and environmental state change.
- Implement the third puzzle and synchronized countdown.
- Add scene progression and basic narrative events.
- Integrate the announced Game Jam modifier if required.
- Run a complete gameplay test with placeholders.

### Day 3 — Presentation and Stability

- Apply the two eras' visual styles.
- Add essential sound and interface feedback.
- Add the opening and cliffhanger ending.
- Test multiplayer failure cases.
- Fix progression blockers and softlocks.
- Package and test the final build on two computers.

## 17. Acceptance Criteria

The demo is complete when:

1. Two users can host and join a session on separate computers.
2. Each player receives and controls the correct timeline character.
3. Both players can complete the three puzzles through cooperation.
4. Past-to-future changes occur reliably on the correct clients.
5. The final countdown is consistent between both players.
6. Failure in the last puzzle does not erase earlier progression.
7. Both players can reach and view the ending.
8. The ending communicates the professor's deliberate involvement without revealing his motive.
9. A complete run takes approximately 5–10 minutes for players familiar with the controls.

## 18. Post-Jam Expansion

The full game can expand into additional campus locations and eventually the surrounding world.

Possible features include more complex historical consequences, additional temporal fractures, the professor's full backstory, new environmental puzzles, and the investigation into why he deliberately activated the device.

The prototype should establish the core experience without attempting to resolve the entire mystery.

---

**Document Version:** 0.2
**Narrative Decisions:** Approved
**Level Mechanics and Technical Design:** Proposed — Pending Playtesting
**Next Milestone:** Godot Greybox Level and First Networked Puzzle
