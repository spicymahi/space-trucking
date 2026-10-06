# Longhaul — cockpit flight and ship life

The default scene is `scenes/longhaul_flight.tscn`. On macOS, double-click `Fly Longhaul.command`. The detailed ship now has printed flight paperwork, manual station flying, and automatic transfers between stations. The earlier economy prototype and independent room study retain their own launchers.

## Cockpit layout

| Screen | Function |
| --- | --- |
| Forward left — CHART | Station directory, route calculation, route-sheet printer |
| Forward middle — NAV | Manual coordinate/fuel entry, automatic transfer, manual takeover |
| Forward right — CHECKLIST | Live departure requirements, printed command checklist, hatch/ramp controls |
| Left console arm — COMMS | Takeoff and docking clearance, takeoff code, berth release/capture, station services |
| Right console arm — ENGINE | Independent `port on/off` and `starboard on/off`, live ASCII engine diagram |
| Upper left — FUEL | Fuel remaining, current burn, spare fuel and coolant status |
| Upper middle — MAP | Live ship/station positions, flown trail, planned transfer, automatic approach zoom |
| Upper right — DISTANCE | Only the selected station and its current distance; value stays blank until NAV loads a destination |

Look at a screen and press **F** to lean in. **Enter** runs a command; **Up/Down** recalls commands; **Escape** returns to the pilot view. `go checklist`, `go chart`, `go nav`, `go engine`, `go comms`, `go fuel`, `go map`, and `go distance` move the view to the corresponding physical screen. `help` and `commands` show a static command reference. There is no next-step help tutorial.

## Printed departure checklist

Docked launches open the CHECKLIST computer. Type `print` for a retained paper checklist. The live screen shows every departure requirement and marks completed items. Printing is optional for the interlock; it gives the player a physical reference rather than advancing a tutorial.

1. **ENGINE:** `port on`, then `starboard on`. Both engines must be on. The ASCII diagram reflects each switch and each engine contributes to actual thrust. Fuel mixture is automatic and has no player command.
2. **CHART:** `stations`, then `plot tharsis direct` (or another station ID, with `direct` or `economy`). Review fuel and travel estimate; `print` produces the route sheet.
3. **NAV:** manually type the exact commands printed on that sheet: `coords <x> <y> <z>`, `burn <kg/s>`, `reserve <kg>`, then `load`. Coordinates are in kilometres, including minus signs. All values are validated. The destination meter becomes active when the route is loaded.
4. **COMMS:** `request`, then `code <the code ATC returned>`. The code has no expiry.
5. **CHECKLIST:** `hatch close`, wait for sealing, then `ramp raise` and wait for movement to finish. Secure cargo clamps in the hold. `status` shows live readiness, including machinery and sufficient fuel.
6. **COMMS:** `depart`. Manually fly forward out of the berth, through the green departure markers. Beyond 300 metres in the corridor, NAV reports safe clearance. The outer 1 km station zone also allows engagement after a wider manual departure.
7. **NAV:** `engage`. The ship aligns, accelerates, corrects the trajectory, and brakes automatically near the destination. It confirms that it is safe to leave the controls.
8. At arrival, **COMMS:** `approach`. Fly the final approach manually or use `autodock` within 1 km and below 15 m/s relative speed.

**Spare fuel** is the reserve: 200 kg kept aside for docking and unexpected corrections. The sheet distinguishes burn rate (kg per second), estimated trip consumption (kg), and spare fuel (kg). The command remains `reserve 200`, printed explicitly on the route sheet. Fuel estimates include departure/arrival burns and a handling allowance.

Preparation holds the simulation clock while docked. There is no ticking launch window, delivery deadline, inspection, or punitive scheduling. Cargo mass or coolant changes require an updated route estimate; turning engines on and off does not change the planned fuel mixture.

## Paper handling

A rigid, full-size sheet advances through the printer slot in short motor steps, with printer sound and an output tray. Printing briefly gives a view of the machine. The printer finishes one sheet before accepting another job. Printed text is a snapshot: choosing another destination does not rewrite old paper.

Up to 12 sheets stay in the cockpit paper rack, including both the checklist and route sheets. `papers` lists them, `paper <id>` selects a sheet, `paper hide` stows it, and `discard <id>` or `discard all` recycles unwanted sheets. Discarding paper does not erase a loaded route. A full rack asks you to discard sheets instead of silently removing old ones.

