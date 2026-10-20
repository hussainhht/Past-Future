# Past-Future audio implementation

Implemented 20?21 October 2026 in the real playable Signal Laboratory (`scenes/world/spawn_area.tscn`), on the existing `main` branch. The overhaul replaces 19 generated WAV placeholders and their import files with 43 acquired/prepared CC0 assets (5.86 MiB). The native catalog exposes 71 event IDs. Existing movement, interactions, ENet authority, puzzle rules and written dialogue remain the event sources. No commits were created.

## A. Architecture

Each loaded menu or laboratory has one AudioDirector. The menu uses the same `scenes/audio/audio_system.tscn` implementation as gameplay. Public methods include `play_sfx(id)`, `play_ui(id)`, `play_world_sfx(id, position)`, `start_ambience(id)`, `start_music(timeline)`, `start_soundscape(timeline)` and corresponding stop methods.

`resources/audio/sound_events.tres` is a native Resource with an editable event dictionary and explicit AudioStream export dependencies. Each event defines files, bus, volume, pitch variation, spatial intent, cooldown, priority, concurrency limit and loop behavior. SoundCatalog loads native streams. Missing IDs return false and warn once; missing stream paths warn and are omitted. Gameplay scripts use stable IDs rather than asset paths.

One-shots reuse 12 non-positional and 8 positional players. Cooldowns/concurrency prevent rapid repetition, and low-priority hover/detail cues cannot steal important playback. Multiple variants avoid immediate repetition. The headless Dummy driver accepts/emits event hooks without allocating native one-shot playbacks: it cannot output sound and can otherwise retain a playback at shutdown. Real output uses AudioStreamPlayer/AudioStreamPlayer3D.

The existing AmbientAudioController is reused for ambience and music, with two players per layer, duplicate-start protection and Tween crossfades. Both layers belong to the same director. The scene-owned rift Hum player and character-owned footstep player are bounded components using the shared catalog. Teardown stops players, releases streams, cancels tweens and cancels delayed radio scans.

To add sounds: import a licensed WAV/OGG, record provenance/credits, add its event to the library Resource, and add its AudioStream to the Resource's `assets` array so selected-scene exports include it. Trigger the stable ID from an actual result or authoritative signal. Add a surface event with multiple samples and use `FootstepEmitter3D.set_surface(event_id)` for later floor types.

## B. Asset research

Selected sources: Kenney Impact Sounds, Interface Sounds and Sci-fi Sounds; SpliceSound tile contacts; Kinoton ventilation; BenjaminNelan paper; thegoose09 recorded radio static; SketchMan3 wind; and two ambient tracks by yd. All ten publication pages identify CC0. Bundled Kenney license files are preserved in `assets/audio/licenses/`.

[AUDIO_ASSET_CREDITS.md](AUDIO_ASSET_CREDITS.md) lists every selected file, creator, original acquired filename, exact download/page, license, date and use. [AUDIO_RESEARCH_REPORT.md](AUDIO_RESEARCH_REPORT.md) explains alternatives, suitability and limitations. Freesound public HQ MP3 previews were acquired where original WAVs require login; these are explicitly identified as previews.

`tools/acquire_audio_sources.py` restores the ignored source cache using pinned URLs and SHA256 checks. `tools/prepare_audio_assets.py` edits actual source material using numpy and ffmpeg: contact/static trimming, filtering, DC removal, anti-click fades, peak normalization to ?6 dBFS and tail-to-head loop overlap. Effects are mono PCM WAV; music and room beds are stereo Vorbis OGG; the positional rift loop is mono. This is not a claim of equal perceived loudness or a completed listening/mastering pass.

## C. Old versus new

The existing director, ambience controller and footstep emitter were refactored, not replaced by parallel systems. `tools/generate_audio_assets.py` and `radio_audio.gd._make_static()` were removed. All old WAVs and `.import` companions were inventoried and checked for active references before removal; Git history can restore them.

| Removed placeholder family | Replacement |
|---|---|
| `footsteps/footstep_01.wav` through `footstep_05.wav` | Six recorded Past tile contacts and five separate Future concrete contacts |
| `ambience/lab_ambience_past.wav` | Recorded stereo ventilation, edited to a 53-second OGG loop |
| `ambience/lab_ambience_future.wav` | Filtered air leakage / wind loop |
| `environment/rift_hum.wav` | Acquired force-field texture, filtered and positional |
| `environment/computer_beep.wav` | Terminal activation, tune, calibration, invalid and lock family |
| `environment/door_open.wav`, `door_locked.wav`, `switch_toggle.wav` | Acquired mechanical/door/interface family |
| `ui/ui_click.wav`, `ui_hover.wav`, `ui_confirm.wav`, `ui_back.wav` | Consistent Kenney Interface sounds |
| `interaction/interaction_click.wav`, `interaction_success.wav`, `interaction_denied.wav` | Compatibility IDs mapped to acquired sounds |
| Synthesized radio noise | Brief selection of a real AM recording; no synthesis fallback |

All removed paths above were beneath `assets/audio/`. A previously unresolved cross-PackedScene NodePath left the playable RadioAudio without its director. `SignalLab.attach_radio()` now binds it explicitly after composition. The console's duplicate link-success cue was removed. The local radio and rift stabilization listen to PuzzleManager's completion signal, which snapshots do not replay.

## D. Sound library

[AUDIO_EVENT_MANIFEST.md](AUDIO_EVENT_MANIFEST.md) lists all **71** public IDs, exact files, triggering components, buses and integration status. It distinguishes integrated effects, API-only power toggles, compatibility aliases and prepared later-stage sounds. An available event does not imply a new gameplay mechanic exists.

