class_name SliceCharacterArt
extends RefCounted
## Original, source-authored low-poly cast. Y up, feet at zero, faces toward +Z.
## All geometry/materials are built or fetched once when an actor is constructed.
## The named limb/head pivots are available to the owning actor's animation code.

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
const Surfaces = preload("res://scripts/surface_kit.gd")
const Batcher = preload("res://scripts/mesh_batcher.gd")

const SKIN := "ad8055"
const SKIN_PALE := "bd9b69"
const SKIN_SHADE := "80583d"
const HAIR := "30261b"
const DARK := "24231b"
const CREAM := "d4c896"
const MOLD := "4a5028"
const RUST := "8a3a3a"
const COPPER := "d06030"


static func create_character(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	root.set_meta("art_id", id)
	match id:
		"tony": _tony(root)
		"pete": _pete(root)
		"yuri": _yuri(root)
		"lurch": _lurch(root)
		"possum": _possum(root)
		"brutus": _brutus(root)
		"player_hands": _hands(root)
		_: push_error("Unknown character art: " + id)
	_finish_rig(root)
	if id == "player_hands":
		_disable_viewmodel_shadows(root)
	_cache_rig(root)
	return root


static func _mat(hex: String) -> StandardMaterial3D:
	if _materials.has(hex):
		return _materials[hex] as StandardMaterial3D
	var kind := "plain"
	if hex in [SKIN,SKIN_PALE,SKIN_SHADE,"c1b58c","b5a77e","765247","8f705b","a08065"]:
		kind = "skin"
	elif hex in [MOLD,RUST,"393328","454c2e","8c6b3b","604020","946b3c","b08e4e","69703e","3e2c1c","424137","6b7048","48483a","626348","4a4d35","4b4735","51473a","6a5b48","4b502c","6d7043","555d34","394027"]:
		kind = "fabric"
	# Character-local triplanar details follow the mesh. Thin lapels need both sides;
	# duplicate the shared kit resource before setting this character-only flag.
	var material := Surfaces.material(kind,hex,0.94).duplicate() as StandardMaterial3D
	# Two-sided surfaces allow genuinely thin lapels, ears and cloth hems.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[hex] = material
	return material


static func _finish_rig(pivot: Node3D) -> void:
	# Only the direct static leaves of each pivot are merged. Limb/head transforms
	# remain separate, as do the actor origin and every external interaction body.
	for child in pivot.get_children():
		if child is Node3D and not child is MeshInstance3D:
			_finish_rig(child as Node3D)
	Batcher.batch_children(pivot,0.0)


static func _disable_viewmodel_shadows(node: Node) -> void:
	# Camera-attached fists have no world body to anchor their ground shadows.
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_disable_viewmodel_shadows(child)


static func _cache_rig(root: Node3D) -> void:
	var rig: Dictionary = {}
	for path in ["head","jaw","left_arm","right_arm","left_arm/forearm","right_arm/forearm","left_leg","right_leg","front_left","front_right","back_left","back_right","tail","head/left_ear","head/right_ear"]:
		var pivot := root.get_node_or_null(NodePath(path)) as Node3D
		if pivot != null:
			rig[path] = {"node":pivot,"rest":pivot.transform}
	root.set_meta("character_rig",rig)


static func _pose(rig: Dictionary, key: String, angles: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	if not rig.has(key): return
	var entry: Dictionary = rig[key]
	var pivot: Node3D = entry.node
	var rest: Transform3D = entry.rest
	pivot.transform = Transform3D(rest.basis * Basis.from_euler(angles),rest.origin + offset)


static func animate_character(root: Node3D, id: String, time: float, moving: float = 0.0, punch: float = 0.0) -> void:
	## moving is 0..1; hands punch is elapsed swing phase, Lurch punch is windup.
	## Owner supplies active simulation time so pauses also pause gestures.
	if not root.has_meta("character_rig"): return
	var rig: Dictionary = root.get_meta("character_rig")
	var walk := clampf(moving,0.0,1.0)
	var strike := clampf(punch,0.0,1.0)
	var breath := sin(time*1.55)
	var gait := sin(time*7.5)*walk
	if id == "player_hands":
		strike = sin(strike*PI)
		_pose(rig,"left_arm",Vector3(0.02*breath,0,0.035*gait),Vector3(0,0.006*breath+0.01*gait,0))
		_pose(rig,"right_arm",Vector3(-0.22*strike,0.13*strike,-0.12*strike-0.025*gait),Vector3(-0.075*strike,0.07*strike-0.008*gait,-0.28*strike))
		return
	if id in ["possum","brutus"]:
		var gait_scale := 0.38 if id == "possum" else 0.22
		_pose(rig,"front_left",Vector3(gait*gait_scale,0,0))
		_pose(rig,"back_right",Vector3(gait*gait_scale,0,0))
		_pose(rig,"front_right",Vector3(-gait*gait_scale,0,0))
		_pose(rig,"back_left",Vector3(-gait*gait_scale,0,0))
		_pose(rig,"head",Vector3(0.018*breath,0.035*sin(time*0.7),0))
		_pose(rig,"tail",Vector3(0,0.08*sin(time*1.4),0))
		if id == "brutus":
			_pose(rig,"jaw",Vector3(0.02+0.025*(breath+1.0),0,0))
		return
	_pose(rig,"left_leg",Vector3(0.32*gait,0,0))
	_pose(rig,"right_leg",Vector3(-0.32*gait,0,0))
	_pose(rig,"left_arm",Vector3(-0.17*gait,0,0.009*breath))
	_pose(rig,"right_arm",Vector3(0.17*gait-0.65*strike,0,-0.009*breath))
	_pose(rig,"head",Vector3(0.008*breath,0.018*sin(time*0.6),0))
	match id:
		"tony":
			# The eyes never change. Only a slow head turn and a reluctant weight shift.
			_pose(rig,"head",Vector3(0,0.025*sin(time*0.33),0.008*breath))
		"pete":
			var bite := pow(maxf(0.0,sin(time*0.57)),6.0)
			_pose(rig,"right_arm",Vector3(-0.35*bite,0,-0.10*bite))
			_pose(rig,"right_arm/forearm",Vector3(-0.68*bite,0,0))
			_pose(rig,"head",Vector3(0.10*bite,0.01*breath,0))
		"yuri":
			_pose(rig,"head",Vector3(0.02+0.018*breath,0.045*sin(time*0.31),0))
			_pose(rig,"left_arm",Vector3(-0.035+0.02*breath,0,-0.025))
		"lurch":
			_pose(rig,"head",Vector3(-0.025,0.04*sin(time*0.71),0.045+0.012*breath))
			_pose(rig,"right_arm",Vector3(0.23*gait-0.85*strike,0.06,0.025))


static func _node(parent: Node3D, node_name: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = at
	parent.add_child(pivot)
	return pivot


static func _instance(parent: Node3D, mesh: Mesh, at: Vector3, color: String, node_name: String = "") -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _mat(color)
	part.position = at
	if not node_name.is_empty(): part.name = node_name
	parent.add_child(part)
	return part


static func _box(parent: Node3D, at: Vector3, size: Vector3, color: String, node_name: String = "") -> MeshInstance3D:
	var key := "box:" + str(size)
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _instance(parent, _meshes[key] as Mesh, at, color, node_name)


static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	# Normals point out; clockwise order matches Godot's front-face convention.
	for vertex in [c, b, a]:
		st.set_normal(normal)
		st.add_vertex(vertex)


static func _loft(rings: Array[Vector3], sides: int = 8, offset: float = 0.0) -> ArrayMesh:
	# Each ring stores (half-width, height, half-depth). Flat triangle normals.
	var key := "loft:" + str(rings) + ":" + str(sides) + ":" + str(offset)
	if _meshes.has(key): return _meshes[key] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(rings.size() - 1):
		var lower: Vector3 = rings[level]
		var upper: Vector3 = rings[level + 1]
		for i in range(sides):
			var angle_a := offset + TAU * float(i) / float(sides)
			var angle_b := offset + TAU * float(i + 1) / float(sides)
			var a := Vector3(sin(angle_a) * lower.x, lower.y, cos(angle_a) * lower.z)
			var b := Vector3(sin(angle_b) * lower.x, lower.y, cos(angle_b) * lower.z)
			var c := Vector3(sin(angle_a) * upper.x, upper.y, cos(angle_a) * upper.z)
			var d := Vector3(sin(angle_b) * upper.x, upper.y, cos(angle_b) * upper.z)
			_triangle(st, a, b, c)
			_triangle(st, b, d, c)
	var result := st.commit()
	_meshes[key] = result
	return result


static func _oval(parent: Node3D, at: Vector3, size: Vector3, color: String, node_name: String = "") -> MeshInstance3D:
	var rings: Array[Vector3] = [
		Vector3(0, -size.y, 0),
		Vector3(size.x * 0.68, -size.y * 0.65, size.z * 0.68),
		Vector3(size.x, 0, size.z),
		Vector3(size.x * 0.68, size.y * 0.65, size.z * 0.68),
		Vector3(0, size.y, 0),
	]
	return _instance(parent, _loft(rings), at, color, node_name)


static func _taper(parent: Node3D, at: Vector3, height: float, base: Vector2, top: Vector2, color: String, node_name: String = "") -> MeshInstance3D:
	var rings: Array[Vector3] = [
		Vector3(0, 0, 0), Vector3(base.x, 0, base.y),
		Vector3(top.x, height, top.y), Vector3(0, height, 0),
	]
	return _instance(parent, _loft(rings), at, color, node_name)


static func _between(parent: Node3D, a: Vector3, b: Vector3, radius_a: float, radius_b: float, color: String, node_name: String = "") -> MeshInstance3D:
	var delta := b - a
	var part := _taper(parent, a, delta.length(), Vector2(radius_a, radius_a), Vector2(radius_b, radius_b), color, node_name)
	part.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return part


static func _wedge(parent: Node3D, points: Array[Vector3], color: String, node_name: String = "") -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Tetrahedron: the front tip gives noses and lapels an actual silhouette.
	_triangle(st, points[0], points[1], points[2])
	_triangle(st, points[0], points[3], points[1])
	_triangle(st, points[1], points[3], points[2])
	_triangle(st, points[2], points[3], points[0])
	return _instance(parent, st.commit(), Vector3.ZERO, color, node_name)


static func _head(parent: Node3D, at: Vector3, skin: String, scale_value: Vector3 = Vector3.ONE, eye_height: float = 0.045) -> Node3D:
	var head := _node(parent, "head", at)
	head.scale = scale_value
	var rings: Array[Vector3] = [Vector3(0,-0.25,0), Vector3(0.105,-0.22,0.105), Vector3(0.165,-0.15,0.145), Vector3(0.195,-0.04,0.171), Vector3(0.202,0.055,0.18), Vector3(0.192,0.16,0.17), Vector3(0.14,0.235,0.13), Vector3(0,0.27,0)]
	_instance(head, _loft(rings,12,PI/12.0), Vector3.ZERO, skin, "face")
	# The loft carries the cheek and chin silhouette. Overlaying separate cheek
	# ovals made discs on the face; keep the front continuous and detail only folds.
	for side in [-1.0, 1.0]:
		_oval(head,Vector3(side*0.196,-0.018,-0.005),Vector3(0.047,0.081,0.045),skin,"ear")
		_oval(head,Vector3(side*0.225,-0.016,0.018),Vector3(0.018,0.046,0.019),SKIN_SHADE,"ear_fold")
		_oval(head,Vector3(side*0.085,eye_height,0.169),Vector3(0.050,0.024,0.013),SKIN_SHADE,"eye_socket")
		_oval(head,Vector3(side*0.085,eye_height,0.179),Vector3(0.040,0.014,0.008),CREAM,"eye")
		_oval(head,Vector3(side*0.077,eye_height-0.002,0.186),Vector3(0.011,0.013,0.004),"675b32","iris")
		_oval(head,Vector3(side*0.077,eye_height-0.002,0.190),Vector3(0.006,0.009,0.002),DARK,"pupil")
		_between(head,Vector3(side*0.042,eye_height+0.015,0.179),Vector3(side*0.124,eye_height+0.009,0.165),0.008,0.006,skin,"upper_lid")
		_between(head,Vector3(side*0.045,eye_height-0.020,0.177),Vector3(side*0.123,eye_height-0.022,0.163),0.004,0.003,SKIN_SHADE,"eye_bag")
		var brow := _box(head,Vector3(side*0.087,eye_height+0.038,0.18),Vector3(0.087,0.016,0.024),HAIR,"brow")
		brow.rotation.z = side*0.06
	# A narrow bridge, a broad tip, two nostril wings; not an isolated triangular spike.
	_wedge(head,[Vector3(-0.025,0.10,0.166),Vector3(0.025,0.10,0.166),Vector3(0,-0.045,0.257),Vector3(0,-0.062,0.17)],skin,"nose_bridge")
	_oval(head,Vector3(0,-0.045,0.235),Vector3(0.035,0.025,0.024),skin,"nose_tip")
	for side in [-1.0,1.0]:
		_oval(head,Vector3(side*0.025,-0.055,0.203),Vector3(0.020,0.015,0.019),skin,"nose_wing")
		_oval(head,Vector3(side*0.023,-0.066,0.218),Vector3(0.009,0.005,0.006),SKIN_SHADE,"nostril")
	_wedge(head,[Vector3(-0.054,-0.121,0.153),Vector3(0.054,-0.121,0.153),Vector3(0,-0.126,0.174),Vector3(0,-0.112,0.155)],SKIN_SHADE,"upper_lip")
	_wedge(head,[Vector3(-0.048,-0.132,0.149),Vector3(0.048,-0.132,0.149),Vector3(0,-0.134,0.167),Vector3(0,-0.145,0.145)],skin,"lower_lip")
	_box(head,Vector3(0,-0.128,0.169),Vector3(0.087,0.004,0.004),"5a3d2e","mouth_line")
	return head


static func _leg(root: Node3D, side: float, hip: float, length: float, width: float, cloth: String, boot: String) -> Node3D:
	var leg := _node(root, "left_leg" if side < 0 else "right_leg", Vector3(side * width * 1.15, hip, 0))
	_between(leg, Vector3.ZERO, Vector3(side * 0.025,-length * 0.53,0.025), width, width * 0.83, cloth)
	_between(leg, Vector3(side * 0.025,-length * 0.53,0.025), Vector3(side * 0.04,-length,0), width * 0.83, width * 0.67, cloth)
	# Knee folds and a sewn outer seam. Boot upper, blunt toe, heel and worn sole.
	_between(leg,Vector3(side*width*0.73,-0.05,0.03),Vector3(side*(width*0.69+0.03),-length+0.03,0.05),0.007,0.006,"393328","trouser_seam")
	_box(leg,Vector3(side*0.03,-length*0.55,0.085),Vector3(width*1.3,0.018,0.018),"393328","knee_crease")
	_oval(leg, Vector3(side * 0.04,-length - 0.04,0.065), Vector3(width * 0.90,0.080,0.17), boot, "shoe")
	_oval(leg, Vector3(side * 0.04,-length - 0.052,0.145), Vector3(width * 0.92,0.061,0.104), boot, "shoe_toe")
	_box(leg, Vector3(side * 0.04,-length - 0.094,0.07), Vector3(width * 1.78,0.025,0.31), DARK,"sole")
	_box(leg,Vector3(side*0.04,-length-0.073,-0.025),Vector3(width*1.52,0.06,0.10),DARK,"heel")
	for lace in range(3):
		_box(leg,Vector3(side*0.04,-length+0.02-float(lace)*0.014,0.045+float(lace)*0.027),Vector3(width*1.10,0.009,0.008),"928263","lace")
	return leg


static func _arm(root: Node3D, side: float, shoulder: Vector3, length: float, width: float, cloth: String, skin: String) -> Node3D:
	var arm := _node(root, "left_arm" if side < 0 else "right_arm", shoulder)
	var elbow := Vector3(side * 0.055,-length * 0.53,0.015)
	_between(arm, Vector3.ZERO, elbow, width, width * 0.85, cloth)
	var forearm := _node(arm,"forearm",elbow)
	var wrist := Vector3(side*0.01,-length*0.47,0.03)
	_between(forearm,Vector3.ZERO,wrist,width*0.85,width*0.68,cloth)
	_between(forearm,wrist+Vector3(0,0.032,0),wrist-Vector3(0,0.005,0),width*0.71,width*0.71,cloth,"cuff")
	_between(arm,Vector3(side*width*0.82,-0.03,0.03),elbow+Vector3(side*width*0.70,0,0.03),0.005,0.005,"393328","sleeve_seam")
	_oval(forearm,wrist+Vector3(0,-0.055,0.008),Vector3(width*0.70,0.075,width*0.46),skin,"palm")
	for finger in range(4):
		var x := float(finger-2)*width*0.31+width*0.15
		var tip := wrist+Vector3(x,-0.137+absf(float(finger)-1.5)*0.009,0.027)
		_between(forearm,wrist+Vector3(x,-0.09,0.018),tip,width*0.16,width*0.13,skin,"finger")
	_between(forearm,wrist+Vector3(-side*width*0.55,-0.035,0.025),wrist+Vector3(-side*width*0.70,-0.08,0.045),width*0.19,width*0.16,skin,"thumb")
	return arm


static func _lapel(parent: Node3D, side: float, y: float, z: float, width: float, color: String) -> void:
	_wedge(parent, [Vector3(side * 0.06,y + 0.14,z),Vector3(side * width,y + 0.1,z - 0.04),Vector3(side * 0.075,y - 0.16,z + 0.05),Vector3(side * width,y + 0.03,z - 0.08)], color, "lapel")


static func _coat_shell(parent: Node3D, bottom: float, top: float, widths: Vector2, depths: Vector2, color: String, node_name: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Open down the front; the other coats remain genuinely visible through the gap.
	for index in range(12):
		var a0 := 0.48 + (TAU - 0.96) * float(index) / 12.0
		var a1 := 0.48 + (TAU - 0.96) * float(index + 1) / 12.0
		var a := Vector3(sin(a0)*widths.x,bottom,cos(a0)*depths.x)
		var b := Vector3(sin(a1)*widths.x,bottom,cos(a1)*depths.x)
		var c := Vector3(sin(a0)*widths.y,top,cos(a0)*depths.y)
		var d := Vector3(sin(a1)*widths.y,top,cos(a1)*depths.y)
		_triangle(st,a,b,c)
		_triangle(st,b,d,c)
	_instance(parent,st.commit(),Vector3.ZERO,color,node_name)


static func _tony(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,0.76,0.64,0.13,"393328","51432c")
	_taper(root,Vector3(0,0.72,0),0.70,Vector2(0.245,0.17),Vector2(0.28,0.18),"454c2e","coat_one")
	_coat_shell(root,0.61,1.40,Vector2(0.30,0.32),Vector2(0.20,0.21),"8c6b3b","coat_two")
	_coat_shell(root,0.39,1.42,Vector2(0.38,0.35),Vector2(0.27,0.245),"604020","coat_three")
	for side in [-1.0,1.0]:
		var arm := _arm(root,side,Vector3(side*0.34,1.39,0),0.62,0.13,"604020",SKIN_PALE)
		var cuff := arm.get_node("forearm") as Node3D
		_box(cuff,Vector3(0,-0.265,0.116),Vector3(0.105,0.032,0.02),"8c6b3b","second_cuff")
		_oval(cuff,Vector3(side*0.045,-0.25,0.115),Vector3(0.012,0.014,0.009),"b29a56","cuff_button")
		_lapel(root,side,1.34,0.24,0.30,"946b3c")
		_lapel(root,side,1.31,0.255,0.19,"b08e4e")
		_lapel(root,side,1.25,0.26,0.105,"69703e")
		_box(root,Vector3(side*0.27,0.77,0.235),Vector3(0.13,0.045,0.027),"3e2c1c")
		_box(root,Vector3(side*0.275,0.70,0.238),Vector3(0.12,0.10,0.014),"694725","pocket_panel")
		_between(root,Vector3(side*0.178,0.43,0.236),Vector3(side*0.164,1.19,0.217),0.007,0.006,"946b3c","coat_seam")
		_between(root,Vector3(side*0.06,0.76,0.18),Vector3(side*0.06,1.21,0.18),0.005,0.005,"69703e","inner_coat_seam")
	for y in [1.13,0.99,0.85]:
		_oval(root,Vector3(0,y,0.177),Vector3(0.021,0.025,0.012),"b29a56")
	_taper(root,Vector3(0,1.39,0),0.17,Vector2(0.09,0.09),Vector2(0.09,0.09),SKIN_SHADE)
	var head := _head(root,Vector3(0,1.69,0.025),SKIN_PALE,Vector3(0.96,0.96,1.0),0.04)
	# Receding hair and the two committed eyebrows; there is no blink animation.
	_oval(head,Vector3(0,0.18,-0.063),Vector3(0.193,0.095,0.14),HAIR)
	_box(head,Vector3(-0.175,0.064,-0.02),Vector3(0.04,0.13,0.13),HAIR)
	_box(head,Vector3(0.175,0.064,-0.02),Vector3(0.04,0.13,0.13),HAIR)
	_box(head,Vector3(0,-0.087,0.183),Vector3(0.12,0.022,0.014),HAIR,"moustache")
	for y in [0.126,0.151]:
		_box(head,Vector3(0,y,0.174),Vector3(0.11,0.005,0.005),"9a784f","forehead_line")
	_between(head,Vector3(-0.14,-0.09,0.146),Vector3(-0.10,-0.148,0.163),0.004,0.004,SKIN_SHADE,"cheek_line")
	_box(root,Vector3(0,0.91,-0.257),Vector3(0.56,0.053,0.018),"4e341f","coat_half_belt")
	root.set_meta("height",1.96)


static func _pete(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,0.66,0.54,0.13,"424137","4b3727")
	var rings: Array[Vector3] = [Vector3(0,0.61,0),Vector3(0.28,0.63,0.19),Vector3(0.39,0.91,0.29),Vector3(0.34,1.19,0.23),Vector3(0.27,1.32,0.18),Vector3(0,1.34,0)]
	_instance(root,_loft(rings),Vector3.ZERO,"6b7048","shirt")
	for side in [-1.0,1.0]:
		var arm := _arm(root,side,Vector3(side*0.32,1.25,0),0.43,0.13,"6b7048",SKIN)
		arm.rotation.x = -0.55 if side > 0 else -0.35
		if side > 0:
			var forearm := arm.get_node("forearm") as Node3D
			forearm.rotation.x = -0.55
			var snack := _node(forearm,"hot_pocket",Vector3(0.012,-0.22,0.08))
			snack.rotation.z = -0.20
			_oval(snack,Vector3.ZERO,Vector3(0.069,0.136,0.047),"b18648","crust")
			_oval(snack,Vector3(0.01,0.115,0.015),Vector3(0.047,0.018,0.034),"755432","bite")
			_box(snack,Vector3(0,-0.09,0.035),Vector3(0.13,0.07,0.025),"a7a07a","sleeve")
			for offset in [-0.065,0.0,0.065]:
				_box(snack,Vector3(0,offset,0.047),Vector3(0.069,0.008,0.008),"755432")
	_taper(root,Vector3(0,1.29,0),0.14,Vector2(0.12,0.1),Vector2(0.1,0.09),SKIN)
	var head := _head(root,Vector3(0,1.52,0.015),SKIN,Vector3(1.1,0.84,1.0),0.03)
	_oval(head,Vector3(0,-0.14,0.105),Vector3(0.15,0.075,0.045),SKIN)
	# Square spectacles, with open centers so the eyes remain visible.
	for side in [-1.0,1.0]:
		for y in [0.001,0.085]: _box(head,Vector3(side*0.09,y,0.205),Vector3(0.12,0.012,0.012),HAIR)
		for x in [side*0.09-0.056,side*0.09+0.056]: _box(head,Vector3(x,0.044,0.205),Vector3(0.012,0.092,0.012),HAIR)
	_box(head,Vector3(0,0.053,0.207),Vector3(0.065,0.012,0.012),HAIR)
	_oval(head,Vector3(0,0.20,-0.07),Vector3(0.19,0.075,0.14),"5a4830")
	_box(root,Vector3(-0.16,1.15,0.235),Vector3(0.12,0.06,0.018),CREAM,"name_patch")
	_box(root,Vector3(-0.16,1.15,0.248),Vector3(0.075,0.008,0.005),"6b7048","patch_mark")
	_box(root,Vector3(0,1.03,0.292),Vector3(0.018,0.32,0.011),"4a4d35","shirt_placket")
	for y in [0.93,1.04,1.15]:
		_oval(root,Vector3(0,y,0.295),Vector3(0.008,0.008,0.007),"b3a06c","button")
	_lapel(root,-1.0,1.25,0.19,0.14,"7b8055")
	_lapel(root,1.0,1.25,0.19,0.14,"7b8055")
	root.set_meta("height",1.77)


static func _yuri(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,0.80,0.67,0.135,"48483a","493222")
	_taper(root,Vector3(0,0.72,0),0.70,Vector2(0.28,0.21),Vector2(0.34,0.20),"626348","work_jacket")
	_box(root,Vector3(0,1.08,0.212),Vector3(0.026,0.56,0.028),"38362b")
	for side in [-1.0,1.0]:
		_arm(root,side,Vector3(side*0.32,1.39,0),0.60,0.14,"626348",SKIN)
		_box(root,Vector3(side*0.20,1.19,0.203),Vector3(0.16,0.13,0.027),"4a4d35")
		_box(root,Vector3(side*0.20,1.25,0.225),Vector3(0.17,0.03,0.02),"777653","pocket_flap")
		_oval(root,Vector3(side*0.20,1.24,0.24),Vector3(0.012,0.012,0.006),"b3a06c","pocket_button")
		_box(root,Vector3(side*0.25,0.86,0.19),Vector3(0.12,0.02,0.018),"3a3628","lower_pocket")
		_between(root,Vector3(side*0.27,0.77,0.11),Vector3(side*0.29,1.33,0.12),0.006,0.006,"777653","jacket_seam")
	_oval(root,Vector3(0,1.43,0),Vector3(0.19,0.09,0.18),RUST,"scarf")
	_box(root,Vector3(0.105,1.24,0.248),Vector3(0.10,0.29,0.028),RUST,"scarf_end")
	for x in [0.066,0.088,0.11,0.132]:
		_between(root,Vector3(x,1.10,0.247),Vector3(x+0.002,1.07,0.247),0.003,0.003,RUST,"scarf_fringe")
	var head := _head(root,Vector3(0,1.70,0.02),SKIN,Vector3(1.02,1.00,1.0),0.045)
	_oval(head,Vector3(0,-0.17,0.08),Vector3(0.17,0.115,0.16),"656052","beard")
	_box(head,Vector3(0,-0.072,0.205),Vector3(0.15,0.045,0.035),"656052","moustache")
	_oval(head,Vector3(0,0.22,-0.02),Vector3(0.212,0.12,0.19),"4b4735","cap")
	_box(head,Vector3(0,0.20,0.172),Vector3(0.33,0.045,0.17),"3a3628","cap_peak")
	for side in [-1.0,1.0]:
		var brow := _box(head,Vector3(side*0.085,0.084,0.195),Vector3(0.10,0.025,0.025),"494132")
		brow.rotation.z = side*0.18
	for x in [-0.11,-0.055,0.0,0.055,0.11]:
		_between(head,Vector3(x,-0.10,0.21),Vector3(x*0.80,-0.23,0.16),0.010,0.006,"807968","beard_lock")
	_box(root,Vector3(0,0.77,0.211),Vector3(0.09,0.07,0.018),"87764c","belt_buckle")
	root.set_meta("height",2.02)


static func _lurch(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,1.01,0.89,0.092,"51473a","4a3426")
	_taper(root,Vector3(0,0.93,0),0.69,Vector2(0.18,0.12),Vector2(0.235,0.14),"6a5b48","shirt")
	_box(root,Vector3(-0.08,1.28,0.129),Vector3(0.11,0.16,0.026),"4b502c","patch")
	for side in [-1.0,1.0]:
		var arm := _arm(root,side,Vector3(side*0.24,1.59,0),0.88,0.082,"6a5b48",SKIN_PALE)
		arm.rotation.z = side*0.05
		if side > 0: arm.position.y -= 0.045
	_taper(root,Vector3(0,1.57,0.02),0.27,Vector2(0.073,0.07),Vector2(0.07,0.07),SKIN_PALE)
	var head := _head(root,Vector3(0,1.96,0.055),SKIN_PALE,Vector3(0.83,1.04,0.95),0.03)
	# Flat, badly separated hair clumps and a heavy downward mouth.
	_oval(head,Vector3(-0.015,0.20,-0.035),Vector3(0.19,0.09,0.16),"55402b")
	for x in [-0.12,-0.055,0.035,0.11]:
		_box(head,Vector3(x,0.17,0.155),Vector3(0.048,0.12,0.04),"55402b")
	_box(head,Vector3(0,-0.14,0.16),Vector3(0.095,0.025,0.012),"5c4032")
	_box(head,Vector3(0.02,-0.134,0.169),Vector3(0.023,0.022,0.006),"b3a06c","tooth")
	for side in [-1.0,1.0]:
		_between(head,Vector3(side*0.145,-0.05,0.145),Vector3(side*0.10,-0.12,0.174),0.006,0.004,SKIN_SHADE,"hollow_cheek")
		_box(root,Vector3(side*0.12,1.48,0.137),Vector3(0.012,0.22,0.014),"3e392d","suspender")
	for y in [1.05,1.21,1.37]:
		_oval(root,Vector3(0,y,0.142),Vector3(0.009,0.011,0.006),"a08c59","shirt_button")
	for x in [-0.13,-0.095,-0.06]:
		_between(root,Vector3(x,1.21,0.146),Vector3(x+0.015,1.25,0.146),0.0025,0.0025,CREAM,"patch_stitch")
	root.set_meta("height",2.24)


static func _possum(root: Node3D) -> void:
	_oval(root,Vector3(0,0.24,-0.04),Vector3(0.22,0.20,0.36),"777767","body")
	_oval(root,Vector3(0,0.17,-0.015),Vector3(0.19,0.125,0.30),"a29d7f","belly")
	for i in range(5):
		var z := -0.24+float(i)*0.085
		_wedge(root,[Vector3(-0.06,0.40,z),Vector3(0.06,0.40,z),Vector3(0,0.465,z-0.05),Vector3(0,0.39,z-0.075)],"676a5c","back_fur")
	var head := _node(root,"head",Vector3(0,0.29,0.26))
	_oval(head,Vector3.ZERO,Vector3(0.15,0.14,0.18),"c1b58c","face")
	_wedge(head,[Vector3(-0.13,0.02,0.05),Vector3(0.13,0.02,0.05),Vector3(0,-0.07,0.32),Vector3(0,-0.12,0.06)],"b5a77e","snout")
	_oval(head,Vector3(0,-0.055,0.29),Vector3(0.030,0.022,0.030),"765247","nose")
	_between(head,Vector3(-0.035,-0.084,0.255),Vector3(0.035,-0.084,0.255),0.003,0.003,"5a4c3f","mouth")
	for side in [-1.0,1.0]:
		_oval(head,Vector3(side*0.125,0.11,-0.04),Vector3(0.065,0.072,0.025),"443e35","ear")
		_oval(head,Vector3(side*0.126,0.113,-0.017),Vector3(0.037,0.043,0.009),"8f705b","ear_inset")
		_oval(head,Vector3(side*0.123,0.042,0.109),Vector3(0.028,0.026,0.021),DARK,"eye")
		_oval(head,Vector3(side*0.129,0.049,0.126),Vector3(0.006,0.007,0.003),CREAM,"eye_glint")
		for row in range(3):
			_between(head,Vector3(side*0.045,-0.05,0.24),Vector3(side*0.17,-0.047+float(row-1)*0.028,0.25-float(row)*0.018),0.0018,0.0008,"b5a77e","whisker")
		for z in [-0.23,0.18]:
			var limb_name := ("front_" if z > 0 else "back_")+("left" if side < 0 else "right")
			var leg := _node(root,limb_name,Vector3(side*0.16,0.22,z))
			_between(leg,Vector3.ZERO,Vector3(side*0.03,-0.165,0.03),0.038,0.027,"5f594b")
			_oval(leg,Vector3(side*0.03,-0.176,0.07),Vector3(0.052,0.025,0.065),"8f705b")
			for toe in range(3):
				_between(leg,Vector3(side*0.03+float(toe-1)*0.025,-0.178,0.08),Vector3(side*0.035+float(toe-1)*0.03,-0.184,0.13),0.008,0.004,"8f705b","toe")
	var tail := _node(root,"tail",Vector3(0,0.20,-0.33))
	var tail_points: Array[Vector3] = [Vector3.ZERO,Vector3(0.05,-0.06,-0.24),Vector3(0.17,-0.10,-0.45),Vector3(0.32,-0.10,-0.54),Vector3(0.43,-0.06,-0.50)]
	for i in range(tail_points.size()-1):
		_between(tail,tail_points[i],tail_points[i+1],0.033-float(i)*0.006,0.027-float(i)*0.006,"a08065")
	# The helmet is a real brim and faceted dome, not a yellow sphere.
	_taper(head,Vector3(0,0.124,0.005),0.025,Vector2(0.19,0.175),Vector2(0.19,0.175),"b99536","helmet_brim")
	_oval(head,Vector3(0,0.148,-0.01),Vector3(0.15,0.10,0.135),"e8c040","helmet")
	_box(head,Vector3(0,0.225,-0.005),Vector3(0.035,0.026,0.22),"b99536","helmet_ridge")
	_box(head,Vector3(-0.05,0.189,0.096),Vector3(0.06,0.029,0.007),CREAM,"helmet_sticker")
	_box(head,Vector3(-0.05,0.189,0.101),Vector3(0.031,0.004,0.004),"777767","sticker_mark")
	root.set_meta("height",0.55)


static func _brutus(root: Node3D) -> void:
	_oval(root,Vector3(0,0.43,-0.12),Vector3(0.24,0.31,0.45),"65432b","body")
	_oval(root,Vector3(0,0.49,0.25),Vector3(0.28,0.31,0.27),"805737","chest")
	_oval(root,Vector3(-0.015,0.51,-0.26),Vector3(0.225,0.23,0.27),"493222","saddle")
	var head := _node(root,"head",Vector3(0,0.69,0.44))
	_oval(head,Vector3.ZERO,Vector3(0.22,0.23,0.24),"704e34","skull")
	_oval(head,Vector3(0,-0.075,0.20),Vector3(0.16,0.108,0.20),"9d8b68","old_muzzle")
	_oval(head,Vector3(0,-0.06,0.36),Vector3(0.09,0.07,0.055),DARK,"nose")
	for side in [-1.0,1.0]:
		_oval(head,Vector3(side*0.045,-0.05,0.407),Vector3(0.014,0.012,0.006),"10120e","nostril")
	var jaw := _node(root,"jaw",Vector3(0,0.56,0.53))
	_oval(jaw,Vector3(0,-0.01,0.10),Vector3(0.123,0.053,0.15),"a29675","lower_jaw")
	_box(jaw,Vector3(0,0.032,0.14),Vector3(0.20,0.016,0.16),"453127","mouth")
	_oval(jaw,Vector3(0.025,0.026,0.205),Vector3(0.038,0.012,0.057),"946951","tongue")
	for side in [-1.0,1.0]:
		var ear := _node(head,"left_ear" if side < 0 else "right_ear",Vector3(side*0.19,-0.03,-0.05))
		ear.rotation.z = side*0.30
		_oval(ear,Vector3.ZERO,Vector3(0.09,0.19,0.07),"493222","ear")
		_oval(ear,Vector3(0,-0.02,0.058),Vector3(0.047,0.115,0.016),"805737","ear_fold")
		_oval(head,Vector3(side*0.143,0.055,0.176),Vector3(0.04,0.033,0.022),"b2ae8c" if side < 0 else "30291d","eye")
		_oval(head,Vector3(side*0.143,0.098,0.158),Vector3(0.06,0.027,0.022),"9d8b68","grey_brow")
		for spot in range(3):
			_oval(head,Vector3(side*(0.09+float(spot)*0.015),-0.07,0.29-float(spot)*0.03),Vector3(0.005,0.005,0.003),"5b4a35","muzzle_dot")
		for z in [-0.40,0.27]:
			var limb_name := ("front_" if z > 0 else "back_")+("left" if side < 0 else "right")
			var leg := _node(root,limb_name,Vector3(side*0.16,0.43,z))
			_between(leg,Vector3.ZERO,Vector3(side*0.03,-0.335,0.035),0.07,0.055,"704e34")
			_oval(leg,Vector3(side*0.03,-0.355,0.09),Vector3(0.085,0.065,0.125),"9d8b68","paw")
			for toe in range(3):
				_oval(leg,Vector3(side*0.03+float(toe-1)*0.038,-0.375,0.171),Vector3(0.018,0.017,0.032),"b0a181","claw")
	var tail := _node(root,"tail",Vector3(0,0.51,-0.49))
	_between(tail,Vector3.ZERO,Vector3(0.09,0.13,-0.28),0.065,0.035,"65432b")
	_between(tail,Vector3(0.09,0.13,-0.28),Vector3(0.13,0.08,-0.38),0.035,0.013,"493222")
	_taper(root,Vector3(0,0.49,0.39),0.09,Vector2(0.237,0.19),Vector2(0.237,0.19),RUST,"collar")
	_oval(root,Vector3(0,0.46,0.60),Vector3(0.045,0.06,0.02),"b19b5d","tag")
	root.set_meta("height",0.95)


static func _hands(root: Node3D) -> void:
	# Attach directly under Camera3D, local origin zero. Camera faces -Z.
	# Lean, slightly uneven fingers close over a palm; the first slice's round mitts
	# were too large and hid the curb. Knuckles are anatomy, not separate beads.
	for side in [-1.0,1.0]:
		var hand := _node(root,"left_arm" if side < 0 else "right_arm",Vector3(side*0.275,-0.385,-0.50))
		hand.rotation.z = -side*0.07
		_between(hand,Vector3(side*0.045,-0.28,0.22),Vector3(0,-0.045,-0.015),0.10,0.069,MOLD,"sleeve")
		_between(hand,Vector3(0,-0.045,-0.015),Vector3(0,-0.005,-0.06),0.071,0.068,"555d34","cuff")
		for seam in range(5):
			_between(hand,Vector3(-0.05+float(seam)*0.025,-0.039,-0.032),Vector3(-0.045+float(seam)*0.022,-0.006,-0.065),0.0025,0.0025,"394027","cuff_rib")
		_between(hand,Vector3(side*0.071,-0.20,0.14),Vector3(side*0.056,-0.049,-0.014),0.004,0.004,"6d7043","sleeve_seam")
		_oval(hand,Vector3(0,0.008,-0.073),Vector3(0.059,0.06,0.043),SKIN,"wrist")
		var palm_rings: Array[Vector3] = [Vector3(0,-0.05,0),Vector3(0.045,-0.05,0.031),Vector3(0.068,-0.012,0.038),Vector3(0.069,0.033,0.037),Vector3(0.059,0.045,0.032),Vector3(0,0.045,0)]
		var palm := _instance(hand,_loft(palm_rings,12),Vector3(0,0.045,-0.11),SKIN_PALE,"palm")
		palm.rotation.x = -0.18
		for finger in range(4):
			var x := -0.051+float(finger)*0.034
			var height := 0.098-absf(float(finger)-1.2)*0.007
			var knuckle := Vector3(x,height,-0.135)
			_between(hand,Vector3(x,0.062,-0.106),knuckle,0.018,0.018,SKIN_PALE,"finger_back")
			_between(hand,knuckle,Vector3(x,height-0.028,-0.17),0.018,0.016,SKIN_PALE,"finger_middle")
			_between(hand,Vector3(x,height-0.028,-0.17),Vector3(x,0.035,-0.15),0.017,0.014,SKIN_PALE,"finger_curl")
			_box(hand,Vector3(x,height-0.017,-0.174),Vector3(0.023,0.008,0.003),SKIN_SHADE,"finger_fold")
		_between(hand,Vector3(-side*0.052,0.025,-0.107),Vector3(-side*0.067,0.045,-0.137),0.025,0.022,SKIN_PALE,"thumb_base")
		_between(hand,Vector3(-side*0.067,0.045,-0.137),Vector3(-side*0.030,0.058,-0.163),0.022,0.019,SKIN_PALE,"thumb")
		_box(hand,Vector3(-side*0.034,0.063,-0.175),Vector3(0.024,0.012,0.004),"b3a077","thumbnail")
		_between(hand,Vector3(-0.025,0.02,-0.15),Vector3(0.024,0.01,-0.145),0.002,0.002,SKIN_SHADE,"palm_crease")
