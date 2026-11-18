class_name SliceFirstPersonRig
extends Node3D
## Presentation only. The owner calls tick in active play and acknowledges resolved actions.
## Camera-local metres, camera forward -Z. No input, physics, gameplay timers or callbacks.

const Surfaces = preload("res://scripts/surface_kit.gd")
const SKIN := "bd9b69"
const MOLD := "4a5028"
const ACTION_LENGTHS := {&"punch":0.24, &"interact":0.24, &"pickup":0.32,
	&"receipt":0.32, &"eat":0.50, &"smoke":0.55, &"equip":0.26,
	&"phone":0.44, &"bench":0.30, &"dumpster":0.36, &"kick":0.28}
const WEAPONS := {&"fists":{"duration":0.24,"family":"arc","grip":0.0},
	&"pipe":{"duration":0.28,"family":"pipe","grip":0.82},
	&"brick":{"duration":0.32,"family":"thud","grip":0.62},
	&"cart_wheel":{"duration":0.22,"family":"spin","grip":0.83},
	&"shoe":{"duration":0.29,"family":"sole","grip":0.70},
	&"baguette":{"duration":0.20,"family":"crumble","grip":0.72},
	&"microphone":{"duration":0.30,"family":"whip","grip":0.88},
	&"knife":{"duration":0.22,"family":"stab","grip":0.86},
	&"broken_bottle":{"duration":0.25,"family":"jagged","grip":0.82}}
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

# Read-only presentation observations for capture tools; never use these to gate gameplay.
var action: StringName = &""
var action_phase: float = 0.0
var last_punch_side: int = 0
var _next_punch_side: int = 1
var _contact: bool = false
var _action_age: float = 0.0
var _time: float = 0.0
var _travel_phase: float = 0.0
var _motion: float = 0.0
var _sprint: float = 0.0
var _strafe: float = 0.0
var _look: Vector2 = Vector2.ZERO
var _shake: float = 0.0
var _high: bool = false
var _crash: bool = false
var _arms: Dictionary = {}
var _props: Dictionary = {}
var weapon: StringName = &"fists"
var attack_weapon: StringName = &""
var _walk_speed: float = 3.6
var _seated: bool = false
var _context_visible: bool = true
var _action_duration: float = 0.24
var _weapon_nodes: Dictionary = {}
var _weapon_pool: Node3D
var _weapon_socket: Node3D
var _selected_weapon: StringName = &""
var _cord: Array[Node3D] = []
var _wheel: Node3D
var _kick_base := Vector3(0.22,-0.88,-0.54)

static func supported_weapons() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in WEAPONS: result.append(id)
	return result

func set_context(snapshot: Dictionary) -> bool:
	var next: Variant = snapshot.get("weapon",weapon)
	if not (next is String or next is StringName) or not WEAPONS.has(StringName(next)): return false
	var seated: Variant = snapshot.get("seated",_seated)
	var shown: Variant = snapshot.get("visible",_context_visible)
	var speed: Variant = snapshot.get("walk_speed",_walk_speed)
	if not seated is bool or not shown is bool or not (speed is int or speed is float) or not is_finite(float(speed)) or speed < 1.0 or speed > 10.0: return false
	weapon = StringName(next); _seated = seated; _context_visible = shown; _walk_speed = float(speed)
	_apply_pose()
	return true


static func create() -> Node3D:
	var rig := SliceFirstPersonRig.new()
	rig.name = "FirstPersonRig"
	rig.set_meta("rig_kind", "first_person")
	rig._build()
	rig.reset()
	return rig


func reset() -> void:
	action = &""
	action_phase = 0.0
	last_punch_side = 0
	_next_punch_side = 1
	_contact = false
	_action_age = 0.0
	_time = 0.0
	_travel_phase = 0.0
	_motion = 0.0
	_sprint = 0.0
	_strafe = 0.0
	_look = Vector2.ZERO
	_shake = 0.0
	_high = false
	_crash = false
	weapon = &"fists"; attack_weapon = &""; _walk_speed = 3.6
	_seated = false; _context_visible = true; _action_duration = 0.24
	_apply_pose()


