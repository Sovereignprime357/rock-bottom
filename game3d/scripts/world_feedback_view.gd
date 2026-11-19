extends Node3D
## Passive world-space geometry. Caller keeps this root at identity and explicitly syncs it.
const Feedback = preload("world_feedback.gd")
const METRES_PER_PIXEL := 0.04
const BANKS: Array[String] = ["fragment_mix","flash_mix","fragment_add","flash_add"]
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _radii: Dictionary = {}
static var _roll_bases: Array[Basis] = []
const ROLL_DEGREES: Array[float] = [-67.0,-19.0,23.0,71.0]
var _banks: Dictionary = {}
var _counts: Dictionary = {}
var _uploads: int = 0
var _epoch: int = 0
var _revision: int = -1

func _init() -> void:
	set_process(false); set_physics_process(false); set_process_input(false); set_process_unhandled_input(false)

func build() -> bool:
	if not _banks.is_empty(): return true
	for key: String in BANKS:
		var bank := MultiMeshInstance3D.new(); bank.name = key
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D; instances.use_colors = true
		instances.mesh = _geometry("flash" if key.begins_with("flash") else "fragment")
		instances.instance_count = Feedback.CAPACITY; instances.visible_instance_count = 0
		bank.multimesh = instances; bank.material_override = _material(key.ends_with("add"))
		bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bank.visible = false; add_child(bank); _banks[key] = bank; _counts[key] = 0
	return true

func clear() -> void:
	for key: String in _banks:
		var bank: MultiMeshInstance3D = _banks[key]
		bank.multimesh.visible_instance_count = 0; bank.visible = false; _counts[key] = 0
	_epoch = 0; _revision = -1

func _invalid() -> bool:
	clear(); return false

static func _valid_row(row: Variant) -> bool:
	if not row is Dictionary: return false
	if not row.get("serial") is int or row.serial <= 0 or row.get("recipe") not in Feedback.RECIPES: return false
	if not Feedback._world(row.get("world_anchor")) or not Feedback._point(row.get("source_point")) or not Feedback._right(row.get("birth_right")): return false
	if absf(row.birth_right.length_squared()-1.0) > 0.00001: return false
	if not row.get("offset") is Vector2 or not row.offset.is_finite() or row.offset.length_squared() > 1e12: return false
	var max_life: float = 6000.0 if row.recipe == "ambient_mote" else (580.0 if row.recipe == "walking_dust" else 1400.0)
	if not Feedback._number(row.get("life")) or row.life <= 0 or row.life > max_life: return false
	if not Feedback._number(row.get("size")) or row.size <= 0 or row.size > 14: return false
	if not row.get("glow") is bool or row.get("shape") not in ["fragment","flash"]: return false
	if not row.get("color") is Color: return false
	var color: Color = row.color
	for value: float in [color.r,color.g,color.b,color.a]:
		if not is_finite(value) or value < 0 or value > 1: return false
	return true

func sync(snapshot: Dictionary) -> bool:
	if _banks.is_empty(): return false
	if not snapshot.get("epoch") is int or snapshot.epoch <= 0 or not snapshot.get("revision") is int: return _invalid()
	if not snapshot.get("particles") is Array or snapshot.particles.size() > Feedback.CAPACITY: return _invalid()
	var serials: Dictionary = {}
	for row: Variant in snapshot.particles:
		if not _valid_row(row) or serials.has(row.serial): return _invalid()
		serials[row.serial] = true
	# All rows preflight before any visible bank changes. A snapshot is not retained.
	var counts: Dictionary = {}; var bounds: Dictionary = {}
	for key: String in BANKS: counts[key] = 0
	for row: Dictionary in snapshot.particles:
		var key: String = str(row.shape)+("_add" if row.glow else "_mix")
		var bank: MultiMeshInstance3D = _banks[key]
		var pose: Transform3D = _instance_pose(row)
		var color: Color = row.color
		if row.glow: color.a *= clampf(float(row.life)/700.0,0,1)
		bank.multimesh.set_instance_transform(counts[key],pose)
		bank.multimesh.set_instance_color(counts[key],color)
		var bound: AABB = _instance_bounds(row,pose)
		bounds[key] = bounds[key].merge(bound) if bounds.has(key) else bound
		counts[key] += 1
	for key: String in BANKS:
		var bank: MultiMeshInstance3D = _banks[key]
		bank.multimesh.visible_instance_count = counts[key]
		bank.visible = counts[key] > 0
		if bounds.has(key): bank.multimesh.custom_aabb = bounds[key]
	_counts = counts; _epoch = snapshot.epoch; _revision = snapshot.revision; _uploads += 1
	return true

