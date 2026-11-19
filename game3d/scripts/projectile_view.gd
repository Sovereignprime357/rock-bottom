class_name RockBottomProjectileView
extends Node3D
## Pure projection of Combat's centered records. No movement, lifetime or impact owner.
const Content = preload("res://scripts/content_catalog.gd")
const Surfaces = preload("res://scripts/surface_kit.gd")
const Batcher = preload("res://scripts/mesh_batcher.gd")
static var _templates: Dictionary = {}
static var _materials: Dictionary = {}
var presentation_kind: String = ""
var source_rotation: float = 0.0
var _art: Node3D
var _bottle: Node3D
var _holy: Node3D
var _glass_material: StandardMaterial3D
var _halo_material: StandardMaterial3D
var _last_angle: float = INF
var _last_pulse: float = INF

static func supported_kinds() -> Array[StringName]: return [&"bottle",&"holy"]

static func create() -> RockBottomProjectileView:
	var result := RockBottomProjectileView.new()
	result.name = "ProjectileView"; result.visible = false
	result._art = Node3D.new(); result._art.name = "Art"; result.add_child(result._art)
	for kind: String in ["bottle","holy"]:
		var bank := Node3D.new(); bank.name = kind; bank.visible = false; result._art.add_child(bank)
		if kind == "bottle": result._bottle = bank
		else: result._holy = bank
		for row: Dictionary in _template(kind):
			var leaf := MeshInstance3D.new(); leaf.name = row.name; leaf.mesh = row.mesh; leaf.transform = row.transform
			if row.role != "solid":
				# Exactly two local alpha materials. Never change a shared template
				# when two views sample different times or array slots change kind.
				var material: StandardMaterial3D = _alpha_base(str(row.role)).duplicate() as StandardMaterial3D
				leaf.material_override = material; leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if row.role == "glass": result._glass_material = material
				else: result._halo_material = material
			bank.add_child(leaf)
		var marker := Node3D.new(); marker.name = "neck_marker" if kind == "bottle" else "cap_marker"
		marker.position = Vector3(0.176,0,0) if kind == "bottle" else Vector3(0,0,-0.144)
		bank.add_child(marker)
	return result

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _hide_invalid() -> bool:
	visible = false; presentation_kind = ""; source_rotation = 0.0
	return false

func project(record: Dictionary, render_ms: float = 0.0) -> bool:
	if not record.get("kind") is String or record.kind not in ["bottle","holy"] or not is_finite(render_ms): return _hide_invalid()
	for key: String in ["x","y","rot"]:
		if not _number(record.get(key)): return _hide_invalid()
	var point := Vector2(float(record.x),float(record.y))
	if not point.is_finite(): return _hide_invalid()
	var at: Vector3 = Content.to_world(point,1.0)
	if not at.is_finite(): return _hide_invalid()
	var kind: String = record.kind
	if presentation_kind != kind:
		_bottle.visible = kind == "bottle"; _holy.visible = kind == "holy"
		presentation_kind = kind
	if position != at: position = at
	source_rotation = float(record.rot)
	var angle: float = -fposmod(source_rotation,TAU)
	if _last_angle != angle:
		_art.rotation.y = angle; _last_angle = angle
	if kind == "holy":
		# Source wall-time opacity, sampled directly. No delta accumulation,
		# TIME shader, render-dependent spin, light or projectile lifecycle here.
		var pulse: float = (sin(fposmod(render_ms,TAU*80.0)/80.0)+1.0)*0.5
		if pulse != _last_pulse:
			var glass: Color = _glass_material.albedo_color; glass.a = 0.75+pulse*0.25
			var halo: Color = _halo_material.albedo_color; halo.a = 0.18+pulse*0.18
			_glass_material.albedo_color = glass; _halo_material.albedo_color = halo
			_last_pulse = pulse
	visible = true
	return true

static func _paint(color: String) -> StandardMaterial3D:
	var key: String = "solid/"+color
	if not _materials.has(key):
		var material: StandardMaterial3D = Surfaces.material("plain",color,0.83)
		if material.uv1_world_triplanar:
			material = material.duplicate() as StandardMaterial3D; material.uv1_world_triplanar = false
		_materials[key] = material
	return _materials[key]

static func _alpha_base(role: String) -> StandardMaterial3D:
	if not _materials.has(role):
		var material: StandardMaterial3D = _paint("d4c896" if role == "glass" else "d488d4").duplicate() as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.render_priority = 1 if role == "glass" else 0
		material.albedo_color.a = 0.875 if role == "glass" else 0.27
		_materials[role] = material
	return _materials[role]