func acknowledge(kind: StringName, success: bool = true, contact: bool = false, used_weapon: StringName = &"") -> void:
	if not success or not ACTION_LENGTHS.has(kind): return
	if kind == &"punch" and not used_weapon.is_empty() and not WEAPONS.has(used_weapon): return
	# No backlog of receipts and no cosmetic gesture can interrupt an accepted punch.
	if action == &"punch" and kind != &"punch": return
	action = kind
	_action_age = 0.0
	action_phase = 0.0
	_contact = contact
	_action_duration = float(ACTION_LENGTHS[kind])
	if kind == &"punch":
		attack_weapon = weapon if used_weapon.is_empty() else used_weapon
		_action_duration = float(WEAPONS[attack_weapon].duration)
		last_punch_side = _next_punch_side if attack_weapon == &"fists" else 1
		if attack_weapon == &"fists": _next_punch_side *= -1
	_apply_pose()


func tick(delta: float, local_velocity: Vector3, sprinting: bool, high: bool = false,
		crash: bool = false, shakes: float = 0.0, look_delta: Vector2 = Vector2.ZERO) -> void:
	# Invalid/negative time is a no-op. Cap a stalled frame instead of jumping a hand
	# through the eye plane; the owner's simulation remains the sole time authority.
	if not is_finite(delta) or delta <= 0.0: return
	var dt := minf(delta,0.10)
	var velocity := Vector2(_safe(local_velocity.x),_safe(local_velocity.z)).limit_length(maxf(12.0,_walk_speed*3.2))
	var speed := velocity.length()
	var blend := 1.0-exp(-14.0*dt)
	_time += dt
	_high = high
	_crash = crash
	_shake = clampf(_safe(shakes),0.0,100.0)/100.0
	_motion = lerpf(_motion,clampf(speed/_walk_speed,0.0,1.5),blend)
	_sprint = lerpf(_sprint,1.0 if sprinting and speed > 0.10 else 0.0,blend)
	_strafe = lerpf(_strafe,clampf(velocity.x/_walk_speed,-1.0,1.0),blend)
	var look_rate := Vector2(clampf(_safe(look_delta.x),-0.30,0.30),clampf(_safe(look_delta.y),-0.30,0.30))/maxf(dt,0.001)
	look_rate = look_rate.limit_length(5.0)
	_look = _look.lerp(look_rate,1.0-exp(-18.0*dt))
	if speed > 0.025:
		_travel_phase = fmod(_travel_phase+speed*dt*TAU/lerpf(3.1,3.6,_sprint),TAU)
	if not action.is_empty():
		_action_age += dt
		action_phase = clampf(_action_age/_action_duration,0.0,1.0)
		if action_phase >= 1.0:
			action = &""
			action_phase = 0.0
			_action_age = 0.0
			attack_weapon = &""
	_apply_pose()


static func _safe(value: float) -> float:
	return value if is_finite(value) else 0.0


static func _ease(value: float) -> float:
	var x := clampf(value,0.0,1.0)
	return x*x*(3.0-2.0*x)


