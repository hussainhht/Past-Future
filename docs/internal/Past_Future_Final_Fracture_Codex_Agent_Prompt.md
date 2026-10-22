# CODEX AGENT — PAST-FUTURE: THE FINAL FRACTURE

## ROLE / EXECUTION MODE

You are the senior Godot gameplay engineer, technical game designer, level artist, and test engineer taking ownership of **Room C / Level 3 only** for an existing two-player asymmetric co-op game named **Past-Future**. Implement actual working code and assets in the repository, not just a plan, outline, or mockup. Work autonomously within the existing project and tools. You may browse the internet for asset sources/documentation and download suitable legal assets if network access is available, but verify licenses and never invent downloaded files or successful tests. Be efficient and prioritize a stable end-to-end playable vertical slice over speculative systems.

The project is for the **Reboot CHECKPOINT Game Jam 2026**, theme **TWO**. Level 3 concludes **Chapter 0: The First Fracture**. The planned full demo is roughly 5–10 minutes and features two versions of the same person, 31 years apart.

## REQUIRED REPO INSPECTION — BEFORE MODIFYING FILES

1. Inspect `git status --short`, the current branch, actual scene tree and `project.godot`, and the latest relevant source code. Do not assume the supplied documentation reflects the live repo; teammates may have advanced Levels 1 and 2 since the last audit.
2. Read the repository's actual `docs/internal/project_context/00_START_HERE.md`, `docs/internal/project_context/13_AI_HANDOVER.md`, `docs/technical/ARCHITECTURE.md`, `docs/internal/project_context/03_GAME_DESIGN.md`, `docs/technical/GAMEPLAY_SYSTEMS.md`, `docs/technical/SCENES_AND_LEVELS.md`, `docs/technical/ASSETS_AND_VISUALS.md`, `docs/development/KNOWN_ISSUES_AND_TECHNICAL_DEBT.md`, `docs/development/SETUP_AND_TESTING.md`, and `docs/development/ROADMAP.md` where present. Read `docs/design/GAME_DESIGN_DOCUMENT.md`. Resolve differences in favor of actual current code and the explicit specification here for Level 3.
3. Identify the authoritative puzzle/state manager, interaction interface, lobby/network manager, local preview/solo test flow, player scenes and camera/controller, scene transition conventions, resource duplication conventions, and asset/style helpers. Reuse stable existing APIs; only create missing integration primitives if necessary, keeping the smallest backward-compatible surface area.
4. Inventory existing models and reusable assets. Never overwrite the original Student model, animation assets, meshes or materials; if alteration is needed, create a derived copy, use per-instance overrides and document provenance.
5. Respect teammates' work: Level 1 (Signal Laboratory) and Level 2 (Maintenance Corridor, which another developer is building) are outside your scope. Do not redesign, delete, or overwrite those scenes. Build Level 3 independently with a documented entrance/exit integration contract. If there are uncommitted teammate changes, do not reset, stash, checkout, or overwrite them. Do not commit or push without explicit authorization.

### Known project baseline — verify, do not blindly trust

- Godot 4.7.2, GDScript, GL Compatibility renderer, Jolt Physics.
- Networking: ENet UDP 7000; Host/Peer 1 is the Past Student, guest is the Future Professor.
- Active model: `scenes/characters/student_3d_player.tscn`; 77 imported KayKit animation clips; Professor's distinct model may or may not yet exist.
- Existing scene: `scenes/world/spawn_area.tscn` is the Lab. `scenes/world/follow_camera.gd` uses a fixed perspective camera, approximately 35-degree pitch and 48-degree FOV.
- Ground-level root transforms: character and prop roots anchored at Y=0.
- All puzzle state is host-authoritative; clients cannot optimistically mutate canonical state.
- GL Compatibility: do not depend on Forward+ exclusives, Vulkan-only compute, SDFGI or expensive volumetric effects.
- Documentation at the time of audit described PuzzleManager, Room B/C, split screen, and puzzle interactions as incomplete. Check what is actually implemented now.

