extends Control
## A planner's card for this turn: the coin flips, the card is drawn from the deck it picked, turns
## over, and its effect happens. A card that needs a decision shows its options under it. That is
## all: no list of what happened, the screen behind shows it (gold, tiles, points).
## Computer planners play it through on their own. Emits `dismissed` when it is done.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const CardEffects = preload("res://scripts/core/card_effects.gd")
const Face = preload("res://scripts/game/circumstance_card_face.gd")
const CardFx = preload("res://scripts/game/overlays/card_fx.gd")

## The card has left its deck (the screen can update the deck then).
signal dealt
signal dismissed
## A person tapped what they were asked to tap (the coin or the right deck).
signal _tapped

const CARD_W := Face.WIDTH
const CARD_H := Face.HEIGHT
const SIDE_W := 320.0
## Every choice under a card is the same size; the badge holds its key number.
const OPTION_W := 340.0
const OPTION_H := 84.0
const OPTION_BADGE := 44
const OPTION_OR_W := 64.0
## How much faster the running animations go when a bot's card is skipped.
const SKIP_SPEED := 40.0

var _gs
var _draw_info: Dictionary
var _auto: bool
var _stage: Control
var _front: Control
var _back: Control
var _coin: Coin
var _coin_title: Label
var _hint: Label
## The two decks a person draws from (type -> DeckPick); empty for a computer planner.
var _decks := {}
## What a person is being asked to tap right now: "coin", "deck" or "".
var _awaiting := ""
var _buttons: HBoxContainer
var _continue_row: Control
var _close_x: Button
var _resolved := false
var _done := false
var _tilt := 0.0
var _intro_rotation := 0.0
var _skip := false
var _tweens: Array[Tween] = []
var _from_rect := Rect2()
var _options: Array = []


## `draw_info` is what GameState.flip_and_draw returned. `auto` plays it out without waiting for a person.
## `from_rect` is where the top card of the deck is on screen: the card flies out of it.
func _init(gs, draw_info: Dictionary, auto := false, from_rect := Rect2()) -> void:
	_gs = gs
	_from_rect = from_rect
	_draw_info = draw_info
	_auto = auto


## A tween that can be hurried up when the card is skipped.
func _tw() -> Tween:
	var t := create_tween()
	if _skip:
		t.set_speed_scale(SKIP_SPEED)
	_tweens.append(t)
	return t


## Plays the rest of it at once: the pauses vanish and the running animations speed up.
## Only a computer planner's card can be skipped; a person reads their own.
func skip() -> void:
	if _skip or not _auto:
		return
	_skip = true
	for t in _tweens:
		if t.is_valid():
			t.set_speed_scale(SKIP_SPEED)


func _ready() -> void:
	var dim := OverlayKit.fill_dimmed(self, 0.8)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			if _auto:
				skip()
			elif _resolved:
				_finish())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)
	row.add_child(_build_coin_column())
	row.add_child(_build_card_column())
	# an empty column of the same width keeps the card in the middle of the screen
	var balance := Control.new()
	balance.custom_minimum_size.x = SIDE_W
	row.add_child(balance)
	modulate.a = 0.0
	CardFx.hide_parts(_front)
	await get_tree().process_frame
	_run()


# ================================================================ layout

func _build_coin_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = SIDE_W
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	var p = _gs.current_player()
	var title := UiKit.label(p.name, 24, UiKit.LIMESTONE, "display_bold")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_coin = Coin.new()
	_coin.custom_minimum_size = Vector2(210, 210)
	if not _auto:
		_coin.mouse_filter = Control.MOUSE_FILTER_STOP
		_coin.pressed.connect(_on_coin_tapped)
	col.add_child(_coin)
	_coin_title = UiKit.label("", 32, UiKit.LIMESTONE, "display_bold")
	_coin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_coin_title)
	_hint = UiKit.label("", 20, UiKit.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)
	return col


