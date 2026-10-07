# Longhaul — complete Blender interior and fitted exterior

Editable Blender source for the playable Longhaul, built from the approved game layout. The normal flight scene now uses the optimized production model in `assets/ships/longhaul/longhaul_playable.glb`. Existing gameplay controllers, saved progress and interaction geometry remain authoritative. The combined ship-life session also installs this production model; it replaces the old cargo equipment with functional packing racks and adds live survival fixtures/paper. See [the development guide](../../docs/DEVELOPMENT.md) for controller ownership and combined regression checks.

## Review

Open `longhaul_full_ship.blend`. The scene selector provides:

- **LONGHAUL • Interior tour**: room cameras, packed textures and editable labels. Timeline frames 101, 121, 141, 161, 181, 201, 221 and 241 show cockpit, hab, washroom, airlock, cargo, engineering, galley and engineering service views.
- **LONGHAUL • Complete assembly**: fitted copy of the v2 exterior enclosing the interior.
- **LONGHAUL • Cutaway overview**: ceiling-free room arrangement.
- The original exterior study remains available for comparison.

Frame 1 is the initial state. Frame 80 demonstrates independent furniture/door movement; interior pieces return to their initial state at frame 100. These are presentation animations, not gameplay controllers. The ramp has its own original exterior action.

`renders/` contains actual Blender renders of all rooms, the complete ship and cutaway. Cockpit textures are static illustrative screen art from the existing project; runtime CLI, radar, map and velocity displays must replace them during integration.

## What is preserved and refined

The capture reproduces the current room dimensions, equipment positions, central passages, text and interaction locations. Blender adds small edge bevels, refined material response, CRT fasteners, chair rails, bunk trim, galley fixtures, cargo tie-downs and engineering fittings while retaining the blocky cassette-futurist style.

Eleven separate mechanical roots preserve the folding table, drawer, service cover, pump rotor, transfer case, washroom/airlock doors and loading hatch leaves. Eight individual cockpit screen meshes carry binding metadata. Hidden collections retain original collision envelopes and interaction anchors for reference. They are not active physics or game logic.

The fitted exterior has internal clearance openings and matching front/hab glazing. The v2 exterior file remains unchanged.

## Review exports and playable integration

- `exports/longhaul_interior.glb`: interior only.
- `exports/longhaul_complete.glb`: interior and fitted exterior.

Both are self-contained GLB files, Y-up with nose toward -Z, shifted down 1.4 m from the Blender presentation elevation to match the current Godot deck origin. Source metadata is exported as glTF extras. Blender may append numerical suffixes to duplicated export object names; use binding/source metadata rather than relying on an exact duplicated name.

Validated by loading both through Godot 4.7.2 GLTFDocument and generating their scene trees. Both have one scene, packed images, all eight cockpit screens and mechanical animation tracks; presentation cameras/lights/stage are excluded. Export validates finite vertex coordinates. See `asset_stats.json` for mesh counts.

The review exports contain roughly 806k interior triangles and 872k complete-ship triangles, including text. They are editable review assets. The separate production export has roughly **201k triangles**, no demo animations, and no baked interior text or duplicated runtime indicators/printer geometry. Current Godot labels remain live and crisp; eight Blender screen surfaces receive the existing terminal SubViewport textures.

`scripts/longhaul_blender_assets.gd` connects eleven Blender mechanical roots to their original controller nodes, preserving the imported axis transform so visible doors, furniture, repair hardware and the carried case stay aligned with their collision shapes. Dynamic status lamps, clamps, water effects, printer/paper and the functional folding ramp remain game-generated. Static original meshes are hidden; their colliders, triggers, labels and gameplay references are retained. New freight and station visuals are created after installation and remain visible.

`export_playable.py` removes exterior surfaces that intrude into room volumes and expresses transparent Blender glazing as standard glTF alpha materials. The production model lives outside `art/.gdignore` and is imported normally by Godot, including in game builds.

Validation: the full flight suite passes, including flight/arrival, physical screens, paper printing and pinning, display reassignment, map navigation, save/load, and manual cargo loading/delivery. Added binding checks verify all eleven moving roots, visible door/cover alignment, live screens and transparent glazing. Actual game renders were inspected for the cockpit, hab and engineering/cargo deck.

`art/.gdignore` keeps the large review sources out of automatic game imports. The production model is imported from `assets/ships/longhaul/`.

## Rebuild

1. From the project root, run Godot with `--headless --log-file /tmp/longhaul-capture.log --path . --script art/longhaul_v3/source/capture_interior.gd`. This builds a capture-only ship without running flight or loading/saving the player state.
2. Open the v2 Blender source, run `build_interior.py`, then `assemble_ship.py` once each in a fresh file. Scripts use their own `__file__` to resolve paths.
3. Run `export_ship.py` to evaluate separate export copies and save the editable source. All font/image dependencies are packed.
4. Run `source/validate_exports.gd` via Godot with the same headless/log-file flags to check GLB loading.

Capture snapshot: `source/interior_layout.json`. Builder and assembly scripts retain provenance and room separation for later asset editing.


## Rebuild the playable model

With the complete Blender source open, run `source/capture_live_visuals.gd` through Godot to capture current live indicator geometry, then run `export_playable.py` in Blender. Import the project in Godot before launching. This does not overwrite the editable source file or review exports.

Run the gameplay regression suite with:

```
Godot --headless --fixed-fps 60 --path . --log-file /tmp/longhaul-tests.log res://scenes/longhaul_flight.tscn -- --flight-test
```

The test path skips loading the player's save and uses temporary files for save/load checks. Launch the normal main scene without test flags to play with existing progress.
