extends SceneTree
## Isolated native input evidence. No production-save writes or gameplay substitutions.
const Content = preload("res://scripts/content_catalog.gd")
const Contact = preload("res://scripts/actor_contact.gd")
# Test-only shared geometry policy; no Boss probe instance or gameplay owner.
const CombatDriver = preload("res://tests/boss_acceptance_probe.gd")
const PHASE_LIMITS := {"intro":120000,"routes":480000,"office_claim":480000,"work_restore":300000,"cot_day":150000}
const TOTAL_LIMIT := 1600000
const WALK_LOCAL_STEP := 0.04
const WALK_LOCAL_MAX_STEPS := 26
const WALK_LOCAL_TAILS := 4

class ObservedScene:
	extends "res://scripts/full_scene.gd"
	signal frame_sampled
	var audit_enabled := false
	var admitted_ms := 0.0
	var trace: Array[Dictionary] = []
	var samples: Array[Dictionary] = []
	var player_epoch: Dictionary = {}
	var state_epoch: Dictionary = {}
	var replacements: Array[Dictionary] = []
	var overflow := false
	var loop_start := -1.0
	var high_end := -1.0
	var crash_end := -1.0
	var last_sample := -1000.0
	var weapon_changes: Array[Dictionary] = []
	var last_weapon := "fists"
	func start_audit() -> void:
		audit_enabled = true; player_epoch = runtime.p; state_epoch = runtime.s; last_weapon = runtime.p.weapon
	func _process(delta: float) -> void:
		var active: bool = ready_for_play and runtime != null and runtime.s.mode == "playing" and not loading
		var was_high: float = float(runtime.p.rockedT) if runtime != null else 0.0
		var was_crash: float = float(runtime.p.crashT) if runtime != null else 0.0
		super._process(delta)
		if not audit_enabled: frame_sampled.emit(); return
		if active: admitted_ms += runtime.last_advanced_ms
		if not is_same(player_epoch,runtime.p) or not is_same(state_epoch,runtime.s):
			replacements.append({"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms,"mode":runtime.s.mode})
			player_epoch = runtime.p; state_epoch = runtime.s
		if last_weapon != str(runtime.p.weapon):
			weapon_changes.append({"from":last_weapon,"to":runtime.p.weapon,"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms}); last_weapon = runtime.p.weapon
		if loop_start >= 0:
			if was_high > 0 and runtime.p.rockedT <= 0 and high_end < 0: high_end = admitted_ms
			if high_end >= 0 and was_crash > 0 and runtime.p.crashT <= 0 and crash_end < 0: crash_end = admitted_ms
		if admitted_ms-last_sample >= 500.0:
			last_sample = admitted_ms
			if samples.size() >= 4000: overflow = true
			else: samples.append({"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms,"mode":runtime.s.mode,"player":[runtime.p.x,runtime.p.y],"hp":runtime.p.hp,"shakes":runtime.p.shakes,"high":runtime.p.rockedT,"crash":runtime.p.crashT,"speed":runtime.p.speed,"weapon":runtime.p.weapon,"day":runtime.s.day,"day_time":runtime.s.dayTime,"actors":runtime.state.npcs.size()})
		frame_sampled.emit()
	func _consume_events() -> void:
		if audit_enabled and runtime != null:
			var observed: Array = runtime._outbox.duplicate(); observed.append_array(runtime.state.events)
			for event: Dictionary in observed:
				if event.kind not in ["actor_hit","player_attack","hurt","death","arrest","boss_started","actor_spawned","actor_died","actor_departed","ending_requested","ending","dependency_missing","toast","feed","placement_reset"]: continue
				if trace.size() >= 40000: overflow = true; break
				trace.append({"kind":event.kind,"payload":event.get("payload",{}).duplicate(true),"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms,"weapon":runtime.p.weapon})
		super._consume_events()

var game: ObservedScene
var output := ""
var diagnostic := false
var failures: Array[String] = []
var captures: Array[String] = []
var receipts: Array[Dictionary] = []
var route_receipts: Array[Dictionary] = []
var attack_receipts: Array[Dictionary] = []
var phases: Array[Dictionary] = []
var legs: Array[Dictionary] = []
var saves: Array[Dictionary] = []
var inputs := {"motion_frames":0,"mouse_motion":0,"keys":0,"clicks":0,"capture_clicks":0,"menu_clicks":0}
var initial: Dictionary = {}
var initial_actor_ids: Array[String] = []
var loop: Dictionary = {}
var began_wall := 0
var phase_name := ""
var phase_wall := 0
var phase_active := 0.0
var decision_wall := -1000
var motion := Vector2.ZERO
var last_frame_wall := 0
var walking: Array[Dictionary] = []
var failure_context: Dictionary = {}
var walking_goal := Vector3.INF
var walking_context: Dictionary = {}
var resident_route_context: Dictionary = {}
var walking_local_context: Dictionary = {}
var service_aim_wait: Dictionary = {}
var service_aim_context: Dictionary = {}
var last_requested_motion := Vector2.ZERO
var last_actual_input := Vector2.ZERO
var rest_count := 0
var preserved_ids := true
var checked_event_count := 0
var combat_plan: Dictionary = {}
var combat_context: Dictionary = {}
var combat_navigation: Array[Dictionary] = []
var combat_replans := 0
var combat_last_plan := -1000
var combat_endpoint_attempts := 0
var combat_occluded_decisions := 0

static func interaction_matches(action: Dictionary,id: String) -> bool:
	if id == "smoke:block": return action.get("kind") == "smoke" and action.get("id") == "block"
	var kind := ""
	if id == "tony": kind = "vendor"
	elif id in ["office","lease_guy"]: kind = "office"
	elif id.begins_with("route:"): kind = "route"
	elif id.begins_with("claim:"): kind = "office_field"
	return not kind.is_empty() and action.get("kind") == kind and action.get("id") == id

static func _same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_finite(float(a)) and is_finite(float(b)) and absf(float(a)-float(b)) < 0.0001
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

static func route_errors(rows: Array) -> Array[String]:
	var errors: Array[String] = []
	if rows.size() != 9: errors.append("nine real source route stamps required"); return errors
	var known: Dictionary = {}
	for stop: Dictionary in Content.definition("src/systems/progression_routes.js","ROUTE_STOPS",[]): known[str(stop.id)] = stop
	var previous: Dictionary = {}
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]; var a: Dictionary = row.get("before",{}); var b: Dictionary = row.get("after",{})
		var route: Dictionary = a.get("route",{}); var cursor: int = int(route.get("cursor",-1))
		var expected_cursor: int = index%3; var completed: int = index/3
		var stops: Array = route.get("stops",[])
		if cursor != expected_cursor or stops.size() != 3 or int(a.get("routes",-1)) != completed: errors.append("source route cursor/lifetime sequence")
		if stops.size() == 3 and cursor >= 0 and cursor < 3:
			for stop: Variant in stops:
				if not known.has(str(stop)): errors.append("unknown route stop")
				elif completed < 2 and (known[str(stop)].x >= 2100 or known[str(stop)].y >= 2100): errors.append("first two routes escaped original neighborhood")
			if row.get("service") != "route:"+str(stops[cursor]) or not interaction_matches(row.get("resolved",{}),row.get("service","")): errors.append("stamp did not resolve generated target")
			if stops[0] == stops[1] or stops[0] == stops[2] or stops[1] == stops[2]: errors.append("generated route has duplicate stops")
		if not previous.is_empty() and not _same(previous,route): errors.append("route replaced between stamps")
		var next: Dictionary = b.get("route",{})
		if cursor < 2:
			var changed: Dictionary = route.duplicate(true); changed.cursor = cursor+1
			if not _same(changed,next) or b.get("routes") != completed or b.get("cash") != a.get("cash") or b.get("cred") != a.get("cred"): errors.append("intermediate stamp payout/state drift")
		else:
			if b.get("routes") != completed+1 or float(b.get("cash",0))-float(a.get("cash",0)) != 6 or float(b.get("cred",0))-float(a.get("cred",0)) != 1: errors.append("final source route payout differs")
			if int(next.get("cursor",-1)) != 0 or int(next.get("serial",-1)) != int(route.get("serial",0))+1 or next.get("lastStopId") != stops.back(): errors.append("next source sheet lineage differs")
		previous = next.duplicate(true)
		var distance: float = float(row.get("source_distance",INF))
		if not is_finite(distance) or distance < 0.0 or distance >= 58.0 or not row.get("reachable",false): errors.append("route stamp lacks strict live reach")
		if cursor >= 0 and cursor < stops.size() and known.has(str(stops[cursor])):
			var expected: String = str(known[str(stops[cursor])].stamp)+("\n[%d/3 stamped]" % (cursor+1) if cursor < 2 else "\n· ROUTE FILED %d ·  + $6 · + 1 cred\na new sheet is under the brick.%s" % [completed+1,"\nthe leasing guy has a key in the lot." if completed == 2 else ""])
			if not _has_toast(row,expected): errors.append("exact source stamp receipt absent")
	if not rows.back().get("after",{}).get("office_available",false): errors.append("third route did not expose Office")
	return errors

static func _has_toast(row: Dictionary,text: String) -> bool:
	for event: Dictionary in row.get("events",[]):
		if event.get("kind") == "toast" and event.get("payload",{}).get("text") == text: return true
	return false

static func expected_toast(kind: String) -> String:
	var texts := {
		"lease":"- $40 · - 1 copper\n+ one key\nthe office is yours in the sense that no one stopped you.",
		"desk":"· OFFICE UPGRADE ·\ndesk installed.\nselect and file district claims.",
		"radio":"· OFFICE UPGRADE ·\nradio installed.\nreceive bounded work orders.",
		"cot":"· OFFICE UPGRADE ·\ncot installed.\nrest. sleep. wake up in the same room.",
		"select_claim":"· CLAIM OPENED ·\nTHE DRAINAGE CANAL\nfirst: read the water gauge while the water is absent.",
		"survey":"gauge says nine.\nwater says nothing.\nreturn to the office. the desk wants money.",
		"file_claim":"- $20 · - 1 copper\nform filed.\nnow install the sign at the drainage canal.",
		"install":"the sign leans east.\nthe canal is entered as pending.\n· DISTRICT ENTERED ·  + 2 cred\nTHE DRAINAGE CANAL",
		"work":"· WORK ORDER 1 ·\ninspect the sign at the drainage canal.\nbring the condition back.",
		"inspect":"sign inspected.\nit is still leaning.\nreturn to the office.",
		"file_work":"· ORDER 1 FILED ·\ngross $23. chair rental $17.\nnet + $6",
		"rest":"the generator clicks.\nthe cot files no complaint.",
		"sleep":"you slept at the office.\nthe office opened before you did.\nthe day is the next day.",
		"work_next":"· WORK ORDER 2 ·\ninspect the sign at the drainage canal.\nbring the condition back."}
	return str(texts.get(kind,""))

static func transaction_errors(rows: Array) -> Array[String]:
	var errors: Array[String] = []; var counts: Dictionary = {}
	var ordered: Array[String] = []
	var required: Array[String] = ["lease","desk","radio","cot","select_claim","survey","file_claim","install","work","inspect","file_work","disabled_cap","sleep","work_next"]
	var prices := {"lease":Vector2(40,1),"desk":Vector2(60,2),"radio":Vector2(90,2),"cot":Vector2(30,0),"file_claim":Vector2(20,1)}
	for row: Dictionary in rows:
		var id: String = str(row.get("kind","")); counts[id] = int(counts.get(id,0))+1
		if id in required: ordered.append(id)
		var exact: String = expected_toast(id)
		if not exact.is_empty() and not _has_toast(row,exact): errors.append("exact source receipt differs: "+id)
		var a: Dictionary = row.get("before",{}); var b: Dictionary = row.get("after",{})
		if id == "buy_rock":
			var price: int = 9 if int(a.get("faction",{}).get("street",0)) >= 10 else 10
			if int(a.get("charisma",0)) >= 1: price = maxi(1,int(floor(float(price)*0.9+0.5)))
			if float(a.get("cash",0))-float(b.get("cash",0)) != price or int(b.get("rocks",0))-int(a.get("rocks",0)) != 1: errors.append("normal Tony purchase price/rock differs")
			var text := "- $%d\n+ 1 rock" % price+("\n(the crown got you a discount.\nhe is not happy about it.)" if price < 10 else "")
			if not _has_toast(row,text): errors.append("exact Tony purchase receipt absent")
		if id == "smoke":
			if int(a.get("rocks",0))-int(b.get("rocks",0)) != 1 or b.get("high") != 18000 or int(b.get("rocks_smoked",0))-int(a.get("rocks_smoked",0)) != 1 or not b.get("intro",false): errors.append("normal Block smoke did not consume one actual rock")
		if prices.has(id):
			if float(a.get("cash",0))-float(b.get("cash",0)) != prices[id].x or float(a.get("copper",0))-float(b.get("copper",0)) != prices[id].y: errors.append("wrong source price: "+id)
			if id == "lease" and (a.get("office",{}).get("owned",true) or not b.get("office",{}).get("owned",false) or a.get("routes",0) < 3): errors.append("lease prerequisites/ownership drift")
			if id in ["desk","radio","cot"] and (a.get("office",{}).get("upgrades",{}).get(id,true) or not b.get("office",{}).get("upgrades",{}).get(id,false)): errors.append("upgrade was not purchased once: "+id)
		if id in ["select_claim","survey","file_claim"]:
			var stages := {"select_claim":"survey","survey":"file","file_claim":"install"}
			if b.get("office",{}).get("claimJob") != {"id":"canal","stage":stages[id]}: errors.append("canal claim stage differs: "+id)
		if id in ["survey","install","inspect"]:
			var distance: float = float(row.get("source_distance",INF))
			if not row.get("reachable",false) or not is_finite(distance) or distance < 0.0 or distance >= 58.0: errors.append("field lacks strict live reach: "+id)
			if not interaction_matches(row.get("resolved",{}),row.get("service","")): errors.append("wrong resolved field: "+id)
		if id == "install":
			if a.get("office",{}).get("claimJob") != {"id":"canal","stage":"install"} or b.get("office",{}).get("claimJob") != null or b.get("claims",{}) != {"canal":true}: errors.append("actual first claim installation missing")
			if float(b.get("cred",0))-float(a.get("cred",0)) != 2 or not b.get("paper_done",false): errors.append("claim milestone/payout differs")
		if id == "work":
			if b.get("office",{}).get("workJob") != {"id":"canal","stage":"inspect","serial":1}: errors.append("first radio order was not generated normally")
		if id == "inspect" and b.get("office",{}).get("workJob") != {"id":"canal","stage":"file","serial":1}: errors.append("radio order inspection missing")
		if id == "file_work":
			if a.get("office",{}).get("workJob") != {"id":"canal","stage":"file","serial":1} or b.get("office",{}).get("workJob") != null: errors.append("pending radio order not consumed once")
			if float(b.get("cash",0))-float(a.get("cash",0)) != 6 or b.get("cred") != a.get("cred") or b.get("office",{}).get("jobsCompleted") != 1 or b.get("office_jobs") != 1 or b.get("office",{}).get("workToday") != 1: errors.append("first work payment/cap differs")
		if id == "sleep":
			if float(a.get("day_time",0)) <= 0.3 or int(b.get("day",0)) != int(a.get("day",0))+1 or not is_equal_approx(float(b.get("day_time",0)),0.3): errors.append("cot must commit actual next day")
			for field: String in ["hp","brain","shakes","wanted"]:
				var expected: float = minf(float(a.get("max_hp",100)),float(a.get("hp",0))+55) if field == "hp" else (minf(100,float(a.get(field,0))+(25 if field == "brain" else 15)) if field != "wanted" else maxf(0,float(a.get(field,0))-2))
				if not _same(b.get(field),expected): errors.append("source cot effect differs: "+field)
			if b.get("office",{}).get("workToday") != 0 or b.get("office_jobs") != 1 or not _same(a.get("claims"),b.get("claims")) or not _same(a.get("office",{}).get("upgrades"),b.get("office",{}).get("upgrades")): errors.append("cot reset erased durable work/claims/upgrades")
		if id == "work_next" and b.get("office",{}).get("workJob") != {"id":"canal","stage":"inspect","serial":2}: errors.append("next-day radio order missing")
		if id == "disabled_cap" and not row.get("disabled",false): errors.append("daily cap was not visibly disabled")
		if id not in ["menu","save","load","resume","disabled_cap"]:
			var toast_found := false
			for event: Dictionary in row.get("events",[]):
				if event.get("kind") == "toast": toast_found = true
			if not toast_found: errors.append("source transaction toast absent: "+id)
	for id: String in ["lease","desk","radio","cot","select_claim","survey","file_claim","install","work","inspect","file_work","sleep","work_next","disabled_cap"]:
		if counts.get(id,0) != 1: errors.append("exactly one accepted progression action required: "+id)
	if ordered != required: errors.append("actual Office progression order differs")
	if counts.get("buy_rock",0) < 1 or counts.get("smoke",0) < 1: errors.append("actual purchase/smoke receipts missing")
	return errors

static func assess(report: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(defense_errors(report))
	if report.get("fixture") != {"kind":"fresh_resources_only","cash":300,"copper":6,"writes":2}: errors.append("unapproved fixture")
	var a: Dictionary = report.get("initial",{}); var b: Dictionary = report.get("final",{})
	for key: String in ["cash","copper","hp","max_hp","weapon","cred","brain","rocks","routes","office_jobs","offenses","speed","cart_mounted"]:
		var expected := {"cash":300,"copper":6,"hp":100,"max_hp":100,"weapon":"fists","cred":0,"brain":70,"rocks":0,"routes":0,"office_jobs":0,"offenses":0,"speed":2.2,"cart_mounted":false}
		if not _same(a.get(key),expected[key]): errors.append("fresh starting value differs: "+key)
	if a.get("intro",true) or a.get("office",{}).get("owned",true) or not a.get("claims",{}).is_empty() or not a.get("inventory",[]).is_empty(): errors.append("unearned initial progression or inventory")
	if a.get("office_available",true) or a.get("paper_done",true) or int(a.get("charisma",0)) != 0: errors.append("unearned starting quest/stat bonus")
	for faction: String in ["street","scrap","spiritual"]:
		if int(a.get("faction",{}).get(faction,0)) != 0: errors.append("unearned starting faction reputation")
	if not a.get("route",{}).is_empty(): errors.append("route was injected before actual intro")
	for value: Variant in a.get("office",{}).get("upgrades",{}).values():
		if value: errors.append("unearned initial Office upgrade")
	for slot: String in ["coat","hat","shoes","tool"]:
		if a.get("equip",{}).get(slot) != null: errors.append("unearned starting equipment")
	errors.append_array(route_errors(report.get("route_receipts",[])))
	errors.append_array(transaction_errors(report.get("receipts",[])))
	var l: Dictionary = report.get("loop",{})
	if l.get("purchased") != true or l.get("spent") != true or l.get("initial_high") != 18000 or l.get("initial_smokes") != 1: errors.append("actual purchased rock and intro smoke missing")
	for key: String in ["high_ms","crash_ms"]:
		var elapsed: float = float(l.get(key,NAN)); var expected := 18000.0 if key == "high_ms" else 8000.0
		if not is_finite(elapsed) or absf(elapsed-expected) > 100: errors.append("actual source loop incomplete: "+key)
	var snapshots: Array = report.get("saves",[])
	if snapshots.size() != 2 or int(report.get("epoch_replacements",-1)) != 2: errors.append("exact two intentional load epochs required")
	for index: int in range(snapshots.size()):
		var save: Dictionary = snapshots[index]
		if not save.get("durable",false) or not save.get("menu_loaded",false) or not _same(save.get("before",{}),save.get("after",null)) or not _same(save.get("before",{}),save.get("stored",null)): errors.append("actual pending/completed state did not round trip")
		var job: Variant = save.get("after",{}).get("workJob")
		if index == 0 and job != {"id":"canal","stage":"file","serial":1}: errors.append("first save was not unpaid inspected work")
		if index == 1 and (job != null or save.get("after",{}).get("jobsCompleted") != 1): errors.append("completed save recreated paid work")
	var seen: Array[String] = []
	for phase: Dictionary in report.get("phases",[]):
		var id: String = str(phase.get("id","")); seen.append(id)
		var elapsed: float = float(phase.get("wall_ms",INF))
		if not PHASE_LIMITS.has(id) or not is_finite(elapsed) or elapsed <= 0.0 or elapsed >= float(PHASE_LIMITS.get(id,0)): errors.append("phase watchdog exceeded: "+id)
	if seen != ["intro","routes","office_claim","work_restore","cot_day"]: errors.append("ordered phases incomplete")
	var total: float = float(report.get("wall_ms",INF))
	if not is_finite(total) or total <= 0.0 or total >= TOTAL_LIMIT: errors.append("total watchdog exceeded")
	var destinations: Dictionary = {}
	for leg: Dictionary in report.get("legs",[]):
		var id: String = str(leg.get("service","")); destinations[id] = int(destinations.get(id,0))+1
		var wall: float = float(leg.get("wall_ms",INF)); var active: float = float(leg.get("active_ms",INF))
		if not leg.get("arrived",false) or not is_finite(wall) or wall < 0.0 or wall >= 120000 or not is_finite(active) or active < 0.0: errors.append("input walk did not arrive within bound")
		if leg.get("inter_stop",false) and active >= 60000: errors.append("mandatory inter-stop route exceeded60seconds")
	for id: String in ["tony","smoke:block","lease_guy","claim:canal:survey"]:
		if destinations.get(id,0) < 1: errors.append("actual input leg missing: "+id)
	if destinations.get("office",0) < 4 or destinations.get("claim:canal:sign",0) < 2: errors.append("Office survey/work return legs missing")
	var reached_routes := 0
	for id: String in destinations:
		if id.begins_with("route:"): reached_routes += int(destinations[id])
	if reached_routes != 9: errors.append("nine generated route approaches required")
	for key: String in ["motion_frames","mouse_motion","keys","menu_clicks","capture_clicks"]:
		if int(report.get("inputs",{}).get(key,0)) <= 0: errors.append("missing actual input: "+key)
	if report.get("overflow",true) or not report.get("canonical_roster_retained",false): errors.append("evidence overflow or removed canonical cast")
	if not report.get("dependencies",[]).is_empty() or report.get("deaths",1) != 0 or report.get("arrests",1) != 0 or report.get("boss_starts",1) != 0: errors.append("unexpected dependency/death/arrest/boss")
	var weapons: Dictionary = weapon_chain(report.get("attack_receipts",[]))
	if not weapons.ok: errors.append_array(weapons.errors)
	if b.get("weapon") != weapons.final_weapon: errors.append("terminal weapon lacks input reward provenance")
	var expected_changes: Array = []; var observed_changes: Array = []
	for row: Dictionary in report.get("attack_receipts",[]):
		if row.get("before_weapon") != row.get("after_weapon"): expected_changes.append([row.get("before_weapon"),row.get("after_weapon")])
	for change: Dictionary in report.get("weapon_changes",[]): observed_changes.append([change.get("from"),change.get("to")])
	if not _same(expected_changes,observed_changes): errors.append("live weapon changed outside accepted input reward")
	if b.get("routes") != 3 or b.get("office_jobs") != 1 or b.get("claims") != {"canal":true} or b.get("office",{}).get("workJob") != {"id":"canal","stage":"inspect","serial":2}: errors.append("earned handoff milestone mismatch")
	return errors

static func defense_errors(report: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var driver: Dictionary = report.get("defense_driver",{})
	if driver.get("version") != 2: errors.append("wall-aware defense driver evidence missing")
	var counts: Dictionary = {}
	for key: String in ["combat_replans","endpoint_route_attempts","occluded_decisions"]:
		var value: Variant = driver.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) != floorf(float(value)):
			errors.append("invalid finite defense work count: "+key)
			counts[key] = INF
		else: counts[key] = float(value)
	if counts.combat_replans > CombatDriver.COMBAT_MAX_REPLANS: errors.append("defense replan budget exceeded")
	if counts.endpoint_route_attempts > counts.combat_replans*CombatDriver.COMBAT_ROUTE_ATTEMPTS: errors.append("defense endpoint-route work budget exceeded")
	for attack: Dictionary in report.get("attack_receipts",[]):
		var geometry: Dictionary = attack.get("geometry",{})
		if str(geometry.get("target_id","")).is_empty() or not CombatDriver.combat_attack_ready(float(geometry.get("distance",NAN)),float(geometry.get("alignment",NAN)),float(geometry.get("cooldown",NAN)),float(geometry.get("stun",NAN)),geometry.get("can_hit") == true):
			errors.append("accepted defense click lacks current physical LOS/range/aim/cooldown evidence")
	return errors

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> bool:
	if not ok and label not in failures: failures.append(label); push_error(label)
	return ok
func _alive() -> bool:
	if not failures.is_empty(): return false
	if not _check(Time.get_ticks_msec()-began_wall < TOTAL_LIMIT,"whole tour watchdog"): return false
	if not phase_name.is_empty() and not _check(Time.get_ticks_msec()-phase_wall < int(PHASE_LIMITS[phase_name]),"phase watchdog: "+phase_name): return false
	if game.audit_enabled:
		if not _check(not game.overflow and game.runtime.s.mode != "ending" and not game.runtime.s.bossActive,"no overflow/unplanned boss/ending"): return false
		while checked_event_count < game.trace.size():
			var event: Dictionary = game.trace[checked_event_count]; checked_event_count += 1
			if event.kind in ["death","arrest","dependency_missing"]: return _check(false,"source event invalidates tour: "+str(event.kind)+" "+JSON.stringify(event.payload))
	return true
func _actor(id: String) -> Dictionary: return game.runtime.combat.actor(id)
func _center(body: Dictionary) -> Vector2: return Vector2(body.x+body.w*0.5,body.y+body.h*0.5)
func _summary() -> Dictionary:
	var p: Dictionary = game.runtime.p; var s: Dictionary = game.runtime.s
	return {"cash":p.cash,"copper":p.copper,"hp":p.hp,"max_hp":p.maxHp,"brain":p.brain,"shakes":p.shakes,"wanted":p.wanted,"cred":p.cred,"weapon":p.weapon,"equip":p.equip.duplicate(true),"inventory":p.inventory.duplicate(true),"speed":p.speed,"cart_mounted":p.cartMounted,"rocks":p.rocks,"offenses":p.tonyOffenses,"rocks_smoked":p.lifetime.rocksSmoked,"routes":p.lifetime.routesCompleted,"office_jobs":p.lifetime.officeJobs,"intro":s.flags.introDone,"office_available":s.quests.office_space.available,"paper_done":s.quests.paper_empire.done,"office":s.office.duplicate(true),"claims":s.districtClaims.duplicate(true),"route":s.blockRoute.duplicate(true) if s.blockRoute is Dictionary else {},"day":s.day,"day_time":s.dayTime,"high":p.rockedT,"crash":p.crashT,"charisma":p.charisma,"faction":p.faction.duplicate(true),"rng":game.runtime.state.rng_seed,"actors":game.runtime.state.npcs.size(),"source_position":game.runtime.state.player_center()}
func _phase(id: String) -> void:
	_release()
	if not phase_name.is_empty(): phases.append({"id":phase_name,"wall_ms":Time.get_ticks_msec()-phase_wall,"active_ms":game.admitted_ms-phase_active,"state":_summary()})
	phase_name = id; phase_wall = Time.get_ticks_msec(); phase_active = game.admitted_ms
func _finish_phase() -> void:
	if not phase_name.is_empty(): phases.append({"id":phase_name,"wall_ms":Time.get_ticks_msec()-phase_wall,"active_ms":game.admitted_ms-phase_active,"state":_summary()}); phase_name = ""
func _receipt(kind: String,before: Dictionary,event_start: int,extra: Dictionary = {}) -> Dictionary:
	var row := {"kind":kind,"before":before,"after":_summary(),"events":game.trace.slice(event_start).duplicate(true),"phase":phase_name,"wall_ms":Time.get_ticks_msec(),"active_ms":game.admitted_ms}
	row.merge(extra); receipts.append(row); return row
func _field_receipt(kind: String,id: String) -> Dictionary:
	var before: Dictionary = _summary(); var resolved: Dictionary = game.resolve_interaction()
	if not _check(interaction_matches(resolved,id),"actual field resolver: "+id): return {}
	var point: Vector2 = Content.to_source(game.world.service_points[id].target)
	var source_point: Variant = game.world.service_points[id].get("source_point")
	if source_point is Vector2: point = source_point
	var extra := {"service":id,"resolved":resolved.duplicate(true),"source_distance":game.runtime.state.player_center().distance_to(point),"reachable":game.physics.can_reach_target(id)}
	var event_start: int = game.trace.size(); _key(KEY_E)
	return _receipt(kind,before,event_start,extra)
func _button(prefix: String) -> Button:
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text.begins_with(prefix): return child
	return null
func _choose(prefix: String,kind: String = "menu") -> bool:
	_release(); await game.frame_sampled
	if not _alive(): return false
	var button: Button = _button(prefix)
	if not _check(button != null and not button.disabled,"normal menu option enabled: "+prefix): return false
	var index := 0
	for child: Node in game.hud.menu_box.get_children():
		if child == button: break
		if child is Button: index += 1
	var before: Dictionary = _summary(); var event_start: int = game.trace.size()
	if game.runtime.s.mode == "dialogue" and index <= 8: _key(KEY_1+index)
	else:
		for scroll in range(24):
			var clip: Rect2 = game.hud.menu_scroll.get_global_rect(); var rect: Rect2 = button.get_global_rect()
			if clip.has_point(rect.get_center()): break
			var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if rect.get_center().y > clip.end.y else MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true; wheel.position = clip.get_center(); root.push_input(wheel,true)
			await game.frame_sampled
		if not _check(game.hud.menu_scroll.get_global_rect().has_point(button.get_global_rect().get_center()),"normal menu button physically visible: "+prefix): return false
		before = _summary(); event_start = game.trace.size()
		var point: Vector2 = button.get_global_rect().get_center()
		var moved := InputEventMouseMotion.new(); moved.position = point; root.push_input(moved,true)
		var pressed := InputEventMouseButton.new(); pressed.button_index = MOUSE_BUTTON_LEFT; pressed.pressed = true; pressed.position = point; root.push_input(pressed,true)
		var released := InputEventMouseButton.new(); released.button_index = MOUSE_BUTTON_LEFT; released.pressed = false; released.position = point; root.push_input(released,true); inputs.menu_clicks += 1
	_receipt(kind,before,event_start,{"option":prefix,"index":index})
	return true
func _service_target(id: String) -> Vector3:
	var actor: Dictionary = _actor(id)
	if not actor.is_empty(): return Content.to_world(_center(actor),1.2)
	return game.world.service_points[id].target
func _open_target(id: String) -> bool:
	if not await _reach_service(id): return _check(false,"actual aimed service reachable: "+id)
	_key(KEY_E)
	return _check(game.runtime.s.mode == "dialogue","real E opens "+id)
func _visit(id: String,inter_stop: bool = false) -> bool:
	var began := Time.get_ticks_msec(); var active: float = game.admitted_ms; var start: Vector3 = game.player.position
	var target: Vector3 = game.world.service_points[id].approach
	var arrived: bool = await _walk_to(target,id)
	legs.append({"service":id,"from":start,"to":game.player.position,"inter_stop":inter_stop,"wall_ms":Time.get_ticks_msec()-began,"active_ms":game.admitted_ms-active,"arrived":arrived,"speed":game.runtime.p.speed,"high":game.runtime.p.rockedT,"crash":game.runtime.p.crashT})
	return arrived
func _buy_and_smoke(first: bool = false) -> bool:
	if game.runtime.p.rocks <= 0:
		if not _check(game.runtime.p.cash >= 250,"cash retains reserved240 Office outlay plus rock"): return false
		if not await _visit("tony") or not await _open_target("tony"): return false
		if not await _choose("buy a rock","buy_rock"): return false
	if not await _visit("smoke:block") or not await _open_target("smoke:block"): return false
	var previous: int = game.runtime.p.rocks; var smoked: int = game.runtime.p.lifetime.rocksSmoked
	if not await _choose("smoke a rock. (-1 rock","smoke"): return false
	if first:
		loop = {"purchased":previous == 1,"spent":game.runtime.p.rocks == 0,"initial_high":game.runtime.p.rockedT,"initial_smokes":game.runtime.p.lifetime.rocksSmoked-smoked}
		game.loop_start = game.admitted_ms
	return _check(game.runtime.p.rockedT == 18000,"real Block smoke starts exact high")
func _office_open() -> bool:
	if not await _visit("office"): return false
	return await _open_target("office")
func _recover_office() -> bool:
	var attempts := 0
	while game.runtime.p.hp < 80 and attempts < 8:
		if not _alive() or not _check(rest_count < 24,"finite normal cot recovery"): return false
		if game.runtime.s.mode == "playing" and not await _open_target("office"): return false
		if not await _choose("use the cot."): return false
		if not await _choose("rest 30 minutes.","rest"): return false
		attempts += 1; rest_count += 1
	if game.runtime.s.mode == "dialogue": return await _choose("leave the office.")
	return true
func _durable_brief(summary: Dictionary) -> Dictionary:
	var o: Dictionary = summary.office
	return {"cash":summary.cash,"copper":summary.copper,"routes":summary.routes,"officeJobs":summary.office_jobs,"claims":summary.claims.duplicate(true),"route":summary.route.duplicate(true),"owned":o.owned,"upgrades":o.upgrades.duplicate(true),"claimJob":o.claimJob,"workJob":o.workJob.duplicate(true) if o.workJob is Dictionary else null,"orderSerial":o.orderSerial,"jobsCompleted":o.jobsCompleted,"workToday":o.workToday,"day":summary.day,"weapon":summary.weapon,"paper_done":summary.paper_done}
func _save_load(label: String) -> bool:
	_release()
	if game.runtime.s.mode == "dialogue" and not await _choose("leave the office."): return false
	_key(KEY_ESCAPE)
	if not _check(game.runtime.s.mode == "paused","actual Escape opens pause for save"): return false
	if not await _choose("remember this.","save"): return false
	var start := Time.get_ticks_msec()
	while game.saving or not game.pending_save.is_empty():
		if not _alive() or not _check(Time.get_ticks_msec()-start < 10000,"await durable native save"): return false
		await game.frame_sampled
	var before: Dictionary = _durable_brief(_summary())
	var payload: String = FileAccess.get_file_as_string(game.store.save_path)
	var decoded: Variant = JSON.parse_string(payload)
	if not _check(decoded is Dictionary and decoded.get("schema") == 2,"actual isolated save is schema2"): return false
	var stored: Dictionary = _durable_brief({"cash":decoded.player.cash,"copper":decoded.player.copper,"routes":decoded.player.lifetime.routesCompleted,"office_jobs":decoded.player.lifetime.officeJobs,"claims":decoded.state.districtClaims,"route":decoded.state.blockRoute,"office":decoded.state.office,"day":decoded.state.day,"weapon":decoded.player.weapon,"paper_done":decoded.state.quests.paper_empire.done})
	if not _check(_same(before,stored),"actual durable file matches pending/payment state"): return false
	var evidence := FileAccess.open(output.path_join(label+"-save.json"),FileAccess.WRITE)
	if evidence == null: return _check(false,"earned save copy writable")
	evidence.store_string(payload); evidence.close()
	var epochs: int = game.replacements.size()
	if not await _choose("remember before.","load"): return false
	start = Time.get_ticks_msec()
	while game.loading or game.replacements.size() == epochs:
		if not _alive() or not _check(Time.get_ticks_msec()-start < 10000,"actual load completes"): return false
		await game.frame_sampled
	var after: Dictionary = _durable_brief(_summary())
	var saved := {"label":label,"file":label+"-save.json","sha256":payload.sha256_text(),"durable":not game.save_failed,"menu_loaded":game.runtime.s.mode == "paused" and _button("continue.") != null,"before":before,"stored":stored,"after":after,"epochs_before":epochs,"epochs_after":game.replacements.size()}
	saves.append(saved)
	if not _check(_same(before,after) and game.replacements.size() == epochs+1,"actual save/load retains exact durable pending/payment state"): return false
	await _capture(label+"_loaded")
	return await _choose("continue.","resume")
func _scenario() -> bool:
	if not await _choose("wake up."): return false
	if not _check(game.runtime.s.mode == "playing","title input started actual fresh game"): return false
	game.runtime.p.cash = 300
	game.runtime.p.copper = 6
	initial = _summary(); receipts.clear(); game.start_audit()
	for actor: Dictionary in game.runtime.state.npcs:
		if not actor.get("kingdomGuard",false): initial_actor_ids.append(str(actor.id))
	_phase("intro")
	if not await _buy_and_smoke(true): return false
	await _capture("01_actual_intro_smoke")
	while game.crash_end < 0:
		if not _alive(): return false
		if not await _defend_exit(): _release()
		await game.frame_sampled
	loop.high_ms = game.high_end-game.loop_start; loop.crash_ms = game.crash_end-game.high_end
	await _capture("02_same_loop_complete")
	_phase("routes")
	for sheet: int in range(3):
		if game.runtime.p.shakes >= 65 and not await _buy_and_smoke(): return false
		for stamp: int in range(3):
			var stop: Dictionary = game.runtime.progression.current_stop()
			if not _check(not stop.is_empty(),"source generated an active route stop"): return false
			var id := "route:"+str(stop.id)
			if not await _visit(id,stamp > 0): return false
			if not _check(interaction_matches(game.resolve_interaction(),id),"route resolver at actual destination"): return false
			var row: Dictionary = _field_receipt("stamp",id); route_receipts.append(row)
			if not _check(int(game.runtime.p.lifetime.routesCompleted) == sheet+(1 if stamp == 2 else 0),"source route completion count after actual E"): return false
		await _capture("03_route_%d_filed" % (sheet+1))
	if game.runtime.p.shakes >= 65 and not await _buy_and_smoke(): return false
	_phase("office_claim")
	if not await _visit("lease_guy") or not await _open_target("lease_guy"): return false
	if not await _choose("replace the lock.","lease"): return false
	if not await _office_open() or not await _choose("look at office upgrades."): return false
	for id: String in ["desk","radio","cot"]:
		if not await _choose(id+" ·",id): return false
	if not await _choose("back to the office."): return false
	await _capture("04_office_bought_and_equipped")
	if not await _choose("open district claims.") or not await _choose("THE DRAINAGE CANAL · open a survey file.","select_claim"): return false
	if not await _visit("claim:canal:survey"): return false
	_field_receipt("survey","claim:canal:survey")
	if not await _office_open() or not await _choose("file the drainage canal.","file_claim"): return false
	if not await _recover_office(): return false
	if not await _visit("claim:canal:sign"): return false
	_field_receipt("install","claim:canal:sign")
	await _capture("05_canal_sign_installed")
	_phase("work_restore")
	if not await _office_open() or not await _choose("take a work order.","work"): return false
	if not await _visit("claim:canal:sign"): return false
	_field_receipt("inspect","claim:canal:sign")
	if not await _office_open(): return false
	if not await _save_load("06_pending_work"): return false
	if not await _open_target("office") or not await _choose("file work order 1.","file_work"): return false
	var disabled: Button = _button("work orders closed today.")
	if not _check(disabled != null and disabled.disabled,"actual menu enforces first-claim one-order daily cap"): return false
	_receipt("disabled_cap",_summary(),game.trace.size(),{"disabled":true,"label":disabled.text})
	if not await _save_load("07_paid_work"): return false
	_phase("cot_day")
	if not await _open_target("office"): return false
	if not await _recover_office(): return false
	while game.runtime.s.dayTime <= 0.3:
		if not _alive(): return false
		await game.frame_sampled
	if not await _open_target("office") or not await _choose("use the cot."): return false
	if not await _choose("sleep until morning.","sleep"): return false
	if not await _open_target("office") or not await _choose("take a work order.","work_next"): return false
	await _capture("08_next_day_new_order")
	_key(KEY_ESCAPE)
	if not await _choose("remember this.","save"): return false
	var wait_started := Time.get_ticks_msec()
	while game.saving or not game.pending_save.is_empty():
		if not _alive() or not _check(Time.get_ticks_msec()-wait_started < 10000,"earned handoff save completes"): return false
		await game.frame_sampled
	_finish_phase(); return true
func _report() -> Dictionary:
	var deaths := 0; var arrests := 0; var bosses := 0; var dependencies: Array[String] = []
	for event: Dictionary in game.trace:
		if event.kind == "death": deaths += 1
		elif event.kind == "arrest": arrests += 1
		elif event.kind == "boss_started": bosses += 1
		elif event.kind == "dependency_missing": dependencies.append(JSON.stringify(event.payload))
	for id: String in initial_actor_ids:
		if _actor(id).is_empty(): preserved_ids = false
	return {"schema":1,"format":"rock-bottom-office-acceptance","fixture":{"kind":"fresh_resources_only","cash":300,"copper":6,"writes":2},"initial":initial,"final":_summary(),"loop":loop,"receipts":receipts,"route_receipts":route_receipts,"phases":phases,"legs":legs,"saves":saves,"attack_receipts":attack_receipts,"weapon_audit":weapon_chain(attack_receipts),"weapon_changes":game.weapon_changes,"events":game.trace,"samples":game.samples,"inputs":inputs,"captures":captures,"walking":walking,"walking_context":walking_context.duplicate(true),"service_aim_context":service_aim_context.duplicate(true),"rest_count":rest_count,"canonical_roster_retained":preserved_ids,"initial_actor_ids":initial_actor_ids,"epoch_replacements":game.replacements.size(),"epoch_events":game.replacements,"defense_driver":{"version":2,"combat_replans":combat_replans,"endpoint_route_attempts":combat_endpoint_attempts,"occluded_decisions":combat_occluded_decisions},"combat_navigation":combat_navigation,"combat_context":combat_context.duplicate(true),"overflow":game.overflow,"deaths":deaths,"arrests":arrests,"boss_starts":bosses,"dependencies":dependencies,"wall_ms":Time.get_ticks_msec()-began_wall,"active_ms":game.admitted_ms,"handoff_save":game.store.save_path,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"scope":"actual native input from fresh progression plus labeled300cash/6copper through3routes/Office/canal/work/persistence/cotday; not resource earning, other claims, Kingdom, Web or performance"}
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Office acceptance requires native rendering"); quit(1); return
	if "--qa-full" not in OS.get_cmdline_user_args(): push_error("Office acceptance requires --qa-full before FullScene startup; no scenario was started."); quit(1); return
	output = ProjectSettings.globalize_path("res://../.build/full-port/office-acceptance")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument == "--diagnostic": diagnostic = true
	DirAccess.make_dir_recursive_absolute(output); root.size = Vector2i(1280,720); Engine.max_fps = 60
	game = ObservedScene.new(); game.qa_mode = true; root.add_child(game)
	for frame: int in range(900):
		await process_frame
		if game.ready_for_play: break
	if not _check(game.ready_for_play,"native FullScene reached title"):
		var boot := FileAccess.open(output.path_join("office-tour.json"),FileAccess.WRITE)
		if boot != null: boot.store_string(JSON.stringify({"acceptance":false,"failures":failures,"phase":"cold_start"})); boot.close()
		await _shutdown(0 if diagnostic else 1); return
	game.qa_mode = true; game.store.save_path = output.path_join("earned-handoff.json"); game.store.storage_key = "rockbottom_3d_office_acceptance_qa"
	began_wall = Time.get_ticks_msec(); last_frame_wall = began_wall
	await _scenario(); _release()
	var report: Dictionary = _report()
	for error: String in assess(report): _check(false,error)
	if not failures.is_empty(): await _capture_failure(); report.failure_context = failure_context
	report.acceptance = failures.is_empty(); report.failures = failures; report.diagnostic = diagnostic; report.captures = captures
	var file := FileAccess.open(output.path_join("office-tour.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
	else: _check(false,"native report writable")
	print("3D OFFICE TOUR ACCEPTANCE: ","PASS" if failures.is_empty() else "FAIL","; phases=",phases.size()," wall_ms=",report.wall_ms,"; ",output)
	await _shutdown(0 if failures.is_empty() or diagnostic else 1)

static func encode_motion(desired: Vector2) -> Vector2:
	var length: float = minf(desired.length(),1.0)
	if length <= 0.000001: return Vector2.ZERO
	# Input.get_vector removes one circular deadzone, not a deadzone per axis.
	return desired.normalized()*(0.5+0.5*length)

func _release() -> void:
	for action: String in ["forward","back","left","right","sprint"]: Input.action_release(action)

func _motion(world_vector: Vector2) -> void:
	_release()
	last_requested_motion = Vector2.ZERO; last_actual_input = Vector2.ZERO
	if world_vector.length_squared() < 0.000001: return
	var local: Vector3 = game.player.global_basis.inverse()*Vector3(world_vector.x,0,world_vector.y)
	var plane := Vector2(local.x,local.z).limit_length(1.0)
	var raw: Vector2 = encode_motion(plane)
	if absf(raw.x) > 0.000001: Input.action_press("right" if raw.x > 0 else "left",absf(raw.x))
	if absf(raw.y) > 0.000001: Input.action_press("back" if raw.y > 0 else "forward",absf(raw.y))
	last_requested_motion = plane; last_actual_input = Input.get_vector("left","right","forward","back")
	inputs.motion_frames += 1

func _aim(target: Vector3,dt: float) -> float:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and game.runtime.s.mode == "playing":
		# qa_mode keeps look released after menus. Use the actual native click-to-
		# capture branch, whose first click deliberately does not request an attack.
		var capture := InputEventMouseButton.new(); capture.button_index = MOUSE_BUTTON_LEFT; capture.pressed = true
		game._unhandled_input(capture); inputs.capture_clicks += 1
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return -1.0
	var to: Vector3 = target-game.camera.global_position
	var desired := Vector2(to.x,to.z)
	var forward3: Vector3 = -game.camera.global_basis.z
	var forward := Vector2(forward3.x,forward3.z)
	if desired.length_squared() < 0.000001: return 1.0
	var yaw: float = clampf(forward.angle_to(desired),-4.5*dt,4.5*dt)
	var pitch: float = clampf(atan2(to.y,desired.length()),-1.1,1.1)
	var pitch_step: float = clampf(pitch-game.pitch,-3.0*dt,3.0*dt)
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(yaw/0.0022,-pitch_step/0.0022)
	game._unhandled_input(event); inputs.mouse_motion += 1
	forward3 = -game.camera.global_basis.z
	return Vector2(forward3.x,forward3.z).normalized().dot(desired.normalized())

func _dt() -> float:
	var now: int = Time.get_ticks_msec()
	var delta: float = clampf(float(now-last_frame_wall)/1000.0,0.001,0.1)
	last_frame_wall = now; return delta

func _key(code: int) -> void:
	var event := InputEventKey.new(); event.pressed = true; event.physical_keycode = code
	game._unhandled_input(event); inputs.keys += 1

func _capture(label: String) -> void:
	await game.frame_sampled; await RenderingServer.frame_post_draw
	if _check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label): captures.append(label)

func _capture_failure() -> void:
	var nearby: Array[Dictionary] = []
	for peer: Dictionary in game.physics._contact_peers(game.runtime.p):
		if _center(peer).distance_to(game.runtime.state.player_center()) <= 200.0: nearby.append(peer.duplicate(true))
	failure_context = {"world_position":game.player.position,"source_center":game.runtime.state.player_center(),"mode":game.runtime.s.mode,"hp":game.runtime.p.hp,"nearby":nearby,"walks":walking.duplicate(true),"walking_goal":walking_goal,"walking_context":walking_context.duplicate(true),"service_aim_context":service_aim_context.duplicate(true),"requested_motion":last_requested_motion,"actual_input":last_actual_input,"mouse_captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"combat":combat_context.duplicate(true),"combat_replans":combat_replans}
	print("OFFICE PROBE FAILURE CONTEXT: ",JSON.stringify(failure_context))
	# Freeze only an already-failed scenario; unwind frame_sampled before readback.
	game.set_process(false)
	await process_frame; await RenderingServer.frame_post_draw
	if _check(root.get_texture().get_image().save_png(output.path_join("failure.png")) == OK,"failed scenario capture"): captures.append("failure")

func _shutdown(code: int) -> void:
	_release()
	if is_instance_valid(game): game.set_process(false); game.queue_free()
	await process_frame
	quit(code)

func _probe_body(point: Vector3) -> Dictionary:
	var half := Vector2(game.runtime.p.w,game.runtime.p.h)*0.5
	var origin: Vector2 = Content.to_source(point)-half
	return {"id":"player","x":origin.x,"y":origin.y,"w":game.runtime.p.w,"h":game.runtime.p.h}

static func walking_corner_candidates(from: Vector3,to: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not from.is_finite() or not to.is_finite(): return result
	var heading: float = atan2(to.z-from.z,to.x-from.x)
	var ordered: Array[Dictionary] = []
	for radius: float in [0.25,0.5,1.0]:
		for offset: float in [0.0,PI*0.25,-PI*0.25,PI*0.5,-PI*0.5,PI*0.75,-PI*0.75,PI]:
			var point: Vector3 = from+Vector3(cos(heading+offset)*radius,0,sin(heading+offset)*radius)
			ordered.append({"point":point,"distance":point.distance_squared_to(to),"order":ordered.size()})
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.order < b.order if a.distance == b.distance else a.distance < b.distance)
	for entry: Dictionary in ordered: result.append(entry.point)
	return result

func _walking_body(from: Vector3) -> Dictionary:
	# The current origin comes directly from the model, never a rounded world copy.
	if from == game.player.position:
		return {"id":"player","x":game.runtime.p.x,"y":game.runtime.p.y,"w":game.runtime.p.w,"h":game.runtime.p.h}
	return _probe_body(from)

func _walking_query(body: Dictionary,goal: Vector2) -> Dictionary:
	var moved: Dictionary = game.physics.move_body(body,goal)
	var reached: Vector2 = moved.get("position",Vector2.INF)
	var reason := ""
	if moved.get("blocked",true): reason = "static_short_step_blocked"
	elif moved.get("body_contact",false): reason = "live_peer_contact"
	elif not reached.is_finite() or reached.distance_to(goal) >= 0.005: reason = "short_endpoint_not_reached"
	return {"ok":reason.is_empty(),"reason":reason,"from":Vector2(body.x,body.y),"to":goal,"actual_end":reached}

func _walking_step(point: Vector3) -> Dictionary:
	var body: Dictionary = _walking_body(game.player.position)
	var origin := Vector2(body.x,body.y)
	var destination: Vector2 = Content.to_source(point)-Vector2(body.w,body.h)*0.5
	var goal: Vector2 = origin+(destination-origin).limit_length(WALK_LOCAL_STEP/0.04)
	return _walking_query(body,goal)

func _walking_local_link(from: Vector3,to: Vector3) -> Dictionary:
	var distance: float = from.distance_to(to)
	if not from.is_finite() or not to.is_finite() or distance > 1.00001:
		return {"ok":false,"reason":"local_link_bounds","steps":0}
	var steps: int = maxi(1,int(ceil(distance/WALK_LOCAL_STEP)))
	if steps > WALK_LOCAL_MAX_STEPS: return {"ok":false,"reason":"local_step_cap","steps":0}
	var body: Dictionary = _walking_body(from)
	var origin := Vector2(body.x,body.y)
	var destination: Vector2 = Content.to_source(to)-Vector2(body.w,body.h)*0.5
	for index: int in range(1,steps+1):
		var goal: Vector2 = origin.lerp(destination,float(index)/float(steps))
		var checked: Dictionary = _walking_query(body,goal)
		if not checked.ok: checked.steps = index; return checked
		# Detached query state only. This never writes the authoritative player.
		body.x = checked.actual_end.x; body.y = checked.actual_end.y
	return {"ok":true,"reason":"local_steps_clear","steps":steps,"from":from,"to":to}

func _walking_detour(from: Vector3,to: Vector3) -> PackedVector3Array:
	var attempts: Array[Dictionary] = []
	var tails := 0; var total_steps := 0
	walking_local_context = {"reason":"no_certified_local_join","from":from,"goal":to,"candidates":attempts,"tail_attempts":0,"steps":0}
	for candidate: Vector3 in walking_corner_candidates(from,to):
		if not game.world.is_clear_position(candidate):
			attempts.append({"point":candidate,"reason":"world_endpoint_blocked","steps":0}); continue
		var link: Dictionary = _walking_local_link(from,candidate)
		total_steps += int(link.steps)
		attempts.append({"point":candidate,"reason":link.reason,"steps":link.steps})
		if not link.ok: continue
		tails += 1
		var tail: PackedVector3Array = _resident_route(candidate,to)
		if tail.size() >= 2:
			var joined := PackedVector3Array([from,candidate])
			for index: int in range(1,tail.size()): joined.append(tail[index])
			walking_local_context.merge({"reason":"certified_outward_join","selected":candidate,"tail_attempts":tails,"steps":total_steps},true)
			if walking.size() < 128: walking.append({"wall_ms":_walk_clock(),"reason":"certified_outward_join","details":walking_local_context.duplicate(true)})
			return joined
		if tails >= WALK_LOCAL_TAILS: break
	walking_local_context.merge({"tail_attempts":tails,"steps":total_steps},true)
	return PackedVector3Array()

func _static_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	var direct: PackedVector3Array = game.world.find_route(from,to)
	if not direct.is_empty() or game.world.is_clear_position(from) or not game.world.is_clear_position(to): return direct
	var body: Dictionary = _walking_body(from)
	if not game.physics._clear(body,Vector2(body.x,body.y),false): return direct
	var tails := 0
	for candidate: Vector3 in walking_corner_candidates(from,to):
		if not game.world.is_clear_position(candidate): continue
		var link: Dictionary = _walking_local_link(from,candidate)
		if not link.ok: continue
		tails += 1
		var tail: PackedVector3Array = game.world.find_route(candidate,to)
		if tail.size() >= 2:
			var joined := PackedVector3Array([from,candidate])
			for index: int in range(1,tail.size()): joined.append(tail[index])
			if walking.size() < 128: walking.append({"wall_ms":_walk_clock(),"reason":"actual_capsule_corner_link","from":from,"joined_at":candidate,"steps":link.steps,"tail_attempts":tails})
			return joined
		if tails >= WALK_LOCAL_TAILS: break
	return direct

func _resident_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	resident_route_context = {"reason":"planning","from":from,"to":to}
	var base: PackedVector3Array = _static_route(from,to)
	if base.size() < 2:
		if walking.size() < 128: walking.append({"wall_ms":Time.get_ticks_msec(),"reason":"static_route_unavailable","from":from,"to":to,"metrics":game.world.last_route_metrics.duplicate(true)})
		resident_route_context.reason = "static_route_unavailable"
		return base
	var peers: Array[Dictionary] = game.physics._contact_peers(game.runtime.p)
	var blockers: Array[String] = []
	for index: int in range(1,base.size()):
		var body: Dictionary = _probe_body(base[index-1])
		var origin := Vector2(body.x,body.y)
		var destination: Dictionary = _probe_body(base[index])
		for peer: Dictionary in peers:
			var one: Array[Dictionary] = [peer]
			if not Contact.first_hit(body,origin,Vector2(destination.x,destination.y)-origin,one).is_empty() and str(peer.id) not in blockers: blockers.append(str(peer.id))
	if blockers.is_empty():
		resident_route_context.reason = "static_route_has_no_peer_blocker"
		return base
	var points: Array[Vector3] = [from,to]
	for point: Vector3 in base:
		if point not in points: points.append(point)
	var half := Vector2(game.runtime.p.w,game.runtime.p.h)*0.5
	for peer: Dictionary in peers:
		var center := Vector2(peer.x+peer.w*0.5,peer.y+peer.h*0.5)
		var at: Vector3 = Content.to_world(center,from.y)
		var nearby := false
		for index: int in range(1,base.size()):
			if Geometry3D.get_closest_point_to_segment(at,base[index-1],base[index]).distance_to(at) < 3.0: nearby = true; break
		if not nearby: continue
		var extent: Vector2 = half+Vector2(peer.w,peer.h)*0.5+Vector2(6,6)
		for sign_x: float in [-1,1]:
			for sign_y: float in [-1,1]:
				var candidate: Vector3 = Content.to_world(center+extent*Vector2(sign_x,sign_y),from.y)
				if candidate not in points: points.append(candidate)
		if points.size() > 80:
			resident_route_context.merge({"reason":"resident_graph_cap","graph_points":points.size(),"blockers":blockers},true)
			return PackedVector3Array()
	var graph := AStar2D.new()
	for index: int in range(points.size()):
		var body: Dictionary = _probe_body(points[index]); var origin := Vector2(body.x,body.y)
		if game.physics._clear(body,origin,false) and game.physics._peer_clear(body,origin,peers): graph.add_point(index,Vector2(points[index].x,points[index].z))
	if not graph.has_point(0) or not graph.has_point(1):
		resident_route_context.merge({"reason":"resident_graph_endpoint_blocked","start_clear":graph.has_point(0),"goal_clear":graph.has_point(1),"blockers":blockers,"graph_points":points.size()},true)
		return PackedVector3Array()
	for a: int in range(points.size()):
		if not graph.has_point(a): continue
		var body: Dictionary = _probe_body(points[a])
		for b: int in range(a+1,points.size()):
			if not graph.has_point(b): continue
			var destination: Dictionary = _probe_body(points[b]); var goal := Vector2(destination.x,destination.y)
			# A detached query body never commits this candidate movement to the model.
			var moved: Dictionary = game.physics.move_body(body,goal)
			if not moved.blocked and not moved.get("body_contact",false) and moved.position.distance_to(goal) < 0.005: graph.connect_points(a,b)
	var result := PackedVector3Array()
	for index: int in graph.get_id_path(0,1): result.append(points[index])
	resident_route_context.merge({"reason":"resident_graph_disconnected" if result.size() < 2 else "resident_detour_ready","blockers":blockers,"graph_points":points.size(),"route_points":result.size()},true)
	if walking.size() < 128: walking.append({"wall_ms":Time.get_ticks_msec(),"blockers":blockers,"graph_points":points.size(),"route_points":result.size()})
	return result

func _resident_ahead(point: Vector3) -> bool:
	var body: Dictionary = game.runtime.p
	var origin := Vector2(body.x,body.y)
	var goal: Vector2 = Content.to_source(point)-Vector2(body.w,body.h)*0.5
	var motion: Vector2 = (goal-origin).limit_length(75.0)
	return not Contact.first_hit(body,origin,motion,game.physics._contact_peers(body)).is_empty()

static func npc_service_range(player_center: Vector2,actor: Dictionary) -> bool:
	if actor.is_empty() or actor.get("dead",false) or not player_center.is_finite(): return false
	for key: String in ["x","y","w","h"]:
		if not (actor.get(key) is int or actor.get(key) is float) or not is_finite(float(actor[key])): return false
	var center := Vector2(float(actor.x)+float(actor.w)*0.5,float(actor.y)+float(actor.h)*0.5)
	return center.is_finite() and player_center.distance_squared_to(center) < 3600.0

func _service_candidate(id: String) -> bool:
	if id.is_empty(): return false
	if id == "smoke:block": return game.runtime.memory._zone_contains("block",game.runtime.state.player_center()) and game.physics.can_use_zone("block")
	var actor: Dictionary = _actor(id)
	if not actor.is_empty() and not npc_service_range(game.runtime.state.player_center(),actor): return false
	return game.physics.can_reach_target(id)

func _service_frame() -> void: await game.frame_sampled

func _reach_service(id: String) -> bool:
	if not _service_candidate(id): return false
	if interaction_matches(game.resolve_interaction(),id): service_aim_wait.clear(); return true
	var focus: Vector3 = _service_target(id)
	if not service_aim_wait.is_empty() and service_aim_wait.id == id and is_same(service_aim_wait.player_epoch,game.runtime.p) and is_same(service_aim_wait.state_epoch,game.runtime.s) and int(service_aim_wait.revision) == game.physics._collision_revision and game.player.position.distance_to(service_aim_wait.position) < 0.25 and focus.distance_to(service_aim_wait.focus) < 0.25:
		return false
	_release()
	var resolved: Dictionary = {}
	for frame: int in range(120):
		if not _alive() or game.runtime.s.mode != "playing" or not _service_candidate(id): return false
		_aim(_service_target(id),_dt())
		resolved = game.resolve_interaction()
		if interaction_matches(resolved,id): service_aim_wait.clear(); return true
		await _service_frame()
	service_aim_wait = {"id":id,"position":game.player.position,"focus":_service_target(id),"revision":game.physics._collision_revision,"player_epoch":game.runtime.p,"state_epoch":game.runtime.s}
	service_aim_context = {"reason":"intended_action_not_resolved_after120frames","id":id,"resolved":resolved.duplicate(true),"position":game.player.position,"target":_service_target(id)}
	return false

func _defend_exit() -> bool:
	_release(); motion = Vector2.ZERO; combat_plan.clear(); combat_context.clear(); decision_wall = -1000
	var target: Dictionary = {}; var distance := 65.0
	for actor: Dictionary in game.runtime.state.npcs:
		if actor.get("dead",false) or not actor.get("hostile",false) or actor.id == "tony": continue
		var gap: float = _center(actor).distance_to(game.runtime.state.player_center())
		if gap < distance: target = actor; distance = gap
	if target.is_empty(): return false
	var started: int = Time.get_ticks_msec()
	while _alive() and game.runtime.s.mode == "playing" and Time.get_ticks_msec()-started < 10000:
		if target.get("dead",false) or _center(target).distance_to(game.runtime.state.player_center()) > 85.0:
			return _finish_defense(target,started,"target_dead" if target.get("dead",false) else "target_left_range")
		_combat_input(target); await game.frame_sampled
	return _finish_defense(target,started,"certified_route_or_tour_failed" if not failures.is_empty() else ("mode_changed" if game.runtime.s.mode != "playing" else "bounded_attempt_finished"))

func _finish_defense(target: Dictionary,started: int,result: String) -> bool:
	_release(); motion = Vector2.ZERO; combat_plan.clear()
	walking.append({"defended_against":target.id,"wall_ms":Time.get_ticks_msec()-started,"dead":target.get("dead",false),"result":result,"actual_position":game.player.position,"combat":combat_context.duplicate(true)})
	return failures.is_empty() # Ordinary bounded attempts still require a fresh walking route.

# Clock/frame seams are overridden only by detached orchestration contract tests.
func _walk_clock() -> int: return Time.get_ticks_msec()
func _walk_frame() -> void: await game.frame_sampled

func _walk_to(target: Vector3,service_id: String = "") -> bool:
	service_aim_wait.clear()
	walking_local_context.clear()
	var leg_started: int = _walk_clock()
	var progressed_at: int = leg_started
	var last_position: Vector3 = game.player.position
	var route := PackedVector3Array()
	var index := 0; var replans := 0; var plans := 0
	var last_plan := -1000000; var last_check := -1000000
	var local_needed := false; var motion_attempt_at := -1
	while true:
		var now: int = _walk_clock()
		if game.player.position.distance_to(last_position) > 0.025:
			last_position = game.player.position; progressed_at = now
		walking_context = {"reason":"following_route" if not route.is_empty() else "waiting_for_resident_route","from":game.player.position,"goal":target,"replans":replans,"plans":plans,"elapsed_ms":now-leg_started,"no_progress_ms":now-progressed_at,"route":resident_route_context.duplicate(true),"local":walking_local_context.duplicate(true)}
		if not _alive() or now-progressed_at > 20000 or now-leg_started >= 120000:
			_release(); return _check(false,"actual controller walking stalled at "+str(game.player.position)+" toward "+str(target))
		if game.runtime.s.mode != "playing":
			_release(); return _check(false,"unexpected modal during real approach: "+str(game.runtime.s.mode))
		if await _reach_service(service_id):
			_release()
			return _check(_walk_clock()-leg_started < 120000 and _walk_clock()-progressed_at <= 20000,"actual service resolution retains walking watchdogs")
		now = _walk_clock()
		if Vector2(game.player.position.x-target.x,game.player.position.z-target.z).length() <= 0.085:
			_release(); return true
		while index < route.size() and Vector2(game.player.position.x-route[index].x,game.player.position.z-route[index].z).length() <= 0.085: index += 1
		if index >= route.size(): route.clear()
		if not route.is_empty() and motion_attempt_at >= 0 and now-progressed_at >= 500 and now-motion_attempt_at >= 500:
			walking_context.reason = "actual500ms_stagnation"
			if walking.size() < 128: walking.append({"wall_ms":now,"reason":"actual500ms_stagnation","from":game.player.position,"waypoint":route[index],"goal":target,"replans":replans})
			local_needed = true; route.clear(); motion_attempt_at = -1; _release()
		if not route.is_empty() and now-last_check >= 250:
			last_check = now
			var segment: Dictionary = _combat_segment(game.player.position,route[index])
			walking_context.segment = segment
			if not segment.get("ok",false):
				walking_context.reason = "cached_walking_segment_blocked"; route.clear(); _release()
		if route.is_empty():
			_release()
			if now-last_plan >= 750:
				if plans > 0:
					if not _check(replans < 32,"bounded live-resident approach replans"): return false
					replans += 1
				plans += 1; last_plan = now; motion_attempt_at = -1
				route = _walking_detour(game.player.position,target) if local_needed else _resident_route(game.player.position,target)
				if not route.is_empty(): local_needed = false
				walking_context.merge({"replans":replans,"plans":plans,"route":resident_route_context.duplicate(true)},true)
				index = 1; last_check = now
				if route.size() < 2:
					route.clear(); walking_context.reason = "resident_route_unavailable_retry"
					# Real defense may move the controller. Retain timers/budget and replan
					# from its actual endpoint on the next permitted opportunity.
					if await _defend_exit(): walking_context.reason = "defense_invalidated_walking_route"
				else:
					var segment: Dictionary = _combat_segment(game.player.position,route[index])
					walking_context.segment = segment
					if not segment.get("ok",false):
						route.clear(); walking_context.reason = "new_walking_segment_blocked"
			if route.is_empty():
				walking_goal = Vector3.INF
				await _walk_frame(); continue
		var point: Vector3 = route[index]
		walking_goal = point
		var delta := Vector2(point.x-game.player.position.x,point.z-game.player.position.z)
		var aligned: float = _aim(Vector3(point.x,game.camera.global_position.y,point.z),_dt())
		if aligned > 0.96:
			var step: Dictionary = _walking_step(point)
			walking_context.short_step = step
			if not step.get("ok",false):
				walking_context.reason = "actual_short_step_refused"
				if walking.size() < 128: walking.append({"wall_ms":now,"reason":"actual_short_step_refused","query":step.duplicate(true),"waypoint":point,"goal":target,"replans":replans})
				local_needed = true; route.clear(); motion_attempt_at = -1; _release()
				await _walk_frame(); continue
			if motion_attempt_at < 0: motion_attempt_at = now
			_motion(delta.normalized()*minf(1.0,delta.length()/0.4))
		else: _motion(Vector2.ZERO)
		await _walk_frame()
	return false

func _send_attack(geometry: Dictionary) -> void:
	var before: Dictionary = {}
	for actor: Dictionary in game.runtime.state.npcs:
		before[str(actor.id)] = {"hp":actor.get("hp",0),"dead":actor.get("dead",false),"ordinary_reward":not actor.get("essential",false) and not actor.get("kingdomGuard",false) and not actor.get("kingdomAdd",false) and not game.runtime.combat._special_death(actor)}
	var row := {"wall_ms":Time.get_ticks_msec(),"active_ms":game.admitted_ms,"before_weapon":game.runtime.p.weapon,"before_cd":game.runtime.p.attackCd,"boss_before":game.runtime.s.bossActive and game.runtime.s.bossKind == "tony","quest_before":game.runtime.s.quests.fallen_king.done,"actors_before":{},"actors_after":{}}
	row.geometry = geometry.duplicate(true)
	var event_start: int = game.trace.size()
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	game._unhandled_input(event); inputs.clicks += 1
	row.events = game.trace.slice(event_start).duplicate(true)
	var accepted := false
	for observed: Dictionary in row.events:
		if observed.kind == "player_attack": accepted = true
		if observed.kind not in ["actor_hit","actor_died"]: continue
		var id: String = str(observed.payload.get("actor_id","")); var actual: Dictionary = _actor(id)
		row.actors_before[id] = before.get(id,{}).duplicate(true)
		row.actors_after[id] = {"hp":actual.get("hp",1),"dead":actual.get("dead",false)}
	if not accepted: return
	row.after_weapon = game.runtime.p.weapon; row.after_cd = game.runtime.p.attackCd
	row.victory_after = _actor("tony").get("dead",false) and game.runtime.s.quests.fallen_king.done and not game.runtime.s.bossActive and game.runtime.s.bossKind == ""
	attack_receipts.append(row)

func _combat_segment(from: Vector3,to: Vector3) -> Dictionary:
	var body: Dictionary = _probe_body(from)
	var destination: Dictionary = _probe_body(to)
	var goal := Vector2(destination.x,destination.y)
	# A detached body performs the same sweep/contact query, never a model write.
	var moved: Dictionary = game.physics.move_body(body,goal)
	var reached: Vector2 = moved.get("position",Vector2.INF)
	var reason := ""
	if moved.get("blocked",true): reason = "static_sweep_blocked"
	elif moved.get("body_contact",false): reason = "live_peer_contact"
	elif not reached.is_finite() or reached.distance_to(goal) >= 0.005: reason = "sweep_endpoint_not_reached"
	return {"ok":reason.is_empty(),"reason":reason,"from":Content.to_source(from),"to":Content.to_source(to),"actual_end":reached+Vector2(body.w,body.h)*0.5}
func _combat_endpoint(point: Vector3,target: Dictionary,peers: Array[Dictionary]) -> bool:
	var center: Vector2 = Content.to_source(point)
	if center.distance_to(_center(target)) >= 57.0: return false
	var body: Dictionary = _probe_body(point); var origin := Vector2(body.x,body.y)
	return game.physics._clear(body,origin,false) and game.physics._peer_clear(body,origin,peers) and game.physics.can_hit(center,_center(target),"player",str(target.id))
func _combat_blocker(target: Dictionary) -> Dictionary:
	var hit: Dictionary = game.physics._ray(Content.to_world(game.runtime.state.player_center(),game.physics.FEET+game.physics._height("player")*0.6),Content.to_world(_center(target),game.physics.FEET+game.physics._height(str(target.id))*0.6))
	if hit.is_empty(): return {}
	var collider: Object = hit.get("collider")
	return {"owner":str(collider.get_meta("source_owner","")) if is_instance_valid(collider) else "","position":hit.get("position"),"normal":hit.get("normal")}
func _plan_combat_route(target: Dictionary,reason: String) -> bool:
	if not _check(combat_replans < CombatDriver.COMBAT_MAX_REPLANS,"bounded combat replans remain below32"): return false
	combat_replans += 1; combat_last_plan = Time.get_ticks_msec(); combat_plan = {}
	var started: int = Time.get_ticks_msec()
	var origin: Vector3 = game.player.position
	var peers: Array[Dictionary] = game.physics._contact_peers(game.runtime.p)
	var attempts := 0; var certified := 0
	for center: Vector2 in CombatDriver.melee_ring(game.runtime.state.player_center(),_center(target)):
		var point: Vector3 = Content.to_world(center,origin.y)
		if not _combat_endpoint(point,target,peers) or not game.world.is_clear_position(point): continue
		certified += 1; attempts += 1; combat_endpoint_attempts += 1
		var route: PackedVector3Array = _resident_route(origin,point)
		if route.size() >= 2:
			combat_plan = {"target_id":str(target.id),"target_center":_center(target),"phase":int(game.runtime.s.bossPhase),"revision":int(game.physics._collision_revision),"endpoint":point,"route":route,"index":1}
			combat_navigation.append({"wall_ms":started,"active_ms":game.admitted_ms,"reason":reason,"target_id":target.id,"target_center":_center(target),"from":Content.to_source(origin),"endpoint":center,"route":route,"attempts":attempts,"planner_ms":Time.get_ticks_msec()-started,"replan":combat_replans})
			return true
		if attempts >= CombatDriver.COMBAT_ROUTE_ATTEMPTS: break
	combat_navigation.append({"wall_ms":started,"active_ms":game.admitted_ms,"reason":"route_unavailable","trigger":reason,"target_id":target.id,"target_center":_center(target),"from":Content.to_source(origin),"certified_endpoints":certified,"attempts":attempts,"planner_ms":Time.get_ticks_msec()-started,"replan":combat_replans,"retryable":combat_replans < CombatDriver.COMBAT_MAX_REPLANS,"next_plan_ms":combat_last_plan+CombatDriver.COMBAT_REPLAN_MS})
	# Live peers can close every current route without ending a lawful defense.
	# This spent plan stays counted; steering holds until the same bounded retry.
	combat_context.reason = "route_unavailable"
	combat_context.next_plan_ms = combat_last_plan+CombatDriver.COMBAT_REPLAN_MS
	return false
func _combat_steering(target: Dictionary,now: int,line_clear: bool) -> Vector2:
	var center: Vector2 = game.runtime.state.player_center()
	var target_center: Vector2 = _center(target)
	var delta: Vector2 = target_center-center; var distance: float = delta.length()
	var toward: Vector2 = delta.normalized() if distance > 0.001 else Vector2.RIGHT
	var desired: Vector2 = toward*clampf((distance-45.0)/16.0,-1.0,1.0) if distance < 40.0 or distance > 50.0 else Vector2.ZERO
	var dodging: bool = line_clear and target.get("chargeState","") in ["windup","lunge"]
	if dodging:
		desired = (Vector2(-toward.y,toward.x)*0.75-toward*(0.35 if distance < 45.0 else 0.0)).limit_length(1.0)
	var goal: Vector2 = target_center-toward*44.0 if distance > 50.0 and not dodging else center+desired*20.0
	var direct: Dictionary = _combat_segment(game.player.position,Content.to_world(goal,game.player.position.y))
	combat_context = {"wall_ms":now,"active_ms":game.admitted_ms,"target_id":target.id,"target_center":target_center,"player_center":center,"distance":distance,"can_hit":line_clear,"phase":game.runtime.s.bossPhase,"revision":game.physics._collision_revision,"direct_segment":direct}
	if line_clear and (direct.ok or distance <= 50.0):
		if not combat_plan.is_empty():
			combat_navigation.append({"wall_ms":now,"active_ms":game.admitted_ms,"reason":"direct_melee_reacquired","target_id":target.id,"target_center":target_center,"from":center})
		combat_plan = {}
		combat_context.reason = "direct_melee" if direct.ok else "blocked_retreat_or_dodge"
		return desired if direct.ok else Vector2.ZERO
	if not line_clear:
		combat_occluded_decisions += 1
		combat_context.line_blocker = _combat_blocker(target)
	var peers: Array[Dictionary] = game.physics._contact_peers(game.runtime.p)
	var endpoint_clear := false; var next_clear := false
	var segment: Dictionary = {}
	if not combat_plan.is_empty():
		var route: PackedVector3Array = combat_plan.route
		while int(combat_plan.index) < route.size() and game.player.position.distance_to(route[int(combat_plan.index)]) <= 0.085:
			combat_plan.index += 1
		endpoint_clear = _combat_endpoint(combat_plan.endpoint,target,peers)
		if int(combat_plan.index) < route.size():
			segment = _combat_segment(game.player.position,route[int(combat_plan.index)])
			next_clear = segment.ok
	var reason: String = CombatDriver.combat_route_reason(combat_plan,str(target.id),target_center,int(game.runtime.s.bossPhase),int(game.physics._collision_revision),endpoint_clear,next_clear)
	if not reason.is_empty():
		combat_context.reason = reason; combat_context.current_segment = segment
		combat_plan = {} # Never follow an invalidated route while awaiting a retry.
		if not _check(combat_replans < CombatDriver.COMBAT_MAX_REPLANS,"bounded combat replans remain below32"): return Vector2.ZERO
		if not CombatDriver.combat_replan_ready(now,combat_last_plan,combat_replans):
			combat_context.reason = "waiting_for_replan_budget"
			combat_context.waiting_for_replan_budget = true
			combat_context.next_plan_ms = combat_last_plan+CombatDriver.COMBAT_REPLAN_MS
			return Vector2.ZERO
		if not _plan_combat_route(target,reason):
			combat_context.waiting_for_replan_budget = true
			_check(combat_replans < CombatDriver.COMBAT_MAX_REPLANS,"bounded combat replans remain below32")
			return Vector2.ZERO
	var points: PackedVector3Array = combat_plan.route
	var point: Vector3 = points[int(combat_plan.index)]
	segment = _combat_segment(game.player.position,point)
	combat_context.reason = "following_melee_route"; combat_context.endpoint = Content.to_source(combat_plan.endpoint)
	combat_context.current_segment = segment; combat_context.route_index = combat_plan.index
	if not segment.ok: combat_context.reason = "new_route_segment_blocked"; return Vector2.ZERO
	var direction := Vector2(point.x-game.player.position.x,point.z-game.player.position.z)
	return direction.normalized()*minf(1.0,direction.length()/0.4)
func _combat_route_motion() -> Vector2:
	# Steering converges each render frame; only costly route decisions use100ms.
	# Otherwise high-speed movement can overshoot a short corner between decisions.
	var route: PackedVector3Array = combat_plan.route
	while int(combat_plan.index) < route.size() and game.player.position.distance_to(route[int(combat_plan.index)]) <= 0.085:
		combat_plan.index += 1
	if int(combat_plan.index) >= route.size(): return Vector2.ZERO
	var point: Vector3 = route[int(combat_plan.index)]
	combat_context.current_input_segment = {"from":Content.to_source(game.player.position),"to":Content.to_source(point)}
	var direction := Vector2(point.x-game.player.position.x,point.z-game.player.position.z)
	return direction.normalized()*minf(1.0,direction.length()/0.4)

func _combat_input(preferred: Dictionary = {}) -> void:
	var target: Dictionary = preferred
	if target.is_empty(): _release(); return
	var delta: Vector2 = _center(target)-game.runtime.state.player_center()
	var distance: float = delta.length()
	var aligned: float = _aim(Content.to_world(_center(target),1.35),_dt())
	var now: int = Time.get_ticks_msec()
	var line_clear: bool = game.physics.can_hit(game.runtime.state.player_center(),_center(target),"player",str(target.id))
	if now-decision_wall >= 100:
		decision_wall = now
		motion = _combat_steering(target,now,line_clear)
	if not combat_plan.is_empty() and combat_plan.target_id == str(target.id) and combat_context.get("reason") == "following_melee_route": motion = _combat_route_motion()
	_motion(motion)
	if failures.is_empty() and CombatDriver.combat_attack_ready(distance,aligned,float(game.runtime.p.attackCd),float(game.runtime.p.stunT),line_clear):
		_send_attack({"target_id":target.id,"target_center":_center(target),"player_center":game.runtime.state.player_center(),"distance":distance,"alignment":aligned,"cooldown":game.runtime.p.attackCd,"stun":game.runtime.p.stunT,"can_hit":line_clear})

static func weapon_chain(rows: Array) -> Dictionary:
	var errors: Array[String] = []; var transitions: Array[Dictionary] = []; var weapons: Array[String] = []
	var expected := "fists"; var fists_only := true
	var previous_ms := -1.0; var previous_cd := 0.0; var accepted := 0
	var catalog: Dictionary = Content.load_content().catalogs.weapons
	for row: Dictionary in rows:
		accepted += 1
		var before: String = str(row.get("before_weapon","")); var after: String = str(row.get("after_weapon",""))
		var attacks: Array[Dictionary] = []; var hits: Dictionary = {}; var deaths: Dictionary = {}
		var evidence: Array = row.get("events",[])
		for event: Dictionary in evidence:
			var payload: Dictionary = event.get("payload",{})
			if event.get("kind") == "player_attack": attacks.append(payload)
			elif event.get("kind") == "actor_hit" and float(payload.get("damage",0)) > 0: hits[str(payload.get("actor_id",""))] = true
		if attacks.size() != 1:
			errors.append("one accepted input event required per attack"); continue
		var used: String = str(attacks[0].get("used_weapon",""))
		if before != expected or used != before or not catalog.has(used): errors.append("unbacked pre-attack weapon or mismatched used_weapon")
		if used != "fists": fists_only = false
		if used not in weapons: weapons.append(used)
		var active: float = float(row.get("active_ms",NAN))
		var before_cd: float = float(row.get("before_cd",NAN))
		if not is_finite(active) or not is_finite(before_cd) or before_cd != 0.0 or (previous_ms >= 0 and active-previous_ms < previous_cd-0.1): errors.append("actual accepted weapon cooldown violated")
		previous_ms = active; previous_cd = float(catalog.get(used,{}).get("cd",INF))
		if float(row.get("after_cd",-1)) != previous_cd: errors.append("assigned source weapon cooldown differs")
		var current: String = before
		for evidence_index: int in range(evidence.size()):
			var event: Dictionary = evidence[evidence_index]
			var payload: Dictionary = event.get("payload",{})
			if event.get("kind") == "actor_died":
				var id: String = str(payload.get("actor_id",""))
				var pre: Dictionary = row.get("actors_before",{}).get(id,{})
				var post: Dictionary = row.get("actors_after",{}).get(id,{})
				var pre_hp: float = float(pre.get("hp",NAN)); var post_hp: float = float(post.get("hp",NAN))
				if not hits.has(id) or id not in attacks[0].get("hits",[]) or pre.get("dead",true) or not is_finite(pre_hp) or pre_hp <= 0 or not post.get("dead",false) or not is_finite(post_hp) or post_hp > 0:
					errors.append("reward death lacks actual live hit-to-death evidence"); continue
				deaths[id] = pre
			elif event.get("kind") == "toast":
				for reward: String in ["pipe","brick","baguette"]:
					var name_value: String = str(catalog[reward].n)
					if payload.get("text") != "+ "+name_value+"\n(equipped.)": continue
					var backing := ""
					if reward == "pipe" and current == "fists":
						for id: String in deaths:
							if deaths[id].get("ordinary_reward",false): backing = id; break
					elif reward == "brick" and deaths.get("lurch",{}).get("ordinary_reward",false): backing = "lurch"
					elif reward == "baguette" and deaths.get("paulie",{}).get("ordinary_reward",false): backing = "paulie"
					var feed_after := false
					for later: int in range(evidence_index+1,evidence.size()):
						if evidence[later].get("kind") == "feed" and evidence[later].get("payload",{}).get("text") == "picked up "+name_value+". things are escalating.": feed_after = true; break
					if backing.is_empty() or not feed_after:
						errors.append("unbacked source reward: "+reward); continue
					transitions.append({"from":current,"to":reward,"actor_id":backing,"active_ms":active,"wall_ms":row.get("wall_ms",-1)})
					current = reward
		if current != after: errors.append("post-attack weapon changed without source death/reward events")
		expected = current
	return {"ok":errors.is_empty(),"errors":errors,"fists_only":fists_only,"transitions":transitions,"weapons_used":weapons,"accepted_attacks":accepted,"final_weapon":expected}
