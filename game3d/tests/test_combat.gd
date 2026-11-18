extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Director = preload("res://scripts/actor_director.gd")
var checks: int = 0
var failures: Array[String] = []
var fixture_count: int = 0
var groups_completed: int = 0

class FixedState:
	extends "res://scripts/game_state.gd"
	var roll: float = 0.75
	func random_float() -> float: return roll
	func random_index(size: int) -> int: return mini(size - 1, int(floor(roll * size))) if size > 0 else 0

class Physics:
	extends RefCounted
	var visible: bool = true
	var blocked_motion: bool = false
	var invalid_motion: bool = false
	var invalid_sweep: bool = false
	var placeable: bool = true
	var wall_fraction: float = INF
	var hit_calls: int = 0
	func move_body(body: Dictionary, intended: Vector2, _goal: Variant = null, _stop: bool = false) -> Dictionary:
		if invalid_motion: return {"position":Vector2(NAN, 1.0), "blocked":false}
		return {"position":Vector2(body.x, body.y) if blocked_motion else intended, "blocked":blocked_motion}
	func clear_placement(body: Dictionary) -> Variant:
		return Vector2(body.x, body.y) if placeable else null
	func can_hit(_from: Vector2, _to: Vector2, _source: String, _target: String) -> bool:
		hit_calls += 1
		return visible
	func sweep_projectile(start: Vector2, end: Vector2, _radius: float) -> Dictionary:
		if invalid_sweep: return {"blocked":false,"fraction":NAN,"position":end}
		return {"blocked":is_finite(wall_fraction),"fraction":wall_fraction if is_finite(wall_fraction) else 1.0,"position":start.lerp(end,wall_fraction) if is_finite(wall_fraction) else end}

class Domain:
	extends RefCounted
	var owner_ref: WeakRef
	var available: bool = true
	var accepts: bool = false
	var completions: int = 0
	var older: int = 0
	func _init(owner: RefCounted) -> void: owner_ref = weakref(owner)
	func can_handle_death(_body: Dictionary) -> bool: return available
	func handle_death(id: String) -> bool:
		if not accepts: return false
		var owner: RefCounted = owner_ref.get_ref()
		for actor: Dictionary in owner.npcs:
			if actor.id == id: actor.dead = true; completions += 1; return true
		return false
	func spawn_brutus_older() -> bool: older += 1; return true


func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	_source_oracle()
	_melee_and_domain()
	_projectile_geometry()
	_director_properties()
	_police_and_lifecycle()
	_check(fixture_count == 63, "all 63 source fixtures completed without script abort")
	_check(groups_completed == 5, "all five test groups completed without script abort")
	if failures.is_empty():
		print("3D COMBAT GATE: PASS (%d checks; %d source fixtures; physics, archetypes, police lifecycle, atomic death seams; P07b and scene integration pending)" % [checks, fixture_count])
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D COMBAT GATE: FAIL (%d failures / %d checks)" % [failures.size(), checks]); quit(1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a) - float(b)) < 0.00001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i: int in range(a.size()):
			if not _same(a[i], b[i]): return false
		return true
	return a == b
func _fields(actual: Dictionary, expected: Dictionary, label: String, skip: Array = []) -> void:
	for key: String in expected:
		if key in skip: continue
		# Godot Vector2 stores float32 coordinates; source JS uses doubles. A tenth of
		# a thousandth of a source pixel is <0.000004m. Resource/timer checks stay strict.
		if key in ["x","y"] and Combat.finite_number(expected[key]) and Combat.finite_number(actual.get(key)):
			_check(absf(float(actual[key]) - float(expected[key])) <= 0.0001, "%s.%s geometry actual=%s expected=%s" % [label,key,str(actual[key]),str(expected[key])])
			continue
		_check(actual.has(key) and _same(actual.get(key), expected[key]), "%s.%s actual=%s expected=%s" % [label,key,str(actual.get(key)),str(expected[key])])
func _actor(id: String = "target", extra: Dictionary = {}) -> Dictionary:
	var value: Dictionary = {"id":id,"name":"TEST ACTOR","sprite":"lurch","x":100.0,"y":100.0,"w":26.0,"h":30.0,"hp":1000.0,"maxHp":1000.0,"speed":1.6,"dmg":8,"hostile":true,"aggro":true,"dead":false,"archetype":"default","attackCd":0.0,"chatterCd":999999.0}
	value.merge(extra, true); return value
