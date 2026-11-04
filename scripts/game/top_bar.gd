extends HBoxContainer
## Top strip of the game screen: logo, round tracker and the help / sound / menu buttons.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const CircumstanceStrip = preload("res://scripts/game/circumstance_strip.gd")
const GameState = preload("res://scripts/core/game_state.gd")

signal rules_pressed
signal sound_pressed
signal menu_pressed
signal circumstance_pressed(index: int)

var _round_label: Label
var _round_tracker: Widgets.RoundTracker
var _circumstance_strip: CircumstanceStrip
var _sound_btn: Button


func _init(muted: bool, tooltip, rounds: int) -> void:
	add_theme_constant_override("separation", 14)
	add_child(_build_logo())
	add_child(UiKit.spacer())
	add_child(_build_round_tracker(tooltip, rounds))
	add_child(UiKit.spacer())
	add_child(_build_buttons(muted))


func set_round(current: int, total: int) -> void:
	_round_tracker.total = total
	_round_tracker.current = current
	_round_label.text = "Round %d of %d" % [current, total]


func set_circumstances(revealed: Array, round_number: int) -> void:
	_circumstance_strip.refresh(revealed, round_number)


func set_muted(muted: bool) -> void:
	_sound_btn.text = "Sound off" if muted else "Sound on"


func _build_logo() -> Control:
	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 10)
	logo.add_child(UiKit.icon("res://assets/tiles/home_small_worker.svg", 40))
	logo.add_child(UiKit.label("Redesign the City", 26, UiKit.LIMESTONE, "display_bold"))
	logo.custom_minimum_size.x = 270
	return logo


func _build_round_tracker(tooltip, rounds: int) -> Control:
	var rt := HBoxContainer.new()
	rt.add_theme_constant_override("separation", 12)
	_round_label = UiKit.label("Round 1 of %d" % rounds, 22, UiKit.LIMESTONE, "display_bold")
	rt.add_child(_round_label)
	_round_tracker = Widgets.RoundTracker.new()
	rt.add_child(_round_tracker)
	var gap := Control.new()
	gap.custom_minimum_size.x = 10
	rt.add_child(gap)
	_circumstance_strip = CircumstanceStrip.new(tooltip, rounds)
	_circumstance_strip.card_pressed.connect(circumstance_pressed.emit)
	rt.add_child(_circumstance_strip)
	return rt


func _build_buttons(muted: bool) -> Control:
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.custom_minimum_size.x = 300
	btns.add_theme_constant_override("separation", 8)
	var help := UiKit.button("How to play", "ghost", 16)
	help.pressed.connect(rules_pressed.emit)
	btns.add_child(help)
	_sound_btn = UiKit.button("", "ghost", 16)
	_sound_btn.pressed.connect(sound_pressed.emit)
	btns.add_child(_sound_btn)
	set_muted(muted)
	var menu := UiKit.button("Menu", "ghost", 16)
	menu.pressed.connect(menu_pressed.emit)
	btns.add_child(menu)
	return btns
