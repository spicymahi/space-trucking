# Complete ship-life test

Updated 2026-10-06. This is the playable combined cargo, flight, survival, and daily maintenance session. Launch `Test Ship Life.command` from the repository root. It opens `scenes/ship_life_trial.tscn`; the project's default scene and the earlier cargo-only launcher remain available separately.

## Start a test journey

A new session begins at Ceres Yard at 06:00, with 600 CR, 900 kg of fuel, and empty food and water storage. Press **F1** for the guide at any time.

1. Use **F** at the dock **CONTRACTS** computer. Enter `jobs`, then `accept 1` for the shortest available small load, or `accept 2` for a full hold. Collection contracts start with an empty flight to their supplier.
2. Use **PROVISIONS** beside the dock computers. Enter `buy food 12`, `buy water 12`, and `refuel` for a fully stocked first test. Purchase smaller quantities when preferred; food and water are sold separately.
3. Carry the consignment to the ship, pack the racks, clear the staging areas, and use **CARGO LOCK**. **F** picks up and places; **R** turns, **T** tips, **Z** changes rack depth, and **P** opens the packing guide. Pickup, delivery, and the four staging areas allow supported stacking just like the racks.
4. Choose normal cockpit departure or the optional prepared-cruise shortcut described below.
5. Aboard, print the day's checklist at the **HAB** terminal and collect it from the tray with **F**. **Tab** raises the carried sheet. Prepare food, drink water, wash as needed, and inspect the selected sensors. The bunk lets you pass time or sleep when eligible.
6. At arrival, obtain a berth with `approach` on NAV or COMMS, then use `auto dock` when within range, or complete the approach manually.
7. Once docked, use CHECKLIST `ramp lower` and `hatch open`. Unlock the cargo, carry every assigned box to the delivery grids, and use the dock **DELIVERY** completion terminal. The remaining fixed fee is paid once.

For collection work, arrival at the supplier makes the consignment available. Load and lock it there, then return it to the employer. Budget for provisions and fuel on both legs; the supplier has port services.

## Flying or starting directly in cruise

Normal flight retains the established cockpit workflow:

- **CHECKLIST:** `print`, then follow the departure readiness items.
- **CHART:** `stations`, `plot <station>`, and `print` for the route sheet.
- **NAV:** enter the printed `coords`, `burn`, and `reserve`, then `load`.
- **ENGINE:** `port on` and `starboard on`.
- **COMMS:** `request`, then `code <received-code>`.
- **CHECKLIST:** `hatch close` and `ramp raise`; wait for the mechanisms to finish.
- **COMMS:** `depart`. Use **G** near the pilot chair to sit, manually clear the station, then enter NAV `engage`. **G** leaves the chair once NAV is controlling the transfer.

Manual controls are **W/S** forward/reverse thrust, **A/D** lateral thrust, **Space/Ctrl** vertical thrust, arrows for pitch/yaw, **Q/E** roll, and **X** to stop rotation. **Shift** gives fine control. NAV remains engaged while the player walks around; `manual` explicitly releases it.

For survival testing without repeating the cockpit setup, use the dock **DEPARTURE** terminal and enter `start test`. This prepares the engines, sealed hatch, raised ramp, route entry, and NAV transfer, and places the player aboard. It still requires a valid contract, secured cargo when carrying freight, working sensors, and adequate fuel. It purchases nothing and does not deliver the cargo automatically. The resulting cruise uses the real flight simulation, fuel consumption, arrival warning, and docking controls.

## Provisions and kitchen interactions

The ship stores **12 food days and 12 drinking-water days**. One meal and one water unit satisfy the daily requirements. Both the hab terminal and the port terminal read the same inventory.

| Item | Port price | Purchase command |
| --- | ---: | --- |
| Food | 8 CR per day | `buy food <days>` |
| Drinking water | 4 CR per day | `buy water <days>` |
| Fuel | 0.08 CR per kg | `refuel` fills the tank to 3,000 kg |

Food: **F at fridge → F at oven → wait four real seconds → F to take the cooked plate → F at table → five F bites → F to pick up the dirty plate → G to stand → F at sink.** Setting the meal down seats the player at the center of the physical bench cushion; the seated view faces the plate. The table stays occupied until its plate is removed. Food leaves storage when its meal pack is collected, not again when cooked or eaten. Each bite supplies one fifth of the daily meal.

