extends Node3D
class_name SliceNeighborhood
## Authored slice geometry. Every standing wall/large prop has a matching solid.
## Tiny ground stains, paper, wire, lettering and vegetation are flat decoration.

const ANCHORS := {
	"block": Vector3(0, 0, 4), "tony": Vector3(18, 0, -13),
	"pete": Vector3(-18, 1.1, -10.2), "yuri": Vector3(-28, 0, 13),
	"lurch": Vector3(27, 0, 14), "possum": Vector3(4, 0, 6),
	"dumpster_1": Vector3(10, 0, -1), "dumpster_2": Vector3(-11, 0, 19),
	"dumpster_3": Vector3(30, 0, -25), "cash_1": Vector3(5, 0, -5),
	"cash_2": Vector3(-9, 0, -8), "cash_3": Vector3(10, 0, 14),
	"copper_1": Vector3(-31, 0, 19),
}

var materials: Dictionary = {}
var meshes: Dictionary = {}
var solid_footprints: Array[Rect2] = []
var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var last_sky_time: float = -1.0
var last_sky_daylight: float = -1.0
var lamps: Array[OmniLight3D] = []
var batch_stats: Dictionary = {}
var built := false

func anchors() -> Dictionary:
	return ANCHORS.duplicate()

func build() -> void:
	if built:
		return
	built = true
	_lighting()
	_ground()
	_pawn_shop()
	_corner()
	_block()
	_scrap_yard()
	_alley()
	_backdrop()
	_street_furniture()
	_dressing()
	_street_details()
	_occupied_edges()
	# One construction-time merge; moving actors, labels and physics stay independent.
	batch_stats = SliceMeshBatcher.batch_children(self, 16.0)

func is_clear_position(point: Vector3, margin: float = 0.42) -> bool:
	if point.x < -41.0 or point.x > 41.0 or point.z < -37.0 or point.z > 29.0:
		return false
	for footprint: Rect2 in solid_footprints:
		if footprint.grow(margin).has_point(Vector2(point.x, point.z)):
			return false
	return true

func safe_spawn(point: Vector3) -> Vector3:
	if is_clear_position(point):
		return Vector3(point.x, 0.05, point.z)
	return Vector3(0, 0.05, 8)

func set_day_time(day_time: float) -> void:
	# A dirty late-afternoon base stays readable; lamps take over at night.
	var phase: float = fposmod(day_time / 240.0, 1.0)
	var daylight: float = clampf(sin(phase * TAU) * 0.7 + 0.65, 0.16, 1.0)
	sun.light_energy = 0.90 * daylight
	environment.ambient_light_energy = 0.36 * daylight + 0.16
	for lamp: OmniLight3D in lamps:
		lamp.light_energy = lerpf(1.3, 0.16, daylight)
	# Sky edits invalidate its cached radiance. Refresh at most four times per
	# simulation second, and leave the clamped midday/night plateaus untouched.
	# Absolute time difference also handles the 240-second day wrap and QA jumps.
	if last_sky_time >= 0.0 and absf(day_time - last_sky_time) < 0.25:
		return
	last_sky_time = day_time
	var sky_daylight: float = (daylight - 0.16) / 0.84
	if is_equal_approx(sky_daylight, last_sky_daylight):
		return
	last_sky_daylight = sky_daylight
	sky_material.sky_top_color = Color("293338").lerp(Color("667b83"), sky_daylight)
	sky_material.sky_horizon_color = Color("3b4541").lerp(Color("b1aa94"), sky_daylight)
	sky_material.ground_bottom_color = Color("22271f").lerp(Color("3c3a30"), sky_daylight)
	sky_material.ground_horizon_color = Color("30382f").lerp(Color("8b8979"), sky_daylight)
	environment.background_energy_multiplier = lerpf(0.40, 0.80, sky_daylight)
	environment.fog_light_color = Color("39423b").lerp(Color("94988a"), sky_daylight)

func _mat(hex: String, roughness: float = 0.94, emission: float = 0.0, kind: String = "plain") -> StandardMaterial3D:
	var key: String = kind + hex + str(roughness) + str(emission)
	if materials.has(key):
		return materials[key] as StandardMaterial3D
	var mat: StandardMaterial3D = SliceSurfaceKit.material(kind, hex, roughness, emission)
	materials[key] = mat
	return mat

func _surface(label: String) -> String:
	# Classify authored objects, never arbitrary palette indices. Emission is opt-in.
	if label.contains("lens") or label.contains("flame") or label.contains("coals") or label.contains("tube"):
		return "plain"
	if label.contains("tire") or label.contains("wheel") or label.contains("bag"):
		return "rubber"
	if label.contains("fabric") or label.contains("awning") or label.contains("mattress") or label.contains("sofa") or label.contains("chair_seat") or label.contains("chair_back"):
		return "fabric"
	if label.contains("board") or label.contains("pallet") or label.contains("crate") or label.contains("wood") or label.contains("shelf") or label == "utility_pole":
		return "wood"
	if label.contains("brick") or label in ["pawn_left", "pawn_right", "pawn_back", "corner_store", "alley_left", "alley_back", "block_backwall"]:
		return "brick"
	if label.contains("plaster") or label in ["pawn_front_left", "pawn_front_right", "pawn_lintel", "neighbor_building", "alley_right"]:
		return "plaster"
	if label.contains("asphalt") or label in ["street", "north_access", "south_path", "alley_strip"]:
		return "asphalt"
	if label.contains("concrete") or label.contains("paving") or label.contains("curb") or label in ["foundation", "block_pad", "scrap_pad", "pawn_sill", "corner_plinth", "block_wall_cap"]:
		return "concrete"
	if label.contains("window") or label.contains("glass") or label.contains("screen") or label.contains("stain") or label.contains("weathering"):
		return "plain"
	if label.contains("metal") or label.contains("dumpster") or label.contains("barrel") or label.contains("pipe") or label.contains("fence") or label.contains("shed") or label.contains("car_") or label.contains("roof") or label.contains("lamp") or label.contains("rail") or label.contains("cabinet"):
		return "painted_metal"
	return "plain"

