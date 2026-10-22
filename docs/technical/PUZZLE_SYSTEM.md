# Puzzle System

A puzzle is a small rules script. `PuzzleManager` (autoload) owns state and networking. Scenes only listen.

```text
Interaction / UI / script
        |  PuzzleManager.submit_action(id, action, payload)
        v
PuzzleManager (host or offline)        Client: sends a reliable RPC to the host instead
   validate -> puzzle.validate_action   Host derives the sender's role from the connection
   apply    -> puzzle.apply_action
   commit state, revision += 1
        |  signals (host) / RPC then signals (client)
        v
puzzle_state_changed, puzzle_completed, puzzle_reset  ->  PuzzleListener  ->  your door, light, screen
```

| Piece | File | Owns |
|---|---|---|
| PuzzleManager | `scripts/puzzles/puzzle_manager.gd` | Registry, canonical state, revisions, sessions, all puzzle RPCs |
| PuzzleBase | `scripts/puzzles/puzzle_base.gd` | The contract a puzzle implements |
| Implementations | `scripts/puzzles/implementations/` | One file per puzzle; rules only, no networking |
| PuzzleListener | `scripts/puzzles/puzzle_listener.gd` | "Apply current state now, and on every change" for world objects |

`NetworkManager` is unchanged. `PuzzleManager` follows its `state_changed` and `game_started` signals.

## Modes

One code path, three modes, chosen from `NetworkManager`:

- **Offline** (solo preview, future split-screen): the manager is its own authority. The acting role comes from `offline_role`, or from the `actor_role` argument (split-screen input routers pass it per call).
- **Host** (Past): validates every action, local or remote, then publishes the confirmed change to the guest.
- **Client** (Future): `submit_action` sends a request and returns `PENDING`. State changes only when the host confirms it.

In a network session the role always comes from the real connection. A client cannot name its own role, and `actor_role` is ignored.

## Create a puzzle

Copy `implementations/power_switch_puzzle.gd`. Override only what you need:

| Method | Purpose |
|---|---|
| `get_initial_state()` | Starting state, and the state after a reset. Host only, so it can also roll a secret. |
| `get_actions()` | `{action_name: [allowed roles]}`. An empty list allows either role. |
| `get_prerequisites()` | Puzzle IDs that must be solved first. |
| `validate_action(action, payload, role, state)` | Return `""` if OK, else a reason code. Call `super()` first, then check the payload. |
| `apply_action(action, payload, role, state)` | Edit the `state` copy and `return change(state)`, or `no_change()` / `reject(reason)`. |
| `is_solved(state)` | Completion condition. Default: `state.solved == true`. |

Rules of thumb:

- State is replicated to both players. Hidden answers go in member variables of the puzzle, never in state.
- You receive copies of `payload` and `state`. Only the state you return is kept.
- Returning an identical state counts as `no_change`, so repeats never create revisions or completion events.
- Everything a payload contains came from a player. Validate types and ranges.

## Register

```gdscript
func _ready() -> void:
	if not PuzzleManager.is_registered("electricity_puzzle"):
		PuzzleManager.register_puzzle("electricity_puzzle", ElectricityPuzzle.new())
```

- Register on both peers so rooms can stay symmetric. A client needs no logic to display state.
- IDs are free-form strings. Nothing in the manager lists them.
- A second, different instance for a taken ID returns `ERR_ALREADY_EXISTS`; pass `replace = true` to swap rules.
- `unregister_puzzle(id)` detaches the rules but keeps the state, so unloading a room never loses progress.
- A puzzle registered after the session began gets its initial state and is sent to the client.

## Submit actions

```gdscript
var result := PuzzleManager.submit_action("electricity_puzzle", "activate_switch", {"switch_id": 2})
```

`result.status` is one of `PuzzleManager.Status.REJECTED`, `NO_CHANGE`, `CHANGED`, `COMPLETED`, `PENDING`.
A rejection carries `result.reason` (for example `role_not_allowed`, `unknown_action`, `invalid_payload`, `prerequisite_not_met`, `no_session`).
Interaction code, UI buttons, and scripted events all use this one call.