func _setup(game: RefCounted) -> void:
	game.p.x = 130.0; game.p.y = 100.0; game.p.iframes = 0.0; game.p.stunT = 0.0; game.p.attackCd = 0.0
	game.s.mode = "playing"; game.npcs.clear(); game.projectiles.clear(); game.cash_piles.clear(); game.events.clear()
func _has_event(game: RefCounted, kind: String) -> bool:
	for event: Dictionary in game.events:
		if event.kind == kind: return true
	return false


func _source_oracle() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/combat_reference.json"))
	for fixture: Dictionary in data.cases:
		var game := FixedState.new()
		game.roll = fixture.roll; game.p.merge(fixture.setup.player.duplicate(true), true)
		game.s.merge(fixture.setup.state.duplicate(true), true); game.s.mode = "playing"
		game.s.flags.merge(fixture.setup.flags.duplicate(true), true); game.s.counters.merge(fixture.setup.counters.duplicate(true), true)
		game.npcs.clear()
		for body: Dictionary in fixture.setup.actors: game.npcs.append(body.duplicate(true))
		game.cash_piles.clear(); game.projectiles.clear(); game.events.clear()
		var physics := Physics.new()
		var combat := Combat.new(game, physics)
		var director := Director.new(game, combat)
		match fixture.kind:
			"attack": combat.attack_player(Vector2.LEFT)
			"death": combat.kill_actor(game.npcs[0].id)
			"damage": combat.damage_player(fixture.amount, game.npcs[0])
			"ai": director.tick(16.0, 1000.0)
			"police": combat.tick_police(16.0, 0.0)
		if fixture.id == "brendan_defect":
			_check(fixture.error == "ReferenceError: cashPiles is not defined", "original Brendan bug remains characterized")
			_check(game.cash_piles.size() == 1 and game.cash_piles[0].amt == 30 and game.s.achievements.has("badge_money"), "Brendan intended badge transaction finishes")
			_check(game.p.cred == 10 and game.p.wanted == 1 and game.p.faction.street == -3 and game.p.faction.spiritual == 1 and game.s.counters.brendanFirstKill == 1, "Brendan repaired rewards/factions/first counter atomic")
			_check(not combat.kill_actor(game.npcs[0].id) and game.cash_piles.size() == 1, "Brendan reward cannot duplicate")
			fixture_count += 1
			continue
		_check(fixture.error == null, fixture.id + " source method succeeds")
		_fields(game.p, fixture.expected.player, fixture.id + ".player")
		_check(game.npcs.size() == fixture.expected.actors.size(), fixture.id + " actor count")
		for i: int in range(mini(game.npcs.size(), fixture.expected.actors.size())):
			_fields(game.npcs[i], fixture.expected.actors[i], fixture.id + ".actor", ["id"] if fixture.kind == "police" else [])
		_check(_same(game.s.combo, fixture.expected.combo) and _same(game.s.comboT, fixture.expected.comboT), fixture.id + " combo")
		_fields(game.s.counters, fixture.expected.counters, fixture.id + ".counters")
		_fields(game.s.flags, fixture.expected.flags, fixture.id + ".flags")
		var achievements: Array = game.s.achievements.duplicate(); achievements.sort()
		_check(_same(achievements, fixture.expected.achievements), fixture.id + " achievements")
		_check(game.projectiles.size() == fixture.expected.projectiles.size(), fixture.id + " projectiles")
		for i: int in range(mini(game.projectiles.size(), fixture.expected.projectiles.size())): _fields(game.projectiles[i], fixture.expected.projectiles[i], fixture.id + ".projectile")
		_check(game.cash_piles.size() == fixture.expected.piles.size(), fixture.id + " cash piles")
		for i: int in range(mini(game.cash_piles.size(), fixture.expected.piles.size())): _fields(game.cash_piles[i], fixture.expected.piles[i], fixture.id + ".pile")
		fixture_count += 1
	groups_completed += 1


