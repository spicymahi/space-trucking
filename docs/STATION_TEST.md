# Blender station playtest

The approved industrial-keel station and shared hangar are integrated into a dedicated full-gameplay session. Double-click **Test Station.command** in the repository root. It starts at the dispatch counter inside the Blender hangar and resumes its own progress on later launches. **F1** opens the in-game guide. The project default, **Test Ship Life.command**, and their saves remain separate.

This is an art and gameplay integration test. All fifteen economy locations provisionally use this industrial exterior and the same hangar. Their names, industries, inventories, contracts and routes remain distinct. The other approved station families are future artwork, not implemented variants.

## Try a complete delivery

1. Use **F** at **CONTRACTS**. `jobs` lists work; `accept 1` normally selects a small consignment. Review the destination before accepting. Collection contracts begin with an empty journey to the supplier.
2. The counter also has **PROVISIONS**, **REPAIRS**, **REFUEL**, and **DELIVERY** screens. Buy stores using `buy food <days>` and `buy water <days>`. At REFUEL, `refuel` fills the tank at the displayed price. Repairs use `quote all` and `repair all`. An eligible `advance` covers an essential shortfall against the accepted contract's final fee.
3. Pickup cargo is on the marked grids to the left of the rear ramp; delivery grids are on the right. Carry with **F**, rotate with **R/T**, and pack the ship's racks. The twelve pickup and twelve delivery pads retain stacking, support and removal rules. Use the ship's four staging grids to rearrange cases, then clear them and engage **CARGO LOCK**.
4. Follow the cockpit checklist: print the instructions, start both engines, plot at CHART, transcribe coordinates/burn/reserve at NAV and `load`, obtain/read back the ATC code, close the cargo hatch, and raise the ramp. Sensor and cargo interlocks still apply.
5. At COMMS, `depart` requests the station pressure door. Wait about **six seconds**, then enter `depart` again to release the berth. **G** enters the pilot seat. Gently lift about **2 m with Space**, brake the upward movement with **Ctrl**, then **S** reverses straight through the opening behind the ship. Keep the ship level and centered; **Shift** provides fine thrust and **X** stops rotation. Beyond **300 m**, NAV `engage` starts the calculated transfer.
6. Live aboard during the trip: the existing hab, kitchen, water, paper, sensor puzzles, shower and rest loop remain active. NAV remains engaged until `manual`. Rest still ends before the arrival-watch boundary.
7. At arrival, NAV `approach` reserves **BAY 01** and requests its pressure door. `auto dock` is available inside **1000 m** and below **15 m/s** relative speed. It aligns outside the entrance, flies **nose-first** through the actual opening with landing feet 2 m above the floor, stops over the dock, and descends.
8. For manual landing, use `manual`, enter from the green approach lights with nose **heading 000 / pitch 000**, keep the ship level, and stop above the landing marks. Descend and use `dock` within **3 m**, below **1 m/s**, with less than **1.5 m lift** and rotation stopped. The door must be clear.
9. After touchdown, lower the ramp and open the cargo hatch. Unlock and unload every case onto the delivery grids. **F** at DELIVERY completes the contract and pays once. Collection contracts use this same loop on their return leg.

The berth-control pedestal beside the ramp also offers `start test`. After accepting and securing the contract, it prepares flight and places the ship outside the station for a real transfer. It skips the cockpit checklist and manual departure only; fuel, transit, arrival, cargo and survival remain active. Use normal departure when testing the new door and flight opening.

## Dimensions and behavior

| Feature | Integrated value |
| --- | --- |
| Interior clearance | 28 m wide × 52 m deep × 10 m high |
| Flight opening | 18 m wide × 9 m high |
| Longhaul reference | 10.876 m wide × 26.459 m long; original ship scale |
| Bay floor relative to docked ship origin | Godot Y = −1.315 m |
| Ship forward / entry direction | Godot −Z; entrance behind the dock at +Z, about Z = 34 m |
| Pressure door | Four independently moving telescoping leaves; six-second travel |
| Cargo pads | Twelve pickup and twelve delivery; 4×3×4 cells, 0.45 m pitch |
| Working stations | Five counter terminals plus berth-control pedestal |

