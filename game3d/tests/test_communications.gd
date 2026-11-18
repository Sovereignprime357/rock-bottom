extends SceneTree
const Props = preload("res://scripts/prop_state.gd")
const Comms = preload("res://scripts/communications_system.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const Street = preload("res://scripts/street_dialogue.gd")
var checks: int = 0
var completed: int = 0
var groups: int = 0
var failures: Array[String] = []
class FixedState:
	extends "res://scripts/game_state.gd"
	var rolls: Array[float] = []
	var cursor: int = 0
	func random_float() -> float:
		var result: float = rolls[cursor] if cursor < rolls.size() else 0.75
		cursor += 1; return result
	func random_index(size: int) -> int: return mini(size-1,int(floor(random_float()*size))) if size > 0 else -1
class Clock:
	extends RefCounted
	var now: float = 1000000.0
	func unix_ms() -> float: return now
class Spatial:
	extends RefCounted
	func can_reach_target(_id: String) -> bool: return true
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	_oracle(); _feed_and_clock(); _calls_and_events(); _props_lifecycle(); _queue_order(); _real_phone()
	_check(completed == 69,"all69 source fixtures completed without script abort")
	_check(groups == 6,"all6 communications groups completed without script abort")
	if failures.is_empty():
		print("3D COMMUNICATIONS GATE: PASS (%d checks;69 source fixtures;12 calls/29 events,real feed/ticker/prop reset;Runtime/UI scheduling pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D COMMUNICATIONS GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
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
	var props := Props.new(game)
	var clock := Clock.new()
	var comms := Comms.new(game,props,clock.unix_ms)
	game.s.mode = "playing"; game.events.clear()
	comms.advance_wall(0.0)
	return {"game":game,"props":props,"clock":clock,"comms":comms,"monotonic":0.0}
func _events(game: RefCounted,kind: String) -> int:
	var count: int = 0
	for event: Dictionary in game.events:
		if event.kind == kind: count += 1
	return count
func _props_view(props: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var records: Array = props.records()
	for index: int in range(records.size()):
		var body: Dictionary = records[index]
		if body.get("type") == "dumpster":
			result.append({"id":"prop:%d" % index,"looted":body.get("looted",false) == true,"tipsJar":body.get("tipsJar",false) == true,"diveCdT":body.get("diveCdT",0)})
	return result
func _oracle() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/communications_reference.json"))
	_check(fixture.cases.size() == 69,"69 source fixtures present")
	for test: Dictionary in fixture.cases:
		var rig := _rig()
		var game: RefCounted = rig.game
		game.p.merge(test.setup.player.duplicate(true),true); game.s.merge(test.setup.state.duplicate(true),true)
		game.s.flags.merge(test.setup.flags.duplicate(true),true); game.p.faction.spiritual = test.setup.spiritual
		for roll: float in test.rolls: game.rolls.append(roll)
		for initial: Dictionary in test.setup.props:
			rig.props.set_dumpster_looted(initial.id,initial.looted)
			var body: Dictionary = rig.props.record(initial.id)
			body.tipsJar = initial.tipsJar; body.diveCdT = initial.diveCdT
		for step: Dictionary in test.steps:
			var operation: Dictionary = step.operation
			match operation.kind:
				"call": rig.comms.ring_phone(int(operation.index))
				"intro": rig.comms.fire_mom_intro_once()
				"proud": rig.comms.maybe_mom_proud()
				"event": rig.comms.fire_random_event()
				"post": rig.comms.post(operation.text,operation.author)
				"broadcast": rig.comms.broadcast(operation.text)
				"show": rig.comms.show_feed()
				"toggle": rig.comms.toggle_feed()
				"rotate": rig.monotonic += operation.count*50000.0; rig.comms.advance_wall(rig.monotonic)
				"garbage": rig.comms.dispatch_day_callback("garbage_truck")
			_fields(game.p,step.expected.player,test.id+".player")
			_fields(game.s.flags,step.expected.flags,test.id+".flags")
			var view: Dictionary = rig.comms.snapshot()
			_check(_same({"posts":view.posts,"visible":view.visible},step.expected.phone),test.id+" exact phone")
			_check(view.news_text == step.expected.news_text and view.news_index == step.expected.news_index,test.id+" exact source ticker")
			_check(_same(_props_view(rig.props),step.expected.props),test.id+" exact live dumpster state")
			_check(game.cursor == step.draws,test.id+" exact gameplay RNG draws")
		completed += 1
	_check(fixture.lifecycle.fresh.looted and fixture.lifecycle.fresh.tipsJar and fixture.lifecycle.fresh.postRetained,"actual source fresh retains PROPS/feed characterization")
	_check(fixture.lifecycle.load.ok and fixture.lifecycle.load.priorLooted and fixture.lifecycle.load.addedLooted and fixture.lifecycle.load.tipsJar,"actual source load overlays true without clearing session state")
	groups += 1
func _feed_and_clock() -> void:
	var rig := _rig()
	_check(rig.comms.ready() and rig.comms.day_capabilities_ready(),"real owners satisfy day capabilities")
	for index: int in range(11): rig.comms.post("post%d" % index,"@qa")
	var view: Dictionary = rig.comms.snapshot()
	_check(view.posts.size() == 8 and view.posts[0].t == "post10" and view.posts[7].t == "post3","feed retains exact8 newest")
	view.posts[0].t = "tampered"
	_check(rig.comms.snapshot().posts[0].t == "post10","feed snapshot cannot mutate authority")
	rig.comms.show_feed(); rig.game.s.mode = "dialogue"
	_check(rig.comms.snapshot().visible and not rig.comms.snapshot().displayed,"dialogue hides but does not clear phone visibility")
	rig.game.s.mode = "playing"
	_check(rig.comms.snapshot().displayed,"same source visibility resumes during play")
	rig.game.s.flags.silenceUntilT = rig.clock.now+1
	var draws: int = rig.game.cursor
	var before: Dictionary = rig.comms.snapshot()
	_check(rig.comms.post("quiet") and rig.comms.broadcast("quiet"),"silenced valid requests are accepted")
	_check(rig.game.cursor == draws and rig.comms.snapshot().posts == before.posts and rig.comms.snapshot().news_text == before.news_text,"silence suppresses before fallback RNG")
	rig.comms.advance_wall(50000)
	_check(rig.comms.snapshot().news_index == before.news_index+1,"wall rotation intentionally ignores silence")
	rig.clock.now += 1
	_check(not rig.comms.silence_active() and rig.comms.post("equal","@qa"),"Unix equality expires suppression")
	before = rig.comms.snapshot(); rig.clock.now = NAN
	_check(not rig.comms.ready() and not rig.comms.post("invalid") and not rig.comms.fire_random_event() and rig.game.cursor == draws,"invalid clock refuses effects and RNG")
	_check(rig.comms.snapshot() == before,"invalid clock leaves presentation unchanged")
	rig.clock.now = 1000001
	_check(not rig.comms.advance_wall(49999) and not rig.comms.advance_wall(INF),"wall clock rejects regression/nonfinite")
	var large := _rig()
	var pool: Array = large.game.definition("src/systems/communications.js","NEWS_POOL",[])
	_check(large.comms.advance_wall(50000.0*(pool.size()*1000000+3)) and large.comms.snapshot().news_index == 4,"large ticker catch-up advances arithmetically")
	groups += 1
func _calls_and_events() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.s.flags.silenceUntilT = rig.clock.now+1000; game.p.cash = 0
	_check(rig.comms.ring_phone(2) and game.p.cash == 3 and rig.comms.snapshot().posts.is_empty(),"direct call retains resource effect under feed silence")
	game.p.faction.spiritual = 10; game.p.brain = 50
	_check(rig.comms.dispatch_day_callback("mom_proud") and game.p.brain == 50 and game.s.flags.get("momProudCallDay",0) == 0,"source-suppressed proud callback is consumed without deferred reward")
	game.s.flags.silenceUntilT = 0
	_check(rig.comms.dispatch_day_callback("mom_proud") and game.p.brain == 55 and game.s.flags.momProudCallDay == game.s.day,"real proud callback applies once")
	_check(rig.comms.dispatch_day_callback("mom_proud") and game.p.brain == 55,"same-day proud callback cannot grant twice")
	game.s.mode = "dialogue"; game.s.day += 1
	_check(rig.comms.dispatch_day_callback("mom_proud") and game.p.brain == 55,"paused proud callback is a real accepted source no-op")
	var count: int = game.cursor; var player: Dictionary = game.p.duplicate(true)
	_check(not rig.comms.ring_phone(-2) and not rig.comms.ring_phone(12) and not rig.comms.fire_random_event(29) and not rig.comms.fire_random_event(-2),"unknown call/event indices fail")
	_check(game.cursor == count and game.p == player,"invalid dispatch cannot mutate resources or RNG")
	var absent := _rig()
	absent.props = null; absent.game.events.clear()
	_check(not absent.comms.day_capabilities_ready() and not absent.comms.dispatch_day_callback("garbage_truck") and absent.game.events.is_empty(),"missing props refuses garbage before receipts")
	var event := _rig()
	event.game.rolls.assign([0.75])
	event.comms.fire_random_event(8)
	_check(event.comms.inventory.count_records("cone") == 1 and event.game.p.brain == 67,"real authored event grants actual inventory and brain cost")
	_check(_events(event.game,"save_requested") == 0,"ordinary source event has no invented immediate save")
	var helicopter := _rig()
	helicopter.game.rolls.assign([0.9,0.1])
	_check(helicopter.comms.fire_random_event(17) and helicopter.game.cursor == 2,"traffic pitch draw precedes helicopter news even without audio playback")
	_check(helicopter.comms.snapshot().news_text.begins_with("· BREAKING · a helicopter"),"helicopter news uses the post-traffic gameplay roll")
	var garbage := _rig()
	garbage.game.rolls.assign([0.8,0.9,0.0])
	_check(garbage.comms.dispatch_day_callback("garbage_truck") and garbage.game.cursor == 3,"two source traffic draws precede garbage selection")
	_check(_props_view(garbage.props)[0].tipsJar,"garbage tips selection uses third roll instead of audio pitch rolls")
	groups += 1
func _props_lifecycle() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	var pristine: Array = game.content.props.duplicate(true)
	var dumps := _props_view(rig.props)
	var first: String = dumps[0].id; var second: String = dumps[1].id
	_check(rig.props.set_dumpster_looted(first,true),"actual dumpster can be marked looted")
	rig.props.record(first).tipsJar = true; rig.props.record(first).diveCdT = 1234
	var saved: Dictionary = game.snapshot()
	_check(saved.state.lootedDumpsters.size() == 1 and not saved.state.has("propRuntime"),"actual looted projection saved without ephemeral props")
	rig.comms.post("retained","@qa"); rig.comms.show_feed(); game.fresh()
	_check(not rig.props.ready() and not rig.comms.day_capabilities_ready(),"new state requires explicit prop rebind before day integration")
	_check(rig.props.reset_session("fresh") and rig.props.record(first).looted and rig.props.record(first).tipsJar,"fresh preserves source session PROPS")
	_check(rig.comms.snapshot().posts[0].t == "retained" and rig.comms.snapshot().visible,"fresh preserves source phone globals")
	rig.props.set_dumpster_looted(first,false); rig.props.set_dumpster_looted(second,true)
	var second_only: Dictionary = game.snapshot()
	rig.props.set_dumpster_looted(second,false); rig.props.set_dumpster_looted(first,true)
	game.restore(second_only); rig.props.reset_session("restore")
	_check(rig.props.record(first).looted and rig.props.record(second).looted and game.s.lootedDumpsters.size() == 2,"restore overlays saved true but retains old true source state")
	_check(rig.props.record(first).tipsJar and rig.props.record(first).diveCdT == 1234,"same-session unsaved tips/cooldown remain")
	var cold := FixedState.new()
	cold.restore(second_only)
	var cold_props := Props.new(cold)
	_check(not cold_props.record(first).get("looted",false) and cold_props.record(second).looted and not cold_props.record(first).get("tipsJar",false),"cold reload only restores saved looted rows")
	game.rolls.assign([0.5]); game.cursor = 0
	_check(rig.comms.dispatch_day_callback("garbage_truck") and game.s.lootedDumpsters.is_empty(),"real garbage resets durable and live looted state")
	_check(rig.props.record(first).tipsJar and rig.props.record(first).diveCdT == 1234,"garbage retains older jar and dive cooldown")
	for row: Dictionary in _props_view(rig.props): _check(not row.looted,"garbage clears each source dumpster")
	var copy: Array = rig.props.records(); copy[0].x = -99
	_check(game.content.props == pristine and rig.props.records()[0].x != -99,"live props and snapshots never mutate canonical content")
	for id: String in ["invented","prop:-1","prop:00","prop:1.5","prop:9999999"]:
		_check(rig.props.record(id).is_empty() and not rig.props.set_dumpster_looted(id,true),"malformed prop identity rejected")
	_check(not rig.props.reset_session("invented"),"unknown lifecycle reason refused")
	var isolated := FixedState.new()
	var props := Props.new(isolated)
	var owner_ref: WeakRef = weakref(isolated)
	isolated = null
	_check(owner_ref.get_ref() == null and not props.ready(),"live prop owner keeps GameState weak")
	groups += 1
func _queue_order() -> void:
	var rig := _rig()
	var game: RefCounted = rig.game
	game.emit_event("feed",{"text":"before silence","author":"@qa"})
	game.emit_event("quest_completed",{"id":"unrelated"})
	game.emit_event("news",{"text":"before news"})
	game.emit_event("communications_changed",{"original":true})
	_check(rig.comms.flush_pending_events(),"narrow source-order queue flush accepts")
	_check(game.events[0].kind == "quest_completed" and game.events[1].payload.get("original",false),"flush preserves other event order and original presentation events")
	for event: Dictionary in game.events: _check(event.kind not in ["feed","news"],"producer events consumed once without recursion")
	game.s.flags.silenceUntilT = rig.clock.now+240000
	rig.comms.post("after silence","@qa")
	_check(rig.comms.snapshot().posts.size() == 1 and rig.comms.snapshot().posts[0].t == "before silence" and rig.comms.snapshot().news_text.begins_with("· BREAKING · before news"),"day7 cannot retroactively suppress pre-silence queue")
	var count: int = game.events.size()
	_check(rig.comms.flush_pending_events() and game.events.size() == count,"second flush has no replay effects")
	game.emit_event("feed",{"text":7})
	var original: Array = game.events.duplicate(true)
	_check(not rig.comms.flush_pending_events() and game.events == original,"malformed queue refuses without partial event loss")
	_check(not rig.comms.consume_event({"kind":"communications_changed"}) and not rig.comms.consume_event({"kind":"death","payload":{}}),"consumer never runs unrelated rewards")
	groups += 1
func _real_phone() -> void:
	var rig := _rig()
	var spatial := Spatial.new()
	var memory := Memory.new(rig.game)
	var street := Street.new(rig.game,spatial,memory,null,null,rig.comms)
	for body: Dictionary in rig.game.npcs:
		if body.id == "phoneguy":
			rig.game.p.x = body.x+(body.w-rig.game.p.w)*0.5; rig.game.p.y = body.y+(body.h-rig.game.p.h)*0.5
	rig.game.p.cash = 3
	var menu: Dictionary = street.open("phoneguy")
	_check(menu.ok and rig.comms.snapshot().visible and not rig.comms.snapshot().displayed,"real Phone Guy reveals persistent feed under dialogue")
	street.select(menu.token,"content")
	_check(rig.game.p.cash == 0 and rig.comms.snapshot().posts.size() == 1 and rig.comms.snapshot().displayed,"real paid phone post writes single feed owner and charges3")
	_check(not street.select(menu.token,"content").ok and rig.comms.snapshot().posts.size() == 1,"phone payment/post cannot replay")
	rig.game.p.cash = 3; rig.game.s.flags.silenceUntilT = rig.clock.now+1
	menu = street.open("phoneguy"); street.select(menu.token,"content")
	_check(rig.game.p.cash == 0 and rig.comms.snapshot().posts.size() == 1,"source paid post still costs3 when feed silence suppresses output")
	var isolated := FixedState.new()
	var clock := Clock.new()
	var communications := Comms.new(isolated,null,clock.unix_ms)
	var owner_ref: WeakRef = weakref(isolated)
	isolated = null
	_check(owner_ref.get_ref() == null and not communications.ready(),"Communications keeps player owner weak")
	groups += 1
