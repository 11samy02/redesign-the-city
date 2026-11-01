extends Control
## In-game screen. This script wires the parts together and runs the turn flow;
## the parts themselves (panels, overlays, effects, bot, keyboard) live in scripts/game/.

const GameState = preload("res://scripts/core/game_state.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const MatView = preload("res://scripts/ui/mat_view.gd")
const ShopView = preload("res://scripts/ui/shop_view.gd")
const Tooltip = preload("res://scripts/ui/tooltip.gd")
const RulesPanel = preload("res://scripts/ui/rules_panel.gd")
const Modal = preload("res://scripts/ui/modal.gd")
const OptionsPanel = preload("res://scripts/ui/options_panel.gd")
const TopBar = preload("res://scripts/game/top_bar.gd")
const ShopPanel = preload("res://scripts/game/shop_panel.gd")
const PlayerBanner = preload("res://scripts/game/player_banner.gd")
const TurnOrderPanel = preload("res://scripts/game/turn_order_panel.gd")
const LastCardPanel = preload("res://scripts/game/last_card_panel.gd")
const CardView = preload("res://scripts/game/overlays/card_view.gd")
const ActionBar = preload("res://scripts/game/action_bar.gd")
const Toast = preload("res://scripts/game/toast.gd")
const TileFx = preload("res://scripts/game/tile_fx.gd")
const Influence = preload("res://scripts/game/influence.gd")
const KeyboardNav = preload("res://scripts/game/keyboard_nav.gd")
const BotDriver = preload("res://scripts/game/bot_driver.gd")
const HandoffOverlay = preload("res://scripts/game/overlays/handoff_overlay.gd")
const CityViewer = preload("res://scripts/game/overlays/city_viewer.gd")
const Banner = preload("res://scripts/game/overlays/banner.gd")
const CircumstanceCard = preload("res://scripts/game/overlays/circumstance_card.gd")
const TurnCard = preload("res://scripts/game/overlays/turn_card.gd")
const DeckPanel = preload("res://scripts/game/deck_panel.gd")
const FastForward = preload("res://scripts/game/overlays/fast_forward.gd")
const CardEffects = preload("res://scripts/core/card_effects.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")

const MAT_CELL := 70.0
const MAT_GAP := 5
const ARROW_KEYS := {KEY_LEFT: Vector2i(-1, 0), KEY_A: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0), KEY_D: Vector2i(1, 0),
	KEY_UP: Vector2i(0, -1), KEY_W: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_S: Vector2i(0, 1)}

var gs: GameState
var result: Dictionary = {}

## What the planner has picked up: {} when empty, {"type": "shop", "slot": i} or {"type": "free"}.
var hand := {}
var busy := false
var modal_count := 0
var turn_bought: Array = []
var hover_cell := -1
## True while a computer planner is taking its turn; locks human input.
var bot_active := false
var handoff_open := false
## True while the round's hidden circumstance card is on screen.
var circumstance_open := false
## True while this turn's coin flip and event or penalty card are on screen.
var turn_card_open := false
## Set while the scene is being left, so a running bot turn stops.
var leaving := false
var kb := KeyboardNav.new()

## A tile was given up while choosing what a penalty takes.
signal loss_chosen

var shop_view: ShopView
var mat_view: MatView
var banner: PlayerBanner
var tooltip: Tooltip
var fx: Control
var overlays: Control
## Sits between the board and the overlays; shows while bots play unseen (bot speed "Instant").
var _skip_layer: Control

var _top_bar: TopBar
var _shop_panel: ShopPanel
var _deck_event: DeckPanel
var _deck_penalty: DeckPanel
var _order_panel: TurnOrderPanel
var _last_card: LastCardPanel
var _action_bar: ActionBar
var _toast: Toast
var _preview_label: Label
var _bot: BotDriver
var _fast_forward: FastForward


func _ready() -> void:
	theme = Game.theme
	if Game.state == null:
		Game.new_game()
	gs = Game.state
	gs.players_pick_losses = true
	_build()
	refresh_all()
	banner.set_money(gs.current_player().money)
	_bot = BotDriver.new(self)
	await _reveal_round_circumstance()
	_start_turn()


