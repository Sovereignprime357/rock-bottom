extends SceneTree
const Runtime = preload("res://scripts/full_runtime.gd")
const Baseline = preload("res://tests/fixtures/dust_baseline_runtime.gd")
const Pool = preload("res://scripts/world_feedback.gd")
var checks: int = 0
var failures: int = 0
var groups: int = 0

class Spatial extends RefCounted:
	func move_body(_body: Dictionary,point: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary: return {"position":point,"blocked":false}
	func can_reach_target(_id: String) -> bool: return true
	func can_use_zone(_id: String) -> bool: return true
	func clear_placement(body: Dictionary) -> Variant: return Vector2(body.x,body.y)
	func can_hit(_a: Vector2,_b: Vector2,_source: String,_target: String) -> bool: return true
	func sweep_projectile(_a: Vector2,b: Vector2,_r: float) -> Dictionary: return {"blocked":false,"fraction":1.0,"position":b}
class AmbientWitness extends RefCounted:
	var owner: WeakRef
	var seen: Array = []
	var open_modal: bool = false
	func _init(host: RefCounted) -> void: owner = weakref(host)
	func tick_active(_ms: float) -> void:
		var runtime: RefCounted = owner.get_ref()
		seen = runtime.feedback_snapshot().particles
		if open_modal: runtime.s.mode = "dialogue"
class DirectorWitness extends RefCounted:
	var owner: WeakRef
	var profile_enabled: bool = false
	var profile_us: Dictionary = {}
	var seen: Array = []
	func _init(host: RefCounted) -> void: owner = weakref(host)
	func tick_dog_discomfort() -> void: pass
	func tick(_ms: float,_wall: float) -> void:
		var runtime: RefCounted = owner.get_ref(); seen = runtime.feedback_snapshot().particles
		runtime.state.emit_event("world_feedback",{"feedback":[{"recipe":"essential","source_point":Vector2(500,500),"anchor_kind":"ground"}]})
class CombatWitness extends RefCounted:
	var owner: WeakRef
	var seen: Array = []
	func _init(host: RefCounted) -> void: owner = weakref(host)
	func tick_status(_ms: float) -> void: pass
	func tick_police(_ms: float,_wall: float) -> void: pass
	func tick_projectiles(_ms: float) -> void: seen = owner.get_ref().feedback_snapshot().particles
class BossWitness extends RefCounted:
	func tick_before_actors(_ms: float) -> void: pass
	func tick_after_actors(_ms: float,_wall: float) -> void: pass
class KingdomWitness extends RefCounted:
	func tick_active(_ms: float) -> void: pass
class SceneHarness:
	extends "res://scripts/full_scene.gd"
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures <= 24: push_error(label)
func _new(script: Script,spatial: RefCounted) -> RefCounted:
	var runtime: RefCounted = script.new(spatial,null,func(): return 1000000.0)
	runtime.fresh(); runtime.drain_events()
	if runtime.has_method("set_dust_context"): runtime.set_dust_context(Transform3D(Basis.IDENTITY,Vector3(42,1.65,34)),78.0,16.0/9.0)
	return runtime
func _names(rows: Array) -> Array:
	var result: Array = []
	for row: Dictionary in rows: result.append(row.recipe)
	return result

func _ordering() -> void:
	for modal: bool in [false,true]:
		var spatial := Spatial.new(); var runtime: RefCounted = _new(Runtime,spatial)
		runtime.world_dust._walk_ms = 110.0
		var ambient := AmbientWitness.new(runtime); ambient.open_modal = modal; runtime.ambient_audio = ambient
		var director := DirectorWitness.new(runtime); runtime.director = director
		var combat := CombatWitness.new(runtime); runtime.combat = combat
		runtime.bosses = BossWitness.new(); runtime.kingdom = KingdomWitness.new(); runtime._actors_enabled = true
		_check(runtime.advance(Pool.STEP_MS/1000.0,{"input_vector":Vector2.RIGHT}),"one real Runtime step accepted")
		_check(_names(ambient.seen) == ["walking_dust"],"walking source position precedes ambient-audio callback")
		_check(_names(director.seen) == ["walking_dust","ambient_mote"],"mote follows audio and precedes Director")
		_check(_names(combat.seen) == ["walking_dust","ambient_mote","essential"],"both dust births and actor receipt precede projectile pass")
		for index: int in range(mini(2,combat.seen.size())):
			_check(absf(combat.seen[index].life-(director.seen[index].life-Pool.STEP_MS)) < 1e-8,"same-step particle pass ages each dust birth exactly once")
		_check(runtime.s.mode == ("dialogue" if modal else "playing"),"mid-step modal preserves original completion semantics")
	groups += 1

func _lifecycle() -> void:
	var spatial := Spatial.new(); var runtime: RefCounted = _new(Runtime,spatial)
	runtime.advance(0.07,{"input_vector":Vector2.RIGHT})
	var held: Dictionary = runtime.world_dust.inspect(); var particles: Dictionary = runtime.feedback_snapshot()
	for mode: String in ["paused","dialogue","title"]:
		runtime.s.mode = mode; runtime.advance(0.1)
		_check(runtime.world_dust.inspect() == held and runtime.feedback_snapshot() == particles,"no dust time or expiry outside active world: "+mode)
	runtime.s.mode = "playing"; runtime.s.hitPause = 100.0; runtime.advance(Pool.STEP_MS/1000.0)
	_check(runtime.world_dust.inspect() == held and runtime.feedback_snapshot() == particles,"hitpause-only step cannot emit/advance dust")
	var epoch: int = runtime._feedback_epoch
	var saved: Dictionary = runtime.snapshot()
	_check(runtime.restore(saved) and runtime._feedback_epoch == epoch+1 and runtime.world_dust.inspect().walk_ms == 0.0 and runtime.world_dust.inspect().ambient_ms == 0.0,"restore resets private clocks exactly with sole feedback generation")
	_check(runtime.feedback_snapshot().particles.is_empty(),"restore clears shared unsaved pool")
	epoch = runtime._feedback_epoch
	_check(runtime.fresh() and runtime._feedback_epoch == epoch+1 and runtime.world_dust.inspect().rng_draws == 0,"fresh resets cosmetic stream/clock exactly once")
	for field: String in ["p","s"]:
		var other: RefCounted = _new(Runtime,spatial)
		if field == "p": other.state.p = other.p.duplicate(true)
		else: other.state.s = other.s.duplicate(true)
		var p_before: Dictionary = other.p.duplicate(true); var s_before: Dictionary = other.s.duplicate(true)
		other._dust_walk(120.0,{"_feedback_intent":Vector2.RIGHT}); other._dust_ambient(16.0)
		_check(not other.feedback_inspect().bound and other.feedback_snapshot().particles.is_empty() and other.p == p_before and other.s == s_before,"unexpected "+field+" epoch refuses dust without replacement writes")
	groups += 1

func _fatal_taser() -> void:
	var spatial := Spatial.new(); var runtime: RefCounted = _new(Runtime,spatial)
	_check(runtime.enable_actor_simulation(),"real Director/Combat installed")
	runtime.world_dust._walk_ms = 110.0; runtime._dust_walk(1.0,{"_feedback_intent":Vector2.RIGHT})
	runtime.world_dust._walk_ms = 70.0
	runtime.p.hp = 1.0; runtime.p.iframes = 0.0
	var brendan := {"id":"brendan","name":"COUSIN BRENDAN","sprite":"brendan_3d","x":runtime.p.x,"y":runtime.p.y,"w":28.0,"h":34.0,"speed":0.0,"isCop":true,"isBrendan":true,"archetype":"brendan","attackCd":0.0,"taserChargeT":4000.0,"hp":100.0,"maxHp":100.0}
	runtime.state.npcs.append(brendan)
	var epoch: int = runtime._feedback_epoch
	runtime.director._hostile(brendan,Pool.STEP_MS)
	# This exercises the new narrow metadata drain, not a second domain resolver.
	runtime._dust_ambient(Pool.STEP_MS)
	var rows: Array = runtime.feedback_snapshot().particles
	_check(runtime._feedback_epoch == epoch+1 and rows.size() == 11,"fatal real taser resets old dust before retaining10 taser births plus later mote")
	_check(_names(rows).count("taser") == 10 and _names(rows).count("ambient_mote") == 1 and _names(rows).count("walking_dust") == 0,"source lifecycle preserves post-reset taser and removes old walking birth")
	_check(runtime.world_dust.inspect().walk_ms == 0.0,"fatal event resets private walking clock at same cursor")
	var before: Dictionary = runtime.feedback_snapshot(); runtime.drain_events()
	_check(runtime.feedback_snapshot() == before and runtime._feedback_epoch == epoch+1,"normal later resolver neither resets nor admits metadata twice")
	groups += 1

func _clean(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if key == "_world_feedback_cursor": continue
			result[key] = _clean(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_clean(item))
		return result
	return value
func _compare(a: RefCounted,b: RefCounted,label: String) -> void:
	_check(a.p == b.p and a.s == b.s,label+" exact complete p/s")
	_check(a.state.rng_seed == b.state.rng_seed and a.state.npcs == b.state.npcs and a.state.projectiles == b.state.projectiles and a.state.cash_piles == b.state.cash_piles,label+" exact gameplay RNG/actors/projectiles/pickups")
	_check(_clean(a.drain_events()) == _clean(b.drain_events()),label+" identical ordered domain events")
	_check(a.snapshot() == b.snapshot(),label+" identical saved state; no new cosmetic field")
func _paired() -> void:
	var sa := Spatial.new(); var sb := Spatial.new()
	var a: RefCounted = _new(Runtime,sa); var b: RefCounted = _new(Baseline,sb)
	_compare(a,b,"fresh")
	_check(a.enable_actor_simulation() and b.enable_actor_simulation(),"paired actual60-actor source compositions")
	for i: int in range(24):
		var context := {"input_vector":Vector2(0.2,-0.7),"sprinting":i%2 == 0}
		a.advance(Pool.STEP_MS/1000.0,context); b.advance(Pool.STEP_MS/1000.0,context)
		_compare(a,b,"active step"+str(i))
	_check(a.world_dust.inspect().walk_births > 0 and a.world_dust.inspect().ambient_births > 0,"paired scenario actually emitted both new effects")
	var saved_a: Dictionary = a.snapshot(); var saved_b: Dictionary = b.snapshot()
	_check(a.restore(saved_a) and b.restore(saved_b),"paired restore accepted"); _compare(a,b,"restore")
	groups += 1

func _scene_context() -> void:
	var spatial := Spatial.new(); var runtime: RefCounted = _new(Runtime,spatial)
	var scene := SceneHarness.new(); root.add_child(scene); scene.runtime = runtime
	var camera := Camera3D.new(); scene.add_child(camera); scene.camera = camera
	camera.position = Vector3(42,1.65,34); camera.rotation = Vector3(-0.1,0.8,0); camera.fov = 78
	var transform: Transform3D = camera.global_transform; var p_before: Dictionary = runtime.p.duplicate(true)
	scene._sync_feedback_context()
	_check(runtime._dust_context.camera == transform and runtime._dust_context.fov == 78.0,"Scene supplies current detached actual camera/projection")
	_check(camera.global_transform == transform and runtime.p == p_before,"context binding never changes aim/controller/model")
	var held: Dictionary = runtime.world_dust.inspect()
	_check(not runtime.set_dust_context(Transform3D(Basis.IDENTITY,Vector3(INF,0,0)),78,16.0/9.0),"invalid current camera disables stale context")
	runtime._dust_ambient(16)
	_check(runtime._dust_context.is_empty() and runtime.world_dust.inspect() == held,"missing context does not consume cosmetic timer/RNG")
	scene.runtime = null; scene.free(); groups += 1

func _run() -> void:
	_ordering(); _lifecycle(); _fatal_taser(); _paired(); _scene_context()
	_check(groups == 5,"all five integration groups completed")
	print("WORLD DUST RUNTIME DRAFT: ","PASS" if failures == 0 else "FAIL","; ",checks," checks;",groups," groups; actual scene visual/native/Web pending.")
	quit(0 if failures == 0 else 1)
