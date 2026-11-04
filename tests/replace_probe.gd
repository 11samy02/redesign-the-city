extends Node
## Shows what picking a 1:1 shop tile and pointing at a 2:2 tile of your own looks like (screenshot to --out=).
##   godot --path . --resolution 1600x900 -- --probe=replace --out=<file.png>
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Grid = preload("res://scripts/core/grid.gd")
var _scene: Control
var _started := false


func _ready() -> void:
	Sfx.muted = true
	Game.seats = [{"name": "Player 1", "color": 0, "bot": 0}, {"name": "Nikos", "color": 1, "bot": 1}, {"name": "Eleni", "color": 2, "bot": 2}, {"name": "Maria", "color": 3, "bot": 3}]
	Game.new_game()
	_scene = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_scene)


func _process(_d: float) -> void:
	if _scene == null or not _scene.is_inside_tree() or _started:
		return
	if _scene.circumstance_open or _scene.handoff_open or _scene.turn_card_open:
		for b in _scene.find_children("*", "Button", true, false):
			if b.visible and not b.disabled:
				b.pressed.emit()
				break
	elif not _scene.busy and _scene.modal_count == 0 and not _scene.bot_active and not _scene.current_is_bot():
		_started = true
		_run()


func _run() -> void:
	var gs = _scene.gs
	var p = gs.current_player()
	p.money = 200
	var big := -1
	var small := -1
	for k in gs.shop.size():
		var n := TileDefs.footprint(gs.shop[k]["tile"])
		if n == 2 and big < 0:
			big = k
		elif n == 1 and small < 0 and big >= 0 and gs.shop[k]["tile"]["kind"] != TileDefs.Kind.ROAD:
			small = k
	if big < 0 or small < 0:
		for k in gs.shop.size():
			print("shop ", k, " ", TileDefs.footprint(gs.shop[k]["tile"]), " ", gs.shop[k]["tile"]["kind"])
	var anchor := 6 * 14 + 6
	Grid.place(p.cells, anchor, gs.shop[big]["tile"].duplicate())
	_scene.refresh_all()
	for i in 10:
		await get_tree().process_frame
	_scene._on_slot_pressed(small) if _scene.has_method("_on_slot_pressed") else _scene.set_hand({"type": "shop", "slot": small})
	for i in 20:
		await get_tree().process_frame
	# the real mouse cannot be moved from here, so point at the bottom-right square of the big tile directly
	_scene.focus_cell(anchor + 15)
	print("GHOST0 ", _scene.mat_view._ghost_anchor, " old ", _scene.mat_view._ghost_replaced_at, " n ", _scene.mat_view._ghost_replaced_n)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].substr(6))
	get_tree().quit()
	return
	for i in 40:
		await get_tree().process_frame
	var out := "replace.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	print("GHOST ", _scene.mat_view._ghost_anchor, " old ", _scene.mat_view._ghost_replaced_at, " n ", _scene.mat_view._ghost_replaced_n, " hover ", _scene.hover_cell)
	print("replace_anchor ", gs.replace_anchor(small, anchor + 15), " pointed ", _scene._pointed_square)
	print("can_replace ", gs.can_replace(small, anchor), " hand ", _scene.hand)
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
