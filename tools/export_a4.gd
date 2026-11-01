extends SceneTree
## Lays the whole printed game out on A4 pages, ready to print at 100 % ("actual size", no fit to page):
##
##   tiles_01.png ...                 every tile in the game, as many copies as the shop holds
##   cards_<deck>_01.png ...          the card fronts: circumstance, event and penalty
##   backs_<deck>.png                 a page of card backs; print it on the back of each front page
##   blank_<deck>.png                 pages of blank cards to write your own
##
## Pages are 300 dpi (2480 x 3508 px) with the dpi stored in the file. Tiles are 4 x 4 cm and
## cards 5 x 7 cm. They sit edge to edge, so cut along the small ticks in the margins.
## Every printed road is the crossing with all four sides open (the game draws the right piece by
## itself, paper cannot), so any road fits anywhere. The 38 roads of the shop are all there.
##
## It needs a real renderer, so do not use --headless. From the project root:
##   godot --path . --script res://tools/export_a4.gd -- --out=C:/some/folder

const Face = preload("res://scripts/game/circumstance_card_face.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const PrintTile = preload("res://scripts/ui/print_tile.gd")

const DPI := 300
const PAGE := Vector2i(2480, 3508)
const MIN_MARGIN := 44
const MARK_GAP := 10
const MARK_LEN := 28
const TILE_CELL := Vector2i(472, 472)
const CARD_CELL := Vector2i(591, 827)
const RENDER_SCALE := 2.0

var _out := ""


func _initialize() -> void:
	_out = ProjectSettings.globalize_path("res://") + "print_export"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_out += "/a4"
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _run() -> void:
	var started := Time.get_ticks_msec()
	await _export_tiles()
	await _export_cards()
	await _export_backgrounds()
	print("A4 pages written to ", _out, " in %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


# ================================================================ what goes on the pages

func _export_tiles() -> void:
	var bag: Array = []
	for t in TileDefs.full_bag():
		if t["kind"] != TileDefs.Kind.ROAD:
			bag.append({"tile": t, "mask": 15})
	bag.sort_custom(func(a, b): return TileDefs.sort_key(a["tile"]) < TileDefs.sort_key(b["tile"]))
	# On the table a road is a crossing with all four sides open, so any road fits anywhere. The
	# shop holds exactly the roads of the game: 24 plain, 5 shaded, 5 pedestrian, 4 bike lanes.
	for v in TileDefs.STREET_BAG:
		bag.append({"tile": TileDefs.make(TileDefs.Kind.ROAD, v), "mask": 15})
	var cache := {}
	var images: Array = []
	for item in bag:
		var key := "%d_%d_%d" % [item["tile"]["kind"], item["tile"].get("variant", 0), item["mask"]]
		if not cache.has(key):
			var node := PrintTile.build(item["tile"], item["mask"])
			cache[key] = await _render_to(node, RENDER_SCALE, Vector2(PrintTile.SIZE, PrintTile.SIZE), TILE_CELL)
		images.append(cache[key])
	var pages := _save_pages(images, TILE_CELL, "tiles")
	print("tiles: ", images.size(), " on ", pages, " pages")


func _export_cards() -> void:
	var decks := [
		["circumstance", CircumstanceDefs.IDS, false],
		["event", CardDefs.ids(CardDefs.EVENT), true],
		["penalty", CardDefs.ids(CardDefs.PENALTY), true],
	]
	for d in decks:
		var images: Array = []
		for id in d[1]:
			var card: Control = Face.front_turn(id, true) if d[2] else Face.front(id, true)
			images.append(await _render_to(card, RENDER_SCALE, Vector2(Face.WIDTH, Face.HEIGHT), CARD_CELL))
		var pages := _save_pages(images, CARD_CELL, "cards_" + d[0])
		print("cards ", d[0], ": ", images.size(), " on ", pages, " pages")


## Backs and blanks: one full page of the same card, so any number of pages can be printed.
func _export_backgrounds() -> void:
	var sheets := {
		"backs_circumstance": Face.back_circumstance(),
		"backs_event": Face.back_turn(CardDefs.EVENT),
		"backs_penalty": Face.back_turn(CardDefs.PENALTY),
		"blank_event": Face.front_blank("event"),
		"blank_penalty": Face.front_blank("penalty"),
		"blank_circumstance_weather": Face.front_blank("weather"),
		"blank_circumstance_city": Face.front_blank("city"),
	}
	for name in sheets:
		var img: Image = await _render_to(sheets[name], RENDER_SCALE, Vector2(Face.WIDTH, Face.HEIGHT), CARD_CELL)
		var per_page: int = _grid(CARD_CELL)["cols"] * _grid(CARD_CELL)["rows"]
		var images: Array = []
		images.resize(per_page)
		images.fill(img)
		_save_pages(images, CARD_CELL, name)
	print("backgrounds: ", sheets.size(), " pages")


# ================================================================ page layout

## How many cells of `cell` fit on a page, and where the grid starts so it is centred.
func _grid(cell: Vector2i) -> Dictionary:
	var cols := (PAGE.x - 2 * MIN_MARGIN) / cell.x
	var rows := (PAGE.y - 2 * MIN_MARGIN) / cell.y
	var origin := Vector2i((PAGE.x - cols * cell.x) / 2, (PAGE.y - rows * cell.y) / 2)
	return {"cols": cols, "rows": rows, "origin": origin}


## Fills pages with `images` (each exactly `cell` big) and saves them as <prefix>_NN.png, or
## <prefix>.png when it all fits on one page. Returns the number of pages.
func _save_pages(images: Array, cell: Vector2i, prefix: String) -> int:
	var g := _grid(cell)
	var per_page: int = g["cols"] * g["rows"]
	var pages := ceili(images.size() / float(per_page))
	for p in pages:
		var page := Image.create(PAGE.x, PAGE.y, false, Image.FORMAT_RGBA8)
		page.fill(Color.WHITE)
		for k in per_page:
			var i := p * per_page + k
			if i >= images.size():
				break
			var at: Vector2i = g["origin"] + Vector2i((k % g["cols"]) * cell.x, (k / g["cols"]) * cell.y)
			page.blend_rect(images[i], Rect2i(Vector2i.ZERO, cell), at)
		_cut_marks(page, g, cell)
		var file := prefix if pages == 1 else "%s_%02d" % [prefix, p + 1]
		_save(page, "%s/%s.png" % [_out, file])
	return pages


## Short ticks in the margins, in line with every cut.
func _cut_marks(page: Image, g: Dictionary, cell: Vector2i) -> void:
	var ink := Color(0.15, 0.15, 0.15, 1.0)
	var o: Vector2i = g["origin"]
	var w: int = g["cols"] * cell.x
	var h: int = g["rows"] * cell.y
	for c in g["cols"] + 1:
		var x: int = o.x + c * cell.x
		page.fill_rect(Rect2i(x - 1, o.y - MARK_GAP - MARK_LEN, 2, MARK_LEN), ink)
		page.fill_rect(Rect2i(x - 1, o.y + h + MARK_GAP, 2, MARK_LEN), ink)
	for r in g["rows"] + 1:
		var y: int = o.y + r * cell.y
		page.fill_rect(Rect2i(o.x - MARK_GAP - MARK_LEN, y - 1, MARK_LEN, 2), ink)
		page.fill_rect(Rect2i(o.x + w + MARK_GAP, y - 1, MARK_LEN, 2), ink)


# ================================================================ drawing and saving

## Draws `node` into a transparent image `scale` times its logical size, then shrinks it to `cell`.
func _render_to(node: Control, scale: float, logical: Vector2, cell: Vector2i) -> Image:
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
	img.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
	return img


## Saves a PNG with a pHYs chunk so printers and viewers know it is 300 dpi (Godot writes none).
func _save(img: Image, path: String) -> void:
	var png := img.save_png_to_buffer()
	var per_metre := roundi(DPI / 0.0254)
	var body := PackedByteArray()
	body.append_array("pHYs".to_ascii_buffer())
	body.append_array(_be32(per_metre))
	body.append_array(_be32(per_metre))
	body.append(1)
	var chunk := _be32(9)
	chunk.append_array(body)
	chunk.append_array(_be32(_crc32(body)))
	# signature (8) + IHDR chunk (25): the pHYs chunk goes straight after, before the image data
	var out := png.slice(0, 33)
	out.append_array(chunk)
	out.append_array(png.slice(33))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(out)
	f.close()


func _be32(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255])


func _crc32(data: PackedByteArray) -> int:
	var c := 0xFFFFFFFF
	for b in data:
		c ^= b
		for k in 8:
			c = (c >> 1) ^ (0xEDB88320 if c & 1 else 0)
	return c ^ 0xFFFFFFFF
