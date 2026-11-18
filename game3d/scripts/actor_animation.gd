class_name RockBottomActorAnimation
extends RefCounted
## Sole presentation pose owner for roster models. No automatic processing,
## world/root movement, AI, hit events, resources, timers or input.

const Roster = preload("res://scripts/character_roster.gd")


static func reset(art: Node3D) -> void:
	if art == null or not art.has_meta("roster_rig"): return
	var rig: Dictionary = art.get_meta("roster_rig")
	rig.time = 0.0
	rig.phase = 0.0
	rig.motion = 0.0
	rig.frame = 0
	rig.detail = -1
	rig.last_state = []
	rig.pose_updates = 0
	rig.finger_updates = 0
	(rig.skeleton as Skeleton3D).reset_bone_poses()
	for layer: Array in rig.layers:
		for mesh: MeshInstance3D in layer: mesh.visible = true
	Roster._sync_attachments(rig)


static func tick(art: Node3D, delta: float, snapshot: Dictionary, detail: int = 0) -> void:
	if art == null or not art.has_meta("roster_rig") or not is_finite(delta) or delta <= 0.0: return
	var rig: Dictionary = art.get_meta("roster_rig")
	var dt := minf(delta,0.10)
	var velocity := _vector3(snapshot.get("local_velocity",Vector3.ZERO))
	velocity.y = 0.0
	velocity = velocity.limit_length(30.0)
	var speed := velocity.length()
	var action := StringName(snapshot.get("action",&"")) if snapshot.get("action",&"") is String or snapshot.get("action",&"") is StringName else &""
	if action not in rig.definition.actions: action = &""
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
	var state := [action,serial,contact,dead,coats,grounded,hurt > 0.0]
	var changed: bool = state != rig.last_state or quality != rig.detail
	rig.last_state = state
	rig.detail = quality
	# Coats and action transitions never wait for the distant idle schedule.
	for layer: int in range(1,4):
		for mesh: MeshInstance3D in rig.layers[layer]: mesh.visible = layer <= coats
	if quality == 2 and not changed and action.is_empty() and not dead and hurt == 0.0 and int(rig.frame)%3 != 0: return
	if not rig.has("poses"): rig["poses"] = (rig.rests as Array[Transform3D]).duplicate()
	var poses: Array[Transform3D] = rig.poses
	for i: int in range(poses.size()): poses[i] = rig.rests[i]
	var time: float = float(rig.time)+float(rig.seed)
	if rig.definition.family == "human":
		_human(rig,velocity,grounded,time,quality)
		_human_action(rig,action,phase,serial,contact,time,quality)
	else:
		_quadruped(rig,velocity,grounded,time,quality)
		_animal_action(rig,action,phase)
	_add(rig,"chest",Vector3(-0.09*hurt,0.08*hurt,clampf(-turn*0.025,-0.12,0.12)))
	_add(rig,"head",Vector3(gaze.y+0.05*hurt,gaze.x,0))
	if dead:
		# Only visual bones collapse. The caller retains collision placement and
		# essential/dead behavior. Supplied death phase never advances here.
		for i: int in range(poses.size()): poses[i] = rig.rests[i]
		var fall := death*death*(3.0-2.0*death)
		if rig.definition.family == "human":
			_pose(rig,"root",Vector3(1.48*fall,0,-0.10*fall),Vector3(0,0.22*fall,0))
			_pose(rig,"left_elbow",Vector3(-0.40*fall,0,0))
			_pose(rig,"right_elbow",Vector3(-0.65*fall,0,0))
		else:
			_pose(rig,"root",Vector3(0,0,1.48*fall),Vector3(0,float(rig.definition.height)*0.27*fall,0))
			_pose(rig,"jaw",Vector3(0.18*fall,0,0))
	var skeleton: Skeleton3D = rig.skeleton
	for i: int in range(poses.size()): skeleton.set_bone_pose(i,poses[i])
	Roster._sync_attachments(rig)
	rig.pose_updates += 1


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


static func _pose(rig: Dictionary, bone: String, angles: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	if not rig.lookup.has(bone): return
	var index: int = rig.lookup[bone]
	var rest: Transform3D = rig.rests[index]
	rig.poses[index] = Transform3D(rest.basis*Basis.from_euler(angles),rest.origin+offset)


static func _add(rig: Dictionary, bone: String, angles: Vector3) -> void:
	if not rig.lookup.has(bone): return
	var index: int = rig.lookup[bone]
	var current: Transform3D = rig.poses[index]
	current.basis *= Basis.from_euler(angles)
	rig.poses[index] = current


static func _human(rig: Dictionary, velocity: Vector3, grounded: bool, time: float, quality: int) -> void:
	var motion: float = rig.motion
	var phase: float = rig.phase
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


static func _human_action(rig: Dictionary, action: StringName, phase: float, serial: int, contact: bool, time: float, quality: int) -> void:
	var gesture := sin(phase*PI)
	var grip: float = 0.0
	var active_side := "right" if posmod(serial,2) == 0 else "left"
	match action:
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
			var shoulder_rest: Transform3D = rig.rests[rig.lookup[active_side+"_shoulder"]]
			var elbow_rest: Transform3D = rig.rests[rig.lookup[active_side+"_elbow"]]
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
	if quality == 0 or not action.is_empty():
		for side: String in ["left","right"]:
			_pose(rig,side+"_fingers",Vector3(-1.20*grip,0,0))
			_pose(rig,side+"_fingertips",Vector3(-1.45*grip,0,0))
			_pose(rig,side+"_thumb",Vector3(-0.55*grip,0,-0.55*grip if side == "left" else 0.55*grip))
			_pose(rig,side+"_thumbtip",Vector3(-0.95*grip,0,0))
		rig.finger_updates += 1


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