func _apply_pose() -> void:
	visible = _context_visible
	var held: StringName = attack_weapon if action == &"punch" else weapon
	var stowed: bool = action in [&"interact",&"pickup",&"receipt",&"eat",&"smoke",&"equip",&"phone",&"bench",&"dumpster",&"kick"]
	_select_weapon(&"fists" if stowed else held)
	var gesture := sin(action_phase*PI)
	var strike := 0.0
	if action == &"punch":
		# The accepted hit is already resolved. Begin visibly extended on that same
		# acknowledgement; reach the contact pose quickly, then spend time recovering.
		if _action_age < 0.035: strike = lerpf(0.32,1.0,_ease(_action_age/0.035))
		elif _action_age < 0.055: strike = 1.0
		else: strike = 1.0-_ease((_action_age-0.055)/maxf(0.10,_action_duration-0.055))
	for side: int in [-1,1]:
		if not _arms.has(side): continue
		var rig: Dictionary = _arms[side]
		var arm: Node3D = rig.arm
		var forearm: Node3D = rig.forearm
		var wrist: Node3D = rig.wrist
		var gait := sin(_travel_phase+PI if side < 0 else _travel_phase)*_motion
		var energy := 0.70 if _crash else (1.12 if _high else 1.0)
		var breath := sin(_time*1.6+float(side)*0.24)*0.002
		var tremor := (sin(_time*37.0+float(side))*0.0015+sin(_time*53.0)*0.0008)*_shake
		var offset := Vector3(-_look.x*0.002,breath+gait*0.010*energy-_sprint*0.045,_look.y*0.001+gait*lerpf(0.013,0.025,_sprint))
		if _seated: offset += Vector3(float(side)*0.015,-0.055,0.025)
		offset.x += gait*0.004-_strafe*0.006+tremor
		offset.y += tremor-(0.018 if _crash else 0.0)
		var angles := Vector3(0.10+gait*0.035,-float(side)*0.08-_look.x*0.009,-float(side)*0.06+gait*0.025-_look.y*0.006)
		var wrist_angles := Vector3(0.06,0,-float(side)*0.055)
		var curl := 0.0
		var elbow := 0.0
		if side == 1 and held != &"fists" and not stowed:
			curl = float(WEAPONS[held].grip)
			wrist_angles += Vector3(0.09,-0.35,0)
			offset += Vector3(0.02,0.025,-0.015)
		if action == &"punch":
			if attack_weapon != &"fists":
				if side == 1:
					var extension: float = strike*(0.84 if _contact else 1.0)
					var family: String = WEAPONS[attack_weapon].family
					match family:
						"stab","jagged":
							offset += Vector3(-0.10,0.20,-0.24)*extension
							wrist_angles += Vector3(0.30,-1.15,0.06)*strike
						"pipe","crumble":
							offset += Vector3(-0.09,0.15,-0.11)*extension
							angles.z -= 0.30*strike; wrist_angles += Vector3(0.25,-0.65,0.30)*strike
						"thud":
							offset += Vector3(-0.12,0.19,-0.20)*extension
							wrist_angles += Vector3(0.42,-0.70,0.10)*strike
						"spin":
							offset += Vector3(-0.10,0.20,-0.18)*extension
							wrist_angles += Vector3(0.35,-0.70,-0.08)*strike
						"sole":
							offset += Vector3(-0.11,0.18,-0.20)*extension
							wrist_angles += Vector3(0.60,-0.90,-0.30)*strike
						"whip":
							offset += Vector3(-0.05,0.13,-0.16)*extension
							wrist_angles += Vector3(0.20,-0.50,0.30)*strike
					elbow = -0.08*strike
				else: offset.y += 0.018*strike
			elif side == last_punch_side:
				var extension := strike*(0.84 if _contact else 1.0)
				offset += Vector3(-float(side)*0.175*extension,0.245*extension,-0.225*extension)
				angles += Vector3(-0.17*strike,-float(side)*0.14*strike,-float(side)*0.11*strike)
				# A straight fist follows the rising forearm. Bending down here puts
				# all the skin behind the cuff from the first-person camera.
				wrist_angles.x += 0.72*strike
				curl = clampf(strike*1.7,0.0,1.0)
				elbow = -0.10*strike
				if _contact and _action_age > 0.035 and _action_age < 0.095:
					wrist_angles.z += float(side)*0.10*sin((_action_age-0.035)/0.06*PI)
			else:
				offset.y += 0.035*strike
				curl = strike*0.3
		elif action in [&"bench",&"dumpster"]:
			if action == &"bench":
				offset += Vector3(float(side)*0.04,-0.06,-0.03)*gesture
				wrist_angles.x -= 0.15*gesture; curl = -0.12*gesture
			else:
				offset += Vector3(-float(side)*0.04,-0.035,-0.11)*gesture
				wrist_angles.x -= 0.28*gesture; curl = gesture*(0.65 if action_phase > 0.5 else -0.15)
		elif side == 1 and action in [&"interact",&"pickup",&"eat",&"smoke",&"equip",&"phone"]:
			match action:
				&"interact":
					offset += Vector3(-0.07,0.08,-0.08)*gesture
					wrist_angles.x -= 0.30*gesture
					curl = -0.18*gesture
				&"pickup":
					offset += Vector3(-0.09,-0.015,-0.11)*gesture
					wrist_angles.x -= 0.35*gesture
					curl = gesture*(0.65 if action_phase > 0.35 else -0.15)
				&"eat":
					offset += Vector3(-0.16,0.245,0.085)*gesture
					wrist_angles += Vector3(0.35,-0.28,-0.10)*gesture
					curl = 0.50*gesture
				&"smoke":
					offset += Vector3(0.035,0.245,0.065)*gesture
					wrist_angles += Vector3(0.30,0.15,-0.08)*gesture
					curl = 0.35*gesture
				&"equip":
					offset += Vector3(0.025,-0.11,0.035)*gesture
					curl = 0.25*gesture
				&"phone":
					offset += Vector3(0.08,0.19,0.04)*gesture
					wrist_angles += Vector3(0.15,0.30,0.25)*gesture; curl = 0.55*gesture
		elif side == -1 and action == &"receipt":
			offset += Vector3(0.09,0.085,-0.025)*gesture
			wrist_angles += Vector3(0.25,-0.13,0.12)*gesture
			curl = 0.20*gesture
		arm.position = rig.rest+offset
		arm.rotation = angles
		forearm.rotation.x = elbow
		wrist.rotation = wrist_angles
		_pose_fingers(rig,side,curl)
	for key: StringName in _props:
		var prop: Node3D = _props[key]
		prop.visible = action == key and action_phase > 0.12 and action_phase < 0.88
	if _props.has(&"kick"):
		_props[&"kick"].position = _kick_base+Vector3(0,0.13,-0.18)*(gesture if action == &"kick" else 0.0)
		_props[&"kick"].rotation.x = 0.15*gesture if action == &"kick" else 0.0
	if _wheel != null: _wheel.rotation.z = strike*TAU*0.65 if held == &"cart_wheel" and action == &"punch" else 0.0
	for index: int in range(_cord.size()):
		var amplitude: float = strike if held == &"microphone" and action == &"punch" else 0.0
		_cord[index].rotation = Vector3(0,sin(action_phase*TAU+index*0.6)*0.20*amplitude,sin(action_phase*TAU+index*0.8)*0.25*amplitude)