# ================================================================ layout

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# created first: HUD widgets bind to it while being built
	tooltip = Tooltip.new()
	tooltip.theme = Game.theme
	var bg := Widgets.Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	_top_bar = TopBar.new(Sfx.muted, tooltip, GameState.ROUNDS)
	_top_bar.rules_pressed.connect(_open_rules)
	_top_bar.sound_pressed.connect(_toggle_sound)
	_top_bar.menu_pressed.connect(_open_pause)
	_top_bar.circumstance_pressed.connect(_open_circumstance_review)
	col.add_child(_top_bar)
	col.add_child(_build_main_row())
	_action_bar = ActionBar.new(gs, tooltip)
	_action_bar.free_road_pressed.connect(_on_free_road)
	_action_bar.loan_pressed.connect(_on_loan)
	_action_bar.end_turn_pressed.connect(_on_end_turn)
	_action_bar.bonus_tile_pressed.connect(_on_bonus_tile)
	col.add_child(_action_bar)
	_build_layers()


## Shop on the left, the active mat in the middle, turn order on the right.
func _build_main_row() -> Control:
	var main := HBoxContainer.new()
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_theme_constant_override("separation", 28)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_panel = ShopPanel.new(gs.shop)
	shop_view = _shop_panel.view
	kb.shop_rows = shop_view.rows
	_shop_panel.slot_pressed.connect(_on_slot_pressed)
	_shop_panel.slot_right_pressed.connect(func(_i): _cancel_hand())
	_shop_panel.slot_hovered.connect(_on_slot_hovered)
	main.add_child(_build_left_column())
	main.add_child(_build_center_column())
	_order_panel = TurnOrderPanel.new(gs)
	_order_panel.city_pressed.connect(_on_city_pressed)
	main.add_child(_order_panel)
	return main


## The construction site with the two turn decks under it.
func _build_left_column() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.add_child(_shop_panel)
	var decks := HBoxContainer.new()
	decks.add_theme_constant_override("separation", 12)
	var piles := VBoxContainer.new()
	piles.add_theme_constant_override("separation", 8)
	piles.custom_minimum_size.x = 200
	_deck_event = DeckPanel.new(CardDefs.EVENT, tooltip, true)
	_deck_penalty = DeckPanel.new(CardDefs.PENALTY, tooltip, true)
	piles.add_child(_deck_event)
	piles.add_child(_deck_penalty)
	decks.add_child(piles)
	_last_card = LastCardPanel.new(tooltip)
	_last_card.pressed.connect(_open_card_view)
	decks.add_child(_last_card)
	decks.custom_minimum_size.x = _shop_panel.view.custom_minimum_size.x
	v.add_child(decks)
	return v


func _build_center_column() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	banner = PlayerBanner.new(tooltip)
	v.add_child(banner)
	mat_view = MatView.new()
	mat_view.setup(MAT_CELL, MAT_GAP, TileView.Mode.MAT)
	mat_view.cell_pressed.connect(_on_cell_pressed)
	mat_view.cell_right_pressed.connect(func(_i): _cancel_hand())
	mat_view.cell_hovered.connect(_on_cell_hovered)
	mat_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(mat_view)
	v.custom_minimum_size.x = mat_view.custom_minimum_size.x
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return v


## Effects, overlays and tooltip each get their own canvas layer, in that order.
func _build_layers() -> void:
	fx = _add_layer(5)
	_skip_layer = _add_layer(7)
	overlays = _add_layer(8)
	var tip_layer := CanvasLayer.new()
	tip_layer.layer = 10
	add_child(tip_layer)
	tip_layer.add_child(tooltip)
	_toast = Toast.new()
	fx.add_child(_toast)
	_preview_label = UiKit.outline(UiKit.label("", 26, UiKit.OLIVE, "display_bold"), 8)
	_preview_label.visible = false
	fx.add_child(_preview_label)


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


func _locked() -> bool:
	return busy or modal_count > 0 or bot_active or not gs.pending_losses.is_empty()


# ================================================================ refresh

func refresh_all() -> void:
	var p = gs.current_player()
	result = gs.score(gs.current_index())
	var prices: Array = []
	for st in gs.shop:
		prices.append(gs.price_of(st["tile"]))
	_shop_panel.refresh(gs.shop, p.money, gs.can_buy(), prices)
	_deck_event.set_count(gs.card_deck_count(CardDefs.EVENT))
	_deck_penalty.set_count(gs.card_deck_count(CardDefs.PENALTY))
	shop_view.set_selected(hand.get("slot", -1) if hand.get("type", "") == "shop" else -1)
	mat_view.refresh(p.cells, result)
	mat_view.set_targets(not hand.is_empty())
	_top_bar.set_round(gs.round_number, GameState.ROUNDS)
	_top_bar.set_circumstances(gs.revealed, gs.round_number)
	banner.show_player(p, result)
	_order_panel.refresh()
	_last_card.show_card(gs.turn_card)
	_apply_hover_rules()
	_action_bar.show_bought(turn_bought)
	_update_actions()