func _box(label: String, size: Vector3, position_at: Vector3, color: String, solid: bool = false,
		rotation_at: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	var key: String = "box" + str(size)
	var mesh: BoxMesh
	if meshes.has(key):
		mesh = meshes[key] as BoxMesh
	else:
		mesh = BoxMesh.new()
		mesh.size = size
		meshes[key] = mesh
	var item := MeshInstance3D.new()
	item.name = label
	item.mesh = mesh
	item.material_override = _mat(color, 0.94, emission, _surface(label))
	item.position = position_at
	item.rotation_degrees = rotation_at
	add_child(item)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_solid(shape, position_at, rotation_at, size)
	return item

func _cylinder(label: String, radius: float, height: float, position_at: Vector3, color: String,
		solid: bool = false, vertices: int = 8, top_radius: float = -1.0) -> MeshInstance3D:
	var top: float = radius if top_radius < 0.0 else top_radius
	var key: String = "cyl" + str(radius) + "/" + str(height) + "/" + str(vertices) + "/" + str(top)
	var mesh: CylinderMesh
	if meshes.has(key):
		mesh = meshes[key] as CylinderMesh
	else:
		mesh = CylinderMesh.new()
		mesh.top_radius = top
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = vertices
		mesh.rings = 1
		meshes[key] = mesh
	var item := MeshInstance3D.new()
	item.name = label
	item.mesh = mesh
	item.position = position_at
	item.material_override = _mat(color, 0.94, 0.0, _surface(label))
	add_child(item)
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = maxf(radius, top)
		shape.height = height
		_solid(shape, position_at, Vector3.ZERO, Vector3(radius * 2, height, radius * 2))
	return item

func _solid(shape: Shape3D, position_at: Vector3, rotation_at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position_at
	body.rotation_degrees = rotation_at
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	# Flat paving does not invalidate a ground spawn. Rotated obstacle footprints
	# use their conservative world-space projection for deterministic save recovery.
	if position_at.y + size.y * 0.5 > 0.3 and position_at.y - size.y * 0.5 < 1.85:
		var yaw: float = deg_to_rad(rotation_at.y)
		var width: float = absf(cos(yaw)) * size.x + absf(sin(yaw)) * size.z
		var depth: float = absf(sin(yaw)) * size.x + absf(cos(yaw)) * size.z
		solid_footprints.append(Rect2(position_at.x - width / 2.0, position_at.z - depth / 2.0, width, depth))

func _sign(text_value: String, position_at: Vector3, size: int = 60, pixel: float = 0.008,
		color: String = "d4c896", yaw: float = 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_at
	label.rotation_degrees.y = yaw
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = Color(color)
	label.outline_size = 3
	label.outline_modulate = Color("28261d")
	label.no_depth_test = false
	label.double_sided = false
	add_child(label)
	return label

func _beam(a: Vector3, b: Vector3, width: float, color: String) -> void:
	var item: MeshInstance3D = _box("beam", Vector3(width, a.distance_to(b), width), (a + b) * 0.5, color)
	item.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _facade_piece(label: String, size: Vector3, at: Vector3, offset: Vector3,
		yaw: float, color: String, solid: bool = false) -> void:
	# Positive local Z faces out from the existing wall; relief never needs a
	# hole through a collision body or a false traversable room behind glazing.
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	_box(label, size, at + turn * offset, color, solid, Vector3(0, yaw, 0))

func _framed_window(at: Vector3, width: float, height: float, frame: String,
		style: int = 0, yaw: float = 0.0) -> void:
	_facade_piece("window_reveal", Vector3(width + 0.22, height + 0.20, 0.075), at, Vector3(0,0,0.04), yaw, "292f2d")
	_facade_piece("window_glass", Vector3(width - 0.12, height - 0.12, 0.035), at, Vector3(0,0,0.09), yaw, "3d4b45")
	for side: float in [-1,1]:
		_facade_piece("window_frame_metal", Vector3(0.09,height + 0.13,0.20), at, Vector3(side * width * 0.5,0,0.13), yaw, frame)
		_facade_piece("window_frame_metal", Vector3(width + 0.10,0.09,0.20), at, Vector3(0,side * height * 0.5,0.13), yaw, frame)
	_facade_piece("window_mullion", Vector3(0.045,height,0.08), at, Vector3(0,0,0.18), yaw, frame)
	_facade_piece("window_mullion", Vector3(width,0.055,0.08), at, Vector3(0,-height * 0.08,0.18), yaw, frame)
	_facade_piece("window_sill_concrete", Vector3(width + 0.42,0.12,0.40), at, Vector3(0,-height * 0.5 - 0.10,0.12), yaw, "a49b86")
	_facade_piece("window_lintel_concrete", Vector3(width + 0.36,0.17,0.20), at, Vector3(0,height * 0.5 + 0.13,0.07), yaw, "978e7b")
	if style % 4 == 0:
		for line in range(5):
			_facade_piece("window_blind", Vector3(width - 0.20,0.055,0.012), at, Vector3(0,height * 0.39 - line * height * 0.115,0.119), yaw, "8d8b75")
	elif style % 4 == 1:
		for side: float in [-1,1]:
			_facade_piece("window_curtain_fabric", Vector3(width * 0.24,height - 0.13,0.018), at, Vector3(side * width * 0.31,0,0.119), yaw, "8b806c")
	elif style % 4 == 2:
		_facade_piece("window_board", Vector3(width + 0.10,0.22,0.06), at, Vector3(0,-height * 0.23,0.23), yaw, "7c664d")

func _closed_entry(at: Vector3, width: float, height: float, color: String, yaw: float = 0.0) -> void:
	_facade_piece("door_reveal", Vector3(width + 0.30,height + 0.24,0.09), at, Vector3(0,height * 0.5,0.05), yaw, "292f2a")
	_facade_piece("closed_metal_door", Vector3(width,height,0.055), at, Vector3(0,height * 0.5,0.10), yaw, color)
	for side: float in [-1,1]:
		_facade_piece("door_frame_metal", Vector3(0.11,height + 0.16,0.22), at, Vector3(side * (width * 0.5 + 0.06),height * 0.5,0.15), yaw, "6b6b5c")
	_facade_piece("door_lintel_concrete", Vector3(width + 0.42,0.18,0.30), at, Vector3(0,height + 0.14,0.15), yaw, "a2967e")
	_facade_piece("door_kickplate_metal", Vector3(width - 0.10,0.30,0.02), at, Vector3(0,0.20,0.14), yaw, "686b61")
	_facade_piece("door_glass", Vector3(width - 0.28,height * 0.29,0.02), at, Vector3(0,height * 0.71,0.14), yaw, "34453d")
	_facade_piece("door_crossbar_metal", Vector3(width + 0.16,0.075,0.08), at, Vector3(0,height * 0.46,0.20), yaw, "8a806b")
	_facade_piece("door_padlock_metal", Vector3(0.11,0.14,0.07), at, Vector3(width * 0.30,height * 0.43,0.25), yaw, "a18d62")

func _pitched_roof(at: Vector3, width: float, depth: float, rise: float, color: String) -> void:
	# Low-poly triangular end caps and two broad roof slopes replace a box lid.
	var key: String = "gable/" + str(Vector3(width, rise, depth))
	var mesh: ArrayMesh
	if meshes.has(key):
		mesh = meshes[key] as ArrayMesh
	else:
		var half: float = width * 0.5
		var front: float = depth * 0.5
		var points := PackedVector3Array([Vector3(-half,0,-front), Vector3(half,0,-front), Vector3(0,rise,-front), Vector3(-half,0,front), Vector3(half,0,front), Vector3(0,rise,front)])
		var faces: Array[Vector3i] = [Vector3i(0,2,1),Vector3i(3,4,5),Vector3i(0,3,5),Vector3i(0,5,2),Vector3i(1,2,5),Vector3i(1,5,4),Vector3i(0,1,4),Vector3i(0,4,3)]
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		for face: Vector3i in faces:
			var a: Vector3 = points[face.x]
			var b: Vector3 = points[face.y]
			var c: Vector3 = points[face.z]
			var normal: Vector3 = (b-a).cross(c-a).normalized()
			# Godot's front faces wind clockwise; retain the outward flat normal.
			for point: Vector3 in [a,c,b]:
				vertices.append(point)
				normals.append(normal)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		meshes[key] = mesh
	var roof := MeshInstance3D.new()
	roof.name = "pitched_metal_roof"
	roof.mesh = mesh
	roof.material_override = _mat(color, 0.94, 0.0, "painted_metal")
	roof.position = at
	add_child(roof)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, rise, depth)
	_solid(shape, at + Vector3(0,rise * 0.5,0), Vector3.ZERO, shape.size)

func _lighting() -> void:
	var world_env := WorldEnvironment.new()
	environment = Environment.new()
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("667b83")
	sky_material.sky_horizon_color = Color("b1aa94")
	sky_material.ground_bottom_color = Color("3c3a30")
	sky_material.ground_horizon_color = Color("8b8979")
	sky_material.sky_curve = 0.22
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9ba5a1")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.background_energy_multiplier = 0.80
	environment.fog_enabled = true
	environment.fog_light_color = Color("94988a")
	environment.fog_density = 0.0028
	environment.fog_sky_affect = 0.4
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -38, 0)
	sun.light_color = Color("d8d2bf")
	sun.light_energy = 0.90
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85
	sun.shadow_bias = 0.06
	add_child(sun)

func _ground() -> void:
	_box("foundation", Vector3(92, 0.2, 80), Vector3(0, -0.1, -4), "5e5b4f", true)
	_box("street", Vector3(83, 0.018, 7.8), Vector3(0, 0.01, -6.5), "282925")
	_box("north_access", Vector3(9, 0.02, 30), Vector3(4, 0.014, -21), "2d302a")
	_box("south_path", Vector3(5.8, 0.02, 29), Vector3(6, 0.014, 12), "47453b")
	for i in range(-8, 9):
		if abs(i) <= 1:
			continue
		_box("old_center_line", Vector3(1.8, 0.004, 0.09), Vector3(i * 5.0, 0.024, -6.5), "a89b5c")
		_box("worn_lane_paint", Vector3(0.23, 0.003, 0.10), Vector3(i * 5.0 + 0.42, 0.028, -6.5), "3d3d32")
	for i in range(-10, 11):
		for side: float in [-11.0, -2.0]:
			var slab: String = ["8a8172","837e70","918777"][posmod(i,3)]
			_box("paving_slab", Vector3(3.95, 0.055, 2.0), Vector3(i * 4.0, 0.027, side), slab)
			_box("paving_joint", Vector3(3.92,0.003,0.018), Vector3(i * 4.0,0.056,side), "69675a")
		_box("curb_seam", Vector3(3.92, 0.07, 0.18), Vector3(i * 4.0, 0.035, -3.05), "aaa18b")
		_box("curb_seam", Vector3(3.92, 0.07, 0.18), Vector3(i * 4.0, 0.035, -10.05), "8d8775")
	for z: float in [-3.32,-9.78]:
		_box("concrete_gutter", Vector3(83,0.010,0.36), Vector3(0,0.023,z), "595d54")
	# The crossing runs north/south over an east/west road. Each bar is across
	# the direction of travel, and paint remains a flat part of the asphalt.
	for i in range(10):
		var z: float = -9.45 + i * 0.65
		_box("crosswalk", Vector3(3.2,0.004,0.36), Vector3(0,0.032,z), "b3aa91")
		if i % 3 == 1:
			_box("crosswalk_paint_loss", Vector3(0.44,0.003,0.38), Vector3(0.78,0.036,z), "35372f")
	for x: float in [-3.1,3.1]:
		_box("crosswalk_stop_line", Vector3(0.14,0.004,2.8), Vector3(x,0.03,-6.5), "a79f86")
	# Repairs have a purpose: service trenches, a patched manhole and a torn
	# curb edge. Broad quiet areas keep footsteps, pickups and faces legible.
	for repair: Vector3 in [Vector3(-25,0,-5.0),Vector3(15,0,-8.2),Vector3(34,0,-5.6)]:
		_surface_patch("asphalt_patch",repair + Vector3(0,0.030,0),Vector2(2.1,0.78),"363b36",19)
		_surface_patch("asphalt_patch",repair + Vector3(0.65,0.032,0.16),Vector2(0.95,0.58),"3b4039",-7)
	for x: float in [-19,27]:
		_box("asphalt_service_trench",Vector3(0.62,0.005,6.1),Vector3(x,0.029,-6.5),"42463d",false,Vector3(0,5,0))
		for side: float in [-0.34,0.34]:
			_box("tar_seam",Vector3(0.028,0.004,6.2),Vector3(x+side,0.034,-6.5),"222820",false,Vector3(0,5,0))
	for x: float in [-11.5,9.5,37]:
		var start := Vector3(x,0.032,-4.7)
		for offset: Vector3 in [Vector3(0.2,0,-0.75),Vector3(-0.18,0,-0.65),Vector3(0.35,0,-0.80)]:
			_beam(start,start+offset,0.018,"252c25")
			start += offset
	for x: float in [-34,-28,-12,25,31,37]:
		_box("parking_bay_end",Vector3(0.07,0.004,1.9),Vector3(x,0.03,-8.65),"9a947f")
	for x: float in [-31,-9,28,34]:
		_box("parking_bay_side",Vector3(5.1,0.004,0.07),Vector3(x,0.03,-7.72),"9a947f")
	for at: Vector3 in [Vector3(-26,0,-3.35),Vector3(-8,0,-9.68),Vector3(22,0,-9.68),Vector3(36,0,-3.35)]:
		_gutter_inlet(at)
	_manhole(Vector3(-14,0,-5.4))
	_manhole(Vector3(22.5,0,-7.0))
	for at: Vector3 in [Vector3(-19,0,-1.6),Vector3(11,0,-11.0),Vector3(31,0,-1.6)]:
		_surface_patch("concrete_repair",at+Vector3(0,0.061,0),Vector2(0.65,0.36),"737468",11)

func _surface_patch(label: String, at: Vector3, size: Vector2, color: String, yaw: float) -> void:
	var patch: MeshInstance3D = _cylinder(label,1.0,0.004,at,color,false,7)
	patch.scale = Vector3(size.x,1.0,size.y)
	patch.rotation_degrees.y = yaw
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _gutter_inlet(at: Vector3) -> void:
	_box("drain_frame_metal",Vector3(0.85,0.012,0.38),at+Vector3(0,0.04,0),"303a32")
	for i in range(7):
		_box("drain_grate_metal",Vector3(0.038,0.010,0.34),at+Vector3(-0.36+i*0.12,0.051,0),"6c7166")

func _manhole(at: Vector3) -> void:
	_cylinder("manhole_frame_metal",0.51,0.008,at+Vector3(0,0.031,0),"555e52",false,12)
	_cylinder("manhole_cover_metal",0.44,0.008,at+Vector3(0,0.039,0),"363f37",false,12)
	for i in range(5):
		_box("manhole_rib_metal",Vector3(0.026,0.005,0.62),at+Vector3(-0.28+i*0.14,0.045,0),"646d5d")

func _multibox(label: String, transforms: Array[Transform3D], color: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i])
	var item := MultiMeshInstance3D.new()
	item.name = label
	item.multimesh = batch
	item.material_override = _mat(color)
	add_child(item)

