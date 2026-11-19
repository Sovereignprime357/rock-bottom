extends SceneTree
const View = preload("res://scripts/actor_hud_view.gd")
const ProjectionHelper = preload("res://scripts/actor_hud_projection.gd")
const Overlay = preload("res://scripts/actor_hud_overlay.gd")
var checks: int = 0
var failures: Array[String] = []
var completed_actors: int = 0
var completed_combat: int = 0
var groups: int = 0
class Host:
	extends RefCounted
	var p: Dictionary = {"x":0.0,"y":0.0,"w":28.0,"h":34.0,"hp":100.0}
	var s: Dictionary = {"mode":"playing","dayTime":.5,"metVendors":[]}
	var npcs: Array[Dictionary] = []
	var rng_seed: int = 778899
	var events: Array = []
class Spatial:
	extends RefCounted
	var host_ref: WeakRef
	var camera_ref: WeakRef
	var world_ref: WeakRef
	var replacement: String = ""
	var at_phase: String = ""
	var result: Variant = true
	var hits: Array[String] = []
	var points: Dictionary = {}
	var real_ray: bool = false
	var free_camera_on_sight: bool = false
	func _replace(phase: String) -> void:
		if at_phase != phase or replacement.is_empty(): return
		var host: RefCounted = host_ref.get_ref()
		if replacement == "p": host.p = host.p.duplicate(true)
		else: host.s = host.s.duplicate(true)
		replacement = ""
	func anchor(id: String) -> Variant:
		_replace("anchor")
		return points.get(id,Vector3(0,0,-10))
	func visible_now(id: String,at: Vector3) -> Variant:
		hits.append(id); _replace("sight")
		if free_camera_on_sight:
			free_camera_on_sight = false; camera_ref.get_ref().free(); return true
		if real_ray:
			var camera: Camera3D = camera_ref.get_ref(); var world: Node3D = world_ref.get_ref()
			var query := PhysicsRayQueryParameters3D.create(camera.global_position,at,1)
			return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		return result
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _same(actual: Variant,expected: Variant,path: String) -> void:
	if expected is Dictionary:
		_check(actual is Dictionary,path+" dictionary")
		if not actual is Dictionary: return
		if expected.is_empty(): _check(actual.is_empty(),path+" empty"); return
		for key: Variant in expected:
			_check(actual.has(key),path+" has "+str(key))
			if actual.has(key): _same(actual[key],expected[key],path+"."+str(key))
	elif expected is Array:
		_check(actual is Array and actual.size() == expected.size(),path+" array length")
		if actual is Array and actual.size() == expected.size():
			for index: int in range(expected.size()): _same(actual[index],expected[index],path+"["+str(index)+"]")
	elif expected is float or expected is int:
		_check((actual is float or actual is int) and absf(float(actual)-float(expected)) < 0.00000001,path+" source numeric")
	else: _check(actual == expected,path+" source value: "+str(actual)+" expected "+str(expected))
func _source() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/actor_hud_reference.json"))
	_check(fixture is Dictionary and fixture.actor_count == 249 and fixture.combat_count == 208,"all independent source cases loaded")
	if not fixture is Dictionary: return
	for row: Dictionary in fixture.actors:
		var actual: Dictionary = View.actor_facts(row.actor,row.player,row.met,fixture.vendor_ids,row.visual_ms)
		var expected: Dictionary = row.expected.duplicate(true)
		if expected.name_color == null: expected.erase("name_color")
		_same(actual,expected,row.id); completed_actors += 1
	for row: Dictionary in fixture.combat:
		_same(View.combat_facts(row.player,row.state,row.visual_ms),row.expected,row.id); completed_combat += 1
	_check(fixture.randomDraws == 0,"original actor and combat drawing consumes no RNG")
	groups += 1
func _actor(id: String = "tony",name: String = "TRE BAG TONY") -> Dictionary:
	return {"id":id,"name":name,"x":0.0,"y":0.0,"w":28.0,"h":34.0,"hp":100.0,"maxHp":100.0,"vendor":true,"showHp":true}
