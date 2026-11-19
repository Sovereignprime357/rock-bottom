extends SceneTree
## Bounded pure-view contract. Combat remains the only motion, collision and expiry owner.
const View = preload("res://scripts/projectile_view.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _record(kind: String = "bottle",rotation: float = 0.0) -> Dictionary:
	return {"kind":kind,"x":1050.0,"y":840.0,"rot":rotation,"vx":-320.0,"vy":17.0,"rotVel":0.25,"life":4000.0,"dmg":15.0,"slowMs":0.0,"from":{"id":"source_actor"}}
func _meshes(view: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in view.find_children("*","MeshInstance3D",true,false): result.append(node as MeshInstance3D)
	return result
func _structure(view: Node) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in view.find_children("*","",true,false):
		var row: Array = [node.get_instance_id()]
		if node is MeshInstance3D: row.append(node.mesh); row.append(node.material_override)
		result[str(view.get_path_to(node))] = row
	return result
func _immutable(view: Node) -> Dictionary:
	var result: Dictionary = {}
	for instance: MeshInstance3D in _meshes(view):
		var surfaces: Array = []
		for index: int in range(instance.mesh.get_surface_count()):
			var material: StandardMaterial3D = instance.get_active_material(index) as StandardMaterial3D
			var alpha: float = 1.0 if instance.name in [&"Glass",&"Halo"] else material.albedo_color.a
			surfaces.append([hash(instance.mesh.surface_get_arrays(index)),material,Color(material.albedo_color,alpha),material.roughness,material.metallic,material.emission_enabled,material.emission,material.cull_mode,material.transparency,material.albedo_texture])
		result[str(view.get_path_to(instance))] = surfaces
	return result
func _alpha(view: View,leaf: String) -> float:
	var mesh: MeshInstance3D = view.get_node("Art/holy/"+leaf)
	return (mesh.material_override as StandardMaterial3D).albedo_color.a
func _banks(view: View,kind: String) -> bool:
	return (view.get_node("Art/bottle") as Node3D).visible == (kind == "bottle") and (view.get_node("Art/holy") as Node3D).visible == (kind == "holy")
func _ownership(view: View) -> void:
	var nodes: Array[Node] = [view]; nodes.append_array(view.find_children("*","",true,false))
	for node: Node in nodes:
		_check(not (node is CollisionObject3D or node is CollisionShape3D or node is Timer or node is Light3D or node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is Camera3D),"projectile view has no gameplay, collision, clock, light or audio node")
		_check(not node.is_processing() and not node.is_physics_processing() and not node.is_processing_input() and not node.is_processing_unhandled_input(),"projectile view has no automatic clock/input callback")
	for name: String in ["Glass","Halo"]:
		var mesh: MeshInstance3D = view.get_node("Art/holy/"+name)
		_check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"transparent "+name+" casts no shadow")
func _geometry(view: View,kind: String) -> void:
	var valid: bool = true; var front: bool = true; var count: int = 0
	var bounds := AABB(); var started: bool = false
	for instance: MeshInstance3D in _meshes(view.get_node("Art/"+kind)):
		var transform: Transform3D = view.global_transform.affine_inverse()*instance.global_transform
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array: valid = false; continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			valid = valid and vertices.size() == normals.size(); count += vertices.size()
			for index: int in range(vertices.size()):
				var point: Vector3 = transform*vertices[index]
				valid = valid and point.is_finite() and index < normals.size()
				if index < normals.size(): valid = valid and normals[index].is_finite() and absf(normals[index].length()-1.0) < 0.001
				bounds = bounds.expand(point) if started else AABB(point,Vector3.ZERO); started = true
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
			var size: int = indices.size() if not indices.is_empty() else vertices.size()
			valid = valid and size%3 == 0
			for offset: int in range(0,size-2,3):
				var a: int = indices[offset] if not indices.is_empty() else offset
				var b: int = indices[offset+1] if not indices.is_empty() else offset+1
				var c: int = indices[offset+2] if not indices.is_empty() else offset+2
				if mini(a,mini(b,c)) < 0 or maxi(a,maxi(b,c)) >= mini(vertices.size(),normals.size()): valid = false; continue
				var cross: Vector3 = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
				if cross.length_squared() < 0.0000000000000001: continue
				var normal: Vector3 = -cross.normalized()
				front = front and normals[a].dot(normal) > 0 and normals[b].dot(normal) > 0 and normals[c].dot(normal) > 0
	_check(started and count > 0 and valid and front,"finite unit front-facing actual geometry "+kind)
	_check(bounds.size.length() < 0.65 and bounds.get_center().length() < 0.15,"source-scale compact centered projectile silhouette "+kind)
func _projection(first: View) -> void:
	var kinds: Array[String] = []
	for kind: StringName in View.supported_kinds(): kinds.append(str(kind))
	kinds.sort(); _check(kinds == ["bottle","holy"],"only the two exact source render kinds are supported")
	for kind: String in kinds:
		for angle: float in [0.0,PI*0.5,PI,-PI*0.5,TAU*3.0+0.37]:
			var record: Dictionary = _record(kind,angle); var before: Dictionary = record.duplicate(true)
			_check(first.project(record,120.0) and first.visible and first.presentation_kind == kind and _banks(first,kind),"exact selected bank replaces prior kind "+kind)
			_check(first.position.is_equal_approx(Content.to_world(Vector2(record.x,record.y),1.0)) and first.source_rotation == angle,"source center and raw provided rotation retained")
			var marker: Node3D = first.get_node("Art/"+kind+("/neck_marker" if kind == "bottle" else "/cap_marker"))
			var local: Vector3 = first.to_local(marker.global_position)
			var source_marker: Vector2 = Vector2(0.176,0) if kind == "bottle" else Vector2(0,-0.144)
			var expected: Vector2 = source_marker.rotated(angle)
			_check(Vector2(local.x,local.z).is_equal_approx(expected) and absf(local.y) < 0.00001,"actual marker follows source clockwise plane rotation, independent of velocity")
			_check(record == before,"projection preserves full authoritative projectile record")
			_geometry(first,kind)
	var sampled: Dictionary = _record("bottle",-0.3)
	sampled.life = -1; sampled.vx = {}; sampled.rotVel = INF; sampled.slowMs = null
	_check(first.project(sampled) and first.visible,"view ignores motion, lifetime and combat fields rather than owning their validation or expiry")
	var pose: Transform3D = first.transform; sampled.x += 300.0
	_check(first.transform == pose,"caller mutations cannot move a projected view without another projection")
	_check(first.project(sampled) and first.position != pose.origin,"next explicit projection consumes current source coordinates")
func _invalid(view: View) -> void:
	var rows: Array[Dictionary] = [{},{"kind":"shoe"},{"kind":&"bottle"},{"kind":true},{"kind":["holy"]},{"x":NAN},{"y":INF},{"rot":-INF},{"x":1e100},{"x":"1050"},{"rot":null}]
	for row: Dictionary in rows:
		view.project(_record("holy"),0.0)
		var record: Dictionary = _record(); record.merge(row,true)
		if row.is_empty(): record.erase("rot")
		_check(not view.project(record) and not view.visible,"unknown/malformed projectile hides prior visible art: "+str(row))
	for time: float in [NAN,INF,-INF]:
		view.project(_record()); _check(not view.project(_record("holy"),time) and not view.visible,"invalid explicit render time hides without keeping stale art")
	_check(view.project(_record("bottle",1e100)) and view.transform.is_finite() and (view.get_node("Art") as Node3D).transform.is_finite(),"finite large angle is safely reduced for visual trigonometry")
func _pulse_and_cache(first: View,second: View) -> void:
	var a: Dictionary = _structure(first); var b: Dictionary = _structure(second)
	var immutable: Dictionary = _immutable(first); var isolated: Dictionary = _immutable(second)
	var shared: bool = true; var alpha_distinct: bool = true
	for path: String in a:
		if not first.get_node(path) is MeshInstance3D: continue
		var first_mesh: MeshInstance3D = first.get_node(path); var second_mesh: MeshInstance3D = second.get_node(path)
		shared = shared and first_mesh.mesh == second_mesh.mesh
		if first_mesh.name in [&"Glass",&"Halo"]: alpha_distinct = alpha_distinct and first_mesh.material_override != second_mesh.material_override
		else:
			for surface: int in range(first_mesh.mesh.get_surface_count()): shared = shared and first_mesh.get_active_material(surface) == second_mesh.get_active_material(surface)
	_check(shared and alpha_distinct,"all meshes and solid materials shared; both opacity materials independent per view")
	var low: float = 80.0*PI*1.5; var high: float = 80.0*PI*0.5
	second.project(_record("holy",0.7),low); var second_pose: Transform3D = (second.get_node("Art") as Node3D).transform
	var record: Dictionary = _record("holy",0.2); var before: Dictionary = record.duplicate(true)
	first.project(record,low); var position: Vector3 = first.position; var art_pose: Transform3D = (first.get_node("Art") as Node3D).transform
	_check(is_equal_approx(_alpha(first,"Glass"),0.75) and is_equal_approx(_alpha(first,"Halo"),0.18),"source holy pulse minimum sampled from supplied wall time")
	first.project(record,high)
	_check(is_equal_approx(_alpha(first,"Glass"),1.0) and is_equal_approx(_alpha(first,"Halo"),0.36),"source holy pulse maximum sampled from supplied wall time")
	_check(first.position == position and (first.get_node("Art") as Node3D).transform == art_pose and record == before,"advancing only render time leaves pose and authoritative record unchanged")
	_check(is_equal_approx(_alpha(second,"Glass"),0.75) and is_equal_approx(_alpha(second,"Halo"),0.18) and (second.get_node("Art") as Node3D).transform == second_pose,"another instance keeps its sampled alpha and pose")
	for index: int in range(60): first.project(_record("bottle" if index%2 == 0 else "holy",index*0.17),index*80.0)
	_check(_structure(first) == a and _structure(second) == b,"repeated kind/pose/pulse changes reuse all node and resource identities")
	_check(_immutable(first) == immutable and _immutable(second) == isolated,"projection mutates only the two owned alpha values, not cached geometry or material content")
	# Scene uses array-index views. Replay a removal/compaction into the same first view.
	first.project(_record("bottle")); second.project(_record("holy",PI*0.5))
	var compacted: Dictionary = _record("holy",PI*0.5); compacted.x = 1080.0
	_check(first.project(compacted) and first.presentation_kind == "holy" and _banks(first,"holy") and first.position == Content.to_world(Vector2(1080,840),1.0),"same-index compaction fully replaces kind and center instead of retaining bottle art")
	_check(first.project(_record("bottle",PI)) and _banks(first,"bottle"),"same indexed slot may later return to bottle using its cached bank")
func _run() -> void:
	seed(80129); var expected_random: float = randf(); seed(80129)
	var first: View = View.create(); var second: View = View.create()
	_check(first.get_parent() == null and second.get_parent() == null and not first.visible and not second.visible,"factories return hidden unparented projectile views")
	root.add_child(first); root.add_child(second)
	_check(first.has_node("Art/bottle/neck_marker") and first.has_node("Art/holy/cap_marker"),"both cached banks expose authored orientation markers")
	_ownership(first); _projection(first); _invalid(first); _pulse_and_cache(first,second)
	_check(randf() == expected_random,"construction and projection consume no global RNG")
	first.free(); second.free(); await process_frame
	if failures.is_empty(): print("3D PROJECTILE VIEW GATE: PASS (%d checks; two source kinds)"%checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D PROJECTILE VIEW GATE: FAIL (%d failures/%d checks)"%[failures.size(),checks]); quit(1)