func _pawn_shop() -> void:
	# An actual service opening, not a complete box with a painted window.
	_box("pawn_back", Vector3(12, 6, 0.5), Vector3(-18, 3, -21), "755041", true)
	_box("pawn_left", Vector3(0.5, 6, 11), Vector3(-24, 3, -15.5), "855d4b", true)
	_box("pawn_right", Vector3(0.5, 6, 11), Vector3(-12, 3, -15.5), "745547", true)
	_box("pawn_roof", Vector3(12.7, 0.45, 11.7), Vector3(-18, 6.1, -15.5), "48493a", true)
	_box("pawn_front_left", Vector3(3.9, 5.6, 0.5), Vector3(-22.1, 2.8, -10.5), "b0a68c", true)
	_box("pawn_front_right", Vector3(3.9, 5.6, 0.5), Vector3(-13.9, 2.8, -10.5), "b0a68c", true)
	_box("pawn_lintel", Vector3(4.4, 2.9, 0.5), Vector3(-18, 4.15, -10.5), "b0a68c", true)
	_box("pawn_counter", Vector3(4.6, 0.9, 0.8), Vector3(-18, 0.45, -10.5), "3c4c40", true)
	_box("pawn_sill", Vector3(5.0, 0.12, 1.1), Vector3(-18, 0.96, -10.5), "a09473", true)
	_box("pawn_counter_back", Vector3(4.0, 0.92, 0.6), Vector3(-18, 0.46, -13.0), "514f3e", true)
	_box("pawn_window_trim", Vector3(4.8, 0.12, 0.18), Vector3(-18, 2.7, -10.16), "393d30")
	for x: float in [-20.25, -15.75]:
		_box("pawn_window_trim", Vector3(0.12, 1.9, 0.18), Vector3(x, 1.8, -10.16), "393d30")
	# Wire/glass is suggested around the service slot; rays can reach the clear opening.
	for x: float in [-19.8, -19.2, -18.6, -18.0, -17.4, -16.8, -16.2]:
		_box("security_bar", Vector3(0.035, 0.9, 0.04), Vector3(x, 2.2, -10.15), "424b3b")
	_box("pawn_fascia", Vector3(8.5, 0.66, 0.22), Vector3(-18, 3.71, -10.03), "30433a")
	_box("metal_sign_frame_top", Vector3(8.6, 0.055, 0.26), Vector3(-18, 4.06, -10.01), "a79d7d")
	_box("metal_sign_frame_low", Vector3(8.6, 0.055, 0.26), Vector3(-18, 3.36, -10.01), "817d65")
	_sign("PAWN SHOP PETE", Vector3(-18, 3.72, -9.88), 62, 0.0075, "d4c896")
	# Slope down toward the street so the lip meets its valance and leaves the
	# fascia readable from sidewalk height, including the oblique west view.
	_box("pawn_awning", Vector3(11.5, 0.12, 1.75), Vector3(-18, 3.12, -9.64), "58644a", true, Vector3(12, 0, 0))
	for x in range(10):
		_box("awning_stripe", Vector3(0.42, 0.014, 1.77), Vector3(-22.6 + x * 1.02, 3.188, -9.64), "9a9270", false, Vector3(12, 0, 0))
		_box("awning_valance_fabric", Vector3(0.96,0.22,0.045), Vector3(-22.6+x*1.02,2.86,-8.77), "58644a" if x%2==0 else "8d886b")
	for x: float in [-23.2,-20.6,-15.4,-12.8]:
		_beam(Vector3(x,2.5,-10.16),Vector3(x,2.94,-8.85),0.045,"454c40")
	for x: float in [-22,-14]:
		_framed_window(Vector3(x,1.8,-10.23),1.65,1.5,"697263",0)
	_box("pawn_open_placard",Vector3(0.65,0.32,0.055),Vector3(-14,1.68,-9.96),"293a32")
	_sign("OPEN", Vector3(-14, 1.68, -9.92), 33, 0.006, "d4c896")
	_box("pawn_notice",Vector3(1.12,0.36,0.055),Vector3(-22,1.45,-9.96),"b1a284")
	_sign("11 MINUTES", Vector3(-22, 1.45, -9.92), 27, 0.0055, "514b3b")
	for x: float in [-22,-18,-14]:
		_framed_window(Vector3(x,5.0,-10.23),1.52,1.37,"6d7267",int(x)%3)
	for x: float in [-23.86,-20.45,-15.55,-12.14]:
		_box("pawn_plaster_pier",Vector3(0.24,5.6,0.25),Vector3(x,2.8,-10.19),"9b937f")
	_box("pawn_concrete_floor_band",Vector3(12.1,0.18,0.28),Vector3(-18,4.15,-10.17),"a69d88")
	_box("pawn_brick_parapet",Vector3(12.2,0.66,0.30),Vector3(-18,6.37,-10.42),"876250")
	_box("pawn_concrete_parapet_cap",Vector3(12.55,0.15,0.52),Vector3(-18,6.77,-10.42),"9c9685")
	_box("pawn_brick_raised_parapet",Vector3(4.0,0.36,0.32),Vector3(-18,6.86,-10.42),"876250")
	_box("pawn_concrete_raised_cap",Vector3(4.35,0.13,0.52),Vector3(-18,7.10,-10.42),"9c9685")
	_box("pawn_metal_projecting_sign",Vector3(0.16,1.35,1.28),Vector3(-23.65,3.87,-9.53),"4a5648")
	_sign("PAWN",Vector3(-23.75,3.87,-9.50),36,0.006,"c1b68f",-90)
	_sign("PAWN",Vector3(-23.55,3.87,-9.50),36,0.006,"c1b68f",90)
	_beam(Vector3(-23.65,4.66,-10.14),Vector3(-23.65,4.66,-8.94),0.06,"5b6055")
	_box("scale_base", Vector3(0.5, 0.1, 0.35), Vector3(-19.3, 1.07, -10.43), "8c8971")
	_cylinder("scale_pan", 0.26, 0.05, Vector3(-19.3, 1.16, -10.43), "b0a78c")
	_box("hot_pocket", Vector3(0.35, 0.12, 0.24), Vector3(-17.1, 1.08, -10.6), "ae8248")
	_box("paper_sleeve", Vector3(0.18, 0.13, 0.26), Vector3(-17.19, 1.08, -10.6), "b9ac83")
	_wall_wear(-18, -10.225, 11, 5.6)
	# Exposed brick courses survive where the ground-floor plaster has failed.
	for x: float in [-22.1, -13.9]:
		_box("pawn_exposed_brick", Vector3(3.9, 0.72, 0.035), Vector3(x, 0.36, -10.23), "805a47")
		_box("concrete_water_table", Vector3(4.0, 0.10, 0.09), Vector3(x, 0.76, -10.19), "8f836c")
	_box("wall_utility_pipe", Vector3(0.11, 5.7, 0.11), Vector3(-23.78, 2.85, -10.15), "514f40")
	_box("wall_utility_pipe", Vector3(0.11, 5.7, 0.11), Vector3(-12.23, 2.85, -10.15), "514f40")
	# The east flank is visible from the Block and has a complete shop side.
	_closed_entry(Vector3(-11.74,0,-17.5),1.25,2.4,"555e52",90)
	for z: float in [-13.5,-18.7]:
		_framed_window(Vector3(-11.74,4.4,z),1.3,1.4,"6d7267",1,90)
	_box("pawn_brick_chimney",Vector3(0.80,1.7,0.80),Vector3(-21.2,6.9,-17.7),"7c5c4d")
	_box("chimney_concrete_cap",Vector3(1.0,0.16,1.0),Vector3(-21.2,7.8,-17.7),"8f8e7c")
	_box("roof_metal_duct",Vector3(2.5,0.55,0.70),Vector3(-16.3,6.65,-17.2),"69746c")
	_pawn_interior()

