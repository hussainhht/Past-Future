"""Exercise tools/assets with synthetic archives and a throwaway localhost server.

Run: python tests/asset_tools.py   (NumPy required)
Blender conversion checks run only if `bpy` is installed. If GODOT_BIN is also set, the converted
GLBs are loaded by that Godot in a throwaway project.

Nothing here touches the real asset library or the network. Fixtures are generated in a temp folder.
"""
from pathlib import Path
import contextlib
import http.server
import io
import os
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import threading
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "assets"))
import assetlib as lib
import convert_models
import download_assets
import inspect_assets
import validate_assets
from gltf_tools import Writer

os.environ["NO_PROXY"] = os.environ["no_proxy"] = "127.0.0.1,localhost"
failures, checks = [], 0


def make_png(rgb=(200, 120, 40)):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    rows = (b"\x00" + bytes(rgb) * 4) * 4
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


PNG = make_png()


def check(condition, message):
    global checks
    checks += 1
    if not condition:
        failures.append(message)
        print("FAIL:", message)


def cube_glb(path, lift=0.0, uri=None):
    low, high = (-0.5, lift, -0.5), (0.5, lift + 1.0, 0.5)
    corners = [(x, y, z) for x in (low[0], high[0]) for y in (low[1], high[1]) for z in (low[2], high[2])]
    faces = [(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1), (2, 3, 7), (2, 7, 6), (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3)]
    writer = Writer()
    position = writer.add(corners, "VEC3", 5126, target=34962, bounds=True)
    indices = writer.add([i for face in faces for i in face], "SCALAR", 5123, target=34963)
    doc = {"asset": {"version": "2.0", "generator": "asset_tools test"}, "scene": 0, "scenes": [{"nodes": [0]}],
           "nodes": [{"mesh": 0}], "meshes": [{"primitives": [{"attributes": {"POSITION": position}, "indices": indices}]}]}
    if uri:
        doc["images"] = [{"uri": uri}]
    writer.save(path, doc)
    return Path(path).read_bytes()


def make_zip(entries, links=()):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        for name, content in entries.items():
            zf.writestr(name, content)
        for name in links:
            info = zipfile.ZipInfo(name)
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            zf.writestr(info, "/etc/passwd")
    return buffer.getvalue()


class Server:
    """Serves canned responses and counts requests per path."""

    def __init__(self, routes):
        self.hits = {}
        server = self
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                server.hits[self.path] = server.hits.get(self.path, 0) + 1
                status, body, headers = routes.get(self.path, (404, b"missing", {}))
                self.send_response(status)
                headers = {"Content-Length": str(len(body)), **headers}
                for key, value in headers.items():
                    self.send_header(key, value)
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *args):
                pass
        self.httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.httpd.server_address[1]}"
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def close(self):
        self.httpd.shutdown()


def entry(pack_id, urls=(), license="CC0-1.0", verification="VERIFIED", attribution=False, name=None):
    return {"id": pack_id, "name": name or pack_id, "kind": "pack", "creator": "Test", "page_url": "http://127.0.0.1/x",
            "license": license, "license_url": "https://example.test/license", "attribution_required": attribution,
            "verification": {"status": verification}, "download": {"status": "MANUAL_DOWNLOAD_REQUIRED", "urls": list(urls)}}


def test_zip_safety(work):
    check(lib.clean_member("a/b.txt") is not None, "plain member should be accepted")
    for bad in ["../x", "a/../../x", "/abs", "C:\\win", "..\\x", "", "a\x00b"]:
        check(lib.clean_member(bad) is None, f"unsafe member {bad!r} should be rejected")
    evil = work / "evil.zip"
    evil.write_bytes(make_zip({"../escape.txt": "x", "/abs.txt": "x", "ok/model.glb": "x"}, links=["link"]))
    audit = lib.audit_zip(evil)
    check(len([p for p in audit["problems"] if "unsafe" in p]) == 3, "traversal, absolute and link entries must be flagged")
    outside = work / "escape.txt"
    written, skipped = lib.safe_extract(evil, work / "dest")
    check(not outside.exists() and not Path("/abs.txt").exists(), "extraction must never write outside the destination")
    check([p.name for p in written] == ["model.glb"] and len(skipped) == 3, "only the safe member should be extracted")
    corrupt = work / "corrupt.zip"
    corrupt.write_bytes(b"PK\x03\x04 not really a zip")
    check("not a readable zip" in lib.audit_zip(corrupt)["problems"][0], "a corrupt zip must be reported")
    bomb = work / "bomb.zip"
    bomb.write_bytes(make_zip({"zeros.bin": b"\0" * (50 << 20)}))
    check(any("zip bomb" in p for p in lib.audit_zip(bomb)["problems"]), "an extreme compression ratio must be flagged")
    (work / "dest" / "ok").mkdir(exist_ok=True)
    (work / "dest" / "ok" / "model.glb").write_bytes(b"changed by hand")
    _, skipped = lib.safe_extract(evil, work / "dest")
    check(any("already exists" in reason for _, reason in skipped), "a modified file must not be overwritten")


