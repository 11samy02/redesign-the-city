extends RefCounted
## Visual effects for buying and placing: the flying tile, coin streams and the landing burst.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Describe = preload("res://scripts/ui/describe.gd")


## Arcs a tile picture from `from` to `to` (global rects). Finishes when it lands.
static func fly_tile(fx: Control, tex_path: String, from: Rect2, to: Rect2) -> void:
	var tr := TextureRect.new()
	tr.texture = UiKit.tex(tex_path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = from.size
	tr.position = from.position
	tr.pivot_offset = from.size / 2
	fx.add_child(tr)
	var a := from.get_center()
	var b := to.get_center()
	var ctrl := (a + b) / 2.0 - Vector2(0, 140)
	var tw := fx.create_tween()
	tw.tween_method(func(t: float):
		var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
		var s := from.size.lerp(to.size, t) * (1.0 + 0.25 * sin(t * PI))
		tr.size = s
		tr.pivot_offset = s / 2
		tr.position = p - s / 2
		tr.rotation = sin(t * PI * 2.0) * 0.08,
		0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	tr.queue_free()


## A stream of up to ten coins from `from` to `to` (global points).
static func fly_coins(fx: Control, from: Vector2, to: Vector2, count: int) -> void:
	for k in mini(count, 10):
		var c := UiKit.icon("res://assets/ui/coin.svg", 30)
		c.size = Vector2(30, 30)
		c.position = from - Vector2(15, 15)
		c.modulate.a = 0.0
		fx.add_child(c)
		var ctrl := (from + to) / 2.0 + Vector2(randf_range(-60, 60), -110)
		var tw := fx.create_tween()
		tw.tween_interval(k * 0.06)
		tw.tween_property(c, "modulate:a", 1.0, 0.05)
		tw.tween_method(func(t: float):
			c.position = from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t) - Vector2(15, 15),
			0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): Sfx.play("coin", 1.0 + k * 0.05))
		tw.tween_property(c, "modulate:a", 0.0, 0.08)
		tw.tween_callback(c.queue_free)


## Dust, leaves or sparkles where a tile landed, plus floating point and pollution changes.
static func landed(fx: Control, tile: Dictionary, to_rect: Rect2, points_delta: int, pollution_delta: int, gauge_at: Vector2) -> void:
	var center := to_rect.get_center()
	var kind: int = tile["kind"]
	var kind_fx := "dust"
	if kind == TileDefs.Kind.PARK or kind == TileDefs.Kind.TREES:
		kind_fx = "leaves"
	elif kind == TileDefs.Kind.AMENITY:
		kind_fx = "sparkle"
	Widgets.burst(fx, center + Vector2(0, to_rect.size.y * 0.3), "dust", 14)
	if kind_fx != "dust":
		Widgets.burst(fx, center, kind_fx, 16)
	if points_delta != 0:
		Widgets.float_text(fx, Describe.points(points_delta), center - Vector2(0, to_rect.size.y * 0.25), UiKit.OLIVE if points_delta > 0 else UiKit.HEAT)
	if pollution_delta != 0:
		Widgets.float_text(fx, "Pollution %d" % pollution_delta, gauge_at - Vector2(0, 10), UiKit.OLIVE, 22)
	if points_delta > 0:
		Sfx.play("coin", 1.2)
