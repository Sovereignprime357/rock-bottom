extends RefCounted
## Sole presentation pose owner for roster models. No automatic processing,
## world/root movement, AI, hit events, resources, timers or input.

const Roster = preload("res://scripts/character_roster.gd")
const AMBIENT_ACTIONS: Array[StringName] = [&"",&"talk",&"eat",&"inspect",&"read",&"write",&"phone",&"strum",&"fold",&"serve",&"radio",&"seated",&"wave",&"salute",&"stamp",&"score",&"vote",&"sleep"]


static func reset(art: Node3D) -> void:
	if art == null or not art.has_meta("roster_rig"): return
	var rig: Dictionary = art.get_meta("roster_rig")
	_prepare_pose_input_memo(rig)
	rig.pose_input_hits = 0
	rig.pose_input_solves = 0
	rig.time = 0.0
	rig.phase = 0.0
	rig.motion = 0.0
	rig.frame = 0
	rig.detail = -1
	rig.last_state = []
	rig.pose_updates = 0
	rig.finger_updates = 0
	rig.bone_writes = 0
	rig.visibility_writes = 0
	for counter: String in ["global_pose_queries","global_pose_solves","attachment_queries","attachment_writes","hidden_pose_skips"]: rig[counter] = 0
	rig.pose_deferred = false
	_reset_working_pose(rig)
	_apply_bones(rig,rig.base_poses)
	for child: Dictionary in rig.companions: reset(child.node)
	_set_coats(rig,3)
	Roster._sync_attachments(rig)


