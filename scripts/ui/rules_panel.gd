extends Control
## "How to play" overlay: every rule from the concept document, split into tabs.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const Roles = preload("res://scripts/core/roles.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const CircumstanceCardFace = preload("res://scripts/game/circumstance_card_face.gd")

signal closed

const TABS := ["The goal", "Your turn", "Tiles", "People and needs", "Happiness", "Complaints", "Turn cards", "Hidden circumstances", "Objectives"]

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
		3: _people()
		4: _happiness()
		5: _complaints()
		6: _turn_cards()
		7: _events()
		8: _objectives()
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


## A card rule with the happiness words replaced by a smiley (see CircumstanceCardFace.happiness_icons).
func _rule_text(text: String, size: int) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_override("normal_font", UiKit.font("body"))
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_color_override("default_color", UiKit.LIMESTONE)
	rt.text = CircumstanceCardFace.happiness_icons(text, "7ED957", "FF8A7A", size)
	return rt


func _wrap_label(text: String, size := 17, color := UiKit.LIMESTONE) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# ---------------------------------------------------------------- tabs

func _goal() -> void:
	_h("Build the happiest city in Egkomi")
	_p("You are a city planner. Every round you buy tiles from the shared construction site and build them on your own %dx%d mat. [b]Homes[/b] bring citizens, and every citizen needs different places nearby: a student needs a library, a child needs a school, an older resident needs a clinic, an expat needs a restaurant. [b]Services, parks, trees and roads[/b] keep them happy. After %d rounds, the planner whose citizens score the most points wins." % [Scoring.SIZE, Scoring.SIZE, GameState.ROUNDS])
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	for s in [[str(GameState.ROUNDS), "rounds"], [str(GameState.BUYS_PER_TURN), "tiles per player per round"], ["%dx%d" % [Scoring.SIZE, Scoring.SIZE], "grid on each mat"], [str(GameState.START_MONEY), "gold to start with"]]:
		stats.add_child(_card([_stat(s[0], s[1])]))
	for c in stats.get_children():
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(stats)
	_h("Setup")
	_p("Each planner starts with [color=#F2B630][b]%d gold[/b][/color], [b]%d free road tiles[/b] and a mat with [b]pollution %d[/b]. There is no income: the gold you start with has to last all game." % [GameState.START_MONEY, GameState.FREE_ROADS, Scoring.START_POLLUTION])
	_p("The shop holds %d tiles for 4 planners. With 2 or 3 planners, %d random tiles per missing planner are removed so it stays balanced. By the end you will have built %d tiles: %d bought and %d free roads." % [TileDefs.BAG_SIZE, GameState.REMOVED_PER_MISSING_PLAYER, GameState.ROUNDS * GameState.BUYS_PER_TURN + GameState.FREE_ROADS, GameState.ROUNDS * GameState.BUYS_PER_TURN, GameState.FREE_ROADS], UiKit.MUTED, 16)
	_h("Winning")
	_p("Every citizen scores its happiness (-5 to +5) as points. Every loan costs points (%s), and every service that no home can reach costs %d point. A mixed city earns a variety bonus (%s): a kind of citizen counts once at least one of them is happy, and every kind is worth more than the last, because each needs different services at the same time. Totals can be negative. Ties go to the planner with more happy citizens, then more gold left." % [_loan_costs(), Scoring.UNUSED_PENALTY, _variety_costs()])


func _variety_costs() -> String:
	var parts: Array[String] = []
	for kinds in range(2, Scoring.VARIETY_BONUS.size()):
		parts.append("%d kinds +%d" % [kinds, Scoring.VARIETY_BONUS[kinds]])
	return ", ".join(parts)


func _loan_costs() -> String:
	var parts: Array[String] = []
	for n in 3:
		parts.append(str(Scoring.loan_penalty(n + 1) - Scoring.loan_penalty(n)))
	return "%s, then %d and more for every further one" % [", ".join(parts), Scoring.LOAN_PENALTIES[-1] + Scoring.LOAN_STEP]


