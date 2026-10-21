# Objective Tracker and Mission Log

Each player has a personal objective list. The HUD card (upper left) shows the current one, and the
**Mission Log** (`M`, View/Create, DualSense touchpad, or the HUD's LOG button) shows completed, current
and upcoming objectives. The Student sees only Student objectives; the Professor only Professor ones.

## Architecture

| Piece | File | Role |
|---|---|---|
| Data | `resources/objectives/{student,professor}/*.tres` (`ObjectiveDefinition`) | Title, HUD summary, description, hint, icon, chapter, completion `conditions`, optional `expires`, `progress`, `secret`, `attempt_puzzle` |
| Rules | `scripts/objectives/objective_conditions.gd` | Pure condition vocabulary: `flag`, `one_of`, `at_least`, `array_count`, `solved`, `journal`, `room`, `any` |
| Manager | `scripts/objectives/objective_manager.gd` (autoload `ObjectiveManager`) | Loads definitions, re-evaluates on state change, remembers progress, owns Log open/close + input lock |
| HUD | `scripts/ui/objective_tracker.gd` / `scenes/ui/objective_tracker.tscn` | Card, "OBJECTIVE COMPLETED" notice, sound |
| Log | `scripts/ui/mission_log.gd` / `scenes/ui/mission_log.tscn` | The panel |
| Shared look | `objective_style.gd`, `objective_icon.gd` | Colours, panel styles, line-art glyphs drawn in code |

An autoload is justified because progress must outlive room scenes (like `JournalManager`).
It reads `PuzzleManager`, `JournalManager` and `GameFlowManager` and writes to none of them.
Adding an objective is adding a `.tres`; no code change.

## How progress is detected

Nothing is scripted per objective and there are no timers. `ObjectiveManager` re-reads confirmed
facts whenever they change (`PuzzleManager.puzzle_state_changed`, `JournalManager.entry_unlocked`,
`GameFlowManager.room_changed`) and completes every objective whose conditions now hold:

* **Shared puzzle state** (radios, calibration, service isolation, storage, access, anchors, reactor stage…) comes from `PuzzleManager.get_state`, i.e. the host-confirmed state on both peers.
* **Private discoveries** (reading the console log, the reactor-room documents) come from the local journal unlock, which already is per-role and local.
* **Arriving in a room** uses `GameFlowManager.room_changed`; walking into the lab's exit zone is *not* leaving.

Rules: an objective completes once (latched for the session); work already done when the manager
looks (snapshot, direct room launch) is filled in silently; unfinished objectives of earlier chapters are
left behind when a later room is entered directly; `expires` drops optional steps (e.g. a log nobody
needed) without claiming they were done; `attempt_puzzle` makes the reactor's objectives start over when
Room C restarts an attempt (overload or replay), without re-announcing pages already read.

## Multiplayer

Each peer runs its own manager and tracks only its own timeline (offline solo preview tracks both and
shows the one being played). View calls for the other timeline answer with the local one, so nothing can
leak by asking. No RPCs are added and no puzzle state is written; the host's confirmed puzzle state reaches
the guest through the existing `PuzzleManager` replication, and each peer derives its own list from it. A
new session (`session_started`/`session_ended`) clears everything, so a rejoin or restart starts at the
first objective; a resync inside the same session changes nothing and announces nothing.

## Mission Log behaviour

* Opens only when the journal, pause, modals, dialogue, cinematics, transitions and actions are idle.
* Locks local movement and interaction every frame while open (rooms recompute their controls each
  frame), then restores exactly what was there. It never pauses the tree and sends nothing, so the other
  player is unaffected and the reactor clock keeps running.
* The panel is moved to the end of the root so it hears Escape/B before any room; other raw keys and
  buttons (journal, role switch, pause) are held back while it is open. It closes on a level transition.
* Mouse wheel, d-pad/left stick (focus follows and scrolls), right stick, click outside, CLOSE button.
* Upcoming objectives: only the next step is shown; the rest read "Undiscovered Objective" / "???";
  later chapters are one anonymous "UNCHARTED AREA" row; `secret` steps stay hidden until current.
* Reduced Motion (`CinematicTransitionManager.is_reduced_motion`): fades only, no slides or shimmer.

## Input

`mission_log`: key `M`, `JOY_BUTTON_BACK` (Xbox View / DualSense Create), `JOY_BUTTON_TOUCHPAD`.
Checked against the InputMap: no other action uses them (`J` journal, `T` role switch, `F2`, `R`, `Esc`,
`G`, `F/I/E` untouched). Defined in `project.godot` and `InputManager`, with glyph labels.

## Tests

`python tests/run_objective_tests.py` (set `GODOT_BIN`): rules and spoiler scan plus a full three-level
playthrough for both roles (`objective_system.gd`), real rooms and Log behaviour (`objective_ui.gd`), and
two real ENet peers (`objective_peer.gd`).

## Known limits

* Level 2 → Level 3 is not wired in the game flow (`room_02.tres` has no `next_room_id`; `core_integration.gd` is unused). Room C objectives start when `room_03` is entered (menu test entry or a future link).
* Reading Room C's evidence and the Level 1 console log are local events, so only the reader's own tracker moves.
* Conditions that come from the player's own journal discoveries cannot be reconstructed after a restart of the game process (the journal is also not persisted).
