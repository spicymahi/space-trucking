# Industrial keel station and standard freight hangar

Built 2026-10-06 for Blender review, using the user-selected industrial keel exterior and compact dispatch hangar concepts. The station exterior uses cream/olive/yellow; the shared hangar uses cream/red with restrained utility colors. Geometry is authored in Blender at one unit per metre. No Godot assets, gameplay code, entry points or saves were replaced.

## Open and review

Open `industrial_keel_and_hangar.blend`, or double-click `Review Station in Blender.command` in the repository root. Use Blender's Scene selector at the top right:

- **01 • INDUSTRIAL KEEL / exterior**: complete station with two linked instances of the same hangar, two process drums, an enclosed transfer corridor, operations block, structural keel, aft power equipment, radiators and auxiliary solar panels. The approaching Longhaul is a scale reference.
- **02 • HANGAR / interior walkthrough**: full room with the actual production Longhaul at its intended dock location. Frame 1 is the cargo-floor overview, frame 30 the player-eye view, and frame 60 the service counter. Frame 80 shows the pressure door open. The docked ship, ramp, human scale figure and sample cargo are review references, not part of the station export.
- **03 • HANGAR / clearance plan**: ceiling-free plan with dimensions, cargo pads, ramp and service locations.

The scene contains cameras for review. Ordinary Blender orbiting and viewport navigation remain available; this is not a playable Godot session. `renders/` contains actual renders from this Blender model, not image-generated concepts.

## Dimensions and operational layout

| Item | Dimension |
| --- | --- |
| Clear hangar interior | 28 m wide × 52 m deep × 10 m high |
| Flight doorway | 18 m wide × 9 m high |
| Pressure-door header | Four vertically telescoping leaves in separate depth tracks, with a hollow overhead housing |
| Existing Longhaul reference | 10.876 m wide × 26.459 m long × 5.66 m tall at ground alignment |
| Ship straight-in arrival | Nose along Blender +Y, landing feet 2 m above floor while translating, then descend at the dock position |
| Central cargo walkway | 4 m wide |
| Pickup and delivery | 12 stackable floor pads each, 4 × 3 × 4 cells at 0.45 m pitch |
| Service screens | Centered about 1.52 m above the floor |
| Human scale reference | 1.8 m tall |

X is ship width, Blender +Y is the ship nose, Z is up. Interior floor is Z=0. The hangar extends X=-14..14 and Y=-33..19; the outer pressure-door cassette is forward of the -33 boundary. The actual ship is not scaled. Its landing feet meet the floor with the game root at Blender Z=1.315. This is 0.115 m higher relative to ground than the older test apron; the reference ramp is adjusted accordingly. Preserve that relationship when building Godot collision geometry and controller transforms.

The service counter is beside the ship's aft section, clear of every pickup/delivery pad. It has five separate CRT terminals: contracts, provisions, repairs, refuel and delivery completion. Berth control is a separate pedestal beside the ramp. Cargo grids preserve the current 45 cm packing rule and floor-grid capacity. They have the same positions in ship X/longitudinal space as the approved cargo trial. Clearance assumes cargo is confined to these marked grids and the ship ramp retracts for flight.

The crew hatch and station-keeping machinery are artwork only. The pressure drums are exterior shells; their interiors are not modeled or playable. Artificial gravity, reactor capacity, thermal performance and pressure-vessel engineering are not physically simulated or certified by this art model.

## Reuse and integration boundaries

`HANGAR • reusable module` is the canonical collection; both station bays instance it, at X=-27 and +27. The shell, ceiling, floor, wall equipment, dispatch fixtures and mechanical door parts remain separate editable assemblies. Material/section batching reduces object overhead while retaining mesh editability. Four named door roots own the presentation animation. Decorative static text will need runtime station names where appropriate.

`INTEGRATION • markers and clearance volumes` contains named empties for dock/approach positions, the 24 cargo-grid origins, all six interaction terminals, ramp clearance and the future crew connection. `integration_manifest.json` records positions, units, coordinate conversion, bindings and limitations. These are integration anchors, not live game triggers or colliders.

For the later Godot import:

1. Export the station and one canonical hangar, excluding REVIEW, REFERENCE, example cargo/person, lights/cameras and the reference ship/ramp. `art/.gdignore` currently protects the working source from automatic Godot imports.
2. Keep each door leaf independently movable; install runtime pressure/docking interlocks. Do not use the demonstration timeline as a gameplay controller.
3. Create simple floor/wall/frame/door collision meshes; avoid detailed decoration colliders. Preserve the measured flight opening, ship-root elevation and ramp connection.
4. Bind the existing cargo grids, docking model, contract/provision/repair/refuel services and departure state to the supplied anchors. The five CRT meshes need live Godot screens.
5. Retain the established combined ship-life controller and save formats. Run actual manual/autodocking, walking/carrying, full pickup/delivery, provision, repair and refuel tests in a dedicated session before replacing normal stations.

The exported bay must not include the reference Longhaul, notebook props, ramp, mannequin or sample cargo. Two below-floor notebook meshes in the existing GLB are hidden only in the review copy; the game asset itself is unchanged.

## Rebuild and validation

Run `build_station.py` in a **fresh** Blender background process with `--factory-startup`; it replaces the new process's starter scene. Never execute that builder inside an unrelated live Blender file. It imports the existing `assets/ships/longhaul/longhaul_playable.glb` read-only, saves the editable model, and renders the review views. Set `STATION_RENDER=0` to build without rendering.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/station_kit_v1/build_station.py
/Applications/Blender.app/Contents/MacOS/Blender --background art/station_kit_v1/industrial_keel_and_hangar.blend --python art/station_kit_v1/validate_station.py
```

**59/59 Blender geometry checks passed.** `validation.json` records finite geometry, open entrance, straight-in swept ship clearance, landing envelope, all 24 cargo-grid clearances, sampled player capsule routes, closed/mid/open door clearances, leaf separation, grounded ship feet and shared bay instances. Walking checks use the current 0.35 m player radius and 1.8 m height; they validate planned paths against static art geometry, not Godot physics. Fixed equipment must stay outside those volumes. This does not claim functional gameplay validation before import.

The live Blender state that existed before this task was preserved separately at `/tmp/longhaul-before-station-review.blend`. The original editable Longhaul and production GLB were not overwritten.

## Approved reference direction

- Exterior: `docs/station-concepts/2026-10-06/exteriors-v2/03-industrial-keel.png`.
- Hangar: `docs/station-concepts/2026-10-06/hangar-colors/00-selected-hangar.png`, with the accepted broader color palette and cream/red variation.
- User also retained the freight-terminal and compact-service-port concepts as future station families. This task models the industrial family first and one reusable hangar; it does not instantiate all fifteen stations.
