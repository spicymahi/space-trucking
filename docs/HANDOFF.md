# Current project handoff

Updated 2026-10-06. Read this first when resuming; then read the guide for the affected system and inspect its implementation. This is the repository handoff. The workspace-parent HANDOFF.md describes the older Claude prototype and is historical, not current project state.

## Where the project stands

Godot 4.7.2, GDScript, macOS playtesting. Repository: https://github.com/spicymahi/space-trucking. Main is the working branch. Current ship visuals include imported Blender Longhaul assets; the old handoff’s code-only-art description is obsolete.

Setting: Aurel, a ringed gas giant, eight moons, fifteen stations. Cozy cassette futurism, ship as home, no violence or delivery deadlines. User may redesign the ship later; preserve gameplay independently of the hull/art.

Flight and map are user-approved. The cargo loop is also user-approved, but currently lives in a separate test scene and has NOT yet replaced normal flight’s older one-case freight implementation. New survival design is approved but NOT implemented. Keep those distinctions explicit.

## Entry points and system guides

| System | Entry point / guide | Main implementation |
| --- | --- | --- |
| Normal flight | `Fly Longhaul.command`, `scenes/longhaul_flight.tscn`, [FLIGHT.md](FLIGHT.md) | `scripts/longhaul_flight.gd`, `longhaul_flight_state.gd`, `longhaul_flight_sheet.gd` |
| Aurel map/world | [AUREL_SYSTEM.md](AUREL_SYSTEM.md) | `scripts/longhaul_system.gd`, `longhaul_system_visuals.gd` |
| Approved cargo trial | `Test Cargo.command`, `scenes/cargo_trial.tscn`, [README cargo guide](../README.md#cargo-loop-test) | `scripts/cargo_trial.gd`, `cargo_trial_packing.gd`, `cargo_trial_economy.gd`, `cargo_trial_visuals.gd` |
| Planned survival/day routine | [SURVIVAL_DESIGN.md](SURVIVAL_DESIGN.md) | Not implemented; inspect existing flight state, `longhaul_hab.gd`, `longhaul_engineering.gd` before integration |
| Blender asset integration | [v3 art README](../art/longhaul_v3/README.md) | `scripts/longhaul_blender_assets.gd` |

The older `LIFE_SLICE.md` documents a separate prototype, not the newly agreed survival loop.

## Cargo implementation details worth preserving

The controller owns interactions, hand-tool carrying, physical boxes, grids, terminals, contract transitions and the explicit test transfer. Packing is a pure rules model shared by the two ship racks and the pickup/delivery/staging floor grids. Economy owns station supply/demand, reservations, offers, lifecycle and payment; visuals build the dock, racks, grids and crates.

Racks: two 2×3×4 grids, 0.45 m cells, access from local low-X face. Floor areas: 4×3×4 grids, access from four sides. Support, bounds, overlap and removal rules are shared. Every staged case blocks departure, even if multiple cases share one pad. All delivered cases count toward completion, independent of how many delivery pads they occupy. Full manifests fit 48 rack cells; small manifests fit 24. Generated solutions include accessible loading order.

Cargo trial starts fresh on each launch and does not read/write normal flight progress. Test transfer skips flying and uses quoted trial fuel estimates; it is not live navigation integration. Other ship systems are scenery in this trial.

IMPORTANT PENDING CHANGE: the trial currently grants automatic fuel advances. The latest agreed economy design removes those in favor of contractor-paid expenses and optional shortfall advances deducted from payment. This is documented in SURVIVAL_DESIGN.md, not yet coded.

## Saves, validation, and continuation

Preserve the normal flight save at `user://longhaul_flight_v1.json`. On this Mac that is under `~/Library/Application Support/Godot/app_userdata/Space Trucking/`. Do not reset it to launch a focused trial.

From the repository directory, using `/Applications/Godot.app/Contents/MacOS/Godot`:

```sh
Godot --headless --path . --log-file /tmp/cargo-packing.log --script res://scripts/cargo_trial_packing_test.gd
Godot --headless --path . --log-file /tmp/cargo-economy.log --script res://scripts/cargo_trial_economy_test.gd
Godot --headless --path . --log-file /tmp/cargo-integration.log res://scenes/cargo_trial.tscn --fixed-fps 60 -- --cargo-trial-test
```

Replace `Godot` with the executable path above unless it is on PATH. Latest cargo validation: 47 packing assertions (including 600 generated manifests), 108 controller/integration assertions; economy’s last run passed 446 assertions. Integration covers real aim/F interactions, walking and carrying through the ship, stacking, both contract types, payment once, and normal-save preservation. Some lifecycle fixture steps intentionally call controller methods directly; this is not exclusively an input-driven test.

Latest gameplay commit at documentation time: `dcf0a57` (stackable floor areas); original cargo trial: `05add28`. Both pushed to main. Subsequent documentation commits supersede these as HEAD.

Next work is survival implementation when the user requests it. Read the full approved design first; settle remaining tuning details without treating older prototype behavior as a requirement. Keep this handoff and the affected system guide updated with entry points, state ownership, behavior changes, migrations, checks actually run, and outstanding work. Record new agreed decisions as planned until implemented. Documentation supports resumption but does not replace reading the relevant current code.
