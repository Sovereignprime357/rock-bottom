extends SceneTree
const Navigation = preload("res://scripts/actor_navigation.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Content = preload("res://scripts/content_catalog.gd")
const State = preload("res://scripts/game_state.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Roster = preload("res://scripts/character_roster.gd")
var checks: int = 0
var failures: Array[String] = []
var serial: int = 0
var active_ms: float = 0.0
var resource_certificate_completed: bool = false

class FixtureWorld:
	extends Node3D
	var records: Array[Dictionary] = []
	func obstacle_records() -> Array[Dictionary]: return records.duplicate()


func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)


func _run() -> void:
	_pure_contract()
	await _physical_routes()
	await _physical_stale_and_charge()
	await _integrated_adapter()
	await _actor_lifetimes_and_profiles()
	await _placement_certificates()
	_check(resource_certificate_completed,"resource certificate group completed")
	await _cash_staging()
	_fairness()
	if failures.is_empty():
		print("3D ACTOR NAVIGATION GATE: PASS (%d checks; real box sweeps, bounded detours/caches/work, source48px target drift; full60AI/rig performance pending)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D ACTOR NAVIGATION GATE: FAIL (%d failures/%d checks)" % [failures.size(),checks])
		quit(1)


func _record(rect: Rect2, owner: String, low: float = 0.0, high: float = 3.0) -> Dictionary:
	var at: Vector3 = Content.to_world(rect.position,low)
	return {"owner":owner,"id":owner,"bounds":AABB(at,Vector3(rect.size.x*0.04,high-low,rect.size.y*0.04))}


func _body(id: String, center: Vector2, width: float = 28.0, depth: float = 32.0) -> Dictionary:
	return {"id":id,"x":center.x-width*0.5,"y":center.y-depth*0.5,"w":width,"h":depth}


func _position(body: Dictionary) -> Vector2: return Vector2(body.x,body.y)
func _center(body: Dictionary) -> Vector2: return _position(body)+Vector2(body.w,body.h)*0.5


func _frame(nav: RefCounted) -> void:
	serial += 1; active_ms += 1000.0/60.0
	nav.begin_frame(serial,active_ms)


func _queue(nav: RefCounted, body: Dictionary, goal: Vector2, motion: Vector2 = Vector2(3,0), height: float = 1.8) -> void:
	var before: Vector2 = _position(body)
	nav.steering(body,before+motion,goal,height)
	nav.note_motion(body,before,before+motion,{"position":before,"blocked":true},goal,height)


func _settle(nav: RefCounted, frames: int = 120) -> void:
	for frame: int in range(frames):
		_frame(nav)
		if nav.metrics().queued == 0: break


func _pure_contract() -> void:
	var nav := Navigation.new(Rect2(0,0,1000,800))
	var wall: Dictionary = _record(Rect2(300,200,100,300),"wall")
	_check(nav.set_obstacles([wall]),"valid world-metre obstacle index")
	_check(nav.metrics().colliders == 1,"index counts actual solids")
	_check(not nav.set_obstacles([{"owner":"bad","bounds":"box"}]) and nav.metrics().colliders == 1,"malformed replacement atomic")
	var body: Dictionary = _body("lurch",Vector2(285.94,350))
	var goal := Vector2(600,350)
	_frame(nav); _queue(nav,body,goal); _settle(nav)
	var status: Dictionary = nav.actor_status(body.id)
	_check(status.status == "ready" and status.path.size() >= 1,"two-corner route found from physics-tangent start")
	var intended: Vector2 = _position(body)+Vector2(3,0)
	var steered: Dictionary = nav.steering(body,intended,goal)
	_check(steered.detouring and _position(body).distance_to(steered.intended) <= 3.0001,"cached steering preserves requested step")
	var first_path: PackedVector2Array = nav.actor_status(body.id).path
	nav.steering(body,intended,goal+Vector2(48,0))
	_check(nav.actor_status(body.id).path == first_path,"target drift exactly48px retains source cache")
	nav.steering(body,intended,goal+Vector2(48.01,0))
	_check(nav.actor_status(body.id).path.is_empty(),"target drift beyond48px invalidates")
	_queue(nav,body,goal); _settle(nav)
	nav.steering(body,_position(body),null)
	_check(not nav.actor_status(body.id).path.is_empty(),"zero-motion zone clamp retains cache")
	nav.steering(body,_position(body)+Vector2(0,2),null)
	_check(nav.actor_status(body.id).status == "absent","nonzero goal-less knockback clears cache")
	_queue(nav,body,goal); _settle(nav)
	body.w = 36
	nav.steering(body,_position(body)+Vector2(3,0),goal)
	_check(nav.actor_status(body.id).path.is_empty(),"body width invalidates incompatible route")
	body.w = 28
	_queue(nav,body,goal); _settle(nav)
	body.y += 100
	nav.steering(body,_position(body)+Vector2(3,0),goal)
	_check(nav.actor_status(body.id).path.is_empty(),"teleported actor invalidates stale path")
	body.y -= 100
	_queue(nav,body,goal); _settle(nav)
	var moved: Dictionary = _record(Rect2(700,200,100,300),"wall")
	_check(nav.update_obstacles("wall",[moved]) and nav.actor_status(body.id).status == "absent","moved cart/solid topology invalidates old route")
	_check(nav.update_obstacles("wall",[]) and nav.metrics().colliders == 0,"disabled parked collider leaves no ghost obstacle")
	nav.set_obstacles([wall]); _queue(nav,body,Vector2(330,350)); _settle(nav)
	_check(nav.actor_status(body.id).status == "goal_blocked","blocked goal reports failure without fake success")
	var requested: int = nav.metrics().requests
	_queue(nav,body,Vector2(330,350))
	_check(nav.metrics().requests == requested,"failed plans respect250ms retry cooldown")
	nav.reset(); _check(nav.metrics().queued == 0 and nav.metrics().actors == 0,"state reset discards paths and pending work")
	nav.set_obstacles([wall]); _queue(nav,body,goal); _settle(nav)
	nav.begin_frame(serial+1,active_ms+10001)
	_check(nav.actor_status(body.id).status == "absent","unseen actor expires after10 active seconds")
	serial += 1; active_ms += 10001
	var player: Dictionary = _body("player",Vector2(285.94,350))
	var result: Dictionary = nav.steering(player,_position(player)+Vector2(3,0),goal)
	_check(not result.detouring and nav.actor_status("player").status == "absent","player is never auto-steered")
	var completed_before: int = nav.metrics().completed
	nav.reset(); nav.begin_frame(serial+1,0.0)
	_queue(nav,body,goal)
	for index: int in range(30): nav.begin_frame(serial+2+index,(index+1)*1000.0/60.0)
	_check(nav.metrics().completed > completed_before and nav.metrics().queued == 0,"new active-time epoch after restore can plan immediately")


func _world(records: Array) -> FixtureWorld:
	var world := FixtureWorld.new()
	root.add_child(world)
	for record: Dictionary in records:
		world.records.append(record.duplicate())
		var box: AABB = record.bounds
		var solid := StaticBody3D.new()
		solid.collision_layer = 1; solid.collision_mask = 0; solid.position = box.get_center()
		solid.set_meta("source_owner",record.owner)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new(); shape.size = box.size; collision.shape = shape
		solid.add_child(collision); world.add_child(solid)
	return world


func _body_node(world: Node3D, adapter: RefCounted, body: Dictionary, height: float) -> void:
	var marker := Node3D.new(); world.add_child(marker)
	adapter.register_body(body.id,marker,height)


func _clear(world: Node3D, body: Dictionary, height: float) -> bool:
	var shape := BoxShape3D.new(); shape.size = Vector3(body.w*0.04,height,body.h*0.04)
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,Content.to_world(_center(body),0.06+height*0.5))
	query.collision_mask = 1; query.margin = 0.0
	return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()


