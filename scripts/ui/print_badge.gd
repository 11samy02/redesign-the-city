extends Control
## One round badge on a printed tile or sheet: a citizen (or a house, or a smog cloud) with the points it
## brings in a coloured pill under it. Set `item` = {"role", "value", "type"} and `d` (the icon's size).
## type: "need" (blue), "like" and "green" (green), "dislike" (red), "air" (green, pollution), "resident" (no pill).

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Roles = preload("res://scripts/core/roles.gd")

const NEED := Color("#2B62C9")
const LIKE := Color("#1E9B4E")
const DISLIKE := Color("#D0312D")
const AIR := Color("#2F8F4E")

static var _role_tex := {}
static var _cloud_tex: Texture2D = null

var item := {}
var d := 60.0


## A citizen's round icon without the dark drop shadow the game draws under it (it printed as a black blob).
static func role_texture(role: String) -> Texture2D:
	if _role_tex.has(role):
		return _role_tex[role]
	var svg := FileAccess.get_file_as_string(Roles.DEFS[role]["icon"])
	svg = svg.replace('<circle cx="32" cy="34" r="29" fill="#000" opacity="0.28"/>', "")
	var img := Image.new()
	img.load_svg_from_string(svg, 4.0)
	var t := ImageTexture.create_from_image(img)
	_role_tex[role] = t
	return t


## The smog cloud of the pollution bar.
static func cloud_texture() -> Texture2D:
	if _cloud_tex == null:
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string("res://assets/ui/pollution.svg"), 4.0)
		_cloud_tex = ImageTexture.create_from_image(img)
	return _cloud_tex


## Colour of the pill for a kind of badge.
static func pill_color(type: String) -> Color:
	match type:
		"need":
			return NEED
		"like", "green":
			return LIKE
		"dislike":
			return DISLIKE
		"air":
			return AIR
	return Color.TRANSPARENT


## "+2", "-1" with a real minus sign.
static func signed(value: int) -> String:
	return ("+%d" % value) if value > 0 else ("−%d" % absi(value))




func _draw() -> void:
	if item.get("only_pill", false):
		_draw_pill(Rect2(Vector2.ZERO, size))
		return
	var c := Vector2(d / 2.0, d / 2.0)
	var role: String = item["role"]
	match role:
		"home":
			draw_circle(c, d / 2.0, Color.WHITE)
			draw_arc(c, d / 2.0 - 1.5, 0, TAU, 40, Color("#10283A"), 3.0, true)
			_house(c, d * 0.62)
		"smog":
			draw_circle(c, d / 2.0, Color.WHITE)
			draw_arc(c, d / 2.0 - 1.5, 0, TAU, 40, Color("#10283A"), 3.0, true)
			var cloud := d * 0.74
			draw_texture_rect(cloud_texture(), Rect2(c - Vector2(cloud, cloud) / 2.0, Vector2(cloud, cloud)), false)
		_:
			draw_texture_rect(role_texture(role), Rect2(Vector2.ZERO, Vector2(d, d)), false)
	var type: String = item["type"]
	if type == "resident":
		return
	var pw := d * 0.92
	var ph := d * 0.46
	_draw_pill(Rect2(Vector2((d - pw) / 2.0, d * 0.76), Vector2(pw, ph)))


## The coloured pill with the points in it, filling `pill`.
func _draw_pill(pill: Rect2) -> void:
	var text := signed(item["value"])
	var f := UiKit.font("display_bold")
	var fs := int(d * 0.4)
	draw_style_box(UiKit.box(pill_color(item["type"]), int(pill.size.y / 2.0), maxi(2, int(d * 0.045)), Color.WHITE), pill)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(pill.position.x + (pill.size.x - tw) / 2.0, pill.position.y + pill.size.y / 2.0 + fs * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _house(c: Vector2, s: float) -> void:
	var half := s / 2.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-half, -half * 0.05), c + Vector2(0, -half), c + Vector2(half, -half * 0.05)]), Color("#C2452D"))
	draw_rect(Rect2(c + Vector2(-half * 0.72, -half * 0.05), Vector2(half * 1.44, half * 0.95)), Color("#F2D9A6"))
	draw_rect(Rect2(c + Vector2(-half * 0.18, half * 0.3), Vector2(half * 0.36, half * 0.6)), Color("#7A4A2A"))
