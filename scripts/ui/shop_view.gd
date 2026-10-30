extends Control
## The shared 6x6 construction site.

const TileView = preload("res://scripts/ui/tile_view.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal slot_pressed(index: int)
signal slot_right_pressed(index: int)
signal slot_hovered(index: int, inside: bool)

const N := 6

var cell := 84.0
var gap := 8.0
var pad := 12.0
var views: Array = []


func setup(cell_size: float, cell_gap: float) -> void:
	cell = cell_size
	gap = cell_gap
	var side := N * cell + (N - 1) * gap + 2 * pad
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	for i in N * N:
		var v := TileView.new()
		v.mode = TileView.Mode.SHOP
		v.index = i
		v.position = Vector2(pad + (i % N) * (cell + gap), pad + (i / N) * (cell + gap))
		v.size = Vector2(cell, cell)
		v.pressed.connect(func(view): slot_pressed.emit(view.index))
		v.right_pressed.connect(func(view): slot_right_pressed.emit(view.index))
		v.hovered.connect(func(view, inside): slot_hovered.emit(view.index, inside))
		add_child(v)
		views.append(v)


func refresh(shop: Array, removed: Array, money: int, can_buy: bool) -> void:
	for i in views.size():
		var v = views[i]
		v.tile = shop[i]
		v.removed = removed[i]
		v.affordable = can_buy and shop[i] != null and money >= TileDefs.cost(shop[i]["kind"])
		v.interactive = shop[i] != null
		v.queue_redraw()


func set_selected(slot: int) -> void:
	for v in views:
		v.selected = v.index == slot


func set_keyboard_focus(at: int) -> void:
	for v in views:
		v.keyboard_focus = v.index == at


func _draw() -> void:
	var sb := UiKit.box(Color("#0C2433"), 20, 2, UiKit.LINE)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
