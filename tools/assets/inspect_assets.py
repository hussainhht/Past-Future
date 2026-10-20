"""Inspect downloaded asset archives without extracting or executing anything inside them.

  python tools/assets/inspect_assets.py                       # every archive under source/_archives and _incoming
  python tools/assets/inspect_assets.py pack.zip --markdown docs/assets/contents
  python tools/assets/inspect_assets.py pack.zip --json report.json

Reports integrity, unsafe paths, model/texture/license files, duplicate files, missing texture
references, which formats Godot imports directly, and triangle counts and bounds for GLB models.
"""
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath
import argparse
import json
import posixpath
import re
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import assetlib as lib

DOC_NAME = re.compile(r"licen[sc]e|readme|credit|copying|terms|attribution", re.I)
MAX_GLB_BYTES = 64 << 20
MAX_TEXT_BYTES = 256 << 10


def map_reference(line: str):
    """The texture file named by an MTL map_*/bump line, ignoring its option flags."""
    tokens = line.split()
    if not tokens or not re.match(r"(map_\w+|bump|disp|decal|refl|norm)$", tokens[0], re.I):
        return None
    rest, index = tokens[1:], 0
    while index < len(rest) and rest[index].startswith("-"):
        index += 1
        while index < len(rest) and re.match(r"^[\d.+-]+$", rest[index]):
            index += 1
    return " ".join(rest[index:]) or None


def find_references(zf: zipfile.ZipFile, names: list) -> tuple:
    """Files that models point at (mtllib, textures, glTF buffers) which are missing or live elsewhere."""
    index = {name.lower(): name for name in names}
    by_base = defaultdict(list)
    for name in names:
        by_base[PurePosixPath(name).name.lower()].append(name)
    missing, relocated = [], []

    def check(owner: str, reference: str) -> None:
        reference = reference.strip().strip('"').replace("\\", "/")
        if not reference or reference.startswith("data:"):
            return
        resolved = posixpath.normpath(posixpath.join(posixpath.dirname(owner), reference))
        if resolved.lower() in index:
            return
        elsewhere = by_base.get(PurePosixPath(reference).name.lower())
        if elsewhere:
            relocated.append({"owner": owner, "reference": reference, "found": elsewhere[0]})
        else:
            missing.append({"owner": owner, "reference": reference})

    def text(name: str, limit: int = MAX_TEXT_BYTES) -> str:
        with zf.open(name) as handle:
            return handle.read(limit).decode("utf-8", errors="replace")

    for name in names:
        suffix = PurePosixPath(name).suffix.lower()
        try:
            if suffix == ".obj":
                for line in text(name).splitlines():
                    if line.lower().startswith("mtllib "):
                        check(name, line[7:])
            elif suffix == ".mtl":
                for line in text(name).splitlines():
                    reference = map_reference(line)
                    if reference:
                        check(name, reference)
            elif suffix == ".gltf":
                doc = json.loads(text(name, MAX_GLB_BYTES))
                for item in doc.get("images", []) + doc.get("buffers", []):
                    if "uri" in item:
                        check(name, item["uri"])
        except (ValueError, KeyError, zipfile.BadZipFile) as error:
            missing.append({"owner": name, "reference": f"(unreadable: {error})"})
    return missing, relocated


def inspect_zip(path: Path) -> dict:
    audit = lib.audit_zip(path)
    report = {"archive": str(path), "size": path.stat().st_size, "sha256": lib.sha256_file(path),
              "unpacked": audit["unpacked"], "entries": len([e for e in audit["entries"] if not e["dir"]]),
              "problems": list(audit["problems"]), "formats": {}, "models": [], "textures": [], "docs": [],
              "duplicates": [], "missing_references": [], "relocated_references": [], "glb": {}}
    files = [e for e in audit["entries"] if not e["dir"] and e["safe"]]
    names = [e["name"] for e in files]
    suffixes = Counter(PurePosixPath(n).suffix.lower() or "(none)" for n in names)
    report["formats"] = dict(sorted(suffixes.items()))
    report["models"] = sorted(n for n in names if PurePosixPath(n).suffix.lower() in lib.MODEL_SUFFIXES)
    report["textures"] = sorted(n for n in names if PurePosixPath(n).suffix.lower() in lib.TEXTURE_SUFFIXES)
    report["docs"] = sorted(n for n in names if DOC_NAME.search(PurePosixPath(n).name))
    groups = defaultdict(list)
    for entry in files:
        if entry["size"] > 0:
            groups[(entry["crc"], entry["size"])].append(entry["name"])
    report["duplicates"] = sorted(sorted(group) for group in groups.values() if len(group) > 1)
    present = {PurePosixPath(m).suffix.lower() for m in report["models"]}
    report["godot"] = {"direct": sorted(present & lib.GODOT_DIRECT), "needs_conversion": sorted(present - lib.GODOT_DIRECT)}
    if audit["entries"] and not audit["problems"]:
        with zipfile.ZipFile(path) as zf:
            report["missing_references"], report["relocated_references"] = find_references(zf, names)
            sizes = {e["name"]: e["size"] for e in files}
            for name in report["models"]:
                if PurePosixPath(name).suffix.lower() != ".glb" or sizes[name] > MAX_GLB_BYTES:
                    continue
                try:
                    report["glb"][name] = lib.model_stats(lib.parse_glb(zf.read(name))[0])
                except (ValueError, KeyError, IndexError) as error:
                    report["problems"].append(f"unreadable GLB '{name}': {error}")
    return report