func _turn() -> void:
	_h("Your turn")
	var steps := [
		["Pick a tile", "Click a stack in the construction site. Its gold cost is on the coin and the number in the corner is how many are left. You must buy %d tiles every round." % GameState.BUYS_PER_TURN],
		["Check who lives there", "Homes show round icons for the citizens inside. Hover a home to see what each of them needs, likes and dislikes before you buy."],
		["Build it", "Click an empty lot on your mat. Building is permanent, so think about roads and neighbours first. Right-click or Esc puts the tile back."],
		["Free roads", "Place your %d free roads on any empty lot during any of your turns. They never count as purchases." % GameState.FREE_ROADS],
		["Loan if needed", "Only when you cannot afford the tiles you still have to buy: +%d gold now, and points off at the end (%s)." % [GameState.LOAN_AMOUNT, _loan_costs()]],
		["End your turn", "After %d purchases, end your turn and pass the mouse and keyboard to the next planner." % GameState.BUYS_PER_TURN],
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
	_p("A family in a large apartment adds 3 citizens. If all of them are fully happy (+5 each), that is [color=#8DBB3C][b]15 points[/b][/color], more than the %d points the first loan costs. A second loan costs more, so borrow only when it buys you something." % (Scoring.loan_penalty(1)))
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
	_p("Homes, services, green space and streets. Hover any tile in the game to see exactly what it does on your mat right now. Quantities are for 4 planners.", UiKit.MUTED, 16)
	var rows: Array = []
	for g in TileDefs.GROUPS:
		for k in g["kinds"]:
			rows.append([k, 0])
	rows.append_array([[TileDefs.Kind.ROAD, 1], [TileDefs.Kind.ROAD, 2], [TileDefs.Kind.ROAD, 3]])
	for r in rows:
		var t := TileDefs.make(r[0], r[1])
		var info := TileDefs.info(r[0])
		var icon := UiKit.icon(TileDefs.art_path(t), 76)
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := HBoxContainer.new()
		title.add_theme_constant_override("separation", 10)
		title.add_child(UiKit.label(TileDefs.display_name(t), 21, UiKit.LIMESTONE, "display_bold"))
		title.add_child(UiKit.chip(info["category"], UiKit.CATEGORY_COLORS[info["category"]], UiKit.LIMESTONE, 13))
		var in_shop: int = TileDefs.STREET_BAG.count(r[1]) if r[0] == TileDefs.Kind.ROAD else info["qty"]
		title.add_child(UiKit.chip("x%d in shop" % in_shop, UiKit.PANEL, UiKit.MUTED, 13))
		mid.add_child(title)
		mid.add_child(_wrap_label(Describe.effect_text(t), 16, UiKit.MUTED))
		if TileDefs.HOUSEHOLDS.has(r[0]):
			var names: Array[String] = []
			for h in TileDefs.HOUSEHOLDS[r[0]]:
				names.append(h["name"])
			mid.add_child(_wrap_label("Households: " + ", ".join(names), 15, UiKit.LIMESTONE))
		var cost := HBoxContainer.new()
		cost.add_theme_constant_override("separation", 6)
		cost.add_child(UiKit.icon("res://assets/ui/coin.svg", 30))
		cost.add_child(UiKit.label(str(TileDefs.tile_cost(t)), 28, UiKit.GOLD, "display_bold"))
		_content.add_child(_card([icon, mid, cost]))
	_p("[b]%d tiles in the shop.[/b] With 4 planners, %d are bought and %d stay in the shop. The %d free roads per planner come on top." % [TileDefs.BAG_SIZE, 4 * GameState.ROUNDS * GameState.BUYS_PER_TURN, TileDefs.BAG_SIZE - 4 * GameState.ROUNDS * GameState.BUYS_PER_TURN, GameState.FREE_ROADS], UiKit.LIMESTONE, 16)


func _people() -> void:
	_h("People and needs")
	_p("Who lives in a home depends on the home you buy. Each citizen has a [b]role[/b], and every role has two needs, a few likes and sometimes a dislike. Plan the neighbourhood around the people you house.")
	for role in Roles.IDS:
		var d: Dictionary = Roles.DEFS[role]
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(d["name"], 22, Color(d["color"]).lightened(0.3), "display_bold"))
		var needs: Array[String] = []
		for n in d["needs"]:
			needs.append("a " + Roles.NEEDS[n]["name"])
		col.add_child(_wrap_label("Needs " + " and ".join(needs) + ". Each need that is met adds happiness; each one that is missing takes it away.", 16, UiKit.LIMESTONE))
		var likes: Array[String] = []
		for k in d["like_kinds"]:
			likes.append(TileDefs.DEFS[k]["name"].to_lower())
		for s in d["like_streets"]:
			likes.append(TileDefs.STREETS[s]["name"].to_lower())
		var extra := "Likes: %s (+1 if any is within reach)." % ", ".join(likes)
		if d["dislike_kind"] >= 0:
			extra += " Dislikes a %s right next door (-1)." % TileDefs.DEFS[d["dislike_kind"]]["name"].to_lower()
		if d["heat_factor"] > 1:
			extra += " Feels a long, unshaded walk twice as hard."
		col.add_child(_wrap_label(extra, 15, UiKit.MUTED))
		_content.add_child(_card([UiKit.icon(d["icon"], 56), col]))
	_h("Who lives where")
	for kind in TileDefs.HOUSEHOLDS:
		var parts: Array[String] = []
		for h in TileDefs.HOUSEHOLDS[kind]:
			var who: Array[String] = []
			for r in h["members"]:
				who.append(Roles.DEFS[r]["name"].to_lower())
			parts.append("%s (%s)" % [h["name"], ", ".join(who)])
		_content.add_child(_card([UiKit.icon(TileDefs.art_path(TileDefs.make(kind)), 56), _wrap_label("[b]%s:[/b] %s" % [TileDefs.DEFS[kind]["name"], "; ".join(parts)], 16, UiKit.LIMESTONE)]))
	_p("[b]Parking:[/b] Egkomi has been asking for parking for years, so everyone but the children likes having it within reach (residents with a disability like the reserved bays). Only children dislike it right next to their home (traffic).", UiKit.MUTED, 16)


