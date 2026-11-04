extends "res://tests/test_base.gd"
## Mats made in the mat editor: saving, loading, the game starting on one, deleting. Everything a test saves is deleted again.

const CustomMats = preload("res://scripts/core/custom_mats.gd")
const MatLibrary = preload("res://scripts/core/mat_library.gd")
const GameState = preload("res://scripts/core/game_state.gd")

const K := TileDefs.Kind

var _made: Array[String] = []


func _tiles() -> Array:
	return [
		{"kind": K.ROAD, "x": 0, "y": 6, "variant": 0, "large": true},
		{"kind": K.ROAD, "x": 2, "y": 6, "variant": 1, "large": false},
		{"kind": K.APT_S, "x": 5, "y": 1, "variant": 2, "large": false},
		{"kind": K.PARK, "x": 8, "y": 8, "variant": 0, "large": false},
	]


func _save(title: String, tiles: Array, path := "") -> String:
	var p := CustomMats.save(title, tiles, path)
	if path == "":
		_made.append(p)
	return p


## The runner has no teardown, so every test ends with this.
func _cleanup() -> void:
	for p in _made:
		CustomMats.delete(p)
	_made.clear()


func test_a_saved_mat_comes_back_as_it_was() -> void:
	var path := _save("Test mat", _tiles())
	check(CustomMats.is_custom(path) and CustomMats.exists(path), "the mat is saved under a custom: path")
	var preset = CustomMats.load_preset(path)
	eq(preset.title, "Test mat", "the name")
	eq(preset.problems(), [] as Array[String], "no overlaps")
	var cells: Array = preset.build_cells()
	eq(Grid.tiles(cells).size(), 4, "every tile")
	check(cells[6 * 14].get("big", false) and cells[6 * 14]["kind"] == K.ROAD, "the 2:2 street is still 2:2")
	eq(cells[7 * 14 + 1]["kind"], K.ROAD, "and covers 2x2 squares")
	eq(cells[6 * 14 + 2].get("variant", 0), 1, "a shaded street keeps its type")
	eq(cells[1 * 14 + 5].get("variant", 0), 2, "a home keeps its household")
	check(cells[8 * 14 + 8].get("fixed", false), "the tiles are fixed, like every prefixed tile")
	_cleanup()


func test_a_game_can_start_on_a_custom_mat() -> void:
	var path := _save("Game mat", _tiles())
	var mat = MatLibrary.by_path(path)
	check(mat != null, "by_path finds custom mats")
	var gs := GameState.new()
	gs.setup(["Ana", "Ben"], [0, 1], 5, [], mat)
	eq(Grid.tiles(gs.players[0].cells).size(), 4, "the planner starts with the mat's tiles")
	var slot := 0
	for i in gs.shop.size():
		if gs.stack_count(i) > 0 and gs.shop[i]["tile"]["kind"] == K.PARK:
			slot = i
	check(not gs.can_replace(slot, 8 * 14 + 8), "and they can't be replaced")
	_cleanup()


func test_saving_again_overwrites_and_keeps_the_place_in_the_list() -> void:
	var a := _save("First", _tiles())
	var b := _save("Second", _tiles())
	var again := CustomMats.save("First, renamed", [_tiles()[0]], a)
	eq(again, a, "same path")
	var titles: Array = []
	for e in CustomMats.all():
		if e["path"] in _made:
			titles.append(e["title"])
	eq(titles, ["First, renamed", "Second"], "still listed before the later one")
	eq(Grid.tiles(CustomMats.load_preset(a).build_cells()).size(), 1, "with the new tiles")
	check(CustomMats.exists(b), "the other mat is untouched")
	_cleanup()


func test_deleting_removes_the_mat() -> void:
	var path := _save("Gone soon", _tiles())
	check(CustomMats.delete(path), "delete says it worked")
	check(not CustomMats.exists(path), "the file is gone")
	check(CustomMats.load_preset(path) == null and MatLibrary.by_path(path) == null, "nothing loads from the path")
	check(not CustomMats.delete(path), "deleting twice reports failure")
	_cleanup()


func test_the_shipped_mats_cannot_be_deleted_here() -> void:
	check(not CustomMats.delete("res://resources/mats/some_game_mat.tres"), "a game mat is not a custom mat")
	check(not CustomMats.delete("custom:../../project"), "paths that are not ids are refused")
	eq(MatLibrary.DEFAULT, "", "the game starts on the empty mat")
	check(MatLibrary.by_path(MatLibrary.DEFAULT) == null, "which has no preset")
	for m in MatLibrary.all():
		check(not CustomMats.is_custom(m.resource_path), "the game mats list never holds custom mats")
	_cleanup()


func test_names_are_cleaned_and_made_unique() -> void:
	eq(CustomMats.clean_name("   "), "My mat", "an empty name gets a default")
	eq(CustomMats.clean_name("A".repeat(60)).length(), CustomMats.MAX_NAME, "long names are cut")
	var p := _save("My mat", _tiles())
	check(p != "", "saved")
	check(CustomMats.free_name().to_lower() != "my mat", "a name that is already used is not offered again")
	_cleanup()


func test_a_broken_file_is_skipped() -> void:
	DirAccess.make_dir_recursive_absolute(CustomMats.DIR)
	var f := FileAccess.open(CustomMats.DIR + "/m1.json", FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	for e in CustomMats.all():
		check(e["id"] != "m1", "the broken file is not listed")
	DirAccess.remove_absolute(CustomMats.DIR + "/m1.json")
	_cleanup()


func test_the_editor_converts_cells_both_ways() -> void:
	var path := _save("Round trip", _tiles())
	var cells: Array = CustomMats.load_preset(path).build_cells()
	var tiles := CustomMats.tiles_from_cells(cells)
	eq(tiles.size(), 4, "one entry per tile, parts left out")
	eq(CustomMats.free_squares(cells), 196 - (4 + 1 + 1 + 4), "free squares count every covered square")
	var min_free := CustomMats.MIN_FREE
	check(min_free > 0 and min_free < 196, "a sensible minimum of free squares")
	_cleanup()
