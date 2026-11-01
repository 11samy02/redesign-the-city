extends RefCounted
## The motion every big card on screen shares (the hidden circumstance card, the event and penalty
## cards), so they all move exactly alike: smooth supersampled edges, a slide-in with a little tilt, the
## gem popping in, the rule text fading up, the foil sheen sweeping across, the card leaning towards the
## cursor and lifting away when it closes.
##
## The host overlay is a Control with a `_intro_rotation` float property (the card's resting tilt is
## added to it), and `stage` is the card-sized control the card is drawn in.

## Room around the card inside its viewport for the drop shadow and the gem that overhangs the corner.
const SURFACE_MARGIN := 40.0


## The card is drawn into its own viewport at several times the screen resolution (with MSAA) and
## shown as a texture inside `stage`. Edges of a tilted card are then smoothed by downsampling instead
## of being stair-stepped, which MSAA alone does not fix for clipped panels, thin lines and text.
## Returns the card-sized control the faces go into, inside that viewport.
static func supersampled_surface(host: Control, stage: Control, card_w: float, card_h: float) -> Control:
	var logical := Vector2(card_w, card_h) + Vector2.ONE * SURFACE_MARGIN * 2.0
	var screen_scale := host.get_window().get_final_transform().get_scale().x
	var factor := clampf(ceilf(screen_scale * 1.1), 2.0, 4.0)
	var sub := SubViewport.new()
	sub.size = Vector2i((logical * factor).round())
	sub.size_2d_override = Vector2i(logical)
	sub.size_2d_override_stretch = true
	sub.transparent_bg = true
	sub.msaa_2d = Viewport.MSAA_4X
	sub.gui_disable_input = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.add_child(sub)
	var shown := TextureRect.new()
	shown.texture = sub.get_texture()
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shown)
	shown.position = -Vector2.ONE * SURFACE_MARGIN
	shown.size = logical
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.position = Vector2.ONE * SURFACE_MARGIN
	content.size = Vector2(card_w, card_h)
	sub.add_child(content)
	return content


## Hides the parts that pop in after the card is shown (gem, rule text) until it is their turn.
static func hide_parts(front: Control) -> void:
	var gem: Control = front.get_meta("gem")
	var rules: Control = front.get_meta("rules")
	gem.pivot_offset = gem.size / 2.0
	gem.scale = Vector2.ZERO
	rules.modulate.a = 0.0


## The card slides up from below, growing and straightening, while the overlay fades in.
static func intro(host: Control, stage: Control) -> Tween:
	stage.pivot_offset = stage.size / 2.0
	stage.scale = Vector2(0.78, 0.78)
	var rest_y := stage.position.y
	stage.position.y = rest_y + 90.0
	host.set("_intro_rotation", -0.09)
	var tw := host.create_tween().set_parallel()
	tw.tween_property(host, "modulate:a", 1.0, 0.25)
	tw.tween_property(stage, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stage, "position:y", rest_y, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(host, "_intro_rotation", 0.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh")
	return tw


## After the card is face up: the gem pops in, the rule fades up, the buttons in `fades` fade in and the
## foil sheen starts sweeping. Pass `tw` (a parallel tween) to run it on a tween you control.
static func bring_to_life(host: Control, front: Control, fades: Array = [], tw: Tween = null) -> Tween:
	var gem: Control = front.get_meta("gem")
	var rules: Control = front.get_meta("rules")
	var sheen: Control = front.get_meta("sheen")
	gem.pivot_offset = gem.size / 2.0
	if tw == null:
		tw = host.create_tween().set_parallel()
	tw.tween_property(gem, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rules, "modulate:a", 1.0, 0.5).set_delay(0.3)
	for node in fades:
		tw.tween_property(node, "modulate:a", 1.0, 0.35).set_delay(0.45)
	var band: Control = sheen.get_meta("band")
	var sweep := host.create_tween().set_loops()
	sweep.tween_interval(0.5)
	sweep.tween_property(band, "position:x", front.size.x + 120.0, 1.7).from(-300.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sweep.tween_interval(2.4)
	return tw


## The card leans a little toward the cursor. Returns the new lean; call it every frame with the last one.
static func lean(host: Control, stage: Control, current: float, intro_rotation: float, delta: float) -> float:
	var vp := host.get_viewport_rect().size
	var mouse := host.get_viewport().get_mouse_position()
	var target := clampf((mouse.x - vp.x / 2.0) / (vp.x / 2.0), -1.0, 1.0) * 0.032
	var now := lerpf(current, target, clampf(delta * 6.0, 0.0, 1.0))
	stage.pivot_offset = stage.size / 2.0
	stage.rotation = now + intro_rotation
	return now


## The card lifts and fades away. Pass `tw` (a parallel tween) to run it on a tween you control.
static func lift_away(host: Control, stage: Control, tw: Tween = null) -> Tween:
	if tw == null:
		tw = host.create_tween().set_parallel()
	tw.tween_property(host, "modulate:a", 0.0, 0.3)
	tw.tween_property(stage, "scale", Vector2.ONE * 1.08, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(stage, "position:y", stage.position.y - 70.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh")
	return tw
