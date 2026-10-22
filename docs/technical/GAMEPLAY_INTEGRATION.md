# Main Menu and Signal Laboratory integration

The project now launches its actual playable **Signal Laboratory** from the existing Main Menu. `project.godot` already points to `scenes/menu/main_menu.tscn`; that entry point and its settings/navigation design are preserved. Play → **PLAY THE LAB / SOLO TEST**, or the existing Host/Join/Ready lobby, enters `scenes/world/spawn_area.tscn`.

The merged scene reuses the painted floor, mesh furniture, collision footprints, spawn marker and tracking camera, with the authored `SignalLab` environment providing timeline dressing, lighting, radio pickups, console and puzzle screens. `laboratory_gameplay.tscn` binds character controls and dialogue to those same devices, with one radio, interaction rig, audio system and set of screens. The main game does not load a sandbox.

## How to play

1. Open `project.godot` in Godot 4.7.2 and press **F5**. Select **PLAY**, then **PLAY THE LAB / SOLO TEST**.
2. You begin as the Student in the Past. WASD/arrows move, Shift runs, and **F** interacts. Approach the **left workbench** and acquire the handheld radio. Its pickup animation completes before ownership is granted, and the radio appears in the right-hand socket. Enter or clicking the dialogue panel reveals/advances the Student's discovery dialogue.
3. Use **PLAY AS PROFESSOR** in the header, or **T**, to switch solo roles. This loads the finished Professor character, retints the real environment for the Future, and binds camera, interactions and radio to that one local character.
4. Acquire the Professor's radio from the **reading corner in the south-west**. Read the recovered research log at the **rear console**: the temporal frequency is **67 MHz**. Escape closes the document. The log also triggers the existing Future-specific discovery sequence.
5. Switch back to Student and approach the **main computer at the rear centre**. Press F, enter a frequency, and select **CALIBRATE SIGNAL**. Incorrect values give retry feedback; enter **67** to establish the carrier once both radios have been acquired.
6. The terminal, HUD and rift show **TEMPORAL RADIO LINK ESTABLISHED**. Close the terminal to continue the actual DialogueDirector radio conversation, alternating Student and Professor with typewriter text, connection status and transmission cues.
7. The optional **receiver relay beside the left cabinet** now becomes solvable by the Student. Its confirmed completion triggers another shared radio sequence. This separate puzzle never gates the original radio connection or opens a door.
8. Approach the **receiver beside the rift** to request another radio check. The established carrier remains usable after Puzzle 01 has completed.

**Escape / PAUSE** opens the pause menu. It offers Resume, Return to Menu and, in solo only, Reset Solo Session and Test Radio Interference. Interference is available after the link is established. It temporarily interrupts local presentation and recovers automatically; it does not reset the puzzle.

The header's Character / F2 option retains the existing animation studio and opens the appropriate Student/Professor studio. Gameplay HUD widgets are hidden during the studio and restored on close. Actions, dialogue and modals prevent unsafe role/studio changes. **R** respawns at the existing spawn marker without resetting progress.

## Host and join

Use two running copies on the same LAN:

- Host: Main Menu → Play → **HOST ON WI-FI / THE STUDENT**. Share the displayed address. Wait for the Professor to connect and select Ready; the existing Start button then becomes available.
- Guest: Main Menu → Play → **JOIN ON WI-FI / THE PROFESSOR**. Enter the host's IP, select Join Game, then **I'M READY**.
- Host: select **START GAME**. NetworkManager's confirmed start event loads the same actual laboratory on both peers, with Student/Past on the host and Professor/Future on the guest.

Each process owns one local character/input rig in its own timeline. The Guest reads the Future log and picks up their radio; the Host picks up the Student radio and calibrates the rear computer. Solo switching/reset controls are hidden during LAN play. Pause affects only local input/presentation, so the networking and puzzle autoloads continue processing.

Both peers receive the confirmed link and auxiliary puzzle completion and begin the associated radio conversations. Each player advances their text locally, as designed by the existing Dialogue System. This integration does not add a line-by-line network dialogue protocol, free-form chat, microphone access or VoIP.

## Authoritative state and persistence

The existing PuzzleManager and NetworkManager are unchanged. Puzzle 01 remains `puzzle_01_frequency`, with the original three canonical flags:

```gdscript
{"student_radio": false, "professor_radio": false, "frequency_calibrated": false}
```

Only PuzzleManager applies accepted rules on the host. Radio pickup/calibration components submit actions; clients remain pending until confirmation. The sender's real connection determines their role. The target remains **67 MHz**, with integer/type/range/ownership validation in the existing frequency rules.

The link is established when all three flags are true. Calibration may wait for a later Professor pickup. Duplicate actions, incorrect tuning and full resynchronization do not replay completion or story triggers. The uncalibrated HUD shows `-- MHz`, preserving the Future research clue.

Later stages use the existing public query:

```gdscript
if PuzzleManager.is_solved("puzzle_01_frequency"):
	# This session's temporal radio carrier is established.
	pass
```

