extends SceneTree
## Real generated meshes and physics; original class differs only in class_name.
const World = preload("res://scripts/full_neighborhood.gd")
const Original = preload("res://tests/reference_full_neighborhood.gd")
const EYE := Vector3(22.76468,1.69,3.967642)
const REST_PAPER := Vector3(22.99808,1.248626,3.285707)
const TONY_TARGET := Vector3(23.36,1.2,1.84)
var checks := 0
var groups := 0
var failures: Array[String] = []

class CurrentWorld:
	extends World
	var piers: Array[Dictionary] = []
	var current_openings: Array[Vector2] = []
	func _facade_bays(rect: Rect2,height: float,index: int,finish: String,color: String,openings: Array[Vector2]) -> void:
		current_openings = openings.duplicate()
		super._facade_bays(rect,height,index,finish,color,openings)
	func _box(label: String,size: Vector3,at: Vector3,color: String,solid: bool = false,rotation_at: Vector3 = Vector3.ZERO,emission: float = 0.0) -> MeshInstance3D:
		var node: MeshInstance3D = super._box(label,size,at,color,solid,rotation_at,emission)
		if label.begins_with("facade_") and label.ends_with("_pier"):
			piers.append({"owner":_owner,"label":label,"bounds":node.transform*node.mesh.get_aabb(),"at":at,"size":size,"color":color,"solid":solid,"rotation":rotation_at,"material":node.material_override,"openings":current_openings.duplicate()})
		return node

class OriginalWorld:
	extends Original
	var piers: Array[Dictionary] = []
	var current_openings: Array[Vector2] = []
	func _facade_bays(rect: Rect2,height: float,index: int,finish: String,color: String,openings: Array[Vector2]) -> void:
		current_openings = openings.duplicate()
		super._facade_bays(rect,height,index,finish,color,openings)
	func _box(label: String,size: Vector3,at: Vector3,color: String,solid: bool = false,rotation_at: Vector3 = Vector3.ZERO,emission: float = 0.0) -> MeshInstance3D:
		var node: MeshInstance3D = super._box(label,size,at,color,solid,rotation_at,emission)
		if label.begins_with("facade_") and label.ends_with("_pier"):
			piers.append({"owner":_owner,"label":label,"bounds":node.transform*node.mesh.get_aabb(),"at":at,"size":size,"color":color,"solid":solid,"rotation":rotation_at,"material":node.material_override,"openings":current_openings.duplicate()})
		return node

func _initialize() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _boundaries() -> void:
	var gaps: Array[Vector2] = [Vector2(1.0,2.0)]
	for row: Array in [[0.0,.25,false],[.75,.25,false],[.7501,.25,true],[1.5,.25,true],[2.2499,.25,true],[2.25,.25,false],[1.5,1.0,true]]:
		check(World._pier_overlaps_opening(row[0],row[1],gaps) == row[2],"positive full-extent intersection, including outside-center overlap and exact tangency")
	var empty: Array[Vector2] = []
	check(not World._pier_overlaps_opening(1.5,1.0,empty),"closed facade retains original pier")
	gaps.append(Vector2(4,5))
	check(World._pier_overlaps_opening(5.125,.25,gaps),"every authored opening participates")
	groups += 1

func _overlap(pier: Dictionary) -> bool:
	# Independent witness: intersect actual constructed BoxMesh AABB with an
	# opening slab, not the candidate's center/half-width implementation.
	var bounds: AABB = pier.bounds
	for gap: Vector2 in pier.openings:
		var opening := AABB(Vector3(gap.x,bounds.position.y,bounds.position.z),Vector3(gap.y-gap.x,bounds.size.y,bounds.size.z))
		if bounds.intersects(opening): return true
	return false
func _collision_rows(world) -> Array:
	var rows: Array = []
	for record: Dictionary in world._obstacles:
		var body: StaticBody3D = record.body
		var shape: Shape3D = body.get_child(0).shape
		var sizes: Variant = shape.size if shape is BoxShape3D else Vector2(shape.radius,shape.height) if shape is CylinderShape3D else null
		rows.append([record.owner,record.bounds,body.transform,body.collision_layer,body.collision_mask,shape.get_class(),sizes])
	return rows
func _source_rows(world) -> Dictionary:
	var result: Dictionary = world.source_records.duplicate(true)
	for category: String in result:
		for id: String in result[category]: result[category][id].erase("mesh_count")
	return result
func _physical_ray(world,from: Vector3,to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from,to,1); q.hit_from_inside = true
	return world.get_world_3d().direct_space_state.intersect_ray(q)
