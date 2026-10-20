# Environment asset library

Free 3D assets for the Signal Laboratory and later rooms. Every file here is either third-party
(with a license record) or made for this project. Status and plan: `docs/assets/ASSET_INVENTORY.md`
and `docs/assets/PHASE_1_ASSET_REPORT.md`.

## Layout

```text
assets/environment/
  licenses/
    sources.json                  <- one record per pack or model: creator, URLs, license, checksums, derived models
    LICENSES.md                   <- what the licenses allow and how verification is graded
    THIRD_PARTY_ATTRIBUTION.md    <- credit lines to ship with the game
  models/                         <- game-ready GLBs, imported by Godot (see models/README.md)
  source/                         <- hidden from Godot by .gdignore
    _incoming/                    <- drop browser downloads here (contents are git-ignored)
    _archives/<pack id>/          <- original downloaded archives, never edited (git-ignored; SHA-256 is in sources.json)
    <category>/<pack id>/         <- optional untouched extraction of a pack (office, laboratory, architecture,
                                     industrial, decorations, documents, doors, temporal, debris)
```

`materials/` and `textures/` are added in Phase 2, when the first model is restyled. Folders appear
when something goes in them; nothing is created empty.

## Rules

- A model may only enter `models/` from a source marked `VERIFIED` in `sources.json`, with a license of
  CC0 or CC BY 4.0, and with a `derived_models` provenance entry. `validate_assets.py` enforces this.
- Originals are never edited. Conversions write a new GLB and record what changed.
- Raw archives stay out of git (`_archives/` and `_incoming/` ignore their contents). Provenance is the URL
  and SHA-256 in `sources.json`; anyone can fetch the same file again.
- Never download paid tiers (EXTRA, SOURCE, Pro, Set #3). Never work around a login, payment, captcha or
  rate limit; record it as `BLOCKED` or `MANUAL_DOWNLOAD_REQUIRED`.
- Files in `source/` are untrusted data. Nothing in them is ever run. `.blend` files are not opened by the tools.

## Workflow

```powershell
python tools/assets/download_assets.py --list                          # status of every record
python tools/assets/download_assets.py --discover <id>                 # print candidate file links from a page
python tools/assets/download_assets.py --only <id>[,<id>]              # download the URLs recorded in sources.json
python tools/assets/download_assets.py --adopt <zip> --id <id>         # register a download made by hand
python tools/assets/inspect_assets.py --markdown docs/assets/contents  # contents, formats, duplicates, missing textures
python tools/assets/download_assets.py --extract <id> --category office
python tools/assets/convert_models.py <source> <category/name.glb> --pack <id>
python tools/assets/validate_assets.py [--godot]                       # licenses, provenance, budgets, GLB sanity; --godot also loads each GLB in Godot
python tests/asset_tools.py                                            # self-test of these tools (synthetic data)
```

`--godot` and the Godot half of `tests/asset_tools.py` need `GODOT_BIN` pointing at Godot 4.7.2. The converter warns
and records `missing_textures` when Blender cannot read a texture, because it would otherwise export the model untextured without any error.

The converter needs Blender: `pip install -r tools/requirements-character.txt` installs `bpy`, or set
`BLENDER_BIN`. Blender's glTF exporter may log "Draco" and "MeshOptimizer" errors when installed from pip;
they refer to optional compression libraries this project does not use.
