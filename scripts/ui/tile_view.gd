extends Control
## One tile on the shop, a player mat or a mini map. Draws the SVG art plus
## live badges (gold cost, citizen happiness, green effects) and animates hover/pop.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Roles = preload("res://scripts/core/roles.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal pressed(view)
signal right_pressed(view)
signal hovered(view, inside: bool)

## STOCK is a free tile waiting in the action bar: shop-like hover and count badge, "Free" instead of a price.
enum Mode { SHOP, MAT, MINI, STOCK }

var mode := Mode.SHOP
var index := -1
var tile = null
var road_mask := 15
## For a 2:2 street: the 1:1 roads that touch it, drawn as strips that line up with them (see MatView.big_road_links).
var road_stubs: Array = []
## How many identical tiles this shop stack still holds (shop only). More than 1 shows an "Nx" badge.
var stack_count := 0
## A shop stack with nothing left: drawn faded and not clickable.
var sold_out := false
## What the current planner pays for this shop tile (a card can change it); -1 means the normal price.
var price := -1
var affordable := true
var selected := false:
	set(v):
		if v == selected:
			return
		selected = v
		z_index = 20 if (v or _hover) else 0
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
## Off while a bot plays: no lift, no sound and no hover signal.
var hover_enabled := true
var _pulse := 0.0
var _tweens := {}

## Tiles on the mat narrower than this (the 1:1 tiles) get the short badges: just a face for a home.
const COMPACT_BELOW := 56.0

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
	if not hover_enabled:
		return
	_hover = true
	z_index = 20
	if tile != null and (mode == Mode.SHOP or mode == Mode.STOCK) and not selected:
		_tween_to("lift", 5.0, 0.15)
		_sfx("hover")
	hovered.emit(self, true)
	queue_redraw()


## Plays a sound through the Sfx autoload when there is one (tests run without autoloads).
func _sfx(sound: String) -> void:
	if is_inside_tree() and get_tree().root.has_node("Sfx"):
		get_tree().root.get_node("Sfx").play(sound)


func _on_exit() -> void:
	_hover = false
	z_index = 20 if selected else 0
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
		draw_texture_rect(UiKit.tex(texture_path()), art, false, Color(1, 1, 1, 0.3) if sold_out else Color.WHITE)
		if not road_stubs.is_empty():
			_draw_road_stubs(art)
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
			if sold_out:
				_draw_sold_out(art, radius)
			else:
				_draw_cost(art)
				_draw_stack_count(art)
				_draw_household(art, 0.19, true)
		elif mode == Mode.STOCK:
			_draw_stack_count(art)
			_draw_free_tag(art)
		elif mode == Mode.MAT:
			_draw_mat_badges(art)
			_draw_household(art, 0.2 if s.x >= COMPACT_BELOW else 0.23, false)

	if keyboard_focus:
		var a := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 160.0)
		draw_style_box(_sb("kb", Color(0, 0, 0, 0), radius + 5, 4, Color(UiKit.GOLD, a)), art.grow(7))
	draw_set_transform(Vector2.ZERO)


