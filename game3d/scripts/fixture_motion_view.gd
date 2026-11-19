class_name RockBottomFixtureMotionView
extends Node3D
## Pure supplied-clock fixture motion; World attachments, Scene clocks, no gameplay authority.
const Content = preload("res://scripts/content_catalog.gd")
const Surface = preload("res://scripts/surface_kit.gd")
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _sodium_shader: Shader
const SODIUM_OFFSETS: Array[Vector2] = [Vector2(80,80),Vector2(220,140),Vector2(320,70)]
const SODIUM_SURFACE_CAP := 64
const SODIUM_PIECE_CAP := 256
const SODIUM_VERTEX_CAP := 16
const SODIUM_TRIANGLE_CAP := 4096
var _bindings: Dictionary = {}
var _tv: Node3D
var _screen: MeshInstance3D
var _washers: Array[Node3D] = []
var _panes: Array[MeshInstance3D] = []
var _patches: Array[MeshInstance3D] = []
var _steam: MeshInstance3D
var _shadows: Array[MeshInstance3D] = []
var _tv_bright: Material
var _tv_dim: Material
var _pane_day: Material
var _pane_night: Material
var _sample: Dictionary = {}
var _transform_writes: int = 0
var _material_writes: int = 0
var _visibility_writes: int = 0
var _sodium: MeshInstance3D
var _sodium_material: ShaderMaterial
var _sodium_alpha: float = -1.0
var _uniform_writes: int = 0
var _sodium_triangles: int = 0

static func create() -> RockBottomFixtureMotionView:
	var view := RockBottomFixtureMotionView.new(); view.name = "SourceFixtureMotion"; return view
static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
static func _transform(value: Variant) -> bool:
	return value is Transform3D and value.is_finite() and is_finite(value.basis.determinant()) and absf(value.basis.determinant()) > 0.00001
static func _corridor(source: Rect2) -> Rect2:
	var start: Vector3 = Content.to_world(Vector2(source.position.x,source.position.y-10.0))
	return Rect2(Vector2(start.x,start.z),Vector2((source.size.x*1.2+120.0)*0.04,0.32))
static func source_sample(visual_ms: float,unix_ms: float,day_time: float) -> Dictionary:
	if not is_finite(visual_ms) or not is_finite(unix_ms) or not is_finite(day_time) or visual_ms < 0 or unix_ms < 0 or day_time < 0 or day_time > 1: return {}
	var night: bool = day_time < 0.25 or day_time > 0.75
	var washer_offsets: Array[Dictionary] = []
	for index: int in range(4):
		var phase: float = visual_ms/300.0+float(index)
		washer_offsets.append({"x":cos(phase)*2.0,"y":sin(phase)*2.0})
	var steam_phase: float = visual_ms/400.0
	var car_phase: float = fposmod(unix_ms/8000.0,1.0)
	return {"tv_on":sin(visual_ms/110.0) > 0.3,"washers":washer_offsets,"pane_alpha":0.8 if night else 0.665,
		"steam_visible":night,"steam_x":sin(steam_phase)*2.0,"steam_rise":fposmod(steam_phase,4.0)*1.5,
		"shadow_visible":car_phase < 0.2,"shadow_phase":car_phase,"sodium_alpha":0.32+((sin(visual_ms/700.0)+1.0)/2.0)*0.08}

static func polygon_area(polygon: PackedVector2Array) -> float:
	# Translate before the cross products to avoid cancellation at far world coordinates.
	if polygon.size() < 3: return 0.0
	var area: float = 0.0
	for index: int in range(1,polygon.size()-1): area += (polygon[index]-polygon[0]).cross(polygon[index+1]-polygon[0])
	return area*0.5
static func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
static func _half_plane(polygon: PackedVector2Array,a: Vector2,b: Vector2,inside: bool = true) -> PackedVector2Array:
	var result := PackedVector2Array()
	if polygon.is_empty(): return result
	var sign_value: float = 1.0 if inside else -1.0
	var previous: Vector2 = polygon[-1]
	var previous_d: float = (b-a).cross(previous-a)*sign_value
	for current: Vector2 in polygon:
		var current_d: float = (b-a).cross(current-a)*sign_value
		if (current_d >= 0.0) != (previous_d >= 0.0):
			var hit: Vector2 = previous.lerp(current,previous_d/(previous_d-current_d))
			if result.is_empty() or result[-1].distance_squared_to(hit) > 0.0000000001: result.append(hit)
		if current_d >= 0.0 and (result.is_empty() or result[-1].distance_squared_to(current) > 0.0000000001): result.append(current)
		previous = current; previous_d = current_d
	if result.size() > 1 and result[0].distance_squared_to(result[-1]) <= 0.0000000001: result.resize(result.size()-1)
	return result
