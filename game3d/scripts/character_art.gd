class_name SliceCharacterArt
extends RefCounted
## Original, source-authored low-poly cast. Y up, feet at zero, faces toward +Z.
## All geometry/materials are built or fetched once when an actor is constructed.
## The named limb/head pivots are available to the owning actor's animation code.

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

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
	return root


static func _mat(hex: String) -> StandardMaterial3D:
	if _materials.has(hex):
		return _materials[hex] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(hex)
	material.roughness = 0.94
	# Two-sided surfaces allow genuinely thin lapels, ears and cloth hems.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[hex] = material
	return material


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
	var rings: Array[Vector3] = [Vector3(0,-0.25,0), Vector3(0.12,-0.21,0.13), Vector3(0.18,-0.11,0.17), Vector3(0.205,0.035,0.19), Vector3(0.19,0.16,0.17), Vector3(0.12,0.25,0.11), Vector3(0,0.27,0)]
	_instance(head, _loft(rings), Vector3.ZERO, skin, "face")
	_oval(head, Vector3(-0.202, -0.015, -0.005), Vector3(0.042,0.075,0.04), skin)
	_oval(head, Vector3(0.202, -0.015, -0.005), Vector3(0.042,0.075,0.04), skin)
	for side in [-1.0, 1.0]:
		_box(head, Vector3(side * 0.087, eye_height, 0.172), Vector3(0.078,0.031,0.025), CREAM, "eye")
		_box(head, Vector3(side * 0.079, eye_height - 0.002, 0.188), Vector3(0.018,0.028,0.012), DARK)
		_box(head, Vector3(side * 0.085, eye_height + 0.026, 0.183), Vector3(0.09,0.025,0.028), SKIN_SHADE, "brow")
		_box(head, Vector3(side * 0.088, eye_height - 0.027, 0.177), Vector3(0.084,0.015,0.024), SKIN_SHADE)
	_wedge(head, [Vector3(-0.038,0.07,0.17),Vector3(0.038,0.07,0.17),Vector3(0,-0.065,0.30),Vector3(0,-0.07,0.165)], skin, "nose")
	_box(head, Vector3(0,-0.13,0.164), Vector3(0.116,0.014,0.022), SKIN_SHADE, "mouth")
	return head


static func _leg(root: Node3D, side: float, hip: float, length: float, width: float, cloth: String, boot: String) -> Node3D:
	var leg := _node(root, "left_leg" if side < 0 else "right_leg", Vector3(side * width * 1.15, hip, 0))
	_between(leg, Vector3.ZERO, Vector3(side * 0.025,-length * 0.53,0.025), width, width * 0.83, cloth)
	_between(leg, Vector3(side * 0.025,-length * 0.53,0.025), Vector3(side * 0.04,-length,0), width * 0.83, width * 0.67, cloth)
	_oval(leg, Vector3(side * 0.04,-length - 0.045,0.07), Vector3(width * 0.95,0.085,0.19), boot, "shoe")
	_box(leg, Vector3(side * 0.04,-length - 0.088,0.07), Vector3(width * 1.8,0.035,0.28), DARK)
	return leg