func _update_actions() -> void:
	_action_bar.update(hand, busy)


## Small entrance once a planner takes the controls.
func turn_intro() -> void:
	for k in mat_view.views.size():
		var v = mat_view.views[k]
		var tw := create_tween()
		tw.tween_interval(k * 0.02)
		tw.tween_callback(func(): v.pop(0.06))


func show_toast(text: String) -> void:
	_toast.show_message(text, mat_view.get_global_rect())


# ================================================================ hand + hover

func _hand_tile():
	match hand.get("type", ""):
		"shop":
			return gs.stack_tile(hand["slot"])
		"free":
			var t := TileDefs.make(TileDefs.Kind.ROAD)
			t["free"] = true
			return t
		"bonus":
			var bonus: Dictionary = gs.current_player().bonus_tiles[hand["index"]].duplicate()
			bonus["free"] = true
			return bonus
	return null


func set_hand(h: Dictionary) -> void:
	hand = h
	shop_view.set_selected(h.get("slot", -1) if h.get("type", "") == "shop" else -1)
	mat_view.set_targets(not h.is_empty())
	if h.is_empty():
		mat_view.set_ghost(null, -1)
		_preview_label.visible = false
	elif kb.on:
		kb.area = "mat"
		if gs.current_player().cells[kb.mat] != null:
			kb.mat = gs.current_player().cells.find(null)
		_update_kb_focus()
	if hover_cell >= 0:
		focus_cell(hover_cell)
	_update_actions()


func _cancel_hand() -> void:
	if hand.is_empty() or busy:
		return
	Sfx.play("cancel")
	set_hand({})


func _on_slot_hovered(i: int, inside: bool) -> void:
	if not inside:
		tooltip.hide_tip()
		return
	focus_slot(i)


func focus_slot(i: int) -> void:
	var t = gs.stack_tile(i)
	if t == null:
		tooltip.hide_tip()
		return
	tooltip.show_tile(t, shop_view.views[i].get_global_rect(), Describe.shop_lines(t, gs.current_player().money, gs.buys_left()), true, 15, gs.price_of(t))


func _on_cell_hovered(i: int, inside: bool) -> void:
	if inside:
		hover_cell = i
		focus_cell(i)
	elif hover_cell == i:
		hover_cell = -1
		unfocus_cell()


## Shows what a lot holds, or what building the picked-up tile there would do.
func focus_cell(i: int) -> void:
	var cells: Array = gs.current_player().cells
	if not gs.pending_losses.is_empty():
		# choosing what to lose: the glowing lots stay lit, hovering only names the tile
		if cells[i] != null:
			tooltip.show_tile(cells[i], mat_view.cell_global_rect(i), Describe.cell_lines(cells, result, i), false, MatView.road_mask(cells, i))
		else:
			tooltip.hide_tip()
		return
	var t = _hand_tile()
	if t != null and cells[i] == null:
		_preview_build(t, cells, i)
		return
	if t != null and hand["type"] == "shop" and gs.can_replace(hand["slot"], i):
		_preview_build(t, cells, i, true)
		return
	mat_view.set_ghost(null, -1)
	_preview_label.visible = false
	if cells[i] == null:
		mat_view.clear_highlights()
		tooltip.hide_tip()
		return
	Influence.show_for(mat_view, cells, result, i)
	tooltip.show_tile(cells[i], mat_view.cell_global_rect(i), Describe.cell_lines(cells, result, i), false, MatView.road_mask(cells, i))


## Ghost tile, floating point change and tooltip for building `t` on empty lot `i`.
func _preview_build(t: Dictionary, cells: Array, i: int, replacing := false) -> void:
	var rect := mat_view.cell_global_rect(i)
	var preview := _with(cells, i, t)
	var pr := Scoring.evaluate(preview, gs.current_player().loans, gs.revealed, gs.current_player().card_points)
	mat_view.set_ghost(t, i)
	Influence.show_for(mat_view, preview, pr, i)
	var delta: int = pr["total"] - result["total"]
	_preview_label.text = Describe.points(delta) if delta != 0 else "No change"
	_preview_label.add_theme_color_override("font_color", UiKit.OLIVE if delta > 0 else (UiKit.HEAT if delta < 0 else UiKit.LIMESTONE))
	_preview_label.visible = true
	_preview_label.reset_size()
	_preview_label.position = Vector2(rect.get_center().x - _preview_label.size.x / 2, rect.position.y - _preview_label.size.y - 2)
	var lines: Array[String] = ["[b]If you %s: %s[/b]" % ["replace this tile" if replacing else "build here", _preview_label.text]]
	lines.append_array(Describe.cell_lines(preview, pr, i))
	tooltip.show_tile(t, rect, lines, hand.get("type", "") == "shop", MatView.road_mask(preview, i))


