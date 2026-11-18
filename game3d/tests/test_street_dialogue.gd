extends SceneTree
const Memory = preload("res://scripts/memory_loop.gd")
const Travel = preload("res://scripts/travel_system.gd")
const Street = preload("res://scripts/street_dialogue.gd")
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
	var calls: int = 0
	func can_reach_target(_id: String) -> bool: calls += 1; return visible
class FeedContractProbe:
	extends RefCounted
	## A delegate recorder only: not the future production8-post/silence/UI system.
	var visible: bool = false
	var allow_open: bool = true
	var allow_post: bool = true
	var day: int = 1
	var posts: Array[Dictionary] = []
	func show_feed() -> bool:
		if not allow_open: return false
		visible = true; return true
	func post(text: String,author: String) -> bool:
		if not allow_post: return false
		posts.push_front({"h":author,"t":text,"day":day}); return true
class ActivityContractProbe:
	extends RefCounted
	## Records the handoff. It deliberately performs no fake cost, rhythm or payout.
	var calls: int = 0
	var accept: bool = false
	func start_paid_karaoke() -> Dictionary:
		calls += 1
		return {"ok":true,"token":"owned-by-P09"} if accept else {"ok":false,"reason":"activity_not_ready"}

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	_oracle()
	_live_guards()
	_pinky_travel()
	_compatibility()
	_dependencies()
	_lifecycle()
	_check(completed == 53,"all53 source fixtures completed without script abort")
	_check(groups == 6,"all6 street groups completed without script abort")
	if failures.is_empty():
		print("3D STREET GATE: PASS (%d checks;53 source fixtures;15 authored handlers;Phone/Karaoke production dependencies explicitly partial)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D STREET GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
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
	var travel := Travel.new(game,spatial)
	var phone := FeedContractProbe.new()
	var activities := ActivityContractProbe.new()
	var street := Street.new(game,spatial,memory,travel,activities,phone)
	game.s.mode = "playing"; game.events.clear()
	return {"game":game,"spatial":spatial,"memory":memory,"travel":travel,"phone":phone,"activities":activities,"street":street,"event_cursor":0}
func _actor(rig: Dictionary,id: String) -> Dictionary:
	for body: Dictionary in rig.game.npcs:
		if body.id == id: return body
	return {}
func _at(rig: Dictionary,id: String) -> void:
	var body := _actor(rig,id)
	rig.game.p.x = float(body.x)+(float(body.w)-float(rig.game.p.w))*0.5
	rig.game.p.y = float(body.y)+(float(body.h)-float(rig.game.p.h))*0.5
func _open(rig: Dictionary,id: String) -> Dictionary:
	_at(rig,id); return rig.street.open(id)
func _choice(menu: Dictionary,id: String) -> Dictionary:
	for option: Dictionary in menu.get("options",[]):
		if option.id == id: return option
	return {}
func _act(rig: Dictionary,id: String,action: String) -> Dictionary:
	var menu := _open(rig,id)
	return rig.street.select(menu.token,action) if menu.get("token") is String else menu
func _events(game: RefCounted,kind: String) -> int:
	var count: int = 0
	for event: Dictionary in game.events:
		if event.kind == kind: count += 1
	return count
func _drain_feed_contract(rig: Dictionary) -> void:
	for index: int in range(rig.event_cursor,rig.game.events.size()):
		var event: Dictionary = rig.game.events[index]
		if event.kind == "feed": rig.phone.post(event.payload.text,event.payload.author)
	rig.event_cursor = rig.game.events.size()
func _menu(actual: Dictionary,expected: Variant,label: String) -> void:
	if expected == null:
		_check(not actual.has("options"),label+" no modal"); return
	_check(actual.get("ok",false) and actual.has("token"),label+" live menu")
	_fields(actual,{"title":expected.title,"text":expected.text},label)
	var options: Array = actual.get("options",[])
	_check(options.size() == expected.options.size(),label+" choice count")
	for index: int in range(mini(options.size(),expected.options.size())): _fields(options[index],expected.options[index],label+".option%d" % index)
func _oracle() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/street_reference.json"))
	_check(fixture.cases.size() == 53,"53 source fixtures present")
	for test: Dictionary in fixture.cases:
		var rig := _rig()
		var game: RefCounted = rig.game
		game.roll = test.roll
		game.p.merge(test.setup.player.duplicate(true),true); game.s.merge(test.setup.state.duplicate(true),true)
		game.s.counters.merge(test.setup.counters.duplicate(true),true); rig.phone.day = game.s.day
		for step: Dictionary in test.steps:
			var operation: Dictionary = step.operation
			var current := _open(rig,operation.actor)
			_menu(current,step.before,test.id+".before")
			var option := _choice(current,operation.action)
			if not option.is_empty() and option.enabled: current = rig.street.select(current.token,operation.action)
			_menu(current,step.after,test.id+".after")
			_fields(game.p,step.expected.player,test.id+".player")
			_fields(game.s.counters,step.expected.counters,test.id+".counter")
			_check(game.s.barbAside == step.expected.barbAside,test.id+" Barb aside")
			var achievements: Array = game.s.achievements.duplicate(); achievements.sort()
			_check(_same(achievements,step.expected.achievements),test.id+" achievements")
			_check(_same(game.s.recognition,step.expected.recognition),test.id+" recognition")
			_drain_feed_contract(rig)
			_check(_same({"posts":rig.phone.posts,"visible":rig.phone.visible},step.expected.phone),test.id+" feed delegate payload/visibility contract")
			_check(_actor(rig,"jogger").speed == step.expected.joggerSpeed,test.id+" Jogger speed")
		completed += 1
	groups += 1

func _live_guards() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.p.cash = 100
	var menu := _open(rig,"pinky")
	var rolls: int = game.rolls
	rig.spatial.visible = false
	_check(not rig.street.select(menu.token,"buy_five").ok and game.p.cash == 100,"current LOS prevents payment")
	_check(game.rolls == rolls,"failed selection does not reroll opening flavor")
	_check(not rig.street.select(menu.token,"buy_five").ok,"rejected geometry consumes token")
	rig.spatial.visible = true; menu = _open(rig,"cubscout"); game.p.cash = 7
	_check(not rig.street.select(menu.token,"popcorn").ok and game.p.cred == 0,"current cash checked before literal purchase")
	game.p.cash = 100; menu = _open(rig,"pinky"); game.p.faction.street = -10
	_check(not rig.street.select(menu.token,"buy_one").ok and game.p.cash == 100,"current hated tier removes old supply action")
	game.p.faction.street = 0; menu = _open(rig,"busker"); _actor(rig,"busker").dead = true
	_check(not rig.street.select(menu.token,"tip").ok and game.p.cash == 100,"dead resident cannot spend old capability")
	game.s.bossKind = "tony"; game.s.bossActive = true
	_check(_open(rig,"pinky").ok,"ordinary Tony fight preserves street conversation")
	menu = _open(rig,"pinky"); game.s.bossKind = "kingdom"
	_check(not rig.street.select(menu.token,"cut").ok,"kingdom lock rechecked")
	game.s.bossKind = ""; _at(rig,"pinky"); game.p.x += 60
	_check(not rig.street.open("pinky").ok,"strict60px boundary")
	_check(not rig.street.supports("price_guy") and not rig.street.open("invented").ok,"day-event/unknown residents are not replaced")
	groups += 1

func _pinky_travel() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.p.cash = 100; game.p.charisma = 1
	_act(rig,"pinky","buy_one"); _act(rig,"pinky","buy_five")
	_check(game.p.cash == 80 and game.p.supplies == 6 and game.p.dirtySupplies == 6,"Pinky uses exact rounded4/18 discount")
	_check(game.s.counters.pinkyFirstBuy == 1 and game.s.barbAside and _events(game,"news") == 1,"first-buy side effects fire once")
	game.s.barbAside = false; _act(rig,"pinky","buy_five")
	_check(not game.s.barbAside and game.p.supplies == 11,"later packets do not restore aside or invent daily cap")
	var supply: int = game.p.supplies; var dirty: int = game.p.dirtySupplies
	_act(rig,"pinky","buy_pass")
	_check(game.p.cash == 44 and rig.travel.has_bus_pass() and game.p.supplies == supply and game.p.dirtySupplies == dirty,"single Travel pass owner charges fixed20 independently")
	var menu := _open(rig,"pinky")
	_check(_choice(menu,"buy_pass").is_empty() and not _choice(menu,"use_pass").is_empty(),"owned pass replaces sale option")
	var route: Dictionary = rig.street.select(menu.token,"use_pass")
	_check(route.get("domain") == "travel" and route.get("service") == "bus" and route.has("token"),"Pinky hands actual destination capability to Travel")
	_check(not rig.street.select(route.token,"leave").ok,"Travel token cannot be submitted to Street")
	_check(rig.travel.select(route.token,"leave").ok,"Travel remains destination/menu owner")
	var first_pass := _rig()
	first_pass.game.p.cash = 20
	_act(first_pass,"pinky","buy_pass")
	_check(first_pass.game.s.counters.pinkyFirstBuy == 0 and not first_pass.game.s.barbAside and first_pass.game.p.faction.street == 0,"bus pass does not trigger supply introduction")
	var stale := _rig()
	stale.game.p.cash = 40; menu = _open(stale,"pinky")
	stale.street.inventory.append_item("bus_pass","a bus pass")
	_check(not stale.street.select(menu.token,"buy_pass").ok and stale.game.p.cash == 40,"pass acquired after opening prevents duplicate spend")
	groups += 1

func _compatibility() -> void:
	var horse := _rig()
	horse.game.p.hp = 5; horse.game.p.iframes = 777; horse.game.p.hitFlash = 123; horse.game.s.combo = 4; horse.game.roll = 0.4
	_act(horse,"horsecop","pet")
	_check(horse.game.p.hp == -1 and horse.game.p.iframes == 777 and horse.game.p.hitFlash == 123 and horse.game.s.combo == 4,"Horse source raw HP bypasses combat effects")
	_check(_events(horse.game,"death") == 0 and horse.game.s.mode == "playing","Horse negative HP does not invent immediate respawn")
	var taco := _rig()
	taco.game.p.cash = 4; taco.game.p.hp = 5; taco.game.p.iframes = 777; taco.game.roll = 0.15
	_act(taco,"food_truck","taco")
	_check(taco.game.p.hp == -5 and taco.game.p.iframes == 777 and _events(taco.game,"death") == 0,"Taco heal-before-raw-cost preserves negative HP")
	var truck := _rig()
	truck.game.p.rocks = 3; truck.game.p.cash = 15; truck.game.p.charisma = 1
	var menu := _open(truck,"food_truck")
	var burrito := _choice(menu,"burrito")
	_check(burrito.enabled and burrito.label == "specials are $15.","Burrito label and eligibility preserve shipped asymmetry")
	truck.street.select(menu.token,"burrito")
	_check(truck.game.p.rocks == 4 and truck.game.p.cash == 0,"Burrito uses cash-only action and fixed15 despite charisma")
	var repeat := _rig()
	_act(repeat,"dogwalker","pet"); _act(repeat,"dogwalker","pet")
	_act(repeat,"horsecop","nod"); _act(repeat,"horsecop","compliment")
	_check(repeat.game.p.cred == 7,"canonical repeatable social grants stay uncapped")
	repeat.game.s.dayTime = 0.9; repeat.game.p.cash = 8
	_check(_act(repeat,"cubscout","popcorn").ok and repeat.game.p.cash == 0,"Cubscout callback has no invented night gate")
	var banter := _rig()
	_open(banter,"busker"); banter.street.close(); banter.game.events.clear()
	banter.game.p.cash = 1; _act(banter,"busker","tip")
	_check(_events(banter.game,"save_requested") == 0,"ordinary inline tip preserves no immediate save")
	var jogger := _rig()
	var speed: float = _actor(jogger,"jogger").speed
	jogger.game.roll = 0.4; _act(jogger,"jogger","dollar")
	_check(_actor(jogger,"jogger").speed == speed and jogger.game.p.cash == 0,"failure toast does not create Jogger speed change")
	groups += 1

func _dependencies() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.p.cash = 100
	var plain := Street.new(game,rig.spatial)
	_at(rig,"pinky")
	var menu: Dictionary = plain.open("pinky")
	_check(not plain.select(menu.token,"buy_pass").ok and game.p.cash == 100,"missing Travel refuses before pass payment")
	_at(rig,"laundromat_lady"); menu = plain.open("laundromat_lady")
	_check(not plain.select(menu.token,"laundry").ok and game.p.cash == 100 and game.s.counters.get("laundryDone",0) == 0,"missing Memory refuses laundry atomically")
	menu = plain.open("laundromat_lady")
	_check(not plain.select(menu.token,"detergent").ok and plain.inventory.count_records("detergent") == 0,"missing Memory refuses detergent before item or cash")
	_at(rig,"phoneguy"); var rolls: int = game.rolls
	var met: Array = game.s.metVendors.duplicate()
	_check(not plain.open("phoneguy").ok and game.s.metVendors == met and game.rolls == rolls,"missing feed refuses Phone opening without claiming visibility")
	_at(rig,"karaoke"); menu = plain.open("karaoke")
	_check(menu.ok and not plain.select(menu.token,"sing").ok and game.p.cash == 100 and game.rolls == rolls,"missing rhythm refuses before cost or random sequence")
	menu = _open(rig,"karaoke")
	_check(not rig.street.select(menu.token,"sing").ok and rig.activities.calls == 1 and game.p.cash == 100,"rhythm owner refusal cannot precharge")
	rig.activities.accept = true; menu = _open(rig,"karaoke")
	var result: Dictionary = rig.street.select(menu.token,"sing")
	_check(result.get("domain") == "activities" and result.token == "owned-by-P09" and game.p.cash == 100,"Street passes actual external capability without a second charge or fake reward")
	rig.phone.allow_open = false; _at(rig,"phoneguy")
	_check(not rig.street.open("phoneguy").ok and not rig.phone.visible,"feed refusal does not fake opening")
	rig.phone.allow_open = true; menu = _open(rig,"phoneguy"); rig.phone.allow_post = false
	_check(not rig.street.select(menu.token,"content").ok and game.p.cash == 100 and rig.phone.posts.is_empty(),"refused post cannot take3cash")
	var released := _rig()
	menu = _open(released,"phoneguy"); released.phone = null
	rolls = released.game.rolls
	_check(not released.street.select(menu.token,"posting").ok and released.game.rolls == rolls,"released feed dependency refuses before random post")
	groups += 1

func _lifecycle() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	var menu := _open(rig,"dogwalker")
	game.fresh(); game.s.mode = "playing"
	_check(rig.street.select(menu.token,"pet").reason == "replaced_state","fresh invalidates Street epoch")
	menu = _open(rig,"dogwalker"); game.restore(game.snapshot()); game.s.mode = "playing"
	_check(rig.street.select(menu.token,"pet").reason == "replaced_state","restore invalidates Street epoch")
	menu = _open(rig,"dogwalker"); rig.street.close()
	_check(not rig.street.select(menu.token,"pet").ok,"close revokes Street capability")
	menu = _open(rig,"dogwalker")
	var another := Street.new(game,rig.spatial,rig.memory,rig.travel)
	var foreign: Dictionary = another.open("dogwalker")
	_check(not rig.street.select(foreign.token,"pet").ok and rig.street.select(menu.token,"pet").ok,"foreign token cannot select another handler's action")
	var isolated := FixedState.new()
	var spatial := Spatial.new()
	var handler := Street.new(isolated,spatial)
	var owner_ref: WeakRef = weakref(isolated)
	isolated = null
	_check(owner_ref.get_ref() == null and not handler.open("pinky").ok,"Street does not retain player owner")
	var saved := _rig()
	saved.game.p.cash = 100
	_act(saved,"pinky","buy_one"); _act(saved,"laundromat_lady","laundry"); _act(saved,"food_truck","taco")
	var data: Dictionary = saved.game.snapshot()
	_check(saved.game.restore(data).ok and saved.game.s.counters.pinkyFirstBuy == 1 and saved.game.s.counters.laundryDone == 1 and saved.game.s.counters.tacosEaten == 1,"durable source counters survive real save roundtrip")
	_check(saved.game.p.supplies == 1 and saved.game.p.dirtySupplies == 1 and saved.game.s.barbAside,"supply and first-buy aside survive roundtrip")
	groups += 1
