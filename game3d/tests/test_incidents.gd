extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Incidents = preload("res://scripts/incident_system.gd")
const Communications = preload("res://scripts/communications_system.gd")
const Props = preload("res://scripts/prop_state.gd")
const Memory = preload("res://scripts/memory_loop.gd")
var checks: int = 0
var failures: Array[String] = []
var fixture: Dictionary = {}
class SequenceState:
	extends "res://scripts/game_state.gd"
	var rolls: Array = []
	var draws: int = 0
	func random_float() -> float:
		var value: float = rolls[draws] if draws < rolls.size() else 0.4
		draws += 1; return value
	func random_index(size: int) -> int: return mini(size-1,int(floor(random_float()*size))) if size > 0 else 0
class Spatial:
	extends RefCounted
	var fraction: float = 1.0
	var malformed: bool = false
	var calls: int = 0
	func move_body(body: Dictionary,intended: Vector2,_goal: Variant = null,_stop: bool = false) -> Dictionary:
		calls += 1
		return {"position":Vector2(NAN,0),"blocked":true} if malformed else {"position":Vector2(body.x,body.y).lerp(intended,fraction),"blocked":fraction < 1.0}
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _unix() -> float: return 1763424000000.0
func _copy(value: Variant) -> Variant: return value.duplicate(true) if value is Dictionary or value is Array else value
func _same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.000001
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
func _bundle() -> Dictionary:
	var state := SequenceState.new(); var spatial := Spatial.new(); var props := Props.new(state)
	var comms := Communications.new(state,props,_unix); var incidents := Incidents.new(state,spatial,comms)
	_check(incidents.ready(),"real incident/comms/source composition ready")
	state.s.mode = "playing"
	return {"state":state,"spatial":spatial,"props":props,"comms":comms,"incidents":incidents}
func _setup(b: Dictionary,data: Dictionary) -> void:
	for key: String in data.player: b.state.p[key] = _copy(data.player[key])
	for key: String in data.state: b.state.s[key] = _copy(data.state[key])
	for key: String in data.flags: b.state.s.flags[key] = _copy(data.flags[key])
	b.state.npcs.assign(data.actors.duplicate(true)); b.comms._posts.assign(data.posts.duplicate(true))
	b.state.events.clear(); b.state.draws = 0
func _change(b: Dictionary,values: Dictionary) -> void:
	for key: String in values.get("player",{}): b.state.p[key] = _copy(values.player[key])
	for key: String in values.get("state",{}): b.state.s[key] = _copy(values.state[key])
	for key: String in values.get("flags",{}): b.state.s.flags[key] = _copy(values.flags[key])
	for id: String in values.get("actors",{}):
		var found: bool = false
		for actor: Dictionary in b.state.npcs:
			if actor.id == id: actor.merge(values.actors[id].duplicate(true),true); found = true; break
		_check(found,"source actor mutation resolves "+id)
func _operation(b: Dictionary,op: Dictionary,label: String) -> void:
	match op.kind:
		"start": _check(b.incidents._start(op.id),label+" source start accepted")
		"finish": b.incidents._finish(op.interrupted)
		"ensure_flags": b.incidents._ensure_flags()
		"change": _change(b,op.values)
		"tick":
			var remaining: float = op.ms
			while remaining > 0:
				var step: float = minf(50,remaining)
				_check(b.incidents.tick_active(step,op.intro,op.silence),label+" bounded accepted active step")
				remaining -= step
		"align_actor":
			b.state.p.x = 8000; b.state.p.y = 5400; b.state.s.incident.t = op.time
			b.incidents._update_active(b.state.s.incident)
			b.state.p.x = op.center.x-b.state.p.w*0.5; b.state.p.y = op.center.y-b.state.p.h*0.5
		"update_active": b.incidents._update_active(b.state.s.incident)
		_: _check(false,"unknown oracle operation "+str(op.kind))
func _actor_projection(actor: Dictionary) -> Dictionary:
	return {"id":actor.id,"x":actor.x,"y":actor.y,"w":actor.w,"h":actor.h,"dead":actor.get("dead",false),"aggro":actor.get("aggro",false),"hostile":actor.get("hostile",false),"isDay3Visitor":actor.get("isDay3Visitor",false),"hidden":actor.get("hidden",false)}