func unfocus_cell() -> void:
	mat_view.set_ghost(null, -1)
	_preview_label.visible = false
	tooltip.hide_tip()
	if gs.pending_losses.is_empty():
		mat_view.clear_highlights()
	else:
		_show_loss_targets()


static func _with(cells: Array, i: int, tile: Dictionary) -> Array:
	var c := cells.duplicate()
	c[i] = tile
	return c


# ================================================================ actions

func _on_slot_pressed(i: int) -> void:
	if _locked():
		return
	var t = gs.stack_tile(i)
	if t == null:
		return
	if hand.get("type", "") == "shop" and hand["slot"] == i:
		_cancel_hand()
		return
	if not gs.can_buy():
		_reject(shop_view.views[i], "You have bought your %d tiles this round." % GameState.BUYS_PER_TURN)
		return
	if not gs.can_afford(i):
		var msg := "Not enough gold. You may take a loan." if gs.can_take_loan() else "Not enough gold for that one. Try a cheaper tile."
		_reject(shop_view.views[i], msg)
		return
	Sfx.play("pick")
	set_hand({"type": "shop", "slot": i})


func _on_free_road() -> void:
	if _locked():
		return
	if gs.current_player().free_roads <= 0:
		show_toast("No free roads left.")
		Sfx.play("error")
		return
	if hand.get("type", "") == "free":
		_cancel_hand()
		return
	Sfx.play("pick")
	set_hand({"type": "free"})


func _on_bonus_tile() -> void:
	if _locked():
		return
	if gs.current_player().bonus_tiles.is_empty():
		show_toast("No free tiles left.")
		Sfx.play("error")
		return
	if hand.get("type", "") == "bonus":
		_cancel_hand()
		return
	Sfx.play("pick")
	set_hand({"type": "bonus", "index": 0})


func _reject(view, msg: String) -> void:
	Sfx.play("error")
	view.shake()
	show_toast(msg)


func _on_cell_pressed(i: int) -> void:
	if not gs.pending_losses.is_empty():
		_on_loss_picked(i)
		return
	if _locked():
		return
	var cells: Array = gs.current_player().cells
	if hand.is_empty():
		if cells[i] == null and gs.can_buy():
			show_toast("Pick a tile from the construction site first.")
		return
	if cells[i] != null:
		if hand["type"] == "shop" and gs.can_replace(hand["slot"], i):
			_replace(i)
		elif hand["type"] == "shop" and gs.current_player().replaced:
			_reject(mat_view.views[i], "You already replaced a tile. Choose an empty lot.")
		else:
			_reject(mat_view.views[i], "That lot is taken. Choose an empty one.")
		return
	commit(i)


## Asks, then swaps the picked-up shop tile for the one on lot `cell`. The old tile goes back to the
## construction site. Allowed once per planner and game.
func _replace(cell: int) -> void:
	var h := hand
	var old: Dictionary = gs.current_player().cells[cell]
	var tile: Dictionary = _hand_tile()
	var yes = await _ask("Replace this tile?",
		"The %s makes room for your %s, which you pay for as usual and which counts as one of your buys. The %s goes back to the construction site. You can only do this once in the whole game." % [
			TileDefs.display_name(old).to_lower(), TileDefs.display_name(tile).to_lower(), TileDefs.display_name(old).to_lower()],
		[["Replace it", "primary", true], ["Keep it", "secondary", false]], TileDefs.art_path(tile), 1)
	if not yes or hand != h or not gs.can_replace(h["slot"], cell):
		return
	busy = true
	tooltip.hide_tip()
	var before: int = result["total"]
	var before_poll: int = result["pollution"]
	var from_rect := _take_from_hand(h)
	var to_rect := mat_view.cell_global_rect(cell)
	var cost := gs.price_of(tile)
	TileFx.fly_coins(fx, banner.coin_center(), from_rect.get_center(), cost)
	banner.animate_money(gs.current_player().money - cost)
	Sfx.play("whoosh")
	await TileFx.fly_tile(fx, TileDefs.art_path(tile, MatView.road_mask(_with(gs.current_player().cells, cell, tile), cell)), from_rect, to_rect)
	var removed := gs.replace_tile(h["slot"], cell)
	assert(not removed.is_empty(), "replacement rejected after validation")
	turn_bought.append(tile)
	# the old tile flies back to its stack in the construction site
	var back_slot := _slot_of(removed)
	var back_rect: Rect2 = shop_view.views[back_slot].get_global_rect() if back_slot >= 0 else from_rect
	busy = false
	refresh_all()
	busy = true
	_pop_placed(cell)
	Sfx.play("place")
	TileFx.landed(fx, tile, to_rect, result["total"] - before, result["pollution"] - before_poll, banner.gauge_center())
	await TileFx.fly_tile(fx, TileDefs.art_path(removed), to_rect, back_rect)
	busy = false
	refresh_all()
	if back_slot >= 0:
		shop_view.views[back_slot].pop(0.12)
	show_toast("The %s is back in the construction site." % TileDefs.display_name(removed).to_lower())
	if kb.on:
		kb.area = "shop" if gs.can_buy() else "mat"
		_update_kb_focus()
	elif hover_cell >= 0:
		focus_cell(hover_cell)


