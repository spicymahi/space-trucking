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
3. Walk back to the hangar. Aim at a crate and press **F** to lift it with your tractor tool, then aim at a green slot in your ship's hold and press **F** again to set it down. Repeat.
4. Walk to the front of the ship and press **F** at the pilot seat.
5. Press **N** for the nav computer. Press **DIR** to see the station list. Key in Tharsis Ring's grid: **X +024, Y +003, Z -068** (use **+/-** to flip the Z sign), then press **ENT**. Press **N** or **Esc** to look back up.
6. Press **W** to lift off. Point the nose at the amber diamond and press **C** for cruise. Cruise drops out on its own near the station.
7. Press **L** to request docking. Fly into the hangar, slow down over pad 07 (the amber circle) and press **L** again to land.
8. Unload your crates onto pallet 07-B at Tharsis, walk to the exchange, and press **R** to sell them.

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
| Request docking / land | L | X |
| Cruise | C | L3 |
| Sell all on pallet (exchange) | R | X |

On the nav computer, you can type digits directly, or click the keys, or move with the D-pad and press A. Enter is ENT, Tab is DIR, Backspace deletes a digit and X (or Delete) is CLR.

## What is in this build

- One star system with two stations, Ceres Yard and Tharsis Ring. The plan is about five.
- Assisted flight with cruise, docking clearance and an autoland onto the pad.
- A walkable hangar, concourse and commodity exchange.
- Cargo crates that snap into a 16-slot hold grid.
- Prices that move as you buy and sell.

Contracts (the terminal is there, but marked offline), NPC traders and the other stations come next.

## For developers

Everything is built in code from `scripts/`, so there are no large scene files to merge.

| File | What it does |
| --- | --- |
| `scripts/main.gd` | World setup, mode switching (on foot, piloting, terminal), self-test and screenshot capture |
| `scripts/game_state.gd` | Autoload with credits, markets, stations and input bindings |
| `scripts/ship.gd` | The ship: hull, hold, cockpit, assisted flight, cruise, docking |
| `scripts/nav_computer.gd` | The physical keypad and nav CRT |
| `scripts/station.gd` | Station hull, hangar, pad, pallet and concourse |
| `scripts/player.gd` | On-foot movement and the crate tractor tool |
| `scripts/hud.gd`, `scripts/trade_terminal_ui.gd` | Flight overlay, prompts and the exchange screen |

A headless test plays the whole loop (buy, load, plot, fly, cruise, dock, land, unload, sell) and prints `SELFTEST OK`:

```sh
godot --headless --path . -- --selftest
```

To save screenshots of the main views into `captures/`, run with a display:

```sh
godot --path . -- --capture
```

## Credits

Fonts: [VT323](https://fonts.google.com/specimen/VT323) and [Oswald](https://fonts.google.com/specimen/Oswald), both under the SIL Open Font License (see `assets/fonts/`).
