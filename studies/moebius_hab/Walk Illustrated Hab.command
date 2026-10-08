#!/bin/bash
cd "$(dirname "$0")"
exec /Applications/Godot.app/Contents/MacOS/Godot --path . res://room.tscn
