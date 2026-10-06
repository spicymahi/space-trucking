#!/bin/bash
cd -- "$(dirname -- "$0")" || exit 1
exec /Applications/Godot.app/Contents/MacOS/Godot --rendering-method forward_plus --path . res://scenes/longhaul_flight.tscn
