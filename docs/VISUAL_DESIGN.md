# Visual design: every surface has a job

The game's visual language is compact cassette futurism: practical hardware, enclosed machinery, modular computers, and visible maintenance access. The user's references are the working spacecraft of Alien and the dense equipment environments of Observer and Routine. They inform the hardware and spatial design; the game's tone remains cozy and nonviolent.

## Rules for every room

- Size the room around its activities, furniture, equipment, and necessary clearance. Avoid oversized rooms with disconnected props.
- Give each wall a purpose: controls, storage, machinery, ventilation, distribution, structural framing, a window, or access to something behind it.
- Keep empty volume only where it serves sightlines, circulation, opening doors, handling cargo, or servicing equipment.
- Design assemblies as connected hardware. Desks have supports, racks mount to rails, and cables or ducts connect related systems.
- Align components on shared mounting grids. Labels, instruments, handles, and support rails belong to the same assembly.
- Use readable hardware detail rather than arbitrary clutter: replaceable modules, cartridge slots, fuse banks, isolation switches, filters, latches, and service covers.
- Preserve a hierarchy of controls. Frequently used information is close to the user; secondary controls require only a small turn; maintenance equipment lives outside the primary operating position.
- Keep the geometry achievable in the established Godot style: block-built forms, matte cream and grey housings, orange accents, green and amber CRT graphics, warm practical lighting.

## Longhaul cockpit application

The approved U-shaped console and seated display positions are the fixed reference. The cabin shell now fits around that console, approximately 3.1 m clear width and 2.38 m clear ceiling. The operating compartment runs from the rear entry bulkhead to the windshield; a short equipment-lined passage connects it to the hab.

The console connects to the side service plinths. Navigation, docking, and fuel remain in the forward view. Throttles, keypad, communications, and drive diagnostics sit along the console arms. Walls carry inertial-navigation electronics, air regulation, circuit protection, cartridges, and isolation controls. The rear bulkhead carries scrubber and backup-power service modules. Ceiling space carries power distribution, cable trays, ducting, service covers, and lights.

The narrowed exterior matches the smaller cabin. The walkable preview still uses illustrative equipment and display values; these modules are not yet connected to simulation systems.

## Longhaul hab application

The living cabin is approximately 3.84 m clear width, 5 m long, and 2.4 m high. A continuous center aisle links the cockpit and service rooms. The shell, windows, floor, ceiling, and exterior belt follow the narrower cabin rather than surrounding it with unused volume.

The port wall holds a full-length bunk with under-bed drawers, shallow overhead lockers, a window, and a switched reading light. Its footboard also houses the personal terminal, with an accessible service panel behind the screen. A dining bench, secured shelf, and wall-hinged table use the remaining port space. The table folds up without occupying the center aisle. Opposite, the galley combines a sink, two heating plates, coffee unit, water filters, extractor, food lockers, and under-counter storage. Refrigeration and personal storage fill the aft starboard wall. Air and water service panels fill the door-side bulkheads; ducts, cable trays, and practical lights fill the ceiling.

Aim at the reading-light switch, bunk drawer, table, or dining bench and press F. While seated, T folds/lowers the table and F returns to the aisle. Moving furniture checks the player's clearance before operating. Food preparation, sleep, and survival effects remain part of the separate gameplay slice; this pass demonstrates room design and physical usability.

Run `res://scenes/longhaul_preview.tscn -- --longhaul-test` for input-driven walking, cockpit-seat regression checks, and hab furniture/clearance checks. The desktop launcher uses Forward+ lighting.

## Longhaul service module application

The washroom and airlock share a 3 m long module with approximately 5.24 m clear width and a 2.4 m ceiling. The center passage is approximately 1.32 m wide between partitions. Each side doorway is 1.16 m wide and uses paired sliding leaves that retract into the fixed wall wings. The narrower hull, floor, roof, and outer hatch replace the original oversized service shell.

The port wet room has a flush shower deck, vacuum toilet, basin, mirror, hygiene and linen lockers, towel rail, water recovery equipment, service covers, plumbing, and ventilation. Standing areas serve each fixture without blocking the entrance. The starboard airlock has a restrained pressure suit and gear lockers forward, scrubber/filter access and a pressure console aft, and a sealed outer hatch aligned with the exterior docking collar. Equipment leaves the center free for turning and dressing. Corridor walls contain water and power distribution; ceiling ducts, cable routes, vents, and practical lights connect the rooms.

F operates the fixed door controls on either side, the shower, basin tap, and airlock seal-check button. Doors refuse to close on an occupied doorway and reopen if someone enters during closing. A brief seal check requires the inner hatch to be closed, holds it closed during the check, then reports completion. The outer hatch stays sealed in this design study; the pressure display and water are local demonstrations, not connected to flight or survival simulation. Input-driven service checks run after the hab checks in the full Longhaul tour.

## Cargo, engineering, and loading application

