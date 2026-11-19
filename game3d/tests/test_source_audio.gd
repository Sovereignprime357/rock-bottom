extends SceneTree
const Audio = preload("res://scripts/source_audio.gd")
const Ambient = preload("res://scripts/ambient_audio.gd")
const State = preload("res://scripts/game_state.gd")
class ObservedAudio:
	extends "res://scripts/source_audio.gd"
	var trace: Array[Dictionary] = []
	func _start_note(note: Dictionary) -> void:
		if ready_for_sound and not muted: trace.append({"type":note.type,"at":_wall})
		super._start_note(note)
class ScriptedAmbient:
	extends "res://scripts/ambient_audio.gd"
	var rolls: Array = []
	var cursor: int = 0
	func _roll() -> float:
		var value: float = float(rolls[cursor]) if cursor < rolls.size() else .75
		cursor += 1; return value
var checks: int = 0
var groups: int = 0
var plans_checked: int = 0
var ambient_checked: int = 0
var failures: Array[String] = []
var fixture: Dictionary
var sound: ObservedAudio
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _same(actual: Variant,expected: Variant,path: String) -> void:
	if (actual is int or actual is float) and (expected is int or expected is float):
		_check(absf(float(actual)-float(expected)) < 0.000001,path+" actual="+str(actual)+" expected="+str(expected)); return
	if actual is Dictionary and expected is Dictionary:
		_check(actual.size() == expected.size(),path+" keys")
		for key: String in expected:
			_check(actual.has(key),path+" has "+key)
			if actual.has(key): _same(actual[key],expected[key],path+"."+key)
		return
	if actual is Array and expected is Array:
		_check(actual.size() == expected.size(),path+" length")
		for index: int in range(mini(actual.size(),expected.size())): _same(actual[index],expected[index],path+"[%d]"%index)
		return
	_check(actual == expected,path+" actual="+str(actual)+" expected="+str(expected))
func _plans() -> void:
	_check(Audio.IDS.size() == 24 and fixture.plans.size() == 192,"24 source recipes and8 exact variation banks")
	for item: Dictionary in fixture.plans:
		var plan: Array[Dictionary] = Audio.recipe(item.kind,int(item.bank))
		_same(plan,item.notes,"source plan %s/%d"%[item.kind,item.bank])
		plans_checked += 1
		for note: Dictionary in plan:
			_check(note.duration > 0 and note.volume > 0 and note.volume <= .12,"source note duration/conservative gain")
			if note.type == "tone": _check(note.frequency > 0 and note.frequency < Audio.RATE*.5,"all source frequencies below synthesis Nyquist")
	_check(Audio.recipe("unknown").is_empty() and Audio.recipe("hit",-1).is_empty() and Audio.recipe("hit",8).is_empty(),"unknown recipe/bank fails closed")
	var detached: Array[Dictionary] = Audio.recipe("hit"); detached[0].frequency = -900
	_check(Audio.recipe("hit")[0].frequency == 180,"recipe inspection cannot mutate authored definitions")
	groups += 1
func _pcm_and_cache() -> void:
	var before: Dictionary = sound.metrics()
	_check(before.recipes == 24 and before.voices == 32 and before.clips > 24 and before.clips <= 512,"fixed recipe/resource/voice bounds")
	_check(before.pcm_bytes > 0 and before.pcm_bytes < 8*1024*1024,"bounded PCM bank under8MiB")
	var resources: Dictionary = {}; var hashes: Dictionary = {}
	for key: String in sound._clips:
		var wave: AudioStreamWAV = sound._clips[key]
		resources[key] = wave.get_instance_id(); hashes[key] = hash(wave.data)
		_check(wave.format == AudioStreamWAV.FORMAT_16_BITS and wave.mix_rate == 22050 and not wave.stereo and wave.data.size()%2 == 0,"cache is exact mono16/22050 PCM")
		# Authored parameters are encoded in the cache key, independent of PCM writer.
		var parameters: Array = JSON.parse_string(key)
		var is_tone: bool = parameters[0] == "tone"
		var count: int = int(22050.0*(float(parameters[2])+(0.02 if is_tone else 0.0)))
		_check(wave.data.size() == count*2,"cached primitive has source duration and20ms oscillator tail")
		var peak: float = 0.0
		for index: int in range(count): peak = maxf(peak,absf(float(wave.data.decode_s16(index*2))/32767.0))
		_check(peak > 0 and peak <= float(parameters[4])+1.0/32767.0,"PCM is audible/nonzero and stays inside authored gain")
		var tail: float = absf(float(wave.data.decode_s16((count-1)*2))/32767.0)
		_check(tail <= .0002,"source decay reaches near-zero tail")
		for fraction: float in [.1,.4,.8]:
			var index: int = mini(count-1,int(float(count)*fraction))
			var sample: float = absf(float(wave.data.decode_s16(index*2))/32767.0)
			var gain: float = float(parameters[4])
			if is_tone: gain *= pow(.0001/gain,minf(float(index)/22050.0/float(parameters[2]),1.0))
			else: gain *= 1.0-float(index)/float(count)
			_check(sample <= gain+1.0/32767.0,"sample follows source exponential/linear envelope")
	# Frequency property uses phase differences, not a replay of the waveform branch.
	for note: Dictionary in Audio.recipe("copSiren"):
		for fraction: float in [.1,.5,.9]:
			var time: float = float(note.duration)*fraction; var epsilon: float = .000001
			var measured: float = (Audio.phase_cycles(note.frequency,note.slide,note.duration,time+epsilon)-Audio.phase_cycles(note.frequency,note.slide,note.duration,time-epsilon))/(2*epsilon)
			var expected: float = float(note.frequency)*pow(float(note.slide)/float(note.frequency),fraction)
			_check(absf(measured-expected) < .001,"analytic pitch follows source exponential slide")
	var noise: Dictionary = Audio.recipe("kick")[1]
	_check(Audio.pcm(noise,17) == Audio.pcm(noise,17) and Audio.pcm(noise,17) != Audio.pcm(noise,18),"noise is deterministic and varied independent of engine/global RNG")
	sound.ready_for_sound = false
	for kind: String in Audio.IDS: sound.play_sound(kind)
	sound.advance_wall(2000)
	sound.prepare()
	_check(sound.metrics().clips == before.clips and sound.metrics().pcm_bytes == before.pcm_bytes,"repeated prepare/play cannot grow cache")
	for key: String in resources:
		_check(sound._clips[key].get_instance_id() == resources[key] and hash(sound._clips[key].data) == hashes[key],"playback keeps shared PCM resources immutable")
	groups += 1
