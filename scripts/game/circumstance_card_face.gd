extends RefCounted
## Draws the hidden circumstance cards as collectible game cards: a beveled, gradient frame with a gold inner
## line, a title ribbon with notched ends, a glossy corner gem, an inset art window with a
## and a lively effect layer, a parchment rules box, an ornamental divider, an engraved
## footer and a foil sheen. Also the patterned back and the mini cards for the top bar.
## Every card uses the same structure; only the colour theme (the card's tint) changes.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const Shape = preload("res://scripts/ui/shape_draw.gd")

const PAPER := Color("#F3E8CF")
const PAPER_DEEP := Color("#E8D9B4")
const INK := Color("#1B2733")
const BROWN := Color("#5E4E38")
const GOOD := Color("#3F9A2B")
const BAD := Color("#CC3B27")
const GOLD_LINE := Color("#E7BC5A")
const EVENT_TINT := Color("#2FA05A")
const PENALTY_TINT := Color("#C8402A")

## Portrait trading-card proportions, 5:7.
const WIDTH := 420.0
const HEIGHT := 588.0
const ART_PX := 208.0
const TEXT_W := 336.0

const FAMILY_ICON := {
	"Weather": "res://assets/ui/sun.svg",
	"City": "res://assets/tiles/home_small_worker.svg",
}


# ================================================================ cards

## The front of the card for circumstance `id`. Meta "gem", "rules" and "sheen" hold the parts the
## overlay animates in after the card is turned over.
static func front(id: String, for_print := false) -> Control:
	var spec := spec_of_circumstance(id)
	spec["print"] = for_print
	return front_from(spec)


## What a card face needs, for a hidden circumstance card.
static func spec_of_circumstance(id: String) -> Dictionary:
	var info := CircumstanceDefs.info(id)
	return {
		"title": info["title"], "story": info["story"], "rule": info["rule"], "key": info["key"],
		"tint": CircumstanceDefs.tint(id), "art": CircumstanceDefs.art_path(id),
		"icon": CircumstanceDefs.icon_path(id), "icon_tinted": info["icon"] == "citizen",
		"badge": CircumstanceDefs.badge(id), "good": CircumstanceDefs.is_good(id),
		"number_text": "%d/%d" % [CircumstanceDefs.number(id), CircumstanceDefs.IDS.size()],
		"tab_icon": FAMILY_ICON[info["family"]], "tab_text": "%s CIRCUMSTANCE" % String(info["family"]).to_upper(),
		"fx": id,
	}


## The same for an event or penalty card: green with a star for events, red with a warning sign for penalties.
static func spec_of_turn_card(id: String) -> Dictionary:
	var info := CardDefs.info(id)
	var event := CardDefs.is_event(id)
	return {
		"title": info["title"], "story": "", "rule": info["rule"], "key": CardDefs.key_words(id),
		"tint": CardDefs.tint(id), "art": CardDefs.art_path(id),
		"icon": "" if CardDefs.icon_name(id) == "citizen" else CardDefs.icon_path(id), "icon_tinted": false,
		"badge": _short_badge(info["badge"], event), "good": event, "simple": true,
		"number_text": "%d/%d" % [info["number"], CardDefs.DECK_SIZE],
		"tab_icon": "res://assets/ui/event.svg" if event else "res://assets/ui/penalty.svg",
		"tab_text": "EVENT CARD" if event else "PENALTY CARD",
		"fx": "",
	}


## The few characters that fit in the gem: "+3g" from "+3g each", "-2" from "-2g -1", else "+" or "-".
static func _short_badge(badge: String, good: bool) -> String:
	var m := RegEx.create_from_string("^[+-]\\d+g?").search(badge)
	if m != null:
		return m.get_string()
	return "+" if good else "-"


static func front_turn(id: String, for_print := false) -> Control:
	var spec := spec_of_turn_card(id)
	spec["print"] = for_print
	return front_from(spec)


