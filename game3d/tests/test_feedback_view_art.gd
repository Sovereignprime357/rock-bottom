extends SceneTree
## Detached geometry contract only. Actual source-trigger/native/Web evidence is separate.
const Feedback = preload("../scripts/world_feedback.gd")
const View = preload("../scripts/world_feedback_view.gd")
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []
var failure_count: int = 0
var vertex_checks: int = 0
var renderer_readback: bool = false
var renderer_vertex_checks: int = 0
var color_diagnostics: Array[Dictionary] = []
var color_readbacks: int = 0
var max_source_color_delta: float = 0.0
var max_stored_color_delta: float = 0.0
var stored_color_mismatches: int = 0

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failure_count += 1
		if failures.size() < 24: failures.append(label)

func _receipt(recipe: String) -> Dictionary:
	var result := {"epoch":1,"recipe":recipe,"source_point":Vector2(114,216),"world_anchor":Vector3(1,1.2,-2),"birth_right":Vector3.RIGHT,"width":38.0,"phase":2,"sings":false}
	if recipe == "walking_dust": result.samples = [0.1,0.2,0.3,0.4,0.5]; result.intent_x = 0.5
	if recipe == "ambient_mote": result.samples = [0.1,0.2,0.3,0.4,0.5,0.6,0.7]; result.rain = false
	return result

func _source_rows() -> Array[Dictionary]:
	var pool := Feedback.new(923); pool.reset_epoch(1)
	for recipe: String in Feedback.supported_recipes(): _check(pool.accept(_receipt(recipe)),"actual source recipe "+recipe)
	var phase_three: Dictionary = _receipt("tony_coat"); phase_three.phase = 3
	_check(pool.accept(phase_three),"actual source phase3 coat color")
	for recipe: String in ["melee_sparks","melee_flash"]:
		var singing: Dictionary = _receipt(recipe); singing.sings = true
		_check(pool.accept(singing),"actual source singing impact color "+recipe)
	var rows: Array[Dictionary] = []; rows.assign(pool.snapshot().particles)
	return rows

func _contains(box: AABB,point: Vector3) -> bool:
	var end: Vector3 = box.end
	return point.is_finite() and point.x >= box.position.x and point.y >= box.position.y and point.z >= box.position.z and point.x <= end.x and point.y <= end.y and point.z <= end.z

static func _gles3_channel(value: float) -> float:
	# Pinned4.5.1 Math::make_half_float/half_to_float, restricted to unit colors.
	# Encode first because source Color channels are single precision.
	if not is_finite(value) or value < 0 or value > 1: return NAN
	var bytes := PackedByteArray(); bytes.resize(4); bytes.encode_float(0,value)
	var bits: int = bytes.decode_u32(0)
	if (bits&0x7f800000) <= 0x38000000: return 0.0
	bytes.encode_u32(0,bits&0xffffe000)
	return bytes.decode_float(0)

static func _gles3_color(value: Color) -> Color:
	return Color(_gles3_channel(value.r),_gles3_channel(value.g),_gles3_channel(value.b),_gles3_channel(value.a))

static func _channels(value: Color) -> Array[float]:
	return [value.r,value.g,value.b,value.a]

static func _channel_delta(a: Color,b: Color) -> float:
	return maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))

func _observe_color(key: String,index: int,row: Dictionary,actual: Color,expected: Color) -> void:
	var predicted: Color = _gles3_color(expected)
	var source_delta: float = _channel_delta(actual,expected)
	var stored_delta: float = _channel_delta(actual,predicted)
	color_readbacks += 1
	max_source_color_delta = maxf(max_source_color_delta,source_delta)
	max_stored_color_delta = maxf(max_stored_color_delta,stored_delta)
	if actual != predicted: stored_color_mismatches += 1
	if not actual.is_equal_approx(expected) and color_diagnostics.size() < 8:
		var diagnostic := {"bank":key,"index":index,"recipe":row.recipe,"serial":row.serial,"actual":_channels(actual),"source_expected":_channels(expected),"gles3_expected":_channels(predicted),"max_source_delta":source_delta,"max_stored_delta":stored_delta}
		color_diagnostics.append(diagnostic)
		print("FEEDBACK COLOR READBACK: ",JSON.stringify(diagnostic))