func _compare(b: Dictionary,expected: Dictionary,event_start: int,label: String) -> void:
	for key: String in expected.player:
		var same: bool = absf(float(b.state.p[key])-float(expected.player[key])) < 0.001 if key in ["x","y"] else _same(b.state.p[key],expected.player[key])
		_check(same,label+" player."+key+" got "+str(b.state.p[key])+" expected "+str(expected.player[key]))
	for key: String in expected.state:
		_check(_same(b.state.s.get(key),expected.state[key]),label+" state."+key+" got "+str(b.state.s.get(key)).left(450)+" expected "+str(expected.state[key]).left(450))
	for key: String in expected.flags: _check(_same(b.state.s.flags.get(key),expected.flags[key]),label+" flags."+key)
	var actors: Array = []
	for actor: Dictionary in b.state.npcs: actors.append(_actor_projection(actor))
	_check(_same(actors,expected.actors),label+" incident cannot mutate NPC payloads or append scene actors")
	_check(_same(b.comms.snapshot().posts,expected.posts),label+" source feed")
	_check(b.state.draws == expected.draws,label+" source RNG got%d expected%d" % [b.state.draws,expected.draws])
	var writes: int = 0; var toast: String = ""; var sounds: Array = []
	for index: int in range(b.state.events.size()):
		var event: Dictionary = b.state.events[index]
		if event.kind == "save_requested": writes += 1
		if index >= event_start:
			if event.kind == "toast": toast = event.payload.text
			elif event.kind == "sound": sounds.append(event.payload.id)
	_check(writes == expected.writes,label+" source saves")
	_check(toast == expected.toast,label+" exact source receipt got "+toast+" expected "+str(expected.toast))
	_check(_same(sounds,expected.sounds),label+" exact source sound order")
func _source_cases() -> void:
	_check(fixture.counts.cases == 132 and fixture.counts.steps == 458 and fixture.counts.incidents == 6 and fixture.counts.beats == 24,"132 independent paths458steps/6 scenes24beats")
	for path: Dictionary in fixture.cases:
		var b: Dictionary = _bundle(); _setup(b,path.setup); b.state.rolls.assign(path.rolls)
		var number: int = 0
		for step: Dictionary in path.steps:
			number += 1; var label: String = str(path.id)+" step%d %s" % [number,step.operation.kind]
			var first: int = b.state.events.size(); _operation(b,step.operation,label); _compare(b,step.expected,first,label)
func _bump_fixtures() -> void:
	var path: Dictionary = {}
	for item: Dictionary in fixture.cases:
		if item.id == "mattress_bump_time_after": path = item; break
	_check(not path.is_empty(),"source strict1800ms bump fixture exists")
	for fraction: float in [0.0,0.5,1.0]:
		var b: Dictionary = _bundle(); _setup(b,path.setup); b.spatial.fraction = fraction
		_operation(b,path.steps[0].operation,"physical bump source start"); _operation(b,path.steps[1].operation,"physical bump source alignment")
		var before := Vector2(b.state.p.x,b.state.p.y); var resources: Dictionary = b.state.snapshot(); var npcs: Array = b.state.npcs.duplicate(true)
		b.incidents._update_active(b.state.s.incident)
		var after := Vector2(b.state.p.x,b.state.p.y)
		_check(is_equal_approx(before.distance_to(after),14.0*fraction),"capsule-shortened bump commits only returned displacement "+str(fraction))
		_check(b.state.s.incident.bumped and b.state.s.shake == 5 and b.spatial.calls == 1,"blocked bump still records once and shakes")
		b.incidents._update_active(b.state.s.incident)
		_check(b.spatial.calls == 1 and Vector2(b.state.p.x,b.state.p.y) == after,"incident never repeats a blocked or partial bump")
		resources.player.x = b.state.p.x; resources.player.y = b.state.p.y
		_check(_same(resources,b.state.snapshot()) and npcs == b.state.npcs,"bump has no damage/reward/economy/NPC effect")
	var malformed: Dictionary = _bundle(); _setup(malformed,path.setup); malformed.spatial.malformed = true
	_operation(malformed,path.steps[0].operation,"malformed start"); _operation(malformed,path.steps[1].operation,"malformed align")
	var before := Vector2(malformed.state.p.x,malformed.state.p.y)
	malformed.incidents._update_active(malformed.state.s.incident)
	_check(Vector2(malformed.state.p.x,malformed.state.p.y) == before and malformed.state.s.incident.bumped,"malformed adapter cannot poison position or repeat event")
	_check(malformed.state.events.any(func(event: Dictionary): return event.kind == "dependency_missing"),"malformed physical return reports missing capability")
