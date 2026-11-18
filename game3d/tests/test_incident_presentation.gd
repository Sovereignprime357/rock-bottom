extends SceneTree
## Actual source trajectories against actual standing world geometry; no Runtime activation.
const World = preload("res://scripts/full_neighborhood.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const State = preload("res://scripts/game_state.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Incidents = preload("res://scripts/incident_system.gd")
const Presentation = preload("res://scripts/incident_presentation.gd")
const Comms = preload("res://scripts/communications_system.gd")
const Props = preload("res://scripts/prop_state.gd")
const PathMap = preload("res://scripts/incident_path_map.gd")
const STARTS := {"runaway_mattress":Vector2(1080,960),"possum_inventory":Vector2(1080,1510),"laundromat_walkout":Vector2(1640,1200),"yuri_receipt":Vector2(400,300),"park_dry_committee":Vector2(2600,1280),"ticketed_luggage":Vector2(800,2985)}
var world: Node3D
var adapter: RefCounted
var state: RefCounted
var incidents: RefCounted
var presentation: Node3D
var props: RefCounted
var comms: RefCounted
var paths: RefCounted
var checks: int = 0
var failures: Array[String] = []
var report: Dictionary = {"complete":false,"ok":false,"paths":[],"roads":[],"beat_views":0,"shape_samples":0,"scope":"actual world geometry and detached presentation; Runtime remains disabled"}
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _unix() -> float: return 1763424000000.0
func _place(point: Vector2) -> void: state.p.x = point.x-state.p.w*0.5; state.p.y = point.y-state.p.h*0.5
func _start(id: String) -> void:
	_place(STARTS[id]); state.s.incident = null; state.s.flags.incidentMask = 0; state.s.flags.incidentsToday = 0
	_check(incidents._start(id),"actual source incident starts "+id)
	_place(Vector2(8500,5500))
func _seek(ms: float) -> Dictionary:
	state.s.incident.t = ms; incidents._update_active(state.s.incident)
	return incidents.visual_snapshot()
func _unique_failure(rows: Array[Dictionary],entry: Dictionary,ms: float) -> void:
	for row: Dictionary in rows:
		if row.part == entry.part and row.owner == entry.owner: return
	var row: Dictionary = entry.duplicate(true); row.time_ms = ms; rows.append(row)
func _audit_canonical() -> void:
	for id: String in Incidents.IDS:
		_start(id)
		var previous: Dictionary = {}; var blocked: Array[Dictionary] = []; var maximum_offset: float = 0.0
		var duration: float = incidents.definitions[id].duration
		var samples: int = int(duration/50)+1
		for step: int in range(samples):
			var ms: float = minf(duration,step*50.0); var view: Dictionary = _seek(ms)
			var before: Dictionary = state.s.duplicate(true); var player: Dictionary = state.p.duplicate(true); var actors: Array = state.npcs.duplicate(true); var event_count: int = state.events.size()
			_check(presentation.sync(view,ms),"detached presentation accepts source view "+id)
			_check(state.s == before and state.p == player and state.npcs == actors and state.events.size() == event_count,"display cannot mutate model/events "+id)
			var sample: Dictionary = presentation.inspect(view,previous); previous = sample; report.shape_samples += sample.shapes
			for entry: Dictionary in sample.failures: _unique_failure(blocked,entry,ms)
			if Presentation.ENVELOPES.has(id):
				var actor: Dictionary = view.active.actors[0]; var offset: float = Presentation.display_point(view.active).distance_to(Vector2(actor.x,actor.y))
				maximum_offset = maxf(maximum_offset,offset)
				_check(offset <= 100.0,"visual detour stays within100 source pixels "+id)
				if step == 0 or step == samples-1: _check(offset < 0.001,"mesh and effective model endpoint are exact "+id)
		_check(blocked.is_empty(),"complete actual collider trajectory "+id+" "+str(blocked))
		for beat: Array in incidents.definitions[id].beats:
			var view: Dictionary = _seek(float(beat[0])+1.0); _check(presentation.sync(view,view.active.t),"source beat has presentable bank "+id)
			_check(presentation.metrics().active_id == id,"correct distinct scene at source beat "+id); report.beat_views += 1
		report.paths.append({"id":id,"duration_ms":duration,"samples":samples,"maximum_visual_offset_px":maximum_offset,"blocked":blocked})
	_check(report.paths.size() == 6 and report.beat_views == 24,"all six canonical trajectories and24 timed beats inspected")
func _audit_roads() -> void:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for road: Dictionary in state.content.world.roadSegments:
		var horizontal: bool = road.axis == "h"
		var from := Vector2(road.x+18 if horizontal else road.x+road.w*0.5,road.y+road.h*0.5 if horizontal else road.y+18)
		var to := Vector2(road.x+road.w-18 if horizontal else road.x+road.w*0.5,road.y+road.h*0.5 if horizontal else road.y+road.h-18)
		var size: Vector3 = Presentation.ENVELOPES.runaway_mattress
		if not horizontal: size = Vector3(size.z,size.y,size.x)
		# Continuous conservative union includes the source y sine's full±3px.
		size.z += 0.24
		var shape := BoxShape3D.new(); shape.size = size
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.margin = 0.002; query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY,Content.to_world(from,0.055+size.y*0.5)); query.motion = Content.to_world(to)-Content.to_world(from)
		var collisions: Array[Dictionary] = []
		for hit: Dictionary in space.intersect_shape(query,32): collisions.append({"owner":str(hit.collider.get_meta("source_owner",hit.collider.name)),"phase":"start"})
		var fraction: PackedFloat32Array = space.cast_motion(query)
		if fraction.size() == 2 and fraction[0] < 0.999999:
			var at: Vector3 = query.transform.origin+query.motion*minf(1.0,float(fraction[1])+0.00001)
			query.transform.origin = at; query.motion = Vector3.ZERO
			var hits: Array[Dictionary] = space.intersect_shape(query,32)
			for hit: Dictionary in hits: collisions.append({"owner":str(hit.collider.get_meta("source_owner",hit.collider.name)),"phase":"corridor","fraction":fraction[0],"point":at})
			if hits.is_empty(): collisions.append({"owner":"interval_collision","fraction":fraction[0],"point":at})
		# Preserve the original collision evidence; approved physical mapping is
		# certified independently below, never by ignoring these world solids.
		report.roads.append({"id":road.id,"axis":road.axis,"from_source":from,"to_source":to,"blocked":collisions})
	_check(report.roads.size() == 28,"all28 mattress source road corridors inspected continuously")
	var mapped: Dictionary = paths.report(); report.mapped_roads = mapped
	_check(mapped.complete and mapped.ok and mapped.roads.size() == 28,"all28 bounded cached lanes pass actual interval casts "+str(mapped.get("failures",[])))
	for lane: Dictionary in mapped.roads:
		_check(lane.ok,"certified mapped lane "+str(lane.id)+" "+str(lane.get("physics",lane.get("reason"))))
		_check(lane.maximum_offset_px <= 100.001,"mapped lane preserves100px bound "+str(lane.id))
		var points: PackedVector2Array = lane.points
		for index: int in range(1,points.size()): _check(points[index].x > points[index-1].x,"lane retains source longitudinal order "+str(lane.id))