## THE PRODUCT TO BUILD

**Level title:** THE FINAL FRACTURE
**Level position:** Room C / third and final level of Chapter 0, entered after Room B (but independently launchable now for testing).
**Genre:** Asymmetric cooperative mystery / environmental puzzle with an optional betrayal layer.
**Players:** Exactly two distinct roles/timelines, Student (Past) and Professor (Future).
**Time limit:** Exactly **150 seconds**, configurable in a named constant/export. There is a no-timer evidence-discovery setup phase before either player starts the reactor countdown. Starting the countdown requires a deliberate, clearly signaled interaction, and must be validated by the host. Timeout resets only the Level 3 reactor challenge, not progress in Rooms A/B.
**Four endings:** both cooperate; Student secretly claims the origin; Professor secretly preserves the echo; both secretly override (temporal paradox).

### Canonical lore and emotional premise

An experimental reactor called the **Temporal Core** connected two moments 31 years apart. The original experiment caused the First Fracture and devastated the university facility. The Future Professor is the older version of the Past Student. He deliberately enabled a forbidden experiment to stop his own timeline from disappearing, and has concealed the full truth. At the time of this encounter the machine holds both versions of the same personal identity in an unstable, impossible temporal overlap. The temporal core can permanently anchor only one version of this identity.

The professor is an **anchored temporal echo** outside ordinary linear causality. This rule matters: he can survive a rewritten past if he seizes the anchor; the story must not accidentally imply he would instantly vanish from causal inconsistency before the ending. Sealing the rift with the canonical safe protocol preserves the Student and saves the world, but the current Professor and his memories disappear. He is not a cartoon villain; he is afraid of nonexistence. The Student discovers the truth gradually and may choose to seize the original timeline himself. Neither player should be forced to betray the other, and betrayal should occur through contextual machine operations, never a crude button named 'Betray'. The premise should feel morally complicated but be clear enough to understand within minutes.

Core line on the final reactor readout: **"TWO VERSIONS. ONE IDENTITY. ONE SURVIVOR."**

### Room C: environmental art and stagecraft

Build one coherent medium-sized 3D room, the same footprint in two temporal states rather than unrelated levels. Central focal point: a distinctive reactor pedestal/rotating core with two concentric rings or carefully performant low-poly equivalents. Four functional stations arranged around the room: (1) Past Power Coils, (2) Past Origin Terminal, (3) Future Signal Anchor, (4) Future Continuity Terminal. Add useful set dressing: cables, guardrails, power nodes, consoles, evidence desk, safety stripes, scattered papers, readable screens, and broken architecture in Future. Avoid visual clutter that hides interactables or player visibility under the fixed camera.

Past: warm cream, ochre, olive, maintained tiles, intact equipment and steady lighting. Future: cold cyan/navy/violet, fractured floor, crumbled supports, smoke-like stylized effects, sparks, ruined panels and clearly visible rifts. In Future, break and rearrange significant objects while maintaining recognizable landmarks, so players immediately understand they are in the same room. Art direction is painted stylized low-poly, not photorealism. Use GL Compatibility-friendly particles, geometry, animation and simple shaders, with performance fallbacks. Distinguish functional interactive objects with contextual prompt / clear subtle highlight. Build real collisions, walkable paths, boundaries and safe spawn points. No invisible-blocking debris. Do not force changes to the project's camera angle.

A shared reactor state must drive distinct Past/Future visual representations. When Past changes a coil/cable configuration, a corresponding Future obstruction, light, bridge or conduit visibly changes, creating observable temporal causality. When Future repairs the anchor, an otherwise-hidden Past waveform/alignment readout is exposed. Both roles must perform substantive physical interactions, not simply read out a code to the other.

### Complete level flow and pacing