func _pose_fingers(rig: Dictionary, side: int, amount: float) -> void:
	var curl := clampf(amount,-0.2,1.0)
	var fingers: Array = rig.fingers
	for i: int in range(fingers.size()):
		var chain: Array = fingers[i]
		var base: Node3D = chain[0]
		var middle: Node3D = chain[1]
		var tip: Node3D = chain[2]
		var relaxed := 0.10+float(i)*0.035
		base.rotation = Vector3(-lerpf(relaxed,1.10,curl),float(side)*float(i-1)*0.045*(1.0-maxf(0.0,curl)),0)
		middle.rotation.x = -lerpf(0.24+float(i)*0.025,1.35,curl)
		tip.rotation.x = -lerpf(0.12,0.72,curl)
	var thumb: Node3D = rig.thumb
	var thumb_tip: Node3D = rig.thumb_tip
	thumb.rotation = Vector3(-lerpf(0.13,0.55,curl),float(side)*lerpf(0.58,-0.95,curl),float(side)*lerpf(0.10,0.20,curl))
	thumb_tip.rotation.x = -lerpf(0.20,0.90,curl)


func _build() -> void:
	for side: int in [-1,1]:
		var arm := _pivot(self,"left_arm" if side < 0 else "right_arm",Vector3(float(side)*0.285,-0.435,-0.50))
		var forearm := _pivot(arm,"forearm",Vector3(0,-0.19,0.17))
		var wrist := _pivot(forearm,"wrist",Vector3(0,0.205,-0.205))
		_link(arm,Vector3(float(side)*0.035,-0.27,0.26),Vector3(0,-0.17,0.15),0.085,0.075,MOLD,"upper_sleeve")
		_link(forearm,Vector3(0,-0.028,0.032),Vector3(0,0.190,-0.184),0.076,0.049,MOLD,"sleeve")
		_link(forearm,Vector3(0,0.166,-0.165),Vector3(0,0.192,-0.192),0.053,0.047,"555d34","cuff")
		_shape(wrist,[Vector4(0.032,0.038,0.026,0.024),Vector4(0.035,0.018,0.023,0.021),Vector4(0.037,-0.012,0.023,0.022),Vector4(0.051,-0.040,0.025,0.024),Vector4(0.052,-0.069,0.022,0.020),Vector4(0.045,-0.083,0.016,0.017)],SKIN,"palm",0.62)
		var fingers: Array = []
		var lengths: Array[float] = [0.083,0.096,0.089,0.071]
		var names: Array[String] = ["index","middle","ring","little"]
		for i: int in range(4):
			var radius := 0.0115 if i < 3 else 0.0100
			var first := _pivot(wrist,names[i],Vector3(float(side)*(-0.038+float(i)*0.025),-0.002,-0.075))
			var a: float = lengths[i]*0.43
			var b: float = lengths[i]*0.32
			var c: float = lengths[i]*0.25
			_digit(first,a,radius,"proximal")
			var middle := _pivot(first,"middle",Vector3(0,0,-a+0.003))
			_digit(middle,b,radius*0.93,"middle_mesh")
			var tip := _pivot(middle,"tip",Vector3(0,0,-b+0.003))
			_digit(tip,c,radius*0.83,"tip_mesh")
			_box(tip,Vector3(0,radius*0.73,-c*0.54),Vector3(radius*1.15,0.0015,c*0.48),"b3a077","nail")
			fingers.append([first,middle,tip])
		var thumb := _pivot(wrist,"thumb",Vector3(-float(side)*0.046,-0.008,-0.028))
		_digit(thumb,0.035,0.016,"thumb_base")
		var thumb_tip := _pivot(thumb,"tip",Vector3(0,0,-0.031))
		_digit(thumb_tip,0.028,0.0125,"thumb_tip")
		_box(thumb_tip,Vector3(0,0.009,-0.017),Vector3(0.014,0.0015,0.014),"b3a077","nail")
		_pivot(wrist,"palm_marker",Vector3(0,0,-0.045))
		_pivot(wrist,"knuckle_marker",Vector3(0,0,-0.078))
		_arms[side] = {"arm":arm,"forearm":forearm,"wrist":wrist,"rest":arm.position,"fingers":fingers,"thumb":thumb,"thumb_tip":thumb_tip}
		if side < 0:
			var receipt := _pivot(wrist,"receipt",Vector3(0,-0.010,-0.125))
			receipt.rotation.x = PI*0.5
			_box(receipt,Vector3.ZERO,Vector3(0.065,0.002,0.085),"d4c896","paper")
			_box(receipt,Vector3(0,0.0015,0.012),Vector3(0.041,0.001,0.003),"604020","mark")
			_props[&"receipt"] = receipt
		else:
			var food := _pivot(wrist,"food",Vector3(0,-0.005,-0.115))
			_shape(food,[Vector4(0.020,0.020,0.019,0.018),Vector4(0.030,0,0.025,0.023),Vector4(0.026,-0.035,0.021,0.020),Vector4(0.015,-0.049,0.012,0.012)],"b18648","food",0.70)
			_props[&"eat"] = food
	_build_weapons()
	_build_context_props()