At a terminal, the selected sheet appears beside the screen. Outside terminals, **P** opens/stows a larger readable copy, **Tab** selects the next sheet, and **Delete** discards it. Stow the full-page view before flying or walking. These keys are shown while reading; letters typed into a terminal stay CLI input.

## Manual flight and automatic navigation

| Control | Action |
| --- | --- |
| W / S | Forward / reverse thrust |
| A / D | Left / right translation |
| R / V | Up / down translation |
| Arrow keys | Pitch and yaw |
| Q / E | Roll |
| X (hold) | Stop rotation without stopping translation |
| Shift (hold) | Fine thrust and finer turning |
| Mouse | Look around the cockpit |
| F | Use a screen or leave the seat when docked, NAV is engaged, or arrival hold is active |
| P | Read/stow paper |
| Escape | Leave terminal view; otherwise pause/resume |

Manual flight preserves momentum and uses real fuel. NAV applies the same six-axis acceleration/fuel model; it does not teleport the ship between stations. The route solver tracks moving stations and accounts for gravity. Delayed departures are rebased when NAV engages, so slow preparation does not invalidate a trip.

`manual` at NAV or manual thrust/steering input cancels automatic transfer, arrival hold, or docking assistance. Momentum is preserved. `recalc` computes a new transfer from the current physical state and re-engages NAV when fuel allows. Ordinary automatic corrections need no repeated coordinate typing. Initial destination selection still requires manual transcription.

## Life aboard and sleep

Once NAV is engaged, stand, eat, drink, wash, inspect cargo, and perform the existing coolant repair puzzle. Food, water, hygiene and rest decline gently. Supplies are finite; station services restock them. Coolant condition affects propulsion.

NAV `warp 5` or `warp 20` speeds up automatic travel; `warp 1` restores normal time. The bunk uses 20x time and restores rest. It continues through automatic burns. Advance maneuver announcements remain, but they do not require the player to wake or return to the controls. Sleep ends at station arrival. Propulsion loss interrupts navigation and wakes the sleeper; F can also wake them early.

At arrival NAV brakes to a holding point about 600 m outside the berth, matches the moving station, restores normal time, and wakes the player. The ship maintains that position until the player takes over or requests docking assistance. There is no arrival deadline.

Tested outbound trips, including assisted berth capture, take approximately 8–9 minutes to Tharsis, 14–17 to Kepler, and 22–26 to Helios at normal speed with degraded-but-operational coolant. Deliberate manual delays can extend a trip. Sleeping and accelerated time shorten the real wait.

## Approach, docking, recovery and saves

COMMS `approach` reserves the berth. For manual capture, reach within 20 m, below 2 m/s relative speed, berth heading 000 / pitch 000, and stop rotation; then use `dock`. Optional `autodock` requires arrival clearance, range under 1 km, relative speed under 15 m/s, both engines, coolant, and maneuver fuel. It flies the remaining approach and captures the berth. Manual input cancels it immediately.

After docking, use CHECKLIST `ramp lower`, then `hatch open` to walk onto the berth. Both engines can be switched off independently at ENGINE. COMMS `refuel`, `service`, and `rescue` remain nonpunitive prototype services; the economy is still separate.

The game autosaves once a minute when moving hardware and carried cargo permit it. COMMS `save` and `load` provide manual control. Saves include route, actual position/velocity, automatic navigation/hold state, engines, papers, trail, needs, fuel, cargo, and repairs. Loads resume at normal time and awake. Earlier flight saves migrate without resetting the journey; NAV can take over an existing manual transfer after station clearance.

## Simulation boundaries and validation

The compressed system uses central gravity, moving Keplerian stations, numerical intercept solving, and six-axis thrust. Multiple moving gravitational bodies and gravity-assist flybys remain future work. The fictional ship clock advances one hour per normal real minute. Station exteriors remain functional prototypes. Contracts, payments, paid cargo handlers, and shops remain in the separate life slice.

The current flight suite passes 94 flight checks and 34 paper/interface checks. `--flight-test` covers full journeys to every station in both route modes, direct return trips, fuel/time budgets, manual momentum and docking, engine loss, clearance and hardware gates, automatic arrival hold, sleep, manual takeover/recalculation, JSON save migration, printed commands, paper disposal, physical terminal placement, page/viewport bounds, walking and life interactions. Forward+ captures verify the actual cockpit screens and printer.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --log-file /tmp/longhaul-flight-test.log res://scenes/longhaul_flight.tscn -- --flight-test
```
