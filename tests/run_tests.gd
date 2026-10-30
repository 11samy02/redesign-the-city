extends SceneTree
## Headless test runner.
## Run: godot --headless --path . --script res://tests/run_tests.gd

const SUITES := [
	"res://tests/test_scoring.gd",
	"res://tests/test_game_state.gd",
	"res://tests/test_bot.gd",
	"res://tests/test_keyboard_nav.gd",
]


func _init() -> void:
	var total := 0
	var failed := 0
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("  FAIL  could not load %s" % path)
			failed += 1
			continue
		var suite: Object = script.new()
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			suite.failures.clear()
			suite.call(name)
			if suite.failures.is_empty():
				print("  PASS  %s" % name)
			else:
				failed += 1
				print("  FAIL  %s" % name)
				for f in suite.failures:
					print("        - %s" % f)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