func _solid(at: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0; body.set_meta("source_owner","incident_bump_fixture")
	var shape := BoxShape3D.new(); shape.size = size; var child := CollisionShape3D.new(); child.shape = shape; body.add_child(child); world.add_child(body); body.position = at
	adapter.invalidate_placement_cache(); return body
func _bump_at(center: Vector2) -> Vector2:
	_place(center); state.s.shake = 0
	state.s.incident = {"id":"runaway_mattress","t":5000.0,"beat":0,"duration":25000.0,"actors":[{"kind":"mattress","x":center.x,"y":center.y,"sx":center.x,"sy":center.y-sin(5000.0/240.0)*3,"ex":center.x+0.000001,"ey":center.y-sin(5000.0/240.0)*3}],"bumped":false,"road":{"axis":"h"}}
	incidents._update_active(state.s.incident)
	return Vector2(state.p.x,state.p.y)
func _physical_bumps() -> void:
	var mapped_owner: RefCounted = incidents
	incidents = Incidents.new(state,adapter,comms) # Original14px force, independent of lane alignment fixture.
	var center := Vector2(1080,960)
	_check(adapter._clear({"id":"player","w":state.p.w,"h":state.p.h},center-Vector2(state.p.w,state.p.h)*0.5,false),"physical mattress fixture starts in clear actual world")
	var before: Vector2 = center-Vector2(state.p.w,state.p.h)*0.5; var after: Vector2 = _bump_at(center)
	_check(absf(after.x-before.x-14.0) < 0.001 and absf(after.y-before.y) < 0.001,"unobstructed real capsule retains exact14px source push")
	for distance: float in [0.49,0.78]:
		var wall := _solid(Content.to_world(center,1.1)+Vector3(distance+0.05,0,0),Vector3(0.1,2.2,1.5))
		await physics_frame; await physics_frame
		after = _bump_at(center)
		_check(after.x >= before.x and after.x-before.x < 14.0,"standing wall shortens actual mattress push "+str(distance))
		_check(adapter._clear({"id":"player","w":state.p.w,"h":state.p.h},after,false),"returned bump endpoint remains clear "+str(distance))
		var once: Vector2 = after; incidents._update_active(state.s.incident)
		_check(Vector2(state.p.x,state.p.y) == once and state.s.incident.bumped and state.s.shake == 5,"real wall contact does not repeat bump or suppress receipt")
		wall.free(); adapter.invalidate_placement_cache(); await physics_frame
	incidents = mapped_owner
func _mapped_contacts() -> void:
	if not paths.ready(): return
	_start("runaway_mattress")
	var view: Dictionary = _seek(6950.0); var actor: Dictionary = view.active.actors[0]
	var physical := Vector2(actor.x,actor.y)
	var q: float = view.active.t/view.active.duration; var ease: float = q*q*(3-2*q)
	var source := Vector2(actor.sx+(actor.ex-actor.sx)*ease,actor.sy+(actor.ey-actor.sy)*ease+sin(view.active.t/240.0)*3)
	_check(physical.distance_to(source) > 0.01 and physical.distance_to(source) <= 100,"real news-box counterexample uses bounded physical lane")
	presentation.sync(view,view.active.t)
	_check(Content.to_source(presentation._banks.runaway_mattress.position).distance_to(physical) < 0.001,"mesh and authoritative mapped point coincide")
	var direction := Vector2.ZERO
	for candidate: Vector2 in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		var center: Vector2 = physical+candidate*25.0
		if adapter._clear({"id":"player","w":state.p.w,"h":state.p.h},center-Vector2(state.p.w,state.p.h)*0.5,false): direction = candidate; break
	_check(direction != Vector2.ZERO,"mapped bump has an actual clear strict-boundary witness")
	if direction == Vector2.ZERO: return
	_place(physical+direction*25.0); state.s.incident.bumped = false; incidents._update_active(state.s.incident)
	_check(not state.s.incident.bumped,"exact25px from mapped body refuses bump")
	_place(physical+direction*24.99); state.s.incident.bumped = false; state.s.shake = 0
	var before := Vector2(state.p.x,state.p.y); incidents._update_active(state.s.incident)
	var after := Vector2(state.p.x,state.p.y)
	_check(state.s.incident.bumped and state.s.shake == 5,"inside25px from mapped body performs original one-shot effect")
	_check(after.distance_to(before) <= 14.001 and adapter._clear({"id":"player","w":state.p.w,"h":state.p.h},after,false),"mapped bump retains bounded actual player sweep")
	incidents._update_active(state.s.incident); _check(Vector2(state.p.x,state.p.y) == after,"mapped mattress cannot push twice")
func _mapper_inputs() -> void:
	if not paths.ready(): return
	for road: Dictionary in state.content.world.roadSegments:
		var horizontal: bool = road.axis == "h"
		var low: float = float(road.x if horizontal else road.y)+18.0; var high: float = float(road.x+road.w if horizontal else road.y+road.h)-18.0
		var middle: float = float(road.y)+float(road.h)*0.5 if horizontal else float(road.x)+float(road.w)*0.5
		for direction: int in [-1,1]:
			var a: float = low if direction == 1 else high; var b: float = high if direction == 1 else low
			for ms: float in [0.0,1800.001,6250.0,12500.0,18750.0,25000.0,25049.0]:
				var q: float = minf(1.0,ms/25000.0); var ease: float = q*q*(3-2*q)
				var actor := {"kind":"mattress","sx":a if horizontal else middle,"sy":middle if horizontal else a,"ex":b if horizontal else middle,"ey":middle if horizontal else b}
				var incident := {"id":"runaway_mattress","road":road.duplicate(true),"duration":25000.0,"t":ms,"actors":[actor],"dir":direction}
				var source := Vector2(actor.sx+(actor.ex-actor.sx)*ease,actor.sy+(actor.ey-actor.sy)*ease+sin(ms/240.0)*3)
				var before: Dictionary = incident.duplicate(true); var mapped: Dictionary = paths.map_mattress(incident,source)
				_check(mapped.ok and incident == before,"canonical road/source point maps without mutation "+str(road.id))
				if not mapped.ok: continue
				_check(mapped.point.distance_to(source) <= 100.001 and (mapped.point.x == source.x if horizontal else mapped.point.y == source.y),"mapping preserves actual source longitudinal position and lateral budget "+str(road.id))
				actor.x = mapped.point.x; actor.y = mapped.point.y
				var view := {"active":incident,"paper_ms":0,"wet_ms":0}; presentation.sync(view,ms)
				_check(presentation.inspect(view).ok,"actual mapped endpoint/interior collider proof "+str(road.id))
				_check(not paths.map_mattress(incident,source+Vector2(0.02,0.02)).ok,"caller cannot smuggle an uncertified source point "+str(road.id))
				var wrong: Dictionary = incident.duplicate(true); wrong.road.x += 1
				_check(not paths.map_mattress(wrong,source).ok,"valid road ID cannot authorize altered road geometry")
				wrong = incident.duplicate(true); wrong.actors[0].sx = NAN
				_check(not paths.map_mattress(wrong,source).ok,"nonfinite source endpoint refuses purely")
func _bounded_lifecycle() -> void:
	var initial: Dictionary = presentation.metrics()
	_check(initial.banks == 6 and initial.receipt_sheets == 12 and initial.pigeon_counts == {"park":6,"luggage":3},"bounded authored inventory exact")
	for cycle: int in range(3):
		for id: String in Incidents.IDS:
			_start(id); var view: Dictionary = _seek(15000); presentation.sync(view,15000); presentation.clear()
	_check(presentation.metrics().nodes == initial.nodes,"repeated scenes reuse exact mesh/node pool")
	_check(not presentation.sync({"active":{"id":"invented"}},0) and not presentation.sync({"active":null},NAN),"invalid display input refused")
	state.fresh(); incidents.reset_session("fresh"); presentation.sync(incidents.visual_snapshot(),0)
	_check(presentation.metrics().active_id == "","fresh epoch has no stale scene mesh")
	for child: Node in presentation.find_children("*","CollisionObject3D",true,false): _check(false,"incidents cannot create standing physics or interaction objects "+str(child.name))
func _run() -> void:
	state = State.new(); props = Props.new(state); comms = Comms.new(state,props,_unix)
	world = World.new(); root.add_child(world); world.build(); adapter = Adapter.new(world,state)
	incidents = Incidents.new(state,adapter,comms); presentation = Presentation.new(); root.add_child(presentation)
	_check(presentation.build(world).ok and incidents.ready(),"actual world/source/comms/presenter composition ready")
	state.s.mode = "playing"
	await physics_frame; await physics_frame
	paths = PathMap.new(); var before: Dictionary = state.snapshot(); var events: Array = state.events.duplicate(true); var seed_before: int = state.rng_seed
	var plan: Dictionary = paths.build(world)
	_check(state.snapshot() == before and state.events == events and state.rng_seed == seed_before,"actual path certification consumes no state/history/RNG")
	_check(plan.ok and incidents.bind_path_owner(paths),"model binds only a complete certified path owner "+str(plan.get("failures",[])))
	_audit_canonical(); _audit_roads(); await _physical_bumps(); _mapped_contacts(); _mapper_inputs(); _bounded_lifecycle()
	report.complete = true; report.ok = failures.is_empty(); report.failures = failures; report.metrics = presentation.metrics()
	presentation.record_route_report(report)
	var directory: String = ProjectSettings.globalize_path("res://../.build/full-port/p14c"); DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("incident-clearance.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
	else: _check(false,"clearance evidence file writable")
	for failure: String in failures: push_error(failure)
	print("3D INCIDENT PRESENTATION GATE: %s (%d checks;6 trajectories/24beats/28 corridors; Runtime OFF)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	world.free(); presentation.free(); quit(0 if failures.is_empty() else 1)