func _mesh_contract() -> void:
	for shape: String in ["flash","fragment"]:
		var mesh: ArrayMesh = View._geometry(shape)
		_check(mesh.get_surface_count() == 1 and mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES,"one triangle surface "+shape)
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		_check(vertices.size() == 12 and normals.size() == 12 and colors.size() == 12,"exact four triangles and explicit attributes "+shape)
		var radius := 0.0
		for index: int in range(vertices.size()):
			var vertex: Vector3 = vertices[index]; radius = maxf(radius,vertex.length())
			_check(vertex.is_finite() and normals[index].is_finite() and absf(normals[index].length_squared()-1) < 0.00001,"finite normalized mesh "+shape)
			_check(colors[index].r == 1 and colors[index].g == 1 and colors[index].b == 1,"white vertex color preserves source tint "+shape)
			if shape == "flash":
				_check(colors[index].a == (1.0 if index%3 == 0 else 0.0),"flash opaque center and zero-alpha edge")
				_check((vertex == Vector3.ZERO) == (index%3 == 0),"fan center remains first despite winding correction")
				_check(vertex.z == 0 and absf(vertex.x)+absf(vertex.y) <= 0.5,"diamond stays within original unit envelope")
			else: _check(colors[index].a == 1,"splinter vertex never changes source opacity")
		_check(radius == View._radii[shape] and radius > 0,"culling uses measured mesh radius "+shape)
		_check(mesh == View._geometry(shape),"shared cached mesh identity "+shape)
	var fragment: PackedVector3Array = View._geometry("fragment").surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var unique: Array[Vector3] = []
	for vertex: Vector3 in fragment:
		if vertex not in unique: unique.append(vertex)
	_check(unique.size() == 4,"one four-vertex tetrahedron")
	var edges: Array[float] = []
	for a: int in range(unique.size()):
		for b: int in range(a+1,unique.size()): edges.append(unique[a].distance_to(unique[b]))
	edges.sort()
	_check(edges[-1] > edges[0]*2.0 and unique[0].z != unique[-1].z,"flattened unequal edges with nonzero thickness")
	for pair: Array in [[0.0,0.0],[1.0,1.0],[0.5,0.5],[0.1,0.0999755859375],[0.85,0.849609375],[0.000030517578125,0.0],[0.00006103515625,0.00006103515625]]:
		_check(_gles3_channel(pair[0]) == pair[1],"pinned half-storage prediction has an exact known value")
	groups += 1

func _transformed_vertices() -> void:
	var rows: Array[Dictionary] = _source_rows(); var recipes: Dictionary = {}
	for row: Dictionary in rows:
		if not recipes.has(row.recipe): recipes[row.recipe] = row
	_check(recipes.size() == 20,"all18 burst and2 dust recipe identities represented")
	var anchors: Array[Vector3] = [Vector3.ZERO,Vector3(0.1,0.08,-0.1),Vector3(1e6,-1e6,1e6),Vector3(-1e6,1e6,-1e6)]
	var sizes: Array[float] = [0.000001,2,3,5,14]
	for recipe: String in recipes:
		var seen: Dictionary = {}
		for serial: int in range(1,5):
			seen[View._roll_index(recipe,serial)] = true
			for angle: float in [0.0,0.7853981633974483,1.229,3.141592653589793]:
				for anchor: Vector3 in anchors:
					for size: float in sizes:
						var row: Dictionary = recipes[recipe].duplicate(true)
						row.serial = serial; row.birth_right = Vector3(cos(angle),0,sin(angle)).normalized(); row.world_anchor = anchor; row.size = size
						row.offset = Vector2(0.25,-0.75)
						var before: Dictionary = row.duplicate(true)
						var pose: Transform3D = View._instance_pose(row)
						var box: AABB = View._instance_bounds(row,pose)
						var arrays: Array = View._geometry(row.shape).surface_get_arrays(0)
						for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
							_check(_contains(box,pose*vertex),"transformed actual vertex inside declared bound "+recipe); vertex_checks += 1
						_check(row == before and pose == View._instance_pose(row),"pose is deterministic and detached")
		_check(seen.size() == 4,"all four birth-static roll selections "+recipe)
	# Old guessed cube width could undersize rotated unequal fragments. Actual radius remains sufficient.
	var sliver: Dictionary = recipes.essential.duplicate(true); sliver.size = 14.0; sliver.glow = true
	var poses: Array[Transform3D] = []
	for serial: int in range(1,5): sliver.serial = serial; poses.append(View._instance_pose(sliver))
	_check(poses[0].basis != poses[1].basis and poses[1].basis != poses[2].basis and poses[2].basis != poses[3].basis,"fragment roll visibly changes basis without changing origin")
	for pose: Transform3D in poses: _check(pose.origin == poses[0].origin,"birth roll cannot move center")
	groups += 1