func _corner() -> void:
	_box("corner_store", Vector3(17, 6.2, 9), Vector3(18, 3.1, -23.0), "8b5944", true)
	_box("corner_plinth", Vector3(17.1, 0.8, 9.1), Vector3(18, 0.4, -23.0), "64584c", true)
	_box("corner_cornice", Vector3(17.7, 0.4, 9.7), Vector3(18, 6.24, -23), "454737", true)
	_box("corner_fascia", Vector3(8.0, 0.78, 0.24), Vector3(18, 4.3, -18.36), "704b39")
	_sign("THE CORNER", Vector3(18, 4.3, -18.20), 67, 0.008, "cbbb8f")
	for x: float in [12.3, 23.7]:
		_framed_window(Vector3(x,1.72,-18.49),3.25,1.9,"777a68",3)
		for offset: float in [-0.9, 0.8]:
			_box("window_board", Vector3(3.7, 0.24, 0.08), Vector3(x, 1.65 + offset, -18.34), "7b6b49", false, Vector3(0, 0, -7))
	_closed_entry(Vector3(18,0,-18.49),1.65,2.55,"4c5c4f")
	_box("corner_door_transom",Vector3(2.15,0.50,0.08),Vector3(18,2.98,-18.39),"34433c")
	_box("door_board", Vector3(2.1, 0.20, 0.1), Vector3(18, 1.4, -18.19), "8e7650", false, Vector3(0, 0, 22))
	_box("corner_canopy", Vector3(13.5, 0.22, 3.8), Vector3(18, 3.42, -16.55), "b0793c", true)
	_box("canopy_edge", Vector3(13.6, 0.38, 0.18), Vector3(18, 3.28, -14.64), "64422d")
	for x: float in [11.8, 24.2]:
		_box("canopy_post", Vector3(0.15, 3.4, 0.15), Vector3(x, 1.7, -15.0), "554c35", true)
	_box("corner_canopy_placard",Vector3(2.80,0.38,0.08),Vector3(20.4,3.28,-14.49),"514a37")
	_sign("TRE BAG TONY", Vector3(20.4, 3.28, -14.435), 31, 0.0055, "c4b78f")
	_box("closed_notice",Vector3(0.80,0.33,0.04),Vector3(12.2,1.6,-18.20),"ada082")
	_sign("CLOSED", Vector3(12.2, 1.6, -18.17), 29, 0.005, "514b3b")
	for x: float in [12.0,15.0,21.0,24.0]:
		_beam(Vector3(x,3.19,-18.2),Vector3(x,3.19,-14.68),0.07,"5a503d")
	_box("canopy_metal_gutter",Vector3(13.8,0.12,0.14),Vector3(18,3.50,-14.57),"8a806a")
	_box("canopy_drainpipe",Vector3(0.075,3.35,0.075),Vector3(24.28,1.68,-14.64),"706d59",true)
	_wall_wear(18, -18.38, 16.7, 5.8)
	_box("roof_vent", Vector3(2.1, 0.8, 1.4), Vector3(21, 6.8, -22), "727362", true)
	for i in range(5):
		_box("vent_slit", Vector3(1.6, 0.045, 0.03), Vector3(21, 6.51 + i * 0.13, -21.28), "3e4638")
	for x: float in [10, 14, 22, 26]:
		_box("corner_plaster_pilaster", Vector3(0.3, 6.0, 0.18), Vector3(x, 3.0, -18.38), "b0a28a")
	_box("corner_concrete_lintel", Vector3(17.2, 0.25, 0.28), Vector3(18, 5.38, -18.37), "a79b83")
	for x: float in [12.4, 18, 23.6]:
		_box("corner_high_window", Vector3(2.4, 0.55, 0.08), Vector3(x, 5.78, -18.40), "293834")
		_box("window_mullion", Vector3(0.06, 0.6, 0.1), Vector3(x, 5.78, -18.34), "aa9b7b")
	_fixture(Vector3(18, 3.23, -16.3), 2.7, "d4c896", 0.85, 5.0)
	_box("metal_security_camera", Vector3(0.22, 0.18, 0.45), Vector3(24.25, 3.02, -17.9), "736f60", false, Vector3(10, -25, 0))
	_box("camera_lens", Vector3(0.16, 0.12, 0.02), Vector3(24.16, 2.98, -17.65), "1f2825")
	_box("door_mail_slot", Vector3(0.55, 0.08, 0.06), Vector3(18, 0.65, -18.29), "a7946e")
	_box("door_handle_metal", Vector3(0.07, 0.3, 0.12), Vector3(18.58, 1.3, -18.27), "857c61")
	for x: float in [9.7,26.3]:
		_box("corner_brick_parapet_pier",Vector3(0.75,1.25,0.8),Vector3(x,6.4,-18.65),"845a49")
		_box("corner_concrete_pier_cap",Vector3(0.96,0.15,0.94),Vector3(x,7.09,-18.65),"aaa18b")
	_box("corner_brick_parapet",Vector3(16,0.45,0.34),Vector3(18,6.7,-18.65),"845a49")
	_box("corner_concrete_cap",Vector3(16.2,0.14,0.52),Vector3(18,6.99,-18.65),"a29884")
	_closed_entry(Vector3(26.51,0,-22.7),1.35,2.4,"555d52",90)
	for z: float in [-21,-25.5]:
		_framed_window(Vector3(26.51,4.6,z),1.35,1.15,"727769",2,90)
	_box("corner_side_concrete_band",Vector3(0.24,0.20,9.1),Vector3(26.55,3.2,-23),"9d927c")

func _block() -> void:
	_box("block_pad", Vector3(12, 0.05, 13), Vector3(0, 0.025, 6.6), "8b8170")
	var grime_rng := RandomNumberGenerator.new()
	grime_rng.seed = 3027
	for i in range(11):
		var at := Vector3(grime_rng.randf_range(-5.5,5.5),0.054,grime_rng.randf_range(0.8,12.4))
		_surface_patch("concrete_stain",at,Vector2(grime_rng.randf_range(0.16,0.45),grime_rng.randf_range(0.12,0.25)),"716c59",float(i*27))
	_surface_patch("crate_use_stain",Vector3(0.08,0.055,4.05),Vector2(0.64,0.49),"65604b",12)
	for x: float in [-4,-2,0,2,4]:
		_box("block_paving_seam", Vector3(0.011,0.003,12.8), Vector3(x,0.054,6.6), "736f60")
	for z: float in [2,4,6,8,10,12]:
		_box("block_paving_seam", Vector3(11.9,0.003,0.011), Vector3(0,0.054,z), "736f60")
	_box("block_backwall", Vector3(15.8, 1.45, 0.38), Vector3(-0.8, 0.725, 14.5), "82604b", true)
	_box("block_wall_cap", Vector3(16, 0.14, 0.58), Vector3(-0.8, 1.5, 14.5), "a3956f", true)
	_sign("THE BLOCK", Vector3(-0.8, 0.95, 14.28), 45, 0.007, "bcae7d", 180)
	# The open lattice crate is the recurring object, not a glowing altar.
	var c: Vector3 = ANCHORS["block"]
	_box("crate_floor", Vector3(0.76, 0.08, 0.68), c + Vector3(0, 0.06, 0), "6b633b", true)
	for x: float in [-0.34, 0.34]:
		for z: float in [-0.30, 0.30]:
			_box("crate_corner", Vector3(0.08, 0.58, 0.08), c + Vector3(x, 0.3, z), "777046")
	for h: float in [0.17, 0.35, 0.53]:
		for z: float in [-0.30, 0.30]:
			_box("crate_lattice", Vector3(0.72, 0.07, 0.05), c + Vector3(0, h, z), "898054")
		for x: float in [-0.34, 0.34]:
			_box("crate_lattice", Vector3(0.05, 0.07, 0.60), c + Vector3(x, h, 0), "898054")
	var crate_shape := BoxShape3D.new()
	crate_shape.size = Vector3(0.76, 0.58, 0.68)
	_solid(crate_shape, c + Vector3(0, 0.29, 0), Vector3.ZERO, crate_shape.size)
	_box("crate_cardboard", Vector3(0.83, 0.045, 0.76), c + Vector3(0.05, 0.61, 0.02), "a18e5d", false, Vector3(0, 8, 0))
	_cylinder("ash_can", 0.16, 0.10, c + Vector3(0.16, 0.68, -0.1), "645f47")
	_chair(Vector3(-3.2, 0, 7.4))
	_box("old_mattress", Vector3(1.5, 0.22, 2.5), Vector3(-4.5, 0.11, 11.6), "817251", true, Vector3(0, 8, 0))
	for x: float in [-4.9, -4.4, -3.9]:
		_box("mattress_seam", Vector3(0.04, 0.014, 2.3), Vector3(x, 0.23, 11.6), "615a40", false, Vector3(0, 8, 0))
	_box("flattened_carton", Vector3(1.4, 0.02, 1.1), Vector3(2.7, 0.04, 9.4), "8a774b", false, Vector3(0, 18, 0))
	_box("block_notice", Vector3(1.55, 1.4, 0.13), Vector3(-6.1, 1.5, 6.6), "4a5034", true, Vector3(0, 26, 0))
	_sign("NO LOITERING", Vector3(-6.02, 1.78, 6.72), 31, 0.007, "bfb484", 26)
	_sign("since 1987", Vector3(-6.02, 1.25, 6.72), 26, 0.006, "a89c72", 26)
	_lamp(Vector3(-5.6, 0, 2.0), 90)

func _chair(at: Vector3) -> void:
	for x: float in [-0.34, 0.34]:
		_beam(at + Vector3(x, 0.08, -0.38), at + Vector3(x, 0.64, 0.37), 0.055, "8c8970")
		_beam(at + Vector3(x, 0.08, 0.38), at + Vector3(x, 0.65, -0.34), 0.055, "8c8970")
		_beam(at + Vector3(x, 0.60, 0.32), at + Vector3(x, 1.16, 0.46), 0.055, "8c8970")
	_box("chair_seat", Vector3(0.72, 0.07, 0.72), at + Vector3(0, 0.61, 0), "777d46", true)
	_box("chair_back", Vector3(0.70, 0.50, 0.07), at + Vector3(0, 0.92, 0.39), "808548", true, Vector3(12, 0, 0))

func _scrap_yard() -> void:
	_box("scrap_pad", Vector3(18, 0.018, 24), Vector3(-31, 0.026, 15), "66634e")
	_fence(Vector3(-40, 0, 2), Vector3(-24, 0, 2))
	_fence(Vector3(-40, 0, 27), Vector3(-24, 0, 27))
	_fence(Vector3(-40, 0, 2), Vector3(-40, 0, 27))
	_fence(Vector3(-23, 0, 2), Vector3(-23, 0, 8))
	_fence(Vector3(-23, 0, 18), Vector3(-23, 0, 27))
	_box("yard_sign", Vector3(4.7, 0.85, 0.18), Vector3(-31, 2.65, 2), "3e482f")
	_sign("YURI'S SCRAP", Vector3(-31, 2.65, 1.85), 48, 0.0075, "c6ba91", 180)
	for x: float in [-33.15,-28.85]:
		_box("yard_sign_metal_post",Vector3(0.065,2.9,0.065),Vector3(x,1.45,2.02),"646c5a",true)
	_box("yard_gate_post", Vector3(0.18, 3.0, 0.18), Vector3(-23, 1.5, 8), "72644a", true)
	_box("yard_gate_post", Vector3(0.18, 3.0, 0.18), Vector3(-23, 1.5, 18), "72644a", true)
	_box("scale_platform", Vector3(2.5, 0.18, 2.6), Vector3(-33, 0.09, 12.5), "484e3f", true)
	_box("scale_column", Vector3(0.18, 1.4, 0.18), Vector3(-34.1, 0.7, 12.5), "8a7958", true)
	_box("scale_display", Vector3(0.64, 0.48, 0.25), Vector3(-34.1, 1.45, 12.5), "b2a480")
	_sign("0", Vector3(-34.1, 1.45, 12.65), 40, 0.009, "292f25")
	_box("yard_shed", Vector3(6, 3.8, 6.5), Vector3(-35, 1.9, 6.2), "666e48", true)
	_pitched_roof(Vector3(-35,3.83,6.2),6.7,7.0,1.05,"555f57")
	for z in range(12):
		var line: float = 2.8 + z * 0.61
		_beam(Vector3(-38.35,3.86,line),Vector3(-35,4.91,line),0.035,"778077")
		_beam(Vector3(-35,4.91,line),Vector3(-31.65,3.86,line),0.035,"778077")
	_box("shed_metal_ridge",Vector3(0.14,0.12,7.1),Vector3(-35,4.91,6.2),"7a8074")
	for x in range(15):
		_box("shed_corrugation", Vector3(0.055, 3.7, 0.1), Vector3(-37.8 + x * 0.4, 1.85, 9.48), "515b3c")
	_box("shed_door", Vector3(1.3, 2.35, 0.1), Vector3(-35.1, 1.175, 9.54), "414a34")
	_box("shed_door_frame_metal",Vector3(1.5,0.12,0.16),Vector3(-35.1,2.4,9.58),"8b8873")
	_box("shed_kennel_placard",Vector3(0.76,0.30,0.035),Vector3(-32.8,1.3,9.56),"8b7955")
	_sign("BRUTUS", Vector3(-32.8, 1.3, 9.59), 27, 0.005, "d0be8d")
	_framed_window(Vector3(-37.0,2.6,9.46),1.0,0.8,"747d6b",3)
	for i in range(5):
		var pipe: MeshInstance3D = _cylinder("scrap_pipe", 0.22, 3.2, Vector3(-37 + i * 0.5, 0.35 + (i % 2) * 0.35, 20), "7d6544")
		pipe.rotation_degrees.z = 90
	_box("pipe_pile_solid", Vector3(5.0, 0.85, 0.85), Vector3(-35.7, 0.42, 20), "625941", true)
	for i in range(3):
		_barrel(Vector3(-37.4 + i * 1.0, 0, 24.3), false)
	_box("rust_sheet", Vector3(3.8, 1.65, 0.16), Vector3(-26.0, 0.9, 24.4), "80593d", true, Vector3(10, -18, 0))
	_box("old_appliance", Vector3(1.0, 1.7, 0.9), Vector3(-25.7, 0.85, 4.5), "9d967a", true, Vector3(0, 18, 0))
	_box("appliance_handle", Vector3(0.07, 0.75, 0.09), Vector3(-25.4, 1.0, 5), "5c624c")

