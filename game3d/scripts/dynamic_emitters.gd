class_name RockBottomDynamicEmitters
extends Node3D
## Six pooled lights with visible fixtures; source records and caller wall time only.
const Weather = preload("res://scripts/weather_presentation.gd")
const Surfaces = preload("res://scripts/surface_kit.gd")
const COP_COLOR := Color("4868d0")
const FIRE_COLOR := Color("d06030")
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
var _slots: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _left: Array[MeshInstance3D] = []
var _right: Array[MeshInstance3D] = []
var _blue: StandardMaterial3D
var _rust: StandardMaterial3D
var _player: OmniLight3D
var _phase: int = -1
var _night: float = -1.0
var _cop_count: int = 0
var _player_active: bool = false
# Output state only: every snapshot is still validated afresh before these are used.
# -1 forces the first clear to hide the engine's default-visible light/fixture nodes.
var _applied_mask: int = -1
var _cop_energy: float = -1.0
var _player_energy: float = -1.0
var _emission_energy: float = -1.0

static func create() -> RockBottomDynamicEmitters:
	var result := RockBottomDynamicEmitters.new(); result.name = "DynamicEmitters"
	result._blue = _paint("4868d0").duplicate() as StandardMaterial3D
	result._rust = _paint("8a3a3a").duplicate() as StandardMaterial3D
	for material: StandardMaterial3D in [result._blue,result._rust]:
		material.emission_enabled = true; material.emission = material.albedo_color
	for index: int in range(5):
		var slot := Node3D.new(); slot.name = "Cop"+str(index); result.add_child(slot); result._slots.append(slot)
		var fixture := Node3D.new(); fixture.name = "Fixture"; fixture.position.y = 0.24; slot.add_child(fixture)
		_box(fixture,"Base",Vector3(0,0.007,0),Vector3(0.174,0.014,0.057),_paint("393c34"))
		result._left.append(_box(fixture,"LeftLens",Vector3(-0.046,0.031,0),Vector3(0.064,0.034,0.042),result._rust))
		result._right.append(_box(fixture,"RightLens",Vector3(0.046,0.031,0),Vector3(0.064,0.034,0.042),result._blue))
		var light := OmniLight3D.new(); light.name = "Light"; light.position.y = 0.271
		light.light_color = COP_COLOR; light.omni_range = 4.16; light.shadow_enabled = false
		slot.add_child(light); result._lights.append(light)
	result._player = OmniLight3D.new(); result._player.name = "PlayerLight"
	result._player.light_color = FIRE_COLOR; result._player.omni_range = 1.92; result._player.shadow_enabled = false
	result.add_child(result._player); result.clear()
	return result

static func qualifies_cop(record: Dictionary) -> bool:
	return not record.get("dead",false) and not record.get("hidden",false) and (record.get("isCop",false) or record.get("sprite","") in ["cop","horsecop"])

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _transform(value: Variant) -> bool:
	return value is Transform3D and value.is_finite() and absf(value.basis.determinant()) > 0.000001

func _valid(snapshot: Dictionary,visual_ms: float) -> bool:
	if not is_finite(visual_ms) or visual_ms < 0 or not _number(snapshot.get("dayTime")) or snapshot.dayTime < 0 or snapshot.dayTime > 1: return false
	if not snapshot.get("cops") is Array or snapshot.cops.size() > 5 or not snapshot.get("player") is Dictionary: return false
	var ids: Dictionary = {}
	for row: Variant in snapshot.cops:
		if not row is Dictionary or not row.get("id") is String or row.id.is_empty() or ids.has(row.id): return false
		ids[row.id] = true
		if not row.get("sprite","") is String: return false
		for key: String in ["isCop","dead","hidden","visible"]:
			if not row.get(key,false) is bool: return false
		if qualifies_cop(row) and row.get("visible",false) and not _transform(row.get("cap_transform")): return false
	var player: Dictionary = snapshot.player
	if not _number(player.get("rockedT")) or not player.get("hitterHigh") is bool or not player.get("visible") is bool: return false
	if (player.rockedT > 0 or player.hitterHigh) and player.visible and not _transform(player.get("ember_transform")): return false
	return true

