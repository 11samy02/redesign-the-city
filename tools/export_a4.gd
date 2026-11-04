extends SceneTree
## Lays the whole printed game out on A4 pages, ready to print at 100 % ("actual size", no fit to page).
## Every page is printed once: it already holds every copy the game needs.
##
##   tiles_01.png ...                 every tile in the game: the shop's tiles, then the free ones. A 2:2 tile
##                                    prints 4 x 4 cm, a 1:1 tile 2 x 2 cm (half the size), and the two sizes
##                                    share pages, big tiles on top and small ones below, to use every page
##   cards_<deck>_01.png ...          the card fronts: circumstance, event and penalty
##   backs_<deck>.png                 a page of card backs; print it on the back of each front page
##   blank_<deck>.png                 pages of blank cards to write your own
##   purse.png                        one starting purse (100 gold) on one page: copy it for every
##                                    player and once for the bank
##   pollution_bars.png               a pollution bar and two cut-out chips for every player colour
##   planner_guide.png                the planner's guide, two on a page: one for every player
##
## Pages are 300 dpi (2480 x 3508 px) with the dpi stored in the file. Cards are 5 x 7 cm. Tiles sit edge to
## edge, so cut along the small ticks in the margins: left and right ticks mark every row (the long one
## separates the big tiles from the small ones: cut there first), the top ticks mark the columns of the big
## tiles and the bottom ticks the columns of the small ones.
## Every printed road is the crossing with all four sides open (the game draws the right piece by
## itself, paper cannot), so any road fits anywhere. The 38 roads of the shop are all there.
## The free tiles of a game (each player's free roads and what the event cards give) come last,
## after the 222 tiles of the shop.
##
## It needs a real renderer, so do not use --headless. From the project root:
##   godot --path . --script res://tools/export_a4.gd -- --out=C:/some/folder

