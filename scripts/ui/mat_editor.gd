extends Control
## The mat editor: a full-screen workshop for building a player mat of your own. There is no money and no
## shop: pick any tile on the left, click the 14 x 14 board to place it, drag to paint, right-click to erase.
## Streets come as 1:1 and as big 2:2 pieces. Name the mat and save it; it then shows up in the map picker.
##
## Emits `finished({"saved": bool, "path": String})` once.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Grid = preload("res://scripts/core/grid.gd")
const MatView = preload("res://scripts/ui/mat_view.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const CustomMats = preload("res://scripts/core/custom_mats.gd")
const Modal = preload("res://scripts/ui/modal.gd")

signal finished(result: Dictionary)

const CELL := 48.0
const GAP := 2.0
const PALETTE_CELL := 58.0
const PALETTE_COLUMNS := 5
const UNDO_LIMIT := 60

## The custom mat being edited ("custom:<id>"), or "" for a new one. Set before the editor is added.
var edit_path := ""

var _mat: MatView
var _ghost: TileView
var _name: LineEdit
var _save_btn: Button
var _undo_btn: Button
var _clear_btn: Button
var _place_btn: Button
var _erase_btn: Button
var _info: VBoxContainer
var _stats: VBoxContainer
var _palette_cells: Array = []

var cells: Array = Grid.empty()
var _initial: Array = []
var _initial_name := ""
var _undo: Array = []
var _entries: Array = []
var _sel := 0
var _erase := false
var _cursor := -1
var _stroke_before = null
var _stroke_erase := false
var _last_applied := -1
var _done := false
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UiKit.INK_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title_text := "New mat"
	if edit_path != "":
		var preset = CustomMats.load_preset(edit_path)
		if preset != null:
			cells = preset.build_cells()
			title_text = preset.title
	else:
		title_text = CustomMats.free_name()
	_initial = cells.duplicate(true)
	_initial_name = title_text

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	root.add_child(_build_header(title_text))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_build_palette())
	var mid := CenterContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(mid)
	_mat = MatView.new()
	_mat.setup(CELL, GAP, TileView.Mode.MINI, true)
	mid.add_child(_mat)
	_ghost = TileView.new()
	_ghost.mode = TileView.Mode.MINI
	_ghost.interactive = false
	_ghost.visible = false
	_ghost.z_index = 30
	_ghost.modulate.a = 0.82
	_mat.add_child(_ghost)
	body.add_child(_build_side())

	_select(0)
	_refresh()

	modulate.a = 0.0
	await get_tree().process_frame
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	UiKit.play_sfx("whoosh")


# ---------------------------------------------------------------- layout

