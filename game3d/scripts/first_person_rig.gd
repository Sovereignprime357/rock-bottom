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
const TOOLS := [&"propane_torch",&"crowbar"]
const COATS := {&"trench":{"body":"8a3a3a","trim":"d4c896","fullness":1.02},
	&"windbreaker":{"body":"d488d4","trim":"e8c040","fullness":0.98},
	&"bathrobe":{"body":"d4c896","trim":"d488d4","fullness":1.10},
	&"parka":{"body":MOLD,"trim":"e8c040","fullness":1.08}}
const FOOTWEAR := [&"airpods",&"crocs",&"walmart_sneak",&"vibrams"]
const CART_DIGIT_ANGLES := [Vector3(0.400,0.900,0.466),Vector3(0.326,1.099,0.897),Vector3(0.303,1.163,0.244),Vector3(0.344,0.686,0.644)]
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
var tool: StringName = &""
var coat: StringName = &""
var shoes: StringName = &""
var high_ember: bool = false
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
var _cart_grips: Dictionary = {}
var _tool_nodes: Dictionary = {}
var _tool_pool: Node3D
var _tool_socket: Node3D
var _selected_tool: StringName = &""
var _sleeves: Array[Dictionary] = []
var _footwear_nodes: Dictionary = {}
var _applied_coat: StringName = &"__unapplied"
var _applied_shoes: StringName = &"__unapplied"
var _emitter_anchors: Dictionary = {}
var _mouth_ember: Node3D

func emitter_anchor(kind: StringName) -> Node3D:
	return _emitter_anchors.get(kind) as Node3D

static func supported_weapons() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in WEAPONS: result.append(id)
	return result

static func supported_tools() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in TOOLS: result.append(id)
	return result

static func _slot_valid(value: Variant, allowed: Variant) -> bool:
	if value == null: return true
	return (value is String or value is StringName) and (StringName(value).is_empty() or allowed.has(StringName(value)))

static func _slot_id(value: Variant) -> StringName:
	return &"" if value == null else StringName(value)

