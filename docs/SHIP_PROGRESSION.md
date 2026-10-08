# Future ship progression

Recorded 2026-10-07. **Design notes only; do not implement until requested.** Existing gameplay, ships, economy and saves are unchanged.

## Confirmed direction

The player starts with a small ship carrying a limited amount of cargo. Contract earnings fund a replacement suited to the player's preferred work. Ships should offer meaningful tradeoffs rather than a straight sequence of universally better upgrades. Preserve flight, cargo handling, survival and daily ship-care loops across hull designs.

The player can **trade in their current ship at a percentage loss to help fund the next ship**. The trade-in credit reduces the amount paid for the replacement. The loss percentage and valuation basis are not decided; do not invent a fixed rate or implement depreciation yet. Keeping a fleet of old ships was suggested but is not the chosen progression plan.

User-defined roles include a high-capacity freighter with higher fuel consumption and a fast, nimble courier with very little cargo space, capable of carrying important documents between stations. The following five-role roster records those ideas and the additional proposed roles for later refinement. Exact capacities, prices, speeds, fuel rates and unlock conditions remain undecided.

## Five ship roles

| Role | Benefit | Tradeoff and effect on play |
| --- | --- | --- |
| Starter utility hauler | Low running costs and a compact home for short local jobs | Small hold and limited range; careful packing and nearby contracts. Should remain useful rather than become obsolete immediately. |
| Heavy freighter | Large bulk consignments and strong earnings when fully loaded | Higher total fuel use, slower acceleration/braking and more manual loading. Potentially efficient per delivered box when full. |
| Express courier | Fast, nimble travel carrying documents, data cartridges or small valuable parcels | Very little cargo capacity; high-speed operation costs more fuel. More frequent port visits. Secure delivery can justify fees without introducing deadlines. |
| Long-range expedition hauler | Efficient cruise, larger fuel/provision stores and a comfortable hab for remote routes | Higher purchase cost, modest acceleration, and stores/tanks taking space that could carry cargo. Emphasizes preparation and life aboard. |
| Specialist transport | Refrigerated, shielded or vibration-isolated storage for medicine, samples or precision equipment | More expensive upkeep and less general-purpose space. Proposed predictable cargo-care checks and storage compatibility, with ample warnings rather than surprise failures. |

The expedition and specialist mechanics are proposals, not existing features. Keep the cozy, nonviolent, no-delivery-deadline direction when balancing every role. Operating costs remain the contractor's responsibility.

## Art and implementation sequence

Five starter-ship exterior alternatives are available in [the 2026-10-07 concept set](ship-concepts/2026-10-07-starter/README.md): Pika, Mule, Sidewinder, Kestrel and Cricket. These are alternatives for the same starter role, not replacements for the five progression classes. No exterior has been selected or modeled yet.

The user has approved the new illustrated room style and its warmer, sharper-shadow lighting direction. Use the fresh [hab study](../studies/moebius_hab/README.md) as the visual reference: illustrated Moebius-inspired surfaces, cassette-futurist technology, purposeful details and restrained labeling.

Proposed next design step: concept the starter ship exterior, then fit a usable cockpit, compact hab, washroom, machinery and cargo hold inside it. The room study establishes the style; its exact dimensions are not a requirement for every ship. Resolve walkways, cargo access and equipment clearance before detailed modeling.

Future ship swapping will need to preserve the existing gameplay systems and define what happens to provisions, belongings, active cargo and contracts. Those transfer rules and trade-in pricing require later design work. This document authorizes no gameplay or asset changes.
