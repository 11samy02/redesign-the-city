extends Control
## One planner's city, big, with the story of how it grew. A timeline runs under it (the start, then
## every round): click a round and the tiles fly in, or out, to get there: from round 1 to round 8 every
## tile placed in between lands one after the other, from 8 back to 4 they leave again, newest first.
## The score on the side counts along with the tiles. Hover a tile to see what it does at that moment.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const MatView = preload("res://scripts/ui/mat_view.gd")
const Tooltip = preload("res://scripts/ui/tooltip.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const Grid = preload("res://scripts/core/grid.gd")
const Influence = preload("res://scripts/game/influence.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")
const Roles = preload("res://scripts/core/roles.gd")

signal closed

## All the tiles of one move together take about this long, however many there are.
const MOVE_SECONDS := 2.4
const MIN_TILE_DELAY := 0.03
const MAX_TILE_DELAY := 0.22

var _gs
var _index: int
var _player
var _tooltip: Tooltip
## Round 0 (the empty mat), then the city as every round ended: {"cells", "loans", "card_points", "money"}.
var _snaps: Array = []
var _last := 0
## The round the city is heading for (or resting at), and the lots as they are drawn right now.
var _logical := 0
var _shown: Array = []
var _result: Dictionary = {}
var _gen := 0
var _busy := false
var _done := false
var _prog_tween: Tween

var _mat: MatView
var _timeline: Timeline
var _play: Button
var _round_label: Label
var _score: Label
var _gold: Label
var _stats := {}
var _sound_tick := 0


## `index` is the planner's seat; `tooltip` is the screen's, so tile tips show above everything.
func _init(gs, index: int, tooltip: Tooltip) -> void:
	_gs = gs
	_index = index
	_player = gs.players[index]
	_tooltip = tooltip
	var start: Array = []
	start.resize(gs.MAT_CELLS)
	_snaps.append({"cells": start, "loans": 0, "card_points": 0, "money": gs.START_MONEY})
	_snaps.append_array(gs.city_history[index])
	if _snaps.size() == 1 or _snaps[_snaps.size() - 1]["cells"] != _player.cells:
		# a game that was not played through end_turn: the finished city is the only round we know
		_snaps.append({"cells": _player.cells.duplicate(true), "loans": _player.loans, "card_points": _player.card_points, "money": _player.money})
	_last = _snaps.size() - 1
	_shown = start.duplicate()


func _ready() -> void:
	var dim := OverlayKit.fill_dimmed(self, 0.9)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())
	var col := UiKit.player_color(_player.color_index)
	var card := OverlayKit.add_card(self, OverlayKit.planner_card_style(col, 26, 26, 8, 40))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 26)
	v.add_child(top)
	_mat = MatView.new()
	var gap := 2
	var cell := mini(104, int((get_viewport_rect().size.y - 300.0 - gap * (Scoring.SIZE - 1)) / Scoring.SIZE))
	_mat.setup(cell, gap, TileView.Mode.MAT)
	_mat.cell_hovered.connect(_on_cell_hovered)
	top.add_child(_mat)
	top.add_child(_build_side(col))
	v.add_child(_build_timeline(col))
	_show_round_label(0)
	_apply(0)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	Sfx.play("whoosh")
	# the city grows from nothing to the end, once, as soon as the view opens
	await get_tree().create_timer(0.55).timeout
	if not _done and _gen == 0:
		_go_to(_last)


# ================================================================ layout

func _build_side(col: Color) -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 330
	side.add_theme_constant_override("separation", 12)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var av := Widgets.Avatar.new(56)
	av.color = col
	av.letter = _player.name.substr(0, 1).to_upper()
	head.add_child(av)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UiKit.label(_player.name, 30, col.lightened(0.25), "display_bold"))
	_round_label = UiKit.label("", 18, UiKit.MUTED, "body_bold")
	names.add_child(_round_label)
	head.add_child(names)
	side.add_child(head)

	var score_row := HBoxContainer.new()
	score_row.add_child(UiKit.label("Score", 20, UiKit.MUTED, "display_bold"))
	score_row.add_child(UiKit.spacer())
	_score = UiKit.label("0", 64, UiKit.LIMESTONE, "display_bold")
	score_row.add_child(_score)
	side.add_child(score_row)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for key in [["happy", "Happy"], ["pollution", "Pollution"], ["loans", "Loans"], ["unused", "Unused"], ["variety", "Variety"], ["cards", "Cards"]]:
		_stats[key[0]] = _stat(grid, key[1])
	side.add_child(grid)

	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	gold_row.add_child(UiKit.icon("res://assets/ui/coin.svg", 26))
	_gold = UiKit.label("", 22, UiKit.GOLD, "display_bold")
	gold_row.add_child(_gold)
	gold_row.add_child(UiKit.label("gold left", 17, UiKit.MUTED))
	side.add_child(gold_row)

	side.add_child(UiKit.spacer(true))
	side.add_child(UiKit.label("Click a round to jump to it. Hover a tile to see what it does.", 15, UiKit.MUTED))
	var close := UiKit.button("Close", "primary", 20)
	close.pressed.connect(_close)
	side.add_child(close)
	return side