## Listen for confirmed changes

Prefer `PuzzleListener`: add it as a child, set `puzzle_id`, connect `state_applied(state, solved)`. It fires once on entering the scene, then after every change.

```gdscript
func _ready() -> void:
	$PuzzleListener.state_applied.connect(_on_state_applied)

func _on_state_applied(state: Dictionary, _solved: bool) -> void:
	$Door.visible = not state.power_on
```

Or connect to `PuzzleManager.puzzle_state_changed(id, state, revision)`, `puzzle_completed(id)`, `puzzle_reset(id)`, `action_rejected(id, action, reason, role)`. `puzzle_completed` fires once per unsolved-to-solved transition. A snapshot (session start, resync) restores state without replaying completions.

## Past and Future consequences

Keep one state and let each timeline present it. For a `bridge_puzzle` with `{support_repaired, bridge_accessible}`:

```gdscript
# In the Past room:   $Support.visible = state.support_repaired
# In the Future room: $Bridge.visible  = state.bridge_accessible
```

One accepted Past action changes the state once, under one revision. Both rooms derive their visuals from it. `PuzzleManager.get_local_role()` returns `"past"` or `"future"` when a shared script needs to branch.

## Reset and sessions

- `reset_puzzle(id)` / `reset_all()` return puzzles to initial state under a new revision (host/offline only).
- `begin_session()` starts a clean session with a new ID. It runs automatically when a LAN game starts and when the menu opens the solo preview. Call it yourself when split-screen starts.
- A session ends when the guest disconnects or the host leaves. Actions are refused (`no_session`) until the next one starts.

## Revisions and safety

- The host increments one revision counter for every confirmed change and publishes it with the puzzle's new state.
- Clients ignore updates that are not newer than what they hold, and updates from another session.
- The host sends a full snapshot when a game starts. A client can ask again with `request_sync()`.
- `get_state(id)` and signal payloads are deep copies. Editing them changes nothing.
- Rejections are logged with `push_warning` in debug builds. Set `PuzzleManager.log_rejections = false` to silence them.

## Test

```powershell
$env:GODOT_BIN = "C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
python tests/run_puzzle_tests.py
```

This runs `tests/puzzle_system.gd` (offline rules, signals, sessions, replica sync) and then two Godot processes over ENet loopback (`tests/puzzle_peer.gd`). The runner also fails on `SCRIPT ERROR:` lines, because the Godot scripts print PASS regardless. Test-only puzzles live in `tests/puzzle_fixtures.gd`.

Autoload names are not available while a `--script` file's `preload`s compile. Test scripts therefore `load()` the manager and listener at runtime.

## Complete example: add a puzzle without touching PuzzleManager

```gdscript
# scripts/puzzles/implementations/dial_puzzle.gd
extends "res://scripts/puzzles/puzzle_base.gd"

var _target: int = 0  # hidden from the Past player; stays on the host

func get_initial_state() -> Dictionary:
	_target = randi_range(1, 9)
	return {"solved": false, "dial": 0}

func get_actions() -> Dictionary:
	return {"set_dial": [PAST]}

func validate_action(action: String, payload: Dictionary, role: String, state: Dictionary) -> String:
	var reason := super(action, payload, role, state)
	if reason.is_empty() and not (payload.get("value") is int and payload.value >= 0 and payload.value <= 9):
		return "invalid_payload"
	return reason

func apply_action(_action: String, payload: Dictionary, _role: String, state: Dictionary) -> Dictionary:
	state.dial = payload.value
	state.solved = state.dial == _target
	return change(state)
```

```gdscript
# In any room script, on both peers:
PuzzleManager.register_puzzle("dial_puzzle", preload("res://scripts/puzzles/implementations/dial_puzzle.gd").new())

# From the interaction code:
PuzzleManager.submit_action("dial_puzzle", "set_dial", {"value": 4})
```

No networking code, no manager edits, no new signals. The client, host, and offline modes all work.
