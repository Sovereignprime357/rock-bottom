extends SceneTree
const Dust = preload("res://scripts/world_dust.gd")
const Pool = preload("res://scripts/world_feedback.gd")
const View = preload("res://scripts/world_feedback_view.gd")
const Runtime = preload("res://scripts/full_runtime.gd")
const Content = preload("res://scripts/content_catalog.gd")
const EPS := 0.00025 # Float32 source-coordinate vectors; scalar timer/RNG checks are tighter.
var checks: int = 0
var failures: int = 0
var groups: int = 0
var cases: int = 0
var data: Dictionary

class Spatial extends RefCounted:
	var blocked: bool = false
	func move_body(body: Dictionary,point: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary: return {"position":Vector2(body.x,body.y) if blocked else point,"blocked":blocked}
	func can_reach_target(_id: String) -> bool: return true
	func can_use_zone(_id: String) -> bool: return true
	func clear_placement(body: Dictionary) -> Variant: return Vector2(body.x,body.y)
	func can_hit(_a: Vector2,_b: Vector2,_source: String,_target: String) -> bool: return true
	func sweep_projectile(_a: Vector2,b: Vector2,_r: float) -> Dictionary: return {"blocked":false,"fraction":1.0,"position":b}

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures <= 24: push_error(label)
func _near(a: float,b: float,epsilon: float = EPS) -> bool: return absf(a-b) <= epsilon
func _runtime(spatial: RefCounted) -> RefCounted:
	var runtime := Runtime.new(spatial,null,func(): return 1000000.0)
	runtime.fresh(); runtime.drain_events(); return runtime
func _birth(expected: Dictionary,row: Dictionary,label: String) -> void:
	var point: Vector2 = row.source_point+row.offset
	_check(_near(point.x,expected.x) and _near(point.y,expected.y),label+" exact source x/y")
	_check(_near(row.velocity.x,expected.vx) and _near(row.velocity.y,expected.vy),label+" exact source vx/vy")
	_check(_near(row.life,expected.life,1e-8) and row.size == expected.sz and row.gravity == 0.0 and not row.glow,label+" life/size/no glow/gravity")
	var channels: PackedStringArray = str(expected.c).trim_prefix("rgba(").trim_suffix(")").split(",")
	var color: Color = row.color
	for i: int in range(4): _check(_near(color[i],float(channels[i])/(255.0 if i < 3 else 1.0),0.000001),label+" literal color channel"+str(i))

func _source_cases() -> void:
	for row: Dictionary in data.cases:
		var dust := Dust.new(int(row.seed)); dust.reset_epoch(1)
		var pool := Pool.new(77); pool.reset_epoch(1)
		var walking: bool = row.kind == "walk"
		if row.timer != null:
			if walking: dust._walk_ms = float(row.timer)
			else: dust._ambient_ms = float(row.timer)
		for step: Dictionary in row.steps:
			var receipt: Dictionary
			if "/fixed/" in str(row.id):
				# Endpoint variates exercise exact source formulas without adding RNG injection to production.
				receipt = {"epoch":1,"recipe":"walking_dust" if walking else "ambient_mote","source_point":Vector2(1062,866) if walking else Vector2(step.births[0].x,step.births[0].y),"world_anchor":Vector3.ZERO,"birth_right":Vector3.RIGHT,"samples":step.samples.duplicate(),"intent_x":float(step.step.get("vx",0)),"rain":row.get("weather","") == "rain"}
			elif walking:
				receipt = dust.walk(float(step.step.dt),1,Rect2(1050,840,24,28),Vector2(step.step.vx,step.step.vy),Vector3.RIGHT)
			else:
				receipt = dust.ambient(float(step.step.dt),1,str(row.weather),Transform3D.IDENTITY,78.0,16.0/9.0)
			_check(receipt.is_empty() == step.births.is_empty(),str(row.id)+" source due/strict/discard result")
			if not "/fixed/" in str(row.id):
				var state: Dictionary = dust.inspect()
				_check(_near(state.walk_ms if walking else state.ambient_ms,0.0 if step.clock == null else float(step.clock),1e-8),str(row.id)+" exact clock")
				_check(state.rng_state == int(step.rng_state) and state.rng_draws == int(step.rng_draws),str(row.id)+" exact independent draw sequence")
			if not receipt.is_empty() and not step.births.is_empty():
				if "/fixed/" in str(row.id):
					_check(receipt.samples == step.samples,str(row.id)+" exact supplied formula variates")
				else:
					# Decimal JSON parsing may round a sample differently by one binary64 bit.
					# Exact integer draws survive JSON unchanged; no RNG tolerance is applied.
					_check(receipt.samples.size() == step.numerators.size(),str(row.id)+" exact source variate count")
					for i: int in range(mini(receipt.samples.size(),step.numerators.size())):
						var numerator: int = int(step.numerators[i])
						_check(numerator > 0 and numerator < 2147483647 and float(numerator) == float(step.numerators[i]),str(row.id)+" exact integer source draw"+str(i))
						_check(receipt.samples[i] == float(numerator)/2147483647.0,str(row.id)+" exact detached source variate"+str(i))
				_check(pool.accept(receipt),str(row.id)+" shared pool accepts named birth")
				_birth(step.births[0],pool.snapshot().particles[-1],str(row.id))
			_check(pool.inspect().rng_draws == 0,"dust admission leaves original18 burst RNG untouched")
		cases += 1
	_check(cases == 72,"all72 unchanged-source schedule/formula cases completed")
	groups += 1

func _source_intent() -> void:
	for row: Dictionary in data.movementCases:
		var spatial := Spatial.new(); spatial.blocked = row.blocked
		var runtime: RefCounted = _runtime(spatial)
		for key: String in ["x","y","w","h","speed","stunT","slowT","rockedT","crashT"]:
			runtime.p[key] = {"x":1050.0,"y":840.0,"w":24.0,"h":28.0,"speed":2.6,"stunT":float(row.stunT),"slowT":0.0,"rockedT":0.0,"crashT":0.0}[key]
		# Pin this independent cosmetic stream to the oracle seed; no gameplay RNG reset.
		runtime.world_dust = Dust.new(7); runtime.world_dust.reset_epoch(runtime._feedback_epoch); runtime.world_dust._walk_ms = 110.0
		var result: Dictionary = runtime._move_player(16.0,{"input_vector":Vector2.RIGHT})
		runtime._dust_walk(16.0,result)
		var particles: Array = runtime.feedback_snapshot().particles
		_check(_near(runtime.p.x,row.expected.x) and _near(runtime.p.y,row.expected.y),row.id+" actual Runtime source placement")
		_check(particles.size() == row.births.size(),row.id+" filtered intent emits despite blocked displacement")
		if not particles.is_empty(): _birth(row.births[0],particles[0],row.id)
	groups += 1

func _invalid_and_epochs() -> void:
	var dust := Dust.new(3); dust.reset_epoch(4)
	var pool := Pool.new(5); pool.reset_epoch(4)
	var before: Dictionary = dust.inspect()
	for dt: Variant in [0,-1,INF,NAN,"16",240001.0]:
		_check(dust.walk(dt,4,Rect2(0,0,24,28),Vector2.RIGHT,Vector3.RIGHT).is_empty() and dust.inspect() == before,"invalid walk dt atomic")
		_check(dust.ambient(dt,4,"clear",Transform3D.IDENTITY,78.0,16.0/9.0).is_empty() and dust.inspect() == before,"invalid mote dt atomic")
	for intent: Variant in [Vector2(INF,0),Vector2(1,1),Vector2(1.000002,0),Vector2(NAN,0),"right"]:
		_check(dust.walk(16,4,Rect2(0,0,24,28),intent,Vector3.RIGHT).is_empty() and dust.inspect() == before,"invalid intent atomic")
	for camera: Variant in [Transform3D(Basis.IDENTITY,Vector3(INF,0,0)),Transform3D(Basis(Vector3.ONE,Vector3.ONE,Vector3.ONE),Vector3.ZERO),Transform3D(Basis.IDENTITY,Vector3(1e6,0,0)),"camera"]:
		_check(dust.ambient(16,4,"clear",camera,78.0,16.0/9.0).is_empty() and dust.inspect() == before,"invalid camera/overflow volume atomic")
	_check(dust.walk(111,3,Rect2(0,0,24,28),Vector2.RIGHT,Vector3.RIGHT).is_empty() and dust.inspect() == before,"old epoch refuses without timer/RNG")
	var receipt: Dictionary = dust.walk(111,4,Rect2(0,0,24,28),Vector2.RIGHT,Vector3.RIGHT)
	for samples: Array in [[],[0.0],[0.0,0.0,0.0,0.0,INF],[0.0,0.0,0.0,0.0,1.0],[0.0,0.0,0.0,0.0,-0.01],[0.0,0.0,0.0,0.0,"0"]]:
		var bad: Dictionary = receipt.duplicate(true); bad.samples = samples
		var prior: Dictionary = pool.snapshot()
		_check(not pool.accept(bad) and pool.snapshot() == prior,"new recipe sample validation rejects atomically")
	_check(pool.accept(receipt),"valid walking receipt accepts")
	var retained: Dictionary = pool.snapshot(); receipt.samples[0] = 0.99
	_check(pool.snapshot() == retained,"samples are resolved once and never retained by reference")
	dust.walk(70,4,Rect2(0,0,24,28),Vector2.RIGHT,Vector3.RIGHT); before = dust.inspect()
	_check(before.walk_ms == 70.0,"private partial clock exists")
	dust.reset_epoch(5); pool.reset_epoch(5)
	_check(dust.inspect().walk_ms == 0.0 and dust.inspect().ambient_ms == 0.0 and dust.inspect().rng_draws == 0 and pool.inspect().live == 0,"documented3D generation reset removes unsaved source carry")
	_check(not pool.accept(receipt),"old receipt cannot enter replacement generation")
	groups += 1

func _geometry_and_life() -> void:
	var dust := Dust.new(7); dust.reset_epoch(1)
	var pool := Pool.new(5); pool.reset_epoch(1)
	var foot: Dictionary = dust.walk(111,1,Rect2(1050,840,24,28),Vector2.RIGHT,Vector3.RIGHT)
	_check(foot.world_anchor == Content.to_world(Vector2(1062,866),0.08) and foot.world_anchor.distance_to(Vector3(0.48,0.08,1.04)) < 0.000001,"actual foot uses canonical source-origin subtraction, not a42m/33.6m displaced anchor")
	var camera := Transform3D(Basis.from_euler(Vector3(-0.2,0.8,0)),Vector3(20,1.65,30))
	var receipt: Dictionary = dust.ambient(1,1,"rain",camera,78.0,16.0/9.0)
	var local: Vector3 = camera.affine_inverse()*receipt.world_anchor
	var depth: float = -local.z; var half_y: float = depth*tan(deg_to_rad(78.0)*0.5)
	_check(depth >= 2 and depth <= 8 and absf(local.x) <= half_y*(16.0/9.0)+0.00001 and local.y >= -half_y-0.00001 and local.y <= half_y*(1.0+8.0/600.0)+0.00001,"actual frozen birth lies in declared perspective volume")
	_check(pool.accept(receipt),"mote admits")
	var held: Dictionary = pool.snapshot(); var anchor: Vector3 = held.particles[0].world_anchor
	dust.ambient(1,1,"clear",Transform3D(Basis.from_euler(Vector3(0,2,0)),Vector3(400,10,-600)),78.0,16.0/9.0)
	_check(pool.snapshot() == held and pool.snapshot().particles[0].world_anchor == anchor,"later camera turn/translation cannot move existing birth")
	var row: Dictionary = held.particles[0].duplicate(true)
	_check(View._valid_row(row),"named long-lived mote passes existing renderer validation")
	row.life = 6000.0001; _check(not View._valid_row(row),"mote lifetime ceiling remains6000")
	row.recipe = "melee_rust"; row.life = 1400.0001; _check(not View._valid_row(row),"old recipe lifetime ceiling is not loosened")
	row.recipe = "walking_dust"; row.life = 580.0001; _check(not View._valid_row(row),"walking ceiling remains580")
	var view := View.new(); root.add_child(view); view.build()
	_check(view.sync(held) and view.inspect().banks == 4 and view.inspect().meshes == 2 and view.inspect().materials == 2,"dust reuses same four banks/two meshes/two materials")
	view.free(); groups += 1

func _shared_capacity() -> void:
	var dust := Dust.new(8); dust.reset_epoch(1)
	var pool := Pool.new(3); pool.reset_epoch(1)
	for index: int in range(240):
		var receipt: Dictionary = dust.ambient(1000,1,"clear",Transform3D.IDENTITY,78.0,16.0/9.0) if index%2 == 0 else dust.walk(111,1,Rect2(0,0,24,28),Vector2.RIGHT,Vector3.RIGHT)
		_check(pool.accept(receipt),"mixed named dust accepted into sole pool")
	_check(pool.inspect().live == 220 and pool.inspect().evicted == 20 and pool.snapshot().particles[0].serial == 21,"mixed walking/motes share oldest-first220 cap")
	pool.accept({"epoch":1,"recipe":"tony_coat","source_point":Vector2.ZERO,"world_anchor":Vector3.ZERO,"birth_right":Vector3.RIGHT,"phase":2})
	_check(pool.inspect().live == 220 and pool.inspect().evicted == 44 and pool.snapshot().particles[-1].recipe == "tony_coat","original combat bursts compete in the same220 pool")
	var view := View.new(); root.add_child(view); view.build(); _check(view.sync(pool.snapshot()) and view.inspect().triangles <= 880,"combined crowd respects880triangle view cap"); view.free()
	groups += 1

func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_dust_reference.json"))
	_check(parsed is Dictionary and parsed.get("cases") is Array,"unchanged-source dust fixture exists")
	if not parsed is Dictionary: quit(1); return
	data = parsed
	_source_cases(); _source_intent(); _invalid_and_epochs(); _geometry_and_life(); _shared_capacity()
	_check(groups == 5 and cases == 72 and data.movementCases.size() == 6,"all focused groups/cases completed")
	print("WORLD DUST DRAFT: ","PASS" if failures == 0 else "FAIL","; ",checks," checks; ",cases," source cases;6 source intent witnesses;",groups," groups; no native/Web acceptance.")
	quit(0 if failures == 0 else 1)
