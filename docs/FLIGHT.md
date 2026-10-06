# Longhaul — cockpit flight and ship life

The default scene is `scenes/longhaul_flight.tscn`. The macOS launcher is `Fly Longhaul.command`. This is the approved detailed ship with live cockpit computers. The old economic life slice and the independent room study remain available through their own launchers.

## Your first departure

Press **F** near the pilot seat. Look at a CRT and press **F** to lean in and type. **Enter** runs a command, **Up/Down** recalls command history, and **Escape** returns to the seat view. Typing does not operate the flight controls. Each terminal supports `help`, `status`, `checklist`, and `clear`.

1. **ENGINE** — right console arm (or overhead center): `power on`.
2. **FUEL** — forward right: `mixture 2.5`, then `flow 6`.
3. **CHART** — forward left: `destinations`, then `plot tharsis direct`. `map` shows current station orbits and the calculated transfer; `route` shows the readback. `economy` chooses a slower transfer candidate.
4. **NAV** — forward center: copy the coordinates from CHART with `coords <x> <y> <z>`. They are kilometres; preserve negative signs. Enter `burn 6` and `reserve 200`, then `load`. Use the burn/reserve values actually printed by CHART if you change the setup.
5. **COMMS** — left console arm (or overhead right): `request`. Read the returned takeoff code back using `code <code>`.
6. **ENGINE**: `hatch close`, wait until sealed, then `ramp raise`. The ramp folds and raises physically; wait for completion. `checklist` identifies anything missing. Cargo clamps must also be secured.
7. **COMMS**: `depart`. The berth releases; you now control the ship.

There is no clearance expiry or delivery deadline. If setup takes long enough that the calculated moving-station intercept is out of date, replot and enter fresh navigation values. Changed fuel flow, mixture, cargo mass, or coolant condition also require a fresh departure calculation. This prevents stale fuel estimates.

## Manual flight

| Control | Action |
| --- | --- |
| W / S | Main forward / reverse thrust |
| A / D | Left / right translation |
| R / V | Up / down translation |
| Arrow keys | Pitch and yaw |
| Q / E | Roll |
| X (hold) | Stop rotation; translational velocity remains |
| Shift (hold) | Fine thrust and finer turning |
| Mouse | Look around the cockpit |
| F | Use the screen under your gaze, or leave the seat on a stable coast |
| Escape | Step back from a terminal; otherwise pause/resume |

The NAV screen shows yaw/pitch correction and remaining delta-V. Point in the indicated direction, apply thrust, and reduce thrust as the remaining velocity change approaches zero. Under 3 m/s, cut thrust, align to the coast heading, and stop rotation with X. Hold that state briefly for **Course established. Safe to leave controls.** The computer checks the actual velocity vector, attitude, absence of thrust, and angular stability. It never applies an autopilot burn.

Releasing thrust does not brake. Gravity continues to curve the trajectory. Fuel flow and available coolant affect acceleration and fuel estimates. The model uses metres, flight seconds and kilograms in a compressed local system; the ship-life clock advances one fictional hour per normal real minute. Coordinates are displayed in kilometres.

## Coast and life aboard

Press F while looking away from a CRT to leave the seat. Walk, eat at the galley heating plate, drink at the sink, wash using the existing washroom controls, inspect/move cargo, or repair the coolant circuit using the existing isolation/cover/fuse puzzle. The repair now changes available engine performance. Food, water, hygiene and rest decline gently; meals and water consume provisions.

At NAV, `warp 5` or `warp 20` speeds up a stable coast; `warp 1` restores normal time. Use the bunk with F to rest at 20x. F wakes you early. Both sleep and accelerated time stop **75 flight seconds before the arrival burn**. A chime, announcement, physical corridor repeaters, and terminal warnings call you back to the cockpit. The ship continues coasting at normal speed, so warnings are not an invisible brake or hold.

Under the automated test pilot, complete outbound trips take approximately 9–10 minutes to Tharsis, 16–18 minutes to Kepler, and 24–28 minutes to Helios, including departure, coast, braking, and berth capture. Deliberate delays or missed burns can extend a journey; there is no punitive clock. Sleeping and fast time shorten the real wait.

## Arrival and recovery

At the burn, NAV changes to arrival guidance. Point at the displayed braking vector and thrust until relative velocity is matched. It then gives approach guidance toward the berth. Request a berth with COMMS `approach`; the berth remains reserved without a deadline.

Manually approach within **20 m** and below **2 m/s relative speed**. NAV then guides the ship toward the berth heading (000 / pitch 000). Stop rotation with X and use COMMS `dock`. Berth capture attaches the ship to the station. Lower the ramp, open the hatch, and walk onto the berth if desired. A return or onward trip uses the same checklist.

If you miss a burn, NAV `recalc` calculates a recovery from your real position and velocity; it does not teleport or brake you. Read the new CHART route into NAV and perform the correction manually. COMMS `rescue` provides a nonpunitive tug recovery if fuel or approach becomes a problem. `refuel` and `service` work while docked; station supplies and servicing are free in this flight test.

## Save and resume

The game autosaves once a minute when movable hardware and carried cargo are safe to save. COMMS `save` and `load` provide manual control. Flight state, fuel, needs, route, attitude/velocity, ramp/hatch, case berth/clamps, and the engineering repair state persist. Saves resume in the pilot seat at normal time; sleep/time acceleration never resume unattended. The next launch automatically loads `user://longhaul_flight_v1.json`. The earlier life slice uses a separate file.

## Simulation boundaries

This build uses numerically integrated central gravity, Keplerian moving stations, numerical intercept solving, and manually applied six-axis thrust. Routes are calculated direct or slower economy transfers. It does not yet simulate multiple moving gravitational bodies or plan planetary gravity-assist flybys. The route calculator solves the current compact system, not a full-scale Solar System.

Station exteriors and berths remain functional prototypes. Contracts, payments, paid cargo handlers, and station shops remain in the separate life slice. Cargo and repair interactions in the detailed ship now participate in flight readiness/performance, but the economy has not been migrated. There is no combat, inspection, destructive collision failure, or delivery timer.

## Validation

The current run passes 106 checks. `--flight-test` covers command validation, departure interlocks, momentum/gravity, fuel use, rotational damping, all six outbound route choices through manual burns and docking, missed-burn recovery, warning/time-skip boundaries, survival interactions, physical terminal focus/input, working hatch/ramp, walking aboard and down the ramp, and save/load including malformed data rejection.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --log-file /tmp/longhaul-flight-test.log res://scenes/longhaul_flight.tscn -- --flight-test
```

The previous `--longhaul-test` on the design-study scene also passes: 48 hab, 73 service, and 100 aft checks, plus the walking and cockpit checks. Forward+ captures check the physical CRT and pilot views.