def test_glb_and_inspect(work):
    glb = cube_glb(work / "cube.glb")
    stats = lib.model_stats(lib.parse_glb(glb)[0])
    check(stats["triangles"] == 12 and stats["size"] == [1.0, 1.0, 1.0] and stats["min"][1] == 0.0, "cube bounds and triangle count")
    for broken in (glb[:30], b"XXXX" + glb[4:], glb + b"\0"):
        try:
            lib.parse_glb(broken)
            check(False, "a damaged GLB must be rejected")
        except ValueError:
            check(True, "")
    mtl = "newmtl wood\nmap_Kd -s 1 1 1 tex\\wood.png\nmap_Bump -bm 0.5 missing_normal.png\n"
    archive = work / "pack.zip"
    archive.write_bytes(make_zip({
        "Pack/License.txt": "CC0", "Pack/readme.md": "hi", "Pack/Models/cube.glb": glb, "Pack/Models/copy.glb": glb,
        "Pack/Models/crate.obj": "mtllib crate.mtl\nv 0 0 0\n", "Pack/Models/crate.mtl": mtl,
        "Pack/Models/chair.fbx": b"Kaydara FBX Binary", "Pack/Models/rig.blend": b"BLENDER", "Pack/Textures/wood.png": PNG}))
    report = inspect_assets.inspect_zip(archive)
    check(len(report["models"]) == 5 and len(report["textures"]) == 1, "model and texture discovery")
    check(len(report["docs"]) == 2, "license and readme files must be listed")
    check(len(report["duplicates"]) == 1 and len(report["duplicates"][0]) == 2, "identical files must be grouped")
    check([m["reference"] for m in report["missing_references"]] == ["missing_normal.png"], "missing texture must be found despite -bm option")
    check([m["found"] for m in report["relocated_references"]] == ["Pack/Textures/wood.png"], "relocated texture must be noticed")
    check(report["godot"]["needs_conversion"] == [".blend"] and ".fbx" in report["godot"]["direct"], "format guidance")
    check(report["glb"]["Pack/Models/cube.glb"]["triangles"] == 12, "GLB statistics inside a zip")
    check(not report["problems"], "a healthy archive reports no problems")
    markdown = inspect_assets.markdown(report, "pack")
    check("Missing references" in markdown and "Duplicate files" in markdown, "markdown listing")
    unsafe = work / "unsafe.zip"
    unsafe.write_bytes(make_zip({"../escape.txt": "x"}))
    check(inspect_assets.inspect_zip(unsafe)["problems"], "an unsafe archive must report problems")
    check(inspect_assets.map_reference("map_Kd -s 1 1 1 -o 0 0 a b.png") == "a b.png", "MTL option flags and spaced names")


