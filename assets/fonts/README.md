# Fonts

Every font the game uses lives here, as local files. Nothing is fetched at runtime, so all of it works
offline and in exported builds. How the fonts are applied is documented in `docs/TYPOGRAPHY_SYSTEM.md`.

## Installed

| Family | Files in this repo | Upstream (commit / version) | License |
|---|---|---|---|
| Departure Mono | `future/DepartureMono-Regular.otf` | https://github.com/rektdeckard/departure-mono, `public/assets/DepartureMono-Regular.otf` (v1.500, commit 75152a3) | SIL OFL 1.1 (`licenses/DepartureMono-OFL.txt`) |
| Monaspace Krypton | `future/MonaspaceKrypton-{Regular,Medium,Bold}.otf` | https://github.com/githubnext/monaspace, `fonts/Static Fonts/Monaspace Krypton` (v1.400 line, commit f31794b) | SIL OFL 1.1 (`licenses/Monaspace-OFL.txt`) |
| DSEG7 Classic | `future/DSEG7Classic-{Regular,Bold}.ttf` | https://github.com/keshikan/DSEG, taken from the official `dseg` npm package 0.46.0 (the repository itself only holds sources; builds are in its releases) | SIL OFL 1.1 (`licenses/DSEG-OFL.txt`) |
| Mona Sans | `dialogue/MonaSans-{Regular,Medium,Bold,MediumItalic,BoldItalic}.ttf` | https://github.com/github/mona-sans, `fonts/static/ttf` (commit 4bc6ba8) | SIL OFL 1.1 (`licenses/MonaSans-OFL.txt`) |
| Hubot Sans | `interface/HubotSans-{Medium,SemiBold,Bold,Black}.ttf` | https://github.com/github/hubot-sans, `fonts/ttf` (v1.1, commit d4b2f67) | SIL OFL 1.1 (`licenses/HubotSans-OFL.txt`) |
| Geist Sans | `interface/GeistSans-{Regular,Medium,SemiBold}.ttf` (renamed from `Geist-*.ttf`) | https://github.com/vercel/geist-font, `fonts/Geist/ttf` (commit 742b082) | SIL OFL 1.1 (`licenses/Geist-OFL.txt`) |

Only the weights the game uses were copied (no archives, no web fonts, no other families from those
collections). Each file was checked for a valid TrueType/OpenType header, and Godot 4.7.2 imports and
renders all of them.

## NOT installed yet (blocked at download time)

The session that did this work could not reach `fontspace.com` or `dafont.com` (the network policy refused
the connection), so these two files were **not** downloaded and nothing was substituted for them:

| Font | Put the file at | Download | Notes |
|---|---|---|---|
| To The Point (handwriting) | `handwriting/ToThePoint.ttf` | https://www.fontspace.com/to-the-point-font-f25644 | Stated to be SIL OFL; confirm on the download page and add its license text to `licenses/`. Small glyph set: missing characters fall back to Mona Sans. |
| Broken, by Picatype Design Studio | `menu/Broken.otf` | https://www.dafont.com/broken-3.font | **Check the license before commercial distribution.** dafont lists many fonts as "personal use only"; if this one is, buy or request a commercial license, or the menu title will have to ship in the fallback font. |

Until they are installed the code falls back automatically and nothing breaks: the journal handwriting uses
the system handwriting fonts it used before, and the main-menu title/buttons use Hubot Sans Black / Geist
SemiBold. Drop the files in, let Godot import them (open the editor once, or run
`godot --headless --import`), and `Typography` picks them up with no code change. Add their license texts
to `licenses/` at the same time.

After importing, commit the generated `*.import` files next to the fonts (the project already tracks
`*.import` files): exported builds need them.

## Glyph coverage notes

- To The Point and DSEG are Latin-only and small. DSEG7 has digits, `: - .` and a few seven-segment letters
  only; do not render sentences or units like "MHz" with it (its "M" and "z" are unreadable). Its
  `FontVariation` falls back to Geist and then Monaspace Krypton for anything it lacks.
- `✓ ✕` are missing from Geist, Mona Sans and Hubot Sans; `▼ ▲ ◀ ▶` are missing from Mona Sans and Hubot Sans;
  `◀ ▶ ● ○` are missing from Departure Mono. Every typography resource chains Geist and then Monaspace Krypton
  (which has all of these) as fallbacks, so no replacement boxes appear.
- None of these fonts cover Arabic. The project currently contains no Arabic text; if some is added, bundle
  a licensed Arabic font (for example Noto Sans Arabic, OFL) and append it to the fallbacks of the
  typography resources.
