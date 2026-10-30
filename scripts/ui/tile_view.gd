extends Control
## One tile on the shop, a player mat or a mini map. Draws the SVG art plus
## live badges (gold cost, citizen happiness, green effects) and animates hover/pop.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal pressed(view)
signal right_pressed(view)
signal hovered(view, inside: bool)

enum Mode { SHOP, MAT, MINI }

var mode := Mode.SHOP
var index := -1
var tile = null
var road_mask := 15
var removed := false
var affordable := true
var selected := false:
	set(v):
		if v == selected:
			return
		selected = v
		_tween_to("lift", 10.0 if v else (5.0 if _hover else 0.0), 0.18)
		queue_redraw()
var keyboard_focus := false:
	set(v):
		keyboard_focus = v
		queue_redraw()
## Sides (N=1, E=2, S=4, W=8) where trees or a park shade this road.
var shade_dirs := 0
## Scoring entry for an apartment (see Scoring.evaluate) or null.
var apartment_info = null
## Citizens served (amenity) / homes boosted (green) shown as a badge.
var badge_text := ""
var highlight := Color(0, 0, 0, 0)
var target_glow := false:
	set(v):
		target_glow = v
		set_process(v)
		queue_redraw()
var ghost_tile = null
var ghost_mask := 15
var interactive := true:
	set(v):
		interactive = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if v else Control.CURSOR_ARROW
var anim_scale := 1.0:
	set(v):
		anim_scale = v
		queue_redraw()
var lift := 0.0:
	set(v):
		lift = v
		queue_redraw()
var dim := 0.0:
	set(v):
		dim = v
		queue_redraw()

var _hover := false
var _pulse := 0.0
var _tweens := {}

static var _sb_cache := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process(false)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(self)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_pressed.emit(self)
			accept_event()


func _on_enter() -> void:
	_hover = true
	if tile != null and mode == Mode.SHOP and not selected:
		_tween_to("lift", 5.0, 0.15)
		Sfx.play("hover")
	hovered.emit(self, true)
	queue_redraw()


func _on_exit() -> void:
	_hover = false
	if not selected:
		_tween_to("lift", 0.0, 0.15)
	hovered.emit(self, false)
	queue_redraw()


