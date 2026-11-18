extends Node

var muted := false
var ready_for_sound := false
var sounds: Dictionary = {}
var players: Array[AudioStreamPlayer] = []

func _exit_tree() -> void:
	for player in players:
		player.stop()
		player.stream = null
	sounds.clear()

func _ready() -> void:
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -21.0
		add_child(player)
		players.append(player)
	for kind in ["hit", "hurt", "pickup", "coin", "high", "crash"]:
		sounds[kind] = _wave(kind)

func play_sound(kind: String) -> void:
	if muted or not ready_for_sound or not sounds.has(kind):
		return
	for player in players:
		if not player.playing:
			player.stream = sounds[kind]
			player.play()
			return

func _wave(kind: String) -> AudioStreamWAV:
	var length := 0.15
	if kind == "high": length = 0.34
	if kind == "crash": length = 0.28
	var rate := 22050
	var count := int(float(rate) * length)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	for index in range(count):
		var ratio := float(index) / float(count)
		var frequency := 180.0
		match kind:
			"hit": frequency = lerpf(180.0, 60.0, ratio)
			"hurt": frequency = lerpf(220.0, 80.0, ratio)
			"pickup": frequency = 800.0 if ratio < 0.5 else 1200.0
			"coin": frequency = 493.88 if ratio < 0.5 else 659.25
			"high": frequency = [440.0, 554.37, 659.25, 880.0][mini(3, int(ratio * 4.0))]
			"crash": frequency = lerpf(440.0, 110.0, ratio)
		phase += frequency / float(rate)
		var value := (1.0 if fmod(phase, 1.0) < 0.5 else -1.0)
		if kind in ["hurt", "crash"]: value = 2.0 * fmod(phase, 1.0) - 1.0
		value *= minf(ratio * 30.0, 1.0) * (1.0 - ratio) * 0.7
		bytes.encode_s16(index * 2, int(value * 32767.0))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	wave.data = bytes
	return wave
