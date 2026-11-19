extends SceneTree
## New packet: root runs after the pending PathMap/Incidents hooks are published.
const World = preload("res://scripts/full_neighborhood.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Props = preload("res://scripts/prop_state.gd")
const Communications = preload("res://scripts/communications_system.gd")
const Incidents = preload("res://scripts/incident_system.gd")
const Paths = preload("res://scripts/incident_path_map.gd")
const Corridors = preload("res://scripts/incident_corridors.gd")
const Presentation = preload("res://scripts/incident_presentation.gd")
const STARTS := {"runaway_mattress":Vector2(1080,960),"possum_inventory":Vector2(1080,1510),"laundromat_walkout":Vector2(1640,1200),"yuri_receipt":Vector2(400,300),"park_dry_committee":Vector2(2600,1280),"ticketed_luggage":Vector2(800,2985)}
class FixedState extends "res://scripts/game_state.gd":
	var draws: int = 0
	func random_float() -> float: draws += 1; return 0.4
	func random_index(size: int) -> int: return mini(size-1,int(floor(random_float()*size))) if size > 0 else 0
class EpochWitness extends RefCounted:
	var owner: RefCounted
	var phase: String
	var player_only: bool
	var replacement: Dictionary = {}
	func _init(state: RefCounted,at: String,replace_player: bool) -> void:
		owner = state; phase = at; player_only = replace_player
	func ready() -> bool: return true
	func _replace(at: String) -> void:
		if phase != at: return
		if player_only: owner.p = owner.p.duplicate(true)
		else: owner.s = owner.s.duplicate(true)
		replacement = {"p":owner.p.duplicate(true),"s":owner.s.duplicate(true),"events":owner.events.duplicate(true),"draws":owner.draws}
	func preflight(_candidates: Array) -> Dictionary:
		_replace("preflight"); return {"ok":true,"token":1}
	func activate(_prepared: Dictionary,_incident: Dictionary) -> bool:
		_replace("activate"); return true
	func release() -> bool:
		_replace("release"); return true
	func map_mattress(_incident: Dictionary,point: Vector2) -> Dictionary:
		_replace("map"); return {"ok":true,"point":point}
var world: Node3D
var adapter: RefCounted
var game: RefCounted
var props: RefCounted
var comms: RefCounted
var incidents: RefCounted
var paths: RefCounted
var corridors: RefCounted
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _unix() -> float: return 1763424000000.0
func _place(point: Vector2) -> void: game.p.x = point.x-game.p.w*0.5; game.p.y = point.y-game.p.h*0.5
func _model() -> Dictionary: return {"p":game.p.duplicate(true),"s":game.s.duplicate(true),"npcs":game.npcs.duplicate(true),"events":game.events.duplicate(true),"draws":game.draws}
func _simple_segments() -> Array[Dictionary]:
	var point: Vector3 = Content.to_world(Vector2(1100,1000),0.4)
	return [{"from":point,"to":point+Vector3(1,0,0),"size":Vector3(0.6,0.6,0.6)}]
func _solid(point: Vector3,size: Vector3,owner: String,layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new(); body.collision_layer = layer; body.collision_mask = 0; body.set_meta("source_owner",owner)
	var shape := BoxShape3D.new(); shape.size = size; var child := CollisionShape3D.new(); child.shape = shape; body.add_child(child); world.add_child(body); body.position = point
	if layer == 1: adapter.update_navigation_obstacles(owner,[{"owner":owner,"bounds":AABB(point-size*0.5,size)}])
	return body
func _adapter_contract() -> void:
	var snapshot: Dictionary = adapter.incident_geometry_snapshot(); var before: Dictionary = _model(); var segments: Array[Dictionary] = _simple_segments()
	_check(snapshot.ok and not snapshot.records.is_empty(),"current geometry exposes actual authoritative records")
	_check(adapter.reserve_incident_corridor("test:immutable",snapshot.revision,segments,snapshot.player_epoch,snapshot.state_epoch),"actual clear swept-box corridor reserved")
	var point: Vector3 = segments[0].from; var candidate := AABB(point-Vector3.ONE*0.1,Vector3.ONE*0.2)
	segments[0].from += Vector3(50,0,0); segments[0].to += Vector3(50,0,0)
	_check(not adapter._reservation_clear(candidate),"caller segment mutation cannot alter immutable reservation")
	_check(not adapter.release_incident_corridor("test:other") and not adapter._reservation_clear(candidate),"another owner cannot release active corridor")
	_check(adapter._reservation_clear(AABB(point+Vector3(0,3,0),Vector3.ONE*0.2)),"vertical separation avoids unnecessary prop rejection")
	_place(Vector2(1000,840)); before = _model()
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",Vector2(1100,1000),0) == null,"real source bottle staging refuses occupied incident corridor")
	var relocated: Variant = adapter.stage_interactive_prop("interactive:6","b_bottle",Vector2(1100,1000),100)
	_check(relocated is Vector2 and relocated.distance_to(Vector2(1100,1000)) <= 100 and relocated != Vector2(1100,1000),"same bounded prop search finds a candidate outside reservation")
	_check(_model() == before,"reservation-aware real prop staging preserves model/RNG")
	_check(adapter.release_incident_corridor("test:immutable") and adapter.release_incident_corridor("test:immutable"),"release is idempotent")
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",Vector2(1100,1000),0) == Vector2(1100,1000),"release restores exact source prop candidate")
	before = _model(); snapshot = adapter.incident_geometry_snapshot(); segments = _simple_segments()
	adapter.invalidate_placement_cache()
	_check(not adapter.reserve_incident_corridor("test:stale",snapshot.revision,segments,snapshot.player_epoch,snapshot.state_epoch),"changed actual revision rejects old certificate")
	_check(_model() == before,"revision refusal consumes no model/RNG/history")
	for invalid: Variant in [[{"from":Vector3(NAN,0,0),"to":Vector3.ZERO,"size":Vector3.ONE}],[{"from":point,"to":point,"size":Vector3(-1,1,1)}],[]]:
		snapshot = adapter.incident_geometry_snapshot()
		_check(not adapter.reserve_incident_corridor("test:invalid",snapshot.revision,invalid,snapshot.player_epoch,snapshot.state_epoch),"malformed segment rejects without reservation")
	var wall := _solid(point+Vector3(0.5,0,0),Vector3(0.15,0.6,0.6),"incident_test_wall")
	snapshot = adapter.incident_geometry_snapshot()
	_check(not adapter.reserve_incident_corridor("test:same_frame_writer",snapshot.revision,_simple_segments(),snapshot.player_epoch,snapshot.state_epoch),"new published solid refuses before PhysicsServer transform synchronization")
	await physics_frame; await physics_frame; snapshot = adapter.incident_geometry_snapshot()
	_check(not adapter.reserve_incident_corridor("test:solid",snapshot.revision,_simple_segments(),snapshot.player_epoch,snapshot.state_epoch),"actual standing wall blocks prospective corridor")
	wall.free(); adapter.update_navigation_obstacles("incident_test_wall",[]); await physics_frame
	var actor := _solid(point+Vector3(0.5,0,0),Vector3(0.15,0.6,0.6),"incident_test_actor",2)
	await physics_frame; await physics_frame; snapshot = adapter.incident_geometry_snapshot()
	_check(adapter.reserve_incident_corridor("test:actor",snapshot.revision,_simple_segments(),snapshot.player_epoch,snapshot.state_epoch),"actual actor collision layer is a participant not environmental obstruction")
	adapter.release_incident_corridor("test:actor"); actor.free(); await physics_frame
func _six_preflights() -> void:
	var candidates: Array[Dictionary] = []
	for id: String in Incidents.IDS:
		_place(STARTS[id]); var before: Dictionary = _model(); var candidate: Dictionary = incidents.preview_scene(id)
		_check(not candidate.is_empty() and _model() == before,"prospective scene generation is pure "+id); candidates.append(candidate)
	var before: Dictionary = _model()
	for invalid: Variant in [{},{"id":"possum_inventory","actors":[]},{"id":"park_dry_committee","actors":[],"duration":28000,"t":0,"beat":-1,"bumped":false,"anchor":{"x":NAN,"y":1280},"sprayAngle":-0.4}]:
		_check(not corridors.preflight([invalid]).ok,"malformed prospective payload refuses safely")
	_check(_model() == before,"malformed preflight preserves model and RNG")
	var prepared: Dictionary = corridors.preflight(candidates)
	_check(prepared.ok,"all six actual prospective plans preflight "+str(prepared))
	_check(_model() == before and corridors.status().active.is_empty(),"six-plan preflight changes no clocks/history/RNG and retains no active reservation")
	if not prepared.ok:
		_plan_diagnostics(candidates)
		return
	var stale: Dictionary = prepared.duplicate(true); stale.token += 1
	_check(not corridors.activate(stale,candidates[0]),"altered preparation capability refuses")
	var changed: Dictionary = candidates[0].duplicate(true); changed.actors[0].sx += 1
	_check(not corridors.activate(prepared,changed),"changed prospective source payload refuses")
	adapter.invalidate_placement_cache()
	_check(not corridors.activate(prepared,candidates[0]),"revision change between preparation and activation refuses")
	_check(_model() == before,"stale capability/refused activation preserves source model")
	for candidate: Dictionary in candidates:
		prepared = corridors.preflight([candidate]); _check(prepared.ok,"individual event certifies "+str(candidate.id))
		if not prepared.ok: continue
		_check(corridors.activate(prepared,candidate) and corridors.status().active == candidate.id,"only chosen source event reserves "+str(candidate.id))
		_check(not corridors.activate(prepared,candidate),"preparation token is one-use "+str(candidate.id))
		_check(corridors.release() and corridors.status().active.is_empty(),"event release clears single reservation "+str(candidate.id))
func _plan_diagnostics(candidates: Array[Dictionary]) -> void:
	var snapshot: Dictionary = adapter.incident_geometry_snapshot(); var failures_found: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		var plan: Dictionary = corridors._segments(candidate)
		if not plan.get("ok",false): continue
		var count: int = 0
		for index: int in range(plan.segments.size()):
			var segment: Dictionary = plan.segments[index]
			for obstacle: Dictionary in snapshot.records:
				if adapter._incident_hits_bounds(segment,obstacle.bounds):
					failures_found.append({"scene":candidate.id,"segment":index,"owner":obstacle.owner,"from":Content.to_source(segment.from),"to":Content.to_source(segment.to),"size":segment.size,"obstacle":obstacle.bounds})
					count += 1
					break
			if count >= 5: break
	print("INCIDENT RESERVATION DIAGNOSTIC: ",JSON.stringify(failures_found))
func _model_lifecycle() -> void:
	_check(incidents.bind_corridor_owner(corridors),"real model binds real prepared/reserved geometry owner")
	for interrupted: bool in [false,true]:
		_place(STARTS.runaway_mattress); game.s.incident = null; game.s.bossActive = false
		_check(incidents._start("runaway_mattress") and corridors.status().active == "runaway_mattress","real start reserves before source commit")
		if interrupted:
			game.s.bossActive = true
			_check(incidents.tick_active(50,false,false),"source active clock interrupts reserved event")
		else:
			for step: int in range(500):
				_check(incidents.tick_active(50,false,false),"real mapped tick accepts predicted source time %d" % step)
				if step < 499: _check(game.s.incident is Dictionary and game.s.incident.t == (step+1)*50,"real mapped tick advances source clock exactly once")
		_check(game.s.incident == null and corridors.status().active.is_empty(),"normal/interrupted finish releases synchronously")
		game.s.bossActive = false
	_place(STARTS.runaway_mattress); game.s.incident = null
	var wall := _solid(Content.to_world(Vector2(1100,1022),1.0),Vector3(0.18,2.0,9.5),"incident_complete_corridor_block")
	await physics_frame; await physics_frame
	game.s.incidentT = 1; game.s.flags.incidentDay = 0; game.s.flags.incidentMask = 63; game.s.flags.incidentsToday = 3
	var before: Dictionary = _model()
	_check(not incidents.tick_active(50,false,false),"uncertifiable source activation returns explicit dependency failure")
	_check(_model() == before and game.s.incident == null,"unready preflight preserves timer/day history/RNG with no invisible active scene")
	var queries: int = adapter.query_count
	_check(not incidents.tick_active(50,false,false) and adapter.query_count == queries and _model() == before,"unchanged failed preparation reuses exact revision/source certificate without repeated casts")
	wall.free(); adapter.update_navigation_obstacles("incident_complete_corridor_block",[]); await physics_frame
	_check(incidents.tick_active(50,false,false) and game.s.incident != null and game.draws == before.draws+1,"removing actual obstruction retries same source scheduling draw once")
	_check(corridors.status().active == "runaway_mattress","successful retry reserves before visible activation")
	game.fresh(); props.reset_session("fresh")
	_check(incidents.reset_session("fresh") and corridors.status().active.is_empty(),"fresh epoch drops active reservation and scene")
func _mesh_corners(node: Node,points: Array[Vector3]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = node.mesh.get_aabb()
		for index: int in range(8): points.append(node.global_transform*bounds.get_endpoint(index))
	for child: Node in node.get_children(): _mesh_corners(child,points)
func _pigeon_bounds() -> void:
	var view := Presentation.new(); root.add_child(view); _check(view.build(world).ok,"actual pigeon mesh banks build")
	for id: String in ["park_dry_committee","ticketed_luggage"]:
		_place(STARTS[id]); var active: Dictionary = incidents.preview_scene(id); active.t = 15000
		view.sync({"active":active},15000)
		var birds: Array = view._pigeons[id]
		for bird: Node3D in birds:
			var actual_heading: float = bird.rotation.y
			var headings: Array[float] = [actual_heading]
			for step: int in range(32): headings.append(step*TAU/32.0)
			for heading: float in headings:
				bird.rotation.y = heading
				var points: Array[Vector3] = []; _mesh_corners(bird,points)
				var bounds := AABB(bird.global_position+Vector3(-0.10,0.02,-0.18),Vector3(0.20,0.36,0.36))
				var contained: bool = not points.is_empty()
				for point: Vector3 in points:
					if not bounds.grow(0.00002).has_point(point): contained = false; break
				_check(contained,"rounded pigeon transformed mesh bounds fit unchanged query "+id+" "+str(heading))
	view.free()
func _luggage_counterexample() -> void:
	var owner := FixedState.new(); var own_props := Props.new(owner); var own_comms := Communications.new(owner,own_props,_unix)
	var model := Incidents.new(owner,adapter,own_comms); var active: Dictionary = model.preview_scene("ticketed_luggage")
	active.t = 26600.0
	var x: float = 670.0+(26600.0-14500.0)*650.0/12500.0; var y: float = 2985.0+sin(26600.0/260.0)*3.0
	owner.p.x = x-owner.p.w*0.5; owner.p.y = y-owner.p.h*0.5
	var before: Dictionary = {"p":owner.p.duplicate(true),"s":owner.s.duplicate(true),"events":owner.events.duplicate(true),"draws":owner.draws}
	model._update_active(active)
	_check(is_equal_approx(float(active.actors[0].y),y+28.0),"actual source luggage still uses exact28px player avoidance")
	var source := Vector2(active.actors[0].x,active.actors[0].y); var mapped: Vector2 = Presentation.display_point(active)
	_check(absf(mapped.x-source.x) < 0.001 and source.y-mapped.y > 0 and source.y-mapped.y <= 12.001,"luggage signal arc changes only bounded displayed Y")
	var size: Vector3 = Presentation.ENVELOPES.ticketed_luggage
	var shape := BoxShape3D.new(); shape.size = size
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.collision_mask = 1; query.margin = 0.002
	query.transform = Transform3D(Basis.IDENTITY,Content.to_world(source,0.055+size.y*0.5))
	var signal_hit: bool = false
	for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,16):
		if str(hit.collider.get_meta("source_owner","")) == "decor:9": signal_hit = true
	_check(signal_hit,"unchanged source avoidance physically intersects retained rail signal counterexample")
	query.transform.origin = Content.to_world(mapped,0.055+size.y*0.5)
	_check(world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"approved mapped luggage clears actual retained signal with unchanged box")
	for endpoint: float in [360.0,1200.0,1320.0]:
		var raw := {"id":"ticketed_luggage","t":0.0,"actors":[{"x":endpoint,"y":3013.0}]}
		_check(Presentation.display_point(raw) == Vector2(endpoint,3013),"luggage arc preserves exact endpoint/phase boundary "+str(endpoint))
	var after := {"p":owner.p.duplicate(true),"s":owner.s.duplicate(true),"events":owner.events.duplicate(true),"draws":owner.draws}
	_check(after == before,"visual arc and tight source counterexample consume no authority/RNG/events")
func _epochs() -> void:
	for replace_player: bool in [true,false]:
		var snapshot: Dictionary = adapter.incident_geometry_snapshot(); var segments: Array[Dictionary] = _simple_segments()
		_check(adapter.reserve_incident_corridor("test:epoch",snapshot.revision,segments,snapshot.player_epoch,snapshot.state_epoch),"epoch fixture reserves actual geometry")
		if replace_player: game.p = game.p.duplicate(true)
		else: game.s = game.s.duplicate(true)
		var point: Vector3 = segments[0].from
		_check(adapter._reservation_clear(AABB(point-Vector3.ONE*0.1,Vector3.ONE*0.2)),"replacement of either authority dictionary invalidates stale reservation")
		var current: Dictionary = adapter.incident_geometry_snapshot()
		_check(not adapter.reserve_incident_corridor("test:stale_epoch",current.revision,segments,snapshot.player_epoch,snapshot.state_epoch),"stale p/s identity handles cannot authorize new reservation")
func _callback_epochs() -> void:
	for phase: String in ["preflight","activate","release","map"]:
		for player_only: bool in [true,false]:
			var owner := FixedState.new(); var own_props := Props.new(owner); var own_comms := Communications.new(owner,own_props,_unix)
			var model := Incidents.new(owner,adapter,own_comms)
			owner.s.mode = "playing"; owner.s.incidentT = 1.0; owner.s.flags.incidentDay = owner.s.day
			owner.p.x = 1080-owner.p.w*0.5; owner.p.y = 960-owner.p.h*0.5
			var witness := EpochWitness.new(owner,phase,player_only)
			_check(model.bind_path_owner(witness if phase == "map" else paths),"callback epoch fixture binds mapped owner")
			if phase != "map": _check(model.bind_corridor_owner(witness),"callback epoch fixture binds corridor owner")
			var accepted: bool = false
			if phase == "preflight": accepted = model.tick_active(50,false,false)
			elif phase == "release":
				owner.s.incident = model.preview_scene("runaway_mattress"); accepted = model._finish()
			else: accepted = model._start("runaway_mattress")
			var current := {"p":owner.p.duplicate(true),"s":owner.s.duplicate(true),"events":owner.events.duplicate(true),"draws":owner.draws}
			_check(not witness.replacement.is_empty() and not accepted,"external "+phase+" replacement refuses p-only="+str(player_only))
			_check(current == witness.replacement,"external "+phase+" cannot mutate replacement state/events/RNG p-only="+str(player_only))
func _run() -> void:
	game = FixedState.new(); props = Props.new(game); comms = Communications.new(game,props,_unix)
	world = World.new(); root.add_child(world); world.build(); adapter = Adapter.new(world,game)
	incidents = Incidents.new(game,adapter,comms); paths = Paths.new(); corridors = Corridors.new(paths,adapter,world)
	game.s.mode = "playing"; game.s.hitPause = 0
	await physics_frame; await physics_frame
	_check(paths.build(world).ok and incidents.bind_path_owner(paths),"actual static map ready before dynamic certification")
	_check(corridors.ready(),"real dynamic capabilities present")
	if corridors.ready():
		await _adapter_contract(); _six_preflights(); _pigeon_bounds(); _luggage_counterexample(); await _model_lifecycle(); _epochs(); _callback_epochs()
	for failure: String in failures: push_error(failure)
	print("3D INCIDENT RESERVATION GATE: %s (%d checks; six prospective scenes/actual props/revisions/epochs/source RNG)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	world.free(); quit(0 if failures.is_empty() else 1)
