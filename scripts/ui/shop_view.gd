extends Control
## The shared construction site: one tile per stack, grouped under small headings
## (Homes, Study, Care and school, Work and shops, Green, Streets).

const TileView = preload("res://scripts/ui/tile_view.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal slot_pressed(index: int)
signal slot_right_pressed(index: int)
signal slot_hovered(index: int, inside: bool)

## Stacks per visual row. Eight columns keep the 35 stacks (15 of them homes) in five rows, so the
## column stays short enough for the action bar to fit under it at 1600x900.
const COLS := 8

var cell := 60.0
var gap := 6.0
var pad := 12.0
## Space above the first row of each section for its heading.
var head_h := 22.0
## Space at the top of the box for its title ("Construction site") and the tile counter.
var title_h := 36.0
## Extra space between two sections that share a row.
var block_gap := 14.0
## One view per stack, in stack order.
var views: Array = []
## The visual rows, top to bottom: arrays of stack indexes (for keyboard navigation).
var rows: Array = []

var _heads: Array = []
var _count_label: Label


## Creates one tile view per stack and lays them out. Sections that fit side by side share a row.
func build(stacks: Array, cell_size := 60.0, cell_gap := 6.0) -> void:
	for c in get_children():
		c.queue_free()
	views.clear()
	rows.clear()
	_heads.clear()
	cell = cell_size
	gap = cell_gap

	# (row, column, stack) for every stack, and where each section starts
	var slots: Array = []
	var starts: Array = []
	var col := 0
	var row := 0
	for g in TileDefs.GROUPS.size():
		var members: Array[int] = []
		for i in stacks.size():
			if TileDefs.group_of(stacks[i]["tile"]["kind"]) == g:
				members.append(i)
		if members.is_empty():
			continue
		if col > 0 and col + members.size() > COLS:
			col = 0
			row += 1
		starts.append({"group": g, "row": row, "col": col})
		for i in members:
			if col >= COLS:
				col = 0
				row += 1
			slots.append({"row": row, "col": col, "stack": i, "shifted": starts[-1]["col"] > 0})
			col += 1

	var row_count := row + 1
	var has_head: Array[bool] = []
	has_head.resize(row_count)
	for s in starts:
		has_head[s["row"]] = true
	var row_y: Array[float] = []
	var y := pad + title_h
	for r in row_count:
		if has_head[r]:
			y += head_h
		row_y.append(y)
		y += cell + gap

	for r in row_count:
		rows.append([])
	views.resize(stacks.size())
	for sl in slots:
		var v := TileView.new()
		v.mode = TileView.Mode.SHOP
		v.index = sl["stack"]
		v.position = Vector2(_col_x(sl["col"], sl["shifted"]), row_y[sl["row"]])
		v.size = Vector2(cell, cell)
		v.pressed.connect(func(view): slot_pressed.emit(view.index))
		v.right_pressed.connect(func(view): slot_right_pressed.emit(view.index))
		v.hovered.connect(func(view, inside): slot_hovered.emit(view.index, inside))
		add_child(v)
		views[sl["stack"]] = v
		rows[sl["row"]].append(sl["stack"])

	for s in starts:
		var l := UiKit.label(TileDefs.GROUPS[s["group"]]["name"].to_upper(), 13, UiKit.MUTED, "body_bold")
		l.position = Vector2(_col_x(s["col"], s["col"] > 0), row_y[s["row"]] - head_h + 1)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		move_child(l, 0)
		_heads.append(l)

	custom_minimum_size = Vector2(2 * pad + COLS * cell + (COLS - 1) * gap + block_gap, y - gap + pad)
	size = custom_minimum_size

	# the box's own title row, so its top edge lines up with the boxes beside it
	var title := UiKit.label("Construction site", 22, UiKit.LIMESTONE, "display_bold")
	title.position = Vector2(pad + 2.0, pad - 3.0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	_count_label = UiKit.label("", 16, UiKit.MUTED)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.position = Vector2(pad, pad + 1.0)
	_count_label.size = Vector2(size.x - 2.0 * pad - 2.0, 24.0)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)


func set_count(left: int) -> void:
	if _count_label != null:
		_count_label.text = "%d tiles left" % left


func _col_x(col: int, shifted: bool) -> float:
	return pad + col * (cell + gap) + (block_gap if shifted else 0.0)


## `stacks` are the shop's stacks; `money` and `can_buy` decide which ones look affordable.
## `prices` (one per stack) are what the planner pays right now, after the turn's card; leave it out for normal prices.
func refresh(stacks: Array, money: int, can_buy: bool, prices: Array = []) -> void:
	for i in views.size():
		var v = views[i]
		var count: int = stacks[i]["count"]
		v.tile = stacks[i]["tile"]
		v.stack_count = count
		v.sold_out = count <= 0
		v.price = prices[i] if i < prices.size() else -1
		var cost: int = v.price if v.price >= 0 else TileDefs.tile_cost(stacks[i]["tile"])
		v.affordable = can_buy and count > 0 and money >= cost
		v.interactive = count > 0
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
