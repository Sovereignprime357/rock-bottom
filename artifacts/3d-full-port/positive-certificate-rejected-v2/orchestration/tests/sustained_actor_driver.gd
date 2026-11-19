extends RefCounted
## Test-only input policy. No source state, actors, clocks or RNG are written.
const DECISION_MS := 200
const CANDIDATE_COUNT := 16
const LOOKAHEAD_PX := 70.0
const STALL_MS := 20000
const MAX_ROSTER := 256
const SHORT_STEP_PX := 1.0
var spatial: RefCounted
var host: RefCounted
var route := PackedVector2Array()
var cursor := 1
var laps := 0
var _p: Dictionary
var _s: Dictionary
var _last_now := -1
var _last_decision := -1000000
var _progress_at := -1
var _progress_point := Vector2.ZERO
var _endpoint := Vector2.ZERO
var _has_endpoint := false
var _revision := -1
var _previous_direction := Vector2.ZERO
var _fatal := ""
var _attempt_since := -1
var _avoided_direction := Vector2.ZERO
var _avoid_until := -1
var decisions := 0
var candidate_sweeps := 0
var retained_sweeps := 0
var short_sweeps := 0
var last_decision: Dictionary = {}
var last_threats: Array[Dictionary] = []

func _init(adapter: RefCounted,owner: RefCounted,points: PackedVector2Array) -> void:
	spatial = adapter; host = owner; route = points.duplicate()
	_p = owner.p; _s = owner.s
	if points.size() < 2: _fatal = "invalid_source_route"
	for point: Vector2 in points:
		if not point.is_finite(): _fatal = "invalid_source_route"

static func sample_displacement(before: Vector2,after: Vector2,lifecycle: Array) -> Dictionary:
	if not before.is_finite() or not after.is_finite(): return {"ok":false,"walked_m":0.0,"excluded_m":0.0}
	for reason: Variant in lifecycle:
		if reason not in ["arrest","death","placement_reset","source_epoch"]: return {"ok":false,"walked_m":0.0,"excluded_m":0.0}
	var distance: float = before.distance_to(after)*0.04
	return {"ok":true,"walked_m":distance if lifecycle.is_empty() else 0.0,"excluded_m":distance if not lifecycle.is_empty() else 0.0,"reasons":lifecycle.duplicate(true)}

static func encode_motion(desired: Vector2) -> Vector2:
	if not desired.is_finite() or desired.length_squared() < 0.000001: return Vector2.ZERO
	return desired.normalized()*(0.5+0.5*minf(desired.length(),1.0))

func _bound() -> bool: return is_same(_p,host.p) and is_same(_s,host.s)

static func score_edge(origin: Vector2,endpoint: Vector2,goal: Vector2,previous: Vector2,threats: Array[Dictionary]) -> float:
	var direction: Vector2 = (endpoint-origin).normalized()
	var progress: float = origin.distance_to(goal)-endpoint.distance_to(goal)
	var score: float = progress*0.4+direction.dot(previous)*6.0
	var current_gap := 1000000.0; var end_gap := 1000000.0; var segment_gap := 1000000.0
	for threat: Dictionary in threats:
		var point: Vector2 = threat.center
		var radius: float = float(threat.radius)
		current_gap = minf(current_gap,origin.distance_to(point)-radius)
		end_gap = minf(end_gap,endpoint.distance_to(point)-radius)
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point,origin,endpoint)
		segment_gap = minf(segment_gap,closest.distance_to(point)-radius)
	if not threats.is_empty():
		var urgency: float = clampf((200.0-current_gap)/100.0,0.0,2.0)
		score += (end_gap-current_gap)*urgency*2.5
		if segment_gap < 8.0: score -= (8.0-segment_gap)*20.0
	return score

