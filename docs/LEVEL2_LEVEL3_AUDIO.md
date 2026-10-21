# Level 2 and Level 3 audio overhaul

All assets are CC0 and built only from downloaded recordings by `tools/prepare_level_audio.py` (layering, filtering, reversing, variable-rate glides, bar-aligned slicing). Per-file sources, hashes and processing are in `assets/audio/asset_provenance.json` (records with `"collection": "level2_level3_audio"`). Events live in `resources/audio/level_sound_events.tres` (regenerate with `tools/build_level_sound_events.py`) and are merged into `SoundCatalog.definitions()`.

## Sources
| Pack | Creator | License | Used for |
|---|---|---|---|
| [Dark Sci-Fi Audio Pack](https://opengameart.org/content/dark-sci-fi-audio-pack) (Pulse, Urgent, Airy, Sector, Transmission, Victory) | SRG774 | CC0 | countdown stems, ending beds |
| [Steam boiler sound loop](https://opengameart.org/content/steam-boiler-sound-loop) | bart | CC0 | Level 2 machinery bed, reactor drone |
| [Kenney Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds), [Impact Sounds](https://kenney.nl/assets/impact-sounds), [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 | device effects, percussion, risers, overload |
| Ventilation (Kinoton), wind loop (SketchMan3) | existing | CC0 | beds (already credited) |

Pulse, Urgent, Sector and Airy are exact whole numbers of bars at 135 BPM (40/32/32/36), so 16-bar slices of each share one grid.

## Countdown score (`ReactorMusic`, `ReactorMusicProfile`)
Five stems (bed, pad, drive, lead, climax) play in one `AudioStreamSynchronized`; only per-stem gain changes. The profile maps the authoritative remaining time (ceil, as shown on the HUD) to tiers 150-111, 110-76, 75-41, 40-21, 20-11, 10-0. Percussion is scheduled in elapsed time on nested grid divisions (quarter, eighth, sixteenth), then accelerates continuously through the last ten seconds, with a 10 s riser and per-second markers. Tempo is never pitch-shifted. `CoreSound.tick` feeds it the room's predicted host time, so retries, late joins and snapshot jumps re-seek (`>0.4 s` drift) instead of restarting; solo pause freezes it; LAN keeps running like the clock.

## Event map
Press feedback (`on_device_action`) uses mechanisms (`core_relay_clunk`, `core_battery_latch`, `core_anchor_calibrate`); confirmed snapshots (`on_state`) play the result: coil surge/align, battery connect, anchor lock, origin stabilize, power restore, phase engage (local positional, partner `_remote`), five-second `core_sync_tick` pulses, `core_sync_success`/`core_sync_fail`, `core_command_lock`, arm confirm, rejections, four ending cues, and the three meltdown cues (`impact`, `rupture`, `shockwave`) via `explosion_audio_cues`. Light reinforcement: beat-locked reactor pulse light, event flashes, green glow over aligned coils (honors the effects toggle and reduced motion).

Level 2 (`scripts/world/maintenance_sound.gd`): industrial bed per timeline, positional boiler and buzz loops, rare clanks/steam, and cues for isolator, crank/latch/surge, reserve lever, bypass, archive, recorder, keypad, release wheel, gates, anchors, power loss and the storage hatch/lift tween.

Tests: `tests/reactor_audio.gd` (80 checks), plus `tests/audio_system.gd` and `tests/run_level3_tests.py`. Audio output itself could not be listened to in this environment; levels were set by measured loudness and should get a listening pass.