static func tick(art: Node3D, delta: float, snapshot: Dictionary, detail: int = 0, pose_needed: bool = true) -> void:
	if art == null or not art.has_meta("roster_rig") or not is_finite(delta) or delta <= 0.0: return
	var rig: Dictionary = art.get_meta("roster_rig")
	_prepare_pose_input_memo(rig)
	var dt := minf(delta,0.10)
	var velocity := _vector3(snapshot.get("local_velocity",Vector3.ZERO))
	velocity.y = 0.0
	velocity = velocity.limit_length(30.0)
	var speed := velocity.length()
	var action := StringName(snapshot.get("action",&"")) if snapshot.get("action",&"") is String or snapshot.get("action",&"") is StringName else &""
	if action.is_empty() and rig.definition.visual_id == &"dave" and _boolean(snapshot.get("asleep",false),false): action = &"sleep"
	if action not in rig.definition.actions: action = &""
	# An ambient flag cannot downgrade authoritative combat, even if supplied
	# accidentally. This list only admits cosmetic identity gestures.
	var ambient := _boolean(snapshot.get("ambient_action",false),false) and action in AMBIENT_ACTIONS
	var phase := clampf(_number(snapshot.get("action_phase",0.0)),0.0,1.0)
	var hurt := clampf(_number(snapshot.get("hurt",0.0)),0.0,1.0)
	var dead := _boolean(snapshot.get("dead",false),false)
	var death := clampf(_number(snapshot.get("death_phase",1.0),1.0),0.0,1.0)
	var coats := clampi(int(_number(snapshot.get("coat_count",3),3.0)),0,3)
	var turn := clampf(_number(snapshot.get("turn_rate",0.0)),-6.0,6.0)
	var grounded := _boolean(snapshot.get("grounded",true),true)
	var contact := _boolean(snapshot.get("contact",false),false)
	var serial := int(_number(snapshot.get("action_serial",0)))
	var gaze := _vector2(snapshot.get("gaze",Vector2.ZERO))
	gaze = Vector2(clampf(gaze.x,-0.65,0.65),clampf(gaze.y,-0.35,0.35))
	var quality := clampi(detail,0,2)
	rig.time = fmod(float(rig.time)+dt,10000.0)
	rig.motion = lerpf(float(rig.motion),clampf(speed/1.6,0.0,1.25),1.0-exp(-12.0*dt))
	if speed > 0.01:
		var stride: float = rig.definition.stride
		rig.phase = fmod(float(rig.phase)+speed*dt*TAU/maxf(0.15,stride),TAU)
	rig.frame += 1
	var state := [action,serial,contact,dead,coats,grounded,hurt > 0.0,ambient]
	var changed: bool = state != rig.last_state or quality != rig.detail
	rig.last_state = state
	rig.detail = quality
	# Coats and action transitions never wait for the distant idle schedule.
	_set_coats(rig,coats)
	# Child rigs consume every current snapshot even when the distant parent
	# skips a cosmetic pose update. No AI or authority state lives in these rigs.
	for child: Dictionary in rig.companions:
		var child_snapshot: Dictionary = snapshot.duplicate()
		if not StringName(child.action).is_empty(): child_snapshot.action = child.action
		tick(child.node,dt,child_snapshot,quality,pose_needed)
	var may_skip: bool = not changed and (action.is_empty() or ambient) and not dead and hurt == 0.0
	if not pose_needed and may_skip:
		rig.pose_deferred = true
		rig.hidden_pose_skips += 1
		return
	var returning: bool = pose_needed and bool(rig.pose_deferred)
	if quality == 2 and not returning and may_skip and int(rig.frame)%3 != 0: return
	rig.pose_deferred = false
	_reset_working_pose(rig)
	var poses: Array[Transform3D] = rig.poses
	if bool(rig.definition.get("inert",false)) or rig.definition.family == "assembly":
		# Furniture and mannequins consume current snapshots but never inherit an
		# animal/human collapse. Child rigs above still own their individual poses.
		_apply_bones(rig,poses)
		Roster._sync_attachments(rig)
		rig.pose_updates += 1
		return
	var time: float = float(rig.time)+float(rig.seed)
	if rig.definition.family == "human":
		_human(rig,velocity,grounded,time,quality)
		_human_action(rig,action,phase,serial,contact,time,quality,ambient)
	elif rig.definition.family in ["quadruped","mounted"]:
		_quadruped(rig,velocity,grounded,time,quality)
		_animal_action(rig,action,phase)
	elif rig.definition.family == "bird": _bird(rig,action,phase,time,quality)
	elif rig.definition.family == "object": _object(rig,action,phase)
	_add(rig,"chest",Vector3(-0.09*hurt,0.08*hurt,clampf(-turn*0.025,-0.12,0.12)))
	_add(rig,"head",Vector3(gaze.y+0.05*hurt,gaze.x,0))
	if rig.definition.family == "human" and not dead: _human_contacts(rig,action,phase)
	if dead:
		# Only visual bones collapse. The caller retains collision placement and
		# essential/dead behavior. Supplied death phase never advances here.
		_reset_working_pose(rig)
		var fall := death*death*(3.0-2.0*death)
		if rig.definition.family == "human":
			_pose(rig,"root",Vector3(1.48*fall,0,-0.10*fall),Vector3(0,0.22*fall,0))
			_pose(rig,"left_elbow",Vector3(-0.40*fall,0,0))
			_pose(rig,"right_elbow",Vector3(-0.65*fall,0,0))
		elif rig.definition.family != "object":
			var lift: float = rig.definition.get("death_lift",float(rig.definition.height)*0.27)
			_pose(rig,"root",Vector3(0,0,1.48*fall),Vector3(0,lift*fall,0))
			_pose(rig,"jaw",Vector3(0.18*fall,0,0))
		# Long held tools lie beside their owner's body. A generic bent elbow
		# otherwise rotates the end of a cane/fork through the ground on collapse.
		for bone: String in rig.definition.get("death_pose",{}): _pose(rig,bone,rig.definition.death_pose[bone]*fall)
	_apply_bones(rig,poses)
	Roster._sync_attachments(rig)
	if dead:
		var release := clampf(death*death*(3.0-2.0*death)*1.35,0.0,1.0)
		for label: String in rig.definition.get("death_props",{}):
			var prop: Node3D = rig.prop_lookup[label].node
			prop.transform = prop.transform.interpolate_with(rig.definition.death_props[label],release)
	rig.pose_updates += 1


static func _apply_bones(rig: Dictionary, poses: Array[Transform3D]) -> void:
	var skeleton: Skeleton3D = rig.skeleton
	var applied: Array[Transform3D] = rig.applied_poses
	for i: int in range(poses.size()):
		# Exact target equality only. Quantization would lose small authored
		# movement and accumulate drift across distant/near transitions.
		if poses[i] == applied[i]: continue
		skeleton.set_bone_pose(i,poses[i])
		applied[i] = poses[i]
		rig.attachments_dirty = true
		rig.bone_writes += 1


static func _set_coats(rig: Dictionary, coats: int) -> void:
	if coats == int(rig.last_coats): return
	for layer: int in range(1,4):
		var visible := layer <= coats
		for mesh: MeshInstance3D in rig.layers[layer]:
			if mesh.visible == visible: continue
			mesh.visible = visible
			rig.visibility_writes += 1
	rig.last_coats = coats


