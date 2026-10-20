# Puzzle 01: The Lost Frequency / Temporal Radio

The playable implementation establishes persistent **scripted, text-based radio communication** between the Student and Professor. Each character first acquires a physical handheld radio. The Student calibrates the main laboratory computer to **67 MHz**, using the Professor's Future research log. The Temporal Rift enables the temporal carrier; the handheld radios are the communication devices.

Success displays **TEMPORAL RADIO LINK ESTABLISHED**. The puzzle has no door dependency. There is no microphone, VoIP, WebRTC, player text chat, or additional networking manager.

The real Dialogue System is now integrated into the playable laboratory through `radio_director_binding.gd`, using its confirmed `DialogueDirector.play_dialogue(DialogueSequence, context)` API. The ID-based adapter below remains reusable. The original sandbox retains its isolated temporary dialogue fixture. See **GAMEPLAY_INTEGRATION.md** for the actual Main Menu → laboratory flow and current tests.

## Mechanics and authoritative state

`frequency_puzzle.gd` extends the existing `PuzzleBase`. `frequency_puzzle_coordinator.gd` registers it as `puzzle_01_frequency` on each peer, only if that ID is not already registered. Neither script changes the existing managers or starts a session on room entry.

The minimum replicated state is:

```gdscript
{"student_radio": false, "professor_radio": false, "frequency_calibrated": false}
```

The link is the conjunction of all three flags. `PuzzleManager` stores its existing derived `solved` record using the rules' `is_solved()`. There is no extra replicated link flag, entered-frequency history, or secret answer. Roles identify the two players in the current architecture: Past = Student/host, Future = Professor/client.

| Action | Allowed actor | Payload | Result |
|---|---|---|---|
| `acquire_radio` | Both, for their own radio only | `{"radio_role": "past"}` or `"future"` | Sets that player's ownership |
| `tune_frequency` | Past, after acquiring their radio | `{"frequency": 67}` | Locks calibration; completes only if both radios are owned |

If calibration happens before the Professor's pickup, it remains locked and searches for the second radio. That final pickup then completes the puzzle. Incorrect, well-formed tuning returns `NO_CHANGE` / `SIGNAL NOT FOUND`, so retries never increase the revision. Invalid types (including floats and booleans), missing/extra keys, out-of-range values, unsupported actions and unauthorized roles are rejected. Valid input is an integer from 1 to 999 inclusive. The correct value is a configurable host-side rule member, initially 67.

Duplicate pickups or tuning after calibration do not change state or replay completion. Wrong tuning after calibration cannot clear progress. Each accepted prerequisite changes one canonical record once. `PuzzleManager.puzzle_completed` fires exactly once per unsolved-to-solved transition, including when the final action is a pickup.

All requests use `PuzzleManager.submit_action()`. The existing manager authenticates network sender roles, ignores client-supplied actor roles, validates rules on the host and broadcasts confirmed revisions/snapshots. A client pickup remains pending until confirmation; it never grants ownership optimistically. Existing Interaction System proximity and timeline checks remain in use; this component does not introduce another player-position authority.

```gdscript
# Normal gameplay calls the pickup or terminal component. These are their underlying requests.
PuzzleManager.submit_action("puzzle_01_frequency", "acquire_radio", {"radio_role": "past"})
PuzzleManager.submit_action("puzzle_01_frequency", "tune_frequency", {"frequency": 67})

# Offline testing / a future trusted local-player router can pass an explicit actor role.
PuzzleManager.submit_action("puzzle_01_frequency", "acquire_radio", {"radio_role": "future"}, "future")
```

## Persistent queries and lifecycle

Later stages can query the existing autoload directly:

```gdscript
if PuzzleManager.is_solved("puzzle_01_frequency"):
	# An authored radio conversation or later puzzle may use the persistent carrier.
	pass
```

