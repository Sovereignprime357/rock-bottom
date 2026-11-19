extends Node3D
class_name FullWeatherPresentation
## Full-world presentation only. No state authority, timers, random draws or bodies.
const Content = preload("res://scripts/content_catalog.gd")
const INSTANCE_COUNT := 160
const COLUMN_COUNT := 16
const COLUMN_SIZE := 2.5
const DROPS_PER_COLUMN := 10
const MAX_QUERIES := 4
const PROFILE_INTERVAL_MS := 250.0
const STREAK_LENGTH := 0.24
const FIELD_HEIGHT := 8.0
var rain: MultiMeshInstance3D
var _mesh: ArrayMesh
var _material: StandardMaterial3D
var _buffer := PackedFloat32Array()
var _world_ref: WeakRef
var _camera_ref: WeakRef
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _fixtures: Array[Dictionary] = []
var _columns: Dictionary = {}
var _column_order: Array[Vector2i] = []
var _cell := Vector2i(2147483647,2147483647)
var _revision: int = -1
var _revision_physics_frame: int = -1
var _last_profile_ms := -1.0
var _last_rain_ms := -1.0
var _last_camera := Transform3D.IDENTITY
var _profile: Dictionary = {}
var _last_input: Dictionary = {}
var _queries := 0
var _total_queries := 0
var _profile_writes := 0
var _sky_writes := 0
var _buffer_writes := 0
var _visible_count := 0
var _built := false

static func night_amount(t: float) -> float:
	if t < 0.2 or t >= 0.8: return 1.0
	if t < 0.3: return 1.0-(t-0.2)/0.1
	if t < 0.7: return 0.0
	return (t-0.7)/0.1

static func fog_opacity(t: float) -> float:
	return 0.72-night_amount(t)*0.18

static func source_rain_line(index: int,visual_ms: float) -> Dictionary:
	var tick: float = visual_ms/30.0
	var a := Vector2(fposmod(index*73.0+tick,800.0),fposmod(index*47.0+tick*1.4,600.0))
	return {"from":a,"to":a+Vector2(-3,10)}

func build(world: Node3D,camera: Camera3D) -> bool:
	if _built: return _world_ref.get_ref() == world and _camera_ref.get_ref() == camera
	if world == null or camera == null or not world.is_inside_tree() or not camera.is_inside_tree(): return false
	if not world.get("content") is Dictionary or world.get("content").is_empty() or not world.get("source_records") is Dictionary: return false
	if not world.get("environment") is Environment or not world.get("sky_material") is ProceduralSkyMaterial or not world.get("sun") is DirectionalLight3D: return false
	var found: Array[Dictionary] = []
	var streets: Array[OmniLight3D] = []
	for lamp: OmniLight3D in world.lamps:
		if not str(lamp.name).begins_with("source_light_"): streets.append(lamp)
	var lamp_sources: Array[Dictionary] = []
	for source: Dictionary in world.content.props:
		if source.type == "lamp": lamp_sources.append(source)
	if streets.size() != 11 or lamp_sources.size() != streets.size(): return false
	for index: int in range(streets.size()):
		found.append({"id":"streetlamp:"+str(index),"node":streets[index],"power":0.55,"kind":"streetlamp","office":false})
	for source: Dictionary in world.content.world.lights:
		var lamp: OmniLight3D = world.get_node_or_null("source_light_"+str(source.id)) as OmniLight3D
		if lamp == null: return false
		found.append({"id":str(source.id),"node":lamp,"power":float(source.power),"kind":"fixture","office":bool(source.get("office",false))})
	var barrel_index := 0
	for source: Dictionary in world.content.world.decor:
		if source.type != "burn_barrel": continue
		var at: Vector3 = Content.to_world(Vector2(source.x,source.y),1.2)
		var match_light: OmniLight3D
		for child: Node in world.get_children():
			if child is OmniLight3D and child.position.distance_to(at) < 0.001:
				match_light = child as OmniLight3D; break
		if match_light == null: return false
		found.append({"id":"burn_barrel:"+str(barrel_index),"node":match_light,"power":0.9,"kind":"barrel_fire","office":false})
		barrel_index += 1
	if found.size() != 39 or barrel_index != 4: return false
	_world_ref = weakref(world); _camera_ref = weakref(camera)
	_environment = world.environment; _sky = world.sky_material; _sun = world.sun; _fixtures = found
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color("99a69f")
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.disable_fog = false
	_material.roughness = 1.0
	_mesh = ArrayMesh.new()
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.006,0,0),Vector3(0.006,0,0),Vector3(-0.030,-STREAK_LENGTH,0),Vector3(-0.006,0,0),Vector3(-0.030,-STREAK_LENGTH,0),Vector3(-0.042,-STREAK_LENGTH,0)])
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_mesh.surface_set_material(0,_material)
	rain = MultiMeshInstance3D.new(); rain.name = "OriginalRain"
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var instances := MultiMesh.new(); instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = _mesh; instances.instance_count = INSTANCE_COUNT
	instances.custom_aabb = AABB(Vector3(-8,-FIELD_HEIGHT,-8),Vector3(16,FIELD_HEIGHT*2,16))
	rain.multimesh = instances; rain.visible = false; add_child(rain)
	_buffer.resize(INSTANCE_COUNT*12); _buffer.fill(0.0)
	instances.buffer = _buffer
	_built = true
	return true

