extends RefCounted
## Shared palette, fonts, theme and small widget factories.

const INK := Color("#0F2A3D")
const INK_DEEP := Color("#0A1F2E")
const PANEL := Color("#173A52")
const PANEL_HI := Color("#1F4A66")
const LINE := Color("#2C5A78")
const LIMESTONE := Color("#EFE6D2")
const MUTED := Color("#9FB3C2")
const GOLD := Color("#F2B630")
const GOLD_DEEP := Color("#B9810F")
const BOUG := Color("#D6337A")
const BOUG_HI := Color("#E8508F")
const OLIVE := Color("#8DBB3C")
const HEAT := Color("#E0533A")
const SKY := Color("#3A8DDE")

const PLAYER_COLORS := [
	Color("#E0603F"), Color("#3A8DDE"), Color("#8DBB3C"),
	Color("#F2B632"), Color("#A15CC9"), Color("#2DB7A3"),
]
const PLAYER_COLOR_NAMES := ["Clay", "Aegean", "Olive", "Saffron", "Plum", "Teal"]

## Tile rim colours from tools/gen_art.py, keyed by TileDefs category.
const CATEGORY_COLORS := {
	"Building": Color("#C7754C"), "Amenity": Color("#3C82C0"),
	"Green space": Color("#5E9B3A"), "Road": Color("#7A8494"),
}

const OBJECTIVES := {
	"O1": "Understand how spaces affect circulation and everyday life.",
	"O2": "Identify how these spaces could be improved.",
	"O3": "Identify where greenery could improve pedestrian routes.",
	"O4": "Reveal how movement, vegetation, accessibility and spaces shape everyday life in Egkomi.",
}
const OBJECTIVE_SHORT := {"O1": "Circulation", "O2": "Improvement", "O3": "Green routes", "O4": "Connected city"}

static var _fonts := {}
static var _textures := {}


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var weights := {"display": 500, "display_bold": 600, "body": 500, "body_bold": 800}
	var base: FontFile = load("res://assets/fonts/Fredoka.ttf" if kind.begins_with("display") else "res://assets/fonts/Nunito.ttf")
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weights[kind]}
	_fonts[kind] = fv
	return fv


static func tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


static func player_color(index: int) -> Color:
	return PLAYER_COLORS[index % PLAYER_COLORS.size()]


static func box(bg: Color, radius := 14, border := 0, border_color := Color.TRANSPARENT, margin := -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.anti_aliasing = true
	if margin >= 0:
		sb.set_content_margin_all(margin)
	return sb


static func label(text: String, size := 18, color := LIMESTONE, kind := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func outline(l: Label, size := 6, color := INK_DEEP) -> Label:
	l.add_theme_constant_override("outline_size", size)
	l.add_theme_color_override("font_outline_color", color)
	return l


static func icon(path: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Empty control that pushes its siblings apart inside a box container.
static func spacer(vertical := false) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## kind: "primary" (bougainvillea), "secondary", "gold" or "ghost".
## Plays a sound through the Sfx autoload when there is one (the headless tests run without it).
static func play_sfx(sound: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("Sfx"):
		tree.root.get_node("Sfx").play(sound)


static func button(text: String, kind := "secondary", font_size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", font("display_bold" if kind == "primary" else "display"))
	b.add_theme_font_size_override("font_size", font_size)
	style_button(b, kind)
	b.resized.connect(func(): b.pivot_offset = b.size / 2)
	b.mouse_entered.connect(func():
		if b.disabled:
			return
		play_sfx("hover")
		b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.04, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	b.pressed.connect(func(): play_sfx("click"))
	return b


static func style_button(b: Button, kind: String) -> void:
	var c: Array = {
		"primary": [BOUG, BOUG_HI, Color("#B42A66"), Color.WHITE, Color.TRANSPARENT],
		"secondary": [PANEL_HI, Color("#285C7E"), PANEL, LIMESTONE, LINE],
		"gold": [GOLD, Color("#FFCB52"), GOLD_DEEP, INK, Color.TRANSPARENT],
		"ghost": [Color(0, 0, 0, 0), Color(1, 1, 1, 0.06), Color(0, 0, 0, 0.15), LIMESTONE, LINE],
	}[kind]
	var border := 2 if c[4] != Color.TRANSPARENT else 0
	var normal := box(c[0], 14, border, c[4])
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 10
	normal.content_margin_bottom = 12
	normal.shadow_color = Color(0, 0, 0, 0.25)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 3)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = c[1]
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = c[2]
	pressed.shadow_size = 0
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(PANEL_HI, 0.35)
	disabled.set_border_width_all(2)
	disabled.border_color = Color(LINE, 0.8)
	disabled.shadow_size = 0
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", c[3])
	b.add_theme_color_override("font_hover_color", c[3])
	b.add_theme_color_override("font_pressed_color", c[3])
	b.add_theme_color_override("font_disabled_color", Color(MUTED, 0.6))


## Small key-cap label for keyboard hints.
static func keycap(text: String) -> Label:
	var l := label(text, 13, LIMESTONE, "body_bold")
	var sb := box(PANEL_HI, 6, 1, LINE)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 1
	sb.content_margin_bottom = 3
	l.add_theme_stylebox_override("normal", sb)
	return l


static func chip(text: String, bg: Color, fg := LIMESTONE, size := 14) -> Label:
	var l := label(text, size, fg, "body_bold")
	var sb := box(bg, 99)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	l.add_theme_stylebox_override("normal", sb)
	return l


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 18
	t.set_color("font_color", "Label", LIMESTONE)

	var le := box(INK_DEEP, 10, 2, LINE)
	le.content_margin_left = 14
	le.content_margin_right = 14
	le.content_margin_top = 8
	le.content_margin_bottom = 8
	var le_focus: StyleBoxFlat = le.duplicate()
	le_focus.border_color = BOUG
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", LIMESTONE)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(BOUG, 0.5))
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.6))
	t.set_font("font", "LineEdit", font("display"))
	t.set_font_size("font_size", "LineEdit", 22)

	t.set_stylebox("panel", "PanelContainer", box(PANEL, 18, 1, LINE, 18))

	var grab := box(LINE, 6)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(MUTED, 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(LIMESTONE, 6))
	var track := box(Color(0, 0, 0, 0.2), 6)
	track.content_margin_left = 6
	track.content_margin_right = 6
	t.set_stylebox("scroll", "VScrollBar", track)

	t.set_stylebox("panel", "PopupMenu", box(INK_DEEP, 12, 2, LINE, 8))
	t.set_stylebox("hover", "PopupMenu", box(PANEL_HI, 8))
	t.set_color("font_color", "PopupMenu", LIMESTONE)
	t.set_color("font_hover_color", "PopupMenu", LIMESTONE)
	t.set_font("font", "PopupMenu", font("display"))
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_constant("v_separation", "PopupMenu", 12)
	t.set_stylebox("panel", "TooltipPanel", box(INK_DEEP, 10, 1, LINE, 10))
	t.set_color("font_color", "TooltipLabel", LIMESTONE)
	t.set_font_size("font_size", "TooltipLabel", 16)
	return t
