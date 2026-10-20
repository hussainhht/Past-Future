# Temporal Radio verification — 20 October 2026

Executed in this Windows checkout using Godot **4.7.2 stable official ed1daf0bf**, GL Compatibility. Tests use the repository's existing autoloads and ENet implementation. No protected source files or project settings were modified.

## Final results

| Executed check | Result |
|---|---|
| Headless editor import / script registration | Exit 0; no script or engine errors |
| `tests/run_frequency_tests.py` → rules | **PASS: 59 checks** |
| Same runner → real-scene integration | **PASS: 72 checks** |
| Same runner → real ENet host process | **PASS: 16 checks** |
| Same runner → real ENet client process | **PASS: 22 checks** |
| Rendered integration at 1280×720 | **PASS: 78 checks**, including six PNG captures |
| Existing `tests/run_puzzle_tests.py` | **PASS: 131 checks**, plus both real ENet peers |
| Existing `tests/interaction_system.gd` | **PASS: 54 checks** |
| Existing `tests/audio_system.gd` | **PASS: 80 checks** |
| Audio teardown regression, four independent headless integration runs | All four passed; no engine errors or leaked-at-exit warnings |
| `git diff --check` / existing-file diff | Clean; no tracked existing-file modifications |

The new radio suite contains **169 assertions** across rules, real scenes and two real peers. Its runner checks exit codes and complete logs, refuses engine/script errors and leaked-at-exit warnings, and requires the expected success marker. A PASS printed before a shutdown error is not accepted.

During final QA the strict runner caught an intermittent in-flight audio playback resource at fast headless process shutdown. Static now stops on component exit; the integration harness stops its owned AudioDirector playback and permits a mixer cycle before quitting. The complete suite and four separate teardown runs passed after this correction. The existing audio implementation was preserved.

## Verified behavior

- Initial state has exactly three false prerequisite flags, with no redundant connection/secret-frequency fields.
- Student and Professor acquire their own physical placeholder radios through the existing interaction detector/controller.
- Wrong-owner pickups, self-declared network roles, extra authoritative payload keys, invalid frequency types and out-of-range values are rejected.
- Wrong valid frequencies produce retry feedback without revisions, completion, or a revealed answer.
- Both pickup orders work, including calibration waiting for a later Professor pickup.
- Confirmed connection, repeated actions and resets produce the correct revisions and exactly one completion per solve.
- Client acquisition is pending until host confirmation; both peers receive matching prerequisite state and revisions.
- A requested full snapshot restores connection without replaying completion or its narrative trigger.
- Fresh room indicators, character radios and terminal instances recover the existing session state immediately.
- New sessions clear ownership/calibration; old-session updates cannot restore a stale connection. Disconnect ends the host session and removes radio readiness.
- Terminal invalid-input handling, focusable controls, incorrect/connected feedback, Escape close, reopen and modal unload restore movement safely.
- Future-only research text displays 67 MHz; an uncalibrated Past HUD displays `-- MHz`.
- HUD states, held-mesh visibility, local activation, temporary interference, signal recovery and transmission cues remain separate from canonical state.
- Sequence-ID request bindings, Past/Future/shared audience filters, alternating Student/Professor lines, typewriter reveal, later narrative events, later confirmed puzzle completions and dialogue completion work through the adapter boundary.
- The temporary sandbox sequence starts on confirmed establishment and finishes without requiring DialogueDirector.

## Visual review

Six actual OpenGL Compatibility renders were captured and inspected at **1280×720** using AMD Radeon graphics:

1. Past lab, unowned radio and disconnected HUD.
2. Open calibration terminal.
3. Incorrect-frequency retry feedback.
4. Professor radio transmission, speaker label, 67 MHz indicator and connected HUD.
5. Future research document.
6. Reopened connected terminal with locked frequency and required success text.

The captures are under `%TEMP%\past-future-radio-review` on this machine and can be regenerated using the command in `FREQUENCY_PUZZLE.md`. The terminal, reader and radio overlay fit without clipping at the requested resolution.

## Pending integration and practical limits

- Real DialogueDirector / DialogueSequence binding awaits the parallel agent's confirmed public API. Tests exercise the radio adapter and a clearly isolated temporary UI driver; they do not claim the unmerged director was tested.
- Both ENet peers ran on loopback. A two-physical-PC LAN smoke test remains a deployment check.
- Production laboratory placement, opening-cutscene hookup, final radio/Professor assets, hand animations and approved story/audio content remain separate integration work. Placeholder objects use replaceable references.
- The link persists within a game session, not across quitting and loading a disk save. Dialogue line advancement is local presentation; no new synchronized dialogue protocol or player communication service was introduced.

See `FREQUENCY_PUZZLE.md` for the full source manifest, public APIs, host authority, stage integration, mesh replacement instructions, and exact sandbox/test commands.
