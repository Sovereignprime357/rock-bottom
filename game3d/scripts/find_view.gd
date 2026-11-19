class_name RockBottomFindView
extends Node3D
## Original immutable pickup art. Runtime/Utilities own records, visibility and collection.
const Content = preload("res://scripts/content_catalog.gd")
const Surfaces = preload("res://scripts/surface_kit.gd")
const Batcher = preload("res://scripts/mesh_batcher.gd")
static var _templates: Dictionary = {}
static var _local_materials: Dictionary = {}
var presentation_kind: String = ""
var source_id: String = ""
var _mode: String = ""
var _art: Node3D
var _leaves: Array[MeshInstance3D] = []

static func create_cash() -> RockBottomFindView: return _create("cash")
static func create_crown() -> RockBottomFindView: return _create("crown")
static func _create(mode: String) -> RockBottomFindView:
	var result := RockBottomFindView.new()
	result.name = "CashFind" if mode == "cash" else "CrownFind"
	result._mode = mode; result.visible = false
	result._art = Node3D.new(); result._art.name = "Art"; result.add_child(result._art)
	return result

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
func _hide_invalid() -> bool:
	visible = false; source_id = ""
	return false
func project_cash(record: Dictionary,is_visible: bool) -> bool:
	if _mode != "cash" or not record.get("id") is String or str(record.id).is_empty() or not _number(record.get("x")) or not _number(record.get("y")):
		return _hide_invalid()
	# Exact source renderer priority; other valid/unknown equipment still draws money.
	var torch: bool = record.get("tool") is String and record.tool == "propane_torch"
	var collar: bool = record.get("equip") is String and record.equip == "priest_collar"
	var kind: String = "propane_torch" if torch else ("priest_collar" if collar else "money")
	return _project(kind,str(record.id),Vector2(record.x,record.y),is_visible and not record.get("collected",false))
func project_crown(record: Variant) -> bool:
	if _mode != "crown" or not record is Dictionary or not _number(record.get("x")) or not _number(record.get("y")):
		return _hide_invalid()
	return _project("crown","quest:crown",Vector2(record.x,record.y),not record.get("collected",true))
func _project(kind: String,id: String,point: Vector2,shown: bool) -> bool:
	# Finite scalar input can still overflow the engine's Vector2 representation.
	if not point.is_finite(): return _hide_invalid()
	var at: Vector3 = Content.to_world(point)
	if not at.is_finite(): return _hide_invalid()
	if presentation_kind != kind:
		for leaf: MeshInstance3D in _leaves: leaf.free()
		_leaves.clear()
		for row: Dictionary in _template(kind):
			var leaf := MeshInstance3D.new(); leaf.name = row.name; leaf.mesh = row.mesh; leaf.transform = row.transform
			_art.add_child(leaf); _leaves.append(leaf)
		presentation_kind = kind
	source_id = id
	if position != at: position = at
	if visible != shown: visible = shown
	return true

static func _template(kind: String) -> Array:
	if _templates.has(kind): return _templates[kind]
	var temporary := Node3D.new()
	match kind:
		"money": _money(temporary)
		"propane_torch": _torch(temporary)
		"priest_collar": _collar(temporary)
		"crown": _crown(temporary)
	Batcher.batch_children(temporary,0.0)
	var result: Array[Dictionary] = []
	for leaf: Node in temporary.get_children():
		if leaf is MeshInstance3D:
			result.append({"name":leaf.name,"mesh":leaf.mesh,"transform":leaf.transform})
	temporary.free(); _templates[kind] = result
	return result

static func _paint(kind: String,color: String,emission: float = 0.0) -> StandardMaterial3D:
	var key: String = kind+"/"+color+"/"+str(emission)
	if _local_materials.has(key): return _local_materials[key]
	var result: StandardMaterial3D = Surfaces.material(kind,color,0.94,emission)
	if result.uv1_world_triplanar:
		result = result.duplicate() as StandardMaterial3D
		result.uv1_world_triplanar = false
	_local_materials[key] = result
	return result
static func _part(parent: Node3D,label: String,mesh: Mesh,color: String,kind: String = "plain",emission: float = 0.0) -> MeshInstance3D:
	var result := MeshInstance3D.new(); result.name = label; result.mesh = mesh
	result.material_override = _paint(kind,color,emission); parent.add_child(result)
	return result