func _happiness() -> void:
	_h("Citizen happiness")
	_p("Every citizen has a happy bar from [color=#E0533A][b]-5[/b][/color] to [color=#8DBB3C][b]+5[/b][/color] and scores it as points. Each citizen in a home has their own bar, so a family can have a happy parent and an unhappy child. The faces on your mat show it live.")
	var rows := [
		["res://assets/ui/route.svg", "Needs: +2, 0 or -2", "A need is met when a road path runs from the home to a matching place (a child's park only needs to be in the home's 3x3 area). Both needs met is +2, one is 0, none is -2. Standing next to each other without a road does not count."],
		["res://assets/ui/trophy.svg", "+1 for something they like", "Any one of a citizen's liked places within reach, or a liked street on their route or next to their home, adds +1 once."],
		["res://assets/ui/leaf.svg", "+1 per park or trees nearby (up to +2)", "A park cheers up its whole 3x3 area, diagonals included. Trees cheer up the 4 tiles that share an edge with them. Everyone in the home shares it."],
		["res://assets/ui/sun.svg", "-1 for a long, hot walk", "A route of %d or more road tiles to something a citizen needs costs 1 happiness from the heat (older residents feel it twice), unless at least one road on it is shaded." % Scoring.LONG_ROUTE],
		["res://assets/ui/leaf.svg", "Shade", "A road next to trees or a park counts as shaded. It shows a leafy green shadow on the side facing the trees and a Shade badge. Grey smog clouds are pollution, not shade."],
	]
	for r in rows:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(r[1], 20, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label(r[2], 16, UiKit.MUTED))
		_content.add_child(_card([UiKit.icon(r[0], 44), col]))
	_h("Pollution")
	_p("Every mat starts at pollution %d. Each [b]park lowers it by 3[/b] and each [b]trees tile by 1[/b], never below 0. At the end it changes the happiness of every citizen on that mat:" % Scoring.START_POLLUTION)
	var bands := HBoxContainer.new()
	bands.add_theme_constant_override("separation", 12)
	for b in [["0 to 7", "No change", UiKit.OLIVE], ["8 to 12", "-1 happiness", UiKit.GOLD], ["13 to %d" % Scoring.START_POLLUTION, "-2 happiness", UiKit.HEAT]]:
		var v := VBoxContainer.new()
		v.add_child(UiKit.label(b[0], 28, b[2], "display_bold"))
		v.add_child(UiKit.label(b[1], 16, UiKit.LIMESTONE))
		var c := _card([v])
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bands.add_child(c)
	_content.add_child(bands)
	_p("Example: 2 parks and 2 trees bring a mat from %d down to %d, so pollution no longer affects anyone. A mat with no green space stays at %d and every citizen on it loses 2 happiness." % [Scoring.START_POLLUTION, Scoring.START_POLLUTION - 8, Scoring.START_POLLUTION], UiKit.MUTED, 16)


