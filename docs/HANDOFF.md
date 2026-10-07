# Current project handoff

Updated 2026-10-06. Read this first when resuming; then read the guide for the affected system and inspect its implementation. This is the repository handoff. The workspace-parent HANDOFF.md describes the older Claude prototype and is historical, not current project state.

## Where the project stands

Godot 4.7.2, GDScript, macOS playtesting. Repository: https://github.com/spicymahi/space-trucking. Main is the working branch. Current ship visuals include imported Blender Longhaul assets; the old handoff’s code-only-art description is obsolete.

Setting: Aurel, a ringed gas giant, eight moons, fifteen stations. Cozy cassette futurism, ship as home, no violence or delivery deadlines. User may redesign the ship later; preserve gameplay independently of the hull/art.

The user considers the core gameplay loops complete after playtesting. Flight, map, cargo, survival and daily ship care are implemented together in the combined ship-life session. This is the current integrated gameplay baseline; balance, production polish and future content remain separate work. The normal project default still opens standalone flight with its older one-case freight and survival behavior. Do not switch entry points or migrate saves implicitly.

Latest work: the user approved the Blender industrial-keel station and shared hangar, then requested playable integration. **Test Station.command** opens `scenes/station_trial.tscn`, a derived full-gameplay session with the imported hangar, real service screens, cargo pads, walking collision and pressure-door/docking control. Read [STATION_TEST.md](STATION_TEST.md) first for this build. It uses independent `station_trial_v1.json` / `station_trial_departure_v1.json` saves. All fifteen locations provisionally share the industrial exterior; station industries/economy are unchanged. This does not replace the older entry points or saves.

Documentation audit completed 2026-10-06 against source at `57296b8`: [GAMEPLAY.md](GAMEPLAY.md) indexes all loops, accepted scope and deferred ideas; [CARGO.md](CARGO.md) documents the complete freight/economy implementation; [DEVELOPMENT.md](DEVELOPMENT.md) maps ownership, saves, tuning, validation and continuation. This audit changes documentation only; the test counts below are prior recorded runs.

## Entry points and system guides