## A card background with nothing on it, for printing: "event", "penalty", "weather" or "city".
static func front_blank(kind: String) -> Control:
	var spec: Dictionary
	match kind:
		"event":
			spec = spec_of_turn_card(CardDefs.ids(CardDefs.EVENT)[0])
			spec["tint"] = EVENT_TINT
		"penalty":
			spec = spec_of_turn_card(CardDefs.ids(CardDefs.PENALTY)[0])
			spec["tint"] = PENALTY_TINT
		"weather":
			spec = spec_of_circumstance("heatwave")
			spec["tint"] = Color("#5B9BD5")
		_:
			spec = spec_of_circumstance("short_walks")
			spec["tint"] = Color("#C9A25B")
	for k in ["title", "story", "rule", "key", "badge", "number_text", "tab_text"]:
		spec[k] = ""
	spec["art"] = ""
	spec["icon"] = ""
	spec["tab_icon"] = ""
	spec["blank"] = true
	spec["print"] = true
	return front_from(spec)


static func front_from(spec: Dictionary) -> Control:
	var tint: Color = spec["tint"]

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(WIDTH, HEIGHT)

	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var simple: bool = spec.get("simple", false)
	frame.add_theme_stylebox_override("panel", FrameStyle.new(tint, simple, spec.get("print", false)))
	root.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var face := PanelContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override("panel", ParchmentStyle.new(PAPER, 21 if simple else 19, tint.darkened(0.2), 12 if simple else 10, 7))
	frame.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	face.add_child(v)

	v.add_child(_ribbon(spec, tint))
	v.add_child(_art_block(spec, tint))
	var rules := _rules_box(spec, tint)
	v.add_child(rules)
	if not simple:
		v.add_child(Ornament.new(tint.darkened(0.25)))
		v.add_child(_flavour(spec))
	v.add_child(_footer(spec))

	var gem := Gem.new(spec["badge"], spec["good"])
	root.add_child(gem)
	# the ornate cards let the gem hang over the corner; the simple ones keep it inside the card
	gem.position = Vector2(2, 2) if (simple or spec.get("print", false)) else Vector2(-16, -16)
	gem.visible = not spec.get("blank", false)

	var sheen := _sheen(tint)
	root.add_child(sheen)

	root.set_meta("gem", gem)
	root.set_meta("rules", rules)
	root.set_meta("sheen", sheen)
	return root


## The face-down card: a dark card with a diamond pattern and the Egkomi sun, in the card's
## colour theme so the back already hints at the front.
static func back(id: String) -> Control:
	return _back_card(CircumstanceDefs.tint(id), "diamonds", "res://assets/ui/sun.svg", "CIRCUMSTANCE")


## The one back all hidden circumstance cards share (for printing).
static func back_circumstance() -> Control:
	return _back_card(Color("#C9A25B"), "diamonds", "res://assets/ui/sun.svg", "CIRCUMSTANCE")


## The back of a turn deck. Event cards are green with a golden star burst; penalty cards are red
## with hazard stripes and a warning sign, so the deck of a drawn card is clear before it is turned.
static func back_turn(type: String) -> Control:
	if type == CardDefs.EVENT:
		return _back_card(EVENT_TINT, "rays", "res://assets/ui/event.svg", "EVENT")
	return _back_card(PENALTY_TINT, "hazard", "res://assets/ui/penalty.svg", "PENALTY")


static func _back_card(tint: Color, style: String, icon_path: String, label: String) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(WIDTH, HEIGHT)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", FrameStyle.new(tint, true))
	root.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var face := PanelContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override("panel", UiKit.box(UiKit.INK, 21, 0, Color.TRANSPARENT, 0))
	frame.add_child(face)
	var inner := Control.new()
	inner.clip_contents = true
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(inner)
	var pattern := BackPattern.new(tint, style)
	inner.add_child(pattern)
	pattern.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var medallion := PanelContainer.new()
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion.add_theme_stylebox_override("panel", UiKit.box(UiKit.INK_DEEP, 999, 0, Color.TRANSPARENT, 28))
	medallion.add_child(UiKit.icon(icon_path, 128))
	center.add_child(medallion)
	return root


