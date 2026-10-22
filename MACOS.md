# Offroad on Apple Silicon

Status: setup prepared from the GitHub main branch; full clone, imports,
runtime, Metal rendering and export have NOT been executed in this restricted
session. The repository contains about 251 MB of source files and assets.

## Setup

Keep all files in this setup folder together. In Terminal run:

```sh
bash /path/to/macos-setup/Setup-Offroad-Mac.command
```

The script clones into `~/Desktop/offroad-prototype`, creates a local
`macos/apple-silicon` branch, applies explicit Forward+ and native Metal
settings, and installs the official Godot 4.7.2 universal editor inside the
project's ignored `.tools` directory. Downloads are checked against the
release's SHA-512 sums. The editor runs as arm64 without Rosetta. Internet
and GitHub repository access are required; a private repository may need
Git authentication. An existing destination is never overwritten.

It imports assets and checks startup headlessly before opening the game.
Logs are kept in `.tools/import.log` and `.tools/startup.log`. These checks
do not verify GPU rendering or driving behavior. Review the visible game
on the Mac for those checks. No commit or push is performed.

## Play and edit

Double-click `Play-Offroad.command` in the cloned project, or run it with
`bash`. WASD drives, I starts the engine, V changes the camera, Esc opens
the menu. To open the editor:

```sh
./Play-Offroad.command --editor
```

If a Metal-specific rendering problem occurs, compare the Vulkan backend
without changing project settings:

```sh
arch -arm64 .tools/Godot.app/Contents/MacOS/Godot --path . --rendering-driver vulkan
```

## Export a standalone application

In this Godot editor, install the matching 4.7.2 export templates through
Editor > Manage Export Templates. Then run `Export-Offroad.command`.
The output is `build/Offroad-macOS-arm64.zip`, containing the native arm64
app for macOS 13 or later. Export uses built-in ad-hoc signing for local
testing. It is not Developer ID signed or notarized for public distribution.
The repository currently ignores `export_presets.cfg`; use `git add -f
export_presets.cfg` if you later want to commit this non-secret preset.

## Official sources

- https://github.com/godotengine/godot/releases/tag/4.7.2-stable
- https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp
- https://github.com/godotengine/godot/blob/4.7.2-stable/platform/macos/export/export_plugin.cpp
