extends SceneTree
## Exact A/B projection witnesses; the reference disables only the new input memo.
const Roster = preload("res://scripts/character_roster.gd")
const Animator = preload("res://scripts/actor_animation.gd")
var checks: int = 0
var failures: Array[String] = []
var completed: int = 0
var total_hits: int = 0
var total_solves: int = 0
var reference_solves: int = 0

func _initialize() -> void: call_deferred("_run")
func _check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _set_memo(art: Node3D,enabled: bool) -> void:
	var rig: Dictionary = art.get_meta("roster_rig")
	rig.pose_input_cache_enabled = enabled
	for child: Dictionary in rig.companions: _set_memo(child.node,enabled)

func _node_state(node: Node) -> Array:
	var result: Array = []
	if node is Node3D: result.append([node.transform,node.visible])
	if node is Skeleton3D:
		for index: int in range(node.get_bone_count()): result.append(node.get_bone_pose(index))
	for child: Node in node.get_children(): result.append_array(_node_state(child))
	return result

func _rig_state(art: Node3D) -> Array:
	var rig: Dictionary = art.get_meta("roster_rig"); var result: Array = []
	for key: String in ["time","phase","motion","frame","detail","last_state","pose_updates","finger_updates","pose_deferred","poses","applied_poses","last_coats"]:
		result.append(rig[key])
	for child: Dictionary in rig.companions: result.append_array(_rig_state(child.node))
	return result

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		if child is MeshInstance3D: result.append(child)
		result.append_array(_meshes(child))
	return result

func _resources(art: Node3D) -> Array:
	var result: Array = []
	for part: MeshInstance3D in _meshes(art):
		var row: Array = [part.mesh,part.skin,part.material_override]
		for surface: int in range(part.mesh.get_surface_count()):
			row.append(hash(part.mesh.surface_get_arrays(surface)))
			var material: Material = part.get_active_material(surface)
			row.append(material)
			if material is StandardMaterial3D: row.append([material.albedo_color,material.roughness,material.emission,material.emission_energy_multiplier,material.cull_mode])
		if part.skin != null:
			for index: int in range(part.skin.get_bind_count()): row.append([part.skin.get_bind_bone(index),part.skin.get_bind_pose(index)])
		result.append(row)
	return result

func _vertices(art: Node3D,all_vertices: bool = false) -> PackedVector3Array:
	var result := PackedVector3Array()
	for part: MeshInstance3D in _meshes(art):
		if not part.is_visible_in_tree(): continue
		var local: Transform3D = Roster._relative(part,art)
		var palette: Array[Transform3D] = []
		if part.skin != null:
			var skeleton: Skeleton3D = part.get_node(part.skeleton)
			for index: int in range(part.skin.get_bind_count()):
				palette.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(index))*part.skin.get_bind_pose(index))
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var stride: int = 1 if all_vertices else maxi(1,vertices.size()/64)
			for index: int in range(0,vertices.size(),stride):
				var point: Vector3 = vertices[index]
				if part.skin != null:
					var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
					var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
					point = Vector3.ZERO
					for slot: int in range(4):
						var at: int = index*4+slot
						point += (palette[bones[at]]*vertices[index])*weights[at]
				result.append(local*point)
	return result

func _same(first: Node3D,reference: Node3D,label: String,geometry: bool = true) -> void:
	_check(_rig_state(first) == _rig_state(reference),label+": exact working/applied poses and clocks")
	_check(_node_state(first) == _node_state(reference),label+": actual Skeleton, attachments, weighted markers and children")
	if geometry:
		var actual: PackedVector3Array = _vertices(first)
		var expected: PackedVector3Array = _vertices(reference)
		_check(not actual.is_empty() and actual == expected,label+": actual four-weight and rigid mesh vertex projections")

func _tick_pair(first: Node3D,reference: Node3D,delta: float,snapshot: Dictionary,detail: int,needed: bool,label: String,geometry: bool = true) -> void:
	var before: Dictionary = snapshot.duplicate(true)
	Animator.tick(first,delta,snapshot,detail,needed)
	Animator.tick(reference,delta,snapshot,detail,needed)
	_same(first,reference,label,geometry)
	_check(snapshot == before,label+": caller snapshot unchanged")

