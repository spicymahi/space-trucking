# Development and continuation guide

Audited 2026-10-06. Read [HANDOFF.md](HANDOFF.md), then [GAMEPLAY.md](GAMEPLAY.md) and the guide for the system being changed. This document records where behavior lives so a future session can resume without depending on chat history. Documentation is a map; inspect the current implementation before editing.

## Entry points and architecture

Godot 4.7.2, GDScript, macOS. `project.godot` currently selects the Mobile renderer and `scenes/longhaul_flight.tscn` as its main scene. Launchers live at the repository root; current combined play is **Test Ship Life.command**. Other launchers preserve standalone flight, cargo-only tests and historical room/life prototypes.

**Test Station.command** / `scenes/station_trial.tscn` is the newer Blender station integration, derived from the full combined session. It deliberately has its own save paths and keeps the original launcher/baseline intact. [STATION_TEST.md](STATION_TEST.md) contains the player guide and station validation commands.

`ship_life_trial.gd` extends `cargo_trial.gd`. Its `_create_ship()` supplies `ship_life_flight.gd`, which extends `longhaul_flight.gd` to build the existing ship/cockpit/space presentation without starting the legacy gameplay loop or loading its save. The bridge hands the combined walker/camera to the ship and disables the legacy frame/input drivers. Do not enable both controllers: that would double-advance state and dispatch inputs twice.

| System | Principal source / integration points |
| --- | --- |
| Session and input | `scripts/ship_life_trial.gd`: `_use`, `_use_life`, `_use_hab`, `_input`, `_unhandled_input`, `_update_life_visuals` |
| Shared simulation | Controller `_advance_simulation` updates flight, life and economy from actual elapsed seconds; `_process_skip` uses the same path and stops at arrival watch |
| Survival model | `scripts/ship_life_state.gd`: clock/day selection, inventory/kitchen, wear, calibration, rest eligibility, snapshot/restore |
| Market / finance | `scripts/ship_life_economy.gd`, derived from `cargo_trial_economy.gd`: fixed fees, hourly market, advance/debt, snapshot/restore |
| Cargo | `scripts/cargo_trial.gd`, `cargo_trial_packing.gd`, `cargo_trial_visuals.gd`; see [CARGO.md](CARGO.md) |
| Flight | `scripts/longhaul_flight_state.gd`: solver, thrust, phases, fuel, NAV and docking; `ship_life_flight.gd`: combined command/service overrides and `sync_hardware` |
| World and map | `scripts/longhaul_system.gd`, `longhaul_system_visuals.gd`, `longhaul_route_map.gd` |
| Terminals / flight paper | `scripts/longhaul_terminal.gd`, `longhaul_flight_sheet.gd`; combined non-cockpit terminal dispatch/history in `ship_life_trial.gd` |
| Physical daily paper | `scripts/ship_life_paper.gd`; collection/stow/inspection/disposal state in combined controller |
| Hab / fixtures | `scripts/ship_life_visuals.gd` creates active fixtures, kitchen props, printer/bin, shower; `longhaul_hab.gd` owns furniture mechanics |
| Ship mechanics / art | `longhaul_cockpit.gd`, `longhaul_service.gd`, `longhaul_loading.gd`, other `longhaul_*` room builders; `longhaul_blender_assets.gd` binds imported visuals |
| Station integration | `station_trial.gd` overrides dock construction, service mapping, doors, save paths and trial guide; `station_hangar.gd` binds imported art, live CRTs, grids, walking collision and lights |
| Station flight / art | `station_trial_flight.gd`, `station_trial_flight_state.gd`, `station_trial_system_visuals.gd`; standalone and original combined flight adapters stay unchanged |

The flight bridge derives secured cargo and cargo mass from the combined manifest, and sensor readiness from the survival model. It fixes legacy coolant at 0.82; the old coolant puzzle is not the current maintenance loop. Actual fuel use belongs to flight, not economic arrival bookkeeping. `_arrived()` advances the contracted leg only on actual docking and spawns pickup cargo only for the collection pickup transition.

## Save ownership and compatibility

On this Mac, Godot `user://` resolves beneath `~/Library/Application Support/Godot/app_userdata/Space Trucking/`.

| File | Purpose |
| --- | --- |
| `ship_life_v1.json` | Persistent combined session; normal launcher resumes it |
| `ship_life_departure_v1.json` | Initial/pre-departure recovery checkpoint; F9 uses it after an emergency-rest run end |
| `longhaul_flight_v1.json` | Independent standalone flight save; never overwrite it to test combined gameplay |
| `station_trial_v1.json` | Independent persistent Blender station session |
| `station_trial_departure_v1.json` | Station trial's initial/pre-departure recovery checkpoint |

