extends SceneTree
## How long a bot takes to plan its first turn on the 14x14 mat, per level and prefixed mat:
##   godot --headless --path . --script res://tests/bot_speed.gd
const GameState = preload("res://scripts/core/game_state.gd")
const Bot = preload("res://scripts/core/bot.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const SampleMats = preload("res://tests/sample_mats.gd")


func _initialize() -> void:
	for mat in SampleMats.all():
		for level in [Bot.MEDIUM, Bot.HARD]:
			var gs := GameState.new()
			gs.setup(["A", "B"], [0, 1], 3, [level, level], mat)
			var rng := RandomNumberGenerator.new()
			rng.seed = 1
			var t := Time.get_ticks_msec()
			Bot.think(gs, level, rng)
			var think := Time.get_ticks_msec() - t
			t = Time.get_ticks_msec()
			for i in 200:
				Scoring.evaluate(gs.players[0].cells, 0)
			print("%s level %d: first plan %d ms, one score %.2f ms" % [mat.title, level, think, (Time.get_ticks_msec() - t) / 200.0])
	quit()