func _counters(art: Node3D) -> Vector2i:
	var rig: Dictionary = art.get_meta("roster_rig")
	var value := Vector2i(rig.pose_input_hits,rig.pose_input_solves)
	for child: Dictionary in rig.companions: value += _counters(child.node)
	return value

func _actor_case(first: Node3D,reference: Node3D,id: String) -> void:
	var rig: Dictionary = first.get_meta("roster_rig")
	var resources: Array = _resources(first)
	var origin: Transform3D = first.transform
	Animator.reset(first); Animator.reset(reference)
	for frame: int in range(4): _tick_pair(first,reference,0.016,{},0,true,id+" idle "+str(frame),frame == 3)
	for action: StringName in rig.definition.actions:
		for phase: float in [0.03,0.73]:
			_tick_pair(first,reference,0.016,{"action":action,"action_phase":phase,"action_serial":3,"contact":phase < 0.1},0,true,id+" "+String(action)+" "+str(phase),phase > 0.1)
	var states: Array[Dictionary] = [
		{"local_velocity":Vector3(0.6,0,1.2)},
		{"local_velocity":Vector3(-0.3,0,-1.1),"grounded":false,"turn_rate":1.2},
		{"hurt":0.7,"gaze":Vector2(0.000004,-0.1),"coat_count":0},
		{"dead":true,"death_phase":0.31},
		{"dead":true,"death_phase":1.0},
		{"dead":true,"death_phase":1.0},
		{"coat_count":2,"asleep":true},
		{"coat_count":3,"asleep":false}]
	for index: int in range(states.size()): _tick_pair(first,reference,0.021,states[index],0,true,id+" transition "+str(index))
	var ambient := {"action":rig.definition.get("action",&""),"ambient_action":true,"action_phase":0.14}
	for frame: int in range(7):
		ambient.action_phase = float(frame)*0.137
		_tick_pair(first,reference,0.016,ambient,2,frame == 0,id+" distant hidden "+str(frame),false)
	_tick_pair(first,reference,0.016,ambient,2,true,id+" immediate same-detail return")
	_tick_pair(first,reference,0.016,ambient,0,true,id+" near detail return")
	if id == "tony": _check(rig.hidden_pose_skips > 0 and not rig.pose_deferred,"actual hidden schedule and immediate visible return both execute")
	for delta: float in [0.0,-0.1,NAN,INF]: _tick_pair(first,reference,delta,{"dead":true},0,true,id+" invalid elapsed",false)
	var cached: Vector2i = _counters(first); var plain: Vector2i = _counters(reference)
	_check(cached.x+cached.y == plain.y and plain.x == 0,id+": memo replaces calculations only; identical authored call census")
	total_hits += cached.x; total_solves += cached.y; reference_solves += plain.y
	_set_memo(first,false)
	_tick_pair(first,reference,0.016,{},0,true,id+" disable warm memo")
	_set_memo(first,true)
	_tick_pair(first,reference,0.016,{},0,true,id+" reenable warm memo")
	Animator.reset(first); Animator.reset(reference)
	_same(first,reference,id+" reset")
	_check(_resources(first) == resources and first.transform == origin,id+": shared resources and authority origin unchanged")
	completed += 1

func _commit(art: Node3D) -> void:
	var rig: Dictionary = art.get_meta("roster_rig")
	Animator._apply_bones(rig,rig.poses)
	Roster._sync_attachments(rig)

func _author_pair(first: Node3D,reference: Node3D,bone: String,angles: Vector3,offset: Vector3 = Vector3.ZERO) -> void:
	Animator._pose(first.get_meta("roster_rig"),bone,angles,offset)
	Animator._pose(reference.get_meta("roster_rig"),bone,angles,offset)
	_commit(first); _commit(reference)