func _select_weapon(id: StringName) -> void:
	if _weapon_pool == null or _weapon_socket == null: return
	var selected: StringName = &"" if id == &"fists" else id
	if selected == _selected_weapon: return
	if _weapon_nodes.has(_selected_weapon):
		var previous: Node3D = _weapon_nodes[_selected_weapon]
		previous.reparent(_weapon_pool,false); previous.transform = Transform3D.IDENTITY; previous.visible = false
	_selected_weapon = selected
	if _weapon_nodes.has(selected):
		var current: Node3D = _weapon_nodes[selected]
		current.reparent(_weapon_socket,false); current.transform = Transform3D.IDENTITY; current.visible = true

func _build_weapons() -> void:
	_weapon_pool = _pivot(self,"WeaponPool",Vector3(0,-0.50,-0.70))
	var wrist: Node3D = _arms[1].wrist
	_weapon_socket = _pivot(wrist,"HeldWeapon",Vector3(0,-0.036,-0.082))
	_pivot(wrist,"held_grip_marker",_weapon_socket.position)
	for id: StringName in WEAPONS:
		if id == &"fists": continue
		var item := _pivot(_weapon_pool,String(id),Vector3.ZERO)
		item.set_meta("weapon_id",String(id)); item.visible = false
		_weapon_nodes[id] = item
		match id:
			&"pipe":
				_xrod(item,0.060,-0.46,0.019,"a46b42","copper_pipe")
				_xrod(item,-0.458,-0.465,0.015,"3b3024","pipe_open_end")
				for x: float in [-0.24,-0.37]: _box(item,Vector3(x,0.019,0),Vector3(0.025,0.002,0.012),"6d7050","oxidized_seam")
			&"brick":
				var body := _xshape(item,[Vector4(0.033,0.055,0.025,0.025),Vector4(0.042,0.045,0.029,0.029),Vector4(0.042,-0.125,0.029,0.029),Vector4(0.032,-0.145,0.023,0.023)],"91584a","chipped_brick",0.22)
				body.position.z = -0.003
				_box(item,Vector3(-0.065,0.030,0),Vector3(0.052,0.002,0.030),"775347","brick_face_recess")
			&"cart_wheel":
				_xrod(item,0.060,-0.090,0.017,"7d806c","wheel_fork_grip")
				for z: float in [-0.044,0.044]: _box(item,Vector3(-0.115,0,z),Vector3(0.11,0.022,0.016),"777b68","fork")
				_wheel = _pivot(item,"wheel",Vector3(-0.155,0,0))
				var tire: MeshInstance3D = _torus(_wheel,0.065,0.094,"32372d","rubber_tire")
				tire.rotation.x = PI*0.5
				var hub: MeshInstance3D = _shape(_wheel,[Vector4(0.063,0.018,0.063,0.063),Vector4(0.063,-0.018,0.063,0.063)],"777b68","rim",1.0)
				_xrod(_wheel,0.025,-0.025,0.014,"9c987a","axle").rotation = Vector3.ZERO
				for angle: float in [0.0,PI*0.5,PI,PI*1.5]:
					var spoke := _pivot(_wheel,"spoke",Vector3.ZERO); spoke.rotation.z = angle
					_box(spoke,Vector3(0.034,0,0.020),Vector3(0.052,0.009,0.006),"aaa389","hub_spoke")
				hub.position = Vector3.ZERO
			&"shoe": _shoe(item,Vector3.ZERO,false)
			&"baguette":
				_xshape(item,[Vector4(0.020,0.060,0.020,0.018),Vector4(0.033,0.030,0.031,0.026),Vector4(0.037,-0.16,0.033,0.028),Vector4(0.032,-0.35,0.027,0.024),Vector4(0.012,-0.40,0.011,0.010)],"a17b42","stale_baguette",0.74)
				for x: float in [-0.07,-0.15,-0.23,-0.31]:
					var cut := _pivot(item,"bread_score",Vector3(x,0.030,0)); cut.rotation.y = 0.38
					_box(cut,Vector3.ZERO,Vector3(0.011,0.003,0.047),"cab17a","score")
			&"microphone":
				_xrod(item,0.054,-0.063,0.014,"34372d","cord_bundle")
				for x: float in [-0.035,-0.010,0.015]:
					var loop: MeshInstance3D = _torus(item,0.018,0.024,"45483b","coiled_cord")
					loop.rotation.z = PI*0.5; loop.position.x = x
				var previous: Node3D = item
				for index: int in range(6):
					var joint := _pivot(previous,"cord_%d" % index,Vector3(-0.063 if index == 0 else -0.065,0,0))
					_xrod(joint,0.002,-0.066,0.0045,"33392f","rubber_cord")
					_cord.append(joint); previous = joint
				_xrod(previous,-0.064,-0.096,0.009,"747b68","audio_plug")
				_xrod(previous,-0.095,-0.115,0.0045,"a89b75","plug_tip")
			&"knife":
				_xrod(item,0.054,-0.070,0.019,"4a4937","taped_handle")
				for x: float in [-0.04,-0.015,0.010,0.035]: _box(item,Vector3(x,0,0),Vector3(0.009,0.040,0.038),"a59c76","tape_wrap")
				_box(item,Vector3(-0.075,0,0),Vector3(0.012,0.052,0.028),"6e7464","knife_guard")
				_convex(item,[Vector3(-0.080,-0.021,-0.003),Vector3(-0.080,0.021,-0.003),Vector3(-0.245,0.005,0),Vector3(-0.080,-0.021,0.003),Vector3(-0.080,0.021,0.003)],[[0,1,2],[3,2,4],[0,2,3],[1,4,2],[0,3,4,1]],"a7aa91","blade")
			&"broken_bottle":
				_xshape(item,[Vector4(0.014,0.055,0.014,0.014),Vector4(0.017,0.045,0.017,0.017),Vector4(0.017,-0.055,0.017,0.017),Vector4(0.039,-0.085,0.039,0.039),Vector4(0.042,-0.150,0.042,0.042)],"657552","bottle_neck_body",1.0)
				_xrod(item,-0.149,-0.152,0.034,"283d2b","broken_interior")
				for index: int in range(6):
					var angle: float = index*TAU/6.0
					var y: float = cos(angle)*0.036; var z: float = sin(angle)*0.036
					var tip_x: float = -0.185-0.012*float(index%3)
					_convex(item,[Vector3(-0.145,y-0.009,z-0.005),Vector3(-0.145,y+0.009,z+0.005),Vector3(tip_x,y*1.04,z*1.04),Vector3(-0.145,y,z+0.008)],[[0,1,2],[1,3,2],[3,0,2],[0,3,1]],"8c9972","broken_rim")

