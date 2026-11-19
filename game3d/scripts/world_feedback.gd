extends RefCounted
## Cosmetic only. No GameState/scene dependency, global RNG, physics or autonomous timer.
const CAPACITY := 220
const STEP_MS := 1000.0/60.0
const DRAG := 0.92
const MAX_STEP_MS := 240000.0
const MODULUS := 2147483647
const MULTIPLIER := 48271
const BURST_RECIPES: Array[String] = ["essential","melee_sparks","melee_rust","melee_flash","bottle_break","bottle_impact","holy_impact","tony_coat","older_phase","dumpster_rats","trash_cash","trash_rats","possum_reveal","ally_hit","ranged_aim","fallen_aim","radio","taser"]
const DUST_RECIPES: Array[String] = ["walking_dust","ambient_mote"]
const RECIPES: Array[String] = ["essential","melee_sparks","melee_rust","melee_flash","bottle_break","bottle_impact","holy_impact","tony_coat","older_phase","dumpster_rats","trash_cash","trash_rats","possum_reveal","ally_hit","ranged_aim","fallen_aim","radio","taser","walking_dust","ambient_mote"]
var _seed: int
var _rng: int
var _epoch: int = 0
var _revision: int = 0
var _serial: int = 0
var _draws: int = 0
var _requested: int = 0
var _emitted: int = 0
var _evicted: int = 0
var _expired: int = 0
var _peak: int = 0
var _particles: Array[Dictionary] = []

func _init(cosmetic_seed: int = 1) -> void:
	_seed = posmod(cosmetic_seed,MODULUS-1)+1
	_rng = _seed

static func supported_recipes() -> Array[String]: return RECIPES.duplicate()
static func _number(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value))
static func _point(value: Variant) -> bool:
	return value is Vector2 and value.is_finite() and absf(value.x) <= 1e7 and absf(value.y) <= 1e7
static func _world(value: Variant) -> bool:
	return value is Vector3 and value.is_finite() and absf(value.x) <= 1e6 and absf(value.y) <= 1e6 and absf(value.z) <= 1e6
static func _right(value: Variant) -> bool:
	return value is Vector3 and value.is_finite() and is_finite(value.length_squared()) and value.x*value.x+value.z*value.z > 1e-12 and absf(value.y) <= 0.00001

func reset_epoch(epoch: int) -> bool:
	if epoch <= 0: return false
	_epoch = epoch; _revision += 1; _particles.clear(); _serial = 0; _draws = 0
	_requested = 0; _emitted = 0; _evicted = 0; _expired = 0; _peak = 0; _rng = _seed
	return true

func _random() -> float:
	_rng = (_rng*MULTIPLIER)%MODULUS; _draws += 1
	return float(_rng)/float(MODULUS)

