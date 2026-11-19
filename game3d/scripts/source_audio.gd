class_name RockBottomSourceAudio
extends Node
## Full-scene audio only. The slice's synth.gd remains unchanged.
const IDS := ["hit","hurt","pickup","coin","rockUp","crash","death","rankUp","dialogue","copSiren","bossRoar","glassBreak","cricket","traffic","carDoor","cough","dogBark","windup","bottleThrow","bottleHit","holyWaterThrow","holyWaterHit","radio","kick"]
const RATE := 22050
const BANKS := 8
const VOICES := 32
const MAX_NOTES := 256
const MASTER_DB := -12.0
var muted: bool = false
var ready_for_sound: bool = false
var players: Array[AudioStreamPlayer] = []
var _clips: Dictionary = {}
var _plans: Dictionary = {}
var _pending: Array[Dictionary] = []
var _wall: float = 0.0
var _wall_started: bool = false
var _variation_seed: int = 0x534f554e
var _serial: int = 0
var _started: int = 0
var _suppressed: int = 0
var _dropped_queue: int = 0
var _dropped_voice: int = 0
var _scheduled: int = 0
var _bytes: int = 0
var _prepared: bool = false

static func next_seed(seed: int) -> int: return (seed*1664525+1013904223)&0xffffffff
static func bank_seed(kind: String,bank: int) -> int: return 0x41554400+bank*7919+IDS.find(kind)*104729
static func _roll(box: Array[int]) -> float:
	box[0] = next_seed(box[0]); return float(box[0])/4294967296.0
static func _tone(frequency: float,duration: float,type: String,volume: float,slide: Variant = null,offset: float = 0.0,deferred: bool = false) -> Dictionary:
	return {"type":"tone","frequency":frequency,"duration":duration,"waveform":type,"volume":volume,"slide":slide,"offset_ms":offset,"deferred":deferred}
static func _noise(duration: float,volume: float) -> Dictionary:
	return {"type":"noise","duration":duration,"volume":volume,"offset_ms":0.0,"deferred":false}
static func recipe(kind: String,bank: int = 0) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if kind not in IDS or bank < 0 or bank >= BANKS: return rows
	var random: Array[int] = [bank_seed(kind,bank)]
	match kind:
		"hit": rows.assign([_tone(180,.08,"square",.1,60),_noise(.06,.08)])
		"hurt": rows.append(_tone(220,.18,"sawtooth",.1,80))
		"pickup": rows.assign([_tone(800,.06,"square",.07),_tone(1200,.06,"square",.07,null,60,true)])
		"coin": rows.assign([_tone(494,.08,"square",.08),_tone(659,.12,"square",.08,null,80,true)])
		"rockUp":
			for index: int in range(4): rows.append(_tone([440,554,659,880][index],.18,"triangle",.09,null,index*100,true))
		"crash": rows.append(_tone(440,.6,"sawtooth",.08,110))
		"death":
			for index: int in range(4): rows.append(_tone([440,330,247,165][index],.32,"sawtooth",.09,null,index*220,true))
		"rankUp":
			for index: int in range(4): rows.append(_tone([523,659,784,1047][index],.16,"square",.08,null,index*80,true))
		"dialogue": rows.append(_tone(660,.04,"square",.05))
		"copSiren": rows.assign([_tone(900,.18,"sine",.06,500),_tone(500,.18,"sine",.06,900,200,true)])
		"bossRoar": rows.assign([_tone(80,.45,"sawtooth",.12,40),_noise(.35,.1)])
		"glassBreak":
			for index: int in range(6): rows.append(_tone(2000+_roll(random)*2000,.05,"square",.05,800,index*30,true))
			rows.append(_noise(.2,.08))
		"cricket": rows.append(_tone(2200+_roll(random)*400,.04,"triangle",.025,1800))
		"traffic": rows.append(_tone(60+_roll(random)*30,.35,"sawtooth",.025,40))
		"carDoor": rows.assign([_tone(120,.08,"square",.04,80),_tone(80,.06,"sawtooth",.03,50)])
		"cough": rows.assign([_noise(.12,.03),_tone(220+_roll(random)*40,.08,"sawtooth",.03,110)])
		"dogBark": rows.assign([_tone(280,.06,"square",.04,180),_tone(240,.06,"square",.04,160,80,true)])
		"windup": rows.assign([_tone(150,.45,"sawtooth",.06,70),_noise(.25,.03)])
		"bottleThrow": rows.append(_tone(360,.07,"square",.05,260))
		"bottleHit":
			for index: int in range(5): rows.append(_tone(1800+_roll(random)*1600,.04,"square",.04,800,index*22,true))
			rows.append(_noise(.08,.04))
		"holyWaterThrow": rows.assign([_tone(660,.10,"triangle",.05),_tone(880,.08,"triangle",.04,null,50,true)])
		"holyWaterHit": rows.assign([_tone(440,.16,"sine",.05,220),_tone(880,.20,"sine",.04,660),_noise(.08,.03)])
		"radio": rows.assign([_tone(1600,.03,"square",.04),_tone(1200,.04,"square",.03,null,40,true),_noise(.04,.02)])
		"kick": rows.assign([_tone(80,.10,"square",.07,40),_noise(.08,.05)])
	return rows