func _stop_voices() -> void:
	for voice: AudioStreamPlayer in sound.players: voice.stop(); voice.stream = null
func _wall_gates() -> void:
	var base: float = 10000
	for item: Dictionary in fixture.gates:
		_stop_voices(); sound.muted = true; sound.advance_wall(base)
		sound.trace.clear(); sound.ready_for_sound = item.ready; sound.muted = item.muted
		_check(sound.play_sound(item.kind),"source gate recipe accepted:"+item.id)
		var times: Array[float] = [0.0]
		for note: Dictionary in Audio.recipe(item.kind):
			if note.deferred and float(note.offset_ms) not in times: times.append(float(note.offset_ms))
		for change: Dictionary in item.changes:
			if float(change.at) not in times: times.append(float(change.at))
		times.sort()
		for time: float in times:
			sound.advance_wall(base+time)
			for change: Dictionary in item.changes:
				if float(change.at) != time: continue
				if change.has("ready"): sound.ready_for_sound = change.ready
				if change.has("muted"): sound.muted = change.muted
		var actual: Array[Dictionary] = sound.trace.duplicate(true)
		for row: Dictionary in actual: row.at -= base
		_same(actual,item.starts,"unchanged primitive readiness/mute timeline:"+item.id)
		_check(sound.metrics().queued == 0,"all scheduled notes consumed once:"+item.id)
		base += 2000
	# Delayed notes do not depend on model mode, and duplicate wall updates cannot replay.
	_stop_voices(); sound.ready_for_sound = true; sound.muted = false; sound.advance_wall(base); sound.trace.clear()
	sound.play_sound("pickup"); sound.advance_wall(base+1000)
	_check(sound.trace.size() == 2 and sound.trace[1].at == base+1000,"late callback starts once at wall time rather than gameplay delta")
	var counts: Dictionary = sound.metrics(); sound.advance_wall(base+1000)
	_check(sound.metrics() == counts,"equal wall time cannot replay consumed notes")
	_check(not sound.advance_wall(base) and not sound.advance_wall(NAN) and not sound.advance_wall(INF) and not sound.play_sound("high"),"backward/nonfinite wall and slice alias fail closed")
	_check(sound.metrics() == counts,"invalid wall/ID does not mutate queue or counters")
	groups += 1
func _bounds() -> void:
	_stop_voices(); sound.ready_for_sound = true; sound.muted = false; sound.trace.clear()
	var before: Dictionary = sound.metrics()
	for index: int in range(20): sound.play_sound("carDoor")
	_check(sound.metrics().started-before.started == 32 and sound.metrics().dropped_voice-before.dropped_voice == 8,"32 real voices preserve existing notes and drop newest overflow")
	var streams: Array[int] = []
	for voice: AudioStreamPlayer in sound.players: streams.append(voice.stream.get_instance_id())
	sound.play_sound("hit")
	for index: int in range(sound.players.size()): _check(sound.players[index].stream.get_instance_id() == streams[index],"overflow cannot replace an existing audible voice")
	_stop_voices(); sound.ready_for_sound = false; before = sound.metrics()
	for index: int in range(70): sound.play_sound("rockUp")
	_check(sound.metrics().queued == 256 and sound.metrics().dropped_queue-before.dropped_queue == 24,"bounded256 pending notes drop newest deterministically")
	var first_serial: int = sound._pending[0].serial; var max_serial: int = 0
	for pending: Dictionary in sound._pending: max_serial = maxi(max_serial,pending.serial)
	_check(max_serial-first_serial == 255,"overflow retains original256 capabilities in deterministic order")
	sound.advance_wall(1000000)
	_check(sound.metrics().queued == 0 and sound.metrics().suppressed-before.suppressed == 256,"large wall delta drains bounded queue exactly once through current gate")
	for voice: AudioStreamPlayer in sound.players: _check(voice.volume_db == Audio.MASTER_DB,"consistent conservative full-audio master gain")
	groups += 1
