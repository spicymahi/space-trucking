# Survival and daily ship life — agreed design

Status: implemented in the combined ship-life test; updated 2026-10-06.
Run `Test Ship Life.command` / `scenes/ship_life_trial.tscn`. The normal default flight scene and cargo-only trial retain their prior behavior; their saves are separate. See [SHIP_LIFE_TEST.md](SHIP_LIFE_TEST.md) for controls and actual test evidence.

Initial tuning: one real second advances 0.12 shipboard hours (a day is 3 minutes 20 seconds). Quoted travel uses the existing flight solver, conservative full-load mass, and 120 seconds of departure/approach allowance. With that flight model, the shortest initial local offer is about 1–2 days, rather than the earlier below-one-day proposal; distant solver quotes stay below 9 days. Manual delays can lengthen a trip. Retuning very short local hops remains a balancing task; the accepted flight physics is preserved.

## Intent

An Oregon Trail-like preparation and living loop within a cozy, single-player cargo game. Longhaul is home. Contracts fund operating expenses; planning supplies, choosing affordable journeys, and caring for the ship matter. No delivery deadlines or violence. The new daily sensor-care model replaces the existing engineering gameplay.

## Shared world time

Use one saved Aurel Standard Time calendar/clock for ship and stations. Advance during active play; pause while the game is closed. All travel, survival, sensor wear, and economic updates must use this clock, including time skipped. One checklist per calendar day, never per wake-up or paper print.

Normal sleep wakes the player at the next 06:00. Restrict sleep to an evening/night window; 20:00–06:00 is the accepted starting proposal, subject to tuning. Completing the daily checklist unlocks passing time until bedtime. Tasks performed before printing still count. Early arrival wake-ups do not create another daily obligation.

Both sleeping and passing time show a BLACK SCREEN WITH A PROGRESS BAR indicating progress toward the scheduled end; show how much remains. This presentation is required by the user. The initial presentation targets four real seconds for an uninterrupted skip; the progress bar shows remaining shipboard hours. Escape interrupts rest. Arrival/fault interrupts can shorten it.

Interrupt skipping for arrival, a ship condition needing attention, or inadequate supplies for the remaining skip. Preserve at least 90 seconds of real active play before arrival needs attention, accounting for the world-time conversion. Do not run past an interrupt and then rewind. Skip simulation must still advance consumption, journey progress, wear, and economy consistently.

## Provisions and onboard inventory

A hangar terminal sells food and drinking water, separately, in days. One food unit and one water unit satisfy one game day. No minimum purchase requirement; quantities cannot exceed ship storage. Initial capacity: 12 food units and 12 water units.

A HAB TERMINAL must show the same live food and water stock as the station terminal. Include days remaining and capacity. The hab terminal also provides the daily checklist and printing. Never maintain separate conflicting inventory copies for the two terminals.

Showering uses a recycled utility-water system rather than consuming the drinking-water units in this initial version.

Food interaction sequence:

1. Take food from fridge.
2. Put it in oven; short cooking interval.
3. Take the resulting plate to the table and set it down.
4. Eat in five interactions, each contributing part of the daily requirement.
5. Take the dirty plate to the sink; it is cleaned and disappears.

A plate left at the eating place prevents sitting there for the next meal. Partial meals retain their remaining portion. Removing, moving, cooking, and eating must not double-consume or duplicate a food unit.

Water interaction sequence:

1. Take a glass from the cabinet.
2. Fill it at the cooler, reserving one water unit.
3. Use the drink prompt; this satisfies the daily requirement.
4. Return the glass to the sink.

The glass represents a daily water unit for gameplay, not a literal real-world hydration amount. Moving/refilling an already full glass must not duplicate water.

## Hygiene

Enter the bathroom shower, turn it on, and remain under it while hygiene rises. Showering is periodic, not mandatory every day; the player may shower more often. Sufficient hygiene satisfies the checklist/sleep condition automatically. Initial tuning: hygiene loses 6 points per day, requires 40 points for normal rest, and rises 5 points per real second under the running shower.

## Daily checklist and sensor care

Print the daily checklist at the cabin/hab terminal. Terminal and paper reflect completion. Include eating, drinking, sufficient hygiene, and a small random selection of sensors for that day.

