# Citizen variety: two new citizens and a roster for every home

## Intent

Players noticed that homes feel like copies of each other. A medium apartment with 2 students and a
large student residence with 2 students are the same household with different pictures, and a large
apartment with 3 students adds a third. Students are about 50 of roughly 120 citizens, so most
decisions in the game revolve around universities and libraries, and the other citizens feel thin.

The goal is a city where **every home type is a different kind of household**, no single citizen type
dominates, and each home looks different from every other, so a player can tell at a glance who
lives there.

## What the player asked for (their words, in order)

1. Add two citizens: a **person with a disability**, and one that is **completely different from the
   existing four and fits real Egkomi** (their words: "it should be something which fits the Egkomi
   city in real life"; the choice of who was left to us).
2. Stop having two homes with the same household. Remove the all-student large apartment and the
   student flatshare; keep students in the student residences.
3. Give each home type its **own roster** that makes sense for that type.
4. Make students less dominant overall.
5. **Every household gets its own, unique building picture**, not just a different icon.
6. Update the tiles in the game and the **printed versions**.

## Decisions

### The two new citizens

| Citizen | Id | Needs | Notes |
|---|---|---|---|
| Resident with a disability | `access` | clinic or hospital (`health`), park (`park`) | Long walks hurt more, like older residents (`heat_factor` 2). Likes pedestrian streets, shaded streets, kiosks and parking (accessible bays). |
| Expat (embassy and international staff) | `expat` | workplace (`work`), restaurant (new need `dining`) | Egkomi is Nicosia's embassy and offices district; this citizen is the person who moves there for work. Likes coffee shops, parking and bike lanes. |

Why these two: each pair of citizens shares at most one need, so each one pulls the player towards a
different service. The expat makes the restaurant a real need (today it is only a "like" for workers
and a dislike for older residents), which also puts the restaurant in tension with older residents.
The disability citizen makes parks and clinics matter together, and rewards pedestrian streets.

The expat is **my choice** from "fits real Egkomi". Changing who it is later only touches the citizen
definition, its icon and the household pictures.

Exact likes, dislikes and heat values are left to the builder, with these constraints: no two
citizens share both needs, each citizen has a distinct set of likes, and each has a clear one-line
explanation in the rules text.

### The rosters

Every home kind keeps the total number of tiles it has today (18 small, 18 medium, 14 large, 8+8
student), so the shop stays 222 tiles and prices do not change. Students live only in the two student
residences, plus one mixed shared house.

| Home | Households (my starting proposal) |
|---|---|
| Small apartment (1 citizen) | Worker, Older person, Resident with a disability, Expat |
| Medium apartment (2) | Working couple, Older couple, Parent and child, Carer and resident (worker + disability), Expat couple |
| Large apartment (3) | Family (worker, worker, child), Three generations (older, worker, child), Shared house (student, worker, expat), Expat family (expat, expat, child) |
| Student residence, small (1) | Students (kept) |
| Student residence, large (2) | Students (kept) |

That is **15 household pictures** (today there are 5 pictures for 12 households).

The builder sets the quantity of each household so that:
- no citizen type is more than about 25% of all citizens in the shop (students today are about 40%);
- every citizen type is at least about 10% (so the disability citizen is not rare enough to be ignored);
- the per-kind totals above are unchanged.

### One picture per household

Each of the 15 households gets its own building drawn in `tools/gen_art.py`, in the same style as the
existing tiles (isometric Mediterranean buildings, same palette, same 256x256 canvas with the corners
left clear for the role icons and the price). The building itself should say who lives there, with
unique silhouettes, not only a different prop. For example: a ground-floor flat with a ramp and wide
door for the resident with a disability; a house with a bench and potted plants for the older couple; a
balcony with a bike and a toy for parent and child; a modern block with a flag and a car for the
expats; the existing blocky bike-rack building for the student residences.

Picture names are per household, for example `home_apartment_small_expat`. Tile data gets an `art`
entry per household (today `art` is per kind); `TileDefs.art_path` is the single place that resolves
it. Card art in `tools/gen_cards.py` that points at `apartment_small/medium/large` is switched to a
household picture that suits the card.

### Scoring and rules that have to follow

- **Citizens:** `Roles.IDS` grows to six, `NEEDS` gets `dining` (restaurant). Role colours and round
  icons (`assets/ui/role_access.svg`, `role_expat.svg`) are added in the same style as the other four.
- **Variety bonus** (`Scoring.VARIETY_BONUS`) is indexed by the number of citizen types that are happy
  and today stops at 4. It has to cover 0 to 6. My proposal is `[0, 0, 2, 5, 9, 14, 20]`, to be tuned
  with `tests/simulate_balance.gd` so that going for all six is a strong but not automatic plan.
- **Circumstance cards** that name citizens today (flu wave, cold snap) include the new disability
  citizen; the expat is covered by the generic ones (parking shortage, bus strike, road works). The
  card text, `describe.gd` and the card tests follow.
- **Rules panel and final scoreboard** text that says "four kinds of citizen" or lists the citizens is
  generated from `Roles.IDS` or updated by hand where it is not.
- **Bot players** and the balance simulation must still run and not prefer one citizen type
  blindly; the builder checks that the bot does not now ignore the new citizens' needs.

### Event and penalty cards (added after approval)

A few of the existing event and penalty cards (`scripts/core/card_defs.gd`, art in
`tools/gen_cards.py`) are changed or added so they fit the new citizens: for example an event that
helps accessible homes (ramps, pedestrian streets) or expat housing, and a penalty that hits
restaurants or accessibility. "A few" means about 3 to 5 cards in total, mostly reworking cards that
today only talk about students, workers, older residents or children, not a new deck. Card text, card
art, `card_effects.gd` descriptions and the card tests follow.

### Bot players (added after approval)

The bot must be able to play with the new tiles and citizens. Tests show that bots buy and place the
new households, connect them to a clinic, park, workplace and restaurant, and finish full games
without errors or crashes. A balance simulation run compares the bots' scores before and after, to
confirm no citizen type is ignored.

### Printed versions

`tools/export_print.gd` already builds one printed tile per household from the tile data, so the
printed sheet follows the new rosters and pictures with no new code. It has to be re-run, and the
result checked, because the sheet gets 3 to 4 more tiles. The print export is written to
`print_export/` in the project unless `--out=` is given.

## Goals

- Every home looks and plays differently; nothing is a re-skin of another home.
- Six citizen types, none dominant, each with a different pair of needs.
- The in-game tiles, the shop, tooltips, the rules panel and the printed sheet all show the new
  households and pictures.
- All existing tests are updated to the new data and pass; new tests cover the new citizens and the
  rosters (totals unchanged, no duplicate household, every household has art).

## Non-goals

- No new building types or new services beyond using the restaurant as a need.
- No change to prices, the 7x7 mat, the number of rounds or the loan rules.
- No redesign of the tile style, the card system or the street types.

## Anti-goals (a failure even if it technically works)

- Two households that read as the same at a glance.
- A new citizen that is only a re-coloured copy of an existing one (same needs).
- Students still being the first thing a player thinks of when they see the shop.
- The disability citizen treated as a joke or a penalty magnet: they have needs and likes like
  everyone else, and the art shows a person living a normal life (ramp, bench, bike), not a stereotype.

## Constraints

- Godot 4.7, the existing scripts and the Python art generator are the source of truth; tiles are SVG
  generated by `tools/gen_art.py` and imported by Godot.
- The working tree has many uncommitted changes to the generated art (the last session regenerated
  it), so the builder regenerates from `gen_art.py` and does not hand-edit SVG.
- Existing tests (`tests/run_tests.gd`) must pass at the end; the visual tour and the print export are
  run to check the result.
- The docs vault (see project memory) is updated at the end.

## Left to the builder

- Exact likes, dislikes and heat values of the two new citizens (within the constraints above).
- Exact household quantities and the final `VARIETY_BONUS` numbers, tuned with the balance simulation.
- The art itself: composition, colours and props of each of the 15 buildings within the style above.
- Names of the households and role icons, as long as the wording is friendly and matches the existing
  rules text ("Resident with a disability", "Expat").
