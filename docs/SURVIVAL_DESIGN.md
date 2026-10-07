# Survival and daily ship life — agreed design

Status: approved design, not implemented. Updated 2026-10-06.
This document records the user’s decisions and accepted proposals. The existing flight and cargo builds still use their previous survival and financing behavior. Do not describe this specification as playable until implementation and testing are complete.

## Intent

An Oregon Trail-like preparation and living loop within a cozy, single-player cargo game. Longhaul is home. Contracts fund operating expenses; planning supplies, choosing affordable journeys, and caring for the ship matter. No delivery deadlines or violence. The new daily sensor-care model replaces the existing engineering gameplay.

## Shared world time

Use one saved Aurel Standard Time calendar/clock for ship and stations. Advance during active play; pause while the game is closed. All travel, survival, sensor wear, and economic updates must use this clock, including time skipped. One checklist per calendar day, never per wake-up or paper print.

Normal sleep wakes the player at the next 06:00. Restrict sleep to an evening/night window; 20:00–06:00 is the accepted starting proposal, subject to tuning. Completing the daily checklist unlocks passing time until bedtime. Tasks performed before printing still count. Early arrival wake-ups do not create another daily obligation.

Both sleeping and passing time show a BLACK SCREEN WITH A PROGRESS BAR indicating progress toward the scheduled end; show how much remains. This presentation is required by the user. The real duration of that presentation is not yet specified.

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

Enter the bathroom shower, turn it on, and remain under it while hygiene rises. Showering is periodic, not mandatory every day; the player may shower more often. Sufficient hygiene satisfies the checklist/sleep condition automatically. Decay and the threshold remain tuning decisions.

## Daily checklist and sensor care

Print the daily checklist at the cabin/hab terminal. Terminal and paper reflect completion. Include eating, drinking, sufficient hygiene, and a small random selection of sensors for that day.

At the engineering sensor terminal, `status` reports sensor condition. A short self-test/calibration action such as `check navigation` completes the selected sensor check. The exact sensor list and CLI names remain implementation details to settle.

All sensors start at 100 condition. Selected sensors wear at 0.5 times normal daily wear when checked and 1.5 times normal wear when neglected. Unselected sensors use normal wear. Apply daily wear once at the day boundary; completing a check late still counts. Choose a base rate that takes many neglected days to fail, and warn before failure.

Only hangar repair services restore sensor condition. Zero condition blocks the next takeoff, while emergency capability must allow the current journey to finish and dock. Port service offers individual repairs and repair-all with a quote. Essential departure-blocking repairs also need a recovery route so the player cannot be trapped without work.

## Emergency rest — latest rule overrides earlier proposal

When food or water is inadequate, emergency rest is available THREE times. Warn and display remaining uses before each one. Attempting a fourth emergency rest without resupplying ends the run. The accepted proposed presentation is rescue/end-of-run with a departure-save reload option, rather than requiring a death presentation.

USER OVERRIDE: restore the three-use allowance after the player BUYS FOOD AND WATER AT A STATION. Do not reset it merely on docking, taking a new contract, cancelling one, or completing a leg. This replaces the earlier per-journey allowance/reset proposal.

Implementation detail still to settle: whether food and water must be purchased in the same transaction or can be purchased separately during a station visit. The user has not specified a minimum refill quantity or required coverage for the whole route; do not silently add one.

## Contracts and affordability — replaces automatic fuel advances

The contractor pays for fuel, provisions, and maintenance. Offer a fixed contract fee with enough expected profit to support sensible operation. No separate fuel/provisions reimbursement and no automatic fuel advance. Internally, balance fees against expected costs; detours, neglect, and expensive purchases may reduce profits.

If the player cannot afford a viable job, offer an optional advance against the accepted contract, limited to the essential shortfall. Subtract it from the final payment, so it is early payment rather than additional income. Only one advance per contract; cancelling must not erase the liability. Display available-now and payment-on-completion amounts clearly.

Keep at least one affordable/manageable local job available. Short jobs help players rebuild funds. Warn about provision shortages before departure rather than automatically locking takeoff for them. The exact repair-financing recovery policy and prices are still to be tuned.

## Journey targets

Accepted initial balancing proposal, not current route timings:
- Local: less than one shipboard day.
- Nearby: 1–3 days.
- Regional: 4–6 days.
- Remote: 7–9 days.

Initial longest journeys stay below 12 days so a full pantry leaves a reserve. Longer journeys can later require provisioning stops or upgraded storage. Preserve the earlier target of roughly 30 minutes maximum active travel for the farthest route; sleep/pass-time can reduce actual session duration. A precise active-time/world-time conversion has not yet been selected.

## Implementation and validation checklist

Before marking this design implemented, cover:
- Shared clock, day rollover, early wake-up, deterministic skip updates, and save/load.
- Real interactions for food, five bites, plate obstruction/cleanup, glass filling/drinking/cleanup, and shower recovery.
- Inventory consistency between port and hab; capacity, payment, and no item duplication.
- One daily checklist despite repeated wakes/prints; sensor selection, once-only wear, inspection multipliers, repair and takeoff gates.
- Emergency allowance reset only on the specified station food-and-water purchase event, with clear fourth-rest outcome.
- Black-screen progress UI and interrupt-safe time skipping.
- Optional advance accounting, cancellation debt, local-job availability, and no soft-lock from essential repairs.
- Existing flight/cargo behavior and normal-save migration; preserve user progress.

Keep agreed design, playable behavior, tuning values, known gaps, and test evidence distinct when updating this document.
