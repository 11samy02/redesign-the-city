extends Node
## Drives the map picker and the mat editor with real mouse events: opens the popup, builds a mat with a 2:2 street,
## saves it, finds it in the list, edits it, deletes it. Started by the Game autoload:
##   godot --path . --resolution 1600x900 -- --probe=matedit [--out=<dir>]
## Exit code 1 when something fails. The mats it saves are deleted again.

const CustomMats = preload("res://scripts/core/custom_mats.gd")
const MatLibrary = preload("res://scripts/core/mat_library.gd")
const MatEditor = preload("res://scripts/ui/mat_editor.gd")
const MatPicker = preload("res://scripts/ui/mat_picker.gd")
const MatView = preload("res://scripts/ui/mat_view.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Grid = preload("res://scripts/core/grid.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")

var _failures: Array[String] = []
var _out := ""
var _before_setting := ""


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
		print("MATEDIT FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if _out != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	get_viewport().push_input(e, true)


func _button(p: Vector2, index: int, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = index
	e.pressed = down
	e.button_mask = (1 << (index - 1)) if down else 0
	get_viewport().push_input(e, true)


func _click(p: Vector2, index := MOUSE_BUTTON_LEFT) -> void:
	_move(p)
	await _frames(2)
	_button(p, index, true)
	await _frames(2)
	_button(p, index, false)
	await _frames(3)


func _find_button(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null


func _find_tip(root: Node, tip: String) -> Control:
	for c in root.find_children("*", "Control", true, false):
		if c.tooltip_text == tip and c.is_visible_in_tree():
			return c
	return null


func _find_class(root: Node, script: Script) -> Control:
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() == script:
			return c
	return null


## Centre of square (x, y) of the board, even where a bigger tile covers it.
func _sq(m: MatView, x: int, y: int) -> Vector2:
	return m.get_global_rect().position + m.cell_pos(Grid.index_of(x, y)) + Vector2(m.cell, m.cell) / 2.0


func _centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _run() -> void:
	Sfx.muted = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_out)
	_before_setting = Game.settings["mat"]
	var existing := CustomMats.all().size()
	get_tree().change_scene_to_file(Game.TITLE_SCENE)
	await _frames(90)
	await get_tree().create_timer(2.0).timeout
	var title := get_tree().current_scene
	_shot("1_title")

	# open the picker with a real click
	var select := _find_button(title, "Select map")
	_check(select != null, "title has a Select map button")
	if select == null:
		return _end()
	await _click(_centre(select))
	await _frames(30)
	var picker: MatPicker = _find_class(title, MatPicker)
	_check(picker != null, "the picker opens")
	if picker == null:
		return _end()
	_shot("2_picker")
	_check(picker._cards.size() == MatLibrary.all().size() + 1, "the game mats tab holds the empty mat and what ships, got %d" % picker._cards.size())
	_check(MatLibrary.all().is_empty(), "the game ships no prefixed mats")
	_check(Game.settings["mat"] == "" and picker._cards.has(""), "the empty mat is the one in use")
	for p in picker._cards:
		_check(picker._cards[p].find_children("*", "Button", true, false).is_empty(), "game mats have no edit or delete button")

	# the tabs: the game mats are open, the custom ones are one click away
	_check(picker._tab == 0, "the picker opens on Game mats when a game mat is in use")
	var mine_tab := _find_button(picker, "Your mats  %d" % existing)
	_check(mine_tab != null, "a Your mats tab")
	await _click(_centre(mine_tab))
	await _frames(5)
	_check(picker._tab == 1, "clicking the tab opens Your mats")
	_shot("2b_picker_your_mats")

	# New mat
	var add := _find_tip(picker, "Build your own mat in the editor")
	_check(add != null, "the New mat card exists")
	await _click(_centre(add))
	await _frames(40)
	var ed: MatEditor = _find_class(title, MatEditor)
	_check(ed != null, "the editor opens")
	if ed == null:
		return _end()
	_shot("3_editor_empty")
	_check(ed._save_btn.disabled, "Save is off while the mat is empty")

	# a 2:2 street: entry 1 is the plain road as a 2:2 piece
	await _click(_centre(ed._palette_cells[1]))
	_check(ed._sel == 1 and TileDefs.footprint(ed._entry_tile()) == 2, "the 2:2 street is selected")
	var m: MatView = ed._mat
	await _click(_sq(m, 2, 2))
	_check(ed.cells[Grid.index_of(2, 2)] != null and ed.cells[Grid.index_of(2, 2)].get("big", false), "a click places a 2:2 street")
	_check(ed.cells[Grid.index_of(3, 3)] != null and ed.cells[Grid.index_of(3, 3)].has("part"), "it covers 2x2 squares")
	_check(ed._sel == 1, "the selected tile stays selected after placing it")
	_check(ed._ghost.visible, "and its ghost is still on the board")
	# regression: a small road dropped on one square of the 2:2 street replaces the whole street, nothing is left behind
	await _click(_centre(ed._palette_cells[0]))
	await _click(_sq(m, 3, 3))
	_check(ed.cells[Grid.index_of(2, 2)] == null and ed.cells[Grid.index_of(3, 2)] == null and ed.cells[Grid.index_of(2, 3)] == null, "the rest of the street is gone")
	_check(ed.cells[Grid.index_of(3, 3)] != null and not ed.cells[Grid.index_of(3, 3)].has("part"), "and the small road is there")
	_check(ed._sel == 0, "the road stays selected")
	ed._undo_last()
	await _frames(2)
	_check(ed.cells[Grid.index_of(2, 2)] != null and ed.cells[Grid.index_of(3, 3)].has("part"), "undo brings the 2:2 street back whole")
	await _click(_sq(m, 3, 3), MOUSE_BUTTON_RIGHT)
	for i in Grid.CELLS:
		_check(ed.cells[i] == null, "erasing a street square clears all four (square %d)" % i)
	ed._undo_last()
	await _frames(2)
	# drag-paint a row of small roads along row 8
	await _click(_centre(ed._palette_cells[0]))
	var y := 8
	var start := _sq(m, 1, y)
	_move(start)
	await _frames(2)
	_button(start, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	for x in range(2, 9):
		_move(_centre(m.views[Grid.index_of(x, y)]))
		await _frames(2)
	_button(_sq(m, 8, y), MOUSE_BUTTON_LEFT, false)
	await _frames(3)
	var painted := 0
	for x in 14:
		if ed.cells[Grid.index_of(x, y)] != null:
			painted += 1
	_check(painted == 8, "dragging paints a row of 8 roads, got %d" % painted)
	# a park (2:2) over the street replaces what it covers
	var park_entry := -1
	for i in ed._entries.size():
		if ed._entries[i]["kind"] == TileDefs.Kind.PARK:
			park_entry = i
	ed._select(park_entry)   # the Green section is below the visible part of the palette
	await _click(_sq(m, 2, 2))
	_check(ed.cells[Grid.index_of(2, 2)]["kind"] == TileDefs.Kind.PARK, "a tile placed on another replaces it")
	# a building next to it, to see the art
	ed._select(park_entry - 3)
	await _click(_sq(m, 8, 3))
	_move(_sq(m, 10, 5))
	await _frames(4)
	_shot("4_editor_built")
	# right-click erases
	await _click(_sq(m, 5, y), MOUSE_BUTTON_RIGHT)
	_check(ed.cells[Grid.index_of(5, y)] == null, "right-click erases")
	ed._undo_last()
	_check(ed.cells[Grid.index_of(5, y)] != null, "undo puts the road back")
	_check(not ed._save_btn.disabled, "Save is on once there are tiles")
	var tiles_now := Grid.tiles(ed.cells).size()

	# name and save
	ed._name.text = "Probe mat"
	await _click(_centre(ed._save_btn))
	await _frames(40)
	var saved := CustomMats.all()
	_check(saved.size() == existing + 1, "one mat was saved")
	var path := ""
	for e in saved:
		if e["title"] == "Probe mat":
			path = e["path"]
	_check(path != "", "the saved mat has the name typed in")
	if path != "":
		var cells: Array = CustomMats.load_preset(path).build_cells()
		_check(Grid.tiles(cells).size() == tiles_now, "the saved mat holds every tile")
		_check(cells[Grid.index_of(2, 2)]["kind"] == TileDefs.Kind.PARK and cells[Grid.index_of(2, 2)]["fixed"], "tiles come back fixed")
	await _frames(30)
	var picker2: MatPicker = _find_class(title, MatPicker)
	_check(picker2 != null, "the picker is back after saving")
	if picker2 != null and path != "":
		_check(picker2._cards.has(path), "the new mat is in the list")
		_shot("5_picker_with_custom")
		await _click(_centre(picker2._cards[path]) + Vector2(0, 40))
		await _frames(30)
		_check(Game.settings["mat"] == path, "clicking the card selects the mat")
		_check(picker2.is_inside_tree() and not picker2._done, "and the popup stays open")
		_check(picker2.current == path, "with the card marked in use")
		_shot("6_picked_popup_open")
		await _click(_centre(_find_button(picker2, "Close")))
		await _frames(30)
		_check(_find_class(title, MatPicker) == null, "Close closes it")
		_shot("6_title_selected")
		var gs := GameState.new()
		gs.setup(["A", "B"], [0, 1], -1, [0, 0], MatLibrary.by_path(path))
		_check(Grid.tiles(gs.players[0].cells).size() == tiles_now, "a game starts on the custom mat")

	# open the picker again: edit, cancel, delete
	select = _find_button(title, "Select map")
	await _click(_centre(select))
	await _frames(30)
	picker = _find_class(title, MatPicker)
	_check(picker != null and picker._tab == 1, "the picker opens on Your mats when a custom mat is in use")
	var edit_btn: Control = null
	if picker != null and picker._cards.has(path):
		for b in picker._cards[path].find_children("*", "Button", true, false):
			if b.tooltip_text == "Edit this mat":
				edit_btn = b
	_check(edit_btn != null, "a custom card has an Edit button")
	if edit_btn != null:
		print("MATEDIT edit button at ", edit_btn.get_global_rect(), " visible ", edit_btn.is_visible_in_tree())
		await _click(_centre(edit_btn))
		await _frames(40)
		print("MATEDIT after edit click: picker in tree ", is_instance_valid(picker) and picker.is_inside_tree(), " mat setting ", Game.settings["mat"], " editor ", _find_class(title, MatEditor))
		ed = _find_class(title, MatEditor)
		_check(ed != null and ed._name.text == "Probe mat", "Edit opens the editor on that mat")
		if ed != null:
			_check(Grid.tiles(ed.cells).size() == tiles_now, "with its tiles")
			_shot("7_editing")
			await _click(_centre(_find_button(ed, "Cancel")))
			await _frames(30)
	picker = _find_class(title, MatPicker)
	_check(picker != null, "the picker is back after cancelling")
	if picker != null and picker._cards.has(path):
		var del_btn: Control = null
		for b in picker._cards[path].find_children("*", "Button", true, false):
			if b.tooltip_text == "Delete this mat":
				del_btn = b
		_check(del_btn != null, "a custom card has a Delete button")
		if del_btn != null:
			await _click(_centre(del_btn))
			await _frames(30)
			_shot("8_delete_ask")
			var yes := _find_button(picker, "Delete mat")
			_check(yes != null, "deleting asks first")
			if yes != null:
				await _click(_centre(yes))
				await _frames(40)
				_check(CustomMats.all().size() == existing, "the mat is gone from disk")
				_check(not picker._cards.has(path), "and from the list")
				_check(Game.settings["mat"] == MatLibrary.DEFAULT, "deleting the mat in use falls back to the default mat")
				_shot("9_picker_after_delete")
	_end()


func _end() -> void:
	for e in CustomMats.all():
		if e["title"] == "Probe mat":
			CustomMats.delete(e["path"])
	Game.set_setting("mat", _before_setting)
	for f in _failures:
		print("MATEDIT FAIL ", f)
	print("MATEDIT probe done, %d failure(s)" % _failures.size())
	get_tree().quit(1 if not _failures.is_empty() else 0)