func accept(receipt: Dictionary) -> bool:
	if _epoch <= 0 or not receipt.get("epoch") is int or receipt.epoch != _epoch: return false
	if not receipt.get("recipe") is String or receipt.recipe not in RECIPES: return false
	if not _point(receipt.get("source_point")) or not _world(receipt.get("world_anchor")) or not _right(receipt.get("birth_right")): return false
	var recipe: String = receipt.recipe
	if receipt.has("sings") and not receipt.sings is bool: return false
	if recipe == "dumpster_rats" and (not _number(receipt.get("width")) or receipt.width < 0 or receipt.width > 100000): return false
	if recipe == "tony_coat" and (not receipt.get("phase") is int or receipt.phase not in [2,3]): return false
	if recipe in DUST_RECIPES:
		var expected_samples: int = 5 if recipe == "walking_dust" else 7
		if not receipt.get("samples") is Array or receipt.samples.size() != expected_samples: return false
		for sample: Variant in receipt.samples:
			if not _number(sample) or sample < 0.0 or sample >= 1.0: return false
		if recipe == "walking_dust" and (not _number(receipt.get("intent_x")) or absf(receipt.intent_x) > 1.0): return false
		if recipe == "ambient_mote" and not receipt.get("rain") is bool: return false
	var count: int = 1
	match recipe:
		"melee_sparks","trash_rats": count = 8
		"melee_rust": count = 3
		"bottle_break","holy_impact": count = 12
		"bottle_impact","dumpster_rats","taser": count = 10
		"tony_coat": count = 24
		"older_phase": count = 20
		"trash_cash","possum_reveal": count = 6
		"ally_hit","fallen_aim": count = 4
	# Validate the entire receipt before the first serial/RNG/counter mutation.
	var right: Vector3 = Vector3(receipt.birth_right.x,0,receipt.birth_right.z).normalized()
	_requested += count
	for _index: int in range(count):
		var offset := Vector2.ZERO
		var velocity := Vector2.ZERO
		var life: float = 0.0; var size: float = 0.0; var gravity: float = 0.0
		var glow: bool = false; var shape: String = "fragment"; var color := Color("d4c896")
		match recipe:
			"essential":
				velocity = Vector2((_random()-0.5)*2,-1.2); life = 420; size = 4
			"melee_sparks":
				velocity = Vector2((_random()-0.5)*5,(_random()-0.5)*5); life = 300; size = 3; glow = true
				color = Color("ffaa60" if receipt.get("sings",false) else "fff080")
			"melee_rust":
				velocity = Vector2((_random()-0.5)*3,(_random()-0.5)*3-1); life = 600; size = 2; gravity = 0.15; color = Color("8a3a3a")
			"melee_flash":
				life = 200; size = 14; glow = true; shape = "flash"; color = Color("ffaa60" if receipt.get("sings",false) else "fff080")
			"bottle_break":
				velocity = Vector2((_random()-0.5)*5,-_random()*3-0.5); life = 600; size = 2; glow = true; color = Color(180.0/255,200.0/255,220.0/255,0.85)
			"bottle_impact":
				velocity = Vector2((_random()-0.5)*5,(_random()-0.5)*5); life = 380; size = 2; color = Color("a07020")
			"holy_impact":
				velocity = Vector2((_random()-0.5)*4,(_random()-0.5)*4); life = 500; size = 3; glow = true; color = Color("a0d0ff")
			"tony_coat":
				velocity = Vector2((_random()-0.5)*10,(_random()-0.7)*8); life = 1400; size = 5; gravity = 0.25; color = Color("4a2018" if receipt.phase == 2 else "2a1010")
			"older_phase":
				velocity = Vector2((_random()-0.5)*8,(_random()-0.7)*6); life = 1200; size = 5; gravity = 0.2; color = Color("8a3030")
			"dumpster_rats":
				offset.x = _random()*float(receipt.width); velocity = Vector2((_random()-0.5)*3,-_random()*2-0.5); life = 600; size = 2; color = Color("181010")
			"trash_cash":
				velocity = Vector2((_random()-0.5)*3,-_random()*2-1); life = 600; size = 3; glow = true; color = Color("e8c040")
			"trash_rats":
				offset.x = (_random()-0.5)*16; velocity = Vector2((_random()-0.5)*4,-_random()*2-0.5); life = 700; size = 2; color = Color("181010")
			"possum_reveal":
				velocity = Vector2((_random()-0.5)*3,-_random()*3); life = 600; size = 3; color = Color("e8c040")
			"ally_hit":
				velocity = Vector2((_random()-0.5)*4,(_random()-0.5)*4); life = 280; size = 3; color = Color("88c0ff")
			"ranged_aim":
				velocity = Vector2(0,-0.3); life = 400; size = 2; glow = true; color = Color("fff080")
			"fallen_aim":
				velocity = Vector2(_random()-0.5,-_random()*1.5); life = 500; size = 2; glow = true; color = Color("a0d0ff")
			"radio":
				velocity = Vector2(0,-0.4); life = 700; size = 3; glow = true; color = Color("88c0ff")
			"taser":
				velocity = Vector2((_random()-0.5)*6,(_random()-0.5)*6); life = 400; size = 3; glow = true; color = Color("88c0ff")
			"walking_dust":
				var samples: Array = receipt.samples
				offset = Vector2((samples[0]-0.5)*6.0,samples[1]*2.0)
				velocity = Vector2(-float(receipt.intent_x)*0.4+(samples[2]-0.5)*0.4,-0.3-samples[3]*0.2)
				life = 380.0+samples[4]*200.0; size = 2; color = Color(180.0/255,160.0/255,120.0/255,0.55)
			"ambient_mote":
				var samples: Array = receipt.samples
				velocity = Vector2(0.3+samples[3]*0.4,-0.15+samples[4]*0.3)
				life = 4500.0+samples[5]*1500.0; size = 2 if samples[6] < 0.2 else 1
				color = Color(180.0/255,200.0/255,220.0/255,0.6) if receipt.rain else Color(232.0/255,210.0/255,160.0/255,0.32)
		_serial += 1
		if _particles.size() == CAPACITY: _particles.pop_front(); _evicted += 1
		_particles.append({"serial":_serial,"recipe":recipe,"source_point":receipt.source_point,"world_anchor":receipt.world_anchor,"birth_right":right,"offset":offset,"velocity":velocity,"life":life,"size":size,"gravity":gravity,"glow":glow,"shape":shape,"color":color})
		_emitted += 1; _peak = maxi(_peak,_particles.size())
	_revision += 1
	return true