## E. Past soundscape

Six clean sneaker-on-tile contacts; quiet stereo ventilation; rare low computer texture; yd's **ObservingTheStar** at ?28 dB catalog gain. The first equipment detail waits 22?38 seconds and later details wait 28?48 seconds. The menu deliberately has no music.

## F. Future soundscape

Five separate worn-concrete contacts; exposed air leakage; rare quiet metallic ticks; yd's **GalacticTemple** at ?29 dB gain. The Future is distinguished by sources and texture, not higher volume. It uses the same sparse detail scheduling.

Ambience fades over two seconds and music over 2.5 seconds. Restarting the same playing ID is suppressed. Normal Return to Menu fades beds over 0.18 seconds before scene teardown. Immediate cleanup remains available. Each ENet peer selects its local room timeline; music/mixing has no RPC protocol.

## G. Gameplay integration and controls

Actual hooks cover walking/running, button clicks/focus, pause/resume, computer open/close, tuning, attempt, invalid frequency, confirmed calibration, connected-state inspection, confirmed radio pickup, local/remote written transmissions, one pending-link scan, explicit interference, confirmed connection, partner disconnect, documents/log open/close, positional rift hum/inspection/stabilization, actual door open/reset closure/locked inspection, keypad contacts, existing breaker inspection, auxiliary receiver completion and laboratory exit.

The Lost Frequency remains **67 MHz**. Audio never grants puzzle success, changes puzzle state, adds microphone input, synthesizes speech or introduces VoIP. Door sounds follow the pre-existing door behavior; no new calibration-to-door rule was introduced.

Footsteps accumulate actual horizontal displacement after movement, require grounded state, and reset for controls locks, stopping and teleports. Nominal velocity alone cannot produce steps against a wall. Running changes physical cadence rather than speeding up samples. A local AudioListener3D at character height makes world attenuation independent of the high-angle camera.

`default_bus_layout.tres` supplies Master ? Music / Ambience / SFX / UI before room children start. The existing Settings page gains five sliders and mute controls. Stable APIs: `set_category_volume_linear`, `get_category_volume_linear`, `set_category_muted`, `is_category_muted`. Preferences merge into `user://menu_settings.cfg`, preserving display settings. Volume zero retains the previous mute-at-zero API behavior. A ?1 dB Master limiter supplies a final ceiling; conservative event gains provide normal headroom beneath it.

## H. Files created and modified

Exact source/config/document paths are listed below. All 43 asset paths are separately listed in the credits, with Godot `.import` companions. Removed files are listed in the replacement table and Git diff. Review images are `docs/assets/audio/past_lab.png`, `docs/assets/audio/future_lab.png` and `docs/assets/audio/audio_settings.png`.

- `docs/AUDIO_ASSET_CREDITS.md`
- `scenes/gameplay/laboratory_gameplay.tscn`
- `scenes/menu/main_menu.tscn`
- `scripts/audio/ambient_audio_controller.gd`
- `scripts/audio/audio_director.gd`
- `scripts/audio/footstep_emitter_3d.gd`
- `scripts/environment/interactive/console_terminal.gd`
- `scripts/environment/interactive/door_keypad.gd`
- `scripts/environment/interactive/lab_document.gd`
- `scripts/environment/interactive/security_door.gd`
- `scripts/environment/signal_lab.gd`
- `scripts/environment/temporal_rift.gd`
- `scripts/gameplay/frequency/frequency_log_reader.gd`
- `scripts/gameplay/frequency/frequency_terminal.gd`
- `scripts/gameplay/laboratory_gameplay.gd`
- `scripts/gameplay/radio/radio_audio.gd`
- `scripts/gameplay/radio/radio_dialogue_box.gd`
- `scripts/gameplay/radio/temporal_radio.gd`
- `scripts/menu/main_menu.gd`
- `scripts/world/spawn_area.gd`
- `tests/audio_system.gd`
- `tests/gameplay_integration.gd`
- `tests/gameplay_peer.gd`
- `default_bus_layout.tres`
- `docs/AUDIO_EVENT_MANIFEST.md`
- `docs/AUDIO_RESEARCH_REPORT.md`
- `resources/audio/sound_events.tres`
- `scripts/audio/sound_catalog.gd`
- `scripts/audio/sound_event_library.gd`
- `tools/acquire_audio_sources.py`
- `tools/prepare_audio_assets.py`

- `docs/AUDIO_TEST_RESULTS.md`

## I. Verification

[AUDIO_TEST_RESULTS.md](AUDIO_TEST_RESULTS.md) records commands, results and limitations. Audio import, catalog/routing/cadence checks, rendered real-menu gameplay, and actual ENet host/client checks passed. No unexpected runtime errors or shutdown leaks remain in final checks. This implementation is used by the real first level, not only a sandbox.

## J. Outstanding work

Final listening and mix approval remain because audio output could not be monitored. Remote footsteps await replicated remote-character movement; each current peer has only one local character. Cabinet sounds are prepared without inventing cabinet gameplay. No player jump/landing mechanic exists to hook. Radio power cues attach to the existing presentation API, which currently has no player-facing toggle. These distinctions are explicit in the manifest.

## K. Manual listening

Launch the normal game, choose Play ? Solo Test, review the Past, acquire its handheld, enter 66 then 67 on the computer, close it and press T to review the Future and acquire the other handheld. Read documents, approach/leave the rift, review written radio dialogue, pause, return to menu, and test volume persistence. The short checklist and LAN route are in [AUDIO_TEST_RESULTS.md](AUDIO_TEST_RESULTS.md). Listening quality has not been claimed as verified.
