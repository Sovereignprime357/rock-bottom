extends SceneTree
## CPU geometry/pose contract; no rendered or physical-world acceptance claim.

const Roster = preload("res://scripts/character_roster.gd")
const Pose = preload("res://scripts/actor_animation.gd")
const Original = preload("res://tests/reference_actor_animation_sleep_original.gd")
const Visibility = preload("res://scripts/presentation_visibility.gd")
var checks: int = 0
var failures: Array[String] = []
var completed_groups: int = 0
var sleep_samples: int = 0
var registry_samples: int = 0
var body_minimum: float = INF
var pillow_minimum: float = INF
var contact_minimum: float = INF
var contact_maximum: float = -INF


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failures.size() <= 12: push_error(label)


func _make(id: StringName, seed_value: int = 17) -> Node3D:
	var art: Node3D = Roster.create(id,seed_value)
	root.add_child(art)
	art.position = Vector3(0,0.06,0)
	return art


func _meshes(art: Node3D) -> Array[MeshInstance3D]:
	var stack: Array[Node] = [art]
	var result: Array[MeshInstance3D] = []
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children(): stack.append(child)
		if node is MeshInstance3D: result.append(node as MeshInstance3D)
	return result


func _resources(art: Node3D) -> Array:
	var result: Array = []
	for part: MeshInstance3D in _meshes(art):
		var row: Array = [part.mesh,part.skin]
		for surface: int in range(part.mesh.get_surface_count()):
			row.append(var_to_bytes(part.mesh.surface_get_arrays(surface)))
			row.append(part.mesh.surface_get_material(surface))
		result.append(row)
	return result


func _pose_receipt(art: Node3D) -> Dictionary:
	var rig: Dictionary = art.get_meta("roster_rig")
	var bones: Array[Transform3D] = []
	for index: int in range(rig.skeleton.get_bone_count()): bones.append(rig.skeleton.get_bone_pose(index))
	var attachments: Array[Transform3D] = []
	for binding: Dictionary in rig.attachments: attachments.append(binding.node.transform)
	var children: Array = []
	for child: Dictionary in rig.companions: children.append(_pose_receipt(child.node))
	return {"root":art.transform,"bones":bones,"attachments":attachments,"children":children,"time":rig.time,"phase":rig.phase,"motion":rig.motion,"rest":rig.base_poses,"coats":rig.last_coats}


func _vertices(part: MeshInstance3D, arrays: Array) -> PackedVector3Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var result := PackedVector3Array()
	if part.skin == null:
		for point: Vector3 in vertices: result.append(part.global_transform*point)
		return result
	var skeleton := part.get_node(part.skeleton) as Skeleton3D
	var palette: Array[Transform3D] = []
	for index: int in range(part.skin.get_bind_count()): palette.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(index))*part.skin.get_bind_pose(index))
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for index: int in range(vertices.size()):
		var point := Vector3.ZERO
		for slot: int in range(4):
			var offset: int = index*4+slot
			point += (palette[bones[offset]]*vertices[index])*weights[offset]
		result.append(part.global_transform*point)
	return result


