extends Node
## Screenshots of the skip box, the scene transition and the card history. Started by the Game autoload:
##   godot --path . -- --probe=shots --out=<dir>

var out := "."


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


func _run() -> void:
	await _wait(2.5)
	await _snap("0_title_after_intro")
	Game.seats = [{"name": "You", "color": 0, "bot": 0}, {"name": "Bea", "color": 1, "bot": 3}, {"name": "Cy", "color": 2, "bot": 3}]
	Game.new_game()
	Game.settings["bot_speed"] = Game.BOT_DELAY.size() - 1
	Game.goto(Game.GAME_SCENE)
	await _wait(0.25)
	await _snap("1_transition_early")
	await _wait(0.3)
	await _snap("2_transition_covered")
	await _wait(0.9)
	await _snap("3_game_revealed")
	var game = get_tree().current_scene
	# dismiss the round card, then end the human turn quickly so the bots start
	for k in 20:
		await _wait(0.5)
		if game.circumstance_open:
			Input.parse_input_event(_enter())
		elif game.handoff_open:
			for b in game.overlays.find_children("*", "Button", true, false):
				if b.is_visible_in_tree() and not b.disabled:
					b.pressed.emit()
					break
		elif game.turn_card_open:
			Input.parse_input_event(_enter())
		elif game.bot_active:
			break
		elif not game.busy and game.modal_count == 0 and not game.current_is_bot():
			var gs = game.gs
			var rng := RandomNumberGenerator.new()
			rng.seed = 3
			while gs.buys_left() > 0:
				if gs.can_take_loan():
					gs.take_loan()
					continue
				var m: Array = load("res://scripts/core/bot.gd").choose_purchase(gs, 1, rng)
				if not gs.buy_and_place(m[0], m[1]):
					break
			game.finish_turn()
	await _wait(0.6)
	await _snap("4_skip_box")
	Game.settings["bot_speed"] = 1
	Game.state = null
	Game.goto(Game.FINAL_SCENE)
	await _wait(3.5)
	var fin = get_tree().current_scene
	for k in 40:
		if fin.scoreboard != null:
			break
		fin.speed = 0.0
		await _wait(0.5)
	await _wait(2.5)
	await _snap("5_results")
	fin.show_cards(0)
	await _wait(0.6)
	await _snap("6_card_history")
	get_tree().quit()


func _enter() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.pressed = true
	return e