static func polygon_intersection(subject: PackedVector2Array,clip: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = subject
	for index: int in range(clip.size()):
		result = _half_plane(result,clip[index],clip[(index+1)%clip.size()])
		if result.size() < 3: return PackedVector2Array()
	return result
static func _convex(polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3 or polygon.size() > SODIUM_VERTEX_CAP or polygon_area(polygon) <= 0.00000001: return false
	for index: int in range(polygon.size()):
		if not polygon[index].is_finite(): return false
		var a: Vector2 = polygon[index]; var b: Vector2 = polygon[(index+1)%polygon.size()]
		if a.distance_squared_to(b) <= 0.0000000001: return false
		for point: Vector2 in polygon:
			if (b-a).cross(point-a) < -0.00001: return false
	return true
static func partition_receivers(rect: Rect2,surfaces: Array[Dictionary]) -> Array[Dictionary]:
	# Build-only convex subtraction. Highest actual horizontal faces receive first.
	if surfaces.is_empty() or surfaces.size() > SODIUM_SURFACE_CAP: return []
	var ordered: Array[Dictionary] = surfaces.duplicate()
	for surface: Dictionary in ordered:
		if not surface.get("polygon") is PackedVector2Array or not _convex(surface.polygon) or not _number(surface.get("height")): return []
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.height) > float(b.height))
	var remaining: Array[PackedVector2Array] = [rect_polygon(rect)]
	var receivers: Array[Dictionary] = []
	for surface: Dictionary in ordered:
		var next: Array[PackedVector2Array] = []
		var clip: PackedVector2Array = surface.polygon
		for polygon: PackedVector2Array in remaining:
			var intersection: PackedVector2Array = polygon_intersection(polygon,clip)
			if polygon_area(intersection) <= 0.00000001: next.append(polygon); continue
			var inside: PackedVector2Array = polygon
			for edge: int in range(clip.size()):
				var outside: PackedVector2Array = _half_plane(inside,clip[edge],clip[(edge+1)%clip.size()],false)
				if polygon_area(outside) > 0.00000001:
					if not _convex(outside): return []
					next.append(outside)
				inside = _half_plane(inside,clip[edge],clip[(edge+1)%clip.size()])
				if inside.size() < 3: break
			if polygon_area(inside) > 0.00000001:
				if not _convex(inside): return []
				receivers.append({"polygon":inside,"height":float(surface.height)})
			if next.size()+receivers.size() > SODIUM_PIECE_CAP: return []
		remaining = next
		if remaining.is_empty(): break
	if not remaining.is_empty() or receivers.is_empty(): return []
	return receivers
static func _valid_sodium(bindings: Dictionary,source: Rect2) -> bool:
	if not bindings.get("sodium") is Array or bindings.sodium.size() != 3: return false
	var triangles: int = 0
	for index: int in range(3):
		var patch: Variant = bindings.sodium[index]
		if not patch is Dictionary or not patch.get("source_center") is Vector2 or patch.source_center != source.position+SODIUM_OFFSETS[index]: return false
		if not patch.get("receivers") is Array or patch.receivers.is_empty() or patch.receivers.size() > SODIUM_PIECE_CAP: return false
		var center: Vector3 = Content.to_world(patch.source_center)
		var rect := Rect2(Vector2(center.x-2.8,center.z-2.8),Vector2(5.6,5.6))
		var seen: Array[PackedVector2Array] = []; var area: float = 0.0
		for receiver: Variant in patch.receivers:
			if not receiver is Dictionary or not receiver.get("polygon") is PackedVector2Array or not _convex(receiver.polygon) or not _number(receiver.get("height")): return false
			if float(receiver.height) < 0.002 or float(receiver.height) > 0.0831: return false
			var polygon: PackedVector2Array = receiver.polygon
			for point: Vector2 in polygon:
				if not rect.grow(0.00001).has_point(point): return false
			for previous: PackedVector2Array in seen:
				if polygon_area(polygon_intersection(polygon,previous)) > 0.000002: return false
			seen.append(polygon); area += polygon_area(polygon); triangles += polygon.size()-2
		if absf(area-rect.get_area()) > 0.0002: return false
	return triangles <= SODIUM_TRIANGLE_CAP
