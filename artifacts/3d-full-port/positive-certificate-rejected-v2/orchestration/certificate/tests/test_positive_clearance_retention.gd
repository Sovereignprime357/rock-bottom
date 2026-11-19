extends SceneTree
## Actual-query differential witnesses; no performance acceptance.
const Candidate = preload("res://scripts/world_adapter.gd")
const Reference = preload("res://tests/reference_positive_clearance_adapter.gd")
const State = preload("res://scripts/game_state.gd")
const Content = preload("res://scripts/content_catalog.gd")
const A := Vector2(1000,970)
const B := Vector2(1090,970)
var checks: int = 0
var failures: Array[String] = []
var groups: int = 0
var serial: int = 10
var saved_queries: int = 0

class TestWorld extends Node3D:
	var service_points: Dictionary = {}

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failures.size() <= 15: push_error(label)
func _body() -> Dictionary: return {"id":"certificate_actor","x":A.x,"y":A.y,"w":24.0,"h":28.0}
func _box(world: Node3D,center: Vector2,size: Vector3,height: float = 1.5) -> StaticBody3D:
	var node := StaticBody3D.new(); node.collision_layer = 1; node.collision_mask = 0
	world.add_child(node); node.position = Content.to_world(center,height)
	var shape := BoxShape3D.new(); shape.size = size
	var child := CollisionShape3D.new(); child.shape = shape; node.add_child(child)
	return node
func _pair(world: Node3D) -> Dictionary:
	var state := State.new()
	state.p.x = 4000.0; state.p.y = 3000.0
	state.npcs.clear(); state.npcs.append(_body())
	var candidate: RefCounted = Candidate.new(world,state)
	var reference: RefCounted = Reference.new(world,state)
	serial += 1
	for adapter: RefCounted in [candidate,reference]: adapter.begin_navigation_frame(serial,0.0)
	return {"candidate":candidate,"reference":reference,"state":state,"body":_body()}
func _prime(pair: Dictionary,point: Vector2 = A) -> void:
	for adapter: RefCounted in [pair.candidate,pair.reference]:
		_check(adapter._clear(pair.body,point,false),"prime is a real positive overlap at "+str(point))
func _fresh(pair: Dictionary,point: Vector2,label: String) -> void:
	for adapter: RefCounted in [pair.candidate,pair.reference]:
		var before: int = adapter.query_count
		adapter._clear(pair.body,point)
		_check(adapter.query_count == before+1,label+": existing lifetime/key requires actual query")
func _basic(world: Node3D) -> void:
	var pair := _pair(world); _prime(pair)
	var original: Dictionary = pair.body.duplicate(true)
	for adapter: RefCounted in [pair.candidate,pair.reference]:
		var before: int = adapter.query_count
		_check(not adapter._clear(pair.body,B,false) and adapter.query_count == before+1,"failed different point is still an actual overlap")
	_check(pair.candidate._placement_clear.has(pair.body.id) and pair.candidate._placement_clear[pair.body.id].point == A,"candidate retains only the actual positive A")
	_check(not pair.reference._placement_clear.has(pair.body.id),"original independently demonstrates failed-B eviction")
	var before_candidate: int = pair.candidate.query_count
	var before_reference: int = pair.reference.query_count
	_check(pair.candidate._clear(pair.body,A) == pair.reference._clear(pair.body,A),"retained-A result equals actual reference query")
	_check(pair.candidate.query_count == before_candidate and pair.reference.query_count == before_reference+1,"exact-A ordinary read saves one proven redundant overlap")
	saved_queries += (pair.reference.query_count-before_reference)-(pair.candidate.query_count-before_candidate)
	for adapter: RefCounted in [pair.candidate,pair.reference]:
		var before: int = adapter.query_count
		_check(adapter._clear(pair.body,A,false) and adapter.query_count == before+1,"forced same-A endpoint proof is never skipped")
		before = adapter.query_count
		_check(not adapter._clear(pair.body,B) and not adapter._clear(pair.body,B) and adapter.query_count == before+2,"negative results never become certificates")
	_fresh(pair,A+Vector2(1,0),"different movement point")
	_check(pair.body == original,"queries never mutate authoritative geometry")
	groups += 1

