# Audio event manifest

The native catalog is [`resources/audio/sound_events.tres`](../../resources/audio/sound_events.tres). Its `assets` array makes all streams explicit export dependencies. A reused file is intentional family consistency, not a second audio manager.

| Gameplay event | Sound ID | Audio file(s) | Triggering component | Bus | Status |
|---|---|---|---|---|---|
| Grounded walking/running in Past | `footstep_past_tile` | `assets/audio/footsteps/past_tile/step_01.wav`, `assets/audio/footsteps/past_tile/step_02.wav`, `assets/audio/footsteps/past_tile/step_03.wav`, `assets/audio/footsteps/past_tile/step_04.wav`, `assets/audio/footsteps/past_tile/step_05.wav`, `assets/audio/footsteps/past_tile/step_06.wav` | FootstepEmitter3D.set_timeline | SFX | Integrated |
| Grounded walking/running in Future | `footstep_future_concrete` | `assets/audio/footsteps/future_concrete/step_01.wav`, `assets/audio/footsteps/future_concrete/step_02.wav`, `assets/audio/footsteps/future_concrete/step_03.wav`, `assets/audio/footsteps/future_concrete/step_04.wav`, `assets/audio/footsteps/future_concrete/step_05.wav` | FootstepEmitter3D.set_timeline | SFX | Integrated |
| Menu, HUD and general button presses | `ui_click` | `assets/audio/ui/click.wav` | AudioDirector.bind_ui | UI | Integrated |
| Prepared reusable alias / later-stage event | `computer_button` | `assets/audio/ui/click.wav` | No production trigger assigned | UI | Prepared / compatibility |
| Animated keypad key contact | `keypad_button` | `assets/audio/ui/click.wav` | door_keypad.gd._press_sequence | UI | Integrated |
| Mouse hover / keyboard focus | `ui_hover` | `assets/audio/ui/hover.wav` | AudioDirector.bind_ui; shared cooldown | UI | Integrated |
| Prepared reusable alias / later-stage event | `ui_focus` | `assets/audio/ui/hover.wav` | No production trigger assigned | UI | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `ui_confirm` | `assets/audio/ui/confirm.wav` | No production trigger assigned | UI | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `ui_notification` | `assets/audio/ui/confirm.wav` | No production trigger assigned | UI | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `ui_cancel` | `assets/audio/ui/back.wav` | No production trigger assigned | UI | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `ui_back` | `assets/audio/ui/back.wav` | No production trigger assigned | UI | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `ui_error` | `assets/audio/ui/error.wav` | No production trigger assigned | UI | Prepared / compatibility |
| Open menu page | `menu_open` | `assets/audio/ui/open.wav` | main_menu.gd._open_page | UI | Integrated |
| Pause opens | `ui_pause` | `assets/audio/ui/open.wav` | spawn_area.gd._set_paused | UI | Integrated |
| Close menu page | `menu_close` | `assets/audio/ui/close.wav` | main_menu.gd._close_page | UI | Integrated |
| Pause closes | `ui_unpause` | `assets/audio/ui/close.wav` | spawn_area.gd._set_paused | UI | Integrated |
| Written dialogue line finishes / advances | `dialogue_advance` | `assets/audio/ui/click.wav` | laboratory_gameplay.gd; DialogueDirector.dialogue_line_finished | UI | Integrated |
| Calibration modal successfully opens | `computer_open` | `assets/audio/ui/open.wav` | SignalLab; terminal.modal_changed | SFX | Integrated |
| Calibration modal closes | `computer_close` | `assets/audio/ui/close.wav` | SignalLab; terminal.modal_changed | SFX | Integrated |
| Frequency text adjusted; throttled | `computer_tune` | `assets/audio/computer/tune.wav` | frequency_terminal.gd._validate_text -> RadioAudio | SFX | Integrated |
| Valid calibration request submitted | `computer_calibrate` | `assets/audio/computer/calibrate.wav` | frequency_terminal.gd.submit_frequency -> RadioAudio | SFX | Integrated |
| Prepared reusable alias / later-stage event | `puzzle_submit` | `assets/audio/computer/calibrate.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Invalid input / incorrect frequency; receiver prerequisite refused | `computer_invalid` | `assets/audio/computer/invalid.wav` | frequency_terminal.gd; laboratory_gameplay.gd -> RadioAudio | SFX | Integrated |
| Prepared reusable alias / later-stage event | `puzzle_failure` | `assets/audio/computer/invalid.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Fused breaker / denied keypad inspection | `interaction_denied` | `assets/audio/computer/invalid.wav` | junction_box.gd; door_keypad.gd | SFX | Integrated |
| Inspect sealed security door | `door_locked` | `assets/audio/computer/invalid.wav` | security_door.gd._on_interacted | SFX | Integrated |
| Confirmed calibration pending partner radio | `computer_success` | `assets/audio/computer/lock.wav` | console_terminal.gd._state_changed | SFX | Integrated |
| Inspect powered console / unlocked door / released keypad | `computer_beep` | `assets/audio/computer/lock.wav` | Existing LabDevice inspection handlers; compatibility ID | SFX | Integrated |
| Reopen an already connected computer; short state indication | `computer_connected` | `assets/audio/computer/lock.wav` | SignalLab._on_terminal_modal | SFX | Integrated |
| Confirmed acquisition of local physical handheld | `radio_pickup` | `assets/audio/radio/pickup.wav` | SignalLab._on_radio_acquired -> RadioAudio | SFX | Integrated |
| Radio presentation explicitly enabled | `radio_activate` | `assets/audio/radio/activate.wav` | TemporalRadio.set_presentation_active(true); API hook, no current player toggle | SFX | API hook only |
| Radio presentation explicitly disabled | `radio_deactivate` | `assets/audio/radio/deactivate.wav` | TemporalRadio.set_presentation_active(false); API hook, no current player toggle | SFX | API hook only |
| Remote scripted text transmission starts; 2.5 s cooldown | `radio_incoming` | `assets/audio/radio/incoming.wav` | RadioDialogueBox -> TemporalRadio.set_transmitting -> RadioAudio | SFX | Integrated |
| Prepared reusable alias / later-stage event | `radio_dialogue_incoming` | `assets/audio/radio/incoming.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Local scripted text transmission starts | `radio_outgoing` | `assets/audio/radio/outgoing.wav` | RadioDialogueBox; DialogueLine.timeline -> TemporalRadio -> RadioAudio | SFX | Integrated |
| Authoritative Lost Frequency completion, once | `radio_connect` | `assets/audio/radio/connect.wav` | PuzzleManager.puzzle_completed -> TemporalRadio._on_completed -> RadioAudio | SFX | Integrated |
| Prepared reusable alias / later-stage event | `puzzle_success` | `assets/audio/radio/connect.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `interaction_success` | `assets/audio/radio/connect.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Player actually exits existing laboratory doorway | `objective_completed` | `assets/audio/radio/connect.wav` | SignalLab._on_player_exited | SFX | Integrated |
| Partner disconnect during gameplay | `radio_disconnect` | `assets/audio/radio/disconnect.wav` | spawn_area.gd._on_network_changed | SFX | Integrated |
| Explicit temporary signal interference | `radio_static` | `assets/audio/radio/static.wav` | TemporalRadio.interfere -> RadioAudio | SFX | Integrated |
| Prepared reusable alias / later-stage event | `radio_interference` | `assets/audio/radio/static.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| One short scan after newly acquired radio waits for a link | `radio_search` | `assets/audio/radio/static.wav` | RadioAudio Timer; cancelled on connection, suspended during overlays | SFX | Integrated |
| Continuous nearby rift energy; positional loop | `rift_hum` | `assets/audio/rift/energy_loop.ogg` | temporal_rift.gd -> catalog; owned Hum player | Ambience | Integrated |
| Inspect temporal rift | `rift_activate` | `assets/audio/rift/stabilize.wav` | temporal_rift.gd._on_interacted | SFX | Integrated |
| Confirmed temporal link stabilizes rift | `rift_stabilize` | `assets/audio/rift/stabilize.wav` | PuzzleManager.puzzle_completed -> temporal_rift.gd._on_audio_completed | SFX | Integrated |
| Existing door leaf begins actual opening movement | `door_open` | `assets/audio/doors/open.wav` | security_door.gd.open(animate=true) | SFX | Integrated |
| Existing door reset actually closes an open leaf | `door_close` | `assets/audio/doors/close.wav` | security_door.gd.close | SFX | Integrated |
| Inspect existing functional breaker | `switch_toggle` | `assets/audio/interactions/switch.wav` | Existing junction_box.gd inspection feedback; no puzzle mutation | SFX | Integrated |
| Prepared reusable alias / later-stage event | `switch_mechanical` | `assets/audio/interactions/switch.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `switch_electrical` | `assets/audio/interactions/switch.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `interaction_click` | `assets/audio/interactions/switch.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `puzzle_interact` | `assets/audio/interactions/switch.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Research log or document successfully opens | `document_open` | `assets/audio/documents/paper.wav` | SignalLab; FrequencyLogReader/LabUI.modal_changed | SFX | Integrated |
| Research log or document closes | `document_close` | `assets/audio/documents/paper.wav` | SignalLab; FrequencyLogReader/LabUI.modal_changed | SFX | Integrated |
| Prepared reusable alias / later-stage event | `equipment_activate` | `assets/audio/computer/equipment.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `equipment_deactivate` | `assets/audio/computer/equipment.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Rare local equipment texture, 28?48 s interval | `past_equipment` | `assets/audio/computer/equipment.wav` | AudioDirector._process (Past) | SFX | Integrated |
| Rare quiet metal detail, 28?48 s interval | `future_creak` | `assets/audio/ambience/future/metal_detail.wav` | AudioDirector._process (Future); a metal tick, not a horror stinger | SFX | Integrated |
| Prepared reusable alias / later-stage event | `puzzle_progress` | `assets/audio/puzzles/progress.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Confirmed auxiliary receiver relay completion | `mechanism_activated` | `assets/audio/puzzles/progress.wav` | PuzzleManager.puzzle_completed -> laboratory_gameplay.gd | SFX | Integrated |
| Prepared reusable alias / later-stage event | `system_unlocked` | `assets/audio/puzzles/progress.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `objective_progression` | `assets/audio/puzzles/progress.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `cabinet_open` | `assets/audio/doors/open.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Prepared reusable alias / later-stage event | `cabinet_close` | `assets/audio/doors/close.wav` | No production trigger assigned | SFX | Prepared / compatibility |
| Local Past room ventilation bed | `lab_ambience_past` | `assets/audio/ambience/past/ventilation.ogg` | SignalLab._apply -> AudioDirector.start_soundscape | Ambience | Integrated |
| Prepared reusable alias / later-stage event | `ambience_past` | `assets/audio/ambience/past/ventilation.ogg` | No production trigger assigned | Ambience | Prepared / compatibility |
| Local Future air leakage bed | `lab_ambience_future` | `assets/audio/ambience/future/air_leak.ogg` | SignalLab._apply -> AudioDirector.start_soundscape | Ambience | Integrated |
| Prepared reusable alias / later-stage event | `ambience_future` | `assets/audio/ambience/future/air_leak.ogg` | No production trigger assigned | Ambience | Prepared / compatibility |
| Local Past restrained ambient track | `music_past` | `assets/audio/music/past/observing_the_star.ogg` | AudioDirector.start_music -> MusicController | Music | Integrated |
| Local Future restrained ambient track | `music_future` | `assets/audio/music/future/galactic_temple.ogg` | AudioDirector.start_music -> MusicController | Music | Integrated |

There is no cabinet animation or player jump/landing mechanic to hook in Level 1. Cabinet events are prepared; landing is deliberately omitted until such a mechanic exists. The existing breaker is an inspection object, not a newly implemented switch. Door audio follows the pre-existing actual door behavior; this overhaul adds no door-unlock puzzle rule. Remote footsteps are omitted because each ENet peer currently instantiates one local character and has no replicated remote character motion.