## The construction site stack a tile belongs to, or -1.
func _slot_of(tile: Dictionary) -> int:
	var key := TileDefs.sort_key(tile)
	for k in gs.shop.size():
		if TileDefs.sort_key(gs.shop[k]["tile"]) == key:
			return k
	return -1


## Pays for and places the picked-up tile on `cell`, with the flying-tile animation.
func commit(cell: int) -> void:
	busy = true
	tooltip.hide_tip()
	var h := hand
	var tile: Dictionary = _hand_tile()
	var before: int = result["total"]
	var before_poll: int = result["pollution"]
	var from_rect := _take_from_hand(h)
	var to_rect := mat_view.cell_global_rect(cell)
	if h["type"] == "shop":
		var cost := gs.price_of(tile)
		TileFx.fly_coins(fx, banner.coin_center(), from_rect.get_center(), cost)
		banner.animate_money(gs.current_player().money - cost)
	Sfx.play("whoosh")
	await TileFx.fly_tile(fx, TileDefs.art_path(tile, MatView.road_mask(_with(gs.current_player().cells, cell, tile), cell)), from_rect, to_rect)

	var ok: bool
	match h["type"]:
		"shop":
			ok = gs.buy_and_place(h["slot"], cell)
		"bonus":
			ok = gs.place_bonus_tile(h["index"], cell)
		_:
			ok = gs.place_free_road(cell)
	assert(ok, "placement rejected after validation")
	if h["type"] == "shop":
		turn_bought.append(tile)
	busy = false
	refresh_all()
	_pop_placed(cell)
	Sfx.play("place")
	TileFx.landed(fx, tile, to_rect, result["total"] - before, result["pollution"] - before_poll, banner.gauge_center())
	if kb.on:
		kb.area = "shop" if gs.can_buy() else "mat"
		_update_kb_focus()
	elif hover_cell >= 0:
		focus_cell(hover_cell)


## Empties the hand and returns the screen rect the tile flies out of.
func _take_from_hand(h: Dictionary) -> Rect2:
	var from_rect: Rect2
	if h["type"] == "shop":
		var v = shop_view.views[h["slot"]]
		from_rect = v.get_global_rect()
		v.selected = false
		v.queue_redraw()
	else:
		var br := _action_bar.bonus_button_rect() if h["type"] == "bonus" else _action_bar.road_button_rect()
		from_rect = Rect2(br.get_center() - Vector2(40, 40), Vector2(80, 80))
	hand = {}
	mat_view.set_ghost(null, -1)
	mat_view.set_targets(false)
	mat_view.clear_highlights()
	_preview_label.visible = false
	_update_actions()
	return from_rect


## The new tile and any roads it touches bounce a little.
func _pop_placed(cell: int) -> void:
	mat_view.views[cell].pop(0.16)
	for n in Scoring.neighbours(cell):
		var nt = gs.current_player().cells[n]
		if nt != null and nt["kind"] == TileDefs.Kind.ROAD:
			mat_view.views[n].pop(0.05)


func _on_loan() -> void:
	if _locked():
		return
	if not gs.can_take_loan():
		Sfx.play("error")
		show_toast("Loans are only allowed when you cannot afford the tiles you still need.")
		return
	_cancel_hand()
	var penalty := gs.next_loan_penalty()
	var yes = await _ask("Take a loan?", "You get %d gold now. At final scoring this loan costs you %d points, and every further loan costs more." % [GameState.LOAN_AMOUNT, penalty],
		[["Take %d gold" % GameState.LOAN_AMOUNT, "gold", true], ["Not now", "secondary", false]], "res://assets/ui/bank.svg")
	if not yes or not gs.can_take_loan():
		return
	take_loan_now()