static func _template(kind: String) -> Array:
	if _templates.has(kind): return _templates[kind]
	var solid := Node3D.new()
	var rows: Array[Dictionary] = []
	if kind == "bottle":
		var body := _mesh(_loft_x([Vector3(-0.160,0.040,0.049),Vector3(-0.145,0.052,0.064),Vector3(0.090,0.052,0.064),Vector3(0.132,0.027,0.033),Vector3(0.160,0.025,0.031)],10))
		_part(solid,"BrownGlass",body,"604020")
		_part(solid,"DarkNeck",_mesh(_loft_x([Vector3(0.128,0.029,0.034),Vector3(0.169,0.029,0.034),Vector3(0.176,0.024,0.029)],10)),"3a2010")
		_box(solid,"AmberShine",Vector3(-0.024,0.047,-0.025),Vector3(0.234,0.002,0.009),"a07020")
		_box(solid,"GlassScuff",Vector3(-0.093,0.050,0.008),Vector3(0.036,0.002,0.007),"7c5426")
	else:
		var glass: ArrayMesh = _mesh(_loft_z([Vector3(0.064,0.034,-0.128),Vector3(0.080,0.048,-0.108),Vector3(0.080,0.048,0.108),Vector3(0.064,0.034,0.128)]))
		var halo: ArrayMesh = _mesh(_loft_z([Vector3(0.125,0.050,-0.192),Vector3(0.160,0.080,-0.160),Vector3(0.160,0.080,0.160),Vector3(0.125,0.050,0.192)]))
		rows.append({"name":"Halo","mesh":halo,"transform":Transform3D.IDENTITY,"role":"halo"})
		rows.append({"name":"Glass","mesh":glass,"transform":Transform3D.IDENTITY,"role":"glass"})
		_box(solid,"CreamCap",Vector3(0,0,-0.136),Vector3(0.096,0.074,0.016),"d4c896")
		_box(solid,"CapSeam",Vector3(0,0.039,-0.133),Vector3(0.082,0.004,0.006),"9b8a58")
		# A small cream collar gives the vial a readable closed end in perspective.
		_box(solid,"CapLip",Vector3(0,0,-0.125),Vector3(0.104,0.078,0.006),"b3a477")
	Batcher.batch_children(solid,0.0)
	for node: Node in solid.get_children():
		if node is MeshInstance3D: rows.append({"name":node.name,"mesh":node.mesh,"transform":node.transform,"role":"solid"})
	solid.free(); _templates[kind] = rows
	return rows

static func _part(parent: Node3D,label: String,mesh: Mesh,color: String) -> MeshInstance3D:
	var part := MeshInstance3D.new(); part.name = label; part.mesh = mesh; part.material_override = _paint(color)
	parent.add_child(part); return part

static func _box(parent: Node3D,label: String,at: Vector3,size: Vector3,color: String) -> void:
	var box := BoxMesh.new(); box.size = size; _part(parent,label,box,color).position = at

static func _data() -> Dictionary: return {"vertices":PackedVector3Array(),"normals":PackedVector3Array()}

static func _triangle(data: Dictionary,a: Vector3,b: Vector3,c: Vector3,outward: Vector3) -> void:
	var normal: Vector3 = -(b-a).cross(c-a)
	if normal.length_squared() < 0.000000000001: return
	if normal.dot(outward) < 0.0:
		var swap: Vector3 = b; b = c; c = swap; normal = -normal
	normal = normal.normalized()
	data.vertices.append_array(PackedVector3Array([a,b,c])); data.normals.append_array(PackedVector3Array([normal,normal,normal]))

static func _face(data: Dictionary,points: Array,outward: Vector3) -> void:
	for index: int in range(1,points.size()-1): _triangle(data,points[0],points[index],points[index+1],outward)

static func _loft_x(rings: Array[Vector3],sides: int) -> Dictionary:
	var data: Dictionary = _data(); var layers: Array = []
	for ring: Vector3 in rings:
		var layer: Array[Vector3] = []
		for index: int in range(sides):
			var angle: float = TAU*float(index)/float(sides)
			layer.append(Vector3(ring.x,cos(angle)*ring.y,sin(angle)*ring.z))
		layers.append(layer)
	for row: int in range(layers.size()-1):
		for index: int in range(sides):
			var next: int = (index+1)%sides; var outward: Vector3 = layers[row][index]+layers[row][next]; outward.x = 0.0
			_face(data,[layers[row][index],layers[row+1][index],layers[row+1][next],layers[row][next]],outward)
	_face(data,layers[0],Vector3.LEFT); _face(data,layers[-1],Vector3.RIGHT)
	return data

static func _loft_z(rings: Array[Vector3]) -> Dictionary:
	var data: Dictionary = _data(); var layers: Array = []
	for ring: Vector3 in rings:
		var layer: Array[Vector3] = []
		for unit: Vector2 in [Vector2(-0.78,-1),Vector2(0.78,-1),Vector2(1,-0.65),Vector2(1,0.65),Vector2(0.78,1),Vector2(-0.78,1),Vector2(-1,0.65),Vector2(-1,-0.65)]:
			layer.append(Vector3(unit.x*ring.x,unit.y*ring.y,ring.z))
		layers.append(layer)
	for row: int in range(layers.size()-1):
		for index: int in range(8):
			var next: int = (index+1)%8; var outward: Vector3 = layers[row][index]+layers[row][next]; outward.z = 0.0
			_face(data,[layers[row][index],layers[row+1][index],layers[row+1][next],layers[row][next]],outward)
	_face(data,layers[0],Vector3.FORWARD); _face(data,layers[-1],Vector3.BACK)
	return data

static func _mesh(data: Dictionary) -> ArrayMesh:
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices; arrays[Mesh.ARRAY_NORMAL] = data.normals
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
