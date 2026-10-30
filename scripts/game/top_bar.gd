extends HBoxContainer
## Top strip of the game screen: logo, round tracker and the help / sound / menu buttons.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")

signal rules_pressed
signal sound_pressed
signal menu_pressed

var _round_label: Label
var _round_tracker: Widgets.RoundTracker
var _sound_btn: Button


func _init(muted: bool) -> void:
	add_theme_constant_override("separation", 14)
	add_child(_build_logo())
	add_child(UiKit.spacer())
	add_child(_build_round_tracker())
	add_child(UiKit.spacer())
	add_child(_build_buttons(muted))


func set_round(current: int, total: int) -> void:
	_round_tracker.current = current
	_round_label.text = "Round %d of %d" % [current, total]


func set_muted(muted: bool) -> void:
	_sound_btn.text = "Sound off" if muted else "Sound on"


func _build_logo() -> Control:
	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 10)
	logo.add_child(UiKit.icon("res://assets/tiles/apartment_small.svg", 40))
	logo.add_child(UiKit.label("Egkomi City", 30, UiKit.LIMESTONE, "display_bold"))
	logo.custom_minimum_size.x = 420
	return logo


func _build_round_tracker() -> Control:
	var rt := HBoxContainer.new()
	rt.add_theme_constant_override("separation", 14)
	_round_label = UiKit.label("Round 1 of 4", 22, UiKit.LIMESTONE, "display_bold")
	rt.add_child(_round_label)
	_round_tracker = Widgets.RoundTracker.new()
	rt.add_child(_round_tracker)
	return rt


func _build_buttons(muted: bool) -> Control:
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.custom_minimum_size.x = 420
	btns.add_theme_constant_override("separation", 8)
	var help := UiKit.button("How to play", "ghost", 17)
	help.pressed.connect(rules_pressed.emit)
	btns.add_child(help)
	_sound_btn = UiKit.button("", "ghost", 17)
	_sound_btn.pressed.connect(sound_pressed.emit)
	btns.add_child(_sound_btn)
	set_muted(muted)
	var menu := UiKit.button("Menu", "ghost", 17)
	menu.pressed.connect(menu_pressed.emit)
	btns.add_child(menu)
	return btns
