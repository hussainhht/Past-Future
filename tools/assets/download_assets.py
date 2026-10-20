"""Download or register the free environment asset archives listed in licenses/sources.json.

  python tools/assets/download_assets.py --list
  python tools/assets/download_assets.py --discover milkandbanana_lab_assets
  python tools/assets/download_assets.py --only kenney_modular_space_kit,milkandbanana_lab_assets
  python tools/assets/download_assets.py --adopt "C:/Users/me/Downloads/Office.zip" --id vnb_office_set_1

A pack downloads only from the URLs in its sources.json "download.urls". Nothing is guessed, and a
refusal (login, payment, captcha, rate limit, network policy) is recorded as BLOCKED rather than worked
around. --discover prints candidate file links from a pack's page so a person can choose the free
Standard file; it never downloads or writes anything.
"""
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse
import argparse
import re
import shutil
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parent))
import assetlib as lib

USER_AGENT = "PastFuture-asset-tool/1.0"
BLOCK_CODES = {401, 402, 403, 407, 429}
PERMANENT_CODES = {404, 410}
FILE_LINK = re.compile(r"""href\s*=\s*["']([^"']+\.(?:zip|glb|gltf|fbx|obj|blend|7z|rar)(?:\?[^"']*)?)["']""", re.I)


class DownloadError(Exception):
    def __init__(self, status: str, reason: str, transient: bool = False):
        super().__init__(reason)
        self.status, self.reason, self.transient = status, reason, transient


def classify(error: Exception) -> DownloadError:
    if isinstance(error, DownloadError):
        return error
    if isinstance(error, urllib.error.HTTPError):
        blocked = error.code in BLOCK_CODES
        return DownloadError("BLOCKED" if blocked else "FAILED", f"HTTP {error.code} {error.reason}",
                             transient=error.code >= 500)
    if isinstance(error, urllib.error.URLError):
        text = str(error.reason)
        if "Tunnel connection failed: 403" in text or "Tunnel connection failed: 407" in text:
            return DownloadError("BLOCKED", "network policy refused the connection (proxy answered 403 to CONNECT)")
        return DownloadError("FAILED", f"network error: {text}", transient=True)
    return DownloadError("FAILED", f"{type(error).__name__}: {error}", transient=True)


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("._")


def open_url(url: str, timeout: float):
    # A fresh opener per call, so proxy settings are read from the environment each time.
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    return urllib.request.build_opener().open(request, timeout=timeout)


def drop_if_empty(folder: Path) -> None:
    try:
        folder.rmdir()
    except OSError:
        pass


def check_download(path: Path) -> None:
    suffix = path.name.removesuffix(".part").rsplit(".", 1)[-1].lower()
    if suffix == "zip":
        problems = lib.audit_zip(path)["problems"]
        if problems:
            raise DownloadError("FAILED", "archive rejected: " + "; ".join(problems[:3]))
    elif suffix == "glb":
        try:
            lib.parse_glb(path.read_bytes())
        except ValueError as error:
            raise DownloadError("FAILED", f"GLB rejected: {error}")


def fetch_file(url: str, folder: Path, timeout: float, attempts: int = 3, backoff: float = 2.0) -> Path:
    name = safe_name(unquote(Path(urlparse(url).path).name)) or "download.bin"
    folder.mkdir(parents=True, exist_ok=True)
    final = folder / name
    part = final.with_name(final.name + ".part")
    for attempt in range(1, attempts + 1):
        try:
            with open_url(url, timeout) as response, open(part, "wb") as out:
                expected, written = response.headers.get("Content-Length"), 0
                for block in iter(lambda: response.read(1 << 20), b""):
                    written += len(block)
                    if written > lib.LIMITS["archive_bytes"]:
                        raise DownloadError("FAILED", f"larger than the {lib.LIMITS['archive_bytes'] >> 20} MB limit")
                    out.write(block)
            if expected is not None and written != int(expected):
                raise DownloadError("FAILED", f"incomplete download: {written} of {expected} bytes", transient=True)
            check_download(part)
            part.replace(final)
            return final
        except Exception as error:
            part.unlink(missing_ok=True)
            failure = classify(error)
            if not failure.transient or attempt == attempts:
                drop_if_empty(folder)
                raise failure
            time.sleep(backoff * 2 ** (attempt - 1))
    raise DownloadError("FAILED", "no attempt made")


def record(path: Path, url) -> dict:
    return {"url": url, "archive": path.relative_to(lib.ENV).as_posix() if lib.ENV in path.parents else str(path),
            "sha256": lib.sha256_file(path), "size_bytes": path.stat().st_size, "date": lib.today()}


def download_pack(pack: dict, archives: Path, timeout: float, backoff: float) -> bool:
    entry = pack["download"]
    if not entry.get("urls"):
        print(f"  {pack['id']}: no direct URL recorded - {entry.get('manual', 'see the page_url')}")
        return False
    files = []
    for url in entry["urls"]:
        known = next((f for f in entry.get("files", []) if f.get("url") == url), None)
        target = archives / pack["id"] / (safe_name(unquote(Path(urlparse(url).path).name)) or "download.bin")
        if known and target.exists() and lib.sha256_file(target) == known["sha256"]:
            print(f"  {pack['id']}: already downloaded {target.name}")
            files.append(known)
            continue
        try:
            path = fetch_file(url, archives / pack["id"], timeout, backoff=backoff)
        except DownloadError as error:
            entry.update(status=error.status, reason=error.reason, last_attempt=lib.today())
            print(f"  {pack['id']}: {error.status} - {error.reason} ({url})")
            return False
        files.append(record(path, url))
        print(f"  {pack['id']}: downloaded {path.name} ({lib.human_bytes(path.stat().st_size)})")
    entry.update(status="DOWNLOADED", files=files, last_attempt=lib.today())
    entry.pop("reason", None)
    return True