**Stage 0: Arrival, investigation, and deliberate activation (NO TIMER).**
- Room C can be loaded via a developer-only launch route while Room B is unfinished, and via a public Level 2 completion event once integrated later.
- Players start in separate temporal versions of the room, with correct role-specific avatar, camera, HUD, prompts and atmosphere.
- Offer a few concise optional or mandatory-as-appropriate clues; avoid long unskippable dialogue and reading walls of text. Each role finds DIFFERENT information. Player communication is expected through voice outside the game or in person; do not scope-creep into adding in-game voice chat.
- **Student clue:** a research authorization sheet and a damaged handwritten warning reveal that the Professor knowingly triggered the device and that a "Claim Origin" failsafe exists.
- **Professor clue:** a ruined continuity recording proves the safe seal deletes his current temporal echo and that a forbidden "Preserve Echo" failsafe exists. The Professor knows more than he says.
- Player-specific clues must not be automatically mirrored to the partner. Show readable, skippable inspect UI and keep discovered evidence in a role-local journal for review. Discovering clues should affect contextual text/knowledge, not determine the choice automatically.
- Once at the start console, show an explicit countdown warning; host authorizes activation. Do not start time until this deliberate activation.

**Stage A: Restore Power (suggested target pacing: 150–100s remaining).**
- Student configures **three** power coils/relays using 3D interactable hardware with immediate local visual feedback after host confirmation.
- Professor recovers a damaged routing diagram or dynamic readings and activates a working future receiver; the information alone is insufficient without Professor's own anchor-related interaction.
- An objectively solvable asymmetric sequence requires at least one meaningful action from each player. Incorrect input must be legible and reversible, not randomly punishing. On success, the temporal conduit changes across both world states and Stage B unlocks.

**Stage B: Temporal Synchronization (suggested pacing: 100–40s remaining).**
- Professor repairs/calibrates the **Signal Anchor**, and the Student stabilizes the **Origin Core**. This exposes complementary information, a synchronizable pair of waveforms/phase indicators and a reachable path.
- Include **one readable cooperative synchronization interaction** (e.g. each presses an enabled physical switch within a ~5-second window). It should be forgiving of ordinary LAN latency and straightforward to restart after a mistimed press; it must not require frame-perfect action or combat reflexes.
- Host authority controls progress. Communicate progress on both players' HUDs and through changing reactor animation, sound and lighting. Stage C must begin immediately when solved, not be hard-gated behind a particular clock timestamp.

**Stage C: Identity Lock (final decision, expected during last ~40s).**
- Both players need to operate a final terminal; each sees a different framing and can choose one of two contextually appropriate in-world machine commands. These commands are not presented as a separate binary moral menu.
- Past Student command 1: `GROUND THE CORE` — cooperate, surrender private override and accept the stable continuity protocol.
- Past Student command 2: `CLAIM ORIGIN` — secretly redirect ownership of the temporal anchor toward the younger self.
- Future Professor command 1: `RELEASE THE ECHO` — cooperate, knowingly let his own anchored echo dissolve.
- Future Professor command 2: `PRESERVE ECHO` — secretly redirect the anchor toward the older self.
- Both interfaces should explain technical consequences sufficiently for an informed choice, especially after reading optional evidence. Neither player's precise selection is revealed to the other before resolution. If players discuss their choices over voice, that is a social decision, not a forced disclosure by UI.
- Each player submits a **locked-in choice** once; provide an understandable confirmation step to prevent misclicks. Host verifies role, current stage, legal action and one-vote-per-role. Resolve together only once both decisions have been received. No remote client should be able to spoof the other role or change the ending after lock.
- On timer expiry before resolution, trigger an audiovisual overload and reset only this Room C attempt (consistent across peers); no fifth canonical narrative ending. If both choices are valid and locked before expiry, resolve atomically and do not permit late countdown events to overwrite the ending.

### Four exact branches — implement as actual playable conclusions, not placeholder text