func _readback() -> bool:
	var instances := MultiMesh.new(); instances.transform_format = MultiMesh.TRANSFORM_3D; instances.use_colors = true; instances.instance_count = 1
	var pose := Transform3D(Basis.IDENTITY,Vector3(3,4,5)); var color := Color(0.25,0.5,0.75,1)
	instances.set_instance_transform(0,pose); instances.set_instance_color(0,color)
	var supported: bool = instances.get_instance_transform(0) == pose and instances.get_instance_color(0) == color
	if DisplayServer.get_name() != "headless" or "--require-feedback-renderer" in OS.get_cmdline_user_args(): _check(supported,"real rendering backend must read submitted instance geometry")
	if supported:
		var version: Dictionary = Engine.get_version_info()
		_check(RenderingServer.get_current_rendering_method() == "gl_compatibility" and version.get("major") == 4 and version.get("minor") == 5 and version.get("patch") == 1,"exact color-storage expectation requires pinned4.5.1 Compatibility")
	return supported

func _banks_and_source() -> void:
	renderer_readback = _readback()
	var view := View.new(); var other := View.new(); root.add_child(view); root.add_child(other)
	_check(view.build() and view.build() and other.build(),"idempotent bounded builds")
	var rows: Array[Dictionary] = _source_rows()
	# Detached geometry-only variants exercise all four banks and fractional-life alpha.
	var flash: Dictionary = rows[12].duplicate(true)
	for row: Dictionary in rows:
		if row.shape == "flash": flash = row.duplicate(true); break
	flash.serial = 10001; flash.glow = false; flash.life = 175.0; rows.append(flash)
	var fractional: Dictionary = flash.duplicate(true); fractional.serial = 10002; fractional.glow = true; rows.append(fractional)
	var snapshot := {"epoch":1,"revision":19,"particles":rows}
	var before: Dictionary = snapshot.duplicate(true)
	seed(7149); var expected_random: float = randf(); seed(7149)
	_check(view.sync(snapshot) and view.sync(snapshot),"repeated source snapshot sync")
	_check(randf() == expected_random and snapshot == before,"view never consumes RNG or mutates source snapshot")
	var stats: Dictionary = view.inspect()
	_check(stats.banks == 4 and stats.allocated_slots == 880 and stats.meshes == 2 and stats.materials == 2,"unchanged fixed resource/instance budget")
	_check(stats.live == rows.size() and stats.triangles == rows.size()*4 and stats.triangles <= 880,"exact four triangles per live particle")
	for key: String in View.BANKS:
		var bank: MultiMeshInstance3D = view._banks[key]; var second: MultiMeshInstance3D = other._banks[key]
		_check(stats.counts[key] > 0,"each mix/add shape bank is exercised "+key)
		_check(bank.multimesh.mesh == second.multimesh.mesh and bank.material_override == second.material_override,"shared mesh/material across views "+key)
		var material: StandardMaterial3D = bank.material_override
		_check(material.vertex_color_use_as_albedo and not material.no_depth_test and material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED and material.cull_mode == BaseMaterial3D.CULL_DISABLED,"same depth-tested vertex-color material "+key)
		_check(material.blend_mode == (BaseMaterial3D.BLEND_MODE_ADD if key.ends_with("add") else BaseMaterial3D.BLEND_MODE_MIX) and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,"unchanged blend policy "+key)
		_check(bank.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"no particle shadow "+key)
		var index := 0
		for row: Dictionary in rows:
			if key != str(row.shape)+("_add" if row.glow else "_mix"): continue
			if renderer_readback:
				var pose: Transform3D = bank.multimesh.get_instance_transform(index)
				_check(pose.is_equal_approx(View._instance_pose(row)),"real instance uses tested pose")
				var color: Color = row.color
				if row.glow: color.a *= clampf(float(row.life)/700.0,0,1)
				var actual_color: Color = bank.multimesh.get_instance_color(index)
				_observe_color(key,index,row,actual_color,color)
				_check(actual_color == _gles3_color(color),"real instance exactly preserves pinned stored source/life color")
				for vertex: Vector3 in bank.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					_check(_contains(bank.multimesh.custom_aabb,pose*vertex),"real submitted vertex inside actual bank AABB"); renderer_vertex_checks += 1
			index += 1
	_check(not view.is_processing() and not view.is_physics_processing() and view.get_child_count() == 4,"passive four-bank view without extra node authority")
	view.free(); other.free(); groups += 1

