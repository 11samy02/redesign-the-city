extends Node
## The final screen: its layout, the big city view with the timeline, and the turn-card grid.
## Started by the Game autoload:  godot --path . --resolution 1600x900 -- --probe=final --out=<dir>
## Exit code 1 when a check fails.

var out := "."
var _failures: Array[String] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Sfx.muted = true
	_run.call_deferred()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _check(ok: bool, what: String) -> void:
	print("FINAL %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


## Waits until the big view has stopped moving (at most `limit` seconds).
func _until_idle(city, limit := 10.0) -> void:
	var left := limit
	await _wait(0.1)
	while city._busy and left > 0.0:
		await _wait(0.1)
		left -= 0.1


func _click_at(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	get_viewport().push_input(m, true)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)


func _run() -> void:
	await _wait(1.0)
	Game.state = null
	Game.goto(Game.FINAL_SCENE)
	await _wait(2.0)
	var fin = get_tree().current_scene
	fin.speed = 0.0
	await _wait(1.5)
	await _snap("1_results")
	fin.goto("cities")
	await _wait(0.6)
	await _snap("2_cities")
	var bottom := 0.0
	for b in fin._dock.find_children("*", "Button", true, false):
		bottom = maxf(bottom, b.get_global_rect().end.y)
	var vp := get_viewport().get_visible_rect().size
	_check(bottom <= vp.y - 20.0, "the bottom buttons keep a margin to the screen edge (%.0f of %.0f)" % [bottom, vp.y])
	for col in fin.columns:
		_check(col.get_global_rect().end.y <= vp.y - 60.0, "column fits above the bottom bar")

	# the big city view
	var col = fin.columns[0]
	_click_at(col.mat.get_global_rect().get_center())
	await _wait(0.9)
	var city = null
	for c in fin.overlays.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with("city_timeline_overlay.gd"):
			city = c
	_check(city != null, "clicking a city opens the big view")
	if city != null:
		await _snap("3_city_early")
		await _wait(1.2)
		await _snap("4_city_mid")
		await _until_idle(city)
		_check(city._logical == city._last and not city._busy, "the story plays through to the last round")
		_check(city._same_cells(city._shown, fin.gs.players[0].cells), "the last round shows the finished city")
		await _snap("5_city_end")
		city._go_to(3)
		await _wait(0.5)
		await _snap("6_back_to_3_midway")
		await _until_idle(city)
		_check(city._same_cells(city._shown, fin.gs.city_history[0][2]["cells"]), "going back to round 3 shows the city as round 3 ended")
		city._go_to(8)
		await _wait(0.3)
		city._go_to(1)
		await _until_idle(city)
		_check(city._same_cells(city._shown, fin.gs.city_history[0][0]["cells"]), "a move interrupted by another lands on the new round")
		await _snap("7_round_1")
		city._close()
		await _wait(0.5)
	# the card grid
	for c in fin.columns:
		c.inspectable = true
	fin.show_cards(0)
	await _wait(1.0)
	await _snap("8_cards_grid")
	print("FINAL probe done, %d failure(s)" % _failures.size())
	for f in _failures:
		print("FINAL   - ", f)
	get_tree().quit(1 if not _failures.is_empty() else 0)
