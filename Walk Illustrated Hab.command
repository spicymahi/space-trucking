#!/bin/bash
cd "$(dirname "$0")/studies/moebius_hab"
exec /Applications/Godot.app/Contents/MacOS/Godot --path . res://room.tscn
