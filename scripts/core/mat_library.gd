extends RefCounted
## Finds the prefixed mats (PlayerMatPreset resources) in res://resources/mats. The title screen lists
## them; the chosen one's path is kept in the settings so the choice is remembered.

const DIR := "res://resources/mats"


## Every mat in the folder, in file-name order.
static func all() -> Array:
	var out: Array = []
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


## The mat at `path`, or null (no path means an empty mat).
static func by_path(path: String):
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	return res if res != null and res.has_method("build_cells") else null
