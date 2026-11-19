extends "res://tests/office_acceptance_probe.gd"
## Draft test routing only. Never changes a service, source actor or player record.
var endpoint_service := ""
var endpoint_original := Vector3.INF
var endpoint_selected := Vector3.INF
var endpoint_window := -1000000
var endpoint_attempts := 0
var endpoint_history: Array[Dictionary] = []
var endpoint_context: Dictionary = {}

static func endpoint_range(center: Vector2,target: Vector2,reach_metres: float) -> bool:
	if not center.is_finite() or not target.is_finite() or not is_finite(reach_metres) or reach_metres <= 0: return false
	var square: float = center.distance_squared_to(target)
	return square < 58.0*58.0 and square < pow(reach_metres/0.04,2)

static func endpoint_candidates(source: Vector2,original: Vector3,from: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not source.is_finite() or not original.is_finite() or not from.is_finite(): return result
	result.append(original)
	var alternatives: Array[Dictionary] = []
	for radius: float in [24.0,36.0,48.0,56.0]:
		for index: int in range(8):
			var center: Vector2 = source+Vector2.from_angle(float(index)*TAU/8.0)*radius
			var point: Vector3 = Content.to_world(center,0.06)
			alternatives.append({"point":point,"distance":point.distance_squared_to(from),"order":alternatives.size()})
	alternatives.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.order < b.order if a.distance == b.distance else a.distance < b.distance)
	for entry: Dictionary in alternatives: result.append(entry.point)
	return result

func _endpoint_proof(id: String,point: Vector3) -> Dictionary:
	var service: Dictionary = game.world.service_points.get(id,{})
	var failed := {"ok":false,"point":point,"reason":"invalid_service"}
	if not (id.begins_with("route:") or id.begins_with("claim:")) or service.is_empty() or not point.is_finite(): return failed
	var source: Vector2 = service.source_point
	var center: Vector2 = Content.to_source(point)
	failed.source_center = center; failed.source_target = source
	if not endpoint_range(center,source,float(service.reach)): failed.reason = "source_or_physical_range"; return failed
	var body: Dictionary = _probe_body(point)
	var origin := Vector2(body.x,body.y)
	if not game.physics._clear(body,origin,false): failed.reason = "actual_capsule_overlap"; return failed
	var peers: Array[Dictionary] = game.physics._contact_peers(body)
	if not game.physics._peer_clear(body,origin,peers): failed.reason = "live_peer_overlap"; return failed
	if not game.world.is_clear_position(point,0.486): failed.reason = "conservative_static_endpoint"; return failed
	var eye: Vector3 = Content.to_world(center,game.physics.FEET+1.63)
	var hit: Dictionary = game.physics._ray(eye,service.target)
	var owner: String = str(service.structure_id)
	var collider: Object = hit.get("collider")
	if not hit.is_empty() and not (not owner.is_empty() and collider is CollisionObject3D and str(collider.get_meta("source_owner","")) == owner):
		failed.reason = "actual_target_occluded"
		failed.hit_owner = str(collider.get_meta("source_owner","")) if is_instance_valid(collider) else ""
		return failed
	if not service_aim_wait.is_empty() and service_aim_wait.id == id and is_same(service_aim_wait.player_epoch,game.runtime.p) and is_same(service_aim_wait.state_epoch,game.runtime.s) and int(service_aim_wait.revision) == game.physics._collision_revision and game.player.position.distance_to(service_aim_wait.position) < 0.25 and _service_target(id).distance_to(service_aim_wait.focus) < 0.25 and point.distance_to(service_aim_wait.position) < 0.25:
		failed.reason = "unchanged_failed_aim_endpoint"; return failed
	return {"ok":true,"point":point,"source_center":center,"source_target":source,"reason":"current_endpoint_clear"}

func _endpoint_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	return super._resident_route(from,to)

func _resident_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	if endpoint_service.is_empty() or to != endpoint_original: return super._resident_route(from,to)
	var now: int = _walk_clock()
	if now-endpoint_window >= 750: endpoint_window = now; endpoint_attempts = 0
	endpoint_context = {"id":endpoint_service,"original":endpoint_original,"from":from,"reason":"no_certified_service_route","proofs":[],"attempts_in_window":endpoint_attempts}
	var service: Dictionary = game.world.service_points[endpoint_service]
	for point: Vector3 in endpoint_candidates(service.source_point,endpoint_original,from):
		if endpoint_attempts >= 4: endpoint_context.reason = "four_route_window_exhausted"; break
		var proof: Dictionary = _endpoint_proof(endpoint_service,point)
		endpoint_context.proofs.append(proof)
		if not proof.ok: continue
		endpoint_attempts += 1; endpoint_context.attempts_in_window = endpoint_attempts
		var path: PackedVector3Array = _endpoint_route(from,point)
		if path.size() < 2: continue
		endpoint_selected = point
		endpoint_context.merge({"reason":"certified_service_route","selected":point,"route_points":path.size()},true)
		if endpoint_history.size() < 256: endpoint_history.append(endpoint_context.duplicate(true))
		else: _check(false,"bounded endpoint evidence history")
		return path
	endpoint_selected = Vector3.INF
	if endpoint_history.size() < 256: endpoint_history.append(endpoint_context.duplicate(true))
	else: _check(false,"bounded endpoint evidence history")
	resident_route_context = endpoint_context.duplicate(true)
	return PackedVector3Array()

func _combat_segment(from: Vector3,to: Vector3) -> Dictionary:
	if not endpoint_service.is_empty() and endpoint_selected.is_finite():
		var proof: Dictionary = _endpoint_proof(endpoint_service,endpoint_selected)
		if not proof.ok: return {"ok":false,"reason":"cached_service_endpoint_invalid","endpoint":proof}
	return super._combat_segment(from,to)

func _defend_exit() -> bool:
	var id: String = endpoint_service
	endpoint_service = ""
	var result: bool = await super._defend_exit()
	endpoint_service = id
	return result

func _visit(id: String,inter_stop: bool = false) -> bool:
	endpoint_service = id if id.begins_with("route:") or id.begins_with("claim:") else ""
	endpoint_original = game.world.service_points[id].approach
	endpoint_selected = Vector3.INF; endpoint_window = -1000000; endpoint_attempts = 0
	var result: bool = await super._visit(id,inter_stop)
	endpoint_service = ""; endpoint_selected = Vector3.INF
	return result