F5 saves, F9 loads, terminals support `save`/`load`, and normal combined play attempts autosave every 45 seconds. Save explicitly before closing when recent progress matters. Saving refuses active rest or moving ramp, hatch, table or drawer. A `.tmp` file is written before rename; the success message depends on the rename result. Do not reset saves just to reopen the game. `--ship-life-new` intentionally starts a fresh combined session and subsequent saves replace its regular progress; use only when requested.

Version 1's top-level snapshot includes `life`, `economy`, `flight`, manifest and solution, rack/floor placements, parcel records and world poses, held-case size/id, cargo locks, walker/camera transforms, seating, cockpit roles/maps, daily-paper state and optional `hab` furniture state. Survival includes dishes/cooking, day/checks, sensor condition/faults and unfinished calibration, emergency count and purchase-pair flags. Economy includes reservations, receipts, debt, RNG state and hourly remainder.

`_encode`/`_decode` preserve integer dictionary keys, Vector3/Vector3i and Transform3D with tagged JSON structures (`@int`, `@dict`, `@v3`, `@v3i`, `@pose`). Economy RNG integers are stored as strings to avoid numeric precision loss. Use the existing snapshot/restore paths rather than serializing physical nodes or replacing these types with untyped JSON numbers.

Existing version-1 saves default new paper/calibration fields, and absent `hab` data means lowered table, closed drawer and light on. Restoring furniture stops pending tweens before applying final poses; an occupied table is kept lowered. Old-clock economic saves keep elapsed progress, accepted fees, wallet and debt while refreshing future route estimates and expiring unsold cached offers. The combined session does not import the standalone flight save.

Terminal browsing history and open panels are transient; screen roles/map choices and actual gameplay state persist. History navigation must not replay actions. A route sheet is a printed snapshot; the current-day daily checklist updates completion, and old-day sheets remain old until replaced.

Station tests/captures map their `user://` writes to `/tmp/station-integration-*` or `/tmp/station-capture-*`. The station controller inherits the version-1 combined snapshot format. Door fraction is transient and reconstructed from the restored flight phase; stale docked departure requests are cleared. Never copy the legacy combined save into the station trial implicitly: physical floor height and berth heading differ.

## Station coordinates and asset boundary

The flight model's `station_position()` is BAY 01's docked ship origin, preserving the orbital catalogue. `ship.station_frame(index)` converts that fixed station frame to the ship's floating local frame. The canonical floor-root offset is `(0,-1.315,0)`; station structure shifts `(27,-1.315,0)` to align its authored left bay, and the second bay is `(54,-1.315,0)`. Godot −Z is the ship nose, +Z is the entrance/departure side. The runtime and detailed exterior use `nearby_station_id()`, not NAV's reference station: NAV changes its reference at engagement while the departure port must remain visibly stationary behind the ship.

The adapter's departure preparation requests the outer door; actual release waits for full clearance. The flight state uses swept conservative bounds for ship/major-structure clearance, independent from the player's simple runtime colliders. Autodock stages are approach gate, level hover through the aperture, then descent. Keep the bay geometry, door bounds, cargo anchors, flight safety volumes and ramp angle in agreement when changing dimensions. The state initializer must call `super._init()` so the new ship starts at the station's orbital position, not world zero.

`assets/stations/industrial_keel/standard_hangar.glb` is the single canonical room; `station_structure.glb` excludes bays, and `station_distant.glb` contains the simplified exterior with both bay shells. `bindings.json` records door/screen/marker coordinates. `art/station_kit_v1/export_game.py` rebuilds these from the editable Blender model without reference ships, cameras, sample cargo or presentation animation. All fifteen locations currently share this family as test artwork; their economy and industry data are unchanged.

## Tuning and change safety

| Change | Start here / preserve |
| --- | --- |
| Clock pace / daily needs | `ship_life_state.gd` constants; economy uses the same clock rate. Keep five-minute display rounding separate from exact simulation. Review route quotes and old-save migration together |
| Food/water capacity, hygiene, wear, cooking | `ship_life_state.gd`; update guide prices/capacities and shared UI strings where applicable |
| Prices / repair / rescue | Controller FOOD_PRICE, WATER_PRICE, FUEL_PRICE, `repair_sensors`, `rescue_ship`; state `repair_quote`; economy route-cost estimate also uses fuel price |
| Fees / routes / cash advance | `ship_life_economy.gd` `_quote`, `_leg_quote`, `request_advance`; controller essential-cost estimate |
| Cargo capacity / shape rules | Packing model plus floor-grid/controller/visual definitions and quote units. Revalidate generated accessible solutions, not just total volume |
| Arrival / docking | Flight state and combined `_process_skip`; preserve 90-second wake margin, nose-first capture, explicit manual release and no duplicate delivery callback |
| New ship / Blender replacement | Preserve moving pivots, live screen metadata, interaction anchors, clearances and controller ownership; follow [asset rebuild guide](../art/longhaul_v3/README.md) |