func _physical_routes() -> void:
	var fixtures: Array[Dictionary] = [
		{"name":"long wall","rects":[Rect2(300,200,100,300)],"start":Vector2(170,350),"goal":Vector2(600,350)},
		{"name":"successive standing props","rects":[Rect2(280,260,80,150),Rect2(450,350,90,150)],"start":Vector2(150,350),"goal":Vector2(700,350)},
		{"name":"touching L wall","rects":[Rect2(300,200,30,250),Rect2(300,420,200,30)],"start":Vector2(400,350),"goal":Vector2(200,350)},
		{"name":"U bay exit","rects":[Rect2(300,200,25,300),Rect2(300,200,250,25),Rect2(525,200,25,300)],"start":Vector2(425,350),"goal":Vector2(200,350)},
		{"name":"body width28 fits30px door","rects":[Rect2(100,350,185,20),Rect2(315,350,285,20)],"start":Vector2(300,250),"goal":Vector2(300,500)},
		{"name":"body width36 must detour30px door","rects":[Rect2(100,350,185,20),Rect2(315,350,285,20)],"start":Vector2(300,250),"goal":Vector2(300,500),"width":36.0},
		{"name":"short body under fixture","rects":[Rect2(300,200,100,300)],"start":Vector2(170,350),"goal":Vector2(600,350),"height":0.7,"low":1.0},
		{"name":"tall body respects overhead","rects":[Rect2(300,200,100,300)],"start":Vector2(170,350),"goal":Vector2(600,350),"height":1.8,"low":1.0},
	]
	for fixture: Dictionary in fixtures:
		var records: Array = []
		for index: int in range(fixture.rects.size()): records.append(_record(fixture.rects[index],"wall%d" % index,float(fixture.get("low",0)),3.0))
		var world: FixtureWorld = _world(records)
		var nav := Navigation.new(Rect2(0,0,1000,800)); nav.set_obstacles(records)
		var adapter := Adapter.new(world)
		var body: Dictionary = _body("lurch",fixture.start,float(fixture.get("width",28)),32)
		var height: float = float(fixture.get("height",1.8))
		_body_node(world,adapter,body,height)
		await physics_frame; await process_frame
		_check(_clear(world,body,height),fixture.name+" starts physically clear")
		var arrived: bool = false
		var total: float = 0.0
		var direct: float = fixture.start.distance_to(fixture.goal)
		for iteration: int in range(1600):
			_frame(nav)
			var delta: Vector2 = fixture.goal-_center(body)
			if delta.length() < 0.1: arrived = true; break
			var before: Vector2 = _position(body)
			var intended: Vector2 = before+delta.normalized()*minf(3.0,delta.length())
			var steer: Dictionary = nav.steering(body,intended,fixture.goal,height)
			var moved: Dictionary = adapter.move_body(body,steer.intended,null,false)
			nav.note_motion(body,before,intended,moved,fixture.goal,height)
			body.x = moved.position.x; body.y = moved.position.y
			total += before.distance_to(moved.position)
			_check(before.distance_to(moved.position) <= 3.002,fixture.name+" no motion boost")
			_check(_clear(world,body,height),fixture.name+" committed box never penetrates")
			_check(adapter._clear(body,_position(body)),fixture.name+" cast endpoint passes the next-frame query margin")
		_check(arrived,"actual box reaches goal: "+fixture.name+" status="+str(nav.actor_status(body.id))+" metrics="+str(nav.metrics()))
		if fixture.name == "body width28 fits30px door" or fixture.name == "short body under fixture":
			_check(total < direct+1.0,fixture.name+" uses real opening without invented blocker")
		_check(nav.metrics().max_tests <= 192 and nav.metrics().max_starts <= 4,"physical route hard budgets")
		world.queue_free(); await process_frame; await physics_frame