At the engineering sensor terminal, `status` reports sensor condition. A short self-test/calibration action such as `check navigation` completes the selected sensor check. Implemented sensors: navigation, proximity, coolant, pressure, drive, communications. Two are selected each day. `check <sensor>` completes the self-test.

All sensors start at 100 condition. Selected sensors wear at 0.5 times normal daily wear when checked and 1.5 times normal wear when neglected. Unselected sensors use normal wear. Apply daily wear once at the day boundary; completing a check late still counts. Choose a base rate that takes many neglected days to fail, and warn before failure.

Only hangar repair services restore sensor condition. Zero condition blocks the next takeoff, while emergency capability must allow the current journey to finish and dock. Port service offers individual repairs and repair-all with a quote. Essential departure-blocking repairs also need a recovery route so the player cannot be trapped without work.

## Emergency rest — latest rule overrides earlier proposal

When food or water is inadequate, emergency rest is available THREE times. Warn and display remaining uses before each one. Attempting a fourth emergency rest without resupplying ends the run. The accepted proposed presentation is rescue/end-of-run with a departure-save reload option, rather than requiring a death presentation.

USER OVERRIDE: restore the three-use allowance after the player BUYS FOOD AND WATER AT A STATION. Do not reset it merely on docking, taking a new contract, cancelling one, or completing a leg. This replaces the earlier per-journey allowance/reset proposal.

Implemented: positive food and water purchases may be made separately during the same station visit. The second kind of purchase resets the allowance and clears the purchase-pair flags. Zero-quantity purchases do not count. There is no required refill quantity beyond buying at least one unit of each. Departure ends that visit.

## Contracts and affordability — replaces automatic fuel advances

The contractor pays for fuel, provisions, and maintenance. Offer a fixed contract fee with enough expected profit to support sensible operation. No separate fuel/provisions reimbursement and no automatic fuel advance. Internally, balance fees against expected costs; detours, neglect, and expensive purchases may reduce profits.

If the player cannot afford a viable job, offer an optional advance against the accepted contract, limited to the essential shortfall. Subtract it from the final payment, so it is early payment rather than additional income. Only one advance per contract; cancelling must not erase the liability. Display available-now and payment-on-completion amounts clearly.

Keep at least one affordable/manageable local job available. Short jobs help players rebuild funds. Warn about provision shortages before departure rather than automatically locking takeoff for them. Initial prices: food 8 CR/day, water 4 CR/day, fuel 0.08 CR/kg, and sensor repair 2 CR per missing condition point. `repair emergency` restores failed sensors, spends available credits, and bills the remainder against future delivery fees. This service provides no cash to the player.

## Journey targets

Original balancing targets (local/nearby durations still need tuning against the existing flight solver):

- Local: less than one shipboard day.
- Nearby: 1–3 days.
- Regional: 4–6 days.
- Remote: 7–9 days.

Initial longest single-leg journeys stay below 12 days so a full pantry leaves a reserve. Collection round trips can exceed that capacity and allow provisioning at the supplier. Longer single-leg journeys can later require intermediate provisioning stops or upgraded storage. Preserve the earlier target of roughly 30 minutes maximum active travel for the farthest route; sleep/pass-time can reduce actual session duration. The implemented conversion is 0.12 shipboard hours per flight-simulation second. Manual delays and time spent at port also advance the shared clock.

## Implementation and validation checklist

Validation requirements for the combined implementation; current results are recorded in [SHIP_LIFE_TEST.md](SHIP_LIFE_TEST.md):

- Shared clock, day rollover, early wake-up, deterministic skip updates, and save/load.
- Real interactions for food, five bites, plate obstruction/cleanup, glass filling/drinking/cleanup, and shower recovery.
- Inventory consistency between port and hab; capacity, payment, and no item duplication.
- One daily checklist despite repeated wakes/prints; sensor selection, once-only wear, inspection multipliers, repair and takeoff gates.
- Emergency allowance reset only on the specified station food-and-water purchase event, with clear fourth-rest outcome.
- Black-screen progress UI and interrupt-safe time skipping.
- Optional advance accounting, cancellation debt, local-job availability, and no soft-lock from essential repairs.
- Existing flight/cargo behavior and independent combined saves; preserve normal-flight progress. The combined test does not migrate or replace the normal default scene's save.

Keep agreed design, playable behavior, tuning values, known gaps, and test evidence distinct when updating this document.