const Face = preload("res://scripts/game/circumstance_card_face.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const PrintTile = preload("res://scripts/ui/print_tile.gd")
const PrintCoin = preload("res://scripts/ui/print_coin.gd")
const PrintGuide = preload("res://scripts/ui/print_guide.gd")
const PrintBars = preload("res://scripts/ui/print_bars.gd")
const GameRules = preload("res://scripts/core/game_state.gd")

const DPI := 300
const PAGE := Vector2i(2480, 3508)
const MIN_MARGIN := 44
const MARK_GAP := 10
const MARK_LEN := 28
## A 2:2 tile is 4 cm, a 1:1 tile half of that.
const BIG_TILE := 472
const SMALL_TILE := 236
const CARD_CELL := Vector2i(591, 827)
const COIN_CELL := Vector2i(472, 472)
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
	await _export_helpers()
	await _export_cards()
	await _export_new_cards()
	await _export_backgrounds()
	await _export_purse()
	print("A4 pages written to ", _out, " in %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


# ================================================================ what goes on the pages

func _export_tiles() -> void:
	# old tile pages from an earlier export would stay behind when there are fewer pages now
	for f in DirAccess.get_files_at(_out):
		if f.begins_with("tiles_") or f == "tiles.png":
			DirAccess.remove_absolute(_out + "/" + f)
	var bag: Array = []
	for t in TileDefs.full_bag():
		if t["kind"] != TileDefs.Kind.ROAD:
			bag.append({"tile": t, "mask": 15})
	bag.sort_custom(func(a, b): return TileDefs.sort_key(a["tile"]) < TileDefs.sort_key(b["tile"]))
	# On the table a road is a crossing with all four sides open, so any road fits anywhere. The
	# shop holds exactly the roads of the game: 24 plain, 5 shaded, 5 pedestrian, 4 bike lanes.
	for v in TileDefs.STREET_BAG:
		bag.append({"tile": TileDefs.make(TileDefs.Kind.ROAD, v), "mask": 15})
	# After the shop come the free tiles a game can hand out. They are not in the shop, so they
	# need their own copies on the table.
	var shop_count := bag.size()
	var extras := _free_tiles()
	extras.sort_custom(func(a, b): return TileDefs.sort_key(a) < TileDefs.sort_key(b))
	for t in extras:
		bag.append({"tile": t, "mask": 15})
	var cache := {}
	var big: Array = []
	var small: Array = []
	for item in bag:
		var is_big: bool = TileDefs.footprint(item["tile"]) == 2
		var key := "%d_%d_%d" % [item["tile"]["kind"], item["tile"].get("variant", 0), item["mask"]]
		if not cache.has(key):
			var cell := Vector2i(BIG_TILE, BIG_TILE) if is_big else Vector2i(SMALL_TILE, SMALL_TILE)
			var node := PrintTile.build(item["tile"], item["mask"])
			cache[key] = await _render_to(node, RENDER_SCALE, Vector2(PrintTile.SIZE, PrintTile.SIZE), cell)
		(big if is_big else small).append(cache[key])
	var pages := _save_tile_pages(big, small)
	print("tiles: ", shop_count, " from the shop + ", extras.size(), " free = ", big.size() + small.size(), " (", big.size(), " big 4 cm, ", small.size(), " small 2 cm) on ", pages, " pages")


## Rows of big tiles (5 across) and then rows of small ones (10 across) go down the pages one after the
## other, so a page that runs out of big tiles carries on with small ones instead of staying half empty.
func _save_tile_pages(big: Array, small: Array) -> int:
	var rows: Array = []
	var per_big := (PAGE.x - 2 * MIN_MARGIN) / BIG_TILE
	var per_small := (PAGE.x - 2 * MIN_MARGIN) / SMALL_TILE
	for k in range(0, big.size(), per_big):
		rows.append({"size": BIG_TILE, "images": big.slice(k, k + per_big)})
	for k in range(0, small.size(), per_small):
		rows.append({"size": SMALL_TILE, "images": small.slice(k, k + per_small)})
	var pages: Array = []
	var page_rows: Array = []
	var used := 0
	var room := PAGE.y - 2 * MIN_MARGIN
	for r in rows:
		if used + r["size"] > room:
			pages.append(page_rows)
			page_rows = []
			used = 0
		page_rows.append(r)
		used += r["size"]
	if not page_rows.is_empty():
		pages.append(page_rows)
	for p in pages.size():
		_draw_tile_page(pages[p], "tiles" if pages.size() == 1 else "tiles_%02d" % (p + 1), per_big, per_small)
	return pages.size()


func _draw_tile_page(page_rows: Array, file: String, per_big: int, per_small: int) -> void:
	var page := Image.create(PAGE.x, PAGE.y, false, Image.FORMAT_RGBA8)
	page.fill(Color.WHITE)
	var height := 0
	var has_big := false
	var has_small := false
	for r in page_rows:
		height += r["size"]
		has_big = has_big or r["size"] == BIG_TILE
		has_small = has_small or r["size"] == SMALL_TILE
	var origin_x := (PAGE.x - per_big * BIG_TILE) / 2
	var y := (PAGE.y - height) / 2
	var top := y
	var ink := Color(0.15, 0.15, 0.15, 1.0)
	var right := origin_x + per_big * BIG_TILE
	var boundary_marks: Array = []
	for i in page_rows.size():
		var r: Dictionary = page_rows[i]
		var size: int = r["size"]
		for k in r["images"].size():
			page.blend_rect(r["images"][k], Rect2i(Vector2i.ZERO, Vector2i(size, size)), Vector2i(origin_x + k * size, y))
		# a tick on both sides at the top of every row; a long one where the size changes
		var long_mark: bool = i > 0 and page_rows[i - 1]["size"] != size
		var tick := MARK_LEN * (3 if long_mark else 1)
		page.fill_rect(Rect2i(origin_x - MARK_GAP - tick, y - 1, tick, 2), ink)
		page.fill_rect(Rect2i(right + MARK_GAP, y - 1, tick, 2), ink)
		y += size
	page.fill_rect(Rect2i(origin_x - MARK_GAP - MARK_LEN, y - 1, MARK_LEN, 2), ink)
	page.fill_rect(Rect2i(right + MARK_GAP, y - 1, MARK_LEN, 2), ink)
	# column ticks: big tiles' columns on top, small tiles' columns at the bottom (the page's only kind on both)
	var top_size := BIG_TILE if has_big else SMALL_TILE
	var bottom_size := SMALL_TILE if has_small else BIG_TILE
	for c in range(0, (right - origin_x) / top_size + 1):
		var x := origin_x + c * top_size
		page.fill_rect(Rect2i(x - 1, top - MARK_GAP - MARK_LEN, 2, MARK_LEN), ink)
	for c in range(0, (right - origin_x) / bottom_size + 1):
		var x := origin_x + c * bottom_size
		page.fill_rect(Rect2i(x - 1, y + MARK_GAP, 2, MARK_LEN), ink)
	_save(page, "%s/%s.png" % [_out, file])


## The sheets that help people play: the pollution bars and the planner's guide.
func _export_helpers() -> void:
	var bars: Image = await _render_native(PrintBars.build(), PrintBars.PAGE)
	_save(bars, "%s/pollution_bars.png" % _out)
	var guide: Image = await _render_native(PrintGuide.build(), Vector2(PrintGuide.WIDTH, PrintGuide.HEIGHT))
	var page := Image.create(PAGE.x, PAGE.y, false, Image.FORMAT_RGBA8)
	page.fill(Color.WHITE)
	var gx := (PAGE.x - guide.get_width()) / 2
	var gap := 60
	var gy := (PAGE.y - 2 * guide.get_height() - gap) / 2
	for k in 2:
		page.blend_rect(guide, Rect2i(Vector2i.ZERO, guide.get_size()), Vector2i(gx, gy + k * (guide.get_height() + gap)))
	# a dashed line between the two guides
	var cut_y := gy + guide.get_height() + gap / 2
	for x in range(MIN_MARGIN, PAGE.x - MIN_MARGIN, 40):
		page.fill_rect(Rect2i(x, cut_y - 1, 22, 2), Color(0.45, 0.45, 0.45, 1.0))
	_save(page, "%s/planner_guide.png" % _out)
	print("helpers: pollution_bars.png, planner_guide.png (2 guides per page)")


## One starting purse on one page (purse.png): copy it once per player and once for the bank.
## The coins come in several values so a purse is a few cuts, not a hundred coins; the spare cell
## carries the label. Always exactly START_MONEY gold, so it follows the rules if they change.
func _export_purse() -> void:
	assert(PrintCoin.purse_total() == GameRules.START_MONEY, "the purse page must hold the starting gold")
	var images: Array = []
	for p in PrintCoin.PURSE:
		var img: Image = await _render_to(PrintCoin.build(p[0]), RENDER_SCALE, Vector2(PrintCoin.SIZE, PrintCoin.SIZE), COIN_CELL)
		for i in p[1]:
			images.append(img)
	var label_img: Image = await _render_to(PrintCoin.build_label(PrintCoin.purse_total()), RENDER_SCALE, Vector2(PrintCoin.SIZE, PrintCoin.SIZE), COIN_CELL)
	images.append(label_img)
	var pages := _save_pages(images, COIN_CELL, "purse")
	print("purse: ", images.size() - 1, " coins worth ", PrintCoin.purse_total(), " gold on ", pages, " page")


## The most free tiles a game can give out, worked out from the rules and the cards so it never
## drifts from them: every player's free roads, the extra roads of the event cards, and every tile
## an event card hands out. Each card exists once. A card that offers a choice is counted for every
## option, so the sheet always has enough whichever way the players choose.
func _free_tiles() -> Array:
	var counts := {}  # "kind_variant" -> {"tile", "n"}
	var add := func(kind: int, variant: int, n: int) -> void:
		var key := "%d_%d" % [kind, variant]
		if not counts.has(key):
			counts[key] = {"tile": TileDefs.make(kind, variant), "n": 0}
		counts[key]["n"] += n
	add.call(TileDefs.Kind.ROAD, 0, GameRules.FREE_ROADS * GameRules.MAX_PLAYERS)
	for type in [CardDefs.EVENT, CardDefs.PENALTY]:
		for id in CardDefs.ids(type):
			var fx: Dictionary = CardDefs.info(id)["fx"]
			var effects: Array = []
			if fx["op"] == "choice":
				for o in fx["options"]:
					effects.append(o["fx"])
			else:
				effects.append(fx)
			for e in effects:
				if e["op"] == "free_tile":
					add.call(e["kind"], e.get("variant", 0), int(e["n"]))
				elif e["op"] == "free_roads":
					add.call(TileDefs.Kind.ROAD, 0, int(e["n"]))
	var out: Array = []
	for key in counts:
		for i in counts[key]["n"]:
			out.append(counts[key]["tile"].duplicate())
	return out


func _export_cards() -> void:
	# pages of an earlier, bigger deck would stay behind when the decks have fewer cards now
	for f in DirAccess.get_files_at(_out):
		if f.begins_with("cards_"):
			DirAccess.remove_absolute(_out + "/" + f)
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


## Only the cards added in the cards rework, in the folder new_cards: the older cards are already printed and cut, so
## these pages hold just the new ones. They are the same cards as in the full pages, with the same numbers. Backs are
## the usual backs_<deck> pages.
func _export_new_cards() -> void:
	var dir := _out + "/new_cards"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	var decks := [
		["event", CardDefs.new_ids(CardDefs.EVENT), true],
		["penalty", CardDefs.new_ids(CardDefs.PENALTY), true],
		["circumstance", CircumstanceDefs.NEW_IDS, false],
	]
	var normal_out := _out
	_out = dir
	for d in decks:
		var images: Array = []
		for id in d[1]:
			var card: Control = Face.front_turn(id, true) if d[2] else Face.front(id, true)
			images.append(await _render_to(card, RENDER_SCALE, Vector2(Face.WIDTH, Face.HEIGHT), CARD_CELL))
		var pages := _save_pages(images, CARD_CELL, "new_" + d[0])
		print("new cards ", d[0], ": ", images.size(), " on ", pages, " page(s)")
	_out = normal_out


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


## Draws `node` at exactly `logical` pixels (one control pixel is one image pixel), opaque.
func _render_native(node: Control, logical: Vector2) -> Image:
	var sub := SubViewport.new()
	sub.size = Vector2i(logical)
	sub.transparent_bg = false
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