func _physical_stale_and_charge() -> void:
	var wall: Dictionary = _record(Rect2(300,200,100,300),"wall")
	var world: FixtureWorld = _world([wall])
	var nav := Navigation.new(Rect2(0,0,1000,800)); nav.set_obstacles([]) # Deliberately stale topology.
	var adapter := Adapter.new(world)
	var body: Dictionary = _body("brutus",Vector2(275,350),32,24)
	_body_node(world,adapter,body,0.9)
	await physics_frame; await process_frame
	var before: Vector2 = _position(body)
	var intended: Vector2 = before+Vector2(100,0)
	var steer: Dictionary = nav.steering(body,intended,Vector2(600,350),0.9)
	var moved: Dictionary = adapter.move_body(body,steer.intended,null,true)
	_check(moved.blocked and moved.position.x < intended.x,"live sweep beats stale empty planner topology")
	body.x = moved.position.x; body.y = moved.position.y
	_check(_clear(world,body,0.9),"charge stops outside standing wall")
	nav.set_obstacles([wall]); _queue(nav,body,Vector2(600,350),Vector2(3,0),0.9); _settle(nav)
	nav.invalidate_actor(body.id) # Exact production stop_on_block hook.
	before = _position(body); moved = adapter.move_body(body,before+Vector2(100,0),null,true)
	_check(moved.blocked and absf(moved.position.y-before.y) < 0.0001 and nav.actor_status(body.id).status == "absent","cached detour never bends a charger lunge")
	world.queue_free(); await process_frame; await physics_frame


