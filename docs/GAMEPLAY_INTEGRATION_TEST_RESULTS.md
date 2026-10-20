# Integrated gameplay verification — 20 October 2026

Tested with Godot **4.7.2 stable official ed1daf0bf** on Windows. Rendered checks used **GL Compatibility / OpenGL 3.3 on AMD Radeon graphics**, at **1280×720**.

The final game entry remains the existing Main Menu. New integration tests enter the real `scenes/world/spawn_area.tscn`; they do not use a sandbox.

## Final executed results

| Executed suite/check | Final result |
|---|---|
| Headless editor import and script registration | Exit 0; no parse/script errors |
| `tests/run_gameplay_tests.py`: menu-driven solo | **PASS — 68 checks** |
| Same runner: actual menu/ready/gameplay ENet host | **PASS — 27 checks** |
| Same runner: actual menu/ready/gameplay ENet client | **PASS — 28 checks** |
| Rendered `gameplay_integration.gd` | **PASS — 77 checks**, including nine PNG captures |
| Additional independent integrated scene/audio lifecycle runs | **3 clean passes** after the ambience fixes |
| Existing Dialogue System | **PASS — 382 checks, 0 failures** |
| Existing Puzzle System | **PASS — 131 checks, 0 failures**, plus both real puzzle-sync peers |
| Existing spawn-area regression | **PASS — 0 failures** |
| Existing Student character regression | **PASS — 0 failures; all 77 animation clips** |
| Existing Professor character regression | **PASS — 0 failures; all 77 animation clips** |
| Existing interaction regression | **PASS — 54 checks, 0 failures** |
| Audio regression, including new cleanup/loop checks | **PASS — 85 checks** |
| Existing frequency suite | **PASS — 59 rules + 72 scene integration + 16 host + 22 client checks** |
| Existing LAN smoke test | **PASS — occupied-port, host and client processes** |
| Final `git diff --check` | Clean |

The new menu/gameplay suite contains **123 checks** across solo and two real LAN peers. Its runner requires the expected success markers and rejects nonzero exits, timeouts, all engine/script ERROR lines and leaked-at-exit warnings. Rendered integration adds nine successful image writes to the 68 logic/UI checks. Direct regression checks also inspected full output rather than relying only on printed PASS lines.

Final dialogue/puzzle/spawn/character regression output was clean after test-owned audio-enabled rooms were closed through their real Return to Menu lifecycle. The audio suite intentionally checks a nonexistent sound ID and produces that expected warning. The occupied-port LAN negative test intentionally causes ENet's occupied-host error; its runner verifies refusal/recovery. These are deliberate negative cases, not gameplay failures.

## Verified solo flow

- Actual menu Play page → labelled Solo Test → actual painted laboratory, Student model, collision and following camera.
- One locally controlled character, one interaction rig, one actual DialogueDirector/DialogueBox, and role-appropriate HUD.
- Existing interaction detection, F input and real pickup/inspect/interact animations; repeated input during an action is refused.
- Student/Professor radio acquisition, hidden uncalibrated frequency, confirmed world-pickup removal and held hand-socket presentation without the studio paper.
- Safe offline role changes load the finished Professor/Student models, retain the radio component, and rebind camera, detector/controller, footsteps and held mesh.
- The actual console retries wrong frequencies without revisions, locks 67 MHz pending the second radio and restores confirmed success when reopened after room reload.
- Future research log reading, modal movement/interaction locks and Escape close without accidental pause.
- Actual Past/Future discovery resources via DialogueTrigger; actual shared radio resources via DialogueDirector and the ID-based adapter.
- Correct alternating speaker names, existing typewriter presentation, 67 MHz channel ribbon, static/interference, recovery and transmission animation.
- Pause remains above dialogue; Resume preserves an active dialogue's input lock.
- Receiver relay refuses premature use, then solves under its authoritative radio prerequisite and triggers a later conversation.
- The rift-side receiver can request another conversation after Puzzle 01, without changing its canonical revision.
- Reloading the actual gameplay scene preserves the session/revision/ownership/link and silently restores held meshes and indicators.
- Explicit Solo Reset restores both pickups, clears puzzles/dialogue history and returns to Student. Return to Menu releases presenters and network resources. The next menu-started game begins fresh.