func _geometry(art: Node3D) -> Dictionary:
	var rig: Dictionary = art.get_meta("roster_rig")
	var head: Node3D = rig.prop_lookup.head.node
	var pillow: Node3D = rig.prop_lookup.pillow.node
	var body_low: float = INF
	var pillow_low: float = INF
	var head_low := Vector3(0,INF,0)
	var cushion := PackedVector3Array()
	var finite: bool = true
	var bounded: bool = true
	var radius: float = Visibility.local_radius(art)
	for part: MeshInstance3D in _meshes(art):
		if not part.is_visible_in_tree(): continue
		var is_head: bool = part == head or head.is_ancestor_of(part)
		var is_pillow: bool = part == pillow or pillow.is_ancestor_of(part)
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = _vertices(part,arrays)
			for point: Vector3 in vertices:
				finite = finite and point.is_finite()
				bounded = bounded and point.distance_to(art.global_position) <= radius
				if part.skin != null: body_low = minf(body_low,point.y)
				if is_head and point.y < head_low.y: head_low = point
				if is_pillow: pillow_low = minf(pillow_low,point.y)
			if is_pillow:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
				if indices.is_empty(): cushion.append_array(vertices)
				else:
					for index: int in indices: cushion.append(vertices[index])
	var cushion_y: float = -INF
	for index: int in range(0,cushion.size()-2,3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(head_low+Vector3.UP*0.20,head_low-Vector3.UP*0.40,cushion[index],cushion[index+1],cushion[index+2])
		if hit is Vector3: cushion_y = maxf(cushion_y,hit.y)
	return {"body":body_low,"pillow":pillow_low,"head":head_low,"contact":head_low.y-cushion_y,"contact_found":is_finite(cushion_y),"finite":finite,"bounded":bounded and is_finite(radius),"radius":radius,"cushion_vertices":cushion.size()}


func _sleep_cycle() -> void:
	for seed_value: int in [17,733]: _sleep_seed(seed_value)
	_check(sleep_samples == 384,"all finite sleep phase/detail/seed samples completed")
	completed_groups += 1


func _sleep_seed(seed_value: int) -> void:
	var art := _make(&"dave",seed_value)
	var rig: Dictionary = art.get_meta("roster_rig")
	var resources: Array = _resources(art)
	var original_root: Transform3D = art.transform
	var base_poses: Array = rig.base_poses.duplicate()
	# Match the real Scene: establish the original rest/binding bound before any
	# sleep-specific transform, rather than certifying a bound from our new pose.
	var original_radius: float = Visibility.local_radius(art)
	var snapshot := {"asleep":true,"grounded":true,"local_velocity":Vector3.ZERO,"gaze":Vector2.ZERO}
	var original_snapshot: Dictionary = snapshot.duplicate(true)
	# 1.4,1.3 and0.43 rad/s share this628.3185s period. Finite samples, not a
	# fabricated continuous-time/contact or real-world physics acceptance claim.
	for detail: int in [0,2]:
		for index: int in range(96):
			Pose.reset(art)
			rig.time = TAU*100.0*float(index)/96.0
			Pose.tick(art,0.01,snapshot,detail)
			var facts: Dictionary = _geometry(art)
			var label: String = "sleep seed%d detail%d sample%d" % [seed_value,detail,index]
			_check(facts.finite and facts.bounded and facts.radius == original_radius,label+": actual posed vertices finite and within original prewarmed conservative radius")
			_check(float(facts.body) >= 0.004,label+": actual skin clears the fixed known floor by4mm")
			_check(absf(float(facts.pillow)-0.008) <= 0.000001,label+": existing pillow geometry clears floor by8mm")
			_check(facts.contact_found and float(facts.contact) >= -0.025 and float(facts.contact) <= 0.005,label+": actual cushion triangles support the lowest head within soft-contact interval")
			_check(art.transform == original_root and rig.base_poses == base_poses,label+": actor root and rest remain unchanged")
			body_minimum = minf(body_minimum,float(facts.body))
			pillow_minimum = minf(pillow_minimum,float(facts.pillow))
			contact_minimum = minf(contact_minimum,float(facts.contact))
			contact_maximum = maxf(contact_maximum,float(facts.contact))
			sleep_samples += 1
	_check(_resources(art) == resources,"sleep never mutates cached meshes/arrays/skins/materials")
	_check(snapshot == original_snapshot,"sleep reads the detached authoritative snapshot without mutation")
	art.free()


func _awake_and_transitions() -> void:
	var left := _make(&"dave",733)
	var right := _make(&"dave",733)
	var snapshots: Array[Dictionary] = [
		{}, {"local_velocity":Vector3(0,0,1.4)}, {"action":"talk","action_phase":0.4},
		{"action":"windup","action_phase":0.6,"asleep":true},
		{"action":"strike","action_phase":0.2,"contact":true,"asleep":true},
		{"hurt":0.8,"gaze":Vector2(0.4,0.2)},
		{"asleep":true,"dead":true,"death_phase":0.45},
		{"dead":true,"death_phase":1.0}, {},
	]
	for detail: int in [0,1,2]:
		for index: int in range(snapshots.size()):
			Pose.reset(left); Original.reset(right)
			Pose.tick(left,0.04,{"asleep":true},detail)
			Original.tick(right,0.04,{"asleep":true},detail)
			Pose.tick(left,0.04,snapshots[index],detail)
			Original.tick(right,0.04,snapshots[index],detail)
			_check(_pose_receipt(left) == _pose_receipt(right),"wake/non-sleep/death exact original output detail%d case%d" % [detail,index])
	Pose.reset(left); Original.reset(right)
	_check(_pose_receipt(left) == _pose_receipt(right),"reset exactly restores original wrist grip/rest and clocks")
	Pose.tick(left,0.03,{"asleep":true},0)
	Original.tick(right,0.03,{"asleep":true},0)
	Pose.tick(left,0.03,{"asleep":false},0,false)
	Original.tick(right,0.03,{"asleep":false},0,false)
	_check(_pose_receipt(left) == _pose_receipt(right),"hidden wake transition still restores wrist before optional idle skipping")
	Pose.tick(left,0.03,{},0,true); Original.tick(right,0.03,{},0,true)
	_check(_pose_receipt(left) == _pose_receipt(right),"return to visible awake stays exact")
	left.free(); right.free()
	completed_groups += 1


func _other_identities() -> void:
	for id: StringName in Roster.supported_visuals():
		if id == &"dave": continue
		var left := _make(id,17)
		var right := _make(id,17)
		var snapshot := {"action":"sleep","asleep":true,"action_phase":0.4,"local_velocity":Vector3.ZERO,"grounded":true}
		Pose.tick(left,0.04,snapshot,0)
		Original.tick(right,0.04,snapshot,0)
		_check(_pose_receipt(left) == _pose_receipt(right),String(id)+": sleep/unsupported-sleep output exactly unchanged including child rigs")
		left.free(); right.free()
		registry_samples += 1
	_check(registry_samples == 71,"all other71 original visual identities completed")
	completed_groups += 1


func _run() -> void:
	_sleep_cycle()
	_awake_and_transitions()
	_other_identities()
	_check(completed_groups == 3 and sleep_samples == 384 and registry_samples == 71,"all three bounded groups reached their actual tails")
	print("DAVE SLEEP SUPPORT: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",completed_groups,"/3 groups; ",sleep_samples," sleep samples; ",registry_samples," other identities; body_min=",body_minimum," pillow_min=",pillow_minimum," contact=[",contact_minimum,",",contact_maximum,"]; no rendered acceptance")
	quit(0 if failures.is_empty() else 1)
