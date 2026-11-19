extends SceneTree
const World = preload("res://scripts/full_neighborhood.gd")
const Weather = preload("res://scripts/weather_presentation.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
class State extends "res://scripts/game_state.gd":
	var draws := 0
	func random_float() -> float: draws += 1; return 0.4
var world: Node3D
var camera: Camera3D
var weather: Node3D
var state: RefCounted
var adapter: RefCounted
var checks := 0
var failures: Array[String] = []
var visual_ms := 0.0
func _initialize() -> void: call_deferred("_run")
func _check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _near(a: float,b: float,epsilon: float = 0.000002) -> bool: return absf(a-b) <= epsilon
func _snapshot(kind: String = "rain",t: float = 0.65,generator: bool = false) -> Dictionary:
	return {"dayTime":t,"weather":kind,"office_generator":generator,"geometry_revision":int(adapter._collision_revision)}
func _sync(snapshot: Dictionary) -> Dictionary:
	visual_ms += 251.0; _check(weather.sync(snapshot,visual_ms),"valid presentation sync")
	var view: Dictionary = weather.inspect(); _check(int(view.queries) <= 4,"hard four-column query cap")
	return view
func _model() -> Dictionary: return {"p":state.p.duplicate(true),"s":state.s.duplicate(true),"actors":state.npcs.duplicate(true),"events":state.events.duplicate(true),"draws":state.draws}
func _submitted_transform(index: int) -> Transform3D:
	# Pinned4.5.1 dummy backend returns identity from get_instance_transform,
	# but retains the actual submitted buffer. Decode its GLES3 row layout here;
	# the native probe additionally compares the real renderer instance getter.
	var buffer: PackedFloat32Array = weather.rain.multimesh.buffer
	_check(buffer.size() == 160*12,"actual submitted multimesh buffer has exact1920 floats")
	if buffer.size() != 160*12: return Transform3D.IDENTITY
	var i: int = index*12
	return Transform3D(Basis(Vector3(buffer[i],buffer[i+4],buffer[i+8]),Vector3(buffer[i+1],buffer[i+5],buffer[i+9]),Vector3(buffer[i+2],buffer[i+6],buffer[i+10])),Vector3(buffer[i+3],buffer[i+7],buffer[i+11]))
func _source_oracle(fixture: Dictionary) -> void:
	_check(int(fixture.counts.curve) == 49 and fixture.curve.size() == 49 and int(fixture.counts.weather) == 48 and fixture.cases.size() == 48 and int(fixture.counts.fixtures) == 936 and fixture.fixtures.size() == 936 and int(fixture.counts.definitions) == 39 and fixture.definitions.size() == 39,"complete independent source fixture census")
	for row: Dictionary in fixture.curve:
		_check(_near(Weather.night_amount(row.t),row.night,0.00000001),"source exact curve "+str(row.t))
	for row: Dictionary in fixture.cases:
		_check(row.stateUnchanged and row.rngDraws == 0,"source renderer has no model/random effects")
		if row.weather == "rain":
			_check(row.lines.size() == 160 and row.strokes == 160 and row.lineWidth == 1,"source rain has160 one-pixel strokes")
			for index: int in range(160):
				var line: Dictionary = Weather.source_rain_line(index,row.visual_ms)
				_check(line.from.distance_to(Vector2(row.lines[index].from[0],row.lines[index].from[1])) < 0.0001,"unchanged source rain start")
				_check(line.to.distance_to(Vector2(row.lines[index].to[0],row.lines[index].to[1])) < 0.0001,"unchanged source rain end")
		elif row.weather == "fog":
			_check(row.images.size() == 1 and _near(Weather.fog_opacity(row.t),row.images[0].alpha,0.00000001),"source night fog attenuation")
		else: _check(row.lines.is_empty() and row.images.is_empty(),"source clear draws no precipitation")
	var last_group := ""; var current: Dictionary = {}
	for row: Dictionary in fixture.fixtures:
		var group: String = str(row.t)+str(row.generator)
		if group != last_group:
			current.clear()
			for light: Dictionary in _sync(_snapshot("clear",row.t,row.generator)).fixtures: current[light.id] = light
			last_group = group
		_check(current.has(row.id),"real source fixture bound "+row.id)
		if current.has(row.id):
			_check(_near(float(current[row.id].energy),float(current[row.id].power)*float(row.level)),"real native energy follows exact source level "+row.id)
	var day: Dictionary = _sync(_snapshot("clear",0.65)); var energy: float = world.sun.light_energy
	_check(day.profile.night == 0 and _near(energy,0.9),".65 is fully daytime instead of inherited sinusoid")
	_sync(_snapshot("clear",0.9)); _check(world.sun.light_energy < energy and _near(world.sun.light_energy,0.144),"source night drives readable native floor")
	_sync(_snapshot("fog",0.65)); var day_density: float = world.environment.fog_density
	_sync(_snapshot("fog",0.9)); _check(world.environment.fog_density < day_density,"fog density reduces at night with source opacity")
func _resources_and_purity() -> void:
	var before: Dictionary = _model(); var original: Dictionary = _snapshot("clear")
	var copy_at: Dictionary = original.duplicate(true); var first: Dictionary = _sync(original)
	_check(first.instances == 160 and first.triangles == 320 and first.surfaces == 1,"single160-instance320-triangle original rain mesh")
	_check(weather.rain.multimesh.mesh.get_surface_count() == 1 and weather.rain.multimesh.instance_count == 160,"actual one-surface multimesh resources")
	_check(weather.rain.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 6,"actual two triangles per original streak")
	_check(weather.get_child_count() == 1 and weather.get_child(0) is MultiMeshInstance3D,"no per-drop nodes, collision or timers")
	var plateaus: int = first.sky_writes
	for frame: int in range(120):
		visual_ms += 16.6666667; _check(weather.sync(original,visual_ms),"stationary daytime plateau sync")
	var after: Dictionary = weather.inspect()
	_check(after.sky_writes == plateaus and after.total_queries == first.total_queries,"day plateau neither rebuilds sky nor queries rain")
	_check(after.mesh_id == first.mesh_id and after.material_id == first.material_id,"shared mesh/material retained")
	_check(original == copy_at and _model() == before,"presentation preserves detached inputs and all gameplay/RNG state")
	for malformed: Dictionary in [{},{"weather":"storm"},{"dayTime":NAN},{"dayTime":-0.1},{"dayTime":1.1},{"office_generator":1},{"geometry_revision":-1},{"geometry_revision":1.5}]:
		var candidate: Dictionary = original.duplicate(true)
		if malformed.is_empty(): candidate.erase("dayTime")
		else: candidate.merge(malformed,true)
		var stable: Dictionary = weather.inspect()
		_check(not weather.sync(candidate,visual_ms+500) and weather.inspect() == stable,"invalid snapshot rejected without presentation mutation")
	_check(not weather.sync(original,NAN) and not weather.sync(original,-1),"invalid render timestamp refused")
	weather.clear(); var rate_start: int = weather.inspect().sky_writes
	for frame: int in range(60):
		visual_ms = 100000+frame*(1000.0/60.0)
		weather.sync(_snapshot("clear",0.21+frame*(0.001/60.0)),visual_ms)
	_check(weather.inspect().sky_writes-rate_start <= 4,"ordinary dawn refresh limited to four per wall second")
	_sync(_snapshot("clear",0.65,false))
	var before_generator: int = weather.inspect().sky_writes
	weather.sync(_snapshot("clear",0.65,true),visual_ms)
	_check(weather.inspect().sky_writes == before_generator,"generator changes do not regenerate unchanged sky")
	_check(_model() == before,"weather/generator/time jumps keep sole model authority")
func _coverage() -> void:
	camera.position = Content.to_world(Vector2(1100,1000),1.71)
	_check(world.is_clear_position(camera.position-Vector3.UP*1.65,0.486),"open rain witness is a valid player placement")
	weather.clear()
	var pending: Dictionary = _sync(_snapshot())
	_check(pending.queries == 0 and pending.visible_instances == 0,"new revision waits for physics publication with all rain hidden")
	await physics_frame; await physics_frame
	for step: int in range(4):
		var partial: Dictionary = _sync(_snapshot())
		var certified := 0
		for column: Dictionary in partial.columns:
			if column.certified: certified += 1
		_check(certified == (step+1)*4,"uncertified coverage resolves in bounded batches")
		for index: int in range(partial.columns.size()):
			if partial.columns[index].certified: continue
			for drop: int in range(10):
				_check(_submitted_transform(index*10+drop).basis == Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),"uncertified rain is actually hidden in submitted geometry")
	var steady: Dictionary = _sync(_snapshot()); var counter: int = steady.total_queries
	_check(steady.queries == 0 and steady.columns.size() == 16 and steady.visible_instances > 0,"certified rain uses no steady queries and remains visible")
	var frozen: Dictionary = _model(); var transforms: PackedFloat32Array = weather.rain.multimesh.buffer
	state.s.mode = "paused"; var paused: Dictionary = _model()
	_sync(_snapshot()); _check(weather.rain.multimesh.buffer != transforms and _model() == paused,"menu render time animates rain without advancing model")
	state.s.mode = frozen.s.mode
	var open_column: Dictionary = {}
	for column: Dictionary in steady.columns:
		if column.cover < 0.15: open_column = column; break
	_check(not open_column.is_empty(),"actual open column exists")
	if not open_column.is_empty():
		var roof := StaticBody3D.new(); roof.name = "weather_revision_roof"; roof.collision_layer = 1; roof.collision_mask = 0
		var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(0.5,0.2,0.5); shape.shape = box; roof.add_child(shape)
		world.add_child(roof); roof.position = Vector3(open_column.point.x,8,open_column.point.y)
		adapter.invalidate_placement_cache()
		var unpublished: Dictionary = _sync(_snapshot())
		_check(unpublished.queries == 0 and unpublished.visible_instances == 0,"same-frame collider publication cannot certify stale PhysicsServer pose")
		for column: Dictionary in unpublished.columns: _check(not column.certified,"new revision immediately invalidates every old cover certificate")
		await physics_frame; await physics_frame
		for step: int in range(4): _sync(_snapshot())
		var updated: Dictionary = weather.inspect(); var observed := false
		for column: Dictionary in updated.columns:
			if column.key == open_column.key: observed = column.collider == "weather_revision_roof" and _near(column.cover,8.1,0.0001)
		_check(observed and updated.total_queries-counter == 16,"actual changed collision revision recertifies all16 columns")
		roof.free(); adapter.invalidate_placement_cache(); _sync(_snapshot()); await physics_frame; await physics_frame
	var covered := false
	for aperture: Dictionary in world.aperture_witnesses:
		var foot: Vector3 = aperture.to; foot.y = 0.06
		if not world.is_clear_position(foot,0.486): continue
		camera.position = foot+Vector3.UP*1.65
		for step: int in range(4): _sync(_snapshot())
		var view: Dictionary = weather.inspect()
		for column: Dictionary in view.columns:
			if column.cover <= camera.position.y+0.5: continue
			covered = true
			var index: int = view.columns.find(column)
			for drop: int in range(10):
				var transform: Transform3D = _submitted_transform(index*10+drop)
				if transform.basis.y.length_squared() == 0: continue
				var vertices: PackedVector3Array = weather.rain.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex: Vector3 in vertices:
					_check((weather.rain.global_transform*(transform*vertex)).y > column.cover+0.019,"actual roof clips every submitted visible streak vertex")
		if covered: break
	_check(covered,"real reachable authored service interior provides roof coverage witness")
	var end: Dictionary = _sync(_snapshot("clear"))
	_check(not end.rain_visible and end.queries == 0,"clear transition immediately hides all precipitation")
	weather.clear(); _check(weather.inspect().columns.is_empty() and not weather.rain.visible,"fresh/restore clear discards old coverage and meshes immediately")
func _run() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/weather_reference.json"))
	if not fixture is Dictionary: push_error("Weather fixture missing"); quit(1); return
	state = State.new(); world = World.new(); root.add_child(world); world.build(); adapter = Adapter.new(world,state)
	camera = Camera3D.new(); root.add_child(camera); camera.position = Content.to_world(Vector2(1100,1000),1.71)
	weather = Weather.new(); root.add_child(weather)
	_check(weather.build(world,camera),"built full-only weather presenter with all39 source fixtures")
	if not weather.inspect().built: push_error("Weather build failed"); quit(1); return
	await physics_frame; await physics_frame
	_source_oracle(fixture); _resources_and_purity(); await _coverage()
	if failures.is_empty(): print("3D WEATHER PRESENTATION GATE: PASS (",checks," checks;49 curves/48 render cases/936 fixture cases; actual roof/revision coverage)")
	else:
		for failure: String in failures: push_error(failure)
		print("3D WEATHER PRESENTATION GATE: FAIL (",checks," checks;",failures.size()," failures)")
	quit(0 if failures.is_empty() else 1)
