extends Control
## "How to play" overlay: every rule from the concept document, split into tabs.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Describe = preload("res://scripts/ui/describe.gd")

signal closed

const TABS := ["The goal", "Your turn", "Tiles", "Happiness", "Complaints", "Objectives"]

var _panel: PanelContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons: Array[Button] = []
var _tab := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK_DEEP, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(1180, 760)
	var sb := UiKit.box(UiKit.PANEL, 24, 2, UiKit.LINE, 28)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 30
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	_panel.add_child(root)
	var head := HBoxContainer.new()
	head.add_child(UiKit.label("How to play", 40, UiKit.LIMESTONE, "display_bold"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close_btn := UiKit.button("Close", "secondary", 18)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	root.add_child(head)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size.x = 200
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for i in TABS.size():
		var b := UiKit.button(TABS[i], "ghost", 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_show_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	tabs.add_child(_spacer_v())
	var keys := UiKit.label("Up and Down switch tabs. Esc closes.", 14, UiKit.MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size.x = 190
	tabs.add_child(keys)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	_scroll.add_child(_content)

	_show_tab(0)
	_panel.pivot_offset = _panel.custom_minimum_size / 2
	_panel.scale = Vector2.ONE * 0.94
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh")


func close() -> void:
	set_process_unhandled_input(false)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_property(_panel, "scale", Vector2.ONE * 0.96, 0.15)
	await tw.finished
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_H, KEY_F1:
				close()
			KEY_UP, KEY_W:
				_show_tab(wrapi(_tab - 1, 0, TABS.size()))
			KEY_DOWN, KEY_S, KEY_TAB:
				_show_tab(wrapi(_tab + 1, 0, TABS.size()))
		get_viewport().set_input_as_handled()


func _spacer_v() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _show_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		UiKit.style_button(_tab_buttons[k], "primary" if k == i else "ghost")
	for c in _content.get_children():
		c.queue_free()
	match i:
		0: _goal()
		1: _turn()
		2: _tiles()
		3: _happiness()
		4: _complaints()
		5: _objectives()
	_scroll.scroll_vertical = 0
	_content.modulate.a = 0.0
	create_tween().tween_property(_content, "modulate:a", 1.0, 0.15)


# ---------------------------------------------------------------- helpers

func _h(text: String) -> void:
	_content.add_child(UiKit.label(text, 28, UiKit.LIMESTONE, "display_bold"))


func _p(text: String, color := UiKit.LIMESTONE, size := 18) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_override("normal_font", UiKit.font("body"))
	rt.add_theme_font_override("bold_font", UiKit.font("body_bold"))
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_font_size_override("bold_font_size", size)
	rt.add_theme_color_override("default_color", color)
	rt.add_theme_constant_override("line_separation", 5)
	rt.text = text
	_content.add_child(rt)
	return rt


func _card(children: Array, bg := UiKit.PANEL_HI) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(bg, 16, 0, Color.TRANSPARENT, 16))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	for c in children:
		hb.add_child(c)
	pc.add_child(hb)
	return pc


func _stat(value: String, caption: String) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label(value, 40, UiKit.GOLD, "display_bold"))
	v.add_child(UiKit.label(caption, 15, UiKit.MUTED))
	return v


func _wrap_label(text: String, size := 17, color := UiKit.LIMESTONE) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# ---------------------------------------------------------------- tabs

func _goal() -> void:
	_h("Build the happiest city in Egkomi")
	_p("You are a city planner. Every round you buy tiles from the shared construction site and build them on your own 4x4 mat. [b]Apartments[/b] bring citizens, while [b]amenities, parks, trees and roads[/b] keep those citizens happy. After 4 rounds, the planner whose citizens score the most points wins.")
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	for s in [["4", "rounds"], ["2", "tiles per player per round"], ["36", "tiles in the 6x6 shop"], ["4x4", "grid on each mat"]]:
		stats.add_child(_card([_stat(s[0], s[1])]))
	for c in stats.get_children():
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(stats)
	_h("Setup")
	_p("Each planner starts with [color=#F2B630][b]20 gold[/b][/color], [b]2 free road tiles[/b] and a mat with [b]pollution 10[/b].")
	_p("With 2 or 3 planners, 4 random tiles per missing planner are removed from the shop so it stays balanced. Removed lots show as hatched squares.", UiKit.MUTED, 16)
	_h("Winning")
	_p("Every citizen scores its happiness (-3 to +3) as points, and every loan costs 2 points, and every amenity that no home can reach costs 1 point. Totals can be negative. Ties go to the planner with more happy citizens, then more gold left.")


func _turn() -> void:
	_h("Your turn")
	var steps := [
		["Pick a tile", "Click a tile in the construction site. Its gold cost is on the coin. You must buy 2 tiles every round."],
		["Build it", "Click an empty lot on your mat. Building is permanent, so think about roads and neighbours first. Right-click or Esc puts the tile back."],
		["Free roads", "Place your 2 free roads on any empty lot during any of your turns. They never count as purchases."],
		["Loan if needed", "Only when you cannot afford the tiles you still have to buy: +10 gold now, -2 points at the end."],
		["End your turn", "After 2 purchases, end your turn and pass the mouse and keyboard to the next planner."],
	]
	for i in steps.size():
		var num := UiKit.label(str(i + 1), 34, UiKit.GOLD, "display_bold")
		num.custom_minimum_size.x = 34
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(steps[i][0], 21, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label(steps[i][1], 16, UiKit.MUTED))
		_content.add_child(_card([num, col]))
	_p("[b]Turn order.[/b] The first round is drawn at random. In every later round the city with the fewest points so far picks first; a tie goes to whoever picked later last round. The round banner and the numbered planner cards show the order.", UiKit.MUTED, 16)
	_h("A loan can still pay off")
	_p("A large apartment adds 3 citizens. If all of them are fully happy (+3 each), that is 3 + 3 + 3 - 2 = [color=#8DBB3C][b]7 points[/b][/color], even after the loan.")
	_h("Controls")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	for row in [
		["Mouse", "Hover any tile for details. Click to pick and build."],
		["Arrows / WASD", "Move the gold cursor"],
		["Enter / Space", "Pick or build at the cursor"],
		["Tab", "Switch between shop and mat"],
		["R", "Pick up a free road"],
		["L", "Take a loan"],
		["E", "End your turn"],
		["Esc", "Put a tile back, or open the menu"],
		["H", "This help"],
		["M", "Sound on or off"],
	]:
		grid.add_child(UiKit.keycap(row[0]))
		grid.add_child(UiKit.label(row[1], 17))
	_content.add_child(grid)


func _tiles() -> void:
	_h("Tile set")
	_p("Three families of tiles. Hover any tile in the game to see exactly what it does on your mat right now.", UiKit.MUTED, 16)
	var rows := [
		[TileDefs.Kind.APT_S, 0], [TileDefs.Kind.APT_M, 0], [TileDefs.Kind.APT_L, 0],
		[TileDefs.Kind.AMENITY, 0], [TileDefs.Kind.PARK, 0], [TileDefs.Kind.TREES, 0], [TileDefs.Kind.ROAD, 0],
	]
	for r in rows:
		var t := TileDefs.make(r[0], r[1])
		var info := TileDefs.info(r[0])
		var icon := UiKit.icon(TileDefs.art_path(t), 76)
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := HBoxContainer.new()
		title.add_theme_constant_override("separation", 10)
		title.add_child(UiKit.label(info["name"], 21, UiKit.LIMESTONE, "display_bold"))
		title.add_child(UiKit.chip(info["category"], UiKit.CATEGORY_COLORS[info["category"]], UiKit.LIMESTONE, 13))
		title.add_child(UiKit.chip("x%d in shop" % info["qty"], UiKit.PANEL, UiKit.MUTED, 13))
		mid.add_child(title)
		var eff: String = Describe.effect_text(t)
		if r[0] == TileDefs.Kind.AMENITY:
			eff += " Comes as a café, clinic, school or market."
		mid.add_child(_wrap_label(eff, 16, UiKit.MUTED))
		var objs := HBoxContainer.new()
		for o in info["objectives"]:
			objs.add_child(UiKit.chip("%s %s" % [o, UiKit.OBJECTIVE_SHORT[o]], UiKit.PANEL, UiKit.MUTED, 12))
		mid.add_child(objs)
		var cost := HBoxContainer.new()
		cost.add_theme_constant_override("separation", 6)
		cost.add_child(UiKit.icon("res://assets/ui/coin.svg", 30))
		cost.add_child(UiKit.label(str(info["cost"]), 28, UiKit.GOLD, "display_bold"))
		_content.add_child(_card([icon, mid, cost]))
	_p("[b]36 tiles:[/b] 11 apartments, 8 amenities, 9 green spaces and 8 roads. The 2 free roads per planner come on top. With 4 planners, 32 tiles are bought and 4 stay in the shop.", UiKit.LIMESTONE, 16)


func _happiness() -> void:
	_h("Citizen happiness")
	_p("Every citizen has a happy bar from [color=#E0533A][b]-3[/b][/color] to [color=#8DBB3C][b]+3[/b][/color] and scores it as points. All citizens in one apartment share the same bar. The faces on your mat show it live.")
	var rows := [
		["res://assets/ui/route.svg", "+1 per amenity reached by road", "A road path must run from the apartment to the amenity. Standing next to each other does not count. All citizens move the same way, so the road layout decides who can reach what."],
		["res://assets/ui/leaf.svg", "+1 per park or trees nearby", "A park cheers up its whole 3x3 area, diagonals included. Trees cheer up the 4 tiles that share an edge with them."],
		["res://assets/ui/sun.svg", "-1 for a long, hot walk", "A route of 2 or more road tiles to an amenity costs 1 happiness from the heat, unless at least one road on it is shaded. A single road tile is never hot."],
		["res://assets/ui/leaf.svg", "Shade", "A road next to trees or a park counts as shaded. It shows a leafy green shadow on the side facing the trees and a Shade badge. Grey smog clouds are pollution, not shade."],
	]
	for r in rows:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(r[1], 20, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label(r[2], 16, UiKit.MUTED))
		_content.add_child(_card([UiKit.icon(r[0], 44), col]))
	_h("Pollution")
	_p("Every mat starts at pollution 10. Each [b]park lowers it by 3[/b] and each [b]trees tile by 1[/b], never below 0. At the end it changes the happiness of every citizen on that mat:")
	var bands := HBoxContainer.new()
	bands.add_theme_constant_override("separation", 12)
	for b in [["0 to 5", "No change", UiKit.OLIVE], ["6 to 8", "-1 happiness", UiKit.GOLD], ["9 to 10", "-2 happiness", UiKit.HEAT]]:
		var v := VBoxContainer.new()
		v.add_child(UiKit.label(b[0], 28, b[2], "display_bold"))
		v.add_child(UiKit.label(b[1], 16, UiKit.LIMESTONE))
		var c := _card([v])
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bands.add_child(c)
	_content.add_child(bands)
	_p("Example: 1 park and 2 trees bring a mat from 10 down to 5, so pollution no longer affects anyone. A mat with no green space stays at 10 and every citizen on it loses 2 happiness.", UiKit.MUTED, 16)


func _complaints() -> void:
	_h("Complaints")
	_p("Every unhappy citizen (below 0) files a complaint about the main cause of their mood. You can see them on each apartment's card while you play.")
	for type in Describe.COMPLAINTS:
		var c: Dictionary = Describe.COMPLAINTS[type]
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(type, 21, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label("%s The fix: %s." % [c["meaning"], c["fix"].to_lower()], 16, UiKit.MUTED))
		_content.add_child(_card([UiKit.icon(c["icon"], 44), col]))
	_p("At the end of the game, each planner names the one change that would add the most points to their city. Every home below +3 and every amenity nobody reaches still has room to improve, so there is always something to name.")


func _objectives() -> void:
	_h("Why this game exists")
	_p("The game is built around four objectives about everyday life in Egkomi. Every tile tooltip shows which ones it serves.", UiKit.MUTED, 16)
	for o in UiKit.OBJECTIVES:
		var tag := UiKit.label(o, 30, UiKit.GOLD, "display_bold")
		tag.custom_minimum_size.x = 56
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(UiKit.OBJECTIVE_SHORT[o], 20, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label(UiKit.OBJECTIVES[o], 16, UiKit.MUTED))
		_content.add_child(_card([tag, col]))
	_p("[b]Where you meet them:[/b] road placement on your mat is the city's circulation (O1). Complaints point at what to improve (O2). Parks and trees shade walking routes (O3). Happiness turns routes, greenery and pollution into score (O4).", UiKit.LIMESTONE, 16)
