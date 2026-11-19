extends RefCounted
## Source cadence, private presentation clocks. No model, Node, save or global RNG.
const Feedback = preload("world_feedback.gd")
const Content = preload("content_catalog.gd")
const MODULUS := 2147483647
const MULTIPLIER := 48271
const METRES_PER_PIXEL := 0.04
var _seed: int
var _rng: int
var _epoch: int = 0
var _walk_ms: float = 0.0
var _ambient_ms: float = 0.0
var _draws: int = 0
var _walk_births: int = 0
var _ambient_births: int = 0

func _init(cosmetic_seed: int = 1) -> void:
	_seed = posmod(cosmetic_seed,MODULUS-1)+1; _rng = _seed

func reset_epoch(epoch: int) -> bool:
	if epoch <= 0: return false
	_epoch = epoch; _rng = _seed; _walk_ms = 0.0; _ambient_ms = 0.0
	_draws = 0; _walk_births = 0; _ambient_births = 0
	return true

func _random() -> float:
	_rng = (_rng*MULTIPLIER)%MODULUS; _draws += 1
	return float(_rng)/MODULUS

func _step(step_ms: Variant,epoch: Variant) -> bool:
	return _epoch > 0 and epoch is int and epoch == _epoch and Feedback._number(step_ms) and step_ms > 0 and step_ms <= Feedback.MAX_STEP_MS

static func valid_camera(camera: Variant,vertical_fov: Variant,aspect: Variant) -> bool:
	if not camera is Transform3D or not camera.is_finite() or not Feedback._world(camera.origin): return false
	if not Feedback._number(vertical_fov) or vertical_fov <= 1 or vertical_fov >= 179 or not Feedback._number(aspect) or aspect < 0.1 or aspect > 10: return false
	var basis: Basis = camera.basis
	for axis: Vector3 in [basis.x,basis.y,basis.z]:
		if not is_finite(axis.length_squared()) or absf(axis.length_squared()-1.0) > 0.0001: return false
	if absf(basis.x.dot(basis.y)) > 0.0001 or absf(basis.x.dot(basis.z)) > 0.0001 or absf(basis.y.dot(basis.z)) > 0.0001 or absf(basis.determinant()-1.0) > 0.0001: return false
	return Feedback._right(Vector3(basis.x.x,0,basis.x.z))

static func _depth(ordinal: int) -> float:
	var value: int = posmod(ordinal,MODULUS-1)+1
	for _round: int in range(3): value = (value*MULTIPLIER)%MODULUS
	return 2.0+6.0*float(value)/MODULUS

func walk(step_ms: Variant,epoch: Variant,source_rect: Variant,intent: Variant,birth_right: Variant) -> Dictionary:
	if not _step(step_ms,epoch) or not source_rect is Rect2 or not intent is Vector2: return {}
	if not Feedback._point(source_rect.position) or not Feedback._point(source_rect.end) or source_rect.size.x <= 0 or source_rect.size.y <= 0 or source_rect.size.x > 100000 or source_rect.size.y > 100000: return {}
	if not intent.is_finite() or absf(intent.x) > 1.0 or absf(intent.y) > 1.0 or not is_finite(intent.length_squared()) or intent.length_squared() > 1.00001 or not Feedback._right(birth_right): return {}
	var point := Vector2(source_rect.position.x+source_rect.size.x*0.5,source_rect.end.y-2.0)
	var anchor: Vector3 = Content.to_world(point,0.08)
	if not Feedback._point(point) or not Feedback._world(anchor): return {}
	if intent == Vector2.ZERO: return {} # Source carries partial walking clock through idle.
	_walk_ms += float(step_ms)
	if _walk_ms <= 110.0: return {}
	_walk_ms = 0.0
	var samples: Array[float] = []
	for _draw: int in range(5): samples.append(_random())
	_walk_births += 1
	return {"epoch":_epoch,"recipe":"walking_dust","source_point":point,"world_anchor":anchor,"birth_right":Vector3(birth_right.x,0,birth_right.z).normalized(),"intent_x":float(intent.x),"samples":samples}

func ambient(step_ms: Variant,epoch: Variant,weather: Variant,camera: Variant,vertical_fov: Variant,aspect: Variant) -> Dictionary:
	if not _step(step_ms,epoch) or not weather is String or not valid_camera(camera,vertical_fov,aspect): return {}
	# Preflight the entire possible perspective volume before private clocks/RNG.
	var half_height: float = 8.0*tan(deg_to_rad(float(vertical_fov))*0.5)
	var maximum_radius: float = 8.0+half_height*(1.014+float(aspect))
	for axis: int in range(3):
		if absf(camera.origin[axis])+maximum_radius > 1e6: return {}
	var source_center := Vector2(camera.origin.x,camera.origin.z)/METRES_PER_PIXEL
	if absf(source_center.x)+400.0 > 1e7 or absf(source_center.y)+304.0 > 1e7: return {}
	_ambient_ms -= float(step_ms)
	if _ambient_ms > 0.0: return {}
	var samples: Array[float] = []
	for _draw: int in range(7): samples.append(_random())
	_ambient_ms = 280.0+samples[0]*350.0; _ambient_births += 1
	var depth: float = _depth(_ambient_births)
	var half_y: float = depth*tan(deg_to_rad(float(vertical_fov))*0.5)
	var local := Vector3((samples[1]*2.0-1.0)*half_y*float(aspect),(1.0-samples[2]*2.0+8.0/600.0)*half_y,-depth)
	var anchor: Vector3 = camera*local
	var point := source_center+Vector2(-400.0+samples[1]*800.0,-304.0+samples[2]*600.0)
	var right := Vector3(camera.basis.x.x,0,camera.basis.x.z).normalized()
	return {"epoch":_epoch,"recipe":"ambient_mote","source_point":point,"world_anchor":anchor,"birth_right":right,"rain":weather == "rain","samples":samples}

func inspect() -> Dictionary:
	return {"epoch":_epoch,"walk_ms":_walk_ms,"ambient_ms":_ambient_ms,"rng_state":_rng,"rng_draws":_draws,"walk_births":_walk_births,"ambient_births":_ambient_births}