static func sodium_gradient(radius_px: float,inner_alpha: float) -> Color:
	# Numerical contract for source stops; actual displayed3D color is renderer-dependent.
	var fraction: float = clampf((radius_px-4.0)/66.0,0.0,1.0)
	var inner := Color(232.0/255.0,140.0/255.0,40.0/255.0,inner_alpha)
	var middle := Color(220.0/255.0,120.0/255.0,30.0/255.0,0.18)
	return inner.lerp(middle,fraction*2.0) if fraction <= 0.5 else middle.lerp(Color(middle.r,middle.g,middle.b,0.0),(fraction-0.5)*2.0)
static func _sodium_program() -> Shader:
	if _sodium_shader == null:
		_sodium_shader = Shader.new()
		_sodium_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 inner_color : source_color = vec4(0.9098039216,0.5490196078,0.1568627451,1.0);
uniform vec4 outer_color : source_color = vec4(0.8627450980,0.4705882353,0.1176470588,1.0);
uniform float inner_alpha = 0.36;
void fragment() {
  float radius_px = length(UV-vec2(0.5))*140.0;
  float fraction = clamp((radius_px-4.0)/66.0,0.0,1.0);
  float first = min(fraction*2.0,1.0);
  ALBEDO = mix(inner_color.rgb,outer_color.rgb,first);
  ALPHA = fraction <= 0.5 ? mix(inner_alpha,0.18,first) : mix(0.18,0.0,(fraction-0.5)*2.0);
}
"""
	return _sodium_shader
func _build_sodium() -> void:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	for patch: Dictionary in _bindings.sodium:
		var center: Vector3 = Content.to_world(patch.source_center)
		for receiver: Dictionary in patch.receivers:
			var polygon: PackedVector2Array = receiver.polygon
			for index: int in range(1,polygon.size()-1):
				for point: Vector2 in [polygon[0],polygon[index],polygon[index+1]]:
					vertices.append(Vector3(point.x,float(receiver.height),point.y)); normals.append(Vector3.UP)
					uvs.append((point-Vector2(center.x,center.z))/5.6+Vector2(0.5,0.5))
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_sodium_material = ShaderMaterial.new(); _sodium_material.shader = _sodium_program()
	_sodium_triangles = vertices.size()/3
	_sodium = _part(self,"SodiumPatches",mesh,Vector3.ZERO,Vector3.ONE,_sodium_material)
static func _box() -> Mesh:
	if not _meshes.has("box"):
		var mesh := BoxMesh.new(); mesh.size = Vector3.ONE; _meshes.box = mesh
	return _meshes.box
static func _quad() -> Mesh:
	if not _meshes.has("quad"):
		var mesh := QuadMesh.new(); mesh.size = Vector2.ONE; _meshes.quad = mesh
	return _meshes.quad
static func _disc() -> Mesh:
	if not _meshes.has("disc"):
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector3Array(); var normals := PackedVector3Array()
		for segment: int in range(12):
			var a: float = -TAU*float(segment)/12.0; var b: float = -TAU*float(segment+1)/12.0
			vertices.append_array(PackedVector3Array([Vector3.ZERO,Vector3(cos(a),sin(a),0),Vector3(cos(b),sin(b),0)]))
			for unused: int in range(3): normals.append(Vector3.BACK)
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); _meshes.disc = mesh
	return _meshes.disc
static func _material(color: String,alpha: float = 1.0,emission: float = 0.0,unshaded: bool = false) -> StandardMaterial3D:
	var key: String = color+"/"+str(alpha)+"/"+str(emission)+"/"+str(unshaded)
	if not _materials.has(key):
		var material: StandardMaterial3D = Surface.material("plain",color,0.96,emission).duplicate()
		material.albedo_color.a = alpha
		if alpha < 1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_materials[key] = material
	return _materials[key]
static func _part(parent: Node3D,name: String,mesh: Mesh,at: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new(); part.name = name; part.mesh = mesh; part.material_override = material
	part.position = at; part.scale = size; part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part); return part
func _show(node: Node3D,value: bool) -> void:
	if node.visible != value: node.visible = value; _visibility_writes += 1
func _pose(node: Node3D,value: Transform3D) -> bool:
	if not value.is_finite() or not is_finite(value.basis.determinant()): return false
	if node.transform != value: node.transform = value; _transform_writes += 1
	return true
func _paint(node: MeshInstance3D,value: Material) -> void:
	if node.material_override != value: node.material_override = value; _material_writes += 1
func build(bindings: Dictionary) -> bool:
	if not _bindings.is_empty(): return bindings == _bindings
	if not bindings.get("tv_window") is Dictionary or not bindings.get("washers") is Array or bindings.washers.size() != 4 or not bindings.get("underpass") is Dictionary: return false
	var tv: Dictionary = bindings.tv_window; var underpass: Dictionary = bindings.underpass
	if not _transform(tv.get("transform")) or not tv.get("size") is Vector2 or not tv.size.is_finite() or tv.size.x <= 0 or tv.size.y <= 0: return false
	if not bindings.get("pawn_counter") is Dictionary: return false
	var pawn: Dictionary = bindings.pawn_counter
	if not _transform(pawn.get("transform")) or not pawn.get("size") is Vector2 or not pawn.size.is_finite() or pawn.size.x <= 0 or pawn.size.y <= 0: return false
	for face: Variant in bindings.washers:
		if not _transform(face): return false
	if not underpass.get("source_rect") is Rect2 or not underpass.source_rect.position.is_finite() or not underpass.source_rect.size.is_finite() or underpass.source_rect.size.x <= 0 or underpass.source_rect.size.y <= 0: return false
	if not underpass.get("receivers") is Array or underpass.receivers.is_empty() or underpass.receivers.size() > 16: return false
	var corridor: Rect2 = _corridor(underpass.source_rect); var area: float = 0.0
	var seen: Array[Rect2] = []
	for receiver: Variant in underpass.receivers:
		if not receiver is Dictionary or not receiver.get("rect") is Rect2 or not receiver.rect.position.is_finite() or not receiver.rect.size.is_finite() or receiver.rect.size.x <= 0 or receiver.rect.size.y <= 0 or not _number(receiver.get("height")): return false
		var rect: Rect2 = receiver.rect
		if rect.position.x < corridor.position.x-0.00001 or rect.position.y < corridor.position.y-0.00001 or rect.end.x > corridor.end.x+0.00001 or rect.end.y > corridor.end.y+0.00001: return false
		for previous: Rect2 in seen:
			if rect.intersection(previous).has_area(): return false
		seen.append(rect); area += rect.get_area()
	if absf(area-corridor.get_area()) > 0.0001: return false
	if not _valid_sodium(bindings,underpass.source_rect): return false
	_bindings = bindings.duplicate(true)
	_tv_bright = _material("b9b58e",1.0,0.45); _tv_dim = _material("39473f",1.0,0.08)
	_pane_day = _material("818378",0.665); _pane_night = _material("818378",0.8)
	_tv = Node3D.new(); _tv.name = "CornerTelevision"; add_child(_tv)
	var width: float = float(tv.size.x)*0.72; var height: float = float(tv.size.y)*0.56
	_part(_tv,"Case",_box(),Vector3(0,0.04,0.06),Vector3(width,height,0.16),_material("514b3e"))
	_part(_tv,"Bezel",_box(),Vector3(-width*0.04,0.06,0.145),Vector3(width*0.86,height*0.82,0.035),_material("292e27"))
	_screen = _part(_tv,"Screen",_quad(),Vector3(-width*0.04,0.06,0.165),Vector3(width*0.76,height*0.70,1),_tv_dim)
	for side: float in [-1.0,1.0]:
		_part(_tv,"Dial",_box(),Vector3(width*0.43,side*height*0.13,0.16),Vector3(0.045,0.045,0.035),_material("938b6a"))
	_part(_tv,"Stand",_box(),Vector3(0,-height*0.5-0.04,0.04),Vector3(width*0.25,0.14,0.10),_material("342b25"))
	for index: int in range(4):
		var holder := Node3D.new(); holder.name = "Washer"+str(index); add_child(holder); _washers.append(holder)
		_panes.append(_part(holder,"DrumPane",_disc(),Vector3(0,0,0.002),Vector3(0.16,0.16,1),_pane_day))
		_patches.append(_part(holder,"TurningPatch",_quad(),Vector3(0.08,0,0.004),Vector3(0.16,0.08,1),_material("292b24")))
	_steam = _part(self,"PocketSteam",_disc(),Vector3.ZERO,Vector3(0.06,0.06,1),_material("d4c896",0.4,0.0,true))
	for index: int in range(underpass.receivers.size()):
		_shadows.append(_part(self,"PassingShadow"+str(index),_quad(),Vector3.ZERO,Vector3.ONE,_material("151410",0.5,0.0,true)))
	_build_sodium()
	clear(); return true
func sync(snapshot: Dictionary,visual_ms: float,unix_ms: float) -> bool:
	if _bindings.is_empty() or not snapshot.get("world_visible") is bool: clear(); return false
	if not snapshot.world_visible: clear(); return true
	if not _number(snapshot.get("dayTime")) or not snapshot.get("food_visible") is bool: clear(); return false
	var sample: Dictionary = source_sample(visual_ms,unix_ms,float(snapshot.dayTime))
	if sample.is_empty() or not _transform(global_transform): clear(); return false
	var steam_active: bool = sample.steam_visible
	if steam_active and snapshot.food_visible and (not _transform(snapshot.get("food_transform")) or not snapshot.get("camera_basis") is Basis or not snapshot.camera_basis.is_finite() or not is_finite(snapshot.camera_basis.determinant()) or snapshot.camera_basis.determinant() < 0.00001): clear(); return false
	var inverse: Transform3D = global_transform.affine_inverse()
	if not _transform(inverse): clear(); return false
	var poses_valid: bool = _pose(_tv,inverse*_bindings.tv_window.transform); _show(_tv,true)
	poses_valid = _pose(_sodium,inverse) and poses_valid; _show(_sodium,true)
	if _sodium_alpha != float(sample.sodium_alpha):
		_sodium_alpha = float(sample.sodium_alpha); _sodium_material.set_shader_parameter("inner_alpha",_sodium_alpha); _uniform_writes += 1
	_paint(_screen,_tv_bright if sample.tv_on else _tv_dim)
	for index: int in range(4):
		poses_valid = _pose(_washers[index],inverse*_bindings.washers[index]) and poses_valid; _show(_washers[index],true)
		var offset: Dictionary = sample.washers[index]
		poses_valid = _pose(_patches[index],Transform3D(Basis.from_scale(Vector3(0.16,0.08,1)),Vector3(offset.x*0.04,-offset.y*0.04,0.004))) and poses_valid
		_paint(_panes[index],_pane_night if sample.steam_visible else _pane_day)
	_show(_steam,steam_active)
	if steam_active:
		var pawn: Transform3D = _bindings.pawn_counter.transform
		var basis: Basis = snapshot.camera_basis.orthonormalized() if snapshot.food_visible else pawn.basis.orthonormalized()
		var bite: Vector3 = snapshot.food_transform*Vector3(0.01,0.135,0.015) if snapshot.food_visible else pawn*Vector3(0,_bindings.pawn_counter.size.y*0.5,0)
		var at: Vector3 = bite+basis.x*float(sample.steam_x)*0.04+Vector3.UP*(0.065+float(sample.steam_rise)*0.04)
		poses_valid = _pose(_steam,inverse*Transform3D(basis*Basis.from_scale(Vector3(0.06,0.06,1)),at)) and poses_valid
	var source_rect: Rect2 = _bindings.underpass.source_rect
	var start: Vector3 = Content.to_world(Vector2(source_rect.position.x+float(sample.shadow_phase)*source_rect.size.x*6.0,source_rect.position.y-10.0))
	var shadow_rect := Rect2(Vector2(start.x,start.z),Vector2(4.8,0.32))
	for index: int in range(_shadows.size()):
		var receiver: Dictionary = _bindings.underpass.receivers[index]
		var overlap: Rect2 = shadow_rect.intersection(receiver.rect)
		var active: bool = sample.shadow_visible and overlap.has_area()
		_show(_shadows[index],active)
		if not active: continue
		var at := Vector3(overlap.get_center().x,float(receiver.height),overlap.get_center().y)
		var basis: Basis = Basis(Vector3.RIGHT,-PI*0.5)*Basis.from_scale(Vector3(overlap.size.x,overlap.size.y,1))
		poses_valid = _pose(_shadows[index],inverse*Transform3D(basis,at)) and poses_valid
	if not poses_valid: clear(); return false
	_sample = sample; return true
func clear() -> void:
	if _sodium != null: _show(_sodium,false)
	if _tv != null: _show(_tv,false)
	for node: Node3D in _washers: _show(node,false)
	if _steam != null: _show(_steam,false)
	for shadow: MeshInstance3D in _shadows: _show(shadow,false)
	_sample.clear()
func inspect() -> Dictionary:
	var visible_shadows: int = 0
	for shadow: MeshInstance3D in _shadows:
		if shadow.visible: visible_shadows += 1
	return {"built":not _bindings.is_empty(),"sample":_sample.duplicate(true),"tv_visible":_tv != null and _tv.visible,"washer_count":_washers.size(),"steam_visible":_steam != null and _steam.visible,"shadow_visible":visible_shadows > 0,"shadow_parts":_shadows.size(),"sodium_visible":_sodium != null and _sodium.visible,"sodium_triangles":_sodium_triangles,"sodium_surfaces":1 if _sodium != null else 0,"uniform_writes":_uniform_writes,"transform_writes":_transform_writes,"material_writes":_material_writes,"visibility_writes":_visibility_writes,"physics_queries":0,"lights":0,"particles":0}
