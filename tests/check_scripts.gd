extends SceneTree
## Loads every script in scripts/ so parse errors show up. godot --headless --path . --script res://tests/check_scripts.gd


func _initialize() -> void:
	var bad := 0
	for path in _scripts("res://scripts"):
		var s = load(path)
		if s == null or (s is GDScript and not s.can_instantiate() and not path.contains("autoload")):
			print("BAD ", path)
			bad += 1
	print("checked, %d bad" % bad)
	quit(1 if bad > 0 else 0)


func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + "/" + d))
	return out
