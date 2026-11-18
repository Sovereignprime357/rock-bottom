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


static func _sculpt_mesh(rings: Array[PackedVector3Array], softness: float = 0.75, cap_ends: bool = true) -> ArrayMesh:
	# Authored cross-sections carry the silhouette. Weighted normals soften broad
	# surfaces while retaining a small plane break; separate caps stay deliberately flat.
	var key := "sculpt:" + str(rings) + ":" + str(softness) + ":" + str(cap_ends)
	if _meshes.has(key): return _meshes[key] as ArrayMesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var faces: Array[Vector3i] = []
	var count := rings[0].size()
	for ring in rings:
		for point in ring: vertices.append(point)
	normals.resize(vertices.size())
	for row in range(rings.size()-1):
		for column in range(count):
			var a := row*count+column
			var b := row*count+(column+1)%count
			var c := (row+1)*count+column
			var d := (row+1)*count+(column+1)%count
			for face in [Vector3i(a,b,c),Vector3i(b,d,c)]:
				var normal := (vertices[face.y]-vertices[face.x]).cross(vertices[face.z]-vertices[face.x])
				if normal.length_squared() < 0.0000000001: continue
				faces.append(face)
				for index in [face.x,face.y,face.z]: normals[index] += normal
	for index in range(normals.size()): normals[index] = normals[index].normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var flat := (vertices[face.y]-vertices[face.x]).cross(vertices[face.z]-vertices[face.x]).normalized()
		for index in [face.z,face.y,face.x]:
			var normal := flat.lerp(normals[index],softness).normalized()
			if normal.dot(flat) <= 0.05: normal = flat
			st.set_normal(normal)
			st.add_vertex(vertices[index])
	if cap_ends:
		for end in [0,rings.size()-1]:
			var center := Vector3.ZERO
			for point in rings[end]: center += point
			center /= float(count)
			for column in range(count):
				var a: Vector3 = rings[end][column]
				var b: Vector3 = rings[end][(column+1)%count]
				if (a-center).cross(b-center).length_squared() < 0.0000000001: continue
				if end == 0: _triangle(st,center,b,a)
				else: _triangle(st,center,a,b)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


static func _section(width: float, y: float, front: float, back: float, shift: Vector2 = Vector2.ZERO) -> PackedVector3Array:
	# Rounded rectangular clothing sections: a chest/front plane, side seam and back.
	var outline := [Vector2(0,front),Vector2(width*0.60,front),Vector2(width*0.92,front*0.70),Vector2(width,0),Vector2(width*0.88,-back*0.72),Vector2(width*0.50,-back),Vector2(0,-back),Vector2(-width*0.50,-back),Vector2(-width*0.88,-back*0.72),Vector2(-width,0),Vector2(-width*0.92,front*0.70),Vector2(-width*0.60,front)]
	var result := PackedVector3Array()
	for point in outline: result.append(Vector3(point.x+shift.x,y,point.y+shift.y))
	return result


static func _garment(parent: Node3D, sections: Array[Vector4], color: String, node_name: String, shifts: Array[Vector2] = [], softness: float = 0.82) -> MeshInstance3D:
	var rings: Array[PackedVector3Array] = []
	for i in range(sections.size()):
		var p: Vector4 = sections[i]
		rings.append(_section(p.x,p.y,p.z,p.w,shifts[i] if i < shifts.size() else Vector2.ZERO))
	return _instance(parent,_sculpt_mesh(rings,softness),Vector3.ZERO,color,node_name)


static func _panel(parent: Node3D, points: PackedVector3Array, color: String, node_name: String) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()-1):
		if (points[i]-points[0]).cross(points[i+1]-points[0]).z < 0.0:
			_triangle(st,points[0],points[i+1],points[i])
		else:
			_triangle(st,points[0],points[i],points[i+1])
	return _instance(parent,st.commit(),Vector3.ZERO,color,node_name)


static func _face_ring(width: float, y: float, front: float, back: float, nose: float = 0.0, cheek: float = 0.0) -> PackedVector3Array:
	# The middle front vertex belongs to the nose bridge; its neighbours form the
	# muzzle and cheeks. They are one continuous surface, not attached facial beads.
	return PackedVector3Array([
		Vector3(0,y,front+nose),Vector3(width*0.30,y,front+cheek),Vector3(width*0.66,y,front-0.009+cheek),Vector3(width*0.88,y,front*0.70),
		Vector3(width,y,0.01),Vector3(width*0.93,y,-back*0.62),Vector3(width*0.68,y,-back*0.92),Vector3(width*0.34,y,-back),
		Vector3(0,y,-back*1.03),Vector3(-width*0.34,y,-back),Vector3(-width*0.68,y,-back*0.92),Vector3(-width*0.93,y,-back*0.62),
		Vector3(-width,y,0.01),Vector3(-width*0.88,y,front*0.70),Vector3(-width*0.66,y,front-0.009+cheek),Vector3(-width*0.30,y,front+cheek)])