func set_context(snapshot: Dictionary) -> bool:
	var next: Variant = snapshot.get("weapon",weapon)
	if not (next is String or next is StringName) or not WEAPONS.has(StringName(next)): return false
	var next_tool: Variant = snapshot.get("tool",tool)
	var next_coat: Variant = snapshot.get("coat",coat)
	var next_shoes: Variant = snapshot.get("shoes",shoes)
	if not _slot_valid(next_tool,TOOLS) or not _slot_valid(next_coat,COATS) or not _slot_valid(next_shoes,FOOTWEAR): return false
	var next_ember: Variant = snapshot.get("high_ember",high_ember)
	if not next_ember is bool: return false
	var seated: Variant = snapshot.get("seated",_seated)
	var shown: Variant = snapshot.get("visible",_context_visible)
	var speed: Variant = snapshot.get("walk_speed",_walk_speed)
	if not seated is bool or not shown is bool or not (speed is int or speed is float) or not is_finite(float(speed)) or speed < 1.0 or speed > 10.0: return false
	var grips: Variant = snapshot.get("cart_grips",_cart_grips)
	if not grips is Dictionary: return false
	if not grips.is_empty():
		if grips.size() != 2: return false
		for key: String in ["left","right"]:
			if not grips.get(key) is Vector3: return false
			var point: Vector3 = grips[key]
			if not point.is_finite() or point.z > -0.44 or point.z < -1.3 or absf(point.x) > 0.72 or point.y < -0.90 or point.y > 0.80: return false
	weapon = StringName(next); _seated = seated; _context_visible = shown; _walk_speed = float(speed)
	tool = _slot_id(next_tool); coat = _slot_id(next_coat); shoes = _slot_id(next_shoes)
	high_ember = next_ember
	_cart_grips = grips.duplicate()
	_apply_clothing()
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
	tool = &""; coat = &""; shoes = &""
	high_ember = false
	_seated = false; _context_visible = true; _action_duration = 0.24
	_cart_grips.clear()
	_apply_clothing()
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
	if not _cart_grips.is_empty() and action.is_empty(): stowed = true
	_select_weapon(&"fists" if stowed else held)
	var left_active: bool = (action == &"punch" and last_punch_side < 0) or action in [&"receipt",&"bench",&"dumpster"]
	var tool_stowed: bool = left_active or action == &"smoke" or (_cart_grips.has("left") and not left_active)
	_select_tool(&"" if tool_stowed else tool)
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
		if side == -1 and not _selected_tool.is_empty():
			# The shaft lies across the closed palm. Roll the wrist, rather than
			# rotating the object through the fingers, for a low vertical carry.
			curl = 0.83
			wrist_angles += Vector3(0.09,0.18,-1.10)
			offset += Vector3(-0.01,0.065,-0.03)
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
				if side != -1 or _selected_tool.is_empty(): curl = strike*0.3
		elif action in [&"bench",&"dumpster"]:
			if action == &"bench":
				offset += Vector3(float(side)*0.04,-0.06,-0.03)*gesture
				wrist_angles.x -= 0.15*gesture; curl = -0.12*gesture
			else:
				offset += Vector3(-float(side)*0.04,-0.035,-0.11)*gesture
				wrist_angles.x -= 0.28*gesture; curl = gesture*lerpf(-0.15,0.65,_ease((action_phase-0.42)/0.16))
		elif side == 1 and action in [&"interact",&"pickup",&"eat",&"smoke",&"equip",&"phone"]:
			match action:
				&"interact":
					offset += Vector3(-0.07,0.08,-0.08)*gesture
					wrist_angles.x -= 0.30*gesture
					curl = -0.18*gesture
				&"pickup":
					offset += Vector3(-0.09,-0.015,-0.11)*gesture
					wrist_angles.x -= 0.35*gesture
					curl = gesture*lerpf(-0.15,0.65,_ease((action_phase-0.28)/0.14))
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
		var active_hand: bool = (action == &"punch" and side == last_punch_side) or action in [&"bench",&"dumpster"] or (action == &"receipt" and side < 0) or (action in [&"interact",&"pickup",&"eat",&"smoke",&"equip",&"phone"] and side > 0)
		var grip_key: String = "left" if side < 0 else "right"
		# Separate from the shared grip evaluator: even a partly closed item grip
		# must retain its authored relaxed endpoint. Stowed equipment also keeps
		# the established gesture pose, and the final cart solve remains exact.
		var free_hand: bool = (held == &"fists" if side > 0 else tool.is_empty()) and not _cart_grips.has(grip_key)
		var relaxation: float = 0.0
		if free_hand:
			relaxation = 1.0-_ease(strike) if action == &"punch" else (1.0-_ease(gesture) if active_hand else 1.0)
			offset += (Vector3(-0.012,-0.018,0.012) if side < 0 else Vector3(0.005,-0.006,-0.004))*relaxation
			angles += (Vector3(0.025,-0.03,0.035) if side < 0 else Vector3(-0.015,0.02,-0.02))*relaxation
			wrist_angles += (Vector3(-0.14,0.18,0.18) if side < 0 else Vector3(-0.08,-0.10,-0.11))*relaxation
		arm.position = rig.rest+offset
		arm.rotation = angles
		forearm.rotation.x = elbow
		wrist.rotation = wrist_angles
		_pose_fingers(rig,side,curl)
		if relaxation > 0.0: _relax_fingers(rig,side,relaxation)
		if _cart_grips.has(grip_key) and not active_hand:
			# Translate the existing connected sleeve chain so its closed fingers
			# surround the real handle; no second handle or autonomous IK clock.
			arm.rotation = Vector3(0.10,0.0,-float(side)*0.04)
			forearm.rotation.x = 0.0; wrist.rotation = Vector3(0.15,0,0)
			_pose_cart_fingers(rig,side)
			var local_grip := Vector3(0,-0.036,-0.082)
			var current: Vector3 = arm.transform*forearm.transform*wrist.transform*local_grip
			arm.position += Vector3(_cart_grips[grip_key])-current
	for key: StringName in _props:
		var prop: Node3D = _props[key]
		prop.visible = action == key and action_phase > 0.12 and action_phase < 0.88
	if _props.has(&"kick"):
		_props[&"kick"].position = _kick_base+Vector3(0,0.30,-0.23)*(gesture if action == &"kick" else 0.0)
		_props[&"kick"].rotation.x = 0.15*gesture if action == &"kick" else 0.0
	if _wheel != null: _wheel.rotation.z = strike*TAU*0.65 if held == &"cart_wheel" and action == &"punch" else 0.0
	for index: int in range(_cord.size()):
		var amplitude: float = strike if held == &"microphone" and action == &"punch" else 0.0
		_cord[index].rotation = Vector3(0,sin(action_phase*TAU+index*0.6)*0.20*amplitude,sin(action_phase*TAU+index*0.8)*0.25*amplitude)
	if _mouth_ember != null: _mouth_ember.visible = high_ember and _context_visible and action.is_empty()


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