func _lifecycle() -> void:
	_check(fixture.lifecycle.fresh.active == "yuri_receipt" and fixture.lifecycle.fresh.delay == 321 and fixture.lifecycle.fresh.paper == 91 and fixture.lifecycle.fresh.wet == 92,"source fresh carryover remains explicitly characterized")
	_check(fixture.lifecycle.restore.ok and fixture.lifecycle.restore.active == null and fixture.lifecycle.restore.delay == 40000 and fixture.lifecycle.restore.draws == 1,"source actual load clears scene and draws one replacement delay")
	var b: Dictionary = _bundle(); b.state.s.incidentT = 321; b.incidents._start("yuri_receipt")
	b.state.s.incidentPaperT = 91; b.state.s.incidentWetT = 92
	var view: Dictionary = b.incidents.visual_snapshot(); view.active.t = 999
	_check(b.state.s.incident.t == 0,"presentation snapshot cannot mutate scene authority")
	var before: Dictionary = b.state.snapshot(); var events: Array = b.state.events.duplicate(true); var draws: int = b.state.draws
	_check(not b.incidents.tick_active(0,false,false) and not b.incidents.tick_active(51,false,false) and not b.incidents.tick_active(NAN,false,false),"active clocks reject invalid delta")
	_check(before == b.state.snapshot() and events == b.state.events and draws == b.state.draws,"invalid clock is pure")
	b.state.s.mode = "paused"; b.incidents.tick_active(50,false,false)
	_check(b.state.s.incident.t == 0 and b.state.s.incidentPaperT == 91,"paused mode cannot advance scene or cosmetics")
	b.state.s.mode = "playing"; b.state.s.hitPause = 5; b.incidents.tick_active(50,false,false)
	_check(b.state.s.incident.t == 0,"hitpause cannot advance incident")
	b.state.fresh(); var timer: float = b.state.s.incidentT; var flags: Dictionary = b.state.s.flags.duplicate(true); draws = b.state.draws
	_check(not b.incidents.tick_active(1,false,false) and b.incidents.visual_snapshot().active == null,"unbound replaced epoch cannot run old incident")
	_check(b.incidents.reset_session("fresh") and b.state.s.incident == null and b.state.s.incidentPaperT == 0 and b.state.s.incidentWetT == 0,"approved fresh adaptation drops stale scene/cosmetics")
	_check(b.state.s.incidentT == timer and b.state.draws == draws and b.state.s.flags == flags,"fresh rebinding preserves core timer/history without extra draw")
	b.state.s.day = 2; b.state.s.flags.incidentDay = 2; b.state.s.flags.incidentMask = 9; b.state.s.flags.incidentsToday = 2; b.state.s.flags.lastIncidentId = "yuri_receipt"
	var saved: Dictionary = b.state.snapshot()
	_check(not saved.state.has("incident") and not saved.state.has("incidentT"),"save contains history without invisible incident state")
	_check(b.state.restore(saved).ok,"actual codec restore accepts source history")
	b.state.rolls = [0.25]; b.state.draws = 0
	_check(b.incidents.reset_session("restore") and b.state.s.incidentT == 40000 and b.state.draws == 1,"restore owner matches exact source single delay draw")
	_check(b.incidents.reset_session("restore") and b.state.draws == 1,"same-epoch restore callback cannot reroll delay")
	for key: String in fixture.lifecycle.restore.storedHistory: _check(_same(b.state.s.flags[key],fixture.lifecycle.restore.storedHistory[key]),"actual restore retains incident history "+key)
func _real_loop() -> void:
	var b: Dictionary = _bundle(); var memory := Memory.new(b.state)
	b.state.p.x = 1050; b.state.p.y = 840; b.state.p.rocks = 1; b.state.p.soapRocks = 0; b.state.p.shakes = 0
	_check(memory.smoke("block").ok,"real Block smoke starts sole high clock")
	b.incidents._start("runaway_mattress")
	for index: int in range(520):
		_check(b.state.tick(0.05,{"at_block":true}) and b.incidents.tick_active(50,false,false),"shared accepted step advances core and scene")
		if index == 358: _check(absf(b.state.p.rockedT-50) < 0.001 and b.state.p.crashT == 0,"incident does not shorten18s high")
		if index == 359: _check(b.state.p.rockedT == 0 and absf(b.state.p.crashT-8000) < 0.001,"incident cannot skip real8s crash boundary")
	_check(b.state.p.rockedT == 0 and b.state.p.crashT == 0 and b.state.s.incident == null,"scene and complete26s loop settle independently")
func _run() -> void:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/incidents_reference.json"))
	_check(decoded is Dictionary,"incident source oracle parses")
	if decoded is Dictionary: fixture = decoded; _source_cases(); _bump_fixtures(); _lifecycle(); _real_loop()
	if failures.is_empty(): print("3D INCIDENTS GATE: PASS (%d checks;132 source paths458steps/6 scenes24beats; presenter/physical paths/Runtime activation pending)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D INCIDENTS GATE: FAIL (%d failures/%d checks)" % [failures.size(),checks]); quit(1)
