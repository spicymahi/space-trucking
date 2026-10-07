# Current project handoff

Updated 2026-10-06. Read this first when resuming; then read the guide for the affected system and inspect its implementation. This is the repository handoff. The workspace-parent HANDOFF.md describes the older Claude prototype and is historical, not current project state.

## Where the project stands

Godot 4.7.2, GDScript, macOS playtesting. Repository: https://github.com/spicymahi/space-trucking. Main is the working branch. Current ship visuals include imported Blender Longhaul assets; the old handoff’s code-only-art description is obsolete.

Setting: Aurel, a ringed gas giant, eight moons, fifteen stations. Cozy cassette futurism, ship as home, no violence or delivery deadlines. User may redesign the ship later; preserve gameplay independently of the hull/art.

Flight and map are user-approved. The cargo loop is also user-approved, but currently lives in a separate test scene and has NOT yet replaced normal flight’s older one-case freight implementation. The combined ship-life test now integrates cargo, the original flight controller, and survival. It has its own scene/launcher/save; normal default flight retains older freight/survival behavior. Keep these entry points explicit.

## Entry points and system guides

| System | Entry point / guide | Main implementation |
| --- | --- | --- |
| Normal flight | `Fly Longhaul.command`, `scenes/longhaul_flight.tscn`, [FLIGHT.md](FLIGHT.md) | `scripts/longhaul_flight.gd`, `longhaul_flight_state.gd`, `longhaul_flight_sheet.gd` |
| Aurel map/world | [AUREL_SYSTEM.md](AUREL_SYSTEM.md) | `scripts/longhaul_system.gd`, `longhaul_system_visuals.gd` |
| Approved cargo trial | `Test Cargo.command`, `scenes/cargo_trial.tscn`, [README cargo guide](../README.md#cargo-loop-test) | `scripts/cargo_trial.gd`, `cargo_trial_packing.gd`, `cargo_trial_economy.gd`, `cargo_trial_visuals.gd` |
| Combined cargo/flight/survival | `Test Ship Life.command`, `scenes/ship_life_trial.tscn`, [SHIP_LIFE_TEST.md](SHIP_LIFE_TEST.md), [SURVIVAL_DESIGN.md](SURVIVAL_DESIGN.md) | `ship_life_trial.gd` controller/save/UI, `ship_life_flight.gd` bridge, `ship_life_state.gd`, `ship_life_economy.gd`, `ship_life_visuals.gd` |
| Blender asset integration | [v3 art README](../art/longhaul_v3/README.md) | `scripts/longhaul_blender_assets.gd` |

The older `LIFE_SLICE.md` documents a separate prototype, not the newly agreed survival loop.

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

Current next step is user playtesting and tuning of the implemented combined scene. The normal default flight scene remains separate. The existing flight duration floor makes initial local jobs about 1–2 days at the new clock rate, rather than the originally proposed sub-day hops. Quotes use the actual solver; do not shorten them without checking physical flight feasibility.

Combined sessions save to `user://ship_life_v1.json` and `user://ship_life_departure_v1.json`; the old flight save is untouched. Tests redirect all combined user save writes to `/tmp`. The new controller owns the shared clock, advances market and survival by actual simulated time, and calls `economy.finish_leg()` only on real docking. The prepared-cruise option skips checklist/manual departure for testing but still runs real transit, braking, and autodocking.

Read the full approved design and test guide before changing these systems; do not treat older prototype behavior as a requirement. Keep this handoff and the affected system guide updated with entry points, state ownership, behavior changes, migrations, checks actually run, and outstanding work. Record new agreed decisions as planned until implemented. Documentation supports resumption but does not replace reading the relevant current code.
