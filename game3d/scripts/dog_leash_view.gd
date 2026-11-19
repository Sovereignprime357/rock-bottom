class_name RockBottomDogLeashView
extends Node3D
## Fixed visual chain. Caller supplies actual post and weighted collar positions.
const Surfaces = preload("res://scripts/surface_kit.gd")
const Art = preload("res://scripts/character_art.gd")
static var _segment_mesh: CylinderMesh
static var _link_mesh: ArrayMesh
static var _dark: StandardMaterial3D
static var _worn: StandardMaterial3D
var _segments: MultiMeshInstance3D
var _links: MultiMeshInstance3D
var _points := PackedVector3Array()
var _last_post := Vector3(INF,INF,INF)
var _last_collar := Vector3(INF,INF,INF)
var _active: bool = false
var _transform_writes: int = 0

static func create() -> RockBottomDogLeashView:
	_prepare()
	var result := RockBottomDogLeashView.new(); result.name = "DogLeash"
	result._segments = _instances("Segments",_segment_mesh,_dark,6)
	result._links = _instances("Links",_link_mesh,_worn,5)
	result.add_child(result._segments); result.add_child(result._links)
	result._points.resize(7); result.visible = false
	return result

static func _prepare() -> void:
	if _segment_mesh != null: return
	_segment_mesh = CylinderMesh.new(); _segment_mesh.height = 1.0
	_segment_mesh.top_radius = 0.012; _segment_mesh.bottom_radius = 0.012
	_segment_mesh.radial_segments = 6; _segment_mesh.rings = 1
	_dark = Surfaces.material("plain","3a2810",0.96)
	_worn = Surfaces.material("plain","5a4828",0.94)
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in range(8):
		var a: float = TAU*float(ring)/8.0; var b: float = TAU*float(ring+1)/8.0
		for side: int in range(4):
			var c: float = TAU*float(side)/4.0; var d: float = TAU*float(side+1)/4.0
			var aa := _ring_point(a,c); var ab := _ring_point(b,c)
			var ba := _ring_point(a,d); var bb := _ring_point(b,d)
			Art._triangle(surface,aa,ab,ba); Art._triangle(surface,ab,bb,ba)
	_link_mesh = surface.commit()

static func _ring_point(angle: float,side: float) -> Vector3:
	return Vector3(cos(angle)*(0.024+cos(side)*0.007),sin(angle)*(0.034+cos(side)*0.007),sin(side)*0.007)

static func _instances(label: String,mesh: Mesh,material: Material,count: int) -> MultiMeshInstance3D:
	var result := MultiMeshInstance3D.new(); result.name = label
	var instances := MultiMesh.new(); instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh; instances.instance_count = count
	result.multimesh = instances; result.material_override = material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result

static func _basis(direction: Vector3) -> Basis:
	var y: Vector3 = direction.normalized()
	var reference: Vector3 = Vector3.RIGHT if absf(y.dot(Vector3.UP)) > 0.999 else Vector3.UP
	var x: Vector3 = y.cross(reference).normalized()
	return Basis(x,y,x.cross(y).normalized())

static func _point(post: Vector3,collar: Vector3,t: float,sag: float) -> Vector3:
	var mid: Vector3 = (post+collar)*0.5+Vector3.DOWN*sag
	return post.lerp(mid,t*2.0) if t <= 0.5 else mid.lerp(collar,(t-0.5)*2.0)

func sync(snapshot: Dictionary) -> bool:
	if not snapshot.get("post_present") is bool or not snapshot.get("dog") is Dictionary:
		clear(); return false
	var dog: Dictionary = snapshot.dog
	if not dog.is_empty() and (not dog.get("id") is String or not dog.get("dead") is bool):
		clear(); return false
	# Source deliberately ignores chained/hidden; only this original living id binds.
	if not snapshot.post_present or dog.is_empty() or dog.id != "scrap_dog" or dog.dead:
		clear(); return true
	if not snapshot.get("post_position") is Vector3 or not snapshot.get("collar_position") is Vector3:
		clear(); return false
	var post: Vector3 = snapshot.post_position; var collar: Vector3 = snapshot.collar_position
	var space: Transform3D = global_transform if is_inside_tree() else transform
	var determinant: float = space.basis.determinant()
	if not post.is_finite() or not collar.is_finite() or not space.is_finite() or not is_finite(determinant) or absf(determinant) <= 0.000001:
		clear(); return false
	var inverse: Transform3D = space.affine_inverse()
	post = inverse*post; collar = inverse*collar
	var distance: float = post.distance_to(collar)
	if not post.is_finite() or not collar.is_finite() or not is_finite(distance):
		clear(); return false
	if distance <= 0.000001:
		clear(); return true
	if post != _last_post or collar != _last_collar:
		var sag: float = minf(0.16,distance*0.15)
		for index: int in range(7): _points[index] = _point(post,collar,float(index)/6.0,sag)
		for index: int in range(6):
			var offset: Vector3 = _points[index+1]-_points[index]
			var basis: Basis = _basis(offset)
			basis.y *= offset.length()
			_segments.multimesh.set_instance_transform(index,Transform3D(basis,(_points[index]+_points[index+1])*0.5))
		for index: int in range(5):
			var t: float = 0.15+0.18*float(index)
			var tangent: Vector3 = _point(post,collar,minf(1.0,t+0.001),sag)-_point(post,collar,maxf(0.0,t-0.001),sag)
			var basis: Basis = _basis(tangent)*Basis(Vector3.UP,PI*0.5 if index%2 == 0 else 0.0)
			_links.multimesh.set_instance_transform(index,Transform3D(basis,_point(post,collar,t,sag)))
		_transform_writes += 11; _last_post = post; _last_collar = collar
	if not _active: visible = true
	_active = true
	return true

func clear() -> void:
	if _active: visible = false
	_active = false

func inspect() -> Dictionary:
	return {"active":_active,"segments":6,"links":5,"transform_writes":_transform_writes,
		"queries":0,"dynamic_shadows":0,"points":_points.duplicate() if _active else PackedVector3Array()}