func _alley() -> void:
	_box("alley_left", Vector3(5.0, 5.5, 16), Vector3(19, 2.75, 15), "805542", true)
	_box("alley_right", Vector3(5.0, 6.5, 22), Vector3(37, 3.25, 15), "95907d", true)
	_box("alley_back", Vector3(16, 4.8, 1.0), Vector3(29, 2.4, 26.8), "6f4c3e", true)
	_box("alley_strip", Vector3(11.7, 0.02, 23), Vector3(28, 0.035, 15), "363b33")
	for z: float in [8.5, 16, 23]:
		_box("alley_window", Vector3(0.09, 1.2, 1.0), Vector3(21.55, 3.6, z), "2f392d")
		_box("window_aircon", Vector3(0.6, 0.48, 0.9), Vector3(21.8, 2.6, z), "8c8b6b", true)
	_box("alley_drainpipe", Vector3(0.12, 5.4, 0.12), Vector3(21.65, 2.7, 10), "4d5140", true)
	_box("no_parking_sign_metal",Vector3(1.4,0.58,0.04),Vector3(28.7,2.6,26.26),"aa9d7d")
	_sign("NO PARKING", Vector3(28.7, 2.6, 26.22), 31, 0.0055, "594d3c", 180)
	_barrel(Vector3(33.4, 0, 22.5), true)
	_pallet(Vector3(24, 0, 24.7), 14)
	_pallet(Vector3(24, 0.22, 24.7), -7)
	_box("abandoned_sofa", Vector3(2.4, 0.70, 1.0), Vector3(32.8, 0.35, 18.4), "60633d", true, Vector3(0, -7, 0))
	_box("sofa_back", Vector3(2.4, 0.6, 0.27), Vector3(32.9, 0.95, 18.8), "6d6f43", true, Vector3(0, -7, 0))
	# Shallow industrial bays articulate both walls while keeping the alley wide.
	for z: float in [6.3,12.5,19.5,25.0]:
		_box("alley_brick_pier",Vector3(0.23,5.6,0.38),Vector3(21.57,2.8,z),"745748")
		_box("alley_concrete_band",Vector3(0.25,0.18,5.4),Vector3(21.57,4.75,z),"918a76")
	for z: float in [7.5,14.8,22]:
		_framed_window(Vector3(34.49,4.6,z),1.4,1.5,"6e7868",1,-90)
	_closed_entry(Vector3(34.49,0,11.5),1.5,2.6,"626d60",-90)
	_box("alley_roof_parapet",Vector3(0.38,0.7,22.4),Vector3(34.62,6.70,15),"938b77")
	_box("alley_concrete_cap",Vector3(0.55,0.12,22.65),Vector3(34.62,7.12,15),"aba28d")

func _backdrop() -> void:
	# Closed silhouettes establish a neighborhood beyond this deliberately bounded slice.
	var buildings: Array[Dictionary] = [
		{"p":Vector3(-35, 4.5, -28),"s":Vector3(10,9,15),"c":"795a4c","kind":"brick"},
		{"p":Vector3(-17, 5.5, -33),"s":Vector3(14,11,7),"c":"a79e88","kind":"plaster"},
		{"p":Vector3(3, 4, -35),"s":Vector3(10,8,6),"c":"999587","kind":"plaster"},
		{"p":Vector3(34, 3, -34),"s":Vector3(12,6,6),"c":"827363","kind":"brick"},
		{"p":Vector3(-14, 3.7, 27),"s":Vector3(12,7.4,5),"c":"826756","kind":"brick"},
		{"p":Vector3(6, 4.4, 29.5),"s":Vector3(14,8.8,3),"c":"a4957b","kind":"plaster"},
	]
	var facade_index: int = 0
	for row: Dictionary in buildings:
		var p: Vector3 = row["p"]
		var size: Vector3 = row["s"]
		var shell: String = "neighbor_brick" if row["kind"] == "brick" else "neighbor_building"
		_box(shell, size, p, row["c"], true)
		_box("neighbor_roof", Vector3(size.x + 0.6, 0.3, size.z + 0.6), Vector3(p.x, size.y + 0.13, p.z), "4d5141", true)
		# South buildings must face inward too; their old detail faced the fence.
		var yaw: float = 180.0 if p.z > 0.0 else 0.0
		var normal := Vector3(0,0,-1 if p.z > 0.0 else 1)
		var front: Vector3 = Vector3(p.x,0,p.z) + normal * (size.z * 0.5 + 0.01)
		_facade_piece("concrete_facade_band",Vector3(size.x+0.12,0.24,0.28),front,Vector3(0,2.8,0.10),yaw,"a69c83")
		_facade_piece("concrete_facade_cornice",Vector3(size.x+0.24,0.18,0.30),front,Vector3(0,size.y-0.22,0.12),yaw,"a69c83")
		_facade_piece("neighbor_ground_plaster",Vector3(size.x-0.1,2.65,0.05),front,Vector3(0,1.325,0.03),yaw,"746e5f" if facade_index%2==0 else "8e8370")
		_closed_entry(front,1.30,2.35,"4c5b4c",yaw)
		for side: float in [-1,1]:
			_framed_window(front+Vector3(side*size.x*0.30,1.5,0),2.2,1.5,"687366",facade_index,yaw)
			_facade_piece("neighbor_plaster_pier",Vector3(0.34,size.y,0.22),front,Vector3(side*(size.x*0.5-0.2),size.y*0.5,0.10),yaw,"9a917c")
		var columns: int = maxi(2,int(size.x/3.1))
		for col in range(columns):
			var wx: float = p.x + (col-float(columns-1)*0.5) * 3.05
			for story in range(1,int((size.y-0.4)/2.6)):
				_framed_window(Vector3(wx,1.9+story*2.6,front.z),1.35 if facade_index%2==0 else 1.55,1.55,"74796b",col+story+facade_index,yaw)
		for side: float in [-1,1]:
			_facade_piece("wall_utility_pipe",Vector3(0.10,size.y-0.4,0.12),front,Vector3(side*size.x*0.44,(size.y-0.4)*0.5,0.16),yaw,"5e6252")
		if facade_index%3==0:
			_box("neighbor_brick_parapet",Vector3(size.x+0.1,0.65,0.36),Vector3(p.x,size.y+0.48,front.z),"795e4f")
			_box("neighbor_concrete_cap",Vector3(size.x+0.4,0.14,0.55),Vector3(p.x,size.y+0.88,front.z),"a29a86")
			_box("neighbor_brick_parapet_step",Vector3(3.6,0.42,0.36),Vector3(p.x,size.y+0.95,front.z),"795e4f")
		elif facade_index%3==1:
			_box("roof_plaster_stairwell",Vector3(2.8,1.4,2.1),Vector3(p.x+size.x*0.2,size.y+0.8,p.z),"8b8778")
			_box("roof_metal_stairwell_cap",Vector3(3.15,0.14,2.4),Vector3(p.x+size.x*0.2,size.y+1.58,p.z),"535e54")
		else:
			_pitched_roof(Vector3(p.x,size.y+0.30,p.z),size.x+0.8,size.z+0.8,1.3,"60675d")
		_box("roof_brick_chimney",Vector3(0.75,1.65,0.85),Vector3(p.x-size.x*0.30,size.y+1.0,p.z-0.4),"705346")
		_box("chimney_concrete_cap",Vector3(0.95,0.13,1.0),Vector3(p.x-size.x*0.30,size.y+1.89,p.z-0.4),"aaa08a")
		# A few high side windows carry the architecture around the corner.
		var side_x: float = p.x + (size.x*0.5+0.01) * (1 if p.x<0 else -1)
		var side_yaw: float = 90.0 if p.x<0 else -90.0
		if size.z > 5:
			for z: float in [-0.25,0.25]:
				_framed_window(Vector3(side_x,4.5,p.z+size.z*z),1.25,1.5,"74796b",facade_index,side_yaw)
		facade_index += 1
	_fence(Vector3(-42,0,-38), Vector3(42,0,-38))
	_fence(Vector3(-42,0,-38), Vector3(-42,0,30))
	_fence(Vector3(42,0,-38), Vector3(42,0,30))
	_fence(Vector3(-42,0,30), Vector3(42,0,30))
	# Low detail built context closes the fence horizon in every direction.
	# These silhouettes remain beyond the already solid slice boundary.
	for i in range(7):
		var distant: float = -57.0 + i * 19.0
		var height: float = 7.0 + (i%3) * 2.8
		for z: float in [-51,44]:
			_box("distant_brick_factory",Vector3(17,height,9),Vector3(distant,height*0.5,z),"62675d",true)
			_box("distant_concrete_roofline",Vector3(17.5,0.3,9.4),Vector3(distant,height+0.1,z),"73786c")
			for col in range(5):
				_box("distant_window",Vector3(1.3,1.8,0.06),Vector3(distant-6+col*3,4.7,z+(4.54 if z<0 else -4.54)),"3d4b44")
			if i%2==0:
				_cylinder("distant_stack",0.65,5.0,Vector3(distant+4,height+2.5,z),"6d6a59",false,8)
	for x: float in [-51,51]:
		for i in range(4):
			var height: float = 6.4 + (i%2)*3.4
			var z: float = -25 + i*19
			_box("distant_plaster_building",Vector3(8,height,16),Vector3(x,height*0.5,z),"75796d",true)
			_box("distant_roof",Vector3(8.4,0.25,16.4),Vector3(x,height+0.1,z),"555f55")
			for row in range(3):
				_box("distant_window",Vector3(0.06,1.6,1.25),Vector3(x+(-4.05 if x>0 else 4.05),4.2,z-5+row*5),"3b4b42")