func _pose_cart_fingers(rig: Dictionary, side: int) -> void:
	# Fixed wrap around the .038m shaft; the source handle marker stays unchanged.
	# Finger lengths differ, so one common tool curl cannot place all pads on it.
	var fingers: Array = rig.fingers
	for index: int in range(fingers.size()):
		var angles: Vector3 = CART_DIGIT_ANGLES[index]
		var chain: Array = fingers[index]
		(chain[0] as Node3D).rotation = Vector3(-angles.x,0,0)
		(chain[1] as Node3D).rotation.x = -angles.y
		(chain[2] as Node3D).rotation.x = -angles.z
	(rig.thumb as Node3D).rotation = Vector3(-0.15,-float(side),-float(side)*0.20)
	(rig.thumb_tip as Node3D).rotation.x = -0.40


func _relax_fingers(rig: Dictionary, side: int, weight: float) -> void:
	# An open, resting cascade rather than four parallel fingers or a guard fist.
	# No mesh work, new clock or change to the occupied-hand grip endpoints.
	var fingers: Array = rig.fingers
	var amount: float = weight*(1.0 if side < 0 else 0.88)
	for index: int in range(fingers.size()):
		var chain: Array = fingers[index]
		(chain[0] as Node3D).rotation.x -= (0.08+float(index)*0.073)*amount
		(chain[1] as Node3D).rotation.x -= (0.10+float(index)*0.083)*amount
		(chain[2] as Node3D).rotation.x -= (0.05+float(index)*0.043)*amount
	var thumb: Node3D = rig.thumb
	thumb.rotation += Vector3(-0.16,-float(side)*0.23,0.0)*amount
	(rig.thumb_tip as Node3D).rotation.x -= 0.13*amount


func _build() -> void:
	for side: int in [-1,1]:
		var arm := _pivot(self,"left_arm" if side < 0 else "right_arm",Vector3(float(side)*0.285,-0.435,-0.50))
		var forearm := _pivot(arm,"forearm",Vector3(0,-0.19,0.17))
		var wrist := _pivot(forearm,"wrist",Vector3(0,0.205,-0.205))
		_link(arm,Vector3(float(side)*0.035,-0.27,0.26),Vector3(0,-0.17,0.15),0.085,0.075,MOLD,"upper_sleeve")
		_link(forearm,Vector3(0,-0.028,0.032),Vector3(0,0.190,-0.184),0.076,0.049,MOLD,"sleeve")
		_link(forearm,Vector3(0,0.166,-0.165),Vector3(0,0.192,-0.192),0.053,0.047,"555d34","cuff")
		for cloth: MeshInstance3D in [arm.get_node("upper_sleeve"),forearm.get_node("sleeve"),forearm.get_node("cuff")]:
			_sleeves.append({"node":cloth,"material":cloth.material_override,"scale":cloth.scale,"trim":cloth.name == &"cuff"})
		_palm(wrist,side)
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
		_shape(thumb,[Vector4(0.020,0.003,0.012,0.015),Vector4(0.020,0,0.0125,0.015),Vector4(0.0175,-0.014,0.013,0.014),Vector4(0.0130,-0.0294,0.011,0.0117),Vector4(0.00752,-0.035,0.00672,0.00688)],SKIN,"thumb_base",0.76)
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
	_build_tools()
	_build_context_props()
	_build_mouth_ember()