func take_loan_now() -> void:
	var p = gs.current_player()
	var penalty := gs.next_loan_penalty()
	gs.take_loan()
	TileFx.fly_coins(fx, _action_bar.loan_button_rect().get_center(), banner.coin_center(), GameState.LOAN_AMOUNT)
	banner.animate_money(p.money)
	Sfx.play("minus")
	refresh_all()
	if p.is_bot():
		show_toast("%s took a loan: +%d gold now, -%d points at the end." % [p.name, GameState.LOAN_AMOUNT, penalty])
	else:
		show_toast("Loan taken: +%d gold now, -%d points at the end." % [GameState.LOAN_AMOUNT, penalty])


func _on_end_turn() -> void:
	if _locked():
		return
	if not gs.can_end_turn():
		Sfx.play("error")
		show_toast("Buy %d more tile%s first." % [gs.buys_left(), "" if gs.buys_left() == 1 else "s"])
		return
	var p = gs.current_player()
	var unplaced: int = p.free_roads + p.bonus_tiles.size()
	if gs.round_number == GameState.ROUNDS and unplaced > 0:
		var go = await _ask("Free tiles left", "This is your last turn. You still have %d free road%s or tile%s to place, and unplaced ones are lost." % [unplaced, "" if unplaced == 1 else "s", "" if unplaced == 1 else "s"],
			[["Keep building", "primary", false], ["End turn anyway", "secondary", true]], "res://assets/tiles/road_15.svg", 0)
		if not go:
			return
	finish_turn()


# ================================================================ turn flow

func finish_turn() -> void:
	set_hand({})
	tooltip.hide_tip()
	var ev := gs.end_turn()
	turn_bought.clear()
	busy = true
	match ev:
		"turn":
			# bots that play unseen do not need the board redrawn after every turn
			if not _plays_unseen():
				refresh_all()
			_start_turn()
		"round":
			end_fast_forward()
			refresh_all()
			await Banner.round_start(overlays, gs)
			await _reveal_round_circumstance()
			_start_turn()
		"game_over":
			end_fast_forward()
			await Banner.play(overlays, "City complete", "Time to count every citizen")
			leaving = true
			Game.goto(Game.FINAL_SCENE)


## Turns over this round's hidden circumstance card (its gold effect lands now) and shows it to everyone.
func _reveal_round_circumstance() -> void:
	var gold_before := _gold_snapshot()
	var entry := gs.reveal_circumstance()
	if entry.is_empty():
		return
	modal_count += 1
	circumstance_open = true
	var card := CircumstanceCard.new(gs, entry)
	overlays.add_child(card)
	await card.dismissed
	modal_count -= 1
	circumstance_open = false
	refresh_all()
	banner.set_money(gs.current_player().money)
	_order_panel.show_gold_changes(gold_before, fx)


## Click on a revealed card in the top bar: shows that round's full card again.
func _open_circumstance_review(i: int) -> void:
	if busy or modal_count > 0 or i >= gs.circumstance_log.size():
		return
	modal_count += 1
	tooltip.hide_tip()
	var card := CircumstanceCard.new(gs, gs.circumstance_log[i], true)
	overlays.add_child(card)
	await card.dismissed
	modal_count -= 1


## This turn's event or penalty card in big, from the small card next to the decks.
func _open_card_view(id: String) -> void:
	if busy or modal_count > 0:
		return
	modal_count += 1
	tooltip.hide_tip()
	var view := CardView.new(id)
	overlays.add_child(view)
	await view.closed
	modal_count -= 1


## What every planner has in gold right now, in seat order; compared with later to show who paid or got paid.
func _gold_snapshot() -> Array:
	var out := []
	for p in gs.players:
		out.append(p.money)
	return out


## Humans get the hand-off card; bots just start playing.
func _start_turn() -> void:
	_apply_hover_rules()
	if gs.current_player().is_bot():
		if not _plays_unseen():
			end_fast_forward()
		busy = true
		await _run_turn_card()
		if leaving:
			return
		busy = false
		_bot.play_turn()
	else:
		end_fast_forward()
		refresh_all()
		_show_handoff()


## Hover lifts, sounds and hint boxes are for the human planner: they stay off while a bot plays.
func _apply_hover_rules() -> void:
	var watching: bool = gs.current_player().is_bot()
	tooltip.muted = watching
	if watching:
		tooltip.hide_tip()
		mat_view.clear_highlights()
		mat_view.set_ghost(null, -1)
		hover_cell = -1
	for v in mat_view.views:
		v.hover_enabled = not watching
	for v in shop_view.views:
		if v != null:
			v.hover_enabled = not watching


