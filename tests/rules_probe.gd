extends Node
## The How to play panel: every page opens without errors and the card pages fill with real cards.
##   godot --path . --resolution 1600x900 -- --probe=rules --out=<dir>
## Exit code 1 when a check fails.

const RulesPanel = preload("res://scripts/ui/rules_panel.gd")

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
	print("RULES %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _run() -> void:
	await _wait(1.0)
	var layer := CanvasLayer.new()
	add_child(layer)
	var rp := RulesPanel.new()
	layer.add_child(rp)
	await _wait(0.6)
	for i in RulesPanel.TABS.size():
		rp._show_tab(i)
		await _wait(0.5 if i != 6 and i != 7 else 2.5)
		await _snap("tab_%d" % i)
		_check(not rp.find_children("*", "Label", true, false).any(func(l): return "[b]" in l.text or "[/b]" in l.text), "page %d: no stray [b] tags" % i)
		if i == 6 or i == 7:
			var grids: Array = rp.find_children("*", "GridContainer", true, false).filter(func(g): return g.columns == RulesPanel.CARD_COLUMNS)
			var cards := 0
			for g in grids:
				cards += g.get_child_count()
			_check(cards > 20, "page %d shows its cards (%d)" % [i, cards])
	rp._show_tab(3)
	await _wait(0.5)
	rp._scroll.scroll_vertical = 900
	await _wait(0.3)
	await _snap("tab_3_scrolled")
	rp._show_tab(2)
	await _wait(0.5)
	rp._scroll.scroll_vertical = 300
	await _wait(0.3)
	await _snap("tab_2_scrolled")
	_check(not rp.find_children("*", "Label", true, false).any(func(l): return "[b]" in l.text or "[/b]" in l.text), "no stray [b] tags show on any page")
	rp._show_tab(6)
	await _wait(2.5)
	rp._scroll.scroll_vertical = 700
	await _wait(0.3)
	await _snap("tab_6_scrolled")
	rp._open_zoom(CardDefs_first(), "turn")
	await _wait(0.5)
	await _snap("zoom")
	_check(rp._zoom != null, "a card opens big")
	rp._close_zoom()
	_check(rp._zoom == null, "and closes again")
	print("RULES probe done, %d failure(s)" % _failures.size())
	get_tree().quit(1 if not _failures.is_empty() else 0)


func CardDefs_first() -> String:
	return load("res://scripts/core/card_defs.gd").ids("event")[0]