func _melee_and_domain() -> void:
	var game := FixedState.new(); _setup(game)
	var physics := Physics.new()
	var combat := Combat.new(game, physics)
	game.npcs.append(_actor())
	var before: Dictionary = game.npcs[0].duplicate(true)
	physics.visible = false
	_check(combat.attack_player(Vector2.LEFT).ok and game.npcs[0] == before and game.s.combo == 0, "occluded melee consumes swing, no hit/reward")
	physics.visible = true; game.p.attackCd = 0.0
	_check(combat.attack_player(Vector2.LEFT).connected and physics.hit_calls >= 2, "LOS re-evaluated for next swing")
	var hp: float = game.npcs[0].hp
	_check(not combat.attack_player(Vector2.LEFT).ok and game.npcs[0].hp == hp, "cooldown blocks duplicate swing")
	game.p.attackCd = 0.0
	_check(not combat.attack_player(Vector2(NAN, 1.0)).ok and game.p.attackCd == 0.0, "nonfinite direction rejects without cost")
	_check(not combat.attack_player(Vector2.ZERO).ok, "zero direction rejected")
	game.s.mode = "dialogue"
	_check(not combat.attack_player(Vector2.LEFT).ok, "modal attack rejected")
	game.s.mode = "playing"
	game.npcs[0] = _actor("essential", {"essential":true,"hp":2.0,"hostile":false,"aggro":false})
	var resources: Dictionary = game.p.duplicate(true)
	combat.attack_player(Vector2.LEFT)
	_check(game.npcs[0].hp == 2.0 and not game.npcs[0].aggro and game.npcs[0].x == 100 and game.p.cred == resources.cred and game.p.wanted == resources.wanted, "essential contact has no offense or resource grants")
	game.p.attackCd = 0.0; game.npcs[0] = _actor("special", {"kingdomBoss":true,"hp":1.0})
	before = game.npcs[0].duplicate(true)
	combat.attack_player(Vector2.LEFT)
	_check(game.npcs[0] == before and _has_event(game, "dependency_missing"), "unavailable domain rejects lethal hit before mutation")
	var domain := Domain.new(game)
	combat = Combat.new(game, physics, null, domain)
	game.p.attackCd = 0.0; combat.attack_player(Vector2.LEFT)
	_check(game.npcs[0] == before and domain.completions == 0, "capable domain refusal rolls back HP and all hit effects")
	_check(not combat.damage_actor("special", 20.0) and game.npcs[0] == before, "ally/cart damage respects atomic domain refusal")
	domain.accepts = true
	_check(combat.damage_actor("special", 20.0) and game.npcs[0].dead and domain.completions == 1, "accepted special death commits once")
	_check(not combat.damage_actor("special", 20.0) and domain.completions == 1, "dead special cannot pay twice")
	game.s.combo = 4; game.s.comboT = 20.0
	combat.tick_status(16.0); _check(game.s.combo == 4 and game.s.comboT == 4.0, "combo remains until exact expiry")
	combat.tick_status(16.0); _check(game.s.combo == 0 and game.s.comboT == 0.0, "combo expiry resets once")
	physics.invalid_motion = true
	var body := _actor(); combat.move_actor(body, Vector2(999,999))
	_check(body.x == 100.0 and body.y == 100.0, "invalid physics output cannot inject NaN")
	_check(not combat.tick_status(INF) and not combat.tick_status(51.0), "invalid active step rejects")
	groups_completed += 1


func _projectile_geometry() -> void:
	var game := FixedState.new(); _setup(game)
	game.p.x = 150.0; game.p.y = 100.0
	var physics := Physics.new()
	var combat := Combat.new(game, physics)
	var shot: Dictionary = {"x":100.0,"y":114.0,"tx":200.0,"ty":114.0,"speed":10000.0,"dmg":15.0,"slowMs":1500.0,"kind":"holy"}
	_check(combat.spawn_projectile(shot), "valid projectile created")
	combat.tick_projectiles(16.0)
	_check(game.p.hp == 85.0 and game.p.slowT == 1500.0 and game.projectiles.is_empty(), "sweep catches crossed player despite endpoint beyond body")
	game.p.hp = 100.0; game.p.iframes = 0.0; game.p.slowT = 0.0
	physics.wall_fraction = 0.1
	combat.spawn_projectile(shot); combat.tick_projectiles(16.0)
	_check(game.p.hp == 100.0 and game.p.slowT == 0.0 and game.projectiles.is_empty(), "earlier wall blocks all projectile effects")
	physics.wall_fraction = (150.0 - 4.0 - 100.0) / 160.0
	combat.spawn_projectile(shot); combat.tick_projectiles(16.0)
	_check(game.p.hp == 100.0, "wall wins equal-time player contact")
	physics.wall_fraction = INF; game.p.iframes = 500.0
	combat.spawn_projectile(shot); combat.tick_projectiles(16.0)
	_check(game.p.hp == 100.0 and game.p.slowT == 1500.0, "projectile slow survives blocked iframe damage")
	physics.invalid_sweep = true; game.p.iframes = 0.0
	combat.spawn_projectile(shot); combat.tick_projectiles(16.0)
	_check(game.p.hp == 100.0 and game.projectiles.is_empty() and _has_event(game,"dependency_missing"), "invalid sweep discarded safely")
	_check(not combat.spawn_projectile({"x":NAN,"y":0,"tx":1,"ty":1}) and not combat.spawn_projectile({"x":0,"y":0,"tx":1,"ty":1,"speed":-1}), "invalid projectile cannot enter pool")
	for i: int in range(45): combat.spawn_projectile(shot)
	_check(game.projectiles.size() == 40, "projectile pool remains bounded")
	_check(is_inf(Combat.segment_rect_fraction(Vector2.ZERO,Vector2(2,0),Rect2(3,3,2,2))), "sweep rejects parallel miss")
	_check(Combat.segment_rect_fraction(Vector2(4,4),Vector2(10,10),Rect2(3,3,2,2)) == 0.0, "sweep starts inside player at zero")
	groups_completed += 1


