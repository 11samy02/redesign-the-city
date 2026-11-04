extends Node
## Checks the title screen with four planners, the most it has to hold: every button and the setup box must lie inside
## the window. Started by the Game autoload:  godot --path . --resolution 1600x900 -- --probe=title [--out=<dir>]

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Sfx.muted = true
	Game.seats = [
		{"name": "Player 1", "color": 0, "bot": 0}, {"name": "Nikos", "color": 1, "bot": 2},
		{"name": "Eleni", "color": 2, "bot": 2}, {"name": "Maria", "color": 3, "bot": 2},
	]
	get_tree().change_scene_to_file(Game.TITLE_SCENE)
	for i in 90:
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	var title := get_tree().current_scene
	var view := get_viewport().get_visible_rect()
	for b in title.find_children("*", "Button", true, false):
		if not b.visible:
			continue
		var r: Rect2 = b.get_global_rect()
		if not view.grow(-4.0).encloses(r):
			_failures.append("button '%s' sticks out of the window: %s in %s" % [b.text, str(r), str(view)])
	var start: Button = null
	for b in title.find_children("*", "Button", true, false):
		if b.text == "Start game":
			start = b
	if start == null:
		_failures.append("no Start game button")
	else:
		check_gap(start, view)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			DirAccess.make_dir_recursive_absolute(a.substr(6))
			get_viewport().get_texture().get_image().save_png(a.substr(6) + "/title_four_planners.png")
	for f in _failures:
		print("TITLE FAIL ", f)
	print("TITLE probe done, %d failure(s)" % _failures.size())
	get_tree().quit(1 if not _failures.is_empty() else 0)


func check_gap(start: Button, view: Rect2) -> void:
	if start.get_global_rect().end.y > view.size.y - 12.0:
		_failures.append("Start game is too close to the bottom edge: %s" % str(start.get_global_rect()))