## A small portrait card for the top bar: the picture and the corner number on cream paper.
static func mini(id: String) -> PanelContainer:
	var tint := CircumstanceDefs.tint(id)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.box(tint.darkened(0.12), 10, 0, Color.TRANSPARENT, 3))
	var face := PanelContainer.new()
	face.add_theme_stylebox_override("panel", UiKit.box(PAPER, 7, 0, Color.TRANSPARENT, 2))
	frame.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	face.add_child(v)
	v.add_child(UiKit.icon(CircumstanceDefs.art_path(id), 34))
	var b := UiKit.label(CircumstanceDefs.badge(id), 13, GOOD if CircumstanceDefs.is_good(id) else BAD, "display_bold")
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	return frame


## A small face-down card for a round whose circumstance has not been revealed.
static func mini_back(now: bool) -> PanelContainer:
	var frame := PanelContainer.new()
	var edge: Color = UiKit.GOLD if now else UiKit.LINE
	frame.add_theme_stylebox_override("panel", UiKit.box(UiKit.INK, 10, 2, edge, 3))
	var q := UiKit.label("?", 30, UiKit.GOLD if now else UiKit.MUTED, "display_bold")
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(q)
	return frame


# ================================================================ pieces

static func _ribbon(spec: Dictionary, tint: Color) -> Control:
	var rib := Ribbon.new(tint)
	var title: String = spec["title"]
	var t := UiKit.label(title, 34 if title.length() <= 12 else 28, Color.WHITE, "display_bold")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 8)
	t.add_theme_color_override("font_outline_color", tint.darkened(0.7))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 3)
	rib.add_child(t)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.offset_left = 44
	t.offset_right = -14
	return rib


## The picture window (double border, live effects) with the type tab on its lower edge.
static func _art_block(spec: Dictionary, tint: Color) -> Control:
	var block := Control.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer := PanelContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_stylebox_override("panel", UiKit.box(tint.darkened(0.6), 27, 3, GOLD_LINE, 5))
	# A rounded panel that masks everything inside it, so no square corners poke out of the frame.
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(ART_PX, ART_PX)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_stylebox_override("panel", UiKit.box(tint.darkened(0.55), 22, 0, Color.TRANSPARENT))
	holder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	outer.add_child(holder)
	if spec["art"] != "":
		var art := UiKit.icon(spec["art"], ART_PX)
		holder.add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fx := ArtFx.new(spec["fx"])
	holder.add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var win := ART_PX + 2.0 * (5 + 3)
	outer.custom_minimum_size = Vector2(win, win)
	block.custom_minimum_size = Vector2(0, win + 16)
	block.add_child(outer)
	outer.anchor_left = 0.5
	outer.anchor_right = 0.5
	outer.offset_left = -win / 2.0
	outer.offset_right = win / 2.0
	outer.offset_top = 0
	outer.offset_bottom = win

	var tab := PanelContainer.new()
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb := UiKit.box(tint.darkened(0.45), 11, 2, GOLD_LINE, 4)
	tsb.shadow_color = Color(0, 0, 0, 0.4)
	tsb.shadow_size = 4
	tsb.shadow_offset = Vector2(0, 2)
	tsb.content_margin_left = 12
	tsb.content_margin_right = 14
	tab.add_theme_stylebox_override("panel", tsb)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 6)
	if spec["tab_icon"] != "":
		th.add_child(UiKit.icon(spec["tab_icon"], 18))
	th.add_child(UiKit.label(spec["tab_text"] if spec["tab_text"] != "" else "      ", 14, Color.WHITE, "body_bold"))
	tab.add_child(th)
	block.add_child(tab)
	tab.anchor_left = 0.5
	tab.anchor_right = 0.5
	tab.anchor_top = 1.0
	tab.anchor_bottom = 1.0
	tab.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tab.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return block


