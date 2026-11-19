extends SceneTree
## Source-phase, bounded-geometry and presentation-purity gate.
const View = preload("res://scripts/fixture_motion_view.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _close(a: float,b: float,epsilon: float = 0.000000001) -> bool: return absf(a-b) <= epsilon
func _bindings() -> Dictionary:
	var washers: Array[Transform3D] = []
	for index: int in range(4): washers.append(Transform3D(Basis.IDENTITY,Vector3(float(index)*1.1,0.55,2.0)))
	var source := Rect2(1020,240,380,220); var corridor: Rect2 = View._corridor(source)
	var left := Rect2(corridor.position,Vector2(corridor.size.x*0.5,corridor.size.y))
	var right := Rect2(Vector2(left.end.x,corridor.position.y),Vector2(corridor.end.x-left.end.x,corridor.size.y))
	var sodium: Array[Dictionary] = []
	for offset: Vector2 in View.SODIUM_OFFSETS:
		var center: Vector2 = source.position+offset; var at: Vector3 = Content.to_world(center)
		sodium.append({"source_center":center,"receivers":[{"polygon":View.rect_polygon(Rect2(at.x-2.8,at.z-2.8,5.6,5.6)),"height":0.017}]})
	return {"tv_window":{"transform":Transform3D(Basis.IDENTITY,Vector3(2,1.65,0.025)),"size":Vector2(1.5,1.35)},"pawn_counter":{"transform":Transform3D(Basis.IDENTITY,Vector3(-3,1.65,0.31)),"size":Vector2(1.5,1.35)},"washers":washers,"sodium":sodium,
		"underpass":{"source_rect":source,"receivers":[{"rect":left,"height":0.003},{"rect":right,"height":0.049}]}}
func _snapshot(day: float = 0.9) -> Dictionary:
	return {"world_visible":true,"dayTime":day,"food_visible":true,"food_transform":Transform3D(Basis(Vector3.UP,0.4),Vector3(1,1.2,3)),"camera_basis":Basis(Vector3.UP,0.2)}
func _resources(view: Node) -> Array:
	var result: Array = []
	for child: Node in view.find_children("*","MeshInstance3D",true,false): result.append([child.mesh,hash(child.mesh.surface_get_arrays(0))])
	return result
func _material_bytes() -> Dictionary:
	var result: Dictionary = {}
	for key: String in View._materials:
		var material: StandardMaterial3D = View._materials[key]
		result[key] = [material.get_instance_id(),material.albedo_color,material.emission,material.emission_energy_multiplier,material.shading_mode,material.transparency]
	return result
func _hidden(view: Node) -> bool:
	for child: Node in view.find_children("*","GeometryInstance3D",true,false):
		if child.is_visible_in_tree(): return false
	return true
func _oracle(fixture: Dictionary) -> void:
	_check(fixture.counts.samples == 53 and fixture.counts.title == 1 and fixture.counts.sodium_patches == 3,"bounded unchanged-source phase census")
	var cover: Dictionary = fixture.occlusion
	_check(fixture.counts.source_covered_tail == 1 and cover.building_index == 2 and cover.unix_ms == 1599,"one explicit canonical building-covered tail characterization")
	_check(cover.frame_order.underpass_before_buildings and cover.frame_order.underpass_line < cover.frame_order.buildings_line and cover.strip_call_index < cover.wall_call_index,"actual source frame/draw order covers the earlier strip with building_02")
	_check(cover.wall.alpha == 1 and cover.wall.blend == "source-over" and cover.covered_rect.w > 35 and cover.covered_rect.w < 36 and cover.covered_rect.h == 8,"opaque source wall covers the late120x8px strip tail")
	_check(cover.rng_draws == 0 and cover.save_writes == 0 and cover.timers_added == 0,"covered-tail source capture remains pure rendering")
	_check(fixture.counts.source_screens == 5 and fixture.counts.source_washers == 6 and fixture.counts.adapted_screens == 1 and fixture.counts.adapted_washers == 4,"fixture-count adaptation is explicit")
	_check(fixture.title.method == "actual unchanged drawAll" and fixture.title.expected.background_draws == 1 and fixture.title.expected.fixture_draws == 0 and not fixture.title.expected.world_visible,"actual source title draw suppresses all fixtures")
	for row: Dictionary in fixture.cases:
		var actual: Dictionary = View.source_sample(row.input.visual_ms,row.input.unix_ms,row.input.dayTime)
		var expected: Dictionary = row.expected
		_check(not actual.is_empty(),row.id+" finite supplied clocks accepted")
		for key: String in ["tv_on","steam_visible","shadow_visible"]: _check(actual[key] == expected[key],row.id+" exact source "+key)
		_check(_close(actual.pane_alpha,expected.pane_alpha),row.id+" source day/night pane alpha")
		_check(_close(actual.sodium_alpha,expected.sodium_alpha),row.id+" actual Canvas sodium alpha from visual clock")
		for index: int in range(3):
			var patch: Dictionary = row.source_draw.sodium[index]
			var center: Vector2 = Vector2(1020,240)+View.SODIUM_OFFSETS[index]
			_check(patch.color.args == [center.x,center.y,4.0,center.x,center.y,70.0] and patch.blend == "lighter" and patch.w == 140 and patch.h == 140,"canonical source additive geometry "+row.id+":"+str(index))
		var inner: Color = View.sodium_gradient(4.0,actual.sodium_alpha)
		var middle: Color = View.sodium_gradient(37.0,actual.sodium_alpha)
		var outer: Color = View.sodium_gradient(70.0,actual.sodium_alpha)
		_check(inner.is_equal_approx(Color(232.0/255.0,140.0/255.0,40.0/255.0,actual.sodium_alpha)) and middle.is_equal_approx(Color(220.0/255.0,120.0/255.0,30.0/255.0,0.18)) and is_zero_approx(outer.a),"source encoded gradient stops use exact4/37/70px "+row.id)
		for index: int in range(4):
			_check(_close(actual.washers[index].x,expected.washer_offsets[index].x) and _close(actual.washers[index].y,expected.washer_offsets[index].y),row.id+" actual Canvas drum orbit "+str(index))
		for key: String in ["steam_x","steam_rise","shadow_phase"]:
			if expected.has(key): _check(_close(actual[key],expected[key]),row.id+" actual visible source "+key)
		_check(row.rng_draws == 0 and row.save_writes == 0 and row.timers_added == 0,row.id+" original fixture draw owns no model work")
func _geometry(view: View,bindings: Dictionary,snapshot: Dictionary,visual: float,unix: float) -> void:
	var saved: Dictionary = snapshot.duplicate(true)
	_check(view.sync(snapshot,visual,unix) and snapshot == saved,"projection preserves caller snapshot")
	for index: int in range(4):
		var holder: Node3D = view.get_node("Washer"+str(index))
		var patch: MeshInstance3D = holder.get_node("TurningPatch")
		var bounds: AABB = patch.mesh.get_aabb(); var clear: bool = true
		for corner: int in range(8):
			var point: Vector3 = patch.transform*bounds.get_endpoint(corner)
			clear = clear and point.is_finite() and Vector2(point.x,point.y).length() <= 0.28001 and point.z >= 0.0039 and point.z <= 0.0041
		_check(clear,"actual rotating patch stays on existing physical drum")
		_check(holder.global_transform.is_equal_approx(bindings.washers[index]),"washer remains at actual supplied face")
	var television: Node3D = view.get_node("CornerTelevision")
	for child: MeshInstance3D in television.get_children():
		var contained: bool = true
		for corner: int in range(8):
			var point: Vector3 = child.transform*child.mesh.get_aabb().get_endpoint(corner)
			contained = contained and absf(point.x) < bindings.tv_window.size.x*0.5 and absf(point.y) < bindings.tv_window.size.y*0.5 and point.z >= -0.02001 and point.z <= 0.20001
		_check(contained,"original TV fixture fits the retained window frame")
	var steam: MeshInstance3D = view.get_node("PocketSteam")
	if steam.visible:
		var bite: Vector3 = snapshot.food_transform*Vector3(0.01,0.135,0.015)
		var offset: Vector3 = steam.global_position-bite
		_check(absf(offset.dot(snapshot.camera_basis.x)) <= 0.08001 and offset.y >= 0.06499 and offset.y < 0.30501,"single steam disc remains bounded above actual food")
		_check(steam.global_transform.basis.z.normalized().dot(snapshot.camera_basis.z.normalized()) > 0.9999 and is_equal_approx(steam.global_transform.basis.x.length(),0.06),"steam faces camera without distorting its original radius")
	var total_area: float = 0.0
	for index: int in range(bindings.underpass.receivers.size()):
		var shadow: MeshInstance3D = view.get_node("PassingShadow"+str(index))
		if not shadow.visible: continue
		var receiver: Dictionary = bindings.underpass.receivers[index]
		for corner: int in range(8):
			var point: Vector3 = shadow.global_transform*shadow.mesh.get_aabb().get_endpoint(corner)
			_check(absf(point.y-float(receiver.height)) < 0.00002 and receiver.rect.grow(0.00002).has_point(Vector2(point.x,point.z)),"shadow piece lies on its actual stepped receiver")
		var basis: Basis = shadow.global_transform.basis
		total_area += basis.x.length()*basis.y.length()
	_check(_close(total_area,4.8*0.32,0.0001) if view.inspect().sample.shadow_visible else total_area == 0,"receiver pieces preserve the whole one-strip source area")
	var sodium: MeshInstance3D = view.get_node("SodiumPatches")
	_check(sodium.visible and sodium.mesh.get_surface_count() == 1 and sodium.global_transform.is_equal_approx(Transform3D.IDENTITY),"one combined sodium surface stays at actual world receivers under parent transforms")
	_check(_close(float(sodium.material_override.get_shader_parameter("inner_alpha")),view.inspect().sample.sodium_alpha,0.0000001),"private shader alpha follows the actual source sample")
func _partition_counterexamples() -> void:
	var square := Rect2(-2,-2,4,4)
	var diamond := PackedVector2Array([Vector2(0,-1),Vector2(1,0),Vector2(0,1),Vector2(-1,0)])
	var strip: PackedVector2Array = View.rect_polygon(Rect2(-0.1,-2,0.2,4))
	var surfaces: Array[Dictionary] = [{"polygon":View.rect_polygon(square),"height":0.003},{"polygon":diamond,"height":0.029},{"polygon":strip,"height":0.049}]
	var original: Array[Dictionary] = surfaces.duplicate(true)
	var pieces: Array[Dictionary] = View.partition_receivers(square,surfaces)
	_check(not pieces.is_empty() and surfaces == original,"bounded partition preserves caller originals")
	var area: float = 0.0
	for piece: Dictionary in pieces: area += View.polygon_area(piece.polygon)
	_check(absf(area-16.0) < 0.00003,"rotated high face and narrow gutter preserve complete lower coverage")
	for x: float in [-1.73,-0.81,-0.37,0.03,0.41,0.87,1.61]:
		for y: float in [-1.79,-0.83,-0.31,0.07,0.49,0.89,1.63]:
			var found: Array[float] = []
			for piece: Dictionary in pieces:
				if Geometry2D.is_point_in_polygon(Vector2(x,y),piece.polygon): found.append(piece.height)
			var expected: float = 0.049 if absf(x) < 0.1 else 0.029 if absf(x)+absf(y) < 1.0 else 0.003
			_check(found.size() == 1 and absf(found[0]-expected) < 0.000001,"actual rotated polygon, not its bounding box, determines receiver height")
	var excessive: Array[Dictionary] = []
	for index: int in range(65): excessive.append(surfaces[0])
	_check(View.partition_receivers(square,excessive).is_empty(),"receiver surface work cap fails closed")
	_check(View.partition_receivers(square,[surfaces[1]]).is_empty(),"incomplete receiver coverage fails closed")
	for kind: String in ["missing","overlap","outside","concave","height","pieces","center"]:
		var bad: Dictionary = _bindings()
		match kind:
			"missing": bad.sodium[0].receivers.clear()
			"overlap": bad.sodium[0].receivers.append(bad.sodium[0].receivers[0].duplicate(true))
			"outside": bad.sodium[0].receivers[0].polygon[0] -= Vector2(1,1)
			"concave": bad.sodium[0].receivers[0].polygon[1] = (bad.sodium[0].receivers[0].polygon[0]+bad.sodium[0].receivers[0].polygon[2])*0.5-Vector2(1,0)
			"height": bad.sodium[0].receivers[0].height = INF
			"pieces":
				for index: int in range(256): bad.sodium[0].receivers.append(bad.sodium[0].receivers[0])
			"center": bad.sodium[1].source_center += Vector2(1,0)
		var candidate: View = View.create()
		_check(not candidate.build(bad) and candidate.get_child_count() == 0,"malformed sodium "+kind+" fails before allocating any presentation")
		candidate.free()
func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/fixture_motion_reference.json"))
	_oracle(fixture)
	_partition_counterexamples()
	seed(654321); var expected_rng: int = randi(); seed(654321)
	var first: View = View.create(); var second: View = View.create(); root.add_child(first); root.add_child(second)
	var bindings: Dictionary = _bindings(); var saved_bindings: Dictionary = bindings.duplicate(true)
	_check(first.build(bindings) and second.build(bindings) and first.build(bindings),"two independent fixed presentations build idempotently")
	_check(_hidden(first) and _hidden(second),"new fixture presentation starts hidden")
	var resources: Array = _resources(first); var material_state: Dictionary = _material_bytes()
	var snapshot: Dictionary = _snapshot(); var other: Dictionary = _snapshot(0.5)
	second.sync(other,0,3000); var second_pose: Transform3D = second.get_node("Washer0/TurningPatch").transform
	for moment: float in [0.0,33.0,399.0,1599.0,1600.0,8700.0,1763424001600.0]: _geometry(first,bindings,snapshot,moment,moment)
	_check(second.get_node("Washer0/TurningPatch").transform == second_pose and not second.inspect().steam_visible,"another instance retains independent poses and gates")
	var first_material: ShaderMaterial = first.get_node("SodiumPatches").material_override
	var second_material: ShaderMaterial = second.get_node("SodiumPatches").material_override
	_check(first_material != second_material and first_material.shader == second_material.shader and _close(float(second_material.get_shader_parameter("inner_alpha")),0.36,0.0000001),"instances share immutable program, never a mutable phase uniform")
	var shader_code: String = first_material.shader.code
	_check(shader_code.contains("blend_add") and shader_code.contains("depth_draw_never") and shader_code.contains("source_color") and not shader_code.contains("depth_test_disabled") and not shader_code.contains("TIME"),"additive shader keeps ordinary occlusion and supplied clock")
	first.sync(snapshot,620,730); var prior: Dictionary = first.inspect()
	for iteration: int in range(60): first.sync(snapshot,620,730)
	var unchanged: Dictionary = first.inspect()
	_check(prior == unchanged,"identical supplied time/data cause no transform/material/visibility rewrites")
	first.position = Vector3(2,0.3,-1); first.rotation.y = 0.5
	_geometry(first,bindings,snapshot,620,730)
	first.sync({"world_visible":false},NAN,NAN); _check(_hidden(first),"title clears without requiring clock/food dependencies")
	var missing_food: Dictionary = _snapshot(); missing_food.food_visible = false; missing_food.erase("food_transform"); missing_food.erase("camera_basis")
	_check(first.sync(missing_food,620,730) and first.inspect().steam_visible and first.inspect().tv_visible,"hidden nighttime Pete leaves the source nightly facade steam visible")
	var steam: MeshInstance3D = first.get_node("PocketSteam")
	var expected_fallback: Vector3 = bindings.pawn_counter.transform*Vector3(sin(620.0/400.0)*0.08,bindings.pawn_counter.size.y*0.5+0.065+fposmod(620.0/400.0,4.0)*0.06,0)
	_check(steam.global_position.distance_to(expected_fallback) < 0.00001 and steam.global_basis.z.normalized().dot(bindings.pawn_counter.transform.basis.z) > 0.9999,"missing food uses actual recorded counter phase and orientation under moved parent")
	missing_food.dayTime = 0.5
	_check(first.sync(missing_food,620,730) and not first.inspect().steam_visible and first.inspect().sodium_visible,"source day hides window steam while sodium stays on")
	for bad: Dictionary in [{},{"world_visible":true},{"world_visible":true,"dayTime":NAN,"food_visible":true}]:
		first.sync(snapshot,620,730); _check(not first.sync(bad,620,730) and _hidden(first),"malformed active snapshot fails closed")
	for bad_clock: float in [-1.0,NAN,INF]:
		_check(not first.sync(snapshot,bad_clock,730) and not first.sync(snapshot,620,bad_clock),"invalid supplied clocks cannot leave stale motion")
	var overflow_basis := Basis.from_scale(Vector3(1.0e30,1.0e30,1.0e30))
	_check(overflow_basis.is_finite() and not is_finite(overflow_basis.determinant()),"large finite basis is an actual determinant-overflow witness")
	var malformed_food: Dictionary = _snapshot(); malformed_food.food_transform = Transform3D(overflow_basis,Vector3.ZERO)
	_check(not first.sync(malformed_food,620,730) and _hidden(first),"finite components with infinite food determinant fail closed before projection")
	var malformed_camera: Dictionary = _snapshot(); malformed_camera.camera_basis = overflow_basis
	_check(not first.sync(malformed_camera,620,730) and _hidden(first),"finite components with infinite camera determinant fail closed")
	var unchanged_pose: Transform3D = first.get_node("Washer0").transform
	_check(not first._pose(first.get_node("Washer0"),Transform3D(overflow_basis,Vector3.ZERO)) and first.get_node("Washer0").transform == unchanged_pose,"invalid final projected basis never reaches a renderer setter")
	var absent: Dictionary = _bindings(); absent.underpass.receivers.pop_back()
	var invalid_view: View = View.create(); _check(not invalid_view.build(absent),"missing ground coverage cannot silently drop shadow pieces"); invalid_view.free()
	_check(_resources(first) == resources and _material_bytes() == material_state and bindings == saved_bindings,"motion preserves all cached mesh/material/source binding bytes")
	_check(randi() == expected_rng,"build and all source projections consume no gameplay RNG")
	for child: Node in first.find_children("*","",true,false):
		_check(not child is CollisionObject3D and not child is CollisionShape3D and not child is Light3D and not child is Timer and not child is GPUParticles3D and not child is CPUParticles3D,"fixture presentation adds no simulation owner")
		_check(not child.is_processing() and not child.is_physics_processing() and not child.is_processing_input(),"fixture pieces own no autonomous frame/input callback")
		if child is GeometryInstance3D: _check(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"fixture inserts cast no new shadow")
	first.free(); second.free(); await process_frame
	if failures.is_empty(): print("3D FIXTURE MOTION GATE: PASS (%d checks)"%checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D FIXTURE MOTION GATE: FAIL (%d failures/%d checks)"%[failures.size(),checks]); quit(1)
