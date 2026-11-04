extends RefCounted
## Small helpers for laying out the printed helper sheets (planner guide, pollution bars) out of plain
## controls. Everything is placed by pixel position: the sheets are rendered at 300 dpi, so 1 px is 0.085 mm.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const PrintBadge = preload("res://scripts/ui/print_badge.gd")

const PAPER := Color("#FFFDF6")
const INK := Color("#10283A")
const MUTED := Color("#55656F")
const LINE := Color("#D9D0BC")


## A rounded rectangle (fill, optional border).
static func box(parent: Control, rect: Rect2, fill: Color, radius := 0, border := 0, border_color := Color.TRANSPARENT) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", UiKit.box(fill, radius, border, border_color))
	parent.add_child(p)
	return p


## Text. `width` > 0 wraps it inside that width; align is a HorizontalAlignment.
static func text(parent: Control, s: String, pos: Vector2, size_px: int, color := INK, kind := "display_bold", width := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT, height := 0.0) -> Label:
	if width > 0.0:
		s = wrap_text(s, UiKit.font(kind), size_px, width)
	var l := UiKit.label(s, size_px, color, kind)
	l.position = pos
	l.horizontal_alignment = align
	if width > 0.0:
		l.size = Vector2(width, height if height > 0.0 else l.get_minimum_size().y)
	if height > 0.0:
		l.size = Vector2(width if width > 0.0 else l.get_minimum_size().x, height)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


## `s` with line breaks put in so no line is wider than `width` (a word wider than that stays on its own line).
static func wrap_text(s: String, font: Font, size_px: int, width: float) -> String:
	var lines: Array[String] = []
	for paragraph in s.split("\n"):
		var line := ""
		for word in paragraph.split(" "):
			var trial := word if line == "" else line + " " + word
			if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width:
				lines.append(line)
				line = word
			else:
				line = trial
		lines.append(line)
	return "\n".join(lines)


## A picture (a path or a texture) stretched into `rect`.
static func picture(parent: Control, source, rect: Rect2, modulate := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiKit.tex(source) if source is String else source
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = rect.position
	t.size = rect.size
	t.modulate = modulate
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


## A round badge (see PrintBadge) of `d` pixels with its top-left corner at `pos`.
static func badge(parent: Control, item: Dictionary, pos: Vector2, d: float) -> Control:
	var b := PrintBadge.new()
	b.item = item
	b.d = d
	b.position = pos
	b.size = Vector2(d, d * 1.3)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b


## A coloured pill with text in it (white text), centred on `centre_x`, top at `y`.
static func pill(parent: Control, s: String, color: Color, centre_x: float, y: float, w: float, h: float, border := 3) -> void:
	box(parent, Rect2(centre_x - w / 2.0, y, w, h), color, int(h / 2.0), border, Color.WHITE)
	text(parent, s, Vector2(centre_x - w / 2.0, y), int(h * 0.62), Color.WHITE, "display_bold", w, HORIZONTAL_ALIGNMENT_CENTER, h)


## The picture of a tile (a thumbnail), with an optional points pill hanging off the bottom and a caption.
static func thumb(parent: Control, tile: Dictionary, pos: Vector2, d: float, value := 0, type := "", caption := "", road_mask := 10) -> void:
	picture(parent, TileDefs.art_path(tile, road_mask), Rect2(pos, Vector2(d, d)))
	if type != "":
		pill(parent, PrintBadge.signed(value), PrintBadge.pill_color(type), pos.x + d / 2.0, pos.y + d - d * 0.2, d * 0.78, d * 0.4, maxi(2, int(d * 0.03)))
	if caption != "":
		text(parent, caption, Vector2(pos.x - 22, pos.y + d + d * 0.24), int(maxf(22.0, d * 0.22)), MUTED, "body_bold", d + 44, HORIZONTAL_ALIGNMENT_CENTER)