func _build_mouth_ember() -> void:
	# Abstract mouth-held fixture enters from below the frame. It never takes a
	# hand, equipment slot, action, timer or inventory item from the simulation.
	_mouth_ember = _pivot(self,"MouthEmber",Vector3.ZERO); _mouth_ember.visible = false
	_link(_mouth_ember,Vector3(0.09,-0.22,-0.085),Vector3(0.12,-0.21,-0.23),0.007,0.008,"8b6038","stem")
	_link(_mouth_ember,Vector3(0.12,-0.21,-0.23),Vector3(0.14,-0.21,-0.30),0.008,0.010,"8b6038","stem_bend")
	var bowl := _shape(_mouth_ember,[Vector4(0.022,0.0175,0.022,0.022),Vector4(0.022,0.007,0.022,0.022),Vector4(0.014,-0.0175,0.014,0.014)],"8b6038","bowl",0.72)
	bowl.position = Vector3(0.14,-0.205,-0.30); bowl.rotation.x = -PI*0.5
	var ember := _shape(_mouth_ember,[Vector4(0.015,0.002,0.015,0.015),Vector4(0.015,-0.002,0.015,0.015)],"d06030","ember",0.80)
	ember.position = Vector3(0.14,-0.1865,-0.30); ember.rotation.x = -PI*0.5
	ember.material_override = _emissive("d06030",0.65)
	var core := _shape(_mouth_ember,[Vector4(0.006,0.001,0.006,0.006),Vector4(0.006,-0.001,0.006,0.006)],"e8c040","core",0.82)
	core.position = Vector3(0.139,-0.1835,-0.301); core.rotation.x = -PI*0.5
	core.material_override = _emissive("e8c040",0.75)
	_emitter_anchors[&"player_ember"] = _pivot(_mouth_ember,"Tip",Vector3(0.139,-0.1835,-0.301))

func _apply_clothing() -> void:
	if coat != _applied_coat:
		for record: Dictionary in _sleeves:
			var mesh: MeshInstance3D = record.node
			if coat.is_empty():
				mesh.material_override = record.material
				mesh.scale = record.scale
			else:
				var style: Dictionary = COATS[coat]
				mesh.material_override = _cloth_material(String(style.trim if record.trim else style.body))
				var fullness: float = float(style.fullness)
				mesh.scale = Vector3(record.scale)*Vector3(fullness,fullness,1.0)
		_applied_coat = coat
	if shoes != _applied_shoes:
		var selected: StringName = &"" if shoes == &"airpods" else shoes
		for id: StringName in _footwear_nodes:
			_footwear_nodes[id].visible = id == selected
		_applied_shoes = shoes

func _select_tool(id: StringName) -> void:
	if _tool_pool == null or _tool_socket == null or id == _selected_tool: return
	if _tool_nodes.has(_selected_tool):
		var previous: Node3D = _tool_nodes[_selected_tool]
		previous.reparent(_tool_pool,false); previous.transform = Transform3D.IDENTITY; previous.visible = false
	_selected_tool = id
	if _tool_nodes.has(id):
		var current: Node3D = _tool_nodes[id]
		current.reparent(_tool_socket,false); current.transform = Transform3D.IDENTITY; current.visible = true

