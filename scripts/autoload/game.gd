extends Node
## Holds the seat setup, the running game and player options between scenes.
## Scene changes go through the Transition autoload.

const GameState = preload("res://scripts/core/game_state.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const MatLibrary = preload("res://scripts/core/mat_library.gd")

const TITLE_SCENE := "res://scenes/title.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const FINAL_SCENE := "res://scenes/final.tscn"
const SETTINGS_PATH := "user://settings.cfg"

## Pause between bot actions, by the "bot speed" option (slow, normal, fast).
## Slow, Normal, Fast, Instant. Instant does not show what the bots do at all.
const BOT_DELAY := [1.7, 1.0, 0.45, 0.0]

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
	"antialiasing": true,
	## Path of the prefixed player mat everyone plays on (see MatLibrary); "" is an empty mat.
	"mat": "",
}

func _ready() -> void:
	theme = UiKit.build_theme()
	_load_settings()
	apply_settings()
	# Automated playtest: godot --path . -- --tour=<dir> (see tests/visual_tour.gd)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tour="):
			var tour: Node = load("res://tests/visual_tour.gd").new()
			tour.out_dir = arg.substr(7)
			add_child(tour)
		elif arg == "--probe=popups":
			add_child(load("res://tests/popup_probe.gd").new())
		elif arg == "--probe=cards":
			add_child(load("res://tests/card_probe.gd").new())
		elif arg == "--probe=gold":
			add_child(load("res://tests/gold_probe.gd").new())
		elif arg == "--probe=close":
			add_child(load("res://tests/close_probe.gd").new())
		elif arg == "--probe=click":
			add_child(load("res://tests/click_probe.gd").new())
		elif arg == "--probe=shots":
			add_child(load("res://tests/shot_probe.gd").new())
		elif arg == "--probe=rules":
			add_child(load("res://tests/rules_probe.gd").new())
		elif arg == "--probe=replace":
			add_child(load("res://tests/replace_probe.gd").new())
		elif arg == "--probe=title":
			add_child(load("res://tests/title_probe.gd").new())
		elif arg == "--probe=matedit":
			add_child(load("res://tests/mat_editor_probe.gd").new())
		elif arg == "--probe=final":
			add_child(load("res://tests/final_probe.gd").new())


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
	get_viewport().msaa_2d = Viewport.MSAA_4X if settings["antialiasing"] else Viewport.MSAA_DISABLED


func bot_delay() -> float:
	return BOT_DELAY[clampi(settings["bot_speed"], 0, BOT_DELAY.size() - 1)]


## True when bots should play without being watched: the bot speed option is Instant.
func bot_instant() -> bool:
	return settings["bot_speed"] >= BOT_DELAY.size() - 1


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
	state.setup(names, colors, -1, bots, MatLibrary.by_path(settings["mat"]))


## Changes the scene with the tile transition. Ignored while a change is already running.
func goto(scene_path: String) -> void:
	Transition.change_scene(scene_path)
