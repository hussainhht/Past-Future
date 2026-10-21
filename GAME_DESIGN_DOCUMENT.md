# THE OTHER ME (formerly PAST & FUTURE)
## Game Design Document — Version 0.17

**Project:** CHECKPOINT — Reboot Game Jam 2026  
**Status:** Visual Direction Approved / Technical Risk Mitigations Defined\
**Engine:** Godot 4.x  
**Genre:** Cooperative Mystery / Puzzle Adventure  
**Visual Style:** Original Skinned 3D Character with KayKit Animations and Painted Furniture\
**Perspective:** Fixed-Angle Perspective View\
**Platform:** Windows PC  
**Multiplayer:** Two-Computer LAN Co-op; Remote Play via Tailscale; Same-PC Split-Screen Fallback\
**Demo Duration:** 5–10 minutes  
**Demo Chapter:** Chapter 0 — The First Fracture

**Story continuation:** [Chapter 0 story and Level 02](docs/STORY_AND_LEVEL_02.md) contains the current runtime audit, detailed Maintenance Corridor design, dialogue beats, and the required ending. Level 02 and the compact Core finale are now implemented; see [Level 02 implementation and tests](docs/LEVEL_02.md) for the playable route, private choices and evidence-dependent endings. Earlier implementation summaries below describe older development milestones.

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

The current prototype uses an original skinned low-poly student with genuine KayKit animations, painted 3D furniture, and a fixed-angle perspective camera. The illustrated 2D version is preserved in checkpoint commit `244b42a` and its original asset scenes.

**Characteristics:**

- Original stylized 3D student with a large rounded head, simple expressive face, ochre jacket, and readable accessories.
- Stylized 3D furniture with flat painted face colors.
- Angled top-down perspective.
- Layered foreground and background objects.
- Depth sorting so characters can walk behind and in front of furniture.
- Soft shadows and atmospheric lighting.
- 77 imported KayKit clips from five animation categories; gameplay uses idle, walk, run, interaction, pickup, and item-use clips.
- Environmental distortion around temporal fractures.

The aesthetic should be mysterious, atmospheric, readable, and distinctive.

The student translates the supplied reference into simple, rounded low-poly forms: dark swept hair, ochre jacket, cream shirt, charcoal trousers, boots, ID, right-hip messenger bag, and left-wrist watch. All visible mesh geometry is original. KayKit supplies the unchanged 23-joint Rig_Medium skeleton and animation samples. The art pass remains subject to visual review.

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

The world uses a simple 3D ground plane, a skinned 3D character, and solid 3D furniture.

- Movement occurs on the X/Z ground plane; Y represents height.
- A `Camera3D` follows the local player with perspective projection, a 48-degree field of view, and a fixed 35-degree downward pitch. Players cannot rotate the camera or change projection.
- The character uses a skinned mesh and Skeleton3D, turns smoothly toward camera-relative travel, and blends imported KayKit clips through AnimationPlayer. Furniture uses world-aligned meshes with visible tops, fronts, and sides.
- 3D depth testing handles front/behind overlap as players walk around furniture. Screen-Y sorting is not used for the gameplay world.
- Low walls, floor meshes, and ground shadows provide basic structure. Both workbenches, both cabinets, and the console use solid painted models.

The original student mesh is authored in `tools/build_student_kaykit.py` and exported with the actual KayKit skeleton and animation tracks. Furniture uses simple Godot meshes with painted face shading. Directional key/ambient lighting makes the character readable. The cutout student and older articulated 3D model remain alternatives.

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

The student includes 77 genuine KayKit clips from General, MovementBasic, MovementAdvanced, Simulation, and Tools. F2 opens a 3D studio with clip selection, front/side/back views, arbitrary character rotation, speed, pause, and pose scrubbing. Gameplay uses idle, walk, run, Interact, PickUp, Use_Item, and a holding pose. These actions currently demonstrate presentation without modifying inventory or puzzle state.

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

