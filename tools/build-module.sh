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

command -v node >/dev/null 2>&1 || { echo "ERROR: Node.js is required; run npm install first" >&2; exit 1; }
ESBUILD="$ROOT/node_modules/.bin/esbuild"
[ -x "$ESBUILD" ] || { echo "ERROR: esbuild is missing; run npm install first" >&2; exit 1; }

mkdir -p "$(dirname -- "$OUTPUT")"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/redmagicdualspace.XXXXXX")
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT HUP INT TERM

mkdir -p "$STAGE/scripts" "$STAGE/webroot"
cp "$META" "$STAGE/module.prop"
cp "$ROOT/scripts/dualspace.sh" "$STAGE/scripts/dualspace.sh"
cp "$ROOT/webroot/index.html" "$STAGE/webroot/index.html"
cp "$ROOT/webroot/style.css" "$STAGE/webroot/style.css"

"$ESBUILD" "$ROOT/webroot/app.js" \
  --bundle \
  --format=esm \
  --platform=browser \
  --target=es2020 \
  --outfile="$STAGE/webroot/app.js"

chmod 0755 "$STAGE/scripts/dualspace.sh"
chmod 0644 "$STAGE/module.prop" "$STAGE/webroot/index.html" "$STAGE/webroot/app.js" "$STAGE/webroot/style.css"
rm -f "$OUTPUT"
(
  cd "$STAGE"
  zip -X -q -r "$OUTPUT" module.prop scripts/dualspace.sh webroot
)

python3 - "$OUTPUT" <<'PY'
import sys
import zipfile
from pathlib import PurePosixPath

archive_path = sys.argv[1]
required = {
    "module.prop",
    "scripts/dualspace.sh",
    "webroot/index.html",
    "webroot/app.js",
    "webroot/style.css",
}
with zipfile.ZipFile(archive_path) as archive:
    names = set(archive.namelist())
    missing = sorted(required - names)
    if missing:
        raise SystemExit("ERROR: archive missing: " + ", ".join(missing))
    meta = archive.read("module.prop").decode("utf-8")
    if "id=redmagicdualspace" not in meta:
        raise SystemExit("ERROR: invalid module id")
    script = archive.getinfo("scripts/dualspace.sh")
    if (script.external_attr >> 16) & 0o777 != 0o755:
        raise SystemExit("ERROR: dualspace.sh is not executable in the archive")
    if any(PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts for name in names):
        raise SystemExit("ERROR: archive contains an unsafe path")
print(f"OK: validated {archive_path}")
PY