## The piece of a 2:2 street where a 1:1 road joins it. The small road's kerb runs up to the street's kerb, and its
## asphalt (with the centre line) cuts through that kerb into the street's asphalt, so the two roads become one surface
## with no edges laid over the street. Everything is sized from the road art (256 units a square, kerb 71-185, asphalt
## 76-180) and the street's own art (the same drawing over two squares: kerb from 142, asphalt from 152).
func _draw_road_stubs(art: Rect2) -> void:
	var cs := art.size.x / 2.0
	var u := cs / 256.0
	var kerb := Color("#B7AA90")
	var light := Color("#56606C")
	var dark := Color("#48505B")
	var line := Color("#F3E7C4")
	for st in road_stubs:
		var k: int = st["k"]
		var o: Vector2
		var inw: Vector2
		var perp: Vector2
		# asphalt colour at the small road's edge and at the street, by side (the art's gradient runs top to bottom)
		var c0 := [light, dark]
		var c1 := [light.lerp(dark, 0.304), light.lerp(dark, 0.72)]
		match st["dir"]:
			1:
				o = art.position + Vector2(k * cs, 0)
				inw = Vector2(0, 1)
				perp = Vector2(1, 0)
				c0 = [dark, dark]
				c1 = [light.lerp(dark, 0.61), light.lerp(dark, 0.61)]
			4:
				o = Vector2(art.position.x + k * cs, art.end.y)
				inw = Vector2(0, -1)
				perp = Vector2(1, 0)
				c0 = [light, light]
				c1 = [light.lerp(dark, 0.416), light.lerp(dark, 0.416)]
			8:
				o = Vector2(art.position.x, art.position.y + k * cs)
				inw = Vector2(1, 0)
				perp = Vector2(0, 1)
			_:
				o = Vector2(art.end.x, art.position.y + k * cs)
				inw = Vector2(-1, 0)
				perp = Vector2(0, 1)
		var pt := func(along: float, across: float) -> Vector2: return o + (inw * along + perp * across) * u
		# kerb: up to the street's kerb, never over it
		draw_colored_polygon(PackedVector2Array([pt.call(0.0, 71.0), pt.call(142.0, 71.0), pt.call(142.0, 185.0), pt.call(0.0, 185.0)]), kerb)
		# asphalt: through the street's kerb into its asphalt (one unit of overlap hides the join)
		draw_polygon(PackedVector2Array([pt.call(0.0, 76.0), pt.call(153.0, 76.0), pt.call(153.0, 180.0), pt.call(0.0, 180.0)]),
			PackedColorArray([c0[0], c1[0], c1[1], c0[1]]))
		# the centre line carries on from the small road's dashes
		for j in 5:
			var a := 2.0 + 28.0 * j
			var p0: Vector2 = pt.call(a, 128.0)
			var p1: Vector2 = pt.call(a + 16.0, 128.0)
			draw_line(p0, p1, line, 5.0 * u, true)
			draw_circle(p0, 2.5 * u, line)
			draw_circle(p1, 2.5 * u, line)


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
		return
	draw_texture_rect(UiKit.tex("res://assets/tiles/lot.svg"), r, false, Color(1, 1, 1, 0.92))
	if highlight.a > 0.0:
		draw_style_box(_sb("hl", Color(highlight, highlight.a * 0.35), radius, maxi(2, int(r.size.x * 0.05)), highlight), r)
	if target_glow:
		var a := 0.45 + 0.35 * sin(_pulse * 5.0)
		var line := 3 if r.size.x >= COMPACT_BELOW else 2
		draw_style_box(_sb("glow%d" % line, Color(UiKit.GOLD, 0.12), radius, line, Color(UiKit.GOLD, a)), r.grow(-1))