The active student model, previews, manifest, and editing guide are in `assets/characters/student_3d/`. The builder creates all visible geometry and skin weights from source; it preserves KayKit Rig_Medium rest transforms, inverse bind matrices, and animation samples. Unchanged CC0 animation GLBs and the creator license are in `assets/third_party/kaykit_character_animations/`, excluded from direct Godot import. The supplied image remains at `assets/characters/references/student_reference.png`. The complete prior 2D version is saved at commit `244b42a`, and both earlier character alternatives remain available.

Complex skeletal animation is not required for the prototype.

---

## 4. Camera and Movement — UPDATED

### Camera

Use a perspective `Camera3D` at a fixed 35-degree downward pitch and a 48-degree field of view, attached to a follow rig. It follows the local player without rotating. There are no player camera-rotation or projection-switch controls.

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
| F | Interact with nearby object, when implemented |
| R | Respawn at the current spawn marker |
| Tab | Show available clues, if implemented |
| Esc | Open pause menu |

Movement is relative to the camera's horizontal right/forward axes. Normalize diagonal movement so diagonal travel has the same speed as movement along one axis.

Local split-screen uses separate input actions: Past uses WASD + F; Future uses arrow keys + Enter. Each viewport routes interaction UI input only to its assigned player. Verify simultaneous movement and interaction on the judging keyboard during Day 1.

### Interactions

Interactive equipment will use `Area3D` detection around its ground footprint.

When a player approaches an object, an interaction prompt appears.

Examples:
- F — Use Terminal
- F — Read Document
- F — Activate Machine
- F — Adjust Support

Character and furniture meshes use depth testing. Character movement retains a small ground collision footprint; furniture, walls, blocked passages, and machines use 3D collision volumes around their physical footprints.

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

**Location:** Maintenance Corridor / service gallery\
**Subtitle:** What We Leave Standing\
**Estimated Duration:** 3–4 minutes

After the Signal Laboratory's north door, both players enter their own version of the maintenance gallery. Public exits are sealed by containment shutters. The Professor's route to the Core is blocked by a fallen slab; the Student has intact service controls but no Core authorization.

**Phase 1 — Restore service power:**
- The Professor reads the surviving isolation plate and directs the Student to the SERVICE loop.
- The Student isolates and latches that circuit in the Past, preserving a usable bypass in the Future.
- The Professor charges a local emergency battery with a hand crank and switches it on. Power is generated locally, not sent across time.

**Phase 2 — Brace the future:**
- The Professor reads the newly powered diagnostic diagram and observes the broken structure.
- The Student reads the intact stage legend and sets three symbol-marked supports.
- Their combined information yields Circle 3 / Triangle 2 / Square 1: BRACE / PIN / RETRACT.
- A confirmed safe plan secures the slab as a broad crossing. Invalid plans are refused without resetting earlier progress.
- The Professor crosses to the maintenance archive. Solved supports lock so the crossing cannot be removed underneath him.

**Phase 3 — Recover Core access:**
- A surviving personnel record and a private detail about their shared watch confirm the Professor is the Student, 31 years later.
- The Professor supplies the archive's service code, 3142. The Student authorizes the intact Core entrance; the Professor operates the damaged door's manual release.
- A partial audit indicates an acknowledged containment warning and a manual override. The full operator record is inside the Core.

**Result:** Both roles can enter the Temporal Research Core. Their radios and Level 01 completion persist; the optional laboratory receiver relay is not an exit prerequisite.

**Purpose:** Deliver a visible Past-to-Future change, give both players essential physical actions, and turn the anonymous radio partnership into a personal conflict.

**Implemented choices:** Either character can claim a local reserve that benefits their equipment while disrupting the remote auxiliary feed. The Professor can extract the recorder battery for early Core-door power, erasing evidence. Repairing both bypass ends restores shared power and permits preservation. The final audit reflects the recording decision; shortcut history persists. See [Level 02](docs/LEVEL_02.md).

