extends SceneTree
const Contact = preload("res://scripts/actor_contact.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const State = preload("res://scripts/game_state.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Director = preload("res://scripts/actor_director.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Robbery = preload("res://scripts/robbery_system.gd")
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []

class World extends Node3D:
	var service_points: Dictionary = {}
class Domains extends RefCounted:
	var robbery: RefCounted
	func _init(host: RefCounted) -> void: robbery = Robbery.new(host)
	func attempt_robbery(actor: Dictionary) -> bool: return robbery.attempt(actor)

func _initialize() -> void: call_deferred("_run")
func _check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
func _body(id: String,at: Vector2,width: float = 28,depth: float = 34) -> Dictionary:
	return {"id":id,"x":at.x,"y":at.y,"w":width,"h":depth}
func _player_at(host: RefCounted,point: Vector2) -> void:
	host.p.x = point.x; host.p.y = point.y
func _geometry(body: Dictionary) -> Dictionary:
	return {"id":str(body.get("id","player")),"x":body.x,"y":body.y,"w":body.w,"h":body.h}
func _source(host: RefCounted,id: String,point: Vector2) -> Dictionary:
	for row: Dictionary in host.content.actors.base:
		if row.id == id:
			var actor: Dictionary = row.duplicate(true)
			actor.x = point.x; actor.y = point.y; actor.dead = false; actor.aggro = true; actor.chatterCd = 999999.0
			return actor
	return {}
func _box(world: Node3D,point: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0
	world.add_child(body); body.position = point
	var collider := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size
	collider.shape = shape; body.add_child(collider)
	return body

func _run() -> void:
	_pure()
	var world := World.new(); root.add_child(world)
	_box(world,Vector3(0,-0.1,0),Vector3(300,0.2,300))
	var host: RefCounted = State.new(); host.npcs.clear(); host.s.mode = "playing"
	var adapter: RefCounted = Adapter.new(world,host)
	await physics_frame; await physics_frame
	_motion(host,adapter)
	await _walls(host,adapter,world)
	_combat(host,adapter)
	_lifecycle(host,adapter)
	_check(groups == 5,"all five contact groups finish without a script abort")
	world.queue_free(); await process_frame
	if failures.is_empty():
		print("3D ACTOR CONTACT GATE: PASS (%d checks; real casts, symmetric overlap band, source combat/charges, repairs and lifecycle)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D ACTOR CONTACT GATE: FAIL (%d/%d checks)" % [failures.size(),checks]); quit(1)

func _pure() -> void:
	var player := _body("player",Vector2(1000,1000),24,28)
	var peer := _body("lurch",Vector2(1060,997))
	var peers: Array[Dictionary] = [peer]
	_check(Contact.half_extents(player,peer) == Vector2(25,30),"1px source overlap gives player/Lurch25x30 half extents")
	for delta: Vector2 in [Vector2(100,0),Vector2(100,30),Vector2(100,-30),Vector2(1000,0)]:
		var hit: Dictionary = Contact.first_hit(player,Vector2(1000,1000),delta,peers)
		_check(not hit.is_empty() and hit.fraction >= 0 and hit.fraction < 1,"sweep catches high-speed approach "+str(delta))
		if hit.is_empty(): continue
		var endpoint: Vector2 = Vector2(1000,1000)+delta*float(hit.fraction)
		var at: Dictionary = player.duplicate(); at.x = endpoint.x; at.y = endpoint.y
		_check(not Contact.penetrating(player,endpoint,peer) and Combat.overlaps(at,peer),"contact endpoint is outside exclusion but inside actual source melee")
		_check(Contact.first_hit(player,endpoint,delta,peers).get("fraction",1.0) == 0.0,"persistent approach cannot walk farther through contact")
	var tangent_hit: Dictionary = Contact.first_hit(player,Vector2(1037,1000),Vector2(0,100),peers)
	_check(tangent_hit.is_empty(),"exact contact tangent remains free")
	_check(Contact.first_hit(player,Vector2(1037,1000),Vector2(-10,0),peers).is_empty(),"outward knockback remains free")
	var reproduced := _body("player",Vector2(1055.6099,852.6901),24,28)
	var lurch := _body("skid_lurch",Vector2(1051.4454,844.69995))
	var exact: Array[Dictionary] = [lurch]
	_check(Contact.penetrating(reproduced,Vector2(reproduced.x,reproduced.y),lurch),"exported idle60 torso/camera overlap is a real contact regression input")
	var repairs: Array[Vector2] = Contact.repair_candidates(reproduced,Vector2(reproduced.x,reproduced.y),exact)
	_check(not repairs.is_empty() and repairs.size() <= 8 and repairs == Contact.repair_candidates(reproduced,Vector2(reproduced.x,reproduced.y),exact),"repair candidate order is deterministic and bounded")
	for candidate: Vector2 in repairs: _check(not Contact.penetrating(reproduced,candidate,lurch),"each single-peer candidate exits the torso exclusion")
	var coincident := _body("z",Vector2(1000,1000),24,28)
	var same: Array[Dictionary] = [coincident]
	_check(Contact.first_hit(player,Vector2(1000,1000),Vector2(3,0),same).is_empty(),"coincident initial bodies can move outward rather than locking forever")
	_check(Contact.first_hit(player,Vector2(INF,0),Vector2.ONE,peers).is_empty(),"nonfinite pure geometry refuses a hit result")
	var farther := _body("farther",Vector2(1100,997))
	var order_a: Array[Dictionary] = [farther,peer]
	var order_b: Array[Dictionary] = [peer,farther]
	_check(Contact.first_hit(player,Vector2(1000,1000),Vector2(1000,0),order_a) == Contact.first_hit(player,Vector2(1000,1000),Vector2(1000,0),order_b),"first swept contact does not depend on roster ordering")
	_check(Contact.half_extents(_body("tiny",Vector2.ZERO,0.1,0.2),_body("tiny2",Vector2.ZERO,0.1,0.2)).x > 0,"tiny profiles retain positive finite exclusion")
	groups += 1

func _motion(host: RefCounted,adapter: RefCounted) -> void:
	host.npcs.clear(); _player_at(host,Vector2(1000,1000))
	var peer: Dictionary = _source(host,"lurch",Vector2(1060,997)); host.npcs.append(peer)
	var copy: Dictionary = host.p.duplicate(true); var actor_copy: Dictionary = peer.duplicate(true); var seed: int = host.rng_seed
	var moved: Dictionary = adapter.move_body(_geometry(host.p),Vector2(1200,1000))
	_check(moved.body_contact and not moved.blocked and moved.position.x > 1000 and moved.position.x < 1060,"player sweep reaches actor contact without reporting a wall")
	_check(host.p == copy and peer == actor_copy and host.rng_seed == seed,"adapter does not mutate either body/resources/RNG")
	var contact_body: Dictionary = _geometry(host.p); contact_body.x = moved.position.x; contact_body.y = moved.position.y
	_check(Combat.overlaps(contact_body,peer) and not Contact.penetrating(contact_body,moved.position,peer),"player can still be hit at stand-off")
	var back: Dictionary = adapter.move_body(contact_body,moved.position-Vector2(8,0))
	_check(not back.blocked and back.position == moved.position-Vector2(8,0),"source8px knockback escapes contact unchanged")
	var actor_motion: Dictionary = adapter.move_body(_geometry(peer),Vector2(950,997),null,true)
	_check(actor_motion.body_contact and not actor_motion.blocked and actor_motion.position.x > 1000,"actor sweep uses the same player exclusion and does not tunnel")
	var actor_at: Dictionary = peer.duplicate(); actor_at.x = actor_motion.position.x; actor_at.y = actor_motion.position.y
	_check(Combat.overlaps(host.p,actor_at),"actor approach still reaches actual attack overlap")
	for delta: Vector2 in [Vector2(100,60),Vector2(100,-60),Vector2(200,0)]:
		var result: Dictionary = adapter.move_body(_geometry(host.p),Vector2(1000,1000)+delta)
		_check(result.position.distance_to(Vector2(1000,1000)) <= delta.length()+0.002 and not Contact.penetrating(host.p,result.position,peer),"contact slide has no speed gain or body penetration: "+str(delta))
	peer.aggro = false; peer.hostile = false
	var neutral: Dictionary = adapter.move_body(_geometry(host.p),Vector2(1200,1000))
	_check(neutral.body_contact and absf(neutral.position.y-1000) > 1 and not Contact.penetrating(host.p,neutral.position,peer),"neutral head-on encounter spends remaining distance on a safe tangent")
	_check(adapter.navigation_metrics().requests == 0,"peer-only stops never enqueue static navigation work")
	# Reproduce the diagnosed spawn overlap using real static-space checks.
	_player_at(host,Vector2(1055.6099,852.6901)); peer.x = 1051.4454; peer.y = 844.69995
	var repaired: Variant = adapter.clear_placement(_geometry(peer))
	_check(repaired is Vector2 and not Contact.penetrating(peer,repaired,_geometry(host.p)),"real placement repairs the exact idle60 Lurch torso overlap")
	_check(peer.x == 1051.4454 and peer.y == 844.69995,"repair remains an explicit return; source owner commits it")
	_player_at(host,Vector2(2000,2000)); peer.x = 1000; peer.y = 1000
	host.npcs.append(_source(host,"tony",Vector2(1060,1000)))
	var through_actor: Dictionary = adapter.move_body(_geometry(peer),Vector2(1200,1000),null,true)
	_check(not through_actor.blocked and not through_actor.body_contact and through_actor.position == Vector2(1200,1000),"packet introduces no NPC/NPC collision")
	groups += 1

func _walls(host: RefCounted,adapter: RefCounted,world: Node3D) -> void:
	host.npcs.clear(); _player_at(host,Vector2(1000,1000))
	var peer: Dictionary = _source(host,"lurch",Vector2(1060,997)); host.npcs.append(peer)
	var wall: StaticBody3D = _box(world,Content.to_world(Vector2(1032,1014),1.5),Vector3(0.2,3,12))
	await physics_frame; await physics_frame; adapter.invalidate_placement_cache()
	var result: Dictionary = adapter.move_body(_geometry(host.p),Vector2(1200,1000),null,true)
	_check(result.blocked and not result.body_contact and result.position.x < 1032-12,"earlier actual wall wins over a farther peer")
	_check(not adapter.can_hit(host.player_center(),Combat.center(peer),"player",peer.id),"contact policy never bypasses wall LOS")
	host.npcs.clear(); _player_at(host,Vector2(1070,1000)); host.p.hp = host.p.maxHp; host.p.iframes = 0.0
	var charger: Dictionary = _source(host,"brutus",Vector2(1000,998))
	charger.hostile = true; charger.chargeState = "lunge"; charger.chargeT = 1000.0; charger.lungeVx = 1.0; charger.lungeVy = 0.0; charger.attackCd = 0.0
	host.npcs.append(charger)
	var wall_combat: RefCounted = Combat.new(host,adapter)
	var wall_director: RefCounted = Director.new(host,wall_combat)
	var hit_wall: bool = false
	for step: int in range(20):
		wall_director.tick(16.0,float(step+1)*16.0)
		if charger.get("structureChargeHit",false): hit_wall = true; break
	_check(hit_wall and host.p.hp == host.p.maxHp and not charger.get("chargeLanded",false),"real charger wall impact remains a structure hit without through-wall damage")
	wall_director.tick(16.0,1000.0)
	_check(charger.chargeState == "cooldown" and not charger.structureChargeHit,"next source step consumes real wall impact into cooldown")
	wall.queue_free(); await process_frame; await physics_frame; adapter.invalidate_placement_cache()
	# Tight static chamber admits the existing overlapping bodies but no axis repair.
	host.npcs.clear(); host.npcs.append(peer)
	_player_at(host,Vector2(1200,1200)); peer.x = 1198; peer.y = 1197
	var chamber: Array[StaticBody3D] = []
	var center: Vector2 = host.player_center()
	for sign_value: float in [-1,1]:
		chamber.append(_box(world,Content.to_world(center+Vector2(sign_value*17,0),1.5),Vector3(0.08,3,2.0)))
		chamber.append(_box(world,Content.to_world(center+Vector2(0,sign_value*20),1.5),Vector3(2.0,3,0.08)))
	await physics_frame; await physics_frame; adapter.invalidate_placement_cache()
	var old: Vector2 = Vector2(peer.x,peer.y)
	var before: int = adapter.body_repairs_deferred
	var held: Variant = adapter.clear_placement(_geometry(peer))
	_check(held is Vector2 and held == old and adapter.body_repairs_deferred == before+1,"wall-blocked peer repair retains valid placement rather than skipping AI")
	_check(adapter._clear(_geometry(peer),held,false),"deferred repair never displaces the actor into a wall")
	host.p.hp = host.p.maxHp; host.p.iframes = 0.0; peer.attackCd = 0.0
	var trapped_domain := Domains.new(host)
	var trapped_combat: RefCounted = Combat.new(host,adapter,null,trapped_domain)
	var trapped_director: RefCounted = Director.new(host,trapped_combat)
	trapped_director.tick(16.0,16.0)
	_check(host.p.hp < host.p.maxHp and peer.attackCd > 0,"deferred repair does not suppress actual grabber AI or damage")
	for body: StaticBody3D in chamber: body.queue_free()
	await process_frame; await physics_frame; adapter.invalidate_placement_cache()
	groups += 1

func _combat(host: RefCounted,adapter: RefCounted) -> void:
	var domain := Domains.new(host)
	var combat: RefCounted = Combat.new(host,adapter,null,domain)
	var director: RefCounted = Director.new(host,combat)
	var wall_ms: float = 0.0
	for id: String in ["tony","lurch","sherri","brutus"]:
		host.npcs.clear(); _player_at(host,Vector2(1050,1000)); host.p.hp = host.p.maxHp; host.p.iframes = 0.0; host.p.stunT = 0.0; host.p.shakes = 0
		var actor: Dictionary = _source(host,id,Vector2(1000,998)); actor.hostile = true; actor.speed = 1.5; actor.attackCd = 0.0
		if id == "brutus": actor.chargeState = "lunge"; actor.chargeT = 1000.0; actor.lungeVx = 1.0; actor.lungeVy = 0.0
		host.npcs.append(actor)
		var damaged: bool = false
		for step: int in range(70):
			wall_ms += 16.0; host.tick(0.016); director.tick(16.0,wall_ms)
			if host.p.hp < host.p.maxHp: damaged = true; break
		_check(damaged and float(actor.attackCd) > 0.0,id+": real Director/Combat damage reaches player through contact band")
		_check(not actor.get("structureChargeHit",false),id+": body contact is never a fabricated structure hit")
		if id == "brutus": _check(actor.chargeState == "cooldown" and actor.chargeLanded and actor.chargeT == 1400,"charger contact follows source hit cooldown, not wall/dodge path")
		if id == "lurch": _check(actor.grabFreezeT == 200.0 and host.p.stunT >= 500.0,"grabber freeze/stun remains source-authoritative")
		if id == "sherri": _check(actor.attackCd == 700.0,"swarmer retains source700ms contact cooldown")
		host.p.attackCd = 0; host.p.stunT = 0; host.p.weapon = "fists"
		var hp: float = actor.hp
		var swing: Dictionary = combat.attack_player((Combat.center(actor)-host.player_center()).normalized())
		_check(swing.ok and float(actor.hp) < hp,id+": original first-person fist reach still hits the separated actor")
	_check(director.tick(16.0,wall_ms+16.0),"contact adapter leaves Director step contract intact")
	groups += 1

func _lifecycle(host: RefCounted,adapter: RefCounted) -> void:
	host.npcs.clear(); _player_at(host,Vector2(1000,1000)); host.s.dayTime = 0.35
	var peer: Dictionary = _source(host,"pete",Vector2(1060,997)); host.npcs.append(peer)
	for flag: String in ["dead","departed"]:
		peer[flag] = true
		_check(not adapter.move_body(_geometry(host.p),Vector2(1200,1000)).body_contact,"absent actor stops blocking immediately: "+flag)
		peer[flag] = false
	for phase: float in [0.2499,0.25,0.75,0.7501]:
		host.s.dayTime = phase
		var expected: bool = phase >= 0.25 and phase <= 0.75
		_check(bool(adapter.move_body(_geometry(host.p),Vector2(1200,1000)).body_contact) == expected,"night-hidden services use exact source boundary: "+str(phase))
		_check(bool(adapter.move_body(_geometry(peer),Vector2(950,997),null,true).body_contact) == expected,"night-hidden service contact is symmetric: "+str(phase))
	host.s.dayTime = 0.35
	var before: int = host.rng_seed
	var frozen: Dictionary = host.snapshot()
	for step: int in range(12): adapter.move_body(_geometry(host.p),Vector2(1200,1000))
	_check(host.rng_seed == before and host.snapshot() == frozen,"repeated physical queries own no state or gameplay RNG")
	# Exact record-index checks exercise the cache within one process frame.
	var geometry: Dictionary = _geometry(peer)
	_check(adapter._contact_peers(geometry).size() == 1,"indexed live actor retains player peer")
	var builds: int = adapter.contact_index_builds
	for index: int in range(50): adapter._contact_peers(geometry)
	_check(adapter.contact_index_builds == builds,"same-frame unique source roster avoids50 complete scans")
	peer.dead = true
	_check(adapter._contact_peers(geometry).is_empty(),"cached record reads live death immediately")
	var replacement: Dictionary = peer.duplicate(true); replacement.dead = false
	host.npcs[0] = replacement
	_check(adapter._contact_peers(geometry).size() == 1 and adapter.contact_index_builds > builds,"same-size in-place replacement invalidates exact slot")
	replacement.hostile = false; replacement.aggro = false
	_check(adapter._neutral_body(geometry),"neutral response reads current indexed flags")
	var swapped: Dictionary = replacement.duplicate(true); swapped.id = "new_actor"
	host.npcs[0] = swapped
	_check(adapter._indexed_contact_actor("new_actor").id == "new_actor" and adapter._indexed_contact_actor(str(peer.id)).is_empty(),"same-size ID replacement cannot retain departed lookup")
	var replaced_array: Array[Dictionary] = [replacement]
	host.npcs = replaced_array
	_check(is_same(adapter._indexed_contact_actor(str(peer.id)),replacement),"same-size array replacement rebinds original record")
	var duplicate: Dictionary = replacement.duplicate(true); duplicate.dead = true; host.npcs.append(duplicate)
	_check(adapter._contact_peers(geometry).is_empty() and not adapter._contact_index_unique,"malformed duplicate IDs preserve conservative original scan")
	host.npcs.clear(); host.fresh()
	_check(not adapter._indexed_contact_actor("tony").is_empty(),"fresh epoch rebinds canonical roster")
	groups += 1
