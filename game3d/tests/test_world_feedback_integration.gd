extends SceneTree
const Runtime = preload("res://scripts/full_runtime.gd")
const Baseline = preload("res://tests/feedback_reference/full_runtime.gd")
const Anchors = preload("res://scripts/world_feedback_anchors.gd")
const Pool = preload("res://scripts/world_feedback.gd")
const View = preload("res://scripts/world_feedback_view.gd")
const Grade = preload("res://scripts/district_grade.gd")
const GradeView = preload("res://scripts/district_grade_view.gd")
var checks: int = 0
var failures: Array[String] = []
var groups: int = 0
var recipe_count: int = 0

class Spatial extends RefCounted:
	func can_reach_target(_id: String) -> bool: return true
	func can_use_zone(_id: String) -> bool: return true
	func move_body(_body: Dictionary,intended: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary: return {"position":intended,"blocked":false}
	func clear_placement(body: Dictionary) -> Variant: return Vector2(body.x,body.y)
	func can_hit(_from: Vector2,_to: Vector2,_source: String,_target: String) -> bool: return true
	func sweep_projectile(_from: Vector2,to: Vector2,_radius: float) -> Dictionary: return {"blocked":false,"fraction":1.0,"position":to}

class OrderDirector extends RefCounted:
	var owner_ref: WeakRef
	var profile_enabled: bool = false
	var profile_us: Dictionary = {}
	var before_rng: int = 0
	func _init(owner: RefCounted) -> void: owner_ref = weakref(owner)
	func tick_dog_discomfort() -> void: pass
	func tick(_step: float,_wall: float) -> void:
		var owner: RefCounted = owner_ref.get_ref()
		before_rng = owner.state.rng_seed
		owner.state.emit_event("intro_completed")
		owner.state.emit_event("world_feedback",{"feedback":[{"recipe":"essential","source_point":Vector2(400,400),"source_rect":Rect2(386,383,28,34),"anchor_kind":"body"}]})

class OrderCombat extends RefCounted:
	var owner_ref: WeakRef
	var observed_rng: int = 0
	var observed_particles: Array = []
	func _init(owner: RefCounted) -> void: owner_ref = weakref(owner)
	func tick_status(_step: float) -> void: pass
	func tick_police(_step: float,_wall: float) -> void: pass
	func tick_projectiles(_step: float) -> void:
		var owner: RefCounted = owner_ref.get_ref()
		observed_rng = owner.state.rng_seed
		if owner.has_method("feedback_snapshot"): observed_particles = owner.feedback_snapshot().particles
		owner.state.emit_event("projectile_impact",{"position":Vector2(450,450),"kind":"bottle","player":true,"feedback":[{"recipe":"bottle_impact","source_point":Vector2(450,450),"anchor_kind":"projectile"}]})

class OrderBoss extends RefCounted:
	func tick_before_actors(_step: float) -> void: pass
	func tick_after_actors(_step: float,_wall: float) -> void: pass
class OrderKingdom extends RefCounted:
	func tick_active(_step: float) -> void: pass
class SceneHarness:
	extends "res://scripts/full_scene.gd"
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
class MinimalHud extends CanvasLayer:
	var district_grade: ColorRect

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _run() -> void:
	_metadata_recipes()
	_birth_anchors()
	_lifecycle()
	_step_order()
	_actual_combat()
	_paired_runtime()
	_grade_and_view()
	_scene_binding()
	_check(groups == 8,"all eight integration groups completed without script abort")
	_check(recipe_count == 18,"all18 exact recipe metadata paths completed")
	if failures.is_empty():
		print("WORLD FEEDBACK INTEGRATION DRAFT: PASS (%d checks;18 metadata recipes;8 groups; paired source owners; native/Web/performance pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("WORLD FEEDBACK INTEGRATION DRAFT: FAIL (%d failures/%d checks)" % [failures.size(),checks]); quit(1)

func _new(script: Script,spatial: RefCounted) -> RefCounted:
	var runtime: RefCounted = script.new(spatial,null,func(): return 1000000.0)
	_check(runtime.fresh(),"real Runtime fresh succeeds")
	runtime.drain_events()
	return runtime
func _raw(recipe: String) -> Dictionary:
	return {"recipe":recipe,"source_point":Vector2(400,500),"source_rect":Rect2(386,483,28,34),"anchor_kind":"body","actor_id":"gone","source_actor":{"id":"gone","name":"LURCH","sprite":"lurch","isOmalleyFallen":false},"sings":true,"phase":2,"width":32.0}
func _emit(runtime: RefCounted,recipe: String) -> void:
	runtime.state.emit_event("world_feedback",{"feedback":[_raw(recipe)]})
func _metadata_recipes() -> void:
	var spatial := Spatial.new(); var runtime: RefCounted = _new(Runtime,spatial)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_feedback_reference.json"))
	_check(fixture.recipes.size() == 18,"unchanged-source recipe census available")
	for item: Dictionary in fixture.recipes:
		var id: String = item.id
		runtime._feedback_reset("test")
		var before: Dictionary = runtime.snapshot()
		_emit(runtime,id)
		var queued: Array = runtime.state.events.duplicate(true)
		runtime._drain_feedback_metadata()
		var after: Dictionary = runtime.feedback_inspect()
		_check(after.bridge.accepted == recipe_count+1,"one bridge admission for "+id)
		_check(after.pool.live > 0 and runtime.snapshot() == before,"cosmetic metadata cannot change saved state/RNG: "+id)
		_check(runtime.state.events.size() == queued.size() and runtime.state.events[0].kind == queued[0].kind,"metadata scan preserves queue and order: "+id)
		var snap: Dictionary = runtime.feedback_snapshot()
		runtime._drain_feedback_metadata(); runtime.drain_events(); runtime.drain_events()
		_check(runtime.feedback_snapshot() == snap,"scan+normal drain admits once: "+id)
		for row: Dictionary in snap.particles: _check(row.recipe == id,"all source particles retain birth recipe: "+id)
		recipe_count += 1
	var before_bad: Dictionary = runtime.feedback_snapshot()
	runtime.state.emit_event("world_feedback",{"feedback":[{"recipe":"essential","source_point":Vector2(NAN,0),"anchor_kind":"ground"}]})
	runtime.drain_events()
	_check(runtime.feedback_snapshot() == before_bad and runtime.feedback_inspect().bridge.rejected == 1,"bad cosmetic metadata refuses without disturbing pool")
	var accepted_before: int = runtime.feedback_inspect().bridge.accepted
	_emit(runtime,"essential"); runtime._drain_feedback_metadata()
	runtime.state.emit_event("feed",{"text":"the paper moved.","author":"@local_eyewitness"})
	_emit(runtime,"essential"); runtime.communications.flush_pending_events(); runtime._drain_feedback_metadata(); runtime.drain_events()
	_check(runtime.feedback_inspect().bridge.accepted == accepted_before+2,"real feed queue compaction cannot skip or replay a metadata cursor")
	groups += 1

func _birth_anchors() -> void:
	var anchors := Anchors.new(); var raw: Dictionary = _raw("essential")
	var first: Dictionary = anchors.decorate(raw,Vector3.RIGHT,1)
	_check(is_equal_approx(first.world_anchor.y,2.24*0.55),"detached Lurch height uses authored definition")
	var unknown: Dictionary = raw.duplicate(true); unknown.source_actor.name = "unknown"; unknown.source_actor.sprite = "unknown"
	_check(is_equal_approx(anchors.decorate(unknown,Vector3.RIGHT,1).world_anchor.y,1.8*0.55),"unknown descriptor has finite declared fallback")
	var head: Dictionary = raw.duplicate(true); head.anchor_kind = "head"; head.source_point = Vector2(400,477)
	_check(is_equal_approx(anchors.decorate(head,Vector3.RIGHT,1).world_anchor.y,2.24*0.9+0.24),"radio head y-6 maps above authored head rather than moving actor north")
	var spatial := Spatial.new(); var runtime: RefCounted = _new(Runtime,spatial)
	runtime.state.emit_event("actor_hit",{"feedback":[raw]})
	raw.source_actor.name = "unknown"; raw.source_rect = Rect2(0,0,1,1); raw.source_point = Vector2.ZERO
	runtime.state.npcs.clear()
	runtime._drain_feedback_metadata()
	_check(runtime.feedback_snapshot().particles[0].world_anchor == first.world_anchor,"event deep copy survives descriptor mutation and actor removal")
	var cop: Dictionary = _raw("radio")
	cop.source_actor = {"id":"born_and_dead_same_step","name":"COP","sprite":"cop_3d","isOmalleyFallen":false}; cop.anchor_kind = "head"
	cop.source_point = Vector2(400,477)
	runtime.state.emit_event("world_feedback",{"feedback":[cop]}); runtime.drain_events()
	_check(runtime.feedback_snapshot().particles[-1].recipe == "radio" and runtime.state.npcs.is_empty(),"same-step newly spawned/dead ID requires no live roster or Scene node")
	var table: Dictionary = anchors.inspect(); table.heights.clear()
	_check(not anchors.inspect().heights.is_empty(),"height table inspection is detached")
	_check(anchors.decorate(raw,Vector3(NAN,0,0),1).is_empty(),"invalid basis refuses before decoration")
	groups += 1

func _lifecycle() -> void:
	var spatial := Spatial.new(); var runtime: RefCounted = _new(Runtime,spatial)
	_emit(runtime,"essential"); runtime._drain_feedback_metadata()
	var epoch: int = runtime.feedback_inspect().epoch
	runtime.state.emit_event("death",{"retained":"original"})
	var taser: Dictionary = _raw("taser"); taser.actor_id = "player"
	taser.source_rect = Rect2(100,200,28,34); taser.source_point = taser.source_rect.get_center()
	runtime.state.emit_event("world_feedback",{"feedback":[taser]})
	runtime._drain_feedback_metadata()
	var snap: Dictionary = runtime.feedback_snapshot()
	_check(snap.epoch == epoch+1 and snap.particles.size() == 10,"ordered death reset discards old burst but retains post-reset taser")
	for row: Dictionary in snap.particles: _check(row.recipe == "taser" and row.source_point == taser.source_point,"post-reset taser immutable respawn origin")
	var events: Array = runtime.drain_events()
	_check(runtime.feedback_snapshot() == snap,"later domain cleanup does not reset cosmetic pool again")
	var held: Dictionary = {}
	for event: Dictionary in events:
		if event.kind == "death": held = event.duplicate(true)
	runtime._feedback_event(held)
	_check(runtime.feedback_snapshot() == snap,"held transition deep-copy retains once-only metadata cursor")
	var view := View.new(); view.build(); view.sync(snap); view.clear(); view.sync(runtime.feedback_snapshot())
	_check(view.inspect().live == 10,"Scene buffer clear can repopulate post-reset particles without pool reset")
	view.free()
	var saved: Dictionary = runtime.snapshot()
	_check(runtime.restore(saved) and runtime.feedback_snapshot().particles.is_empty(),"accepted restore clears unsaved feedback")
	_emit(runtime,"radio"); runtime.drain_events()
	_check(runtime.fresh() and runtime.feedback_snapshot().particles.is_empty(),"fresh clears unsaved feedback")
	for key: String in ["p","s"]:
		runtime.fresh(); runtime.drain_events(); _emit(runtime,"essential")
		if key == "p": runtime.state.p = runtime.state.p.duplicate(true)
		else: runtime.state.s = runtime.state.s.duplicate(true)
		runtime._drain_feedback_metadata()
		_check(not runtime.feedback_inspect().bound and runtime.feedback_snapshot().particles.is_empty(),"unexpected "+key+" replacement refuses stale admission")
	groups += 1

func _install_order(runtime: RefCounted) -> void:
	runtime.director = OrderDirector.new(runtime); runtime.combat = OrderCombat.new(runtime)
	runtime.bosses = OrderBoss.new(); runtime.kingdom = OrderKingdom.new(); runtime._actors_enabled = true
func _step_order() -> void:
	var spatial := Spatial.new(); var runtime: RefCounted = _new(Runtime,spatial)
	_install_order(runtime); runtime.profile_enabled = true; runtime.s.shake = 14.0
	runtime.advance(Pool.STEP_MS/1000.0)
	_check(runtime.combat.observed_rng == runtime.director.before_rng,"actor-boundary scan cannot run queued intro RNG/domain consequence before projectiles")
	_check(runtime.combat.observed_particles.size() == 1 and is_equal_approx(runtime.combat.observed_particles[0].life,420.0-Pool.STEP_MS),"actor birth ages at original pre-projectile particle boundary")
	var late: Array = runtime.feedback_snapshot().particles.filter(func(row: Dictionary): return row.recipe == "bottle_impact")
	_check(late.size() == 10 and late[0].life == 380.0,"projectile birth retains full life until next step")
	_check(is_equal_approx(runtime.s.shake,12.6),"sole shake scalar decays exactly once at source tail")
	_check(runtime.profile_calls.get("actors") == 1 and runtime.profile_calls.get("world_feedback") == 1 and runtime.profile_calls.get("projectiles_boss") == 1,"original diagnostic denominators preserved plus separate feedback stage")
	var pool_before: Dictionary = runtime.feedback_snapshot(); runtime.s.hitPause = 100.0; runtime.s.shake = 8.0
	runtime.advance(Pool.STEP_MS/1000.0)
	_check(runtime.feedback_snapshot() == pool_before and runtime.s.shake == 8.0 and runtime.profile_calls.is_empty(),"hitpause skips particle age/shake decay and stage accounting")
	runtime.s.hitPause = 0; runtime.s.mode = "dialogue"; runtime.advance(0.05)
	_check(runtime.feedback_snapshot() == pool_before and runtime.s.shake == 8.0,"modal world pause owns no particle or shake timer")
	runtime.s.mode = "playing"; runtime.s.shake = 8.0; runtime.advance(Pool.STEP_MS/2000.0)
	_check(is_equal_approx(runtime.s.shake,8.0*sqrt(0.9)),"fractional accepted step retains source exponential adaptation")
	groups += 1

func _actor(runtime: RefCounted,id: String) -> Dictionary:
	for actor: Dictionary in runtime.state.npcs:
		if actor.id == id: return actor
	return {}
func _actual_combat() -> void:
	var spatial := Spatial.new(); var runtime: RefCounted = _new(Runtime,spatial)
	_check(runtime.enable_actor_simulation(),"actual combat/director installed")
	var target: Dictionary = _actor(runtime,"lurch")
	target.x = runtime.p.x+24.0; target.y = runtime.p.y; target.hp = 1000.0; target.maxHp = 1000.0
	var rect := Rect2(target.x,target.y,target.w,target.h)
	var result: Dictionary = runtime.attack(Vector2.RIGHT)
	_check(result.get("ok",false) and runtime.feedback_snapshot().particles.size() == 12,"actual accepted melee command admits8sparks+3rust+1flash immediately")
	for row: Dictionary in runtime.feedback_snapshot().particles: _check(row.source_point == rect.get_center(),"actual melee feedback captures pre-knockback center")
	var state_before: Dictionary = runtime.snapshot(); var pool_before: Dictionary = runtime.feedback_snapshot()
	runtime.attack(Vector2.RIGHT)
	_check(runtime.feedback_snapshot() == pool_before and runtime.snapshot() == state_before,"cooldown-refused immediate command adds no particles or RNG")
	for iframe: bool in [true,false]:
		runtime.fresh(); runtime.drain_events(); runtime._feedback_reset("test")
		runtime.p.iframes = 1000.0 if iframe else 0.0; runtime.p.hp = 1.0 if not iframe else 100.0
		var brendan := {"id":"brendan","name":"COUSIN BRENDAN","sprite":"brendan_3d","x":runtime.p.x,"y":runtime.p.y,"w":28.0,"h":34.0,"speed":0.0,"isCop":true,"isBrendan":true,"archetype":"brendan","attackCd":0.0,"taserChargeT":4000.0,"hp":100.0,"maxHp":100.0}
		runtime.state.npcs.append(brendan)
		_emit(runtime,"essential"); runtime._drain_feedback_metadata()
		runtime.director._hostile(brendan,Pool.STEP_MS)
		var accepted_center: Vector2 = runtime.state.player_center()
		runtime._drain_feedback_metadata()
		var tasers: Array = runtime.feedback_snapshot().particles.filter(func(row: Dictionary): return row.recipe == "taser")
		_check(tasers.size() == 10,"actual charged taser emits despite iframe/fatal case="+str(iframe))
		for row: Dictionary in tasers: _check(row.source_point == accepted_center,"actual taser uses exact post-hit center, including fatal respawn")
		if not iframe: _check(runtime.feedback_snapshot().particles.size() == 10,"fatal actual taser resets earlier burst before admitting new burst")
		pool_before = runtime.feedback_snapshot(); runtime.drain_events()
		_check(runtime.feedback_snapshot() == pool_before,"actual taser cleanup cannot double-reset/admit")
	# Projectile receipt is independent of damage acceptance, with immutable swept origin.
	runtime.fresh(); runtime.drain_events(); runtime.p.iframes = 1000.0
	var impact: Vector2 = runtime.state.player_center()
	runtime.state.projectiles.append({"x":impact.x,"y":impact.y,"vx":0.0,"vy":0.0,"rot":0.0,"rotVel":0.0,"life":1000.0,"dmg":9.0,"from":{},"slowMs":0.0,"kind":"bottle"})
	runtime.combat.tick_projectiles(Pool.STEP_MS); runtime.drain_events()
	_check(runtime.p.hp == 100.0 and runtime.feedback_snapshot().particles.size() == 10,"actual iframe-blocked bottle impact still emits source recipe")
	groups += 1

func _clean(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if key in ["feedback","_world_feedback_cursor","shake"]: continue
			result[key] = _clean(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			if item is Dictionary and item.get("kind") == "world_feedback": continue
			result.append(_clean(item))
		return result
	return value
func _compare(a: RefCounted,b: RefCounted,label: String) -> void:
	_check(_clean(a.p) == _clean(b.p) and _clean(a.s) == _clean(b.s),label+" exact source p/s ignoring sole approved shake")
	_check(a.state.rng_seed == b.state.rng_seed,label+" unchanged gameplay RNG state")
	_check(a.state.npcs == b.state.npcs and a.state.cash_piles == b.state.cash_piles and a.state.projectiles == b.state.projectiles,label+" exact actors/pickups/projectiles")
	_check(_clean(a.drain_events()) == _clean(b.drain_events()),label+" exact ordered domain events after cosmetic projection")
func _paired_runtime() -> void:
	var sa := Spatial.new(); var sb := Spatial.new()
	var a: RefCounted = _new(Runtime,sa); var b: RefCounted = _new(Baseline,sb)
	_compare(a,b,"fresh")
	_check(a.enable_actor_simulation() and b.enable_actor_simulation(),"both actual source compositions enabled")
	for owner: RefCounted in [a,b]:
		var actor: Dictionary = _actor(owner,"lurch")
		actor.x = owner.p.x+24.0; actor.y = owner.p.y; actor.hp = 1000.0; actor.maxHp = 1000.0
		owner.attack(Vector2.RIGHT)
	_compare(a,b,"actual melee")
	for dt: float in [0.008,0.016,0.05,0.001]:
		a.advance(dt); b.advance(dt); _compare(a,b,"active step "+str(dt))
	for owner: RefCounted in [a,b]: owner.set_mode("paused"); owner.advance_wall(500.0); owner.advance(0.1)
	_compare(a,b,"paused wall callbacks")
	var save_a: Dictionary = a.snapshot(); var save_b: Dictionary = b.snapshot()
	_check(a.restore(save_a) and b.restore(save_b),"paired actual restore")
	_compare(a,b,"restore")
	groups += 1

func _grade_and_view() -> void:
	var content: Dictionary = Runtime.Content.load_content()
	var model := Grade.new(content.world)
	var view := GradeView.new(model)
	_check(view.sync(420,520,"playing"),"real district grade model binds")
	var offset := Vector2(1.25,-0.75)
	_check(view.set_world_feedback_offset(offset),"private grade accepts bounded offset")
	_check(view.material.get_shader_parameter("world_feedback_offset_px") == offset,"active material receives current offset")
	var regions: Array = content.world.terrainRegions
	for region: Dictionary in regions:
		view.sync(float(region.x)+1,float(region.y)+1,"playing")
		_check(view.material.get_shader_parameter("world_feedback_offset_px") == offset,"profile swap cannot reuse stale offset")
	var before: Dictionary = view.inspect()
	_check(not view.set_world_feedback_offset(Vector2(NAN,0)) and view.inspect() == before,"invalid shader offset is atomic")
	view.set_world_feedback_offset(Vector2.ZERO)
	_check(view.material.get_shader_parameter("world_feedback_offset_px") == Vector2.ZERO,"zero-strength branch exact zero uniform")
	view.set_world_feedback_offset(offset); view.clear()
	_check(view.material.get_shader_parameter("world_feedback_offset_px") == Vector2.ZERO,"clear immediately resets the current private material uniform")
	view.sync(420,520,"playing")
	_check(view.material.get_shader_parameter("world_feedback_offset_px") == Vector2.ZERO,"clear/profile rebind resets only passive uniform")
	view.free()
	groups += 1

func _scene_binding() -> void:
	var spatial := Spatial.new(); var runtime: RefCounted = _new(Runtime,spatial)
	var scene := SceneHarness.new()
	scene.runtime = runtime; scene.player = Node3D.new(); scene.camera = Camera3D.new()
	scene.add_child(scene.player); scene.player.add_child(scene.camera)
	scene.feedback_view = View.new(); scene.add_child(scene.feedback_view); scene.feedback_view.build()
	var hud := MinimalHud.new(); hud.district_grade = GradeView.new(Grade.new(Runtime.Content.load_content().world)); hud.add_child(hud.district_grade)
	scene.hud = hud; scene.add_child(hud); root.add_child(scene)
	scene.player.position = Vector3(12,0,18); scene.player.rotation.y = 0.7
	scene.camera.position = Vector3(0,1.6,0); scene.camera.rotation.x = -0.15
	var camera_before: Transform3D = scene.camera.global_transform
	var body_before: Transform3D = scene.player.global_transform
	var fov_before: float = scene.camera.fov
	var hud_before: Transform2D = hud.transform
	hud.district_grade.sync(runtime.state.player_center().x,runtime.state.player_center().y,"playing")
	scene._sync_feedback_context(); _emit(runtime,"essential"); runtime.drain_events()
	runtime.s.shake = 14.0
	scene._sync_world_feedback(1000.0)
	_check(scene.feedback_view.inspect().live == 1,"real Scene binding uploads current pool snapshot")
	_check(scene.camera.global_transform == camera_before and scene.player.global_transform == body_before and scene.camera.fov == fov_before and hud.transform == hud_before,"world shader feedback cannot alter actual camera/body/aim basis/FOV/HUD transform")
	var pool_before: Dictionary = runtime.feedback_snapshot()
	scene.loading = true; scene._sync_world_feedback(1017.0)
	_check(hud.district_grade.inspect().world_feedback_offset == Vector2.ZERO and runtime.feedback_snapshot() == pool_before,"loading suppression is passive and keeps pool untouched")
	scene.loading = false; runtime.s.mode = "paused"; scene._sync_world_feedback(1034.0)
	_check(hud.district_grade.inspect().world_feedback_offset == Vector2.ZERO,"actual modal Scene binding suppresses displacement")
	runtime.s.mode = "title"; scene._sync_world_feedback(1051.0)
	_check(scene.feedback_view.inspect().live == 0 and runtime.feedback_snapshot() == pool_before,"title clears only visible bank without a second model reset")
	scene.free()
	groups += 1