func _director_properties() -> void:
	var game := FixedState.new(); _setup(game)
	var physics := Physics.new()
	var combat := Combat.new(game, physics)
	var director := Director.new(game, combat)
	game.npcs.append(_actor("charger", {"archetype":"charger","chargeState":"lunge","chargeT":500.0,"lungeVx":1.0,"lungeVy":0.0}))
	physics.blocked_motion = true; physics.visible = false
	director.tick(16.0, 1000.0)
	_check(game.p.hp == 100.0 and game.npcs[0].x == 100.0 and game.npcs[0].structureChargeHit, "blocked charge cannot contact through wall")
	_check(director.snapshot("charger").local_velocity == Vector3.ZERO, "animation reports actual zero collision movement")
	director.tick(16.0, 1016.0)
	_check(game.npcs[0].chargeState == "cooldown" and game.npcs[0].chargeT == 1384.0, "wall collision enters source cooldown next tick")
	physics.blocked_motion = false; physics.visible = true
	game.npcs[0] = _actor("walker")
	director.tick(16.0, 1032.0)
	var pose: Dictionary = director.snapshot("walker")
	_check((pose.local_velocity as Vector3).is_finite() and absf(pose.local_velocity.x) < 0.00001 and pose.local_velocity.z > 0.0, "snapshot uses +Z forward and metre velocity")
	_check(is_equal_approx(pose.local_velocity.length(), 4.0), "source 1.6px/16ms maps to four metres per second")
	pose.local_velocity = Vector3(999,999,999)
	_check(director.snapshot("walker").local_velocity != pose.local_velocity, "snapshot detached from pose authority")
	game.npcs[0] = _actor("pet", {"isPet":true,"aggro":false,"hostile":false,"x":game.p.x,"y":game.p.y})
	director.tick(16.0,1048.0)
	_check(is_finite(game.npcs[0].x) and is_finite(game.npcs[0].y), "exact-overlap pet remains finite")
	game.npcs[0] = _actor("robber", {"robs":true,"archetype":"grabber"})
	var before: Dictionary = game.npcs[0].duplicate(true)
	director.tick(16.0,1064.0)
	_check(game.npcs[0] == before and not director.supported(game.npcs[0]), "missing robbery subsystem cannot become ordinary grabber")
	game.npcs[0] = _actor("fallen", {"archetype":"priest_fallen"})
	_check(not director.supported(game.npcs[0]), "P07b archetype explicitly unsupported")
	_check(director.supported(_actor("passive_older", {"archetype":"passive"})), "source passive archetype remains an explicit default-chase compatible type")
	_check(not director.tick(NAN, 1080.0) and not director.tick(16.0,NAN), "director invalid clocks reject")
	game.npcs[0] = _actor("corpse", {"dead":true})
	director.tick(16.0,1080.0)
	_check(director.snapshot("corpse").death_phase > 0.0, "dead pose age advances without AI")
	game.fresh()
	_check(director.snapshot("corpse").is_empty(), "fresh state drops prior presentation epoch")
	groups_completed += 1