Room entry only performs guarded registration and reads confirmed state. It does not begin or reset a session. Tests reload the actual `spawn_area.tscn` on solo and both LAN peers and verify the same session, ownership and calibration with no replayed conversation.

Starting a new Solo Test explicitly begins a new session; LAN start uses the existing manager lifecycle. Reset Solo Session deliberately starts a fresh session, clears dialogue history, restores pickups and returns to Student. Return to Menu stops local presentation/audio, leaves the network session and resets ended-session puzzle progress. Disconnect disables movement, cancels dialogue and presents Return to Menu rather than leaving a stale playable world.

## Confirmed Dialogue System integration

`radio_director_binding.gd` resolves the radio adapter's sequence IDs to actual `DialogueSequence` resources and calls:

```gdscript
director.play_dialogue(sequence, {"timeline": radio.player_role, "channel": "radio"})
```

It listens to the actual `dialogue_started`, `dialogue_finished` and `dialogue_cancelled` signals, and releases the adapter with `end_conversation()`. The existing director owns its queue, history, timeline filtering, line progression, and typewriter handling. Its `gameplay_input_block_changed` signal participates in the laboratory's input-lock calculation.

`radio_dialogue_box.gd` extends the real `DialogueBox`. It adds a channel/status ribbon and transmission animation/audio hooks while retaining the existing speaker, text, BBCode, typewriter, fade and advance API. No dialogue core files were changed or replaced, and the temporary sandbox driver is not referenced by gameplay.

The production adapter binds these sequence IDs:

| Trigger | Actual resource |
|---|---|
| Confirmed Puzzle 01 completion, both peers | `laboratory/radio_link_established.tres` |
| Confirmed auxiliary relay completion, both peers | `laboratory/receiver_online.tres` |
| Rift-side receiver interaction, local radio check | `laboratory/radio_check.tres` |
| Student radio discovery, Past audience | Existing `samples/opening_past.tres`, via DialogueTrigger |
| Research log interaction, Future audience | Existing `samples/future_discovery.tres`, via DialogueTrigger |

Conversation text lives in resources. Radio state and authoritative puzzle logic contain no story lines. The binding freezes only the local director during a document/terminal, pause, or radio interference. Closing a modal recomputes the combined input lock, so it cannot accidentally release a still-blocking conversation. Interference recovery resumes typewriter, advance and signal animation without changing canonical state.

## Interaction, models, HUD and audio

The composition adds one InteractionRig to each active character and binds its existing detector/controller to the existing InteractionPrompt. Pickups use the authored `PickUp` clip, the main computer uses `Interact`, and the research document uses `Use_Item`. Behavior runs through the controller after animation completion, which prevents duplicate inputs during the action. The primary console is the existing console model; it does not gain an extra blue sandbox cube.

The TemporalRadio component is retained while solo characters change, then reparented to the new player and given the corresponding role. The held placeholder is attached with `BoneAttachment3D` to `handslot.r`, independently of ownership/network logic. The character's studio demonstration paper and free demo item shortcuts are disabled only in integrated gameplay. Action completion selects the holding/rest pose before a dialogue listener can freeze animation.

Replace `PlaceholderRadio` under either world pickup and the held model instantiated in `bind_player()` when the final radio mesh arrives. The existing presenter still controls visibility; rules and synchronization need no changes.

UI layers keep the existing header/footer below the gameplay HUD and interaction prompt, dialogue at layer 20, terminal/document at 30, and pause at 60. Escape belongs to an open document/terminal before it can toggle pause. Role switching and character preview are disabled while an action or conversation owns input. There is one radio HUD, one focus prompt and one actual dialogue box/director per local gameplay scene.

