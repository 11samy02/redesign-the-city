extends PanelContainer
## Centre-top card: whose city it is, their gold and the live stats of that city.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const Tooltip = preload("res://scripts/ui/tooltip.gd")
const Bot = preload("res://scripts/core/bot.gd")

const COIN := "res://assets/ui/coin.svg"

var _tooltip: Tooltip
var _avatar: Widgets.Avatar
var _name_label: Label
var _sub_label: Label
var _money_label: Label
var _money_icon: TextureRect
var _shown_money := 0
var _stat_values := {}
var _stat_notes := {}
var _gauge: Widgets.PollutionGauge


func _init(tooltip: Tooltip) -> void:
	_tooltip = tooltip
	add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 18, 1, UiKit.LINE, 14))
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 12)
	add_child(bv)
	bv.add_child(_build_top_row())
	bv.add_child(_build_stats())


## Shows `p`'s city: name, bot tag and the stats read from their scoring `result`.
func show_player(p, result: Dictionary) -> void:
	var col := UiKit.player_color(p.color_index)
	_avatar.color = col
	_avatar.letter = p.name.substr(0, 1).to_upper()
	_name_label.text = p.name
	_name_label.add_theme_color_override("font_color", col.lightened(0.25))
	_sub_label.text = ("%s bot, building their city" % Bot.level_name(p.bot_level)) if p.is_bot() else "is building their city"

	var poll: int = result["pollution"]
	var pen: int = result["pollution_penalty"]
	_stat_values["pollution"].text = "%d, %s" % [poll, "no effect" if pen == 0 else "-%d each" % pen]
	_stat_values["pollution"].add_theme_color_override("font_color", UiKit.OLIVE if pen == 0 else (UiKit.GOLD if pen == 1 else UiKit.HEAT))
	create_tween().tween_property(_gauge, "level", float(poll), 0.5).set_trans(Tween.TRANS_CUBIC)
	_stat_values["citizens"].text = "%d of %d" % [result["happy_citizens"], result["citizens"]]
	_stat_values["score"].text = Describe.points(result["total"])
	_stat_notes["score"].text = "Score now" if p.loans == 0 else "Score now, %d loan%s" % [p.loans, "" if p.loans == 1 else "s"]
	_stat_values["score"].add_theme_color_override("font_color", UiKit.OLIVE if result["total"] > 0 else (UiKit.HEAT if result["total"] < 0 else UiKit.LIMESTONE))
	_stat_values["extras"].text = "%d left" % p.free_roads


## Jumps the gold counter to `amount` without animating.
func set_money(amount: int) -> void:
	_shown_money = amount
	_money_label.text = str(amount)


## Counts the gold up or down to `to` with a small pop.
func animate_money(to: int) -> void:
	var from := _shown_money
	_shown_money = to
	var tw := create_tween()
	tw.tween_method(func(v: float): _money_label.text = str(roundi(v)), float(from), float(to), 0.45)
	_money_label.pivot_offset = _money_label.size / 2
	var pt := create_tween()
	pt.tween_property(_money_label, "scale", Vector2.ONE * 1.18, 0.1)
	pt.tween_property(_money_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func coin_center() -> Vector2:
	return _money_icon.get_global_rect().get_center()


func gauge_center() -> Vector2:
	return _gauge.get_global_rect().get_center()


func _build_top_row() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_avatar = Widgets.Avatar.new(54)
	top.add_child(_avatar)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	_name_label = UiKit.label("", 30, UiKit.LIMESTONE, "display_bold")
	_sub_label = UiKit.label("", 15, UiKit.MUTED)
	names.add_child(_name_label)
	names.add_child(_sub_label)
	top.add_child(names)
	top.add_child(UiKit.spacer())
	top.add_child(_build_money())
	return top


func _build_money() -> Control:
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 6)
	_money_icon = UiKit.icon(COIN, 44)
	money.add_child(_money_icon)
	_money_label = UiKit.label("20", 40, UiKit.GOLD, "display_bold")
	money.add_child(_money_label)
	money.mouse_filter = Control.MOUSE_FILTER_PASS
	money.mouse_entered.connect(func(): _tooltip.show_text("Gold", ["Pay for tiles from the construction site.", "Loans add 10 gold but cost 2 points at the end."], money.get_global_rect(), COIN))
	money.mouse_exited.connect(_tooltip.hide_tip)
	return money


func _build_stats() -> Control:
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	stats.add_child(_stat("pollution", "Pollution", "res://assets/ui/pollution.svg", [
		"Starts at 10. Each park lowers it by 3, each trees tile by 1.",
		"0 to 5: no effect. 6 to 8: -1 happiness. 9 to 10: -2 happiness for every citizen."]))
	stats.add_child(_stat("citizens", "Happy citizens", "res://assets/ui/citizen.svg", [
		"Citizens live in apartments. A happy citizen is above 0.",
		"Hover an apartment to see what raises or lowers its mood."]))
	stats.add_child(_stat("score", "Score now", "res://assets/ui/trophy.svg", [
		"What your city would score if the game ended now:",
		"each citizen's happiness, minus 2 per loan."]))
	stats.add_child(_stat("extras", "Free roads", "res://assets/tiles/road_15.svg", [
		"You get 2 free roads for the whole game.",
		"Place them on any empty lot during your turns (R)."]))
	return stats


func _stat(key: String, caption: String, icon_path: String, help: Array) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL_HI, 12, 0, Color.TRANSPARENT, 8))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UiKit.icon(icon_path, 28))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var cap := UiKit.label(caption, 13, UiKit.MUTED)
	v.add_child(cap)
	var val := UiKit.label("", 19, UiKit.LIMESTONE, "display_bold")
	v.add_child(val)
	_stat_notes[key] = cap
	if key == "pollution":
		_gauge = Widgets.PollutionGauge.new()
		_gauge.custom_minimum_size = Vector2(70, 6)
		v.add_child(_gauge)
	h.add_child(v)
	pc.add_child(h)
	_stat_values[key] = val
	pc.mouse_entered.connect(func(): _tooltip.show_text(caption, help, pc.get_global_rect(), icon_path))
	pc.mouse_exited.connect(_tooltip.hide_tip)
	return pc