The room coordinator also exposes `is_temporal_link_established()`. A `TemporalRadio` exposes `has_established_link()` for the persistent carrier, and `can_receive()` for local presentation readiness. Interference or stowing a radio changes only local presentation readiness.

`PuzzleManager` retains both registration and canonical state independently of scene lifetimes. New radios, terminals, HUDs, pickups and rift presenters query confirmed state immediately on entry. Recreating a room restores appearance silently; it does not emit the original completion event. Do **not** call `begin_session()`, `reset_all()` or `reset_puzzle()` from room-loading code. A new solo/game session or explicit host reset clears both radios and calibration. Disconnect follows the existing manager lifecycle; a finished LAN session is not inherited by the next session. This is session persistence, not a disk-save system.

For a later puzzle's rules, return `PackedStringArray(["puzzle_01_frequency"])` from `get_prerequisites()` to require the established carrier.

## Character, pickup and visual integration

1. Add `frequency_puzzle_coordinator.gd` to a Node in the first laboratory on both peers. Add it to independently loadable test rooms if needed; registration is guarded.
2. Add `scenes/gameplay/radio/temporal_radio.tscn` beneath each character, setting `player_role` to `past` or `future`. Future character models need no communication-specific code.
3. Instance `radio_pickup.tscn` into each timeline. Set `radio_role` appropriately. Its existing `Interactable3D` base supplies distance, prompts, and eligibility; acquisition goes through PuzzleManager. The pickup stays visible while a client request is pending and disappears only after confirmation. Reset restores it.
4. Bind `radio_hud.tscn.radio` to the local character's TemporalRadio. It displays disconnected/searching/connected and stowed status. The HUD shows `-- MHz` before confirmed calibration, preserving the Future-only clue.
5. Place `placeholder_radio.tscn` under a hand/socket transform, and add `radio_model_presenter.gd`, assigning `radio` and `model`. Visibility follows ownership/activity. The sandbox uses a temporary transform attached to the existing character's Visual node. A production character can use a BoneAttachment3D socket and separate animation tracks.

Replace the pickup's `placeholder` reference and the held presenter's `model` with final 3D assets. No ownership, calibration or network code changes are required. Do not attach the radio logic to mesh names or animation events.

`TemporalRadio` public presentation API:

| Method/signal | Purpose |
|---|---|
| `request_acquisition() -> Dictionary` | Submit own-radio request through PuzzleManager |
| `set_player_role(role)` | Select a trusted local character's presentation role |
| `has_established_link() -> bool` | Query persistent confirmed prerequisites |
| `can_receive() -> bool` | Connected, owned, active and free of local interference |
| `get_calibrated_frequency() -> int` | Configured frequency after calibration; 0 while unknown |
| `set_presentation_active(bool)` | Draw/stow the local radio without changing ownership/link |
| `interfere(seconds)` | Temporary local signal interference; automatic recovery |
| `set_transmitting(bool)` | Incoming-transmission animation/audio cue hook |
| `status_changed(status, owns_radio, active)` | HUD, held mesh, connection indicator |
| `ownership_changed(owns_radio)` | Character presentation/inventory hook |
| `presentation_active_changed(active)` | Separate draw/stow animation hook |
| `transmission_changed(transmitting)` | Signal animation hook |
| `audio_cue_requested(cue)` | `connected`, `incoming`, `static` |

The canonical carrier remains active through local interference and presentation deactivation. A freshly instantiated radio rehydrates ownership from PuzzleManager; it does not need a persistent character node.

## Terminal, research log and rift

Instance `frequency_terminal_ui.tscn` beneath a CanvasLayer (sandbox uses layer 30). Instance `frequency_computer.tscn` on the main laboratory computer and assign its `terminal` reference. The component extends existing `Interactable3D`, restricts interaction to Past, and calls `terminal.open_for(actor, role)`. Replace its blue cube independently.