static func _hair_cap(head: Node3D, style: String, color: String) -> void:
	var rings: Array[PackedVector3Array] = []
	var low := PackedVector3Array()
	for i in range(16):
		var angle := TAU*float(i)/16.0
		var facing := cos(angle)
		var y := -0.035
		if facing > 0.45:
			if style == "tony": y = 0.19+0.012*sin(angle*3.0)
			elif style == "lurch": y = 0.10+0.025*sin(angle*5.0+0.7)
			else: y = 0.13+0.014*sin(angle*3.0)
		elif facing > -0.2: y = 0.015
		var width := lerpf(0.181,0.146,clampf((y-0.10)/0.11,0.0,1.0))
		var depth := lerpf(0.17,0.138,clampf((y-0.10)/0.11,0.0,1.0))
		low.append(Vector3(sin(angle)*width,y,cos(angle)*depth))
	rings.append(low)
	rings.append(_face_ring(0.143,0.205,0.135,0.133) if style == "tony" else _face_ring(0.164,0.183,0.152,0.151))
	rings.append(_face_ring(0.106,0.218,0.100,0.097))
	rings.append(_face_ring(0.014,0.234,0.014,0.014))
	var hair := _instance(head,_sculpt_mesh(rings,0.70),Vector3.ZERO,color,"hair")
	if style == "pete": hair.scale.x = 1.10


static func _organic_link(parent: Node3D, centers: Array[Vector3], sizes: Array[Vector2], color: String, node_name: String) -> MeshInstance3D:
	var axis := (centers[centers.size()-1]-centers[0]).normalized()
	var rotation := Quaternion(Vector3.UP,axis)
	var rings: Array[PackedVector3Array] = []
	for row in range(centers.size()):
		var ring := PackedVector3Array()
		for i in range(10):
			var angle := TAU*float(i)/10.0
			ring.append(centers[row]+rotation*Vector3(sin(angle)*sizes[row].x,0,cos(angle)*sizes[row].y))
		rings.append(ring)
	return _instance(parent,_sculpt_mesh(rings,0.88),Vector3.ZERO,color,node_name)


static func _animal_form(parent: Node3D, profiles: Array[Vector4], center_y: float, color: String, node_name: String, offsets: Array[float] = [], softness: float = 0.82) -> MeshInstance3D:
	# Front-to-back cross-sections keep the spine, belly, neck and muzzle connected.
	var rings: Array[PackedVector3Array] = []
	for row in range(profiles.size()):
		var p: Vector4 = profiles[row]
		var ring := PackedVector3Array()
		for i in range(12):
			var angle := TAU*float(i)/12.0
			var c := cos(angle)
			var y := center_y+(offsets[row] if row < offsets.size() else 0.0)
			ring.append(Vector3(sin(angle)*p.x,y+c*(p.z if c > 0.0 else p.w),p.y))
		rings.append(ring)
	return _instance(parent,_sculpt_mesh(rings,softness),Vector3.ZERO,color,node_name)


static func _head(parent: Node3D, at: Vector3, skin: String, scale_value: Vector3 = Vector3.ONE, eye_height: float = 0.045, identity: String = "tony") -> Node3D:
	var head := _node(parent, "head", at)
	head.scale = scale_value
	var broad := 1.0
	if identity == "pete": broad = 1.10
	elif identity == "yuri": broad = 1.06
	elif identity == "lurch": broad = 0.91
	var jaw := 0.139 if identity == "yuri" else 0.121
	if identity == "pete": jaw = 0.148
	if identity == "lurch": jaw = 0.108
	var rings: Array[PackedVector3Array] = [
		_face_ring(0.050,-0.218,0.055,0.055),_face_ring(jaw,-0.192,0.116,0.109),
		_face_ring(0.151*broad,-0.135,0.145,0.140,0.005),_face_ring(0.169*broad,-0.075,0.149,0.159,0.008,0.003),
		_face_ring(0.174*broad,-0.047,0.155,0.164,0.069,0.002),_face_ring(0.178*broad,0.005,0.157,0.168,0.047,-0.005),
		_face_ring(0.178*broad,eye_height,0.155,0.168,0.030,-0.010),_face_ring(0.177*broad,0.090,0.162,0.165,0.006,0.002),
		_face_ring(0.173*broad,0.137,0.157,0.159),_face_ring(0.155*broad,0.185,0.143,0.140),
		_face_ring(0.099*broad,0.217,0.092,0.090),_face_ring(0.012,0.227,0.013,0.013)]
	_instance(head,_sculpt_mesh(rings,0.72),Vector3.ZERO,skin,"face")
	for side in [-1.0,1.0]:
		# Ears are a single folded outline attached along the jaw plane.
		var ear := PackedVector3Array([Vector3(side*0.165*broad,0.028,0.006),Vector3(side*0.192*broad,0.046,0.007),Vector3(side*0.214*broad,0.024,0.003),Vector3(side*0.218*broad,-0.033,-0.003),Vector3(side*0.201*broad,-0.073,0.001),Vector3(side*0.174*broad,-0.069,0.012),Vector3(side*0.174*broad,-0.015,0.032)])
		_panel(head,ear,skin,"ear")
		_panel(head,PackedVector3Array([Vector3(side*0.186*broad,0.016,0.018),Vector3(side*0.203*broad,0.008,0.013),Vector3(side*0.199*broad,-0.041,0.013),Vector3(side*0.184*broad,-0.047,0.022)]),SKIN_SHADE,"ear_fold")
		# Shallow, shaped eye whites lie against a socket, with upper/lower lid ribbons.
		var x: float = side*0.081*broad
		var eye_z := 0.158
		var half_width := 0.037
		var upper := eye_height+0.012
		var lower := eye_height-0.011
		if identity == "pete": upper -= 0.003
		_panel(head,PackedVector3Array([Vector3(x-half_width,eye_height,eye_z-0.004),Vector3(x-0.013,upper,eye_z+0.004),Vector3(x+0.019,upper-0.002,eye_z+0.003),Vector3(x+half_width,eye_height-0.002,eye_z-0.007),Vector3(x+0.014,lower,eye_z+0.003),Vector3(x-0.014,lower,eye_z+0.003)]),CREAM,"eye")
		_panel(head,PackedVector3Array([Vector3(x-0.010,upper-0.001,eye_z+0.007),Vector3(x+0.009,upper-0.001,eye_z+0.007),Vector3(x+0.009,lower+0.001,eye_z+0.007),Vector3(x-0.010,lower+0.001,eye_z+0.007)]),"675b32","iris")
		_box(head,Vector3(x,eye_height,eye_z+0.009),Vector3(0.008,0.018,0.002),DARK,"pupil")
		_panel(head,PackedVector3Array([Vector3(x-half_width,eye_height,eye_z-0.002),Vector3(x-0.013,upper,eye_z+0.006),Vector3(x+0.019,upper-0.002,eye_z+0.005),Vector3(x+half_width,eye_height-0.002,eye_z-0.005),Vector3(x+0.020,upper+0.011,eye_z),Vector3(x-0.016,upper+0.012,eye_z+0.002)]),skin,"upper_lid")
		_panel(head,PackedVector3Array([Vector3(x-half_width,eye_height-0.002,eye_z-0.003),Vector3(x-0.014,lower-0.001,eye_z+0.004),Vector3(x+0.014,lower-0.001,eye_z+0.004),Vector3(x+half_width,eye_height-0.003,eye_z-0.006),Vector3(x+0.014,lower-0.006,eye_z),Vector3(x-0.014,lower-0.006,eye_z)]),SKIN_SHADE,"lower_lid")
		var inner := eye_height+0.033
		var outer := eye_height+0.030
		if identity == "yuri": inner -= 0.010; outer += 0.005
		_panel(head,PackedVector3Array([Vector3(side*0.040*broad,inner,0.167),Vector3(side*0.123*broad,outer,0.151),Vector3(side*0.130*broad,outer+0.013,0.150),Vector3(side*0.043*broad,inner+0.018,0.167)]),HAIR,"brow")
		_panel(head,PackedVector3Array([Vector3(side*0.010,-0.060,0.208),Vector3(side*0.029,-0.057,0.185),Vector3(side*0.025,-0.063,0.181),Vector3(side*0.011,-0.065,0.202)]),SKIN_SHADE,"nostril")
	var mouth_y := -0.120 if identity != "lurch" else -0.137
	_panel(head,PackedVector3Array([Vector3(-0.049,mouth_y+0.003,0.154),Vector3(0,mouth_y,0.159),Vector3(0.049,mouth_y+0.003,0.154),Vector3(0.044,mouth_y-0.003,0.155),Vector3(0,mouth_y-0.004,0.160),Vector3(-0.044,mouth_y-0.003,0.155)]),"5a3d2e","mouth_line")
	return head


