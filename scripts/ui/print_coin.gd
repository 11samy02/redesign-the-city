extends RefCounted
## A gold coin as it is printed for the real board game: a round coin with its value in the middle.
## Each value has its own colour ring, so a 5 and a 10 differ at a glance. The same page is copied
## once per player (and once for the bank), so one page holds exactly one starting purse.

const UiKit = preload("res://scripts/ui/ui_kit.gd")

const SIZE := 256.0
const MARGIN := 10.0

## One starting purse: [value, how many]. It must add up to the starting gold of a player.
## Prices and cards run from 1 to 8 gold, so 1, 2, 5 and 10 make any of them in at most 3 coins.
const PURSE := [[10, 4], [5, 6], [2, 8], [1, 14]]

## The rim of the coin icon, tinted per value so a 5 and a 10 differ at a glance. The 1-gold coin
## keeps the exact icon of the game, with no tint.
const RIM := {
	2: Color("#A9B4BF"),
	5: Color("#3A6FC4"),
	10: Color("#3F9A52"),
}
const COIN_SVG := "res://assets/ui/coin.svg"
const SVG_SCALE := 8.0
const FACE_DEEP := Color("#E8B33A")
const INK := Color("#3A2A06")

static var _coin_tex: Texture2D = null


static func purse_total() -> int:
	var total := 0
	for p in PURSE:
		total += p[0] * p[1]
	return total


## A 256 x 256 control: the game's coin icon in the middle of its cell, with room around it for the
## cut, and the value on it in the style of the prices in the game (gold number, dark outline).
static func build(value: int) -> Control:
	var root := _cell()
	var d := SIZE - 2.0 * MARGIN
	var coin := TextureRect.new()
	coin.texture = _coin_texture()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_SCALE
	coin.position = Vector2(MARGIN, MARGIN)
	coin.size = Vector2(d, d)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coin)
	if RIM.has(value):
		# the icon's rim is the outer 3 of its 28 units of radius
		var unit := d / 64.0
		var r := 28.0 * unit
		var ring := Panel.new()
		ring.position = Vector2(SIZE / 2.0 - r, SIZE / 2.0 - r)
		ring.size = Vector2(2.0 * r, 2.0 * r)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_theme_stylebox_override("panel", UiKit.box(Color.TRANSPARENT, int(r), int(3.0 * unit), RIM[value]))
		root.add_child(ring)
	var fs := 128 if value < 10 else 106
	var num := UiKit.outline(UiKit.label(str(value), fs, UiKit.GOLD, "display_bold"), 22)
	num.position = Vector2(0, SIZE / 2.0 - 78)
	num.size = Vector2(SIZE, 150)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(num)
	return root


## The game's coin icon, drawn again from its SVG at a high resolution so it stays sharp on paper.
static func _coin_texture() -> Texture2D:
	if _coin_tex == null:
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string(COIN_SVG), SVG_SCALE)
		assert(err == OK, "could not draw " + COIN_SVG)
		img.generate_mipmaps()
		_coin_tex = ImageTexture.create_from_image(img)
	return _coin_tex


## The spare cell on the purse page: what the page is and how to use it.
static func build_label(total: int) -> Control:
	var root := _cell()
	var box := Panel.new()
	box.position = Vector2(MARGIN, MARGIN)
	box.size = Vector2(SIZE - 2.0 * MARGIN, SIZE - 2.0 * MARGIN)
	box.add_theme_stylebox_override("panel", UiKit.box(Color("#FFF6D8"), 26, 5, FACE_DEEP))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var lines := [["PURSE", 28, "display_bold", INK], [str(total), 84, "display_bold", INK],
		["GOLD", 26, "display_bold", UiKit.GOLD_DEEP], ["one per player", 16, "body_bold", INK.lightened(0.25)],
		["and one for the bank", 16, "body_bold", INK.lightened(0.25)]]
	var y := 28.0
	for ln in lines:
		var l := UiKit.label(ln[0], ln[1], ln[3], ln[2])
		l.position = Vector2(0, y)
		l.size = Vector2(SIZE, ln[1] * 1.2)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(l)
		y += ln[1] * 1.1
	return root


static func _cell() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(SIZE, SIZE)
	root.size = Vector2(SIZE, SIZE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root


static func _disc(at: Vector2, d: float, fill: Color, border_color := Color.TRANSPARENT, border := 0) -> Panel:
	var p := Panel.new()
	p.position = at
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiKit.box(fill, int(d / 2.0), border, border_color))
	return p