The terminal uses native containers, a validated LineEdit, focusable buttons, a failure tween and an Escape/close handler. Invalid pasted text is kept for correction but cannot submit. It blocks gameplay interaction and temporarily disables the existing character's `controls_enabled` property; closing or unloading the modal releases the same actor. It displays locked/awaiting-radios or connected state from the authoritative record. A recreated terminal displays the completed frequency immediately. The common modal expects the existing character control contract and InteractionController's public `set_interaction_blocked()` API.

Instance `frequency_clue.tscn` only in the Future timeline. Add `frequency_log_reader.gd` to a Control under the modal CanvasLayer and assign it as `reader`. Edit `research_text` to change the scientific log. Only Future can open it. The provisional paper mesh and reader can each be replaced independently by the proper Document System. Past does not receive or auto-open the clue.

Instance `temporal_link_indicator.tscn`, or attach `temporal_link_presenter.gd` and set `indicator` / optional `light` references. The presenter switches purple/cyan from confirmed state and applies it immediately on scene entry. `link_applied(connected)` is an appearance hook, not a one-shot story event. No door or final rift shader is required.

## Radio Dialogue Presentation Adapter and actual director binding

`radio_dialogue_adapter.gd` remains the sequence-ID boundary. The production `radio_director_binding.gd` resolves IDs to actual DialogueSequence resources and calls the existing director's public API. Its `RadioDialogueBox` extends the real DialogueBox; it uses the existing typewriter and speaker presentation. No dialogue core files were changed.

Assign `radio`, the `radio_dialogue_presenter.tscn` instance as `presenter`, and optionally `link_sequence_id`. Set `event_sequence_ids` to map narrative event IDs or confirmed puzzle IDs to sequence IDs. `event_audience` selects `shared`, `past` or `future`. Completion triggers are derived from existing confirmed `puzzle_completed` signals; snapshots/room entry never replay them.

| Adapter interface | Meaning |
|---|---|
| `request_conversation(sequence_id: StringName, audience = "shared") -> bool` | Request an authored sequence while the radio can receive |
| `request_event(event_id: String, audience = "shared") -> bool` | Resolve a configured event ID to its sequence ID |
| `bind_sequence_player(player: Callable)` | Optional callback accepting one sequence ID; return false if unavailable/busy |
| `conversation_requested(sequence_id, metadata)` | Alternative request hook / observer; metadata contains channel `radio`, frequency and audience |
| `present_line(speaker_name: String, text: String) -> bool` | Display a line supplied by the actual director |
| `end_conversation()` | Clear presentation and active ID on director completion/cancellation |
| `conversation_finished(sequence_id)` | Local presentation lifetime notification |
| `conversation_unavailable(reason)` | Missing binding/sequence, busy, inactive/interfered radio, or invalid audience |
| `temporal_radio_link_established` | One confirmed completion hook |

Choose the callback or request-signal delivery route when binding playback; do not start the same sequence twice from both. A second conversation is refused while an active ID exists. Finish/cancel it with `end_conversation()` before requesting another. The adapter intentionally owns no queue, branching or narrative progression; those belong to DialogueDirector. Failed event requests can be retried by that narrative owner.

The original standalone presenter exposes `show_line(speaker_name, dialogue_text)`, `reveal_line()`, `request_advance()`, `end_transmission()`, and `advance_requested` / `line_revealed`; its names/text are literal. Production gameplay instead uses `radio_dialogue_box.tscn`, extending the existing DialogueBox and supporting its authored BBCode text. The director still owns line advancement, typewriting, queueing and play-once history. The radio binding adds channel status and suspends this local presentation during interference or modals; it never changes canonical puzzle state.

Production binding uses the confirmed interface:

```gdscript
# radio_director_binding.gd binds this callback via bind_sequence_player().
func play_sequence(sequence_id: StringName) -> bool:
	for sequence in sequences:
		if sequence.sequence_id == String(sequence_id):
			return director.play_dialogue(sequence, {"timeline": radio.player_role, "channel": "radio"})
	return false
```

