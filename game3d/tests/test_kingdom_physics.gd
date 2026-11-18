extends SceneTree
## Physical campaign access, not a direct-damage substitute for competent combat.
const World = preload("res://scripts/full_neighborhood.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Content = preload("res://scripts/content_catalog.gd")
const State = preload("res://scripts/game_state.gd")
const Campaign = preload("res://scripts/campaign_system.gd")
const Office = preload("res://scripts/office_campaign.gd")
const Kingdom = preload("res://scripts/kingdom_campaign.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Bosses = preload("res://scripts/boss_system.gd")
const Days = preload("res://scripts/day_system.gd")
const Progression = preload("res://scripts/progression_routes.gd")
const Travel = preload("res://scripts/travel_system.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const Communications = preload("res://scripts/communications_system.gd")
const Props = preload("res://scripts/prop_state.gd")
const Roster = preload("res://scripts/character_roster.gd")
var world: Node3D
var adapter: RefCounted
var bundle: Dictionary = {}
var checks: int = 0
var failures: Array[String] = []
var walked_metres: float = 0.0
var walk_segments: int = 0
var rigs: Array[Node3D] = []
var resident_detours: int = 0
var route_blockers: Dictionary = {}
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _unix() -> float: return 1763424000000.0
func _compose() -> void:
	var state := State.new(); adapter.bind_state(state)
	var progression := Progression.new(state); var props := Props.new(state)
	var comms := Communications.new(state,props,_unix); var memory := Memory.new(state)
	var travel := Travel.new(state,adapter); var campaign := Campaign.new(state,adapter,progression,travel,comms,memory)
	var days := Days.new(state,adapter,progression,travel,campaign,comms,_unix)
	campaign.bind_day_owner(days); travel.bind_day_owner(days)
	var office := Office.new(state,adapter,campaign,progression,travel); var combat := Combat.new(state,adapter)
	var kingdom := Kingdom.new(state,adapter,campaign,office,combat,memory,comms,days)
	var bosses := Bosses.new(state,combat,kingdom); combat._domain_ref = weakref(bosses)
	bundle = {"state":state,"progression":progression,"props":props,"comms":comms,"memory":memory,"travel":travel,"campaign":campaign,"days":days,"office":office,"combat":combat,"kingdom":kingdom,"bosses":bosses}
	state.s.mode = "playing"; state.s.day = 6; state.s.office.owned = true; state.s.office.upgrades.radio = true
	_check(kingdom.ready() and days.ready(),"actual world and all real campaign dependencies ready")
func _place(center: Vector2) -> void:
	bundle.state.p.x = center.x-float(bundle.state.p.w)*0.5; bundle.state.p.y = center.y-float(bundle.state.p.h)*0.5
func _position() -> Vector2: return Vector2(bundle.state.p.x,bundle.state.p.y)
func _standing(center: Vector2) -> bool:
	var body: Dictionary = bundle.state.p.duplicate(); body.id = "player"
	return adapter._clear(body,center-Vector2(body.w,body.h)*0.5,false)
func _stage(id: String,marks: int = 0) -> void:
	bundle.kingdom.abort(false,false)
	if id.begins_with("kingdom_mark:") or (id.begins_with("kingdom_banner:") and id != "kingdom_banner:throne"):
		var clan: Dictionary = bundle.kingdom._by_id[id.split(":")[1]]
		bundle.state.s.kingdom = Campaign.normalize_kingdom({"stage":clan.marksStage,"marks":marks})
	elif id == "kingdom_banner:throne": bundle.state.s.kingdom = Campaign.normalize_kingdom({"stage":"emperor_gate"})
	bundle.state.s.mode = "playing"; bundle.state.p.stunT = 0
func _command(id: String) -> bool:
	return bundle.kingdom.use_door(id).ok if id.begins_with("kingdom:") else bundle.kingdom.use_target(id).ok
func _source_center(id: String) -> Vector2:
	var parts: PackedStringArray = id.split(":")
	if parts[0] == "kingdom":
		for door: Dictionary in bundle.kingdom.doors:
			if door.id == parts[1]: return Vector2(door.x+door.w*0.5,door.y+door.h*0.5)
	if id == "kingdom_banner:throne": return Vector2(bundle.kingdom.emperor.banner.x,bundle.kingdom.emperor.banner.y)
	var clan: Dictionary = bundle.kingdom._by_id[parts[1]]
	var point: Dictionary = clan.marks[int(parts[2])] if parts[0] == "kingdom_mark" else clan.banner
	return Vector2(point.x,point.y)
func _boundary_direction(id: String,reach: float) -> Vector2:
	var center: Vector2 = _source_center(id)
	for direction: Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		var near: Vector2 = center+direction*(reach-0.01)
		if not _standing(near) or not _standing(center+direction*reach): continue
		_place(near)
		if adapter.can_reach_target(id): return direction
	return Vector2.ZERO
func _solid(center: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0
	body.set_meta("source_owner","kingdom_physics_fixture")
	var shape := BoxShape3D.new(); shape.size = size
	var child := CollisionShape3D.new(); child.shape = shape; body.add_child(child)
	world.add_child(body); body.global_position = center
	adapter.invalidate_placement_cache(); return body
func _range_and_los() -> void:
	var targets: Array[Dictionary] = []
	for door: Dictionary in bundle.kingdom.doors: targets.append({"id":"kingdom:"+str(door.id),"reach":44.0})
	for clan: Dictionary in bundle.kingdom.clans:
		for index: int in range(3): targets.append({"id":"kingdom_mark:%s:%d" % [clan.id,index],"reach":58.0})
		targets.append({"id":"kingdom_banner:"+str(clan.id),"reach":72.0})
	targets.append({"id":"kingdom_banner:throne","reach":72.0})
	_check(targets.size() == 17,"all9 corrections4 doors4 banners included")
	for target: Dictionary in targets:
		var id: String = target.id; var reach: float = target.reach
		_stage(id,7 if id.begins_with("kingdom_banner:") else 0)
		var service: Dictionary = world.service_points[id]; var center: Vector2 = _source_center(id)
		_check(service.source_point == center,"world retains exact raw source center "+id)
		_check(is_equal_approx(service.reach,reach*0.04),"world/source reach agrees "+id)
		_check(service.approach.is_finite() and _standing(Content.to_source(service.approach)),"real player capsule fits canonical approach "+id)
		_place(Content.to_source(service.approach)); _check(adapter.can_reach_target(id),"canonical approach has actual eye ray "+id)
		var direction: Vector2 = _boundary_direction(id,reach)
		_check(direction != Vector2.ZERO,"clear cardinal strict-boundary witness exists "+id)
		if direction == Vector2.ZERO: continue
		_place(center+direction*reach)
		var source_distance: float = bundle.state.player_center().distance_to(center)
		var world_at: Vector3 = Content.to_world(bundle.state.player_center())
		var world_distance: float = Vector2(world_at.x,world_at.z).distance_to(Vector2(service.target.x,service.target.z))
		_check(source_distance == reach,"boundary witness retains exact source distance "+id)
		_check(not adapter.can_reach_target(id),"adapter rejects exact source radius "+id+" source="+str(source_distance)+" world="+str(world_distance)+" reach="+str(service.reach))
		_check(not _command(id),"model independently rejects exact source radius "+id)
		_place(center+direction*(reach+0.01)); _check(not _command(id),"beyond source radius rejects "+id)
		_place(center+direction*(reach-0.01)); _check(adapter.can_reach_target(id),"inside source radius has actual LOS "+id)
		var before: Dictionary = bundle.state.snapshot(); var actors: Array = bundle.state.npcs.duplicate(true)
		var eye: Vector3 = Content.to_world(bundle.state.player_center(),Adapter.FEET+1.63)
		var blocker := _solid(eye.lerp(service.target,0.5),Vector3(0.24,0.4,0.24))
		await physics_frame; await physics_frame
		_check(not adapter.can_reach_target(id) and not _command(id),"unrelated live solid blocks command "+id)
		_check(bundle.state.snapshot() == before and bundle.state.npcs == actors,"LOS rejection leaves source state/actors unchanged "+id)
		blocker.free(); adapter.invalidate_placement_cache(); await physics_frame
		_check(_command(id),"removing physical obstruction restores exact command "+id)
		bundle.kingdom.abort(false,false)
func _resident_aware_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	# World routes describe buildings. The test controller must also walk around
	# actual residents, which stay stationary here because this is not an AI tick.
	# Keep source endpoints and certify each optional detour with production sweeps.
	var base: PackedVector3Array = world.find_route(from,to)
	if base.size() < 2: return base
	var half := Vector2(bundle.state.p.w,bundle.state.p.h)*0.5
	var peers: Array[Dictionary] = adapter._contact_peers(bundle.state.p)
	var blocked: bool = false
	for index: int in range(1,base.size()):
		var source_a: Vector2 = Content.to_source(base[index-1])-half
		var motion: Vector2 = Content.to_source(base[index])-half-source_a
		var body := {"id":"player","x":source_a.x,"y":source_a.y,"w":bundle.state.p.w,"h":bundle.state.p.h}
		for peer: Dictionary in peers:
			var one_peer: Array[Dictionary] = [peer]
			var hit: Dictionary = Adapter.Contact.first_hit(body,source_a,motion,one_peer)
			if not hit.is_empty(): blocked = true; route_blockers[str(peer.id)] = true
	if not blocked: return base
	resident_detours += 1
	var points: Array[Vector3] = [from,to]
	for point: Vector3 in base:
		if point not in points: points.append(point)
	for peer: Dictionary in peers:
		var center := Vector2(peer.x+peer.w*0.5,peer.y+peer.h*0.5)
		var at: Vector3 = Content.to_world(center,Adapter.FEET)
		var nearby: bool = false
		for index: int in range(1,base.size()):
			if Geometry3D.get_closest_point_to_segment(at,base[index-1],base[index]).distance_to(at) < 3.0:
				nearby = true; break
		if not nearby: continue
		var extent: Vector2 = half+Vector2(peer.w,peer.h)*0.5+Vector2(2,2)
		for sign_x: float in [-1,1]:
			for sign_y: float in [-1,1]:
				var candidate: Vector3 = Content.to_world(center+extent*Vector2(sign_x,sign_y),Adapter.FEET)
				if candidate not in points: points.append(candidate)
	var graph := AStar2D.new()
	for index: int in range(points.size()):
		var source: Vector2 = Content.to_source(points[index])-half
		var body := {"id":"player","x":source.x,"y":source.y,"w":bundle.state.p.w,"h":bundle.state.p.h}
		if adapter._clear(body,source,false) and adapter._peer_clear(body,source,peers):
			graph.add_point(index,Vector2(points[index].x,points[index].z))
	if not graph.has_point(0) or not graph.has_point(1): return PackedVector3Array()
	for a: int in range(points.size()):
		if not graph.has_point(a): continue
		var source_a: Vector2 = Content.to_source(points[a])-half
		var body := {"id":"player","x":source_a.x,"y":source_a.y,"w":bundle.state.p.w,"h":bundle.state.p.h}
		for b: int in range(a+1,points.size()):
			if not graph.has_point(b): continue
			var source_b: Vector2 = Content.to_source(points[b])-half
			var moved: Dictionary = adapter.move_body(body,source_b)
			if not moved.blocked and not moved.get("body_contact",false) and moved.position.distance_to(source_b) < 0.005:
				graph.connect_points(a,b)
	var result := PackedVector3Array()
	for index: int in graph.get_id_path(0,1): result.append(points[index])
	return result

func _walk(to: Vector3,label: String) -> bool:
	var from: Vector3 = Content.to_world(bundle.state.player_center(),0.06)
	var route: PackedVector3Array = _resident_aware_route(from,to)
	_check(route.size() >= 2,"source progression route exists "+label+" "+str(world.last_route_metrics))
	if route.size() < 2: return false
	_check(route[0] == from and route[-1] == to,"resident detour preserves exact source service/exterior endpoints "+label)
	var travelled: float = 0.0
	var peers_clear: bool = true
	for waypoint: Vector3 in route:
		var goal: Vector2 = Content.to_source(waypoint)
		var reached: bool = false
		var last_result: Dictionary = {}
		for step: int in range(24000):
			var offset: Vector2 = goal-bundle.state.player_center()
			if offset.length() < 0.05: reached = true; break
			var before: Vector2 = _position()
			var motion: Vector2 = offset.normalized()*minf(6.875,offset.length())
			var result: Dictionary = adapter.move_body(bundle.state.p,before+motion)
			last_result = result.duplicate(true)
			if result.position.distance_to(before) < 0.0001: break
			bundle.state.p.x = result.position.x; bundle.state.p.y = result.position.y
			peers_clear = peers_clear and adapter._peer_clear(bundle.state.p,result.position,adapter._contact_peers(bundle.state.p))
			travelled += result.position.distance_to(before)*0.04; walk_segments += 1
		_check(reached,"actual capsule sweep reaches waypoint "+label+" at "+str(goal))
		if not reached:
			var nearby: Array[Dictionary] = []
			for peer: Dictionary in adapter._contact_peers(bundle.state.p):
				var center := Vector2(peer.x+peer.w*0.5,peer.y+peer.h*0.5)
				var distance: float = center.distance_to(bundle.state.player_center())
				if distance <= 150.0:
					nearby.append({"id":peer.id,"center":center,"width":peer.w,"depth":peer.h,"distance":distance,"neutral":peer.neutral})
			var contact: Dictionary = Adapter.Contact.first_hit(bundle.state.p,_position(),goal-bundle.state.player_center(),adapter._contact_peers(bundle.state.p))
			print("KINGDOM WALK OBSTRUCTION: ",JSON.stringify({"label":label,"goal":goal,"actual_center":bundle.state.player_center(),"last_sweep":last_result,"static_clear":_standing(bundle.state.player_center()),"next_actor_contact":contact,"nearby":nearby}))
			return false
	walked_metres += travelled
	_check(peers_clear,"every real walked position remains outside live resident envelopes "+label)
	_check(_standing(bundle.state.player_center()),"walk endpoint remains physically clear "+label)
	return true
func _zone(id: String) -> Dictionary:
	for zone: Dictionary in bundle.state.content.world.zones:
		if zone.id == id: return zone
	return {}
func _outside(zone: Dictionary,near: Vector2) -> Vector3:
	var candidates: Array[Vector2] = []
	for fraction: float in [0.5,0.25,0.75,0.1,0.9]:
		candidates.append(Vector2(zone.x-20,zone.y+zone.h*fraction)); candidates.append(Vector2(zone.x+zone.w+20,zone.y+zone.h*fraction))
		candidates.append(Vector2(zone.x+zone.w*fraction,zone.y-20)); candidates.append(Vector2(zone.x+zone.w*fraction,zone.y+zone.h+20))
	candidates.sort_custom(func(a: Vector2,b: Vector2): return a.distance_squared_to(near) < b.distance_squared_to(near))
	for candidate: Vector2 in candidates:
		if _standing(candidate): return Content.to_world(candidate,0.06)
	return Vector3.INF
func _cleanup_rigs() -> void:
	for rig: Node3D in rigs:
		adapter.unregister_body(str(rig.get_meta("actor_id"))); rig.free()
	rigs.clear()
func _inspect_encounter(definition: Dictionary,is_emperor: bool) -> void:
	var expected: Array[Dictionary] = bundle.kingdom._battle_records(definition,is_emperor)
	var ids: Dictionary = {}
	for original: Dictionary in expected:
		var actor: Dictionary = bundle.combat.actor(original.id)
		_check(not actor.is_empty() and not ids.has(original.id),"unique accepted encounter actor "+str(original.id)); ids[original.id] = true
		if actor.is_empty(): continue
		var visual: StringName = Roster.visual_for_actor(actor); var profile: Dictionary = Roster.definition(visual)
		_check(not visual.is_empty() and not profile.is_empty(),"source encounter identity has real visual "+str(actor.id))
		if profile.is_empty(): continue
		_check(is_equal_approx(adapter._height(actor.id,actor),profile.height),"preappend placement uses exact profile height "+str(actor.id))
		_check(Vector2(actor.x,actor.y).distance_to(Vector2(original.x,original.y)) <= 100.0001,"accepted encounter remains within source recovery bound "+str(actor.id))
		_check(adapter._clear(actor,Vector2(actor.x,actor.y),false),"accepted encounter clears actual world with full height "+str(actor.id))
		var rig: Node3D = Roster.create(visual)
		_check(rig != null,"actual rig instantiates "+str(actor.id))
		if rig == null: continue
		world.add_child(rig); rig.position = Content.body_position(actor,Adapter.FEET); rig.set_meta("actor_id",actor.id); rigs.append(rig)
		adapter.register_body(actor.id,rig,profile.height)
		_check(rig.has_node("Skeleton") and rig.get_meta("height") == profile.height,"rig skeleton/height matches physics profile "+str(actor.id))
		_check(adapter._clear(actor,Vector2(actor.x,actor.y),false),"registered rig preserves the same standing clearance "+str(actor.id))
	var boss: Dictionary = bundle.combat.actor(definition.bossId)
	var saved: Array = bundle.state.s.dayPendingPlacements.duplicate(true)
	bundle.state.s.dayPendingPlacements.clear()
	for index: int in range(64): bundle.state.s.dayPendingPlacements.append(bundle.days._pending("inheritance",{"id":"cp_inheritance_%d" % index,"x":500.0,"y":500.0,"amt":500,"isInheritance":true,"collected":false},6))
	var before: Dictionary = bundle.state.snapshot(); var hp: float = boss.hp
	_check(not bundle.kingdom.can_finish_actor(boss.duplicate(true)),"real Day capacity refuses completion before damage "+str(boss.id))
	_check(bundle.state.snapshot() == before and boss.hp == hp,"capacity preflight is pure with actual encounter "+str(boss.id))
	bundle.state.s.dayPendingPlacements.assign(saved)
func _progression_and_escape() -> void:
	_compose(); _place(Content.to_source(world.service_points.office.approach))
	var encounters: Array[Dictionary] = []; encounters.assign(bundle.kingdom.clans); encounters.append(bundle.kingdom.emperor)
	for definition: Dictionary in encounters:
		var is_emperor: bool = definition.bossId == "curb_emperor"
		var banner: String = "kingdom_banner:throne" if is_emperor else "kingdom_banner:"+str(definition.id)
		if is_emperor:
			bundle.state.s.kingdom = Campaign.normalize_kingdom({"stage":"anoint"})
			_check(_walk(world.service_points["smoke:block"].approach,"royal Block return"),"Block anoint reachable after third court")
			bundle.state.p.rocks = 1; bundle.state.p.soapRocks = 0
			_check(bundle.memory.smoke("block").ok and bundle.state.s.kingdom.stage == "emperor_gate","actual physical Block consumes sole real anointing rock")
		else:
			_stage(banner,0)
			for index: int in range(3):
				var id: String = "kingdom_mark:%s:%d" % [definition.id,index]
				_check(_walk(world.service_points[id].approach,id),"required correction has continuous real walk "+id)
				_check(_command(id),"walked correction commits once "+id)
		_check(_walk(world.service_points[banner].approach,banner),"required banner has continuous real walk "+banner)
		_check(_command(banner),"real banner stages all3 arena bodies "+banner)
		if not bundle.state.s.bossActive: continue
		_inspect_encounter(definition,is_emperor)
		var zone: Dictionary = _zone(definition.zoneId)
		var point: Vector2 = bundle.state.player_center()
		_check(point.x >= zone.x and point.x <= zone.x+zone.w and point.y >= zone.y and point.y <= zone.y+zone.h,"banner approach is inside actual source arena "+banner)
		bundle.kingdom.tick_active(1)
		_check(bundle.state.s.kingdomBattle.escapeT == 0,"inside arena resets source escape timer "+banner)
		var exterior: Vector3 = _outside(zone,point)
		_check(exterior.is_finite(),"source arena has clear exterior "+banner)
		if exterior.is_finite():
			_check(_walk(exterior,"escape "+banner),"real capsule can leave arena "+banner)
			for step: int in range(100): bundle.kingdom.tick_active(50)
			_check(bundle.state.s.bossActive and bundle.state.s.kingdomBattle.escapeT == 5000,"exact5000ms outside does not abort "+banner)
			bundle.kingdom.tick_active(1)
			_check(not bundle.state.s.bossActive and bundle.state.s.kingdomBattle == null,"5001ms outside recesses via real campaign owner "+banner)
		_cleanup_rigs()
		for actor: Dictionary in bundle.state.npcs:
			if actor.get("kingdomGuard",false): _check(adapter._clear(actor,Vector2(actor.x,actor.y),false),"refreshed guard has actual legal physical placement "+str(actor.id))
		_check(bundle.campaign.refresh_forces(),"source force refresh remains valid after physical escape "+banner)
func _staging_obstruction() -> void:
	_compose()
	var encounters: Array[Dictionary] = []; encounters.assign(bundle.kingdom.clans); encounters.append(bundle.kingdom.emperor)
	for definition: Dictionary in encounters:
		var is_emperor: bool = definition.bossId == "curb_emperor"
		var clan: String = "emperor" if is_emperor else str(definition.id)
		var banner: String = "kingdom_banner:throne" if is_emperor else "kingdom_banner:"+clan
		_stage(banner,7)
		var add: Dictionary = bundle.kingdom._battle_records(definition,is_emperor)[1]
		var obstruction := _solid(Content.body_position(add,3),Vector3(14,6,14))
		await physics_frame; await physics_frame
		var before: Dictionary = bundle.state.snapshot(); var actors: Array = bundle.state.npcs.duplicate(true); var events: Array = bundle.state.events.duplicate(true)
		_check(not bundle.kingdom.start_boss(clan),"actual solid rejects obstructed3-body staging "+clan)
		_check(bundle.state.snapshot() == before and bundle.state.npcs == actors and bundle.state.events == events,"physical staging refusal cannot partially commit "+clan)
		obstruction.free(); adapter.invalidate_placement_cache(); await physics_frame
		_check(bundle.kingdom.start_boss(clan),"cleared actual spawn obstruction restores encounter "+clan)
		bundle.kingdom.abort(false,false)
func _run() -> void:
	world = World.new(); root.add_child(world); world.build(); adapter = Adapter.new(world)
	await physics_frame; await physics_frame
	_compose(); await _range_and_los(); _progression_and_escape(); await _staging_obstruction()
	_check(resident_detours > 0 and route_blockers.has("skid_brutus_1") and route_blockers.has("skid_lurch"),"source skid dog and Lurch remain actual static-route blockers; competent walks detour rather than removing contact")
	print("KINGDOM PHYSICAL WALKS: %0.3fm / %0.3fs base-walk geometry; %d actual capsule steps; queries %d; %d resident detours %s" % [walked_metres,walked_metres/5.5,walk_segments,adapter.query_count,resident_detours,str(route_blockers.keys())])
	_cleanup_rigs(); bundle.clear(); adapter = null; world.free(); await process_frame
	if failures.is_empty(): print("3D KINGDOM PHYSICS GATE: PASS (%d checks; actual world/17 service points/4 arenas/12 rigs; competent fight timing remains pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D KINGDOM PHYSICS GATE: FAIL (%d failures/%d checks)" % [failures.size(),checks]); quit(1)
