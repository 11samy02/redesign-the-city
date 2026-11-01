extends Node
## Checks the gold indicators in the turn order panel on the real game screen: after a "Tourist tax"
## style payment (+6 for one planner, -2 for each of the others) every planner gets a floating green or
## red number, the gold rolls to its new value and the colour goes back to gold. Optionally saves a
## screenshot: --shots=<dir>. Exit code 1 on failure. Started by the Game autoload:
##   godot --path . --resolution 1600x900 -- --probe=gold [--shots=<dir>]

var _scene: Control
var _failures: Array[String] = []


func _ready() -> void:
	Sfx.muted = true
	Game.seats = [
		{"name": "Player 1", "color": 0, "bot": 0},
		{"name": "Nikos", "color": 1, "bot": 0},
		{"name": "Eleni", "color": 2, "bot": 0},
		{"name": "Maria", "color": 3, "bot": 0},
	]
	Game.new_game()
	_scene = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_scene)
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print("GOLD %-4s %s" % ["ok" if ok else "FAIL", msg])
	if not ok:
		_failures.append(msg)


func _floating_texts() -> Array[String]:
	var out: Array[String] = []
	for c in _scene.fx.get_children():
		if c is Label and c.text.length() > 0 and (c.text.begins_with("+") or c.text.begins_with("-")):
			out.append(c.text)
	return out


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	_scene.overlays.visible = false
	var gs = _scene.gs
	var before: Array = _scene._gold_snapshot()
	var gain := 6
	gs.players[0].money += gain
	for i in range(1, 4):
		gs.players[i].money -= 2
	_scene.refresh_all()
	_scene._order_panel.show_gold_changes(before, _scene.fx)
	await get_tree().create_timer(0.7).timeout
	var texts := _floating_texts()
	texts.sort()
	_check(texts == ["+6", "-2", "-2", "-2"], "one green +6 and three red -2 float up (got %s)" % str(texts))
	for out in OS.get_cmdline_user_args():
		if out.begins_with("--shots="):
			DirAccess.make_dir_recursive_absolute(out.substr(8))
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/gold_changes.png" % out.substr(8))
	await get_tree().create_timer(3.0).timeout
	for i in 4:
		var label: Label = _scene._order_panel._refs[i]["money"]
		_check(label.text == str(gs.players[i].money), "planner %d shows %d gold (shows %s)" % [i + 1, gs.players[i].money, label.text])
		_check(label.get_theme_color("font_color") == Color("#F2B630"), "planner %d's gold is back to gold" % [i + 1])
	_check(_floating_texts().is_empty(), "the floating numbers are gone")
	# no change, no animation
	_scene._order_panel.show_gold_changes(_scene._gold_snapshot(), _scene.fx)
	await get_tree().create_timer(0.3).timeout
	_check(_floating_texts().is_empty(), "nothing floats when nobody's gold changed")
	print("GOLD probe done: %d failure(s)" % _failures.size())
	get_tree().quit(1 if not _failures.is_empty() else 0)