The existing AudioDirector supplies footsteps, button/interaction sounds, radio beeps and connection cues. Radio static continues through the existing radio audio adapter and SFX bus. Timeline ambience uses the existing AmbientAudioController. Integration exposed imported WAV/QOA files with zero loop bounds; local duplicate streams now receive a valid full-sample loop range, avoiding mutation of shared imported SFX. Zero-fade stop is synchronous, and teardown clears playback references instead of relying on a Tween that would disappear with the room. This uses the [documented sample-based WAV loop bounds](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html#class-audiostreamwav-property-loop-end).

## Files created

| File | Purpose |
|---|---|
| `scenes/gameplay/laboratory_gameplay.tscn` | Editable lab pickup/console/log/relay locations and integrated subsystem composition |
| `scripts/gameplay/laboratory_gameplay.gd` | Player binding, role presentation, objectives, combined input locks and lifecycle |
| `scenes/gameplay/radio/radio_dialogue_box.tscn` | Inherited real DialogueBox with radio skin |
| `scripts/gameplay/radio/radio_dialogue_box.gd` | Channel/status and transmission extension to existing DialogueBox |
| `scripts/gameplay/radio/radio_director_binding.gd` | ID-based adapter → confirmed DialogueDirector API |
| `scripts/puzzles/implementations/laboratory_relay_puzzle.gd` | Existing power-switch rules with radio-link prerequisite |
| `resources/dialogue/laboratory/radio_link_established.tres` | Initial shared Student/Professor radio conversation |
| `resources/dialogue/laboratory/radio_check.tres` | Repeatable radio-check conversation |
| `resources/dialogue/laboratory/receiver_online.tres` | Shared receiver completion conversation |
| `tests/gameplay_integration.gd` | Actual menu/solo/scene-transition/UI/animation integration, optional visual captures |
| `tests/gameplay_peer.gd` | Two actual menu/lobby/gameplay ENet peers |
| `tests/run_gameplay_tests.py` | Strict solo and multiplayer runner, exit/log/timeout/leak checks |
| `docs/technical/GAMEPLAY_INTEGRATION.md` | Play guide, architecture and complete file manifest |
| `docs/development/reports/GAMEPLAY_INTEGRATION_TEST_RESULTS.md` | Executed results, corrections and remaining limits |

Godot-generated UID companions were also created for these six scripts:

```text
scripts/gameplay/laboratory_gameplay.gd.uid
scripts/gameplay/radio/radio_dialogue_box.gd.uid
scripts/gameplay/radio/radio_director_binding.gd.uid
scripts/puzzles/implementations/laboratory_relay_puzzle.gd.uid
tests/gameplay_integration.gd.uid
tests/gameplay_peer.gd.uid
```

## Existing files modified

| File | Focused integration change |
|---|---|
| `scenes/menu/main_menu.tscn` | Solo Test label and updated Play description; original layout retained |
| `scripts/menu/main_menu.gd` | Solo role/session initialization, guarded scene entry, configurable LAN port for tests |
| `scenes/world/spawn_area.tscn` | Compose actual gameplay, add foreground pause layer/solo controls and update hints |
| `scripts/world/spawn_area.gd` | Role model selection, lifecycle, modal-aware input, pause, reset, disconnect and return |
| `scripts/characters/student_3d_player.gd` | Disable studio demo items per gameplay instance; public action query; rest pose before action-finished callbacks |
| `scripts/audio/ambient_audio_controller.gd` | Valid private loop configuration and immediate/scene-exit playback cleanup |
| `tests/spawn_area.gd` | Follow actual character replacement and assert Professor model rather than tint-only assumption |
| `tests/student_3d.gd` | Verify completed actions select a resting/holding pose |
| `tests/audio_system.gd` | Loop/resource/zero-fade tests and explicit owned playback cleanup |
| `tests/lan_peer.gd` | Confirm client scene readiness through existing PuzzleManager test fixture instead of a fixed load-time race |
| `tests/puzzle_system.gd` | End the menu-launched audio-enabled test room through its actual Return to Menu lifecycle |
| `docs/design/FREQUENCY_PUZZLE.md` | Replace pending dialogue notes with confirmed production binding and current integration links |
| `docs/development/reports/FREQUENCY_PUZZLE_TEST_RESULTS.md` | Mark the older isolated report as historical and link current integration verification |

`project.godot` already had an uncommitted editor-serialization diff when this task started; it was preserved and not edited by this integration. NetworkManager, PuzzleManager, PuzzleBase, interaction/dialogue cores, assets and shaders were not changed. No branches were switched/merged, and no commits or pushes were made.

## Test commands and limits

```powershell
$env:GODOT_BIN = 'C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
.\.venv\Scripts\python.exe tests/run_gameplay_tests.py
.\.venv\Scripts\python.exe tests/run_dialogue_tests.py --skip-import --regression
.\.venv\Scripts\python.exe tests/run_frequency_tests.py
.\.venv\Scripts\python.exe tests/run_puzzle_tests.py
.\.venv\Scripts\python.exe tests/run_lan_smoke.py
& $env:GODOT_BIN --headless --path . --script res://tests/student_3d.gd -- --professor
& $env:GODOT_BIN --headless --path . --script res://tests/interaction_system.gd
& $env:GODOT_BIN --headless --path . --script res://tests/audio_system.gd
```

The dedicated gameplay runner fails on engine/script errors, leaked-at-exit warnings, missing success markers, timeouts and nonzero exits. Its default runs the entire menu-driven solo flow and then two actual menu-driven LAN processes. `--peers-only` is available for focused networking diagnostics.

To regenerate actual 1280×720 GL Compatibility screenshots:

```powershell
$env:GAMEPLAY_REVIEW_DIR = Join-Path $env:TEMP 'past-future-gameplay-review'
& $env:GODOT_BIN --path . --resolution 1280x720 --script res://tests/gameplay_integration.gd
Remove-Item Env:GAMEPLAY_REVIEW_DIR
```

Current results are recorded in `GAMEPLAY_INTEGRATION_TEST_RESULTS.md`. Two physical-PC/Wi-Fi verification remains a deployment check. Final radio meshes/hand offsets, further room content and final story wording remain asset/content work. The current checkout contains this one laboratory; persistence was verified by reloading that actual scene, without constructing a separate final sandbox.