The exact layout, authored clue table, dialogue, failure behavior, transition requirements, and finale are specified in [Story and Level 02](docs/STORY_AND_LEVEL_02.md). For the required two-level jam build, a compact Core control alcove supplies the stabilization and cliffhanger below; the optional full Puzzle 03 can expand that finale later.

### Puzzle 03 — Temporal Anchor

**Location:** Temporal Research Core  
**Estimated Duration:** 2–3 minutes

**Past Player:**
- Configures energy output.
- Activates the anchor transmitter in stabilization mode.

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
4. Confirm the Student and Professor appear connected. The Professor marks ready; the Student selects Start Game. Both enter the spawn laboratory in their assigned timelines.
5. Allow the game through the host's firewall on UDP `7000` if prompted. Guest networks or client isolation can block device-to-device traffic even when the Wi-Fi name matches.
6. Leaving the session closes its network connection. In the lobby, if the guest leaves, the host stays available for a replacement. During gameplay, losing either player blocks exploration until returning to the menu and starting a fresh session.

**Current Implementation:** The LAN lobby supports hosting, joining by IP, role assignment, host-confirmed ready status, and a host-authorized transition into a temporary spawn laboratory. Each device displays its own timeline and independently controls one original skinned 3D student prototype character. Connection loss blocks movement and offers a return to the menu. Chapter 0 puzzles and same-PC split-screen remain future work. Cross-device testing on the intended Wi-Fi is still required; two-process loopback testing alone does not verify a real Wi-Fi network.

**Spawn Area Preview:** Play Together → Explore the Lab opens the same room without networking. Use WASD or arrows to move, Shift to run, F for an interaction animation, I for the item-use animation, E to pick up/put down a demonstration document, R to respawn, and Esc to pause. F2 or the Character button opens the animation studio. The camera follows at a fixed angle. The preview's View Future / View Past button changes the local timeline appearance; this switch is unavailable during LAN play.

**Current Visual Direction:** Both tables, both cabinets, and the console use solid 3D models with flat painted face shading and Past/Future palettes. The camera keeps a fixed 35-degree downward pitch and perspective projection; Q/E and P do not change the view; E now triggers the pick-up/put-down animation. Reusable models are `scenes/props/table_visual.tscn`, `cabinet_visual.tscn`, and `console_visual.tscn`, selected by the Kind property on `scenes/props/lab_prop.tscn`.

**Character Rig:** `scenes/characters/student_3d_player.tscn` supplies a grounded collision body, shadow, turning visual root, and original skinned mesh. The standalone GLB contains 23 KayKit joints and 77 genuine animation clips. Animation resources and jacket materials are independent for each player. Both timelines currently share the student with subtle timeline tinting; the older professor remains future work. The demonstration document and action animations do not implement puzzle interactions or inventory. `assets/characters/student_3d/README.md` documents provenance, visual study, building, previews, and remaining polish.

The replaceable room is `scenes/world/spawn_area.tscn`. Move its `SpawnPoint` marker to change the initial position, or rearrange the reusable furniture instances under `Actors`. The player scene is `scenes/characters/student_3d_player.tscn`; its origin remains at the character's feet and its small footprint handles collision. `SpawnPoint` is a `Marker3D` on the ground plane. `Actors` contains grounded collision bodies, solid furniture meshes, and a skinned 3D character; `CameraRig` provides fixed-angle perspective following using `scripts/world/follow_camera.gd`. Each device follows its own player with `Camera3D`; movement is not mirrored into the other timeline.

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
- Display Past and Future side by side using two `SubViewportContainer` / `SubViewport` pairs, each with an isolated `World3D`, its own player, camera, and puzzle UI.
- Both players submit actions to the same local authoritative puzzle manager. Reuse online puzzle rules and confirmed state notifications without requiring a network connection.
- Preserve both player roles, clue exchange, and all required puzzle logic. Scope the fallback to simultaneous split-screen; hotseat is not required.
- Keep the fallback playable without Steam, Tailscale, or internet access. Verify it by Day 2 and rehearse switching to it from the menu before judging.