## Parchment box with the rule as the hero: big and bold, the key words in colour with a small icon.
static func _rules_box(spec: Dictionary, tint: Color) -> Control:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", ParchmentStyle.new(PAPER_DEEP, 12, tint.darkened(0.05), 12, 21))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(center)
	var rule: String = spec["rule"]
	var size := 27 if rule.length() <= 45 else (24 if rule.length() <= 62 else 21)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.custom_minimum_size.x = TEXT_W - 24
	rt.add_theme_font_override("normal_font", UiKit.font("display_bold"))
	rt.add_theme_font_override("bold_font", UiKit.font("display_bold"))
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_font_size_override("bold_font_size", size)
	rt.add_theme_color_override("default_color", INK)
	rt.add_theme_constant_override("line_separation", 2)
	var accent := GOOD if spec["good"] else BAD
	var hex := accent.darkened(0.1).to_html(false)
	rt.text = "[center]%s[/center]" % rich_rule(spec["rule"], spec["key"], hex, size, spec["icon_tinted"], spec["icon"])
	center.add_child(rt)
	return box


const COIN_ICON := "res://assets/ui/coin.svg"
const POINT_ICON := "res://assets/ui/trophy.svg"
const HAPPY_ICON := "res://assets/ui/smile_up.svg"
const SAD_ICON := "res://assets/ui/smile_down.svg"


## "lose 1 happiness" becomes "get -1" and a red frowning face, "gain 1 happiness" "get +1" and a green
## smiling one, so the word is never repeated by the picture next to it. `good` and `bad` are the
## colours (html, no #) of the + and - numbers.
static func happiness_icons(text: String, good: String, bad: String, size: int) -> String:
	var icon_size := size + 2
	var out := text
	for spec in [["lose", "get", "-", bad, SAD_ICON], ["loses", "gets", "-", bad, SAD_ICON],
			["gain", "get", "+", good, HAPPY_ICON], ["gains", "gets", "+", good, HAPPY_ICON]]:
		for extra in [true, false]:
			var re := RegEx.create_from_string("\\b%s (\\d+) %shappiness" % [spec[0], "extra " if extra else ""])
			var lead: String = "%s an extra " % spec[1] if extra else "%s " % spec[1]
			out = re.sub(out, "%s[color=#%s]%s$1[/color]⁠[img width=%d height=%d]%s[/img]" % [lead, spec[3], spec[2], icon_size, icon_size, spec[4]], true)
	return out


## The rule as bbcode. An amount of gold or points shows as the number and a small coin or trophy
## instead of the word, so the picture is never repeated by the text next to it ("3 gold" with a
## coin after it). A rule without such an amount highlights its key words instead, with the
## citizen icon after them when the card asks for one.
static func rich_rule(rule: String, key: String, hex: String, size: int, tinted: bool, icon: String) -> String:
	var icon_size := size + 2
	var out := happiness_icons(rule, GOOD.darkened(0.1).to_html(false), BAD.darkened(0.1).to_html(false), size)
	var changed := out != rule
	for pair in [["gold", COIN_ICON], ["points?", POINT_ICON]]:
		var re := RegEx.create_from_string("([+-]?\\d+) %s\\b" % pair[0])
		if re.search(out) != null:
			changed = true
			out = re.sub(out, "[color=#%s]$1[/color]⁠[img width=%d height=%d]%s[/img]" % [hex, icon_size, icon_size, pair[1]], true)
	if changed:
		return out
	if key == "" or not rule.contains(key):
		return rule
	var img := "[img width=%d color=#%s]%s[/img]" % [size - 2, hex, icon] if tinted and icon != "" else ""
	return rule.replace(key, "[color=#%s]%s[/color]%s" % [hex, key, img])


## Italic, smaller and muted, so it clearly ranks below the rule.
static func _flavour(spec: Dictionary) -> Control:
	var l := UiKit.label(spec["story"], 15, BROWN.lightened(0.15))
	var fv := FontVariation.new()
	fv.base_font = UiKit.font("body")
	fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)
	l.add_theme_font_override("font", fv)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = TEXT_W
	return l


