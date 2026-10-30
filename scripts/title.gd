extends Control
## Title screen: wordmark, a sample Egkomi block that builds itself, and seat setup.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const RulesPanel = preload("res://scripts/ui/rules_panel.gd")
const Modal = preload("res://scripts/ui/modal.gd")
const OptionsPanel = preload("res://scripts/ui/options_panel.gd")
const Bot = preload("res://scripts/core/bot.gd")

const MAX_SEATS := 4
const MIN_SEATS := 2
## Sample block shown on the right: T trees, P park, R road, s/m/l apartments, c/k/h/k amenities.
const DIORAMA := ["TlRcP", "RRRRT", "mPRhR", "sTRkm"]
const DIO_CELL := 104.0
## Names offered to computer planners.
const BOT_NAMES := ["Nikos", "Eleni", "Maria", "Andreas", "Sofia", "Kostas"]
const SEAT_KINDS := ["Human", "Easy bot", "Medium bot", "Hard bot"]

var _seat_box: VBoxContainer
var _add_btn: Button
var _overlays: Control
var _modal := false
var _diorama: Control
var _dio_views: Array = []


func _ready() -> void:
	theme = Game.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Widgets.Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 70)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 60)
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 730
	left.add_theme_constant_override("separation", 18)
	row.add_child(left)
	var mark := VBoxContainer.new()
	mark.add_theme_constant_override("separation", -34)
	mark.add_child(UiKit.label("Egkomi", 116, UiKit.LIMESTONE, "display_bold"))
	mark.add_child(UiKit.label("City", 116, UiKit.LIMESTONE, "display_bold"))
	left.add_child(mark)
	var tag := UiKit.label("Plan streets, shade and parks so every citizen of Egkomi can walk, breathe and get where they need to go.", 20, UiKit.MUTED)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size.x = 560
	left.add_child(tag)

	var setup := PanelContainer.new()
	setup.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 22, 1, UiKit.LINE, 22))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	setup.add_child(sv)
	var head := HBoxContainer.new()
	head.add_child(UiKit.label("Who is playing?", 26, UiKit.LIMESTONE, "display_bold"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UiKit.label("2 to 4 planners on this computer", 15, UiKit.MUTED))
	sv.add_child(head)
	_seat_box = VBoxContainer.new()
	_seat_box.add_theme_constant_override("separation", 10)
	sv.add_child(_seat_box)
	var seat_actions := HBoxContainer.new()
	seat_actions.add_theme_constant_override("separation", 10)
	_add_btn = UiKit.button("Add a planner", "ghost", 18)
	_add_btn.pressed.connect(_add_seat)
	seat_actions.add_child(_add_btn)
	var solo := UiKit.button("Play solo against 3 bots", "ghost", 18)
	solo.pressed.connect(_setup_solo)
	seat_actions.add_child(solo)
	sv.add_child(seat_actions)
	left.add_child(setup)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	var start := UiKit.button("Start game", "primary", 26)
	start.pressed.connect(_start)
	actions.add_child(start)
	var how := UiKit.button("How to play", "secondary", 20)
	how.pressed.connect(_open_rules)
	actions.add_child(how)
	var opts := UiKit.button("Options", "secondary", 20)
	opts.pressed.connect(_open_options)
	actions.add_child(opts)
	var quit := UiKit.button("Quit", "ghost", 20)
	quit.pressed.connect(func(): get_tree().quit())
	actions.add_child(quit)
	left.add_child(actions)

	var right := CenterContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_diorama = Control.new()
	_diorama.custom_minimum_size = Vector2(5 * DIO_CELL + 4 * 8, 4 * DIO_CELL + 3 * 8)
	right.add_child(_diorama)

	_overlays = Control.new()
	_overlays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlays)

	_rebuild_seats()
	_build_diorama()
	_intro(mark, tag, setup, actions)