func _direct_cases(first: Node3D,reference: Node3D) -> void:
	Animator.reset(first); Animator.reset(reference)
	var rig: Dictionary = first.get_meta("roster_rig"); var other: Dictionary = reference.get_meta("roster_rig")
	var shoulder: int = rig.lookup.left_shoulder; var wrist: int = rig.lookup.left_wrist
	var angles := Vector3(0.17,-0.11,0.06); var offset := Vector3(0.003,-0.002,0.001)
	_author_pair(first,reference,"left_shoulder",angles,offset)
	var authored: Transform3D = rig.poses[shoulder]
	var original_global: Transform3D = Animator._global_pose(rig,wrist)
	Animator._global_pose(other,wrist)
	Animator._add(rig,"left_shoulder",Vector3(0.13,0.02,-0.04)); Animator._add(other,"left_shoulder",Vector3(0.13,0.02,-0.04))
	_check(Animator._global_pose(rig,wrist) != original_global,"overlay actually changes a populated descendant global")
	Animator._global_pose(other,wrist)
	var hits: int = rig.pose_input_hits
	_author_pair(first,reference,"left_shoulder",angles,offset)
	_check(rig.pose_input_hits == hits+1 and Animator._global_pose(rig,wrist) == original_global,"memo hit reinstalls authored target and invalidates overlaid descendant globals")
	_same(first,reference,"overlay restoration")
	var wrist_pose: Transform3D = Animator._global_pose(rig,wrist)
	var contact_target: Vector3 = wrist_pose.origin+Vector3(0.07,0.04,0.05)
	Animator._arm_contact(rig,"left",contact_target,wrist_pose.basis)
	Animator._arm_contact(other,"left",contact_target,wrist_pose.basis)
	_check(rig.poses[shoulder] != authored,"actual analytic contact IK replaces warmed shoulder target")
	hits = rig.pose_input_hits
	_author_pair(first,reference,"left_shoulder",angles,offset)
	_check(rig.pose_input_hits == hits+1 and rig.poses[shoulder] == authored,"memo hit restores shoulder after actual contact IK")
	_same(first,reference,"contact IK restoration")
	_author_pair(first,reference,"left_shoulder",Vector3(-0.2,0.3,-0.1),Vector3.ZERO)
	_author_pair(first,reference,"left_shoulder",angles,offset)
	_same(first,reference,"same bone receives A then B then A")
	Animator.reset(first); Animator.reset(reference)
	_author_pair(first,reference,"left_shoulder",angles,offset)
	_check(rig.pose_input_hits == 1 and rig.poses[shoulder] == authored,"warm memo target is reapplied over reset base pose")
	_same(first,reference,"warm reset restoration")
	# Actual vertices, not the unrelated gaze/_add path, witness four-microradian _pose changes.
	_author_pair(first,reference,"left_wrist",Vector3.ZERO)
	var neutral: PackedVector3Array = _vertices(first,true)
	for input: Dictionary in [{"angle":Vector3(0.000004,0,0),"offset":Vector3.ZERO},{"angle":Vector3.ZERO,"offset":Vector3(0.000004,0,0)}]:
		_author_pair(first,reference,"left_wrist",input.angle,input.offset)
		var changed: PackedVector3Array = _vertices(first,true)
		_check(changed != neutral and changed == _vertices(reference,true),"tiny authored angle/offset changes actual weighted geometry without quantization")
		_author_pair(first,reference,"left_wrist",Vector3.ZERO)
		_check(_vertices(first,true) == neutral,"tiny authored input returns exactly to original weighted geometry")
	var saved_base: Transform3D = rig.base_poses[wrist]
	var saved_rest: Transform3D = rig.rests[wrist]
	for change: int in range(2):
		var base: Transform3D = saved_base
		if change == 0: base.origin += Vector3(0.000004,0,0)
		else: base.basis *= Basis.from_euler(Vector3(0,0.000004,0))
		rig.base_poses[wrist] = base; other.base_poses[wrist] = base
		var solves: int = rig.pose_input_solves
		_author_pair(first,reference,"left_wrist",Vector3.ZERO)
		_check(rig.pose_input_solves == solves+1 and rig.rests[wrist] == saved_rest,"changed actual base origin/basis misses despite unchanged skeletal rest")
		_same(first,reference,"base pose key "+str(change))
	rig.base_poses[wrist] = saved_base; other.base_poses[wrist] = saved_base
	_author_pair(first,reference,"left_wrist",Vector3.ZERO)
	# Changing the separate rest metadata cannot replace the effective authored base key.
	rig.rests[wrist] = Transform3D(Basis.from_euler(Vector3(0.1,0,0)),saved_rest.origin)
	other.rests[wrist] = rig.rests[wrist]
	var skeleton: Skeleton3D = rig.skeleton; var reference_skeleton: Skeleton3D = other.skeleton
	var skeleton_rest: Transform3D = skeleton.get_bone_rest(wrist)
	skeleton.set_bone_rest(wrist,rig.rests[wrist]); reference_skeleton.set_bone_rest(wrist,other.rests[wrist])
	hits = rig.pose_input_hits
	_author_pair(first,reference,"left_wrist",Vector3.ZERO)
	_check(rig.pose_input_hits == hits+1,"unchanged effective base still reuses target when unused rest metadata differs")
	_same(first,reference,"separate rest metadata")
	rig.rests[wrist] = saved_rest; other.rests[wrist] = saved_rest
	skeleton.set_bone_rest(wrist,skeleton_rest); reference_skeleton.set_bone_rest(wrist,skeleton_rest)
	var writes: int = rig.bone_writes; var attachment_writes: int = rig.attachment_writes
	_author_pair(first,reference,"left_wrist",Vector3.ZERO)
	_check(rig.bone_writes == writes and rig.attachment_writes == attachment_writes,"identical targets preserve existing engine setter suppression")
	var independent: Node3D = Roster.create(&"tony",93); root.add_child(independent); Animator.reset(independent)
	var separate: Dictionary = independent.get_meta("roster_rig")
	Animator._pose(separate,"left_wrist",Vector3(0.4,0.1,-0.2)); _commit(independent)
	_check(rig.pose_input_memo[wrist] != separate.pose_input_memo[wrist] and rig.poses[wrist] != separate.poses[wrist],"cached original meshes never share per-instance pose memo or target state")
	independent.free()
	# Existing global-cache reference switch still includes this optimization.
	rig.pose_cache_enabled = false
	var solves: int = rig.pose_input_solves; hits = rig.pose_input_hits
	_author_pair(first,reference,"left_wrist",Vector3.ZERO)
	_check(rig.pose_input_solves == solves+1 and rig.pose_input_hits == hits,"existing uncached reference bypasses the new memo")
	rig.pose_cache_enabled = true
	_same(first,reference,"complete uncached reference")

func _run() -> void:
	for id: String in Roster.supported_visuals():
		var first: Node3D = Roster.create(StringName(id),71)
		var reference: Node3D = Roster.create(StringName(id),71)
		_check(first != null and reference != null,id+": both original rigs build")
		if first == null or reference == null:
			if first != null: first.free()
			if reference != null: reference.free()
			continue
		root.add_child(first); root.add_child(reference)
		_set_memo(reference,false)
		await process_frame
		_actor_case(first,reference,id)
		if id == "tony": _direct_cases(first,reference)
		first.free(); reference.free()
		await process_frame
	_check(completed == 72,"all 72 original visual templates finish without script abort")
	_check(total_hits > 0 and total_solves < reference_solves and total_hits+total_solves == reference_solves,"live authored poses avoid real target calculations without omitting any pose call")
	print("POSE INPUT MEMO WORK: %d reused / %d calculated / %d uncached calculations"%[total_hits,total_solves,reference_solves])
	if failures.is_empty():
		print("3D POSE INPUT MEMO GATE: PASS (%d checks; %d original templates)"%[checks,completed]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D POSE INPUT MEMO GATE: FAIL (%d/%d checks; %d/72 templates)"%[failures.size(),checks,completed]); quit(1)
