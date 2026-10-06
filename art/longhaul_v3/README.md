# Longhaul — complete Blender interior and fitted exterior

Editable art replacement candidate for the existing Longhaul, built from the approved game layout. This does not replace the playable ship yet. Flight, saves, collision behavior and terminal code are unchanged.

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

## Godot exports and remaining integration

- `exports/longhaul_interior.glb`: interior only.
- `exports/longhaul_complete.glb`: interior and fitted exterior.

Both are self-contained GLB files, Y-up with nose toward -Z, shifted down 1.4 m from the Blender presentation elevation to match the current Godot deck origin. Source metadata is exported as glTF extras. Blender may append numerical suffixes to duplicated export object names; use binding/source metadata rather than relying on an exact duplicated name.

Validated by loading both through Godot 4.7.2 GLTFDocument and generating their scene trees. Both have one scene, packed images, all eight cockpit screens and mechanical animation tracks; presentation cameras/lights/stage are excluded. Export validates finite vertex coordinates. See `asset_stats.json` for mesh counts.

Before live replacement: bind current SubViewport terminal textures; reconnect interaction targets and moving-part controllers; reuse/verify gameplay collisions; replace static cargo props with runtime cargo; validate all passage and ramp clearances in play; tune materials and lighting in Godot; optimize text geometry, draw calls and small bevels. The review exports contain roughly 806k interior triangles and 872k complete-ship triangles, including text. They are detailed source assets, not yet a performance-approved production replacement. Blender and Godot lighting will differ.

`art/.gdignore` keeps these review assets out of automatic game imports until deliberate integration.

## Rebuild

1. From the project root, run Godot with `--headless --log-file /tmp/longhaul-capture.log --path . --script art/longhaul_v3/source/capture_interior.gd`. This builds a capture-only ship without running flight or loading/saving the player state.
2. Open the v2 Blender source, run `build_interior.py`, then `assemble_ship.py` once each in a fresh file. Scripts use their own `__file__` to resolve paths.
3. Run `export_ship.py` to evaluate separate export copies and save the editable source. All font/image dependencies are packed.
4. Run `source/validate_exports.gd` via Godot with the same headless/log-file flags to check GLB loading.

Capture snapshot: `source/interior_layout.json`. Builder and assembly scripts retain provenance and room separation for later asset editing.
