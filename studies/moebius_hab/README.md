# Illustrated hab — standalone room study

Created 2026-10-07 from the approved bunk/terminal concept. This is a new, independent Godot project with a newly modeled Blender room. It contains walking and collision only. No Space Trucking assets, controllers, shaders, saves or gameplay systems are referenced. The parent project's `studies/.gdignore` prevents its importer from scanning this study.

## Open

Double-click **Walk Illustrated Hab.command**. It expects Godot at `/Applications/Godot.app/Contents/MacOS/Godot`. Alternatively, import this folder's `project.godot` and run it. Do not run the parent game's default scene to see this room.

- WASD: walk; mouse: look.
- Shift: faster walking.
- Esc: release the mouse; click: recapture it.
- R: return to the starting view.
- H: hide/show the control legend.

Furniture, terminals and doors are static artwork. There is no interacting, cooking, cargo, simulation, saving or loading. The rear passage ends at a closed decorative hatch.

## Source and rendering

- `art/illustrated_hab.blend`: editable, individually named new Blender geometry, camera and lighting reference.
- `art/build_room.py`: complete deterministic modeling/export source. Starts from Blender factory settings and reads no game assets. Creates rounded pressure frames, cabinetry, desk, CRT/keypad, printer, chair, recessed sink, oven, water filter, kettle, plant, bench/table, bunk, shaped cloth and small fittings.
- `art/reference.png`: the approved illustration, kept for reference only; it is excluded from Godot import and never used as a backdrop or room texture.
- `art/build_report.json`: authored part and export batch counts.
- `assets/hab.glb`: standalone model export, grouped into spatial/material batches. Blender source retains individual parts. LOD generation/compression are disabled for this small study to preserve thin seams and cloth layering.
- `assets/collision.json`: simple explicitly authored collision volumes in Godot coordinates.
- `scripts/room.gd`: new walking controller, lighting, fresh procedural planet/rings/stars, visual capture and traversal checks.
- `shaders/illustrated.gdshader`: restrained diffuse light response for matte colors; no brush overlay or screen-space color filter.
- `shaders/outline.gdshader`: thin backface contour pass. Selected seams, hinges, fasteners and folds are actual authored geometry.
- `shaders/planet.gdshader`: new illustrative banded planet, used only outside the window.

The Blender material colors are the source palette; the final illustrated light response, outlines, directional shadows and ambient occlusion run in Godot Forward+/Metal. Blender's standard lighting preview is not an exact rendering of that Godot shader. Room lighting is deliberately fixed for the art test. The window view is a local-scale visual backdrop, not an astronomical simulation.

The approved illustration is the visual target, not a claim of pixel-identical reconstruction. The room plan resolves the image into walkable 3D geometry; the rear and reverse views are newly designed. Cloth, linework and fine details remain subject to the user's in-engine review. No art approval or production integration is implied by this build.

## Rebuild and verify

From this folder:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/build_room.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --walk-test
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --capture
```

`--walk-test` drives the real capsule through five waypoints (central aisle, rear passage and return), then checks that the bunk blocks the player. All six checks passed on 2026-10-07. `--capture` records five actual Godot viewport images in `review/` and a short warm static frame-time sample. Five viewpoints were visually reviewed. The 1400×1000 Forward+/Metal sample on an Apple M3 Pro was 8.34 ms median / 9.04 ms p95 in the final capture run. This is a limited local diagnostic, not a Steam Deck benchmark or general performance guarantee.

The parent game's prior rejected painterly overlay is unrelated to this study and was not reused or promoted. The original game and its saved progress remain separate.