func _valid(snapshot: Dictionary,visual_ms: float) -> bool:
	if not _built or _world_ref.get_ref() == null or _camera_ref.get_ref() == null or not is_finite(visual_ms) or visual_ms < 0: return false
	for key: String in ["dayTime","weather","office_generator","geometry_revision"]:
		if not snapshot.has(key): return false
	if not snapshot.dayTime is float and not snapshot.dayTime is int: return false
	if not is_finite(float(snapshot.dayTime)) or float(snapshot.dayTime) < 0 or float(snapshot.dayTime) > 1: return false
	if not snapshot.weather is String or snapshot.weather not in ["clear","rain","fog"] or not snapshot.office_generator is bool: return false
	if not snapshot.geometry_revision is int or int(snapshot.geometry_revision) < 0: return false
	return true

func sync(snapshot: Dictionary,visual_ms: float) -> bool:
	if not _valid(snapshot,visual_ms): return false
	_queries = 0
	var next: Dictionary = _make_profile(snapshot)
	var forced: bool = _last_input.is_empty() or snapshot.weather != _last_input.weather or snapshot.office_generator != _last_input.office_generator or absf(float(snapshot.dayTime)-float(_last_input.dayTime)) > 0.02 or visual_ms < _last_profile_ms
	if next != _profile and (forced or visual_ms-_last_profile_ms >= PROFILE_INTERVAL_MS):
		_apply_profile(next); _last_profile_ms = visual_ms
	_last_input = snapshot.duplicate(true)
	rain.visible = snapshot.weather == "rain"
	if not rain.visible: _visible_count = 0; return true
	var camera: Camera3D = _camera_ref.get_ref() as Camera3D
	var next_cell := Vector2i(floori(camera.global_position.x/COLUMN_SIZE),floori(camera.global_position.z/COLUMN_SIZE))
	var changed: bool = next_cell != _cell or int(snapshot.geometry_revision) != _revision
	if changed: _regrid(next_cell,int(snapshot.geometry_revision))
	for key: Vector2i in _column_order:
		# A collision writer can publish its revision before PhysicsServer has
		# synchronized that process-frame transform. Never certify the old pose
		# under the new revision. This is a validity fence, not a weather clock.
		if Engine.get_physics_frames() <= _revision_physics_frame: break
		if _queries >= MAX_QUERIES: break
		if bool(_columns[key].certified): continue
		_certify(key); _queries += 1; _total_queries += 1
	if changed or _queries > 0 or visual_ms != _last_rain_ms or camera.global_transform != _last_camera:
		_update_rain(camera,visual_ms); _last_rain_ms = visual_ms; _last_camera = camera.global_transform
	return true

func _make_profile(snapshot: Dictionary) -> Dictionary:
	var night: float = night_amount(float(snapshot.dayTime))
	var cloudy: float = 0.0 if snapshot.weather == "clear" else (0.55 if snapshot.weather == "rain" else 0.72)
	return {"night":night,"weather":snapshot.weather,"generator":snapshot.office_generator,"cloudy":cloudy,"fog_opacity":fog_opacity(float(snapshot.dayTime))}

func _apply_profile(next: Dictionary) -> void:
	var night: float = next.night; var daylight: float = 1.0-night; var cloud: float = next.cloudy
	_sun.light_energy = lerpf(0.144,0.90,daylight)*(1.0-cloud*0.22)
	_environment.ambient_light_energy = lerpf(0.2176,0.52,daylight)*(1.0-cloud*0.06)
	_environment.fog_enabled = true
	_environment.fog_density = 0.0028 if next.weather == "clear" else (0.0055 if next.weather == "rain" else 0.0028+0.026*float(next.fog_opacity))
	_environment.fog_sky_affect = 0.75 if next.weather == "fog" else 0.4
	for fixture: Dictionary in _fixtures:
		var level: float = maxf(0.30,night) if fixture.kind == "barrel_fire" else (night if night > 0.01 else 0.0)
		if fixture.office and not next.generator: level = 0.0
		(fixture.node as OmniLight3D).light_energy = float(fixture.power)*level
	# A generator purchase changes one real light, not the sky radiance cache.
	if _profile.is_empty() or next.night != _profile.night or next.weather != _profile.weather:
		_sky.sky_top_color = Color("293338").lerp(Color("667b83").lerp(Color("626b66"),cloud),daylight)
		_sky.sky_horizon_color = Color("3b4541").lerp(Color("b1aa94").lerp(Color("898b7c"),cloud),daylight)
		_sky.ground_bottom_color = Color("22271f").lerp(Color("3c3a30"),daylight)
		_sky.ground_horizon_color = Color("30382f").lerp(Color("8b8979"),daylight)
		_environment.background_energy_multiplier = lerpf(0.40,0.80,daylight)*(1.0-cloud*0.10)
		_environment.fog_light_color = Color("39423b").lerp(Color("94988a"),daylight)
		_sky_writes += 1
	_profile = next; _profile_writes += 1