| Student choice | Professor choice | Ending ID | Ending title | Required outcome |
| --- | --- | --- | --- | --- |
| GROUND THE CORE | RELEASE THE ECHO | `trust` | THE LAST GOODBYE | Reactor sealed, world stabilized, Professor knowingly fades out, Student survives. Emotional exchange: "You made a different choice than I did." |
| CLAIM ORIGIN | RELEASE THE ECHO | `student_override` | ERASED FUTURE | Student forcibly anchors himself, Professor and his timeline are erased; Student sees proof he used the same forbidden protocol behind the catastrophe. |
| GROUND THE CORE | PRESERVE ECHO | `professor_override` | STOLEN TOMORROW | Professor forcibly preserves his temporal echo, Student disappears; a changed, eerie future survives with a heavy cost. |
| CLAIM ORIGIN | PRESERVE ECHO | `paradox` | ITERATION 02 | Conflicting claims destabilize the anchor; a concise time-loop visual returns to the first-contact motif and displays `ITERATION 02 DETECTED`. |

All four branches need distinct visuals (tints, rift animation, character visibility, audio cue, camera staging if compatible with fixed camera), a few short lines of dialogue, and a clear `END OF CHAPTER 0` presentation that does not trap the player. Include replay/return-to-menu actions. Finish other endings with a tiny unexplained signal from a **third unknown time**, as a teaser for Chapter 1; do NOT add a third playable character or explain the signal yet. Storyboard sequences can be implemented with in-engine Tween/AnimationPlayer/CanvasLayer without pre-rendered cinematics or costly video assets.

### Narrative content (write clear original English text in the game's tone)

Include role-specific evidence and approximately 8–15 brief lines of key dialogue distributed across discovery, countdown activation, power restoration, synchronization, final decision and branch endings. Use atmospheric, grounded dialogue without giant exposition dumps. Some useful lines or equivalents:
- Student clue: `AUTHORIZATION: Project Continuity / Manual Override Approved — [Professor signature]`
- Warning: `IF HE TELLS YOU THE CORE IS SAFE, ASK WHAT HAPPENS TO HIM WHEN IT STOPS.`
- Professor log: `Echo continuity will be terminated if the core is grounded.`
- Professor: `I didn't tell you everything. I didn't think you would help me if you knew.`
- Student: `You knew what this machine would do?`
- Terminal: `TWO VERSIONS. ONE IDENTITY. ONE SURVIVOR.`

All narrative, stage descriptions and ending results must remain internally consistent with the four-choice state table.

## NETWORKING, STATE, INTEGRATION — MANDATORY

1. **Host authority**: Only Peer 1 validates actions and changes canonical Level 3 states, reactor status, timer state, branching resolution and ending. Clients send reliable, role-scoped requests; the host checks peer identity/role, player proximity and action preconditions where practical, rejects malformed/out-of-phase/duplicate requests and broadcasts monotonically versioned authoritative state.
2. Keep RPC NodePaths and scene hierarchy consistent between peers, and avoid sending references to non-networked Godot Nodes. Never do client-side optimistic state progression. If existing `PuzzleManager` is in place, integrate with it. If missing, implement the smallest general reusable authority foundation that is backward-compatible with the rest of the game. Coordinate with current NetworkManager rather than replacing it.
3. A deterministic stage machine is required: `DISCOVERY -> COUNTDOWN/STAGE_A -> STAGE_B -> STAGE_C -> ENDING` with TIMEOUT reset to DISCOVERY or a clearly signaled RESTART-ready Level 3 substate. Timer starts only once per attempt on host; expiry is host-determined. Countdown display on peers can predict local seconds for smoothness but must periodically resync using host-reported remaining time; do not compare `Time.get_ticks_msec()` across different machines as if they shared a clock. Guard callbacks against stale attempt IDs/revisions.
4. Make simultaneous inputs idempotent. Both players must see identical stage completion and final ending. Choice privacy is role-local until final resolution, but a neutral 'Partner locked in' indicator may be shown if it does not reveal which choice.
5. Pause, reconnect, disconnect and scene change should leave the game in coherent state. Reinitialize Level 3 state on intentional replay; do not leave expired timers or duplicate signal connections alive. Choose and implement a clearly documented behavior for an in-game peer disconnect (e.g., suspend challenge and show a connection-lost dialog rather than silently losing the stage). Do not promise seamless reconnection if the existing network manager cannot support it.
6. Build **Level 3 as a standalone testable scene**, preferably `scenes/rooms/temporal_core.tscn` with associated scripts/resources grouped cleanly. Add a dev-only/test entrypoint that can launch Past and Future without waiting for Room B; development shortcuts must not leak into release gameplay. Document a stable single integration API/trigger for the Room B developer (e.g. `enter_temporal_core()` or a host-driven synchronized scene transition) and how to hook it up when the corridor is complete. A direct level transition must occur on both peers only after host authorization and consistent shared session state.
7. Ensure design is compatible with future same-PC split-screen, but **do not build an entire new split-screen system** or rewrite levels unrelated to this task. Support a useful solo/debug simulation of each role for manual tests where possible, without letting solo/debug role switching bypass live multiplayer security.
8. Avoid deleting or changing existing automated tests; do not attempt to repair deprecated 2D character scenes unless directly necessary. Avoid modifying legacy Student GLB references.

