"""Convert one model (FBX, OBJ, glTF, GLB) into a validated GLB under assets/environment/models.

  python tools/assets/convert_models.py SRC DST [--pack ID] [--note TEXT] [--force]
  python tools/assets/convert_models.py ARCHIVE.zip DST --member "Models/FBX format/wall.fbx" --pack ID

SRC is a model file, or a zip together with --member. DST is relative to assets/environment/models.
The original is never modified. GLB sources are validated and copied; other formats go through
Blender: the `bpy` module if installed, else the executable named by BLENDER_BIN or found on PATH.
.blend files are refused unless --allow-blend is given, because they can carry scripts.
No scaling, recentring or material edits happen here. With --pack, the result is added to that
entry's derived_models list in sources.json so every shipped model keeps its provenance.
"""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import assetlib as lib

HELPER = Path(__file__).resolve().with_name("_blender_export.py")


def blender_convert(source: Path, destination: Path) -> tuple:
    """Returns (tool description, names of textures Blender could not load)."""
    try:
        import _blender_export
        return _blender_export.convert(source, destination)
    except ModuleNotFoundError as error:
        if error.name != "bpy":
            raise
    blender = os.environ.get("BLENDER_BIN") or shutil.which("blender")
    if not blender:
        raise SystemExit("Converting FBX/OBJ/glTF needs Blender. Install the `bpy` package "
                         "(see tools/requirements-character.txt), set BLENDER_BIN, or put blender on PATH.")
    result = subprocess.run([blender, "--background", "--factory-startup", "--python-exit-code", "1",
                             "--python", str(HELPER), "--", str(source), str(destination)],
                            capture_output=True, text=True, timeout=600)
    if result.returncode:
        raise SystemExit("Blender conversion failed:\n" + (result.stdout + result.stderr)[-1500:])
    lines = result.stdout.splitlines()
    tool = next((line.split(" ", 1)[1] for line in lines if line.startswith("CONVERTED_WITH")), "Blender")
    return tool, sorted(line.split(" ", 1)[1] for line in lines if line.startswith("MISSING_TEXTURE"))


def resolve_destination(name: str) -> Path:
    destination = Path(name)
    if not destination.is_absolute():
        destination = lib.MODELS / destination
    if destination.suffix.lower() != ".glb":
        raise SystemExit("DST must end in .glb")
    return destination


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source")
    parser.add_argument("destination")
    parser.add_argument("--member", help="path of the model inside a zip SOURCE")
    parser.add_argument("--pack", help="sources.json entry this model comes from")
    parser.add_argument("--note", default="", help="extra text for the changes field")
    parser.add_argument("--force", action="store_true", help="replace an existing destination")
    parser.add_argument("--allow-blend", action="store_true")
    parser.add_argument("--sources", default=str(lib.SOURCES))
    args = parser.parse_args(argv)

    source, destination = Path(args.source), resolve_destination(args.destination)
    if destination.exists() and not args.force:
        raise SystemExit(f"{destination} already exists; use --force to replace it")
    if not source.is_file():
        raise SystemExit(f"{source} is not a file")
    scratch = Path(tempfile.mkdtemp(prefix="pf-convert-"))
    try:
        origin = source
        if source.suffix.lower() == ".zip":
            if not args.member:
                raise SystemExit("A zip SOURCE needs --member")
            problems = lib.audit_zip(source)["problems"]
            if problems:
                raise SystemExit("Archive rejected: " + "; ".join(problems[:3]))
            member = lib.clean_member(args.member)
            if member is None:
                raise SystemExit(f"'{args.member}' is not a safe archive path")
            lib.safe_extract(source, scratch / "pack")
            source = (scratch / "pack" / member).resolve()
            if not source.is_file():
                raise SystemExit(f"'{args.member}' is not in {origin.name}")
        suffix = source.suffix.lower()
        if suffix == ".blend" and not args.allow_blend:
            raise SystemExit(".blend files are refused (they can carry scripts); export to FBX/OBJ/glTF first")
        staged = scratch / "out.glb"
        missing = []
        if suffix == ".glb":
            lib.parse_glb(source.read_bytes())
            shutil.copyfile(source, staged)
            tool = "copied unchanged (already GLB)"
        else:
            tool, missing = blender_convert(source, staged)
        stats = lib.model_stats(lib.parse_glb(staged.read_bytes())[0])
        if not stats["triangles"]:
            raise SystemExit("Conversion produced a GLB with no triangles; refusing to install it")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(staged, destination)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)

    print(f"{destination}: {stats['triangles']} triangles, {stats['materials']} materials, size {stats['size']}, {tool}")
    if missing:
        print(f"  WARNING: textures could not be loaded and the model is exported without them: {', '.join(missing)}")
    if args.pack:
        data = lib.load_sources(args.sources)
        pack = lib.pack_by_id(data, args.pack)
        change = "Format conversion only; no geometry, scale or material edits." if suffix != ".glb" else "Copied unchanged."
        entry = {"path": destination.relative_to(lib.ENV).as_posix() if lib.ENV in destination.parents else str(destination),
                 "source_member": args.member or source.name, "source_archive_sha256": lib.sha256_file(origin) if origin.suffix.lower() == ".zip" else None,
                 "sha256": lib.sha256_file(destination), "converted_with": tool, "date": lib.today(),
                 "changes": (change + " " + args.note).strip()}
        if missing:
            entry["missing_textures"] = missing
        pack["derived_models"] = [m for m in pack.get("derived_models", []) if m["path"] != entry["path"]] + [entry]
        lib.save_sources(data, args.sources)
        print(f"  provenance recorded under '{args.pack}'")
    return 0


if __name__ == "__main__":
    sys.exit(main())
