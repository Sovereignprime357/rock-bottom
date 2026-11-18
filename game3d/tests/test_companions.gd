extends SceneTree
const Companions = preload("res://scripts/companion_system.gd")
const Lockpick = preload("res://scripts/lockpick_system.gd")
const Props = preload("res://scripts/prop_state.gd")
const Communications = preload("res://scripts/communications_system.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Director = preload("res://scripts/actor_director.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const Heists = preload("res://scripts/heist_system.gd")
var checks: int = 0
var completed: int = 0
var groups: int = 0
var failures: Array[String] = []

class FixedState:
	extends "res://scripts/game_state.gd"
	var rolls: Array[float] = []
	var fallback: float = 0.75
	var cursor: int = 0
	func random_float() -> float:
		var value: float = rolls[cursor] if cursor < rolls.size() else fallback
		cursor += 1; return value
class Spatial:
	extends RefCounted
	var reachable: bool = true
	var placeable: bool = true
	var cash_placeable: bool = true
	var invalid: bool = false
	var excessive: bool = false
	var blocked_motion: bool = false
	var probes: int = 0
	var actor_placements: int = 0
	var cash_placements: int = 0
	func can_reach_target(_id: String) -> bool: probes += 1; return reachable
	func can_use_site(_id: String) -> bool: return reachable
	func clear_placement(body: Dictionary) -> Variant:
		actor_placements += 1
		if invalid: return Vector2(NAN,0)
		if excessive: return Vector2(body.x+101,body.y)
		return Vector2(body.x,body.y) if placeable else null
	func stage_cash_pickup(point: Vector2,_limit: float) -> Variant:
		cash_placements += 1
		if invalid: return Vector2(INF,0)
		if excessive: return point+Vector2(101,0)
		return point if cash_placeable else null
	func move_body(body: Dictionary,intended: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary:
		return {"position":Vector2(body.x,body.y) if blocked_motion else intended,"blocked":blocked_motion}
	func can_hit(_from: Vector2,_to: Vector2,_source: String,_target: String) -> bool: return reachable

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/companion_reference.json"))
	_dialogue_oracle(fixture); _world_oracle(fixture); _reveal_oracle(fixture)
	_capabilities(); _physical_spawns(); _physical_reveals(); _lifecycle(fixture); _shared_puzzle(); _source_order()
	_check(completed == 114,"all114 source paths completed without script abort")
	_check(groups == 9,"all9 companion groups completed without script abort")
	if failures.is_empty():
		print("3D COMPANION GATE: PASS (%d checks;114 source paths;four handlers/shared puzzle/physical deferred lifecycle;Runtime and dumpster integration pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D COMPANION GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
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
		for index: int in range(a.size()):
			if not _same(a[index],b[index]): return false
		return true
	return a == b
func _fields(actual: Dictionary,expected: Dictionary,label: String) -> void:
	for key: String in expected:
		if key == "dead": _check(bool(actual.get("dead",false)) == expected.dead,label+".dead"); continue
		# Vector2 coordinates use float32 at the physical seam, unlike source doubles.
		if key in ["x","y"] and actual.has(key):
			_check(absf(float(actual[key])-float(expected[key])) <= 0.0003,label+"."+key+" float32 coordinate"); continue
		_check(actual.has(key) and _same(actual.get(key),expected[key]),"%s.%s actual=%s expected=%s" % [label,key,str(actual.get(key)),str(expected[key])])
func _rig(setup: Dictionary = {}) -> Dictionary:
	var game := FixedState.new()
	var spatial := Spatial.new()
	var props := Props.new(game)
	var communications := Communications.new(game,props,func() -> float: return 1000000.0)
	var puzzle := Lockpick.new(game)
	var combat := Combat.new(game,spatial)
	var director := Director.new(game,combat)
	var companions := Companions.new(game,spatial,communications,puzzle,director)
	game.s.mode = "playing"; game.p.x = 3000.0; game.p.y = 4000.0
	if not setup.is_empty():
		game.p.merge(setup.player.duplicate(true),true); game.s.merge(setup.state.duplicate(true),true)
		game.s.quests.scrap_dog = setup.quest.duplicate(true); game.s.counters.possumProphecies = setup.prophecies
		game.s.achievements.assign(setup.achievements)
		game.npcs.clear()
		for body: Dictionary in setup.actors:
			var actor: Dictionary = body.duplicate(true); actor.chatterCd = 999999.0; game.npcs.append(actor)
		game.cash_piles.clear()
		for pile: Dictionary in setup.piles: game.cash_piles.append(pile.duplicate(true))
	else:
		var keep: Array[Dictionary] = []
		for actor: Dictionary in game.npcs:
			if actor.id in ["scrap_dog","possum"]:
				actor.x = 3000.0; actor.y = 4040.0; actor.chatterCd = 999999.0; keep.append(actor)
		game.npcs = keep; game.cash_piles.clear()
	game.events.clear(); companions.advance_wall(0)
	return {"game":game,"spatial":spatial,"props":props,"communications":communications,"puzzle":puzzle,"combat":combat,"director":director,"companions":companions}
func _actor(rig: Dictionary,id: String) -> Dictionary:
	for body: Dictionary in rig.game.npcs:
		if body.id == id: return body
	return {}
func _event_count(game: RefCounted,kind: String) -> int:
	var count: int = 0
	for event: Dictionary in game.events:
		if event.kind == kind: count += 1
	return count
func _toast(game: RefCounted) -> String:
	var result: String = ""
	for event: Dictionary in game.events:
		if event.kind == "toast": result = event.payload.text
		elif event.kind == "achievement": result = "· ACHIEVEMENT ·\n"+str(event.payload.definition.name)
	return result
func _menu_view(menu: Dictionary) -> Variant:
	if not menu.get("ok",false) or not menu.has("options"): return null
	var options: Array[Dictionary] = []
	for option: Dictionary in menu.options: options.append({"label":option.label,"enabled":option.enabled})
	return {"title":menu.title,"text":menu.text,"options":options}
func _actors(rig: Dictionary,expected: Array,label: String) -> void:
	_check(rig.game.npcs.size() == expected.size(),label+" actor count")
	for index: int in range(mini(rig.game.npcs.size(),expected.size())): _fields(rig.game.npcs[index],expected[index],label+" actor%d" % index)
func _state(rig: Dictionary,expected: Dictionary,label: String) -> void:
	_fields(rig.game.p,expected.player,label+" player"); _fields(rig.game.s,expected.state,label+" state")
	_check(_same(rig.game.s.quests.scrap_dog,expected.quest),label+" quest")
	_check(rig.game.s.counters.possumProphecies == expected.prophecies,label+" prophecy count")
	var achievements: Array = rig.game.s.achievements.duplicate(); achievements.sort()
	_check(_same(achievements,expected.achievements),label+" achievements")
	_actors(rig,expected.actors,label)
	_check(_same(rig.game.cash_piles,expected.piles),label+" exact pile payloads")
	_check(_same(rig.communications.snapshot().posts,expected.posts),label+" real communications posts")
	_check(rig.game.s.mode == expected.mode,label+" mode")
	_check(_toast(rig.game) == expected.toast,label+" final toast actual="+_toast(rig.game)+" expected="+str(expected.toast))
	_check(_event_count(rig.game,"save_requested") == expected.saves,label+" source save calls")
func _dialogue_oracle(fixture: Dictionary) -> void:
	_check(fixture.cases.size() == 98,"98 dialogue source fixtures present")
	for test: Dictionary in fixture.cases:
		var rig := _rig(test.setup)
		for value: float in test.rolls: rig.game.rolls.append(value)
		rig.game.fallback = test.roll
		var menu: Dictionary = {}
		for step: Dictionary in test.steps:
			var op: Dictionary = step.operation
			match op.kind:
				"open": menu = rig.companions.open(op.id)
				"choice":
					_check(menu.get("ok",false) and menu.has("options"),test.id+" opens actual menu before choice")
					if menu.get("ok",false) and menu.has("options"):
						var option: Dictionary = menu.options[int(op.index)]
						if option.enabled: menu = rig.companions.select(menu.token,option.id)
				"escape": rig.companions.close(); menu = {}
				"spawn": rig.companions.spawn_pet_possum()
				"spawn_due": rig.companions.advance_wall(2200.0)
			_check(_same(_menu_view(menu),step.menu),test.id+" exact menu after "+str(op))
			_state(rig,step.expected,test.id+" "+str(op))
			_check(rig.game.cursor == step.draws,test.id+" exact mechanic RNG count")
			for delay: float in step.spawnDelays: _check(delay == 2200.0,test.id+" source schedules2200ms")
		completed += 1
	groups += 1
func _world_oracle(fixture: Dictionary) -> void:
	_check(fixture.worlds.size() == 11,"11 source world boundaries present")
	for test: Dictionary in fixture.worlds:
		var rig := _rig(test.setup); rig.game.fallback = test.roll
		rig.director.tick_dog_discomfort(); rig.companions.tick_world(16.0); rig.director.tick(16.0,16.0)
		_fields(rig.game.s,test.expected.state,test.id+" world state")
		_actors(rig,test.expected.actors,test.id)
		completed += 1
	groups += 1
func _reveal_oracle(fixture: Dictionary) -> void:
	_check(fixture.reveals.size() == 5,"five source cash reveal paths present")
	for test: Dictionary in fixture.reveals:
		var rig := _rig(test.setup); rig.game.fallback = test.roll
		rig.director.tick(16.0,16.0)
		_state(rig,test.expected,test.id)
		_check(rig.game.cursor == test.mechanicDraws,test.id+" P07 excludes12 cosmetic particle samples")
		completed += 1
	groups += 1
func _choose(rig: Dictionary,id: String,action: String) -> Dictionary:
	var menu: Dictionary = rig.companions.open(id)
	return rig.companions.select(menu.get("token",""),action)
func _capabilities() -> void:
	var rig := _rig()
	var menu: Dictionary = rig.companions.open("possum")
	rig.spatial.reachable = false
	_check(not rig.companions.select(menu.token,"prophecy").ok and rig.game.cursor == 0 and rig.game.s.counters.possumProphecies == 0,"live LOS checked before prophecy cost/RNG")
	rig.spatial.reachable = true
	menu = rig.companions.open("possum")
	var newer: Dictionary = rig.companions.open("possum")
	_check(not rig.companions.select(menu.token,"prophecy").ok and rig.companions.is_active(),"stale token preserves newer menu")
	_check(rig.companions.select(newer.token,"prophecy").ok and not rig.companions.select(newer.token,"prophecy").ok,"one accepted prophecy per capability")
	rig.game.p.hp = -3; rig.game.p.stunT = 200; rig.game.s.bossActive = true; rig.game.s.bossKind = "tony"
	_check(rig.companions.open("scrap_dog").ok,"source raw HP/stun/ordinary boss do not prevent dialogue")
	rig.companions.close(); rig.game.s.bossKind = "kingdom"
	_check(not rig.companions.open("scrap_dog").ok,"kingdom interaction blanket preserved")
	rig.game.s.bossKind = ""; rig.game.p.x = 3000.0; rig.game.p.y = 4000.0
	var dog: Dictionary = _actor(rig,"scrap_dog")
	dog.x = rig.game.player_center().x+60.0-float(dog.w)*0.5; dog.y = rig.game.player_center().y-float(dog.h)*0.5
	_check(not rig.companions.open("scrap_dog").ok,"strict60px source boundary")
	dog.x -= 0.01
	_check(rig.companions.open("scrap_dog").ok,"inside60px accepted")
	rig.companions.close(); dog.x = 3000.0; dog.y = 4040.0
	rig.game.p.inventory = [{"id":"food","n":"a can of food (unmarked)","q":4,"migration_units":true}]
	_check(_choose(rig,"scrap_dog","feed").ok and rig.game.p.inventory[0].q == 3,"migrated food consumes one virtual unit")
	rig.game.s.quests.scrap_dog.state = "idle"; menu = rig.companions.open("scrap_dog"); rig.game.p.inventory.clear()
	var cred: float = rig.game.p.cred
	_check(not rig.companions.select(menu.token,"feed").ok and rig.game.p.cred == cred,"inventory disappearance cannot grant free feeding")
	_check(not rig.companions.open_from_dumpster("invented").ok,"future dumpster branch requires real one-use authority")
	menu = rig.companions.open("possum"); rig.game.fresh(); rig.game.s.mode = "title"
	_check(not rig.companions.select(menu.token,"prophecy").ok and rig.game.s.mode == "title","replaced epoch rejects stale menu without changing replacement mode")
	_check(not rig.companions.tick_world(NAN) and not rig.companions.tick_world(51) and not rig.companions.advance_wall(INF),"nonfinite/unsupported time rejected")
	groups += 1
func _physical_spawns() -> void:
	var rig := _rig(); rig.spatial.placeable = false
	var result: Dictionary = rig.companions.spawn_pet_possum()
	var original: Dictionary = rig.companions.pending_snapshot().pet
	_check(result.get("pending",false) and not rig.game.p.hasPossum and _actor(rig,"pet_possum").is_empty(),"blocked spawn grants no phantom ownership")
	_check(_event_count(rig.game,"achievement") == 0 and rig.communications.snapshot().posts.is_empty(),"blocked spawn emits no success receipts")
	rig.game.p.x += 200; rig.game.p.y += 100
	for step: int in range(10): rig.companions.tick_world(16.0)
	_check(rig.game.cursor == 0 and _same(original,rig.companions.pending_snapshot().pet),"spawn retries freeze original candidate without RNG")
	rig.spatial.placeable = true; rig.companions.tick_world(16.0)
	var pet: Dictionary = _actor(rig,"pet_possum")
	_check(not pet.is_empty() and pet.x == original.x and pet.y == original.y and rig.game.p.hasPossum,"deferred pet commits original valid body once")
	_check(_event_count(rig.game,"actor_spawned") == 1 and rig.communications.snapshot().posts.size() == 1,"one committed spawn publishes one receipt")
	rig.companions.spawn_pet_possum(); _check(_event_count(rig.game,"actor_spawned") == 1,"spawn replay cannot duplicate")
	rig.spatial.blocked_motion = true
	var pet_at := Vector2(float(pet.x),float(pet.y))
	rig.director.tick(16.0,16.0)
	_check(Vector2(pet.x,pet.y) == pet_at and rig.director.snapshot("pet_possum").local_velocity == Vector3.ZERO,"pet follows through actual movement seam and cannot cross blocked motion")
	var delayed := _rig(); delayed.game.s.counters.possumProphecies = 4
	_choose(delayed,"possum","prophecy")
	delayed.game.s.mode = "paused"; delayed.companions.advance_wall(2199.0)
	_check(_actor(delayed,"pet_possum").is_empty(),"spawn waits full2200wallms")
	delayed.companions.advance_wall(2200.0)
	_check(not _actor(delayed,"pet_possum").is_empty() and delayed.game.s.mode == "paused","source wall spawn runs while paused without replacing mode")
	var dog_rig := _rig(); dog_rig.game.s.quests.scrap_dog.state = "freed"; dog_rig.spatial.placeable = false
	dog_rig.companions.tick_world(16.0)
	var pending: Dictionary = dog_rig.companions.pending_snapshot().dog
	_check(dog_rig.game.cursor == 2 and dog_rig.game.s.freedDogFollowT == 0 and not dog_rig.game.s.freedDogFirstReturn,"blocked return reserves two source offsets without follow/receipt")
	for step: int in range(20): dog_rig.companions.tick_world(16.0)
	_check(dog_rig.game.cursor == 2 and _same(pending,dog_rig.companions.pending_snapshot().dog),"blocked dog does not reroll or accumulate bodies")
	dog_rig.spatial.placeable = true; dog_rig.companions.tick_world(16.0)
	_check(dog_rig.game.s.freedDogFollowT == 60000 and dog_rig.game.s.freedDogFirstReturn,"successful deferred dog begins full follow window")
	for failure: String in ["invalid","excessive"]:
		var bad := _rig(); bad.spatial.set(failure,true)
		_check(bad.companions.spawn_pet_possum().get("pending",false) and not bad.game.p.hasPossum,"reject "+failure+" placement response")
	groups += 1
func _physical_reveals() -> void:
	var rig := _rig(); rig.companions.spawn_pet_possum(); rig.game.events.clear(); rig.game.cursor = 0
	var pet: Dictionary = _actor(rig,"pet_possum")
	var pile: Dictionary = {"id":"equipment","x":2500.0,"y":4500.0,"amt":0,"equip":"priest_collar","collected":false}
	rig.game.cash_piles.append(pile); rig.spatial.cash_placeable = false
	_check(not rig.companions.tick_possum_reveal(pet,16.0) and pile.x == 2500.0,"blocked reveal leaves existing pile unchanged")
	var pending: Dictionary = rig.companions.pending_snapshot().reveal
	var timer: float = pet.revealT
	_check(rig.game.cursor == 4 and _event_count(rig.game,"cash_revealed") == 0,"blocked reveal captures exactlyfour gameplay rolls, no receipt")
	rig.game.p.x += 500
	for step: int in range(10): rig.companions.tick_possum_reveal(pet,16.0)
	_check(rig.game.cursor == 4 and pet.revealT == timer and rig.game.cash_piles.size() == 1,"pending reveal pauses timer and does not create cash")
	rig.spatial.cash_placeable = true; rig.companions.tick_possum_reveal(pet,16.0)
	_check(Vector2(pile.x,pile.y) == pending.position and pile.equip == "priest_collar" and pile.amt == 0 and not pile.collected,"same exact selected payload moves once to captured point")
	_check(_event_count(rig.game,"cash_revealed") == 1 and rig.game.cursor == 4,"one successful reveal receipt without reroll")
	rig.companions.tick_possum_reveal(pet,16.0)
	_check(pet.revealT == timer-16.0,"original already-drawn reveal timer resumes")
	pet.revealT = 0; rig.spatial.cash_placeable = false; rig.companions.tick_possum_reveal(pet,16.0)
	var draws: int = rig.game.cursor; pile.collected = true
	rig.companions.tick_possum_reveal(pet,16.0)
	_check(rig.companions.pending_snapshot().reveal.is_empty() and rig.game.cursor == draws and _event_count(rig.game,"cash_revealed") == 1,"collected selected pile cancels pending reveal without reward")
	for failure: String in ["invalid","excessive"]:
		pile.collected = false; pet.revealT = 0; rig.spatial.set(failure,true); rig.companions.tick_possum_reveal(pet,16.0)
		_check(not rig.companions.pending_snapshot().reveal.is_empty(),"reject "+failure+" cash response")
		rig.spatial.set(failure,false); pile.collected = true; rig.companions.tick_possum_reveal(pet,16.0)
	groups += 1
func _lifecycle(fixture: Dictionary) -> void:
	_check(fixture.sourceDefects.omitted.hasPossum and fixture.sourceDefects.ghost.hasPossum and not fixture.sourceDefects.ghost.livePet,"original omitted ownership/load ghost independently characterized")
	_check(_same(fixture.sourceDefects.duplicateDogs,[true,false]),"original repeated dog IDs independently characterized")
	var rig := _rig(); rig.companions.spawn_pet_possum()
	var pet: Dictionary = _actor(rig,"pet_possum")
	rig.game.p.x = pet.x; rig.game.p.y = pet.y
	_choose(rig,"pet_possum","release")
	_check(pet.dead and pet.departed and not rig.game.p.hasPossum,"release marks departed without kill reward")
	var cred: float = rig.game.p.cred; rig.companions.spawn_pet_possum()
	_check(not rig.game.p.hasPossum and rig.game.p.cred == cred,"released corpse preserves source reacquisition block")
	rig.game.s.quests.scrap_dog.state = "freed"; rig.game.s.freedDogT = 0
	rig.companions.tick_world(16.0)
	var dog: Dictionary = _actor(rig,"freed_dog_follower")
	rig.game.s.freedDogFollowT = 1; rig.director.tick(16.0,16.0); rig.companions.tick_world(16.0)
	_check(dog.dead and dog.departed and rig.game.p.cred == cred,"timed departure gives no kill rewards")
	rig.director.tick(16.0,32.0); _check(rig.director.snapshot("freed_dog_follower").dead,"prior departed pose exists before replacement")
	rig.game.s.freedDogT = 0; rig.companions.tick_world(16.0)
	var count: int = 0
	for actor: Dictionary in rig.game.npcs:
		if actor.id == "freed_dog_follower": count += 1
	_check(count == 1 and not _actor(rig,"freed_dog_follower").get("dead",false) and rig.director.snapshot("freed_dog_follower").is_empty(),"return replaces prior dead keyed row and clears stale pose")
	_check(rig.communications.snapshot().posts.size() == 2,"only first dog return publishes feed alongside original possum spawn")
	var living_dog: Dictionary = _actor(rig,"freed_dog_follower")
	living_dog.hp = 0
	_check(rig.combat.kill_actor("freed_dog_follower"),"actual Combat owns follower death")
	var after_kill: float = rig.game.p.cred
	rig.companions.tick_world(16.0)
	_check(not _actor(rig,"freed_dog_follower").get("dead",false) and rig.game.p.cred == after_kill,"killed dog resumes existing expired absence timer without duplicate kill rewards")
	var saved: Dictionary = rig.game.snapshot()
	_check(not saved.player.has("hasPossum") and not saved.state.has("freedDogT") and not saved.state.has("freedDogFollowT") and not saved.state.has("freedDogFirstReturn"),"companion ownership/timers remain unsaved")
	_check(rig.game.restore(saved).ok,"real GameState restore succeeds")
	rig.companions.ready()
	_check(not rig.game.p.hasPossum and rig.game.s.freedDogT == 0 and rig.game.s.freedDogFollowT == 0 and not rig.game.s.freedDogFirstReturn,"restore resets unsaved companion state")
	_check(rig.game.s.quests.scrap_dog.state == "freed" and _actor(rig,"freed_dog_follower").is_empty(),"durable dog quest survives without phantom actor")
	rig.game.s.mode = "playing"; rig.spatial.placeable = false; rig.companions.spawn_pet_possum()
	rig.game.fresh(); rig.companions.advance_wall(100000)
	_check(rig.companions.pending_snapshot().pet.is_empty() and not rig.game.p.hasPossum,"epoch replacement drops old physical callback")
	groups += 1
func _shared_puzzle() -> void:
	var rig := _rig()
	var heists := Heists.new(rig.game,rig.spatial,rig.puzzle)
	var anchor: Dictionary = {}
	for building: Dictionary in rig.game.content.buildings:
		if building.get("locked",false): anchor = building; break
	rig.game.p.x = anchor.x+anchor.w*0.5-rig.game.p.w*0.5; rig.game.p.y = anchor.y+anchor.h+10-rig.game.p.h*0.5
	var menu: Dictionary = heists.open("abandoned")
	menu = heists.select(menu.token,"entry:1")
	_check(menu.get("title") == "LOCKPICK","heist uses shared four-pin implementation")
	var old_token: String = menu.token
	var dog: Dictionary = _actor(rig,"scrap_dog"); dog.x = rig.game.p.x; dog.y = rig.game.p.y
	var dog_menu: Dictionary = rig.companions.open("scrap_dog")
	dog_menu = rig.companions.select(dog_menu.token,"free")
	var brain: float = rig.game.p.brain
	_check(not heists.select(old_token,"pin:2").ok and rig.game.p.brain == brain,"new dog puzzle revokes old heist context before wrong-pin cost")
	# A stale old-context close must not cancel the new shared puzzle or its menu.
	_check(rig.companions.select(dog_menu.token,"pin:1").ok,"new shared puzzle survives stale-context close")
	rig.companions.close()
	_check(rig.puzzle.begin("qa"),"direct puzzle setup")
	_check(not rig.puzzle.choose("qa",0).ok and rig.game.p.brain == brain,"invalid pin rejects without cost")
	rig.game.fresh()
	_check(not rig.puzzle.choose("qa",1).ok,"puzzle epoch replacement rejects stale answer")
	groups += 1
func _source_order() -> void:
	var rig := _rig(); rig.game.s.quests.scrap_dog.state = "freed"; rig.game.s.freedDogT = 0
	var cop: Dictionary = {"id":"horsecop","name":"HORSE COP","sprite":"horsecop","x":3030.0,"y":4110.0,"w":28,"h":32,"hp":100,"maxHp":100,"speed":0.0,"hostile":false,"chatterCd":999999.0}
	rig.game.npcs.append(cop)
	var memory := Memory.new(rig.game)
	rig.director.tick_dog_discomfort(); memory.tick(16.0); rig.companions.tick_world(16.0)
	_check(not cop.has("dogSpookSlow") and memory.condition("underpass"),"return enables actual underpass presence but aura waits next step")
	rig.director.tick(16.0,16.0)
	_check(not cop.has("dogSpookSlow"),"configured Director does not repeat aura after new return")
	rig.game.s.freedDogFollowT = 1
	rig.director.tick_dog_discomfort(); memory.tick(16.0); rig.companions.tick_world(16.0)
	_check(cop.get("dogSpookSlow",0) == 1 and not memory.condition("underpass"),"last follow step gives source aura before expiry closes underpass")
	rig.game.s.mode = "paused"; var timer: float = rig.game.s.freedDogT
	_check(not rig.companions.tick_world(16.0) and rig.game.s.freedDogT == timer,"world lifecycle pauses with menus")
	groups += 1
