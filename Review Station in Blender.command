#!/bin/bash
set -e
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
open -a /Applications/Blender.app "$project_dir/art/station_kit_v1/industrial_keel_and_hangar.blend"