## Printed-card footer with an engraved look: city left, emblem centre, collector number right.
static func _footer(spec: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if spec.get("simple", false):
		var only := _engraved(spec["number_text"], HORIZONTAL_ALIGNMENT_CENTER)
		only.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(only)
		return row
	var left := _engraved("REDESIGN THE CITY", HORIZONTAL_ALIGNMENT_LEFT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	row.add_child(UiKit.icon("res://assets/ui/sun.svg", 20))
	var right := _engraved(spec["number_text"], HORIZONTAL_ALIGNMENT_RIGHT)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	return row


static func _engraved(text: String, align: int) -> Label:
	var l := UiKit.label(text, 13, BROWN.darkened(0.15), "body_bold")
	l.horizontal_alignment = align
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.65))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


## Diagonal foil sheen: a soft light band inside a clipping holder. The overlay animates it.
static func _sheen(tint: Color) -> Control:
	# A rounded, opaque panel that only masks its children (it is not drawn itself), so the
	# sheen is cut to the card's rounded outline instead of a square.
	var holder := Panel.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_stylebox_override("panel", UiKit.box(Color.WHITE, 27))
	holder.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.34), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	gt.width = 128
	gt.height = 8
	var band := TextureRect.new()
	band.texture = gt
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(110, 900)
	band.pivot_offset = band.size / 2.0
	band.rotation_degrees = 16
	band.position = Vector2(-400, -150)
	band.modulate = Color(1, 1, 1).lerp(tint.lightened(0.5), 0.35)
	holder.add_child(band)
	holder.set_meta("band", band)
	return holder


static func _centered(text: String, size: int, color: Color, kind := "body") -> Label:
	var l := UiKit.label(text, size, color, kind)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ================================================================ custom drawing

## Beveled copper-style frame in the card's colour: soft shadow, dark edge, gradient body, a light
## top bevel, a darker lower bevel, a dark groove and a thin gold inner line.
class FrameStyle extends StyleBox:
	var _tint: Color
	var _simple := false
	var _no_shadow := false
	var _shadow := StyleBoxFlat.new()

	func _init(tint: Color, simple := false, no_shadow := false) -> void:
		_tint = tint
		_simple = simple
		_no_shadow = no_shadow
		set_content_margin_all(11 if simple else 16)
		_shadow.bg_color = Color(0, 0, 0, 0.0)
		_shadow.set_corner_radius_all(30)
		_shadow.shadow_color = Color(0, 0, 0, 0.45)
		_shadow.shadow_size = 16
		_shadow.shadow_offset = Vector2(0, 6)

	func _draw(ci: RID, rect: Rect2) -> void:
		if _simple:
			var flat := Shape.rounded(rect, 30.0)
			Shape.fill_colors(ci, flat, Shape.vertical_colors(flat, rect, _tint.lightened(0.12), _tint.darkened(0.35)))
			return
		if not _no_shadow:
			_shadow.draw(ci, rect)
		Shape.fill(ci, Shape.rounded(rect, 30.0), _tint.darkened(0.78))
		var body := rect.grow(-2.5)
		var pts := Shape.rounded(body, 28.0)
		Shape.fill_colors(ci, pts, Shape.vertical_colors(pts, body, _tint.lightened(0.22), _tint.darkened(0.5)))
		var top_edge := PackedVector2Array()
		var low_edge := PackedVector2Array()
		for p in pts:
			if p.y < body.position.y + 34.0:
				top_edge.append(p)
			elif p.y > body.end.y - 34.0:
				low_edge.append(p)
		if top_edge.size() > 1:
			Shape.line(ci, top_edge, Color(1, 1, 1, 0.55), 2.5)
		if low_edge.size() > 1:
			Shape.line(ci, low_edge, Color(0, 0, 0, 0.4), 3.0)
		var groove := rect.grow(-10.5)
		Shape.fill(ci, Shape.rounded(groove, 21.0), _tint.darkened(0.72))
		Shape.line(ci, Shape.rounded(rect.grow(-12.5), 19.5), GOLD_LINE, 1.8, true)