def adopt(pack: dict, source: Path, archives: Path) -> None:
    if not source.is_file():
        raise SystemExit(f"{source} is not a file")
    folder = archives / pack["id"]
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / (safe_name(source.name) or "download.bin")
    shutil.copy2(source, target)
    try:
        check_download(target)
    except DownloadError as error:
        target.unlink()
        drop_if_empty(folder)
        raise SystemExit(f"Rejected {source.name}: {error.reason}")
    entry, added = pack["download"], record(target, None)
    entry["files"] = [f for f in entry.get("files", []) if f.get("archive") != added["archive"]] + [added]
    entry.update(status="DOWNLOADED", method="manual", last_attempt=lib.today())
    entry.pop("reason", None)
    print(f"  {pack['id']}: registered {target.name} ({lib.human_bytes(target.stat().st_size)})")


CATEGORIES = ("office", "laboratory", "architecture", "industrial", "decorations", "documents", "doors", "temporal", "debris")


def extract(pack: dict, category: str, destination: Path) -> None:
    if category not in CATEGORIES:
        raise SystemExit(f"--category must be one of: {', '.join(CATEGORIES)}")
    archives = [lib.ENV / f["archive"] for f in pack["download"].get("files", []) if f["archive"].endswith(".zip")]
    if not archives:
        raise SystemExit(f"{pack['id']} has no downloaded zip to extract")
    target = destination / category / pack["id"]
    for archive in archives:
        problems = lib.audit_zip(archive)["problems"]
        if problems:
            raise SystemExit(f"{archive.name} rejected: {'; '.join(problems[:3])}")
        written, skipped = lib.safe_extract(archive, target)
        print(f"  {pack['id']}: {len(written)} files extracted, {len(skipped)} skipped -> {target}")
        for name, reason in skipped:
            print(f"    skipped {name}: {reason}")
    pack["local_path"] = target.relative_to(lib.ENV).as_posix() if lib.ENV in target.parents else str(target)


def discover(pack: dict, timeout: float) -> None:
    page = pack["page_url"]
    try:
        with open_url(page, timeout) as response:
            html = response.read(2 << 20).decode("utf-8", errors="replace")
    except Exception as error:
        failure = classify(error)
        raise SystemExit(f"{pack['id']}: {failure.status} - {failure.reason} ({page})")
    links = sorted({urljoin(page, match) for match in FILE_LINK.findall(html)})
    print(f"{pack['id']}: {len(links)} candidate file link(s) on {page}")
    for link in links:
        print("  ", link)
    print("Pick only the free Standard file. Never add Source, Extra or Pro tiers. Put the chosen URL in "
          "sources.json under download.urls, then run --only.")


def show(data: dict) -> None:
    print(f"{'id':34s} {'priority':10s} {'license':11s} {'verification':20s} download")
    for pack in data["packs"]:
        priority = pack.get("priority", "-").split(" (")[0]
        print(f"{pack['id']:34s} {priority:10s} {pack.get('license', '-'):11s} "
              f"{pack['verification']['status']:20s} {pack['download']['status']}")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--list", action="store_true", help="show every entry and its status")
    parser.add_argument("--discover", metavar="ID", help="print candidate file links from a pack page")
    parser.add_argument("--only", metavar="ID[,ID]", help="download these entries")
    parser.add_argument("--adopt", metavar="FILE", help="register an archive downloaded by hand")
    parser.add_argument("--id", help="entry id for --adopt")
    parser.add_argument("--extract", metavar="ID", help="unpack a downloaded pack, untouched, into source/<category>/<id>")
    parser.add_argument("--category", help="source folder for --extract: " + ", ".join(CATEGORIES))
    parser.add_argument("--sources", default=str(lib.SOURCES))
    parser.add_argument("--archives", default=str(lib.ARCHIVES))
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--backoff", type=float, default=2.0)
    args = parser.parse_args(argv)
    data = lib.load_sources(args.sources)
    archives = Path(args.archives)
    if args.list:
        show(data)
        return 0
    if args.discover:
        discover(lib.pack_by_id(data, args.discover), args.timeout)
        return 0
    if args.adopt:
        if not args.id:
            parser.error("--adopt needs --id")
        adopt(lib.pack_by_id(data, args.id), Path(args.adopt), archives)
        lib.save_sources(data, args.sources)
        return 0
    if args.extract:
        if not args.category:
            parser.error("--extract needs --category")
        extract(lib.pack_by_id(data, args.extract), args.category, Path(args.archives).parent)
        lib.save_sources(data, args.sources)
        return 0
    if args.only:
        results = [download_pack(lib.pack_by_id(data, pack_id.strip()), archives, args.timeout, args.backoff)
                   for pack_id in args.only.split(",")]
        lib.save_sources(data, args.sources)
        return 0 if all(results) else 1
    parser.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
