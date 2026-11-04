extends RefCounted
## The player mats made in the mat editor. Each one is a small JSON file in user://custom_mats, so they
## survive restarts and never touch the mats that ship with the game (res://resources/mats).
##
## A custom mat is picked like any other: Game.settings["mat"] holds "custom:<id>" and
## MatLibrary.by_path() turns that back into a PlayerMatPreset.

const PlayerMatPreset = preload("res://scripts/resources/player_mat_preset.gd")
const PresetTile = preload("res://scripts/resources/preset_tile.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Grid = preload("res://scripts/core/grid.gd")

const DIR := "user://custom_mats"
const PREFIX := "custom:"
const MAX_NAME := 22
## A mat needs room left to build on: fewer free squares than this and the game would run out of space.
const MIN_FREE := 80


static func is_custom(path: String) -> bool:
	return path.begins_with(PREFIX)


static func id_of(path: String) -> String:
	return path.trim_prefix(PREFIX)


## Ids are "m" and digits, so they are always a safe file name.
static func _valid_id(id: String) -> bool:
	if id.length() < 2 or id[0] != "m":
		return false
	return id.substr(1).is_valid_int()


static func _file(id: String) -> String:
	return "%s/%s.json" % [DIR, id]


## Every custom mat, oldest first: [{ "path", "id", "title", "preset" }].
static func all() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".json"):
			continue
		var id := f.trim_suffix(".json")
		var entry := _read(id)
		if not entry.is_empty():
			out.append(entry)
	out.sort_custom(func(a, b): return a["created"] < b["created"] or (a["created"] == b["created"] and a["id"] < b["id"]))
	return out


## The preset of "custom:<id>", or null when that mat is gone.
static func load_preset(path: String):
	if not is_custom(path):
		return null
	var entry := _read(id_of(path))
	return entry.get("preset") if not entry.is_empty() else null


static func exists(path: String) -> bool:
	return is_custom(path) and FileAccess.file_exists(_file(id_of(path)))


## Saves a mat and returns its path ("custom:<id>"). `tiles` is [{kind, x, y, variant, large}] (see tiles_from_cells).
## Pass the path of an existing mat to overwrite it. Returns "" when the file can't be written.
static func save(title: String, tiles: Array, path := "") -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var id := id_of(path) if is_custom(path) and _valid_id(id_of(path)) else ""
	# the id is "m" and the creation time in milliseconds: unique, and it sorts the list oldest first
	if id == "":
		var created := int(Time.get_unix_time_from_system() * 1000.0)
		while FileAccess.file_exists(_file("m%d" % created)):
			created += 1
		id = "m%d" % created
	var list: Array = []
	for t in tiles:
		list.append({
			"kind": str(TileDefs.Kind.find_key(t["kind"])),
			"x": t["x"], "y": t["y"],
			"variant": t.get("variant", 0), "large": t.get("large", false),
		})
	var data := {"title": clean_name(title), "tiles": list}
	var f := FileAccess.open(_file(id), FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return PREFIX + id


static func delete(path: String) -> bool:
	if not is_custom(path) or not _valid_id(id_of(path)):
		return false
	return DirAccess.remove_absolute(_file(id_of(path))) == OK


static func clean_name(title: String) -> String:
	var t := title.strip_edges()
	return t.substr(0, MAX_NAME) if t != "" else "My mat"


## A name nobody uses yet: "My mat", "My mat 2", ...
static func free_name() -> String:
	var used: Array = []
	for e in all():
		used.append(e["title"].to_lower())
	var name := "My mat"
	var k := 2
	while name.to_lower() in used:
		name = "My mat %d" % k
		k += 1
	return name


## The tiles of a mat as the editor and the files hold them: one entry per tile, in reading order.
static func tiles_from_cells(cells: Array) -> Array:
	var out: Array = []
	for a in Grid.anchors(cells):
		var t: Dictionary = cells[a]
		out.append({
			"kind": t["kind"], "x": Grid.x_of(a), "y": Grid.y_of(a),
			"variant": t.get("variant", 0), "large": t.get("big", false),
		})
	return out


## Squares of a 14 x 14 mat that no tile covers.
static func free_squares(cells: Array) -> int:
	var n := 0
	for c in cells:
		if c == null:
			n += 1
	return n


static func _read(id: String) -> Dictionary:
	if not _valid_id(id) or not FileAccess.file_exists(_file(id)):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(_file(id))) != OK:
		return {}
	var data = parser.data
	if not (data is Dictionary) or not (data.get("tiles") is Array):
		return {}
	var preset := PlayerMatPreset.new()
	preset.title = clean_name(str(data.get("title", "")))
	var tiles: Array[PresetTile] = []
	for t in data["tiles"]:
		if not (t is Dictionary):
			continue
		var kind: int = TileDefs.Kind.get(str(t.get("kind", "")), -1)
		if kind < 0:
			continue
		var pt := PresetTile.new()
		pt.kind = kind
		pt.x = clampi(int(t.get("x", 0)), 0, Grid.SIZE - 1)
		pt.y = clampi(int(t.get("y", 0)), 0, Grid.SIZE - 1)
		pt.variant = maxi(int(t.get("variant", 0)), 0)
		pt.large = bool(t.get("large", false))
		tiles.append(pt)
	preset.tiles = tiles
	preset.description = "%d tiles of your own. Made in the mat editor." % tiles.size()
	return {"path": PREFIX + id, "id": id, "title": preset.title, "created": int(id.substr(1)), "preset": preset}