| System | Entry point / guide | Main implementation |
| --- | --- | --- |
| Normal flight | `Fly Longhaul.command`, `scenes/longhaul_flight.tscn`, [FLIGHT.md](FLIGHT.md) | `scripts/longhaul_flight.gd`, `longhaul_flight_state.gd`, `longhaul_flight_sheet.gd` |
| Aurel map/world | [AUREL_SYSTEM.md](AUREL_SYSTEM.md) | `scripts/longhaul_system.gd`, `longhaul_system_visuals.gd` |
| Approved cargo trial | `Test Cargo.command`, `scenes/cargo_trial.tscn`, [CARGO.md](CARGO.md), [isolated trial](../README.md#cargo-loop-test) | `scripts/cargo_trial.gd`, `cargo_trial_packing.gd`, `cargo_trial_economy.gd`, `cargo_trial_visuals.gd` |
| Combined cargo/flight/survival | `Test Ship Life.command`, `scenes/ship_life_trial.tscn`, [SHIP_LIFE_TEST.md](SHIP_LIFE_TEST.md), [SURVIVAL_DESIGN.md](SURVIVAL_DESIGN.md) | `ship_life_trial.gd` controller/save/UI, `ship_life_flight.gd` bridge, `ship_life_state.gd`, `ship_life_economy.gd`, `ship_life_visuals.gd` |
| Blender station with all loops | `Test Station.command`, `scenes/station_trial.tscn`, [STATION_TEST.md](STATION_TEST.md) | `station_trial.gd`, `station_hangar.gd`, `station_trial_flight.gd`, `station_trial_flight_state.gd`, `station_trial_system_visuals.gd` |
| Blender asset integration | [v3 art README](../art/longhaul_v3/README.md) | `scripts/longhaul_blender_assets.gd` |

The older `LIFE_SLICE.md` documents a separate prototype, not the newly agreed survival loop.

Latest survival refinement: dining seats use the physical bench-cushion marker, not an aisle offset. Hab printing produces a carried sheet (`ship_life_paper.gd`): F collect, H stow/retrieve (J alias), Tab inspect held paper, F at galley recycling bin to discard (Delete/Backspace shortcuts). Hands are empty by default; cargo gun is equipped only while a box is held. Assigned checks are disclosed on paper only; Engineering reports condition and runs three-channel trim/test puzzles. Failed submissions set DEGRADED and 1.5× wear; successful retries clear calibration faults without repairing condition. Existing version-1 saves load with defaults for new paper/puzzle fields. Previous state/economy checks: 116/375 passing. Latest combined checks: 170 integration and 19 actual-flight, including independent dining furniture, physical recycling, actual keyboard dispatch, empty hands, and save migration. Rendered seat, folded/lowered desk, paper, bin, and puzzle views inspected.

Dining furniture is now connected to the combined controller: F on the bench sits without needing a meal; G stands; T folds/lowers the table while seated. From standing, F/T on an empty table controls it. Plates block folding, player clearance remains enforced, and a folded desk can be lowered while carrying a meal. Meal props/target follow the table pivot, with the meal target disabled when folded or moving. Original bunk drawer and reading-light interactions are also forwarded. The optional `hab` save dictionary stores table/drawer/light state; old version-1 saves default to a lowered table, closed drawer and lit lamp. Saving waits for furniture motion to finish. F1 and the ship-life guide document the controls.

## Cargo implementation details worth preserving

The controller owns interactions, hand-tool carrying, physical boxes, grids, terminals, contract transitions and the explicit test transfer. Packing is a pure rules model shared by the two ship racks and the pickup/delivery/staging floor grids. Economy owns station supply/demand, reservations, offers, lifecycle and payment; visuals build the dock, racks, grids and crates.

Racks: two 2×3×4 grids, 0.45 m cells, access from local low-X face. Floor areas: 4×3×4 grids, access from four sides. Support, bounds, overlap and removal rules are shared. Every staged case blocks departure, even if multiple cases share one pad. All delivered cases count toward completion, independent of how many delivery pads they occupy. Full manifests fit 48 rack cells; small manifests fit 24. Generated solutions include accessible loading order.

Cargo trial starts fresh on each launch and does not read/write normal flight progress. Test transfer skips flying and uses quoted trial fuel estimates; it is not live navigation integration. Other ship systems are scenery in this trial.

The cargo-only trial still uses its original automatic fuel advance. Combined ship life uses a derived economy with fixed fees, paid operating costs, optional once-per-contract shortfall advances and persistent service debt. Do not reintroduce free COMMS supplies or reimbursements into the combined session.

## Saves, validation, and continuation

Preserve the normal flight save at `user://longhaul_flight_v1.json`. On this Mac that is under `~/Library/Application Support/Godot/app_userdata/Space Trucking/`. Do not reset it to launch a focused trial.

From the repository directory, using `/Applications/Godot.app/Contents/MacOS/Godot`:

```sh
Godot --headless --path . --log-file /tmp/cargo-packing.log --script res://scripts/cargo_trial_packing_test.gd
Godot --headless --path . --log-file /tmp/cargo-economy.log --script res://scripts/cargo_trial_economy_test.gd
Godot --headless --path . --log-file /tmp/cargo-integration.log res://scenes/cargo_trial.tscn --fixed-fps 60 -- --cargo-trial-test
```

Replace `Godot` with the executable path above unless it is on PATH. Latest cargo validation: 47 packing assertions (including 600 generated manifests), 108 controller/integration assertions; economy’s last run passed 446 assertions. Integration covers real aim/F interactions, walking and carrying through the ship, stacking, both contract types, payment once, and normal-save preservation. Some lifecycle fixture steps intentionally call controller methods directly; this is not exclusively an input-driven test.

Pre-combined cargo baseline: `dcf0a57` added stackable floor areas; `05add28` introduced the original cargo trial. Both were pushed to main before the combined ship-life implementation. These are historical cargo reference points, not the latest gameplay revision; consult `git log` for the current HEAD.

The core-loop milestone is complete according to user playtesting. Future work should follow the next user-selected feature or polish task; do not infer a new gameplay redesign from older proposals. The normal default flight scene remains separate. User feedback slowed the clock 18×: one real hour is one game day, with five-minute display steps. The same flight solver now gives local starting jobs below three game hours and distant single-leg estimates around 11.5 hours. Historical multi-day trip targets are superseded for this pacing test; actual flight durations remain unchanged. Existing saves preserve progress and accepted fees, refresh future ETAs, and expire unsold cached quotes.

Combined sessions save to `user://ship_life_v1.json` and `user://ship_life_departure_v1.json`; the old flight save is untouched. Tests redirect all combined user save writes to `/tmp`. The new controller owns the shared clock, advances market and survival by actual simulated time, and calls `economy.finish_leg()` only on real docking. The prepared-cruise option skips checklist/manual departure for testing but still runs real transit, braking, and autodocking.

Read the full approved design and test guide before changing these systems; do not treat older prototype behavior as a requirement. Keep this handoff and the affected system guide updated with entry points, state ownership, behavior changes, migrations, checks actually run, and outstanding work. Record new agreed decisions as planned until implemented. Documentation supports resumption but does not replace reading the relevant current code.

## Current art direction work

Current 2026-10-06 result: user retained three exterior families (freight terminal, industrial keel, compact service port), approved the industrial keel and reusable hangar in Blender, and requested Godot integration. [The editable model and review views](../art/station_kit_v1/README.md) remain at `art/station_kit_v1/industrial_keel_and_hangar.blend`; `Review Station in Blender.command` opens them. The production GLBs are now in `assets/stations/industrial_keel/`, with a reproducible exporter and Godot binding manifest. The 28×52×10 m room and 18×9 m opening retain actual Longhaul scale. The floor is −1.315 m relative to the ship root; the test ramp angle matches that height. Latest Blender validation passed 60/60 geometry checks after the imported-floor correction; this supersedes the original 59-check review.

The integrated station uses five live counter CRTs, a berth pedestal, 24 stackable floor grids and shared cargo/survival/economy logic. Four door leaves open in six seconds; COMMS `depart` requests opening, then a second `depart` releases the berth. Lift approximately 2 m with Space, brake lift with Ctrl, and reverse out with S. Arrival is nose-first along −Z, hovering through the opening before descending. The station remains in its own orbital frame; nearest-port detail remains visible after NAV engagement until its 1800 m detail cutoff. BAY 02 is closed visual art. Conservative swept hull bounds protect major structures and stop contact without damage; walking has separate simple colliders. Test and capture flags redirect save writes to `/tmp`.

Validated 2026-10-06: **63/63 station integration checks**, plus fresh reruns of **170/170 original combined checks and 19/19 original actual-flight checks**, all successful. The station suite covers physical service targeting, walking/carrying, loaded departure/door interlocks, actual transfer and nose-first landing, unloading/payment and save preservation. Five actual Godot views (hangar, dispatch, loading, terminal and exterior) were captured and visually inspected. Warm static views at 1280×800 on the M3 Pro/Mobile renderer measured approximately 119 FPS; that is a limited diagnostic, not an end-to-end performance guarantee.

The paragraphs below retain the concept exploration history; the approved selections and Blender result above supersede older pending-selection statements.

Hangar concept exploration has begun. The preferred reference is the compact remote-outpost bay with a dispatch booth and separate pickup/delivery areas. User explicitly removed the cream/orange-only color rule: restrained vibrant red, blue and other industrial palettes are allowed while preserving cassette futurism. [Three color variations and exact prompts](station-concepts/2026-10-06/hangar-colors/README.md) are saved; no final color or station shell is approved. The original request for five compatible station exterior concepts remains outstanding after the user redirected the review to hangar variations. No gameplay/assets have been replaced.

The user subsequently favored red and requested an exterior using Station Inspo. [One cream/red spindle-station exterior](station-concepts/2026-10-06/red-station/README.md) is now saved with its prompt: an attached rectangular Bay 05 hangar, tank spine, ring and radiator booms. It is concept art awaiting review, not an implemented or dimensionally tested asset.

Latest station direction: user rejected the red spindle exterior as unrealistic and instructed us not to use Station Inspo for the new pass. [Five fresh exterior alternatives](station-concepts/2026-10-06/exteriors-v2/README.md) are saved, with varied palettes and full-depth hangar structures. The rejected spindle is historical only; no new exterior is approved or implemented. The original five-exterior request is now fulfilled by this replacement set.
