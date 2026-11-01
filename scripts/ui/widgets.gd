extends RefCounted
## Small custom-drawn widgets and effects shared by the scenes.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")


## Player token: coloured disc with their initial.
class Avatar extends Control:
	var color := Color.WHITE:
		set(v):
			color = v
			queue_redraw()
	var letter := "?":
		set(v):
			letter = v
			queue_redraw()
	var ring := false:
		set(v):
			ring = v
			queue_redraw()

	func _init(px := 56.0) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		var c := size / 2.0
		draw_circle(c + Vector2(0, r * 0.08), r, Color(0, 0, 0, 0.3))
		draw_circle(c, r, color)
		draw_circle(c - Vector2(r * 0.2, r * 0.25), r * 0.55, Color(1, 1, 1, 0.12))
		if ring:
			draw_arc(c, r + 3, 0, TAU, 48, UiKit.LIMESTONE, 3, true)
		var f := UiKit.font("display_bold")
		var fs := int(r * 1.1)
		var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w / 2.0, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK_DEEP)


## Ten segments coloured by the doc's pollution bands.
class PollutionGauge extends Control:
	var level := 10.0:
		set(v):
			level = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(120, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := 10
		var gap := 3.0
		var w := (size.x - gap * (n - 1)) / n
		for k in n:
			var seg := k + 1
			var col: Color = UiKit.OLIVE if seg <= 5 else (UiKit.GOLD if seg <= 8 else UiKit.HEAT)
			var fill := clampf(level - k, 0.0, 1.0)
			var r := Rect2(k * (w + gap), 0, w, size.y)
			draw_rect(r, Color(col, 0.18))
			if fill > 0:
				draw_rect(Rect2(r.position, Vector2(w * fill, size.y)), col)


## Four connected round markers.
class RoundTracker extends Control:
	var current := 1:
		set(v):
			current = v
			queue_redraw()
	var total := 8

	func _init() -> void:
		custom_minimum_size = Vector2(216, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y / 2.0
		var step := (size.x - 40) / (total - 1)
		draw_line(Vector2(20, y), Vector2(size.x - 20, y), UiKit.LINE, 4, true)
		if current > 1:
			draw_line(Vector2(20, y), Vector2(20 + step * (current - 1), y), UiKit.GOLD, 4, true)
		var f := UiKit.font("display_bold")
		for k in total:
			var c := Vector2(20 + step * k, y)
			var r := 12.0 if k + 1 == current else 9.0
			var col: Color = UiKit.GOLD if k + 1 < current else (UiKit.BOUG if k + 1 == current else UiKit.PANEL_HI)
			draw_circle(c, r + 3, UiKit.INK_DEEP)
			draw_circle(c, r, col)
			var t := str(k + 1)
			var fs := 16 if k + 1 == current else 12
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, c + Vector2(-w / 2.0, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK_DEEP if k + 1 < current else UiKit.LIMESTONE)


## The plain dark background of every screen.
class Backdrop extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	## A flat dark blue with a very soft fade towards the bottom. Nothing else, so the game is what you look at.
	func _draw() -> void:
		var top := UiKit.INK
		var bottom := UiKit.INK_DEEP
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([top, top, bottom, bottom]))


## One of the two "bought this turn" slots in the action bar.
class TurnSlot extends Control:
	var tile = null:
		set(v):
			tile = v
			queue_redraw()
	var number := 1

	func _init(n: int) -> void:
		number = n
		custom_minimum_size = Vector2(54, 54)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if tile == null:
			var sb := UiKit.box(Color(UiKit.INK_DEEP, 0.6), 10, 2, UiKit.LINE)
			draw_style_box(sb, r)
			var f := UiKit.font("display_bold")
			var t := str(number)
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(f, r.get_center() + Vector2(-w / 2, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.MUTED)
		else:
			draw_texture_rect(UiKit.tex(TileDefs.art_path(tile)), r, false)
			var c := r.end - Vector2(6, 6)
			draw_circle(c, 10, UiKit.OLIVE)
			draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(5, -4)]), UiKit.INK_DEEP, 3, true)


static var _soft_dot: Texture2D


static func soft_dot() -> Texture2D:
	if _soft_dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 32
		gt.height = 32
		_soft_dot = gt
	return _soft_dot


## One-shot particle burst. kind: "dust", "leaves", "sparkle", "confetti".
static func burst(parent: Node, pos: Vector2, kind := "dust", amount := 18) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.explosiveness = 0.92
	p.lifetime = 0.7
	p.spread = 180.0
	p.direction = Vector2(0, -1)
	p.gravity = Vector2(0, 380)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	p.texture = soft_dot()
	var ramp := Gradient.new()
	match kind:
		"dust":
			p.color = Color("#E8DCC0")
			ramp.set_color(0, Color(1, 1, 1, 0.8))
			ramp.set_color(1, Color(1, 1, 1, 0))
		"leaves":
			p.color = UiKit.OLIVE
			p.gravity = Vector2(0, 160)
			p.lifetime = 1.0
			ramp.set_color(0, Color(1, 1, 1, 1))
			ramp.set_color(1, Color(1, 1, 1, 0))
		"sparkle":
			p.color = UiKit.GOLD
			p.gravity = Vector2(0, 120)
			ramp.set_color(0, Color(1, 1, 1, 1))
			ramp.set_color(1, Color(1, 1, 1, 0))
		"confetti":
			p.texture = null
			p.lifetime = 2.6
			p.gravity = Vector2(0, 260)
			p.initial_velocity_min = 260.0
			p.initial_velocity_max = 620.0
			p.spread = 70.0
			p.scale_amount_min = 6.0
			p.scale_amount_max = 11.0
			p.angular_velocity_min = -400.0
			p.angular_velocity_max = 400.0
			p.damping_min = 40.0
			p.damping_max = 90.0
			p.color_initial_ramp = _confetti_colors()
			ramp.set_color(0, Color(1, 1, 1, 1))
			ramp.add_point(0.8, Color(1, 1, 1, 1))
			ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)


static func _confetti_colors() -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray([UiKit.BOUG, UiKit.GOLD, UiKit.SKY, UiKit.OLIVE, UiKit.LIMESTONE])
	return g


## Text that rises and fades, e.g. "+3 points".
static func float_text(parent: Node, text: String, pos: Vector2, color: Color, font_size := 30) -> void:
	var l := UiKit.outline(UiKit.label(text, font_size, color, "display_bold"), 8)
	parent.add_child(l)
	l.reset_size()
	l.position = pos - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE * 0.6
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 56, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.75)
	tw.chain().tween_callback(l.queue_free)