func advance_particles(dt_ms: Variant) -> bool:
	if not _number(dt_ms) or dt_ms <= 0 or dt_ms > MAX_STEP_MS: return false
	if _particles.is_empty(): return true
	var n: float = float(dt_ms)/STEP_MS
	var decay: float = pow(DRAG,n)
	var sum: float = (1.0-decay)/(1.0-DRAG)
	for index: int in range(_particles.size()-1,-1,-1):
		var particle: Dictionary = _particles[index]
		particle.life -= float(dt_ms)
		if particle.life <= 0:
			_particles.remove_at(index); _expired += 1; continue
		var gravity: Vector2 = Vector2(0,float(particle.gravity))
		particle.offset += particle.velocity*sum+gravity/(1.0-DRAG)*(n-sum)
		particle.velocity = particle.velocity*decay+gravity*sum
	_revision += 1
	return true

func inspect() -> Dictionary:
	return {"epoch":_epoch,"revision":_revision,"rng_state":_rng,"rng_draws":_draws,"requested":_requested,"emitted":_emitted,"evicted":_evicted,"expired":_expired,"live":_particles.size(),"peak":_peak}
func snapshot() -> Dictionary:
	return {"epoch":_epoch,"revision":_revision,"particles":_particles.duplicate(true),"stats":inspect()}

static func decayed_shake(shake: Variant,dt_ms: Variant) -> float:
	if not _number(shake): return 0.0
	if not _number(dt_ms) or dt_ms <= 0 or dt_ms > MAX_STEP_MS or shake <= 0: return float(shake)
	return float(shake)*pow(0.9,float(dt_ms)/STEP_MS)

static func world_offset(shake: Variant,visual_ms: Variant,viewport_size: Variant,mode: String,strength: Variant = 1.0,focused: bool = true,loading: bool = false,cosmetic_seed: int = 1) -> Vector2:
	if mode != "playing" or not focused or loading or not _number(shake) or not _number(visual_ms) or not _number(strength): return Vector2.ZERO
	if visual_ms < 0 or visual_ms > 1e12 or not viewport_size is Vector2 or not viewport_size.is_finite(): return Vector2.ZERO
	if viewport_size.x < 1 or viewport_size.y < 1 or viewport_size.x > 16384 or viewport_size.y > 16384: return Vector2.ZERO
	var amplitude: float = clampf(float(shake),0,14)*(2.0/7.0)*(viewport_size.y/720.0)*clampf(float(strength),0,1)
	if amplitude <= 0: return Vector2.ZERO
	# Local hash only: offset sampling never advances particle or gameplay RNG.
	var tick: int = floori(float(visual_ms)/STEP_MS)
	var value: int = (posmod(tick,MODULUS-1)+posmod(cosmetic_seed,MODULUS-1))%(MODULUS-1)+1
	# Two mixing rounds avoid adjacent wall ticks producing a near-linear x drift.
	value = (value*MULTIPLIER)%MODULUS
	value = (value*MULTIPLIER)%MODULUS
	value = (value*MULTIPLIER)%MODULUS
	var x: float = float(value)/MODULUS-0.5
	value = (value*MULTIPLIER)%MODULUS
	return Vector2(x,float(value)/MODULUS-0.5)*amplitude
