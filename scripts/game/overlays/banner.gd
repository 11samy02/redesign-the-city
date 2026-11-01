extends RefCounted
## Full-width ribbon announcements: a new round, or the end of the game.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")


## "Round N" ribbon with the new turn order as a row of planner chips.
static func round_start(overlays: Control, gs) -> void:
	var order: Array[int] = gs.turn_order()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for pos in order.size():
		row.add_child(_planner_chip(gs.players[order[pos]], pos))
	var first: String = gs.players[order[0]].name
	var last: String = gs.players[order[order.size() - 1]].name
	await play(overlays, "Round %d" % gs.round_number, "Fewest points picks first: %s picks first, %s picks last" % [first, last], row)


## Slides a ribbon with `big` and `small` text across `overlays`, optionally with an extra row.
static func play(overlays: Control, big: String, small: String, extra: Control = null) -> void:
	var ov := Control.new()
	overlays.add_child(ov)
	var dim := OverlayKit.fill_dimmed(ov, 0.55)
	var vp := overlays.get_viewport_rect().size
	var ribbon_h := 190.0 if extra == null else 270.0
	var ribbon := ColorRect.new()
	ribbon.color = UiKit.BOUG
	ribbon.size = Vector2(vp.x, ribbon_h)
	ribbon.position = Vector2(0, vp.y / 2 - ribbon_h / 2)
	ribbon.pivot_offset = Vector2(vp.x / 2, ribbon_h / 2)
	ribbon.scale = Vector2(0, 1)
	ov.add_child(ribbon)
	var v := _ribbon_text(big, small, extra, Vector2(vp.x, ribbon_h), ribbon.position)
	ov.add_child(v)
	Sfx.play("fanfare" if big.begins_with("City") else "round")
	var tw := overlays.create_tween()
	tw.tween_property(ribbon, "scale:x", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(v, "modulate:a", 1.0, 0.3).set_delay(0.15)
	tw.parallel().tween_property(v, "position:x", 0.0, 0.5).from(-80.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3 if extra == null else 2.6)
	tw.tween_property(v, "position:x", 80.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(v, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(ribbon, "scale:y", 0.0, 0.3).set_delay(0.05)
	tw.parallel().tween_property(dim, "modulate:a", 0.0, 0.3)
	await tw.finished
	ov.queue_free()


static func _ribbon_text(big: String, small: String, extra: Control, ribbon_size: Vector2, at: Vector2) -> Control:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size = ribbon_size
	v.position = at
	v.add_theme_constant_override("separation", -6)
	var bl := UiKit.outline(UiKit.label(big, 84, Color.WHITE, "display_bold"), 10, Color("#8E1E4F"))
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sl := UiKit.label(small, 24, Color("#FFE3EF"), "display")
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(bl)
	v.add_child(sl)
	if extra != null:
		var gap := Control.new()
		gap.custom_minimum_size.y = 16
		v.add_child(gap)
		v.add_child(extra)
	v.modulate.a = 0.0
	return v


## Pill with the planner's place, avatar and name.
static func _planner_chip(p, pos: int) -> Control:
	var chip := PanelContainer.new()
	var csb := UiKit.box(Color(UiKit.INK_DEEP, 0.55), 99, 0, Color.TRANSPARENT, 6)
	csb.content_margin_right = 16
	chip.add_theme_stylebox_override("panel", csb)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	ch.add_child(UiKit.label(str(pos + 1), 24, UiKit.GOLD, "display_bold"))
	var av := Widgets.Avatar.new(34)
	av.color = UiKit.player_color(p.color_index)
	av.letter = p.name.substr(0, 1).to_upper()
	ch.add_child(av)
	ch.add_child(UiKit.label(p.name, 19, Color.WHITE, "display_bold"))
	chip.add_child(ch)
	return chip