## Cream paper with fine grain, a few fibres and a soft darker edge.
class ParchmentStyle extends StyleBox:
	var _base: Color
	var _radius: float
	var _edge: Color
	var _seed: int

	func _init(base: Color, radius: float, edge: Color, margin: float, seed_value: int) -> void:
		_base = base
		_radius = radius
		_edge = edge
		_seed = seed_value
		set_content_margin_all(margin)

	func _draw(ci: RID, rect: Rect2) -> void:
		var pts := Shape.rounded(rect, _radius)
		Shape.fill_colors(ci, pts, Shape.vertical_colors(pts, rect, _base.lightened(0.05), _base.darkened(0.07)))
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		var count := clampi(int(rect.size.x * rect.size.y / 45.0), 60, 700)
		var area := rect.grow(-5)
		for i in count:
			var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
			var s := rng.randf_range(1.0, 2.2)
			var shade := Color(0.42, 0.3, 0.12, rng.randf_range(0.03, 0.09)) if rng.randf() < 0.7 else Color(1, 1, 1, rng.randf_range(0.06, 0.14))
			RenderingServer.canvas_item_add_rect(ci, Rect2(p, Vector2(s, s * rng.randf_range(1.0, 2.0))), shade)
		for i in 7:
			var a := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
			var b := a + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-5.0, 5.0))
			Shape.line(ci, PackedVector2Array([a, b]), Color(0.45, 0.32, 0.14, 0.07), 1.0)
		Shape.line(ci, Shape.rounded(rect.grow(-1.5), _radius - 1.5), Color(_edge, 0.55), 2.0, true)
		Shape.line(ci, Shape.rounded(rect.grow(-4.0), _radius - 4.0), Color(0.3, 0.2, 0.08, 0.07), 3.0, true)


## Title ribbon with notched (swallowtail) ends. The title label sits inside it.
class Ribbon extends Control:
	var _tint: Color

	func _init(tint: Color) -> void:
		_tint = tint
		custom_minimum_size = Vector2(0, 62)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ci := get_canvas_item()
		var w := size.x
		var h := size.y
		var y0 := 7.0
		var y1 := h - 7.0
		var notch := 22.0
		var pts := PackedVector2Array([
			Vector2(0, y0), Vector2(w, y0), Vector2(w - notch, h * 0.5),
			Vector2(w, y1), Vector2(0, y1), Vector2(notch, h * 0.5),
		])
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + Vector2(0, 4))
		Shape.fill(ci, shadow, Color(0, 0, 0, 0.35))
		var rect := Rect2(0, y0, w, y1 - y0)
		Shape.fill_colors(ci, pts, Shape.vertical_colors(pts, rect, _tint.lightened(0.12), _tint.darkened(0.4)))
		Shape.line(ci, pts, _tint.darkened(0.75), 3.0, true)
		Shape.line(ci, PackedVector2Array([Vector2(3, y0 + 3), Vector2(w - 3, y0 + 3)]), Color(1, 1, 1, 0.4), 2.0)


