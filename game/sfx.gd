extends Node

## Chiptune blips synthesised once into AudioStreamWAVs (square/triangle/saw with
## exponential decay), ported from the prototype's WebAudio tones.

const RATE := 22050
const VOICES := 8

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## type: press | collect | sell | buy | deny | unlock | tick. `p` is the combo/streak step.
func play(type: String, p := 0) -> void:
	if Game.mute:
		return
	var key := "%s%d" % [type, p]
	if not _cache.has(key):
		_cache[key] = _render(_tones(type, p))
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _cache[key]
	player.play()


## Each tone: [freq, dur, wave, vol, at, slide_to]
func _tones(type: String, p: int) -> Array:
	match type:
		"press": return [[150.0 + mini(p, 20) * 6.0, 0.09, "square", 0.05, 0.0, 55.0]]
		"collect": return [[520.0 * pow(2.0, mini(p, 24) / 12.0), 0.07, "triangle", 0.08, 0.0, 0.0]]
		"sell": return [[988.0, 0.07, "square", 0.035, 0.0, 0.0], [1319.0, 0.2, "square", 0.035, 0.06, 0.0]]
		"buy": return [523.0, 659.0, 784.0].map(func(f): return [f, 0.1, "square", 0.04, [523.0, 659.0, 784.0].find(f) * 0.05, 0.0])
		"deny": return [[120.0, 0.16, "sawtooth", 0.05, 0.0, 80.0]]
		"unlock": return [523.0, 659.0, 784.0, 1047.0].map(func(f): return [f, 0.14, "triangle", 0.07, [523.0, 659.0, 784.0, 1047.0].find(f) * 0.08, 0.0])
		"tick": return [[1800.0, 0.02, "square", 0.015, 0.0, 0.0]]
	return []


func _render(tones: Array) -> AudioStreamWAV:
	var length := 0.0
	for t: Array in tones:
		length = maxf(length, t[4] + t[1] + 0.02)
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for t: Array in tones:
		var f0: float = t[0]
		var dur: float = t[1]
		var vol: float = t[3] * 4.0  # WebAudio gains are quiet; scale to a usable level
		var s0 := int(t[4] * RATE)
		var phase := 0.0
		for s in int(dur * RATE):
			var k := float(s) / (dur * RATE)
			var f: float = f0 * pow(t[5] / f0, k) if t[5] > 0.0 else f0
			phase = fmod(phase + f / RATE, 1.0)
			var w := 0.0
			match t[2]:
				"square": w = 1.0 if phase < 0.5 else -1.0
				"triangle": w = 4.0 * absf(phase - 0.5) - 1.0
				"sawtooth": w = 2.0 * phase - 1.0
			if s0 + s < n:
				buf[s0 + s] += w * vol * pow(0.0001 / vol, k)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for s in n:
		bytes.encode_s16(s * 2, int(clampf(buf[s], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav
