# Audio research and selection — 20 October 2026

43 prepared audio files from ten published asset pages replace the generated library. All selected material is CC0 1.0. The per-file source, acquired filename, exact download, source/output hashes, processing and event usage are in [the credits](../technical/AUDIO_ASSET_CREDITS.md) and [provenance manifest](../../assets/audio/asset_provenance.json). Licenses were checked on the primary pages and, for Kenney, against each downloaded `License.txt`.

## Selected sources

| Source / creator | Selection and intended fit | Rights verified |
|---|---|---|
| [Footsteps, Tile, Male Sneakers, Slow Pace.wav](https://freesound.org/people/SpliceSound/sounds/170506/) — SpliceSound | Six separate contacts cut from an actual sneaker-on-tile recording. Clean transients and short tails suit the functioning Past laboratory. Running changes cadence, not playback speed. | Page explicitly identifies CC0. Public HQ MP3 preview acquired; original WAV requires login. |
| [Impact Sounds](https://kenney.nl/assets/impact-sounds) — Kenney | Five distinct concrete contacts for the worn Future floor; a light generic contact for picking up the handheld. The Future steps are a separate source set, not pitch-shifted Past steps. | Page and bundled license identify CC0; commercial use explicitly allowed. |
| [Interface Sounds](https://kenney.nl/assets/interface-sounds) — Kenney | One consistent family of tactile clicks, restrained confirmations, tuning, transmit cues and a glass resonance for the rift. No unrelated retro packs mixed into the UI. | Page and bundled CC0 license agree. |
| [Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) — Kenney | Electronic doors, quiet computer texture, a rare metallic detail and a filtered force-field recording for the positional rift bed. Explosions, weapons and heavy engines were not selected. | Page and bundled CC0 license agree. |
| [Room Tone, Deep Ventilation](https://freesound.org/people/Kinoton/sounds/503255/) — Kinoton | A real stereo ventilation recording gives the Past a functional indoor bed. A 55-second selection is filtered and overlapped into a 53-second loop. | Page identifies CC0 and explicitly permits commercial modification/distribution. Public HQ MP3 preview acquired. |
| [wind whoosh loop](https://opengameart.org/content/wind-whoosh-loop) — SketchMan3 | A filtered, quiet air-leak texture makes the Future feel exposed and empty. The author describes a wind extraction from Loopable Dungeon Ambience. | Published sound page identifies CC0. Original published OGG acquired. |
| [Paper Rustle](https://freesound.org/people/BenjaminNelan/sounds/353125/) — BenjaminNelan | Real paper handling for opening and closing research documents; considerably quieter than the terminal controls. | Page identifies CC0. Public HQ MP3 preview acquired. |
| [Radio Static.wav](https://freesound.org/people/thegoose09/sounds/125392/) — thegoose09 | A 0.38-second selection of recorded AM tuning static, band-limited and faded. Used only for explicit interference and one pending-link scan; no continuous noise. | Page identifies CC0. Public HQ MP3 preview acquired. |
| [Another space background track](https://opengameart.org/content/another-space-background-track) and [Galactic Temple](https://opengameart.org/content/galactic-temple) — yd | Two distinct instrumental ambient tracks from the same composer. Past uses ObservingTheStar; Future uses GalacticTemple at a slightly lower gain. They sit below the environmental bed. The original OGG tracks, not synthesized replacements, were acquired from the published ZIPs. | Both pages identify CC0. No attribution requirement; voluntary credits retained. |

There are **ten** individual selected publication pages in the table: the final row contains two music pages. Kenney packs contain many candidate files; only the chosen files are imported into `assets/audio/`.

## Alternatives and exclusions

- [Floating in Space](https://opengameart.org/content/floating-in-space) by Umplix was a CC0 candidate for the Future. Its original WAV download timed out; it is not shipped. Galactic Temple was successfully acquired instead.
- [Searching](https://opengameart.org/content/searching) by yd was considered from its published drone/industrial description, but the selected pair better supports a restrained shared musical family. It was not downloaded.
- [Pixabay's license summary](https://pixabay.com/service/license-summary/) and [terms](https://pixabay.com/service/terms/) were checked. Its separate content license was not treated as CC0. Clear primary CC0 alternatives were available, so no Pixabay assets are included.
- [Sonniss GDC bundles](https://gdc.sonniss.com/) and the [bundle-specific license](https://sonniss.com/gdc-bundle-license/) were reviewed. The bundle license is distinct from CC0 and the multi-part archives are unnecessarily large for this focused library. No Sonniss files are included or relabeled.
- itch.io was searched, including [SubspaceAudio](https://subspaceaudio.itch.io/) and [Retro Starter SFX Pack](https://dungeon-bits.itch.io/retro-starter-sfx). The retro emphasis was unsuitable for the natural laboratory direction; no files were acquired and no unverified pack license is relied on.
- The presumed Kenney `/assets/foley-sounds` URL returned 404. No download or license was invented for that address; paper and radio foley came from the verified pages above.
- A derivative tile pack whose author reported unsourceable mixed samples was excluded. The original SpliceSound recording was used directly.

## Preparation and limits

`tools/acquire_audio_sources.py` reacquires the recorded sources and checks their SHA256 values. `tools/prepare_audio_assets.py` trims real material, removes DC offset, filters where appropriate, adds short anti-click fades, and normalizes individual asset peaks to −6 dBFS. Effects are mono 48 kHz PCM WAV; room beds and music are stereo 48 kHz Vorbis OGG. The rift loop is mono for positional playback.

Loops use a tail-to-head overlap of up to two seconds, then native stream looping. This avoids an unprocessed discontinuity; it does not substitute for a human listening check. Peak normalization is not a claim of equal perceived loudness or measured LUFS mastering. The catalog adds substantial gain reduction and a Master limiter preserves a final safety ceiling.

Selection is based on verified provenance, source descriptions, waveform/transient inspection and restrained integration. Audio output could not be monitored during this session. Final musical suitability, seam audibility, radio character and in-context balance require the listening review in [AUDIO_TEST_RESULTS.md](../development/reports/AUDIO_TEST_RESULTS.md). No claim of a professionally auditioned final mix is made.