func _street_furniture() -> void:
	for point: Vector3 in [Vector3(-30,0,-2), Vector3(-10,0,-1.5), Vector3(13,0,-2.2), Vector3(34,0,-10.6)]:
		_lamp(point, 0)
	for x: float in [-36, -8, 25]:
		_cylinder("utility_pole", 0.17, 8.4, Vector3(x,4.2,-1.2), "776044", true)
		_box("crossarm", Vector3(2.5,0.15,0.18), Vector3(x,7.4,-1.2), "60533a")
		for offset: float in [-0.8, 0.8]:
			_cylinder("insulator",0.09,0.22,Vector3(x+offset,7.6,-1.2),"85896c")
	for pair: Vector2 in [Vector2(-36,-8), Vector2(-8,25)]:
		for offset: float in [-0.8,0.8]:
			var previous := Vector3(pair.x+offset,7.65,-1.2)
			for i in range(1,9):
				var t: float = i / 8.0
				var next := Vector3(lerpf(pair.x,pair.y,t)+offset,7.65-sin(t*PI)*1.25,-1.2)
				_beam(previous,next,0.025,"32372c")
				previous = next
	for id: String in ["dumpster_1", "dumpster_2", "dumpster_3"]:
		_dumpster(ANCHORS[id])
	_box("bus_stop_pole",Vector3(0.08,2.6,0.08),Vector3(-5,1.3,-11.4),"575e47",true)
	_box("bus_stop_sign",Vector3(0.7,0.8,0.09),Vector3(-5,2.4,-11.4),"9b9877")
	_sign("BUS",Vector3(-5,2.42,-11.34),35,0.008,"404a35")
	_sign("EVENTUALLY",Vector3(-5,2.16,-11.34),20,0.006,"404a35")
	for x: float in [-7.3, -3.5]:
		_cylinder("bollard",0.11,0.65,Vector3(x,0.325,-11.3),"9b8f4d",true)

func _lamp(at: Vector3, yaw: float) -> void:
	_cylinder("sodium_lamp_post", 0.10, 4.9, at+Vector3(0,2.45,0), "4a5140", true)
	_cylinder("lamp_foot", 0.23, 0.28, at+Vector3(0,0.14,0), "5a5e49", true)
	var arm := Vector3(sin(deg_to_rad(yaw))*0.8,0,cos(deg_to_rad(yaw))*0.8)
	_beam(at+Vector3(0,4.7,0),at+Vector3(0,4.7,0)+arm,0.12,"4a5140")
	_box("lamp_fixture",Vector3(0.48,0.16,0.72),at+Vector3(0,4.67,0)+arm,"555b44")
	_box("sodium_lens",Vector3(0.36,0.04,0.58),at+Vector3(0,4.56,0)+arm,"e8c040",false,Vector3.ZERO,1.5)
	var light := OmniLight3D.new()
	light.position = at+Vector3(0,4.35,0)+arm
	light.light_color = Color("e8c040")
	light.light_energy = 0.55
	light.omni_range = 9.0
	light.shadow_enabled = false
	add_child(light)
	lamps.append(light)

func _dumpster(at: Vector3) -> void:
	_box("dumpster_body",Vector3(1.85,1.18,1.14),at+Vector3(0,0.72,0),"485938",true)
	_box("dumpster_rim",Vector3(1.99,0.13,1.23),at+Vector3(0,1.35,0),"303d2c",true)
	_box("dumpster_lid",Vector3(2.02,0.10,1.3),at+Vector3(0,1.44,-0.03),"3e4930",true,Vector3(-6,0,0))
	for x: float in [-0.77,0.77]:
		for z: float in [-0.40,0.40]:
			var wheel: MeshInstance3D = _cylinder("dumpster_wheel",0.13,0.11,at+Vector3(x,0.14,z),"252c22")
			wheel.rotation_degrees.z = 90
	for x: float in [-0.6,0.6]:
		_box("dumpster_front_rib",Vector3(0.08,0.9,0.05),at+Vector3(x,0.73,0.6),"677046")
	_box("dumpster_sticker",Vector3(0.6,0.29,0.012),at+Vector3(0,0.90,0.6),"b5a76e")
	_sign("NO ASHES",at+Vector3(0,0.91,0.614),23,0.004,"4a5033")
	_box("dumpster_rust",Vector3(0.43,0.17,0.018),at+Vector3(-0.52,0.3,0.6),"80573b")

func _fence(a: Vector3,b: Vector3) -> void:
	var length: float = a.distance_to(b)
	var count: int = maxi(1,int(ceil(length/2.0)))
	for i in range(count+1):
		var at: Vector3 = a.lerp(b,float(i)/float(count))
		_box("fence_post",Vector3(0.13,1.9,0.13),at+Vector3(0,0.95,0),"6d7154",true)
	for y: float in [0.32,1.45]:
		_beam(a+Vector3(0,y,0),b+Vector3(0,y,0),0.10,"6f7152")
	# Broad sheets make an honest solid boundary and cheaper draw count than wire cells.
	var mid: Vector3 = (a+b)*0.5+Vector3(0,0.83,0)
	if absf(a.x-b.x)>absf(a.z-b.z):
		_box("fence_sheet",Vector3(length,1.5,0.055),mid,"666d49",true)
	else:
		_box("fence_sheet",Vector3(0.055,1.5,length),mid,"666d49",true)

func _barrel(at: Vector3,fire: bool) -> void:
	_cylinder("barrel",0.38,0.96,at+Vector3(0,0.48,0),"795b3d",true,10)
	for h: float in [0.17,0.77]:
		_cylinder("barrel_band",0.391,0.055,at+Vector3(0,h,0),"484e3b",false,10)
	if fire:
		_cylinder("barrel_coals",0.31,0.025,at+Vector3(0,0.97,0),"d06030",false,10)
		_box("barrel_flame",Vector3(0.12,0.38,0.09),at+Vector3(0.08,1.1,0),"d06030",false,Vector3(0,0,-14),1.6)
		var light:=OmniLight3D.new()
		light.position=at+Vector3(0,1.2,0)
		light.light_color=Color("d06030")
		light.light_energy=0.9
		light.omni_range=4.5
		add_child(light)

func _pallet(at: Vector3,yaw: float) -> void:
	for i in range(5):
		_box("pallet_board",Vector3(0.19,0.07,1.08),at+Vector3(-0.48+i*0.24,0.18,0),"88764e",false,Vector3(0,yaw,0))
	_box("pallet_core",Vector3(1.15,0.18,1.05),at+Vector3(0,0.09,0),"6c6241",true,Vector3(0,yaw,0))

func _wall_wear(center_x: float, z: float, width: float, height: float) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=int(absf(center_x)*233)
	for i in range(18):
		var x: float=center_x+rng.randf_range(-width*0.47,width*0.47)
		var y: float=rng.randf_range(0.15,height)
		# Paint wear never covers the service window or the fascia.
		if center_x<0 and absf(x-center_x)<2.4 and y<2.8:
			continue
		_box("wall_weathering",Vector3(rng.randf_range(0.15,0.55),rng.randf_range(0.05,0.28),0.012),Vector3(x,y,z+0.012),"665b43")

func _fixture(at: Vector3, width: float, color: String, energy: float, reach: float) -> void:
	# Every local light owns a visible casing and a luminous tube.
	_box("metal_strip_fixture", Vector3(width + 0.22, 0.13, 0.32), at, "585b51")
	_box("fluorescent_tube", Vector3(width, 0.045, 0.11), at + Vector3(0, -0.085, 0), color, false, Vector3.ZERO, 1.0)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, -0.28, 0.13)
	light.light_color = Color(color)
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	add_child(light)

