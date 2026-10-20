# Dialogue System

A small, data-driven system for conversations, narration and story beats. Conversations are `.tres`
resources edited in the Inspector. One `DialogueDirector` per player plays them, a `DialogueBox`
shows them, and everything else in the game reacts through signals.

```text
 Interaction / PuzzleManager / Cutscene / Area3D / any script
        |  a signal, or a direct call
        v
 DialogueTrigger (optional adapter) ---> DialogueDirector.play_dialogue(sequence, context)
                                              |  state machine, FIFO queue, play-once history,
                                              |  timeline filter, narrative events
        game systems  <---- signals ----------+-----------> DialogueBox
        (camera, doors, player lock...)                      (typewriter, accent, portrait, fades)
```

Verified with Godot 4.7.2 (GL Compatibility). Nothing here needs a second engine, a plugin, or a change to
`project.godot`.

## Principles

- **Dialogue is local presentation.** Each peer runs its own director. There is no dialogue RPC and nothing
  here writes to the network. The only thing read from `NetworkManager` is `role`.
- **Authoritative state stays elsewhere.** A conversation cannot solve a puzzle, open a door or move a camera.
  The director announces what happened; other systems decide what it means.
- **Content is data.** Adding a conversation, speaker or event never edits `DialogueDirector`.
- **Every request has an ending.** Each request that `play_dialogue()` accepts produces exactly one
  `dialogue_finished` or `dialogue_cancelled` for its `sequence_id`, and every `dialogue_line_started` is
  followed by exactly one `dialogue_line_finished`. Listeners can rely on both pairings.

## Files

| File | Responsibility |
|---|---|
| `scripts/dialogue/dialogue_line.gd` | `DialogueLine`: one line (speaker, text, timeline, portrait, voice, speed, event). |
| `scripts/dialogue/dialogue_sequence.gd` | `DialogueSequence`: ordered lines plus how they play (audience, blocking, play-once, skip, auto-advance, events). |
| `scripts/dialogue/dialogue_director.gd` | `DialogueDirector`: playback state, queue, history, timeline filter, signals, input. |
| `scripts/dialogue/dialogue_box.gd` | `DialogueBox`: presentation only. Typewriter, accent colours, portrait, fades, voice clip. |
| `scripts/dialogue/dialogue_trigger.gd` | `DialogueTrigger`: turns a signal or a call into a dialogue request. |
| `scripts/testing/dialogue_sandbox.gd` | Controller of the test bench scene. Not game code. |
| `scenes/dialogue/dialogue_box.tscn` | The box: `CanvasLayer` (layer 10) with the panel, speaker row, `RichTextLabel`, continue indicator. |
| `scenes/dialogue/dialogue_system.tscn` | The reusable unit: a `DialogueDirector` root with a `DialogueBox` child. **Add this to a scene.** |
| `scenes/testing/dialogue_sandbox.tscn` | Standalone test bench. |
| `resources/dialogue/samples/*.tres` | Four provisional sample conversations (placeholder text, not final story). |
| `tests/dialogue_system.gd`, `tests/run_dialogue_tests.py` | Headless tests and their runner. |

## Quick start