static func phase_cycles(frequency: float,slide: Variant,duration: float,time: float) -> float:
	var active: float = minf(time,duration)
	if slide == null or is_equal_approx(float(slide),frequency): return frequency*time
	var target: float = maxf(float(slide),20.0)
	var rate: float = log(target/frequency)/duration
	return frequency*(exp(rate*active)-1.0)/rate+target*maxf(0,time-duration)
static func tone_sample(note: Dictionary,time: float) -> float:
	var duration: float = note.duration
	var phase: float = fposmod(phase_cycles(note.frequency,note.slide,duration,time),1.0)
	var value: float = 0.0
	match note.waveform:
		"square": value = 1.0 if phase < 0.5 else -1.0
		"sawtooth": value = 2.0*phase-1.0
		"triangle": value = 1.0-4.0*absf(phase-0.5)
		"sine": value = sin(phase*TAU)
	var gain: float = float(note.volume)*pow(0.0001/float(note.volume),minf(time/duration,1.0))
	return value*gain
static func pcm(note: Dictionary,noise_seed: int = 1) -> PackedByteArray:
	var count: int = int(float(RATE)*(float(note.duration)+(0.02 if note.type == "tone" else 0.0)))
	var bytes := PackedByteArray(); bytes.resize(count*2)
	for index: int in range(count):
		var sample: float
		if note.type == "tone": sample = tone_sample(note,float(index)/float(RATE))
		else:
			noise_seed = next_seed(noise_seed)
			sample = (float(noise_seed)/4294967296.0*2.0-1.0)*(1.0-float(index)/float(count))*float(note.volume)
		bytes.encode_s16(index*2,int(round(clampf(sample,-1.0,1.0)*32767.0)))
	return bytes
func _ready() -> void:
	prepare()
	for index: int in range(VOICES):
		var player := AudioStreamPlayer.new(); player.volume_db = MASTER_DB
		add_child(player); players.append(player)
func prepare() -> void:
	if _prepared: return
	for kind: String in IDS:
		var banks: Array[Array] = []
		for bank: int in range(BANKS):
			var plan: Array[Dictionary] = recipe(kind,bank)
			for index: int in range(plan.size()):
				var note: Dictionary = plan[index]
				# Equal fixed tones share a resource across every recipe/bank.
				var key: String = JSON.stringify([note.type,note.get("frequency"),note.duration,note.get("waveform"),note.volume,note.get("slide"),bank if note.type == "noise" else -1])
				if not _clips.has(key):
					var wave := AudioStreamWAV.new(); wave.format = AudioStreamWAV.FORMAT_16_BITS; wave.mix_rate = RATE
					wave.data = pcm(note,0x4e4f4953+bank*65537+index*31337+IDS.find(kind)*971)
					_clips[key] = wave; _bytes += wave.data.size()
				note.clip = key
			banks.append(plan)
		_plans[kind] = banks
	_prepared = true
func _start_note(note: Dictionary) -> void:
	if not ready_for_sound or muted: _suppressed += 1; return
	for player: AudioStreamPlayer in players:
		if not player.playing:
			player.stream = _clips[note.clip]; player.play(); _started += 1; return
	_dropped_voice += 1
func play_sound(kind: String) -> bool:
	if not _prepared or not _plans.has(kind): return false
	_variation_seed = next_seed(_variation_seed)
	var bank: int = int(floor(float(_variation_seed)/4294967296.0*BANKS))
	for note: Dictionary in _plans[kind][bank]:
		if not note.deferred: _start_note(note); continue
		if _pending.size() >= MAX_NOTES: _dropped_queue += 1; continue
		_serial += 1; _scheduled += 1
		_pending.append({"due":_wall+float(note.offset_ms),"serial":_serial,"note":note})
	_pending.sort_custom(func(a: Dictionary,b: Dictionary): return a.due < b.due or (a.due == b.due and a.serial < b.serial))
	return true
func advance_wall(monotonic_ms: float) -> bool:
	if not is_finite(monotonic_ms) or monotonic_ms < 0 or (_wall_started and monotonic_ms < _wall): return false
	# Establish the monotonic origin without making pre-first-tick relative delays overdue.
	if not _wall_started:
		for pending: Dictionary in _pending: pending.due += monotonic_ms
	_wall = monotonic_ms; _wall_started = true
	while not _pending.is_empty() and float(_pending[0].due) <= _wall:
		var pending: Dictionary = _pending.pop_front(); _start_note(pending.note)
	return true
func metrics() -> Dictionary:
	return {"recipes":_plans.size(),"clips":_clips.size(),"pcm_bytes":_bytes,"voices":players.size(),"queued":_pending.size(),"scheduled":_scheduled,"started":_started,"suppressed":_suppressed,"dropped_queue":_dropped_queue,"dropped_voice":_dropped_voice}
func _exit_tree() -> void:
	for player: AudioStreamPlayer in players: player.stop(); player.stream = null
	_pending.clear(); _clips.clear(); _plans.clear(); _prepared = false