## ASSET REUSE, DOWNLOADS, AND LICENSING

Inspect `assets/`, existing GLBs, KayKit resources, Blender source projects, meshes, animation libraries and shader conventions. Prefer scene inheritance, reuse, and per-instance material overrides. If appropriate and legal, browse trusted asset libraries (e.g. Kenney, KayKit, Quaternius, Poly Haven) for compatible **CC0/public-domain or properly attributed CC-BY** industrial/science-fiction modules, reactor props, mechanical panels or ambience. Browse asset detail pages and verify actual licenses before downloading or incorporating anything. Keep downloaded assets minimal and lean, and record source URL, author, license and imported path in `assets/third_party/LEVEL3_ASSET_CREDITS.md`. Do not scrape paywalled content, remove licensing requirements, or include assets whose reuse permission is uncertain. If internet is unavailable or imports cause problems, build stylized low-poly geometry procedurally in Godot or Blender. No internet dependency at runtime. New assets should not overwrite upstream originals; create copies/derivatives.

Sound design should use legally reusable small files if available, or simple procedural effects when practical. Include: steady Past machine ambience, intermittent Future electrical rattle, distinct reactor phase-complete signal, 10-second warning and 4 distinct ending sting variations. Master level/audio buses and existing settings should continue to behave correctly where supported. Do not claim that a generated silent placeholder is finished SFX.

## UX, GAME FEEL, ACCESSIBILITY, PERFORMANCE

- Keep essential text readable on 1280x720 with a clear Past/Student warm identity and Future/Professor cool identity; no text hidden behind scene geometry. Render timers prominently only after activation.
- Controls must work through the existing input map (`interact`, `inspect`, etc.) or introduce properly named actions if missing; document controls. Do not hardwire every new mechanic to unremappable raw key polling.
- Animate reactor charging, emergency lighting, rings, rifts and transitions deliberately; avoid seizure-risk high-frequency full-screen flashes. Add quality/performance toggles if needed; maintain a smooth low-end laptop experience.
- Ensure gamepad/key hints match actually supported inputs. Avoid decorative unusable switches, false prompts, and portals that look interactable but are not.
- All objectives and discoveries should have short clear feedback and reset cleanly on retries.
- Prioritize the core cooperation sequence and four deterministic endings over unbounded environmental detail.

## IMPLEMENT IN ORDER, VALIDATE EACH PLAYABLE MILESTONE

**Milestone 1 — Foundation and world:** repo audit, architecture decision, standalone Level 3 scene, Past/Future room visuals, collision, correct player/camera, launch method, host/client scene consistency. Basic launch works.