static func heading_endpoints(origin: Vector2,goal: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not origin.is_finite() or not goal.is_finite(): return result
	var toward: Vector2 = goal-origin
	if toward.length_squared() < 0.000001: return result
	var base: float = toward.angle()
	var offsets := [0,1,-1,2,-2,3,-3,4,-4,5,-5,6,-6,7,-7,8]
	for index: int in offsets:
		var radius: float = minf(LOOKAHEAD_PX,toward.length()) if index == 0 else LOOKAHEAD_PX
		result.append(origin+Vector2.from_angle(base+float(index)*TAU/16.0)*radius)
	return result

func invalidate_lifecycle(kind: String) -> void:
	if _fatal.is_empty(): _fatal = "source_lifecycle:"+kind
	_has_endpoint = false

func _held(reason: String,fatal: bool = false,decision: bool = false) -> Dictionary:
	return {"ok":not fatal,"reason":reason,"direction":Vector2.ZERO,"sprint":false,"decision":decision,"edge":{},"cursor":cursor,"laps":laps}

func _valid_player() -> bool:
	for key: String in ["x","y","w","h"]:
		if not (host.p.get(key) is int or host.p.get(key) is float) or not is_finite(float(host.p[key])): return false
	return float(host.p.w) > 0 and float(host.p.h) > 0

func _threats(origin: Vector2) -> Array[Dictionary]:
	var source: Dictionary = {}
	for actor: Dictionary in host.npcs: source[str(actor.id)] = actor
	var result: Array[Dictionary] = []
	for peer: Dictionary in spatial._contact_peers(host.p):
		var id: String = str(peer.id); var actor: Dictionary = source.get(id,{})
		if actor.is_empty() or actor.get("dead",false) or actor.get("departed",false): continue
		if not (actor.get("isCop",false) or actor.get("aggro",false) or actor.get("hostile",false)): continue
		var center := Vector2(float(peer.x)+float(peer.w)*0.5,float(peer.y)+float(peer.h)*0.5)
		if not center.is_finite() or center.distance_to(origin) > 360.0: continue
		result.append({"id":id,"center":center,"size":Vector2(peer.w,peer.h),"radius":maxf(float(peer.w),float(peer.h))*0.5+maxf(float(host.p.w),float(host.p.h))*0.5,"distance":origin.distance_to(center),"is_cop":actor.get("isCop",false),"brendan":actor.get("isBrendan",false),"aggro":actor.get("aggro",false),"hostile":actor.get("hostile",false),"charge":actor.get("chargeState","")})
	return result

func _edge(origin: Vector2,endpoint: Vector2,short_step: bool = false) -> Dictionary:
	var half := Vector2(host.p.w,host.p.h)*0.5
	var from := Vector2(host.p.x,host.p.y)
	var goal: Vector2 = from+(endpoint-origin).limit_length(SHORT_STEP_PX) if short_step else endpoint-half
	# Preserve source scalar origin exactly; do not reconstruct it from a world pose.
	var body := {"id":"player","x":host.p.x,"y":host.p.y,"w":host.p.w,"h":host.p.h}
	var moved: Dictionary = spatial.move_body(body,goal)
	if not _bound(): _fatal = "unexpected_source_epoch"; return {"ok":false,"reason":_fatal}
	var actual: Variant = moved.get("position")
	var reason := ""
	if moved.get("blocked",true): reason = "static_sweep_blocked"
	elif moved.get("body_contact",false): reason = "live_peer_contact"
	elif not actual is Vector2 or not actual.is_finite() or actual.distance_to(goal) >= 0.005: reason = "sweep_endpoint_not_reached"
	return {"ok":reason.is_empty(),"reason":reason,"from":origin,"to":endpoint,"query_goal":goal,"short_step":short_step,"actual_origin":actual}

func step(now_ms: int) -> Dictionary:
	if not _fatal.is_empty(): return _held(_fatal,true)
	if now_ms < 0 or now_ms < _last_now: _fatal = "invalid_driver_clock"; return _held(_fatal,true)
	_last_now = now_ms
	if not _bound(): _fatal = "unexpected_source_epoch"; return _held(_fatal,true)
	if not _valid_player() or host.npcs.size() > MAX_ROSTER: _fatal = "invalid_live_population"; return _held(_fatal,true)
	var origin: Vector2 = host.player_center()
	if not origin.is_finite(): _fatal = "invalid_live_population"; return _held(_fatal,true)
	if _progress_at < 0: _progress_at = now_ms; _progress_point = origin
	elif origin.distance_to(_progress_point) > 0.625: _progress_at = now_ms; _progress_point = origin
	if now_ms-_progress_at > STALL_MS: _fatal = "no_actual_progress20s"; return _held(_fatal,true)
	if host.s.mode != "playing": return _held("source_mode:"+str(host.s.mode))
	if float(host.p.get("stunT",0)) > 0.0: _has_endpoint = false; return _held("source_stun")
	if int(spatial._collision_revision) != _revision:
		_revision = int(spatial._collision_revision); _has_endpoint = false
	if _attempt_since >= 0 and now_ms-_attempt_since >= 500 and now_ms-_progress_at >= 500:
		_avoided_direction = _previous_direction; _avoid_until = now_ms+1000
		_has_endpoint = false; _attempt_since = -1
	if origin.distance_to(route[cursor]) < 2.5:
		cursor += 1
		if cursor >= route.size(): cursor = 1; laps += 1
		_has_endpoint = false
	var planned := false
	if now_ms-_last_decision >= DECISION_MS:
		_last_decision = now_ms; decisions += 1; planned = true
		last_threats = _threats(origin)
		if not _bound(): _fatal = "unexpected_source_epoch"; return _held(_fatal,true)
		var candidates: Array[Dictionary] = []
		var best: float = -INF; _has_endpoint = false
		for endpoint: Vector2 in heading_endpoints(origin,route[cursor]):
			if now_ms < _avoid_until and (endpoint-origin).normalized().dot(_avoided_direction) > 0.9:
				candidates.append({"edge":{"ok":false,"reason":"observed_stagnant_heading","to":endpoint},"score":null}); continue
			candidate_sweeps += 1
			var edge: Dictionary = _edge(origin,endpoint)
			if not _fatal.is_empty(): return _held(_fatal,true)
			if edge.ok:
				short_sweeps += 1
				var short_edge: Dictionary = _edge(origin,endpoint,true)
				if not _fatal.is_empty(): return _held(_fatal,true)
				if not short_edge.ok: edge = short_edge
			var score: float = score_edge(origin,endpoint,route[cursor],_previous_direction,last_threats) if edge.ok else -INF
			candidates.append({"edge":edge,"score":score if is_finite(score) else null})
			if edge.ok and score > best:
				best = score; _endpoint = endpoint; _has_endpoint = true
		last_decision = {"at_ms":now_ms,"origin":origin,"goal":route[cursor],"cursor":cursor,"threats":last_threats.duplicate(true),"candidates":candidates,"selected":_endpoint if _has_endpoint else null,"reason":"certified_edge" if _has_endpoint else "no_certified_heading","revision":_revision,"decision":decisions}
	if not _has_endpoint: return _held("waiting_for_certified_heading",false,planned)
	retained_sweeps += 1
	var certificate: Dictionary = _edge(origin,_endpoint)
	if not _fatal.is_empty(): return _held(_fatal,true)
	if certificate.ok:
		short_sweeps += 1
		var short_certificate: Dictionary = _edge(origin,_endpoint,true)
		if not _fatal.is_empty(): return _held(_fatal,true)
		if not short_certificate.ok: certificate = short_certificate
	if not certificate.ok:
		_has_endpoint = false
		var held: Dictionary = _held("cached_edge_blocked",false,planned); held.edge = certificate
		return held
	var to: Vector2 = _endpoint-origin
	if to.length_squared() < 0.000001: _has_endpoint = false; return _held("certified_endpoint_reached",false,planned)
	var nearest := 1000000.0; var after := 1000000.0
	for threat: Dictionary in _threats(origin):
		nearest = minf(nearest,origin.distance_to(threat.center))
		after = minf(after,_endpoint.distance_to(threat.center))
	if not _bound(): _fatal = "unexpected_source_epoch"; return _held(_fatal,true)
	var sprint: bool = nearest < 180.0 and (after > nearest+2.0 or nearest < 75.0)
	_previous_direction = to.normalized()
	if _attempt_since < 0: _attempt_since = now_ms
	return {"ok":true,"reason":"evading" if sprint else "walking","direction":to.normalized()*minf(1.0,to.length()/10.0),"sprint":sprint,"decision":planned,"edge":certificate,"cursor":cursor,"laps":laps,"nearest_threat_px":nearest if nearest < 1000000 else null}