func _pure_view() -> void:
	var host := Host.new(); host.npcs.append(_actor())
	var view := View.new(host)
	var before := {"p":host.p.duplicate(true),"s":host.s.duplicate(true),"npcs":host.npcs.duplicate(true),"rng":host.rng_seed,"events":host.events.duplicate(true)}
	var a: Dictionary = view.snapshot(123); var b: Dictionary = view.snapshot(123)
	_check(a == b and {"p":host.p,"s":host.s,"npcs":host.npcs,"rng":host.rng_seed,"events":host.events} == before,"repeated view is pure including source actor label-cache mutation avoided")
	a.actors[0].name_lines.append("poison"); a.actors[0].hp.test = true
	_check(view.snapshot(123) == b,"detached view cannot mutate future names or authority")
	for index: int in range(180): host.npcs[0].name = "CURB PRETENDER No. "+str(index); view.snapshot(10)
	_check(view.cache_size() == View.CACHE_LIMIT,"numbered names cannot grow private cache beyond128")
	host.npcs.assign([_actor("mom"),_actor("pete"),_actor("day"),_actor("dead"),_actor("gone"),_actor("tony")])
	host.npcs[2].daytimeOnly = true; host.npcs[3].dead = true; host.npcs[4].departed = true
	for time: float in [.0,.249999,.25,.75,.750001,.99]:
		host.s.dayTime = time
		var night: bool = time < .25 or time > .75
		_check(view.snapshot(10).actors.size() == (1 if night else 4),"exact source night boundary "+str(time))
	host.s.mode = "title"; _check(view.snapshot(10).actors.is_empty() and view.snapshot(10).combat.is_empty(),"title suppresses actor/combat presentation")
	host.s.mode = "dialogue"; host.p.stunT = 1
	_check(not view.snapshot(10).combat.is_empty(),"paused/modal combat facts survive without clock ticks")
	_check(view.snapshot(NAN).is_empty() and view.snapshot(INF).is_empty() and view.snapshot(-1).is_empty(),"invalid visual time rejected")
	host.p = host.p.duplicate(true); _check(not view.is_current(),"p-only replacement invalidates captured frame")
	view.snapshot(10); _check(view.is_current(),"next detached frame reads new epoch")
	host.s = host.s.duplicate(true); _check(not view.is_current(),"s-only replacement invalidates captured frame")
	view.snapshot(10); host = null; _check(view.snapshot(10).is_empty(),"view weak owner expires without retained authority")
	groups += 1
func _projection(camera: Camera3D) -> void:
	var viewport: Rect2 = root.get_visible_rect()
	var center: Dictionary = ProjectionHelper.project(camera,Vector3(0,0,-10),viewport)
	_check(not center.is_empty() and center.point.distance_to(viewport.get_center()) < .01,"actual Camera3D front point projects to center")
	for point: Vector3 in [Vector3(0,0,10),Vector3(100,0,-10),Vector3(0,100,-10),Vector3(0,0,-.001),Vector3(0,0,-camera.far-1),Vector3(NAN,0,-10),Vector3(INF,0,-10)]:
		_check(ProjectionHelper.project(camera,point,viewport).is_empty(),"behind/offscreen/near/far/nonfinite has no NPC arrow "+str(point))
	var occupied: Array[Rect2] = []
	var box: Dictionary = ProjectionHelper.layout(Vector2(400,500),Vector2(80,30),viewport,occupied)
	_check(not box.is_empty() and box.attempts == 1 and viewport.encloses(box.rect),"first nameplate fits viewport")
	for index: int in range(4):
		var next: Dictionary = ProjectionHelper.layout(Vector2(400,500),Vector2(80,30),viewport,occupied)
		_check(not next.is_empty() and next.attempts == index+1,"first four source upward placements remain clear")
		if not next.is_empty(): occupied.append(next.rect)
	var side: Dictionary = ProjectionHelper.layout(Vector2(400,500),Vector2(80,30),viewport,occupied)
	_check(not side.is_empty() and side.side and side.attempts <= 8 and viewport.encloses(side.rect),"crowded upward slots receive bounded visible side placement")
	var blocked_all: Array[Rect2] = [viewport]
	_check(ProjectionHelper.layout(Vector2(400,500),Vector2(80,30),viewport,blocked_all).is_empty(),"fully occupied viewport fails closed without unbounded lifting")
	var objective: Array[Rect2] = [Rect2(20,110,824,83)]
	var crowded: Dictionary = ProjectionHelper.layout(Vector2(640,290),Vector2(240,140),viewport,objective)
	_check(not crowded.is_empty() and crowded.side and crowded.attempts <= 8 and not crowded.rect.intersects(objective[0]),"native Tony objective collision resolves beside actual head without moving camera or objective")
	groups += 1