func _ambient_oracle() -> void:
	for item: Dictionary in fixture.ambient:
		var state := State.new(); var spec: Dictionary = item.setup
		state.s.mode = "playing"; state.s.dayTime = spec.get("time",.35); state.p.wanted = spec.get("wanted",0)
		state.s.flags.introDone = false; state.s.flags.silenceUntilT = 999999999999999.0 if spec.get("silence",false) else 0
		if spec.has("timer"): state.s.ambientT = spec.timer
		else: state.s.erase("ambientT")
		var owner := ScriptedAmbient.new(state); owner.rolls = spec.rolls
		var sounds: Array[String] = []; var seed: int = state.rng_seed
		for step: Dictionary in item.steps:
			state.s.dayTime = step.time # Core already performs source day timing before this seam.
			_check(owner.tick_active(step.dt),"ambient source active tick:"+spec.id)
			for event: Dictionary in state.drain_events():
				if event.kind == "sound": sounds.append(event.payload.id)
			_same(state.s.ambientT,step.timer,"source ambient clock:"+spec.id)
			_same(sounds,step.sounds,"source ambient choice:"+spec.id)
			_check(owner.cursor == int(step.draws),"isolated source scheduler draw count:"+spec.id)
			_check(state.rng_seed == seed,"ambient never consumes authoritative gameplay RNG")
		ambient_checked += 1
	groups += 1
func _ambient_properties() -> void:
	var state := State.new(); var owner := Ambient.new(state,42)
	state.s.mode = "playing"; state.s.ambientT = 1234
	_check(state.fresh() and owner.reset_session("fresh") and state.s.ambientT == fixture.lifecycle.fresh,"actual fresh retains source session ambient timer")
	var save: Dictionary = state.snapshot()
	_check(not save.state.has("ambientT"),"ambient timer is not a persisted authority")
	_check(state.restore(save).ok and owner.reset_session("restore") and state.s.ambientT == fixture.lifecycle.restore,"actual restore retains source session ambient timer")
	var before: Dictionary = state.snapshot(); var timer: float = state.s.ambientT; var metrics: Dictionary = owner.metrics()
	for dt: float in [0,-1,50.01,NAN,INF]: _check(not owner.tick_active(dt),"invalid ambient delta refuses")
	_check(state.snapshot() == before and state.s.ambientT == timer and owner.metrics() == metrics,"invalid deltas are atomic")
	for replacement: String in ["player","state"]:
		if replacement == "player": state.p = state.p.duplicate(true)
		else: state.s = state.s.duplicate(true)
		before = state.snapshot(); timer = state.s.ambientT
		_check(not owner.tick_active(1) and state.snapshot() == before and state.s.ambientT == timer,"unexpected epoch replacement refuses:"+replacement)
		_check(owner.reset_session("restore"),"explicit replacement reset rebinds")
	state.s.mode = "dialogue"; state.s.ambientT = 1
	var seed: int = state.rng_seed
	_check(owner.tick_active(1) and state.s.ambientT >= 3500 and state.s.ambientT < 8000,"accepted current update remainder has no new mid-step mode gate")
	_check(owner.metrics().draws == 2 and state.rng_seed == seed,"real cosmetic generator independent of GameState")
	owner.reset_session("fresh")
	_check(owner.metrics().draws == 2,"same-session reset does not rewind cosmetic random stream")
	var cold := State.new(); cold.s.erase("ambientT"); var fresh_owner := Ambient.new(cold)
	_check(not cold.s.has("ambientT") and fresh_owner.tick_active(1) and cold.s.ambientT == 3999,"cold missing source timer starts4000 only at first tick")
	for row: Dictionary in fixture.coupling:
		_check(int(row.draws) == (int(row.rate)*8/100 if row.ready and not row.muted else 0),"original source noise coupling explicitly characterized")
	_check(fixture.coupling[2].draws != fixture.coupling[6].draws,"source sample rate would change shared RNG; adaptation kept separate")
	groups += 1
func _run() -> void:
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/audio_reference.json"))
	sound = ObservedAudio.new(); root.add_child(sound); sound.advance_wall(0)
	_plans(); _pcm_and_cache(); _wall_gates(); _bounds(); _ambient_oracle(); _ambient_properties()
	_check(groups == 6 and plans_checked == 192 and ambient_checked == 94,"all6groups192banks94sourceambient paths completed")
	_stop_voices(); await create_timer(.1).timeout; sound.free(); sound = null
	await process_frame; await process_frame
	if failures.is_empty():
		print("3D SOURCE AUDIO GATE: PASS (%d checks;192recipe banks/6gate timelines/94ambient cases)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D SOURCE AUDIO GATE: FAIL (%d/%d checks;groups%d/6 plans%d ambient%d)" % [failures.size(),checks,groups,plans_checked,ambient_checked]); quit(1)