## The card with its options or its Continue button under it.
func _build_card_column() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	# the card and, for a person, the two decks to draw it from share the same spot
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(CARD_W, CARD_H)
	col.add_child(holder)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.custom_minimum_size = Vector2(CARD_W, CARD_H)
	_stage.size = Vector2(CARD_W, CARD_H)
	holder.add_child(_stage)
	var content := CardFx.supersampled_surface(self, _stage, CARD_W, CARD_H)
	_front = Face.front_turn(_draw_info["id"])
	_back = Face.back_turn(_draw_info["type"])
	content.add_child(_front)
	content.add_child(_back)
	for face in [_front, _back]:
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front.visible = false
	_stage.modulate.a = 0.0
	if not _auto:
		holder.add_child(_build_decks())
		# the X on the card's top-right corner appears with the Continue button, once the card has played out
		_close_x = OverlayKit.close_button(_finish)
		_close_x.position = Vector2(CARD_W - _close_x.size.x * 0.65, -_close_x.size.y * 0.35)
		_close_x.visible = false
		holder.add_child(_close_x)

	var under := Control.new()
	under.custom_minimum_size = Vector2(CARD_W, 64)
	col.add_child(under)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	# wider than the card, so it is pinned to the card's centre and grows to both sides: the "or"
	# then sits exactly under the middle of the card
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	under.add_child(_buttons)
	_continue_row = HBoxContainer.new()
	_continue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_continue_row.add_theme_constant_override("separation", 10)
	var go := UiKit.button("Continue", "primary", 24)
	go.pressed.connect(_finish)
	_continue_row.add_child(go)
	_continue_row.add_child(UiKit.keycap("Enter"))
	_continue_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	under.add_child(_continue_row)
	_continue_row.modulate.a = 0.0
	_continue_row.visible = false
	return col


# ================================================================ the sequence

func _wait(seconds: float) -> void:
	var left := seconds * (Game.bot_delay() if _auto else 1.0)
	while left > 0.0 and not _skip:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _run() -> void:
	if _auto and Game.bot_instant():
		# bots play unseen: the card still resolves, but nothing is shown
		skip()
		visible = false
	else:
		_tw().tween_property(self, "modulate:a", 1.0, 0.15)
	await _wait(0.2)
	if not _auto:
		await _ask_for_flip()
	await _flip_coin()
	await _wait(0.25)
	if not _auto:
		await _ask_for_deck()
	await _deal_card()
	await _turn_card_over()
	await _wait(0.2)
	_decide()


## The coin waits, bobbing, until the planner taps it.
func _ask_for_flip() -> void:
	_coin_title.text = "Tap the coin"
	_coin_title.add_theme_color_override("font_color", UiKit.GOLD)
	_coin.armed = true
	_awaiting = "coin"
	await _tapped
	_coin.armed = false


func _on_coin_tapped() -> void:
	if _awaiting != "coin":
		return
	_awaiting = ""
	_tapped.emit()


## Both decks light up; the planner has to tap the one the coin picked. The other one shakes.
func _ask_for_deck() -> void:
	var type: String = _draw_info["type"]
	_hint.text = "Tap the %s deck" % ("event" if type == CardDefs.EVENT else "penalty")
	for t in _decks:
		_decks[t].set_live(t == type)
	_awaiting = "deck"
	await _tapped
	_hint.text = ""


func _on_deck_tapped(type: String) -> void:
	if _awaiting != "deck":
		return
	if type != _draw_info["type"]:
		Sfx.play("error")
		_decks[type].shake()
		return
	_awaiting = ""
	Sfx.play("pick")
	var picked = _decks[type]
	_from_rect = picked.card_rect()
	picked.vanish()
	for t in _decks:
		if t != type:
			_decks[t].fade_to(0.0, 0.25)
	_tapped.emit()


func _build_decks() -> Control:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in [CardDefs.EVENT, CardDefs.PENALTY]:
		var d := DeckPick.new(t)
		d.tapped.connect(_on_deck_tapped.bind(t))
		row.add_child(d)
		_decks[t] = d
	return row