func _integrated_adapter() -> void:
	var world: FixtureWorld = _world([_record(Rect2(300,200,100,300),"wall")])
	var adapter := Adapter.new(world)
	var body: Dictionary = _body("lurch",Vector2(170,350))
	_body_node(world,adapter,body,1.8)
	await physics_frame; await process_frame
	var goal := Vector2(600,350)
	var arrived: bool = false
	for iteration: int in range(700):
		serial += 1; active_ms += 1000.0/60.0
		adapter.begin_navigation_frame(serial,active_ms)
		var delta: Vector2 = goal-_center(body)
		if delta.length() < 0.1: arrived = true; break
		var before: Vector2 = _position(body)
		var moved: Dictionary = adapter.move_body(body,before+delta.normalized()*minf(3.0,delta.length()),goal,false)
		body.x = moved.position.x; body.y = moved.position.y
		_check(before.distance_to(moved.position) <= 3.002 and adapter._clear(body,moved.position),"integrated adapter commits only its clear cast result")
	_check(arrived and adapter.navigation_metrics().completed > 0 and adapter.navigation_metrics().cache_hits > 0,"public adapter hook traverses actual obstruction")
	body = _body("lurch",Vector2(275,350))
	for iteration: int in range(30):
		serial += 1; active_ms += 1000.0/60.0; adapter.begin_navigation_frame(serial,active_ms)
		var before: Vector2 = _position(body)
		var moved: Dictionary = adapter.move_body(body,before+Vector2(3,0),goal,false)
		body.x = moved.position.x; body.y = moved.position.y
		if not adapter.navigation_status(body.id).path.is_empty(): break
	var before_charge: Vector2 = _position(body)
	var charged: Dictionary = adapter.move_body(body,before_charge+Vector2(100,0),goal,true)
	_check(charged.blocked and absf(charged.position.y-before_charge.y) < 0.0001 and adapter.navigation_status(body.id).status == "absent","production stop_on_block invalidates and bypasses active navigation")
	_check(adapter._clear(body,charged.position),"charge endpoint remains clear at the actual query margin")
	world.queue_free(); await process_frame; await physics_frame