func _intro(mark: Control, tag: Control, setup: Control, actions: Control) -> void:
	var items := [mark, tag, setup, actions]
	for k in items.size():
		items[k].modulate.a = 0.0
	await get_tree().process_frame
	for k in items.size():
		var c: Control = items[k]
		var y := c.position.y
		c.position.y = y + 24
		var tw := create_tween().set_parallel()
		tw.tween_property(c, "modulate:a", 1.0, 0.45).set_delay(0.1 + k * 0.1)
		tw.tween_property(c, "position:y", y, 0.55).set_delay(0.1 + k * 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- diorama

func _dio_tile(ch: String) -> Variant:
	match ch:
		"T": return TileDefs.make(TileDefs.Kind.TREES)
		"P": return TileDefs.make(TileDefs.Kind.PARK)
		"R": return TileDefs.make(TileDefs.Kind.ROAD)
		"s": return TileDefs.make(TileDefs.Kind.APT_S)
		"m": return TileDefs.make(TileDefs.Kind.APT_M)
		"l": return TileDefs.make(TileDefs.Kind.APT_L)
		"c": return TileDefs.make(TileDefs.Kind.AMENITY, 0)
		"h": return TileDefs.make(TileDefs.Kind.AMENITY, 1)
		"k": return TileDefs.make(TileDefs.Kind.AMENITY, 3)
	return null


func _build_diorama() -> void:
	var w := 5
	var h := 4
	var tiles: Array = []
	for row in DIORAMA:
		for ch in row:
			tiles.append(_dio_tile(ch))
	for i in tiles.size():
		var x := i % w
		var y := i / w
		var v := TileView.new()
		v.mode = TileView.Mode.MINI
		v.tile = tiles[i]
		if tiles[i]["kind"] == TileDefs.Kind.ROAD:
			var mask := 0
			for d in [[0, -1, 1], [1, 0, 2], [0, 1, 4], [-1, 0, 8]]:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					var k: int = tiles[ny * w + nx]["kind"]
					if k == TileDefs.Kind.ROAD:
						mask |= d[2]
			v.road_mask = mask
		v.size = Vector2(DIO_CELL, DIO_CELL)
		v.position = Vector2(x * (DIO_CELL + 8), y * (DIO_CELL + 8))
		v.mouse_default_cursor_shape = Control.CURSOR_ARROW
		v.hovered.connect(func(view, inside):
			if inside:
				view.pop(0.07)
				Sfx.play("hover"))
		v.modulate.a = 0.0
		_diorama.add_child(v)
		_dio_views.append(v)
	# build order: diagonal sweep from the top-left corner
	var order := range(tiles.size())
	order.sort_custom(func(a, b): return (a % w + a / w) < (b % w + b / w))
	for n in order.size():
		var v = _dio_views[order[n]]
		var final_y: float = v.position.y
		v.position.y = final_y - 70
		v.anim_scale = 0.7
		var tw := create_tween().set_parallel()
		var delay := 0.5 + n * 0.07
		tw.tween_property(v, "modulate:a", 1.0, 0.2).set_delay(delay)
		tw.tween_property(v, "position:y", final_y, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "anim_scale", 1.0, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if n % 3 == 0:
			tw.tween_callback(func(): Sfx.play("tick", 0.8 + n * 0.03)).set_delay(delay + 0.3)


# ---------------------------------------------------------------- seats

func _rebuild_seats() -> void:
	for c in _seat_box.get_children():
		c.queue_free()
	for i in Game.seats.size():
		_seat_box.add_child(_seat_row(i))
	_add_btn.visible = Game.seats.size() < MAX_SEATS


func _seat_row(i: int) -> Control:
	var seat: Dictionary = Game.seats[i]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var av := Widgets.Avatar.new(46)
	av.color = UiKit.player_color(seat["color"])
	av.letter = str(i + 1)
	h.add_child(av)
	var name := LineEdit.new()
	name.text = seat["name"]
	name.placeholder_text = "Player %d" % (i + 1)
	name.max_length = 14
	name.custom_minimum_size.x = 150
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.select_all_on_focus = true
	name.text_changed.connect(func(t): Game.seats[i]["name"] = t)
	name.text_submitted.connect(func(_t): _start())
	h.add_child(name)
	var kind := OptionButton.new()
	for k in SEAT_KINDS:
		kind.add_item(k)
	kind.select(seat.get("bot", 0))
	kind.focus_mode = Control.FOCUS_NONE
	kind.custom_minimum_size.x = 150
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kind.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	kind.tooltip_text = "A person at this computer, or a computer planner"
	UiKit.style_button(kind, "secondary")
	kind.add_theme_font_override("font", UiKit.font("display"))
	kind.add_theme_font_size_override("font_size", 17)
	kind.item_selected.connect(func(idx: int):
		Sfx.play("click")
		Game.seats[i]["bot"] = idx
		if idx > 0 and Game.seats[i]["name"].begins_with("Player"):
			Game.seats[i]["name"] = _free_bot_name()
		elif idx == 0 and Game.seats[i]["name"] in BOT_NAMES:
			Game.seats[i]["name"] = "Player %d" % (i + 1)
		_rebuild_seats())
	h.add_child(kind)
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 3)
	for c in UiKit.PLAYER_COLORS.size():
		swatches.add_child(_swatch(i, c))
	h.add_child(swatches)
	if Game.seats.size() > MIN_SEATS:
		var rm := UiKit.button("Remove", "ghost", 15)
		rm.pressed.connect(func():
			Game.seats.remove_at(i)
			_rebuild_seats())
		h.add_child(rm)
	return h


func _swatch(seat: int, color_index: int) -> Control:
	var taken := false
	for k in Game.seats.size():
		if k != seat and Game.seats[k]["color"] == color_index:
			taken = true
	var mine: bool = Game.seats[seat]["color"] == color_index
	var b := Button.new()
	b.custom_minimum_size = Vector2(24, 24)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = taken
	b.tooltip_text = UiKit.PLAYER_COLOR_NAMES[color_index] + (" (taken)" if taken else "")
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var col: Color = UiKit.player_color(color_index)
	var sb := UiKit.box(col if not taken else Color(col, 0.18), 12, 3 if mine else 0, UiKit.LIMESTONE)
	for s in ["normal", "hover", "pressed", "disabled"]:
		var st: StyleBoxFlat = sb.duplicate()
		if s == "hover" and not taken:
			st.bg_color = col.lightened(0.2)
		b.add_theme_stylebox_override(s, st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Sfx.play("click")
		Game.seats[seat]["color"] = color_index
		_rebuild_seats())
	return b


func _add_seat() -> void:
	if Game.seats.size() >= MAX_SEATS:
		return
	var used := []
	for s in Game.seats:
		used.append(s["color"])
	var free := 0
	while free in used:
		free += 1
	Game.seats.append({"name": "Player %d" % (Game.seats.size() + 1), "color": free, "bot": 0})
	_rebuild_seats()
	var row: Control = _seat_box.get_child(_seat_box.get_child_count() - 1)
	row.modulate.a = 0.0
	create_tween().tween_property(row, "modulate:a", 1.0, 0.25)


func _start() -> void:
	if _modal:
		return
	var seen := {}
	for i in Game.seats.size():
		var n: String = Game.seats[i]["name"].strip_edges()
		if n == "":
			n = "Player %d" % (i + 1)
		var base := n
		var k := 2
		while seen.has(n.to_lower()):
			n = "%s %d" % [base, k]
			k += 1
		seen[n.to_lower()] = true
		Game.seats[i]["name"] = n
	Sfx.play("turn")
	Game.new_game()
	Game.goto(Game.GAME_SCENE)


func _free_bot_name() -> String:
	var used := []
	for s in Game.seats:
		used.append(s["name"])
	for n in BOT_NAMES:
		if not n in used:
			return n
	return "Bot"


## One human in seat 1, three Medium bots.
func _setup_solo() -> void:
	var me: Dictionary = Game.seats[0]
	Game.seats = [{"name": me["name"] if not me["name"] in BOT_NAMES else "Player 1", "color": me["color"], "bot": 0}]
	for k in 3:
		var col := 0
		var used := []
		for s in Game.seats:
			used.append(s["color"])
		while col in used:
			col += 1
		Game.seats.append({"name": _free_bot_name(), "color": col, "bot": Bot.MEDIUM})
	_rebuild_seats()
	Sfx.play("pop")


func _open_options() -> void:
	if _modal:
		return
	_modal = true
	var op := OptionsPanel.new()
	_overlays.add_child(op)
	await op.closed
	_modal = false


func _open_rules() -> void:
	if _modal:
		return
	_modal = true
	var rp := RulesPanel.new()
	_overlays.add_child(rp)
	await rp.closed
	_modal = false


func _unhandled_input(event: InputEvent) -> void:
	if _modal or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_H or event.keycode == KEY_F1:
		_open_rules()
		get_viewport().set_input_as_handled()
