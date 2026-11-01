extends Node
## Sound effects. Each name maps to res://assets/sfx/<name>.wav, already trimmed and level-matched.

const NAMES := ["hover", "click", "pick", "cancel", "place", "coin", "coin_land", "error",
		"whoosh", "turn", "start", "round", "tick", "minus", "fanfare", "pop"]
## Small random pitch spread so repeated sounds don't feel mechanical.
const JITTER := {"click": 0.04, "place": 0.06, "coin": 0.03, "pick": 0.05, "whoosh": 0.06, "hover": 0.05}

var muted := false
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for n in NAMES:
		_streams[n] = load("res://assets/sfx/%s.wav" % n)


func _exit_tree() -> void:
	for p in _players:
		p.stop()
		p.stream = null


func play(name: String, pitch := 1.0) -> void:
	if muted or _streams.get(name) == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	var j: float = JITTER.get(name, 0.0)
	p.pitch_scale = pitch * randf_range(1.0 - j, 1.0 + j)
	p.play()
