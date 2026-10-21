#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")" && pwd)"
godot_bin="$repo_dir/.tools/Godot.app/Contents/MacOS/Godot"
[[ -x "$godot_bin" ]] || { echo "Run Setup-Offroad-Mac.command first." >&2; exit 1; }
exec arch -arm64 "$godot_bin" --path "$repo_dir" --rendering-method forward_plus --rendering-driver metal "$@"
