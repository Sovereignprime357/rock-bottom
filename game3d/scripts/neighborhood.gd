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
	sun.light_energy = 0.62 * daylight
	environment.ambient_light_energy = 0.25 * daylight + 0.13
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
	sky_material.sky_top_color = Color("30383a").lerp(Color("535c63"), sky_daylight)
	sky_material.sky_horizon_color = Color("3d4542").lerp(Color("97958b"), sky_daylight)
	sky_material.ground_bottom_color = Color("22271f").lerp(Color("3c3a30"), sky_daylight)
	sky_material.ground_horizon_color = Color("30382f").lerp(Color("78776b"), sky_daylight)
	environment.background_energy_multiplier = lerpf(0.5, 0.65, sky_daylight)
	environment.fog_light_color = Color("39423b").lerp(Color("7b807a"), sky_daylight)

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
	if label in ["street", "north_access", "south_path", "alley_strip"]:
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

func _lighting() -> void:
	var world_env := WorldEnvironment.new()
	environment = Environment.new()
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("535c63")
	sky_material.sky_horizon_color = Color("97958b")
	sky_material.ground_bottom_color = Color("3c3a30")
	sky_material.ground_horizon_color = Color("78776b")
	sky_material.sky_curve = 0.22
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b2ada3")
	environment.ambient_light_energy = 0.37
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.background_energy_multiplier = 0.65
	environment.fog_enabled = true
	environment.fog_light_color = Color("7b807a")
	environment.fog_density = 0.0032
	environment.fog_sky_affect = 0.4
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -38, 0)
	sun.light_color = Color("d4c8a6")
	sun.light_energy = 0.62
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
		_box("old_center_line", Vector3(2.3, 0.012, 0.1), Vector3(i * 5.0, 0.024, -6.5), "a89b5c")
	for i in range(-10, 11):
		for side: float in [-11.0, -2.0]:
			_box("paving_slab", Vector3(3.95, 0.055, 2.0), Vector3(i * 4.0, 0.027, side), "8a8172")
		_box("curb_seam", Vector3(3.92, 0.07, 0.18), Vector3(i * 4.0, 0.035, -3.05), "aaa18b")
		_box("curb_seam", Vector3(3.92, 0.07, 0.18), Vector3(i * 4.0, 0.035, -10.05), "8d8775")
	for x: float in [-6.0, 0.0, 6.0]:
		_box("crosswalk", Vector3(0.72, 0.012, 5.4), Vector3(x, 0.035, -6.5), "b0a580")
	var rng := RandomNumberGenerator.new()
	rng.seed = 73815
	var colors: Array[String] = ["44453a", "393b33", "626051", "4b4b3f"]
	for color: String in colors:
		var stamps: Array[Transform3D] = []
		for i in range(38):
			var pos := Vector3(rng.randf_range(-39, 39), 0.037, rng.randf_range(-31, 26))
			var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI))
			basis = basis.scaled(Vector3(rng.randf_range(0.25, 1.7), 0.008, rng.randf_range(0.2, 0.95)))
			stamps.append(Transform3D(basis, pos))
		_multibox("asphalt_repairs", stamps, color)
	# Thin tar seams join repaired ground into a legible material rather than noise.
	for x: float in [-35, -24, -11, 9, 23, 36]:
		_box("tar_seam", Vector3(0.032, 0.01, 5.1), Vector3(x, 0.04, -6.4), "24281f", false, Vector3(0, 12, 0))

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
	_box("pawn_fascia", Vector3(11.2, 1.0, 0.22), Vector3(-18, 4.25, -10.08), "30433a")
	_box("metal_sign_frame_top", Vector3(11.3, 0.055, 0.26), Vector3(-18, 4.76, -10.06), "a79d7d")
	_box("metal_sign_frame_low", Vector3(11.3, 0.055, 0.26), Vector3(-18, 3.74, -10.06), "817d65")
	_sign("PAWN SHOP PETE", Vector3(-18, 4.25, -9.94), 80, 0.010, "d4c896")
	_sign("BUY  /  SELL  /  WEIGH", Vector3(-18, 3.36, -10.13), 40, 0.009, "c8b67b")
	_box("pawn_awning", Vector3(11.5, 0.16, 2.0), Vector3(-18, 3.05, -9.8), "58644a", true, Vector3(-7, 0, 0))
	for x in range(10):
		_box("awning_stripe", Vector3(0.42, 0.018, 2.02), Vector3(-22.6 + x * 1.02, 3.145, -9.8), "9a9270", false, Vector3(-7, 0, 0))
	_sign("OPEN", Vector3(-14, 1.9, -10.2), 50, 0.010, "e8c040")
	_sign("11 MINUTES", Vector3(-22, 1.8, -10.2), 36, 0.010, "b6a67c")
	for x: float in [-22, -14]:
		_box("upstairs_window", Vector3(1.35, 1.25, 0.09), Vector3(x, 5.15, -10.19), "313b31")
		_box("upstairs_sill", Vector3(1.5, 0.12, 0.3), Vector3(x, 4.49, -10.1), "a4997c")
	_box("scale_base", Vector3(0.5, 0.1, 0.35), Vector3(-19.3, 1.07, -10.43), "8c8971")
	_cylinder("scale_pan", 0.26, 0.05, Vector3(-19.3, 1.16, -10.43), "b0a78c")
	_box("hot_pocket", Vector3(0.35, 0.12, 0.24), Vector3(-17.1, 1.08, -10.6), "ae8248")
	_box("paper_sleeve", Vector3(0.18, 0.13, 0.26), Vector3(-17.19, 1.08, -10.6), "b9ac83")
	_wall_wear(-18, -10.225, 11, 5.6)
	# Exposed brick courses survive where the ground-floor plaster has failed.
	for x: float in [-22.1, -13.9]:
		_box("pawn_exposed_brick", Vector3(3.9, 0.72, 0.035), Vector3(x, 0.36, -10.23), "805a47")
		_box("concrete_water_table", Vector3(4.0, 0.10, 0.09), Vector3(x, 0.76, -10.19), "8f836c")
		for side: float in [-0.63, 0.63]:
			_box("window_frame_metal", Vector3(0.055, 1.3, 0.12), Vector3(x + side, 5.15, -10.12), "aa9c7c")
		_box("window_mullion", Vector3(1.3, 0.055, 0.12), Vector3(x, 5.15, -10.11), "91866c")
	_box("wall_utility_pipe", Vector3(0.11, 5.7, 0.11), Vector3(-23.78, 2.85, -10.15), "514f40")
	_box("wall_utility_pipe", Vector3(0.11, 5.7, 0.11), Vector3(-12.23, 2.85, -10.15), "514f40")
	_pawn_interior()