static func _arm(root: Node3D, side: float, shoulder: Vector3, length: float, width: float, cloth: String, skin: String) -> Node3D:
	var arm := _node(root, "left_arm" if side < 0 else "right_arm", shoulder)
	var elbow := Vector3(side * 0.055,-length * 0.53,0.015)
	var wrist := Vector3(side * 0.065,-length,0.045)
	_between(arm, Vector3.ZERO, elbow, width, width * 0.85, cloth)
	_between(arm, elbow, wrist, width * 0.85, width * 0.68, cloth)
	_oval(arm, wrist + Vector3(0,-0.065,0), Vector3(width * 0.8,0.105,width * 0.68), skin, "hand")
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
		_arm(root,side,Vector3(side*0.34,1.39,0),0.62,0.13,"604020",SKIN_PALE)
		_lapel(root,side,1.34,0.24,0.30,"946b3c")
		_lapel(root,side,1.31,0.255,0.19,"b08e4e")
		_lapel(root,side,1.25,0.26,0.105,"69703e")
		_box(root,Vector3(side*0.27,0.77,0.235),Vector3(0.13,0.045,0.027),"3e2c1c")
	for y in [1.13,0.99,0.85]:
		_oval(root,Vector3(0,y,0.177),Vector3(0.021,0.025,0.012),"b29a56")
	_taper(root,Vector3(0,1.39,0),0.17,Vector2(0.09,0.09),Vector2(0.09,0.09),SKIN_SHADE)
	var head := _head(root,Vector3(0,1.69,0.025),SKIN_PALE,Vector3(0.96,0.96,1.0),0.04)
	# Receding hair and the two committed eyebrows; there is no blink animation.
	_oval(head,Vector3(0,0.18,-0.063),Vector3(0.193,0.095,0.14),HAIR)
	_box(head,Vector3(-0.175,0.064,-0.02),Vector3(0.04,0.13,0.13),HAIR)
	_box(head,Vector3(0.175,0.064,-0.02),Vector3(0.04,0.13,0.13),HAIR)
	_box(head,Vector3(0,-0.087,0.207),Vector3(0.12,0.022,0.019),HAIR,"moustache")
	root.set_meta("height",1.96)


static func _pete(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,0.66,0.54,0.13,"424137","4b3727")
	var rings: Array[Vector3] = [Vector3(0,0.61,0),Vector3(0.28,0.63,0.19),Vector3(0.39,0.91,0.29),Vector3(0.34,1.19,0.23),Vector3(0.27,1.32,0.18),Vector3(0,1.34,0)]
	_instance(root,_loft(rings),Vector3.ZERO,"6b7048","shirt")
	for side in [-1.0,1.0]:
		var arm := _arm(root,side,Vector3(side*0.32,1.25,0),0.43,0.13,"6b7048",SKIN)
		arm.rotation.x = -0.65 if side > 0 else -0.35
		if side > 0:
			var snack := _oval(arm,Vector3(0.07,-0.48,0.09),Vector3(0.075,0.15,0.055),"b18648","hot_pocket")
			snack.rotation.z = -0.25
			for offset in [-0.065,0.0,0.065]:
				_box(arm,Vector3(0.07,-0.48+offset,0.145),Vector3(0.073,0.015,0.01),"755432")
	_taper(root,Vector3(0,1.29,0),0.14,Vector2(0.12,0.1),Vector2(0.1,0.09),SKIN)
	var head := _head(root,Vector3(0,1.52,0.015),SKIN,Vector3(1.1,0.84,1.0),0.03)
	_oval(head,Vector3(0,-0.14,0.135),Vector3(0.15,0.075,0.095),SKIN)
	# Square spectacles, with open centers so the eyes remain visible.
	for side in [-1.0,1.0]:
		for y in [0.001,0.085]: _box(head,Vector3(side*0.09,y,0.205),Vector3(0.12,0.012,0.012),HAIR)
		for x in [side*0.09-0.056,side*0.09+0.056]: _box(head,Vector3(x,0.044,0.205),Vector3(0.012,0.092,0.012),HAIR)
	_box(head,Vector3(0,0.053,0.207),Vector3(0.065,0.012,0.012),HAIR)
	_oval(head,Vector3(0,0.20,-0.07),Vector3(0.19,0.075,0.14),"5a4830")
	_box(root,Vector3(-0.16,1.15,0.235),Vector3(0.12,0.06,0.018),CREAM,"name_patch")
	root.set_meta("height",1.77)