func _tween_to(prop: String, value: float, time: float) -> void:
	if _tweens.has(prop) and _tweens[prop].is_valid():
		_tweens[prop].kill()
	var tw := create_tween()
	tw.tween_property(self, prop, value, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens[prop] = tw


## Squash-and-settle used when a tile lands or scores.
func pop(strength := 0.14) -> void:
	if _tweens.has("anim_scale") and _tweens["anim_scale"].is_valid():
		_tweens["anim_scale"].kill()
	var tw := create_tween()
	tw.tween_property(self, "anim_scale", 1.0 + strength, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "anim_scale", 1.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tweens["anim_scale"] = tw


func shake() -> void:
	var tw := create_tween()
	var base := position.x
	for i in 4:
		tw.tween_property(self, "position:x", base + (6.0 if i % 2 == 0 else -6.0), 0.04)
	tw.tween_property(self, "position:x", base, 0.04)


func texture_path() -> String:
	if tile == null:
		return ""
	return TileDefs.art_path(tile, road_mask)


static func _sb(key: String, bg: Color, radius: int, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var k := "%s|%s|%d|%d|%s" % [key, bg.to_html(), radius, border, border_color.to_html()]
	if not _sb_cache.has(k):
		var sb := UiKit.box(bg, radius, border, border_color)
		sb.draw_center = bg.a > 0.0
		_sb_cache[k] = sb
	return _sb_cache[k]


func _draw() -> void:
	var s := size
	var radius := int(s.x * 0.11)
	draw_set_transform(s / 2.0, 0.0, Vector2.ONE * anim_scale)
	var r := Rect2(-s / 2.0, s)
	var art := Rect2(r.position - Vector2(0, lift), r.size)

	if tile == null:
		_draw_empty(r, radius)
	else:
		# drop shadow grows as the tile lifts
		var sh := Rect2(r.position + Vector2(0, 3 + lift * 0.5), r.size).grow(-1 + lift * 0.2)
		draw_style_box(_sb("shadow", Color(0, 0, 0, 0.34), radius), sh)
		draw_texture_rect(UiKit.tex(texture_path()), art, false)
		if shade_dirs != 0 and tile["kind"] == TileDefs.Kind.ROAD:
			_draw_shade(s, radius)
		if highlight.a > 0.0:
			draw_style_box(_sb("hl", Color(highlight, highlight.a * 0.35), radius, maxi(3, int(s.x * 0.035)), highlight), art)
		if mode == Mode.SHOP and not affordable:
			draw_style_box(_sb("dim", Color(UiKit.INK_DEEP, 0.55), radius), art)
		if dim > 0.0:
			draw_style_box(_sb("dimv", Color(UiKit.INK_DEEP, 0.6 * dim), radius), art)
		if selected:
			draw_style_box(_sb("sel", Color(0, 0, 0, 0), radius + 3, 4, UiKit.BOUG), art.grow(4))
		if mode == Mode.SHOP:
			_draw_cost(art)
		elif mode == Mode.MAT:
			_draw_mat_badges(art)

	if keyboard_focus:
		var a := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 160.0)
		draw_style_box(_sb("kb", Color(0, 0, 0, 0), radius + 5, 4, Color(UiKit.GOLD, a)), art.grow(7))
	draw_set_transform(Vector2.ZERO)


## Leafy canopy shadow rotated towards each shading neighbour.
func _draw_shade(s: Vector2, radius: int) -> void:
	var shade := UiKit.tex("res://assets/tiles/shade_edge.svg")
	var center := s / 2.0 - Vector2(0, lift * anim_scale)
	for d in [[1, 0.0], [2, PI / 2], [4, PI], [8, -PI / 2]]:
		if shade_dirs & d[0]:
			draw_set_transform(center, d[1], Vector2.ONE * anim_scale)
			draw_texture_rect(shade, Rect2(-s / 2.0, s), false)
	draw_set_transform(s / 2.0, 0.0, Vector2.ONE * anim_scale)


func _draw_empty(r: Rect2, radius: int) -> void:
	if mode == Mode.SHOP:
		draw_style_box(_sb("socket", Color(UiKit.INK_DEEP, 0.7), radius, 2, Color(UiKit.LINE, 0.6)), r)
		if removed:
			# hatched "closed lot" for the fewer-players rule
			var step := r.size.x / 6.0
			for i in range(1, 6):
				var o := step * i
				draw_line(r.position + Vector2(o, 4), r.position + Vector2(4, o), Color(UiKit.LINE, 0.55), 2.0, true)
				draw_line(r.end - Vector2(o, 4), r.end - Vector2(4, o), Color(UiKit.LINE, 0.55), 2.0, true)
		return
	draw_texture_rect(UiKit.tex("res://assets/tiles/lot.svg"), r, false, Color(1, 1, 1, 0.92))
	if highlight.a > 0.0:
		draw_style_box(_sb("hl", Color(highlight, highlight.a * 0.35), radius, maxi(3, int(r.size.x * 0.035)), highlight), r)
	if target_glow:
		var a := 0.45 + 0.35 * sin(_pulse * 5.0)
		draw_style_box(_sb("glow", Color(UiKit.GOLD, 0.12), radius, 3, Color(UiKit.GOLD, a)), r.grow(-2))
	if ghost_tile != null:
		var gr := r.grow(-r.size.x * 0.04)
		gr.position.y -= 4.0 + 2.0 * sin(_pulse * 4.0)
		draw_texture_rect(UiKit.tex(TileDefs.art_path(ghost_tile, ghost_mask)), gr, false, Color(1, 1, 1, 0.78))


func _draw_cost(art: Rect2) -> void:
	var cost := TileDefs.cost(tile["kind"])
	var f := UiKit.font("display_bold")
	var fs := int(art.size.x * 0.24)
	var coin := art.size.x * 0.3
	var pill := Rect2(art.end - Vector2(coin + fs * 0.85 + 10, coin + 4), Vector2(coin + fs * 0.85 + 6, coin))
	draw_style_box(_sb("pill", Color(UiKit.INK_DEEP, 0.88), int(coin / 2)), pill)
	draw_texture_rect(UiKit.tex("res://assets/ui/coin.svg"), Rect2(pill.position, Vector2(coin, coin)), false)
	var col := UiKit.GOLD if affordable else UiKit.HEAT
	var pos := Vector2(pill.position.x + coin + 1, pill.position.y + coin * 0.5 + fs * 0.36)
	draw_string(f, pos, str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_mat_badges(art: Rect2) -> void:
	var f := UiKit.font("display_bold")
	var fs := int(art.size.x * 0.15)
	if apartment_info != null:
		var h: int = apartment_info["happiness"]
		var n: int = apartment_info["citizens"]
		var fr := art.size.x * 0.075
		var w := n * fr * 2.3 + fs * 1.4 + 12
		var pill := Rect2(art.position + Vector2(6, 6), Vector2(w, fr * 2 + 8))
		draw_style_box(_sb("face", Color(UiKit.INK_DEEP, 0.88), int(pill.size.y / 2)), pill)
		for k in n:
			draw_face(self, pill.position + Vector2(6 + fr + k * fr * 2.3, pill.size.y / 2), fr, h)
		var txt := ("+%d" % h) if h > 0 else str(h)
		var col := face_color(h)
		draw_string(f, Vector2(pill.position.x + 8 + n * fr * 2.3, pill.position.y + pill.size.y / 2 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	elif badge_text != "":
		var w := f.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16
		var pill := Rect2(art.position + Vector2(6, 6), Vector2(w, fs * 1.45))
		draw_style_box(_sb("badge", Color(UiKit.INK_DEEP, 0.85), int(pill.size.y / 2)), pill)
		draw_string(f, Vector2(pill.position.x + 8, pill.position.y + pill.size.y / 2 + fs * 0.36), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.LIMESTONE)
	elif shade_dirs != 0 and tile["kind"] == TileDefs.Kind.ROAD:
		# leaf + "Shade" so the canopy shadow is never mistaken for smog
		var t := "Shade"
		var leaf := fs * 1.05
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + leaf + 18
		var pill := Rect2(Vector2(art.position.x + 6, art.end.y - fs * 1.45 - 6), Vector2(w, fs * 1.45))
		draw_style_box(_sb("shade", Color("#1E5B3A"), int(pill.size.y / 2)), pill)
		draw_texture_rect(UiKit.tex("res://assets/ui/leaf.svg"), Rect2(pill.position + Vector2(6, (pill.size.y - leaf) / 2), Vector2(leaf, leaf)), false)
		draw_string(f, Vector2(pill.position.x + leaf + 10, pill.position.y + pill.size.y / 2 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#D8F0B8"))
	if tile.get("free", false):
		var t := "Free"
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14
		var pill := Rect2(Vector2(art.end.x - w - 6, art.position.y + 6), Vector2(w, fs * 1.4))
		draw_style_box(_sb("free", UiKit.GOLD, int(pill.size.y / 2)), pill)
		draw_string(f, Vector2(pill.position.x + 7, pill.position.y + pill.size.y / 2 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK)


static func face_color(h: int) -> Color:
	if h > 0:
		return UiKit.OLIVE
	if h < 0:
		return UiKit.HEAT
	return UiKit.GOLD


## A citizen's face: smile, flat or frown by happiness.
static func draw_face(ci: CanvasItem, c: Vector2, r: float, h: int) -> void:
	ci.draw_circle(c, r, face_color(h))
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.2), r * 0.13, UiKit.INK_DEEP)
	ci.draw_circle(c + Vector2(r * 0.35, -r * 0.2), r * 0.13, UiKit.INK_DEEP)
	var w := maxf(1.5, r * 0.16)
	if h > 0:
		ci.draw_arc(c + Vector2(0, r * 0.05), r * 0.5, 0.35, PI - 0.35, 12, UiKit.INK_DEEP, w, true)
	elif h < 0:
		ci.draw_arc(c + Vector2(0, r * 0.75), r * 0.5, PI + 0.5, TAU - 0.5, 12, UiKit.INK_DEEP, w, true)
	else:
		ci.draw_line(c + Vector2(-r * 0.35, r * 0.35), c + Vector2(r * 0.35, r * 0.35), UiKit.INK_DEEP, w, true)
