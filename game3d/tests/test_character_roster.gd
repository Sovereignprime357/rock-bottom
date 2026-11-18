extends SceneTree

const Roster = preload("res://scripts/character_roster.gd")
const Animator = preload("res://scripts/actor_animation.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(Roster.supported_visuals().size() == 6,"first checkpoint advertises exactly its six implemented identities")
	_check(Roster.create(&"unbuilt_bird") == null and Roster.definition(&"unbuilt_bird").is_empty(),"unsupported identities cannot silently become generic models")
	var copy := Roster.definition(&"tony")
	copy.height = 99.0
	copy.actions.clear()
	_check(float(Roster.definition(&"tony").height) < 3.0 and not Roster.definition(&"tony").actions.is_empty(),"definition edits cannot corrupt the immutable roster")
	var completed_models: int = 0
	for id: String in Roster.supported_visuals():
		var first := Roster.create(StringName(id),17)
		var second := Roster.create(StringName(id),17)
		_check(first != null and second != null,id+": both complete model instances construct successfully")
		if first == null or second == null:
			if first != null: first.free()
			if second != null: second.free()
			continue
		root.add_child(first)
		root.add_child(second)
		await process_frame
		var geometry_complete := _geometry(first,second,id)
		var animation_complete := _animation(first,second,id)
		_check(geometry_complete and animation_complete,id+": both gate sections reach completion without a script abort")
		if geometry_complete and animation_complete: completed_models += 1
		first.free()
		second.free()
	_check(completed_models == 6,"all six identities complete construction, geometry and animation checks")
	if failures.is_empty():
		print("3D CHARACTER ROSTER GATE: PASS (%d checks; weighted original six, shared resources/independent poses, finite joints/UVs, coat states and current low-detail actions)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D CHARACTER ROSTER GATE: FAIL (%d / %d checks)" % [failures.size(),checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		if child is MeshInstance3D: result.append(child as MeshInstance3D)
		result.append_array(_meshes(child))
	return result


func _no_gameplay(node: Node) -> bool:
	if node is CollisionObject3D or node is Timer or node is AudioStreamPlayer or node is AudioStreamPlayer3D: return false
	for child: Node in node.get_children():
		if not _no_gameplay(child): return false
	return true


func _geometry(first: Node3D, second: Node3D, id: String) -> bool:
	var a := _meshes(first)
	var b := _meshes(second)
	var rig: Dictionary = first.get_meta("roster_rig")
	var skeleton: Skeleton3D = rig.skeleton
	var human: bool = rig.definition.family == "human"
	var cached: bool = a.size() == b.size()
	var finite: bool = true
	var weights_valid: bool = true
	var uv_valid: bool = true
	var oriented: bool = true
	var weighted_vertices: int = 0
	var blended_vertices: int = 0
	var max_influences: int = 0
	var triangles: int = 0
	var surfaces: int = 0
	for mesh_index: int in range(a.size()):
		var item: MeshInstance3D = a[mesh_index]
		cached = cached and item.mesh == b[mesh_index].mesh and item.skin == b[mesh_index].skin and item.material_override == b[mesh_index].material_override
		for surface: int in range(item.mesh.get_surface_count()):
			surfaces += 1
			var arrays: Array = item.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			triangles += floori(float(count)/3.0)
			finite = finite and vertices.size() == normals.size()
			for i: int in range(vertices.size()): finite = finite and vertices[i].is_finite() and normals[i].is_finite()
			for i: int in range(0,count,3):
				var ia: int = indices[i] if not indices.is_empty() else i
				var ib: int = indices[i+1] if not indices.is_empty() else i+1
				var ic: int = indices[i+2] if not indices.is_empty() else i+2
				var outward := -(vertices[ib]-vertices[ia]).cross(vertices[ic]-vertices[ia])
				if outward.length_squared() < 0.000000000001: continue
				# Legacy rigid heads retain zero-area pole triangles. Unit/outward
				# requirements apply to triangles that can actually be rendered.
				for index: int in [ia,ib,ic]: oriented = oriented and normals[index].dot(outward) > 0.0 and absf(normals[index].length()-1.0) < 0.002
			if item.skin == null: continue
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			weights_valid = weights_valid and bones.size() == vertices.size()*4 and weights.size() == vertices.size()*4
			uv_valid = uv_valid and uvs.size() == vertices.size()
			for uv: Vector2 in uvs: uv_valid = uv_valid and uv.is_finite() and absf(uv.x) < 4.0 and absf(uv.y) < 4.0
			for vertex: int in range(vertices.size()):
				var total: float = 0.0
				var influences: int = 0
				for slot: int in range(4):
					var offset := vertex*4+slot
					weights_valid = weights_valid and bones[offset] >= 0 and bones[offset] < skeleton.get_bone_count() and is_finite(weights[offset]) and weights[offset] >= 0.0
					total += weights[offset]
					if weights[offset] > 0.00001: influences += 1
				weights_valid = weights_valid and absf(total-1.0) < 0.0001
				weighted_vertices += 1
				if influences > 1: blended_vertices += 1
				max_influences = maxi(max_influences,influences)
	var metrics: Dictionary = first.get_meta("roster_metrics")
	print("ROSTER %s: meshes=%d surfaces=%d triangles=%d bones=%d max_weights=%d blended_vertices=%d" % [id,a.size(),surfaces,triangles,skeleton.get_bone_count(),max_influences,blended_vertices])
	_check(cached,id+": instances share meshes, skins and materials")
	_check(finite and oriented,id+": geometry has finite unit outward normals")
	_check(weights_valid and weighted_vertices > 100 and blended_vertices > 50 and max_influences <= 4,id+": normalized bounded skin influences actually blend articulated surfaces")
	_check(uv_valid,id+": deforming surfaces carry finite fixed UVs")
	_check(triangles > 1500 and triangles < 40000 and skeleton.get_bone_count() >= (24 if human else 18),id+": useful bounded geometry and an anatomical bone hierarchy")
	_check(metrics.meshes == a.size() and metrics.surfaces == surfaces and metrics.triangles == triangles and metrics.bones == skeleton.get_bone_count(),id+": reported metrics count all weighted and attached geometry")
	_check(first.has_node("head") and _no_gameplay(first),id+": stable head handle and presentation-only node ownership")
	var rest_vertices := _posed_vertices(first)
	_check(_bounded(rest_vertices,Vector3(1.2,2.7,1.5)),id+": actual rest geometry fits its broad actor envelope")
	return true


func _posed_vertices(art: Node3D, selected_bone: int = -1, only_skinned: bool = false) -> PackedVector3Array:
	var rig: Dictionary = art.get_meta("roster_rig")
	var skeleton: Skeleton3D = rig.skeleton
	var result := PackedVector3Array()
	for part: MeshInstance3D in _meshes(art):
		if not part.is_visible_in_tree(): continue
		var local := Roster._relative(part,art)
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if part.skin == null:
				if selected_bone < 0 and not only_skinned:
					for vertex: Vector3 in vertices: result.append(local*vertex)
				continue
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var palette: Array[Transform3D] = []
			for i: int in range(part.skin.get_bind_count()): palette.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(i))*part.skin.get_bind_pose(i))
			for vertex: int in range(vertices.size()):
				var point := Vector3.ZERO
				var relevant: bool = selected_bone < 0
				for slot: int in range(4):
					var offset := vertex*4+slot
					point += (palette[bones[offset]]*vertices[vertex])*weights[offset]
					if bones[offset] == selected_bone and weights[offset] > 0.25: relevant = true
				if relevant: result.append(local*point)
	return result


func _bounded(vertices: PackedVector3Array, extent: Vector3) -> bool:
	if vertices.is_empty(): return false
	for vertex: Vector3 in vertices:
		if not vertex.is_finite() or absf(vertex.x) > extent.x or vertex.y < -0.35 or vertex.y > extent.y or absf(vertex.z) > extent.z: return false
	return true


func _poses(art: Node3D) -> Array[Transform3D]:
	var skeleton := art.get_node("Skeleton") as Skeleton3D
	var result: Array[Transform3D] = []
	for i: int in range(skeleton.get_bone_count()): result.append(skeleton.get_bone_pose(i))
	return result


func _max_motion(before: PackedVector3Array, after: PackedVector3Array) -> float:
	if before.size() != after.size(): return INF
	var distance: float = 0.0
	for i: int in range(before.size()): distance = maxf(distance,before[i].distance_to(after[i]))
	return distance


func _animation(first: Node3D, second: Node3D, id: String) -> bool:
	var rig: Dictionary = first.get_meta("roster_rig")
	var other: Dictionary = second.get_meta("roster_rig")
	var human: bool = rig.definition.family == "human"
	var initial := _poses(first)
	var origin := first.transform
	var resources := _meshes(first)
	var elbow: int = rig.lookup["right_elbow" if human else "front_left_knee"]
	var rest_joint := _posed_vertices(first,elbow)
	var request := {"action":&"windup","action_phase":1.0,"local_velocity":Vector3.ZERO,"coat_count":3}
	var saved_request := request.duplicate(true)
	Animator.tick(first,1.0/60.0,request)
	_check(request == saved_request and first.transform == origin,id+": presentation cannot modify snapshot or actor origin")
	_check(_poses(second) == initial and rig.skeleton != other.skeleton,id+": independent skeleton poses cannot cross between cached instances")
	if human: _check(_max_motion(rest_joint,_posed_vertices(first,elbow)) > 0.03,id+": accepted windup deforms actual elbow geometry")
	Animator.reset(first)
	if human:
		var finger: int = rig.lookup["right_fingertips"]
		var open_extent := _finger_extent(first,finger,"right_wrist")
		Animator.tick(first,1.0/60.0,{"action":&"strike","action_phase":0.03,"contact":true,"action_serial":0})
		var skeleton: Skeleton3D = rig.skeleton
		var shoulder := skeleton.get_bone_global_pose(rig.lookup["right_shoulder"]).origin
		var wrist := skeleton.get_bone_global_pose(rig.lookup["right_wrist"]).origin
		_check(wrist.y > shoulder.y-0.18 and wrist.z > shoulder.z+0.25,id+": peak strike extends a nearly level hand toward actor +Z")
		var closed_extent := _finger_extent(first,finger,"right_wrist")
		_check(closed_extent > open_extent+0.015,id+": peak strike curls actual finger geometry into a shorter grip (open %.5f, closed %.5f)" % [open_extent,closed_extent])
		Animator.reset(first)
	var knee: int = rig.lookup["left_knee" if human else "front_left_knee"]
	var knee_rest := _posed_vertices(first,knee)
	var motion: float = 0.0
	var safe: bool = true
	for frame: int in range(12):
		Animator.tick(first,1.0/60.0,{"local_velocity":Vector3(0,0,1.6)})
		if frame%3 == 0:
			motion = maxf(motion,_max_motion(knee_rest,_posed_vertices(first,knee)))
			safe = safe and _bounded(_posed_vertices(first),Vector3(1.5,3.0,1.8))
	_check(motion > 0.015 and safe,id+": actual +Z travel bends weighted knees within the actor envelope")
	for frame: int in range(90): Animator.tick(first,1.0/60.0,{"local_velocity":Vector3.ZERO})
	_check(float(rig.motion) < 0.001,id+": stopped motion settles without input-driven walking")
	Animator.reset(first)
	Animator.reset(second)
	for frame: int in range(120):
		Animator.tick(first,1.0/60.0,{},0)
		Animator.tick(second,1.0/60.0,{},2)
	_check(int(other.pose_updates) < int(rig.pose_updates)/2 and is_equal_approx(float(other.time),float(rig.time)),id+": distant detail reduces pose work while consuming active time")
	if human: _check(int(other.finger_updates) == 0 and int(rig.finger_updates) > 0,id+": distant detail suppresses finger cosmetics")
	Animator.tick(second,1.0/60.0,{"action":&"windup","action_phase":1.0},2)
	var wound := _poses(second)
	Animator.tick(second,1.0/60.0,{"action":&"strike" if human else &"bite","action_phase":1.0},2)
	_check(_poses(second) != wound,id+": current action phase replaces a far-away pose immediately")
	Animator.tick(second,1.0/60.0,{"dead":true,"death_phase":1.0},2)
	_check(_bounded(_posed_vertices(second),Vector3(2.8,3.0,3.0)) and second.transform == Transform3D.IDENTITY,id+": death changes visual bones without moving the actor")
	var uncropped := _skin_inside_bounds(second)
	for state: Dictionary in [{"action":&"windup","action_phase":1.0},{"action":&"throw" if human else &"lunge","action_phase":0.0}]:
		Animator.tick(second,1.0/60.0,state,0)
		uncropped = uncropped and _skin_inside_bounds(second)
	_check(uncropped,id+": actual weighted death/extended geometry stays within its render culling bounds")
	Animator.tick(second,1.0/60.0,{},0)
	_check(_poses(second) != wound and absf((other.skeleton as Skeleton3D).get_bone_pose_rotation(0).get_euler().x) < 0.01,id+": return to near detail clears stale death/action transforms")
	Animator.reset(first)
	var before := _poses(first)
	for invalid: float in [NAN,INF,0.0,-1.0]: Animator.tick(first,invalid,{"action":&"windup","action_phase":1.0})
	_check(before == _poses(first),id+": malformed time does not advance poses")
	Animator.tick(first,1000.0,{"local_velocity":Vector3(NAN,INF,-INF),"turn_rate":INF,"gaze":Vector2(NAN,INF),"hurt":NAN,"action":{},"coat_count":"bad","death_phase":INF},2)
	_check(_bounded(_posed_vertices(first),Vector3(2.5,3.0,2.5)),id+": malformed pose input stays finite and bounded")
	Animator.reset(first)
	_check(_poses(first) == initial and first.transform == origin and _meshes(first).size() == resources.size(),id+": reset restores rest without changing cached resources or node count")
	if id == "tony":
		for coats: int in range(4):
			Animator.tick(first,1.0/60.0,{"coat_count":coats},2)
			var correct: bool = true
			for layer: int in range(1,4):
				correct = correct and not (rig.layers[layer] as Array).is_empty()
				for mesh: MeshInstance3D in rig.layers[layer]: correct = correct and mesh.visible == (layer <= coats)
			_check(correct,"Tony: exact %d-coat visibility applies at distant detail" % coats)
		Animator.reset(first)
		Animator.tick(first,1.0/60.0,{"coat_count":0})
		var skin_vertices := _posed_vertices(first,-1,true)
		var joined: bool = true
		for side: float in [-1.0,1.0]:
			for x: float in [0.21,0.24,0.27]: joined = joined and _front_covers(skin_vertices,Vector2(side*x,1.38))
		_check(joined,"Tony's bare shoulder silhouette connects the chest and both upper arms")
		var head := first.get_node("head") as Node3D
		var eye_parts: Array[Transform3D] = []
		for mesh: MeshInstance3D in _meshes(head): eye_parts.append(mesh.transform)
		for frame: int in range(180): Animator.tick(first,1.0/60.0,{})
		var unchanged: bool = true
		var index: int = 0
		for mesh: MeshInstance3D in _meshes(head):
			unchanged = unchanged and mesh.transform == eye_parts[index]
			index += 1
		_check(unchanged,"Tony's face parts never blink or change eye scale")
	if id == "pete":
		Animator.reset(first)
		var continuous: bool = true
		for x: float in [-0.10,0.0,0.10]:
			for y: float in [0.70,0.80,0.98,1.11,1.21]:
				continuous = continuous and _front_color(first,Vector2(x,y)).is_equal_approx(Color("b9ad7f"))
		for x: float in [-0.24,-0.20,0.20,0.24]:
			for y: float in [0.70,0.80,0.90,0.98,1.05,1.11]:
				continuous = continuous and _front_color(first,Vector2(x,y)).is_equal_approx(Color("b9ad7f"))
		_check(continuous,"Pete's apron is the visible continuous front surface across its lower panel, belly and bib")
	return true


func _finger_extent(art: Node3D, bone: int, wrist_name: String) -> float:
	var rig: Dictionary = art.get_meta("roster_rig")
	var skeleton: Skeleton3D = rig.skeleton
	var hand_space := skeleton.get_bone_global_pose(rig.lookup[wrist_name]).affine_inverse()
	var extent: float = INF
	for vertex: Vector3 in _posed_vertices(art,bone): extent = minf(extent,(hand_space*vertex).y)
	return extent


func _front_covers(vertices: PackedVector3Array, point: Vector2) -> bool:
	# Weighted body surfaces are sequential triangles. Test their actual front
	# projection for the shoulder opening that bounds/weight checks cannot see.
	for i: int in range(0,vertices.size(),3):
		var polygon := PackedVector2Array([Vector2(vertices[i].x,vertices[i].y),Vector2(vertices[i+1].x,vertices[i+1].y),Vector2(vertices[i+2].x,vertices[i+2].y)])
		if Geometry2D.is_point_in_polygon(point,polygon): return true
	return false


func _front_color(art: Node3D, point: Vector2) -> Color:
	# Inspect final weighted triangles, not construction rows. A shirt/button
	# protruding through the apron must be caught as the nearer visible surface.
	var vertices := _posed_vertices(art,-1,true)
	var colors := PackedColorArray()
	for part: MeshInstance3D in _meshes(art):
		if part.skin == null or not part.is_visible_in_tree(): continue
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			colors.append_array(arrays[Mesh.ARRAY_COLOR] as PackedColorArray)
	var nearest: float = -INF
	var color := Color.TRANSPARENT
	for i: int in range(0,vertices.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(point.x,point.y,2.0),Vector3(point.x,point.y,-2.0),vertices[i],vertices[i+1],vertices[i+2])
		if hit is Vector3 and hit.z > nearest:
			nearest = hit.z
			color = colors[i]
	return color


func _skin_inside_bounds(art: Node3D) -> bool:
	var skeleton := art.get_node("Skeleton") as Skeleton3D
	for part: MeshInstance3D in _meshes(art):
		if part.skin == null: continue
		var palette: Array[Transform3D] = []
		for i: int in range(part.skin.get_bind_count()): palette.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(i))*part.skin.get_bind_pose(i))
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for i: int in range(vertices.size()):
				var point := Vector3.ZERO
				for slot: int in range(4): point += (palette[bones[i*4+slot]]*vertices[i])*weights[i*4+slot]
				if not point.is_finite() or not part.custom_aabb.grow(0.001).has_point(point): return false
	return true