func _build_tools() -> void:
	_tool_pool = _pivot(self,"ToolPool",Vector3(0,-0.50,-0.70))
	_tool_pool.visible = false
	var wrist: Node3D = _arms[-1].wrist
	_tool_socket = _pivot(wrist,"HeldTool",Vector3(0,-0.036,-0.082))
	_pivot(wrist,"tool_grip_marker",_tool_socket.position)
	for id: StringName in TOOLS:
		var item := _pivot(_tool_pool,String(id),Vector3.ZERO)
		item.set_meta("tool_id",id); item.visible = false; _tool_nodes[id] = item
		match id:
			&"propane_torch":
				# Axis X passes through the finger curl. The reservoir hangs below
				# the gripping neck after the left wrist rolls into its carry pose.
				_xshape(item,[Vector4(0.039,0.245,0.039,0.039),Vector4(0.054,0.232,0.052,0.047),Vector4(0.057,0.075,0.055,0.049),Vector4(0.039,0.046,0.037,0.037),Vector4(0.018,0.035,0.018,0.018)],"b1813d","dented_reservoir",0.76)
				_xrod(item,0.038,-0.060,0.018,"3d3a2b","gripping_neck")
				_xrod(item,0.246,0.235,0.043,"604020","base_rim")
				_xrod(item,0.061,0.051,0.043,"8a3a3a","shoulder_ring")
				_link(item,Vector3(-0.060,0,0),Vector3(-0.097,0,-0.037),0.018,0.014,"3d3a2b","bent_neck")
				_link(item,Vector3(-0.097,0,-0.037),Vector3(-0.118,0,-0.062),0.015,0.012,"604020","nozzle")
				var pilot := _convex(item,[Vector3(-0.119,-0.008,-0.057),Vector3(-0.119,0.008,-0.057),Vector3(-0.116,0,-0.071),Vector3(-0.141,0,-0.087)],[[0,1,2],[0,3,1],[1,3,2],[2,3,0]],"e8c040","static_pilot")
				pilot.material_override = _emissive("e8c040",0.35)
				_emitter_anchors[&"torch_pilot"] = _pivot(item,"TorchTip",Vector3(-0.141,0,-0.087))
				_box(item,Vector3(0.143,0.057,0.010),Vector3(0.063,0.003,0.039),"d4c896","paper_mark")
				_box(item,Vector3(0.151,0.059,0.010),Vector3(0.027,0.001,0.004),"604020","paper_line")
				_box(item,Vector3(0.205,0.040,-0.034),Vector3(0.021,0.004,0.020),"8a3a3a","rust_dent")
			&"crowbar":
				_xrod(item,0.345,-0.080,0.015,"8a3a3a","municipal_shaft")
				_link(item,Vector3(-0.079,0,0),Vector3(-0.119,0,-0.035),0.015,0.014,"8a3a3a","hook_bend")
				_link(item,Vector3(-0.119,0,-0.035),Vector3(-0.117,0,-0.074),0.014,0.012,"8a3a3a","hook_tip")
				_box(item,Vector3(-0.113,0,-0.076),Vector3(0.018,0.023,0.020),"3a342a","worn_hook")
				_convex(item,[Vector3(0.335,-0.014,-0.014),Vector3(0.335,0.014,-0.014),Vector3(0.335,0.014,0.014),Vector3(0.335,-0.014,0.014),Vector3(0.397,-0.006,-0.020),Vector3(0.397,0.006,-0.020),Vector3(0.397,0.006,0.020),Vector3(0.397,-0.006,0.020)],[[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]],"504331","flattened_foot")
				_box(item,Vector3(0.096,0.015,0),Vector3(0.042,0.002,0.018),"d4c896","property_mark")
				_box(item,Vector3(0.103,0.0165,0),Vector3(0.003,0.001,0.012),"604020","property_ink")
				_xrod(item,0.239,0.218,0.0155,"604020","worn_band")

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
				var tip := _xrod(item,-0.458,-0.465,0.015,"e8c040","pipe_open_end")
				tip.material_override = _emissive("e8c040",0.35)
				_emitter_anchors[&"weapon_pipe"] = _pivot(item,"PipeTip",Vector3(-0.465,0,0))
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
				# Broad shards follow the rim tangent; unequal breaks expose the dark
				# interior instead of reading as parallel teeth from the player's eye.
				var angles: Array[float] = [-0.20,0.55,1.50,2.40,3.00,4.15,5.05,TAU-0.20]
				var tips: Array[float] = [-0.190,-0.161,-0.204,-0.173,-0.196,-0.154,-0.183]
				for index: int in range(tips.size()):
					var first: Vector3 = Vector3(0,cos(angles[index]),sin(angles[index]))
					var last: Vector3 = Vector3(0,cos(angles[index+1]),sin(angles[index+1]))
					var middle: float = lerpf(angles[index],angles[index+1],0.34 if index%2 == 0 else 0.65)
					var tip: Vector3 = Vector3(0,cos(middle),sin(middle))
					var base := Vector3(-0.146,0,0); var end := Vector3(tips[index],0,0)
					_convex(item,[base+first*0.042,base+last*0.042,end+tip*0.043,base+first*0.033,base+last*0.033,end+tip*0.034],[[0,1,2],[3,5,4],[0,3,4,1],[1,4,5,2],[2,5,3,0]],"8c9972","broken_rim")

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
	shoe.set_meta("footwear_id",&""); _footwear_nodes[&""] = shoe
	for id: StringName in [&"crocs",&"walmart_sneak",&"vibrams"]:
		var footwear := _pivot(foot,"footwear_"+String(id),shoe.position)
		footwear.rotation.y = shoe.rotation.y; footwear.visible = false
		footwear.set_meta("footwear_id",id); _footwear_nodes[id] = footwear
		_build_footwear(footwear,id)
	_props[&"kick"] = foot

