#!/usr/bin/env bash
# Renders the iOS seasonal alternate app icons and their asset-catalog sets.
# Run from the repository root:  assets/app_icon/render_seasonal_icons.sh
set -euo pipefail

FONT="${ICON_FONT:-Farah}"
CATALOG="ios/Runner/Assets.xcassets"
PREVIEWS="assets/app_icon/previews"

render() {
  local theme="$1" name="$2"
  local set_dir="$CATALOG/AppIcon-$name.appiconset"
  local png="$set_dir/AppIcon-$name-1024.png"
  mkdir -p "$set_dir" "$PREVIEWS"
  swift assets/app_icon/render_icon.swift "$png" "$FONT" full "$theme"
  # App Store icons must be opaque; flatten any alpha channel.
  sips -s format jpeg "$png" --out "$png.jpg" >/dev/null
  sips -s format png "$png.jpg" --out "$png" >/dev/null
  rm -f "$png.jpg"
  cp "$png" "$PREVIEWS/seasonal-$theme.png"
  # Match the primary icon's explicit iPhone/iPad slots. Universal-only
  # alternates are omitted by actool when targeting older iOS releases.
  python3 - "$CATALOG/AppIcon.appiconset/Contents.json" "$set_dir" "$png" <<'PY'
import json
import pathlib
import subprocess
import sys

source, folder, original = map(pathlib.Path, sys.argv[1:])
contents = json.loads(source.read_text())
generated = set()
for image in contents["images"]:
    pixels = round(float(image["size"].split("x")[0]) * float(image["scale"][:-1]))
    filename = original.name if pixels == 1024 else f"Icon-{pixels}.png"
    image["filename"] = filename
    if pixels != 1024 and filename not in generated:
        subprocess.run(
            ["sips", "-z", str(pixels), str(pixels), str(original),
             "--out", str(folder / filename)],
            check=True, stdout=subprocess.DEVNULL,
        )
        generated.add(filename)
(folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
PY
}

render ramadan Ramadan
render eid_al_fitr EidAlFitr
render eid_al_adha EidAlAdha