func _complaints() -> void:
	_h("Complaints")
	_p("Every unhappy citizen (below 0) files a complaint. A missing need always comes first and is named in plain words, for example [b]No library within reach[/b]. You can see them on each home's card while you play.")
	for type in Describe.COMPLAINTS:
		var c: Dictionary = Describe.COMPLAINTS[type]
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(type, 21, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label("%s The fix: %s." % [c["meaning"], c["fix"].to_lower()], 16, UiKit.MUTED))
		_content.add_child(_card([UiKit.icon(c["icon"], 44), col]))
	_p("At the end of the game, each planner names the one change that would add the most points to their city. Every citizen below +5 and every service nobody reaches still has room to improve, so there is always something to name.")


func _turn_cards() -> void:
	_h("Event and penalty cards")
	_p("At the start of every turn, tap the coin. [b]Heads[/b]: tap the [color=#6FD08C][b]event deck[/b][/color] for good news. [b]Tails[/b]: tap the [color=#F08A78][b]penalty deck[/b][/color] for trouble. The card is shown to everyone and its effect happens [b]at once[/b].")
	var decks := HBoxContainer.new()
	decks.add_theme_constant_override("separation", 12)
	for pair in [[CardDefs.EVENT, "Event cards", "Reward planners: gold, free tiles, cheaper tiles, extra buys or points. Some reward several planners, and some take from the others.", "res://assets/ui/event.svg"],
			[CardDefs.PENALTY, "Penalty cards", "Punish planners: fees, lost tiles, dearer tiles, fewer buys or lost points. Some hit several planners, and some give you a choice of pain.", "res://assets/ui/penalty.svg"]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(pair[1], 22, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label(pair[2], 16, UiKit.MUTED))
		var c := _card([UiKit.icon(pair[3], 60), col])
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		decks.add_child(c)
	_content.add_child(decks)
	_p("[b]How cards work.[/b] Each deck has %d cards and a card is drawn at most once per game. Gold never drops below 0, and you cannot pay more than you have. \"The player with the most or least\" means everyone who ties for it. A card that changes prices or the number of tiles you may buy lasts for this turn only. A free tile is placed from the [b]Free tile[/b] button (B), costs nothing and is not one of your purchases. Some cards ask you to choose between two options. Every card you draw is remembered: on the final scoring screen, press [b]Show cards[/b] under a city to see each card and what it did to that planner's gold and points." % CardDefs.DECK_SIZE, UiKit.MUTED, 16)
	for type in CardDefs.TYPES:
		_h("Every event card" if type == CardDefs.EVENT else "Every penalty card")
		for id in CardDefs.ids(type):
			var info := CardDefs.info(id)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 0)
			col.add_child(UiKit.label(info["title"], 18, UiKit.LIMESTONE, "display_bold"))
			col.add_child(_wrap_label(info["rule"], 15, UiKit.MUTED))
			var badge := UiKit.chip(info["badge"], Color("#2F7A4A") if type == CardDefs.EVENT else Color("#8E3328"), UiKit.LIMESTONE, 13)
			_content.add_child(_card([UiKit.icon(CardDefs.art_path(id), 52), col, badge]))


func _events() -> void:
	_h("Hidden circumstances")
	_p("At the start of every round one hidden circumstance card is turned over. The deck holds %d cards and a game draws %d of them, so nobody knows what is coming. Every planner gets the same card, and it changes only happiness, points or gold, never your tiles." % [CircumstanceDefs.IDS.size(), GameState.ROUNDS])
	_p("[b]Happiness effects[/b] stay on until the end of the game and count in every score. [b]Gold effects[/b] happen once, the moment the card is revealed (gold never drops below 0). The cards shown so far sit in the top bar: hover one to read it again.", UiKit.MUTED, 16)
	for id in CircumstanceDefs.IDS:
		var info := CircumstanceDefs.info(id)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := HBoxContainer.new()
		title.add_theme_constant_override("separation", 10)
		title.add_child(UiKit.label(info["title"], 21, UiKit.LIMESTONE, "display_bold"))
		var weather: bool = info["family"] == CircumstanceDefs.FAMILY_WEATHER
		title.add_child(UiKit.chip(info["family"], UiKit.SKY if weather else UiKit.BOUG, Color.WHITE, 13))
		col.add_child(title)
		col.add_child(_rule_text(info["rule"], 17))
		col.add_child(_wrap_label(info["tip"], 15, UiKit.MUTED))
		_content.add_child(_card([UiKit.icon(CircumstanceDefs.art_path(id), 84), col]))
	_p("[b]Tip:[/b] keep a little gold in reserve for a budget cut, shade your long walks for a heatwave, and put parks and trees next to your homes. Those choices pay off whichever card turns up.", UiKit.LIMESTONE, 16)


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
