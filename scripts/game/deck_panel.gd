extends PanelContainer
## One face-down turn deck on the game screen: a pile of card backs, its name and how many cards
## are left. The pile shows the real card back (the one the big card has), so deck and card match:
## event decks are green with a golden star burst, penalty decks red with hazard stripes.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const Face = preload("res://scripts/game/circumstance_card_face.gd")

const PILE_SIZE := Vector2(68, 95)
const COMPACT_PILE_SIZE := Vector2(34, 48)

var type: String
var _pile: Pile
var _count_label: Label
var _count := 0


func _init(deck_type: String, tooltip, compact := false) -> void:
	type = deck_type
	var pile_size := COMPACT_PILE_SIZE if compact else PILE_SIZE
	var event := type == CardDefs.EVENT
	var tint := Face.EVENT_TINT if event else Face.PENALTY_TINT
	add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL, 0.9), 16, 0, Color.TRANSPARENT, 8 if compact else 10))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	add_child(h)
	_pile = Pile.new(type, pile_size)
	_pile.custom_minimum_size = pile_size + Vector2(12, 10)
	h.add_child(_pile)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	v.add_child(UiKit.label("Event cards" if event else "Penalty cards", 16 if compact else 19, tint.lightened(0.35), "display_bold"))
	_count_label = UiKit.label("", 13 if compact else 15, UiKit.MUTED)
	v.add_child(_count_label)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(func(): tooltip.show_text("Event cards" if event else "Penalty cards", [
		"Tap the coin each turn: heads draws from the event deck, tails from the penalty deck.",
		"Event cards reward planners: gold, free tiles, cheaper tiles or points." if event else "Penalty cards punish planners: fees, lost tiles, higher prices or lost points.",
		"Each card is drawn at most once per game."], get_global_rect(), "res://assets/ui/event.svg" if event else "res://assets/ui/penalty.svg"))
	mouse_exited.connect(tooltip.hide_tip)


func set_count(n: int) -> void:
	_count = n
	_count_label.text = "%d left" % n
	_pile.set_layers(clampi(ceili(n / 17.0), 0, 3))


## Where the top card of the pile is on screen, for a card that flies out of it.
func pile_rect() -> Rect2:
	return _pile.top_rect()


## A small hop of the pile when a card is taken from it.
func pulse() -> void:
	var tw := create_tween()
	tw.tween_property(_pile, "position:y", _pile.position.y - 8.0, 0.1)
	tw.tween_property(_pile, "position:y", _pile.position.y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Up to three card backs stacked on top of each other. The back is drawn once, smoothly, into a
## small viewport (4x multisampling) and the layers show that picture.
class Pile extends Control:
	var _layers: Array[TextureRect] = []
	var _empty: Panel

	func _init(deck_type: String, pile_size: Vector2) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sub := SubViewport.new()
		sub.size = Vector2i(pile_size * 3.0)
		sub.size_2d_override = Vector2i(Face.WIDTH, Face.HEIGHT)
		sub.size_2d_override_stretch = true
		sub.transparent_bg = true
		sub.msaa_2d = Viewport.MSAA_4X
		sub.gui_disable_input = true
		sub.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(sub)
		var back := Face.back_turn(deck_type)
		back.size = Vector2(Face.WIDTH, Face.HEIGHT)
		sub.add_child(back)
		_empty = Panel.new()
		_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_empty.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK_DEEP, 0.4), 12, 2, Color(UiKit.LINE, 0.7)))
		_empty.position = Vector2(6, 6)
		_empty.size = pile_size
		add_child(_empty)
		for k in 3:
			var t := TextureRect.new()
			t.texture = sub.get_texture()
			t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_SCALE
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.size = pile_size
			t.position = Vector2(8.0 - 3.0 * k, 4.0 + 3.0 * k)
			t.modulate = Color.WHITE.darkened(0.12 * k)
			t.z_index = -k
			add_child(t)
			_layers.append(t)

	func set_layers(n: int) -> void:
		for k in _layers.size():
			_layers[k].visible = k < n
		_empty.visible = n <= 0

	func top_rect() -> Rect2:
		return _layers[0].get_global_rect()