func inspect() -> Dictionary:
	var live: int = 0; var triangles: int = 0
	for key: String in _counts:
		live += _counts[key]; triangles += _counts[key]*4
	return {"banks":_banks.size(),"allocated_slots":_banks.size()*Feedback.CAPACITY,"live":live,"triangles":triangles,"counts":_counts.duplicate(),"uploads":_uploads,"epoch":_epoch,"revision":_revision,"meshes":_meshes.size(),"materials":_materials.size()}

static func _roll_index(recipe: String,serial: int) -> int:
	return posmod(posmod(int(recipe.hash()),4)+posmod(serial,4),4)

static func _instance_pose(row: Dictionary) -> Transform3D:
	var at: Vector3 = row.world_anchor+row.birth_right*(row.offset.x*METRES_PER_PIXEL)-Vector3.UP*(row.offset.y*METRES_PER_PIXEL)
	var size: float = float(row.size)*(2.0 if row.glow else 1.0)*METRES_PER_PIXEL
	var axes := Basis(row.birth_right,Vector3.UP,row.birth_right.cross(Vector3.UP))
	if row.shape == "fragment":
		if _roll_bases.is_empty():
			for angle: float in ROLL_DEGREES: _roll_bases.append(Basis(Vector3.BACK,deg_to_rad(angle)))
		axes = axes*_roll_bases[_roll_index(str(row.recipe),int(row.serial))]
	return Transform3D(axes.scaled(Vector3.ONE*size),at)

static func _instance_bounds(row: Dictionary,pose: Transform3D) -> AABB:
	_geometry(str(row.shape))
	var size: float = float(row.size)*(2.0 if row.glow else 1.0)*METRES_PER_PIXEL
	var magnitude: float = maxf(absf(pose.origin.x),maxf(absf(pose.origin.y),absf(pose.origin.z)))
	var roundoff: float = maxf(0.00001,magnitude/4194304.0)+size*0.000001
	var radius: float = float(_radii[row.shape])*size+roundoff
	return AABB(pose.origin-Vector3.ONE*radius,Vector3.ONE*(radius*2.0))

static func _material(additive: bool) -> StandardMaterial3D:
	var key: String = "add" if additive else "mix"
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		material.vertex_color_use_as_albedo = true
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.no_depth_test = false; material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 1.0
		_materials[key] = material
	return _materials[key]

static func _triangle(vertices: PackedVector3Array,normals: PackedVector3Array,a: Vector3,b: Vector3,c: Vector3,outward: Vector3) -> void:
	var normal: Vector3 = -(b-a).cross(c-a)
	if normal.dot(outward) < 0:
		var swap: Vector3 = b; b = c; c = swap; normal = -normal
	normal = normal.normalized()
	vertices.append_array(PackedVector3Array([a,b,c])); normals.append_array(PackedVector3Array([normal,normal,normal]))

static func _geometry(shape: String) -> ArrayMesh:
	if _meshes.has(shape): return _meshes[shape]
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var colors := PackedColorArray()
	if shape == "flash":
		var rim: Array[Vector3] = [Vector3(0.5,0,0),Vector3(0,0.5,0),Vector3(-0.5,0,0),Vector3(0,-0.5,0)]
		for index: int in range(4):
			_triangle(vertices,normals,Vector3.ZERO,rim[index],rim[(index+1)%4],Vector3.BACK)
			colors.append_array(PackedColorArray([Color(1,1,1,1),Color(1,1,1,0),Color(1,1,1,0)]))
	else:
		var points: Array[Vector3] = [Vector3(-0.5,-0.12,-0.04),Vector3(0.5,-0.08,-0.04),Vector3(-0.12,0.21,-0.04),Vector3(0.08,0.015,0.06)]
		var middle: Vector3 = (points[0]+points[1]+points[2]+points[3])*0.25
		for face: Array in [[0,1,2],[0,3,1],[1,3,2],[2,3,0]]:
			var a: Vector3 = points[face[0]]; var b: Vector3 = points[face[1]]; var c: Vector3 = points[face[2]]
			_triangle(vertices,normals,a,b,c,(a+b+c)/3.0-middle)
			colors.append_array(PackedColorArray([Color(1,1,1,1),Color(1,1,1,1),Color(1,1,1,1)]))
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_COLOR] = colors
	var radius := 0.0
	for vertex: Vector3 in vertices: radius = maxf(radius,vertex.length())
	_radii[shape] = radius
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_meshes[shape] = mesh
	return mesh