func _stat(parent: Control, caption: String) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL_HI, 0.7), 14, 0, Color.TRANSPARENT, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	panel.add_child(box)
	var cap := UiKit.label(caption, 13, UiKit.MUTED, "body_bold")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	var value := UiKit.label("", 26, UiKit.LIMESTONE, "display_bold")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	parent.add_child(panel)
	return value


func _build_timeline(col: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_play = UiKit.button("Play", "secondary", 20)
	_play.custom_minimum_size.x = 120
	_play.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_play.pressed.connect(_on_play)
	row.add_child(_play)
	_timeline = Timeline.new()
	_timeline.accent = col
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.node_count = _last + 1
	for k in _last + 1:
		var r := _evaluate(_snaps[k]["cells"], k)
		_timeline.scores.append(r["total"])
	_timeline.picked.connect(func(r: int):
		Sfx.play("click")
		_go_to(r))
	row.add_child(_timeline)
	return row


# ================================================================ showing a state

func _evaluate(cells: Array, round_k: int) -> Dictionary:
	var snap: Dictionary = _snaps[round_k]
	return Scoring.evaluate(cells, snap["loans"], _gs.revealed.slice(0, mini(round_k, _gs.revealed.size())), snap["card_points"])


## Draws `_shown` with the loans, card points and hidden cards of round `round_k` and updates the side.
func _apply(round_k: int) -> void:
	_result = _evaluate(_shown, round_k)
	_mat.refresh(_shown, _result)
	var r := _result
	_set_stat("happy", "%d/%d" % [r["happy_citizens"], r["citizens"]], 0 if r["citizens"] == 0 else (1 if r["unhappy_citizens"] == 0 else -1))
	_set_stat("pollution", str(r["pollution"]), -1 if r["pollution_penalty"] > 0 else 0)
	_set_stat("loans", "-%d" % r["loan_penalty"] if r["loans"] > 0 else "0", -1 if r["loans"] > 0 else 0)
	_set_stat("unused", "-%d" % r["unused_penalty"] if r["unused_penalty"] > 0 else "0", -1 if r["unused_penalty"] > 0 else 0)
	_set_stat("variety", Describe.signed(r["variety_bonus"]) if r["variety_bonus"] > 0 else "0", 1 if r["variety_bonus"] > 0 else 0)
	_set_stat("cards", Describe.signed(r["card_points"]) if r["card_points"] != 0 else "0", signi(r["card_points"]))
	var total: int = r["total"]
	_score.text = Describe.signed(total) if total != 0 else "0"
	_score.add_theme_color_override("font_color", UiKit.OLIVE if total > 0 else (UiKit.HEAT if total < 0 else UiKit.LIMESTONE))
	_gold.text = str(_snaps[round_k]["money"])


func _set_stat(key: String, text: String, effect: int) -> void:
	var l: Label = _stats[key]
	l.text = text
	l.add_theme_color_override("font_color", UiKit.OLIVE if effect > 0 else (UiKit.HEAT if effect < 0 else UiKit.MUTED))


func _show_round_label(k: int) -> void:
	_round_label.text = "Before the first round" if k == 0 else "After round %d of %d" % [k, _last]
	_timeline.current = k


func _on_cell_hovered(c: int, inside: bool) -> void:
	if inside and _shown[c] != null:
		Influence.show_for(_mat, _shown, _result, c)
		_tooltip.show_tile(_shown[c], _mat.cell_global_rect(c), Describe.cell_lines(_shown, _result, c), false, MatView.road_mask(_shown, c))
	else:
		_mat.clear_highlights()
		_tooltip.hide_tip()


# ================================================================ the animation

func _on_play() -> void:
	if _busy:
		_stop()
		return
	if _logical >= _last and _same_cells(_shown, _snaps[_last]["cells"]):
		# at the end already: start the story again from the empty mat
		_gen += 1
		_shown = _snaps[0]["cells"].duplicate()
		_logical = 0
		_timeline.progress = 0.0
		_show_round_label(0)
		_apply(0)
	_go_to(_last)


func _stop() -> void:
	_gen += 1
	if _prog_tween != null and _prog_tween.is_valid():
		_prog_tween.kill()
	_set_busy(false)


func _set_busy(on: bool) -> void:
	_busy = on
	_play.text = "Pause" if on else ("Replay" if _logical >= _last else "Play")


static func _same_cells(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


## The lots whose tile differs between two cities, by the top-left square of the tile: the other squares of
## a 2:2 tile follow it (see _land).
static func _changed(a: Array, b: Array) -> Array[int]:
	var out: Array[int] = []
	for i in a.size():
		if a[i] != b[i] and ((a[i] != null and not a[i].has("part")) or (b[i] != null and not b[i].has("part"))):
			out.append(i)
	return out


## Puts the tile of `snapshot` that has its top-left square on `c` into the city on show, with all its squares
## (or empties the lot of the tile that stood there).
static func _land(shown: Array, snapshot: Array, c: int) -> void:
	var old = shown[c]
	if old != null and not old.has("part"):
		for sq in Grid.squares_of(shown, c):
			shown[sq] = null
	shown[c] = snapshot[c]
	var tile = snapshot[c]
	if tile != null and not tile.has("part"):
		for sq in Grid.squares_of(snapshot, c):
			shown[sq] = snapshot[sq]


## Moves the city to how it stood when round `target` ended. Going forward the tiles of every round in
## between land in turn; going back they leave again, the newest first. Calling this again halts the
## move in progress and carries on from wherever the city has got to.
func _go_to(target: int) -> void:
	target = clampi(target, 0, _last)
	_gen += 1
	var gen := _gen
	if _prog_tween != null and _prog_tween.is_valid():
		_prog_tween.kill()
	var direction := 1 if target >= _logical else -1
	var steps: Array[int] = []
	if target == _logical:
		steps.append(target)
	else:
		for k in range(_logical + direction, target + direction, direction):
			steps.append(k)
	var nothing_to_do := _same_cells(_shown, _snaps[target]["cells"]) and target == _logical
	if nothing_to_do:
		_set_busy(false)
		return
	# the pace follows the number of tiles that have to move
	var sim := _shown.duplicate()
	var total := 0
	for k in steps:
		total += _changed(sim, _snaps[k]["cells"]).size()
		sim = _snaps[k]["cells"]
	var delay := clampf(MOVE_SECONDS / maxf(total, 1.0), MIN_TILE_DELAY, MAX_TILE_DELAY)
	_set_busy(true)
	_sound_tick = 0
	for k in steps:
		_logical = k
		_show_round_label(k)
		var tiles := _changed(_shown, _snaps[k]["cells"])
		if direction < 0:
			tiles.reverse()
		_prog_tween = create_tween()
		_prog_tween.tween_property(_timeline, "progress", float(k), maxf(tiles.size() * delay, 0.18)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		for c in tiles:
			var tile = _snaps[k]["cells"][c]
			var spent := 0.0
			if _shown[c] != null and not _shown[c].has("part"):
				spent = minf(0.09, delay)
				await _vanish(c, tile == null, spent, delay)
				if gen != _gen:
					return
			_land(_shown, _snaps[k]["cells"], c)
			_apply(k)
			if tile != null and not tile.has("part"):
				_appear(c, delay)
			await get_tree().create_timer(maxf(delay - spent, 0.001)).timeout
			if gen != _gen:
				return
		_apply(k)
		if steps.size() > 1:
			await get_tree().create_timer(0.1).timeout
			if gen != _gen:
				return
	_timeline.progress = float(target)
	_set_busy(false)
	_pop_score()


## A tile shrinks away (and the lot is drawn empty by the caller right after).
func _vanish(c: int, leaving_for_good: bool, seconds: float, delay: float) -> void:
	var view = _mat.views[c]
	if leaving_for_good:
		_tick_sound("pop", 0.8, delay)
	var tw := create_tween()
	tw.tween_property(view, "anim_scale", 0.0, seconds)
	await tw.finished
	view.anim_scale = 1.0


## A tile lands: it grows from small with a little bounce.
func _appear(c: int, delay: float) -> void:
	var view = _mat.views[c]
	_tick_sound("place", 0.9 + 0.2 * float(_logical) / maxf(_last, 1.0), delay)
	var tw := create_tween()
	tw.tween_property(view, "anim_scale", 1.0, 0.3).from(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A fast move would turn a sound per tile into a buzz: every other tile (or third) makes one.
func _tick_sound(sound: String, pitch: float, delay: float) -> void:
	_sound_tick += 1
	var every := 1 if delay >= 0.1 else (2 if delay >= 0.05 else 3)
	if _sound_tick % every == 0:
		Sfx.play(sound, pitch)


func _pop_score() -> void:
	_score.pivot_offset = _score.size / 2.0
	var tw := create_tween()
	tw.tween_property(_score, "scale", Vector2.ONE * 1.12, 0.08)
	tw.tween_property(_score, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


# ================================================================ input and closing

func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			_close()
		KEY_LEFT:
			_go_to(_logical - 1 if _logical > 0 else 0)
		KEY_RIGHT:
			_go_to(_logical + 1)
		KEY_HOME:
			_go_to(0)
		KEY_END:
			_go_to(_last)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_on_play()
		_:
			return
	get_viewport().set_input_as_handled()


func _close() -> void:
	if _done:
		return
	_done = true
	_gen += 1
	_tooltip.hide_tip()
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.15)
	await out.finished
	closed.emit()
	queue_free()


## The line of rounds: a dot for the empty start and one for every round, with the score of the city at
## that moment under it. A gold bar fills as the city moves through time; click a dot to go there.
class Timeline extends Control:
	signal picked(round: int)

	const SIDE := 36.0
	const TRACK_Y := 22.0

	var node_count := 2
	var scores: Array[int] = []
	var accent := Color.WHITE
	var current := 0:
		set(v):
			current = v
			queue_redraw()
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()
	var _hover := -1

	func _init() -> void:
		custom_minimum_size = Vector2(300, 76)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _x(i: int) -> float:
		return SIDE + float(i) * (size.x - 2.0 * SIDE) / maxf(node_count - 1, 1)

	func _node_at(pos: Vector2) -> int:
		if pos.y > 70.0:
			return -1
		var best := -1
		var best_d := 30.0
		for i in node_count:
			var d := absf(pos.x - _x(i))
			if d < best_d:
				best_d = d
				best = i
		return best

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var h := _node_at(event.position)
			if h != _hover:
				_hover = h
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var n := _node_at(event.position)
			if n >= 0:
				picked.emit(n)
				accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_hover = -1
			queue_redraw()

	func _draw() -> void:
		var font := UiKit.font("display_bold")
		var x0 := _x(0)
		var x1 := _x(node_count - 1)
		draw_line(Vector2(x0, TRACK_Y), Vector2(x1, TRACK_Y), Color(UiKit.LINE, 0.9), 8.0, true)
		var fill_to := x0 + (x1 - x0) * clampf(progress / maxf(node_count - 1, 1), 0.0, 1.0)
		if fill_to > x0:
			draw_line(Vector2(x0, TRACK_Y), Vector2(fill_to, TRACK_Y), accent, 8.0, true)
		for i in node_count:
			var c := Vector2(_x(i), TRACK_Y)
			var reached := float(i) <= progress + 0.001
			var is_now := i == current
			var r := 17.0 if is_now else (15.0 if i == _hover else 13.0)
			if is_now:
				draw_circle(c, r + 6.0, Color(UiKit.GOLD, 0.25), true, -1.0, true)
			draw_circle(c, r, UiKit.GOLD if is_now else (accent if reached else UiKit.PANEL_HI), true, -1.0, true)
			draw_arc(c, r, 0.0, TAU, 32, UiKit.GOLD if is_now else (UiKit.LIMESTONE if reached else UiKit.LINE), 2.5, true)
			var label := "0" if i == 0 else str(i)
			var fs := 17
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string(font, Vector2(c.x - w / 2.0, c.y + fs * 0.34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK if is_now else UiKit.LIMESTONE)
			if i < scores.size():
				var s := scores[i]
				var text := ("+%d" % s) if s > 0 else str(s)
				var sw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x
				var tint := UiKit.OLIVE if s > 0 else (UiKit.HEAT if s < 0 else UiKit.MUTED)
				draw_string(font, Vector2(c.x - sw / 2.0, TRACK_Y + 44.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, tint if is_now or reached else Color(tint, 0.55))