The aft rooms retain their 6 m hull width because it accommodates the machinery, racks, and freight route. Cargo spans z=-1 to 7; engineering spans z=7 to 11.1. The ceiling is 2.8 m high. A 2.6 m marked handling lane serves the cargo racks and receiving berths, with the forward workstation beside the narrower service entrance. Engineering keeps at least 2.8 m clear between the machinery. The connecting bulkhead now has a 2.6 m opening, and the ramp hatch is 2.8 m wide. The service-module entrance retains its narrower, correctly aligned opening. No cabinets, working covers, or door pockets intrude into the main freight route.

Cargo has fitted numbered racks with sixteen restrained freight cases, visible attachment rails and straps, two receiving berths, a manifest workstation, restraint storage, loading-power panels, cable trays, ducts, and practical lights. The forward rack is set back to leave a usable standing bay directly in front of the manifest. A separate hand case can be released, lifted, carried along the ship and ramp, transferred into either berth, and secured again. The manifest and physical clamps reflect its location and restraint state. Carried cargo has a matching player collision shape plus turning-clearance checks; it cannot be placed arbitrarily through walls. The walkthrough begins at the cargo entrance, facing aft.

Engineering groups hardware by task: coolant pump, filters and manifolds to port; diagnostics, auxiliary battery cassettes, tools, and spares to starboard. Pipes and distribution trays connect the fitted machinery. P-01 begins with reduced flow. F operates the diagnostic computer, isolation lever, retracting service cover, and three bypass fuses. The repair sequence is isolate, open, match the marked 1 / 0 / 1 pattern, close, restore. The live display reports a temporary bypass at 82% flow and recommends a station overhaul. A marked fault-test control resets the local demonstration. Access to the live circuit and restoration with an open cover are blocked.

The loading hatch uses paired sliding leaves in the aft bulkhead, with fixed controls inside and outside. It starts open, refuses to close over the player or carried case, and reopens if the doorway becomes occupied during closing. The fixed ramp remains walkable in both directions, with aligned surface strips and lighting. These cargo and engineering interactions are local to the walkable design study; the economic, flight, and survival simulation remains separate.

`--longhaul-test` additionally drives the cargo transfer, loaded ramp round trip, complete temporary repair/reset sequence, loading hatch and obstruction checks, then returns to the hab using normal walking and F input.

## Review each room in Godot

Inspect the normal working view, both side views, the entry, the rear wall, and the ceiling. Check that the floor plan supports the intended activity, screens remain readable, equipment does not float or overlap, and the player can enter and leave safely. Test at the actual game window size.


## Approved cockpit flight requirements

The playable flight scene now connects the approved detailed Longhaul interior to flight. See `FLIGHT.md` for the implemented loop, controls, validation, and remaining simulation boundaries. The independent design study and earlier economic life slice remain available.

All flight preparation and planning must happen on the physical cockpit computer terminals through command-line interfaces. Route planning, navigation entry, engine setup, and ATC each belong to the appropriate terminal. Guidance stays on cockpit displays. The flight scene implements CHART, NAV, FUEL, ENGINE, and COMMS command lines with a close physical view for typing.

- Short departure checklist: power engines, set fuel mixture, plot course, obtain an ATC takeoff code, close cargo hatch, and raise the ramp. The design study keeps its fixed ramp; the flight scene has a folding, powered ramp.
- Momentum-based flight: releasing thrust preserves motion, the pilot brakes manually, and a separate key stops rotation only.
- Select a destination on the route computer, obtain calculated coordinates and burn information, then enter the required values into the navigation computer. Begin with calculated routes rather than freehand orbital planning.
- Guidance tells the player where to point and what velocity to achieve. The player manually establishes the trajectory; the computer then confirms that it is safe to leave the controls. Matching orientation alone is insufficient: travel direction and speed must also agree with the route.
- Fuel planning includes departure, corrections, arrival braking, and reserve. Distinguish burn rate from total fuel required. The user wants fuel information to be entered as part of the planning ritual.
- Gravity-assisted routes are a desired fuel-saving option. Their orbital math belongs to the route calculator; detailed simulation scope remains to be decided.
- The longest normal journey should take at most roughly 30 minutes of actual player time aboard the ship, not 30 in-game minutes. Sleep and time acceleration can shorten the wait. There are no delivery deadlines, inspections, or violence.
- Coast time supports food, drink, hygiene, sleep, cargo checks, and temporary repairs. Arrival returns to manual flying and docking.

- Provide advance maneuver warnings so the player has time to return to the cockpit.
- Stop sleep and time acceleration before a required burn, leaving time to prepare and take the controls.
- Allow route recalculation and recovery if the player misses a burn.
- Keep the experience cozy, with no delivery deadlines or punitive scheduling.

These requirements are implemented in the flight scene. Gravity assists remain a later extension; current routes use a central gravity field and moving station intercepts.

## Launch and validation snapshot

The repository root includes macOS launchers for the original hab study, the separate life slice, and the detailed Longhaul walkthrough. They expect Godot at `/Applications/Godot.app/Contents/MacOS/Godot`; other platforms can open the corresponding scenes directly in Godot. Generated ship concepts are archived in `docs/ship-concepts`.

The latest Longhaul tour passed its walking and cockpit checks plus 48 hab, 73 service, and 100 aft checks. The life slice previously passed its 51-check suite. The original game scene is retained; the default startup is now the flight scene. The new flight scene has its own tests, documented in `FLIGHT.md`.
