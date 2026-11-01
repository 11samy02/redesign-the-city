extends RefCounted
## A tile as it is printed for the real board game: the picture with what a player needs on it,
## laid out like the tiles in the game, with no boxes.
##
##   top left       homes only: one round role icon per citizen who lives there
##   bottom right   what it costs (coin and number)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Roles = preload("res://scripts/core/roles.gd")

const SIZE := 256.0
const MARGIN := 18.0
const COIN := 50.0
const ICON := 50.0
const ICON_STEP := 36.0


## A 256 x 256 control. `road_mask` picks the piece of a road (see TileDefs.art_path).
static func build(tile: Dictionary, road_mask := 15) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(SIZE, SIZE)
	root.size = Vector2(SIZE, SIZE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = UiKit.tex(TileDefs.art_path(tile, road_mask))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = Vector2(SIZE, SIZE)
	root.add_child(art)
	root.add_child(_residents(TileDefs.members(tile)))
	root.add_child(_price(TileDefs.tile_cost(tile)))
	return root


## Coin and number in the bottom-right corner; the outline keeps the number readable on any picture.
static func _price(cost: int) -> Control:
	var f := UiKit.font("display_bold")
	var fs := 46
	var text_w := f.get_string_size(str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(COIN + text_w + 4, COIN)
	holder.position = Vector2(SIZE - MARGIN - holder.size.x, SIZE - MARGIN - COIN)
	holder.add_child(_soft_disc(Vector2(COIN, COIN)))
	var c := UiKit.icon("res://assets/ui/coin.svg", COIN)
	c.size = Vector2(COIN, COIN)
	holder.add_child(c)
	var l := UiKit.outline(UiKit.label(str(cost), fs, UiKit.GOLD, "display_bold"), 10)
	l.position = Vector2(COIN + 4, 0)
	l.size = Vector2(text_w + 4, COIN)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(l)
	return holder


## The citizens of a home, as round role icons that overlap a little, like in the game.
static func _residents(members: Array) -> Control:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(MARGIN, MARGIN)
	for k in members.size():
		var at := Vector2(k * ICON_STEP, 0)
		var disc := _soft_disc(Vector2(ICON, ICON))
		disc.position = at
		row.add_child(disc)
		var icon := UiKit.icon(Roles.DEFS[members[k]]["icon"], ICON)
		icon.size = Vector2(ICON, ICON)
		icon.position = at
		row.add_child(icon)
	return row


## A faint dark disc behind an icon so it stands out from the picture without a box.
static func _soft_disc(size: Vector2) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = size
	p.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK_DEEP, 0.35), int(size.x / 2)))
	return p


## File name for a tile's print image, for example "home_medium_working_couple".
static func file_name(tile: Dictionary, road_mask := 15) -> String:
	# every household has its own picture, named after it, so the picture's name is the file name
	return TileDefs.art_path(tile, road_mask).get_file().get_basename()