## Glossy round gem for the corner badge: red for a penalty, green for a bonus.
class Gem extends Control:
	var _base: Color

	func _init(text: String, good: bool) -> void:
		_base = GOOD if good else BAD
		custom_minimum_size = Vector2(66, 66)
		size = Vector2(66, 66)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UiKit.label(text, 26 if text.length() <= 2 else 20, Color.WHITE, "display_bold")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", _base.darkened(0.55))
		add_child(l)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.offset_top = 3

	func _draw() -> void:
		var c := size / 2.0
		var r := 31.0
		draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.42))
		draw_circle(c, r, _base.darkened(0.65))
		draw_circle(c, r - 2.0, GOLD_LINE)
		draw_circle(c, r - 5.0, _base.darkened(0.4))
		draw_circle(c, r - 7.0, _base)
		draw_circle(c + Vector2(0, 7), r - 12.0, _base.lightened(0.2))
		var gloss := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			gloss.append(c + Vector2(0, -r * 0.4) + Vector2(cos(a) * r * 0.62, sin(a) * r * 0.32))
		draw_colored_polygon(gloss, Color(1, 1, 1, 0.6))
		draw_circle(c + Vector2(-r * 0.42, -r * 0.55), 3.2, Color(1, 1, 1, 0.95))


## Divider: a thin line, a small diamond and a dot at each end.
class Ornament extends Control:
	var _color: Color

	func _init(color: Color) -> void:
		_color = color
		custom_minimum_size = Vector2(0, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var arm := minf(size.x * 0.28, 110.0)
		var col := Color(_color, 0.8)
		draw_line(Vector2(c.x - arm, c.y), Vector2(c.x - 11, c.y), col, 1.8, true)
		draw_line(Vector2(c.x + 11, c.y), Vector2(c.x + arm, c.y), col, 1.8, true)
		draw_circle(Vector2(c.x - arm - 4, c.y), 2.2, col)
		draw_circle(Vector2(c.x + arm + 4, c.y), 2.2, col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), _color)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(3, 0), c + Vector2(0, 3), c + Vector2(-3, 0)]), Color(1, 1, 1, 0.55))


## Slow living effects over a card picture: a pulsing sun, heat shimmer, rain, drifting dust and
## twinkling sparkles. Coordinates are in the 256 px space of the art.
class ArtFx extends Control:
	var _id: String
	var _t := 0.0

	func _init(id: String) -> void:
		_id = id
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := size.x / 256.0
		match _id:
			"heatwave":
				_sun(Vector2(78, 70), 34.0, k)
				for i in 4:
					var pts := PackedVector2Array()
					for x in range(0, 264, 8):
						pts.append(Vector2(x, 192 + i * 15 + 3.0 * sin(x * 0.09 + _t * 2.6 + i * 1.7)) * k)
					draw_polyline(pts, Color(1, 0.97, 0.85, 0.2), 3.0 * k, true)
			"nice_weather":
				_sun(Vector2(70, 62), 28.0, k)
			"grant":
				_sun(Vector2(204, 54), 22.0, k)
				_sparkles([Vector2(52, 52), Vector2(84, 26), Vector2(178, 30), Vector2(222, 100), Vector2(36, 120)], k)
			"flash_flood":
				for n in 18:
					var x := fmod(n * 47.0 + _t * 26.0, 270.0) - 8.0
					var y := fmod(n * 31.0 + _t * 190.0, 190.0) + 20.0
					draw_line(Vector2(x, y) * k, Vector2(x - 7, y + 20) * k, Color(0.87, 0.95, 1.0, 0.55), 2.4 * k, true)
			"dust_storm":
				for n in 30:
					var x := fmod(n * 37.0 + _t * (30.0 + (n % 5) * 10.0), 270.0) - 8.0
					var y := 24.0 + fmod(n * 53.0, 200.0) + 6.0 * sin(_t * 1.5 + n)
					draw_circle(Vector2(x, y) * k, (1.6 + (n % 3)) * k, Color(0.96, 0.84, 0.55, 0.5))
			"budget_cut":
				_sparkles([Vector2(86, 120), Vector2(160, 60), Vector2(214, 124)], k)
			"road_works":
				_sparkles([Vector2(126, 52), Vector2(36, 214), Vector2(224, 214)], k)
			"new_attractor":
				_sparkles([Vector2(206, 22), Vector2(150, 30), Vector2(232, 70)], k)
			"population_growth":
				_sparkles([Vector2(204, 28), Vector2(226, 52), Vector2(180, 60)], k)

	func _sun(pos: Vector2, r: float, k: float) -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 1.7)
		draw_circle(pos * k, (r * 1.7 + 6.0 * pulse) * k, Color(1.0, 0.92, 0.55, 0.12 + 0.1 * pulse))
		draw_circle(pos * k, (r * 1.2 + 3.0 * pulse) * k, Color(1.0, 0.95, 0.65, 0.16 + 0.1 * pulse))

	func _sparkles(points: Array, k: float) -> void:
		for i in points.size():
			var a := 0.5 + 0.5 * sin(_t * 2.4 + i * 2.1)
			var p: Vector2 = points[i] * k
			var s := (4.0 + 5.0 * a) * k
			var star := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.3, -s * 0.3), p + Vector2(s, 0), p + Vector2(s * 0.3, s * 0.3),
				p + Vector2(0, s), p + Vector2(-s * 0.3, s * 0.3), p + Vector2(-s, 0), p + Vector2(-s * 0.3, -s * 0.3)])
			draw_colored_polygon(star, Color(1, 1, 1, 0.35 + 0.55 * a))