static func _yuri(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,0.80,0.67,0.135,"48483a","493222")
	_taper(root,Vector3(0,0.72,0),0.70,Vector2(0.28,0.21),Vector2(0.34,0.20),"626348","work_jacket")
	_box(root,Vector3(0,1.08,0.212),Vector3(0.026,0.56,0.028),"38362b")
	for side in [-1.0,1.0]:
		_arm(root,side,Vector3(side*0.32,1.39,0),0.60,0.14,"626348",SKIN)
		_box(root,Vector3(side*0.20,1.19,0.203),Vector3(0.16,0.13,0.027),"4a4d35")
	_oval(root,Vector3(0,1.43,0),Vector3(0.19,0.09,0.18),RUST,"scarf")
	_box(root,Vector3(0.105,1.24,0.248),Vector3(0.10,0.29,0.028),RUST,"scarf_end")
	var head := _head(root,Vector3(0,1.70,0.02),SKIN,Vector3(1.02,1.00,1.0),0.045)
	_oval(head,Vector3(0,-0.17,0.08),Vector3(0.17,0.115,0.16),"656052","beard")
	_box(head,Vector3(0,-0.072,0.205),Vector3(0.15,0.045,0.035),"656052","moustache")
	_oval(head,Vector3(0,0.22,-0.02),Vector3(0.212,0.12,0.19),"4b4735","cap")
	_box(head,Vector3(0,0.20,0.172),Vector3(0.33,0.045,0.17),"3a3628","cap_peak")
	for side in [-1.0,1.0]:
		var brow := _box(head,Vector3(side*0.085,0.084,0.195),Vector3(0.10,0.025,0.025),"494132")
		brow.rotation.z = side*0.18
	root.set_meta("height",2.02)


static func _lurch(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,1.01,0.89,0.092,"51473a","4a3426")
	_taper(root,Vector3(0,0.93,0),0.69,Vector2(0.18,0.12),Vector2(0.235,0.14),"6a5b48","shirt")
	_box(root,Vector3(-0.08,1.28,0.129),Vector3(0.11,0.16,0.026),"4b502c","patch")
	for side in [-1.0,1.0]:
		var arm := _arm(root,side,Vector3(side*0.24,1.59,0),0.88,0.082,"6a5b48",SKIN_PALE)
		arm.rotation.z = side*0.05
	_taper(root,Vector3(0,1.57,0.02),0.27,Vector2(0.073,0.07),Vector2(0.07,0.07),SKIN_PALE)
	var head := _head(root,Vector3(0,1.96,0.055),SKIN_PALE,Vector3(0.83,1.04,0.95),0.03)
	# Flat, badly separated hair clumps and a heavy downward mouth.
	_oval(head,Vector3(-0.015,0.20,-0.035),Vector3(0.19,0.09,0.16),"55402b")
	for x in [-0.12,-0.055,0.035,0.11]:
		_box(head,Vector3(x,0.17,0.155),Vector3(0.048,0.12,0.04),"55402b")
	_box(head,Vector3(0,-0.14,0.175),Vector3(0.095,0.025,0.016),"5c4032")
	_box(head,Vector3(0.02,-0.134,0.188),Vector3(0.023,0.022,0.008),"b3a06c","tooth")
	root.set_meta("height",2.24)


static func _possum(root: Node3D) -> void:
	_oval(root,Vector3(0,0.24,-0.04),Vector3(0.22,0.20,0.36),"777767","body")
	_oval(root,Vector3(0,0.29,0.26),Vector3(0.15,0.14,0.18),"c1b58c","head")
	_wedge(root,[Vector3(-0.13,0.31,0.31),Vector3(0.13,0.31,0.31),Vector3(0,0.22,0.58),Vector3(0,0.17,0.32)],"b5a77e","snout")
	_oval(root,Vector3(0,0.235,0.55),Vector3(0.035,0.027,0.032),"765247","nose")
	for side in [-1.0,1.0]:
		_oval(root,Vector3(side*0.125,0.40,0.22),Vector3(0.065,0.072,0.025),"443e35","ear")
		_oval(root,Vector3(side*0.123,0.332,0.369),Vector3(0.028,0.026,0.021),DARK,"eye")
		for z in [-0.23,0.18]:
			_between(root,Vector3(side*0.16,0.22,z),Vector3(side*0.19,0.055,z+0.03),0.038,0.027,"5f594b")
			_oval(root,Vector3(side*0.19,0.044,z+0.07),Vector3(0.052,0.025,0.07),"8f705b")
	var tail_points: Array[Vector3] = [Vector3(0,0.20,-0.33),Vector3(0.05,0.14,-0.57),Vector3(0.17,0.10,-0.78),Vector3(0.32,0.10,-0.87),Vector3(0.43,0.14,-0.83)]
	for i in range(tail_points.size()-1):
		_between(root,tail_points[i],tail_points[i+1],0.033-float(i)*0.006,0.027-float(i)*0.006,"a08065","tail")
	# The helmet is a real brim and faceted dome, not a yellow sphere.
	_taper(root,Vector3(0,0.414,0.265),0.025,Vector2(0.19,0.175),Vector2(0.19,0.175),"b99536","helmet_brim")
	_oval(root,Vector3(0,0.438,0.25),Vector3(0.15,0.10,0.135),"e8c040","helmet")
	_box(root,Vector3(0,0.515,0.255),Vector3(0.035,0.026,0.22),"b99536","helmet_ridge")
	root.set_meta("height",0.55)