func _corner() -> void:
	_box("corner_store", Vector3(17, 6.2, 9), Vector3(18, 3.1, -23.0), "8b5944", true)
	_box("corner_plinth", Vector3(17.1, 0.8, 9.1), Vector3(18, 0.4, -23.0), "64584c", true)
	_box("corner_cornice", Vector3(17.7, 0.4, 9.7), Vector3(18, 6.24, -23), "454737", true)
	_box("corner_fascia", Vector3(15.8, 1.15, 0.24), Vector3(18, 4.3, -18.36), "703928")
	_sign("THE CORNER", Vector3(18, 4.3, -18.20), 88, 0.012, "e8c040")
	for x: float in [12.3, 23.7]:
		_box("store_window", Vector3(3.5, 2.0, 0.1), Vector3(x, 1.65, -18.43), "313a30")
		for offset: float in [-0.9, 0.8]:
			_box("window_board", Vector3(3.7, 0.24, 0.08), Vector3(x, 1.65 + offset, -18.34), "7b6b49", false, Vector3(0, 0, -7))
	_box("locked_door", Vector3(1.7, 2.55, 0.13), Vector3(18, 1.275, -18.4), "3f4530")
	_box("door_board", Vector3(2.1, 0.28, 0.1), Vector3(18, 1.4, -18.27), "8e7650", false, Vector3(0, 0, 22))
	_box("corner_canopy", Vector3(13.5, 0.22, 3.8), Vector3(18, 3.42, -16.55), "b0793c", true)
	_box("canopy_edge", Vector3(13.6, 0.38, 0.18), Vector3(18, 3.28, -14.64), "64422d")
	for x: float in [11.8, 24.2]:
		_box("canopy_post", Vector3(0.15, 3.4, 0.15), Vector3(x, 1.7, -15.0), "554c35", true)
	_sign("TRE BAG TONY", Vector3(18, 2.92, -14.48), 47, 0.010, "d4c896")
	_sign("CLOSED", Vector3(12.2, 1.6, -18.24), 37, 0.008, "a38f62")
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