static func _leg(root: Node3D, side: float, hip: float, length: float, width: float, cloth: String, boot: String) -> Node3D:
	var leg := _node(root, "left_leg" if side < 0 else "right_leg", Vector3(side * width * 1.15, hip, 0))
	_garment(leg,[Vector4(width*0.69,-length,0.070,0.077),Vector4(width*0.77,-length*0.84,0.089,0.087),Vector4(width*0.83,-length*0.56,0.105,0.093),Vector4(width*0.80,-length*0.48,0.099,0.089),Vector4(width*0.98,-length*0.24,0.123,0.113),Vector4(width*1.04,0.025,0.125,0.12)],cloth,"trousers",[Vector2(side*0.04,0),Vector2(side*0.036,-0.005),Vector2(side*0.025,0.020),Vector2(side*0.024,0.028),Vector2(side*0.012,0.008),Vector2.ZERO])
	_panel(leg,PackedVector3Array([Vector3(-width*0.53+side*0.03,-length*0.53,0.119),Vector3(width*0.65+side*0.03,-length*0.52,0.116),Vector3(width*0.48+side*0.03,-length*0.54,0.117),Vector3(-width*0.48+side*0.03,-length*0.55,0.117)]),"393328","knee_fold")
	# A single boot upper rises at the ankle and extends into a blunt, flattened toe.
	var shoe := _garment(leg,[Vector4(width*0.91,-length-0.080,0.218,0.083),Vector4(width*0.94,-length-0.043,0.224,0.084),Vector4(width*0.84,-length+0.001,0.190,0.077),Vector4(width*0.65,-length+0.045,0.091,0.069)],boot,"shoe",[],0.68)
	shoe.position.x = side*0.04
	var sole := _garment(leg,[Vector4(width*0.94,-length-0.105,0.226,0.087),Vector4(width*0.95,-length-0.081,0.227,0.087)],DARK,"sole",[],0.15)
	sole.position.x = side*0.04
	for lace in range(3):
		_box(leg,Vector3(side*0.04,-length+0.025-float(lace)*0.013,0.078+float(lace)*0.025),Vector3(width*0.92,0.006,0.007),"928263","lace")
	return leg