## "12x" sitting on the top-right corner of a shop stack that holds more than one tile, half
## outside the tile so it never covers the citizen icons.
func _draw_stack_count(art: Rect2) -> void:
	if stack_count <= 1:
		return
	var f := UiKit.font("display_bold")
	var fs := int(art.size.x * 0.18)
	var t := "%dx" % stack_count
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10
	var pill := Rect2(Vector2(art.end.x - w + 3, art.position.y - fs * 0.55), Vector2(w, fs * 1.35))
	draw_style_box(_sb("count", Color(UiKit.INK_DEEP, 0.96), int(pill.size.y / 2), 1, Color(UiKit.LINE, 0.8)), pill)
	draw_string(f, Vector2(pill.position.x + 5, pill.position.y + pill.size.y / 2 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.LIMESTONE)


## Gold "Free" pill along the bottom edge, where a shop tile shows its price.
func _draw_free_tag(art: Rect2) -> void:
	var f := UiKit.font("display_bold")
	var fs := int(art.size.x * 0.21)
	var t := "Free"
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14
	var pill := Rect2(Vector2(art.get_center().x - w / 2.0, art.end.y - fs * 1.4 - 3), Vector2(w, fs * 1.4))
	draw_style_box(_sb("free", UiKit.GOLD, int(pill.size.y / 2)), pill)
	draw_string(f, Vector2(pill.position.x + 7, pill.position.y + pill.size.y / 2 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK)


func _draw_sold_out(art: Rect2, radius: int) -> void:
	draw_style_box(_sb("soldout", Color(UiKit.INK_DEEP, 0.55), radius), art)
	var f := UiKit.font("display_bold")
	var fs := int(art.size.x * 0.17)
	var t := "Sold out"
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(art.get_center().x - w / 2.0, art.get_center().y + fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiKit.LIMESTONE, 0.85))


## Who lives here: one small round role icon per citizen. In the shop they sit in the top-left
## corner (the price takes the bottom and the stack count the top-right); on the mat, bottom-left.
func _draw_household(art: Rect2, size_factor: float, top: bool) -> void:
	if tile == null or not TileDefs.is_home(tile["kind"]):
		return
	var members := TileDefs.members(tile)
	var d := art.size.x * size_factor
	var step := d * (0.62 if top else 0.72)
	var w := d + step * (members.size() - 1) + 6
	var y := art.position.y + 3 if top else art.end.y - d - 7
	var pill := Rect2(Vector2(art.position.x + 3, y), Vector2(w, d + 4))
	draw_style_box(_sb("house", Color(UiKit.INK_DEEP, 0.9), int(pill.size.y / 2)), pill)
	for k in members.size():
		draw_texture_rect(UiKit.tex(Roles.DEFS[members[k]]["icon"]), Rect2(pill.position + Vector2(3 + k * step, 2), Vector2(d, d)), false)


func _draw_cost(art: Rect2) -> void:
	var normal := TileDefs.tile_cost(tile)
	var cost := normal if price < 0 else price
	var f := UiKit.font("display_bold")
	var fs := int(art.size.x * 0.24)
	var coin := art.size.x * 0.3
	var pill := Rect2(art.end - Vector2(coin + fs * 0.85 + 10, coin + 4), Vector2(coin + fs * 0.85 + 6, coin))
	draw_style_box(_sb("pill", Color(UiKit.INK_DEEP, 0.88), int(coin / 2)), pill)
	draw_texture_rect(UiKit.tex("res://assets/ui/coin.svg"), Rect2(pill.position, Vector2(coin, coin)), false)
	var col := UiKit.GOLD if affordable else UiKit.HEAT
	if cost < normal:
		col = UiKit.OLIVE
	elif cost > normal:
		col = UiKit.HEAT
	var pos := Vector2(pill.position.x + coin + 1, pill.position.y + coin * 0.5 + fs * 0.36)
	draw_string(f, pos, str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## The live badges on a mat tile, the same as ever, scaled to the tile: a home shows a face for every citizen and the
## points they bring; a service how many citizens it serves; green tiles their pollution; a shaded road its leaf. A 1:1
## tile is about 46 px, so its badges are small and use a little icon instead of words.
func _draw_mat_badges(art: Rect2) -> void:
	var small := art.size.x < COMPACT_BELOW
	var f := UiKit.font("display_bold")
	var fs := int(maxf(art.size.x * 0.15, 11.0))
	var m := 3.0 if small else 6.0
	if apartment_info != null:
		var members: Array = apartment_info["members"]
		var n := members.size()
		var fr := maxf(art.size.x * 0.075, 4.4)
		var step := fr * (2.2 if small else 2.3)
		var sp: int = apartment_info["sp"]
		var txt := ("+%d" % sp) if sp > 0 else str(sp)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w := n * step + tw + (7.0 if small else 12.0)
		var pill := Rect2(art.position + Vector2(m, m), Vector2(w, fr * 2 + (6.0 if small else 8.0)))
		draw_style_box(_sb("face", Color(UiKit.INK_DEEP, 0.88), int(pill.size.y / 2)), pill)
		for k in n:
			draw_face(self, pill.position + Vector2(3 + fr + k * step, pill.size.y / 2), fr, members[k]["happiness"])
		draw_string(f, Vector2(pill.position.x + 4 + n * step, pill.position.y + pill.size.y / 2 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, face_color(signi(sp)))
	elif badge_text != "":
		var icon := ""
		var shown := badge_text
		if small:
			if badge_text.begins_with("Serves "):
				icon = "res://assets/ui/citizen.svg"
				shown = badge_text.substr(7)
			elif badge_text.begins_with("Air "):
				icon = "res://assets/ui/pollution.svg"
				shown = badge_text.substr(4)
		var tw := f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ic := fs * 1.0 if icon != "" else 0.0
		var w := tw + ic + (8.0 if small else 16.0)
		var pill := Rect2(art.position + Vector2(m, m), Vector2(w, fs * 1.45))
		draw_style_box(_sb("badge", Color(UiKit.INK_DEEP, 0.85), int(pill.size.y / 2)), pill)
		var x := pill.position.x + (4.0 if small else 8.0)
		if icon != "":
			draw_texture_rect(UiKit.tex(icon), Rect2(Vector2(x, pill.position.y + (pill.size.y - ic) / 2), Vector2(ic, ic)), false)
			x += ic + 1.0
		draw_string(f, Vector2(x, pill.position.y + pill.size.y / 2 + fs * 0.36), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.LIMESTONE)
	elif shade_dirs != 0 and tile["kind"] == TileDefs.Kind.ROAD:
		# leaf (+ "Shade") so the canopy shadow is never mistaken for smog
		var t := "" if small else "Shade"
		var leaf := fs * 1.05
		var w := (f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0 if t != "" else 0.0) + leaf + 8.0
		var pill := Rect2(Vector2(art.position.x + m, art.end.y - fs * 1.45 - m), Vector2(w, fs * 1.45))
		draw_style_box(_sb("shade", Color("#1E5B3A"), int(pill.size.y / 2)), pill)
		draw_texture_rect(UiKit.tex("res://assets/ui/leaf.svg"), Rect2(pill.position + Vector2(4, (pill.size.y - leaf) / 2), Vector2(leaf, leaf)), false)
		if t != "":
			draw_string(f, Vector2(pill.position.x + leaf + 10, pill.position.y + pill.size.y / 2 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#D8F0B8"))
	if tile.get("free", false):
		if small:
			var c := Vector2(art.end.x - 6, art.position.y + 6)
			draw_circle(c, 4.5, Color(UiKit.INK_DEEP, 0.9))
			draw_circle(c, 3.0, UiKit.GOLD)
		else:
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
