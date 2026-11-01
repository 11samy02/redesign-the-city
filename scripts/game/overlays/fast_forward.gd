extends Control
## Shown while the bots play out of sight (bot speed "Instant"). It tells people what is
## going on (who is thinking, how far through the round it is, that they are up next) so a skipped
## turn never looks like a frozen game. The game screen shows it with `show_turn` before each bot
## turn and hides it with `dismiss` once a person is up or something that needs reading comes up.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")
const Bot = preload("res://scripts/core/bot.gd")

var _gs
var _who: Label
var _round: Label
var _hint: Label
var _chips: HBoxContainer
var _spinner: Spinner
var _fade: Tween
var _shown := false


func _init(gs) -> void:
	_gs = gs


func _ready() -> void:
	OverlayKit.fill_dimmed(self, 0.84)
	var sb := UiKit.box(UiKit.PANEL, 26, 2, UiKit.LINE, 30)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 36
	var card := OverlayKit.add_card(self, sb, 640)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	_spinner = Spinner.new()
	_spinner.custom_minimum_size = Vector2(0, 84)
	v.add_child(_spinner)
	var title := UiKit.label("The bots are playing", 38, UiKit.LIMESTONE, "display_bold")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_who = UiKit.label("", 24, UiKit.GOLD, "display_bold")
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_who)
	_round = UiKit.label("", 17, UiKit.MUTED)
	_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_round)
	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 8)
	v.add_child(_chips)
	_hint = UiKit.label("", 17, UiKit.LIMESTONE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hint)
	modulate.a = 0.0
	visible = false


## Fades in (when not yet showing) and describes the bot whose turn it is now.
func show_turn() -> void:
	var p = _gs.current_player()
	_who.text = "%s (%s bot) is playing" % [p.name, Bot.level_name(p.bot_level)]
	_round.text = "Round %d of %d" % [_gs.round_number, _gs.ROUNDS]
	_rebuild_chips()
	_refresh_hint()
	if _shown:
		return
	_shown = true
	visible = true
	_fade_to(1.0, 0.18)


## Fades out. Safe to call when nothing is showing.
func dismiss() -> void:
	if not _shown:
		return
	_shown = false
	_fade_to(0.0, 0.2)
	get_tree().create_timer(0.25).timeout.connect(func():
		if not _shown:
			visible = false)


func is_showing() -> bool:
	return _shown


func _fade_to(alpha: float, seconds: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, seconds)


## One chip per planner in this round's order: finished ones are green, the current one gold.
func _rebuild_chips() -> void:
	for c in _chips.get_children():
		c.queue_free()
	for k in _gs.order.size():
		var p = _gs.players[_gs.order[k]]
		var bg := UiKit.PANEL_HI
		var fg := UiKit.MUTED
		var mark := ""
		if k < _gs.turn:
			bg = Color(UiKit.OLIVE, 0.3)
			fg = UiKit.OLIVE.lightened(0.35)
			mark = "done  "
		elif k == _gs.turn:
			bg = UiKit.GOLD_DEEP
			fg = UiKit.LIMESTONE
			mark = "now  "
		_chips.add_child(UiKit.chip("%s%s" % [mark, p.name], bg, fg, 15))


func _refresh_hint() -> void:
	var next := _next_person()
	if next == "":
		var people: Array = _gs.players.filter(func(p): return not p.is_bot())
		if people.size() == 1:
			_hint.text = "%s is up again in the next round, as soon as the bots are done." % people[0].name
		else:
			_hint.text = "The next round starts as soon as the bots are done."
	else:
		_hint.text = "%s is up as soon as the bots are done." % next
	_hint.text += " Bot speed is set to Instant in the options."


## The first human still to play this round, or "".
func _next_person() -> String:
	for k in range(_gs.turn, _gs.order.size()):
		var p = _gs.players[_gs.order[k]]
		if not p.is_bot():
			return p.name
	return ""


## An arc that keeps turning, so the box is clearly alive while a bot thinks.
class Spinner extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.36
		var t := Time.get_ticks_msec() / 1000.0
		draw_arc(c, r, 0.0, TAU, 40, Color(UiKit.LINE, 0.9), 8.0, true)
		draw_arc(c, r, t * 4.0, t * 4.0 + 1.9, 24, UiKit.GOLD, 8.0, true)
		draw_arc(c, r * 0.55, -t * 6.0, -t * 6.0 + 1.3, 16, UiKit.GOLD_DEEP, 6.0, true)