func current_is_bot() -> bool:
	return gs.current_player().is_bot()


## True when the planner whose turn it is now is a bot and the bots are being played out of sight.
func _plays_unseen() -> bool:
	return gs.current_player().is_bot() and Game.bot_instant()


## Covers the board with the "bots are playing" box and says whose turn it is.
func begin_fast_forward() -> void:
	if _fast_forward == null:
		_fast_forward = FastForward.new(gs)
		_skip_layer.add_child(_fast_forward)
	tooltip.hide_tip()
	_fast_forward.show_turn()


func end_fast_forward() -> void:
	if _fast_forward != null:
		_fast_forward.dismiss()


func _show_handoff() -> void:
	busy = true
	modal_count += 1
	handoff_open = true
	var card := HandoffOverlay.new(gs)
	overlays.add_child(card)
	await card.dismissed
	modal_count -= 1
	handoff_open = false
	busy = false
	banner.set_money(gs.current_player().money)
	await _run_turn_card()
	busy = false
	_update_actions()
	turn_intro()


## Cards in a deck before this turn's card was drawn from it.
func deck_count_before(type: String) -> int:
	return gs.card_deck_count(type) + 1


## Before a planner buys: the coin flip decides between the event and the penalty deck, the top
## card is drawn and its effect happens at once.
func _run_turn_card() -> void:
	var draw := gs.flip_and_draw()
	if draw.is_empty():
		return
	if _plays_unseen():
		_resolve_turn_card_unseen()
		return
	busy = true
	modal_count += 1
	turn_card_open = true
	tooltip.hide_tip()
	var gold_before := _gold_snapshot()
	var deck: DeckPanel = _deck_penalty if draw["type"] == CardDefs.PENALTY else _deck_event
	var overlay := TurnCard.new(gs, draw, gs.current_player().is_bot(), deck.pile_rect())
	# the deck shrinks when the card leaves it, not before the coin has landed
	deck.set_count(deck_count_before(draw["type"]))
	overlay.dealt.connect(func():
		deck.set_count(gs.card_deck_count(draw["type"]))
		deck.pulse())
	overlays.add_child(overlay)
	await overlay.dismissed
	turn_card_open = false
	modal_count -= 1
	refresh_all()
	banner.set_money(gs.current_player().money)
	_order_panel.show_gold_changes(gold_before, fx)
	await _choose_losses()


## A bot's card when nobody watches: the coin and the card are drawn and resolved at once, with no
## pictures to build. The bot picks the option it likes best, like it does on screen.
func _resolve_turn_card_unseen() -> void:
	begin_fast_forward()
	var choice := -1
	if gs.card_needs_choice():
		choice = CardEffects.pick_option(gs, gs.current_index(), gs.card_choice_options())
	gs.resolve_turn_card(choice)


## A penalty that takes tiles lets the planner point at the ones to give up: the lots that can go
## glow, and the turn only goes on once all of them are chosen.
func _choose_losses() -> void:
	if gs.pending_losses.is_empty() or gs.current_player().is_bot():
		return
	busy = false
	kb.area = "mat"
	while not gs.pending_losses.is_empty() and not leaving:
		_show_loss_targets()
		_update_actions()
		await loss_chosen
	mat_view.clear_highlights()
	refresh_all()


func _show_loss_targets() -> void:
	var glow := {}
	for c in gs.loss_cells():
		glow[c] = Color(UiKit.HEAT, 0.85)
	mat_view.set_highlights(glow)


## The planner clicked lot `cell` while choosing what to lose.
func _on_loss_picked(cell: int) -> void:
	if busy or modal_count > 0:
		return
	var tile := gs.lose_tile_at(cell)
	if tile.is_empty():
		_reject(mat_view.views[cell], "Choose one of the glowing tiles.")
		return
	Sfx.play("minus")
	tooltip.hide_tip()
	mat_view.views[cell].shake()
	var p = gs.current_player()
	show_toast("%s lost a %s." % [p.name, TileDefs.display_name(tile).to_lower()])
	refresh_all()
	loss_chosen.emit()


# ================================================================ overlays

## Esc picks choices[cancel_index] (default: the last one).
func _ask(title: String, body: String, choices: Array, icon_path := "", cancel_index := -1):
	modal_count += 1
	var m := Modal.make(title, body, choices, icon_path, cancel_index)
	overlays.add_child(m)
	var v = await m.chosen
	modal_count -= 1
	return v


