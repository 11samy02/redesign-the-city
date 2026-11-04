extends SceneTree
## Headless test runner.
## Run: godot --headless --path . --script res://tests/run_tests.gd
## A script error inside a test (a crash, a bad index, a division by zero) fails that test too:
## Godot would otherwise just stop the test function and leave it looking green.

const SUITES := [
	"res://tests/test_roles.gd",
	"res://tests/test_tile_defs.gd",
	"res://tests/test_grid.gd",
	"res://tests/test_scoring.gd",
	"res://tests/test_game_state.gd",
	"res://tests/test_circumstances.gd",
	"res://tests/test_deck.gd",
	"res://tests/test_bot.gd",
	"res://tests/test_bot_planner.gd",
	"res://tests/test_keyboard_nav.gd",
	"res://tests/test_shop_layout.gd",
	"res://tests/test_describe.gd",
	"res://tests/test_cards.gd",
]


## Counts the errors Godot reports while a test runs.
class ErrorCounter extends Logger:
	var count := 0
	var last := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
		count += 1
		last = "%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line]


func _init() -> void:
	var total := 0
	var failed := 0
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	# optional filter: -- --only=roles,tile_defs
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	for path in SUITES:
		if not only.is_empty() and not only.any(func(n): return path.ends_with("test_%s.gd" % n)):
			continue
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
			errors.count = 0
			suite.call(name)
			if errors.count > 0:
				suite.failures.append("%d script error(s), the last: %s" % [errors.count, errors.last])
			if suite.failures.is_empty():
				print("  PASS  %s" % name)
			else:
				failed += 1
				print("  FAIL  %s" % name)
				for f in suite.failures:
					print("        - %s" % f)
	print("\n%d tests, %d failed" % [total, failed])
	OS.remove_logger(errors)
	quit(1 if failed > 0 else 0)
