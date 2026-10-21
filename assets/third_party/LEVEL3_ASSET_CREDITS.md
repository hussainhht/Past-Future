# Room C / The Final Fracture: asset provenance

No new third-party downloads were needed. The existing library supplies the room's consoles,
desks, machinery, cables, papers, plants, damaged panels and debris. Nothing requires a network
connection at runtime. No source GLB, animation, material, texture or Blender file was modified.

| Content | Source / author | License / record | Runtime use |
| --- | --- | --- | --- |
| Student and Professor | Past-Future project originals, existing `student.glb` and `professor.glb` | Existing manifests and character READMEs under `assets/characters/` | Existing player scenes; the controller duplicates animation libraries and tint materials per instance |
| Character animations | Kay Lousberg / [KayKit Character Animations](https://kaylousberg.itch.io/kaykit-character-animations) | CC0; unchanged `assets/third_party/kaykit_character_animations/License.txt` | Existing imported clips through existing character scenes |
| Small reading tables, low cabinet | Kay Lousberg / KayKit Furniture Bits | CC0; unchanged `assets/third_party/kaykit_furniture_bits/LICENSE.txt`; existing source manifest and `assets/environment/licenses/THIRD_PARTY_ATTRIBUTION.md` | Existing `scenes/environment/props/reading_table.tscn`, `cabinet_low.tscn` |
| Console, papers, plant, cable reel, signal rack, debris, damaged panel, broken pipe | Past-Future generated environment library | Project originals; `docs/assets/ASSET_INVENTORY.md` and `assets/environment/licenses/sources.json` | Scene instances; existing TimelineProp palette swapping, no upstream resource edits |
| Reactor, rings, coils, tiles, rails, cracked conduits, rift shards | Original procedural geometry authored for Room C | Project source: `scripts/level3/core_world.gd` | Godot primitives and per-instance new materials |
| Hum, electrical rattle, phase cue, warning, overload, ending stings and unknown signal | Original PCM synthesis authored for Room C | Project source: `scripts/level3/core_sound.gd` | Audible 16-bit PCM generated in memory; routed through existing Ambience/SFX/Master buses |

The existing palette helper uses cached immutable materials for scene instances. Room C's animated
materials are newly created per room instance. Future displacement uses instance transforms. No
existing asset required alteration, so there are no replacement asset copies or new license claims.
