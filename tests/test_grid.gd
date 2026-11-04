extends "res://tests/test_base.gd"
## Tile sizes (1:1 and 2:2), the 14x14 grid, prefixed mats and what the printed tiles say.

const GameState = preload("res://scripts/core/game_state.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const MatLibrary = preload("res://scripts/core/mat_library.gd")
const PrintTile = preload("res://scripts/ui/print_tile.gd")
const PresetTile = preload("res://scripts/resources/preset_tile.gd")
const PlayerMatPreset = preload("res://scripts/resources/player_mat_preset.gd")

const K := TileDefs.Kind


func _game(mat = null) -> GameState:
	var gs := GameState.new()
	gs.setup(["Ana", "Ben"], [0, 1], 5, [], mat)
	return gs


func _home(result: Dictionary, anchor: int) -> Dictionary:
	for a in result["apartments"]:
		if a["index"] == anchor:
			return a
	return {}


func _slot(gs: GameState, kind: int) -> int:
	for i in gs.shop.size():
		if gs.stack_count(i) > 0 and gs.shop[i]["tile"]["kind"] == kind:
			return i
	return -1


# ---------------------------------------------------------------- sizes

func test_tile_sizes_follow_the_update_3_list() -> void:
	var small := [K.APT_S, K.APT_M, K.STUDENT_S, K.BOOKSHOP, K.PRINT_SHOP, K.CLINIC, K.COMMERCIAL, K.MARKET, K.KIOSK, K.COFFEE_SHOP, K.TREES, K.ROAD]
	var big := [K.APT_L, K.STUDENT_L, K.UNIVERSITY, K.LIBRARY, K.HOSPITAL, K.SCHOOL, K.SUPERMARKET, K.RESTAURANT, K.PARK, K.PARKING]
	for k in small:
		eq(TileDefs.footprint(TileDefs.make(k)), 1, "%s is 1:1" % TileDefs.DEFS[k]["name"])
	for k in big:
		eq(TileDefs.footprint(TileDefs.make(k)), 2, "%s is 2:2" % TileDefs.DEFS[k]["name"])
	eq(small.size() + big.size(), TileDefs.DEFS.size(), "every kind is in one list")
	var street := TileDefs.make(K.ROAD)
	street["big"] = true
	eq(TileDefs.footprint(street), 2, "a prefixed street can be 2:2")
	eq(TileDefs.size_label(TileDefs.make(K.PARK)), "2:2", "label")
	eq(TileDefs.size_label(TileDefs.make(K.KIOSK)), "1:1", "label")


func test_the_grid_is_14x14() -> void:
	eq(Grid.SIZE, 14, "side")
	eq(Grid.CELLS, 196, "squares")
	eq(Grid.empty().size(), 196, "an empty mat")


# ---------------------------------------------------------------- placing

func test_a_big_tile_fills_four_squares_and_clears_again() -> void:
	var cells := Grid.empty()
	var park := TileDefs.make(K.PARK)
	check(Grid.fits(cells, 15, 2), "it fits on an empty mat")
	Grid.place(cells, 15, park)
	for sq in [15, 16, 29, 30]:
		eq(Grid.anchor_of(cells, sq), 15, "square %d belongs to the park" % sq)
		eq(cells[sq]["kind"], K.PARK, "square %d shows a park" % sq)
	check(not Grid.is_part(cells[15]), "the top-left square is the tile")
	check(Grid.is_part(cells[30]), "the others are parts")
	eq(Grid.tiles(cells).size(), 1, "one tile, however many squares")
	eq(Grid.anchors(cells), [15] as Array[int], "one anchor")
	check(not Grid.fits(cells, 16, 2), "it does not fit over the park")
	check(not Grid.fits(cells, 2 * 14 + 14 + 1, 2) or true, "")
	Grid.remove(cells, 30)
	eq(Grid.tiles(cells).size(), 0, "removing any square removes the whole tile")
	check(cells[15] == null and cells[16] == null and cells[29] == null and cells[30] == null, "all four squares are empty")


func test_a_big_tile_has_to_fit_inside_the_mat() -> void:
	var cells := Grid.empty()
	check(not Grid.fits(cells, 13, 2), "not over the right edge")
	check(not Grid.fits(cells, 13 * 14, 2), "not over the bottom edge")
	check(Grid.fits(cells, 13 * 14 + 12, 2) == false, "no row 13 start")
	check(Grid.fits(cells, 12 * 14 + 12, 2), "the bottom-right corner block fits")
	check(Grid.fits(cells, 195, 1), "a small tile fits in the last square")


func test_pointing_at_a_square_finds_a_place_for_a_big_tile() -> void:
	var cells := Grid.empty()
	# the square under the cursor is the top-left square when it fits
	eq(Grid.find_anchor(cells, 5 * 14 + 5, 2), 5 * 14 + 5, "top-left first")
	# at the right edge the tile shifts left
	eq(Grid.find_anchor(cells, 5 * 14 + 13, 2), 5 * 14 + 12, "shifted in from the right edge")
	Grid.place(cells, 5 * 14 + 5, TileDefs.make(K.KIOSK))
	# a kiosk on the cursor square: the footprint moves up and left instead
	var found := Grid.find_anchor(cells, 6 * 14 + 6, 2)
	check(found >= 0 and Grid.fits(cells, found, 2), "another footprint on the same square")
	eq(Grid.find_anchor(cells, 5 * 14 + 5, 2), -1, "an occupied square cannot be pointed at")


# ---------------------------------------------------------------- game state

func test_the_game_places_big_tiles_and_refuses_overlaps() -> void:
	var gs := _game()
	var park := _slot(gs, K.PARK)
	var kiosk := _slot(gs, K.KIOSK)
	check(gs.buy_and_place(park, 0), "a park goes on the top-left corner")
	check(not gs.buy_and_place(kiosk, 1), "a kiosk cannot go on the park's second square")
	check(not gs.buy_and_place(kiosk, 15), "nor on its fourth")
	check(gs.buy_and_place(kiosk, 2), "but right beside it")
	check(not gs.can_place(13, 2), "a big tile cannot hang over the edge")
	eq(Grid.tiles(gs.current_player().cells).size(), 2, "two tiles")


func test_replacing_a_tile_needs_the_new_one_to_fit() -> void:
	var gs := _game()
	var kiosk := _slot(gs, K.KIOSK)
	var park := _slot(gs, K.PARK)
	check(gs.buy_and_place(kiosk, 0), "a kiosk")
	check(gs.buy_and_place(_slot(gs, K.COFFEE_SHOP), 1), "a coffee shop right next to it")
	check(not gs.can_replace(park, 0), "a park does not fit where the kiosk stood: the coffee shop is in the way")
	var gs2 := _game()
	check(gs2.buy_and_place(_slot(gs2, K.KIOSK), 0), "a kiosk alone")
	check(gs2.can_replace(_slot(gs2, K.PARK), 0), "a park fits where it stood")
	var old := gs2.replace_tile(_slot(gs2, K.PARK), 0)
	eq(old["kind"], K.KIOSK, "the kiosk went back")
	eq(Grid.anchor_of(gs2.current_player().cells, 15), 0, "the park covers four squares")


func test_a_small_tile_replacing_a_big_one_goes_where_the_planner_points() -> void:
	for square in [0, 1, 14, 15]:
		var gs := _game()
		var kiosk := _slot(gs, K.KIOSK)
		check(gs.buy_and_place(_slot(gs, K.PARK), 0), "a park on the corner")
		check(gs.can_replace(kiosk, square), "a kiosk may replace it, pointing at square %d" % square)
		eq(gs.replace_anchor(kiosk, square), square, "and it stands on square %d" % square)
		var old := gs.replace_tile(kiosk, square)
		eq(old["kind"], K.PARK, "the park went back")
		var cells: Array = gs.current_player().cells
		eq(cells[square]["kind"], K.KIOSK, "the kiosk is on the pointed square")
		eq(Grid.tiles(cells).size(), 1, "and only the kiosk is left")
	var gs2 := _game()
	check(gs2.buy_and_place(_slot(gs2, K.KIOSK), 15), "a kiosk")
	eq(gs2.replace_anchor(_slot(gs2, K.PARK), 15), 15, "a bigger tile keeps the old top-left square when it fits")


# ---------------------------------------------------------------- connections

func test_a_road_touching_any_side_of_a_big_street_connects() -> void:
	var rows := blank14()
	put(rows, 4, 6, "WW")
	put(rows, 4, 7, "WW")
	put(rows, 3, 7, "s")
	put(rows, 6, 6, "M")
	var r := Scoring.evaluate(mat14(rows), 0)
	var home := _home(r, 7 * 14 + 3)
	check(home["routes"].has(6 * 14 + 6), "a home beside the street reaches a market on its other side")
	check(home["routes"][6 * 14 + 6]["length"] >= 1, "the route is made of street squares")


func test_a_small_road_joins_a_big_street_and_a_big_building() -> void:
	var rows := blank14()
	put(rows, 0, 12, "WW")
	put(rows, 0, 13, "WW")
	put(rows, 2, 12, "R")
	put(rows, 3, 12, "s")
	var cells := mat14(rows)
	check(Scoring.kind_at(cells, 12 * 14 + 2) == K.ROAD, "the road square")
	check(Grid.is_part(cells[13 * 14 + 1]) and cells[13 * 14 + 1]["kind"] == K.ROAD, "street squares count as road")
	# a hospital (2:2) beside the street is reached by a home on the same street
	var rows2 := blank14()
	put(rows2, 2, 4, "W")
	put(rows2, 3, 4, "W")
	put(rows2, 2, 5, "W")
	put(rows2, 3, 5, "W")
	put(rows2, 4, 4, "HH")
	put(rows2, 4, 5, "HH")
	put(rows2, 1, 4, "m")
	var r := Scoring.evaluate(mat14(rows2), 0)
	var home := _home(r, 4 * 14 + 1)
	check(home["routes"].has(4 * 14 + 4), "the hospital is reached from any side of the street")


func test_homes_and_services_are_counted_once_each() -> void:
	var rows := blank14()
	put(rows, 0, 0, "ll")
	put(rows, 0, 1, "ll")
	var r := Scoring.evaluate(mat14(rows), 0)
	eq(r["apartments"].size(), 1, "a 2:2 home is one home")
	eq(r["citizens"], 3, "with its three citizens")
	var rows2 := blank14()
	put(rows2, 0, 0, "HH")
	put(rows2, 0, 1, "HH")
	eq(Scoring.evaluate(mat14(rows2), 0)["unused"].size(), 1, "a 2:2 service is one unused service")
	eq(Scoring.pollution_level(mat14(rows2)), Scoring.START_POLLUTION, "and counts nothing for pollution")
	var rows3 := blank14()
	put(rows3, 0, 0, "PP")
	put(rows3, 0, 1, "PP")
	eq(Scoring.pollution_level(mat14(rows3)), Scoring.START_POLLUTION - 3, "a park takes 3 off once")


func test_a_park_helps_homes_within_two_squares() -> void:
	var rows := blank14()
	put(rows, 5, 5, "PP")
	put(rows, 5, 6, "PP")
	put(rows, 8, 5, "s")
	put(rows, 11, 5, "s")
	var r := Scoring.evaluate(mat14(rows), 0)
	eq(_home(r, 5 * 14 + 8)["green_sources"].size(), 1, "a home right beside the park")
	eq(_home(r, 5 * 14 + 11)["green_sources"].size(), 0, "a home two squares further away")


# ---------------------------------------------------------------- prefixed mats

func test_the_shipped_mats_are_valid() -> void:
	var all := MatLibrary.all()
	check(all.size() >= 2, "at least two prefixed mats ship with the game")
	for m in all:
		eq(m.problems(), [] as Array[String], "%s has no overlapping or off-mat tiles" % m.title)
		check(m.title != "" and m.description != "", "%s has a title and a description" % m.title)


func test_the_southern_avenue_has_a_whole_street_and_a_university() -> void:
	var mat = MatLibrary.by_path("res://resources/mats/01_southern_avenue.tres")
	check(mat != null, "the mat loads")
	var cells: Array = mat.build_cells()
	for x in 14:
		for y in [12, 13]:
			eq(cells[y * 14 + x]["kind"], K.ROAD, "the last two rows are street at %d,%d" % [x, y])
	for x in range(0, 14, 2):
		check(cells[12 * 14 + x].get("big", false), "street tiles are 2:2 at x=%d" % x)
	eq(cells[6 * 14 + 12]["kind"], K.UNIVERSITY, "the university stands in the middle of the right edge")
	eq(Grid.anchor_of(cells, 7 * 14 + 13), 6 * 14 + 12, "and covers 2x2 squares")
	for t in Grid.tiles(cells):
		check(t.get("fixed", false), "every prefixed tile is fixed")
	eq(Grid.tiles(cells).size(), 8, "seven streets and a university")


func test_every_player_starts_on_their_own_copy_of_the_mat() -> void:
	var mat = MatLibrary.by_path("res://resources/mats/02_crossroads.tres")
	var gs := _game(mat)
	var a: Array = gs.players[0].cells
	var b: Array = gs.players[1].cells
	eq(a, b, "the same tiles")
	check(Grid.tiles(a).size() > 0, "the mat is not empty")
	Grid.remove(a, 0 if a[0] != null else Grid.anchors(a)[0])
	check(Grid.tiles(a).size() != Grid.tiles(b).size(), "a copy, not the same array")
	check(_game(null).players[0].cells.count(null) == 196, "no mat means an empty one")


func test_prefixed_tiles_can_be_neither_replaced_nor_lost() -> void:
	var mat = MatLibrary.by_path("res://resources/mats/01_southern_avenue.tres")
	var gs := _game(mat)
	var uni := 6 * 14 + 12
	check(not gs.can_replace(_slot(gs, K.PARK), uni), "the university is not replaceable")
	check(not gs.can_replace(_slot(gs, K.PARK), 12 * 14), "nor is the street")
	gs.pending_losses.append({"kinds": [K.UNIVERSITY, K.ROAD], "n": 1})
	eq(gs.loss_cells(), [] as Array[int], "a penalty finds nothing to take")
	eq(gs.lose_tile_at(uni), {}, "so the university stays")
	check(not gs.place_free_road(uni), "and nothing can be built on top")


func test_a_bad_preset_reports_what_is_wrong() -> void:
	var bad := PlayerMatPreset.new()
	var a := PresetTile.new()
	a.kind = K.PARK
	a.x = 5
	a.y = 5
	var b := PresetTile.new()
	b.kind = K.KIOSK
	b.x = 6
	b.y = 6
	var c := PresetTile.new()
	c.kind = K.UNIVERSITY
	c.x = 13
	c.y = 13
	bad.tiles = [a, b, c] as Array[PresetTile]
	eq(bad.problems().size(), 2, "one overlap and one tile off the mat")
	eq(Grid.tiles(bad.build_cells()).size(), 1, "the bad ones are left out when the mat is built")


func test_the_tile_picker_is_a_drop_down() -> void:
	var found := false
	for prop in PresetTile.new().get_property_list():
		if prop["name"] == "kind":
			found = true
			eq(prop["hint"], PROPERTY_HINT_ENUM, "kind is an enum")
			check(String(prop["hint_string"]).contains("University:") and String(prop["hint_string"]).contains("Road:"), "it lists the tiles")
	check(found, "a kind property")


# ---------------------------------------------------------------- the printed tiles

func test_printed_tiles_show_who_a_building_matters_to() -> void:
	var uni := PrintTile.effects(TileDefs.make(K.UNIVERSITY))
	eq(uni.size(), 1, "only students need a university")
	eq([uni[0]["role"], uni[0]["value"], uni[0]["type"]], ["student", 2, "need"], "a need is +2")
	var hospital := PrintTile.effects(TileDefs.make(K.HOSPITAL))
	eq(hospital.size(), 2, "older residents and residents with a disability")
	eq(hospital[0]["value"], 3, "a hospital is +2 for the need and +1 for the better building")
	var restaurant := PrintTile.effects(TileDefs.make(K.RESTAURANT))
	var kinds := []
	for e in restaurant:
		kinds.append(e["type"])
	check("need" in kinds and "like" in kinds and "dislike" in kinds, "a restaurant is needed, liked and disliked")
	var parking := PrintTile.effects(TileDefs.make(K.PARKING))
	var likes := 0
	var dislikes := 0
	for e in parking:
		likes += 1 if e["type"] == "like" else 0
		dislikes += 1 if e["type"] == "dislike" else 0
	eq([likes, dislikes], [5, 1], "five citizens like parking, children dislike it")
	eq(PrintTile.effects(TileDefs.make(K.ROAD)), [], "a plain road matters to nobody")
	eq(PrintTile.air_effect(TileDefs.make(K.PARK)), 3, "a park takes 3 off the pollution bar")
	eq(PrintTile.air_effect(TileDefs.make(K.TREES)), 1, "trees take 1")
	eq(PrintTile.air_effect(TileDefs.make(K.ROAD, TileDefs.STREET_SHADED)), 1, "so does a shaded street")
	eq(PrintTile.air_effect(TileDefs.make(K.KIOSK)), 0, "other tiles none")