func _police_and_lifecycle() -> void:
	var game := FixedState.new(); _setup(game)
	var physics := Physics.new()
	var domain := Domain.new(game)
	var combat := Combat.new(game, physics, null, domain)
	game.roll = 0.0; game.p.wanted = 1
	game.npcs.append(_actor("caller", {"x":0.0,"isCop":true}))
	combat.tick_police(16.0, 0.0)
	game.s.mode = "dialogue"; combat.tick_wall(799.0)
	_check(game.npcs.size() == 1, "radio delay not early")
	combat.tick_wall(800.0)
	_check(game.npcs.size() == 2 and game.npcs[1].transient, "radio arrival fires during modal at deadline")
	var first_id: String = game.npcs[1].id
	game.npcs[1].dead = true
	game.p.wanted = 3; game.roll = 0.75; combat.tick_police(16.0,832.0)
	_check(game.npcs[-1].id != first_id, "runtime police identities never reused")
	for i: int in range(10): combat.tick_police(16.0, 848.0 + i * 16.0)
	_check(combat._live_cops().size() <= 4, "police population hard cap")
	game.npcs.append(_actor("permanent", {"hp":0.0}))
	combat.kill_actor("permanent")
	game.npcs.append(_actor("temporary", {"hp":0.0,"transient":true}))
	combat.kill_actor("temporary")
	var saved: Dictionary = game.snapshot()
	_check(saved.npcs_killed.has("permanent") and not saved.npcs_killed.has("temporary") and not saved.npcs_killed.has(first_id), "only permanent actor deaths saved")
	game.fresh(); _setup(game); game.roll = 0.0; game.p.wanted = 1
	game.npcs.append(_actor("caller", {"x":0.0,"isCop":true}))
	combat.tick_police(16.0,2000.0); game.npcs[0].dead = true; combat.tick_wall(2800.0)
	_check(game.npcs.size() == 1, "dead radio caller cancels arrival")
	game.fresh(); _setup(game); game.roll = 0.0; game.p.wanted = 1
	game.npcs.append(_actor("caller", {"x":0.0,"isCop":true}))
	combat.tick_police(16.0,3000.0); game.p.wanted = 0; combat.tick_wall(3800.0)
	_check(game.npcs.size() == 1, "wanted cleared cancels queued arrival")
	game.fresh(); _setup(game); game.roll = 0.0; game.p.wanted = 1
	game.npcs.append(_actor("caller", {"x":0.0,"isCop":true}))
	combat.tick_police(16.0,4000.0); game.fresh(); game.p.wanted = 1; game.npcs.clear(); combat.tick_wall(4800.0)
	_check(game.npcs.is_empty(), "fresh identity cancels old wall callbacks")
	game.npcs.append(_actor("brutus", {"hp":0.0})); game.p.brutusDefeated = 4
	combat.kill_actor("brutus"); combat.tick_wall(6299.0)
	_check(domain.older == 0, "Older summon not early")
	combat.tick_wall(6300.0); combat.tick_wall(6301.0)
	_check(domain.older == 1, "fifth Brutus summon domain runs exactly once")
	game.fresh(); _setup(game); physics.placeable = false; game.p.wanted = 1
	combat.tick_police(16.0,7000.0)
	_check(game.npcs.is_empty(), "failed clear placement cannot spawn police inside wall")
	_check(not combat.tick_wall(6999.0), "wall clock reversal rejected")
	physics.placeable = true
	game.fresh(); game.npcs.clear(); game.p.wanted = 1; game.roll = 0.0
	game.npcs.append(_actor("tony", {"x":0.0,"isCop":true}))
	combat.tick_police(16.0,8000.0)
	var restore_data: Dictionary = game.snapshot()
	_check(game.restore(restore_data).get("ok") == true, "real restore accepts state with queued radio")
	var restored_count: int = game.npcs.size()
	combat.tick_wall(8800.0)
	_check(game.npcs.size() == restored_count, "restore identity cancels callback even when authored caller ID lives again")
	game.fresh(); _setup(game); game.p.wanted = 3; game.roll = 0.0
	for i: int in range(4): game.npcs.append(_actor("cap_%d" % i, {"x":-100.0 - i * 40.0,"isCop":true}))
	combat.tick_police(16.0,9000.0); combat.tick_wall(9800.0)
	_check(combat._live_cops().size() == 4, "four simultaneous backup arrivals cannot exceed existing cap")
	groups_completed += 1
