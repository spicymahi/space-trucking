# Kestrel — A Quiet Delivery

Historical prototype documentation. The current integrated gameplay is **Test Ship Life.command**, documented in [GAMEPLAY.md](GAMEPLAY.md) and [SHIP_LIFE_TEST.md](SHIP_LIFE_TEST.md). Do not treat this prototype’s controls, economy or survival rules as current requirements.

A playable two-station prototype of the cozy cargo and ship-life loop. Launch `Play Life Slice.command` from the workspace root. This uses its own scene; the original game's startup scene is unchanged.

## First run

Start a new run, turn around, and walk through the cargo hold into Ceres Yard. Find the Contracts terminal and sign a delivery. Carry the two job crates from the station pallet into empty cargo slots aboard your ship.

Walk through the hab and engineering corridor to the cockpit. Take the seat, open the map, select Tharsis Ring, and enter its displayed coordinates into the computer. Release the dock and fly at least 400 m from the station before engaging the programmed route.

During transit, leave the seat to inspect engineering, repair the coolant pump, eat, drink, and wash. Arrival holds safely until you return. Fly toward the destination, release thrust to brake, and dock within 260 m at less than 12 m/s. Unload the crates and claim payment at Contracts. A return job is available afterward.

## Controls

| Action | Control |
| --- | --- |
| Walk / look | WASD / mouse |
| Use terminal, lift/place cargo, take/leave seat | F |
| Gameplay checklist | J |
| Pause and save menu | Escape |
| Save / load | F5 / F9 |
| Map and route computer while seated | N |
| Release dock | Space |
| Forward / reverse thrust | W / S |
| Strafe | A / D |
| Vertical thrust in flight | Space / Z |
| Steer | Mouse or arrow keys |
| Engage programmed route | C |
| Dock | L |
| Request recovery tug in flight | R |

Menus display their own keyboard shortcuts and clickable buttons. Only the pause menu pauses the simulation; arrival has no deadline.

## Included loops

Client contracts supply free cargo. Personal trade cargo costs money and can be sold at either station. Cargo can be moved by hand or handled by a paid dock service. Station services also provide fuel, provisions, and permanent repairs. The engineering computer reports component condition; a physical coolant-pump puzzle provides a temporary repair. Food, water, and hygiene decline gently. Save/load preserves the run and the checklist.

## Prototype boundaries

Stations use a shared simple service concourse. Paid handling is instantaneous, with no animated workers. Washing is a timed interaction at the washroom door. The repair puzzle covers one component. Exterior stations and flight physics are simplified; manual flight includes automatic braking when thrust is released. Route transit is deliberately short for testing. There are no combat systems, inspections, or delivery deadlines.

The ship interior stays in a stable local reference frame while exterior scenery follows flight state. This supports walking aboard during transit. This slice has its own save file, `user://life_slice_v1.json`.

## Validation

The `--slice-test` headless run passes 51 checks, walking the routes with movement input and exercising cargo, navigation, manual flight, transit, survival, repair, services, payouts, return contracts, and save/load. The standalone hab collision regression also passes. Forward+ screenshots were inspected for the cockpit and station.

Run from the Godot project directory:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --log-file /tmp/life-test.log --path . res://scenes/life_slice.tscn -- --slice-test
```
