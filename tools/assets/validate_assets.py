"""Validate the environment asset library: licenses, provenance, archives and models.

  python tools/assets/validate_assets.py             # check everything
  python tools/assets/validate_assets.py --godot     # also run Godot's headless importer (needs GODOT_BIN)

Exits non-zero on any error. A model may only ship from a source whose verification status is
VERIFIED, with an allowed license, a provenance entry and (for CC BY) a credit line.
"""
from pathlib import Path
import argparse
import os
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import assetlib as lib

REQUIRED = ("id", "name", "kind", "creator", "page_url", "license", "license_url", "attribution_required",
            "verification", "download")
NAME = re.compile(r"^[a-z0-9]+(_[a-z0-9]+)*\.glb$")
# Wall-mounted decorations and floating temporal crystals have no floor contact.
WALL_MOUNTED = {"decorations", "temporal"}
BUDGET = {"warn_triangles": 8000, "fail_triangles": 60000, "max_extent": 50.0, "min_extent": 0.02}


def check_sources(env: Path, errors: list, warnings: list) -> dict:
    path = env / "licenses" / "sources.json"
    if not path.exists():
        errors.append(f"{path} is missing")
        return {"packs": []}
    data = lib.load_sources(path)
    seen = set()
    for pack in data["packs"]:
        label = pack.get("id", "?")
        missing = [key for key in REQUIRED if key not in pack]
        if missing:
            errors.append(f"{label}: missing fields {missing}")
            continue
        if label in seen:
            errors.append(f"{label}: duplicate id")
        seen.add(label)
        if pack["verification"]["status"] not in lib.VERIFIED_STATES:
            errors.append(f"{label}: unknown verification status '{pack['verification']['status']}'")
        if pack["license"] not in lib.ALLOWED_LICENSES:
            warnings.append(f"{label}: license '{pack['license']}' is not CC0-1.0, CC-BY-4.0 or project-original; do not use until approved")
    return data


def check_downloads(env: Path, data: dict, errors: list, warnings: list) -> int:
    present = 0
    for pack in data["packs"]:
        entry = pack.get("download", {})
        if entry.get("status") == "DOWNLOADED" and not entry.get("files"):
            errors.append(f"{pack['id']}: marked DOWNLOADED but lists no files")
        for item in entry.get("files", []):
            archive = env / item["archive"]
            if not archive.exists():
                warnings.append(f"{pack['id']}: archive {item['archive']} is not on this machine; re-run download_assets.py")
            elif lib.sha256_file(archive) != item["sha256"]:
                errors.append(f"{pack['id']}: {item['archive']} does not match its recorded SHA-256")
            else:
                present += 1
    return present


def in_use_credits(path: Path) -> str:
    """Text under '## In use' only, so credit lines prepared for later cannot satisfy the check early."""
    if not path.exists():
        return ""
    match = re.search(r"^## In use[ \t]*$(.*?)(?=^## |\Z)", path.read_text(encoding="utf-8"), re.S | re.M)
    return match.group(1) if match else ""


