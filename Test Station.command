#!/bin/bash
cd -- "$(dirname -- "$0")" || exit 1
exec /Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/station_trial.tscn
