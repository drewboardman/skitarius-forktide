#!/bin/sh
# Build the release package that gets dropped into the game's mods folder.
#
# The archive contains a single top-level "Skitarius" folder so it can be
# extracted straight into <game>/mods/, giving the layout Darktide Mod
# Framework expects:
#
#   mods/Skitarius/Skitarius.mod
#   mods/Skitarius/scripts/mods/Skitarius/...
#
# Usage: tools/package.sh <version>   (e.g. tools/package.sh v2.3.0)
set -eu

version="${1:?usage: tools/package.sh <version>}"

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/release"
staging="$out/Skitarius"

rm -rf "$staging"
mkdir -p "$staging/scripts/mods"
cp "$root/Skitarius.mod" "$staging/"
cp "$root/LICENSE" "$staging/"
cp -R "$root/scripts/mods/Skitarius" "$staging/scripts/mods/"

(cd "$out" && rm -f "Skitarius-$version.zip" && zip -r -q "Skitarius-$version.zip" Skitarius)
rm -rf "$staging"

echo "$out/Skitarius-$version.zip"
