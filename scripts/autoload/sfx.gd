extends Node
## Procedurally synthesised sound effects, so the game ships without audio files.

const RATE := 22050

var muted := false
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# Each note: [frequency, seconds]. 0 Hz is silence.
	_streams["hover"] = _synth([[1500, 0.025]], "sine", 0.05)
	_streams["click"] = _synth([[760, 0.05]], "triangle", 0.22)
	_streams["pick"] = _synth([[520, 0.05], [780, 0.08]], "triangle", 0.22)
	_streams["cancel"] = _synth([[600, 0.05], [420, 0.08]], "triangle", 0.18)
	_streams["place"] = _mix(_synth([[150, 0.14]], "sine", 0.55, 18.0), _synth([[0, 0.05]], "noise", 0.25, 40.0))
	_streams["coin"] = _synth([[1320, 0.06], [1760, 0.2]], "sine", 0.22, 9.0)
	_streams["error"] = _synth([[220, 0.09], [175, 0.14]], "square", 0.12)
	_streams["whoosh"] = _sweep(0.28, 0.18)
	_streams["turn"] = _synth([[523, 0.08], [659, 0.08], [784, 0.18]], "triangle", 0.22, 5.0)
	_streams["tick"] = _synth([[900, 0.04]], "sine", 0.14, 30.0)
	_streams["minus"] = _synth([[330, 0.08], [247, 0.16]], "triangle", 0.2, 8.0)
	_streams["fanfare"] = _synth([[523, 0.12], [659, 0.12], [784, 0.12], [1047, 0.5]], "triangle", 0.25, 2.5)
	_streams["pop"] = _synth([[880, 0.03], [1320, 0.05]], "sine", 0.18, 20.0)


func _exit_tree() -> void:
	for p in _players:
		p.stop()
		p.stream = null


func play(name: String, pitch := 1.0) -> void:
	if muted or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.play()


func _samples(notes: Array, wave: String, volume: float, decay: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var phase := 0.0
	for note in notes:
		var freq: float = note[0]
		var n := int(RATE * float(note[1]))
		for i in n:
			var t := float(i) / RATE
			var env := minf(1.0, t / 0.004) * exp(-decay * t)
			phase += freq / RATE
			var s := 0.0
			match wave:
				"sine": s = sin(TAU * phase)
				"triangle": s = 1.0 - 4.0 * absf(fposmod(phase, 1.0) - 0.5)
				"square": s = 0.6 if fposmod(phase, 1.0) < 0.5 else -0.6
				"noise": s = randf_range(-1.0, 1.0)
			out.append(s * env * volume)
	return out


func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _synth(notes: Array, wave: String, volume: float, decay := 12.0) -> AudioStreamWAV:
	return _to_stream(_samples(notes, wave, volume, decay))


func _mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var n := maxi(a.data.size(), b.data.size()) / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var va := a.data.decode_s16(i * 2) / 32767.0 if i * 2 < a.data.size() else 0.0
		var vb := b.data.decode_s16(i * 2) / 32767.0 if i * 2 < b.data.size() else 0.0
		out[i] = va + vb
	return _to_stream(out)


## Filtered noise sweep for flying tiles.
func _sweep(seconds: float, volume: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var k := lerpf(0.02, 0.3, sin(t * PI))
		y += k * (randf_range(-1.0, 1.0) - y)
		out[i] = y * sin(t * PI) * volume * 3.0
	return _to_stream(out)