func _pawn_interior() -> void:
	_box("shop_concrete_floor", Vector3(11.5, 0.035, 10.3), Vector3(-18, 0.035, -15.7), "756956")
	_box("shop_plaster_rear", Vector3(11.3, 4.8, 0.09), Vector3(-18, 2.4, -20.68), "998b70")
	_fixture(Vector3(-18, 2.85, -11.75), 2.8, "d4c896", 1.5, 5.8)
	_fixture(Vector3(-18, 3.5, -17.6), 3.2, "d4c896", 0.75, 6.3)
	# Back shelves are visible past Pete, but never intersect his target or body.
	for level: float in [0.65, 1.35, 2.05]:
		_box("shop_shelf_wood", Vector3(7.6, 0.10, 0.58), Vector3(-18, level, -17.4), "836b49", true)
	for x: float in [-21.75, -18, -14.25]:
		_box("shop_shelf_metal_upright", Vector3(0.07, 2.6, 0.07), Vector3(x, 1.3, -17.3), "464e43", true)
	for x: float in [-20.65, -18.9, -16.7]:
		_box("old_tv_wood", Vector3(1.0, 0.73, 0.48), Vector3(x, 1.77, -17.25), "6b533c")
		_box("tv_screen", Vector3(0.69, 0.48, 0.03), Vector3(x - 0.09, 1.8, -16.99), "34433c")
		_box("tv_screen_glare", Vector3(0.41, 0.035, 0.012), Vector3(x - 0.18, 1.96, -16.968), "687769", false, Vector3(0, 0, -18))
		for y: float in [1.62, 1.87]:
			var knob: MeshInstance3D = _cylinder("radio_metal_knob", 0.045, 0.035, Vector3(x + 0.38, y, -16.97), "a39776", false, 8)
			knob.rotation_degrees.x = 90
		_beam(Vector3(x - 0.11, 2.13, -17.2), Vector3(x - 0.46, 2.53, -17.2), 0.015, "7c806a")
		_beam(Vector3(x - 0.11, 2.13, -17.2), Vector3(x + 0.27, 2.44, -17.2), 0.015, "7c806a")
	for i in range(6):
		var x: float = -21.1 + i * 1.1
		_box("radio_metal_case", Vector3(0.73, 0.42, 0.31), Vector3(x, 0.91, -17.25), "655e4c")
		_box("radio_speaker", Vector3(0.39, 0.28, 0.02), Vector3(x - 0.10, 0.91, -17.07), "292f28")
		for slit in range(6):
			_box("speaker_grille_metal", Vector3(0.018, 0.23, 0.022), Vector3(x - 0.25 + slit * 0.06, 0.91, -17.05), "6f715d")
		_box("radio_tuner", Vector3(0.11, 0.07, 0.025), Vector3(x + 0.24, 0.99, -17.05), "c2b47e")
	for x: float in [-21, -20.35, -19.7, -15.4, -14.75]:
		_box("stock_box_cardboard", Vector3(0.53, 0.47, 0.43), Vector3(x, 2.34, -17.4), "9a8155")
		_box("packing_tape", Vector3(0.11, 0.49, 0.016), Vector3(x, 2.34, -17.17), "b4a071")
	_sign("AS IS", Vector3(-18, 2.86, -17.05), 37, 0.008, "c6b989")
	_box("desk_register_metal", Vector3(0.68, 0.40, 0.49), Vector3(-16.7, 1.13, -12.95), "6b6e5d")
	_box("register_readout", Vector3(0.43, 0.16, 0.035), Vector3(-16.7, 1.42, -12.74), "263a2d")
	_sign("0.00", Vector3(-16.7, 1.42, -12.71), 27, 0.003, "b6b176")
	for x in range(4):
		for z in range(3):
			_box("register_key", Vector3(0.08, 0.025, 0.07), Vector3(-16.85 + x * 0.10, 1.35, -12.77 + z * 0.09), "b6aa89")
	_box("receipt_spool", Vector3(0.17, 0.18, 0.22), Vector3(-16.4, 1.4, -13.0), "c2b68e")
	_box("receipt_paper", Vector3(0.13, 0.34, 0.014), Vector3(-16.4, 1.21, -12.72), "c2b68e")
	_box("shop_notice", Vector3(0.75, 0.52, 0.04), Vector3(-20.6, 1.85, -12.3), "b4a583")
	_sign("NO REFUNDS", Vector3(-20.6, 1.85, -12.27), 25, 0.005, "493b2e")
	_box("wall_clock_back", Vector3(0.55, 0.55, 0.09), Vector3(-15, 3.2, -20.57), "4f4e40")
	_box("clock_face", Vector3(0.43, 0.43, 0.025), Vector3(-15, 3.2, -20.50), "c1b68d")
	_box("clock_hand", Vector3(0.025, 0.18, 0.018), Vector3(-15, 3.26, -20.48), "373b31")
	_box("clock_hand", Vector3(0.14, 0.025, 0.018), Vector3(-14.95, 3.2, -20.47), "373b31")

func _street_details() -> void:
	_parked_car(Vector3(-32, 0, -6.4))
	# Cabinets hug existing structures; they do not narrow the public crossings.
	_utility_cabinet(Vector3(-11.35, 0, -17.7), 90)
	_utility_cabinet(Vector3(34.1, 0, 6.5), -90)
	_box("metal_mailbox", Vector3(0.66, 1.12, 0.66), Vector3(-29.6, 0.56, -1.45), "4f6052", true)
	_box("mailbox_metal_lid", Vector3(0.70, 0.12, 0.71), Vector3(-29.6, 1.18, -1.45), "697365")
	_box("mail_slot", Vector3(0.46, 0.07, 0.018), Vector3(-29.6, 0.97, -1.10), "252f28")
	_sign("COLLECTION\nPENDING", Vector3(-29.6, 0.69, -1.10), 21, 0.005, "bdaf83")
	# Loading stoop at the back of the alley, outside the Lurch approach/recovery lane.
	_box("loading_concrete_stoop", Vector3(3.0, 0.32, 1.25), Vector3(32, 0.16, 25.5), "85806c", true)
	_box("loading_concrete_step", Vector3(3.0, 0.15, 0.38), Vector3(32, 0.075, 24.7), "777563", true)
	_box("loading_metal_door", Vector3(2.3, 2.7, 0.08), Vector3(32, 1.67, 26.23), "526055")
	for x: float in [30.6, 33.4]:
		for z: float in [24.95, 25.95]:
			_box("loading_rail_post", Vector3(0.065, 0.9, 0.065), Vector3(x, 0.77, z), "5b6150", true)
		_beam(Vector3(x,1.22,24.95),Vector3(x,1.22,25.95),0.065,"747962")
	_fixture(Vector3(32, 3.25, 26.1), 1.4, "d4c896", 0.55, 4.1)
	for z: float in [8.5, 16, 23]:
		# Wall-only geometry stays outside the traversable alley.
		_box("window_frame_metal", Vector3(0.12, 1.32, 1.18), Vector3(21.53, 3.6, z), "9c9279")
		_box("alley_window", Vector3(0.14, 1.12, 0.98), Vector3(21.60, 3.6, z), "283b35")
		_box("window_mullion", Vector3(0.16, 0.045, 1.0), Vector3(21.64, 3.6, z), "8d8770")
		for slit in range(5):
			_box("aircon_grille", Vector3(0.025, 0.035, 0.7), Vector3(22.115, 2.43 + slit * 0.07, z), "505746")
	_box("wall_utility_pipe", Vector3(0.11, 5.0, 0.11), Vector3(34.35, 2.5, 9.4), "675948")
	_box("wall_utility_pipe", Vector3(0.11, 5.8, 0.11), Vector3(34.35, 2.9, 21.5), "675948")
	for at: Vector3 in [Vector3(-3.6,0,11.8), Vector3(11.5,0,-18.0), Vector3(-39,0,17)]:
		# Crushed cans and one newspaper are flat debris, not new pickups.
		var can: MeshInstance3D = _cylinder("discarded_metal_can", 0.075, 0.15, at + Vector3(0,0.09,0), "99957e", false, 7)
		can.rotation_degrees.z = 68
	_box("newspaper", Vector3(0.38,0.008,0.48), Vector3(2.6,0.08,9.4), "b0a487", false, Vector3(0,13,0))
	for i in range(5):
		_box("newspaper_print", Vector3(0.28,0.006,0.014), Vector3(2.6,0.088,9.25 + i * 0.06), "6c6754", false, Vector3(0,13,0))
	# Yuri's inventory has physical variety while the optional copper anchor remains clear.
	for at: Vector3 in [Vector3(-37,0,15.5), Vector3(-37.8,0,16.4)]:
		for level in range(3):
			_cylinder("scrap_tire", 0.48, 0.25, at + Vector3(0,0.125 + level * 0.25,0), "30372e", false, 10)
		# The three tires form one standing obstacle, including its save footprint.
		var tire_stack_shape := CylinderShape3D.new()
		tire_stack_shape.radius = 0.48
		tire_stack_shape.height = 0.75
		_solid(tire_stack_shape, at + Vector3(0,0.375,0), Vector3.ZERO, Vector3(0.96,0.75,0.96))
	_box("yard_workbench_wood", Vector3(2.7, 0.16, 0.78), Vector3(-29.4, 1.0, 4.0), "87714e", true)
	for x: float in [-30.55,-28.25]:
		_box("workbench_metal_leg", Vector3(0.10, 0.93, 0.10), Vector3(x, 0.465, 4.0), "5b6450", true)
	_box("metal_vise", Vector3(0.34, 0.25, 0.28), Vector3(-30,1.2,4.04), "7a5742")
	_box("metal_toolbox", Vector3(0.61, 0.28, 0.36), Vector3(-28.8,1.22,4.0), "8a4c3b")
	_box("toolbox_handle", Vector3(0.22,0.05,0.08), Vector3(-28.8,1.39,4.0), "30392d")
	for x in range(4):
		var p: MeshInstance3D = _cylinder("scrap_pipe_short",0.095,1.3,Vector3(-37.2+x*0.28,0.30,23.0),"8b6140",false,8)
		p.rotation_degrees.z=90