func _capacity_lifecycle() -> void:
	var pool := Feedback.new(1); pool.reset_epoch(1)
	for index: int in range(220): _check(pool.accept(_receipt("melee_flash")),"full flash fixture source acceptance")
	var view := View.new(); root.add_child(view); view.build()
	var snapshot: Dictionary = pool.snapshot()
	_check(view.sync(snapshot) and view.inspect().live == 220 and view.inspect().triangles == 880 and view.inspect().counts.flash_add == 220,"all220 flash worst case remains880 triangles")
	var invalid: Dictionary = snapshot.duplicate(true); invalid.particles[219].size = INF
	_check(not view.sync(invalid) and view.inspect().live == 0,"last invalid row fails closed without partial bank update")
	_check(view.sync(snapshot),"valid snapshot restores after invalid input")
	var duplicate: Dictionary = snapshot.duplicate(true); duplicate.particles[219].serial = duplicate.particles[0].serial
	_check(not view.sync(duplicate) and view.inspect().live == 0,"duplicate serial rejected")
	_check(view.sync(snapshot),"source can be rendered again unchanged")
	view.clear(); _check(view.inspect().live == 0 and view.inspect().epoch == 0,"clear hides all banks and epoch")
	for key: String in View.BANKS: _check(not view._banks[key].visible and view._banks[key].multimesh.visible_instance_count == 0,"cleared bank invisible "+key)
	_check(view.inspect().meshes == 2 and view.inspect().materials == 2,"clear/reset retains bounded resources")
	view.free(); groups += 1

func _run() -> void:
	_mesh_contract(); _transformed_vertices(); _banks_and_source(); _capacity_lifecycle()
	_check(groups == 4,"all four groups completed without silent runtime abort")
	_check(vertex_checks == 20*4*4*4*5*12,"all deterministic pose/actual-vertex combinations completed")
	print("FEEDBACK VIEW ART DETAIL: ",JSON.stringify({"groups":groups,"checks":checks,"failures":failure_count,"actual_vertex_checks":vertex_checks,"renderer_readback":renderer_readback,"renderer_vertex_checks":renderer_vertex_checks,"color_readbacks":color_readbacks,"color_diagnostic_rows":color_diagnostics.size(),"max_source_color_delta":max_source_color_delta,"max_stored_color_delta":max_stored_color_delta,"stored_color_mismatches":stored_color_mismatches,"renderer":RenderingServer.get_current_rendering_method(),"visual_acceptance":false}))
	for failure: String in failures: push_error(failure)
	print("3D FEEDBACK VIEW ART GATE: ","PASS" if failure_count == 0 else "FAIL")
	quit(0 if failure_count == 0 else 1)