func _build_context_props() -> void:
	var wrist: Node3D = _arms[1].wrist
	var phone := _pivot(wrist,"phone",Vector3(0,-0.015,-0.115))
	_box(phone,Vector3.ZERO,Vector3(0.035,0.025,0.12),"3c4435","public_receiver")
	for z: float in [-0.069,0.069]:
		_box(phone,Vector3(0,-0.008,z),Vector3(0.060,0.043,0.039),"4d5541","receiver_end")
		_box(phone,Vector3(0,-0.031,z),Vector3(0.041,0.004,0.025),"222a20","receiver_grille")
	_props[&"phone"] = phone
	var foot := _pivot(self,"kick_foot",_kick_base)
	_link(foot,Vector3(0,0.22,0.11),Vector3(0,0.04,0.015),0.071,0.052,MOLD,"trouser_cuff")
	var shoe := _pivot(foot,"worn_shoe",Vector3(0,0.018,0)); shoe.rotation.y = -PI*0.5
	_shoe(shoe,Vector3.ZERO,true)
	_props[&"kick"] = foot

static func _xshape(parent: Node3D,profiles: Array[Vector4],color: String,part_name: String,roundness: float) -> MeshInstance3D:
	var part: MeshInstance3D = _shape(parent,profiles,color,part_name,roundness)
	part.rotation.y = PI*0.5
	return part

