extends SceneTree
## Isolated draft gate; no runtime/controller/physics/native acceptance claim.
const Feedback = preload("../scripts/world_feedback.gd")
const View = preload("../scripts/world_feedback_view.gd")
const EPS := 0.0002 # Source-pixel coordinate/velocity comparison across float32 Vector values.
var checks: int = 0
var failures: Array[String] = []
var failure_count: int = 0
var renderer_readback: bool = false
var renderer_vertex_checks: int = 0
var groups: int = 0
var fixture_count: int = 0

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failure_count += 1
		if failures.size() < 32: failures.append(label)
func _near(a: float,b: float,tolerance: float = EPS) -> bool: return absf(a-b) <= tolerance
func _receipt(recipe: String = "essential",epoch: int = 1) -> Dictionary:
	var result := {"epoch":epoch,"recipe":recipe,"source_point":Vector2(114,216),"world_anchor":Vector3(1,1.2,-2),"birth_right":Vector3.RIGHT,"width":38.0,"phase":2,"sings":false}
	if recipe == "walking_dust": result.samples = [0.1,0.2,0.3,0.4,0.5]; result.intent_x = 0.5
	if recipe == "ambient_mote": result.samples = [0.1,0.2,0.3,0.4,0.5,0.6,0.7]; result.rain = false
	return result
func _pool(seed_value: int = 1) -> Feedback:
	var pool := Feedback.new(seed_value); pool.reset_epoch(1); return pool

func _recipes() -> void:
	var filename: String = get_script().resource_path.get_base_dir()+"/fixtures/world_feedback_reference.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(filename))
	_check(parsed is Dictionary and parsed.get("cases") is Array,"source recipe fixture parsed")
	if not parsed is Dictionary or not parsed.get("cases") is Array: return
	var names: Array[String] = []
	for recipe: Dictionary in parsed.recipes: names.append(recipe.id)
	_check(names == Feedback.BURST_RECIPES and Feedback.supported_recipes() == names+Feedback.DUST_RECIPES,"exact18 unchanged-source burst identities/order plus two explicitly tested dust recipes")
	for row: Dictionary in parsed.cases:
		var pool := _pool(int(row.seed)); var receipt: Dictionary = _receipt(str(row.recipe))
		receipt.source_point = Vector2(row.source_point[0],row.source_point[1])
		receipt.width = float(row.width); receipt.phase = int(row.phase); receipt.sings = bool(row.sings)
		var before: Dictionary = receipt.duplicate(true)
		_check(pool.accept(receipt),"accept source recipe "+row.id)
		_check(receipt == before,"receipt remains detached "+row.id)
		var actual: Array = pool.snapshot().particles
		_check(actual.size() == row.expected.size(),"source particle count "+row.id)
		_check(pool.inspect().rng_draws == row.rng_draws and pool.inspect().rng_state == row.rng_state,"source cosmetic draw count/state "+row.id)
		for index: int in range(mini(actual.size(),row.expected.size())):
			var got: Dictionary = actual[index]; var expected: Dictionary = row.expected[index]
			var point: Vector2 = got.source_point+got.offset
			_check(_near(point.x,expected.x) and _near(point.y,expected.y),"source origin "+row.id+"/"+str(index))
			_check(_near(got.velocity.x,expected.vx) and _near(got.velocity.y,expected.vy),"source velocity "+row.id+"/"+str(index))
			_check(_near(got.life,expected.life,1e-9) and _near(got.size,expected.size,1e-9) and _near(got.gravity,expected.gravity,1e-9) and got.glow == expected.glow,"source lifetime/size/gravity/glow "+row.id)
			var color_ok: bool = true
			for channel: int in range(4): color_ok = color_ok and _near(got.color[channel],expected.color[channel],0.000001)
			_check(color_ok,"literal source color/alpha "+row.id)
		fixture_count += 1
	_check(fixture_count == 84,"all84 source cases completed")
	groups += 1