func _bisection(world: Node3D) -> void:
	var pair := _pair(world); _prime(pair)
	var low: float = 0.0; var high: float = 1.0
	var accepted := A; var last_clear: bool = true; var passed: int = 0; var refused: int = 0
	# Same eight-probe low/high sequence through actual physics, no fake cast result.
	for index: int in range(8):
		var fraction: float = (low+high)*0.5
		var point: Vector2 = A+Vector2(104,0)*fraction
		var actual: bool = pair.candidate._clear(pair.body,point,false)
		var expected: bool = pair.reference._clear(pair.body,point,false)
		_check(actual == expected,"bisection actual low/high result "+str(index))
		last_clear = actual
		if actual: low = fraction; accepted = point; passed += 1
		else: high = fraction; refused += 1
	_check(passed > 0 and refused > 0 and not last_clear,"real wall yields accepted low then final failed high")
	_check(pair.candidate._placement_clear.has(pair.body.id) and pair.candidate._placement_clear[pair.body.id].point == accepted,"bisection retains its actual returned low")
	_check(not pair.reference._placement_clear.has(pair.body.id),"reference loses low on final high refusal")
	var a: int = pair.candidate.query_count; var b: int = pair.reference.query_count
	_check(pair.candidate._clear(pair.body,accepted) and pair.reference._clear(pair.body,accepted),"accepted low remains physically clear")
	_check(pair.candidate.query_count == a and pair.reference.query_count == b+1,"bisection low reuse saves one actual duplicate")
	saved_queries += (pair.reference.query_count-b)-(pair.candidate.query_count-a)
	pair.body.x = accepted.x; pair.body.y = accepted.y
	_check(pair.candidate.move_body(pair.body,accepted) == pair.reference.move_body(pair.body,accepted),"actual zero-clamp result after accepted low is unchanged")
	groups += 1

func _same_point(world: Node3D,blocker: StaticBody3D) -> void:
	var pair := _pair(world); _prime(pair)
	# Synchronous actual layer publication: retain old proof until forced query.
	# This deliberately exercises the fresh-failure invalidation, not a cache read.
	blocker.collision_layer = 1
	var rounded: Vector2 = A+Vector2(0.0000001,0)
	_check(rounded == A,"float32 equality witness is exactly the same source point")
	for adapter: RefCounted in [pair.candidate,pair.reference]:
		var before: int = adapter.query_count
		_check(not adapter._clear(pair.body,rounded,false) and adapter.query_count == before+1,"same-point forced query sees actual newly enabled collider")
		_check(not adapter._placement_clear.has(pair.body.id),"same-point actual refusal invalidates earlier positive proof")
		before = adapter.query_count
		_check(not adapter._clear(pair.body,A) and adapter.query_count == before+1,"same-point refusal cannot return a stale certificate")
	blocker.collision_layer = 0
	for adapter: RefCounted in [pair.candidate,pair.reference]: adapter.invalidate_placement_cache()
	_prime(pair)
	groups += 1

func _key_changes(world: Node3D) -> void:
	for key: String in ["w","h"]:
		var pair := _pair(world); _prime(pair)
		pair.body[key] += 1.0
		for adapter: RefCounted in [pair.candidate,pair.reference]:
			_check(not adapter._clear(pair.body,B,false),key+": changed-body refusal uses real wall")
			_check(not adapter._placement_clear.has(pair.body.id),key+": failed new key cannot retain incompatible proof")
		_fresh(pair,A,key+" change")
	var pair := _pair(world); _prime(pair)
	for adapter: RefCounted in [pair.candidate,pair.reference]:
		# Private prepared-height path is also a real shape query, not fake data.
		var prepared = adapter._body_query(pair.body,adapter._space())
		prepared.height += 0.1
		_check(not adapter._clear_prepared(pair.body,B,false,prepared),"different resolved height still meets real wall")
		_check(not adapter._placement_clear.has(pair.body.id),"different-height refusal cannot retain old proof")
	_fresh(pair,A,"original height after mismatch")
	pair.body.id = "replacement_actor"
	_fresh(pair,A,"different actor ID")
	groups += 1

