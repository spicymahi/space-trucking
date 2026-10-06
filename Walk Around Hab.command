#!/bin/bash
# Standalone room study; the main game's startup scene is unchanged.
cd -- "$(dirname -- "$0")" || exit 1
exec /Applications/Godot.app/Contents/MacOS/Godot --rendering-method forward_plus --path . res://scenes/hab_preview.tscn
