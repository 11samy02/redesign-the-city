# Egkomi City 3.0: tile sizes, 14x14 mats and prefixed mats

Source: `Update 3.0.md` in the Obsidian vault (the requirements). This file records how the code meets them
and the calls made where the note is silent. Calls that are mine, not the note's, are marked **(call)**.

## Intent
Tiles stop being all the same size. A 1:1 tile fills one square, a 2:2 tile fills four. The mat grows to
14x14 squares (the same physical mat as the old 7x7, cut in half both ways, so an old tile is now 2x2).
A *prefixed mat* starts a game with tiles already built on it, which players build around.

## Sizes (from the note)
- 1:1: small and medium apartments, small student residence, bookshop, print shop, clinic, commercial area,
  market, kiosk, coffee shop, trees, every road.
- 2:2: large apartments, large student residence, university, library, hospital, school, supermarket,
  restaurant, park, parking place.
- Prefixed streets may be 2:2 roads. Roads in the construction site are always 1:1.

## Model
- `cells` stays one flat array, now 196 long (`Grid.SIZE = 14`). A tile sits in its top-left square (the
  *anchor*). The other squares of a 2:2 tile hold a *part* marker: a copy of the tile's kind/variant with
  `part = true` and the offset to the anchor. So "what kind is on this square" works for any square
  (roads connect through any square of a 2:2 street) and loops that count tiles use `Grid.anchors`.
- Neighbours of a tile = squares that share an edge with any of its squares. A route is a path of road
  squares. A 2:2 street is simply 4 road squares, so a 1:1 road touching any side connects.
- Prefixed tiles carry `fixed = true`: they cannot be replaced, lost to a penalty, or moved.
- **(call)** Distances that were "tiles" are doubled to keep the same physical meaning: a long, hot walk is
  6 road squares (was 3), the park area is 2 squares around the park (was 1 tile = 3x3), "market within
  reach" is 4 squares.
- **(call)** Replacing a tile (once a game) works when the new tile fits where the old one stood.
- **(call)** Costs, quantities, 4 buys a turn, 4 free roads and the 222-tile bag are unchanged. A 14x14 mat
  with 32 tiles is roomy; a prefixed mat fills it. Tune `BUYS_PER_TURN` / `FREE_ROADS` after playtests.

## Prefixed mats (digital)
- `PlayerMatPreset` (resource): title, description, `tiles: Array[PresetTile]`.
- `PresetTile` (resource): `kind` (dropdown of every tile type), `x`, `y` (top-left square), `variant`
  (household or street type), `large` (2:2 street; roads only).
- Presets live in `resources/mats/*.tres`; every file there shows up in the title screen's mat picker next
  to "Empty mat". Everyone in a game gets the chosen mat.
- Two ship: **Southern Avenue** (requested: the bottom row is a whole 2:2 street, a university sits in the
  middle of the right edge) and **Crossroads** **(call)**: a 2:2 street up the middle and across, a park in
  one corner and a school in another.

## Print (A4)
- 2:2 tiles stay 4 x 4 cm. **1:1 tiles print 2 x 2 cm** on their own pages (four times as many per page),
  so a printed 1:1 tile really is half the size of a 2:2 tile.

## Bots
Same planner, now with sizes: an item is a tile type plus an anchor square, moves only go to squares where
the footprint fits, swaps only between equal sizes.

## Done when
Unit tests pass (with new ones for footprints, adjacency, presets, 2:2 placement), the click/popup probes pass,
a bots-only game finishes on every preset, and screenshots of shop, mat, tooltips, final screens and the title
screen show no clipped or overlapping UI.

## Added during the work (requests that came in while building)
- The game is renamed **Redesign the City** (title, top bar, card footers, export name). The GitHub repo link in the README is unchanged.
- **Cards rework** (`New Cards rework` in the vault): the listed cards were removed; decks are 32 event, 32 penalty and 24 hidden circumstance cards. **(call)** The note lists removals for events (44) but only some penalties and no hidden cards, so the other cuts were chosen by how well a card answers an objective; 12 new events, 5 new penalties and 7 new hidden cards were written. Every card answers at least one objective through what it does; the tags live in `OBJECTIVES` in `card_defs.gd` and `circumstance_defs.gd` and are tested, but the card face is unchanged and does not print them. New cards reuse pictures of removed ones (`ART_FROM`).
- **Print**: 1:1 tiles print at half size and share pages with the 2:2 tiles; persona badges with points (need +2, hospital and supermarket +3, like +1, dislike -1) sit on the left (good) and right (bad) half of a tile; parks, trees and shaded streets carry a pollution cloud. New sheets: four pollution bars with four player chips, and the planner's guide (two to a page).
