extends Control
## Close-up of one planner's city: hover a tile to see its effect and what it connects to.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const MatView = preload("res://scripts/ui/mat_view.gd")
const Tooltip = preload("res://scripts/ui/tooltip.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const Influence =preload("res://scripts/game/influence.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")

signal closed

var _player
var _result: Dictionary
var _tooltip: Tooltip
var _mat: MatView
var _done := false


func _init(player, result: Dictionary, tooltip: Tooltip) -> void:
	_player = player
	_result = result
	_tooltip = tooltip


func _ready() -> void:
	var dim := OverlayKit.fill_dimmed(self, 0.85)
	var col := UiKit.player_color(_player.color_index)
	var card := OverlayKit.add_card(self, OverlayKit.planner_card_style(col, 26, 28, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	card.add_child(h)
	_mat = MatView.new()
	# the whole mat has to fit the screen height, with room for the card's padding and border
	var gap := 8
	var cell := mini(118, int((get_viewport_rect().size.y - 140.0 - gap * (Scoring.SIZE - 1)) / Scoring.SIZE))
	_mat.setup(cell, gap, TileView.Mode.MAT)
	_mat.refresh(_player.cells, _result)
	_mat.cell_hovered.connect(_on_cell_hovered)
	h.add_child(_mat)
	h.add_child(_build_info(col))

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	Sfx.play("whoosh")
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())
	gui_input.connect(func(e):
		if e is InputEventKey and e.pressed and e.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
			_close())
	focus_mode = Control.FOCUS_ALL
	grab_focus()


func _build_info(col: Color) -> Control:
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 300
	info.add_theme_constant_override("separation", 10)
	var av := Widgets.Avatar.new(70)
	av.color = col
	av.letter = _player.name.substr(0, 1).to_upper()
	info.add_child(av)
	info.add_child(UiKit.label("%s's city" % _player.name, 34, col.lightened(0.2), "display_bold"))
	var r := _result
	var p = _player
	for line in [
		["%d gold" % p.money, UiKit.GOLD],
		["%s if the game ended now" % Describe.points(r["total"]), UiKit.LIMESTONE],
		["%d of %d citizens happy" % [r["happy_citizens"], r["citizens"]], UiKit.LIMESTONE],
		["Pollution %d" % r["pollution"], UiKit.MUTED],
		["%d free road%s, %d loan%s" % [p.free_roads, "" if p.free_roads == 1 else "s", p.loans, "" if p.loans == 1 else "s"], UiKit.MUTED],
	]:
		info.add_child(UiKit.label(line[0], 19, line[1]))
	info.add_child(UiKit.spacer(true))
	info.add_child(UiKit.label("Hover a tile to see its effect.", 15, UiKit.MUTED))
	var close := UiKit.button("Back to the game", "primary", 19)
	close.pressed.connect(_close)
	info.add_child(close)
	return info


func _on_cell_hovered(c: int, inside: bool) -> void:
	if inside and _player.cells[c] != null:
		Influence.show_for(_mat, _player.cells, _result, c)
		_tooltip.show_tile(_player.cells[c], _mat.cell_global_rect(c), Describe.cell_lines(_player.cells, _result, c), false, MatView.road_mask(_player.cells, c))
	else:
		_mat.clear_highlights()
		_tooltip.hide_tip()


func _close() -> void:
	if _done:
		return
	_done = true
	_tooltip.hide_tip()
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.15)
	await out.finished
	closed.emit()
	queue_free()