func _block() -> void:
	_box("block_pad", Vector3(12, 0.05, 13), Vector3(0, 0.025, 6.6), "8b8170")
	var grime_rng := RandomNumberGenerator.new()
	grime_rng.seed = 3027
	for color: String in ["56563f", "65604a", "4d5140"]:
		var stains: Array[Transform3D] = []
		for i in range(9):
			var basis := Basis(Vector3.UP, grime_rng.randf_range(-PI, PI))
			basis = basis.scaled(Vector3(grime_rng.randf_range(0.15, 0.7), 0.006, grime_rng.randf_range(0.13, 0.45)))
			stains.append(Transform3D(basis, Vector3(grime_rng.randf_range(-5.5,5.5),0.062,grime_rng.randf_range(0.8,12.4))))
		_multibox("block_oil_and_wear", stains, color)
	_box("crate_use_stain", Vector3(1.2, 0.006, 1.0), Vector3(0.08,0.062,4.05), "53523b", false, Vector3(0,12,0))
	for i in range(4):
		_box("block_paving_seam", Vector3(0.025, 0.012, 12.5), Vector3(-4.5 + i * 3, 0.057, 6.6), "464a39")
	_box("block_backwall", Vector3(15.8, 1.45, 0.38), Vector3(-0.8, 0.725, 14.5), "82604b", true)
	_box("block_wall_cap", Vector3(16, 0.14, 0.58), Vector3(-0.8, 1.5, 14.5), "a3956f", true)
	_sign("THE BLOCK", Vector3(-0.8, 0.95, 14.28), 64, 0.009, "bcae7d", 180)
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
	_sign("NO LOITERING", Vector3(-6.02, 1.78, 6.72), 35, 0.009, "bfb484", 26)
	_sign("since 1987", Vector3(-6.02, 1.25, 6.72), 30, 0.008, "a89c72", 26)
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
	_box("yard_sign", Vector3(7, 1.35, 0.18), Vector3(-31, 3.0, 2), "3e482f")
	_sign("YURI'S SCRAP", Vector3(-31, 3.02, 1.85), 60, 0.010, "d4c896", 180)
	_box("yard_gate_post", Vector3(0.18, 3.0, 0.18), Vector3(-23, 1.5, 8), "72644a", true)
	_box("yard_gate_post", Vector3(0.18, 3.0, 0.18), Vector3(-23, 1.5, 18), "72644a", true)
	_box("scale_platform", Vector3(2.5, 0.18, 2.6), Vector3(-33, 0.09, 12.5), "484e3f", true)
	_box("scale_column", Vector3(0.18, 1.4, 0.18), Vector3(-34.1, 0.7, 12.5), "8a7958", true)
	_box("scale_display", Vector3(0.64, 0.48, 0.25), Vector3(-34.1, 1.45, 12.5), "b2a480")
	_sign("0", Vector3(-34.1, 1.45, 12.65), 40, 0.009, "292f25")
	_box("yard_shed", Vector3(6, 3.8, 6.5), Vector3(-35, 1.9, 6.2), "666e48", true)
	_box("shed_roof", Vector3(6.7, 0.18, 7.0), Vector3(-35, 3.9, 6.2), "534d3d", true, Vector3(0, 0, -3))
	for x in range(15):
		_box("shed_corrugation", Vector3(0.055, 3.7, 0.1), Vector3(-37.8 + x * 0.4, 1.85, 9.48), "515b3c")
	_box("shed_door", Vector3(1.3, 2.35, 0.1), Vector3(-35.1, 1.175, 9.54), "414a34")
	_sign("BRUTUS", Vector3(-32.8, 1.35, 9.6), 32, 0.009, "c1ae76")
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
	_sign("NO PARKING", Vector3(28.7, 2.6, 26.22), 65, 0.012, "c1ae79", 180)
	_barrel(Vector3(33.4, 0, 22.5), true)
	_pallet(Vector3(24, 0, 24.7), 14)
	_pallet(Vector3(24, 0.22, 24.7), -7)
	_box("abandoned_sofa", Vector3(2.4, 0.70, 1.0), Vector3(32.8, 0.35, 18.4), "60633d", true, Vector3(0, -7, 0))
	_box("sofa_back", Vector3(2.4, 0.6, 0.27), Vector3(32.9, 0.95, 18.8), "6d6f43", true, Vector3(0, -7, 0))

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
	for row: Dictionary in buildings:
		var p: Vector3 = row["p"]
		var size: Vector3 = row["s"]
		var shell: String = "neighbor_brick" if row["kind"] == "brick" else "neighbor_building"
		_box(shell, size, p, row["c"], true)
		_box("neighbor_roof", Vector3(size.x + 0.6, 0.3, size.z + 0.6), Vector3(p.x, size.y + 0.13, p.z), "4d5141", true)
		var front: float = p.z + size.z * 0.5 + 0.055
		_box("concrete_facade_band",Vector3(size.x+0.1,0.22,0.12),Vector3(p.x,2.8,front),"a69c83")
		_box("concrete_facade_cornice",Vector3(size.x+0.15,0.18,0.19),Vector3(p.x,size.y-0.37,front),"a69c83")
		for x in range(int(size.x / 3.0)):
			for y in range(1, int(size.y / 2.7) + 1):
				var wx: float = p.x - size.x / 2 + 1.6 + x * 3.0
				_box("neighbor_window", Vector3(1.05, 1.4, 0.07), Vector3(wx, y * 2.5 - 0.5, front), "374034")
				_box("neighbor_window_sill", Vector3(1.3, 0.1, 0.22), Vector3(wx, y * 2.5 - 1.23, front + 0.04), "9a9272")
				_box("window_lintel_concrete",Vector3(1.26,0.15,0.12),Vector3(wx,y*2.5+0.27,front+0.03),"a39a80")
				_box("window_mullion",Vector3(1.05,0.05,0.09),Vector3(wx,y*2.5-0.38,front+0.04),"8b8b73")
				if (x+y)%3==0:
					_box("window_board",Vector3(1.22,0.22,0.055),Vector3(wx,y*2.5-0.7,front+0.08),"7e6746",false,Vector3(0,0,12))
		_box("closed_metal_door",Vector3(1.3,2.2,0.10),Vector3(p.x,1.1,front+0.04),"4c5b4c")
		_box("door_lintel_concrete",Vector3(1.6,0.2,0.2),Vector3(p.x,2.3,front+0.04),"9b917a")
		_box("wall_utility_pipe",Vector3(0.12,size.y,0.12),Vector3(p.x+size.x*0.46,size.y/2,front+0.06),"5e6252")
	_fence(Vector3(-42,0,-38), Vector3(42,0,-38))
	_fence(Vector3(-42,0,-38), Vector3(-42,0,30))
	_fence(Vector3(42,0,-38), Vector3(42,0,30))
	_fence(Vector3(-42,0,30), Vector3(42,0,30))
	for i in range(5):
		var distant: float = -50.0 + i * 24.0
		_box("distant_factory", Vector3(16, 12 + (i % 3) * 5, 12), Vector3(distant, 4, -58), "626858")
		_cylinder("distant_stack", 0.9, 16, Vector3(distant + 4, 15, -58), "6d6a52")

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
	for at: Vector3 in [Vector3(7,0,-8.5),Vector3(-20,0,1.0),Vector3(29,0,21)]:
		var puddle: MeshInstance3D=_cylinder("puddle",1.25,0.008,at+Vector3(0,0.045,0),"575b45",false,9)
		puddle.scale.z=0.48
		puddle.material_override=_mat("555a47",0.25)
