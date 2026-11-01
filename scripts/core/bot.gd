extends RefCounted
## Computer planners. All three levels plan their city the same way (see BotPlanner): they
## search for a layout of the whole mat and buy what it needs. The levels differ in how hard
## they search, so Easy builds a muddle, Medium a decent city and Hard a careful one.

const Scoring = preload("res://scripts/core/scoring.gd")
const CardEffects = preload("res://scripts/core/card_effects.gd")
const BotPlanner = preload("res://scripts/core/bot_planner.gd")

const EASY := 1
const MEDIUM := 2
const HARD := 3
const LEVEL_NAMES := {EASY: "Easy", MEDIUM: "Medium", HARD: "Hard"}
## How much layout searching each level does, as a share of Hard's (see BotPlanner.COLD_ITERATIONS).
const EFFORT := {EASY: 0.03, MEDIUM: 0.07, HARD: 1.0}


static func level_name(level: int) -> String:
	return LEVEL_NAMES.get(level, "Human")


static func effort(level: int) -> float:
	return BotPlanner.tune.get("effort%d" % level, EFFORT.get(level, 1.0))


static func _empty_cells(cells: Array) -> Array[int]:
	var out: Array[int] = []
	for c in cells.size():
		if cells[c] == null:
			out.append(c)
	return out


## Does a turn's searching ahead of time, so a screen can run it off the main thread; the
## choices that follow then pick the finished plan up.
static func think(gs, level: int, rng: RandomNumberGenerator) -> void:
	if level > EASY:
		BotPlanner.next_purchase(gs, rng, effort(level))


## Returns [shop slot, mat cell]. The caller handles loans first.
static func choose_purchase(gs, level: int, rng: RandomNumberGenerator) -> Array:
	var planned := BotPlanner.next_purchase(gs, rng, effort(level))
	if not planned.is_empty():
		return planned
	# nothing the plan wants is affordable: take any affordable tile on any empty lot
	var slots: Array[int] = []
	for s in gs.shop.size():
		if gs.can_afford(s):
			slots.append(s)
	var empty := _empty_cells(gs.current_player().cells)
	return [slots[rng.randi() % slots.size()], empty[rng.randi() % empty.size()]]


## Where a free tile from an event card goes: any empty lot for Easy, the plan's lot otherwise.
static func choose_bonus_cell(gs, level: int, rng: RandomNumberGenerator) -> int:
	var p = gs.current_player()
	var empty := _empty_cells(p.cells)
	if empty.is_empty():
		return -1
	if level > EASY and not p.bonus_tiles.is_empty():
		var planned := BotPlanner.bonus_cell(gs, rng, effort(level))
		if planned >= 0:
			return planned
	return empty[rng.randi() % empty.size()]


## The option a bot takes on a choice card (see CardEffects.pick_option).
static func choose_card_option(gs, _rng: RandomNumberGenerator) -> int:
	return CardEffects.pick_option(gs, gs.current_index(), gs.card_choice_options())


## Cell for a free road, or -1 to keep it for later.
static func choose_free_road(gs, level: int, rng: RandomNumberGenerator) -> int:
	var p = gs.current_player()
	if p.free_roads <= 0:
		return -1
	var empty := _empty_cells(p.cells)
	if empty.is_empty():
		return -1
	if level > EASY:
		return BotPlanner.next_free_road(gs, rng, effort(level))
	# Easy drops roads at random in the second half of the game
	if gs.round_number >= 5 and (gs.round_number >= gs.ROUNDS or rng.randf() < 0.5):
		return empty[rng.randi() % empty.size()]
	return -1


## The change a bot names at the end of the game: the one with the most points still to gain.
static func choose_change(result: Dictionary, level: int, rng: RandomNumberGenerator) -> String:
	var types: Array = Scoring.COMPLAINT_TYPES
	if level <= EASY:
		return types[rng.randi() % types.size()]
	var best: String = types[0]
	for t in types:
		if result["room"][t] > result["room"][best]:
			best = t
	return best