func _recurrence() -> void:
	for recipe: String in Feedback.supported_recipes():
		var whole := _pool(923); var split := _pool(923)
		whole.accept(_receipt(recipe)); split.accept(_receipt(recipe))
		var initial: Array = whole.snapshot().particles
		_check(whole.advance_particles(Feedback.STEP_MS),"one source60Hz pass")
		split.advance_particles(Feedback.STEP_MS*0.25); split.advance_particles(Feedback.STEP_MS*0.75)
		var after: Array = whole.snapshot().particles; var pieces: Array = split.snapshot().particles
		_check(after.size() == initial.size() and pieces.size() == after.size(),"step keeps live source recipe "+recipe)
		for index: int in range(after.size()):
			var a: Dictionary = after[index]; var start: Dictionary = initial[index]; var b: Dictionary = pieces[index]
			var source_offset: Vector2 = start.offset+start.velocity
			var source_velocity: Vector2 = start.velocity*0.92+Vector2(0,start.gravity)
			_check(a.offset.distance_to(source_offset) < EPS and a.velocity.distance_to(source_velocity) < EPS and _near(a.life,start.life-Feedback.STEP_MS,1e-8),"unchanged source60Hz recurrence "+recipe)
			_check(a.offset.distance_to(b.offset) < EPS and a.velocity.distance_to(b.velocity) < EPS and _near(a.life,b.life,1e-8),"split-step analytic equivalence "+recipe)
		_check(whole.inspect().rng_draws == split.inspect().rng_draws,"advancement draws no RNG")
		_check(whole.advance_particles(240000) and whole.inspect().live == 0,"supported catch-up expires bounded pool "+recipe)
	var before_pass := _pool(); var after_pass := _pool()
	before_pass.accept(_receipt()); before_pass.advance_particles(10.0)
	after_pass.advance_particles(10.0); after_pass.accept(_receipt())
	_check(_near(before_pass.snapshot().particles[0].life,410,1e-9) and _near(after_pass.snapshot().particles[0].life,420,1e-9),"source pre-pass vs late projectile/boss birth lifetime")
	_check(before_pass.snapshot().particles[0].offset != after_pass.snapshot().particles[0].offset,"birth order affects first movement")
	groups += 1

func _capacity() -> void:
	var pool := _pool()
	for _index: int in range(219): pool.accept(_receipt("melee_flash"))
	pool.advance_particles(Feedback.STEP_MS)
	_check(pool.inspect().live == 219,"pre-pass source capacity below220")
	pool.accept(_receipt("tony_coat"))
	var stats: Dictionary = pool.inspect(); var rows: Array = pool.snapshot().particles
	_check(stats.requested == 243 and stats.emitted == 243 and stats.evicted == 23 and stats.live == 220 and stats.peak == 220,"approved tighter late-birth cap retains count/eviction evidence")
	_check(rows[0].serial == 24 and rows[-1].serial == 243,"strict oldest-first eviction")
	_check(rows[-1].life == 1400.0 and rows[-1].offset == Vector2.ZERO,"late coat birth retains full source life")
	for _index: int in range(100): pool.accept(_receipt("tony_coat"))
	_check(pool.inspect().live == 220 and pool.snapshot().particles.size() == 220,"repeated accepted bursts cannot grow past220")
	var retained: Dictionary = pool.snapshot()
	retained.particles[0].life = 99999; retained.particles.clear(); retained.stats.live = -50
	_check(pool.inspect().live == 220 and pool.snapshot().particles[0].life == 1400.0,"snapshots cannot mutate pool")
	groups += 1

func _invalid() -> void:
	var pool := _pool(); pool.accept(_receipt("holy_impact"))
	var cases: Array[Dictionary] = [{"epoch":0},{"epoch":2},{"epoch":1.0},{"recipe":"dust"},{"recipe":&"essential"},{"source_point":Vector2(INF,0)},{"source_point":Vector2(1e8,0)},{"world_anchor":Vector3(0,NAN,0)},{"world_anchor":Vector3(1e8,0,0)},{"birth_right":Vector3.ZERO},{"birth_right":Vector3(0,0.000005,0)},{"birth_right":Vector3.UP},{"birth_right":Vector3(1e30,0,0)},{"sings":1},{"recipe":"tony_coat","phase":1},{"recipe":"tony_coat","phase":2.0},{"recipe":"dumpster_rats","width":-1},{"recipe":"dumpster_rats","width":INF}]
	for patch: Dictionary in cases:
		var receipt: Dictionary = _receipt(); receipt.merge(patch,true)
		var before: Dictionary = pool.snapshot()
		_check(not pool.accept(receipt) and pool.snapshot() == before,"invalid/stale receipt atomically refuses "+str(patch))
	for key: String in ["recipe","source_point","world_anchor","birth_right","epoch"]:
		var receipt: Dictionary = _receipt(); receipt.erase(key); var before: Dictionary = pool.snapshot()
		_check(not pool.accept(receipt) and pool.snapshot() == before,"required receipt field "+key)
	for value: Variant in [0,-1,INF,NAN,240000.1,"16",null,true]:
		var before: Dictionary = pool.snapshot()
		_check(not pool.advance_particles(value) and pool.snapshot() == before,"invalid dt does not partially expire/render "+str(value))
	groups += 1