static func _arm(root: Node3D, side: float, shoulder: Vector3, length: float, width: float, cloth: String, skin: String) -> Node3D:
	var arm := _node(root, "left_arm" if side < 0 else "right_arm", shoulder)
	var elbow := Vector3(side * 0.055,-length * 0.53,0.015)
	_garment(arm,[Vector4(width*0.77,elbow.y-0.018,width*0.79,width*0.78),Vector4(width*0.91,elbow.y*0.62,width*0.93,width*0.91),Vector4(width*1.08,-0.045,width*0.99,width*0.93),Vector4(width*0.73,0.045,width*0.69,width*0.73)],cloth,"upper_sleeve",[Vector2(elbow.x,elbow.z),Vector2(elbow.x*0.57,0.009),Vector2.ZERO,Vector2(-side*0.016,0)])
	var forearm := _node(arm,"forearm",elbow)
	var wrist := Vector3(side*0.01,-length*0.47,0.03)
	_garment(forearm,[Vector4(width*0.66,wrist.y,width*0.65,width*0.62),Vector4(width*0.76,wrist.y*0.75,width*0.75,width*0.69),Vector4(width*0.87,wrist.y*0.32,width*0.85,width*0.77),Vector4(width*0.78,0.015,width*0.79,width*0.77)],cloth,"fore_sleeve",[Vector2(wrist.x,wrist.z),Vector2(wrist.x*0.7,0.024),Vector2(wrist.x*0.3,0.012),Vector2.ZERO])
	_garment(forearm,[Vector4(width*0.68,wrist.y-0.008,width*0.67,width*0.65),Vector4(width*0.70,wrist.y+0.031,width*0.69,width*0.65)],cloth,"cuff",[Vector2(wrist.x,wrist.z),Vector2(wrist.x,wrist.z)],0.25)
	_garment(forearm,[Vector4(width*0.51,wrist.y-0.105,width*0.38,width*0.32),Vector4(width*0.65,wrist.y-0.061,width*0.43,width*0.34),Vector4(width*0.49,wrist.y-0.006,width*0.39,width*0.33)],skin,"hand",[Vector2(wrist.x,wrist.z+0.013),Vector2(wrist.x,wrist.z+0.01),Vector2(wrist.x,wrist.z)],0.85)
	for finger in range(4):
		var x := float(finger-2)*width*0.31+width*0.15
		var tip := wrist+Vector3(x,-0.137+absf(float(finger)-1.5)*0.009,0.027)
		_between(forearm,wrist+Vector3(x,-0.086,0.023),tip,width*0.17,width*0.135,skin,"finger")
	_between(forearm,wrist+Vector3(-side*width*0.55,-0.035,0.025),wrist+Vector3(-side*width*0.70,-0.08,0.045),width*0.19,width*0.16,skin,"thumb")
	return arm


static func _lapel(parent: Node3D, side: float, y: float, z: float, width: float, color: String) -> void:
	_panel(parent,PackedVector3Array([Vector3(side*0.06,y+0.14,z-0.018),Vector3(side*width,y+0.09,z-0.035),Vector3(side*width*0.82,y+0.012,z+0.015),Vector3(side*0.075,y-0.16,z+0.026),Vector3(side*0.115,y+0.024,z+0.012)]),color,"lapel")


static func _coat_shell(parent: Node3D, bottom: float, top: float, widths: Vector2, depths: Vector2, color: String, node_name: String) -> void:
	# Open down the front; the other coats remain genuinely visible through the gap.
	var rings: Array[PackedVector3Array] = []
	var height := top-bottom
	var profiles := [Vector3(widths.x,bottom,depths.x),Vector3(widths.x*0.96,bottom+height*0.28,depths.x*0.94),Vector3(widths.y*0.98,bottom+height*0.68,depths.y),Vector3(widths.y,bottom+height*0.88,depths.y),Vector3(widths.y*0.80,bottom+height*0.96,depths.y*0.84),Vector3(widths.y*0.40,top,depths.y*0.60)]
	# Duplicate end points across the gap so the generic ring builder's closing
	# segment becomes the inner facing of the coat, not a panel across the opening.
	for profile in profiles:
		var ring := PackedVector3Array()
		for index in range(17):
			var angle := 0.45+(TAU-0.90)*float(index)/16.0
			ring.append(Vector3(sin(angle)*profile.x,profile.y,cos(angle)*profile.z))
		for index in range(16,-1,-1):
			var angle := 0.45+(TAU-0.90)*float(index)/16.0
			ring.append(Vector3(sin(angle)*(profile.x-0.009),profile.y,cos(angle)*(profile.z-0.009)))
		rings.append(ring)
	_instance(parent,_sculpt_mesh(rings,0.82,false),Vector3.ZERO,color,node_name)


static func _tony(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,0.76,0.64,0.13,"393328","51432c")
	_garment(root,[Vector4(0.245,0.72,0.17,0.15),Vector4(0.255,1.02,0.175,0.16),Vector4(0.285,1.32,0.18,0.17),Vector4(0.245,1.42,0.16,0.15),Vector4(0.115,1.48,0.12,0.105)],"454c2e","coat_one")
	_coat_shell(root,0.61,1.47,Vector2(0.30,0.32),Vector2(0.20,0.21),"8c6b3b","coat_two")
	_coat_shell(root,0.39,1.49,Vector2(0.38,0.35),Vector2(0.27,0.245),"604020","coat_three")
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
	var head := _head(root,Vector3(0,1.69,0.025),SKIN_PALE,Vector3(1.0,0.92,1.0),0.04,"tony")
	# Receding hair and the two committed eyebrows; there is no blink animation.
	_hair_cap(head,"tony",HAIR)
	_panel(head,PackedVector3Array([Vector3(-0.050,-0.087,0.158),Vector3(0,-0.083,0.164),Vector3(0.050,-0.087,0.158),Vector3(0.041,-0.102,0.159),Vector3(0,-0.100,0.164),Vector3(-0.041,-0.102,0.159)]),HAIR,"moustache")
	_box(root,Vector3(0,0.91,-0.257),Vector3(0.56,0.053,0.018),"4e341f","coat_half_belt")
	root.set_meta("height",1.96)


