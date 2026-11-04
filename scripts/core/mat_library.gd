extends RefCounted
## Finds the mats that ship with the game (PlayerMatPreset resources in res://resources/mats, none at the moment) and
## resolves a saved choice back to a mat. The map picker lists them under "Game mats"; the chosen one's path is kept
## in the settings so the choice is remembered.

const CustomMats = preload("res://scripts/core/custom_mats.gd")

const DIR := "res://resources/mats"
## The mat the game starts on, and the one picked again when the chosen custom mat is deleted: the empty mat.
const DEFAULT := ""


## Every mat in the folder, in file-name order.
static func all() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	var names: Array = []
	for f in DirAccess.get_files_at(DIR):
		# an exported game keeps resources as .remap files
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			if not (name in names):
				names.append(name)
	names.sort()
	for name in names:
		var res = load("%s/%s" % [DIR, name])
		if res != null and res.has_method("build_cells"):
			out.append(res)
	return out


## The mat at `path`, or null (no path means an empty mat). "custom:<id>" is a mat made in the mat editor.
static func by_path(path: String):
	if CustomMats.is_custom(path):
		return CustomMats.load_preset(path)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	return res if res != null and res.has_method("build_cells") else null
