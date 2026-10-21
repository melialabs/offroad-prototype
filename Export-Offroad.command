#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")" && pwd)"
godot_bin="$repo_dir/.tools/Godot.app/Contents/MacOS/Godot"
[[ -x "$godot_bin" ]] || { echo "Run Setup-Offroad-Mac.command first." >&2; exit 1; }
mkdir -p "$repo_dir/build"
exec arch -arm64 "$godot_bin" --headless --path "$repo_dir" --export-release "macOS Apple Silicon" "$repo_dir/build/Offroad-macOS-arm64.zip"