static func _brutus(root: Node3D) -> void:
	_oval(root,Vector3(0,0.43,-0.12),Vector3(0.24,0.31,0.45),"65432b","body")
	_oval(root,Vector3(0,0.49,0.25),Vector3(0.28,0.31,0.27),"805737","chest")
	_oval(root,Vector3(0,0.69,0.44),Vector3(0.22,0.23,0.24),"704e34","head")
	_oval(root,Vector3(0,0.60,0.64),Vector3(0.16,0.13,0.20),"9d8b68","old_muzzle")
	_oval(root,Vector3(0,0.63,0.80),Vector3(0.09,0.07,0.055),DARK,"nose")
	for side in [-1.0,1.0]:
		var ear := _oval(root,Vector3(side*0.19,0.66,0.39),Vector3(0.09,0.19,0.07),"493222","ear")
		ear.rotation.z = side*0.30
		_oval(root,Vector3(side*0.143,0.745,0.616),Vector3(0.04,0.033,0.022),"b2ae8c" if side < 0 else "30291d","eye")
		for z in [-0.40,0.27]:
			_between(root,Vector3(side*0.16,0.43,z),Vector3(side*0.19,0.095,z+0.035),0.07,0.055,"704e34")
			_oval(root,Vector3(side*0.19,0.075,z+0.09),Vector3(0.085,0.065,0.125),"9d8b68","paw")
	_between(root,Vector3(0,0.51,-0.49),Vector3(0.09,0.64,-0.77),0.065,0.035,"65432b","tail")
	_taper(root,Vector3(0,0.49,0.39),0.09,Vector2(0.237,0.19),Vector2(0.237,0.19),RUST,"collar")
	_oval(root,Vector3(0,0.46,0.60),Vector3(0.045,0.06,0.02),"b19b5d","tag")
	root.set_meta("height",0.95)


static func _hands(root: Node3D) -> void:
	# Attach directly under Camera3D, local origin zero. Camera faces -Z.
	# Root can animate right_arm.position.z for the punch, keeping original pose as rest.
	for side in [-1.0,1.0]:
		var hand := _node(root,"left_arm" if side < 0 else "right_arm",Vector3(side*0.30,-0.37,-0.48))
		_between(hand,Vector3(side*0.045,-0.28,0.22),Vector3(0,-0.035,-0.02),0.105,0.075,MOLD,"sleeve")
		_between(hand,Vector3(0,-0.035,-0.02),Vector3(0,0.005,-0.065),0.078,0.078,"6d7043","cuff")
		var fist := _oval(hand,Vector3(0,0.038,-0.10),Vector3(0.085,0.095,0.075),SKIN_PALE,"fist")
		fist.rotation.z = -side*0.15
		for x in [-0.048,-0.016,0.016,0.048]:
			_oval(hand,Vector3(x,0.095,-0.126),Vector3(0.021,0.026,0.023),SKIN_PALE,"knuckle")
		_oval(hand,Vector3(-side*0.068,0.01,-0.115),Vector3(0.03,0.055,0.04),SKIN,"thumb")