## Verified real two-process multiplayer flow

- Two actual menus invoke Host and Join with a loopback UDP port, display the existing lobby and respect Ready before Start.
- Confirmed start loads real Past/Student and Future/Professor environments/models, with one independent local input character on each peer.
- Client movement never controls the host character. LAN role/reset test controls are unavailable.
- A client request with a forged Past role cannot tune the frequency; the host authenticates the Future connection.
- Animated Future pickup remains unowned until confirmed; the host then acquires its own radio and calibrates the actual main terminal.
- Both peers receive the same three prerequisites, connected HUD/rift state and real radio dialogue after one confirmed completion.
- Full snapshot recovery retains canonical revision without replaying the conversation.
- Auxiliary relay completion starts the next real radio conversation on both peers.
- Both peers reload the actual room without losing connection or replaying story completion.
- Host pause retains the network session. Host Return to Menu disconnects cleanly; the guest receives a recovery overlay, loses radio readiness, stops dialogue and can return to the actual menu.

## Corrections made during verification

- Imported ambience resources had zero loop bounds. The controller now uses local duplicate streams with a nonempty full-sample range, without changing shared imported SFX configuration.
- Immediate ambience stop previously scheduled a Tween that could disappear with the room. Zero-fade stop is now synchronous and stream references are released on stop/exit. Audio tests cover these behaviors; the strict gameplay suite and repeated lifecycle runs passed.
- Blocking dialogue could freeze the final pickup pose before the next physics update. Character action completion now selects the resting/holding pose before emitting its completion signal.
- Older spawn assertions assumed Future only retinted the Student. They now follow the real Professor character replacement while retaining movement, collision, camera, studio and menu checks.
- The older LAN smoke test disconnected the host after a fixed 0.4-second load delay. The finished Professor model can load later, so the test now waits for the guest's actual scene acknowledgement using the existing PuzzleManager test fixture. No new production networking code was added.
- Tests that previously quit while leaving their menu-launched world active now use the normal Return to Menu cleanup before process shutdown. Tests still fail on engine errors; warnings were investigated rather than accepted solely because PASS had printed.

## Visual review

Nine actual rendered screenshots were captured and inspected under `%TEMP%\past-future-gameplay-review`:

1. Main Menu Play page with preserved styling and labelled Solo Test.
2. Actual Past laboratory and disconnected HUD.
3. Incorrect-frequency terminal feedback.
4. Actual Future laboratory and Professor model.
5. Actual DialogueBox radio transmission with speaker/typewriter/channel status.
6. Foreground pause UI above dialogue.
7. Research log modal.
8. Student holding the acquired placeholder radio.
9. Reopened connected console after actual room reload.

The menu, HUD, terminal, document, pause and dialogue layouts fit the target resolution without overlapping controls or clipped text. The held radio remains a placeholder with replaceable socket/visual references.

## Remaining limits

- LAN verification used two real processes over loopback. Two physical PCs on Wi-Fi remain untested.
- The available authored world is this one laboratory. Cross-room persistence was verified by unloading/reloading the actual scene; additional level content was not supplied in this checkout.
- Final radio meshes/hand offsets and final story wording remain asset/content polish. The real Professor model and actual Dialogue System are integrated.
- Dialogue sequence starts from shared confirmed events, but each peer advances lines locally, consistent with the existing director. There is no real-time player voice/chat service or new dialogue synchronization protocol.

No commits, pushes or branch merges were made. The pre-existing `project.godot` editor diff was preserved. See `GAMEPLAY_INTEGRATION.md` for the full created/modified file manifest and exact play/test commands.