static func _xrod(parent: Node3D,start: float,end: float,radius: float,color: String,part_name: String) -> MeshInstance3D:
	return _xshape(parent,[Vector4(radius,start,radius,radius),Vector4(radius,end,radius,radius)],color,part_name,1.0)

static func _shoe(parent: Node3D,at: Vector3,player_shoe: bool) -> void:
	var holder := _pivot(parent,"shoe_form",at)
	_xshape(holder,[Vector4(0.029,0.055,0.029,0.024),Vector4(0.042,0.025,0.043,0.026),Vector4(0.049,-0.09,0.049,0.028),Vector4(0.049,-0.18,0.031,0.028),Vector4(0.033,-0.215,0.018,0.023)],"5d5841" if player_shoe else "73533a","worn_leather",0.54)
	_box(holder,Vector3(-0.075,-0.030,0),Vector3(0.270,0.012,0.088),"33392c","shoe_sole")
	_box(holder,Vector3(0.023,-0.039,0),Vector3(0.063,0.018,0.074),"292f26","heel")
	for x: float in [-0.02,-0.045,-0.070]: _box(holder,Vector3(x,0.045,0),Vector3(0.006,0.004,0.060),"aaa07b","lace")
	_box(holder,Vector3(-0.170,0.028,0),Vector3(0.026,0.003,0.044),"958367","toe_scuff")

static func _torus(parent: Node3D,inner: float,outer: float,color: String,part_name: String) -> MeshInstance3D:
	var key := "torus:"+str(inner)+":"+str(outer)
	if not _meshes.has(key):
		var mesh := TorusMesh.new(); mesh.inner_radius = inner; mesh.outer_radius = outer; mesh.rings = 16; mesh.ring_segments = 8
		_meshes[key] = mesh
	return _part(parent,_meshes[key] as Mesh,color,part_name)

static func _convex(parent: Node3D,points: Array[Vector3],faces: Array,color: String,part_name: String) -> MeshInstance3D:
	var key := "convex:"+str(points)+":"+str(faces)
	if not _meshes.has(key):
		var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var indices := PackedInt32Array()
		var center := Vector3.ZERO
		for point: Vector3 in points: center += point
		center /= float(points.size())
		for face: Array in faces:
			for index: int in range(1,face.size()-1):
				var a: Vector3 = points[face[0]]; var b: Vector3 = points[face[index]]; var c: Vector3 = points[face[index+1]]
				var normal: Vector3 = (b-a).cross(c-a).normalized()
				if normal.dot((a+b+c)/3.0-center) < 0:
					var swap: Vector3 = b; b = c; c = swap; normal = -normal
				var start: int = vertices.size()
				vertices.append_array(PackedVector3Array([a,b,c])); normals.append_array(PackedVector3Array([normal,normal,normal])); indices.append_array(PackedInt32Array([start+2,start+1,start]))
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); _meshes[key] = mesh
	return _part(parent,_meshes[key] as Mesh,color,part_name)