func _lifetimes(world: Node3D,blocker: StaticBody3D) -> void:
	var pair := _pair(world); _prime(pair)
	serial += 1
	for adapter: RefCounted in [pair.candidate,pair.reference]: adapter.begin_navigation_frame(serial,0.0)
	_fresh(pair,A,"new render serial")
	await physics_frame; await process_frame
	_fresh(pair,A,"new actual physics frame")
	for adapter: RefCounted in [pair.candidate,pair.reference]: adapter.invalidate_placement_cache()
	_fresh(pair,A,"collision revision")
	for adapter: RefCounted in [pair.candidate,pair.reference]: adapter.register_body(pair.body.id,world,1.8)
	_fresh(pair,A,"body registration")
	for adapter: RefCounted in [pair.candidate,pair.reference]: adapter.unregister_body(pair.body.id)
	_fresh(pair,A,"body unregistration")
	for replacement: String in ["p","s"]:
		pair.state[replacement] = pair.state[replacement].duplicate(true)
		for adapter: RefCounted in [pair.candidate,pair.reference]:
			var before: int = adapter.query_count
			_check(adapter.clear_placement(pair.body) == A and adapter.query_count == before+1,replacement+"-only epoch replacement forces actual origin")
	blocker.collision_layer = 1
	for adapter: RefCounted in [pair.candidate,pair.reference]:
		var before: int = adapter.query_count
		_check(adapter.update_navigation_obstacles("test_dynamic",[{"owner":"test_dynamic","bounds":AABB(blocker.position-Vector3(0.5,1.5,0.5),Vector3(1,3,1))}]),"real collider writer publishes layer change")
		_check(not adapter._clear(pair.body,A) and adapter.query_count == before+1,"published layer invalidation queries newly obstructed A")
	blocker.collision_layer = 0
	for adapter: RefCounted in [pair.candidate,pair.reference]:
		_check(adapter.update_navigation_obstacles("test_dynamic",[]),"disabled layer removes published obstacle")
	_fresh(pair,A,"disabled layer invalidation")
	var no_world: RefCounted = Candidate.new(null,pair.state)
	_check(not no_world._clear(pair.body,A),"missing actual space cannot certify a point")
	_check(not pair.candidate._clear(pair.body,Vector2(-100,0)),"world bounds still refuse")
	groups += 1

func _movement_and_peers(world: Node3D) -> void:
	var completed: int = 0
	for intended: Vector2 in [A,A+Vector2(10,0),Vector2(1100,970),Vector2(1100,1110),Vector2(900,900)]:
		for charge: bool in [false,true]:
			var pair := _pair(world)
			var original: Dictionary = pair.body.duplicate(true)
			_prime(pair)
			for adapter: RefCounted in [pair.candidate,pair.reference]: _check(not adapter._clear(pair.body,B,false),"movement prelude has failed different-point actual query")
			var actual: Dictionary = pair.candidate.move_body(pair.body,intended,null,charge)
			var expected: Dictionary = pair.reference.move_body(pair.body,intended,null,charge)
			_check(actual == expected,"actual ordinary/slide/charge/zero result remains byte-equal "+str(intended)+str(charge))
			_check(pair.body == original,"actual movement leaves source geometry detached")
			_check(pair.candidate._clear(pair.body,actual.position,false),"actual returned endpoint has fresh same-margin overlap proof")
			completed += 1
	_check(completed == 10,"all ten actual movement pairs completed")
	var pair := _pair(world); _prime(pair)
	for adapter: RefCounted in [pair.candidate,pair.reference]: _check(not adapter._clear(pair.body,B,false),"peer prelude retains only static proof")
	pair.state.p.x = A.x+10.0; pair.state.p.y = A.y
	var before: int = pair.candidate.body_contact_tests
	var repaired: Variant = pair.candidate.clear_placement(pair.body)
	var expected: Variant = pair.reference.clear_placement(pair.body)
	_check(repaired == expected and repaired is Vector2 and repaired != A,"current player contact repairs despite retained static certificate")
	_check(pair.candidate.body_contact_tests > before and pair.candidate.placement_cache_hits > 0,"live peer checks actually run on a static cache hit")
	var peer_motion: Dictionary = pair.candidate.move_body(pair.body,A+Vector2(24,0))
	_check(peer_motion == pair.reference.move_body(pair.body,A+Vector2(24,0)),"overlap escape/contact outcome stays exact")
	groups += 1

func _run() -> void:
	var world := TestWorld.new(); root.add_child(world)
	_box(world,Vector2(1100,1000),Vector3(0.4,3,20))
	var blocker := _box(world,A+Vector2(12,14),Vector3(1,3,1)); blocker.collision_layer = 0
	await physics_frame; await process_frame
	_basic(world)
	_bisection(world)
	_same_point(world,blocker)
	_key_changes(world)
	await _lifetimes(world,blocker)
	_movement_and_peers(world)
	_check(groups == 6,"all six bounded real-physics groups reached their tails")
	_check(saved_queries == 2,"only two directly demonstrated ordinary duplicate queries counted as saved")
	world.queue_free(); await process_frame; await physics_frame
	print("POSITIVE CLEARANCE RETENTION: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",groups,"/6 groups; focused_saved_queries=",saved_queries,"; no performance claim")
	quit(0 if failures.is_empty() else 1)
