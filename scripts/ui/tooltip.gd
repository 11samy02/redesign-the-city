extends PanelContainer
## Floating tile card shown on hover or keyboard focus.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Describe = preload("res://scripts/ui/describe.gd")

const WIDTH := 330.0

var _box: VBoxContainer
var _tw: Tween
var _request := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var sb := UiKit.box(Color(UiKit.INK_DEEP, 0.97), 16, 2, UiKit.LINE, 16)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	add_theme_stylebox_override("panel", sb)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func show_tile(tile: Dictionary, anchor: Rect2, lines: Array, show_cost: bool, road_mask := 15) -> void:
	_clear()
	var info := TileDefs.info(tile["kind"])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UiKit.icon(TileDefs.art_path(tile, road_mask), 64))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 4)
	names.add_child(UiKit.label(TileDefs.display_name(tile), 24, UiKit.LIMESTONE, "display_bold"))
	var cat: String = info["category"]
	var chip_row := HBoxContainer.new()
	chip_row.add_child(UiKit.chip(cat if tile["kind"] != TileDefs.Kind.AMENITY else "Amenity", UiKit.CATEGORY_COLORS[cat]))
	names.add_child(chip_row)
	head.add_child(names)
	_box.add_child(head)

	if show_cost:
		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", -6)
		for k in info["cost"]:
			cost_row.add_child(UiKit.icon("res://assets/ui/coin.svg", 26))
		var spacer := Control.new()
		spacer.custom_minimum_size.x = 16
		cost_row.add_child(spacer)
		cost_row.add_child(UiKit.label("%d gold" % info["cost"], 20, UiKit.GOLD, "display_bold"))
		_box.add_child(cost_row)

	var eff := UiKit.label(Describe.effect_text(tile), 16)
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.custom_minimum_size.x = WIDTH
	_box.add_child(eff)

	if not lines.is_empty():
		_add_rule()
		_add_rich(lines)

	var obj := HBoxContainer.new()
	obj.add_theme_constant_override("separation", 6)
	for o in info["objectives"]:
		obj.add_child(UiKit.chip("%s %s" % [o, UiKit.OBJECTIVE_SHORT[o]], UiKit.PANEL_HI, UiKit.MUTED, 13))
	_box.add_child(obj)
	_present(anchor)


func show_text(title: String, lines: Array, anchor: Rect2, icon_path := "") -> void:
	_clear()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	if icon_path != "":
		head.add_child(UiKit.icon(icon_path, 36))
	head.add_child(UiKit.label(title, 22, UiKit.LIMESTONE, "display_bold"))
	_box.add_child(head)
	_add_rich(lines)
	_present(anchor)


func _add_rule() -> void:
	var rule := ColorRect.new()
	rule.color = UiKit.LINE
	rule.custom_minimum_size = Vector2(WIDTH, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(rule)


func _add_rich(lines: Array) -> void:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.custom_minimum_size.x = WIDTH
	rt.add_theme_font_override("normal_font", UiKit.font("body"))
	rt.add_theme_font_override("bold_font", UiKit.font("body_bold"))
	rt.add_theme_font_size_override("normal_font_size", 16)
	rt.add_theme_font_size_override("bold_font_size", 16)
	rt.add_theme_color_override("default_color", UiKit.LIMESTONE)
	rt.add_theme_constant_override("line_separation", 4)
	rt.text = "\n".join(PackedStringArray(lines))
	_box.add_child(rt)


func _present(anchor: Rect2) -> void:
	_request += 1
	var req := _request
	visible = true
	modulate.a = 0.0
	await get_tree().process_frame
	if req != _request:
		return
	reset_size()
	size = get_combined_minimum_size()
	var vp := get_viewport_rect().size
	var x := anchor.end.x + 14
	if x + size.x > vp.x - 8:
		x = anchor.position.x - size.x - 14
	var y := clampf(anchor.position.y - 6, 8, vp.y - size.y - 8)
	position = Vector2(maxf(8, x), y + 8)
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel()
	_tw.tween_property(self, "modulate:a", 1.0, 0.14)
	_tw.tween_property(self, "position:y", y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func hide_tip() -> void:
	_request += 1
	if not visible:
		return
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 0.0, 0.08)
	_tw.tween_callback(func(): visible = false)