func _flip_coin() -> void:
	var heads: bool = _draw_info["coin"] == "heads"
	var spins := 6 if heads else 7
	Sfx.play("whoosh")
	var tw := _tw().set_parallel()
	tw.tween_property(_coin, "spin", float(spins), 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_coin, "hop", 1.0, 1.0).from(0.0)
	await tw.finished
	Sfx.play("coin_land")
	_coin_title.text = "Heads" if heads else "Tails"
	_coin_title.add_theme_color_override("font_color", Face.EVENT_TINT.lightened(0.45) if heads else Face.PENALTY_TINT.lightened(0.45))
	_coin_title.pivot_offset = _coin_title.size / 2.0
	if _auto:
		_hint.text = "Event card" if _draw_info["type"] == CardDefs.EVENT else "Penalty card"
	var pop := _tw()
	pop.tween_property(_coin_title, "scale", Vector2.ONE * 1.2, 0.08)
	pop.tween_property(_coin_title, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


## The face-down card is drawn from its deck: it lifts off the pile at its small size and flies in a
## curve to the middle of the screen, growing and straightening as it comes.
func _deal_card() -> void:
	_stage.pivot_offset = _stage.size / 2.0
	var rest := _stage.position
	var start := rest + Vector2(0, 90)
	var small := 0.7
	if _from_rect.size != Vector2.ZERO:
		start = rest + (_from_rect.get_center() - _stage.get_global_rect().get_center())
		small = _from_rect.size.x / CARD_W
	_stage.scale = Vector2.ONE * small
	_stage.position = start
	_stage.modulate.a = 1.0
	_intro_rotation = -0.5 if _from_rect.size != Vector2.ZERO else -0.08
	dealt.emit()
	Sfx.play("whoosh")
	# a curve that swings out above the straight line
	var control := (start + rest) / 2.0 + Vector2(0, -160)
	var tw := _tw().set_parallel()
	tw.tween_method(func(t: float): _stage.position = start.lerp(control, t).lerp(control.lerp(rest, t), t), 0.0, 1.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_stage, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_intro_rotation", 0.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await _wait(0.1)


func _turn_card_over() -> void:
	_back.pivot_offset = _back.size / 2.0
	_front.pivot_offset = _front.size / 2.0
	var half := _tw()
	half.tween_property(_back, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await half.finished
	_back.visible = false
	_front.visible = true
	_front.scale.x = 0.0
	Sfx.play("whoosh")
	var full := _tw()
	full.tween_property(_front, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await full.finished
	Sfx.play("place")
	await CardFx.bring_to_life(self, _front, [], _tw().set_parallel()).finished


## A normal card just happens. A card with a choice waits for the planner (or the bot's pick).
func _decide() -> void:
	if not _gs.card_needs_choice():
		_resolve(-1)
		return
	_options = _gs.card_choice_options()
	if _auto:
		await _wait(0.5)
		_resolve(CardEffects.pick_option(_gs, _gs.current_index(), _options))
		return
	for k in _options.size():
		var o: Dictionary = _options[k]
		if k > 0:
			var or_label := _or_label()
			_buttons.add_child(or_label)
			or_label.modulate.a = 0.0
			_tw().tween_property(or_label, "modulate:a", 1.0, 0.3)
		var b := _option_button(k, o)
		b.disabled = not o["available"]
		b.tooltip_text = "" if o["available"] else "You cannot afford this one."
		b.pressed.connect(_resolve.bind(k))
		_buttons.add_child(b)
		b.modulate.a = 0.0
		_tw().tween_property(b, "modulate:a", 1.0, 0.3)


## The "or" that sits centred between two choices.
func _or_label() -> Label:
	var l := Label.new()
	l.text = "or"
	l.custom_minimum_size = Vector2(OPTION_OR_W, OPTION_H)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiKit.font("display_bold"))
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", UiKit.LIMESTONE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## One choice under the card: a round key badge with the number, then the text. Every option has the
## same size and the same text size, however short its words are.
func _option_button(k: int, o: Dictionary) -> Button:
	var ok: bool = o["available"]
	var b := UiKit.button("", "gold" if ok else "ghost", 22)
	b.set_meta("option", k)
	b.custom_minimum_size = Vector2(OPTION_W, OPTION_H)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	b.add_child(row)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(OPTION_BADGE, OPTION_BADGE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", UiKit.box(UiKit.INK if ok else Color(1, 1, 1, 0.12), OPTION_BADGE / 2))
	var num := Label.new()
	num.text = str(k + 1)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_override("font", UiKit.font("display_bold"))
	num.add_theme_font_size_override("font_size", 24)
	num.add_theme_color_override("font_color", UiKit.GOLD if ok else UiKit.LIMESTONE)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(num)
	row.add_child(badge)
	var text := Label.new()
	text.text = o["label"]
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_override("font", UiKit.font("display"))
	text.add_theme_font_size_override("font_size", 22)
	text.add_theme_color_override("font_color", UiKit.INK if ok else UiKit.LIMESTONE)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	return b


func _resolve(choice: int) -> void:
	if _resolved:
		return
	var result: Dictionary = _gs.resolve_turn_card(choice)
	if result.is_empty():
		return
	_resolved = true
	for b in _buttons.get_children():
		b.queue_free()
	Sfx.play("coin" if result["type"] == CardDefs.EVENT else "minus")
	if _auto:
		await _wait(0.9)
		_finish()
	else:
		_continue_row.visible = true
		_tw().tween_property(_continue_row, "modulate:a", 1.0, 0.3)
		_close_x.modulate.a = 0.0
		_close_x.visible = true
		_tw().tween_property(_close_x, "modulate:a", 1.0, 0.3)


# ================================================================ input and finish

func _process(delta: float) -> void:
	if _stage == null or _done:
		return
	_tilt = CardFx.lean(self, _stage, _tilt, _intro_rotation, delta)


func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	if _auto:
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			skip()
			get_viewport().set_input_as_handled()
		return
	if _awaiting != "":
		# keyboard: Enter or Space taps the coin, or the glowing deck; 1 and 2 pick a deck by position
		if _awaiting == "coin" and key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_on_coin_tapped()
		elif _awaiting == "deck" and key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_on_deck_tapped(_draw_info["type"])
		elif _awaiting == "deck" and key in [KEY_1, KEY_KP_1]:
			_on_deck_tapped(CardDefs.EVENT)
		elif _awaiting == "deck" and key in [KEY_2, KEY_KP_2]:
			_on_deck_tapped(CardDefs.PENALTY)
		get_viewport().set_input_as_handled()
		return
	if not _resolved and not _options.is_empty() and key in [KEY_1, KEY_2, KEY_KP_1, KEY_KP_2]:
		var k := 0 if key in [KEY_1, KEY_KP_1] else 1
		if k < _options.size() and _options[k]["available"]:
			_resolve(k)
		get_viewport().set_input_as_handled()
	elif _resolved and key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		_finish()
		get_viewport().set_input_as_handled()
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if _done or not _resolved:
		return
	_done = true
	await CardFx.lift_away(self, _stage, _tw().set_parallel()).finished
	dismissed.emit()
	queue_free()


## The coin: a gold disc that spins, heads (a star on green) on one side, tails (a warning sign on
## red) on the other. `spin` counts half turns; an even number lands on heads.
class Coin extends Control:
	signal pressed
	var spin := 0.0:
		set(v):
			spin = v
			queue_redraw()
	var hop := 0.0:
		set(v):
			hop = v
			queue_redraw()
	## Waiting for a tap: the coin bobs and a gold ring pulses around it.
	var armed := false:
		set(v):
			armed = v
			set_process(v)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if v else Control.CURSOR_ARROW
			queue_redraw()
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if armed and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var bob := sin(_t * 4.0) * 5.0 if armed else 0.0
		var c := size / 2.0 + Vector2(0, -sin(hop * PI) * 46.0 + bob)
		var r := minf(size.x, size.y) * 0.42
		if armed:
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_arc(c, r + 10.0 + pulse * 5.0, 0.0, TAU, 56, Color(UiKit.GOLD, 0.35 + 0.45 * pulse), 4.0, true)
		var k := cos(spin * PI)
		var heads := k >= 0.0
		var sx := maxf(0.06, absf(k))
		draw_set_transform(c, 0.0, Vector2(sx, 1.0))
		draw_circle(Vector2(0, r * 0.1 + 14.0 + sin(hop * PI) * 30.0), r, Color(0, 0, 0, 0.25 * (1.0 - sin(hop * PI) * 0.6)), true, -1.0, true)
		var body := Color("#2FA05A") if heads else Color("#C8402A")
		draw_circle(Vector2.ZERO, r, Color("#B9810F"), true, -1.0, true)
		draw_circle(Vector2.ZERO, r - 5.0, Color("#F2B630"), true, -1.0, true)
		draw_circle(Vector2.ZERO, r - 14.0, body.darkened(0.15), true, -1.0, true)
		draw_circle(Vector2.ZERO, r - 17.0, body, true, -1.0, true)
		for i in 28:
			var a := TAU * float(i) / 28.0
			draw_circle(Vector2(cos(a), sin(a)) * (r - 9.5), 1.8, Color("#B9810F"), true, -1.0, true)
		var icon := UiKit.tex("res://assets/ui/event.svg" if heads else "res://assets/ui/penalty.svg")
		var s := r * 1.15
		draw_texture_rect(icon, Rect2(Vector2(-s / 2.0, -s / 2.0), Vector2(s, s)), false)
		draw_arc(Vector2.ZERO, r - 3.0, -2.6, -1.2, 16, Color(1, 1, 1, 0.6), 3.0, true)
		draw_set_transform(Vector2.ZERO)


## A face-down deck on the table. It waits dimmed until the coin has landed, then the deck the coin
## picked glows and bobs and the other one stays dim; tapping the wrong one only shakes it.
class DeckPick extends Control:
	signal tapped

	const PILE := Vector2(190, 266)
	const REST_Y := 10.0

	var type := ""
	var _art: TextureRect
	var _tint: Color
	var _live := false
	var _glow := false
	var _hover := false
	var _tween: Tween
	var _fade: Tween
	var lift := 0.0:
		set(v):
			lift = v
			if _art != null:
				_art.position.y = REST_Y - v
			queue_redraw()

	func _init(deck_type: String) -> void:
		type = deck_type
		var event := type == CardDefs.EVENT
		_tint = Face.EVENT_TINT if event else Face.PENALTY_TINT
		custom_minimum_size = Vector2(PILE.x, PILE.y + 56)
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate = Color(1, 1, 1, 0.4)
		var sub := SubViewport.new()
		sub.size = Vector2i(PILE * 2.0)
		sub.size_2d_override = Vector2i(Face.WIDTH, Face.HEIGHT)
		sub.size_2d_override_stretch = true
		sub.transparent_bg = true
		sub.msaa_2d = Viewport.MSAA_4X
		sub.gui_disable_input = true
		sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sub)
		var back := Face.back_turn(type)
		back.size = Vector2(Face.WIDTH, Face.HEIGHT)
		sub.add_child(back)
		_art = TextureRect.new()
		_art.texture = sub.get_texture()
		_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_SCALE
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.size = PILE
		_art.position = Vector2(0, REST_Y)
		add_child(_art)
		var name_label := UiKit.label("Event" if event else "Penalty", 24, _tint.lightened(0.4), "display_bold")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.position = Vector2(0, PILE.y + 18)
		name_label.size.x = PILE.x
		add_child(name_label)
		mouse_entered.connect(func():
			_hover = true
			if _live and not _glow:
				_move(8.0))
		mouse_exited.connect(func():
			_hover = false
			if _live and not _glow:
				_move(0.0))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tapped.emit()
			accept_event()

	## After the flip: `glow` marks the deck to draw from, the other one is dimmed but still tappable.
	func set_live(glow: bool) -> void:
		_live = true
		_glow = glow
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		fade_to(1.0 if glow else 0.5, 0.25)
		if glow:
			_kill_tween()
			_tween = create_tween().set_loops()
			_tween.tween_property(self, "lift", 12.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_tween.tween_property(self, "lift", 3.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		queue_redraw()

	## Fades the deck, replacing any fade still running (a quick tap must not be undone by the fade-in).
	func fade_to(alpha: float, seconds: float) -> void:
		if _fade != null and _fade.is_valid():
			_fade.kill()
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", alpha, seconds)

	## The deck's card has been drawn: it is gone for good, along with its glow and bobbing.
	func vanish() -> void:
		if _fade != null and _fade.is_valid():
			_fade.kill()
		_kill_tween()
		modulate.a = 0.0
		visible = false

	func shake() -> void:
		_kill_tween()
		_tween = create_tween()
		for i in 4:
			_tween.tween_property(_art, "position:x", 7.0 if i % 2 == 0 else -7.0, 0.04)
		_tween.tween_property(_art, "position:x", 0.0, 0.04)

	## Where the deck's card is on screen, for the card that flies out of it.
	func card_rect() -> Rect2:
		return _art.get_global_rect()

	func _move(to: float) -> void:
		_kill_tween()
		_tween = create_tween()
		_tween.tween_property(self, "lift", to, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _kill_tween() -> void:
		if _tween != null and _tween.is_valid():
			_tween.kill()

	func _draw() -> void:
		if _glow:
			var ring := UiKit.box(Color(_tint, 0.0), 22, 4, UiKit.GOLD)
			ring.draw_center = false
			draw_style_box(ring, Rect2(_art.position, PILE).grow(7))
