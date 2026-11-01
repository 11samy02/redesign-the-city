extends SceneTree
## Exports everything for printing the real-life board game, into one folder:
##
##   tiles_sheet.png            every tile in one sprite sheet, with price, name and (for homes) who lives there
##   cards_circumstance_sheet.png   the hidden circumstance cards
##   cards_event_sheet.png          the event cards
##   cards_penalty_sheet.png        the penalty cards
##   backgrounds/               each card back and each blank card background, transparent corners
##
## Print a sheet, then cut along the crop marks in the gaps. The cards are drawn by the same code as
## the big card in the game, so a printed card looks exactly like the one on the screen (only the drop
## shadow is left out, and the corner gem of the ornate cards sits inside the card).
##
## It needs a real renderer, so do not use --headless. From the project root:
##   godot --path . --script res://tools/export_print.gd -- --out=C:/some/folder

const Face = preload("res://scripts/game/circumstance_card_face.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const PrintTile = preload("res://scripts/ui/print_tile.gd")

const TILE_PX := 512
const GAP := 36
const MARK := 12
const MARK_OFF := 6
const TILE_SCALE := 2.0
const CARD_SCALE := 2.0
const SHEET_CARD_SCALE := 1.5
const TILE_COLUMNS := 12
const CARD_COLUMNS := 12

var _out := ""


func _initialize() -> void:
	_out = ProjectSettings.globalize_path("res://") + "print_export"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	for d in ["", "/backgrounds"]:
		DirAccess.make_dir_recursive_absolute(_out + d)
	_run()


func _run() -> void:
	var started := Time.get_ticks_msec()
	await _export_tiles()
	await _export_backgrounds()
	await _export_cards()
	print("print export written to ", _out, " in %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


# ================================================================ tiles

## Every tile of the game once: the homes by household, the other buildings, then the road pieces.
func _print_tiles() -> Array:
	var list: Array = []
	for kind in TileDefs.DEFS:
		if kind == TileDefs.Kind.ROAD:
			continue
		var variants: int = TileDefs.HOUSEHOLDS[kind].size() if TileDefs.HOUSEHOLDS.has(kind) else 1
		for v in variants:
			list.append({"tile": TileDefs.make(kind, v), "mask": 15})
	list.sort_custom(func(a, b): return TileDefs.sort_key(a["tile"]) < TileDefs.sort_key(b["tile"]))
	# a printed road is always the crossing with four open sides, so it fits anywhere on the table
	for v in TileDefs.STREETS.size():
		list.append({"tile": TileDefs.make(TileDefs.Kind.ROAD, v), "mask": 15})
	return list


func _export_tiles() -> void:
	var items := _print_tiles()
	var cell := Vector2i(TILE_PX, TILE_PX)
	var sheet := _blank_sheet(items.size(), TILE_COLUMNS, cell)
	for i in items.size():
		var node := PrintTile.build(items[i]["tile"], items[i]["mask"])
		var img: Image = await _render(node, TILE_SCALE, Vector2(PrintTile.SIZE, PrintTile.SIZE))
		_place(sheet, img, i, TILE_COLUMNS, cell)
	sheet.save_png(_out + "/tiles_sheet.png")
	print("tiles: ", items.size())


# ================================================================ sheet layout

## A transparent sheet with room for `count` cells of `cell` pixels in `columns` columns,
## a gap around each so there is space for the crop marks.
func _blank_sheet(count: int, columns: int, cell: Vector2i) -> Image:
	var rows := ceili(count / float(columns))
	var sheet := Image.create(columns * (cell.x + GAP) + GAP, rows * (cell.y + GAP) + GAP, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	return sheet


## Puts `img` in the cell for item `i` and draws small crop marks at its four corners.
func _place(sheet: Image, img: Image, i: int, columns: int, cell: Vector2i) -> void:
	var at := Vector2i(GAP + (i % columns) * (cell.x + GAP), GAP + (i / columns) * (cell.y + GAP))
	img.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
	sheet.blend_rect(img, Rect2i(Vector2i.ZERO, cell), at)
	var ink := Color(0.15, 0.15, 0.15, 1.0)
	for cx in [at.x, at.x + cell.x]:
		for cy in [at.y, at.y + cell.y]:
			var dx := -1 if cx == at.x else 1
			var dy := -1 if cy == at.y else 1
			# a tick along each axis, in the gap, pointing away from the corner
			var hx := Rect2i(cx + dx * MARK_OFF if dx > 0 else cx - MARK_OFF - MARK, cy - 1, MARK, 2)
			var vy := Rect2i(cx - 1, cy + dy * MARK_OFF if dy > 0 else cy - MARK_OFF - MARK, 2, MARK)
			sheet.fill_rect(hx, ink)
			sheet.fill_rect(vy, ink)


# ================================================================ backgrounds

func _export_backgrounds() -> void:
	var backs := {
		"card_back_event": Face.back_turn(CardDefs.EVENT),
		"card_back_penalty": Face.back_turn(CardDefs.PENALTY),
		"card_back_circumstance": Face.back_circumstance(),
		"card_blank_event": Face.front_blank("event"),
		"card_blank_penalty": Face.front_blank("penalty"),
		"card_blank_circumstance_weather": Face.front_blank("weather"),
		"card_blank_circumstance_city": Face.front_blank("city"),
	}
	for name in backs:
		var img: Image = await _render(backs[name], CARD_SCALE)
		img.save_png("%s/backgrounds/%s.png" % [_out, name])
	print("backgrounds: ", backs.size())


# ================================================================ cards

## One sprite sheet per deck, so each can be printed and cut on its own.
func _export_cards() -> void:
	var groups := [
		["circumstance", CircumstanceDefs.IDS, false],
		["event", CardDefs.ids(CardDefs.EVENT), true],
		["penalty", CardDefs.ids(CardDefs.PENALTY), true],
	]
	var cell := Vector2i((Face.WIDTH * SHEET_CARD_SCALE) as int, (Face.HEIGHT * SHEET_CARD_SCALE) as int)
	for g in groups:
		var ids: Array = g[1]
		var sheet := _blank_sheet(ids.size(), CARD_COLUMNS, cell)
		for i in ids.size():
			var card: Control = Face.front_turn(ids[i], true) if g[2] else Face.front(ids[i], true)
			var img: Image = await _render(card, CARD_SCALE)
			_place(sheet, img, i, CARD_COLUMNS, cell)
		sheet.save_png("%s/cards_%s_sheet.png" % [_out, g[0]])
		print("cards ", g[0], ": ", ids.size())


# ================================================================ drawing a control to an image

## Draws `node` (a 420 x 588 card) with 4x multisampling into a transparent image, `scale` times its size.
func _render(node: Control, scale: float, logical := Vector2(Face.WIDTH, Face.HEIGHT)) -> Image:
	var sub := SubViewport.new()
	sub.size = Vector2i(logical * scale)
	sub.size_2d_override = Vector2i(logical)
	sub.size_2d_override_stretch = true
	sub.transparent_bg = true
	sub.msaa_2d = Viewport.MSAA_4X
	sub.gui_disable_input = true
	sub.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(sub)
	node.size = logical
	sub.add_child(node)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	sub.queue_free()
	return img