static func _pete(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,0.66,0.54,0.13,"424137","4b3727")
	_garment(root,[Vector4(0.28,0.62,0.19,0.16),Vector4(0.355,0.76,0.265,0.21),Vector4(0.39,0.98,0.29,0.22),Vector4(0.355,1.18,0.24,0.20),Vector4(0.29,1.29,0.185,0.17),Vector4(0.135,1.325,0.12,0.11)],"6b7048","shirt",[Vector2.ZERO,Vector2(0,0.01),Vector2(0,0.015),Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])
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
	var head := _head(root,Vector3(0,1.52,0.025),SKIN,Vector3(1.07,0.89,1.0),0.03,"pete")
	# Square spectacles, with open centers so the eyes remain visible.
	for side in [-1.0,1.0]:
		for y in [-0.005,0.069]: _box(head,Vector3(side*0.092,y,0.184),Vector3(0.112,0.009,0.009),HAIR)
		for x in [side*0.092-0.051,side*0.092+0.051]: _box(head,Vector3(x,0.032,0.184),Vector3(0.009,0.078,0.009),HAIR)
	_box(head,Vector3(0,0.044,0.184),Vector3(0.071,0.009,0.009),HAIR)
	_hair_cap(head,"pete","5a4830")
	_box(root,Vector3(-0.16,1.15,0.235),Vector3(0.12,0.06,0.018),CREAM,"name_patch")
	_box(root,Vector3(-0.16,1.15,0.248),Vector3(0.075,0.008,0.005),"6b7048","patch_mark")
	_box(root,Vector3(0,1.03,0.292),Vector3(0.018,0.32,0.011),"4a4d35","shirt_placket")
	for y in [0.93,1.04,1.15]:
		_oval(root,Vector3(0,y,0.295),Vector3(0.008,0.008,0.007),"b3a06c","button")
	_lapel(root,-1.0,1.18,0.19,0.14,"7b8055")
	_lapel(root,1.0,1.18,0.19,0.14,"7b8055")
	root.set_meta("height",1.77)


static func _yuri(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,0.80,0.67,0.135,"48483a","493222")
	_garment(root,[Vector4(0.28,0.72,0.21,0.17),Vector4(0.30,0.91,0.216,0.18),Vector4(0.33,1.20,0.21,0.19),Vector4(0.35,1.34,0.20,0.18),Vector4(0.29,1.43,0.17,0.16),Vector4(0.14,1.49,0.13,0.115)],"626348","work_jacket")
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
	var head := _head(root,Vector3(0,1.70,0.025),SKIN,Vector3(1.03,0.96,1.0),0.045,"yuri")
	var beard_rings: Array[PackedVector3Array] = [_face_ring(0.077,-0.238,0.083,0.065),_face_ring(0.145,-0.193,0.136,0.111),_face_ring(0.165,-0.129,0.157,0.143),_face_ring(0.178,-0.080,0.154,0.160)]
	_instance(head,_sculpt_mesh(beard_rings,0.48),Vector3.ZERO,"656052","beard")
	_panel(head,PackedVector3Array([Vector3(-0.068,-0.064,0.157),Vector3(-0.023,-0.071,0.170),Vector3(0,-0.066,0.175),Vector3(0.023,-0.071,0.170),Vector3(0.068,-0.064,0.157),Vector3(0.061,-0.096,0.162),Vector3(0,-0.088,0.174),Vector3(-0.061,-0.096,0.162)]),"656052","moustache")
	_garment(head,[Vector4(0.187,0.151,0.177,0.179),Vector4(0.194,0.186,0.181,0.184),Vector4(0.169,0.229,0.158,0.158),Vector4(0.075,0.248,0.07,0.07)],"4b4735","cap",[],0.50)
	_panel(head,PackedVector3Array([Vector3(-0.163,0.159,0.11),Vector3(0.163,0.159,0.11),Vector3(0.178,0.147,0.222),Vector3(0.12,0.140,0.265),Vector3(-0.12,0.140,0.265),Vector3(-0.178,0.147,0.222)]),"3a3628","cap_peak")
	_box(root,Vector3(0,0.77,0.211),Vector3(0.09,0.07,0.018),"87764c","belt_buckle")
	root.set_meta("height",2.02)