The dining nook is usable between meals. Look at the bench cushion and press **F** to sit, then **G** to stand. You can read your checklist or use the hab computer from the bench. **T** folds or lowers the desk while seated; while standing, look at the empty tabletop and press **F** (or **T**). A folded desk can be lowered with a meal in hand; press F again on the lowered place setting to serve it. Clear any meal or dirty plate before folding. The mechanism also refuses to move through the player. Table position, bunk drawer and reading light are saved with the session; older saves start with the table lowered.

Water: **F at cabinet → F at cooler → look away from other fixtures and F to drink → F at sink.** Filling the glass removes one drinking-water unit. Drinking an already consumed glass or refilling a full glass cannot duplicate water. The sink cleans and puts away used dishes.

Use the bathroom shower control with **F**, then stand under the water. Hygiene rises while washing; switch the shower off when finished. It uses recycled utility water, leaving drinking supplies untouched. Hygiene declines by six points per shipboard day, and at least 40% satisfies the daily hygiene requirement. A shower is therefore periodic rather than mandatory every morning.

## Hab checklist and engineering

At **HAB**, `stock` shows food, water, hygiene, and remaining emergency rests. `checklist` shows overall completion; `print` feeds a physical work order into the tray. Close the terminal and use **F** on the finished sheet to collect it. It is visible in your hand while walking. **H** stows/retrieves it and **Tab** raises/lowers the sheet already in your hand. **J** remains an alias for H. A stowed sheet stays stowed when Tab is pressed. Use **F at the PAPER / RECYCLING slot in the galley waste cabinet** to throw away the sheet in your hand. Delete and the Mac Delete/Backspace key also work as shortcuts. A sheet must first be physically collected; no key retrieves it remotely from the printer. The tray becomes empty after collection. Picking up cargo or a dish stows the paper until you retrieve it again.

Your hands are empty by default. The lifting tool appears only while a cargo box is held and disappears immediately on placement. The paper, food, plate, or glass appears only when that item is held; stowing or discarding a sheet never brings the gun back.

The printed work order contains the day's assigned sensor names. Neither the engineering CLI, its wall screen, nor a terminal `checklist` shortcut labels sensors as due. Hab displays overall routine completion and stocks; print to obtain the assignments. The sheet reflects completed tasks during its own day. At midnight it remains yesterday's sheet; recycle it and print a new work order. A single sheet is tracked at a time. `discard` also recycles it at a terminal. **Tab at Engineering temporarily reveals the paper and then restores the same terminal view**; cockpit terminals retain their established flight-paper controls.

Each calendar day has one checklist: food, drinking water, adequate hygiene, and two deterministic randomly selected sensor inspections. Waking, printing again, or loading a save does not generate another day's tasks.

At the engineering **SENSORS** terminal, `status` reports all sensor conditions. Read the assignment on your paper, then enter `check <sensor>`. Names are `navigation`, `proximity`, `coolant`, `pressure`, `drive`, and `communications`. Any sensor can be checked, so command availability does not reveal the daily selection.

Each check opens a three-channel calibration puzzle. Match each **READING** to its **REFERENCE**, using `trim a <signed amount>`, `trim b <signed amount>`, and `trim c <signed amount>`. For example, a reading of 8 and reference of 6 needs `trim a -2`. Enter `test` to submit all three. `resume` returns to an unfinished puzzle; `cancel` leaves it without a result or penalty. There is no timer.

Correct readings produce **PASS** and record the inspection. A failed test produces **DEGRADED**, leaves the daily inspection incomplete, and uses 1.5× daily wear until recalibrated or repaired. Use `check <sensor>` to retry. Passing clears the calibration fault but restores no lost condition; only port repairs do that. In-progress puzzles and degraded results are saved. A day boundary cancels an unfinished puzzle without a test result; existing degraded faults persist until corrected.

All sensors begin at 100. Daily base wear is one condition point, applied once at the calendar boundary. A selected, checked sensor loses 0.5 points; a selected, neglected sensor loses 1.5; unselected sensors lose one. A zero-condition sensor blocks departure. A journey already in progress retains emergency capability to reach port.

