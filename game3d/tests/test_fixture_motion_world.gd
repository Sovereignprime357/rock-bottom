extends SceneTree
## Actual-world attachment, unchanged-physics and source-covered shadow gate.
const World = preload("res://scripts/full_neighborhood.gd")
const View = preload("res://scripts/fixture_motion_view.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _physics_records(world: World) -> Array:
	var result: Array = []
	for row: Dictionary in world.obstacle_records(): result.append([row.owner,row.bounds])
	return result
func _ground_triangles(world: World,view: View) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	for node: Node in world.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node
		if view.is_ancestor_of(mesh) or mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var bounds: AABB = mesh.global_transform*mesh.mesh.get_aabb()
		if bounds.position.y > 0.081 or bounds.end.y < -0.001: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for first: int in range(0,count-2,3):
				var points := PackedVector3Array()
				for slot: int in range(3): points.append(mesh.global_transform*vertices[indices[first+slot] if not indices.is_empty() else first+slot])
				if points[0].y < -0.001 or points[0].y > 0.081 or absf(points[0].y-points[1].y) > 0.00001 or absf(points[0].y-points[2].y) > 0.00001: continue
				result.append(points)
	return result
func _ground_top(triangles: Array[PackedVector3Array],point: Vector2) -> float:
	var result: float = -INF
	for triangle: PackedVector3Array in triangles:
		var a: Vector3 = triangle[0]; var b: Vector3 = triangle[1]; var c: Vector3 = triangle[2]
		var determinant: float = (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(determinant) < 0.00000001: continue
		var u: float = ((b.z-c.z)*(point.x-c.x)+(c.x-b.x)*(point.y-c.z))/determinant
		var v: float = ((c.z-a.z)*(point.x-c.x)+(a.x-c.x)*(point.y-c.z))/determinant
		if u >= -0.00001 and v >= -0.00001 and u+v <= 1.00001: result = maxf(result,a.y)
	return result
func _shadow_height(view: View,point: Vector2) -> float:
	var result: float = -INF
	for node: Node in view.get_children():
		if not node is MeshInstance3D or not str(node.name).begins_with("PassingShadow") or not node.visible: continue
		var bounds: AABB = node.global_transform*node.mesh.get_aabb()
		if Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z).grow(0.00001).has_point(point):
			result = maxf(result,bounds.end.y)
	return result
func _sodium_geometry(view: View,bindings: Dictionary,triangles: Array[PackedVector3Array]) -> void:
	var patch_mesh: MeshInstance3D = view.get_node("SodiumPatches")
	_check(bindings.sodium.size() == 3 and patch_mesh.mesh.get_surface_count() == 1,"three real sodium receivers share one combined surface")
	var arrays: Array = patch_mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	_check(vertices.size() == uvs.size() and vertices.size()%3 == 0 and vertices.size()/3 <= View.SODIUM_TRIANGLE_CAP,"sodium mesh has finite bounded triangles and patch-local UVs")
	var cursor: int = 0
	for index: int in range(3):
		var patch: Dictionary = bindings.sodium[index]
		var center: Vector3 = Content.to_world(patch.source_center)
		_check(patch.source_center == Vector2(1020,240)+View.SODIUM_OFFSETS[index],"actual canonical sodium center "+str(index))
		var area: float = 0.0
		for receiver: Dictionary in patch.receivers:
			var polygon: PackedVector2Array = receiver.polygon
			area += View.polygon_area(polygon)
			var underlying: Array[PackedVector3Array] = []
			for triangle: PackedVector3Array in triangles:
				if absf(triangle[0].y+0.003-float(receiver.height)) < 0.00003: underlying.append(triangle)
			for fan: int in range(1,polygon.size()-1):
				var corners: Array[Vector2] = [polygon[0],polygon[fan],polygon[fan+1]]
				for point: Vector2 in corners:
					var expected := Vector3(point.x,receiver.height,point.y)
					_check(vertices[cursor].distance_to(expected) < 0.00001 and uvs[cursor].distance_to((point-Vector2(center.x,center.z))/5.6+Vector2(0.5,0.5)) < 0.00001,"cached mesh vertex/UV matches its actual local patch receiver")
					cursor += 1
				for weights: Vector3 in [Vector3(0.2,0.3,0.5),Vector3(0.6,0.2,0.2)]:
					var sample: Vector2 = corners[0]*weights.x+corners[1]*weights.y+corners[2]*weights.z
					var actual: float = _ground_top(underlying,sample)
					_check(is_finite(actual) and absf(actual+0.003-float(receiver.height)) < 0.00003,"every sodium triangle interior has actual underlying mesh support3mm below")
		_check(absf(area-5.6*5.6) < 0.0002,"whole source140px square has exactly one receiver per point")
	_check(cursor == vertices.size(),"all combined vertices belong to exactly the three source patches")
func _covered_tail(world: World,view: View,triangles: Array[PackedVector3Array]) -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/fixture_motion_reference.json"))
	var cover: Dictionary = fixture.occlusion
	var source: Dictionary = cover.covered_rect
	var building: Dictionary = Content.load_content().buildings[int(cover.building_index)]
	_check(building.x == cover.wall.x and building.y == cover.wall.y and building.w == cover.wall.w and building.h == cover.wall.h,"source-covered tail still names the actual canonical building rectangle")
	var abandoned: Dictionary = {}
	for zone: Dictionary in Content.load_content().world.zones:
		if zone.id == "abandoned": abandoned = zone; break
	_check(not abandoned.is_empty() and Rect2(abandoned.x,abandoned.y,abandoned.w,abandoned.h).encloses(Rect2(source.x,source.y,source.w,source.h)),"covered tail belongs to actual abandoned zone, whose top.014m supplies receiver.017m")
	var snapshot := {"world_visible":true,"dayTime":0.9,"food_visible":false}
	_check(view.sync(snapshot,713,float(cover.unix_ms)),"source-covered1599ms late shadow remains in its exact original phase")
	for u: float in [0.25,0.5,0.75]:
		for v: float in [0.25,0.5,0.75]:
			var sample: Vector3 = Content.to_world(Vector2(source.x+source.w*u,source.y+source.h*v))
			var point := Vector2(sample.x,sample.z)
			var painted_y: float = _shadow_height(view,point)
			var floor_y: float = _ground_top(triangles,point)
			_check(is_finite(painted_y) and absf(painted_y-0.017) < 0.00003,"covered tail keeps its original abandoned-zone receiver; no lifted/removed segment")
			_check(is_finite(floor_y) and absf(floor_y-0.021) < 0.00003 and absf(floor_y-painted_y-0.004) < 0.00003,"actual later building_02 floor covers the original shadow with4mm depth separation")
	for node: Node in view.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("PassingShadow"):
			var material: StandardMaterial3D = node.material_override
			_check(not material.no_depth_test,"covered shadow uses ordinary depth testing, not a through-floor overlay")
	_check(world.fixture_motion_bindings().underpass.receivers.size() == view.inspect().shadow_parts,"tail classification adds no receiver or presentation mesh")
func _run() -> void:
	var baseline := World.new(); root.add_child(baseline); baseline.build()
	_check(baseline.fixture_motion_bindings().is_empty(),"default world retains legacy baked fixture contract")
	var original_geometry: Array = _physics_records(baseline)
	var original_footprints: Array = baseline.collision_footprints()
	var original_services: Dictionary = baseline.service_points.duplicate(true)
	var original_apertures: Array = baseline.aperture_witnesses.duplicate(true)
	baseline.free()
	var world := World.new(); world.dynamic_fixture_motion = true; root.add_child(world); world.build()
	var bindings: Dictionary = world.fixture_motion_bindings(); var original_bindings: Dictionary = bindings.duplicate(true)
	_check(_physics_records(world) == original_geometry and world.collision_footprints() == original_footprints,"fixture-motion opt-in changes no physical body or navigation footprint")
	_check(world.service_points == original_services and world.aperture_witnesses == original_apertures,"every service and real door aperture remains unchanged")
	_check(bindings.has("tv_window") and bindings.has("pawn_counter") and bindings.washers.size() == 4 and bindings.has("underpass") and bindings.has("sodium"),"actual world exposes source window, drum and ground attachment records")
	var pawn_source: Dictionary = Content.load_content().buildings[0]
	var pawn_front: Vector3 = Content.to_world(Vector2(pawn_source.x+pawn_source.w,pawn_source.y+pawn_source.h))
	_check(bindings.pawn_counter.source_index == 0 and bindings.pawn_counter.mount == "service_aperture" and absf(bindings.pawn_counter.transform.origin.z-pawn_front.z-0.31) < 0.00002 and absf(bindings.pawn_counter.transform.origin.y-1.25) < 0.00001,"nightly fallback is attached to actual PAWN service aperture, beyond unchanged facade")
	var pawn_opening: Dictionary = {}
	for opening: Dictionary in world.aperture_witnesses:
		if opening.owner == "structures:building_00": pawn_opening = opening; break
	_check(not pawn_opening.is_empty() and absf(bindings.pawn_counter.size.x-float(pawn_opening.width)) < 0.00001 and bindings.pawn_counter.size.y == 2.5 and absf(bindings.pawn_counter.transform.origin.x-pawn_opening.from.x) < 0.00001,"counter binding matches the independently registered live opening width/center and2.5m lintel")
	var original_parts: Dictionary = {}
	for child: Node in world.find_children("*","MeshInstance3D",true,false):
		if child.has_meta("fixture_motion_original"):
			original_parts[int(child.get_meta("fixture_motion_original"))] = child
			_check(not child.visible and child.mesh != null,"only adopted old TV interior remains hidden and resource-intact")
	_check(original_parts.keys().size() == 5 and original_parts.has(1) and original_parts.has(6) and original_parts.has(7) and original_parts.has(10) and original_parts.has(11),"exact source-built glass/mullion/curtain parts adopted, outer frame retained")
	if original_parts.has(1):
		var glass: MeshInstance3D = original_parts[1]
		var delta: Vector3 = glass.global_position-bindings.tv_window.transform.origin
		_check(absf(delta.x) < 0.0001 and absf(delta.y) < 0.0001 and absf(delta.z-0.075) < 0.0001,"TV binding comes from actual front window before batching")
	var laundry: Dictionary = Content.load_content().buildings[4]
	var north: Vector3 = Content.to_world(Vector2(laundry.x,laundry.y))
	for index: int in range(4):
		var expected: Vector3 = north+Vector3(0.8+float(index)*1.1,0.55,1.09)
		_check(bindings.washers[index].origin.distance_to(expected) < 0.0001 and bindings.washers[index].basis.z.dot(Vector3.BACK) > 0.999,"washer binding meets authored front cap "+str(index))
	var receivers: Array = bindings.underpass.receivers
	_check(receivers.size() > 1 and receivers.size() <= 16,"real stepped ground is covered within fixed shadow budget")
	var low: float = INF; var high: float = -INF
	for receiver: Dictionary in receivers:
		low = minf(low,float(receiver.height)); high = maxf(high,float(receiver.height))
	_check(high-low > 0.02,"actual source band includes different foundation/road/gutter levels")
	var view: View = View.create(); world.add_child(view)
	_check(view.build(bindings),"actual receivers completely cover the source strip corridor without overlaps")
	bindings.washers.clear(); bindings.underpass.receivers.clear()
	_check(world.fixture_motion_bindings() == original_bindings,"attachment descriptor is detached from World-owned records")
	await physics_frame; await physics_frame
	var ground_triangles: Array[PackedVector3Array] = _ground_triangles(world,view)
	_check(not ground_triangles.is_empty(),"actual rendered ground triangles available independently of receiver descriptors")
	_sodium_geometry(view,original_bindings,ground_triangles)
	var covering: Dictionary = Content.load_content().buildings[2]
	var source_cover := Rect2(covering.x,covering.y,covering.w,covering.h)
	for receiver: Dictionary in original_bindings.underpass.receivers:
		# Sample more than the center: the long final receiver crosses a building
		# boundary. Physics cannot prove non-solid road/gutter/interior-floor heights.
		for u: float in [0.05,0.5,0.95]:
			for v: float in [0.05,0.5,0.95]:
				var point := Vector3(receiver.rect.position.x+receiver.rect.size.x*u,float(receiver.height),receiver.rect.position.y+receiver.rect.size.y*v)
				var surface_y: float = _ground_top(ground_triangles,Vector2(point.x,point.z))
				if source_cover.has_point(Content.to_source(point)):
					_check(point.is_finite() and is_finite(surface_y) and absf(surface_y-point.y-0.004) < 0.00003,"source-covered abandoned-zone receiver remains4mm below later opaque building floor")
				else:
					_check(point.is_finite() and is_finite(surface_y) and absf(point.y-surface_y-0.003) < 0.00003,"uncovered receiver sits3mm above actual final rendered ground triangles")
	_covered_tail(world,view,ground_triangles)
	var snapshot := {"world_visible":true,"dayTime":0.9,"food_visible":false}
	for unix: float in [0.0,400.0,800.0,1200.0,1599.0,1600.0,8000.0]:
		_check(view.sync(snapshot,unix*0.71,unix),"actual world fixture pose accepts independently supplied clocks")
		_check(view.inspect().steam_visible,"nightly source window steam persists without a Pete-food anchor")
		var expected: Vector3 = original_bindings.pawn_counter.transform*Vector3(sin(unix*0.71/400.0)*0.08,original_bindings.pawn_counter.size.y*0.5+0.065+fposmod(unix*0.71/400.0,4.0)*0.06,0)
		_check(view.get_node("PocketSteam").global_position.distance_to(expected) < 0.00002,"actual world fallback obeys source phase at recorded PAWN aperture")
	_check(_physics_records(world) == original_geometry and world.collision_footprints() == original_footprints,"all fixture phases leave physics/navigation unchanged")
	view.free(); world.free(); await process_frame
	if failures.is_empty(): print("3D FIXTURE MOTION WORLD GATE: PASS (%d checks)"%checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D FIXTURE MOTION WORLD GATE: FAIL (%d failures/%d checks)"%[failures.size(),checks]); quit(1)