static func _number(value: Variant, fallback: float = 0.0) -> float:
	if value is float or value is int:
		var number := float(value)
		if is_finite(number): return clampf(number,-1000000.0,1000000.0)
	return fallback


static func _boolean(value: Variant, fallback: bool) -> bool:
	return value if value is bool else fallback


static func _vector3(value: Variant) -> Vector3:
	if not value is Vector3: return Vector3.ZERO
	return Vector3(_number(value.x),_number(value.y),_number(value.z))


static func _vector2(value: Variant) -> Vector2:
	if not value is Vector2: return Vector2.ZERO
	return Vector2(_number(value.x),_number(value.y))


static func _prepare_pose_input_memo(rig: Dictionary) -> void:
	if rig.has("pose_input_memo") and rig.pose_input_memo.size() == rig.base_poses.size(): return
	var entries: Array[Array] = []
	for unused: int in range(rig.base_poses.size()):
		entries.append([Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,Transform3D.IDENTITY,false])
	rig.pose_input_memo = entries
	if not rig.has("pose_input_cache_enabled"): rig.pose_input_cache_enabled = true
	rig.pose_input_hits = 0
	rig.pose_input_solves = 0


static func _pose(rig: Dictionary, bone: String, angles: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	if not rig.lookup.has(bone): return
	var index: int = rig.lookup[bone]
	var rest: Transform3D = rig.base_poses[index]
	if rig.pose_cache_enabled and rig.pose_input_cache_enabled:
		var entry: Array = rig.pose_input_memo[index]
		if entry[4] and entry[0] == rest and entry[1] == angles and entry[2] == offset:
			rig.pose_input_hits += 1
			# The working pose may now contain an overlay or IK result. Even a
			# hit must reinstall its target and invalidate populated descendants.
			_set_local_pose(rig,index,entry[3])
			return
		var target := Transform3D(rest.basis*Basis.from_euler(angles),rest.origin+offset)
		entry[0] = rest; entry[1] = angles; entry[2] = offset; entry[3] = target; entry[4] = true
		_set_local_pose(rig,index,target)
	else:
		_set_local_pose(rig,index,Transform3D(rest.basis*Basis.from_euler(angles),rest.origin+offset))
	rig.pose_input_solves += 1


static func _add(rig: Dictionary, bone: String, angles: Vector3) -> void:
	if not rig.lookup.has(bone): return
	var index: int = rig.lookup[bone]
	var current: Transform3D = rig.poses[index]
	current.basis *= Basis.from_euler(angles)
	_set_local_pose(rig,index,current)


static func _reset_working_pose(rig: Dictionary) -> void:
	var poses: Array[Transform3D] = rig.poses
	for i: int in range(poses.size()): poses[i] = rig.base_poses[i]
	rig.global_valid.fill(0)
	rig.global_cached_count = 0


static func _set_local_pose(rig: Dictionary, index: int, value: Transform3D) -> void:
	if rig.poses[index] == value: return
	rig.poses[index] = value
	# Normal pose authoring precedes all queries. Avoid walking descendants
	# until contact IK has actually populated a working global cache.
	if int(rig.global_cached_count) == 0: return
	for descendant: int in rig.descendants[index]:
		if rig.global_valid[descendant] == 0: continue
		rig.global_valid[descendant] = 0
		rig.global_cached_count -= 1


static func _human(rig: Dictionary, velocity: Vector3, grounded: bool, time: float, quality: int) -> void:
	var motion: float = rig.motion
	var phase: float = rig.phase
	if rig.definition.visual_id == &"mounted_rider" or bool(rig.definition.get("seated",false)): motion = 0.0
	if bool(rig.definition.get("still",false)) and motion < 0.001: return
	var forward := -1.0 if velocity.z < -0.01 else 1.0
	var lateral := clampf(velocity.x/2.0,-1.0,1.0)
	var leg: float = rig.definition.leg
	var amplitude := asin(clampf(float(rig.definition.stride)/(4.0*leg),0.15,0.65))*minf(motion,1.0)
	var stance_angle := sin(phase)*amplitude
	var drop := -leg*(1.0-cos(stance_angle)) if grounded else 0.0
	_pose(rig,"pelvis",Vector3(0,0.025*sin(phase)*motion,0),Vector3(0,drop,0))
	_pose(rig,"spine",Vector3(0.006*sin(time*1.4),0,-0.02*sin(phase)*motion))
	_pose(rig,"chest",Vector3(0,-0.028*sin(phase)*motion,0))
	for side: String in ["left","right"]:
		var cycle := phase+(PI if side == "right" else 0.0)
		var step := sin(cycle)
		var hip := -step*amplitude*forward
		var knee := maxf(0.0,step)*0.72*minf(motion,1.0)
		if not grounded: knee += 0.20
		_pose(rig,side+"_hip",Vector3(hip,0,step*lateral*0.16*motion))
		_pose(rig,side+"_knee",Vector3(knee,0,0))
		_pose(rig,side+"_ankle",Vector3(-hip-knee,0,-step*lateral*0.16*motion))
		_pose(rig,side+"_shoulder",Vector3(step*0.25*motion*forward,0,0.012*sin(time*1.4)))
		_pose(rig,side+"_elbow",Vector3(-0.05*motion-0.07*maxf(0.0,-step)*motion,0,0))
	var id: StringName = rig.definition.visual_id
	if quality < 2:
		_pose(rig,"head",Vector3(0.008*sin(time*1.3),0.025*sin(time*0.43),0))
		if id == &"tony": _pose(rig,"head",Vector3(0,0.025*sin(time*0.33),0.006*sin(time*1.4)))
		elif id == &"lurch": _pose(rig,"head",Vector3(-0.025,0.035*sin(time*0.7),0.045))
		elif id == &"yuri": _pose(rig,"head",Vector3(0.025,0.035*sin(time*0.31),0))


static func _human_action(rig: Dictionary, action: StringName, phase: float, serial: int, contact: bool, time: float, quality: int, ambient: bool) -> void:
	var gesture := sin(phase*PI)
	var grip: float = 0.0
	var active_side := "right" if posmod(serial,2) == 0 else "left"
	match action:
		&"wave":
			_pose(rig,"right_shoulder",Vector3(-0.55,0,0.95))
			_pose(rig,"right_elbow",Vector3(-1.35,0,0))
			_pose(rig,"right_wrist",Vector3(0.12,0,0.22*sin(phase*TAU*2.0)))
			_pose(rig,"head",Vector3(0,0.06*sin(phase*PI),0))
		&"salute":
			_pose(rig,"right_shoulder",Vector3(-1.22,0,0.32))
			_pose(rig,"right_elbow",Vector3(-0.95,0,0))
			grip = 0.10
		&"score":
			_pose(rig,"right_shoulder",Vector3(-0.64-0.10*gesture,0,0.18))
			_pose(rig,"right_elbow",Vector3(-1.14-0.12*gesture,0,0))
			_pose(rig,"right_wrist",Vector3(-0.10,0.08,0))
			grip = 0.22
		&"stamp": grip = 0.35
		&"radio":
			_pose(rig,"left_shoulder",Vector3(-0.75,0,-0.08))
			_pose(rig,"left_elbow",Vector3(-1.20,0,0))
			_pose(rig,"left_wrist",Vector3(-0.10,0.15,0))
			_pose(rig,"head",Vector3(0.02,-0.13,0.025))
			grip = 0.34
		&"taser":
			_pose(rig,"right_shoulder",Vector3(-1.18,0,-0.05))
			_pose(rig,"right_elbow",Vector3(-0.22,0,0))
			_pose(rig,"right_wrist",Vector3(-0.12,0,0))
			_pose(rig,"head",Vector3(-0.015,0.05,0))
			grip = 0.42
		&"sleep":
			# Dave's source state is a horizontal sleeper, not a blinking idle.
			_pose(rig,"root",Vector3(0,0,1.48),Vector3(0,0.27,0))
			_pose(rig,"left_shoulder",Vector3(-0.54,0,0))
			_pose(rig,"left_elbow",Vector3(-1.0,0,0))
			_pose(rig,"right_elbow",Vector3(-0.24,0,0))
		&"read",&"write",&"fold",&"serve":
			_pose(rig,"left_shoulder",Vector3(-0.42,0,-0.14))
			_pose(rig,"left_elbow",Vector3(-0.90,0,0))
			_pose(rig,"left_wrist",Vector3(-0.12,0,0))
			_pose(rig,"head",Vector3(0.18,-0.06,0))
			var writing: float = sin(phase*TAU*3.0)*0.09 if action == &"write" else gesture*0.14
			_pose(rig,"right_shoulder",Vector3(-0.30-writing,0,0.16))
			_pose(rig,"right_elbow",Vector3(-0.96+writing,0,0))
			grip = 0.30
		&"phone":
			_pose(rig,"right_shoulder",Vector3(-0.18,0,0))
			_pose(rig,"right_elbow",Vector3(-0.18,0,0))
			_pose(rig,"right_wrist",Vector3(0,-0.18,0))
			_pose(rig,"head",Vector3(0.04,0.10,0.015))
			grip = 0.34
		&"strum":
			_pose(rig,"left_shoulder",Vector3(-0.28,0,-0.13))
			_pose(rig,"left_elbow",Vector3(-0.80,0,0))
			_pose(rig,"right_shoulder",Vector3(-0.42,0,0.30))
			_pose(rig,"right_elbow",Vector3(-0.72+0.12*sin(phase*TAU*3.0),0,0))
			grip = 0.28
		&"seated":
			if rig.definition.visual_id != &"mounted_rider":
				for side: String in ["left","right"]:
					_pose(rig,side+"_hip",Vector3(-1.2,0,0))
					_pose(rig,side+"_knee",Vector3(1.4,0,0))
			_pose(rig,"head",Vector3(0.045*gesture,0,0))
		&"windup":
			_pose(rig,active_side+"_shoulder",Vector3(-0.60*phase,0.12,-0.08))
			_pose(rig,active_side+"_elbow",Vector3(-1.10*phase,0,0))
			_add(rig,"chest",Vector3(0,-0.12*phase,0))
			grip = phase
		&"strike":
			# Immediate contact stays readable briefly before recovery. Target an
			# anatomical extension, including actors whose authored rest holds food.
			var recovery := clampf((phase-0.18)/0.82,0.0,1.0)
			var reach := 1.0-recovery*recovery*(3.0-2.0*recovery)
			var extension := reach*(0.90 if contact else 1.0)
			var shoulder_rest: Transform3D = rig.base_poses[rig.lookup[active_side+"_shoulder"]]
			var elbow_rest: Transform3D = rig.base_poses[rig.lookup[active_side+"_elbow"]]
			_pose(rig,active_side+"_shoulder",Vector3((-1.65-shoulder_rest.basis.get_euler().x)*extension,0,0))
			_pose(rig,active_side+"_elbow",Vector3((-0.08-elbow_rest.basis.get_euler().x)*extension,0,0))
			_pose(rig,active_side+"_wrist",Vector3(0.08*extension,0.90*extension if active_side == "right" else -0.90*extension,0))
			_add(rig,"chest",Vector3(0.06*extension,0.10*extension,0))
			grip = reach
		&"grab":
			for side: String in ["left","right"]:
				_pose(rig,side+"_shoulder",Vector3(-1.18,0,0.12 if side == "left" else -0.12))
				_pose(rig,side+"_elbow",Vector3(-0.20,0,0))
			grip = 0.35+0.30*phase
		&"throw":
			_pose(rig,active_side+"_shoulder",Vector3(-2.30+1.80*phase,0,0.15))
			_pose(rig,active_side+"_elbow",Vector3(-1.00*(1.0-phase),0,0))
			grip = 1.0-phase
		&"inspect":
			_pose(rig,"left_shoulder",Vector3(-0.48*gesture,0,-0.05))
			_pose(rig,"left_elbow",Vector3(-0.95*gesture,0,0))
			_add(rig,"head",Vector3(0.16*gesture,-0.08*gesture,0))
			grip = 0.35
		&"talk":
			_add(rig,"head",Vector3(0.035*sin(phase*TAU*2),0,0))
			_pose(rig,"left_elbow",Vector3(-0.25*gesture,0,0))
			if rig.definition.visual_id == &"larry":
				for side: String in ["left","right"]:
					_pose(rig,side+"_shoulder",Vector3(-0.45,0,-0.95 if side == "left" else 0.95))
					_pose(rig,side+"_elbow",Vector3(-0.50,0,0))
	var bite: float = 0.0
	if action == &"eat": bite = gesture
	elif action.is_empty() and rig.definition.visual_id == &"pete" and float(rig.motion) < 0.08 and quality < 2:
		bite = pow(maxf(0.0,sin(time*0.57)),6.0)
	if bite > 0.0:
		_pose(rig,"right_shoulder",Vector3(-0.35*bite,0,-0.10*bite))
		_pose(rig,"right_elbow",Vector3(-0.68*bite,0,0))
		_pose(rig,"right_wrist",Vector3(-0.10*bite,0,0))
		_add(rig,"head",Vector3(0.10*bite,0,0))
		grip = 0.40
	if rig.definition.visual_id == &"busker" and action in [&"",&"strum",&"talk"]: grip = 0.15
	elif rig.definition.visual_id == &"launderlady" and action in [&"",&"fold",&"read",&"serve",&"talk"]: grip = 0.25
	elif rig.definition.visual_id == &"math" and action in [&"",&"read",&"write",&"inspect"]: grip = 0.20
	elif bool(rig.definition.get("site_resident",false)) and action not in [&"wave",&"salute"]: grip = 0.24
	if quality == 0 or not action.is_empty() and not ambient:
		for side: String in ["left","right"]:
			_pose(rig,side+"_fingers",Vector3(-1.20*grip,0,0))
			_pose(rig,side+"_fingertips",Vector3(-1.45*grip,0,0))
			_pose(rig,side+"_thumb",Vector3(-0.55*grip,0,-0.55*grip if side == "left" else 0.55*grip))
			_pose(rig,side+"_thumbtip",Vector3(-0.95*grip,0,0))
		rig.finger_updates += 1


static func _global_pose(rig: Dictionary, index: int) -> Transform3D:
	rig.global_pose_queries += 1
	if rig.pose_cache_enabled and rig.global_valid[index] != 0: return rig.global_poses[index]
	# Preserve the original multiplication association, including during IK.
	var result: Transform3D = rig.poses[index]
	var parent: int = rig.parents[index]
	while parent >= 0:
		result = (rig.poses[parent] as Transform3D)*result
		parent = rig.parents[parent]
	rig.global_poses[index] = result
	if rig.global_valid[index] == 0: rig.global_cached_count += 1
	rig.global_valid[index] = 1
	rig.global_pose_solves += 1
	return result


static func _prop_pose(rig: Dictionary, label: String) -> Transform3D:
	var binding: Dictionary = rig.prop_lookup[label]
	return _global_pose(rig,binding.bone)*(binding.offset as Transform3D)


static func _arm_contact(rig: Dictionary, side: String, target: Vector3, wrist_basis: Basis) -> void:
	# Analytic cosmetic reach. The actor root, segment lengths and authority
	# snapshot stay fixed; only shoulder/elbow/wrist bases are replaced.
	var shoulder: int = rig.lookup[side+"_shoulder"]
	var elbow: int = rig.lookup[side+"_elbow"]
	var wrist: int = rig.lookup[side+"_wrist"]
	var s := _global_pose(rig,shoulder)
	var e := _global_pose(rig,elbow)
	var w := _global_pose(rig,wrist)
	var upper := s.origin.distance_to(e.origin)
	var lower := e.origin.distance_to(w.origin)
	var toward := target-s.origin
	if toward.length_squared() < 0.000001 or upper < 0.001 or lower < 0.001: return
	var direction := toward.normalized()
	var distance := clampf(toward.length(),absf(upper-lower)+0.001,upper+lower-0.002)
	var pole := Vector3(-1.0 if side == "left" else 1.0,-0.6,-0.2)
	pole = (pole-direction*pole.dot(direction)).normalized()
	if pole.length_squared() < 0.5: pole = direction.cross(Vector3.UP).normalized()
	var along := (upper*upper+distance*distance-lower*lower)/(2.0*distance)
	var bend := sqrt(maxf(0.0,upper*upper-along*along))
	var aim := direction*along+pole*bend
	var rotated := Basis(Quaternion((e.origin-s.origin).normalized(),aim.normalized()))*s.basis
	var local: Transform3D = rig.poses[shoulder]
	local.basis = _global_pose(rig,rig.parents[shoulder]).basis.inverse()*rotated
	_set_local_pose(rig,shoulder,local)
	e = _global_pose(rig,elbow)
	w = _global_pose(rig,wrist)
	var endpoint := s.origin+direction*distance
	rotated = Basis(Quaternion((w.origin-e.origin).normalized(),(endpoint-e.origin).normalized()))*e.basis
	local = rig.poses[elbow]
	local.basis = _global_pose(rig,rig.parents[elbow]).basis.inverse()*rotated
	_set_local_pose(rig,elbow,local)
	local = rig.poses[wrist]
	local.basis = _global_pose(rig,rig.parents[wrist]).basis.inverse()*wrist_basis
	_set_local_pose(rig,wrist,local)


static func _human_contacts(rig: Dictionary, action: StringName, phase: float) -> void:
	var id: StringName = rig.definition.visual_id
	if id == &"busker" and action in [&"",&"strum",&"talk"]:
		var guitar := _prop_pose(rig,"guitar")
		var stroke := 0.04*sin(phase*TAU*3.0) if action == &"strum" else 0.0
		_arm_contact(rig,"left",guitar*Vector3(0,0.50,0.02),guitar.basis)
		_arm_contact(rig,"right",guitar*Vector3(stroke,0.11,0.062),guitar.basis)
	elif id == &"launderlady" and action in [&"",&"fold",&"read",&"serve",&"talk"]:
		var basket := _prop_pose(rig,"laundry_basket")
		for side: String in ["left","right"]:
			var sign_value := -1.0 if side == "left" else 1.0
			_arm_contact(rig,side,basket*Vector3(sign_value*0.32,0.16,0),basket.basis*Basis(Vector3.UP,-sign_value*PI*0.5))
	elif id == &"math" and action in [&"",&"read",&"write",&"inspect"]:
		var board := _prop_pose(rig,"equation_board")
		var stroke := 0.045*sin(phase*TAU*3.0) if action == &"write" else 0.0
		var target := board*Vector3(0.02+stroke,0.01,0.018)
		var basis := board.basis*Basis(Vector3.RIGHT,PI*0.5)
		var pencil: Dictionary = rig.prop_lookup.pencil
		var tip_in_wrist: Vector3 = (pencil.offset as Transform3D)*Vector3(0,0.09,0)
		_arm_contact(rig,"right",target-basis*tip_in_wrist,basis)
		_arm_contact(rig,"left",board*Vector3(-0.13,0.10,0.035),board.basis)
	elif id == &"dennis" and action in [&"",&"inspect",&"read",&"talk",&"serve"]:
		var thermos := _prop_pose(rig,"empty_thermos")
		for side: String in ["left","right"]:
			var sign_value := -1.0 if side == "left" else 1.0
			_arm_contact(rig,side,thermos*Vector3(sign_value*0.10,0.075,0),thermos.basis*Basis(Vector3.UP,-sign_value*PI*0.5))
	elif id == &"transit_dan" and action in [&"",&"read",&"write",&"inspect"]:
		var paper := _prop_pose(rig,"transfer_slips")
		var stroke := 0.04*sin(phase*TAU*3.0) if action == &"write" else 0.0
		var basis := paper.basis*Basis(Vector3.RIGHT,PI*0.5)
		var tip: Vector3 = (rig.prop_lookup.pencil.offset as Transform3D)*Vector3(0,0.09,0)
		_arm_contact(rig,"right",paper*Vector3(stroke,0.01,0.018)-basis*tip,basis)
		_arm_contact(rig,"left",paper*Vector3(-0.12,0.10,0.04),paper.basis)
	elif id == &"former_teller" and action in [&"",&"read",&"stamp",&"inspect",&"talk"]:
		var paper := _prop_pose(rig,"bank_papers")
		var lift := 0.07*(0.5+0.5*cos(phase*TAU)) if action == &"stamp" else 0.055
		var basis := paper.basis*Basis(Vector3.RIGHT,PI*0.5)
		var contact: Vector3 = (rig.prop_lookup.rubber_stamp.offset as Transform3D)*Vector3(0,-0.1125,0)
		_arm_contact(rig,"right",paper*Vector3(0.025,0.01,0.018+lift)-basis*contact,basis)
	elif id == &"docent" and action in [&"",&"read",&"inspect",&"talk",&"wave"]:
		var brochure := _prop_pose(rig,"brochure")
		_arm_contact(rig,"left",brochure*Vector3(-0.12,0.10,0.035),brochure.basis)
	elif id == &"lifeguard_seated" and action == &"score":
		var chest := _global_pose(rig,rig.lookup.chest)
		_arm_contact(rig,"right",chest*Vector3(0.34,0.20+0.10*sin(phase*PI),0.30),chest.basis)


static func _quadruped(rig: Dictionary, velocity: Vector3, grounded: bool, time: float, quality: int) -> void:
	var motion: float = rig.motion
	var forward := -1.0 if velocity.z < -0.01 else 1.0
	for limb: String in ["front_left","front_right","back_left","back_right"]:
		var diagonal: bool = limb in ["front_right","back_left"]
		var step := sin(float(rig.phase)+(PI if diagonal else 0.0))
		var hip := -step*0.38*motion*forward
		var knee := maxf(0.0,step)*0.55*motion+(0.12 if not grounded else 0.0)
		_pose(rig,limb,Vector3(hip,0,0))
		_pose(rig,limb+"_knee",Vector3(knee,0,0))
		_pose(rig,limb+"_ankle",Vector3(-hip-knee,0,0))
	_pose(rig,"spine",Vector3(0.015*sin(time*1.5),0.018*sin(float(rig.phase))*motion,0))
	if quality < 2:
		_pose(rig,"head",Vector3(0.018*sin(time*1.4),0.035*sin(time*0.7),0))
		_pose(rig,"jaw",Vector3(0.025+0.02*sin(time*1.4),0,0))
		_pose(rig,"tail",Vector3(0,0.07*sin(time*1.4),0))
		_pose(rig,"tail_mid",Vector3(0,0.07*sin(time*1.4-0.5),0))
		_pose(rig,"tail_tip",Vector3(0,0.06*sin(time*1.4-1.0),0))


static func _animal_action(rig: Dictionary, action: StringName, phase: float) -> void:
	match action:
		&"vote":
			var gesture := sin(phase*PI)
			_pose(rig,"front_left",Vector3(-0.65*gesture,0,-0.12*gesture))
			_pose(rig,"front_left_knee",Vector3(0.55*gesture,0,0))
			_pose(rig,"head",Vector3(0.11*sin(phase*TAU),0.08*sin(phase*PI),0))
		&"inspect": _add(rig,"head",Vector3(0.15*sin(phase*PI),0,0))
		&"windup":
			_add(rig,"chest",Vector3(-0.10*phase,0,0))
			_add(rig,"head",Vector3(0.12*phase,0,0))
			_pose(rig,"jaw",Vector3(0.22*phase,0,0))
		&"lunge":
			_add(rig,"chest",Vector3(0.14,0,0))
			_add(rig,"head",Vector3(-0.12,0,0))
			_pose(rig,"jaw",Vector3(0.30*(1.0-phase),0,0))
		&"bite":
			_pose(rig,"jaw",Vector3(0.34*sin(phase*PI),0,0))
			_add(rig,"head",Vector3(0.10*sin(phase*PI),0,0))
		&"talk": _add(rig,"head",Vector3(0.08*sin(phase*TAU),0,0))


static func _bird(rig: Dictionary, action: StringName, phase: float, time: float, quality: int) -> void:
	var motion: float = minf(rig.motion,1.0)
	var step: float = sin(rig.phase)
	_pose(rig,"pelvis",Vector3(0,0,0.025*step*motion),Vector3(0,absf(step)*0.035*motion,0))
	if bool(rig.definition.get("two_feet",false)):
		for side: String in ["left","right"]:
			var cycle := step if side == "left" else -step
			_pose(rig,"bird_"+side,Vector3(-cycle*0.30*motion,0,0))
			_pose(rig,"bird_"+side+"_knee",Vector3(maxf(cycle,0)*0.40*motion,0,0))
			_pose(rig,"bird_"+side+"_ankle",Vector3(cycle*0.20*motion,0,0))
	else:
		_pose(rig,"single_leg",Vector3(-step*0.30*motion,0,0))
		_pose(rig,"single_knee",Vector3(maxf(step,0)*0.40*motion,0,0))
		_pose(rig,"single_ankle",Vector3(step*0.20*motion,0,0))
	_pose(rig,"neck",Vector3(step*0.09*motion,0,0))
	if quality < 2:
		_pose(rig,"head",Vector3(0,0.04*sin(time*0.73),0))
		_pose(rig,"tail",Vector3(0,0.04*step*motion,0))
	var peck := sin(phase*PI)
	if action in [&"eat",&"bite",&"inspect"]:
		_pose(rig,"neck",Vector3(0.42*peck,0,0))
		_pose(rig,"head",Vector3(0.30*peck,0,0))
	elif action in [&"talk",&"windup",&"wave"]:
		for side: String in ["left","right"]: _pose(rig,side+"_wing",Vector3(0,0,(-0.35 if side == "left" else 0.35)*peck))
		_pose(rig,"head",Vector3(0.06*sin(phase*TAU*2),0,0))


static func _object(rig: Dictionary, action: StringName, phase: float) -> void:
	if action == &"talk": _pose(rig,"mouth",Vector3(0,0,0),Vector3(0,0.004*absf(sin(phase*TAU*2)),0))