func _lifecycle() -> void:
	var pool := _pool(42); pool.accept(_receipt("melee_sparks"))
	var first: Array = pool.snapshot().particles; var old: Dictionary = pool.snapshot()
	_check(pool.reset_epoch(2) and pool.inspect().live == 0 and pool.inspect().rng_draws == 0,"explicit epoch clears unsaved presentation")
	var empty: Dictionary = pool.snapshot()
	_check(not pool.accept(_receipt("melee_sparks",1)) and pool.snapshot() == empty,"old epoch cannot add a new-world effect")
	pool.accept(_receipt("melee_sparks",2)); var same: Array = pool.snapshot().particles
	_check(same == first and old.particles == first,"independent epoch replays cosmetic seed only; old snapshot detached")
	_check(pool.reset_epoch(2) and pool.inspect().live == 0,"explicit same-epoch presentation reset clears effects")
	var before: Dictionary = pool.snapshot()
	_check(not pool.reset_epoch(0) and pool.snapshot() == before,"invalid reset preserves pool")
	seed(9324); var expected: float = randf(); seed(9324)
	pool.accept(_receipt("tony_coat",2)); pool.advance_particles(13.0)
	Feedback.world_offset(14,2222,Vector2(1280,720),"playing")
	_check(randf() == expected,"pool and offset never consume engine global RNG")
	groups += 1

func _offset() -> void:
	var viewport := Vector2(1280,720)
	var first: Vector2 = Feedback.world_offset(14,1.0,viewport,"playing")
	_check(first == Feedback.world_offset(14,Feedback.STEP_MS-0.00001,viewport,"playing"),"offset constant inside one60Hz sample")
	_check(first != Feedback.world_offset(14,Feedback.STEP_MS+0.00001,viewport,"playing"),"offset updates at next60Hz sample")
	for tick: int in range(600):
		var value: Vector2 = Feedback.world_offset(14,tick*Feedback.STEP_MS,viewport,"playing")
		_check(value.is_finite() and absf(value.x) <= 2 and absf(value.y) <= 2,"approved per-axis2px comfort bound")
		_check(value == Feedback.world_offset(14,tick*Feedback.STEP_MS,viewport,"playing"),"offset independent of render call count")
		_check((value*0.75).distance_to(Feedback.world_offset(14,tick*Feedback.STEP_MS,Vector2(960,540),"playing")) < 0.000001,"offset scales with actual viewport height")
	for mode: String in ["title","paused","dialogue","cookmini","ending","loading"]:
		_check(Feedback.world_offset(14,200,viewport,mode) == Vector2.ZERO,"offset suppressed for "+mode)
	_check(Feedback.world_offset(14,200,viewport,"playing",1.0,false) == Vector2.ZERO and Feedback.world_offset(14,200,viewport,"playing",1.0,true,true) == Vector2.ZERO,"focus/loading suppress without amplitude mutation")
	_check(Feedback.world_offset(14,200,viewport,"playing",0) == Vector2.ZERO and Feedback.world_offset(-3,200,viewport,"playing") == Vector2.ZERO,"zero strength/negative amplitude are still")
	for value: Variant in [NAN,INF,null,"14",true]:
		_check(Feedback.world_offset(value,200,viewport,"playing") == Vector2.ZERO,"invalid shake fails closed")
		_check(Feedback.world_offset(14,value,viewport,"playing") == Vector2.ZERO,"invalid visual time fails closed")
	_check(Feedback.world_offset(14,-1,viewport,"playing") == Vector2.ZERO and Feedback.world_offset(14,1e13,viewport,"playing") == Vector2.ZERO,"bounded clock range")
	for size: Variant in [Vector2.ZERO,Vector2(20000,720),Vector2(INF,720),null]:
		_check(Feedback.world_offset(14,200,size,"playing") == Vector2.ZERO,"invalid viewport fails closed")
	_check(_near(Feedback.decayed_shake(14,Feedback.STEP_MS),12.6,1e-10),"source.9 decay at60Hz")
	var split: float = Feedback.decayed_shake(Feedback.decayed_shake(14,5),15)
	_check(_near(split,Feedback.decayed_shake(14,20),1e-10),"tail amplitude split equivalence")
	_check(Feedback.decayed_shake(14,0) == 14 and Feedback.decayed_shake(14,INF) == 14,"invalid/no active world time cannot decay")
	groups += 1

func _readback_probe() -> bool:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D; instances.use_colors = true; instances.instance_count = 1
	var submitted := Transform3D(Basis.IDENTITY,Vector3(3,4,5))
	var bounds := AABB(Vector3(2,3,4),Vector3(2,3,4))
	var color := Color(0.25,0.5,0.75,1)
	instances.set_instance_transform(0,submitted); instances.set_instance_color(0,color); instances.custom_aabb = bounds
	var got: Transform3D = instances.get_instance_transform(0)
	var got_bounds: AABB = instances.custom_aabb
	var got_color: Color = instances.get_instance_color(0)
	var supported: bool = got == submitted and got_bounds == bounds and got_color == color
	print("FEEDBACK MULTIMESH READBACK: ",JSON.stringify({"display":DisplayServer.get_name(),"supported":supported,"origin":str(got.origin),"aabb":str(got_bounds),"color":str(got_color)}))
	if DisplayServer.get_name() == "headless":
		_check(not supported and got == Transform3D.IDENTITY,"pinned dummy readback cannot be counted as submitted GPU geometry")
	else: _check(supported,"real renderer roundtrips the explicit transform/color/AABB sentinel")
	if "--require-feedback-renderer" in OS.get_cmdline_user_args(): _check(supported,"mandatory real-renderer readback gate cannot run with dummy storage")
	return supported