Use an external voice call for online cooperative communication.

---

## 10. Godot 2.5D Architecture — UPDATED

The gameplay world uses simple 3D geometry and physics, with a skinned 3D character and painted 3D furniture. Menus and HUD remain native 2D UI.

### Main Nodes

- `Node3D` — World and camera-rig organization.
- `CharacterBody3D` — Camera-relative movement on the ground.
- `Skeleton3D` / `Skin` / `MeshInstance3D` — Original weighted mesh bound to the actual KayKit Rig_Medium skeleton.
- `AnimationPlayer` — Imported KayKit locomotion and action clips, with blending and per-player resources.
- `SubViewport` — Isolated 3D character studio; the old 2D alternative also uses one for its billboard.
- `Sprite3D` — Floor spawn marker.
- `StaticBody3D` / `CollisionShape3D` — Ground, wall, and object-footprint collision.
- `Camera3D` — Fixed-angle perspective following.
- `Marker3D` — Editable spawn position.
- `MeshInstance3D` — Solid furniture, simple floor, low boundaries, and ground shadows.
- `ShaderMaterial` — Floor grid, painted furniture face shading, and past/future palette.
- `Area3D` — Future interaction detection.
- `CanvasLayer` / `Control` — HUD, dialogue, and menus.
- `SubViewportContainer` / `SubViewport` — Planned same-PC split-screen views with separate 3D worlds.

### Critical Risk 2 — Ground Anchors, Character Rigs, and Depth

**Problem:** Character feet and furniture bases must remain aligned with the floor. Mismatched collision boxes prevent walking naturally around furniture. The retained 2D alternative also requires consistent ground anchors and alpha cutouts.

**Required Scene Convention:**

- Place each character/prop root at its ground contact point on X/Z. Keep sprites attached to that anchor and exclude transparent padding from their visible-base offset.
- Keep the skinned character under a grounded visual root and turn it toward camera-relative travel. Align visible feet with the collision origin and blend locomotion clips without resetting the same clip every frame. Furniture meshes stay fixed in world space.
- Use simple painted mesh materials for furniture. Each instance has independent materials so Past/Future recoloring cannot affect another prop.
- Enable depth testing and alpha-cutout rendering for character cards. Transparent texture regions must not block the objects behind them. Furniture meshes remain opaque.
- Use 3D collision shapes around furniture footprints and body height, independent of camera orientation. Collision volumes stay fixed in world space.
- Keep ground shadows on the actual floor. Match anchors across later character frames and past/future variants.
- Use low boundary geometry in the prototype to keep the player visible near walls. More elaborate wall fading can come later.

**Owner:** Developer B supplies grounded character and furniture visuals; Developer A maintains collision footprints, camera-relative controls, and stable depth overlap.

**Visual Check:** Walk around tables and machinery in both timelines. Confirm that the student turns toward travel, limbs move while walking and settle while idle, furniture has visible volume, ground anchors stay attached, front/behind overlap is correct, and the camera follows without changing its viewing angle.

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

Use the original skinned student and reusable Godot furniture scenes. Keep the mesh builder, supplied reference, KayKit source license, unchanged source animation GLBs, and provenance manifest together for reproducible iteration.

Arrange ground meshes, solid furniture scenes, and the reusable skinned student scene in the 3D world. Keep the student visual root separate from its collision body.

Set each scene root to the visible ground contact point and position its geometry to match. Preserve matching anchors across animation frames and past/future variants.

Add 3D ground-footprint collision shapes as specified in Section 10. Fit these to the physical base of an object rather than its entire camera-facing sprite rectangle.

Developer B must complete the front/behind overlap check before marking an asset ready for integration.