func _renderer(camera: Camera3D,world: Node3D) -> void:
	var host := Host.new(); var spatial := Spatial.new(); spatial.host_ref = weakref(host); spatial.camera_ref = weakref(camera); spatial.world_ref = weakref(world)
	var overlay := Overlay.new(); root.add_child(overlay); overlay.size = root.get_visible_rect().size
	_check(overlay.bind_model(host,camera,spatial.anchor,spatial.visible_now),"renderer binds real camera and required seams")
	for index: int in range(72):
		var actor: Dictionary = _actor("a"+str(index),"ACTOR "+str(index)); actor.x = float(index)
		if index == 71: actor.chargeState = "windup"
		host.npcs.append(actor); spatial.points[actor.id] = Vector3((index%8-3.5)*.32,(floori(index/8.0)-4)*.18,-10)
	var before := {"p":host.p.duplicate(true),"s":host.s.duplicate(true),"npcs":host.npcs.duplicate(true),"rng":host.rng_seed}
	_check(overlay.update_frame(100),"full72 display candidates processed")
	var report: Dictionary = overlay.inspect(); var resource_ids: Array = report.resource_ids
	_check(report.counters.rays == 64 and report.counters.excess == 8 and spatial.hits.size() == 64,"64 fresh rays bounded and8 excess hidden")
	_check(spatial.hits[0] == "a71","actual windup is prioritized before nearer passive nameplates")
	_check(report.counters.max_layout_attempts <= 8,"crowding uses at most8 layout attempts")
	for cluster: Dictionary in report.clusters:
		_check(Rect2(Vector2.ZERO,overlay.size).encloses(cluster.rect),"every drawn cluster inside viewport")
		for drawn: Rect2 in cluster.geometry.draw_bounds: _check(Rect2(Vector2.ZERO,cluster.rect.size).encloses(drawn),"reported cluster encloses actual font/glyph/shadow/HP/backing bounds")
	for left: int in range(report.clusters.size()):
		for right: int in range(left+1,report.clusters.size()): _check(not report.clusters[left].rect.intersects(report.clusters[right].rect),"drawn clusters do not overlap")
	spatial.result = false; spatial.hits.clear(); overlay.update_frame(101)
	_check(overlay.inspect().clusters.is_empty() and spatial.hits.size() == 64,"newly blocked rays erase prior labels immediately")
	spatial.result = 1; overlay.update_frame(102); _check(overlay.inspect().clusters.is_empty(),"nonboolean visibility fails closed")
	spatial.result = true
	for index: int in range(12): overlay.update_frame(1000+index)
	_check(overlay.inspect().resource_ids == resource_ids and overlay.get_child_count() == 0 and overlay.inspect().metric_cache <= Overlay.METRIC_LIMIT,"font/gradient resources and singleControl stable acrossframes")
	_check({"p":host.p,"s":host.s,"npcs":host.npcs,"rng":host.rng_seed} == before,"projection/LOS/render prep owns no state/RNG/timers")
	for phase: String in ["anchor","sight"]:
		for key: String in ["p","s"]:
			spatial.at_phase = phase; spatial.replacement = key
			_check(not overlay.update_frame(2000) and overlay.inspect().clusters.is_empty() and overlay.inspect().combat.is_empty(),phase+" callback "+key+" replacement clears captured frame")
			_check(overlay.update_frame(2001),"next frame accepts fresh identity")
	spatial.at_phase = ""
	host.npcs.assign([_actor()]); var tony: Dictionary = host.npcs[0]
	tony.hp = 50.0; tony.aggro = true; tony.chargeState = "windup"; tony.chatter = "the copper sings in b flat."; tony.chatterT = 5000.0
	spatial.points = {"tony":camera.project_position(Vector2(640,290),10.0)}
	var objective: Array[Rect2] = [Rect2(20,110,824,83)]
	overlay.update_frame(2090,objective)
	var beside: Dictionary = overlay.inspect()
	_check(beside.clusters.size() == 1 and beside.clusters[0].side,"real camera combined HP/windup/chatter fits beside head with objective unchanged")
	for cluster: Dictionary in beside.clusters:
		_check(not cluster.rect.intersects(objective[0]),"combined actual glyph cluster avoids objective")
		for drawn: Rect2 in cluster.geometry.draw_bounds: _check(Rect2(Vector2.ZERO,cluster.rect.size).encloses(drawn),"combined windup/chatter actual glyph bounds are certified")
	host.s.mode = "dialogue"; host.p.stunT = 500; spatial.hits.clear()
	_check(overlay.update_frame(2100) and overlay.inspect().clusters.is_empty() and spatial.hits.is_empty() and overlay.inspect().combat.stun_text == "GRABBED","modal hides actor labels/rays but retains source global stun")
	var early: float = overlay.inspect().combat.stun
	overlay.update_frame(2140); _check(overlay.inspect().combat.stun != early and host.p.stunT == 500,"paused wall pulse changes without gameplay timer decrement")
	host.s.mode = "playing"; host.npcs.assign([_actor()]); spatial.points = {"tony":Vector3(0,0,-10)}
	var full: Array[Rect2] = [Rect2(Vector2.ZERO,overlay.size)]
	overlay.update_frame(2200,full); _check(overlay.inspect().clusters.is_empty(),"occupied actual HUD region prevents overlay text collisions")
	host.p.stunT = 0; spatial.real_ray = true
	await physics_frame
	overlay.update_frame(2300); _check(overlay.inspect().counters.drawn == 1,"actual empty physics ray displays actor")
	var wall := StaticBody3D.new(); wall.collision_layer = 1; wall.collision_mask = 0; world.add_child(wall); wall.position = Vector3(0,0,-5)
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = Vector3(3,3,.2); collision.shape = shape; wall.add_child(collision)
	await physics_frame; await physics_frame
	overlay.update_frame(2301); _check(overlay.inspect().clusters.is_empty() and overlay.inspect().counters.occluded == 1,"real layer1 wall hides name without cached old clear result")
	wall.position.x = 20; await physics_frame; await physics_frame
	overlay.update_frame(2302); _check(overlay.inspect().counters.drawn == 1,"moving actual blocker away restores current label")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions; await process_frame; overlay.size = root.get_visible_rect().size
		overlay.update_frame(2400)
		_check(overlay.inspect().counters.drawn == 1,"actual viewport supports source vendor label "+str(dimensions))
		for cluster: Dictionary in overlay.inspect().clusters: _check(Rect2(Vector2.ZERO,overlay.size).encloses(cluster.rect),"resized safe viewport contains every displayed cluster")
	wall.free(); spatial.free_camera_on_sight = true
	_check(not overlay.update_frame(2500) and overlay.inspect().clusters.is_empty(),"camera freed inside current sight callback cannot publish stale projected label")
	overlay.update_frame(2501)
	_check(overlay.inspect().clusters.is_empty(),"expired weak camera cannot leave stale labels")
	overlay.clear(); _check(overlay.inspect().combat.is_empty() and overlay.inspect().clusters.is_empty(),"unbind clears all captured facts")
	overlay.free(); groups += 1
func _run() -> void:
	_source(); _pure_view()
	root.size = Vector2i(1280,720)
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera); camera.current = true; camera.near = .06; camera.far = 380
	await process_frame
	_projection(camera); await _renderer(camera,world)
	world.free()
	_check(completed_actors == 249 and completed_combat == 208 and groups == 4,"all source views and asynchronous groups completed")
	if failures.is_empty(): print("3D ACTOR HUD: PASS (",checks," checks / ",completed_actors," actor + ",completed_combat," combat source views)"); quit(0)
	else:
		for failure: String in failures: print("FAIL ",failure)
		print("3D ACTOR HUD: FAIL ",failures.size(),"/",checks); quit(1)