static func _box(parent: Node3D,label: String,at: Vector3,size: Vector3,color: String,kind: String = "plain",rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new(); mesh.size = size
	var result: MeshInstance3D = _part(parent,label,mesh,color,kind)
	result.position = at; result.rotation = rotation
static func _data() -> Dictionary: return {"vertices":PackedVector3Array(),"normals":PackedVector3Array()}
static func _triangle(data: Dictionary,a: Vector3,b: Vector3,c: Vector3,outward: Vector3) -> void:
	var normal: Vector3 = -(b-a).cross(c-a)
	if normal.length_squared() < 0.000000000001: return
	if normal.dot(outward) < 0.0:
		var swap: Vector3 = b; b = c; c = swap; normal = -normal
	normal = normal.normalized()
	data.vertices.append_array(PackedVector3Array([a,b,c]))
	data.normals.append_array(PackedVector3Array([normal,normal,normal]))
static func _face(data: Dictionary,points: Array,outward: Vector3) -> void:
	for index: int in range(1,points.size()-1): _triangle(data,points[0],points[index],points[index+1],outward)
static func _finish(parent: Node3D,label: String,data: Dictionary,color: String,kind: String = "plain",emission: float = 0.0) -> MeshInstance3D:
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices; arrays[Mesh.ARRAY_NORMAL] = data.normals
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return _part(parent,label,mesh,color,kind,emission)
static func _slab(parent: Node3D,label: String,outline: Array[Vector3],thickness: float,color: String,kind: String = "plain") -> void:
	var data: Dictionary = _data(); var lower: Array[Vector3] = []
	var center := Vector3.ZERO
	for point: Vector3 in outline: lower.append(point-Vector3(0,thickness,0)); center += point
	center /= float(outline.size())
	_face(data,outline,Vector3.UP); _face(data,lower,Vector3.DOWN)
	for index: int in range(outline.size()):
		var next: int = (index+1)%outline.size()
		var outward: Vector3 = (outline[index]+outline[next])*0.5-center; outward.y = 0.0
		_face(data,[outline[index],lower[index],lower[next],outline[next]],outward)
	_finish(parent,label,data,color,kind)

static func _money(parent: Node3D) -> void:
	# Different edges belong to one find; amount never spawns extra collectible objects.
	_slab(parent,"lower_note",[Vector3(-0.169,0.011,-0.069),Vector3(0.151,0.011,-0.091),Vector3(0.169,0.011,0.068),Vector3(-0.151,0.011,0.091)],0.003,"9c945b")
	_slab(parent,"middle_note",[Vector3(-0.158,0.016,-0.088),Vector3(0.164,0.016,-0.074),Vector3(0.156,0.016,0.087),Vector3(-0.166,0.016,0.074)],0.003,"b5aa6e")
	var outline: Array[Vector3] = [Vector3(-0.16,0.022,-0.078),Vector3(0.109,0.022,-0.078),Vector3(0.16,0.022,-0.032),Vector3(0.16,0.022,0.078),Vector3(-0.16,0.022,0.078)]
	_slab(parent,"top_note",outline,0.003,"c6b767")
	_slab(parent,"creased_corner",[outline[1],Vector3(0.153,0.051,-0.069),outline[2]],0.002,"d4c896")
	# A broad frame and abstract portrait/ledger marks are authored geometry, no real bill.
	for z: float in [-0.059,0.059]: _box(parent,"note_border",Vector3(-0.016,0.024,z),Vector3(0.250,0.0015,0.004),"756c39")
	for x: float in [-0.14,0.11]: _box(parent,"note_border",Vector3(x,0.024,0),Vector3(0.004,0.0015,0.118),"756c39")
	_slab(parent,"portrait_ink",[Vector3(-0.041,0.025,-0.018),Vector3(-0.022,0.025,-0.041),Vector3(0.011,0.025,-0.035),Vector3(0.027,0.025,0.004),Vector3(0.010,0.025,0.036),Vector3(-0.025,0.025,0.032)],0.001,"8b814a")
	_box(parent,"portrait_cut",Vector3(-0.007,0.027,-0.007),Vector3(0.019,0.001,0.033),"bbae67", "plain",Vector3(0,0.17,0))
	for side: float in [-1.0,1.0]:
		for line: int in range(3): _box(parent,"printed_line",Vector3(side*0.083,0.026,-0.020+float(line)*0.015),Vector3(0.038-float(line)*0.006,0.001,0.003),"756c39")
	_box(parent,"fold_shadow",Vector3(0.048,0.025,0.002),Vector3(0.002,0.001,0.144),"a49752")

static func _loft(parent: Node3D,label: String,rings: Array[Vector2],color: String,kind: String = "plain",dented: bool = false) -> MeshInstance3D:
	var data: Dictionary = _data(); var layers: Array = []; var sides: int = 12
	for row: int in range(rings.size()):
		var layer: Array[Vector3] = []
		for index: int in range(sides):
			var angle: float = float(index)*TAU/float(sides)
			var radius: float = rings[row].x
			if dented and row in [1,2] and index in [2,3]: radius *= 0.82 if index == 2 else 0.94
			layer.append(Vector3(sin(angle)*radius,rings[row].y,cos(angle)*radius))
		layers.append(layer)
	for row: int in range(layers.size()-1):
		for index: int in range(sides):
			var next: int = (index+1)%sides
			var outward: Vector3 = layers[row][index]+layers[row][next]; outward.y = 0.0
			_face(data,[layers[row][index],layers[row+1][index],layers[row+1][next],layers[row][next]],outward)
	_face(data,layers[0],Vector3.DOWN); _face(data,layers[-1],Vector3.UP)
	return _finish(parent,label,data,color,kind)
static func _rod(parent: Node3D,label: String,from: Vector3,to: Vector3,radius: float,color: String,kind: String = "plain") -> void:
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = from.distance_to(to); mesh.radial_segments = 8; mesh.rings = 1
	var result: MeshInstance3D = _part(parent,label,mesh,color,kind)
	result.position = (from+to)*0.5
	var direction: Vector3 = (to-from).normalized()
	var right: Vector3 = direction.cross(Vector3.FORWARD if absf(direction.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	result.basis = Basis(right,direction,right.cross(direction)).orthonormalized()
static func _torch(parent: Node3D) -> void:
	_loft(parent,"rubber_foot",[Vector2(0.075,0.010),Vector2(0.090,0.019),Vector2(0.090,0.035),Vector2(0.080,0.041)],"514a30","rubber")
	_loft(parent,"dented_brass_reservoir",[Vector2(0.080,0.032),Vector2(0.087,0.055),Vector2(0.083,0.217),Vector2(0.057,0.243),Vector2(0.026,0.251)],"b88443","painted_metal",true)
	_loft(parent,"rolled_shoulder_seam",[Vector2(0.084,0.213),Vector2(0.086,0.219),Vector2(0.075,0.226)],"8e6939","painted_metal")
	_loft(parent,"neck",[Vector2(0.025,0.245),Vector2(0.025,0.276),Vector2(0.018,0.281)],"735631","painted_metal")
	_rod(parent,"bent_nozzle",Vector3(0.009,0.270,0),Vector3(0.103,0.301,0),0.014,"a57843","painted_metal")
	_rod(parent,"nozzle_lip",Vector3(0.094,0.298,0),Vector3(0.114,0.306,0),0.019,"574d33","painted_metal")
	_rod(parent,"valve_spindle",Vector3(-0.009,0.268,0),Vector3(-0.064,0.268,0),0.009,"6d5938","painted_metal")
	for index: int in range(5):
		var angle: float = float(index)*TAU/5.0
		var next: float = float(index+1)*TAU/5.0
		var point := Vector3(-0.066,0.268+sin(angle)*0.029,cos(angle)*0.029)
		_rod(parent,"valve_rim",point,Vector3(-0.066,0.268+sin(next)*0.029,cos(next)*0.029),0.006,"614d2c")
		_rod(parent,"valve_spoke",Vector3(-0.066,0.268,0),point,0.0035,"614d2c")
	_box(parent,"creased_paper_label",Vector3(-0.005,0.132,0.080),Vector3(0.079,0.074,0.003),"b6aa72")
	for row: int in range(3): _box(parent,"label_accounting",Vector3(-0.008,0.151-float(row)*0.018,0.082),Vector3(0.050-float(row)*0.008,0.005,0.001),"6b623d")
	# Small attached abstract pilot. It has no light, timer or operational gameplay.
	var pilot: Dictionary = _data()
	var base: Array[Vector3] = [Vector3(0.113,0.304,-0.011),Vector3(0.113,0.295,0),Vector3(0.113,0.304,0.011),Vector3(0.113,0.316,0)]
	var tip := Vector3(0.144,0.352,0.002)
	for index: int in range(base.size()):
		var next: int = (index+1)%base.size()
		_triangle(pilot,base[index],base[next],tip,((base[index]+base[next])*0.5-Vector3(0.113,0.304,0)).normalized())
	_face(pilot,base,Vector3.LEFT)
	_finish(parent,"sodium_pilot",pilot,"e8c040","plain",0.22)

static func _collar(parent: Node3D) -> void:
	var outside: Dictionary = _data(); var inside: Dictionary = _data(); var edge: Dictionary = _data()
	var layers: Array = []
	for index: int in range(19):
		var angle: float = lerpf(-2.63,2.63,float(index)/18.0)
		var height: float = 0.065+0.008*sin(angle*3.0)
		var outer := Vector3(sin(angle)*0.180,0,cos(angle)*0.112)
		var inner := Vector3(sin(angle)*0.166,0,cos(angle)*0.098)
		layers.append([outer+Vector3(0,0.013,0),outer+Vector3(0,height,0),inner+Vector3(0,height,0),inner+Vector3(0,0.013,0)])
	for index: int in range(layers.size()-1):
		var a: Array = layers[index]; var b: Array = layers[index+1]
		var radial: Vector3 = (Vector3(a[0])+Vector3(b[0]))*0.5; radial.y = 0
		_face(outside,[a[0],a[1],b[1],b[0]],radial)
		_face(inside,[a[3],b[3],b[2],a[2]],-radial)
		_face(edge,[a[1],a[2],b[2],b[1]],Vector3.UP)
		_face(edge,[a[0],b[0],b[3],a[3]],Vector3.DOWN)
	_face(edge,layers[0],Vector3(-1,0,-1)); _face(edge,layers[-1],Vector3(1,0,-1))
	_finish(parent,"cream_cloth_band",outside,"d4c896","fabric")
	_finish(parent,"worn_inner_band",inside,"a99e78","fabric")
	_finish(parent,"folded_cloth_edges",edge,"bfb388","fabric")
	_box(parent,"reversed_dark_tab",Vector3(0,0.039,0.114),Vector3(0.064,0.038,0.007),"27281d")
	_box(parent,"tab_seam",Vector3(0.014,0.039,0.118),Vector3(0.003,0.035,0.001),"716c4d")
	for side: float in [-1.0,1.0]:
		_box(parent,"folded_end",Vector3(side*0.084,0.029,-0.101),Vector3(0.045,0.043,0.013),"c5ba8a","fabric",Vector3(0,side*0.49,side*0.12))

static func _crown(parent: Node3D) -> void:
	var outer: Dictionary = _data(); var inner: Dictionary = _data(); var rim: Dictionary = _data()
	var layers: Array = []
	for index: int in range(12):
		var angle: float = float(index)*TAU/12.0
		var high: float = 0.078
		if index%2 == 0: high = 0.205 if index == 0 else (0.173 if index in [2,10] else 0.131)
		var radius: float = 0.147*(0.95 if index in [5,6] else 1.0)
		var direction := Vector3(sin(angle),0,cos(angle))
		layers.append([direction*radius+Vector3(0,0.014,0),direction*radius+Vector3(0,high,0),direction*(radius-0.014)+Vector3(0,high,0),direction*(radius-0.014)+Vector3(0,0.014,0)])
	for index: int in range(12):
		var a: Array = layers[index]; var b: Array = layers[(index+1)%12]
		var radial: Vector3 = (Vector3(a[0])+Vector3(b[0]))*0.5; radial.y = 0
		_face(outer,[a[0],a[1],b[1],b[0]],radial)
		_face(inner,[a[3],b[3],b[2],a[2]],-radial)
		_face(rim,[a[1],a[2],b[2],b[1]],Vector3.UP)
		_face(rim,[a[0],b[0],b[3],a[3]],Vector3.DOWN)
	_finish(parent,"bent_brass_crown",outer,"b69b47")
	_finish(parent,"dull_inside",inner,"786131")
	_finish(parent,"exposed_edges",rim,"d0b45b")
	var setting: Dictionary = _data(); var gem: Dictionary = _data()
	var diamond: Array[Vector3] = [Vector3(0,0.132,0.150),Vector3(0.025,0.099,0.150),Vector3(0,0.071,0.150),Vector3(-0.025,0.099,0.150)]
	_face(setting,diamond,Vector3.FORWARD*-1)
	_finish(parent,"gem_setting",setting,"746137")
	var center := Vector3(0,0.102,0.161)
	for index: int in range(4):
		var a: Vector3 = diamond[index].lerp(Vector3(0,0.102,0.150),0.17)
		var b: Vector3 = diamond[(index+1)%4].lerp(Vector3(0,0.102,0.150),0.17)
		a.z = 0.152; b.z = 0.152
		_triangle(gem,a,b,center,Vector3.BACK)
	_finish(parent,"purple_glass_gem",gem,"b978b2")
	# Dull flat rivets stay on the band instead of reading as separate beads.
	for index: int in [1,3,5,7,9,11]:
		var angle: float = float(index)*TAU/12.0
		_box(parent,"flat_rivet",Vector3(sin(angle)*0.143,0.045,cos(angle)*0.143),Vector3(0.010,0.011,0.004),"d0b45b","plain",Vector3(0,angle,0))