func _mesh_hits(node: Node,from: Vector3,to: Vector3) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for child: Node in node.get_children():
		if child is MeshInstance3D and child.visible and child.mesh != null:
			var part := child as MeshInstance3D
			var inverse: Transform3D = part.global_transform.affine_inverse()
			var a: Vector3 = inverse*from; var b: Vector3 = inverse*to
			if part.get_aabb().intersects_segment(a,b) != null:
				for surface: int in range(part.mesh.get_surface_count()):
					var arrays: Array = part.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
					var count: int = vertices.size() if indices.is_empty() else indices.size()
					for index: int in range(0,count,3):
						var i0: int = index if indices.is_empty() else indices[index]
						var i1: int = index+1 if indices.is_empty() else indices[index+1]
						var i2: int = index+2 if indices.is_empty() else indices[index+2]
						var point: Variant = Geometry3D.segment_intersects_triangle(a,b,vertices[i0],vertices[i1],vertices[i2])
						if point is Vector3: hits.append({"point":part.global_transform*point,"mesh":str(part.name)})
		hits.append_array(_mesh_hits(child,from,to))
	return hits
func _build(world) -> void:
	world.dynamic_interactive = true; world.dynamic_cart = true
	world.dynamic_ownership = true; world.dynamic_fixture_motion = true
	root.add_child(world); world.build()
	await process_frame; await physics_frame

func _run() -> void:
	_boundaries()
	var original := OriginalWorld.new(); await _build(original)
	var before_piers: Array[Dictionary] = original.piers.duplicate()
	var before_collisions: Array = _collision_rows(original)
	var before_services: Dictionary = original.service_points.duplicate(true)
	var before_anchors: Dictionary = original.anchors().duplicate(true)
	var before_apertures: Array = original.aperture_witnesses.duplicate(true)
	var before_sources: Dictionary = _source_rows(original)
	var before_counts: Dictionary = original.source_records.duplicate(true)
	var before_footprints: Array = original.solid_footprints.duplicate()
	var corner: Array[Dictionary] = []
	for pier: Dictionary in before_piers:
		if pier.owner == "structures:building_01" and _overlap(pier): corner.append(pier)
	check(corner.size() == 1,"actual original CORNER has exactly one aperture-obstructing pier")
	if corner.size() == 1:
		check(corner[0].at.is_equal_approx(Vector3(22.8,2.25,3.63)) and corner[0].size == Vector3(.20,4.5,.13),"actual original pier matches retained receipt image")
		check(not corner[0].solid and corner[0].bounds.intersects_segment(EYE,REST_PAPER) != null,"actual original decorative box crosses recorded hand sightline")
	check(not _mesh_hits(original,EYE,REST_PAPER).is_empty(),"meaningful original failure: final batched mesh blocks recorded rest-hand ray")
	check(not _mesh_hits(original,EYE,TONY_TARGET).is_empty(),"original final mesh blocks recorded actor sightline")
	check(_physical_ray(original,EYE,REST_PAPER).is_empty() and _physical_ray(original,EYE,TONY_TARGET).is_empty(),"original physical LOS accepts despite decorative obstruction")
	groups += 1
	original.free(); await process_frame; await physics_frame
	var current := CurrentWorld.new(); await _build(current)
	var expected: Array[Dictionary] = []; var removed: Dictionary = {}
	for pier: Dictionary in before_piers:
		if _overlap(pier): removed[pier.owner] = int(removed.get(pier.owner,0))+1
		else: expected.append(pier)
	check(not removed.is_empty() and removed.has("structures:building_01"),"original negative reference cannot vacuously pass")
	check(current.piers == expected,"every nonoverlapping pier retains original order, mesh bounds, material and transform")
	for pier: Dictionary in current.piers: check(not _overlap(pier),"actual generated pier leaves the complete authored opening clear")
	check(_mesh_hits(current,EYE,REST_PAPER).is_empty(),"candidate final batched geometry clears exact recorded rest-hand ray")
	check(_mesh_hits(current,EYE,TONY_TARGET).is_empty(),"candidate final geometry clears exact recorded actor ray")
	check(_physical_ray(current,EYE,REST_PAPER).is_empty() and _physical_ray(current,EYE,TONY_TARGET).is_empty(),"physical LOS remains unchanged")
	groups += 1
	check(_collision_rows(current) == before_collisions,"all generated colliders retain exact owner, bounds, transform, shape and layer/mask")
	check(current.solid_footprints == before_footprints,"all standing footprints unchanged")
	check(current.service_points == before_services and current.anchors() == before_anchors,"all services/approaches/reaches and anchors unchanged")
	check(current.aperture_witnesses == before_apertures,"all original openings unchanged")
	check(_source_rows(current) == before_sources,"all source records unchanged excluding derived mesh counts")
	for category: String in before_counts:
		for id: String in before_counts[category]:
			var old: Dictionary = before_counts[category][id]
			check(int(current.source_records[category][id].mesh_count) == int(old.mesh_count)-int(removed.get(old.owner,0)),"only omitted pier count changes source mesh census")
	groups += 1
	current.free(); await process_frame
	check(groups == 4,"all four groups completed")
	print("FACADE APERTURE GATE: ","PASS" if failures.is_empty() else "FAIL"," (",checks," checks; ",groups,"/4 groups; original_visual_obstruction=true)")
	quit(0 if failures.is_empty() else 1)
