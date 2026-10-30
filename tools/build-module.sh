#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
META="$ROOT/module.prop"
[ -f "$META" ] || { echo "ERROR: module.prop is missing" >&2; exit 1; }

version=$(sed -n 's/^version=//p' "$META" | head -n 1)
[ -n "$version" ] || { echo "ERROR: module.prop has no version" >&2; exit 1; }
OUTPUT=${1:-"$ROOT/dist/RedMagicDualSpace-$version.zip"}
case "$OUTPUT" in
  /*) ;;
  *) OUTPUT="$ROOT/$OUTPUT" ;;
esac
mkdir -p "$(dirname -- "$OUTPUT")"

python3 - "$ROOT" "$OUTPUT" <<'PY'
import pathlib
import re
import sys
import zipfile

root = pathlib.Path(sys.argv[1])
output = pathlib.Path(sys.argv[2])
required = [
    "module.prop",
    "scripts/dualspace.sh",
    "webroot/index.html",
    "webroot/app.js",
    "webroot/kernelsu-api.js",
    "webroot/style.css",
]
for name in required:
    if not (root / name).is_file():
        raise SystemExit(f"ERROR: required module file is missing: {name}")

metadata = {}
for line in (root / "module.prop").read_text(encoding="utf-8").splitlines():
    if "=" in line and not line.lstrip().startswith("#"):
        key, value = line.split("=", 1)
        metadata[key.strip()] = value.strip()
if not re.fullmatch(r"[A-Za-z][A-Za-z0-9._-]+", metadata.get("id", "")):
    raise SystemExit("ERROR: module.prop has an invalid or missing module id")
if not metadata.get("name") or not metadata.get("version"):
    raise SystemExit("ERROR: module.prop must define name and version")
try:
    int(metadata.get("versionCode", ""))
except ValueError:
    raise SystemExit("ERROR: module.prop versionCode must be an integer")

files = required + ["README.md", "LICENSE"]
files = [name for name in files if (root / name).is_file()]
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for name in sorted(files):
        info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
        info.create_system = 3
        info.compress_type = zipfile.ZIP_DEFLATED
        mode = 0o755 if name == "scripts/dualspace.sh" else 0o644
        info.external_attr = (mode & 0xFFFF) << 16
        archive.writestr(info, (root / name).read_bytes())
print(f"Built {output} ({output.stat().st_size} bytes)")
PY
