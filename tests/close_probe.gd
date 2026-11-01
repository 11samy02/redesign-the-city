extends Node
## Opens the big card view and the hidden circumstance card on a real window and closes each one with
## real mouse clicks: once by clicking the dimmed backdrop, once by clicking the X in the corner.
## Optionally saves a screenshot of each: --shots=<dir>. Exit code 1 on failure. Started by the Game autoload:
##   godot --path . --resolution 1600x900 -- --probe=close [--shots=<dir>]

const CardView = preload("res://scripts/game/overlays/card_view.gd")
const CircumstanceCard = preload("res://scripts/game/overlays/circumstance_card.gd")

var _failures: Array[String] = []
var _shots := ""
var _closed := false


func _ready() -> void:
	Sfx.muted = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots = a.substr(8)
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
	_run.call_deferred()


func _run() -> void:
	await _case("card view, click outside", func(): return CardView.new("healthy_city"), "closed", false, 1.2)
	await _case("card view, click X", func(): return CardView.new("healthy_city"), "closed", true, 1.2)
	await _case("hidden card, click outside", func(): return CircumstanceCard.new(null, {"id": "smog_alert", "round": 1}, true), "dismissed", false, 1.2)
	await _case("hidden card, click X", func(): return CircumstanceCard.new(null, {"id": "smog_alert", "round": 1}, true), "dismissed", true, 1.2)
	print("CLOSE probe done: %d failure(s)" % _failures.size())
	for f in _failures:
		print("CLOSE   - %s" % f)
	get_tree().quit(1 if not _failures.is_empty() else 0)


## Opens the overlay, waits `settle` seconds, then clicks the X or an empty corner of the backdrop.
func _case(label: String, make: Callable, done_signal: String, click_x: bool, settle: float) -> void:
	var overlay: Control = make.call()
	_closed = false
	overlay.connect(done_signal, func(): _closed = true)
	get_tree().root.add_child(overlay)
	await get_tree().create_timer(settle).timeout
	if _shots != "" and click_x:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots, label.replace(", ", "_").replace(" ", "_")])
	var target := Vector2(30, 30)
	if click_x:
		var buttons := overlay.find_children("*", "Button", true, false)
		if buttons.is_empty():
			_fail(label, "no X button found")
			overlay.queue_free()
			return
		var x: Button = buttons[0]
		if not x.is_visible_in_tree():
			_fail(label, "the X is not visible")
		target = x.get_global_rect().get_center()
	_click_at(target)
	await get_tree().create_timer(0.8).timeout
	if not _closed:
		_fail(label, "the card did not close")
	if is_instance_valid(overlay):
		overlay.queue_free()
	print("CLOSE %-28s %s" % [label, "ok" if _closed else "FAIL"])


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


func _fail(label: String, msg: String) -> void:
	_failures.append("%s: %s" % [label, msg])
	print("CLOSE FAIL %s: %s" % [label, msg])
