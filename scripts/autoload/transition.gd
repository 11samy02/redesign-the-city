extends CanvasLayer
## Scene changes for the whole game: the screen fades to the dark background colour, the scene is
## swapped while it is covered, and the new scene fades in. Every change of scene goes through
## `change_scene`. Input is blocked only while the fade runs, the layer ignores the mouse otherwise.

const UiKit = preload("res://scripts/ui/ui_kit.gd")

## Emitted when the screen is fully covered (the old scene is still showing underneath).
signal covered
## Emitted when the new scene is fully visible and clickable again.
signal revealed

const COVER_TIME := 0.3
const REVEAL_TIME := 0.4

var _fade: ColorRect
var _busy := false
var _tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = UiKit.INK_DEEP
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)


func is_busy() -> bool:
	return _busy


## Fades out, loads `path`, then fades the new scene in. Ignored while a change is running.
func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0, COVER_TIME, Tween.EASE_IN)
	covered.emit()
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Transition: could not load %s (error %d)" % [path, err])
	# the old scene is freed at the end of this frame and the new one is ready a frame later
	for k in 2:
		await get_tree().process_frame
	await _fade_to(0.0, REVEAL_TIME, Tween.EASE_OUT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	revealed.emit()


func _fade_to(alpha: float, seconds: float, ease_type: Tween.EaseType) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_fade, "modulate:a", alpha, seconds).set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	await _tween.finished