static func _build_footwear(parent: Node3D, id: StringName) -> void:
	match id:
		&"crocs":
			_xshape(parent,[Vector4(0.034,0.054,0.020,0.027),Vector4(0.047,0.015,0.028,0.028),Vector4(0.052,-0.095,0.043,0.027),Vector4(0.051,-0.180,0.037,0.026),Vector4(0.035,-0.216,0.016,0.021)],"8a3a3a","single_red_croc",0.65)
			_box(parent,Vector3(-0.071,-0.030,0),Vector3(0.272,0.012,0.089),"604020","croc_sole")
			for x: float in [-0.10,-0.14,-0.18]:
				for z: float in [-0.023,0.023]:
					_box(parent,Vector3(x,0.043+(x+0.10)*0.075,z),Vector3(0.010,0.003,0.011),"302a22","vent")
			_box(parent,Vector3(0.026,0.029,0),Vector3(0.014,0.007,0.080),"604020","heel_strap")
		&"walmart_sneak":
			_xshape(parent,[Vector4(0.032,0.055,0.031,0.025),Vector4(0.042,0.020,0.047,0.026),Vector4(0.048,-0.090,0.047,0.026),Vector4(0.047,-0.177,0.031,0.026),Vector4(0.034,-0.216,0.018,0.023)],"d4c896","cream_sneaker",0.62)
			_box(parent,Vector3(-0.075,-0.030,0),Vector3(0.272,0.012,0.088),"3d3a2b","rubber_sole")
			for z: float in [-0.047,0.047]: _box(parent,Vector3(-0.065,0.010,z),Vector3(0.095,0.010,0.003),"604020","dirty_side_seam")
			for x: float in [-0.020,-0.044,-0.068]: _box(parent,Vector3(x,0.046,0),Vector3(0.005,0.004,0.055),"e8c040","yellow_lace")
			_box(parent,Vector3(-0.180,0.026,0.009),Vector3(0.022,0.003,0.033),"958367","toe_dirt")
		&"vibrams":
			_xshape(parent,[Vector4(0.031,0.054,0.030,0.025),Vector4(0.044,0.015,0.035,0.026),Vector4(0.049,-0.095,0.031,0.025),Vector4(0.044,-0.151,0.024,0.023)],"d06030","orange_foot",0.68)
			_box(parent,Vector3(-0.049,-0.030,0),Vector3(0.213,0.010,0.084),"3d3a2b","foot_sole")
			_box(parent,Vector3(0.004,0.031,0),Vector3(0.022,0.008,0.079),"604020","foot_strap")
			for index: int in range(5):
				var length: float = 0.070-float(index)*0.005
				var toe := _xshape(parent,[Vector4(0.011,-0.139,0.022,0.018),Vector4(0.010,-0.139-length*0.80,0.018,0.017),Vector4(0.006,-0.139-length,0.010,0.011)],"d06030" if index%2 == 0 else "e8c040","toe_"+str(index),0.80)
				toe.position.z = -0.038+float(index)*0.019

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

static func _cloth_material(color: String) -> StandardMaterial3D:
	# A shared color need not imply a shared surface type: the red municipal
	# bar stays metal while a red trench sleeve uses object-space fabric grain.
	var key: String = "cloth:"+color
	if not _materials.has(key):
		var material := Surfaces.material("fabric",color,0.97).duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = material
	return _materials[key] as StandardMaterial3D

