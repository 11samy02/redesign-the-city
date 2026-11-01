extends Control
## The results card: winner headline, ranked rows and the end-of-game buttons.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")

signal reflect_pressed
signal cities_pressed
signal again_pressed
signal menu_pressed
## The "Cards" button of a row: the seat of that planner.
signal cards_pressed(index: int)

const PLACES := ["1st", "2nd", "3rd", "4th"]

var _screen
var _gs
var _results: Array
var _ranks := {}
var _order: Array = []
var _rows: Array = []
var _headline: Label
var _crown: TextureRect
var _buttons: HBoxContainer


## `screen` is the final scene: it supplies the game state, scores, effects layer and pacing.
func _init(screen) -> void:
	_screen = screen
	_gs = screen.gs
	_results = screen.results
	_rank_players()


## Player index -> rank (1 = winner; ties share a rank).
func ranks() -> Dictionary:
	return _ranks


func _ready() -> void:
	OverlayKit.fill_dimmed(self, 0.86)
	var sb := UiKit.box(UiKit.PANEL, 28, 2, UiKit.LINE, 34)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 40
	var card := OverlayKit.add_card(self, sb, 900)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	_crown = UiKit.icon("res://assets/ui/crown.svg", 84)
	var crown_box := CenterContainer.new()
	crown_box.add_child(_crown)
	v.add_child(crown_box)
	_headline = UiKit.label(_headline_text(), 52, UiKit.GOLD, "display_bold")
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_headline)
	var sub := UiKit.label("The happiest city in Egkomi after %d rounds." % _gs.ROUNDS, 18, UiKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_build_circumstance_recap())
	for i in _order:
		var row := _build_row(i)
		v.add_child(row)
		_rows.append(row)
	_buttons = _build_buttons()
	v.add_child(_buttons)
	_reveal()


## Higher total wins; ties go to more happy citizens, then more gold.
func _rank_players() -> void:
	_order = range(_gs.players.size())
	_order.sort_custom(func(a, b):
		var ra: Dictionary = _results[a]
		var rb: Dictionary = _results[b]
		if ra["total"] != rb["total"]:
			return ra["total"] > rb["total"]
		if ra["happy_citizens"] != rb["happy_citizens"]:
			return ra["happy_citizens"] > rb["happy_citizens"]
		return _gs.players[a].money > _gs.players[b].money)
	for pos in _order.size():
		var i: int = _order[pos]
		_ranks[i] = 1 if pos == 0 else (_ranks[_order[pos - 1]] if _same_rank(_order[pos - 1], i) else pos + 1)


func _same_rank(a: int, b: int) -> bool:
	return _results[a]["total"] == _results[b]["total"] and _results[a]["happy_citizens"] == _results[b]["happy_citizens"] \
		and _gs.players[a].money == _gs.players[b].money


func _headline_text() -> String:
	var winners := []
	for i in _order:
		if _ranks[i] == 1:
			winners.append(_gs.players[i].name)
	return "%s wins!" % winners[0] if winners.size() == 1 else "%s share the win!" % " and ".join(PackedStringArray(winners))


## The hidden circumstances that shaped this game, in the order they were revealed.
func _build_circumstance_recap() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for id in _gs.revealed:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 6)
		chip.add_child(UiKit.icon(CircumstanceDefs.art_path(id), 34))
		chip.add_child(UiKit.label(CircumstanceDefs.title(id), 15, UiKit.MUTED, "body_bold"))
		row.add_child(chip)
	return row


static func ordinal(n: int) -> String:
	return PLACES[clampi(n - 1, 0, PLACES.size() - 1)]


func _build_row(i: int) -> Control:
	var p = _gs.players[i]
	var r: Dictionary = _results[i]
	var col := UiKit.player_color(p.color_index)
	var first: bool = _ranks[i] == 1
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.GOLD, 0.16) if first else UiKit.PANEL_HI, 16, 2 if first else 0, UiKit.GOLD, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	rp.add_child(h)
	var rank_l := UiKit.label(ordinal(_ranks[i]), 30, UiKit.GOLD if first else UiKit.MUTED, "display_bold")
	rank_l.custom_minimum_size.x = 64
	h.add_child(rank_l)
	var av := Widgets.Avatar.new(46)
	av.color = col
	av.letter = p.name.substr(0, 1).to_upper()
	h.add_child(av)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", -2)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(UiKit.label(p.name, 24, col.lightened(0.25), "display_bold"))
	nv.add_child(UiKit.label("%d of %d citizens happy, %d loan%s, %d gold left" % [r["happy_citizens"], r["citizens"], r["loans"], "" if r["loans"] == 1 else "s", p.money], 15, UiKit.MUTED))
	h.add_child(nv)
	var drawn: int = _gs.cards_drawn_by(i).size()
	if drawn > 0:
		var cards_btn := UiKit.button("%d cards" % drawn, "ghost", 16)
		cards_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cards_btn.tooltip_text = "See every event and penalty card %s drew, and what each one did." % p.name
		cards_btn.pressed.connect(func(): cards_pressed.emit(i))
		h.add_child(cards_btn)
	h.add_child(UiKit.label(Describe.points(r["total"]), 32, UiKit.LIMESTONE, "display_bold"))
	return rp


func _build_buttons() -> HBoxContainer:
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	var reflect := UiKit.button("Name the one change", "primary", 22)
	reflect.pressed.connect(reflect_pressed.emit)
	btns.add_child(reflect)
	var cities := UiKit.button("View cities", "secondary", 20)
	cities.pressed.connect(cities_pressed.emit)
	btns.add_child(cities)
	var again := UiKit.button("Play again", "secondary", 20)
	again.pressed.connect(again_pressed.emit)
	btns.add_child(again)
	var menu := UiKit.button("Main menu", "ghost", 20)
	menu.pressed.connect(menu_pressed.emit)
	btns.add_child(menu)
	return btns


## Last place first, the winner last, then the crown drops in with confetti.
func _reveal() -> void:
	modulate.a = 0.0
	for rp in _rows:
		rp.modulate.a = 0.0
	_headline.modulate.a = 0.0
	_crown.modulate.a = 0.0
	_buttons.modulate.a = 0.0
	await get_tree().process_frame
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	await _screen.wait(0.4)
	for k in range(_rows.size() - 1, -1, -1):
		var rp: Control = _rows[k]
		var x := rp.position.x
		rp.position.x = x - 60
		var tw := create_tween().set_parallel()
		tw.tween_property(rp, "modulate:a", 1.0, 0.3)
		tw.tween_property(rp, "position:x", x, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play("pop", 0.8 + (_rows.size() - k) * 0.1)
		await _screen.wait(0.45)
	_crown.pivot_offset = _crown.size / 2
	_crown.position.y -= 60
	var ct := create_tween().set_parallel()
	ct.tween_property(_crown, "modulate:a", 1.0, 0.2)
	ct.tween_property(_crown, "position:y", _crown.position.y + 60, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	ct.tween_property(_headline, "modulate:a", 1.0, 0.4).set_delay(0.2)
	ct.tween_property(_buttons, "modulate:a", 1.0, 0.4).set_delay(0.6)
	Sfx.play("fanfare")
	var vp := get_viewport_rect().size
	Widgets.burst(_screen.fx, Vector2(vp.x * 0.2, vp.y + 10), "confetti", 70)
	Widgets.burst(_screen.fx, Vector2(vp.x * 0.8, vp.y + 10), "confetti", 70)
	await _screen.wait(0.5)
	Widgets.burst(_screen.fx, Vector2(vp.x * 0.5, vp.y + 10), "confetti", 90)