1. Instance `scenes/dialogue/dialogue_system.tscn` anywhere in a scene (see [Integrating](#integrating-into-the-game)).
2. Play a conversation from any script:

```gdscript
const RIFT_CONTACT := preload("res://resources/dialogue/samples/first_rift_contact.tres")

func _on_console_used() -> void:
	var director := get_tree().get_first_node_in_group(DialogueDirector.GROUP) as DialogueDirector
	director.play_dialogue(RIFT_CONTACT)
```

3. Press **Enter or Space** to reveal a line, then again to continue. **Esc** skips, where the sequence allows it.

Try it first in the [sandbox](#the-sandbox).

## Writing a conversation

A conversation is a `DialogueSequence` resource containing `DialogueLine` resources. Everything below is done in
the Inspector.

**Create one.** In the FileSystem dock: right-click `resources/dialogue/` > *New Resource...* > `DialogueSequence`,
save it as `<sequence_id>.tres`. In the Inspector, click *Lines* > *Add Element* and choose *New DialogueLine*
for each line. Duplicating a sample is often quicker.

**`DialogueSequence` fields**

| Field | Meaning | Default |
|---|---|---|
| `sequence_id` | Unique across the game, no spaces (`first_rift_contact`). Keys the queue and the play-once history. Match the file name. | empty (refused) |
| `audience` | `Past`, `Future` or `Both`. A director plays only sequences for its own timeline. | `Both` |
| `lines` | The ordered lines. | empty (refused) |
| `playback_mode` | `Blocking` asks the game to lock gameplay input while it plays. `Non Blocking` lets the player keep moving. | `Blocking` |
| `play_once` | Play at most once per session. Cancelled conversations do not count. | off |
| `allow_skip` | The player may skip the rest. Skipping still announces the events of the skipped lines. | on |
| `typing_speed` | Characters per second for every line. `0` uses the director's default (40). | `0` |
| `auto_advance` / `auto_advance_delay` | Continue by itself, this many seconds after a line is fully visible. | off / 1.5 |
| `start_event_id` / `finish_event_id` | Story events announced when the sequence starts, and when it ends by finishing or being skipped (never when cancelled). | empty |

**`DialogueLine` fields**

| Field | Meaning |
|---|---|
| `line_id` | Optional, unique within the sequence. For notes and other systems. |
| `speaker_id` | Stable internal identity (`student`, `professor`). Never shown. |
| `speaker_name` | What the player sees. It may hide the real identity: the professor is credited as `Unknown Voice`. Empty hides the name. |
| `text` | BBCode: `[i]emphasis[/i]`, `[b]bold[/b]`. Use `[lb]` for a literal `[`. Lines without text are never shown. |
| `timeline` | The speaker's timeline: `Past` (amber), `Future` (cyan) or `Both` (blue-violet, for voices heard across the rift). Picks the box's accent. |
| `portrait` | Optional `Texture2D`. Without one the portrait area is hidden and takes no space. |
| `typing_speed` | Characters per second for this line. `0` inherits. |
| `event_id` | Optional story event announced when this line starts. |
| `voice` | Optional `AudioStream`, played when the line starts. Reserved for future voice acting. |

**Add a speaker.** There is no speaker registry. Set `speaker_id`, `speaker_name` and `timeline` on each of their
lines. To add a narrator or an in-world object, leave `speaker_name` empty.

**Add a portrait.** Drag a texture onto the line's `portrait`. Remove it again and the box lays out as if it had
never existed. The portrait is shown at 56x56.

**Check your work.** `sequence.validate()` returns readable problems (missing ID, no lines, repeated `line_id`,
negative speeds). Lines with no text, and empty slots in the array, are skipped when played. `line_index` in
signals always counts positions in `lines`, including skipped ones, so it maps straight back to the array.

### A complete new conversation, without touching code

```ini
; resources/dialogue/console_warning.tres  (save it from the Inspector, or write it by hand)
[gd_resource type="Resource" script_class="DialogueSequence" format=3]

[ext_resource type="Script" path="res://scripts/dialogue/dialogue_line.gd" id="1_line"]
[ext_resource type="Script" path="res://scripts/dialogue/dialogue_sequence.gd" id="2_seq"]

[sub_resource type="Resource" id="Resource_a"]
script = ExtResource("1_line")
speaker_id = "student"
speaker_name = "The Student"
text = "The warning label is half peeled away."

[sub_resource type="Resource" id="Resource_b"]
script = ExtResource("1_line")
speaker_id = "student"
speaker_name = "The Student"
text = "[i]DO NOT OPERATE UNSUPERVISED.[/i]"

[resource]
script = ExtResource("2_seq")
sequence_id = "console_warning"
audience = 0
lines = Array[ExtResource("1_line")]([SubResource("Resource_a"), SubResource("Resource_b")])
playback_mode = 1
```

Play it with `director.play_dialogue(preload("res://resources/dialogue/console_warning.tres"))`. Because
`play_once` is off, inspecting the console again repeats it. `audience = 0` is the Past, so a Future director
refuses it, and `playback_mode = 1` is non-blocking, so the player can keep walking while it plays. Enum
fields are stored as numbers in `.tres` files: `Past` 0, `Future` 1, `Both` 2; `Blocking` 0, `Non Blocking` 1.

## The samples

All four are provisional text used to exercise the system.

| Sequence | Audience | Mode | Notes |
|---|---|---|---|
| `opening_past` | Past | Blocking | Student, three lines. Plays once. |
| `first_rift_contact` | Both | Blocking | Student and *Unknown Voice*. Plays once. Announces `rift_activated` (start), `rift_voice_detected` (the first Unknown Voice line) and `rift_conversation_finished` (end). |
| `future_discovery` | Future | Non-blocking, auto-advance 1.8 s | Professor, three lines. Plays once. |
| `puzzle_completed` | Both | Blocking | Student, Professor, Student. Repeatable. |

## `DialogueDirector`

Add it by instancing `dialogue_system.tscn`. It joins the group `DialogueDirector.GROUP` (`"dialogue_director"`)
so other nodes can find it, and processes input only while a dialogue is active.

### Methods

| Method | Behaviour |
|---|---|
| `play_dialogue(sequence, context := {}) -> bool` | Ask for a conversation. `true` means it is playing or queued; `false` means it was refused (see `dialogue_rejected`). `context["timeline"]` (`"past"`/`"future"`) overrides the director's timeline for this request. |
| `advance_dialogue()` | The player pressed "continue": while typing, reveal the whole line; once fully visible, go to the next line, or finish after the last. |
| `skip_typewriter()` | Reveal the rest of the current line. Never advances. |
| `skip_dialogue() -> bool` | Skip the rest of the sequence if `allow_skip`. Events of the skipped lines still fire, then it finishes normally. Returns whether it skipped. |
| `stop_dialogue(clear := true)` | Cancel the active sequence. With `clear` everything queued is cancelled too, otherwise the next one starts. No story events fire for what was left unplayed. |
| `clear_queue() -> int` | Cancel everything waiting. Returns how many. |
| `reset_session()` | Cancel the active and queued dialogue and forget the play-once history. Nothing can be requested while it runs. |
| `is_dialogue_active()`, `get_state()` | `State.IDLE`, `SHOWING_LINE`, `WAITING_FOR_INPUT` or `FINISHING`. |
| `get_current_sequence_id()`, `get_current_sequence()` | `""` / `null` while idle. |
| `get_current_line()`, `get_current_line_index()` | The line on screen (`null` / `-1` otherwise). The index is a position in `DialogueSequence.lines`. |
| `get_queue_size()`, `get_queued_sequence_ids()` | What is waiting, in order. |
| `has_played(id)`, `mark_played(id)`, `get_played_ids()` | The session history. `mark_played` counts a sequence as played without playing it. |
| `is_gameplay_input_blocked()` | True while a blocking sequence plays. |
| `get_local_timeline()`, `set_local_timeline(name)` | `"past"` or `"future"`. `set_local_timeline("auto")` follows the network again. |
| `set_dialogue_box(box)` | Attach, swap or remove (`null`) the presenter at any time. A conversation in progress carries on. |

### States

```text
IDLE --play--> SHOWING_LINE --text revealed--> WAITING_FOR_INPUT --advance--> SHOWING_LINE (next line)
                                                      |                                 ...
                                                      +--last line--> FINISHING --> IDLE
```

`SHOWING_LINE` is the typewriter running. `WAITING_FOR_INPUT` is a fully visible line waiting for the player,
or for its auto-advance delay. `FINISHING` lasts only while the end of a sequence is being announced; during it,
stop, skip and advance calls from listeners are ignored. A director with no box treats every typewriter as
instantly finished.

### Signals

| Signal | When |
|---|---|
| `dialogue_started(sequence_id)` | A sequence began. Its first line follows. |
| `dialogue_line_started(sequence_id, line_index)` | A line became current. |
| `dialogue_line_finished(sequence_id, line_index)` | A line ended: advanced past, skipped, or interrupted. Always pairs with `dialogue_line_started`. |
| `dialogue_finished(sequence_id)` | The sequence ran to its end or was skipped. Emitted once, after the director is idle again. |
| `dialogue_cancelled(sequence_id)` | Stopped early (stop, reset, queue clear, scene exit, box lost). Also sent for queued sequences that never started. Never follows `dialogue_finished`. |
| `dialogue_skipped(sequence_id)` | The player skipped the rest. `dialogue_finished` follows immediately. |
| `narrative_event_requested(event_id)` | A line or sequence announced a story event. |
| `dialogue_rejected(sequence_id, reason)` | A request was refused. |
| `gameplay_input_block_changed(blocked)` | Lock (`true`) or restore (`false`) gameplay input. |

Order for a normal two-line blocking sequence with a start event, a line event and a finish event:

```text
gameplay_input_block_changed(true), dialogue_started, narrative_event_requested(start),
dialogue_line_started(0), dialogue_line_finished(0),
dialogue_line_started(1), narrative_event_requested(line), dialogue_line_finished(1),
narrative_event_requested(finish), gameplay_input_block_changed(false), dialogue_finished
```

A line's `event_id` fires right after its `dialogue_line_started`. Event IDs are trimmed; empty ones announce
nothing. Cancelling announces no further events.

Listeners may call back into the director from inside any signal (stop it, queue something new, chain the next
conversation). The tests cover these cases.

### Rejection reasons

`REJECT_NO_SEQUENCE`, `REJECT_INVALID_ID`, `REJECT_EMPTY_SEQUENCE` (authoring mistakes, warned about in debug
builds), `REJECT_WRONG_TIMELINE`, `REJECT_ALREADY_PLAYED`, `REJECT_DUPLICATE`, `REJECT_QUEUE_FULL` and
`REJECT_UNAVAILABLE` (the director is outside the tree, or a reset is running). The strings are `no_sequence`,
`invalid_id`, `empty_sequence`, `wrong_timeline`, `already_played`, `duplicate`, `queue_full`, `unavailable`.
The last four are normal outcomes and are not logged.

### Queue

One conversation plays at a time. A request made meanwhile joins a first-in, first-out queue (`max_queue_size`,
default 8). A request is refused as `duplicate` if its ID is already active or queued, even from a different
resource object, and as `queue_full` when the queue is full. A queued sequence that stops being eligible while it
waits (for example `mark_played` was called) is cancelled instead of started. When one blocking sequence is followed
by another from the queue, input stays locked rather than flickering off and on.

### Play once and the session history

`play_once` sequences are refused with `already_played` after they complete (finish or skip). Cancelled
sequences can be played again. The history records every completed sequence, but only `play_once` sequences are
refused by it. It lives in the director, for the session only; there is no save file. `reset_session()` clears it.

### Timeline

A director plays a sequence only if its `audience` is `Both` or matches the director's timeline, which is
resolved in this order:

1. the `local_timeline` property or `set_local_timeline()` when set to Past or Future;
2. `NetworkManager.role` (`"past"` for the host, `"future"` for the guest);
3. `"past"`.

For split-screen, give each local player's director its own `local_timeline`, or pass `{"timeline": "future"}`
as the context of a request.

### Input

Input is read in `_unhandled_input`, only while a dialogue is active.

| Action | Property | Default | Behaviour |
|---|---|---|---|
| Advance | `advance_action` | `ui_accept` (Enter, Space) | Reveal, then continue. The event is marked handled. |
| Skip | `skip_action` | `ui_cancel` (Esc) | Skips if the sequence allows it, and only then marks the event handled. |

- Movement and every other action are never consumed.
- A key held down does not repeat the action (echo events are ignored).
- Input in the frame a sequence starts is ignored, so the press that triggered a conversation cannot also advance it.
- An action missing from the InputMap, or an empty name, is ignored.
- A focused button takes `ui_accept` before `_unhandled_input` sees it. Give test buttons `focus_mode = FOCUS_NONE`, as the sandbox does.
- Clicking the dialogue panel with the left mouse button also advances.

## `DialogueBox`

Presentation only. It never decides what comes next.

- **Typewriter:** one `Tween` on `RichTextLabel.visible_characters`, killed before every new line. The full text
  is laid out from the start, so the panel never changes size while it types. Empty text and speeds so fast the
  reveal would take under 20 ms complete at once.
- **Accents:** `past_accent` `#E4BF7F`, `future_accent` `#86C9D1`, `rift_accent` `#9F96E8` (exported, editable). They colour the
  panel border, the speaker name and the continue indicator.
- **Layout:** bottom-centre, 1080 px wide, 112 px above the bottom edge in the project's 1600x900 design space, growing upward for longer text. It scales with the
  window (checked at 1600x900 and 1280x720). The Interaction System's `[F]` prompt is also bottom-centre, on the same canvas layer, and sits directly
  beneath the box with a clear gap; it does not overlap it.
- **Continue indicator:** a pulsing `▼`, shown only when the player's input is needed (not while auto-advancing).
- **Fades:** 0.18 s in, 0.22 s out. Showing a new line mid-fade reverses it without a flicker.
- **Independent instances:** the panel style is `resource_local_to_scene`, so two boxes never share a colour.
- **Voice:** a line's `voice` plays on the box's `VoicePlayer`, which uses the Master bus. The audio system provisions `Master`, `Music`, `SFX`, `UI` and
  `Ambience`; if a voice bus is added later, set `VoicePlayer.bus` in `dialogue_box.tscn`.

Useful members: `present_line(line, cps, show_continue)`, `reveal_all()`, `close(immediately)`, `is_typing()`,
`is_open()`, `get_accent_for(timeline)`, `get_speaker_text()`, `get_line_text()`.

## `DialogueTrigger`

A node that turns "something happened" into a dialogue request, so gameplay scripts never reference dialogue.

| Field | Meaning |
|---|---|
| `sequence` | The conversation to request. |
| `source` + `source_signal` | The node and the signal to listen to. Autoloads are `/root/PuzzleManager`. Signals of any shape work, up to 8 arguments. |
| `argument_index` + `argument_value` | Only react when that argument (as text) equals the value. `-1` reacts to every emission. |
| `director` | Which director to ask. Empty uses the first one in the `dialogue_director` group. |
| `trigger_on_ready` | Request the sequence once the whole scene has loaded. |
| `enabled` | A disabled trigger does nothing. |

Call `trigger(context := {})` from code. A misconfigured trigger (missing node or signal, too many arguments)
warns in debug builds and `is_listening()` reports `false`.

## Recipes

### Handle completion

```gdscript
@onready var director: DialogueDirector = $DialogueSystem

func _ready() -> void:
	director.dialogue_finished.connect(_on_dialogue_finished)
	director.dialogue_cancelled.connect(_on_dialogue_cancelled)

func _on_dialogue_finished(sequence_id: String) -> void:
	if sequence_id == "first_rift_contact":
		print("The rift conversation is over.")

func _on_dialogue_cancelled(sequence_id: String) -> void:
	print("%s was cut short." % sequence_id)
```

### Different conversations for the Past and the Future

Write one sequence per timeline and request both. The director plays the one that matches its timeline and
quietly refuses the other (`wrong_timeline`), so the calling code never branches on who the player is.

```gdscript
const POWER_ON_PAST := preload("res://resources/dialogue/power_on_past.tres")      # audience: Past
const POWER_ON_FUTURE := preload("res://resources/dialogue/power_on_future.tres")  # audience: Future

func announce_power_restored(director: DialogueDirector) -> void:
	director.play_dialogue(POWER_ON_PAST)
	director.play_dialogue(POWER_ON_FUTURE)
```

### After PuzzleManager confirms a puzzle

`PuzzleManager.puzzle_completed(puzzle_id)` fires on **both** peers, only for confirmed completions, and a
resync does not replay it. Each peer therefore starts its own conversation from the one confirmed event.

**With no code**, add two `DialogueTrigger` nodes to the room:

| Field | Past trigger | Future trigger |
|---|---|---|
| `sequence` | `power_on_past.tres` | `power_on_future.tres` |
| `source` | `/root/PuzzleManager` | `/root/PuzzleManager` |
| `source_signal` | `puzzle_completed` | `puzzle_completed` |
| `argument_index` / `argument_value` | `0` / `power_switch` | `0` / `power_switch` |

**Or in code**, requesting both conversations as in the previous recipe:

```gdscript
const POWER_ON_PAST := preload("res://resources/dialogue/power_on_past.tres")      # audience: Past
const POWER_ON_FUTURE := preload("res://resources/dialogue/power_on_future.tres")  # audience: Future

func _ready() -> void:
	PuzzleManager.puzzle_completed.connect(_on_puzzle_completed)

func _on_puzzle_completed(puzzle_id: String) -> void:
	if puzzle_id != "power_switch":
		return
	var director := get_tree().get_first_node_in_group(DialogueDirector.GROUP) as DialogueDirector
	director.play_dialogue(POWER_ON_PAST)
	director.play_dialogue(POWER_ON_FUTURE)
```

A rejected action, or a different puzzle completing, starts nothing. Dialogue never changes puzzle state.

### From the Interaction System

`Interactable3D` (see `docs/INTERACTION_SYSTEM.md`) emits `interacted(actor, role)` when the player uses it. A
`DialogueTrigger` beside it turns that into a conversation, with no code:

```text
Terminal (Node3D)
|-- Interactable3D   (Area3D, interactable_3d.gd)   interaction_name = "Read Notes"
`-- DialogueTrigger  (Node, dialogue_trigger.gd)    sequence       = terminal_notes.tres
                                                    source         = ../Interactable3D
                                                    source_signal  = interacted
```

The interaction's own rules (distance, timeline, `one_shot`, timing) apply first; the director's rules (audience,
play-once, queue) apply second. A repeatable object with a `play_once` conversation still reacts every time, but the
conversation is quietly refused after the first. Set `one_shot` on the interactable instead if the object itself
should stop working.

Or from code, with the same effect:

```gdscript
const TERMINAL_NOTES := preload("res://resources/dialogue/terminal_notes.tres")

func _ready() -> void:
	$Interactable3D.interacted.connect(_on_terminal_interacted)

func _on_terminal_interacted(_actor: Node, _role: String) -> void:
	var director := get_tree().get_first_node_in_group(DialogueDirector.GROUP) as DialogueDirector
	director.play_dialogue(TERMINAL_NOTES)
```

Give research documents their own sequences (one line per paragraph, `speaker_name` empty for narration). A sequence can
also be non-blocking, so the player keeps moving while a remark scrolls past.

### In a cutscene

The director never touches the camera and does not assume a cutscene exists. A cutscene can wait for a
conversation like this; it also works if the request is refused or the conversation is cancelled:

```gdscript
signal _dialogue_ended(sequence_id: String, finished: bool)

@onready var director: DialogueDirector = $DialogueSystem

func _ready() -> void:
	director.dialogue_finished.connect(func(id: String) -> void: _dialogue_ended.emit(id, true))
	director.dialogue_cancelled.connect(func(id: String) -> void: _dialogue_ended.emit(id, false))

## Returns true if the conversation played to its end (or was skipped).
func play_and_wait(sequence: DialogueSequence) -> bool:
	if not director.play_dialogue(sequence):
		return false
	var result: Array = await _dialogue_ended
	while result[0] != sequence.sequence_id:
		result = await _dialogue_ended
	return result[1]

func opening_cutscene() -> void:
	# await camera_pan()
	await play_and_wait(preload("res://resources/dialogue/samples/opening_past.tres"))
	# await camera_return()
```

Because every accepted request ends in `dialogue_finished` or `dialogue_cancelled`, this cannot wait forever.

### Narrative events

```gdscript
func _ready() -> void:
	$DialogueSystem.narrative_event_requested.connect(_on_narrative_event)

func _on_narrative_event(event_id: String) -> void:
	match event_id:
		"rift_activated":
			pass  # start the rift glow
		"rift_voice_detected":
			pass  # flicker the rift while the Unknown Voice speaks
		"rift_conversation_finished":
			pass  # settle the rift, unlock the next objective
```

The dialogue system only announces these. Events fire at line start, and a skipped sequence still announces the
events of every line it skipped, in order, so skipping never leaves the story out of step.

### Lock the player during blocking dialogue

`gameplay_input_block_changed(blocked)` is the hook. The player already has a `controls_enabled` flag, and the
Interaction System's controller has `set_interaction_blocked()`, so the glue is a few lines in the scene that owns
them:

```gdscript
@onready var player: CharacterBody3D = $Actors/Player
@onready var director: DialogueDirector = $DialogueSystem

func _ready() -> void:
	var controller := player.get_node_or_null("InteractionRig/InteractionController")
	director.gameplay_input_block_changed.connect(func(blocked: bool) -> void:
		player.controls_enabled = not blocked
		if controller != null:
			controller.set_interaction_blocked(blocked))
```

Both lines matter. `controls_enabled = false` stops movement and the player's key handling, including the interact key.
`set_interaction_blocked(true)` also hides the `[F]` prompt, and the controller brings it back when the lock is released
(if the target is still in range). Skip the controller lines in rooms without an `InteractionRig`. See the pause caveat
under [Integrating](#integrating-into-the-game).

### Pausing the game

- **`get_tree().paused = true`** (what the interaction sandbox does): the director, its auto-advance timer, the typewriter and
  the input handling are all pausable, so a conversation freezes with the game and carries on when it resumes. The box
  stays on screen; set `director.dialogue_box.visible = false` if the pause menu should own the screen.
- **A pause that leaves the tree running** (`spawn_area.gd` shows its pause panel and disables the player but does not
  pause the tree): the conversation would keep typing and advancing behind the menu, and the box would draw above the
  panel. Freeze it explicitly:

```gdscript
func set_dialogue_paused(director: DialogueDirector, paused: bool) -> void:
	director.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	director.dialogue_box.visible = not paused
```

While disabled the director consumes no input, its timers and tweens stand still, and everything continues from where
it was when it is re-enabled.

### Forget the story

`director.reset_session()` ends whatever is playing, empties the queue and clears the play-once history.
Call it when a new run begins. There is no persistence; if progress ever has to survive a restart, save
`get_played_ids()` and replay it with `mark_played()`.

## Multiplayer notes

- The host (Past) and the guest (Future) each have their own director and play dialogue at their own pace.
  A conversation for `Both` is played independently by both, not in lock step.
- Nothing about dialogue is replicated. Pass it a confirmed gameplay event, never the other way round.
- `speaker_name` is the same text for both viewers; there is no per-viewer name.
- Timeline strings and event IDs are local data and never authorize gameplay changes.

## The sandbox

`scenes/testing/dialogue_sandbox.tscn` runs without the laboratory or any 3D asset.

- **Editor:** open the scene and press **F6** (*Run Current Scene*).
- **Command line:** `& $Godot --path . res://scenes/testing/dialogue_sandbox.tscn`

The buttons are testing aids; the dialogue box at the bottom is the real one. A square *marker* moves with WASD and
turns red and stops while a blocking dialogue plays, which is exactly what the player will do with the same signal.

| Control | What it shows |
|---|---|
| Play Opening / Rift / Future / Puzzle Completion Dialogue | The four samples. Past-only and Future-only sequences are refused on the wrong timeline; play-once ones are refused the second time. |
| Switch Local Timeline | Toggles the director between Past and Future. |
| Test Play-Once Behavior | Runs by itself and prints PASS/FAIL lines: first request accepted, second refused, history remembers it, repeatable sequences repeat. |
| Test Dialogue Queue | Five requests at once (playing, queued, timeline-refused, queued, duplicate) with PASS/FAIL against what the current timeline should do. |
| Test Skipping | A skippable sequence: press Esc and watch the skipped lines' events fire. |
| Test Skip Locked | A sequence that refuses to be skipped; the sandbox also calls `skip_dialogue()` itself and reports the refusal. |
| Test Blocking / Non-Blocking Playback | The marker locks, or keeps moving. |
| Stop Dialogue / Reset Dialogue Session | `stop_dialogue()` and `reset_session()`. |

The state panel shows the director's state, sequence, line, speaker, queue, input lock and history live. The log
shows every signal in order.

## Tests

```powershell
$env:GODOT_BIN = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
python tests/run_dialogue_tests.py              # import the project, then the dialogue suite
python tests/run_dialogue_tests.py --regression # ...and the puzzle, spawn area and student suites
```

Or directly (import the project once first, so the new `class_name`s are registered):

```powershell
& $Godot --headless --path . --import
& $Godot --headless --path . --script res://tests/dialogue_system.gd
```

The runner also fails on any `SCRIPT ERROR`, `Parse Error` or `ERROR:` line, because the Godot script prints PASS
even when the engine logs one. The suite covers: the sample files against the specified text; validation; `.tres`
round-trips; starting, refusing and queueing; the state machine and signal order; speaker names, text and BBCode;
the typewriter (gradual reveal, early reveal, replaced lines, closing mid-reveal); empty lines and missing
portraits, voices and names; skipping and cancelling; queue order, duplicates, limits and clearing; timeline
filtering including `NetworkManager.role`; play-once and reset; blocking and non-blocking input locks; Enter,
Space and Esc through real key events; mashed input; scene cleanup (with and without a box, with timers and tweens
pending); independent directors and boxes; listeners calling back into the director; swapping the box;
pausing (a paused tree, and a disabled director); the trigger adapter; the hand-off from `PuzzleManager`; the hand-off
from `Interactable3D` (skipped, with a printed note, in a checkout without the Interaction System); and the sandbox scene. The multi-process LAN tests are not
affected and stay in `run_puzzle_tests.py` and `run_lan_smoke.py`.

## Integrating into the game

Nothing here edits `project.godot`, `spawn_area`, the player, `NetworkManager` or `PuzzleManager`. When the other
work lands, choose one:

**A. Per scene (simplest).** Instance `scenes/dialogue/dialogue_system.tscn` as a child of the room root. Each
player's director is then created and freed with their room.

**B. Autoload (one director for the whole game).** Add to `project.godot` after the two existing entries:

```ini
[autoload]

NetworkManager="*res://scripts/network/network_manager.gd"
PuzzleManager="*res://scripts/puzzles/puzzle_manager.gd"
DialogueSystem="*res://scenes/dialogue/dialogue_system.tscn"
```

The autoload *is* the `DialogueDirector`, so `DialogueSystem.play_dialogue(sequence)` works anywhere in
scripts that are loaded in the running game. (A `--script` test file compiles before autoloads exist; look it up
with `get_tree().root.get_node("DialogueSystem")` there, as the other tests do for the existing autoloads.)

Either way, check these:

1. **The Esc key.** `spawn_area.gd` handles `ui_cancel` in `_input()`, which runs before `_unhandled_input`, so
   Esc will pause the game and the dialogue will never see it. Register a dedicated action such as `dialogue_skip`
   in the Input Map and set `skip_action = &"dialogue_skip"` on the director. The same goes for `advance_action`
   if `ui_accept` is ever claimed by something else. Scenes that handle Esc in `_unhandled_input`, such as the
   interaction sandbox, already behave well: the director is deeper in the tree, so it receives Esc first, consumes it
   for a skippable sequence and leaves it alone for an unskippable one, which lets the pause menu have it.
2. **The pause menu also locks the player.** `spawn_area.gd` sets `player.controls_enabled` when pausing, and it does
   not pause the tree. If the dialogue lock handler writes the same flag, a dialogue that ends while the game is
   paused would re-enable the player behind the pause menu. Track the two reasons separately, for example
   `player.controls_enabled = not (_paused or _dialogue_blocked)`, and freeze the conversation with
   `set_dialogue_paused()` from [Pausing the game](#pausing-the-game).
3. **The HUD and the prompt.** The box draws on canvas layer 10, above the HUD (layer 1), and sits 112 px up so it
   clears the HUD's hint lines. The `InteractionPrompt` is on the same layer and sits beneath the box. Adjust `layer`
   or the panel's offsets in `dialogue_box.tscn` if either changes.
4. **Timeline.** Nothing to do over the network: the director follows `NetworkManager.role`. In the solo preview
   call `director.set_local_timeline("future")` when the preview toggles the timeline.
5. **Documentation.** `PROJECT_CONTEXT/00_START_HERE.md` and `13_AI_HANDOVER.md` still list the dialogue UI as missing.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Parse errors such as *Could not find type "DialogueLine"* | The new `class_name`s are not registered yet. Open the project in the editor once, or run `godot --headless --path . --import`. |
| `play_dialogue()` returns `false` | Connect `dialogue_rejected`, or check the sandbox log, for the reason. Most often `wrong_timeline` (the director's timeline is not the sequence's audience) or `already_played`. |
| Nothing is shown | The director has no box (it runs invisibly by design), or the sequence has no lines with text. |
| Enter does nothing | A focused `Button` took it, or something handles `ui_accept` earlier. Give the button `focus_mode = FOCUS_NONE`, or use a dedicated `advance_action`. |
| Esc pauses instead of skipping | See *Integrating*, item 1. |
| The player keeps moving during a blocking dialogue | Nothing listens to `gameplay_input_block_changed` yet. See *Lock the player*. |
| A conversation never repeats | `play_once` is on, or the ID was passed to `mark_played`. `reset_session()` clears the history. |
| Italic text looks upright | The serif `SystemFont` falls back to a font without an italic face. Georgia, the first choice on Windows, has one. |

## Not included

Final story text, portraits, voice acting, a speaker registry or per-speaker colours (the accent follows the
line's timeline), translation, save files for narrative history, a cutscene system, and any dialogue network
protocol.
