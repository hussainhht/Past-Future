# Journal System

One journal backend, two skins: the Student's paper **Notebook** (past) and the Professor's **Research DataPad** (future).
Each timeline has its own set of discovered entries. Nothing is sent over the network and nothing is saved to disk.

## Files

| File | Role |
|---|---|
| `scripts/journal/journal_entry.gd` | `JournalEntry` resource (id, title, subtitle, body, category, timeline, image, sort_order, unlock_on_puzzle) |
| `scripts/journal/journal_manager.gd` | Autoload `JournalManager`: entry registry, per-role progress, open/close, gameplay lock |
| `scripts/journal/journal_ui.gd`, `scenes/journal/journal_ui.tscn` | Shared UI built in code, two skins, toast + `J` corner hint |
| `scripts/journal/journal_unlock.gd` | `JournalUnlock` node: unlocks entries when its interactable is used |
| `resources/journal/student/`, `resources/journal/professor/` | Entry `.tres` files (folders are scanned recursively) |
| `tests/journal_system.gd` | One-shot check against the real game (see Testing) |

Touched existing files: `project.godot` (autoload + `journal` action), `laboratory_gameplay.gd` (`has_modal()` also reports the journal),
and the Room 01 scenes `research_notebook.tscn`, `lab_memo.tscn`, `console_terminal.tscn` (one `JournalUnlock` child each).

## Using it

- **Open/close:** `J` (InputMap action `journal`; attach a controller button to that action later). `Esc` closes it first.
  Arrow Left/Right or the Previous/Next buttons turn pages; the list and mouse wheel scroll.
- It will not open in menus, during transitions, dialogue, a terminal/document viewer, the pause menu, or while a character action plays.
- While open, the local player and interaction controllers are frozen and restored exactly afterwards.
  A starting level transition (`GameFlowManager.transition_started`) closes it.

## Adding an entry

1. Create a `JournalEntry` resource, e.g. `resources/journal/professor/future_blueprint.tres`
   (Inspector: set `entry_id`, `title`, `body` (BBCode ok), `category`, `timeline`, optional `image`).
   `timeline` decides whose journal it belongs to (Past = Student, Future = Professor, Both = either).
2. Choose a trigger (no manager changes needed):
   - **Interaction:** add a `JournalUnlock` node as a child of the `Interactable3D` (or of a device that owns one) and list `entry_ids`.
     One node can list entries for both timelines; only the one matching the local player unlocks.
   - **Confirmed event:** set `unlock_on_puzzle` to a puzzle ID; it unlocks when that puzzle completes.
   - **Code:** `JournalManager.unlock_entry("future_blueprint")` (returns `true` only when newly added).

Other API: `is_unlocked(id)`, `get_unlocked_entries()`, `open_journal()`, `close_journal()`, `reset()`.

## Timelines and persistence

- The local role is `PuzzleManager.get_local_role()` (the assigned role online, `offline_role` in solo preview).
  An entry for the other timeline is ignored by `unlock_entry`, so nothing leaks between roles. In solo preview, switching role shows that role's own journal.
- The Professor may discover the Student's old pages: author an entry with `timeline = Future` (see `future_recovered_notebook_page.tres`).
- The autoload outlives scene changes, so progress carries from Room 01 into Room 02 and beyond.
- Progress resets on `PuzzleManager.session_started` / `session_ended` (new game, Reset Solo, leaving the session).

## Future rooms

Room 02 / 03 content is just new `.tres` files plus `JournalUnlock` nodes (or `unlock_on_puzzle`) in those scenes.
Room scripts that manage their own controls can add `or JournalManager.is_open()` to their modal check (as `laboratory_gameplay.gd` does);
rooms without that still work through the manager's generic lock.

## First-level content

| Entry | Who | Trigger |
|---|---|---|
| Lab Experiment Notes | Student | Read the research notebook |
| Research Observations | Student | Use the rear main computer |
| Temporal Anomaly | Student | Frequency puzzle completes |
| Recovered Frequency Log (67 MHz) | Professor | Read the recovered log at the console |
| Laboratory Incident Record | Professor | Read the lab memo |
| Recovered Notebook Page | Professor | Read the research notebook |
| Temporal Fracture Observation | Professor | Frequency puzzle completes |

## Testing

- Import check: `godot --headless --path . --import` (no script/resource errors).
- Journal check: `godot --headless --path . -s tests/journal_system.gd` prints `JOURNAL CHECK OK`.
- Manual: Solo preview, press `J` as the Student, read the notebook (bottom-right hint shows new entries), `T` to the Professor,
  read the log at the rear console, press `J`; finish the radio puzzle and use the exit to Room 02 and confirm the DataPad still lists the entries.