func _actor_lifetimes_and_profiles() -> void:
	var world: FixtureWorld = _world([_record(Rect2(300,200,100,300),"low_lintel",1.885,3.0)])
	var state := State.new()
	state.npcs.clear()
	var adapter := Adapter.new(world,state)
	adapter.bind_state(state)
	var combat := Combat.new(state,adapter)
	await physics_frame; await process_frame
	var children_before: int = world.get_child_count()
	for variant: String in ["cop","brendan"]:
		var body: Dictionary = _body("preappend_"+variant,Vector2(350,350),26 if variant == "brendan" else 28,30 if variant == "brendan" else 32)
		body.name = "COUSIN BRENDAN" if variant == "brendan" else "COP"
		body.sprite = variant
		body.hp = 60
		body.unrelated = {"mutable":true}
		var geometry: Dictionary = combat._geometry(body)
		_check(not geometry.has("hp") and not geometry.has("unrelated") and geometry.name == body.name and geometry.sprite == variant,"Combat passes detached visual hints only:"+variant)
		var height: float = Roster.definition(Roster.visual_for_actor(body)).height
		_check(state.npcs.is_empty() and _clear(world,body,1.8),"preappend fixture would admit old fallback:"+variant)
		_check(not _clear(world,body,height),"real profile intersects lintel:"+variant)
		_check(combat.clear_actor(body),"preappend source actor finds real clear placement:"+variant)
		_check(is_equal_approx(adapter._height(body.id),height) and _clear(world,body,height),"first placement uses real profile height:"+variant)
		body.x = 260-body.w*0.5; body.y = 350-body.h*0.5
		var before: Vector2 = _position(body)
		var moved: Dictionary = combat.move_actor(body,before+Vector2(200,0),null,true)
		_check(moved.blocked and _clear(world,body,height) and _center(body).x < 300.0-body.w*0.5,"preappend sweep cannot pass under lintel:"+variant)
		adapter.unregister_body(body.id)
		_check(not adapter._height_profiles.has(body.id),"unregister removes pre-rig metadata cache:"+variant)
	_check(world.get_child_count() == children_before,"profile lookup constructs no presentation nodes")
	var host_actor: Dictionary = _body("host_cop",Vector2(170,350))
	host_actor.name = "COP"; host_actor.sprite = "cop"
	state.npcs.append(host_actor)
	_check(is_equal_approx(adapter._height(host_actor.id),1.91),"ID-only unregistered query resolves current host actor")
	host_actor.name = "COUSIN BRENDAN"; host_actor.sprite = "brendan"
	_check(is_equal_approx(adapter._height(host_actor.id),1.86),"same-ID visual change refreshes cached profile")
	var fallen: Dictionary = _body("not_the_special_id",Vector2(170,350))
	fallen.name = "FATHER O'MALLEY"; fallen.sprite = "priest"; fallen.isOmalleyFallen = true
	_check(combat._geometry(fallen).get("isOmalleyFallen") == true,"fallen priest profile hint survives detached geometry")
	var marker := Node3D.new(); world.add_child(marker)
	adapter.register_body(host_actor.id,marker,1.2)
	_check(is_equal_approx(adapter._height(host_actor.id),1.2),"live registered profile remains fast authoritative height")
	marker.free()
	_check(is_equal_approx(adapter._height(host_actor.id),1.86),"expired weak node resolves current source profile")
	host_actor.x = 285.94-host_actor.w*0.5
	serial += 1; active_ms += 1000.0/60.0; adapter.begin_navigation_frame(serial,active_ms)
	_queue(adapter._navigation,host_actor,Vector2(600,350),Vector2(3,0),1.86)
	_check(adapter.navigation_metrics().queued > 0,"lifetime fixture holds actual pending work")
	var replacement := Node3D.new(); world.add_child(replacement)
	adapter.register_body(host_actor.id,replacement,1.86)
	_check(adapter.navigation_status(host_actor.id).status == "absent" and adapter.navigation_metrics().queued == 0,"registration cancels same-ID stale queued path")
	_queue(adapter._navigation,host_actor,Vector2(600,350),Vector2(3,0),1.86)
	adapter.unregister_body(host_actor.id)
	_check(not adapter._bodies.has(host_actor.id) and not adapter._height_profiles.has(host_actor.id) and adapter.navigation_status(host_actor.id).status == "absent" and adapter.navigation_metrics().queued == 0,"despawn releases registration/profile/queued path")
	adapter._height(host_actor.id)
	_check(not adapter._height_profiles.is_empty(),"epoch fixture caches a real profile")
	state.fresh()
	serial += 1; adapter.begin_navigation_frame(serial,0.0)
	_check(adapter._height_profiles.is_empty(),"fresh state identity discards metadata height caches")
	world.queue_free(); await process_frame; await physics_frame
	var sealed: FixtureWorld = _world([_record(Rect2(100,100,500,500),"sealed_spawn",0.0,3.0)])
	var refused := Adapter.new(sealed)
	await physics_frame; await process_frame
	for index: int in range(8):
		var pending: Dictionary = _body("refused_cop_%d" % index,Vector2(350,350))
		pending.name = "COP"; pending.sprite = "cop"
		_check(refused.clear_placement(pending) == null,"bounded preappend placement can refuse source spawn")
		_check(not refused._height_profiles.has(pending.id),"refused unregistered spawn leaves no profile cache")
	_check(refused._height_profiles.is_empty(),"repeated refused spawns cannot accumulate orphan profiles")
	sealed.queue_free(); await process_frame; await physics_frame


