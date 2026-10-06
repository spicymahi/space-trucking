# Longhaul — cockpit flight and ship life

The default scene is `scenes/longhaul_flight.tscn`. On macOS, double-click `Fly Longhaul.command`. The detailed ship now has printed flight paperwork, manual station flying, and automatic transfers between stations. The earlier economy prototype and independent room study retain their own launchers.

## Cockpit layout

| Screen | Function |
| --- | --- |
| Forward left — CHART | Station directory, route calculation, route-sheet printer, live journey map |
| Forward middle — NAV | Manual coordinate/fuel entry, automatic transfer, manual takeover |
| Forward right — CHECKLIST | Live departure requirements, printed command checklist, hatch/ramp controls |
| Left console arm — COMMS | Takeoff and docking clearance, takeoff code, berth release/capture, station services |
| Right console arm — ENGINE | Independent `port on/off` and `starboard on/off`, live ASCII engine diagram |
| Upper left — RADAR | ASCII station target reticle, horizontal/vertical offsets, fore/aft cue, docking guidance |
| Upper middle — VELOCITY | Large station-relative velocities along the ship's right/left, up/down, and forward/back axes |
| Upper right — DISTANCE | Only the selected station and its current distance; value stays blank until NAV loads a destination |

Look at a screen and press **F** to lean in. **Enter** runs a command; **Up/Down** recalls commands; **Escape** returns to the pilot view. `go <role>` moves the view to a screen assigned that role. `help` and `commands` show a static command reference. There is no next-step help tutorial.

Every physical cockpit screen supports `display <role>`, including `display NAV`. Names are case-insensitive. The available roles are `chart`, `nav`, `checklist`, `fuel`, `engine`, `comms`, `map`, `distance`, `velocity`, and `radar`. The current role name remains visible, and assignments are saved with the flight. For example, `display FUEL` replaces the active screen's display with fuel remaining, burn, spare fuel, and coolant status. This changes the screen's function without switching off navigation.

RADAR plots the selected station against a central aiming reticle, with signed horizontal and vertical offsets and an explicit indication when the target is behind the ship. Its normal view enlarges range, offsets, closing speed, and heading; press F to see the detailed docking instrument. The upper-left and upper-right monitors sit closer, angle toward the pilot, and have larger screens. VELOCITY measures motion relative to that station in ship axes: sideways, vertical, and forward/backward. Use the radar to line up the station and the velocity display to remove sideways drift and control closing speed. The journey map remains on CHART; a dedicated MAP display is also available.

## Printed departure checklist

Docked launches open the CHECKLIST computer. Type `print` for a retained paper checklist. The live screen shows every departure requirement and marks completed items. Printing is optional for the interlock; it gives the player a physical reference rather than advancing a tutorial.

1. **ENGINE:** `port on`, then `starboard on`. Both engines must be on. The ASCII diagram reflects each switch and each engine contributes to actual thrust. Fuel mixture is automatic and has no player command.
2. **CHART:** `stations`, then `plot tharsis direct` (or another station ID, with `direct` or `economy`). Review fuel and travel estimate; `print` produces the route sheet.
3. **NAV:** manually type the exact commands printed on that sheet: `coords <x> <y> <z>`, `burn <kg/s>`, `reserve <kg>`, then `load`. Coordinates are in kilometres, including minus signs. All values are validated. The destination meter becomes active when the route is loaded.
4. **COMMS:** `request`, then `code <the code ATC returned>`. The code has no expiry.
5. **CHECKLIST:** `hatch close`, wait for sealing, then `ramp raise` and wait for movement to finish. Secure cargo clamps in the hold. `status` shows live readiness, including machinery and sufficient fuel.
6. **COMMS:** `depart`. Manually exit through the green departure markers. After a nose-first landing, use **S** to back out of the berth; an outward-facing ship uses **W**. The release message tells you which way to thrust. Beyond 300 metres in the corridor, NAV reports safe clearance. The outer 1 km station zone also allows engagement after a wider manual departure.
7. **NAV:** `engage`. The ship aligns, accelerates, corrects the trajectory, and brakes automatically near the destination. It confirms that it is safe to leave the controls.
8. Before arrival, sleep and accelerated time end automatically. NAV completes braking and holds outside the station. At **COMMS** or **NAV**, `approach` assigns berth K-01 automatically. Use `manual` before flying the final approach yourself, or use `autodock` / `auto dock` within 1 km and below 15 m/s relative speed.

**Spare fuel** is the reserve: 200 kg kept aside for docking and unexpected corrections. The sheet distinguishes burn rate (kg per second), estimated trip consumption (kg), and spare fuel (kg). The command remains `reserve 200`, printed explicitly on the route sheet. Fuel estimates include departure/arrival burns and a handling allowance.

Preparation holds the simulation clock while docked. There is no ticking launch window, delivery deadline, inspection, or punitive scheduling. Cargo mass or coolant changes require an updated route estimate; turning engines on and off does not change the planned fuel mixture.

## Paper handling

A rigid, full-size sheet advances through the printer slot in short motor steps, with printer sound and an output tray. Printing briefly gives a view of the machine. At feed completion the sheet is collected into the paper rack and leaves the tray, so there is no duplicate page left behind. The printer finishes one sheet before accepting another job. Printed text is a snapshot: choosing another destination does not rewrite old paper.

Up to 12 sheets stay in the cockpit paper rack, including both the checklist and route sheets. Discarding paper does not erase a loaded route. A full rack asks you to discard sheets instead of silently removing old ones.