func _regrid(next_cell: Vector2i,revision: int) -> void:
	var updated: Dictionary = {}; var order: Array[Vector2i] = []
	if revision != _revision: _revision_physics_frame = Engine.get_physics_frames()
	for z: int in range(-2,2):
		for x: int in range(-2,2):
			var key: Vector2i = next_cell+Vector2i(x,z)
			if revision == _revision and _columns.has(key): updated[key] = _columns[key]
			else:
				var jitter: float = 0.33+fposmod(key.x*73.0+key.y*47.0,101.0)/101.0*0.34
				updated[key] = {"point":Vector2((key.x+jitter)*COLUMN_SIZE,(key.y+1.0-jitter)*COLUMN_SIZE),"certified":false,"cover":0.0,"collider":""}
			order.append(key)
	_columns = updated; _column_order = order; _cell = next_cell; _revision = revision

func _certify(key: Vector2i) -> void:
	var column: Dictionary = _columns[key]; var point: Vector2 = column.point
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,64,point.y),Vector3(point.x,-2,point.y),1)
	var hit: Dictionary = (_world_ref.get_ref() as Node3D).get_world_3d().direct_space_state.intersect_ray(query)
	column.cover = float(hit.position.y) if not hit.is_empty() else -2.0
	column.collider = str(hit.collider.name) if not hit.is_empty() else ""
	column.certified = true

func _update_rain(camera: Camera3D,visual_ms: float) -> void:
	# One packed upload. Columns are world-anchored; only each strip's facing follows the eye.
	rain.global_position = camera.global_position
	var right: Vector3 = camera.global_basis.x; right.y = 0.0
	if right.length_squared() < 0.001: right = Vector3.RIGHT
	right = right.normalized()
	var normal: Vector3 = right.cross(Vector3.UP)
	var top: float = camera.global_position.y+6.0
	var tick: float = visual_ms/30.0; _visible_count = 0
	for column_index: int in range(COLUMN_COUNT):
		var column: Dictionary = _columns[_column_order[column_index]]
		var point: Vector2 = column.point
		for drop: int in range(DROPS_PER_COLUMN):
			var index: int = column_index*DROPS_PER_COLUMN+drop
			var y: float = top-fposmod(index*47.0+tick*1.4,600.0)/600.0*FIELD_HEIGHT
			var shown: bool = bool(column.certified) and y-STREAK_LENGTH > float(column.cover)+0.02
			var at: Vector3 = Vector3(point.x,y,point.y)-rain.global_position
			_write_transform(index,right,normal,at,shown)
			if shown: _visible_count += 1
	rain.multimesh.buffer = _buffer; _buffer_writes += 1

func _write_transform(index: int,right: Vector3,normal: Vector3,at: Vector3,shown: bool) -> void:
	var i: int = index*12; var scale_at: float = 1.0 if shown else 0.0
	_buffer[i] = right.x*scale_at; _buffer[i+1] = 0.0; _buffer[i+2] = normal.x*scale_at; _buffer[i+3] = at.x
	_buffer[i+4] = 0.0; _buffer[i+5] = scale_at; _buffer[i+6] = 0.0; _buffer[i+7] = at.y
	_buffer[i+8] = right.z*scale_at; _buffer[i+9] = 0.0; _buffer[i+10] = normal.z*scale_at; _buffer[i+11] = at.z

func clear() -> void:
	if rain != null: rain.visible = false
	_columns.clear(); _column_order.clear(); _revision = -1; _revision_physics_frame = -1; _cell = Vector2i(2147483647,2147483647)
	_profile.clear(); _last_input.clear(); _last_profile_ms = -1; _last_rain_ms = -1; _visible_count = 0; _queries = 0

func inspect() -> Dictionary:
	var columns: Array[Dictionary] = []
	for key: Vector2i in _column_order:
		var record: Dictionary = _columns[key].duplicate(true); record.key = key; columns.append(record)
	var fixtures: Array[Dictionary] = []
	for source: Dictionary in _fixtures:
		var light: OmniLight3D = source.node as OmniLight3D
		fixtures.append({"id":source.id,"power":source.power,"energy":light.light_energy,"kind":source.kind,"office":source.office,"resource":light.get_instance_id()})
	return {"built":_built,"instances":INSTANCE_COUNT if _built else 0,"triangles":320 if _built else 0,"surfaces":1 if _built else 0,"rain_visible":rain.visible if rain != null else false,"visible_instances":_visible_count,"profile":_profile.duplicate(true),"fixtures":fixtures,"columns":columns,"geometry_revision":_revision,"revision_physics_frame":_revision_physics_frame,"queries":_queries,"total_queries":_total_queries,"profile_writes":_profile_writes,"sky_writes":_sky_writes,"buffer_writes":_buffer_writes,"mesh_id":_mesh.get_instance_id() if _mesh != null else 0,"material_id":_material.get_instance_id() if _material != null else 0}
