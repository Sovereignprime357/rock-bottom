extends SceneTree
const Actions = preload("res://scripts/interactive_prop_actions.gd")
const Props = preload("res://scripts/prop_state.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Comms = preload("res://scripts/communications_system.gd")
var checks: int = 0
var groups: int = 0
var completed: int = 0
var failures: Array[String] = []

class FixedState extends "res://scripts/game_state.gd":
	var rolls: Array[float] = []
	var cursor: int = 0
	var fallback: float = 0.75
	func random_float() -> float:
		var value: float = rolls[cursor] if cursor < rolls.size() else fallback
		cursor += 1; return value

class Spatial extends RefCounted:
	var reachable: bool = true
	var blocked: Array = []
	var blocked_hits: Array = []
	var calls: Dictionary = {}
	var invalid: String = ""
	var on_stage: Callable
	var on_hit: Callable
	var on_reach: Callable
	func can_reach_target(_id: String) -> bool:
		if on_reach.is_valid():
			var callback := on_reach; on_reach = Callable(); callback.call()
		return reachable
	func stage_interactive_prop(id: String,_kind: String,desired: Vector2,_maximum: float) -> Variant:
		calls[id] = int(calls.get(id,0))+1
		if on_stage.is_valid():
			var callback := on_stage; on_stage = Callable(); callback.call()
		if id in blocked: return null
		if invalid == "far": return desired+Vector2(100.1,0)
		if invalid == "nan": return Vector2(NAN,0)
		if invalid == "outside": return Vector2(-1,-1)
		return desired
	func can_hit(_from: Vector2,_to: Vector2,_source: String,target: String) -> bool:
		if on_hit.is_valid():
			var callback := on_hit; on_hit = Callable(); callback.call()
		return target not in blocked_hits
	func move_body(_body: Dictionary,intended: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary:
		return {"position":intended,"blocked":false}
	func clear_placement(body: Dictionary) -> Vector2: return Vector2(body.x,body.y)

class SpyActions extends "res://scripts/interactive_prop_actions.gd":
	var mode: String = ""
	var captured: Variant
	var first: Dictionary = {}
	var second: Dictionary = {}
	func resolve_swing(token: Variant) -> Dictionary:
		captured = token
		if mode == "same_mode_change": host.s.mode = "dialogue"
		if mode == "replace": host.p = host.p.duplicate(true)
		if mode == "wrong_consumer": _combat_ref.get_ref().consume_prop_swing(token,[],RefCounted.new())
		first = super.resolve_swing(token)
		second = super.resolve_swing(token)
		return first

func _initialize() -> void: call_deferred("_run")
func _check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
func _run() -> void:
	_source_cases()
	_capabilities()
	_placement()
	_continuity()
	_check(groups == 4,"all four interactive prop groups complete without script abort")
	if failures.is_empty():
		print("3D INTERACTIVE PROPS GATE: PASS (%d checks; %d unchanged-source paths; shared14 records/real Combat/physical pending/epoch reset; world binding pending)" % [checks,completed]); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D INTERACTIVE PROPS GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
func _rig(blocked: Array = [],spy: bool = false) -> Dictionary:
	var game := FixedState.new()
	var spatial := Spatial.new(); spatial.blocked = blocked.duplicate()
	var props := Props.new(game)
	var combat := Combat.new(game,spatial)
	combat.tick_wall(1763424000000.0) # Same fixed Date.now epoch as the unchanged-source harness.
	var comms := Comms.new(game,props,func(): return 1000.0)
	var actions: RefCounted = SpyActions.new(game,spatial,props,combat) if spy else Actions.new(game,spatial,props,combat)
	game.s.mode = "playing"; game.npcs.clear(); game.events.clear(); game.cursor = 0
	return {"game":game,"spatial":spatial,"props":props,"combat":combat,"comms":comms,"actions":actions,"saves":0,"toast":"","orderedToasts":[],"events":[]}
func _row(rig: Dictionary,index: int) -> Dictionary: return rig.props.interactive_record("interactive:%d" % index)
func _flush(rig: Dictionary) -> void:
	while not rig.game.events.is_empty():
		for event: Dictionary in rig.game.drain_events():
			rig.events.append(event)
			if event.kind == "save_requested": rig.saves += 1
			elif event.kind == "toast":
				rig.toast = event.payload.text; rig.orderedToasts.append(rig.toast)
			elif event.kind == "achievement":
				rig.toast = "· ACHIEVEMENT ·\n"+str(event.payload.definition.name); rig.orderedToasts.append(rig.toast)
			elif event.kind in ["feed","news"]: rig.comms.consume_event(event)
func _same(actual: Variant,expected: Variant) -> bool:
	if (actual is int or actual is float) and (expected is int or expected is float): return absf(float(actual)-float(expected)) < 0.00001
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key: Variant in expected:
			if not actual.has(key) or not _same(actual[key],expected[key]): return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for index: int in range(expected.size()):
			if not _same(actual[index],expected[index]): return false
		return true
	if typeof(actual) != typeof(expected): return false
	return actual == expected
func _fields(actual: Dictionary,expected: Dictionary,label: String) -> void:
	for key: String in expected:
		if key in ["x","y"] and actual.has(key):
			_check(absf(float(actual[key])-float(expected[key])) <= 0.0003,label+"."+key+" float32 physical coordinate"); continue
		_check(actual.has(key) and _same(actual.get(key),expected[key]),"%s.%s actual=%s expected=%s" % [label,key,str(actual.get(key)),str(expected[key])])
func _setup(rig: Dictionary,setup: Dictionary) -> void:
	rig.game.p.merge(setup.player.duplicate(true),true); rig.game.s.merge(setup.state.duplicate(true),true)
	rig.game.s.achievements.assign(setup.achievements); rig.game.npcs.assign(setup.actors.duplicate(true))
	for row: Dictionary in setup.interactiveProps:
		var live: Dictionary = _row(rig,int(row.index)); live.clear()
		for key: String in row:
			if key not in ["id","index"]: live[key] = row[key]
	rig.game.events.clear(); rig.events.clear(); rig.saves = setup.saves; rig.toast = setup.toast
func _change(rig: Dictionary,values: Dictionary) -> void:
	if values.has("player"): rig.game.p.merge(values.player.duplicate(true),true)
	if values.has("state"): rig.game.s.merge(values.state.duplicate(true),true)
	if values.has("actors"): rig.game.npcs.assign(values.actors.duplicate(true))
	if values.has("achievements"): rig.game.s.achievements.assign(values.achievements)
	for key: String in values.get("interactiveProps",{}): _row(rig,int(key)).merge(values.interactiveProps[key].duplicate(true),true)
func _direction(facing: String) -> Vector2:
	return {"right":Vector2.RIGHT,"left":Vector2.LEFT,"up":Vector2.UP,"down":Vector2.DOWN}.get(facing,Vector2.ZERO)
func _expected(rig: Dictionary,expected: Dictionary,label: String,compare_saves: bool) -> void:
	for key: String in ["player","state"]:
		if expected.has(key): _fields(rig.game.p if key == "player" else rig.game.s,expected[key],label+" "+key)
	if expected.has("interactiveProps"):
		_check(rig.props.interactive_records().size() == expected.interactiveProps.size(),label+" shared14 slots")
		for row: Dictionary in expected.interactiveProps:
			var projected: Dictionary = row.duplicate(true); projected.erase("id"); projected.erase("index")
			_fields(_row(rig,int(row.index)),projected,label+" "+row.id)
	if expected.has("actors"):
		_check(rig.game.npcs.size() == expected.actors.size(),label+" actor count")
		for actor: Dictionary in expected.actors: _fields(rig.combat.actor(actor.id),actor,label+" actor "+actor.id)
	if expected.has("achievements"):
		var achievements: Array = rig.game.s.achievements.duplicate(); achievements.sort()
		_check(_same(achievements,expected.achievements),label+" achievements")
	if expected.has("posts"): _check(_same(rig.comms.snapshot().posts,expected.posts),label+" exact feed")
	if expected.has("toast"): _check(rig.toast == expected.toast,label+" last receipt")
	if expected.has("orderedToasts"): _check(_same(rig.orderedToasts,expected.orderedToasts),label+" NPC/bottle/combo/achievement receipt order")
	if compare_saves and expected.has("saves"): _check(rig.saves == int(expected.saves),label+" exact saves")
func _source_cases() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/interactive_props_reference.json"))
	_check(fixture is Dictionary and fixture.get("schema") == 1 and fixture.get("cases",[]).size() == 126,"unchanged-source interactive fixture is available")
	if not fixture is Dictionary: return
	var steps: int = 0
	var handoffs: int = 0
	for test: Dictionary in fixture.cases:
		var rig := _rig(); _setup(rig,test.setup)
		rig.game.rolls.assign(test.rolls); rig.game.fallback = test.roll; rig.game.cursor = 0
		for step: Dictionary in test.steps:
			rig.toast = ""; rig.orderedToasts.clear()
			var op: Dictionary = step.operation
			var result: Dictionary = {"ok":true}
			match str(op.kind):
				"init_props":
					# The production reset is explicitly once per new p/s epoch.
					rig.game.p = rig.game.p.duplicate(true); rig.game.s = rig.game.s.duplicate(true)
					rig.props.reset_session("fresh"); result.ok = rig.actions.reset_session("fresh")
				"open_trash":
					var row: Dictionary = _row(rig,int(op.index))
					rig.game.p.x = float(row.x)-float(rig.game.p.w)*0.5+float(op.get("offset",0)); rig.game.p.y = float(row.y)-float(rig.game.p.h)*0.5
					result = rig.actions.kick("interactive:%d" % int(op.index))
				"attack": result = rig.combat.attack_player(_direction(str(rig.game.p.facing)))
				"change": _change(rig,op.values)
				"tick":
					var remaining: float = op.ms
					while remaining > 0:
						var dt := minf(50.0,remaining)
						# Runtime owns the source updateWorld/hit-pause scheduling boundary.
						if rig.game.s.mode == "playing" and float(rig.game.s.get("hitPause",0)) <= 0: rig.actions.tick(dt)
						remaining -= dt
				"audio_due": pass # Audio presentation draws are explicitly outside gameplay RNG.
				"save": rig.saved = rig.game.snapshot(); rig.saves += 1
				"fresh": result.ok = rig.game.fresh(); rig.props.reset_session("fresh"); rig.actions.reset_session("fresh")
				"restore": result = rig.game.restore(rig.saved); rig.props.reset_session("restore"); rig.actions.reset_session("restore")
				_: _check(false,"unknown oracle operation "+str(op.kind))
			_flush(rig)
			var label: String = "%s step%d %s" % [test.id,steps,op.kind]
			if step.result.has("ok"): _check(result.get("ok") is bool and result.ok == step.result.ok,label+" accepted/refused")
			var owned_expected: Dictionary = step.expected
			if step.has("handoff"):
				# Source tryInteract falls through to the separately owned Block menu
				# exactly outside this can's range. Do not make this owner open that menu.
				_check(_same(step.handoff,{"owner":"block","reason":"trash_out_of_reach"}),label+" explicit external dispatch handoff")
				_check(not result.ok and result.get("reason") == "out_of_reach" and rig.game.s.mode == "playing" and step.expected.state.mode == "dialogue",label+" bounded owner refuses while source dispatcher opens Block")
				owned_expected = step.expected.duplicate(true); owned_expected.state.erase("mode")
				handoffs += 1
			_expected(rig,owned_expected,label,bool(step.compareSaves))
			if step.compareDraws: _check(rig.game.cursor == int(step.mechanicDraws),label+" exact gameplay draw order/count")
			steps += 1
		completed += 1
	_check(completed == 126 and steps == 132,"all126 source paths and132 steps complete without abort")
	_check(handoffs == 2,"only the exact two excluded50px witnesses hand off to Block")
	groups += 1

func _swing_setup(rig: Dictionary) -> void:
	rig.game.p.merge({"x":1000.0,"y":1000.0,"w":24.0,"h":28.0,"facing":"right","attackCd":0.0,"stunT":0.0,"weapon":"fists"},true)
	for index: int in range(6,14): _row(rig,index).merge({"x":1500.0+index*10,"y":1500.0,"broken":false},true)
	_row(rig,6).merge({"x":1042.0,"y":1014.0},true)
	rig.game.rolls.assign([0.1,0.0,0.2,0.0]); rig.game.cursor = 0
func _capabilities() -> void:
	var rig := _rig([],true); _swing_setup(rig)
	_check(rig.actions.ready(),"shared owners and physical adapter ready")
	for bad: String in ["","interactive:-1","interactive:00","interactive:14","prop:0"]:
		_check(not rig.actions.supports(bad),"strict interactive identity rejects "+bad)
	_check(not rig.actions.resolve_swing("forged").ok and rig.game.cursor == 0,"forged capability has no gameplay effect")
	var result: Dictionary = rig.combat.attack_player(Vector2.RIGHT)
	_check(result.ok and not result.connected and result.hits.is_empty(),"bottle-only swing stays disconnected")
	_check(_row(rig,6).broken and rig.game.cursor == 2 and rig.game.p.weapon == "broken_bottle","real Combat authorizes exactly one bottle break/drop")
	_check(rig.actions.first.ok and not rig.actions.second.ok,"synchronous duplicate consumer cannot spend swing twice")
	_check(not rig.actions.resolve_swing(rig.actions.captured).ok and rig.game.cursor == 2,"returned capability is revoked")
	_flush(rig); _check(rig.saves == 0,"bottle shatter and equipped drop never save")
	for mode: String in ["wrong_consumer","replace","same_mode_change"]:
		var trial := _rig([],true); _swing_setup(trial); trial.actions.mode = mode
		trial.combat.attack_player(Vector2.RIGHT)
		_check(trial.game.cursor == (2 if mode == "same_mode_change" else 0),mode+" keeps accepted epoch/capability contract")
		if mode == "same_mode_change": _check(_row(trial,6).broken,"accepted swing survives same-epoch mode change")
	var blocked := _rig(); _swing_setup(blocked); blocked.spatial.blocked_hits.append("interactive:6")
	blocked.combat.attack_player(Vector2.RIGHT)
	_check(not _row(blocked,6).broken and blocked.game.cursor == 0,"fresh physical LOS blocks bottle break and RNG")
	var replaced := _rig(); _swing_setup(replaced)
	replaced.spatial.on_hit = func():
		replaced.game.p = replaced.game.p.duplicate(true); replaced.game.s = replaced.game.s.duplicate(true)
		replaced.game.s.combo = 17
		replaced.props.reset_session("cold"); replaced.actions.reset_session("cold")
	replaced.combat.attack_player(Vector2.RIGHT)
	_check(replaced.game.cursor == 0 and not _row(replaced,6).broken,"reentrant LOS epoch replacement cannot grant old swing to new shared records")
	_check(replaced.game.s.combo == 17,"stale swing finalization cannot reset replacement combo")
	var original := _rig(); _swing_setup(original); _row(original,7).merge({"x":1068.0,"y":1014.0},true)
	original.combat.attack_player(Vector2.RIGHT)
	_check(_row(original,6).broken and not _row(original,7).broken and original.game.cursor == 2,"mid-swing equipment never extends original reach")
	var oblique := _rig(); _swing_setup(oblique)
	_row(oblique,6).merge({"x":1040.0,"y":1042.0},true)
	oblique.combat.attack_player(Vector2(1,1))
	_check(_row(oblique,6).broken,"continuous first-person direction uses existing Combat SAT")
	var legacy := _rig(); _swing_setup(legacy); legacy.combat.set_prop_attack_owner(null)
	legacy.combat.attack_player(Vector2.RIGHT); _flush(legacy)
	_check(not _row(legacy,6).broken and legacy.game.cursor == 0,"unbound optional owner preserves existing Combat behavior")
	var legacy_requests: int = 0
	for event: Dictionary in legacy.events:
		if event.kind == "attack_props_requested": legacy_requests += 1
	_check(legacy_requests == 1,"legacy integration receives its single existing prop request")
	groups += 1

func _placement() -> void:
	var rig := _rig(["interactive:6"]); _swing_setup(rig)
	_check(rig.actions.render_records()[6].pending and not rig.actions.render_records()[6].placed,"failed initial physical placement remains hidden/unattackable")
	rig.combat.attack_player(Vector2.RIGHT)
	_check(not _row(rig,6).broken and rig.game.cursor == 0,"pending bottle never becomes invisible melee target")
	var attempts: int = rig.spatial.calls["interactive:6"]
	for index: int in range(4): rig.actions.tick(50.0)
	_check(rig.spatial.calls["interactive:6"] == attempts,"initial intent does not retry before250 active ms")
	rig.actions.tick(50.0)
	_check(rig.spatial.calls["interactive:6"] == attempts+1 and rig.game.cursor == 0,"blocked retry consumes no RNG")
	rig.spatial.blocked.clear()
	for index: int in range(5): rig.actions.tick(50.0)
	_check(rig.actions.render_records()[6].placed and not rig.actions.render_records()[6].pending,"valid retry publishes the original point exactly once")
	var respawn := _rig(); _swing_setup(respawn)
	respawn.spatial.blocked.append("interactive:6")
	_row(respawn,6).merge({"broken":true,"respawnT":199.0},true)
	respawn.game.rolls.assign([0.999999,0.0,0.999999]); respawn.game.cursor = 0
	for index: int in range(4): respawn.actions.tick(50.0)
	attempts = respawn.spatial.calls["interactive:6"]
	_check(respawn.game.cursor == 3 and _row(respawn,6).broken and _row(respawn,6).respawnT == -1.0,"expired bottle reserves three-draw intent and source negative remainder")
	for index: int in range(4): respawn.actions.tick(50.0)
	_check(respawn.spatial.calls["interactive:6"] == attempts,"new respawn gets its own full250ms retry interval")
	respawn.actions.tick(50.0)
	_check(respawn.spatial.calls["interactive:6"] == attempts+1 and respawn.game.cursor == 3,"failed respawn retry never rerolls point")
	respawn.spatial.blocked.clear()
	for index: int in range(5): respawn.actions.tick(50.0)
	_check(not _row(respawn,6).broken and respawn.actions.render_records()[6].placed and _row(respawn,6).respawnT == -1.0,"placed respawn retains exact clock remainder and becomes attackable")
	_check(absf(_row(respawn,6).x-1360.0) < 0.0003 and absf(_row(respawn,6).y-1719.99996) < 0.0003,"retry commits first12-pool point and original jitter")
	_flush(respawn); _check(respawn.saves == 0,"respawn placement never saves")
	for invalid: String in ["far","nan","outside"]:
		var trial := _rig(["interactive:6"]); trial.spatial.blocked.clear(); trial.spatial.invalid = invalid
		for index: int in range(5): trial.actions.tick(50.0)
		_check(trial.actions.render_records()[6].pending and trial.game.cursor == 0,"invalid physical point retains intent: "+invalid)
	for mode: String in ["paused","dialogue","cookmini"]:
		var frozen := _rig(["interactive:6"]); frozen.game.s.mode = mode
		_row(frozen,0).cdT = 100; attempts = frozen.spatial.calls["interactive:6"]
		for index: int in range(10): _check(not frozen.actions.tick(50),mode+" refuses inactive world clock")
		_check(_row(frozen,0).cdT == 100 and frozen.spatial.calls["interactive:6"] == attempts,mode+" freezes source timers and pending retries")
	for dt: float in [0.0,-1.0,50.001,INF,NAN]: _check(not rig.actions.tick(dt),"invalid world delta rejected")
	var detached: Array = rig.actions.render_records(); detached[0].cdT = 99999
	_check(_row(rig,0).cdT != 99999,"renderer receives detached shared records")
	groups += 1

func _continuity() -> void:
	var rig := _rig(["interactive:6"])
	var static_id: String = ""
	for index: int in range(rig.props.records().size()):
		if rig.props.records()[index].type == "dumpster": static_id = "prop:%d" % index; break
	rig.props.set_dumpster_looted(static_id,true); rig.props.record(static_id).diveCdT = 54321.0
	_row(rig,0).cdT = 123.0; _row(rig,6).broken = true
	_check(rig.actions.reset_session("cold") and rig.game.cursor == 0,"same epoch cold binding does not reroll/reset pending")
	var old: Dictionary = _row(rig,6)
	rig.game.fresh()
	_check(not rig.actions.ready() and rig.actions.render_records().is_empty() and not rig.actions.tick(50),"unexpected state replacement revokes presentation and pending work")
	rig.props.reset_session("fresh"); rig.actions.reset_session("fresh")
	_check(rig.game.cursor == 24 and _row(rig,0).cdT == 0 and not _row(rig,6).broken,"fresh boundary creates exactly eight ordered three-draw bottles")
	_check(rig.props.record(static_id).looted and rig.props.record(static_id).diveCdT == 54321.0,"interactive reset preserves source static PROPS continuity")
	_check(rig.actions.reset_session("fresh") and rig.game.cursor == 24,"repeated fresh binding cannot consume another24 draws")
	_check(old.broken and not is_same(old,_row(rig,6)),"fresh drops old live interactive array")
	var saved: Dictionary = rig.game.snapshot()
	_row(rig,0).cdT = 800; _row(rig,6).broken = true
	var restored: Dictionary = rig.game.restore(saved)
	_check(restored.ok,"real persisted state restores")
	rig.props.reset_session("restore"); rig.actions.reset_session("restore")
	_check(rig.game.cursor == 48 and _row(rig,0).cdT == 0 and not _row(rig,6).broken,"restore rebuilds unsaved interactive props instead of resurrecting old cooldowns")
	var reentrant := _rig(["interactive:6"]); reentrant.spatial.blocked.clear()
	reentrant.spatial.on_stage = func():
		reentrant.game.p = reentrant.game.p.duplicate(true); reentrant.game.s = reentrant.game.s.duplicate(true)
		reentrant.props.reset_session("cold"); reentrant.actions.reset_session("cold")
	for index: int in range(5): reentrant.actions.tick(50)
	_check(reentrant.actions.ready() and reentrant.actions.render_records()[6].placed,"old physical callback cannot erase a newer epoch placement")
	for path: String in ["reset","expiry"]:
		var interrupted := _rig()
		interrupted.spatial.on_stage = func(): interrupted.game.s = interrupted.game.s.duplicate(true)
		if path == "reset":
			interrupted.game.s = interrupted.game.s.duplicate(true); interrupted.props.reset_session("cold")
			_check(not interrupted.actions.reset_session("cold"),"initial placement stops after epoch replacement at first row")
		else:
			_row(interrupted,6).merge({"broken":true,"respawnT":1.0},true)
			_check(not interrupted.actions.tick(50),"respawn placement stops after epoch replacement before later rows")
		_check(not interrupted.actions.ready() and interrupted.actions.render_records().is_empty(),path+" exposes no stale interactive records")
	var kick := _rig(); var can: Dictionary = _row(kick,0)
	kick.game.p.x = float(can.x)-float(kick.game.p.w)*0.5; kick.game.p.y = float(can.y)-float(kick.game.p.h)*0.5
	kick.spatial.on_reach = func():
		kick.game.p = kick.game.p.duplicate(true); kick.game.s = kick.game.s.duplicate(true)
		kick.props.reset_session("cold"); kick.actions.reset_session("cold")
	_check(not kick.actions.kick("interactive:0").ok and kick.game.cursor == 0 and _row(kick,0).cdT == 0,"reentrant interaction query cannot credit a replaced player")
	groups += 1