func _occupied_edges() -> void:
	# Small, authored groups sit against occupied edges. No props enter the
	# central crossing, service approaches or the yard's broad gate lane.
	var bench := Vector3(-5.2,0,-12.55)
	for x: float in [-1.1,1.1]:
		_box("bench_metal_support",Vector3(0.12,0.45,0.62),bench+Vector3(x,0.225,0),"535f52",true)
		_box("bench_metal_back",Vector3(0.07,1.0,0.07),bench+Vector3(x,0.50,-0.23),"535f52",true)
	for z: float in [-0.20,0,0.20]:
		_box("bench_wood_seat",Vector3(2.75,0.065,0.15),bench+Vector3(0,0.48,z),"8a7758",true)
	for y: float in [0.72,0.94]:
		_box("bench_wood_back",Vector3(2.75,0.16,0.065),bench+Vector3(0,y,-0.23),"7e7056",true)
	_cylinder("litter_bin_metal",0.30,0.80,Vector3(-8.15,0.40,-12.5),"5d6a58",true,10)
	_cylinder("litter_bin_lid_metal",0.33,0.10,Vector3(-8.15,0.85,-12.5),"79816b",false,10)
	_cylinder("litter_bin_slot",0.17,0.008,Vector3(-8.15,0.907,-12.5),"28342a",false,10)
	for at: Vector3 in [Vector3(-27.5,0,-1.9),Vector3(29.3,0,-11.3)]:
		_cylinder("parking_meter_metal_post",0.055,1.18,at+Vector3(0,0.59,0),"6b7568",true,8)
		_box("parking_meter_metal_case",Vector3(0.27,0.46,0.21),at+Vector3(0,1.36,0),"9a9d88",true)
		_box("parking_meter_face",Vector3(0.18,0.16,0.018),at+Vector3(0,1.43,0.114),"35483b")
		_box("parking_meter_slot",Vector3(0.08,0.018,0.022),at+Vector3(0,1.28,0.116),"25342b")
	# A low rack is a single collision envelope, not a set of holes the player
	# can accidentally wedge into. It stays on the broad eastern sidewalk edge.
	var rack := Vector3(31.2,0,-1.55)
	for x: float in [-0.9,0,0.9]:
		for z: float in [-0.22,0.22]:
			_cylinder("bicycle_rack_metal",0.035,0.70,rack+Vector3(x,0.35,z),"7d8774",false,8)
		_beam(rack+Vector3(x,0.70,-0.22),rack+Vector3(x,0.70,0.22),0.07,"7d8774")
	var rack_shape := BoxShape3D.new()
	rack_shape.size = Vector3(1.9,0.74,0.54)
	_solid(rack_shape,rack+Vector3(0,0.37,0),Vector3.ZERO,rack_shape.size)
	_pallet(Vector3(-10.5,0,-20.4),0)
	for offset: Vector3 in [Vector3(-0.25,0.46,-0.20),Vector3(0.27,0.42,0.20),Vector3(-0.25,0.95,-0.20)]:
		_box("stock_box_cardboard",Vector3(0.53,0.48,0.52),Vector3(-10.5,0,-20.4)+offset,"927b57",true)
		_box("packing_tape",Vector3(0.10,0.49,0.015),Vector3(-10.5,0,-20.4)+offset+Vector3(0,0,0.27),"b2a07a")
	# A proper wire spool and grouped appliance fronts establish what is sold.
	var spool := Vector3(-37.3,0,12.6)
	_cylinder("wood_cable_spool",0.67,0.12,spool+Vector3(0,0.10,0),"8b7555",true,10)
	_cylinder("cable_spool_metal",0.39,0.66,spool+Vector3(0,0.46,0),"4d5b4f",true,10)
	_cylinder("wood_cable_spool",0.67,0.12,spool+Vector3(0,0.86,0),"8b7555",true,10)
	for y: float in [0.22,0.31,0.40,0.49,0.58,0.67]:
		_cylinder("coiled_wire_metal",0.41,0.035,spool+Vector3(0,y,0),"677065",false,10)
	for x: float in [-29.0,-27.8]:
		_box("old_appliance_metal",Vector3(1.0,1.15,0.80),Vector3(x,0.575,24.9),"999787",true)
		_box("appliance_control_metal",Vector3(0.94,0.18,0.04),Vector3(x,1.04,25.32),"6e786a")
		var drum: MeshInstance3D = _cylinder("appliance_drum_metal",0.32,0.05,Vector3(x,0.55,25.33),"56665c",false,12)
		drum.rotation_degrees.x = 90
		var glass: MeshInstance3D = _cylinder("appliance_glass",0.23,0.055,Vector3(x,0.55,25.37),"2d3d34",false,12)
		glass.rotation_degrees.x = 90
	_box("yard_wood_rack",Vector3(2.7,0.10,0.8),Vector3(-37.8,1.95,18.1),"857354",true)
	for x: float in [-38.9,-36.7]:
		_box("yard_rack_metal_post",Vector3(0.09,2.4,0.09),Vector3(x,1.2,18.1),"5c695a",true)
	for x: float in [-38.7,-37.9,-37.1]:
		_box("salvaged_metal_radiator",Vector3(0.62,0.64,0.42),Vector3(x,2.32,18.1),"878c77")
		for rib in range(4):
			_box("radiator_metal_rib",Vector3(0.055,0.57,0.46),Vector3(x-0.22+rib*0.14,2.32,18.1),"a0a18b")
	# Meter banks, a downpipe and the patched wall remain a single side-wall group.
	for z: float in [-14.8,-15.45,-16.1]:
		_box("wall_meter_metal",Vector3(0.18,0.42,0.33),Vector3(-11.66,1.7,z),"859080")
		_cylinder("wall_meter_conduit",0.025,1.45,Vector3(-11.63,0.725,z),"697667",false,6)

func _utility_cabinet(at: Vector3, yaw: float) -> void:
	_box("utility_cabinet", Vector3(1.0, 1.55, 0.52), at + Vector3(0,0.775,0), "686d61", true, Vector3(0,yaw,0))
	var normal: Vector3 = Vector3(sin(deg_to_rad(yaw)),0,cos(deg_to_rad(yaw)))
	var front: Vector3 = at + normal * 0.28
	_box("cabinet_front_metal", Vector3(0.88,1.37,0.035),front+Vector3(0,0.77,0),"7c8070",false,Vector3(0,yaw,0))
	for i in range(5):
		_box("cabinet_vent", Vector3(0.62,0.035,0.04),front+normal*0.03+Vector3(0,0.4+i*0.10,0),"3b463a",false,Vector3(0,yaw,0))
	_box("cabinet_warning", Vector3(0.23,0.19,0.016),front+normal*0.04+Vector3(0,1.18,0),"b4a34e",false,Vector3(0,yaw,0))
	_sign("!",front+normal*0.052+Vector3(0,1.18,0),30,0.004,"433d2a",yaw)

func _parked_car(at: Vector3) -> void:
	# Original crooked sedan, inert scenery. No transport or item surface is added.
	_box("car_underbody",Vector3(4.3,0.34,1.72),at+Vector3(0,0.50,0),"353b32",true)
	_box("car_body",Vector3(4.2,0.53,1.82),at+Vector3(0,0.78,0),"84533d",true)
	_box("car_hood",Vector3(1.25,0.16,1.78),at+Vector3(1.4,1.04,0),"925e43")
	_box("car_trunk",Vector3(0.88,0.12,1.78),at+Vector3(-1.65,1.02,0),"735542")
	_box("car_cabin",Vector3(1.95,0.66,1.48),at+Vector3(-0.18,1.34,0),"745a45",true)
	_box("car_roof",Vector3(2.05,0.10,1.55),at+Vector3(-0.18,1.72,0),"9b7859")
	for side: float in [-1,1]:
		_box("car_side_glass",Vector3(1.68,0.43,0.025),at+Vector3(-0.18,1.39,side*0.757),"30423c")
		_box("car_window_pillar",Vector3(0.10,0.57,0.065),at+Vector3(-0.18,1.37,side*0.77),"7b5941")
		_box("car_window_seal",Vector3(1.85,0.05,0.065),at+Vector3(-0.18,1.13,side*0.77),"2c352d")
		_box("car_door_seam",Vector3(0.025,0.48,0.018),at+Vector3(-0.18,0.83,side*0.92),"493c2d")
		for x: float in [-1.34,1.34]:
			var wheel: MeshInstance3D = _cylinder("car_tire",0.42,0.20,at+Vector3(x,0.43,side*0.86),"292f28",false,12)
			wheel.rotation_degrees.x=90
			var hub: MeshInstance3D = _cylinder("car_metal_hub",0.22,0.025,at+Vector3(x,0.43,side*0.975),"938e75",false,8)
			hub.rotation_degrees.x=90
			_box("car_door_handle",Vector3(0.21,0.055,0.04),at+Vector3(x*0.42,1.0,side*0.93),"a49c7d")
		_box("car_rust_patch",Vector3(0.72,0.19,0.025),at+Vector3(-1.4,0.71,side*0.929),"634734")
	_box("car_windshield",Vector3(0.025,0.44,1.28),at+Vector3(0.813,1.41,0),"334740")
	_box("car_rear_glass",Vector3(0.025,0.41,1.28),at+Vector3(-1.17,1.41,0),"2e3e36")
	for x: float in [-2.16,2.16]:
		_box("car_metal_bumper",Vector3(0.15,0.16,1.86),at+Vector3(x,0.58,0),"97917a")
	for z: float in [-0.59,0.59]:
		_box("car_headlamp",Vector3(0.045,0.20,0.42),at+Vector3(2.12,0.87,z),"c5b98d")
		_box("car_tail_light",Vector3(0.045,0.15,0.37),at+Vector3(-2.12,0.89,z),"8a3a3a")
	_box("car_grille",Vector3(0.05,0.22,0.62),at+Vector3(2.12,0.83,0),"30392f")
	for z in range(5):
		_box("car_grille_metal",Vector3(0.065,0.18,0.026),at+Vector3(2.14,0.83,-0.23+z*0.115),"8a8a70")
	_box("car_plate",Vector3(0.04,0.16,0.44),at+Vector3(-2.24,0.65,0),"ada181")
	_box("car_mirror",Vector3(0.22,0.13,0.12),at+Vector3(0.52,1.19,-0.99),"6c5d45")
	_box("car_missing_mirror_stem",Vector3(0.11,0.05,0.14),at+Vector3(0.52,1.18,0.98),"484b3b")

func _dressing() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=1967
	var weeds: Array[Transform3D]=[]
	var papers: Array[Transform3D]=[]
	for i in range(115):
		var x: float=rng.randf_range(-39,39)
		var z: float=rng.randf_range(-29,27)
		if z > -10.8 and z < -2.7:
			continue
		var h: float=rng.randf_range(0.10,0.32)
		var basis:=Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3(0.04,h,0.08))
		weeds.append(Transform3D(basis,Vector3(x,h*0.5,z)))
	for i in range(35):
		var basis:=Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3(rng.randf_range(0.10,0.24),0.006,rng.randf_range(0.12,0.28)))
		papers.append(Transform3D(basis,Vector3(rng.randf_range(-33,33),0.055,rng.randf_range(-11,25))))
	_multibox("gutter_weeds",weeds,"777746")
	_multibox("discarded_paper",papers,"b1a57c")
	for at: Vector3 in [Vector3(12,0,1.0),Vector3(-9,0,20),Vector3(31.8,0,-24.3),Vector3(-22,0,-8.8)]:
		_cylinder("trash_bag",0.27,0.48,at+Vector3(0,0.24,0),"353e2c",false,6,0.10)
		_cylinder("bag_knot",0.04,0.12,at+Vector3(0,0.53,0),"454a35",false,5,0.02)
	for at: Vector3 in [Vector3(-7,0,13),Vector3(12,0,-11),Vector3(29,0,4)]:
		_box("drain_frame",Vector3(0.90,0.026,0.45),at+Vector3(0,0.04,0),"333c2e")
		for i in range(6):
			_box("drain_grate",Vector3(0.035,0.025,0.42),at+Vector3(-0.36+i*0.14,0.06,0),"77785a")
	# A brown, shallow reflection catches a piece of sky without making a clean blue pool.
	for at: Vector3 in [Vector3(7,0.019,-8.5),Vector3(-20,0,1.0),Vector3(29,0.045,21)]:
		var puddle: MeshInstance3D=_cylinder("puddle",1.25,0.004,at+Vector3(0,0.0025,0),"575b45",false,9)
		puddle.scale.z=0.48
		puddle.material_override=_mat("555a47",0.25)
		puddle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