func _placement_certificates() -> void:
	var world: FixtureWorld = _world([_record(Rect2(400,100,20,500),"certificate_wall"),_record(Rect2(150,300,60,60),"certificate_lintel",1.2,2.3)])
	var state := State.new()
	var adapter := Adapter.new(world,state)
	var body: Dictionary = _body("certificate_actor",Vector2(200,200))
	_body_node(world,adapter,body,1.8)
	var dynamic := StaticBody3D.new()
	dynamic.collision_layer = 0; dynamic.collision_mask = 0
	dynamic.position = Content.to_world(Vector2(200,200),1.0)
	var shape := BoxShape3D.new(); shape.size = Vector3(1,2,1)
	var collision := CollisionShape3D.new(); collision.shape = shape; dynamic.add_child(collision); world.add_child(dynamic)
	await physics_frame; await process_frame
	serial += 1; adapter.begin_navigation_frame(serial,active_ms)
	var before: int = adapter.query_count
	_check(adapter.clear_placement(body) == _position(body),"certificate starts from actual clear overlap")
	_check(adapter.clear_placement(body) == _position(body) and adapter.query_count == before+1,"same-frame exact positive origin uses one overlap")
	var entry: Dictionary = adapter._navigation._entry(body,1.8)
	entry.path = PackedVector2Array([Vector2(250,250),Vector2(300,250)])
	entry.goal = Vector2(500,250); entry.status = "ready"
	var retained: Dictionary = adapter.navigation_status(body.id).duplicate(true)
	var zero_before: int = adapter.query_count
	var stationary: Dictionary = adapter.move_body(body,_position(body),entry.goal,false)
	_check(stationary.position == _position(body) and not stationary.blocked and not stationary.body_contact,"exact-zero actor movement retains original stationary result")
	_check(adapter.query_count == zero_before and adapter.navigation_status(body.id) == retained,"ordinary zero zone clamp retains its exact navigation path and existing origin certificate")
	stationary = adapter.move_body(body,_position(body),entry.goal,true)
	_check(not stationary.blocked and adapter.navigation_status(body.id).status == "absent","zero-length charge still invalidates navigation before returning")
	var hits: int = adapter.placement_cache_hits
	var moved: Dictionary = adapter.move_body(body,_position(body)+Vector2(1,0))
	_check(moved.position.distance_to(_position(body)+Vector2(1,0)) < 0.0001 and adapter.placement_cache_hits > hits,"Director placement certificate reused by movement origin")
	_check(adapter.query_count >= before+3,"cached origin still performs cast and uncached endpoint proof")
	# Production Combat commits the returned point before the next fixed step.
	body.x = moved.position.x; body.y = moved.position.y
	before = adapter.query_count; hits = adapter.placement_cache_hits
	_check(adapter.clear_placement(body) == _position(body) and adapter.query_count == before and adapter.placement_cache_hits == hits+1,"fresh swept endpoint publishes exact next-origin certificate")
	_check(adapter._clear(body,_position(body),false) and adapter.query_count == before+1,"false-call bypasses a positive certificate and performs actual overlap")
	before = adapter.query_count
	_check(adapter._clear(body,_position(body)) and adapter.query_count == before,"successful false-call publishes its new exact proof for ordinary reads")
	before = adapter.query_count; adapter.begin_navigation_frame(serial,active_ms)
	adapter.clear_placement(body)
	_check(adapter.query_count == before,"same render serial does not prematurely discard exact positive point")
	serial += 1; adapter.begin_navigation_frame(serial,active_ms)
	adapter.clear_placement(body)
	_check(adapter.query_count == before+1,"render-frame change expires certificate")
	before = adapter.query_count
	await physics_frame; await process_frame
	adapter.clear_placement(body)
	_check(adapter.query_count == before+1,"physics-frame change expires certificate even without new render hook")
	dynamic.collision_layer = 1
	adapter.invalidate_placement_cache()
	before = adapter.query_count
	_check(not adapter._clear(body,_position(body)) and adapter.query_count == before+1,"same-frame standing-collider invalidation queries actual new obstruction")
	_check(not adapter._clear(body,_position(body)) and adapter.query_count == before+2,"negative overlaps are never certified")
	dynamic.collision_layer = 0; adapter.invalidate_placement_cache()
	_check(adapter._clear(body,_position(body)),"cleared dynamic collider is queried again")
	body.x = 371; body.y = 220
	_check(adapter._clear(body,_position(body)),"body fits original width before wall")
	body.w = 32
	_check(not adapter._clear(body,_position(body)),"exact width change cannot inherit old certificate")
	body.w = 28; body.x = 160; body.y = 200
	adapter._clear(body,_position(body)); before = adapter.query_count; body.h += 1
	adapter._clear(body,_position(body))
	_check(adapter.query_count == before+1,"exact logical depth change requires fresh overlap")
	body = _body("certificate_actor",Vector2(180,330))
	var low_marker := Node3D.new(); world.add_child(low_marker)
	adapter.register_body(body.id,low_marker,1.0)
	_check(adapter._clear(body,_position(body)),"short registered body fits authored overhead")
	adapter.register_body(body.id,low_marker,1.8)
	_check(not adapter._clear(body,_position(body)),"registration/height change rejects formerly clear overhead")
	body = _body("certificate_actor",Vector2(200,200)); adapter._clear(body,_position(body))
	before = adapter.query_count; adapter.unregister_body(body.id); adapter._clear(body,_position(body))
	_check(adapter.query_count == before+1,"unregister drops matching positive certificate")
	before = adapter.query_count; state.fresh(); adapter.clear_placement(body)
	_check(adapter.query_count == before+1,"state epoch replacement invalidates exact placement")
	before = adapter.query_count
	_check(adapter.update_navigation_obstacles("optional_cart",[]),"empty dynamic owner update accepted")
	adapter.clear_placement(body)
	_check(adapter.query_count == before+1,"topology update invalidates certificate even within frame")
	_check(not adapter._query_scratch_busy,"certificate/height/epoch/topology checks leave no query lease")
	_check(adapter._query_scratch == null or (adapter._query_scratch.body.is_empty() and adapter._query_scratch.space == null),"certificates never retain source bodies or world space through query lease")
	world.queue_free(); await process_frame; await physics_frame
	resource_certificate_completed = true


