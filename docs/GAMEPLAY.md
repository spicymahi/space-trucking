# Gameplay overview and documentation index

Audited against the implementation on 2026-10-06. The core flight, cargo, survival and daily ship-care loops are implemented in **Test Ship Life.command** (`scenes/ship_life_trial.tscn`). They have been playtested by the user; this is a playable integrated prototype, not a claim that production art, balance or every proposed feature is finished.

The latest visual integration is **Test Station.command** (`scenes/station_trial.tscn`): the same full loops inside the approved Blender industrial station and reusable hangar. It has separate station-trial saves and retains the original combined build. See [STATION_TEST.md](STATION_TEST.md) for the new physical door, reverse departure, nose-first landing and service-counter layout.

## The game we are making

Station layout requirement (accepted 2026-10-06): every station has at least two full-size hangars. The player's berth remains available for an unrestricted stay; a separate NPC berth supports independent arrivals, cargo work and departures. Approach paths and door control must be independent. The current station has the two physical bay volumes, but NPC berth operation and traffic are not yet implemented.

A single-player, cozy space-delivery game where the ship is home. Earn fixed fees carrying station-owned freight, prepare for the journey, fly manually near stations, let NAV handle interstation travel, and live aboard between ports. Hard-science-fiction influences inform instruments, inertia, route planning and operating costs; usability takes priority over literal scale. There is no combat, inspection loop or delivery deadline.

The setting is Aurel, a ringed gas giant with eight moons and fifteen orbital stations. Longhaul is the current player ship, with cockpit, living hab, washroom/airlock, cargo, engineering and loading areas. Compact cassette-futurist hardware, useful wall equipment, readable CRTs and safe working clearances define the visual style. A future hull redesign should preserve the gameplay independently of the artwork.

## One complete working cycle

