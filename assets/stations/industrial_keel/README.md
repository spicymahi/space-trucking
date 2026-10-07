# Industrial keel / shared freight hangar

Production geometry exported from `art/station_kit_v1/industrial_keel_and_hangar.blend` with `art/station_kit_v1/export_game.py`. The editable Blender source includes the floor correction found during Godot integration: its structural slab sits below the gray deck plates, so it does not obscure them. Geometry uses metres, Godot Y-up and ship nose -Z.

## Assets

| Asset | Use | Triangles | Material surfaces |
| --- | --- | ---: | ---: |
| `standard_hangar.glb` | One full playable bay, with movable leaves and six live-display planes | 440,724 | 42 |
| `station_structure.glb` | Near station structure; instantiate bays at its two anchors | 133,218 | 10 |
| `station_distant.glb` | Distant station with two closed exterior shells and no interior detail | 29,684 | 25 |

Reference ship/ramp, sample cargo, mannequin, Blender lights/cameras, review animations and fake screen text are excluded. Static parts are batched by assembly/material; the ceiling remains its own `HangarRoof` mesh. Small manufacturing bevels are baked into near geometry; the distant model omits them. There are no texture dependencies.

`bindings.json` records all positions in **asset-local Godot coordinates**, before the runtime offset. Put the hangar root at `(0, -1.315, 0)` relative to the existing ship root. Local hangar floor is Y=0; the landing root is Y=1.315. Do not apply the floor offset a second time to marker children.

The near station intentionally has no bays: `BayAnchor_1` and `BayAnchor_2` are at X=-27 and X=27. The distant station already includes two closed bays. Avoid displaying the distant and near station at the same time.

## Movable door roots

| Root | Closed position | Open position |
| --- | --- | --- |
| `HangarDoorLeaf_1` | `(0, 1.125, 34.7)` | `(0, 10.6, 34.7)` |
| `HangarDoorLeaf_2` | `(0, 3.375, 34.2)` | `(0, 10.6, 34.2)` |
| `HangarDoorLeaf_3` | `(0, 5.625, 33.7)` | `(0, 10.6, 33.7)` |
| `HangarDoorLeaf_4` | `(0, 7.875, 33.2)` | `(0, 10.6, 33.2)` |

Each root owns one child mesh in local coordinates. The GLBs contain no animation clips; Godot owns the pressure/docking sequence and collisions. Clear opening is 18 m wide × 9 m tall at local Z=33..35.

## Live screens

The six meshes are `Screen_contracts`, `Screen_provisions`, `Screen_repairs`, `Screen_refuel`, `Screen_complete`, and `Screen_depart`. Each is a single UV-mapped quad suitable for a ViewportTexture material override. Counter screens face -X, with screen-right in world +Z; the departure screen faces +Z, with screen-right +X. All have screen-up +Y. The exported UVs map top-left to `(0,0)` and bottom-right to `(1,1)`, so the viewport image reads correctly without a UV flip.

Counter screen centres are `(11.048, 1.52, z)` where z is 7.5, 9.3, 11.1, 12.9 or 14.7, respectively; size is 0.77×0.53 m. Departure centre is `(-3.4, 1.46, 17.997)`, size 0.72×0.41 m. Screen vertices retain the bay coordinate system: do not reposition a named screen object at its centre.

The `IntegrationMarkers` subtree includes 24 grid origins, six service interactions, crew access, ship dock origin, touchdown, approach gate and ramp clearance. Use these markers for gameplay; the GLBs contain artwork and binding metadata, not functioning interactions or physics.

## Rebuild and verification

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background art/station_kit_v1/industrial_keel_and_hangar.blend --python art/station_kit_v1/export_game.py
```

Godot 4.7.2 GLTFDocument successfully imported all three assets. Four leaf transforms, six screen mesh bindings and all 35 marker transforms were checked. All six screen UV orientations and outward normals were verified against the exported binary. `art/station_kit_v1/export_stats.json` and `export_validation.json` record results. Functional docking, collisions and gameplay are owned and tested by the Godot integration.