func _cash_staging() -> void:
	var world: FixtureWorld = _world([_record(Rect2(300,100,20,500),"cash_wall")])
	var state := State.new(); var adapter := Adapter.new(world,state)
	await physics_frame; await process_frame
	var original: Dictionary = state.snapshot(); var rng: int = state.rng_seed
	var exact := Vector2(200,350)
	_check(adapter.stage_cash_pickup(exact,100) == exact,"cash anchor uses exact clear source center first")
	var tangent := Vector2(294,350)
	_check(adapter.stage_cash_pickup(tangent,0) == null,"zero recovery cannot fit capsule through standing wall")
	var recovered: Variant = adapter.stage_cash_pickup(tangent,100)
	_check(recovered is Vector2 and recovered.distance_to(tangent) <= 100.0001 and recovered.x < 288,"bounded cash recovery remains on visible side of wall")
	if recovered is Vector2:
		var body := {"id":"player","x":recovered.x-state.p.w*0.5,"y":recovered.y-state.p.h*0.5,"w":state.p.w,"h":state.p.h}
		_check(adapter._clear(body,Vector2(body.x,body.y),false),"staged cash has actual player capsule approach")
		_check(adapter._ray(Content.to_world(tangent,0.18),Content.to_world(recovered,0.18)).is_empty(),"recovered cash retains low source-to-target LOS")
	var before: int = adapter.query_count
	_check(adapter.stage_cash_pickup(Vector2(310,350),100) == null,"source inside solid remains pending instead of jumping through wall")
	_check(adapter.query_count-before <= 339,"cash recovery query work stays finite")
	for bad: Vector2 in [Vector2(NAN,0),Vector2(-1,0),Vector2(8601,1)]:
		_check(adapter.stage_cash_pickup(bad,100) == null,"invalid cash source rejected")
	for maximum: float in [-1.0,100.01,NAN,INF]:
		_check(adapter.stage_cash_pickup(exact,maximum) == null,"invalid/unbounded recovery rejected")
	_check(JSON.stringify(state.snapshot()) == JSON.stringify(original) and state.rng_seed == rng,"cash staging changes neither source model nor RNG")
	world.queue_free(); await process_frame; await physics_frame
	var roof: FixtureWorld = _world([_record(Rect2(100,100,500,500),"low_cash_room",0.8,3.0)])
	var blocked := Adapter.new(roof,state)
	await physics_frame; await process_frame
	_check(blocked.stage_cash_pickup(Vector2(350,350),100) == null,"pickup cannot claim accessibility under player-height obstruction")
	roof.queue_free(); await process_frame; await physics_frame


