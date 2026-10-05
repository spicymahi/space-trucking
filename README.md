# Space Trucking

A first-person space trading game in voxel cassette futurism. Fly your ship, land in a station, walk to the exchange, buy cargo, carry it into your hold, then fly it somewhere that pays more.

Built with Godot 4 for macOS and Steam Deck (1280x800, keyboard/mouse or gamepad).

![Cockpit](docs/screenshots/05_cockpit.png)

## Run it on a Mac

1. Download **Godot 4.7** (standard version, not .NET) from <https://godotengine.org/download/macos/> and drag it into Applications.
   - The first time you open it, macOS may block it. If so, right-click Godot.app, choose Open, then confirm.
2. Clone or download this repo.
3. Open Godot. In the Project Manager, click **Import**, pick `project.godot` from this folder, and confirm.
4. Press **F5** (or the ▶ play button at the top right) to play.

The first import takes a few seconds while Godot builds its cache.

## The first run

You start on foot on pad 07 at Ceres Yard, behind your ship, the Kestrel-9.

1. Walk through the door at the back of the hangar into the concourse and up to the **Commodity Exchange** terminal on the right. Press **F** to use it.
2. Buy some **water ice** (cheap at Ceres). Bought crates appear on pallet 07-B next to your pad.
3. Walk back to the hangar. Aim at a crate and press **F** to lift it with your tractor tool, then aim into your ship's hold and press **F** again to set it down. A green ghost shows where it will go.
   - Aim at a crate that's already down to stack the new one on top of it. The hold and the pallet both take two layers.
   - Lifting from a stack always takes the top crate.
4. Walk to the front of the ship and press **F** at the pilot seat.
5. Press **N** for the nav computer, then press **DIR** (or **Tab**) to swing over to the route printer on its left. From the seat you can also press **M** to go straight there.
   - Pick **Tharsis Ring** with **W/S** and press **F** to print. The route slip clips onto the board to the right of the keypad, and the view returns to the keypad.
   - Key in the grid from the slip: **X +024, Y +003, Z -068**. Use **+/-** (or the minus key) to flip a sign, then press **ENT**.
   - Press **N** or **Esc** to look back up.
6. Press **W** to lift off. Point the nose at the amber diamond and press **C** for cruise. Cruise drops out on its own near the station.
7. Press **L** to request docking. Fly into the hangar, slow down over pad 07 (the amber circle) and press **L** again to land.
8. Walk to the exchange in the concourse and press **R** to sell.
   - The dock crew unloads anything still in your hold, for a 10% fee.
   - Crates you carry over yourself, or set on pallet 07-B first, sell at full price. A crate in your hands sells too.

## Hauling contracts

The **Contract Board** is the amber terminal past the exchange in every concourse. Press **F** to use it.

- Each board posts five jobs, with at least one to every other station. Pick one with **W/S** and press **F** to sign it. Its crates appear on pallet 07-B for free, with a cream **JOB** band. The sign line shows how much room your hold has left once your other jobs are aboard, and warns when a job won't fit.
- Load them into your hold like any cargo and fly to the job's destination. The route printer marks job destinations with `*`.
- At the destination's contract board, press **F** on the job to deliver it. Every crate must be there: in your hands, on pallet 07-B, or in your docked hold. The dock crew charges 10% of the hold crates' share of the pay.
- Job crates belong to the client. The exchange won't buy them.
- You can hold four jobs at once. Press **R** twice on one of your jobs to abandon it. That costs a quarter of its pay, and the client takes its crates back.
- Boards turn over: every three minutes each one drops its oldest offer and posts a new one.

## Controls

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Walk / look | WASD / mouse | Left stick / right stick |
| Sprint | Shift | L3 |
| Use, lift, place | F | A |
| Back / close | Esc | B |
| Pause (controls list, quit) | P | Start |
| Throttle up / down | W / S | RT / LT |
| Strafe | A / D | Right stick X |
| Up / down thrust | Space / Z | Right stick Y |
| Pitch / yaw | Mouse or arrow keys | Left stick |
| Roll | Q / E | LB / RB |
| Nav computer | N | Y |
| Route printer (in the seat) | M | DIR on the keypad |
| Request docking / land | L | X |
| Cruise | C | L3 |
| Sell all of a good (exchange) | R | X |
| Abandon a job (contract board, press twice) | R | X |

On the nav computer, you can type digits directly, or click the keys, or move with the D-pad and press A. Enter is ENT, Tab is DIR, Backspace deletes a digit and X (or Delete) is CLR.

On the route printer, W/S (or the D-pad) picks a station and F (or A) prints its slip. Esc goes back to the keypad.

## What is in this build

- One star system with five stations: Ceres Yard, Tharsis Ring, Vesta Forge, Europa Deep and Callisto Hub. Each one makes some goods and pays well for others.
- Assisted flight with cruise, docking clearance and an autoland onto the pad.
- A walkable hangar, concourse and commodity exchange.
- Cargo crates that snap into a 16-slot hold grid, stacked two high, and an 18-slot pallet by each pad.
- A route printer in the cockpit that prints each station's grid on a slip you can read while you key it in.
- Selling from the pallet, from your hands, or straight from the hold through the dock crew.
- Prices that move as you buy and sell.
- Hauling contracts at every station's contract board.

NPC traders come next.

## For developers

Everything is built in code from `scripts/`, so there are no large scene files to merge.

| File | What it does |
| --- | --- |
| `scripts/main.gd` | World setup, mode switching (on foot, piloting, terminal), self-test and screenshot capture |
| `scripts/game_state.gd` | Autoload with credits, markets, stations, contract offers and jobs, and input bindings |
| `scripts/ship.gd` | The ship: hull, hold, cockpit, assisted flight, cruise, docking |
| `scripts/cockpit.gd` | Cockpit art: CRT monitor housings, gauge hood with live dials, toggles and lamps, canopy, seat |
| `scripts/nav_computer.gd` | The physical keypad and nav CRT |
| `scripts/nav_directory.gd` | The route printer: station list, printed slips and the slip clipboard |
| `scripts/slot.gd`, `scripts/crate.gd` | Cargo slots (with stacking) and crates |
| `scripts/station.gd` | Station hull, hangar, pad, pallet and concourse |
| `scripts/player.gd` | On-foot movement and the crate tractor tool |
| `scripts/hud.gd`, `scripts/trade_terminal_ui.gd` | Flight overlay, prompts and the exchange screen |
| `scripts/contract_terminal_ui.gd` | The contract board screen: sign, deliver and abandon jobs |
| `scripts/vox.gd`, `scripts/collider_audit.gd` | Box helpers (including `Vox.Batch`, which merges static boxes into one draw call) and the collider audit |

A headless test plays the whole loop the way a player does, with aim, walking and key presses (buy, load and stack, sign a hauling job and carry its crates aboard, print a route slip, key it in, fly, cruise, dock, land, unload, sell, deliver the job, abandon another), and prints `SELFTEST OK`:

```sh
godot --headless --path . -- --selftest
```

The self-test also audits the ship's colliders: every visible part bigger than a knob must have a matching collider, and every collider must be filled by something visible. To run only that check:

```sh
godot --headless --path . -- --audit
```

To print the ship's collision shape count and the cost of its per-frame flight sweep:

```sh
godot --headless --path . -- --bench
```

To save screenshots of the main views into `captures/`, run with a display:

```sh
godot --path . -- --capture
```

## Credits

Fonts: [VT323](https://fonts.google.com/specimen/VT323) and [Oswald](https://fonts.google.com/specimen/Oswald), both under the SIL Open Font License (see `assets/fonts/`).