def inspect_file(path: Path) -> dict:
    report = {"archive": str(path), "size": path.stat().st_size, "sha256": lib.sha256_file(path),
              "problems": [], "formats": {path.suffix.lower(): 1}, "models": [path.name], "glb": {}}
    if path.suffix.lower() == ".glb":
        try:
            report["glb"][path.name] = lib.model_stats(lib.parse_glb(path.read_bytes())[0])
        except (ValueError, KeyError, IndexError) as error:
            report["problems"].append(f"unreadable GLB: {error}")
    return report


def summarize(report: dict) -> str:
    glb = report["glb"].values()
    lines = [f"{Path(report['archive']).name}: {lib.human_bytes(report['size'])}, sha256 {report['sha256'][:16]}...",
             f"  formats: {report['formats']}"]
    if "entries" in report:
        lines.append(f"  {report['entries']} files, {lib.human_bytes(report['unpacked'])} unpacked; "
                     f"{len(report['models'])} model files, {len(report['textures'])} textures, "
                     f"{len(report['docs'])} license/readme files")
        lines.append(f"  Godot imports directly: {report['godot']['direct'] or 'none'}; "
                     f"needs conversion: {report['godot']['needs_conversion'] or 'none'}")
        lines.append(f"  duplicate groups: {len(report['duplicates'])}; missing texture/material references: "
                     f"{len(report['missing_references'])}; relocated: {len(report['relocated_references'])}")
    if glb:
        lines.append(f"  GLB models: {len(report['glb'])}, {sum(g['triangles'] for g in glb)} triangles total")
    lines += [f"  PROBLEM: {problem}" for problem in report["problems"]]
    return "\n".join(lines)


def markdown(report: dict, title: str) -> str:
    lines = [f"# {title} - archive contents", "",
             f"- Archive: `{Path(report['archive']).name}` ({lib.human_bytes(report['size'])})",
             f"- SHA-256: `{report['sha256']}`", f"- Files: {report.get('entries', 1)}, formats {report['formats']}", ""]
    if report.get("godot"):
        lines += [f"- Imported directly by Godot: {', '.join(report['godot']['direct']) or 'none'}",
                  f"- Needs conversion: {', '.join(report['godot']['needs_conversion']) or 'none'}", ""]
    lines += ["## License and readme files", ""] + [f"- `{n}`" for n in report.get("docs", [])] + [""]
    lines += ["## Models", "", "| File | Triangles | Size (x, y, z) |", "|---|---:|---|"]
    for name in report["models"]:
        stats = report["glb"].get(name)
        lines.append(f"| `{name}` | {stats['triangles'] if stats else ''} | {stats['size'] if stats and stats['size'] else ''} |")
    for heading, items in (("Duplicate files", [", ".join(f"`{n}`" for n in g) for g in report.get("duplicates", [])]),
                           ("Missing references", [f"`{m['owner']}` -> `{m['reference']}`" for m in report.get("missing_references", [])]),
                           ("Problems", report["problems"])):
        if items:
            lines += ["", f"## {heading}", ""] + [f"- {item}" for item in items]
    return "\n".join(lines) + "\n"


def targets(paths) -> list:
    found = []
    for item in paths:
        item = Path(item)
        if item.is_dir():
            found += sorted(p for p in item.rglob("*") if p.suffix.lower() in {".zip", ".glb"})
        elif item.exists():
            found.append(item)
        else:
            print(f"Skipping missing path {item}")
    return found


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="*", help="zip/glb files or folders (default: the archive folders)")
    parser.add_argument("--json", metavar="FILE")
    parser.add_argument("--markdown", metavar="DIR", help="write one contents listing per archive")
    args = parser.parse_args(argv)
    found = targets(args.paths or [lib.ARCHIVES, lib.INCOMING])
    if not found:
        print("No archives found. Download packs with download_assets.py or place them in source/_incoming/.")
        return 0
    reports = []
    for path in found:
        report = inspect_zip(path) if path.suffix.lower() == ".zip" else inspect_file(path)
        reports.append(report)
        print(summarize(report))
        if args.markdown:
            folder = Path(args.markdown)
            folder.mkdir(parents=True, exist_ok=True)
            pack = path.parent.name if path.parent.name not in {"_archives", "_incoming"} else path.stem
            (folder / f"{pack}_contents.md").write_text(markdown(report, pack), encoding="utf-8")
    if args.json:
        Path(args.json).write_text(json.dumps(reports, indent=2) + "\n", encoding="utf-8")
    return 1 if any(r["problems"] for r in reports) else 0


if __name__ == "__main__":
    sys.exit(main())