func _fairness() -> void:
	var nav := Navigation.new(Rect2(0,0,1000,800))
	nav.set_obstacles([_record(Rect2(300,200,100,300),"wall")])
	_frame(nav)
	var bodies: Array[Dictionary] = []
	for index: int in range(60):
		var body: Dictionary = _body("fixture_%d" % index,Vector2(285.94,240.0+index*3.5))
		bodies.append(body); _queue(nav,body,Vector2(600,350))
	for frame: int in range(400):
		_frame(nav)
		var before: Dictionary = nav.metrics()
		for substep: int in range(5): nav.begin_frame(serial,active_ms)
		_check(nav.metrics().frame_tests == before.frame_tests and nav.metrics().frame_starts == before.frame_starts,"same render frame never replenishes budget")
		_check(nav.metrics().frame_tests <= 192 and nav.metrics().frame_starts <= 4,"60 simultaneous requests obey hard work caps")
		if nav.metrics().queued == 0: break
	_check(nav.metrics().queued == 0,"FIFO planning does not starve the last actor")
	for body: Dictionary in bodies:
		_check(nav.actor_status(body.id).status == "ready","every finite wall request resolves: "+body.id)
	_check(nav.metrics().completed == 60,"all60 independent cached plans completed")
	var metrics: Dictionary = nav.metrics()
	print("NAVIGATION LOCAL BUDGET: ",JSON.stringify(metrics))