At the hangar **REPAIRS** terminal, `quote <sensor|all>` gives the cost and `repair <sensor|all>` restores condition. Repairs cost 2 CR per missing condition point, rounded up per sensor. `repair emergency` restores failed sensors, spends available credits, and bills any shortfall against future delivery payments. It addresses departure-blocking failures rather than providing free general maintenance.

## World time, sleep, and arrival

One saved Aurel Standard Time clock drives survival, sensor wear, flight, and the market. Ordinary simulation currently advances **24 shipboard seconds per real second**: a full day takes **60 real minutes**, 18× slower than the original test. All clocks show five-minute increments (06:00, 06:05, 06:10); a visible step takes 12.5 real seconds. Internal time stays precise so rest, wear and arrival interrupts still happen at the correct boundaries. Time continues while reading an in-world terminal. **Esc** closes a terminal; **Esc** again pauses the session. Closing the game also stops time.

At the bunk:

- `pass` requires the complete daily checklist and advances to 20:00.
- `sleep` is available from 20:00 until 06:00, requires food, water, and sufficient hygiene, and wakes at the next 06:00.
- Both show a black screen, progress bar, current clock, and remaining shipboard hours. A complete uninterrupted presentation takes approximately four real seconds. **Esc** interrupts it.

Skips advance the same simulation and operating costs as active time. They end early for the arrival watch or a relevant ship fault. Arrival interrupts sleep/pass-time at least **90 real simulation seconds before arrival braking**, with NAV still engaged; the remaining approach is handled awake. A shortened sleep does not create a new checklist unless the calendar actually crosses midnight.

Board journey estimates come from the existing flight solver at the catalogue epoch, assuming 980 kg cargo mass and adding 120 seconds for departure/approach. They use the same clock conversion as actual travel. CHART replans for the current orbital positions, ship setup, and departure time, so its current route can differ. Manual delays and detours add time.

Flight durations retain the existing approved physics. With the slower clock, a starting local job is below three shipboard hours and the longest initial solver quote is approximately 11.5 hours, including approach allowance. Fewer game days pass during each flight than in the earlier fast-clock test. The earlier 7–9-day remote-trip target is superseded by this pacing revision pending further playtesting. These are gameplay estimates within the compressed flight world, not literal journeys calculated from catalogue kilometres. Collection quotes include both legs. Readability of the system map remains independent of physical distance scale.

Loading a pre-pacing save preserves elapsed time, supplies, wear, wallet, advances, accepted fees, and flight progress. Future estimates are recalculated at the slower clock rate and unaccepted cached offers expire; completed historical receipts are retained.

## Emergency rest and operating money

`emergency` rest is available when the daily food or water requirement cannot be met from available supplies. The first three uses are allowed; attempting a fourth ends the run with a rescue screen. **F9** then reloads the departure checkpoint.

The three-use allowance resets only after buying a positive quantity of **both food and water during the same station visit**. The two purchases may be separate transactions. Buying zero, merely docking, changing contracts, or sleeping does not reset it. No minimum refill quantity beyond an actual purchase is imposed.

Contracts advertise a single fixed fee. The contractor pays for fuel, provisions, and repairs from their wallet; there is no automatic advance or separate reimbursement. At CONTRACTS, PROVISIONS, or DEPARTURE, `advance` requests only the shortfall for essential purchases on an accepted job. The estimate includes the current tank deficiency, a full-tank cash reserve for each later leg, food and water for the remaining journey, and failed-sensor repairs. Pantry capacity still limits what can be bought at once; keep the future-leg reserve for intermediate purchases.

An advance is available once before the first departure and is deducted from the final fee. Funds already owed reduce the unpledged contract balance. Emergency repair debt is likewise deducted from subsequent settlements. The economy supports retaining a cancelled advance as debt, but this combined test does not expose a player cancellation command while physical freight handling is active.

## Saving and restarting

**F5** saves; **F9** loads the combined session, except on the run-ended screen where it loads the departure checkpoint. `save` and `load` also work at the terminals. Ordinary play autosaves approximately every 45 seconds. Save waits for running rest or a moving hatch, ramp, table or bunk drawer to finish. Press F5 before closing if you want to preserve changes since the last autosave.

The combined session has independent files in Godot's `Space Trucking` user-data directory:

- `ship_life_v1.json`: regular combined save.
- `ship_life_departure_v1.json`: initial/departure recovery checkpoint.

