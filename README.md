# Egkomi City (dev)

A city-building board game about streets, shade and green space in Egkomi, Nicosia. 1 to 4 planners on one computer, built with **Godot 4.7** (GDScript, no plugins).

This is the private development repo. The public page, with downloads, is [egkomi-city](https://github.com/11samy02/egkomi-city).

## The game in short

- Each planner builds a **7x7 city** over **8 rounds**, buying **4 tiles a turn** from a shared construction site (222 tiles in the bag) with 100 starting gold.
- **Homes** bring citizens. Every citizen has a role (student, worker, child, older resident, resident with a disability, expat) with two needs, a few likes and a dislike. Needs are met by walking along **roads** to the right place, or by a **park** in the home's 3x3 area.
- **Green space** cheers up neighbours and cuts **pollution**. Long walks without shade overheat citizens.
- Each citizen scores their happiness (-5 to +5) as points. Extras: a **variety bonus** for a mix of happy citizen kinds, **loan penalties** (6, 9, 12, ...), and a penalty for services no home can reach.
- A **hospital** and a **supermarket** meet the same need as a clinic and a market, and give +1 happiness to each citizen they serve.
- Every turn a coin flip picks an **event** or **penalty card** (64 each). Hidden **circumstance cards** are revealed over the game and change the rules for everyone.
- Play with friends, or solo against **Easy, Medium and Hard bots**. The bots plan a whole city with simulated annealing, scored with the real scoring code.

## Run it

1. Install [Godot 4.7](https://godotengine.org/download).
2. Open this folder as a project and press F5 (main scene: `scenes/title.tscn`).

Export for Windows: Project > Export > "Windows Desktop" (the preset writes to `../build/EgkomiCity.exe`).

## Tests and tools

All commands run from the project root.

| What | Command |
| --- | --- |
| Unit tests | `godot --headless --path . --script res://tests/run_tests.gd` |
| Script syntax check | `godot --headless --path . --script res://tests/check_scripts.gd` |
| Bot economy and balance simulation | `godot --headless --path . --script res://tests/simulate_balance.gd -- --games=6 --level=2` |
| Real-click UI probes | `godot --path . --resolution 1600x900 -- --probe=click\|cards\|popups` |
| Visual playtest with screenshots | `godot --path . --resolution 1600x900 -- --tour=<dir> --players=4 --bot=greedy` |

`tools/` holds the Python and GDScript used to generate tile and card art and the print-and-play sheets.

## Code map

| Path | Contents |
| --- | --- |
| `scripts/core/` | Rules with no UI: `game_state`, `scoring`, `tile_defs`, `roles`, `card_defs`, `card_effects`, `circumstance_defs`, `bot`, `bot_planner` |
| `scripts/game/`, `scripts/final/`, `scripts/ui/` | Board screen, final scoring screen and shared widgets |
| `scenes/` | `title`, `game`, `final` |
| `assets/` | Tile, card, UI and font art (SVG) |
| `tests/` | Unit tests (`test_*.gd`) and probes |
| `docs/` | Design notes and plans |

When you change a scoring or tile rule, re-run the unit tests and the balance simulation, because the bot planner is tuned to the score range.

<sub>Fonts: Fredoka and Nunito, SIL Open Font License.</sub>