def check_models(env: Path, data: dict, errors: list, warnings: list) -> int:
    recorded = {}
    for pack in data["packs"]:
        for model in pack.get("derived_models", []):
            recorded[model["path"]] = (pack, model)
            if pack["verification"]["status"] != "VERIFIED":
                errors.append(f"{model['path']}: ships from '{pack['id']}', which is {pack['verification']['status']}, not VERIFIED")
            if pack["license"] not in lib.ALLOWED_LICENSES:
                errors.append(f"{model['path']}: ships from '{pack['id']}' with license '{pack['license']}'")
    credits = in_use_credits(env / "licenses" / "THIRD_PARTY_ATTRIBUTION.md")
    for pack in data["packs"]:
        if pack.get("derived_models") and pack["attribution_required"] and pack["name"] not in credits:
            errors.append(f"{pack['id']}: CC BY credit for '{pack['name']}' is missing from THIRD_PARTY_ATTRIBUTION.md")
    models = sorted((env / "models").rglob("*.glb")) if (env / "models").exists() else []
    for model in models:
        relative = model.relative_to(env).as_posix()
        if not NAME.match(model.name):
            warnings.append(f"{relative}: use lowercase snake_case names")
        if relative not in recorded:
            errors.append(f"{relative}: no provenance entry in sources.json (derived_models)")
        elif lib.sha256_file(model) != recorded[relative][1]["sha256"]:
            warnings.append(f"{relative}: differs from its recorded conversion; note the edit in 'changes'")
        if relative in recorded and recorded[relative][1].get("missing_textures"):
            warnings.append(f"{relative}: converted without textures {recorded[relative][1]['missing_textures']}")
        try:
            stats = lib.model_stats(lib.parse_glb(model.read_bytes())[0])
        except (ValueError, KeyError, IndexError) as error:
            errors.append(f"{relative}: unreadable GLB ({error})")
            continue
        if stats["external_images"]:
            errors.append(f"{relative}: references external textures {stats['external_images'][:2]}; GLBs must be self-contained")
        if stats["triangles"] > BUDGET["fail_triangles"]:
            errors.append(f"{relative}: {stats['triangles']} triangles is far over budget")
        elif stats["triangles"] > BUDGET["warn_triangles"]:
            warnings.append(f"{relative}: {stats['triangles']} triangles is heavy for a prop")
        if stats["size"] is None:
            warnings.append(f"{relative}: bounds unavailable")
            continue
        if max(stats["size"]) > BUDGET["max_extent"] or max(stats["size"]) < BUDGET["min_extent"]:
            warnings.append(f"{relative}: size {stats['size']} looks like a unit/scale problem")
        if model.parent.name not in WALL_MOUNTED and not -0.12 <= stats["min"][1] <= 0.05:
            warnings.append(f"{relative}: lowest point is Y={stats['min'][1]}, not the floor-level origin the project requires")
    return len(models)


def check_layout(env: Path, errors: list, warnings: list) -> None:
    source = env / "source"
    if source.exists() and not (source / ".gdignore").exists():
        errors.append("assets/environment/source/.gdignore is missing; Godot would import every raw source file")


def godot_import(project: Path, errors: list, warnings: list) -> str:
    binary = os.environ.get("GODOT_BIN")
    if not binary:
        return "Godot import check SKIPPED (set GODOT_BIN to the Godot executable)"
    imported = subprocess.run([binary, "--headless", "--path", str(project), "--import"],
                              capture_output=True, text=True, timeout=900)
    checked = subprocess.run([binary, "--headless", "--path", str(project), "--script", "res://tools/assets/godot_model_check.gd"],
                             capture_output=True, text=True, timeout=900)
    output = imported.stdout + imported.stderr + checked.stdout + checked.stderr
    bad = [line for line in output.splitlines() if "ERROR" in line and "assets/environment" in line]
    errors.extend(f"Godot: {line.strip()}" for line in bad)
    if imported.returncode:
        errors.append(f"Godot import exited with code {imported.returncode}")
    summary = next((line for line in checked.stdout.splitlines() if line.startswith("GODOT MODEL CHECK:")), None)
    if summary is None or "PASS" not in summary:
        errors.append(f"Godot model check did not pass: {summary or 'no result line'}")
    return f"Godot ran: {summary or 'model check produced no result'}"


def validate(env: Path, project: Path = lib.ROOT, godot: bool = False) -> tuple:
    errors, warnings = [], []
    data = check_sources(env, errors, warnings)
    archives = check_downloads(env, data, errors, warnings)
    models = check_models(env, data, errors, warnings)
    check_layout(env, errors, warnings)
    note = godot_import(project, errors, warnings) if godot else "Godot import check not requested"
    verified = sum(1 for p in data["packs"] if p.get("verification", {}).get("status") == "VERIFIED")
    summary = (f"{len(errors)} errors, {len(warnings)} warnings; {models} models, {archives} archives on disk, "
               f"{verified} of {len(data['packs'])} sources verified")
    return errors, warnings, summary, note


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", action="store_true")
    parser.add_argument("--env", default=str(lib.ENV), help="assets/environment folder to check")
    parser.add_argument("--project", default=str(lib.ROOT), help="Godot project folder for --godot")
    args = parser.parse_args(argv)
    errors, warnings, summary, note = validate(Path(args.env), Path(args.project), godot=args.godot)
    for line in errors:
        print("ERROR  ", line)
    for line in warnings:
        print("WARNING", line)
    print(note)
    print("ASSET LIBRARY:", "PASS" if not errors else "FAIL", f"({summary})")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
