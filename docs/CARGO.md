# Cargo contracts, packing and economy

Current combined implementation, audited 2026-10-06. Launch **Test Ship Life.command**. [SHIP_LIFE_TEST.md](SHIP_LIFE_TEST.md) covers the connected flight and survival sequence. **Test Cargo.command** is an isolated older trial with automatic fuel advances and a simulated transfer; its travel/finance behavior is not the current combined design.

## Contract lifecycle

One contract can be active at a time. At the hangar CONTRACTS computer, use `jobs` and `accept <offer number>`. The board attempts a short local outbound job, a full outbound load and a small collection job. Offers depend on available stock/demand and profitable route matches; fewer can appear when no valid match exists. Acceptance rechecks availability and reserves the consignment. Reload/refresh a stale quote if acceptance reports changed stock.

| Contract | Progression |
| --- | --- |
| Outbound | Employer exports goods: accept → `loading` → rack and lock all cases → `delivery` → fly to buyer → `unloading` → complete |
| Collection | Employer needs an import: accept → `to_pickup` → fly empty to supplier → `loading` → rack and lock → `delivery` → fly back to employer → `unloading` → complete |

Goods belong to the employer; the player does not buy them. Outbound boxes appear at pickup on acceptance. Collection boxes appear after actual docking at the supplier. The generated manifest has a valid packing solution and cannot exceed rack capacity. Its commodity quantity is measured in occupied cells, not number of individual boxes.

Acceptance removes goods from free source supply, removes the matching demand from the destination's free pool, and adds reserved inbound quantity. Background traders cannot consume accepted freight or its destination capacity. Completion releases the inbound reservation and records fulfilled units. Physical cargo must not be regenerated when loading a saved session; restore the original manifest and poses.

## Packing and handling

| Area | Capacity / access |
| --- | --- |
| Two ship racks | Each 2×3×4 cells (X depth, Y height, Z length), 0.45 m per cell; access from local low-X face |
| Small job | 24 cells, one rack; generated 4–6 cases |
| Full job | 48 cells, both racks; generated 8–12 cases |
| Pickup / delivery / four temporary staging grids | Each 4×3×4 cells; horizontal access from all four sides; stacking allowed |

F lifts/places a case; R turns it and T tips it. Z chooses automatic/rear/front rack depth. P opens an optional solution order. Aim at an empty floor cell or a box's top face to stack. The green placement preview is valid; red explains why it is blocked. The lifting tool only appears while holding cargo; picking up a case stows the daily paper.

Placement requires unchanged box dimensions up to rotation, bounds, no overlap, support below every bottom cell, and an unobstructed access path. Remove top cases before their supports and front cases before those behind them. Carrying and placement also respect ship/player collision. Floor areas use the same packing model with different size/access settings; they are not one-box slots.

Manifests are built by tiling a valid rack volume, finding a supported and accessible loading order, then shuffling the cases/orientations. `solution_order` is both the optional hint and a regression aid. Do not replace this with a volume-only fit check: volume alone does not guarantee loadability.

## Locking, departure and unloading

F at CARGO LOCK secures a complete racked consignment. No case may be held or remain on a staging grid; every assigned case must be in a rack. Unlock before rearranging or unloading. Every staged case blocks departure even if several share one grid. An empty collection first leg is allowed.

Locking satisfies cargo readiness, not the entire flight checklist. The combined controller also requires working sensors, correct next contract destination, engines, clearance/code, loaded route, fuel and closed/stationary hatch and ramp. The cockpit checklist remains the source of overall readiness. The optional `start test` at DEPARTURE prepares a real cruise for testing; it does not complete delivery or purchase supplies.

After actual docking, lower the ramp and open the hatch via CHECKLIST. Release cargo locks, carry every case to the destination DELIVERY grids, and F the completion computer. Stacked cases count individually regardless of grid count. Payment requires the correct destination, every assigned box and an unpaid contract. It happens once; delivered physical cases are cleared after settlement.

## Fees, costs and recovery

The combined economy advertises a fixed fee; the player pays fuel, provisions and repairs. Internal expected operating costs help price the offer but are not separate reimbursements. Actual extra fuel use or maintenance does not increase the fee. Collection quotes cover both legs. CHART's live departure-epoch estimate is more authoritative than the board's cached catalogue-epoch quote.

Current balancing formula in `ship_life_economy.gd`:

- Estimated operating cost = quoted fuel cost + `max(1, ceil(journey_hours / 24)) × 40` + 35 CR.
- Fee = estimated operating cost + cargo units × 9 + `ceil(quoted_real_minutes × 8)` + 150 CR.
- Valid offers also require positive employer margin. A local-job candidate favors the shortest valid small outbound route; it is not an unconditional stock grant.

`advance` at CONTRACTS, PROVISIONS or DEPARTURE pays an essential cash shortfall once before the first leg begins. It is deducted from settlement, never additional profit, and cannot exceed unpledged remaining fee after debt. Essentials include current fuel fill, future-leg fuel reserve, missing food/water and failed-sensor repair. An advance can be refused if the contract cannot fund the shortfall. The UI does not expose contract cancellation; the economic model supports returning reservations and retaining cancelled advances as debt for future use.

Port `repair emergency` restores failed sensors using available cash and service debt. COMMS `rescue` invokes flight recovery and adds 150 CR debt. Debt is repaid from delivery settlements and can persist across jobs. See [survival finance](SHIP_LIFE_TEST.md#emergency-rest-and-operating-money) for prices, provisions and emergency-rest rules.

## Dynamic economy and NPC scope

All fifteen stations have production, consumption, supply, demand and reserved inbound values. Free stock/demand are capped at 120 units; reserved inbound reduces free demand capacity. Limited abstract background trades move free quantities between producers and buyers. The combined model processes these at whole shared-clock hours, keeping sleeping and ordinary time advancement consistent, and adds routine Port supplies production/consumption alongside authored commodities.

This is a coarse economic simulation, not individual NPC vessels physically flying routes. Player deliveries fulfill reserved demand; background trades use only free pools. Neither the market nor an NPC should invalidate accepted cargo. There are no delivery deadlines, individual trading, trolleys or loading-service commands in the combined scene.

## Implementation and validation

| File | Ownership |
| --- | --- |
| `scripts/cargo_trial_packing.gd` | Generation, rack/floor occupancy, support, access and removal rules |
| `scripts/cargo_trial.gd` | Physical cases, hand tool, placement previews, grids, locks, pickup/drop-off and completion |
| `scripts/cargo_trial_visuals.gd` | Dock, cases, rack and grid presentation |
| `scripts/cargo_trial_economy.gd` | Station market, matching, reservations and contract lifecycle; older standalone trial finance |
| `scripts/ship_life_economy.gd` | Combined fixed fees, route quotes, optional advances, debt, shared-clock market and persistence |
| `scripts/ship_life_trial.gd` | Connects cargo to actual docking, paid services, survival gates and combined saves |
| `scripts/ship_life_flight.gd` | Copies cargo readiness/mass into established flight hardware state |

Regression commands, last recorded results and save protections are in [DEVELOPMENT.md](DEVELOPMENT.md#validation). Preserve both the physical-controller tests and pure packing/economic tests when changing cargo behavior.