`scripts/testing/radio_dialogue_preview.gd` is the replaceable sandbox fixture. It binds the adapter to four diagnostic Student/Professor lines under `sandbox.radio_check`. This checks alternating speakers, typewriter behavior and completion independently. These lines are not approved story content and never reside in puzzle or radio logic. Confirmed establishment starts this diagnostic sequence on both peers. Each peer advances its text locally; no new dialogue-advance network protocol is claimed. The actual director can later coordinate presentation through its own public integration.

## Audio

Attach `radio_audio.gd` and assign the existing scene's `AudioDirector` plus local `radio`. Beeps/confirmation use its public `has_sound()` and `play_sfx()` methods with an exported cue map. Hook the terminal's `audio_cue_requested` and the local pickup's confirmed `radio_acquired(role)` to this adapter as the sandbox demonstrates.

| Cue | Default placeholder |
|---|---|
| Incoming line | Existing `ui_hover` sound |
| Confirmed connection | Existing `ui_confirm` sound; once per completion |
| Confirmed local pickup | Existing `interaction_click` sound |
| Calibration attempt | Existing `ui_click` sound |
| Static / interference / wrong tuning | Catalog `radio_static` if available; otherwise a short deterministic noise burst |

The generated static uses one bounded AudioStreamPlayer on the existing SFX bus, respecting category/master mute and volume. It does not change the audio catalog or asset files. Missing AudioDirector/catalog sounds are safe no-ops. Static is generated in memory, with no new asset dependencies. Final sound IDs can be substituted without changing communication logic.

## Changing the frequency

Set the first coordinator's `target_frequency` (1–999). Keep the terminal's `display_frequency`, each radio's `display_frequency`, and the Future clue's `research_text` aligned with that configuration. The first guarded registration controls a session's rule instance; later rooms do not overwrite it. The default production design is **67 MHz**. A rules test also exercises 81 MHz to verify the answer does not live in PuzzleManager.

## Sandbox walkthrough and launch

Open `scenes/testing/frequency_puzzle_sandbox.tscn` in Godot 4.7.2 and press **F6** (Run Current Scene). The project's menu/main scene is untouched. Alternatively:

```powershell
$godot = 'C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . res://scenes/testing/frequency_puzzle_sandbox.tscn
```

1. Start as Student. Move with WASD/arrows, approach the handheld radio, and press F to acquire it.
2. Press T to switch offline to Professor. Move to the Future radio and acquire it. Read the research log with F; it identifies 67 MHz. Close with Escape.
3. Press T to return to Student, approach the blue main computer, and press F. Enter 66 to check retry feedback, then enter 67 and calibrate.
4. Both-radio ownership plus calibration establishes the link. The HUD/rift update, the required success text appears, and the diagnostic text conversation becomes available. Close the terminal to see it. Continue first reveals a line, then advances to the other speaker.
5. Close/reopen the computer. Press R to unload the room and load a minimal presentation probe; the fresh indicator is already connected. R returns to the lab without resetting anything.
6. X introduces two seconds of local interference. D requests another diagnostic radio conversation. N explicitly starts a fresh session (host/offline only); this is a sandbox control, not a room-transition action.

For two computers/processes, launch the same scene on each. Existing NetworkManager lobby APIs ready the Professor and start the sandbox game automatically:

```powershell
# Student / host
& $godot --path . res://scenes/testing/frequency_puzzle_sandbox.tscn -- --radio-host 7000
# Professor / client (use host LAN IP on another machine)
& $godot --path . res://scenes/testing/frequency_puzzle_sandbox.tscn -- --radio-join 127.0.0.1 7000
```

T is disabled during LAN play; each peer retains its authenticated timeline. Room-probe controls affect local presentation and preserve the shared record. Final lab placement, opening-cutscene hookup, final held-radio assets/animations and authored story resources are intentionally separate integration work.

## Verification