**Step 5 — Atmosphere**

Use lighting, overlays, particles, and sound to differentiate the timelines.

### Asset Guidelines

- Maintain a consistent viewing angle.
- Maintain consistent proportions and pixel density.
- Use solid furniture meshes and a skinned 3D student. The retained 2D alternative uses transparent RGBA character artwork.
- Align every sprite scene to its visible feet or base contact point; transparent padding and shadows do not define the anchor.
- Keep contact anchors consistent across all frames and timeline variants.
- Deliver painted furniture meshes with ground-footprint collisions and verified depth overlap, following Section 10.
- Avoid inconsistent realistic and cartoon styles.
- Keep interaction targets visually recognizable.
- Prefer reusable sprite variations over generating every room as a single flat image.

### Minimum Visual Asset Requirements

**Characters:**
- Young student.
- Older professor.
- Student: 77 genuine KayKit clips imported on the original mesh; professor model remains to be produced.

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

The complete beat-by-beat continuation is in [Chapter 0 story and Level 02](docs/STORY_AND_LEVEL_02.md). This section defines its chapter arc.

### Opening — The Signal

The Student investigates an unusual signal in the working university laboratory. The Professor searches its ruined counterpart, 31 years later. Acquiring both radios and calibrating the array to 67 MHz establishes their connection and releases the north containment door.

Existing blackboard and notebook clues suggest deliberate involvement. Neither the Student nor the player should treat the later discovery of an override as the first hint that this was not an accident.

### Discovery — What We Leave Standing

The door leads to the maintenance gallery. The Professor cannot cross the ruined walkway; the Student cannot authorize the Core entrance. The Professor explains that the Core anchor must be stabilized to hold their connection and contain the spreading instability.

Together they restore the service bypass and secure the structural supports. The Professor watches the Student's actions change what survived. An archive record and their shared watch confirm they are the same person. His old memories do not predict this newly altered route, so cooperation remains necessary.

### Escalation — The Override

The archive provides Core access and a partial incident record: someone acknowledged a containment warning and overrode automatic shutdown. The Professor insists the complete audit is inside. The Student follows because they need the anchor and because he now wants an answer from his future self.

### Climax — The First Fracture

Both characters reach the Core. The Student arms its intact transmitter; the Professor connects his local emergency receiver. Their confirmed actions stabilize the local fracture.

In the required two-level jam build, this is a short finale in a Core control alcove, with latched actions and no narrow synchronization window. The optional full Temporal Anchor puzzle can add the coil/receiver challenge without changing the ending. The ending must remain deliverable without the optional room or timer.

### Cliffhanger — Who Authorized It

When the recording is preserved, stabilization recovers the Future terminal's activation audit and makes the same authenticated record readable to both characters through the link. It identifies the Professor as the operator who authorized activation, acknowledged containment-failure risk, and disabled automatic abort. It does not place the 49-year-old Professor on the Student's calendar date.

With preserved evidence, the Student asks: **“You knew. Why did you do it?”** If the Professor extracted the recorder cell, the authorization remains erased and the Student instead confronts him about the extraction log. The Professor does not explain.

The recovered monitoring map reveals other unresolved fractures and a second signal. Their local success remains intact; the map exposes a larger existing crisis rather than undoing their work.

**END OF CHAPTER 0.** The Professor's motive remains a mystery for the full game.

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

- Original skinned 3D characters and painted furniture with a fixed-angle perspective presentation.
- Two controllable characters.
- Eight-direction movement.
- Simple interaction system.
- Separate past and future visuals.
- Two-player Host/Join multiplayer with a documented, tested Tailscale setup.
- Offline local split-screen for two players on one PC.
- Host-authoritative puzzle state for both timelines with no optimistic puzzle changes.
- Verified ground-contact anchors, billboard depth testing, and footprint collisions.
- Two complete cooperative puzzles.
- A visible change between timelines.
- Short opening and cliffhanger ending.
- Windows export.

