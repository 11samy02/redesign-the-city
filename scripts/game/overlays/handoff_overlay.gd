extends Control
## Hand-off card shown before each human turn: who is up, their gold and their place in the round.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")

signal dismissed

const PLACES := ["1st", "2nd", "3rd", "4th"]

var _gs
var _card: PanelContainer
var _avatar: Widgets.Avatar
var _done := false


func _init(gs) -> void:
	_gs = gs


func _ready() -> void:
	OverlayKit.fill_dimmed(self, 0.9)
	var p = _gs.current_player()
	var col := UiKit.player_color(p.color_index)
	_card = OverlayKit.add_card(self, OverlayKit.planner_card_style(col, 28, 40, 10, 40), 620)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	_card.add_child(v)

	_avatar = Widgets.Avatar.new(110)
	_avatar.color = col
	_avatar.letter = p.name.substr(0, 1).to_upper()
	var av_box := CenterContainer.new()
	av_box.add_child(_avatar)
	v.add_child(av_box)
	v.add_child(_centered_label("Round %d of %d. %s plays %s of %d this round." % [
		_gs.round_number, _gs.ROUNDS, p.name, PLACES[_gs.turn], _gs.players.size()], 18, UiKit.MUTED))
	v.add_child(_centered_label("%s's turn" % p.name, 52, col.lightened(0.2), "display_bold"))
	v.add_child(_centered_label(_pass_text(p), 20, UiKit.LIMESTONE))
	v.add_child(_build_chips(p))
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	v.add_child(gap)
	v.add_child(_build_start_row())

	gui_input.connect(_on_gui_input)
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	modulate.a = 0.0
	await get_tree().process_frame
	_animate_in()


func _pass_text(p) -> String:
	if Game.human_count() > 1:
		return "Pass the mouse and keyboard to %s." % p.name
	if _gs.round_number > 1 or _gs.turn > 0:
		return "You are up. The bots have made their moves."
	return "You are up first. Good luck, planner."


func _build_chips(p) -> Control:
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	var r: Dictionary = _gs.score(_gs.current_index())
	chips.add_child(UiKit.chip("%d gold" % p.money, UiKit.GOLD_DEEP, UiKit.LIMESTONE, 15))
	chips.add_child(UiKit.chip("Buy 2 tiles", UiKit.PANEL_HI, UiKit.LIMESTONE, 15))
	chips.add_child(UiKit.chip("%d free road%s" % [p.free_roads, "" if p.free_roads == 1 else "s"], UiKit.PANEL_HI, UiKit.LIMESTONE, 15))
	chips.add_child(UiKit.chip("%s so far" % Describe.points(r["total"]), UiKit.PANEL_HI, UiKit.LIMESTONE, 15))
	return chips


func _build_start_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var start := UiKit.button("Start my turn", "primary", 24)
	start.pressed.connect(_finish)
	row.add_child(start)
	row.add_child(UiKit.keycap("Enter"))
	return row


func _centered_label(text: String, size: int, color: Color, kind := "body") -> Label:
	var l := UiKit.label(text, size, color, kind)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _animate_in() -> void:
	_card.pivot_offset = _card.size / 2
	_card.scale = Vector2.ONE * 0.85
	_avatar.pivot_offset = _avatar.size / 2
	_avatar.scale = Vector2.ZERO
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_avatar, "scale", Vector2.ONE, 0.5).set_delay(0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("turn")


func _on_gui_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var out := create_tween().set_parallel()
	out.tween_property(self, "modulate:a", 0.0, 0.22)
	out.tween_property(_card, "scale", Vector2.ONE * 1.05, 0.22)
	await out.finished
	dismissed.emit()
	queue_free()
