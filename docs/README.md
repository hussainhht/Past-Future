# Documentation

Index of the project documentation for **The Other Me** (repository name: `Past-Future`).
The game's source is the final authority; documents marked *snapshot* or *historical* describe
the project as it was on 2026-10-21.

> Many documents contain puzzle solutions and story spoilers. The public [README](../README.md) does not.

## Design — `design/`

| Document | Contents |
| --- | --- |
| [GAME_DESIGN_DOCUMENT.md](design/GAME_DESIGN_DOCUMENT.md) | The single Game Design Document: premise, characters, puzzles, endings, multiplayer architecture |
| [PROJECT_OVERVIEW.md](design/PROJECT_OVERVIEW.md) | Concept, theme and technology overview *(snapshot)* |
| [PLAYER_EXPERIENCE.md](design/PLAYER_EXPERIENCE.md) | Discovery and physical interaction design |
| [FREQUENCY_PUZZLE.md](design/FREQUENCY_PUZZLE.md) | Puzzle 01 — The Lost Frequency / Temporal Radio |
| [STORY_AND_LEVEL_02.md](design/STORY_AND_LEVEL_02.md) | Chapter 0 story continuation and Level 02 design |
| [LEVEL_02.md](design/LEVEL_02.md) | Level 02 — The Broken Corridor |
| [LEVEL3_FINAL_FRACTURE.md](design/LEVEL3_FINAL_FRACTURE.md) | Level 3 — The Final Fracture |

## Guides — `guides/`

| Document | Contents |
| --- | --- |
| [MACOS_INSTALLATION.md](guides/MACOS_INSTALLATION.md) | Installing the unsigned macOS test build |

Running from source, controls, and LAN setup are covered in the root [README](../README.md);
developer commands are in [SETUP_AND_TESTING.md](development/SETUP_AND_TESTING.md).

## Technical — `technical/`

| Document | Contents |
| --- | --- |
| [ARCHITECTURE.md](technical/ARCHITECTURE.md) | Code structure, autoloads, scene flow, RPCs *(snapshot)* |
| [GAMEPLAY_SYSTEMS.md](technical/GAMEPLAY_SYSTEMS.md) | Locomotion, interaction, camera, ghost, controllers *(snapshot)* |
| [CHARACTERS_AND_ANIMATIONS.md](technical/CHARACTERS_AND_ANIMATIONS.md) | Student and Professor models, animation retargeting *(snapshot)* |
| [SCENES_AND_LEVELS.md](technical/SCENES_AND_LEVELS.md) | Scene inventory and level layouts *(snapshot)* |
| [ASSETS_AND_VISUALS.md](technical/ASSETS_AND_VISUALS.md) | Materials, shaders, palettes *(snapshot)* |
| [GAME_FLOW_SYSTEM.md](technical/GAME_FLOW_SYSTEM.md) | Level transitions and game flow |
| [PUZZLE_SYSTEM.md](technical/PUZZLE_SYSTEM.md) | Host-authoritative puzzle framework |
| [INTERACTION_SYSTEM.md](technical/INTERACTION_SYSTEM.md) | Modular 3D interaction system |
| [DIALOGUE_SYSTEM.md](technical/DIALOGUE_SYSTEM.md) | Dialogue system |
| [JOURNAL_SYSTEM.md](technical/JOURNAL_SYSTEM.md) | Role-specific investigation journal |
| [OBJECTIVE_SYSTEM.md](technical/OBJECTIVE_SYSTEM.md) | Objective tracker and Mission Log |
| [CINEMATIC_ROOM_TRANSITIONS.md](technical/CINEMATIC_ROOM_TRANSITIONS.md) | Room introduction cards |
| [CONTROLLER_SUPPORT.md](technical/CONTROLLER_SUPPORT.md) | Gamepad support |
| [TEMPORAL_GHOST.md](technical/TEMPORAL_GHOST.md) | Solo temporal ghost prototype |
| [TUTORIAL_POPUP.md](technical/TUTORIAL_POPUP.md) | First-time tutorial popup |
| [TYPOGRAPHY_SYSTEM.md](technical/TYPOGRAPHY_SYSTEM.md) | Fonts and text styling |
| [PERFORMANCE.md](technical/PERFORMANCE.md) | Gameplay performance notes |
| [GAMEPLAY_INTEGRATION.md](technical/GAMEPLAY_INTEGRATION.md) | Main menu and Signal Laboratory integration |
| [REACTOR_MELTDOWN.md](technical/REACTOR_MELTDOWN.md) | Level 3 timeout catastrophe |
| [LEVEL3_ENVIRONMENT_ART.md](technical/LEVEL3_ENVIRONMENT_ART.md) | Level 3 environment layer |
| [AUDIO_SYSTEM.md](technical/AUDIO_SYSTEM.md) | Audio implementation |
| [AUDIO_EVENT_MANIFEST.md](technical/AUDIO_EVENT_MANIFEST.md) | Audio event list |
| [LEVEL2_LEVEL3_AUDIO.md](technical/LEVEL2_LEVEL3_AUDIO.md) | Level 2 and 3 audio sources |
| [AUDIO_ASSET_CREDITS.md](technical/AUDIO_ASSET_CREDITS.md) | Per-file audio provenance and licenses |

## Development — `development/`

| Document | Contents |
| --- | --- |
| [SETUP_AND_TESTING.md](development/SETUP_AND_TESTING.md) | Environment, launch commands, test runners *(snapshot)* |
| [DEVELOPMENT_PROGRESS.md](development/DEVELOPMENT_PROGRESS.md) | Feature status matrix *(snapshot)* |
| [KNOWN_ISSUES_AND_TECHNICAL_DEBT.md](development/KNOWN_ISSUES_AND_TECHNICAL_DEBT.md) | Bugs and technical debt *(snapshot)* |
| [ROADMAP.md](development/ROADMAP.md) | Prioritized backlog *(snapshot)* |
| [reports/](development/reports/) | Dated verification and implementation reports (audio, frequency puzzle, gameplay integration, Level 3, Room 02 placeholder) |

## Asset reports — `assets/`

[ASSET_INVENTORY.md](assets/ASSET_INVENTORY.md), [FINAL_ENVIRONMENT_REPORT.md](assets/FINAL_ENVIRONMENT_REPORT.md)
and [PHASE_1_ASSET_REPORT.md](assets/PHASE_1_ASSET_REPORT.md) cover the Signal Laboratory environment library.
`assets/screenshots/` holds gameplay captures used by the documents and the README
(some are rewritten by the `tests/` and `tools/` render scripts).

## Internal / historical — `internal/`

| Item | Contents |
| --- | --- |
| [project_context/](internal/project_context/) | Remaining files of the former `PROJECT_CONTEXT/` set: onboarding index, GDD analysis, git chronology, AI handover |
| [AUDIO_RESEARCH_REPORT.md](internal/AUDIO_RESEARCH_REPORT.md) | Audio source research and selection |
| [Past_Future_Final_Fracture_Codex_Agent_Prompt.md](internal/Past_Future_Final_Fracture_Codex_Agent_Prompt.md) | Agent prompt used to build Level 3 |
| [gameplay_recording/](internal/gameplay_recording/) | Archived automated playthrough: logs, raw capture, screenshots, final video, report |
| [validation/](internal/validation/) | Raw logs from the reactor validation runs |

The scripts that produced the recording live in [`tools/recording/`](../tools/recording/).
