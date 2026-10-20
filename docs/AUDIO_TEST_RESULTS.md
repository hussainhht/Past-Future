# Audio validation ? 20?21 October 2026

Validation was limited to audio and the existing integrated gameplay checks, plus a short rendered review. Unrelated asset, character, dialogue-only and puzzle-only suites were not repeatedly run.

Engine: `C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`, reporting `4.7.2.stable.official.ed1daf0bf`. The actual game rendered through GL Compatibility at the normal 1280?720 window.

| Check | Result |
|---|---|
| Godot `--headless --editor --import --quit` | Exit 0; 43 replacement assets imported; no script/import errors |
| Existing `tests/audio_system.gd` | Exit 0; **271 checks passed**: 71 event IDs/streams, missing-ID handling, pools, cooldown, buses/volume/mute, loops, music/timeline selection, movement and cleanup |
| Walking/running | **6 walking / 10 running contacts over three seconds**; idle, airborne, blocked nominal movement, teleport and immediate-repeat checks passed |
| Existing `tests/gameplay_integration.gd`, rendered | Exit 0; **80 checks passed**, including nine review captures; actual menu ? Past/Future lab, physical pickups, calibration/retry, documents, dialogue, pause, reload and return |
| Final `tests/run_gameplay_tests.py` | Exit 0; **solo 71 / host 34 / client 36 checks passed**, including final fade/cleanup changes; no runtime errors or leaked-at-exit warnings |
| Host/client audio assertions | Independent local ambience/music/surfaces; one confirmed connection cue each; client snapshots and room reload do not replay it |
| Settings visual review | Five category sliders/mutes and existing display controls fit at 1280?720; screenshot retained |
| Replacement reference audit | No old WAV paths referenced by scripts, scenes, resources or tests before deleting 19 placeholders and their import files |

The unknown-ID test deliberately logs one expected warning. Headless Dummy checks event delivery, resource/routing state and lifecycle, not audible playback/DSP quality; one-shot allocation is skipped on that driver.

The initial audio run exposed two assumptions in older tests: manual movement did not advance the physics clock, and a timer assumed the fade callback had already run. They now use physics frames and the stop signal. The rendered gameplay check caught the real cross-PackedScene AudioDirector binding failure, fixed in room composition. An intermittent headless client shutdown retained a UI playback; Dummy-driver one-shots now emit accepted events without allocating an unusable playback. Affected checks were rerun after corrections.

Ignored local logs: `.godot/audio_import.log`, `audio_tests.log`, `audio_tests_output.txt`, `audio_gameplay_solo.log`, `audio_gameplay_solo_output.txt`, and `audio_review/`. Durable images: `docs/assets/audio/past_lab.png`, `future_lab.png`, `audio_settings.png`.

## Reproduce only the relevant checks

```powershell
$godotBin = 'C:\Users\hanwd\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $godotBin --headless --path . --script res://tests/audio_system.gd
$env:GODOT_BIN = $godotBin
.venv\Scripts\python.exe tests/run_gameplay_tests.py
```

## Manual listening route ? pending

Audio output could not be monitored. Rendered gameplay and screenshots do not establish subjective quality, loudness, audible seams, stereo image or latency. This is a checklist, not a claim that listening checks passed.

1. Launch `& $godotBin --path .`. Review Settings: Master, Music, Ambience, SFX and UI volume/mute. Return to menu and relaunch to confirm preferences.
2. Choose Play ? Solo Test. Stand still in the Past, then walk/run using existing controls. Listen for varied clean tile contacts, natural cadence, silence against walls and during controls locks, and restrained ventilation/music.
3. Acquire the Student's handheld on the left workbench. Hear one tactile pickup and at most one short pending-link scan. Use the rear computer, submit **66**, then **67**. Review gentle opening/closing, tuning cooldown, invalid feedback and lock. Connection must wait for the other radio.
4. Close the terminal and press **T** for the Professor. Compare concrete steps, exposed air and distinct sparse music. Acquire the Future handheld in the reading corner. Hear one confirmed synchronization cue, then restrained scripted text-transmission feedback.
5. Read the rear-console research log and desk documents. Review paper open/close cues. Approach and leave the rift: its loop should remain nearby and unobtrusive from a distance.
6. Review existing door/keypad responses and the receiver relay. Pause/resume, return to menu and re-enter. Listen for short fades, no lingering steps/loops, no duplicate layers and no replayed completion when reopening a connected terminal.
7. For LAN, host and join with two processes, mark the guest Ready and Start. Host should hear Past; client Future, each with local UI/radio cues and one success cue. Remote footsteps are unavailable without replicated remote movement.
8. During normal development, allow the Past bed (~53 seconds) and music (~132/171 seconds) to loop. Check the shorter Future wind/rift beds for repetition or seams. This does not require repeated automated test runs.

Final tuning: listen for harsh peaks/clipping, overly loud radio static, intrusive equipment details, repetitive rift texture, unnatural step tails and poor attenuation. Reduce/mute Music if it distracts from clues. Edited seams and conservative starting gains do not replace this human listening pass.