func _build_header(title_text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var t := UiKit.label("Mat editor", 36, UiKit.LIMESTONE, "display_bold")
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	_name = LineEdit.new()
	_name.text = title_text
	_name.placeholder_text = "Name your mat"
	_name.max_length = CustomMats.MAX_NAME
	_name.custom_minimum_size.x = 320
	_name.select_all_on_focus = true
	_name.tooltip_text = "The name shown in the map picker"
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name.text_submitted.connect(func(_t): _name.release_focus())
	h.add_child(_name)
	h.add_child(UiKit.spacer())
	_undo_btn = UiKit.button("Undo", "ghost", 18)
	_undo_btn.pressed.connect(_undo_last)
	h.add_child(_undo_btn)
	_clear_btn = UiKit.button("Clear mat", "ghost", 18)
	_clear_btn.pressed.connect(_clear)
	h.add_child(_clear_btn)
	var cancel := UiKit.button("Cancel", "secondary", 19)
	cancel.pressed.connect(_cancel)
	h.add_child(cancel)
	_save_btn = UiKit.button("Save mat", "primary", 20)
	_save_btn.pressed.connect(_save)
	h.add_child(_save_btn)
	return h


func _build_palette() -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size.x = PALETTE_COLUMNS * PALETTE_CELL + (PALETTE_COLUMNS - 1) * 8 + 24 + 36
	pc.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 22, 1, UiKit.LINE, 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	_place_btn = UiKit.button("Place", "primary", 17)
	_place_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_place_btn.tooltip_text = "Click or drag on the board to build"
	_place_btn.pressed.connect(func(): _set_erase(false))
	tools.add_child(_place_btn)
	_erase_btn = UiKit.button("Erase", "secondary", 17)
	_erase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_erase_btn.tooltip_text = "Click or drag to remove tiles. Right-click erases in any mode."
	_erase_btn.pressed.connect(func(): _set_erase(true))
	tools.add_child(_erase_btn)
	v.add_child(tools)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for g in _groups():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		box.add_child(UiKit.label(g["name"], 19, UiKit.LIMESTONE, "display_bold"))
		var grid := GridContainer.new()
		grid.columns = PALETTE_COLUMNS
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for e in g["entries"]:
			var k := _entries.size()
			_entries.append(e)
			var cell := PaletteCell.new()
			cell.setup(_tile_of(e), PALETTE_CELL, _tip(e))
			cell.activated.connect(func(): _select(k, true))
			_palette_cells.append(cell)
			grid.add_child(cell)
		box.add_child(grid)
		list.add_child(box)
	return pc


func _build_side() -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size.x = 300
	pc.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 22, 1, UiKit.LINE, 18))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	pc.add_child(v)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 8)
	v.add_child(_info)
	v.add_child(_rule())
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 6)
	v.add_child(_stats)
	v.add_child(UiKit.spacer(true))
	v.add_child(_rule())
	var tips := VBoxContainer.new()
	tips.add_theme_constant_override("separation", 8)
	for t in [["Click", "place the tile"], ["Drag", "paint a row"], ["Right-click", "erase a tile"], ["Ctrl+Z", "undo"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UiKit.keycap(t[0]))
		row.add_child(UiKit.label(t[1], 15, UiKit.MUTED))
		tips.add_child(row)
	v.add_child(tips)
	return pc


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(UiKit.LINE, 0.7)
	r.custom_minimum_size.y = 1
	return r


## Palette sections: streets first (1:1 and 2:2 of every street type), then the shop sections. Homes are one tile
## per household, because the household decides who lives there.
func _groups() -> Array:
	var order: Array = [TileDefs.GROUPS.size() - 1]
	for g in TileDefs.GROUPS.size() - 1:
		order.append(g)
	var out: Array = []
	for gi in order:
		var group: Dictionary = TileDefs.GROUPS[gi]
		var entries: Array = []
		for kind in group["kinds"]:
			if kind == TileDefs.Kind.ROAD:
				for v in TileDefs.STREETS.size():
					entries.append({"kind": kind, "variant": v, "big": false})
					entries.append({"kind": kind, "variant": v, "big": true})
			elif TileDefs.HOUSEHOLDS.has(kind):
				for v in TileDefs.HOUSEHOLDS[kind].size():
					entries.append({"kind": kind, "variant": v, "big": false})
			else:
				entries.append({"kind": kind, "variant": 0, "big": false})
		out.append({"name": group["name"], "entries": entries})
	return out


func _tile_of(e: Dictionary) -> Dictionary:
	var tile := TileDefs.make(e["kind"], e["variant"])
	if e["big"]:
		tile["big"] = true
	return tile


func _tip(e: Dictionary) -> String:
	var tile := _tile_of(e)
	var t := TileDefs.display_name(tile)
	if TileDefs.is_home(e["kind"]):
		t += ": " + TileDefs.household_name(tile)
	return "%s  (%s)" % [t, TileDefs.size_label(tile)]


# ---------------------------------------------------------------- tools and selection

func _select(k: int, announce := false) -> void:
	_sel = k
	for i in _palette_cells.size():
		_palette_cells[i].selected = i == k
	if announce:
		UiKit.play_sfx("pick")
	_set_erase(false)
	_fill_info()


func _set_erase(on: bool) -> void:
	_erase = on
	UiKit.style_button(_place_btn, "secondary" if on else "primary")
	UiKit.style_button(_erase_btn, "primary" if on else "secondary")
	for c in _palette_cells:
		c.dimmed = on
		c.queue_redraw()
	_update_hover()


func _fill_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	var tile := _tile_of(_entries[_sel])
	var art := UiKit.icon(TileDefs.art_path(tile), 132)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_info.add_child(art)
	var name := UiKit.label(TileDefs.display_name(tile), 24, UiKit.LIMESTONE, "display_bold")
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_child(name)
	var n := TileDefs.footprint(tile)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	chips.add_child(UiKit.chip("%s  %d square%s" % [TileDefs.size_label(tile), n * n, "" if n == 1 else "s"], UiKit.PANEL_HI))
	_info.add_child(chips)
	var text := ""
	if TileDefs.is_home(tile["kind"]):
		text = "Home of: %s." % TileDefs.household_name(tile)
	elif tile["kind"] == TileDefs.Kind.ROAD:
		text = TileDefs.STREETS[tile["variant"]]["effect"]
	else:
		text = TileDefs.DEFS[tile["kind"]]["effect"]
	var d := UiKit.label(text, 15, UiKit.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 250
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_child(d)


func _fill_stats() -> void:
	for c in _stats.get_children():
		c.queue_free()
	var free := CustomMats.free_squares(cells)
	var ok := free >= CustomMats.MIN_FREE
	_stats.add_child(_stat("Tiles on the mat", str(Grid.tiles(cells).size()), UiKit.LIMESTONE))
	_stats.add_child(_stat("Free squares", "%d of %d" % [free, Grid.CELLS], UiKit.OLIVE if ok else UiKit.HEAT))
	if not ok:
		var w := UiKit.label("Keep %d squares free, so there is room to build." % CustomMats.MIN_FREE, 14, UiKit.HEAT)
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.custom_minimum_size.x = 250
		_stats.add_child(w)


func _stat(label: String, value: String, color: Color) -> Control:
	var h := HBoxContainer.new()
	var l := UiKit.label(label, 17, UiKit.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UiKit.label(value, 19, color, "display_bold"))
	return h


# ---------------------------------------------------------------- editing

func _entry_tile() -> Dictionary:
	return _tile_of(_entries[_sel])


## Empties every square of the tile that covers square `sq`. Grid.remove can't be used here: a part of a 2:2 street does
## not know it is big (only the top-left square does), so it would clear one square and leave the rest of the street behind.
static func clear_tile(arr: Array, sq: int) -> void:
	var a := Grid.anchor_of(arr, sq)
	if a < 0:
		return
	for c in Grid.footprint(a, TileDefs.footprint(arr[a])):
		arr[c] = null


## Puts the selected tile on the board with its top-left square near `cell`. Whatever it covers is replaced.
func _place_at(cell: int) -> void:
	var tile := _entry_tile()
	var n := TileDefs.footprint(tile)
	var anchor := Grid.ghost_anchor(cell, n)
	if anchor == _last_applied:
		return
	_last_applied = anchor
	var cur = cells[anchor]
	if cur != null and not cur.has("part") and cur["kind"] == tile["kind"] and cur.get("variant", 0) == tile["variant"] and TileDefs.footprint(cur) == n:
		return
	for sq in Grid.footprint(anchor, n):
		if cells[sq] != null:
			clear_tile(cells, sq)
	Grid.place(cells, anchor, tile)
	UiKit.play_sfx("place")


func _erase_at(cell: int) -> void:
	if cell == _last_applied or cells[cell] == null:
		return
	_last_applied = cell
	clear_tile(cells, cell)
	UiKit.play_sfx("click")


func _apply(cell: int, erase: bool) -> void:
	if cell < 0:
		return
	if erase:
		_erase_at(cell)
	else:
		_place_at(cell)
	_refresh()


func _begin_stroke(right: bool, square: int) -> void:
	if _done or _busy or square < 0:
		return
	_name.release_focus()
	_stroke_before = cells.duplicate(true)
	_stroke_erase = right or _erase
	_last_applied = -1
	_cursor = square
	_apply(_cursor, _stroke_erase)


func _end_stroke() -> void:
	if _stroke_before == null:
		return
	if _stroke_before != cells:
		_undo.append(_stroke_before)
		if _undo.size() > UNDO_LIMIT:
			_undo.pop_front()
	_stroke_before = null
	_stroke_erase = false
	_refresh()


## The board square a mouse event points at, or -1 outside the squares.
func _square_of(event: InputEventMouse) -> int:
	return _mat.square_at(_mat.get_global_rect().position + _mat.make_input_local(event).position)


func _undo_last() -> void:
	if _undo.is_empty() or _busy:
		return
	cells = _undo.pop_back()
	UiKit.play_sfx("click")
	_refresh()


func _clear() -> void:
	if _busy or Grid.tiles(cells).is_empty():
		return
	_undo.append(cells.duplicate(true))
	cells = Grid.empty()
	UiKit.play_sfx("whoosh")
	_refresh()


func _refresh() -> void:
	_mat.refresh(cells, Scoring.evaluate(cells, 0))
	_fill_stats()
	var any := not Grid.tiles(cells).is_empty()
	var free_ok := CustomMats.free_squares(cells) >= CustomMats.MIN_FREE
	_undo_btn.disabled = _undo.is_empty()
	_clear_btn.disabled = not any
	_save_btn.disabled = not any or not free_ok
	_save_btn.tooltip_text = "" if not _save_btn.disabled else ("Place at least one tile." if not any else "Leave %d squares free." % CustomMats.MIN_FREE)
	_update_hover()


## The ghost tile and the marks on what it would replace, for the square under the mouse.
func _update_hover() -> void:
	if _mat == null:
		return
	_mat.set_highlights({})
	_ghost.visible = false
	var cell := _cursor
	if cell < 0 or _busy:
		return
	if _erase or _stroke_erase:
		if cells[cell] != null:
			_mat.set_highlights({cell: Color(UiKit.HEAT, 0.95)})
		return
	var tile := _entry_tile()
	var n := TileDefs.footprint(tile)
	var anchor := Grid.ghost_anchor(cell, n)
	var preview := cells.duplicate()
	var marks := {}
	for sq in Grid.footprint(anchor, n):
		if preview[sq] != null:
			marks[Grid.anchor_of(preview, sq)] = Color(UiKit.HEAT, 0.95)
			clear_tile(preview, sq)
	Grid.place(preview, anchor, tile.duplicate())
	_mat.set_highlights(marks)
	_ghost.tile = tile
	_ghost.road_mask = MatView.road_mask(preview, anchor) if tile["kind"] == TileDefs.Kind.ROAD else 15
	_ghost.road_stubs = MatView.big_road_links(preview, anchor)["stubs"] if (tile["kind"] == TileDefs.Kind.ROAD and n == 2) else []
	_ghost.position = _mat.cell_pos(anchor)
	_ghost.size = Vector2(_mat.span(n), _mat.span(n))
	_ghost.highlight = Color(UiKit.GOLD, 0.85)
	_ghost.visible = true
	_ghost.queue_redraw()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseMotion and not _busy:
		var sq := _square_of(event)
		if sq != _cursor:
			_cursor = sq
			if _stroke_before != null and sq >= 0:
				_apply(sq, _stroke_erase)
			else:
				_update_hover()
	elif event is InputEventMouseButton and not _busy and event.pressed and _stroke_before == null:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_begin_stroke(event.button_index == MOUSE_BUTTON_RIGHT, _square_of(event))
	elif event is InputEventMouseButton and not event.pressed:
		_end_stroke()


# ---------------------------------------------------------------- leaving

func _save() -> void:
	if _done or _busy or _save_btn.disabled:
		return
	var tiles := CustomMats.tiles_from_cells(cells)
	var path := CustomMats.save(_name.text if _name.text.strip_edges() != "" else _initial_name, tiles, edit_path)
	if path == "":
		_busy = true
		var m := Modal.make("Could not save", "The mat could not be written to disk. Check that the game may save files, then try again.",
			[["OK", "primary", true]])
		add_child(m)
		await m.chosen
		_busy = false
		return
	UiKit.play_sfx("start")
	_finish({"saved": true, "path": path})


func _dirty() -> bool:
	return cells != _initial or _name.text != _initial_name


func _cancel() -> void:
	if _done or _busy:
		return
	if not _dirty():
		_finish({"saved": false, "path": edit_path})
		return
	_busy = true
	_update_hover()
	var m := Modal.make("Leave the editor?", "Your changes to this mat are not saved.",
		[["Keep editing", "primary", false], ["Discard changes", "ghost", true]], "", 0)
	add_child(m)
	var leave: bool = await m.chosen
	_busy = false
	if leave:
		_finish({"saved": false, "path": edit_path})


func _finish(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	await tw.finished
	finished.emit(result)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _done or _busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var typing := get_viewport().gui_get_focus_owner() is LineEdit
		if event.keycode == KEY_ESCAPE:
			_cancel()
		elif event.keycode == KEY_Z and event.ctrl_pressed and not typing:
			_undo_last()
		elif event.keycode == KEY_S and event.ctrl_pressed:
			_save()
		else:
			return
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- palette cell

## One tile in the palette. Draws its own frame so a long list stays light and the mouse wheel keeps scrolling.
class PaletteCell extends Control:
	signal activated

	var tile: Dictionary
	var selected := false:
		set(v):
			selected = v
			queue_redraw()
	var dimmed := false
	var _hover := false

	func setup(p_tile: Dictionary, px: float, tip: String) -> void:
		tile = p_tile
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = tip
		accessibility_name = tip
		mouse_entered.connect(func():
			_hover = true
			UiKit.play_sfx("hover")
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			queue_redraw())

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := UiKit.PANEL_HI if not _hover else Color("#285C7E")
		var border := UiKit.LINE
		var w := 1
		if selected and not dimmed:
			border = UiKit.BOUG
			w = 3
			bg = Color("#285C7E")
		draw_style_box(UiKit.box(bg, 12, w, border), r)
		var art := r.grow(-6)
		var mod := Color(1, 1, 1, 0.45) if dimmed else Color.WHITE
		draw_texture_rect(UiKit.tex(TileDefs.art_path(tile)), art, false, mod)
		if TileDefs.footprint(tile) == 2:
			var f := UiKit.font("display_bold")
			var t := "2:2"
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8
			var pill := Rect2(Vector2(r.end.x - tw - 2, r.end.y - 18), Vector2(tw, 16))
			draw_style_box(UiKit.box(Color(UiKit.INK_DEEP, 0.92), 8), pill)
			draw_string(f, Vector2(pill.position.x + 4, pill.position.y + 12.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.GOLD)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			activated.emit()