**Milestone 2 — Interactions and discovery:** real proximity interactions, readable role-specific documents, evidence journal, stage display, start console and 150-second host timer with retry flow.

**Milestone 3 — Cooperative puzzles:** three Past power coils, Future routing/receiver repair, visibly causally updated environment, Future Signal Anchor + Past core synchronization, forgiving dual-switch confirmation; both players essential.

**Milestone 4 — Betrayal and endings:** role-specific secret operational commands, locked private votes, authority validation, exactly four branch outcomes and unique cinematic presentation, retry/menu navigation.

**Milestone 5 — Polish and tests:** legal assets/materials/effects/audio, legibility, low-end performance, documentation, LAN multi-process test, gameplay end-to-end verification.

At all milestones, actually implement files and fix verified blockers rather than stopping after a design document. Prefer small coherent edits over broad rewrites. When a step requires access/approval unavailable to you, use an honest fallback and document the limitation; do not stall the entire playable level.

## ACCEPTANCE TESTS AND DEFINITION OF DONE

Deliver and run (where tools/environment allow) the following automated and manual verification:

1. Godot can import the project and parse/load the new Room C without fatal errors; no missing scene dependencies, materials, sounds or GLB files.
2. Existing core character, spawn-room and LAN smoke tests remain green; recognize documented legacy `tests/student_2d.gd` known failure instead of attributing it to your changes.
3. Both roles independently enter the Level 3 scene in separate processes with correct visuals, player control and cameras.
4. Timer stays at 150 before activation, starts exactly once on host after deliberate interaction, decreases and resynchronizes, never becomes negative in display, and timeout resets only Room C challenge.
5. Wrong coil input is reversible; correct action dependencies are enforced; Future gets visibly changed space when Past makes the required alteration; Student receives the previously hidden readout after Future acts.
6. Synchronization works inside its forgiving window, and does not succeed when just one player presses their switch.
7. Both final decisions are submitted once per role; invalid stage, duplicated/replayed requests or role spoofing cannot alter the result.
8. Run the full four-case ending matrix and confirm both peers get the SAME expected ending exactly once, with no later timeout reset.
9. Test interruption/disconnect handling, replay, first-load, stale network packets and rapid repeated interaction.
10. Visual smoke review: no severe occlusion, unreachable props, unreadable clue text, hidden HUD, huge FPS drops or endless glow artifacts.

Create appropriately scoped tests under `tests/` (e.g., an automated Level 3 stage/choice/timer test, authority tests, and a two-process ENet scenario test) using the existing project's test conventions. If GUI/manual checks can't be run in your environment, explicitly mark them **NOT VERIFIED**. Don't say a gameplay build is fully tested merely because scripts parse.

## REQUIRED DELIVERABLES

- Fully playable Godot Room C scene and all supporting production GDScript/scene/assets/UI/audio needed for the defined vertical slice.
- Actual two-timeline, two-role gameplay, networking-authoritative state, real interactive puzzles, 150s timer and four deterministic endings.
- Document `docs/design/LEVEL3_FINAL_FRACTURE.md` (or the repository's equivalent documentation path) including narrative/level structure, files created, live controls, puzzle solution, branch truth table, timer/reset behavior, asset credits, performance notes, test results, and exact instructions for linking Room B when a teammate finishes it.
- Small clear list of any unavoidable blocked items and truthful verification status.
- Final response describing what files changed, how to run Level 3 independently, how to test it with two players, which tests actually passed, how to integrate Room B later and any known risks.

**Success criterion:** Two people can load the same final room in different timelines, explore conflicting clues, activate a 150-second challenge, cooperatively stabilize a reactor through asymmetric physical interactions, privately choose whether to protect themselves, and witness the correct shared one-of-four ending. Preserve all working existing game features and leave Level 2 unmodified.

**Begin by auditing the actual repo, then build the game. Do not stop at a proposal.**
