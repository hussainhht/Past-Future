"""Reacquire the exact published sources recorded in asset_provenance.json.

Only cached sources needed by prepare_audio_assets.py are extracted. Downloads are
kept outside the shipped assets. Existing downloads are reused after SHA256 checks.
"""
from pathlib import Path
import hashlib
import io
import json
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".godot/audio_sources"


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "PastFuture-AudioResearch/1.0"})
    return urllib.request.urlopen(request, timeout=60).read()


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    records = json.loads((ROOT / "assets/audio/asset_provenance.json").read_text(encoding="utf8"))
    downloads = {}
    pages = set()
    for record in records:
        source = record["cached_source"]
        target = CACHE / source
        page = record["source_url"]
        if page not in pages:
            if "kenney.nl" in page:
                page_name = page.rsplit("/", 1)[-1]
            elif source.startswith("past_music/"):
                page_name = "past_music"
            elif source.startswith("future_music/"):
                page_name = "future_music_alternative"
            else:
                page_name = Path(source).stem
            snapshot = CACHE / (page_name + ".html")
            if not snapshot.exists():
                snapshot.write_bytes(fetch(page))
            pages.add(page)
        if not target.exists():
            url = record["download_url"]
            if url not in downloads:
                print("Downloading", url, flush=True)
                downloads[url] = fetch(url)
            data = downloads[url]
            if url.lower().endswith(".zip"):
                with zipfile.ZipFile(io.BytesIO(data)) as archive:
                    member = source.split("/", 1)[1]
                    data = archive.read(member)
                    if "License.txt" in archive.namelist():
                        license_path = CACHE / source.split("/", 1)[0] / "License.txt"
                        license_path.parent.mkdir(parents=True, exist_ok=True)
                        license_path.write_bytes(archive.read("License.txt"))
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        if hashlib.sha256(target.read_bytes()).hexdigest() != record["source_sha256"]:
            raise RuntimeError("Published source changed; review its source/license before replacing " + source)
    print("Verified cached sources for", len(records), "imported assets.")


if __name__ == "__main__":
    main()