Do not restore old automatic fuel reimbursements, free COMMS supplies, per-trip emergency resets, duplicate printer sheets or always-visible cargo tools. Distinguish food/water units from recycled shower water. Rendering changes must not silently remove colliders or interaction metadata.

## Validation

Last recorded results, not rerun for this documentation-only audit: **170 combined integration + 19 actual-flight checks** passed for the hab-furniture revision; prior state/economy results were **116 / 375**. Cargo-only results were **47 packing** (including 600 generated manifests), **446 economy**, and **108 controller checks**. Do not claim a fresh run solely because these counts appear in documentation.

Run appropriate suites from the repository root:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/ship-life-state.log --script res://scripts/ship_life_state_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/ship-life-economy.log --script res://scripts/ship_life_economy_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/ship-life-integration.log res://scenes/ship_life_trial.tscn -- --ship-life-test
```

The last command runs combined integration then the actual flight/delivery suite. It hashes existing save files before/after and redirects combined user save writes into `/tmp`; some setup/packing uses controller calls rather than exclusively real keyboard input. It exercises fixtures, dishes, paper, seated furniture, clearance, migration, calibration, money, rest, departure interlocks, physical flight, docking, unloading and single payment.

For the station build, use its dedicated suite rather than running the legacy fixture on the different hangar geometry:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/station-trial-test.log res://scenes/station_trial.tscn -- --station-trial-test --ship-life-new
```

Do not combine `--station-trial-test` and `--ship-life-test`; they dispatch separate suites. The station suite checks physical terminal aim/F, walked ramp routes with cargo, door interlock, a real solver-driven delivery and all five save files' preservation. Latest station integration run on 2026-10-06 passed **63/63**, and the retained combined baseline passed fresh **170/170 integration + 19/19 actual-flight checks**. Blender geometry passed **60/60** after the floor correction. See [STATION_TEST.md](STATION_TEST.md) for the five actual Godot capture views and their command. Warm static-camera frame measurements are diagnostics only, not a substitute for interactive flight/cargo performance testing.

For packing/economic/controller changes, also use:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/cargo-packing.log --script res://scripts/cargo_trial_packing_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/cargo-economy.log --script res://scripts/cargo_trial_economy_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/cargo-integration.log res://scenes/cargo_trial.tscn --fixed-fps 60 -- --cargo-trial-test
```

Flight, all-pairs map/world and Blender binding validation are documented in [FLIGHT.md](FLIGHT.md#simulation-boundaries-and-validation), [AUREL_SYSTEM.md](AUREL_SYSTEM.md) and the [asset guide](../art/longhaul_v3/README.md). Run those when shared flight/world/art changes warrant them. Inspect actual rendered geometry for visual changes; headless assertions cannot establish legibility or absence of mesh overlap.

Hab render capture (fresh temporary scene, no normal save load):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --log-file /tmp/ship-life-hab-capture.log res://scenes/ship_life_trial.tscn -- --ship-life-capture --hab-furniture
```

It writes seated, folded-seat, folded-aisle and lowered PNGs to `/tmp/ship-life-hab-*.png`, then exits. `--survival-revision` instead of `--hab-furniture` captures the paper/kitchen/sensor refinement views. Capture modes are visual QA helpers, not interactive save-backed play.

## Troubleshooting and resuming

- Wrong cargo/survival rules: verify the scene/launcher before debugging. Default project Play still opens standalone flight.
- Cannot depart: check cargo lock/staging/held cases, contract's next destination, sensor condition, fuel, code, route and hatch/ramp movement. Provisions produce warnings; they are not a takeoff gate.
- Cannot fold desk: clear its plate, step out of its sweep, close terminal/paper inspection, and wait for motion. T works while seated; F works while aiming at the desk.
- Cannot sleep/pass: compare bedtime, daily food/water/hygiene and checklist rules. In flight NAV must be in safe injection/coast and outside arrival watch. Put dishes/cargo away.
- Missing paper: distinguish cockpit rack sheets from the daily carried sheet. Daily paper must be collected at the tray, then H retrieves it if stowed. Tab only enlarges an already-held daily sheet.
- Cannot pay: check optional advance eligibility or failed-sensor emergency service. These retain liabilities; repeatedly accepting/loading must not mint money.

For future changes: read the handoff and affected guide, inspect git status and relevant source, implement without resetting progress, run scoped checks, update docs with actual evidence and any remaining gaps, then commit/push authorized work. Documentation updates alone require link/path/content checks, not replaying all gameplay tests.
