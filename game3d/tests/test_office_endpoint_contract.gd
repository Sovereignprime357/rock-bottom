extends "office_endpoint_driver.gd"
const Draft = preload("office_endpoint_driver.gd")
const Base = preload("res://tests/office_acceptance_probe.gd")
var checks := 0
var now := 1000
var route_calls := 0
var routes_ready := true
var watching_defense := false
var defense_suspended := false

class FakeState:
	extends RefCounted
	var npcs: Array[Dictionary] = []
class FakeRuntime:
	extends RefCounted
	var p := {"x":100.0,"y":100.0,"w":24.0,"h":28.0}
	var s := {"mode":"playing"}
	var state := FakeState.new()
class FakeWorld:
	extends Node3D
	var clear := true
	var service_points := {"route:alley_can":{"source_point":Vector2(300,1560),"target":Content.to_world(Vector2(300,1560),1.25),"approach":Content.to_world(Vector2(300,1573),0.06),"reach":2.30,"structure_id":"","kind":"route"}}
	func is_clear_position(_point: Vector3,_radius: float = 0.48) -> bool: return clear
class FakePhysics:
	extends RefCounted
	const FEET := 0.06
	var _collision_revision := 49
	var all_blocked := false
	var peer_clear := true
	var ray: Dictionary = {}
	func _clear(body: Dictionary,at: Vector2,_cached: bool = true) -> bool:
		return not all_blocked and (at+Vector2(body.w,body.h)*0.5).distance_to(Vector2(300,1560)) >= 20.0
	func _contact_peers(_body: Dictionary) -> Array[Dictionary]: return []
	func _peer_clear(_body: Dictionary,_point: Vector2,_peers: Array[Dictionary]) -> bool: return peer_clear
	func _ray(_from: Vector3,_to: Vector3) -> Dictionary: return ray

func _check(ok: bool,label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok
func _walk_clock() -> int: return now
func _endpoint_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	route_calls += 1
	return PackedVector3Array([from,to]) if routes_ready else PackedVector3Array()
func _release() -> void:
	if watching_defense: defense_suspended = endpoint_service.is_empty()

func _run() -> void:
	game = Base.ObservedScene.new(); game.runtime = FakeRuntime.new()
	game.world = FakeWorld.new(); game.physics = FakePhysics.new(); game.player = Node3D.new()
	game.add_child(game.world); game.add_child(game.player)
	var id := "route:alley_can"
	var source: Vector2 = game.world.service_points[id].source_point
	var original: Vector3 = game.world.service_points[id].approach
	var start: Vector3 = Content.to_world(Vector2(1778.57788085938,1136.09252929688),0.06)
	game.player.position = start
	var authoritative := [game.runtime.p.duplicate(true),game.runtime.s.duplicate(true),game.world.service_points.duplicate(true),game.player.position]
	for pair: Array in [[57.499,true],[57.5,false],[57.999,false],[58.0,false]]:
		_check(Draft.endpoint_range(Vector2(float(pair[0]),0),Vector2.ZERO,2.30) == pair[1],"strict physical57.5px at "+str(pair[0]))
	_check(Draft.endpoint_range(Vector2(57.999,0),Vector2.ZERO,2.32) and not Draft.endpoint_range(Vector2(58,0),Vector2.ZERO,2.32),"strict source58px remains independent of physical service")
	_check(not Draft.endpoint_range(Vector2.INF,Vector2.ZERO,2.3) and not Draft.endpoint_range(Vector2.ZERO,Vector2.ZERO,NAN),"invalid endpoints cannot gain permission")
	var candidates: Array[Vector3] = Draft.endpoint_candidates(source,original,start)
	_check(candidates.size() == 33 and candidates[0] == original,"original guide plus exactly32 finite alternatives")
	var previous := -1.0
	for index: int in range(1,candidates.size()):
		var point: Vector3 = candidates[index]
		var center: Vector2 = Content.to_source(point)
		_check(Draft.endpoint_range(center,source,2.3),"generated candidate stays inside both strict ranges")
		_check(point.distance_squared_to(start) >= previous,"alternative endpoints are considered nearest current position first")
		previous = point.distance_squared_to(start)
	_check(_endpoint_proof(id,original).reason == "actual_capsule_overlap","stale guidance endpoint is refused by actual query dependency")
	var legal: Vector3 = candidates[1]
	_check(_endpoint_proof(id,legal).ok,"clear alternative can be considered without relocating source target")
	game.physics.peer_clear = false
	_check(_endpoint_proof(id,legal).reason == "live_peer_overlap","live neutral or hostile body invalidates an endpoint")
	game.physics.peer_clear = true; game.world.clear = false
	_check(_endpoint_proof(id,legal).reason == "conservative_static_endpoint","static navigation clearance is preserved")
	game.world.clear = true
	var wall := StaticBody3D.new(); wall.set_meta("source_owner","unrelated_wall")
	game.physics.ray = {"collider":wall}
	_check(_endpoint_proof(id,legal).reason == "actual_target_occluded","unrelated wall cannot be bypassed by endpoint search")
	game.world.service_points[id].structure_id = "allowed_marker"
	wall.set_meta("source_owner","allowed_marker")
	_check(_endpoint_proof(id,legal).ok,"same-owner visible marker keeps existing ray semantics")
	game.world.service_points[id].structure_id = ""; game.physics.ray = {}; wall.free()
	endpoint_service = id; endpoint_original = original
	var path: PackedVector3Array = _resident_route(start,original)
	_check(path.size() == 2 and path[-1] == legal and endpoint_selected == legal and route_calls == 1,"first legal alternative joins the current controller route")
	for attempt: int in range(3): _resident_route(start,original)
	_check(_resident_route(start,original).is_empty() and route_calls == 4,"nested local joins cannot exceed four route attempts in750ms")
	now += 749
	_check(_resident_route(start,original).is_empty() and route_calls == 4,"749ms cannot renew endpoint route work")
	now += 1; routes_ready = false
	_check(_resident_route(start,original).is_empty() and route_calls == 8 and endpoint_context.proofs.size() <= 33,"at750ms at most four new failed routes and33 endpoint proofs are allowed")
	game.physics.all_blocked = true; now += 750
	_check(_resident_route(start,original).is_empty() and route_calls == 8 and endpoint_context.proofs.size() == 33,"all occupied points fail closed without any route work")
	game.physics.all_blocked = false; routes_ready = true; now += 750
	_resident_route(start,original)
	game.physics.peer_clear = false
	_check(not _combat_segment(start,legal).ok,"new occupancy invalidates cached destination before another long segment")
	game.physics.peer_clear = true
	watching_defense = true
	var defended: bool = await _defend_exit()
	watching_defense = false
	_check(not defended and defense_suspended and endpoint_service == id,"ordinary defense suspends service routing and restores its context")
	_check([game.runtime.p,game.runtime.s,game.world.service_points,game.player.position] == authoritative,"endpoint search never changes source state, guidepoint or physical position")
	game.free(); game = null
	for failure: String in failures: push_error(failure)
	print("OFFICE SERVICE ENDPOINT CONTRACT: ","PASS" if failures.is_empty() else "FAIL"," (",checks," checks; detached orchestration only)")
	quit(0 if failures.is_empty() else 1)
