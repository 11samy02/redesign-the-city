extends Node
## Holds the seat setup, the running game and player options between scenes,
## plus fade transitions.

const GameState = preload("res://scripts/core/game_state.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

const TITLE_SCENE := "res://scenes/title.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const FINAL_SCENE := "res://scenes/final.tscn"
const SETTINGS_PATH := "user://settings.cfg"

## Pause between bot actions, by the "bot speed" option (slow, normal, fast).
const BOT_DELAY := [1.7, 1.0, 0.45]

## [{ "name": String, "color": int, "bot": int }] for 2-4 seats, edited on the title screen.
## bot is 0 for a human, otherwise Bot.EASY / MEDIUM / HARD.
var seats: Array = [
	{"name": "Player 1", "color": 0, "bot": 0},
	{"name": "Player 2", "color": 1, "bot": 0},
]
var state: GameState
var theme: Theme

## Player options, saved to user://settings.cfg.
var settings := {
	"fullscreen": false,
	"vsync": true,
	"volume": 0.8,
	"muted": false,
	"bot_speed": 1,
	"fast_animations": false,
}

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	theme = UiKit.build_theme()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = UiKit.INK_DEEP
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	_load_settings()
	apply_settings()
	# Automated playtest: godot --path . -- --tour=<dir> (see tests/visual_tour.gd)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tour="):
			var tour: Node = load("res://tests/visual_tour.gd").new()
			tour.out_dir = arg.substr(7)
			add_child(tour)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_setting("fullscreen", not settings["fullscreen"])
		get_viewport().set_input_as_handled()


func set_setting(key: String, value) -> void:
	settings[key] = value
	apply_settings()
	_save_settings()


func apply_settings() -> void:
	var fs: bool = settings["fullscreen"]
	var mode := DisplayServer.window_get_mode()
	if fs and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fs and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	var vol: float = settings["volume"]
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.0001)))
	AudioServer.set_bus_mute(0, vol <= 0.0)
	Sfx.muted = settings["muted"]
	Engine.time_scale = 1.6 if settings["fast_animations"] else 1.0


func bot_delay() -> float:
	return BOT_DELAY[clampi(settings["bot_speed"], 0, 2)]


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in settings:
		settings[key] = cfg.get_value("options", key, settings[key])


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings:
		cfg.set_value("options", key, settings[key])
	cfg.save(SETTINGS_PATH)


func human_count() -> int:
	var n := 0
	for s in seats:
		if s.get("bot", 0) == 0:
			n += 1
	return n


func new_game() -> void:
	state = GameState.new()
	var names: Array = []
	var colors: Array = []
	var bots: Array = []
	for s in seats:
		names.append(s["name"])
		colors.append(s["color"])
		bots.append(s.get("bot", 0))
	state.setup(names, colors, -1, bots)


func goto(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.35)
	await tw.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	tw = create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.45)
	await tw.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