They preserve the shared clock, stores, dishes and cooking, daily checks, sensor condition, emergency allowance and resupply flags, wallet/advance/debt, station economy and cargo reservations, physical cargo positions, flight, cockpit display assignments, carried checklist text/location, unfinished sensor calibration puzzles, and hab table/drawer/light state. They neither load nor overwrite `longhaul_flight_v1.json`, the original normal-flight save.

The launcher resumes an existing combined save. To start a fresh combined test explicitly, launch with the user argument `--ship-life-new`; subsequent saves belong to that fresh combined session. Normal-flight progress remains separate.

## Implementation map

| File | Responsibility |
| --- | --- |
| `scenes/ship_life_trial.tscn` | Combined test entry scene |
| `scripts/ship_life_trial.gd` | Session controller, fixtures, wallet purchases, world-clock bridge, rest UI, cargo/flight progression, saves |
| `scripts/ship_life_flight.gd` | Hosts the established cockpit/flight system with sensor interlocks and paid services |
| `scripts/ship_life_state.gd` | Calendar, daily requirements, kitchen item state, hygiene, checks, wear, emergency rest |
| `scripts/ship_life_economy.gd` | Fixed fees, optional advances/debt, real-planner estimates, deterministic hourly market updates, economic saves |
| `scripts/ship_life_paper.gd` | Camera-carried paper mesh, printed texture, and Tab inspection animation |
| `scripts/ship_life_visuals.gd` | Physical provisions/repair/hab/sensor fixtures, food/glass props, printer and shower visuals |
| `scripts/cargo_trial.gd` | Shared physical cargo handling, rack/floor grids, staging and delivery |
| `scripts/cargo_trial_packing.gd` | Generated guaranteed-fit manifests and support/access validation |
| `scripts/longhaul_flight_state.gd` | Existing navigation solver, inertial flight, NAV and docking state |

The legacy engineering puzzle and legacy automatic supplies service are not the maintenance/provisions systems used by this combined scene. Original scenes remain independent so this test can be evaluated before changing the project's normal entry point.

## Verification

Last recorded checks: **170 combined integration and 19 complete-flight checks passed** for the hab-furniture revision; previous state/economy runs passed **116 / 375**. The furniture checks cover independent sitting, real F/G/T input, paper reading while seated, folding clearance, plate interlocks, lowering with food in hand, and old/new save restoration. These results were not rerun for the documentation-only audit. The new checks include real H/Backspace input events, physical bin targeting, persistent stowing, cargo-tool lifecycle, five-minute clock boundaries, and old-clock save migration. Existing cargo regressions also passed: 47 packing assertions (including 600 generated manifests), 446 economy assertions, and 108 controller assertions.

The integration suite exercises the real scene/fixture rays, provisions and cooking, drinking/shower/checks, rest and arrival interruption, cockpit CLI departure and cargo/sensor interlocks, printing, finance, and save restoration. The following flight suite runs actual injection, coast, braking, approach, nose-first autodocking, arrival bookkeeping, animated hatch/ramp opening, unloading, and one-time payment. Some fixture setup and cargo placement use controller methods directly; these are not exclusively input-driven tests. Both suites hash existing normal/combined/checkpoint saves before and after; test writes are redirected into `/tmp`.

Rendered checks also confirmed independent bench seating and folded/lowered desk geometry. Earlier rendered checks confirmed empty hands after stowing, the galley recycling slot and discarded-sheet view, as well as the centered bench seat, carried/enlarged checklist, calibration prompt, and degraded result. Earlier checks also confirmed the hab fixtures, stock terminal, and centered black-screen sleep progress display. Physical interaction checks covered all new fixture rays, the meal/glass workflow, dining-seat exit, and entry into the shower. User playtesting is the next step for pacing and comfort.

Run from the repository root:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/ship-life-state.log --script res://scripts/ship_life_state_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/ship-life-economy.log --script res://scripts/ship_life_economy_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/ship-life-integration.log res://scenes/ship_life_trial.tscn -- --ship-life-test
```

The scene test command runs `ship_life_integration_test.gd` followed by `ship_life_flight_test.gd` and exits nonzero if either fails.

New-session launch:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/ship_life_trial.tscn -- --ship-life-new
```
