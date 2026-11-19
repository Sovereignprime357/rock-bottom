extends SceneTree
const OldSchool = preload("res://scripts/old_school.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Bosses = preload("res://scripts/boss_system.gd")
var fixture: Dictionary = {}
var checks: int = 0
var completed: int = 0
var groups: int = 0
var failures: Array[String] = []
class SequenceState:
	extends "res://scripts/game_state.gd"
	var rolls: Array[float] = []
	var draws: int = 0
	var trace: Array = []
	func record(kind: String,payload: Dictionary = {}) -> void:
		trace.append({"kind":kind,"payload":payload.duplicate(true),"copper":p.copper,"counter":s.counters.get("copperStripped",0),"mode":s.mode})
	func random_float() -> float:
		var value: float = rolls[draws] if draws < rolls.size() else 0.75
		draws += 1; record("random",{"value":value}); return value
	func emit_event(kind: String,payload: Dictionary = {}) -> void:
		super.emit_event(kind,payload)
		match kind:
			"toast","sound","feed": record(kind,payload)
			"save_requested": record("save")
			"achievement":
				record("toast",{"text":"· ACHIEVEMENT ·\n"+str(payload.definition.name),"duration_ms":3000})
				record("sound",{"id":"rankUp"})
class Physics:
	extends RefCounted
	var owner_ref: WeakRef
	var reachable: bool = true
	var placeable: bool = true
	var entry_calls: int = 0
	var placement_calls: int = 0
	var replace_at: String = ""
	var replace_key: String = ""
	var replacement: Dictionary = {}
	var mode_at_placement: String = ""
	func _replace(at: String) -> void:
		if replace_at != at: return
		var owner: RefCounted = owner_ref.get_ref()
		if replace_key == "p": owner.p = owner.p.duplicate(true)
		else: owner.s = owner.s.duplicate(true)
		replacement = {"p":owner.p.duplicate(true),"s":owner.s.duplicate(true),"npcs":owner.npcs.duplicate(true)}
	func can_reach_target(_id: String) -> bool:
		entry_calls += 1; _replace("entry"); return reachable
	func clear_placement(body: Dictionary) -> Variant:
		placement_calls += 1; _replace("placement")
		if not mode_at_placement.is_empty(): owner_ref.get_ref().s.mode = mode_at_placement
		return Vector2(body.x,body.y) if placeable else null
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.0000001
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
func _body(dead: bool = false) -> Dictionary:
	var body: Dictionary = fixture.body.duplicate(true)
	if dead: body.dead = true; body.hp = 0
	return body
func _actors(state: RefCounted,kind: String) -> void:
	state.npcs.clear()
	if kind in ["live","dead"]: state.npcs.append(_body(kind == "dead"))
func _bundle(spec: Dictionary = {}) -> Dictionary:
	var state := SequenceState.new()
	state.p.x = 3760.0+float(spec.get("distance",0.0)); state.p.y = 700.0; state.p.rank = 3; state.p.copper = 0; state.p.hp = 100; state.p.stunT = 0
	for key: String in spec.get("player",{}): state.p[key] = spec.player[key]
	state.s.mode = "playing"; state.s.day = 1; state.s.bossKind = spec.get("bossKind",""); state.s.bossActive = not str(state.s.bossKind).is_empty()
	state.s.flags.osBrutusKilled = spec.get("killed",false); state.s.flags.silenceUntilT = 0
	state.s.counters.copperStripped = spec.get("counter",0); state.s.achievements = []
	if spec.get("achievement",false): state.s.achievements.append("copper_singer")
	_actors(state,spec.get("actor","absent")); state.cash_piles.clear()
	var physics := Physics.new(); physics.owner_ref = weakref(state)
	var combat := Combat.new(state,physics); var bosses := Bosses.new(state,combat)
	var school := OldSchool.new(state,physics,bosses)
	state.rolls.assign(spec.get("rolls",[0.75])); state.events.clear(); state.trace.clear(); state.draws = 0
	return {"state":state,"physics":physics,"combat":combat,"bosses":bosses,"school":school,"menu":{}}
func _menu(page: Dictionary) -> Variant:
	if not page.get("ok",false) or not page.has("options"): return null
	var options: Array = []
	for option: Dictionary in page.options: options.append({"label":option.label,"enabled":option.get("enabled",true)})
	return {"title":page.title,"text":page.text,"options":options}
func _outcome(bundle: Dictionary) -> Dictionary:
	var state: RefCounted = bundle.state
	return {"copper":state.p.copper,"counter":state.s.counters.get("copperStripped",0),"hp":state.p.hp,"stun":state.p.stunT,"rank":state.p.rank,"mode":state.s.mode,"killed":state.s.flags.get("osBrutusKilled",false),"achievements":state.s.achievements.duplicate(),"actors":state.npcs.duplicate(true),"trace":state.trace.duplicate(true),"draws":state.draws,"menu":_menu(bundle.menu)}
func _compare(bundle: Dictionary,expected: Dictionary,label: String) -> void:
	var actual: Dictionary = _outcome(bundle)
	for key: String in actual: _check(_same(actual[key],expected[key]),label+" "+key+" got "+str(actual[key])+" expected "+str(expected[key]))
func _source() -> void:
	_check(fixture.counts.entries == 22 and fixture.counts.cases == 48 and fixture.counts.steps == 57,"all source entry/path/step counts")
	for row: Dictionary in fixture.entries:
		var bundle: Dictionary = _bundle(row.setup); bundle.menu = bundle.school.open()
		_check(bundle.menu.get("ok",false) == row.entered,"strict44/rank/kingdom source entry "+str(row.setup))
		_compare(bundle,row.expected,"entry "+str(row.setup)); completed += 1
	for row: Dictionary in fixture.cases:
		var bundle: Dictionary = _bundle(row.setup); bundle.menu = bundle.school.open()
		_check(_same(_menu(bundle.menu),row.initial),row.setup.id+" source initial page")
		if row.setup.has("afterActor"): _actors(bundle.state,row.setup.afterActor)
		for key: String in row.setup.get("afterPlayer",{}): bundle.state.p[key] = row.setup.afterPlayer[key]
		if row.setup.has("afterBoss"): bundle.state.s.bossKind = row.setup.afterBoss
		if row.setup.has("afterKilled"): bundle.state.s.flags.osBrutusKilled = row.setup.afterKilled
		for step: Dictionary in row.steps:
			if step.action == "open": bundle.menu = bundle.school.open()
			elif step.action == "escape": bundle.school.close(); bundle.menu = {}
			else:
				_check(bundle.menu.has("token"),row.setup.id+" has source offered page before "+step.action)
				if not bundle.menu.has("token"): continue
				bundle.menu = bundle.school.select(bundle.menu.token,step.action)
				_check(bundle.menu.get("ok",false),row.setup.id+" source action accepts")
			_compare(bundle,step.expected,row.setup.id+" "+step.action); completed += 1
	groups += 1
func _capabilities() -> void:
	var bundle: Dictionary = _bundle({"actor":"live"}); var page: Dictionary = bundle.school.open(); var first: String = page.token
	var next: Dictionary = bundle.school.select(first,"rip")
	_check(next.has("token") and next.token != first,"reopened source page gets fresh capability")
	var before: Dictionary = _outcome(bundle)
	_check(bundle.school.select(first,"rip").reason == "stale_session" and _same(_outcome(bundle),before),"replayed copper cannot consume current page or reward")
	_check(bundle.school.select(next.token,"leave").ok and bundle.state.s.mode == "playing","fresh page still usable after old replay")
	bundle = _bundle(); page = bundle.school.open()
	_check(bundle.school.select(page.token,"invented").reason == "unknown_action" and bundle.state.p.copper == 0 and bundle.state.draws == 0,"unknown action consumes without grant/RNG")
	for key: String in ["p","s"]:
		bundle = _bundle(); page = bundle.school.open()
		if key == "p": bundle.state.p = bundle.state.p.duplicate(true)
		else: bundle.state.s = bundle.state.s.duplicate(true)
		bundle.state.s.mode = "quest"; before = {"p":bundle.state.p.duplicate(true),"s":bundle.state.s.duplicate(true)}
		_check(bundle.school.select(page.token,"rip").reason == "replaced_state","stale "+key+" identity refuses")
		_check(_same(before.p,bundle.state.p) and _same(before.s,bundle.state.s) and bundle.state.events.is_empty(),"stale selection cannot close or mutate replacement page")
		bundle.state.s.mode = "playing"; bundle.bosses.normalize_state()
		_check(bundle.school.open().ok,"explicit new open binds replacement epoch")
	groups += 1
func _physics_and_reentry() -> void:
	for killed: bool in [false,true]:
		var bundle: Dictionary = _bundle({"killed":killed,"rolls":[0.9]}); var page: Dictionary = bundle.school.open(); bundle.physics.placeable = false
		var refused: Dictionary = bundle.school.select(page.token,"rip")
		_check(refused.reason == "boss_unavailable" and bundle.state.p.copper == 0 and bundle.state.s.counters.copperStripped == 0 and bundle.state.draws == 0 and bundle.state.events.is_empty(),"potential physical spawn preflights before effects/RNG even when future roll would miss")
		_check(bundle.physics.placement_calls == 1 and bundle.bosses._old_school_pending.is_empty(),"blocked body leaves no pending plan")
	var corpse: Dictionary = _bundle({"actor":"dead","killed":true,"rolls":[0.2]}); corpse.physics.placeable = false
	var corpse_page: Dictionary = corpse.school.open(); var corpse_result: Dictionary = corpse.school.select(corpse_page.token,"rip")
	_check(corpse_result.ok and corpse.physics.placement_calls == 0 and corpse.state.p.copper == 2 and corpse.state.draws == 1,"source corpse no-op needs no physical placement")
	for event: Dictionary in corpse.state.events: _check(event.kind != "save_requested" and event.kind != "actor_spawned","corpse risk hit deliberately has neither spawn nor trailing save")
	for where: String in ["entry","placement"]:
		for key: String in ["p","s"]:
			var bundle: Dictionary = _bundle(); bundle.physics.replace_at = where; bundle.physics.replace_key = key
			var result: Dictionary = bundle.school.open()
			if where == "placement": result = bundle.school.select(result.token,"rip")
			_check(result.reason == "replaced_state",where+" external callback "+key+" identity replacement refuses")
			_check(_same(bundle.physics.replacement.p,bundle.state.p) and _same(bundle.physics.replacement.s,bundle.state.s) and _same(bundle.physics.replacement.npcs,bundle.state.npcs),"no replacement writes after "+where+" "+key)
			_check(bundle.state.draws == 0 and bundle.state.events.is_empty(),"replacement callback has no rewards/RNG/receipts")
	var modal: Dictionary = _bundle(); var modal_page: Dictionary = modal.school.open(); modal.physics.mode_at_placement = "quest"
	_check(modal.school.select(modal_page.token,"rip").reason == "wrong_mode" and modal.state.s.mode == "quest" and modal.state.events.is_empty(),"external modal switch is preserved without source effects")
	var missing: Dictionary = _bundle(); var no_boss := OldSchool.new(missing.state,missing.physics,null)
	_check(not no_boss.ready() and no_boss.open().reason == "missing_dependency","missing real Boss API refuses before opening")
	var no_reach: Dictionary = _bundle(); no_reach.physics.reachable = false
	_check(no_reach.school.open().reason == "out_of_reach" and no_reach.state.s.mode == "playing","entry actual LOS/placement refusal leaves playing")
	groups += 1
func _prepared_bosses() -> void:
	var bundle: Dictionary = _bundle(); var before: Dictionary = _outcome(bundle)
	var first: Dictionary = bundle.bosses.prepare_old_school_brutus()
	_check(first.ok and not first.noop and not first.has("body"),"prepared body stays private behind one-use token")
	_check(_same(_outcome(bundle),before),"real physical preflight has zero state/events/RNG effects")
	var second: Dictionary = bundle.bosses.prepare_old_school_brutus()
	bundle.bosses.discard_old_school_brutus(first)
	_check(not bundle.bosses.commit_old_school_brutus(first) and bundle.bosses.commit_old_school_brutus(second),"old plan/discard cannot consume newer pending plan")
	_check(_same(bundle.state.npcs[0],fixture.body) and bundle.state.npcs.size() == 1,"commit creates exact canonical source actor once")
	before = _outcome(bundle)
	_check(not bundle.bosses.commit_old_school_brutus(second) and _same(_outcome(bundle),before),"prepared spawn cannot replay")
	_check(not bundle.bosses.spawn_old_school_brutus(),"legacy bool wrapper still refuses an existing actor")
	var corpse: Dictionary = _bundle({"actor":"dead"}); var plan: Dictionary = corpse.bosses.prepare_old_school_brutus(); before = _outcome(corpse)
	_check(plan.ok and plan.noop and corpse.physics.placement_calls == 0 and corpse.bosses.commit_old_school_brutus(plan),"direct corpse capability is successful source no-op")
	_check(_same(_outcome(corpse),before),"corpse plan emits no spawn/reward/save")
	for key: String in ["p","s"]:
		bundle = _bundle(); plan = bundle.bosses.prepare_old_school_brutus()
		if key == "p": bundle.state.p = bundle.state.p.duplicate(true)
		else: bundle.state.s = bundle.state.s.duplicate(true)
		before = _outcome(bundle)
		_check(not bundle.bosses.commit_old_school_brutus(plan) and _same(_outcome(bundle),before),"direct prepared "+key+" epoch rejects without replacement effects")
	var miss: Dictionary = _bundle({"killed":true,"rolls":[0.9]}); var miss_page: Dictionary = miss.school.open()
	_check(miss.school.select(miss_page.token,"rip").ok and miss.bosses._old_school_pending.is_empty(),"risk miss discards bounded unused plan")
	groups += 1
func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/old_school_reference.json"))
	if not parsed is Dictionary: push_error("Old School fixture invalid"); quit(1); return
	fixture = parsed
	_source(); _capabilities(); _physics_and_reentry(); _prepared_bosses()
	_check(completed == 79 and groups == 4,"all22entries+57steps and fourgroups completed without skipped abort")
	if failures.is_empty(): print("3D OLD SCHOOL: PASS (%d checks / 22 source entries / 48 paths / 57 steps)" % checks); quit(0)
	else:
		for failure: String in failures: print("FAIL: "+failure)
		print("3D OLD SCHOOL: FAIL (%d/%d)" % [failures.size(),checks]); quit(1)
