#!/usr/bin/env python3
"""Finishes the Godot web export for the PWA (build/web-public by default).

- Manifest: app name "EMPIRE RUSH", short name, id/scope, theme colour,
  Vietnamese language (the Godot project name stays "Empire Rush" because it
  also names the user:// data folder).
- Service worker: the engine (.wasm) and game data (.pck) join the files
  cached at install time. Godot's worker only caches them on the *second*
  launch; precaching makes the game playable offline right after the first
  online launch. The cache name still changes with every export, so a new
  deploy replaces the old cache.
- .nojekyll for GitHub Pages (serve files as they are).
Fails loudly if the export does not look like a Godot web PWA export.
"""
import json
import os
import re
import sys

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "build", "web-public")
out = os.path.abspath(out)
need = ["index.html", "index.js", "index.wasm", "index.pck", "index.manifest.json", "index.service.worker.js"]
missing = [f for f in need if not os.path.isfile(os.path.join(out, f))]
if missing:
    sys.exit("not a Godot web PWA export (missing %s) in %s" % (missing, out))

mp = os.path.join(out, "index.manifest.json")
m = json.load(open(mp))
m.update({
    "name": "EMPIRE RUSH",
    "short_name": "EMPIRE RUSH",
    "id": "./index.html",
    "scope": "./",
    "start_url": "./index.html",
    "display": "standalone",
    "theme_color": "#060a12",
    "background_color": "#060a12",
    "lang": "vi",
    "description": "Cờ chiến thuật xây thành phố. Chơi offline với máy.",
})
for icon in m.get("icons", []):
    icon["purpose"] = "any"
json.dump(m, open(mp, "w"), ensure_ascii=False, indent=1)

sp = os.path.join(out, "index.service.worker.js")
sw = open(sp).read()
cached = json.loads(re.search(r"const CACHED_FILES = (\[[^\]]*\]);", sw).group(1))
opt = json.loads(re.search(r"const CACHEABLE_FILES = (\[[^\]]*\]);", sw).group(1))
for f in opt:
    if f not in cached:
        cached.append(f)
sw = re.sub(r"const CACHED_FILES = \[[^\]]*\];", "const CACHED_FILES = %s;" % json.dumps(cached), sw)
sw = re.sub(r"const CACHEABLE_FILES = \[[^\]]*\];", "const CACHEABLE_FILES = [];", sw)
open(sp, "w").write(sw)

open(os.path.join(out, ".nojekyll"), "w").close()
size = sum(os.path.getsize(os.path.join(out, f)) for f in os.listdir(out))
print("WEB POSTPROCESS ok: manifest name=%s, precached %d files, total %.1f MB in %s" % (m["name"], len(cached), size / 1048576, out))
