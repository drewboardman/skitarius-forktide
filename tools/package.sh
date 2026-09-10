#!/bin/sh
# Build the release package that gets dropped into the game's mods folder.
#
# The archive contains a single top-level "Forktide" folder so it can be
# extracted straight into <game>/mods/, giving the layout Darktide Mod
# Framework expects:
#
#   mods/Forktide/Forktide.mod
#   mods/Forktide/scripts/mods/Forktide/...
#
# Usage: tools/package.sh <version>   (e.g. tools/package.sh v2.3.0)
set -eu

version="${1:?usage: tools/package.sh <version>}"

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/release"
staging="$out/Forktide"

rm -rf "$staging"
mkdir -p "$staging/scripts/mods"
cp "$root/Forktide.mod" "$staging/"
cp "$root/LICENSE" "$staging/"
cp -R "$root/scripts/mods/Forktide" "$staging/scripts/mods/"

(cd "$out" && rm -f "Forktide-$version.zip" && zip -r -q "Forktide-$version.zip" Forktide)
rm -rf "$staging"

echo "$out/Forktide-$version.zip"
