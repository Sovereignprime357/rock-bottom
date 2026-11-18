extends SceneTree
const Memory = preload("res://scripts/memory_loop.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Bosses = preload("res://scripts/boss_system.gd")
const Quests = preload("res://scripts/quest_dialogue.gd")
var checks: int = 0
var completed: int = 0
var groups: int = 0
var failures: Array[String] = []

class FixedState:
	extends "res://scripts/game_state.gd"
	var roll: float = 0.75
	var rolls: int = 0
	func random_float() -> float: rolls += 1; return roll
	func random_index(size: int) -> int: return mini(size-1,int(floor(random_float()*size))) if size > 0 else 0
class Spatial:
	extends RefCounted
	var visible: bool = true
	var placeable: bool = true
	var zone_clear: bool = true
	var calls: int = 0
	func can_reach_target(_id: String) -> bool: calls += 1; return visible
	func can_use_zone(_id: String) -> bool: calls += 1; return zone_clear
	func clear_placement(body: Dictionary) -> Variant: return Vector2(body.x,body.y) if placeable else null
	func move_body(_body: Dictionary,intended: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary: return {"position":intended,"blocked":false}
	func can_hit(_a: Vector2,_b: Vector2,_source: String,_target: String) -> bool: return visible

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	_oracle()
	_live_guards()
	_crossword()
	_stripe()
	_crown()
	_package_and_wait()
	_lifecycle()
	_check(completed == 56,"all56 source fixtures completed without script abort")
	_check(groups == 7,"all7 quest groups completed without script abort")
	if failures.is_empty():
		print("3D QUEST GATE: PASS (%d checks;56 source fixtures;five linked handlers,crown/package lifecycle,live sessions;runtime/scene pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D QUEST GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
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
		_check(actual.has(key) and _same(actual.get(key),expected[key]),"%s.%s actual=%s expected=%s" % [label,key,str(actual.get(key)),str(expected[key])])
func _rig() -> Dictionary:
	var game := FixedState.new()
	var spatial := Spatial.new()
	var memory := Memory.new(game)
	var combat := Combat.new(game,spatial)
	var bosses := Bosses.new(game,combat)
	var quests := Quests.new(game,spatial,memory,combat,bosses)
	game.s.mode = "playing"; game.events.clear()
	return {"game":game,"spatial":spatial,"memory":memory,"combat":combat,"bosses":bosses,"quests":quests}
func _at(rig: Dictionary,id: String) -> void:
	var body: Dictionary = rig.combat.actor(id)
	rig.game.p.x = float(body.x)+(float(body.w)-float(rig.game.p.w))*0.5
	rig.game.p.y = float(body.y)+(float(body.h)-float(rig.game.p.h))*0.5
func _block(rig: Dictionary) -> void:
	for zone: Dictionary in rig.game.content.world.zones:
		if zone.id == "block":
			rig.game.p.x = zone.x+zone.w*0.5-rig.game.p.w*0.5
			rig.game.p.y = zone.y+zone.h*0.5-rig.game.p.h*0.5
			return
func _open(rig: Dictionary,id: String) -> Dictionary:
	_at(rig,id); return rig.quests.open(id)
func _choice(menu: Dictionary,id: String) -> Dictionary:
	for option: Dictionary in menu.get("options",[]):
		if option.id == id: return option
	return {}
func _act(rig: Dictionary,id: String,action: String) -> Dictionary:
	var menu := _open(rig,id)
	return rig.quests.select(menu.token,action) if menu.get("token") is String else menu
func _events(game: RefCounted,kind: String) -> int:
	var count: int = 0
	for event: Dictionary in game.events:
		if event.kind == kind: count += 1
	return count
func _menu(actual: Dictionary,expected: Variant,label: String) -> void:
	if expected == null:
		_check(not actual.has("options"),label+" no modal"); return
	_check(actual.get("ok",false) and actual.has("token"),label+" live menu")
	_fields(actual,{"title":expected.title,"text":expected.text},label)
	var options: Array = actual.get("options",[])
	_check(options.size() == expected.options.size(),label+" choice count")
	for index: int in range(mini(options.size(),expected.options.size())):
		_fields(options[index],expected.options[index],label+".option%d" % index)
func _snapshot(game: RefCounted,expected: Dictionary,label: String) -> void:
	_fields(game.p,expected.player,label+".player")
	_fields(game.s.counters,expected.counters,label+".counter")
	_fields(game.s.flags,expected.flags,label+".flag")
	_fields(game.s,expected.state,label+".state")
	_check(game.p.lifetime.get("rocksFenced",0) == expected.rocksFenced,label+" lifetime fence count")
	for id: String in expected.quests: _fields(game.s.quests[id],expected.quests[id],label+".quest."+id)
	var achievements: Array = game.s.achievements.duplicate(); achievements.sort()
	_check(_same(achievements,expected.achievements),label+" achievements")
	_check(_same(game.s.recognition,expected.recognition),label+" recognition")
	var actors: Array[Dictionary] = []
	for body: Dictionary in game.npcs:
		if body.id in ["dave","stripe","tony"]: actors.append(body)
	_check(actors.size() == expected.actors.size(),label+" actor count")
	for index: int in range(mini(actors.size(),expected.actors.size())): _fields(actors[index],expected.actors[index],label+".actor")
func _oracle() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/quest_reference.json"))
	_check(fixture.cases.size() == 56,"56 source fixtures present")
	for test: Dictionary in fixture.cases:
		var rig := _rig()
		var game: RefCounted = rig.game
		game.roll = test.roll
		game.p.merge(test.setup.player.duplicate(true),true); game.s.merge(test.setup.state.duplicate(true),true)
		game.s.flags.merge(test.setup.flags.duplicate(true),true); game.s.counters.merge(test.setup.counters.duplicate(true),true)
		for id: String in test.setup.quests: game.s.quests[id].merge(test.setup.quests[id].duplicate(true),true)
		var current: Dictionary = {}
		for step: Dictionary in test.steps:
			var operation: Dictionary = step.operation
			if operation.get("kind") == "package":
				_block(rig); current = rig.quests.open_package()
			elif operation.get("kind") == "lifecycle":
				var conductor: Dictionary = rig.combat.actor("conductor")
				game.npcs.clear()
				if not operation.get("crown",false): game.npcs.append(conductor)
				conductor.x = 2986; conductor.y = 3984; conductor.dead = operation.get("dead",false)
				game.p.x = 3000.0+float(operation.distance)-game.p.w*0.5; game.p.y = 4000.0-game.p.h*0.5
				game.s.flags.introDone = true; game.s.mode = "playing"
				if operation.dt > 0: rig.quests.tick_before_pickups(operation.dt)
				current = rig.quests.tick_after_pickups()
			else:
				if not operation.get("reuse",false): current = _open(rig,operation.actor)
				_menu(current,step.before,test.id+".before")
				if operation.action != null:
					var option := _choice(current,operation.action)
					if not option.is_empty() and option.enabled: current = rig.quests.select(current.token,operation.action)
			_menu(current,step.after,test.id+".after")
			_snapshot(game,step.expected,test.id)
		completed += 1
	groups += 1

func _live_guards() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.p.cash = 20
	var menu := _open(rig,"barb")
	var visits: int = game.s.counters.barbVisits
	var rolls: int = game.rolls
	rig.spatial.visible = false
	_check(not rig.quests.select(menu.token,"buy_one").ok and game.p.cash == 20,"live LOS prevents stale payment")
	_check(game.s.counters.barbVisits == visits and game.rolls == rolls,"validation does not replay opening effects")
	_check(not rig.quests.select(menu.token,"buy_one").ok,"refused geometry consumes token")
	rig.spatial.visible = true; menu = _open(rig,"barb"); game.p.cash = 0
	_check(not rig.quests.select(menu.token,"buy_one").ok and game.p.supplies == 0,"current cash rechecked")
	game.p.cash = 100; menu = _open(rig,"barb"); game.s.counters.barbPacketsToday = 6
	_check(not rig.quests.select(menu.token,"buy_five").ok and game.p.cash == 100,"current daily cap rechecked")
	menu = _open(rig,"stripe"); game.s.flags.hasStripePackage = true
	_check(not rig.quests.select(menu.token,"buy_rock").ok and game.p.cash == 100,"held package invalidates commerce")
	game.s.flags.hasStripePackage = false; menu = _open(rig,"stripe"); rig.combat.actor("stripe").isAlly = true
	_check(not rig.quests.select(menu.token,"buy_rock").ok and game.p.cash == 100,"ally callback replacement invalidates commerce")
	rig.combat.actor("stripe").isAlly = false; menu = _open(rig,"conductor"); rig.combat.actor("conductor").dead = true
	_check(not rig.quests.select(menu.token,"train").ok,"dead actor cannot run old action")
	game.s.bossKind = "tony"; game.s.bossActive = true
	_check(_open(rig,"barb").ok,"ordinary Tony fight permits quest vendor")
	menu = _open(rig,"barb"); game.s.bossKind = "kingdom"
	_check(not rig.quests.select(menu.token,"contents").ok,"kingdom lock revalidated")
	game.s.bossKind = ""; _at(rig,"barb"); game.p.x += 60
	_check(not rig.quests.open("barb").ok,"strict60px interaction boundary")
	_check(not rig.quests.supports("pinky") and not rig.quests.open("pinky").ok,"unsupported dispatch stays explicit")
	groups += 1

func _crossword() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	_act(rig,"barb","leave"); _act(rig,"barb","leave")
	_check(game.s.quests.barb_crossword.available and game.s.flags.daveHasCrossword,"second actual visit starts crossword")
	var menu := _act(rig,"dave","demand")
	var token: String = menu.token
	var before: int = game.s.counters.barbVisits
	game.p.cash = 20
	var result: Dictionary = rig.quests.select(token,"pay_ransom")
	_check(result.ok and game.p.cash == 0 and game.s.flags.hasCrossword,"ransom produces actual quest inventory")
	_check(not rig.quests.select(token,"pay_ransom").ok and game.p.cash == 0,"ransom cannot replay")
	game.s.counters.barbPacketsToday = 6
	menu = _act(rig,"barb","return_crossword")
	_check(game.s.quests.barb_crossword.done and game.p.supplies == 1 and game.s.counters.barbPacketsToday == 6,"crossword reward independent of packet cap")
	_check(game.s.counters.barbVisits == before+1 and not game.s.flags.hasCrossword and rig.quests.inventory.count_records("crossword") == 0,"return page does not count another visit and consumes crossword")
	rig.quests.select(menu.token,"leave")
	_act(rig,"barb","answer")
	_check(game.p.supplies == 1,"post-completion answer cannot reward again")
	var fight := _rig()
	fight.game.s.quests.barb_crossword.available = true; fight.game.s.flags.daveHasCrossword = true
	var plain := Quests.new(fight.game,fight.spatial,fight.memory)
	_at(fight,"dave"); menu = plain.open("dave"); menu = plain.select(menu.token,"demand")
	_check(not plain.select(menu.token,"fight_dave").ok and fight.combat.actor("dave").asleep,"missing combat refuses without waking Dave")
	var unsaved := _rig()
	_open(unsaved,"dave"); unsaved.quests.close(); unsaved.game.events.clear()
	_act(unsaved,"dave","wake")
	_check(_events(unsaved.game,"save_requested") == 0,"wake preserves source no-immediate-save")
	groups += 1

func _stripe() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.p.rocks = 3; game.s.counters.stripeFencedToday = 9
	_act(rig,"stripe","fence_bulk")
	_check(game.p.rocks == 2 and game.p.cash == 2 and game.p.lifetime.rocksFenced == 1,"bulk consumes only one remaining daily slot")
	game.p.rocks = 4; game.s.counters.stripeFencedToday = 0; game.p.faction.spiritual = 10
	_act(rig,"stripe","fence_bulk")
	_check(game.p.faction.spiritual == 8,"spiritual cap shared with earlier same-day rock")
	game.s.day += 1; game.s.counters.stripeFencedToday = 0; game.p.rocks = 3
	_act(rig,"stripe","fence_bulk")
	_check(game.p.faction.spiritual == 5,"next-day spiritual governor resets by stamp")
	var coop := _rig()
	coop.game.p.stripeLoyalty = 5
	var menu := _act(coop,"stripe","about")
	coop.spatial.placeable = false
	var original: Dictionary = coop.combat.actor("stripe").duplicate(true)
	_check(not coop.quests.select(menu.token,"agree_coop").ok and not coop.game.s.bossActive and coop.combat.actor("stripe") == original,"failed coop placement is atomic")
	coop.spatial.placeable = true; menu = _act(coop,"stripe","about")
	_check(coop.quests.select(menu.token,"agree_coop").ok and coop.combat.actor("stripe").get("isAlly",false),"real boss owner establishes alliance")
	var visits: int = coop.game.s.counters.stripeVisits
	menu = _open(coop,"stripe")
	_check(menu.get("closed",false) and coop.game.s.counters.stripeVisits == visits,"ally interaction does not reopen old commerce")
	var absent := _rig()
	var plain := Quests.new(absent.game,absent.spatial,absent.memory,absent.combat)
	absent.game.p.stripeLoyalty = 5; _at(absent,"stripe"); menu = plain.open("stripe"); menu = plain.select(menu.token,"about")
	_check(not plain.select(menu.token,"agree_coop").ok and not absent.game.s.bossActive,"missing boss cannot fake alliance")
	groups += 1

func _crown() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.s.counters.pigeonVisits = 1; game.roll = 0.1
	var menu := _act(rig,"pigeon","crown")
	var spot: Dictionary = rig.quests.pick_crown_spot()
	var rolls: int = game.rolls
	rig.quests.select(menu.token,"decline_crown"); menu = _act(rig,"pigeon","crown")
	_check(rig.quests.pick_crown_spot() == spot and game.rolls == rolls,"declining retains source spot without reroll")
	rig.quests.select(menu.token,"accept_crown")
	game.s.mode = "playing"; game.p.x = spot.x-game.p.w*0.5; game.p.y = spot.y-game.p.h*0.5
	rig.spatial.visible = false
	_check(not rig.quests.collect_crown() and not game.s.crownPickup.collected,"real crown obstruction prevents pickup")
	rig.spatial.visible = true; game.p.x += 18
	_check(not rig.quests.collect_crown(),"strict18px crown boundary")
	game.p.x -= 18
	_check(rig.quests.collect_crown() and game.p.equip.hat == "pigeon_crown" and game.p.charisma == 1,"crown equips through core stats")
	var rewards: int = _events(game,"quest_completed")
	_check(not rig.quests.collect_crown() and _events(game,"quest_completed") == rewards,"collected crown cannot reward twice")
	var saved: Dictionary = game.snapshot()
	_check(game.restore(saved).ok and game.s.crownPickup.collected and game.p.equip.hat == "pigeon_crown","durable crown and equipment restore together")
	for malformed: Variant in [null,{},{"x":NAN,"y":20,"collected":false},{"x":20,"y":INF,"collected":false},{"x":-1,"y":20,"collected":false},{"x":20,"y":5601,"collected":false},{"x":20,"y":20,"collected":1}]:
		_check(Quests.normalize_crown(malformed) == null,"malformed crown normalizes to null")
	_check(Quests.normalize_crown({"x":8600,"y":5600,"collected":true}) == {"x":8600.0,"y":5600.0,"collected":true},"valid edge crown remains exact")
	for index: Variant in [-1,99,0.5,NAN,"2"]:
		game.s.flags.crownSpotIdx = index
		var chosen: Dictionary = rig.quests.pick_crown_spot()
		_check(not chosen.is_empty() and game.s.flags.crownSpotIdx is int,"malformed spot index cannot unsafe-index catalog")
	var overlap := _rig()
	overlap.game.s.counters.pigeonVisits = 1
	var old_offer := _act(overlap,"pigeon","crown")
	var second := Quests.new(overlap.game,overlap.spatial,overlap.memory,overlap.combat,overlap.bosses)
	menu = second.open("pigeon"); menu = second.select(menu.token,"crown"); second.select(menu.token,"accept_crown")
	var accepted_pickup: Dictionary = overlap.game.s.crownPickup.duplicate(true)
	_check(not overlap.quests.select(old_offer.token,"accept_crown").ok and overlap.game.s.crownPickup == accepted_pickup,"already accepted crown quest invalidates another handler's stale offer")
	groups += 1

func _package_and_wait() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.s.flags.hasStripePackage = true; game.s.quests.stripe_package.available = true
	rig.quests.inventory.append_item("stripe_package","stripe's sealed package")
	_at(rig,"conductor"); game.s.conductorWaitT = 59950
	_check(rig.quests.tick_before_pickups(50) and game.s.achievements.has("the_conductor_knows"),"source wait reaches60s")
	rig.spatial.visible = false
	_check(rig.quests.tick_after_pickups().is_empty() and game.s.flags.hasStripePackage,"delivery checks current wall LOS")
	rig.spatial.visible = true; game.p.x += 60
	_check(rig.quests.tick_after_pickups().is_empty(),"strict60px delivery boundary")
	_at(rig,"conductor"); game.s.bossKind = "kingdom"
	var menu: Dictionary = rig.quests.tick_after_pickups()
	_check(menu.has("token") and not game.s.flags.hasStripePackage and game.p.cash == 40 and game.p.cred == 3,"automatic delivery preserves source non-interaction kingdom behavior")
	_check(game.s.mode == "dialogue" and not rig.quests.tick_before_pickups(16),"delivery pauses subsequent updates")
	rig.quests.select(menu.token,"leave"); game.s.bossKind = ""
	game.s.flags.hasStripePackage = true; menu = rig.quests.tick_after_pickups()
	_check(menu.has("token") and game.p.cash == 40 and game.p.cred == 3,"malformed held flag cannot repeat completed delivery reward")
	rig.quests.close(); _at(rig,"conductor"); game.s.conductorWaitT = 123
	rig.combat.actor("conductor").dead = true; rig.quests.tick_before_pickups(16)
	_check(game.s.conductorWaitT == 123,"dead Conductor freezes source wait")
	rig.combat.actor("conductor").dead = false; game.p.x += 80; rig.quests.tick_before_pickups(16)
	_check(game.s.conductorWaitT == 0,"strict80px wait boundary resets")
	for dt: float in [0.0,-1.0,51.0,NAN,INF]: _check(not rig.quests.tick_before_pickups(dt),"invalid active delta rejected")
	var parcel := _rig()
	game = parcel.game; game.roll = 0.9; game.s.flags.hasStripePackage = true
	_block(parcel); parcel.spatial.zone_clear = false
	var rolls: int = game.rolls
	_check(not parcel.quests.open_package().ok and game.s.flags.hasStripePackage and game.rolls == rolls,"blocked Block opening has no partial roll or consume")
	parcel.spatial.zone_clear = true; game.p.x = 8500
	_check(not parcel.quests.open_package().ok and game.s.flags.hasStripePackage,"outside Block cannot open package")
	_block(parcel); menu = parcel.quests.open_package()
	_check(menu.options[0].id == "sprint" and game.p.wanted == 2 and game.s.flags.stripeBetrayed,"bait applies exact result with actual close choice")
	_check(game.s.counters.stripeBetrayed == 0 and not game.s.achievements.has("judas"),"opening is not Stripe death counter or Judas achievement")
	_check(not parcel.quests.select(menu.token,"leave").ok,"unshown package exit is rejected")
	_check(not parcel.quests.open_package().ok and game.p.wanted == 2,"package cannot be opened twice")
	groups += 1

func _lifecycle() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	var menu := _open(rig,"barb")
	game.fresh(); game.s.mode = "playing"
	_check(rig.quests.select(menu.token,"contents").reason == "replaced_state","fresh invalidates quest token")
	menu = _open(rig,"barb"); game.restore(game.snapshot()); game.s.mode = "playing"
	_check(rig.quests.select(menu.token,"contents").reason == "replaced_state","restore invalidates quest token")
	menu = _open(rig,"barb"); rig.quests.close()
	_check(not rig.quests.select(menu.token,"contents").ok,"close revokes quest token")
	var isolated := FixedState.new()
	var spatial := Spatial.new()
	var handler := Quests.new(isolated,spatial)
	var owner_ref: WeakRef = weakref(isolated)
	isolated = null
	_check(owner_ref.get_ref() == null and not handler.open("barb").ok,"quest handler and normalizer do not retain owner")
	var missing := _rig()
	var plain := Quests.new(missing.game,missing.spatial)
	missing.game.p.cash = 100; _at(missing,"barb"); menu = plain.open("barb")
	_check(not plain.select(menu.token,"buy_five").ok and missing.game.p.cash == 100,"missing memory cannot consume purchase")
	var both := _rig()
	_at(both,"conductor"); both.game.s.crownPickup = {"x":both.game.player_center().x,"y":both.game.player_center().y,"collected":false}
	both.game.s.flags.hasStripePackage = true
	menu = both.quests.tick_after_pickups()
	_check(both.game.s.crownPickup.collected and both.game.s.quests.pigeon_crown.done and both.game.s.quests.stripe_package.done and menu.has("token"),"same update collects crown before delivery pauses future updates")
	var crown_index: int = -1; var delivery_index: int = -1
	for index: int in range(both.game.events.size()):
		if both.game.events[index].kind == "quest_pickup_changed": crown_index = index
		if both.game.events[index].kind == "package_delivered": delivery_index = index
	_check(crown_index >= 0 and delivery_index > crown_index,"source crown-before-package order visible in events")
	var migrated := _rig()
	migrated.game.p.inventory.append({"id":"junk","n":"junk","q":80,"migration_units":true})
	migrated.game.s.flags.hasStripePackage = true
	migrated.quests.inventory.append_item("stripe_package","stripe's sealed package")
	_block(migrated); migrated.game.roll = 0.35; migrated.quests.open_package()
	_check(migrated.game.p.inventory[0].q == 80 and migrated.game.p.inventory[0].migration_units and migrated.quests.inventory.count_records("soap") == 2,"quest removal leaves migrated stacks intact and adds two source records")
	groups += 1