## The pattern on the back of a card. "diamonds": rows of small diamonds with an inner border, like
## a playing card. "rays": a golden star burst, for event cards. "hazard": diagonal warning stripes
## and a striped border, for penalty cards.
class BackPattern extends Control:
	var _color: Color
	var _style: String

	func _init(color: Color, style := "diamonds") -> void:
		_color = color
		_style = style
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		match _style:
			"rays":
				_rays()
			"hazard":
				_hazard()
			_:
				_diamonds()

	func _diamonds() -> void:
		var step := 38.0
		var half := step / 2.0
		var row := 0
		var y := 0.0
		while y < size.y + step:
			var x := -half * (row % 2)
			while x < size.x + step:
				if x > 32.0 and x < size.x - 32.0 and y > 32.0 and y < size.y - 32.0:
					var pts := PackedVector2Array([Vector2(x, y - 12), Vector2(x + 10, y), Vector2(x, y + 12), Vector2(x - 10, y)])
					draw_colored_polygon(pts, Color(_color, 0.22))
				x += step
			y += half
			row += 1

	## A sunburst of wedges around the centre, with small stars scattered between the rays.
	func _rays() -> void:
		var c := size / 2.0
		var reach := size.length()
		var n := 24
		for k in n:
			if k % 2 == 1:
				continue
			var a0 := TAU * float(k) / n
			var a1 := TAU * float(k + 1) / n
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * reach, c + Vector2(cos(a1), sin(a1)) * reach]), Color(_color, 0.3))
		for k in 14:
			var a := TAU * float(k) / 14.0 + 0.2
			var r := 150.0 + 60.0 * float(k % 3)
			var p := c + Vector2(cos(a), sin(a)) * r * Vector2(0.8, 1.15)
			if p.x > 40.0 and p.x < size.x - 40.0 and p.y > 40.0 and p.y < size.y - 40.0:
				_star(p, 7.0 + 3.0 * float(k % 2))

	func _star(p: Vector2, r: float) -> void:
		var pts := PackedVector2Array()
		for i in 8:
			var a := -PI / 2.0 + float(i) * PI / 4.0
			var rr := r if i % 2 == 0 else r * 0.42
			pts.append(p + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, Color(GOLD_LINE, 0.55))

	## Diagonal stripes across the whole card and a thick striped band around the edge.
	func _hazard() -> void:
		var step := 44.0
		var x := -size.y
		while x < size.x:
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + step * 0.5, 0), Vector2(x + step * 0.5 + size.y, size.y), Vector2(x + size.y, size.y)]), Color(_color, 0.18))
			x += step
		var yellow := Color("#F2C21C", 0.85)
		for k in 6:
			var p := Vector2(size.x * (0.2 + 0.12 * float(k)), size.y * (0.14 if k % 2 == 0 else 0.86))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12), p + Vector2(11, 9), p + Vector2(-11, 9)]), Color(yellow, 0.5))
