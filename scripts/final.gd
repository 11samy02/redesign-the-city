extends Control
## Final scoring: counts each city visually, then shows the scoreboard and the
## end-of-game reflection. The columns and overlays live in scripts/final/.

const GameState = preload("res://scripts/core/game_state.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Tooltip = preload("res://scripts/ui/tooltip.gd")
const FinalColumn = preload("res://scripts/final/final_column.gd")
const ScoreboardOverlay = preload("res://scripts/final/scoreboard_overlay.gd")
const ReflectionOverlay = preload("res://scripts/final/reflection_overlay.gd")
const DemoGame = preload("res://scripts/final/demo_game.gd")
const CardHistoryOverlay = preload("res://scripts/final/card_history_overlay.gd")

var gs: GameState
## One scoring result per player, in seat order.
var results: Array = []
var columns: Array[FinalColumn] = []
## Pace of the counting: 1.0 normal, 0.0 skips all waiting and effects.
var speed := 1.0
var fx: Control
var overlays: Control
var tooltip: Tooltip
var scoreboard: ScoreboardOverlay
var reflection: ReflectionOverlay

var _skip_btn: Button
## Slim bar under the cities while the player looks at them without the results card in the way.
var _dock: PanelContainer


func _ready() -> void:
	theme = Game.theme
	if Game.state == null:
		DemoGame.play_random()
	gs = Game.state
	for i in gs.players.size():
		results.append(gs.score(i))
	_build()
	_count_all()


## Waits `seconds` at the current pace; returns at once when counting was skipped.
func wait(seconds: float) -> void:
	if speed <= 0.0:
		return
	await get_tree().create_timer(seconds * speed).timeout


## mode: "results", "cities" (a clear view of the cities) or "reflect".
func goto(mode: String) -> void:
	tooltip.hide_tip()
	if mode == "reflect" and reflection == null:
		reflection = ReflectionOverlay.new(gs, results, tooltip)
		reflection.back_pressed.connect(func(): goto("results"))
		reflection.cities_pressed.connect(func(): goto("cities"))
		overlays.add_child(reflection)
	if scoreboard != null:
		scoreboard.visible = mode == "results"
	if _dock != null:
		_dock.visible = mode == "cities"
	if reflection != null:
		reflection.visible = mode == "reflect"
	if mode != "results":
		Sfx.play("whoosh")


# ================================================================ layout

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# created first: the columns show tile tooltips through it
	tooltip = Tooltip.new()
	tooltip.theme = Game.theme
	var bg := Widgets.Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	margin.add_child(v)
	v.add_child(_build_head())
	v.add_child(_build_columns())
	_dock = _build_dock()
	v.add_child(_dock)

	fx = _add_layer(5)
	overlays = _add_layer(8)
	var tip_layer := CanvasLayer.new()
	tip_layer.layer = 10
	add_child(tip_layer)
	tip_layer.add_child(tooltip)


func _add_layer(layer: int) -> Control:
	var canvas := CanvasLayer.new()
	canvas.layer = layer
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.theme
	canvas.add_child(root)
	return root


func _build_head() -> Control:
	var head := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.add_child(UiKit.label("Final scoring", 48, UiKit.LIMESTONE, "display_bold"))
	titles.add_child(UiKit.label("Every citizen scores their happiness. Every loan costs points, and each one costs more than the last.", 18, UiKit.MUTED))
	head.add_child(titles)
	head.add_child(UiKit.spacer())
	_skip_btn = UiKit.button("Skip counting", "ghost", 18)
	_skip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skip_btn.pressed.connect(func(): speed = 0.0)
	head.add_child(_skip_btn)
	return head


func _build_columns() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var n := gs.players.size()
	var cell := 38.0  # the same for every player count: the footer buttons must stay on screen
	for i in n:
		var col := FinalColumn.new(gs.players[i], results[i], cell, tooltip)
		col.cards_pressed.connect(show_cards.bind(i))
		columns.append(col)
		row.add_child(col)
	return row


func _build_dock() -> PanelContainer:
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 20, 2, UiKit.LINE, 12))
	dock.visible = false
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	dock.add_child(h)
	var hint := UiKit.label("Hover any home to see why it scores what it does.", 18, UiKit.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(hint)
	var back := UiKit.button("Back to results", "primary", 20)
	back.pressed.connect(func(): goto("results"))
	h.add_child(back)
	var reflect := UiKit.button("Name the one change", "secondary", 20)
	reflect.pressed.connect(func(): goto("reflect"))
	h.add_child(reflect)
	var again := UiKit.button("Play again", "ghost", 20)
	again.pressed.connect(_play_again)
	h.add_child(again)
	var menu := UiKit.button("Main menu", "ghost", 20)
	menu.pressed.connect(_to_menu)
	h.add_child(menu)
	return dock


# ================================================================ flow

func _count_all() -> void:
	for c in columns:
		c.modulate.a = 0.0
	await get_tree().process_frame
	for k in columns.size():
		_slide_in(columns[k], k)
	await wait(0.8)
	for c in columns:
		await c.count(self)
		await wait(0.4)
	for c in columns:
		c.inspectable = true
	_skip_btn.visible = false
	await wait(0.5)
	_show_scoreboard()


func _slide_in(column: Control, k: int) -> void:
	var tw := create_tween().set_parallel()
	var y := column.position.y
	column.position.y = y + 40
	tw.tween_property(column, "modulate:a", 1.0, 0.35).set_delay(k * 0.12)
	tw.tween_property(column, "position:y", y, 0.5).set_delay(k * 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_scoreboard() -> void:
	scoreboard = ScoreboardOverlay.new(self)
	var ranks := scoreboard.ranks()
	for i in columns.size():
		columns[i].rank_label.text = ScoreboardOverlay.ordinal(ranks[i])
	scoreboard.reflect_pressed.connect(func(): goto("reflect"))
	scoreboard.cities_pressed.connect(func(): goto("cities"))
	scoreboard.again_pressed.connect(_play_again)
	scoreboard.menu_pressed.connect(_to_menu)
	scoreboard.cards_pressed.connect(show_cards)
	overlays.add_child(scoreboard)


## Opens the list of cards planner `index` drew, on top of whatever is showing.
func show_cards(index: int) -> void:
	tooltip.hide_tip()
	Sfx.play("click")
	overlays.add_child(CardHistoryOverlay.new(gs, index))


func _play_again() -> void:
	Game.new_game()
	Game.goto(Game.GAME_SCENE)


func _to_menu() -> void:
	Game.goto(Game.TITLE_SCENE)