At a terminal, **Tab** pins or stows the selected sheet beside that screen. **Shift+Tab** selects the next sheet, and **Delete** discards a visible sheet. Outside terminals, **P** opens/stows a larger readable copy. Stow the full-page view before flying or walking. These keys are shown while reading; letters typed into a terminal stay CLI input. The optional compatibility commands `papers`, `paper <id>`, `paper hide`, `discard <id>`, and `discard all` remain available, but paper handling needs no CLI command.

## Manual flight and automatic navigation

| Control | Action |
| --- | --- |
| W / S | Forward / reverse thrust |
| A / D | Left / right translation |
| Space / Control | Up / down translation |
| Arrow keys | Pitch and yaw |
| Q / E | Roll |
| X (hold) | Stop rotation without stopping translation |
| Shift (hold) | Fine thrust and finer turning |
| Mouse | Look around the cockpit |
| F | Use a screen or leave the seat when docked, NAV is engaged, or arrival hold is active |
| P | Read/stow paper |
| Tab | Pin/stow paper beside the active terminal |
| Shift+Tab | Select the next sheet |
| Delete | Discard the visible sheet |
| Escape | Leave terminal view; otherwise pause/resume |

Manual flight preserves momentum and uses real fuel. NAV applies the same six-axis acceleration/fuel model; it does not teleport the ship between stations. The route solver tracks moving stations and accounts for gravity. Delayed departures are rebased when NAV engages, so slow preparation does not invalidate a trip.

NAV remains engaged when the player sits, stands, opens a terminal, or presses flight controls. Type `manual` at any terminal to take over automatic transfer, arrival hold, or docking assistance; momentum is preserved. Propulsion faults such as lost engines, coolant, or fuel can still interrupt navigation. `recalc` computes a new transfer from the current physical state and re-engages NAV when fuel allows. Ordinary automatic corrections need no repeated coordinate typing. Initial destination selection still requires manual transcription.

## Life aboard and sleep

Once NAV is engaged, stand, eat, drink, wash, inspect cargo, and perform the existing coolant repair puzzle. Food, water, hygiene and rest decline gently. Supplies are finite; station services restock them. Coolant condition affects propulsion.

NAV `warp 5` or `warp 20` speeds up automatic travel; `warp 1` restores normal time. The bunk uses 20x time and restores rest. Sleep and accelerated time stop at least 90 seconds before the planned arrival braking point, leaving more than 90 seconds before actual berth arrival. The player is forced out of the bunk and notified. Sleeping or accelerating time again inside this warning window is blocked. NAV remains engaged and handles the arrival burn. Propulsion loss also wakes the sleeper; F can wake them early.

At arrival NAV brakes to a holding point about 600 m outside the berth and matches the moving station. The ship maintains that position until the player types `manual` or requests docking assistance. There is no arrival deadline.

Tested outbound trips, including assisted berth capture, take approximately 8–9 minutes to Tharsis, 14–17 to Kepler, and 22–26 to Helios at normal speed with degraded-but-operational coolant. Deliberate manual delays can extend a trip. Sleeping and accelerated time shorten the real wait.

## Approach, docking, recovery and saves

At COMMS or NAV, `approach` grants arrival clearance and automatically assigns berth K-01; no separate berth selection is needed. This also works when the ship reaches the station manually or from a flight saved under an older navigation phase. For manual capture, type `manual`, reach within 20 m, below 2 m/s relative speed, nose-first berth heading 180 / pitch 000, and stop rotation; then use `dock`.

Optional `autodock`, `auto dock`, and `auto-dock` are equivalent commands. They require `approach` clearance, range under 1 km, relative speed under 15 m/s, both engines, coolant, and maneuver fuel. Assistance turns to line up before advancing, flies into the open end of the pad nose-first, and keeps that heading when the berth captures the ship. If assistance starts beside or behind the pad, it first moves to the entrance; a rear approach clears the station spine overhead. It stays engaged until capture, a propulsion fault, or an explicit `manual` command. The station radar and velocity screens provide alignment and drift information for either approach method.

After docking, use CHECKLIST `ramp lower`, then `hatch open` to walk onto the berth. Both engines can be switched off independently at ENGINE. COMMS `refuel`, `service`, and `rescue` remain nonpunitive prototype services; the economy is still separate.

The game autosaves once a minute when moving hardware and carried cargo permit it. COMMS `save` and `load` provide manual control. Saves include route, actual position/velocity, automatic navigation/hold state, engines, screen assignments, papers, trail, needs, fuel, cargo, and repairs. Loads resume at normal time and awake. Docking approach stages and the parked orientation also survive save/load. Earlier flight saves migrate without resetting the journey; NAV can take over an existing manual transfer after station clearance.

## Simulation boundaries and validation

The compressed system uses central gravity, moving Keplerian stations, numerical intercept solving, and six-axis thrust. Multiple moving gravitational bodies and gravity-assist flybys remain future work. The fictional ship clock advances one hour per normal real minute. Station exteriors remain functional prototypes. Contracts, payments, paid cargo handlers, and shops remain in the separate life slice.

The updated suite passes 133 flight/ship checks, 53 paper/control checks, and 18 display checks. `--flight-test` covers full journeys to every station in both route modes, direct return trips, fuel/time budgets, manual momentum and nose-first docking, approach alignment and side/rear entry, docking save compatibility, engine loss, clearance and hardware gates, automatic arrival hold, early sleep wakeup, explicit manual takeover/recalculation, JSON save migration, printed commands, paper disposal, physical terminal placement, page/viewport bounds, walking and life interactions. Cockpit checks cover station radar, relative velocity, screen reassignment, and paper hotkeys. Forward+ captures support visual review of the actual cockpit screens and printer.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --log-file /tmp/longhaul-flight-test.log res://scenes/longhaul_flight.tscn -- --flight-test
```