static func _emissive(color: String,energy: float) -> StandardMaterial3D:
	var key: String = "emissive:"+color+":"+str(energy)
	if not _materials.has(key):
		var material := _material(color).duplicate() as StandardMaterial3D
		material.emission_enabled = true; material.emission = Color(color); material.emission_energy_multiplier = energy
		_materials[key] = material
	return _materials[key] as StandardMaterial3D


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


static func _palm(parent: Node3D, side: int) -> void:
	var key := "sculpted_palm_v1:"+str(side)
	if not _meshes.has(key):
		# The lower/contact surface retains its authored profile; extra volume sits
		# on the thumb heel and dorsal knuckle planes, not inside held objects.
		var profiles: Array[Vector4] = [Vector4(0.032,0.038,0.026,0.024),Vector4(0.035,0.018,0.023,0.021),Vector4(0.037,-0.012,0.023,0.022),Vector4(0.045,-0.028,0.024,0.023),Vector4(0.051,-0.040,0.025,0.024),Vector4(0.0515,-0.055,0.0235,0.022),Vector4(0.052,-0.069,0.022,0.020),Vector4(0.045,-0.083,0.016,0.017)]
		var heel: Array[float] = [0,0,0.002,0.006,0.006,0.003,0,0]
		var ridge: Array[float] = [0,0,0,0,0,0.45,1.0,0.35]
		var heights: Array[float] = [0.003,0.004,0.0035,0.0025]
		var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var indices := PackedInt32Array()
		const SIDES := 24
		for row: int in range(profiles.size()):
			var p: Vector4 = profiles[row]
			for column: int in range(SIDES):
				var angle: float = TAU*float(column)/float(SIDES)
				var s: float = sin(angle); var c: float = cos(angle)
				var x: float = signf(s)*pow(absf(s),0.62)*p.x
				var y: float = signf(c)*pow(absf(c),0.62)*(p.z if c > 0.0 else p.w)
				if c > 0.0:
					var knuckle: float = 0.0
					for digit: int in range(4):
						var center: float = float(side)*(-0.038+float(digit)*0.025)
						knuckle = maxf(knuckle,exp(-pow((x-center)/0.010,2.0))*heights[digit])
					y += knuckle*ridge[row]*c*c
					x -= float(side)*heel[row]*pow(maxf(0.0,-float(side)*s),2.0)*c
				vertices.append(Vector3(x,y,p.y))
		normals.resize(vertices.size())
		for row: int in range(profiles.size()-1):
			for column: int in range(SIDES):
				var a: int = row*SIDES+column; var b: int = row*SIDES+(column+1)%SIDES
				var c: int = (row+1)*SIDES+column; var d: int = (row+1)*SIDES+(column+1)%SIDES
				for face: Vector3i in [Vector3i(a,b,c),Vector3i(b,d,c)]:
					var normal: Vector3 = (vertices[face.y]-vertices[face.x]).cross(vertices[face.z]-vertices[face.x])
					for vertex: int in [face.x,face.y,face.z]: normals[vertex] += normal
					indices.append_array(PackedInt32Array([face.z,face.y,face.x]))
		for vertex: int in range(normals.size()): normals[vertex] = normals[vertex].normalized()
		for end: int in [0,profiles.size()-1]:
			var center := Vector3(0,0,profiles[end].y)
			var normal := Vector3.BACK if end == 0 else Vector3.FORWARD
			for column: int in range(SIDES):
				var a: Vector3 = vertices[end*SIDES+column]; var b: Vector3 = vertices[end*SIDES+(column+1)%SIDES]
				var start: int = vertices.size()
				vertices.append_array(PackedVector3Array([center,b,a] if end == 0 else [center,a,b]))
				normals.append_array(PackedVector3Array([normal,normal,normal]))
				indices.append_array(PackedInt32Array([start+2,start+1,start]))
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); _meshes[key] = mesh
	_part(parent,_meshes[key] as Mesh,SKIN,"palm")


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