func sync(snapshot: Dictionary,visual_ms: float) -> bool:
	if not _valid(snapshot,visual_ms): clear(); return false
	var night: float = Weather.night_amount(float(snapshot.dayTime))
	var level: float = maxf(0.34,night)
	var emission_energy: float = 0.58+level*0.34
	if _emission_energy != emission_energy:
		_blue.emission_energy_multiplier = emission_energy
		_rust.emission_energy_multiplier = emission_energy
		_emission_energy = emission_energy
	_night = night
	var phase: int = int(floor(fposmod(visual_ms,300.0)/150.0))
	if phase != _phase:
		for index: int in range(5):
			_left[index].material_override = _blue if phase == 1 else _rust
			_right[index].material_override = _rust if phase == 1 else _blue
		_phase = phase
	_cop_count = 0
	var next_mask: int = 0
	var cop_energy: float = 0.62*level
	var cop_energy_changed: bool = _cop_energy != cop_energy
	for index: int in range(5):
		var slot: Node3D = _slots[index]; var light: OmniLight3D = _lights[index]
		var row: Dictionary = snapshot.cops[index] if index < snapshot.cops.size() else {}
		var active: bool = not row.is_empty() and qualifies_cop(row) and row.get("visible",false)
		var bit: int = 1 << index
		var activity_changed: bool = ((_applied_mask & bit) != 0) != active
		if activity_changed:
			slot.visible = active; light.visible = active
		if active:
			if slot.global_transform != row.cap_transform: slot.global_transform = row.cap_transform
			if activity_changed or cop_energy_changed: light.light_energy = cop_energy
			next_mask |= bit; _cop_count += 1
		elif activity_changed: light.light_energy = 0.0
	_cop_energy = cop_energy
	var player: Dictionary = snapshot.player
	_player_active = (player.rockedT > 0 or player.hitterHigh) and player.visible
	if ((_applied_mask & 32) != 0) != _player_active: _player.visible = _player_active
	var player_energy: float = 0.0
	if _player_active:
		var at: Vector3 = (player.ember_transform as Transform3D).origin
		if _player.global_position != at: _player.global_position = at
		player_energy = 0.62*maxf(0.36,night); next_mask |= 32
	if _player_energy != player_energy:
		_player.light_energy = player_energy; _player_energy = player_energy
	_applied_mask = next_mask
	return true

func clear() -> void:
	for index: int in range(_slots.size()):
		if (_applied_mask & (1 << index)) != 0:
			_slots[index].visible = false; _lights[index].visible = false; _lights[index].light_energy = 0.0
	if _player != null and (_applied_mask & 32) != 0:
		_player.visible = false; _player.light_energy = 0.0
	_applied_mask = 0; _cop_energy = 0.0; _player_energy = 0.0
	_cop_count = 0; _player_active = false; _phase = -1; _night = -1.0

func inspect() -> Dictionary:
	return {"cop_count":_cop_count,"player_active":_player_active,"active_lights":_cop_count+(1 if _player_active else 0),"allocated_lights":_lights.size()+(1 if _player != null else 0),"phase":_phase,"night":_night,"queries":0,"dynamic_shadows":0}

static func _paint(color: String) -> StandardMaterial3D:
	if not _materials.has(color):
		var material: StandardMaterial3D = Surfaces.material("plain",color,0.88)
		if material.uv1_world_triplanar:
			material = material.duplicate() as StandardMaterial3D; material.uv1_world_triplanar = false
		_materials[color] = material
	return _materials[color]

static func _box(parent: Node3D,label: String,at: Vector3,size: Vector3,material: StandardMaterial3D) -> MeshInstance3D:
	var key: String = str(size)
	if not _meshes.has(key):
		var mesh := BoxMesh.new(); mesh.size = size; _meshes[key] = mesh
	var part := MeshInstance3D.new(); part.name = label; part.mesh = _meshes[key]; part.material_override = material
	part.position = at; part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(part)
	return part