### Optional

- Third timed puzzle.
- Further hand-authored sprite animation polish and directional transitions.
- Additional fracture particles.
- Dynamic lighting transitions.
- Animated cutscene elements.
- Interactive journal.

### Excluded from the Game Jam

- Detailed realistic 3D character/environment modeling. The student uses a supplied KayKit skeleton; simple ground and boundary geometry is required.
- Large open-world campus.
- Authoring a full custom skeletal animation library; reuse KayKit clips for the student.
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
- Ground-contact anchors, consistent animation/variant offsets, footprint collision shapes, and billboard depth checks.
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

- Establish a fixed-angle 3D world with a simple ground plane, skinned characters, and painted furniture meshes.
- Implement basic player movement.
- Build the main Host/Join menu.
- Add Local Co-op to the menu and establish separate timeline views and input actions.
- Configure ENet over Tailscale and document the remote setup steps.
- Test an exported host/client build across two independent internet connections; loopback and LAN alone do not satisfy this check.
- Create two placeholder rooms.
- Establish ground-contact roots, a shared painted shading and depth-testing convention, and footprint collisions with placeholder meshes.
- Implement the central authoritative state dictionary and request/validate/broadcast flow.
- Synchronize one past-to-future state change, including host-side presentation and client snapshot initialization.

**Milestone:** Both players connect across separate networks and observe the first host-confirmed temporal interaction. The local mode skeleton uses the same puzzle validation path.

### Day 2 — Playable Experience

- Finish the first cooperative puzzle.
- Build the maintenance corridor.
- Implement the second cooperative puzzle.
- Refine critical placeholder characters and props while keeping consistent proportions and shading.
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
3. Characters move smoothly on the ground plane with camera-relative controls, with a fixed camera angle.
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
14. Character feet and prop bases define grounded origins. Walking around objects changes perspective and occlusion while reusing the skinned character and furniture meshes, without anchor drift or camera rotation, in both timelines.
15. Character and freestanding-prop 3D collisions follow their ground footprints and stay fixed as the camera follows the player; walls block their intended full gameplay footprint.
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

- [KayKit Character Animations — free CC0 source clips](https://kaylousberg.itch.io/kaykit-character-animations).
- [KayKit Adventurers — character construction study](https://kaylousberg.itch.io/kaykit-adventurers).
- [Godot skeletal animation retargeting and rest transforms](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html).

- [Eight-direction character rigging in Spine 2D — Armanimation](https://www.youtube.com/watch?v=pxP87em31e8).
- [Creator discussion: shared rigs, directional poses, and animation continuity](https://en.esotericsoftware.com/forum/d/24092-best-practices-of-rigging-8-directional-character-in-spine-2d).
- [Godot high-level multiplayer: ENet, RPCs, and authority](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html).
- [Godot SpriteBase3D: billboarding, offsets, and alpha cutouts](https://docs.godotengine.org/en/stable/classes/class_spritebase3d.html).
- [Godot Camera3D: orthographic and perspective projection](https://docs.godotengine.org/en/stable/classes/class_camera3d.html).
- [Tailscale connection types: direct and relayed connections](https://tailscale.com/docs/reference/connection-types).
- [Tailscale private game server setup](https://tailscale.com/docs/use-cases/personal-or-at-home-use/share-private-game-server).

---

**Document Version:** 0.17\
**Narrative:** Established premise retained; detailed Level 02 continuation authored for review\
**Visual Direction:** Original Skinned 3D Student with KayKit Animations and Painted Furniture\
**Gameplay and Level Scope:** Updated for Two Developers  
**Technical Risk Plan:** Tailscale Remote Play / Required Local Split-Screen / Grounded Character/Prop Meshes / Fixed Perspective Camera / Host-Authoritative Puzzle State\
**Next Milestone:** Playtest the connected two-level chapter, private choices, recovery and finale