| Stage | Player actions | Completion / next step | Detailed reference |
| --- | --- | --- | --- |
| Choose work | Accept an outbound or collection contract at the hangar CONTRACTS terminal | One active consignment; source goods and destination demand are reserved | [Cargo and economy](CARGO.md) |
| Prepare | Buy food/water, pay for fuel and sensor repairs; request an advance if essential costs exceed cash | Stores and ship readiness suit the trip; provision shortage warns rather than blocks departure | [Ship-life guide](SHIP_LIFE_TEST.md) |
| Load | Carry cases with the hand tool, rotate and stack them into the two racks; use four staging grids for rearrangement | Every case racked, staging empty, hands clear, CARGO LOCK engaged | [Packing rules](CARGO.md#packing-and-handling) |
| Depart | Print flight instructions, switch engines on, plot and transcribe route, obtain ATC code, close hatch/raise ramp, release berth | Manually clear the station, then NAV `engage` | [Cockpit guide](FLIGHT.md), with combined-session differences below |
| Travel | NAV aligns, accelerates, coasts and brakes; player can walk around | Arrival watch interrupts rest 90 active seconds before arrival braking | [Travel and rest](SHIP_LIFE_TEST.md#world-time-sleep-and-arrival) |
| Live aboard | Print/collect daily checklist, cook/eat/clean up, drink/wash glass, shower periodically, calibrate assigned sensors | Daily tasks affect rest eligibility and sensor wear | [Survival design](SURVIVAL_DESIGN.md) |
| Use the hab | Sit without eating, fold/lower the empty table, read/stow/recycle paper, use the hab inventory terminal | Furniture and held items remain part of the saved session | [Hab interactions](SHIP_LIFE_TEST.md#provisions-and-kitchen-interactions) |
| Arrive | `approach` assigns berth; use `manual` for final flying or optional `auto dock` within its limits | Nose-first docking; lower ramp/open hatch | [Docking](FLIGHT.md#approach-docking-recovery-and-saves) |
| Settle | Unlock and unload all cases onto destination DELIVERY grids; use completion terminal | Remaining fee paid once, less advances/debt; choose the next job | [Contract lifecycle](CARGO.md#contract-lifecycle) |

Collection contracts add an empty first leg to the supplier, then the same loading/travel/unloading loop back to the employer. No commodity purchase or individual speculative trading is required.

## Current build versus retained prototypes

The project default is still `scenes/longhaul_flight.tscn`. Use **Test Station.command** for all loops with the new Blender hangar, or **Test Ship Life.command** for the previously approved combined baseline. Pressing Play on the default project opens the older standalone flight build. The station trial keeps all fifteen industries and routes but provisionally shares one industrial exterior across them; it does not add new industry rules.

| Concern | Combined ship-life session | Older standalone flight / cargo trial |
| --- | --- | --- |
| Freight | Multi-case packing contracts accepted at hangar | Flight: older single-case COMMS contracts; cargo trial: same packing with test transfer |
| Money | Fixed fee, paid operating costs, optional shortfall advance | Older cargo trial automatically advances fuel money |
| Time | One game day per 60 real minutes; five-minute clock display; advances at port too | Standalone flight has its older clock and docked-preparation behavior |
| Rest / upkeep | Bunk commands, next 06:00 wake, daily sensor puzzles and paid repairs | Older needs, coolant puzzle and NAV warp/bunk acceleration |
| Pilot seat | G enters/leaves; F uses terminals | Standalone flight uses its original seat controls |
| Recovery | Paid refuel, port repair, COMMS rescue adds 150 CR debt | Original prototype services differ |
| Save | `ship_life_v1.json` plus departure checkpoint | `longhaul_flight_v1.json`; cargo-only trial starts fresh |

The shared cockpit guide documents navigation, screens, paper, map and docking. Its standalone survival, clock, service, freight and save rules do **not** override the combined session. See [SHIP_LIFE_TEST.md](SHIP_LIFE_TEST.md) for the current controls. NAV `warp`/`sleep` is redirected to the bunk in the combined session; old COMMS crew/delivery commands redirect to physical cargo handling.

## Documentation coverage

Future ship ownership and trade-ins are recorded in [SHIP_PROGRESSION.md](SHIP_PROGRESSION.md). These are deferred design notes, not implemented gameplay.

| Document | Purpose |
| --- | --- |
| [HANDOFF.md](HANDOFF.md) | First read for a new coding session: current state, entry points and continuation notes |
| [SHIP_LIFE_TEST.md](SHIP_LIFE_TEST.md) | End-to-end player walkthrough, terminal commands, kitchen, paper, sensors, rest, money and saves |
| [STATION_TEST.md](STATION_TEST.md) | Blender station launch, physical hangar/door, service layout, departure/arrival differences, isolated saves and validation commands |
| [CARGO.md](CARGO.md) | Contract/economy rules, packing, staging, locks, unloading, payment and implementation ownership |
| [FLIGHT.md](FLIGHT.md) | Cockpit controls, engine/ATC sequence, transcription, instruments, flight paper, inertia, NAV, docking |
| [AUREL_SYSTEM.md](AUREL_SYSTEM.md) | Planet/moon/station directory, schematic map commands, route geography and simulation limits |
| [SURVIVAL_DESIGN.md](SURVIVAL_DESIGN.md) | Agreed survival rules, current tuning and superseded proposals |
| [VISUAL_DESIGN.md](VISUAL_DESIGN.md) | Room philosophy, spatial layout and physical hardware design |
| [Blender pipeline](../art/longhaul_v3/README.md) | Editable source, production GLB, mechanical/display bindings and rebuild steps |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Code ownership, save format, safe continuation, tuning locations, validation and troubleshooting |
| [LIFE_SLICE.md](LIFE_SLICE.md) | Historical Kestrel prototype only |

## Scope boundaries and remaining decisions

- Background station production, demand and abstract NPC trades are implemented. Individually simulated NPC ships, schedules and a visible traffic fleet are not part of this loop; no fleet count has been committed.
- The five proposed ship designs and eventual replacement player hull are art/content work, not completed playable fleet support. Current integration uses the Blender Longhaul plus Godot-generated interaction props and displays.
- Moons are scenery/orbital anchors. Landable bases, atmospheres/weather gameplay, moon gravity affecting the ship, N-body dynamics and optimized gravity assists remain deferred.
- Cargo is manually carried; no trolley, speculative trading or paid loading crew is available in the combined session. Cases currently have rectangular grid dimensions, not arbitrary interlocking mesh shapes.
- Sensor inspection/port repair replaces the old coolant-repair loop in the combined session. It does not yet simulate individual physical ship parts failing during flight; the bridge holds legacy coolant at 0.82 and uses sensor failure as a departure gate.
- Slower time supersedes the earlier multi-day journey target. Existing flight times remain roughly 5–30 real minutes; the longest initial combined quote is around 11.5 shipboard hours. Pantry stock therefore covers multiple jobs. Further balancing is a decision, not an undocumented change to make while resuming.
- The industrial station's playable hangar is implemented in its dedicated test scene. Other station interiors, station-family artwork and NPC bay traffic remain future work. Core-loop completion does not switch the default scene, migrate saves or redesign the ship hull.

When a rule changes, update its detailed guide, this overview if scope changes, and the handoff. Keep implemented behavior, user decisions, proposals and historical behavior clearly distinguished.
