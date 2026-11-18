extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Director = preload("res://scripts/actor_director.gd")
const Bosses = preload("res://scripts/boss_system.gd")
var checks: int = 0
var failures: Array[String] = []
var completed: int = 0
var groups: int = 0

class FixedState:
	extends "res://scripts/game_state.gd"
	func random_float() -> float: return 0.75
	func random_index(size: int) -> int: return mini(size-1,int(floor(size*0.75))) if size > 0 else 0
class Physics:
	extends RefCounted
	var placeable: bool = true
	var visible: bool = true
	var blocked: bool = false
	var fail_x: float = INF
	var departure: Dictionary = {}
	var departure_calls: int = 0
	func clear_placement(body: Dictionary) -> Variant:
		return Vector2(body.x,body.y) if placeable and float(body.x) != fail_x else null
	func move_body(body: Dictionary, intended: Vector2, _goal: Variant = null, _stop: bool = false) -> Dictionary:
		return {"position":Vector2(body.x,body.y) if blocked else intended,"blocked":blocked}
	func can_hit(_a: Vector2,_b: Vector2,_source: String,_target: String) -> bool: return visible
	func sweep_projectile(_a: Vector2,b: Vector2,_radius: float) -> Dictionary: return {"position":b,"fraction":1.0,"blocked":false}
	func resolve_departure(_body: Dictionary,_edge: String) -> Dictionary:
		departure_calls += 1
		return departure.duplicate(true)