Both exterior bays reuse the canonical hangar asset. BAY 01 is the assigned playable bay; BAY 02 is a closed visual instance. The station stays in its own orbital frame as the ship translates and rotates. Detailed nearby geometry changes to a lighter exterior beyond 1800 m; engaging NAV alone does not remove the departing station.

Walking uses simple floor, wall, counter, frame and moving-door collision shapes. Flying uses swept, conservative ship bounds against the bay and major station structures. Contact arrests motion without damage. These are measured safety volumes, not mesh-perfect collision or rigid-body impact simulation. Decorative fittings are not individual physics objects. The door waits if the ship or player occupies its closing threshold. Detailed pressure equalization, NPC bay traffic and the station's non-hangar interiors are not simulated.

## Saves and testing

Normal station play writes `user://station_trial_v1.json` and `user://station_trial_departure_v1.json`. **F5** saves and **F9** loads. These files do not replace `ship_life_v1.json`, its departure checkpoint, or `longhaul_flight_v1.json`. The mechanical door position is transient; on restore, its requested state is reconstructed from flight state. A restored docked checkpoint does not retain an abandoned departure request.

Run the station integration suite from the repository root:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/station-trial-test.log res://scenes/station_trial.tscn -- --station-trial-test --ship-life-new
```

Use the station flag alone; `--ship-life-test` starts the separate legacy combined suite. Station test/capture saves are redirected to `/tmp/station-integration-*` or `/tmp/station-capture-*`. Tests check initial orbital placement, physical terminal targeting, floor/door clearance, walking and carrying through the ramp, cargo loading, services, real flight/arrival, delivery payment and save isolation.

Validated 2026-10-06: **63/63 station integration checks passed**. The original combined build also passed fresh **170/170 integration and 19/19 actual-flight checks**. Blender source geometry passed **60/60** after the imported-floor correction. Five actual Godot views were visually inspected. Automated lifecycle tests mix physical input/walking with controller fixture calls; these results do not claim every step was played manually.

Capture actual rendered Godot views:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --log-file /tmp/station-trial-capture.log res://scenes/station_trial.tscn -- --station-trial-capture --ship-life-new
```

This writes `/tmp/station-trial-hangar.png`, `/tmp/station-trial-dispatch.png`, `/tmp/station-trial-loading.png`, `/tmp/station-trial-terminal.png`, and `/tmp/station-trial-exterior.png`, then exits. It also logs warmed static-camera frame-time diagnostics; these are not a full gameplay benchmark. The ordinary launcher is the interactive playtest.

## Implementation ownership

- `station_trial.gd` extends the combined controller: dock factory, service bindings, door simulation, separate save paths, guide and test entry points.
- `station_hangar.gd` imports the canonical room, binds six CRTs, floor grids, simple colliders, lights and door interlocks.
- `station_trial_flight.gd` bridges cockpit flight to the new runtime; `station_frame()` and `nearby_station_id()` provide the physical station transform.
- `station_trial_flight_state.gd` overrides this bay's heading, hold/entry/descent, departure gate and swept hull clearance. Its `_init()` must call the inherited initializer to establish the starting orbital position and velocity.
- `station_trial_system_visuals.gd` keeps the existing celestial system and replaces station art, with a shared distant mesh and one nearby detailed station.
- `assets/stations/industrial_keel/` contains the three production GLBs and `bindings.json`; `art/station_kit_v1/export_game.py` rebuilds them from the approved editable Blender file.

See [SHIP_LIFE_TEST.md](SHIP_LIFE_TEST.md) for all unchanged living/contract controls, [CARGO.md](CARGO.md) for packing rules, and the [station art guide](../art/station_kit_v1/README.md) for source geometry.