static func _lurch(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_leg(root,side,1.01,0.89,0.092,"51473a","4a3426")
	_garment(root,[Vector4(0.18,0.93,0.12,0.105),Vector4(0.178,1.12,0.128,0.12),Vector4(0.205,1.38,0.143,0.15),Vector4(0.239,1.56,0.145,0.15),Vector4(0.19,1.64,0.13,0.12),Vector4(0.09,1.70,0.075,0.075)],"6a5b48","shirt",[Vector2.ZERO,Vector2(0,0.005),Vector2(-0.012,0.016),Vector2(-0.01,0.025),Vector2(-0.008,0.04),Vector2(0,0.045)])
	_box(root,Vector3(-0.08,1.28,0.129),Vector3(0.11,0.16,0.026),"4b502c","patch")
	for side in [-1.0,1.0]:
		var arm := _arm(root,side,Vector3(side*0.24,1.59,0),0.88,0.082,"6a5b48",SKIN_PALE)
		arm.rotation.z = side*0.05
		if side > 0: arm.position.y -= 0.045
	_taper(root,Vector3(0,1.57,0.02),0.27,Vector2(0.073,0.07),Vector2(0.07,0.07),SKIN_PALE)
	var head := _head(root,Vector3(0,1.96,0.079),SKIN_PALE,Vector3(0.93,1.04,0.95),0.03,"lurch")
	_hair_cap(head,"lurch","55402b")
	_box(head,Vector3(0.018,-0.137,0.160),Vector3(0.019,0.012,0.003),"b3a06c","tooth")
	for side in [-1.0,1.0]:
		_box(root,Vector3(side*0.12,1.48,0.137),Vector3(0.012,0.22,0.014),"3e392d","suspender")
	for y in [1.05,1.21,1.37]:
		_oval(root,Vector3(0,y,0.142),Vector3(0.009,0.011,0.006),"a08c59","shirt_button")
	for x in [-0.13,-0.095,-0.06]:
		_between(root,Vector3(x,1.21,0.146),Vector3(x+0.015,1.25,0.146),0.0025,0.0025,CREAM,"patch_stitch")
	root.set_meta("height",2.24)


static func _possum(root: Node3D) -> void:
	_animal_form(root,[Vector4(0.12,0.29,0.12,0.10),Vector4(0.19,0.19,0.18,0.13),Vector4(0.225,-0.04,0.235,0.15),Vector4(0.19,-0.24,0.19,0.13),Vector4(0.10,-0.36,0.12,0.08),Vector4(0.035,-0.405,0.04,0.035)],0.205,"777767","body")
	var head := _node(root,"head",Vector3(0,0.29,0.26))
	_animal_form(head,[Vector4(0.022,0.30,0.021,0.019),Vector4(0.057,0.22,0.045,0.041),Vector4(0.108,0.12,0.076,0.071),Vector4(0.145,0.015,0.128,0.101),Vector4(0.119,-0.095,0.105,0.09),Vector4(0.043,-0.151,0.044,0.041)],0.0,"c1b58c","face",[-0.045,-0.035,-0.019,0.0,0.0,0.0])
	_animal_form(head,[Vector4(0.016,0.321,0.012,0.012),Vector4(0.024,0.307,0.018,0.016),Vector4(0.021,0.290,0.015,0.014)],-0.044,"765247","nose")
	_panel(head,PackedVector3Array([Vector3(-0.027,-0.064,0.266),Vector3(0,-0.070,0.286),Vector3(0.027,-0.064,0.266),Vector3(0,-0.073,0.286)]),"5a4c3f","mouth")
	for side in [-1.0,1.0]:
		_oval(head,Vector3(side*0.125,0.11,-0.04),Vector3(0.065,0.072,0.025),"443e35","ear")
		_oval(head,Vector3(side*0.126,0.113,-0.017),Vector3(0.037,0.043,0.009),"8f705b","ear_inset")
		_panel(head,PackedVector3Array([Vector3(side*0.084,0.044,0.118),Vector3(side*0.102,0.061,0.112),Vector3(side*0.126,0.052,0.088),Vector3(side*0.128,0.033,0.088),Vector3(side*0.109,0.022,0.110),Vector3(side*0.088,0.029,0.120)]),DARK,"eye")
		_panel(head,PackedVector3Array([Vector3(side*0.098,0.051,0.117),Vector3(side*0.105,0.052,0.113),Vector3(side*0.105,0.044,0.115),Vector3(side*0.098,0.044,0.119)]),CREAM,"eye_glint")
		for row in range(3):
			_between(head,Vector3(side*0.045,-0.05,0.24),Vector3(side*0.17,-0.047+float(row-1)*0.028,0.25-float(row)*0.018),0.0018,0.0008,"b5a77e","whisker")
		for z in [-0.23,0.18]:
			var limb_name := ("front_" if z > 0 else "back_")+("left" if side < 0 else "right")
			var leg := _node(root,limb_name,Vector3(side*0.16,0.22,z))
			_organic_link(leg,[Vector3.ZERO,Vector3(side*0.018,-0.07,-0.008),Vector3(side*0.03,-0.165,0.03)],[Vector2(0.038,0.04),Vector2(0.033,0.035),Vector2(0.022,0.026)],"5f594b","leg")
			var paw := _animal_form(leg,[Vector4(0.038,0.121,0.015,0.013),Vector4(0.051,0.075,0.026,0.019),Vector4(0.025,0.025,0.018,0.014)],-0.175,"8f705b","paw")
			paw.position.x = side*0.03
			for toe in range(3):
				_between(leg,Vector3(side*0.03+float(toe-1)*0.025,-0.178,0.08),Vector3(side*0.035+float(toe-1)*0.03,-0.184,0.13),0.008,0.004,"8f705b","toe")
	var tail := _node(root,"tail",Vector3(0,0.20,-0.33))
	_organic_link(tail,[Vector3.ZERO,Vector3(0.05,-0.06,-0.24),Vector3(0.17,-0.10,-0.45),Vector3(0.32,-0.10,-0.54),Vector3(0.43,-0.06,-0.50)],[Vector2(0.029,0.029),Vector2(0.024,0.024),Vector2(0.018,0.018),Vector2(0.012,0.012),Vector2(0.006,0.006)],"a08065","tail_skin")
	# The helmet is a real brim and faceted dome, not a yellow sphere.
	_taper(head,Vector3(0,0.124,0.005),0.025,Vector2(0.19,0.175),Vector2(0.19,0.175),"b99536","helmet_brim")
	_oval(head,Vector3(0,0.148,-0.01),Vector3(0.15,0.10,0.135),"e8c040","helmet")
	_box(head,Vector3(0,0.225,-0.005),Vector3(0.035,0.026,0.22),"b99536","helmet_ridge")
	_box(head,Vector3(-0.05,0.189,0.096),Vector3(0.06,0.029,0.007),CREAM,"helmet_sticker")
	_box(head,Vector3(-0.05,0.189,0.101),Vector3(0.031,0.004,0.004),"777767","sticker_mark")
	root.set_meta("height",0.55)


static func _brutus(root: Node3D) -> void:
	_animal_form(root,[Vector4(0.15,0.40,0.18,0.18),Vector4(0.27,0.27,0.29,0.26),Vector4(0.245,0.02,0.25,0.20),Vector4(0.22,-0.25,0.22,0.17),Vector4(0.17,-0.47,0.16,0.12),Vector4(0.045,-0.57,0.048,0.045)],0.46,"65432b","body")
	_panel(root,PackedVector3Array([Vector3(-0.178,0.594,0.02),Vector3(0,0.714,0.02),Vector3(0.18,0.594,0.02),Vector3(0.17,0.574,-0.36),Vector3(0,0.654,-0.43),Vector3(-0.17,0.574,-0.36)]),"493222","saddle")
	var head := _node(root,"head",Vector3(0,0.69,0.44))
	_animal_form(head,[Vector4(0.145,0.16,0.105,0.115),Vector4(0.192,0.065,0.197,0.18),Vector4(0.205,-0.025,0.22,0.195),Vector4(0.155,-0.15,0.16,0.13),Vector4(0.04,-0.21,0.047,0.04)],0.0,"704e34","skull",[-0.035,0.0,0.0,-0.015,-0.02])
	_animal_form(head,[Vector4(0.05,0.38,0.033,0.032),Vector4(0.113,0.302,0.069,0.069),Vector4(0.137,0.211,0.087,0.092),Vector4(0.145,0.16,0.105,0.115)],0.0,"9d8b68","old_muzzle",[-0.068,-0.063,-0.047,-0.035])
	_animal_form(head,[Vector4(0.049,0.407,0.023,0.021),Vector4(0.065,0.386,0.032,0.029),Vector4(0.054,0.364,0.027,0.025)],-0.067,DARK,"nose",[],0.65)
	for side in [-1.0,1.0]:
		_panel(head,PackedVector3Array([Vector3(side*0.021,-0.066,0.409),Vector3(side*0.037,-0.063,0.405),Vector3(side*0.037,-0.075,0.404),Vector3(side*0.023,-0.075,0.409)]),"10120e","nostril")
	var jaw := _node(root,"jaw",Vector3(0,0.56,0.53))
	_animal_form(jaw,[Vector4(0.071,0.266,0.022,0.028),Vector4(0.119,0.179,0.030,0.045),Vector4(0.126,0.074,0.034,0.045),Vector4(0.063,0.015,0.028,0.032)],-0.006,"a29675","lower_jaw")
	_panel(jaw,PackedVector3Array([Vector3(-0.09,0.026,0.15),Vector3(0.09,0.026,0.15),Vector3(0.068,0.024,0.26),Vector3(-0.068,0.024,0.26)]),"453127","mouth")
	_panel(jaw,PackedVector3Array([Vector3(0.0,0.027,0.20),Vector3(0.047,0.027,0.20),Vector3(0.043,0.021,0.268),Vector3(0.014,0.020,0.277),Vector3(0.001,0.021,0.261)]),"946951","tongue")
	for side in [-1.0,1.0]:
		var ear := _node(head,"left_ear" if side < 0 else "right_ear",Vector3(side*0.19,-0.03,-0.05))
		ear.rotation.z = side*0.30
		_garment(ear,[Vector4(0.024,-0.192,0.021,0.019),Vector4(0.063,-0.145,0.036,0.028),Vector4(0.077,-0.045,0.041,0.032),Vector4(0.055,0.063,0.031,0.028)],"493222","ear",[],0.80)
		_panel(ear,PackedVector3Array([Vector3(-0.038,-0.027,0.043),Vector3(0.041,-0.027,0.043),Vector3(0.028,-0.136,0.034),Vector3(0.0,-0.163,0.030),Vector3(-0.029,-0.128,0.035)]),"805737","ear_fold")
		_panel(head,PackedVector3Array([Vector3(side*0.096,0.068,0.153),Vector3(side*0.117,0.085,0.145),Vector3(side*0.151,0.080,0.119),Vector3(side*0.164,0.063,0.104),Vector3(side*0.143,0.052,0.130),Vector3(side*0.111,0.053,0.151)]),"b2ae8c" if side < 0 else "30291d","eye")
		_panel(head,PackedVector3Array([Vector3(side*0.095,0.071,0.154),Vector3(side*0.117,0.089,0.145),Vector3(side*0.153,0.084,0.118),Vector3(side*0.166,0.065,0.104),Vector3(side*0.154,0.102,0.113),Vector3(side*0.115,0.108,0.141)]),"9d8b68","grey_brow")
		for z in [-0.40,0.27]:
			var limb_name := ("front_" if z > 0 else "back_")+("left" if side < 0 else "right")
			var leg := _node(root,limb_name,Vector3(side*0.16,0.43,z))
			_organic_link(leg,[Vector3.ZERO,Vector3(side*0.014,-0.13,-0.012),Vector3(side*0.03,-0.27,0.012),Vector3(side*0.03,-0.342,0.04)],[Vector2(0.075,0.076),Vector2(0.065,0.069),Vector2(0.047,0.054),Vector2(0.053,0.059)],"704e34","leg")
			var paw := _animal_form(leg,[Vector4(0.055,0.185,0.03,0.026),Vector4(0.082,0.125,0.052,0.042),Vector4(0.067,0.055,0.061,0.041),Vector4(0.04,0.008,0.028,0.026)],-0.355,"9d8b68","paw")
			paw.position.x = side*0.03
			for toe in range(3):
				_oval(leg,Vector3(side*0.03+float(toe-1)*0.038,-0.375,0.171),Vector3(0.018,0.017,0.032),"b0a181","claw")
	var tail := _node(root,"tail",Vector3(0,0.51,-0.49))
	_between(tail,Vector3.ZERO,Vector3(0.09,0.13,-0.28),0.065,0.035,"65432b")
	_between(tail,Vector3(0.09,0.13,-0.28),Vector3(0.13,0.08,-0.38),0.035,0.013,"493222")
	_animal_form(root,[Vector4(0.214,0.425,0.197,0.197),Vector4(0.227,0.355,0.209,0.206)],0.515,RUST,"collar",[],0.35)
	_panel(root,PackedVector3Array([Vector3(-0.026,0.393,0.48),Vector3(0.026,0.393,0.48),Vector3(0.039,0.364,0.48),Vector3(0.022,0.334,0.48),Vector3(-0.022,0.334,0.48),Vector3(-0.039,0.364,0.48)]),"b19b5d","tag")
	root.set_meta("height",0.95)


static func _hands(root: Node3D) -> void:
	# Attach directly under Camera3D, local origin zero. Camera faces -Z.
	# One continuous palm/knuckle surface carries the fist silhouette. Finger folds
	# sit on that surface, rather than forming separate hooks with daylight between.
	for side in [-1.0,1.0]:
		var hand := _node(root,"left_arm" if side < 0 else "right_arm",Vector3(side*0.275,-0.385,-0.50))
		hand.rotation.z = -side*0.07
		_organic_link(hand,[Vector3(side*0.045,-0.28,0.22),Vector3(side*0.027,-0.17,0.13),Vector3(side*0.004,-0.065,0.014),Vector3(0,-0.027,-0.036)],[Vector2(0.092,0.087),Vector2(0.086,0.083),Vector2(0.069,0.065),Vector2(0.061,0.059)],MOLD,"sleeve")
		_organic_link(hand,[Vector3(0,-0.038,-0.019),Vector3(0,-0.018,-0.043),Vector3(0,-0.002,-0.063)],[Vector2(0.065,0.062),Vector2(0.065,0.061),Vector2(0.060,0.057)],"555d34","cuff")
		for seam in range(5):
			_between(hand,Vector3(-0.044+float(seam)*0.022,-0.015,-0.069),Vector3(-0.047+float(seam)*0.023,-0.036,-0.043),0.0015,0.0015,"394027","cuff_rib")
		_organic_link(hand,[Vector3(0,-0.006,-0.059),Vector3(0,0.022,-0.086),Vector3(0,0.035,-0.105)],[Vector2(0.045,0.037),Vector2(0.049,0.039),Vector2(0.048,0.037)],SKIN_PALE,"wrist")
		var rings: Array[PackedVector3Array] = []
		var outline := [Vector2(0,1),Vector2(0.24,1.02),Vector2(0.48,0.94),Vector2(0.72,0.85),Vector2(0.9,0.64),Vector2(1,0.18),Vector2(1,-0.4),Vector2(0.8,-0.85),Vector2(0.4,-1),Vector2(0,-1),Vector2(-0.4,-1),Vector2(-0.8,-0.85),Vector2(-1,-0.4),Vector2(-1,0.18),Vector2(-0.9,0.66),Vector2(-0.72,0.9),Vector2(-0.48,1.02),Vector2(-0.24,1.02)]
		var profiles: Array[Vector4] = [Vector4(0.041,-0.063,0.027,0.026),Vector4(0.055,-0.096,0.041,0.035),Vector4(0.066,-0.137,0.062,0.040),Vector4(0.063,-0.170,0.052,0.025),Vector4(0.050,-0.181,0.030,0.018)]
		for p in profiles:
			var ring := PackedVector3Array()
			for point in outline:
				ring.append(Vector3(point.x*p.x,0.035+point.y*(p.z if point.y > 0.0 else p.w),p.y))
			rings.append(ring)
		_instance(hand,_sculpt_mesh(rings,0.83),Vector3.ZERO,SKIN_PALE,"fist")
		for finger in range(3):
			var x := -0.031+float(finger)*0.031
			_panel(hand,PackedVector3Array([Vector3(x-0.001,0.079,-0.172),Vector3(x+0.001,0.079,-0.172),Vector3(x+0.001,0.044,-0.182),Vector3(x-0.001,0.044,-0.182)]),SKIN_SHADE,"finger_fold")
		_organic_link(hand,[Vector3(-side*0.046,0.021,-0.106),Vector3(-side*0.063,0.028,-0.133),Vector3(-side*0.048,0.039,-0.163),Vector3(-side*0.022,0.041,-0.177)],[Vector2(0.025,0.022),Vector2(0.023,0.021),Vector2(0.021,0.018),Vector2(0.015,0.013)],SKIN_PALE,"thumb")
		_panel(hand,PackedVector3Array([Vector3(-side*0.038,0.050,-0.178),Vector3(-side*0.024,0.052,-0.183),Vector3(-side*0.017,0.043,-0.184),Vector3(-side*0.032,0.041,-0.180)]),"b3a077","thumbnail")