def test_proxy_denial(work):
    """The cloud sandbox answers 403 to CONNECT for blocked hosts. Reproduce that with a fake local proxy."""
    import socket
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen(5)
    seen = []

    def refuse():
        while True:
            try:
                connection, _ = listener.accept()
            except OSError:
                return
            seen.append(connection.recv(4096).split(b"\r\n")[0])
            connection.sendall(b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            connection.close()
    threading.Thread(target=refuse, daemon=True).start()
    saved = {key: os.environ.get(key) for key in ("https_proxy", "HTTPS_PROXY")}
    os.environ["https_proxy"] = os.environ["HTTPS_PROXY"] = f"http://127.0.0.1:{listener.getsockname()[1]}"
    try:
        download_assets.fetch_file("https://blocked.example.test/pack.zip", work / "archives", timeout=5, backoff=0.01)
        check(False, "a refused tunnel must raise")
    except download_assets.DownloadError as error:
        check(error.status == "BLOCKED" and "network policy" in error.reason and not error.transient, f"proxy 403 must be BLOCKED: {error.status} {error.reason}")
    finally:
        listener.close()
        for key, value in saved.items():
            os.environ.pop(key, None) if value is None else os.environ.__setitem__(key, value)
    check(len(seen) == 1 and seen[0].startswith(b"CONNECT blocked.example.test:443"), f"a policy denial must not be retried: {seen}")
    check(not list((work / "archives").glob("*")), "no file may be left behind")
    import urllib.error
    check(download_assets.classify(urllib.error.HTTPError("u", 429, "Too Many Requests", {}, None)).status == "BLOCKED", "rate limits are recorded, not retried")
    check(download_assets.classify(urllib.error.HTTPError("u", 503, "Unavailable", {}, None)).transient, "5xx errors are retried")
    check(download_assets.classify(urllib.error.HTTPError("u", 404, "Not Found", {}, None)).status == "FAILED", "404 is a plain failure")


def test_downloads(work):
    good = make_zip({"Pack/License.txt": "CC0", "Pack/a.glb": cube_glb(work / "a.glb")})
    evil = make_zip({"../escape.txt": "x"})
    page = b'<a href="files/pack.zip">x</a> <a href="/x/Model.GLB?dl=1">y</a> <a href="notes.html">z</a>'
    server = Server({"/good.zip": (200, good, {}), "/forbidden.zip": (403, b"no", {}), "/notzip.zip": (200, b"<html>login</html>", {}),
                     "/short.zip": (200, good[:-20], {"Content-Length": str(len(good))}), "/evil.zip": (200, evil, {}),
                     "/page.html": (200, page, {})})
    try:
        sources, archives = work / "dl_sources.json", work / "dl_archives"
        data = {"schema": 1, "packs": [entry("good", [server.url + "/good.zip"]), entry("forbidden", [server.url + "/forbidden.zip"]),
                                        entry("notzip", [server.url + "/notzip.zip"]), entry("short", [server.url + "/short.zip"]),
                                        entry("evil", [server.url + "/evil.zip"]), entry("nourl")]}
        data["packs"][0]["page_url"] = server.url + "/page.html"
        lib.save_sources(data, sources)
        base = ["--sources", str(sources), "--archives", str(archives), "--backoff", "0.01", "--timeout", "5"]
        code = download_assets.main(base + ["--only", "good"])
        saved = lib.load_sources(sources)["packs"][0]["download"]
        check(code == 0 and saved["status"] == "DOWNLOADED", "a valid archive must download")
        path = Path(saved["files"][0]["archive"])
        check(path.read_bytes() == good and saved["files"][0]["sha256"] == lib.sha256_file(path), "bytes and checksum must match")
        download_assets.main(base + ["--only", "good"])
        check(server.hits["/good.zip"] == 1, "a second run must not download again")
        for pack_id, status, text, hits in [("forbidden", "BLOCKED", "403", 1), ("notzip", "FAILED", "rejected", 1),
                                            ("short", "FAILED", "", 3), ("evil", "FAILED", "unsafe", 1)]:
            code = download_assets.main(base + ["--only", pack_id])
            result = next(p for p in lib.load_sources(sources)["packs"] if p["id"] == pack_id)["download"]
            check(code == 1 and result["status"] == status and text in result["reason"], f"{pack_id}: expected {status}, got {result.get('status')} {result.get('reason')}")
            check(server.hits[f"/{pack_id}.zip"] == hits, f"{pack_id}: expected {hits} request(s), saw {server.hits.get(f'/{pack_id}.zip')}")
            leftovers = [p.name for p in (archives / pack_id).glob("*")] if (archives / pack_id).exists() else []
            check(leftovers == [], f"{pack_id}: no partial or rejected file may remain, found {leftovers}")
        check(download_assets.main(base + ["--only", "nourl"]) == 1, "an entry without a URL must not claim success")
        before = sources.read_text()
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            download_assets.main(base + ["--discover", "good"])
            download_assets.main(base + ["--list"])
        links = buffer.getvalue()
        check(f"{server.url}/files/pack.zip" in links and f"{server.url}/x/Model.GLB?dl=1" in links and "notes.html" not in links,
              "discover must print absolute file links only")
        check(sources.read_text() == before, "discover and list must not change sources.json")
        manual = work / "Manual Download (1).zip"
        manual.write_bytes(good)
        download_assets.main(base + ["--adopt", str(manual), "--id", "nourl"])
        adopted = lib.load_sources(sources)["packs"][5]["download"]
        check(adopted["status"] == "DOWNLOADED" and adopted["method"] == "manual" and Path(adopted["files"][0]["archive"]).exists(), "adopting a manual download")
        bad_manual = work / "bad.zip"
        bad_manual.write_bytes(b"nope")
        try:
            download_assets.main(base + ["--adopt", str(bad_manual), "--id", "nourl"])
            check(False, "a non-zip must not be adopted")
        except SystemExit:
            check(True, "")
        download_assets.main(base + ["--extract", "good", "--category", "office"])
        check((archives.parent / "office" / "good" / "Pack" / "a.glb").exists(), "extract places pristine files in source/<category>/<id>")
    finally:
        server.close()


def test_conversion(work):
    cube = work / "cube.glb"
    cube_glb(cube)
    sources = work / "conv_sources.json"
    lib.save_sources({"schema": 1, "packs": [entry("p")]}, sources)
    out = work / "models" / "furniture" / "lab_cube.glb"
    convert_models.main([str(cube), str(out), "--pack", "p", "--sources", str(sources)])
    derived = lib.load_sources(sources)["packs"][0]["derived_models"][0]
    check(out.read_bytes() == cube.read_bytes() and derived["sha256"] == lib.sha256_file(out), "GLB passthrough keeps bytes and records provenance")
    try:
        convert_models.main([str(cube), str(out), "--sources", str(sources)])
        check(False, "an existing destination must not be replaced without --force")
    except SystemExit as stop:
        check("already exists" in str(stop), "overwrite protection message")
    obj = work / "crate.obj"
    (work / "crate.png").write_bytes(PNG)
    (work / "crate.mtl").write_text("newmtl wood\nKd 1 1 1\nmap_Kd crate.png\n")
    obj.write_text("mtllib crate.mtl\nusemtl wood\nv 0 0 0\nv 1 0 0\nv 1 0 1\nv 0 0 1\nv 0 1 0\nv 1 1 0\nv 1 1 1\nv 0 1 1\n"
                   "vt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\n"
                   "f 1/1 2/2 3/3 4/4\nf 5/1 8/4 7/3 6/2\nf 1/1 5/4 6/3 2/2\nf 2/1 6/4 7/3 3/2\nf 3/1 7/4 8/3 4/2\nf 4/1 8/4 5/3 1/2\n")
    blend = work / "scene.blend"
    blend.write_bytes(b"BLENDER")
    try:
        convert_models.main([str(blend), str(work / "x.glb")])
        check(False, ".blend input must be refused")
    except SystemExit as stop:
        check("refused" in str(stop), ".blend refusal message")
    try:
        import bpy
    except ModuleNotFoundError:
        try:
            convert_models.main([str(obj), str(work / "crate.glb")])
            check(False, "OBJ conversion without Blender must explain what is missing")
        except SystemExit as stop:
            check("needs Blender" in str(stop), "missing-Blender message")
        print("NOTE: bpy not installed; OBJ/FBX conversion checks skipped")
        return
    destination = work / "models" / "furniture" / "crate.glb"
    convert_models.main([str(obj), str(destination), "--pack", "p", "--sources", str(sources)])
    stats = lib.model_stats(lib.parse_glb(destination.read_bytes())[0])
    check(stats["triangles"] == 12 and all(abs(v - 1.0) < 1e-3 for v in stats["size"]), f"OBJ cube converts without rescaling: {stats['size']}")
    check(stats["images"] == 1 and stats["external_images"] == [], f"the OBJ's texture must be embedded in the GLB: {stats['images']} images, {stats['external_images']}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0, 0, 1.0))
    fbx = work / "block.fbx"
    bpy.ops.export_scene.fbx(filepath=str(fbx))
    archive = work / "fbx_pack.zip"
    archive.write_bytes(make_zip({"Models/block.fbx": fbx.read_bytes()}))
    destination = work / "models" / "furniture" / "block.glb"
    convert_models.main([str(archive), str(destination), "--member", "Models/block.fbx", "--pack", "p", "--sources", str(sources)])
    stats = lib.model_stats(lib.parse_glb(destination.read_bytes())[0])
    check(stats["triangles"] == 12 and all(abs(v - 2.0) < 1e-2 for v in stats["size"]) and abs(stats["min"][1]) < 1e-2,
          f"FBX in a zip converts with 1 unit = 1 metre and the floor at Y=0: {stats['size']} {stats['min']}")
    check(len(lib.load_sources(sources)["packs"][0]["derived_models"]) == 3, "each conversion records provenance")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
    moving = bpy.context.object
    moving.keyframe_insert("location", frame=1)
    moving.location.z = 2.5
    moving.keyframe_insert("location", frame=24)
    bpy.ops.export_scene.fbx(filepath=str(work / "door.fbx"), bake_anim=True)
    animated = work / "animated" / "door.glb"
    convert_models.main([str(work / "door.fbx"), str(animated)])
    kept = lib.parse_glb(animated.read_bytes())[0].get("animations", [])
    check(len(kept) >= 1, "an animated source must keep its animation when converted")
    check(not any("missing_textures" in m for m in lib.load_sources(sources)["packs"][0]["derived_models"]), "no texture was lost in the healthy conversions")
    (work / "ghost.mtl").write_text("newmtl paint\nKd 1 1 1\nmap_Kd ghost_texture.png\n")
    (work / "ghost.obj").write_text(obj.read_text().replace("crate.mtl", "ghost.mtl").replace("usemtl wood", "usemtl paint"))
    ghost_sources = work / "ghost_sources.json"
    lib.save_sources({"schema": 1, "packs": [entry("p")]}, ghost_sources)
    convert_models.main([str(work / "ghost.obj"), str(work / "ghost_out" / "ghost.glb"), "--pack", "p", "--sources", str(ghost_sources)])
    ghost = lib.load_sources(ghost_sources)["packs"][0]["derived_models"][0]
    check(ghost.get("missing_textures") == ["ghost_texture.png"], f"a texture Blender cannot load must be recorded, not silently dropped: {ghost.get('missing_textures')}")
    godot = os.environ.get("GODOT_BIN")
    if not godot:
        print("NOTE: GODOT_BIN not set; skipping the check that Godot loads the converted GLBs")
    else:
        project = work / "godot_project"
        (project / "tools" / "assets").mkdir(parents=True)
        (project / "project.godot").write_text('config_version=5\n\n[application]\n\nconfig/name="AssetCheck"\n')
        shutil.copy(ROOT / "tools" / "assets" / "godot_model_check.gd", project / "tools" / "assets")
        shutil.copytree(work / "models", project / "assets" / "environment" / "models")
        run = lambda *args: subprocess.run([godot, "--headless", "--path", str(project), *args], capture_output=True, text=True, timeout=300)
        run("--import")
        output = run("--script", "res://tools/assets/godot_model_check.gd").stdout
        check("GODOT MODEL CHECK: PASS (3 models, 0 failures)" in output, f"Godot must load all converted GLBs: {output[-300:]}")
        check("crate.glb: triangles=12 textured_surfaces=1 size=(1.000, 1.000, 1.000) min_y=0.000" in output, "Godot sees the texture, the 1 m size and the floor origin")
        check("block.glb: triangles=12 textured_surfaces=0 size=(2.000, 2.000, 2.000) min_y=0.000" in output, "Godot sees the FBX block at 2 m on the floor")
        (project / "assets" / "environment" / "models" / "furniture" / "broken.glb").write_bytes(b"glTF" + b"\0" * 8)
        run("--import")
        broken = run("--script", "res://tools/assets/godot_model_check.gd")
        check("GODOT MODEL CHECK: FAIL" in broken.stdout and broken.returncode != 0, "a corrupt GLB must fail the Godot check")
    try:
        convert_models.main([str(archive), str(work / "y.glb"), "--member", "../../etc/passwd"])
        check(False, "an unsafe --member must be refused")
    except SystemExit as stop:
        check("not a safe archive path" in str(stop), "unsafe member message")


def test_validation(work):
    env = work / "env"
    (env / "licenses").mkdir(parents=True)
    (env / "source").mkdir()
    (env / "models" / "furniture").mkdir(parents=True)
    model = env / "models" / "furniture" / "lab_cube.glb"
    cube_glb(model)
    pack = entry("p", name="Test Pack")
    pack["derived_models"] = [{"path": "models/furniture/lab_cube.glb", "sha256": lib.sha256_file(model)}]
    sources = env / "licenses" / "sources.json"

    def run():
        lib.save_sources({"schema": 1, "packs": [pack]}, sources)
        errors, warnings, summary, note = validate_assets.validate(env)
        return errors, warnings

    errors, _ = run()
    check(any(".gdignore" in e for e in errors) and len(errors) == 1, f"missing .gdignore should be the only error: {errors}")
    (env / "source" / ".gdignore").write_text("")
    check(run()[0] == [], "a verified, recorded, floor-level model passes")
    cube_glb(env / "models" / "furniture" / "unlisted.glb")
    check(any("no provenance" in e for e in run()[0]), "a model without provenance must fail")
    (env / "models" / "furniture" / "unlisted.glb").unlink()
    pack["verification"]["status"] = "SEARCH_CORROBORATED"
    check(any("not VERIFIED" in e for e in run()[0]), "shipping from an unverified source must fail")
    pack["verification"]["status"] = "VERIFIED"
    pack["license"], pack["attribution_required"] = "CC-BY-4.0", True
    check(any("credit" in e for e in run()[0]), "a CC BY model without a credit line must fail")
    credits = env / "licenses" / "THIRD_PARTY_ATTRIBUTION.md"
    credits.write_text("# Credits\n\n## In use\n\n## Prepared for later\n\nTest Pack by Test, CC BY 4.0\n")
    check(any("credit" in e for e in run()[0]), "a credit line that is only prepared for later does not count")
    credits.write_text("# Credits\n\n## In use\n\nTest Pack by Test, CC BY 4.0\n\n## Prepared for later\n")
    check(run()[0] == [], "a credit line under 'In use' fixes it")
    pack["license"] = "CC-BY-NC-4.0"
    check(any("license" in e for e in run()[0]), "a non-commercial license must fail for a shipped model")
    pack["license"] = "CC0-1.0"
    cube_glb(model, lift=0.8)
    pack["derived_models"][0]["sha256"] = lib.sha256_file(model)
    errors, warnings = run()
    check(errors == [] and any("floor-level origin" in w for w in warnings), "a floating model is a warning")
    cube_glb(model, uri="wood.png")
    pack["derived_models"][0]["sha256"] = lib.sha256_file(model)
    check(any("self-contained" in e for e in run()[0]), "external textures must fail")
    cube_glb(model)
    check(any("differs" in w for w in run()[1]), "a model edited after recording is flagged")
    pack["download"] = {"status": "DOWNLOADED", "files": [{"archive": "source/_archives/p/x.zip", "sha256": "0" * 64}]}
    check(any("not on this machine" in w for w in run()[1]), "git-ignored archives are warnings on a fresh clone")
    (env / "source" / "_archives" / "p").mkdir(parents=True)
    (env / "source" / "_archives" / "p" / "x.zip").write_bytes(b"PK")
    check(any("SHA-256" in e for e in run()[0]), "a changed archive must fail its checksum")
    if not os.environ.get("GODOT_BIN"):
        check(validate_assets.godot_import(work, [], []).startswith("Godot import check SKIPPED"), "Godot check skips when GODOT_BIN is unset")


def main():
    with tempfile.TemporaryDirectory(prefix="pf-asset-tools-") as folder:
        work = Path(folder)
        for test in (test_zip_safety, test_glb_and_inspect, test_proxy_denial, test_downloads, test_conversion, test_validation):
            sub = work / test.__name__
            sub.mkdir()
            test(sub)
    print("ASSET TOOLS:", "PASS" if not failures else "FAIL", f"({checks} checks, {len(failures)} failures)")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