class Domain:
	extends RefCounted
	var bosses_ref: WeakRef
	var host_ref: WeakRef
	var campaign_ready: bool = false
	var campaign_accepts: bool = false
	var campaign_completions: int = 0
	var after_tony: int = 0
	func can_handle_death(body: Dictionary) -> bool: return bosses_ref.get_ref().can_handle_death(body)
	func handle_death(id: String) -> bool: return bosses_ref.get_ref().handle_death(id)
	func spawn_brutus_older() -> bool: return bosses_ref.get_ref().spawn_brutus_older()
	func can_finish_actor(_body: Dictionary) -> bool: return campaign_ready
	func finish_actor(id: String) -> bool:
		if not campaign_accepts: return false
		for body: Dictionary in host_ref.get_ref().npcs:
			if body.id == id: body.dead = true; campaign_completions += 1; return true
		return false
	func after_tony_defeat() -> bool: after_tony += 1; return true

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	_oracle()
	_transactions()
	_restore_and_clocks()
	_fallen_and_phase_properties()
	_departures()
	_check(completed == 39,"all 39 boss fixtures completed without script abort")
	_check(groups == 5,"all five boss test groups completed without script abort")
	if failures.is_empty():
		print("3D BOSS GATE: PASS (%d checks;39 source fixtures;atomic special deaths,phase boundaries,restore repairs;campaign and scene fight tours pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D BOSS GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.00001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i: int in range(a.size()):
			if not _same(a[i],b[i]): return false
		return true
	return a == b
func _fields(actual: Dictionary,expected: Dictionary,label: String,skip: Array = []) -> void:
	for key: String in expected:
		if key in skip: continue
		if key in ["x","y"] and Combat.finite_number(expected[key]) and Combat.finite_number(actual.get(key)):
			_check(absf(float(actual[key])-float(expected[key])) <= 0.0001,label+"."+key+" coordinate")
		else:
			_check(actual.has(key) and _same(actual.get(key),expected[key]),"%s.%s actual=%s expected=%s" % [label,key,str(actual.get(key)),str(expected[key])])
func _actor(id: String,extra: Dictionary = {}) -> Dictionary:
	var body: Dictionary = {"id":id,"name":id,"sprite":id,"x":230.0,"y":230.0,"w":26,"h":30,"hp":100,"maxHp":100,"speed":0.0,"dmg":8,"hostile":false,"aggro":false,"dead":false,"chatterCd":999999.0,"attackCd":0.0}
	body.merge(extra,true); return body
func _rig() -> Dictionary:
	var game := FixedState.new()
	var physics := Physics.new()
	var domain := Domain.new(); domain.host_ref = weakref(game)
	var combat := Combat.new(game,physics,null,domain)
	var bosses := Bosses.new(game,combat,domain); domain.bosses_ref = weakref(bosses)
	var director := Director.new(game,combat)
	game.s.mode = "playing"; game.events.clear()
	return {"game":game,"physics":physics,"domain":domain,"combat":combat,"bosses":bosses,"director":director}
func _count(game: RefCounted,id: String) -> int:
	var total: int = 0
	for body: Dictionary in game.npcs:
		if body.id == id: total += 1
	return total
func _event_count(game: RefCounted,kind: String) -> int:
	var count: int = 0
	for event: Dictionary in game.events:
		if event.kind == kind: count += 1
	return count

func _oracle() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/boss_reference.json"))
	for fixture: Dictionary in data.cases:
		var rig := _rig()
		var game: RefCounted = rig.game
		game.p.merge(fixture.setup.player.duplicate(true),true)
		game.s.merge(fixture.setup.state.duplicate(true),true); game.s.mode = "playing"
		game.s.flags.merge(fixture.setup.flags.duplicate(true),true); game.s.counters.merge(fixture.setup.counters.duplicate(true),true)
		game.npcs.clear(); game.cash_piles.clear(); game.projectiles.clear()
		for body: Dictionary in fixture.setup.actors: game.npcs.append(body.duplicate(true))
		for key: String in fixture.setup.refs: game.s[key] = rig.combat.actor(fixture.setup.refs[key])
		match fixture.kind:
			"tony": rig.bosses.start_tony()
			"coop": rig.bosses.start_coop()
			"older": rig.bosses.spawn_brutus_older()
			"transform": rig.bosses.transform_fallen_priest()
			"school": rig.bosses.spawn_old_school_brutus()
			"death": rig.bosses.handle_death(game.npcs[0].id)
			"phase":
				rig.bosses.tick_before_actors(16.0); rig.director.tick(16.0,1000.0); rig.bosses.tick_after_actors(16.0,1000.0)
			"ai": rig.director.tick(16.0,1000.0)
		_check(fixture.error == null,fixture.id+" source succeeds")
		_fields(game.p,fixture.expected.player,fixture.id+".player")
		_fields(game.s,fixture.expected.state,fixture.id+".state")
		_fields(game.s.flags,fixture.expected.flags,fixture.id+".flags")
		_fields(game.s.counters,fixture.expected.counters,fixture.id+".counters")
		for key: String in fixture.expected.quests: _fields(game.s.quests[key],fixture.expected.quests[key],fixture.id+".quests."+key)
		_check(game.npcs.size() == fixture.expected.actors.size(),fixture.id+" actor count")
		for i: int in range(mini(game.npcs.size(),fixture.expected.actors.size())):
			var skip: Array = ["id"] if str(fixture.expected.actors[i].id).begins_with("sherri_") else []
			_fields(game.npcs[i],fixture.expected.actors[i],fixture.id+".actor%d" % i,skip)
		var achievements: Array = game.s.achievements.duplicate(); achievements.sort()
		_check(_same(achievements,fixture.expected.achievements),fixture.id+" achievements")
		_check(game.cash_piles.size() == fixture.expected.piles.size(),fixture.id+" piles")
		for i: int in range(mini(game.cash_piles.size(),fixture.expected.piles.size())): _fields(game.cash_piles[i],fixture.expected.piles[i],fixture.id+".pile")
		_check(game.projectiles.size() == fixture.expected.projectiles.size(),fixture.id+" projectiles")
		for i: int in range(mini(game.projectiles.size(),fixture.expected.projectiles.size())): _fields(game.projectiles[i],fixture.expected.projectiles[i],fixture.id+".projectile")
		completed += 1
	_check(data.defects.fallenRestart == {"flag":true,"ordinary":true,"fallen":false},"original Fallen restore softlock recorded separately")
	_check(_same(data.defects.olderStale,{"phase":3,"berserk":false}),"original Older stale phase recorded separately")
	_check(data.defects.departure.dead == false and data.defects.departure.x < data.defects.departure.targetX-4.0,"source off-map departure cannot complete")
	groups += 1


func _transactions() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.npcs.clear(); game.npcs.append(_actor("tony")); game.npcs.append(_actor("stripe"))
	rig.physics.placeable = false
	var before: Dictionary = game.p.duplicate(true)
	_check(not rig.bosses.start_tony() and not game.s.bossActive and game.p == before,"blocked start leaves resources and boss globals unchanged")
	rig.physics.placeable = true
	_check(rig.bosses.start_coop() and game.s.bossActive and game.s.coopMode and game.npcs[1].isAlly,"coop starts existing ally through one transaction")
	_check(not rig.bosses.start_tony(),"active boss blocks duplicate start")
	game.p.weapon = "fists"; game.p.cred = 0
	_check(rig.combat.damage_actor("tony",10000.0),"Combat hands staged lethal HP to boss domain")
	_check(game.p.cred == 200 and game.p.weapon == "shoe" and game.s.quests.fallen_king.done and rig.domain.after_tony == 1,"Tony grants only special rewards and campaign hook once")
	_check(not rig.combat.damage_actor("tony",10000.0) and game.p.cred == 200,"duplicate Tony death cannot pay")
	game.npcs.append(_actor("king",{ "hp":1.0,"kingdomBoss":true }))
	var king: Dictionary = rig.combat.actor("king")
	before = king.duplicate(true)
	_check(not rig.combat.damage_actor("king",20.0) and king == before,"unavailable kingdom campaign refuses before HP mutation")
	rig.domain.campaign_ready = true
	_check(not rig.combat.damage_actor("king",20.0) and king == before,"capable campaign false rolls staged HP back")
	rig.domain.campaign_accepts = true
	_check(rig.combat.damage_actor("king",20.0) and rig.domain.campaign_completions == 1 and king.dead,"capable campaign commits its own outcome once")
	_check(not rig.combat.damage_actor("king",20.0) and rig.domain.campaign_completions == 1,"campaign death idempotent")
	var older_rig := _rig()
	game = older_rig.game
	game.npcs.clear(); game.s.brutusOlderPhase = 3
	game.npcs.append(_actor("brutus_older",{"dead":true,"hp":0,"isBossB":true}))
	_check(older_rig.bosses.spawn_brutus_older() and _count(game,"brutus_older") == 1 and game.s.brutusOlderPhase == 1 and not game.s.brutusOlderNPC.get("berserk",false),"approved Older repair replaces dead identity and resets phase")
	_check(not older_rig.bosses.spawn_brutus_older(),"live Older cannot duplicate")
	game.events.clear(); var old_max: float = game.p.maxHp; var old_cred: int = game.p.cred
	_check(older_rig.combat.damage_actor("brutus_older",10000),"Older special death accepted")
	_check(game.p.maxHp == old_max+5 and game.p.cred == old_cred+100 and _event_count(game,"save_requested") == 0,"Older source maxHP mutation and absent immediate save preserved")
	var school_rig := _rig()
	game = school_rig.game; game.cash_piles.clear()
	_check(school_rig.bosses.spawn_old_school_brutus(),"Old School uses exported authored door")
	_check(school_rig.combat.damage_actor("os_brutus",10000),"Old School special death accepted")
	var copper: int = game.p.copper
	_check(not school_rig.bosses.spawn_old_school_brutus() and game.p.copper == copper,"dead Old School corpse blocks same-session cousins without new rewards")
	groups += 1


func _restore_and_clocks() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	_check(rig.bosses.transform_fallen_priest(),"Fallen transforms living authored priest")
	var saved: Dictionary = game.snapshot()
	_check(game.restore(saved).get("ok") == true,"Fallen unfinished state restores")
	game.events.clear()
	_check(rig.bosses.normalize_state(),"Fallen restore normalization succeeds")
	_check(_count(game,"priest") == 0 and _count(game,"omalley_fallen") == 1 and rig.combat.actor("omalley_fallen").hp == 160,"restore repairs identity with fresh combat HP")
	_check(game.events.is_empty(),"restore transformation is silent, no rewards or receipts")
	var fallen: Dictionary = rig.combat.actor("omalley_fallen"); fallen.hp = 73
	_check(rig.bosses.normalize_state() and fallen.hp == 73,"same-epoch normalization cannot heal encounter")
	var pile_count: int = game.cash_piles.size()
	_check(rig.combat.damage_actor("omalley_fallen",10000.0),"Fallen special death commits")
	_check(game.cash_piles.size() == pile_count+2 and game.cash_piles[-1].equip == "priest_collar","Fallen creates source equipment pickup alongside cash")
	saved = game.snapshot(); var paid_cred: int = game.p.cred
	game.restore(saved); game.events.clear(); rig.bosses.normalize_state()
	_check(not _alive_id(game,"priest") and not _alive_id(game,"omalley_fallen") and game.p.cred == paid_cred and game.events.is_empty(),"dead Fallen restore suppresses both identities without payment replay")
	var ending_rig := _rig()
	game = ending_rig.game; game.npcs.clear(); game.npcs.append(_actor("tony"))
	ending_rig.bosses.tick_wall(1000.0); ending_rig.bosses.start_tony(); ending_rig.combat.damage_actor("tony",10000)
	game.s.mode = "paused"; game.events.clear()
	ending_rig.bosses.tick_wall(4999.0)
	_check(_event_count(game,"ending_requested") == 0,"ending receipt not early")
	ending_rig.bosses.tick_wall(5000.0); ending_rig.bosses.tick_wall(5001.0)
	_check(_event_count(game,"ending_requested") == 1 and game.s.endingContinue and game.s.mode == "title","ending receipt runs once across pause")
	game.fresh(); ending_rig.bosses.normalize_state(); game.npcs.clear(); game.npcs.append(_actor("tony"))
	ending_rig.bosses.start_tony(); ending_rig.combat.damage_actor("tony",10000)
	game.fresh(); game.events.clear(); ending_rig.bosses.tick_wall(10000)
	_check(_event_count(game,"ending_requested") == 0,"new game cancels old ending callback")
	groups += 1

func _alive_id(game: RefCounted,id: String) -> bool:
	for body: Dictionary in game.npcs:
		if body.id == id and not body.get("dead",false): return true
	return false


func _fallen_and_phase_properties() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.npcs.clear(); game.npcs.append(_actor("tony")); rig.bosses.start_tony()
	game.s.bossNPC.hp = 131; rig.physics.fail_x = 310.0
	rig.bosses.tick_after_actors(16,1000)
	_check(game.s.bossPhase == 1 and game.npcs.size() == 1,"failed one-of-two add placement defers whole phase transition")
	rig.physics.fail_x = INF; rig.bosses.tick_after_actors(16,1016)
	_check(game.s.bossPhase == 2 and game.npcs.size() == 3 and game.npcs[1].transient and game.npcs[2].transient and game.npcs[1].id != game.npcs[2].id,"phase2 adds exactly two unique transient actors")
	var count: int = game.npcs.size(); rig.bosses.tick_after_actors(16,1032)
	_check(game.npcs.size() == count,"repeated phase2 tick cannot duplicate adds")
	var skip_rig := _rig()
	game = skip_rig.game; game.npcs.clear(); game.npcs.append(_actor("tony")); skip_rig.bosses.start_tony()
	game.s.bossNPC.hp = 1; skip_rig.bosses.tick_after_actors(16,1000)
	_check(game.s.bossPhase == 3 and game.npcs.size() == 1,"single large hit skips source phase2 summons")
	var fallen_rig := _rig()
	game = fallen_rig.game; fallen_rig.bosses.transform_fallen_priest()
	game.s.counters.omalleyFallenSurviveT = 59990.0
	fallen_rig.bosses.tick_before_actors(16.0)
	_check(game.s.achievements.has("outran_the_priest"),"Fallen survival threshold grants once")
	game.die(); fallen_rig.bosses.tick_before_actors(16)
	_check(game.s.counters.omalleyFallenSurviveT == 60022.0,"source survival counter continues through player respawn")
	var fallen: Dictionary = fallen_rig.combat.actor("omalley_fallen")
	fallen.dead = true; fallen_rig.bosses.tick_before_actors(16)
	_check(game.s.counters.omalleyFallenSurviveT == 0.0,"no living Fallen resets survival counter")
	_check(not fallen_rig.bosses.tick_before_actors(INF) and not fallen_rig.bosses.tick_after_actors(51,2000) and not fallen_rig.bosses.tick_wall(NAN),"invalid boss clocks rejected")
	groups += 1


func _departures() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.npcs.clear()
	var visitor := _actor("day3_visitor",{"isDay3Visitor":true,"wanderOff":true,"targetX":float(game.content.world.bounds.w)+80.0,"speed":1.2})
	game.npcs.append(visitor)
	var original := Vector2(visitor.x,visitor.y)
	rig.director.tick(16,1000)
	_check(Vector2(visitor.x,visitor.y) == original and _event_count(game,"dependency_missing") == 1,"missing authored departure route remains blocked explicitly")
	rig.physics.departure = {"exit_id":"east_pad","target":Vector2(300,245),"route":[Vector2(270,245),Vector2(300,245)]}
	rig.physics.blocked = true
	for i: int in range(10): rig.director.tick(16,1016+i*16)
	_check(game.npcs.size() == 1 and Vector2(visitor.x,visitor.y) == original,"departure cannot bypass blocking collision")
	rig.physics.blocked = false
	var resources: Dictionary = game.p.duplicate(true)
	for i: int in range(100): rig.director.tick(16,1200+i*16)
	_check(game.npcs.is_empty() and _event_count(game,"actor_departed") == 1,"known visitor follows waypoints then departs at pad")
	_check(game.p == resources and _event_count(game,"actor_died") == 0 and not game.snapshot().npcs_killed.has("day3_visitor"),"departure has no damage/reward/permanent death")
	_check(rig.physics.departure_calls > 10,"departure obtains current route evidence while walking")
	var price := _actor("price_guy",{"isPriceGuy":true,"priceWalkOff":true,"wanderOff":true,"targetX":-80.0,"speed":1.4})
	game.npcs.append(price)
	rig.physics.departure = {"exit_id":"west_pad","target":Vector2(220,245),"route":[Vector2(220,245)]}
	for i: int in range(40): rig.director.tick(16,3000+i*16)
	_check(game.npcs.is_empty() and _event_count(game,"actor_departed") == 2,"Price Guy uses west-intent departure")
	var invalid := _actor("bad_route",{"isDay3Visitor":true,"wanderOff":true,"targetX":99999.0})
	game.npcs.append(invalid)
	rig.physics.departure = {"exit_id":"outside","target":Vector2(-5,1),"route":[Vector2(-5,1)]}
	rig.director.tick(16,4000)
	_check(invalid.x == 230 and invalid.y == 230,"outside-pad route rejected")
	rig.physics.departure = {"exit_id":"malformed","target":Vector2(240,245),"route":[Vector2(NAN,245)]}
	rig.director.tick(16,4016)
	_check(invalid.x == 230 and invalid.y == 230,"nonfinite departure route rejected")
	game.npcs.clear(); game.npcs.append(_actor("sleeping_dave",{"asleep":true}))
	rig.director.tick(16,4032)
	_check(rig.director.snapshot("sleeping_dave").asleep,"snapshot exposes authoritative sleep flag")
	game.npcs[0].asleep = false; rig.director.tick(16,4048)
	_check(not rig.director.snapshot("sleeping_dave").asleep,"waking updates snapshot without an animation-owned timer")
	groups += 1