func _open_rules() -> void:
	if modal_count > 0:
		return
	modal_count += 1
	tooltip.hide_tip()
	var rp := RulesPanel.new()
	overlays.add_child(rp)
	await rp.closed
	modal_count -= 1


func _toggle_sound() -> void:
	Game.set_setting("muted", not Sfx.muted)
	_top_bar.set_muted(Sfx.muted)
	Sfx.play("click")


func _open_options() -> void:
	if modal_count > 0:
		return
	modal_count += 1
	tooltip.hide_tip()
	var op := OptionsPanel.new()
	overlays.add_child(op)
	await op.closed
	modal_count -= 1
	_top_bar.set_muted(Sfx.muted)


func _open_pause() -> void:
	if modal_count > 0 or busy:
		return
	if not bot_active:
		set_hand({})
	tooltip.hide_tip()
	var choice = await _ask("Paused", "Round %d of %d. %s is building." % [gs.round_number, GameState.ROUNDS, gs.current_player().name],
		[["Resume", "primary", "resume"], ["How to play", "secondary", "rules"], ["Options", "secondary", "options"], ["Main menu", "secondary", "menu"], ["Quit game", "ghost", "quit"]], "", 0)
	match choice:
		"rules":
			_open_rules()
		"options":
			_open_options()
		"menu":
			if await _ask("Leave this game?", "The current game will be lost.", [["Stay", "primary", false], ["Main menu", "secondary", true]], "", 0):
				leaving = true
				Game.goto(Game.TITLE_SCENE)
		"quit":
			if await _ask("Quit Egkomi City?", "The current game will be lost.", [["Stay", "primary", false], ["Quit", "secondary", true]], "", 0):
				get_tree().quit()


func _on_city_pressed(i: int) -> void:
	if busy or modal_count > 0:
		return
	Sfx.play("click")
	_open_city_viewer(i)


func _open_city_viewer(i: int) -> void:
	modal_count += 1
	tooltip.hide_tip()
	var was_muted := tooltip.muted
	tooltip.muted = false
	var viewer := CityViewer.new(gs.players[i], gs.score(i), tooltip)
	overlays.add_child(viewer)
	await viewer.closed
	tooltip.muted = was_muted
	modal_count -= 1


# ================================================================ keyboard

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if kb.on:
			kb.on = false
			_update_kb_focus()
		return
	if not (event is InputEventKey and event.pressed):
		return
	var key: int = event.keycode
	if modal_count > 0 or busy:
		return
	if bot_active and not key in [KEY_ESCAPE, KEY_H, KEY_F1, KEY_M]:
		return
	if not _handle_key(key, event.echo):
		return
	get_viewport().set_input_as_handled()


## Returns true when the key did something.
func _handle_key(key: int, echo: bool) -> bool:
	if ARROW_KEYS.has(key):
		_kb_move(ARROW_KEYS[key])
	elif echo:
		return false
	elif key == KEY_TAB:
		kb.on = true
		kb.toggle_area()
		_update_kb_focus()
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_kb_activate()
	elif key == KEY_ESCAPE:
		if not hand.is_empty() and not bot_active:
			_cancel_hand()
		else:
			_open_pause()
	elif key == KEY_R:
		_on_free_road()
	elif key == KEY_B:
		_on_bonus_tile()
	elif key == KEY_L:
		_on_loan()
	elif key == KEY_E:
		_on_end_turn()
	elif key == KEY_H or key == KEY_F1:
		_open_rules()
	elif key == KEY_M:
		_toggle_sound()
	else:
		return false
	return true


func _kb_move(d: Vector2i) -> void:
	if not kb.on:
		kb.on = true
		_update_kb_focus()
		return
	kb.step(d)
	Sfx.play("hover")
	_update_kb_focus()


func _kb_activate() -> void:
	if not kb.on:
		kb.on = true
		_update_kb_focus()
	elif kb.area == "shop":
		_on_slot_pressed(kb.shop)
	else:
		_on_cell_pressed(kb.mat)


func _update_kb_focus() -> void:
	shop_view.set_keyboard_focus(kb.shop if kb.on and kb.area == "shop" else -1)
	mat_view.set_keyboard_focus(kb.mat if kb.on and kb.area == "mat" else -1)
	if not kb.on:
		if hover_cell < 0:
			unfocus_cell()
		return
	if kb.area == "shop":
		unfocus_cell()
		focus_slot(kb.shop)
	else:
		focus_cell(kb.mat)