static func _pivot(parent: Node3D, part_name: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = part_name
	node.position = at
	parent.add_child(node)
	return node


static func _material(color: String) -> StandardMaterial3D:
	if not _materials.has(color):
		var kind := "skin" if color in [SKIN,"b3a077"] else ("fabric" if color in [MOLD,"555d34"] else "plain")
		var material := Surfaces.material(kind,color,0.93).duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[color] = material
	return _materials[color] as StandardMaterial3D


static func _part(parent: Node3D, mesh: Mesh, color: String, part_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.material_override = _material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _box(parent: Node3D, at: Vector3, size: Vector3, color: String, part_name: String) -> void:
	var key := "box:"+str(size)
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	_part(parent,_meshes[key] as Mesh,color,part_name).position = at


static func _digit(parent: Node3D, length: float, radius: float, part_name: String) -> void:
	_shape(parent,[Vector4(radius*0.78,0.003,radius*0.69,radius*0.72),Vector4(radius,0,radius*0.82,radius*0.88),Vector4(radius*0.95,-length*0.40,radius*0.80,radius*0.86),Vector4(radius*0.81,-length*0.84,radius*0.69,radius*0.73),Vector4(radius*0.47,-length,radius*0.42,radius*0.43)],SKIN,part_name,0.85)


static func _link(parent: Node3D, start: Vector3, end: Vector3, wide: float, narrow: float, color: String, part_name: String) -> void:
	var distance := start.distance_to(end)
	var part := _shape(parent,[Vector4(wide,0,wide*0.94,wide*0.94),Vector4(wide*0.98,-distance*0.30,wide*0.91,wide*0.94),Vector4(narrow*1.08,-distance*0.82,narrow,narrow),Vector4(narrow,-distance,narrow*0.94,narrow*0.94)],color,part_name,0.82)
	part.position = start
	part.quaternion = Quaternion(Vector3.FORWARD,(end-start).normalized())


static func _shape(parent: Node3D, profiles: Array[Vector4], color: String, part_name: String, roundness: float) -> MeshInstance3D:
	var key := "profile:"+str(profiles)+":"+str(roundness)
	if not _meshes.has(key):
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		const SIDES := 16
		for p: Vector4 in profiles:
			for i: int in range(SIDES):
				var angle := TAU*float(i)/float(SIDES)
				var s := sin(angle)
				var c := cos(angle)
				vertices.append(Vector3(signf(s)*pow(absf(s),roundness)*p.x,signf(c)*pow(absf(c),roundness)*(p.z if c > 0.0 else p.w),p.y))
		normals.resize(vertices.size())
		for row: int in range(profiles.size()-1):
			for column: int in range(SIDES):
				var a := row*SIDES+column
				var b := row*SIDES+(column+1)%SIDES
				var c := (row+1)*SIDES+column
				var d := (row+1)*SIDES+(column+1)%SIDES
				for face: Vector3i in [Vector3i(a,b,c),Vector3i(b,d,c)]:
					var normal := (vertices[face.y]-vertices[face.x]).cross(vertices[face.z]-vertices[face.x])
					for index: int in [face.x,face.y,face.z]: normals[index] += normal
					indices.append_array(PackedInt32Array([face.z,face.y,face.x]))
		for i: int in range(normals.size()): normals[i] = normals[i].normalized()
		# Caps have their own vertices/normals, preserving cuff and fingertip edges.
		for end: int in [0,profiles.size()-1]:
			var center := Vector3(0,0,profiles[end].y)
			var normal := Vector3.BACK if end == 0 else Vector3.FORWARD
			for column: int in range(SIDES):
				var a: Vector3 = vertices[end*SIDES+column]
				var b: Vector3 = vertices[end*SIDES+(column+1)%SIDES]
				var offset := vertices.size()
				vertices.append_array(PackedVector3Array([center,b,a] if end == 0 else [center,a,b]))
				normals.append_array(PackedVector3Array([normal,normal,normal]))
				indices.append_array(PackedInt32Array([offset+2,offset+1,offset]))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		_meshes[key] = mesh
	return _part(parent,_meshes[key] as Mesh,color,part_name)