```powershell
$env:GODOT_BIN = $godot
.\.venv\Scripts\python.exe tests/run_frequency_tests.py
.\.venv\Scripts\python.exe tests/run_puzzle_tests.py
& $godot --headless --path . --script res://tests/interaction_system.gd
& $godot --headless --path . --script res://tests/audio_system.gd
```

The new runner checks process exit codes, timeouts, required completion markers and **all engine/script ERROR lines**. It runs rules and real-scene integration tests, then two actual ENet processes using the unchanged managers. The peers verify forged roles/state fields, pending client acquisition, revisions, full snapshots without repeated completion, a fresh room/character radio, explicit reset, a new-session snapshot, stale-session rejection and disconnect cleanup.

Visual QA can capture six actual GL Compatibility renders at 1280×720:

```powershell
$env:RADIO_REVIEW_DIR = Join-Path $env:TEMP 'past-future-radio-review'
& $godot --path . --resolution 1280x720 --script res://tests/frequency_puzzle_integration.gd
Remove-Item Env:RADIO_REVIEW_DIR
```

The original isolated verification is recorded in `FREQUENCY_PUZZLE_TEST_RESULTS.md`; current integrated gameplay results are in `GAMEPLAY_INTEGRATION_TEST_RESULTS.md`. Both use loopback ENet; two-physical-PC Wi-Fi testing remains a deployment check. Actual DialogueDirector integration is implemented. A live microphone or voice service remains outside scope.

## File manifest and protected systems

New source files (Godot-generated `.gd.uid` companions accompany the new GDScripts):

```text
scripts/puzzles/implementations/frequency_puzzle.gd
scripts/gameplay/frequency/frequency_puzzle_coordinator.gd
scripts/gameplay/frequency/frequency_ui.gd
scripts/gameplay/frequency/frequency_modal.gd
scripts/gameplay/frequency/frequency_terminal.gd
scripts/gameplay/frequency/frequency_computer.gd
scripts/gameplay/frequency/frequency_clue.gd
scripts/gameplay/frequency/frequency_log_reader.gd
scripts/gameplay/frequency/temporal_link_presenter.gd
scripts/gameplay/radio/temporal_radio.gd
scripts/gameplay/radio/radio_pickup.gd
scripts/gameplay/radio/radio_model_presenter.gd
scripts/gameplay/radio/radio_hud.gd
scripts/gameplay/radio/radio_dialogue_presenter.gd
scripts/gameplay/radio/radio_dialogue_adapter.gd
scripts/gameplay/radio/radio_audio.gd
scripts/testing/frequency_puzzle_sandbox.gd
scripts/testing/radio_dialogue_preview.gd
scenes/gameplay/frequency/frequency_terminal_ui.tscn
scenes/gameplay/frequency/frequency_computer.tscn
scenes/gameplay/frequency/frequency_clue.tscn
scenes/gameplay/frequency/temporal_link_indicator.tscn
scenes/gameplay/radio/temporal_radio.tscn
scenes/gameplay/radio/radio_pickup.tscn
scenes/gameplay/radio/placeholder_radio.tscn
scenes/gameplay/radio/radio_hud.tscn
scenes/gameplay/radio/radio_dialogue_presenter.tscn
scenes/testing/frequency_puzzle_sandbox.tscn
tests/frequency_puzzle.gd
tests/frequency_puzzle_integration.gd
tests/frequency_peer.gd
tests/run_frequency_tests.py
docs/FREQUENCY_PUZZLE.md
docs/FREQUENCY_PUZZLE_TEST_RESULTS.md
```

This manifest records the original standalone radio addition, which modified no existing files. The later Main Menu and real laboratory integration, including its focused existing-file changes, is documented in `GAMEPLAY_INTEGRATION.md`. NetworkManager, PuzzleManager, PuzzleBase and the interaction/dialogue cores remain unchanged. No branches were switched or merged and no commits were created.