func _view() -> void:
	renderer_readback = _readback_probe()
	var pool := _pool()
	for recipe: String in Feedback.supported_recipes(): pool.accept(_receipt(recipe))
	var first := View.new(); var second := View.new(); root.add_child(first); root.add_child(second)
	_check(first.build() and first.build() and second.build(),"build is bounded/idempotent")
	var snapshot: Dictionary = pool.snapshot(); var before: Dictionary = snapshot.duplicate(true)
	_check(first.sync(snapshot) and second.sync(snapshot) and snapshot == before,"passive views leave snapshot/model unchanged")
	var stats: Dictionary = first.inspect()
	_check(stats.banks == 4 and stats.allocated_slots == 880 and stats.live <= 220 and stats.triangles <= 880 and stats.meshes == 2 and stats.materials == 2,"declared renderer resource/draw/triangle limits")
	_check(first.get_child_count() == 4 and not first.is_processing() and not first.is_physics_processing(),"no per-particle node or autonomous clock")
	for key: String in View.BANKS:
		var a: MultiMeshInstance3D = first.get_node(key); var b: MultiMeshInstance3D = second.get_node(key)
		_check(a.multimesh != b.multimesh and a.multimesh.mesh == b.multimesh.mesh and a.material_override == b.material_override,"immutable shared resources, independent transform buffers "+key)
		_check(a.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and a.multimesh.use_colors,"feedback does not cast shadows")
		var material: StandardMaterial3D = a.material_override
		_check(not material.no_depth_test and material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED and material.vertex_color_use_as_albedo and not material.emission_enabled and material.albedo_texture == null,"depth-tested unlit original colored geometry")
		var arrays: Array = a.multimesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		_check(vertices.size() == 12 and normals.size() == vertices.size(),"nonempty original geometry "+key)
		for index: int in range(vertices.size()):
			_check(vertices[index].is_finite() and normals[index].is_finite() and _near(normals[index].length(),1.0,0.00001),"finite unit mesh normal")
			_check(vertices[index].length() <= 0.866026,"original mesh vertices lie inside independent conservative unit-radius sphere")
		if renderer_readback:
			for instance: int in range(a.multimesh.visible_instance_count):
				var pose: Transform3D = a.multimesh.get_instance_transform(instance)
				for vertex: Vector3 in vertices:
					renderer_vertex_checks += 1
					_check(a.multimesh.custom_aabb.has_point(pose*vertex),"actual visible geometry fits bank bound")
				var color: Color = a.multimesh.get_instance_color(instance)
				_check(color.a >= 0 and color.a <= 1,"bounded per-instance output alpha")
	var second_before: Dictionary = second.inspect()
	first.clear(); _check(first.inspect().live == 0 and second.inspect() == second_before,"clear cannot hide another view")
	var invalid: Dictionary = snapshot.duplicate(true); invalid.particles[-1].offset = Vector2(INF,0)
	_check(not first.sync(invalid) and first.inspect().live == 0,"whole-snapshot validation prevents partial visible upload")
	_check(second.sync(snapshot) and pool.snapshot() == before,"presentation does not advance source lifetimes or seed")
	first.free(); second.free(); groups += 1

func _run() -> void:
	_recipes(); _recurrence(); _capacity(); _invalid(); _lifecycle(); _offset(); _view()
	_check(groups == 7 and fixture_count == 84,"all7 groups and84 source cases reached completion")
	if "--require-feedback-renderer" in OS.get_cmdline_user_args(): _check(renderer_readback and renderer_vertex_checks > 0,"mandatory native geometry containment group completed")
	if failure_count == 0: print("WORLD FEEDBACK DRAFT: PASS (%d checks; %d supported recipes; %d unchanged burst source cases; renderer_readback=%s; actual_vertex_checks=%d; native readback required separately when false)" % [checks,Feedback.RECIPES.size(),fixture_count,str(renderer_readback),renderer_vertex_checks])
	else:
		for failure: String in failures: push_error(failure)
		print("WORLD FEEDBACK DRAFT: FAIL (%d/%d checks; printed first%d failures)" % [failure_count,checks,failures.size()])
	quit(0 if failure_count == 0 else 1)
