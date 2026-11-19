extends "res://tests/office_endpoint_driver.gd"
## One normal-input continuation. No resource, actor, progress or clock fixtures.
const OfficeAcceptance = preload("res://tests/office_acceptance_probe.gd")
const HANDOFF_SHA := "dc13e35bc438725c69fd9d41299b85bb0665fb0a776abc9314cb6c035d0bc066"
const PARENT_SHA := "002bf2fb7f9ecb59e826b2f9a964f3049d93cc4ecc7a38f217cfac4bcc304708"
const CAMPAIGN_LIMIT := 1800000
const CAMPAIGN_PHASES := {"load":30000,"resources":480000,"claims":600000,"tony":180000,"blue_tarp":270000,"cart_cavalry":270000,"copper_choir":270000,"anoint":180000,"emperor":270000,"persistence":60000}
const BOSS_HP := {"tony":200,"darryl_under_blue":180,"general_receipt":200,"bishop_wire":210,"curb_emperor":280}
const REWARDS := {"darryl_under_blue":Vector2(24,18),"general_receipt":Vector2(30,22),"bishop_wire":Vector2(36,26),"curb_emperor":Vector2(60,40)}
const COT_TARGET_HP := 90.0
const COT_ACTION_LIMIT := 12
const DAILY_COT_KEYS := ["stripeFencedToday","barbPacketsToday","peteCashToday","heistsToday","robberiesToday","breakinsToday"]
const CLAIM_ORDER := ["alley","projects","skidrow"]
const CLAIM_NAMES := {"alley":"BACK ALLEY","projects":"THE PROJECTS","skidrow":"SKID ROW"}
const BANNERS := {"darryl_under_blue":"blue_tarp","general_receipt":"cart_cavalry","bishop_wire":"copper_choir","curb_emperor":"throne"}
class CampaignObservedScene:
	extends OfficeAcceptance.ObservedScene
	var day_receipts: Array[Dictionary] = []
	static func project_day_events(outbox: Array,pending: Array) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for queue: Array in [outbox,pending]:
			for event: Dictionary in queue:
				if event.get("kind") == "day_started": result.append(event.duplicate(true))
		return result
	func _consume_events() -> void:
		if audit_enabled and runtime != null:
			for event: Dictionary in project_day_events(runtime._outbox,runtime.state.events):
				if day_receipts.size() >= 64: overflow = true; break
				day_receipts.append({"kind":event.kind,"payload":event.get("payload",{}).duplicate(true),"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms})
		super._consume_events()

class FinishLatch:
	extends RefCounted
	var queued := false
	var started := false
	var started_at := -1
	func request() -> bool:
		if queued or started: return false
		queued = true; return true
	func begin(now: int) -> bool:
		if started: return false
		queued = true; started = true; started_at = now; return true
	func timed_out(now: int) -> bool:
		return started and now-started_at >= 15000

class CourtDefenseBudget:
	extends RefCounted
	var bouts := 0
	var total_ms := 0
	var guard_ms: Dictionary = {}
	var guard_bouts: Dictionary = {}
	var active_id := ""
	var active_start := -1
	func remaining_ms(id: String) -> int:
		return maxi(0,mini(10000-int(guard_ms.get(id,0)),150000-total_ms))
	func can_begin(id: String) -> bool:
		return not id.is_empty() and active_id.is_empty() and bouts < 30 and int(guard_bouts.get(id,0)) < 2 and (guard_ms.has(id) or guard_ms.size() < 15) and remaining_ms(id) > 0
	func begin(id: String,now: int) -> bool:
		if now < 0 or not can_begin(id): return false
		active_id = id; active_start = now; bouts += 1
		guard_ms[id] = int(guard_ms.get(id,0)); guard_bouts[id] = int(guard_bouts.get(id,0))+1
		return true
	func finish(now: int) -> Dictionary:
		if active_id.is_empty() or now < active_start: return {"ok":false,"reason":"inactive_or_invalid_clock"}
		var id: String = active_id; var elapsed: int = now-active_start
		guard_ms[id] = int(guard_ms[id])+elapsed; total_ms += elapsed; active_id = ""; active_start = -1
		return {"ok":int(guard_ms[id]) < 10000 and total_ms < 150000,"id":id,"elapsed_ms":elapsed,"guard_ms":guard_ms[id],"total_ms":total_ms,"bouts":bouts,"unique_guards":guard_ms.size()}

var finish_latch := FinishLatch.new()
var watchdog_boot_wall := 0
var campaign_output_owned := false
var campaign_transactions: Array[Dictionary] = []
var campaign_battles: Array[Dictionary] = []
var campaign_smokes: Array[Dictionary] = []
var campaign_endings: Array[Dictionary] = []
var campaign_input: Dictionary = {}
var campaign_persistence: Dictionary = {}
var expected_boss := ""
var expected_ending := ""
var allowed_epochs := 0
var campaign_last_weapon := "pipe"
var campaign_weapon_errors: Array[String] = []
var campaign_reward_rows: Dictionary = {}
var campaign_last_attack_ms := -1.0
var campaign_last_attack_cd := 0.0
var active_smoke: Dictionary = {}
var campaign_initial: Dictionary = {}
var campaign_started := false
var capture_serial := 0
var court_defense_budget := CourtDefenseBudget.new()
var court_defenses: Array[Dictionary] = []
var stop_after_tony := false
var resume_tony := false
var tony_prefix_report: Dictionary = {}
var tony_checkpoint_info: Dictionary = {}
var resume_input_snapshot: Dictionary = {}
var immutable_source_hashes: Dictionary = {}
var resume_info: Dictionary = {}

static func digest_valid(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true

static func evidence_value_equal(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_finite(float(a)) and is_finite(float(b)) and a == b
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not evidence_value_equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in range(a.size()):
			if not evidence_value_equal(a[index],b[index]): return false
		return true
	return typeof(a) == typeof(b) and a == b

static func checkpoint_value_equal(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_finite(float(a)) and is_finite(float(b)) and JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not checkpoint_value_equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in range(a.size()):
			if not checkpoint_value_equal(a[index],b[index]): return false
		return true
	return typeof(a) == typeof(b) and a == b

static func checkpoint_durable_equal(a: Dictionary,b: Dictionary) -> bool:
	for key: String in ["cash","copper","cred","weapon","equip","inventory","rocks","lifetime","faction","hp","brain","shakes","wanted"]:
		if not a.get("player",{}).has(key) or not b.get("player",{}).has(key) or not checkpoint_value_equal(a.player[key],b.player[key]): return false
	for key: String in ["day","office","districtClaims","kingdom","quests"]:
		if not a.get("state",{}).has(key) or not b.get("state",{}).has(key) or not checkpoint_value_equal(a.state[key],b.state[key]): return false
	return true

static func summary_checkpoint_matches(summary: Dictionary,snapshot: Dictionary) -> bool:
	var pairs := {"cash":"cash","copper":"copper","cred":"cred","weapon":"weapon","equip":"equip","inventory":"inventory","rocks":"rocks","hp":"hp","brain":"brain","shakes":"shakes","wanted":"wanted"}
	for key: String in pairs:
		if not summary.has(key) or not snapshot.get("player",{}).has(pairs[key]) or not checkpoint_value_equal(summary[key],snapshot.player[pairs[key]]): return false
	for pair: Array in [["day","day"],["office","office"],["claims","districtClaims"],["kingdom","kingdom"]]:
		if not summary.has(pair[0]) or not snapshot.get("state",{}).has(pair[1]) or not checkpoint_value_equal(summary[pair[0]],snapshot.state[pair[1]]): return false
	return true

static func assess_prefix_content(report: Dictionary) -> Array[String]:
	var errors: Array[String] = []; var proof: Dictionary = report.get("input",{})
	if report.get("format") != "rock-bottom-campaign-tony-prefix" or proof.get("handoff_sha256") != HANDOFF_SHA or proof.get("parent_report_sha256") != PARENT_SHA or proof.get("parent_accepted") != true or proof.get("fixture_writes") != 0: errors.append("original earned prefix lineage")
	for key: String in ["state_writes","deaths","arrests","escapes","unexpected_epochs"]:
		if report.get(key,-1) != 0: errors.append("prefix forbidden lifecycle/write: "+key)
	if report.get("bounded") != true or not evidence_bounded(report) or not is_finite(_c_number(report,"wall_ms")) or _c_number(report,"wall_ms") <= 0 or _c_number(report,"wall_ms") >= CAMPAIGN_LIMIT: errors.append("bounded prefix")
	errors.append_array(assess_initial(report.get("initial",{})))
	var counts: Dictionary = {}; var filed: Array = []; var installed: Array = []
	for row: Dictionary in report.get("transactions",[]):
		errors.append_array(assess_transaction(row)); var kind: String = str(row.get("kind","")); counts[kind] = counts.get(kind,0)+1
		if kind == "claim_file": filed.append(row.details.id)
		if kind == "claim_install": installed.append(row.details.id)
		if kind not in ["work","copper","conductor","buy_rock","short","claim_file","claim_install","rest","sleep"]: errors.append("prefix has downstream transaction")
	for pair: Array in [["work",1],["copper",3],["conductor",1],["buy_rock",3],["short",3],["claim_file",3],["claim_install",3]]:
		if counts.get(pair[0],0) != pair[1]: errors.append("prefix exact receipt count: "+str(pair[0]))
	if filed != CLAIM_ORDER or installed != CLAIM_ORDER: errors.append("prefix three ordered claims")
	if counts.get("rest",0)+counts.get("sleep",0) != report.get("rest_count",-1) or int(report.get("rest_count",99)) > COT_ACTION_LIMIT: errors.append("prefix cot ledger")
	var fights: Array = report.get("battles",[])
	if fights.size() != 1 or fights[0].get("id") != "tony": errors.append("one actual Tony prefix fight")
	else: errors.append_array(assess_battle(fights[0]))
	var loops: Array = report.get("smoke_loops",[])
	if loops.size() != 2: errors.append("two completed prefix smoke loops")
	else:
		for index: int in range(2):
			errors.append_array(assess_smoke(loops[index]))
			if loops[index].get("kind") != ["street","tony"][index]: errors.append("ordered prefix loops")
	if report.get("pending_smoke",{}) != {}: errors.append("no truncated prefix smoke")
	var ending: Array = report.get("endings",[])
	if ending.size() != 1 or ending[0].get("id") != "tony" or ending[0].get("seen") != true or ending[0].get("continued") != true: errors.append("real Tony ending continuation")
	var final: Dictionary = report.get("final",{})
	if final.get("claims") != {"canal":true,"alley":true,"projects":true,"skidrow":true} or final.get("kingdom",{}).get("stage") != "summons" or final.get("kingdom",{}).get("defeats") != [] or final.get("fallen_king") != true or final.get("rocks") != 1 or final.get("weapon") != "shoe" or final.get("high") != 0 or final.get("crash") != 0: errors.append("earned Tony prefix endpoint")
	var phases_seen: Array = []
	for phase: Dictionary in report.get("phase_states",[]):
		phases_seen.append(phase.get("id"))
		if not CAMPAIGN_PHASES.has(phase.get("id")) or not is_finite(_c_number(phase,"wall_ms")) or _c_number(phase,"wall_ms") <= 0 or _c_number(phase,"wall_ms") >= float(CAMPAIGN_PHASES.get(phase.get("id"),0)): errors.append("prefix phase deadline")
	if phases_seen != ["load","resources","claims","tony"] or report.get("captures",[]).size() < 9 or report.get("weapon_errors",["missing"]) != []: errors.append("prefix rendered phases and combat audit")
	for key: String in ["motion_frames","mouse_motion","keys","clicks"]:
		if int(report.get("input_counts",{}).get(key,0)) <= 0: errors.append("prefix actual input: "+key)
	return errors

static func assess_prefix(report: Dictionary) -> Array[String]:
	var errors: Array[String] = assess_prefix_content(report); var saved: Dictionary = report.get("checkpoint",{})
	if saved.get("saved_through_pause") != true or saved.get("menu_receipt",{}).get("option") != "remember this." or saved.get("save_completed") != true or not digest_valid(saved.get("save_sha256")) or not checkpoint_durable_equal(saved.get("before",{}),saved.get("stored",{})) or not summary_checkpoint_matches(report.get("final",{}),saved.get("stored",{})): errors.append("actual immutable Pause save checkpoint")
	var hashes: Dictionary = report.get("source_hashes",{})
	if hashes.is_empty() or not hashes.has("res://data/source_content.json"): errors.append("immutable production source inventory")
	for value: Variant in hashes.values():
		if not digest_valid(value): errors.append("valid source inventory digest")
	if not digest_valid(report.get("driver_sha256")): errors.append("prefix driver provenance")
	return errors

static func resume_admission_errors(parent: Variant,saved_input: Variant,save_pin: String,sources: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not parent is Dictionary: return ["prefix JSON root is not a dictionary"]
	if parent.get("acceptance") != true: errors.append("prefix acceptance is not true")
	if parent.get("status") != "complete": errors.append("prefix status is not complete")
	if parent.get("failures",["missing"]) != []: errors.append("prefix failures are present or missing")
	for reason: String in assess_prefix(parent): errors.append("prefix proof: "+reason)
	if not saved_input is Dictionary: errors.append("save JSON root is not a dictionary")
	if parent.get("checkpoint",{}).get("save_sha256") != save_pin: errors.append("prefix checkpoint digest differs from pinned save digest")
	if not checkpoint_value_equal(parent.get("checkpoint",{}).get("stored"),saved_input): errors.append("prefix stored save differs from decoded pinned save")
	var expected: Dictionary = parent.get("source_hashes",{})
	for path: String in expected:
		if not sources.has(path): errors.append("source missing: "+path)
		elif sources[path] != expected[path]: errors.append("source changed: "+path+" expected="+str(expected[path])+" actual="+str(sources[path]))
	for path: String in sources:
		if not expected.has(path): errors.append("source extra: "+path)
	return errors

static func assess_suffix(report: Dictionary,prefix: Dictionary) -> Array[String]:
	var errors: Array[String] = assess_prefix(prefix); var proof: Dictionary = report.get("resume",{})
	if prefix.get("acceptance") != true or prefix.get("status") != "complete" or prefix.get("failures",["missing"]) != []: errors.append("accepted immutable prefix only")
	if report.get("format") != "rock-bottom-campaign-kingdom-suffix" or proof.get("prefix_accepted") != true or not digest_valid(proof.get("report_sha256")) or proof.get("save_sha256") != prefix.get("checkpoint",{}).get("save_sha256") or not checkpoint_durable_equal(report.get("loaded_input",{}),prefix.get("checkpoint",{}).get("stored",{})) or not summary_checkpoint_matches(report.get("initial",{}),report.get("loaded_input",{})) or report.get("source_hashes") != prefix.get("source_hashes"): errors.append("exact suffix prefix/source/save binding")
	if report.get("initial",{}).get("max_hp") != prefix.get("final",{}).get("max_hp") or report.get("initial",{}).get("high") != 0 or report.get("initial",{}).get("crash") != 0: errors.append("source derived maximumHP and completed-loop load boundary")
	for key: String in ["state_writes","deaths","arrests","escapes","unexpected_epochs"]:
		if report.get(key,-1) != 0: errors.append("suffix forbidden lifecycle/write: "+key)
	if report.get("bounded") != true or not evidence_bounded(report) or not is_finite(_c_number(report,"wall_ms")) or _c_number(report,"wall_ms") <= 0 or _c_number(prefix,"wall_ms")+_c_number(report,"wall_ms") >= CAMPAIGN_LIMIT: errors.append("combined original30min bound")
	var counts: Dictionary = {}; var awards: Array = []
	for row: Dictionary in report.get("transactions",[]):
		errors.append_array(assess_transaction(row)); var kind: String = str(row.get("kind","")); counts[kind] = counts.get(kind,0)+1
		if kind == "kingdom_reward": awards.append(row.details.id)
		if kind not in ["summons","mark","kingdom_reward","rest","sleep"]: errors.append("suffix cannot replay prefix transaction")
	if counts.get("summons",0) != 1 or counts.get("mark",0) != 9 or counts.get("kingdom_reward",0) != 4 or awards != REWARDS.keys(): errors.append("four earned Kingdom awards and nine marks")
	if counts.get("rest",0)+counts.get("sleep",0)+int(prefix.get("rest_count",0)) != report.get("rest_count",-1) or int(report.get("rest_count",99)) > COT_ACTION_LIMIT: errors.append("shared12 cot commands across runs")
	var ids: Array = []
	for fight: Dictionary in report.get("battles",[]): ids.append(fight.get("id")); errors.append_array(assess_battle(fight))
	if ids != REWARDS.keys(): errors.append("four suffix sub90s boss proofs")
	var loops: Array = report.get("smoke_loops",[])
	if loops.size() != 1 or loops[0].get("kind") != "royal": errors.append("one full royal smoke in suffix")
	else: errors.append_array(assess_smoke(loops[0]))
	if report.get("pending_smoke",{}) != {}: errors.append("no unfinished suffix smoke")
	var endings: Array = report.get("endings",[])
	if endings.size() != 1 or endings[0].get("id") != "kingdom" or endings[0].get("seen") != true or endings[0].get("continued") != true: errors.append("real Kingdom ending continuation")
	var final: Dictionary = report.get("final",{})
	if final.get("claims") != prefix.get("final",{}).get("claims") or final.get("kingdom",{}).get("stage") != "complete" or final.get("kingdom",{}).get("defeats") != REWARDS.keys() or final.get("one_cracklord") != true: errors.append("actual completed Kingdom suffix")
	var persistence: Dictionary = report.get("persistence",{})
	if persistence.get("ok") != true or persistence.get("durable_equal") != true or persistence.get("resumed_motion") != true: errors.append("suffix final real save/load/movement")
	var phase_ids: Array = []
	for phase: Dictionary in report.get("phase_states",[]):
		phase_ids.append(phase.get("id"))
		if not CAMPAIGN_PHASES.has(phase.get("id")) or not is_finite(_c_number(phase,"wall_ms")) or _c_number(phase,"wall_ms") <= 0 or _c_number(phase,"wall_ms") >= float(CAMPAIGN_PHASES.get(phase.get("id"),0)): errors.append("suffix phase deadline")
	if phase_ids != ["load","blue_tarp","cart_cavalry","copper_choir","anoint","emperor","persistence"] or report.get("captures",[]).size() < 15 or report.get("weapon_errors",["missing"]) != []: errors.append("suffix rendered phases/combat audit")
	if not evidence_value_equal(report.get("input"),prefix.get("input")) or not digest_valid(report.get("driver_sha256")): errors.append("suffix original lineage and driver provenance")
	for key: String in ["motion_frames","mouse_motion","keys","clicks"]:
		if int(report.get("input_counts",{}).get(key,0)) <= 0: errors.append("suffix actual input: "+key)
	return errors

static func assess_aggregate(report: Dictionary) -> Array[String]:
	var prefix: Dictionary = report.get("prefix",{}); var suffix: Dictionary = report.get("suffix",{}); var errors: Array[String] = assess_suffix(suffix,prefix)
	if report.get("format") != "rock-bottom-campaign-two-run-aggregate" or report.get("runs") != 2 or report.get("continuous_run") != false or suffix.get("acceptance") != true or suffix.get("status") != "complete" or suffix.get("failures",["missing"]) != []: errors.append("honest two-run accepted composition")
	if not evidence_value_equal(report.get("five_bosses"),prefix.get("battles",[])+suffix.get("battles",[])): errors.append("five real referenced fight receipts")
	return errors

static func court_guard_candidate(body: Dictionary,day: int,center: Vector2) -> bool:
	if day < 1 or not center.is_finite() or body.get("dead",false) or (body.get("hostile") != true and body.get("aggro") != true) or body.get("kingdomGuard") != true or body.get("essential",false) or body.get("kingdomBoss",false) or body.get("kingdomPretender",false): return false
	var clan: String = str(body.get("kingdomClan","")); var names := {"blue_tarp":"TARP KNIGHT","cart_cavalry":"CART LANCER","copper_choir":"WIRE DEACON","throne":"KNIGHT EMERITUS"}
	if not names.has(clan) or body.get("name") != names[clan]: return false
	var prefix: String = "kingdom_guard_%s_%d_" % [clan,day]; var id: String = str(body.get("id",""))
	if not id.begins_with(prefix): return false
	var suffix: String = id.trim_prefix(prefix)
	if suffix not in (["0","1","2"] if clan == "throne" else ["0","1","2","3"]): return false
	var sprites := {"blue_tarp":"blue_tarp_guard","cart_cavalry":"receipt_guard","copper_choir":"wire_guard"}
	var expected: String = ["blue_tarp_guard","receipt_guard","wire_guard"][int(suffix)%3] if clan == "throne" else sprites[clan]
	if body.get("sprite") != expected or body.get("w") != 32 or body.get("h") != 32: return false
	var x: float = _c_number(body,"x"); var y: float = _c_number(body,"y"); var hp: float = _c_number(body,"hp")
	return is_finite(x) and is_finite(y) and is_finite(hp) and hp > 0 and center.distance_to(Vector2(x+16,y+16)) < 85.0

func _court_defensive_target(require_los: bool = true) -> Dictionary:
	if phase_name not in ["blue_tarp","cart_cavalry","copper_choir","emperor"] or not expected_boss.is_empty() or game.runtime.s.bossActive or game.runtime.s.mode != "playing": return {}
	var chosen: Dictionary = {}; var nearest := 85.0; var center: Vector2 = game.runtime.state.player_center()
	for body: Dictionary in game.runtime.state.npcs:
		if not court_guard_candidate(body,int(game.runtime.s.day),center): continue
		var distance: float = _center(body).distance_to(center)
		if distance < nearest and (not require_los or game.physics.can_hit(center,_center(body),"player",str(body.id))):
			chosen = body; nearest = distance
	return chosen

func _court_defend(candidate: Dictionary = {}) -> void:
	var target: Dictionary = _court_defensive_target() if candidate.is_empty() else candidate
	if target.is_empty(): return
	var id: String = str(target.id); var began: int = Time.get_ticks_msec(); var remaining: int = court_defense_budget.remaining_ms(id)
	if not _check(court_defense_budget.begin(id,began),"finite shared canonical guard defense budget"): return
	var prior_service: String = endpoint_service; var prior_selected: Vector3 = endpoint_selected; var origin: Vector3 = game.player.position; var first: int = attack_receipts.size()
	var source_before: Dictionary = target.duplicate(true); var player_before: Vector2 = game.runtime.state.player_center(); var planning_before: int = combat_replans
	endpoint_service = ""; endpoint_selected = Vector3.INF
	var reason := "remaining_bout_budget"
	while _alive() and game.runtime.s.mode == "playing" and Time.get_ticks_msec()-began < maxi(0,remaining-50):
		if target.get("dead",false): reason = "target_dead"; break
		if not court_guard_candidate(target,int(game.runtime.s.day),game.runtime.state.player_center()): reason = "left_actual_threat_range"; break
		_combat_input(target); await game.frame_sampled
	_release(); motion = Vector2.ZERO
	endpoint_service = prior_service
	var moved: bool = game.player.position.distance_to(origin) > 0.00001
	endpoint_selected = Vector3.INF if moved else prior_selected
	if moved: service_aim_wait.clear()
	var budget: Dictionary = court_defense_budget.finish(Time.get_ticks_msec())
	court_defenses.append({"id":id,"source_before":source_before,"source_actor":target.duplicate(true),"player_before":player_before,"day":game.runtime.s.day,"from":origin,"to":game.player.position,"reason":reason,"first_attack":first,"last_attack":attack_receipts.size(),"endpoint_invalidated":moved,"budget":budget,"planning_before":planning_before,"planning_after":combat_replans,"start_wall":began,"end_wall":Time.get_ticks_msec()})
	_check(budget.ok,"shared guard10s/150s cumulative limit")
	_checkpoint("court_defense:"+id)

func _walk_frame() -> void:
	await _court_defend()
	await game.frame_sampled

func _service_frame() -> void:
	await _court_defend()
	await game.frame_sampled

func _defend_exit() -> bool:
	# The older no-route fallback must not create a second uncounted guard budget.
	var guard: Dictionary = _court_defensive_target(false)
	if not guard.is_empty():
		await _court_defend(guard)
		return failures.is_empty()
	return await super._defend_exit()

func _initialize() -> void:
	watchdog_boot_wall = Time.get_ticks_msec()
	call_deferred("_campaign_watchdog")
	call_deferred("_run")

func _campaign_watchdog() -> void:
	while true:
		await create_timer(1.0,true,false,true).timeout
		var now: int = Time.get_ticks_msec()
		if finish_latch.started:
			if finish_latch.timed_out(now): _force_failed_exit("campaign finalization15s watchdog"); return
			continue
		if not failures.is_empty(): _request_campaign_finish(); continue
		if campaign_started:
			if not _alive(): _request_campaign_finish()
		elif now-watchdog_boot_wall >= 120000:
			_check(false,"independent cold title120s watchdog"); _request_campaign_finish()

func _request_campaign_finish() -> void:
	if finish_latch.request(): call_deferred("_finish_campaign")

func _force_failed_exit(reason: String) -> void:
	_check(false,reason)
	if campaign_output_owned:
		var path: String = output.path_join("campaign-kingdom-suffix.json" if resume_tony else "campaign-continuation.json")
		var existing: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		var report: Dictionary = existing if existing is Dictionary else {"schema":1,"format":"rock-bottom-campaign-continuation","input":campaign_input}
		report.acceptance = false; report.status = "failed"; report.failures = failures.duplicate(); report.watchdog_reason = reason
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	quit(1)

static func launch_error(arguments: PackedStringArray) -> String:
	var found: Dictionary = {}
	for argument: String in arguments:
		var key: String = argument.get_slice("=",0)
		if key not in ["--qa-full","--handoff","--parent-report","--output","--diagnostic","--stop-after-tony","--resume-tony","--handoff-sha","--parent-sha"]: return "unknown argument"
		if found.has(key): return "duplicate argument"
		found[key] = argument
		if key in ["--qa-full","--diagnostic","--stop-after-tony","--resume-tony"] and argument != key: return "flag takes no value"
		if key in ["--handoff-sha","--parent-sha"] and (not argument.begins_with(key+"=") or not digest_valid(argument.trim_prefix(key+"="))): return "explicit SHA256 required"
		if key in ["--handoff","--parent-report","--output"]:
			if not argument.begins_with(key+"=") or not argument.trim_prefix(key+"=").is_absolute_path(): return "absolute path required"
	for key: String in ["--qa-full","--handoff","--parent-report","--output"]:
		if not found.has(key): return "missing "+key
	if found.has("--stop-after-tony") and found.has("--resume-tony"): return "exclusive checkpoint modes"
	if found.has("--resume-tony"):
		if not found.has("--handoff-sha") or not found.has("--parent-sha"): return "pinned prefix and save required"
	elif found.has("--handoff-sha") or found.has("--parent-sha"): return "prefix pins require resume mode"
	return ""

static func _c_number(row: Dictionary,key: String) -> float:
	var value: Variant = row.get(key)
	return float(value) if (value is int or value is float) and is_finite(float(value)) else NAN

static func same_aim_wait(wait: Dictionary,id: String,player_epoch: Dictionary,state_epoch: Dictionary,revision: int,position: Vector3,focus: Vector3) -> bool:
	return not wait.is_empty() and wait.get("id") == id and is_same(wait.get("player_epoch"),player_epoch) and is_same(wait.get("state_epoch"),state_epoch) and wait.get("revision") == revision and wait.get("position") is Vector3 and wait.get("focus") is Vector3 and position.distance_to(wait.position) < 0.25 and focus.distance_to(wait.focus) < 0.25

static func endpoint_ray_clear(hit: Dictionary,owner: String) -> bool:
	return hit.is_empty() or (not owner.is_empty() and hit.get("collider") is CollisionObject3D and str(hit.collider.get_meta("source_owner","")) == owner)

static func observed_boss_phase(id: String,state: Dictionary,body: Dictionary) -> int:
	if not BOSS_HP.has(id) or body.get("id") != id: return 0
	var value: Variant = state.get("bossPhase") if id == "tony" else body.get("kingdomPhase")
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 1 or float(value) > 3: return 0
	return int(value)

static func assess_initial(a: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if a.get("cash") != 79 or a.get("copper") != 0 or a.get("hp") != 100 or a.get("weapon") != "pipe" or a.get("street") != 6 or a.get("claims") != {"canal":true} or not evidence_value_equal(a.get("office",{}).get("workJob"),{"id":"canal","serial":2,"stage":"inspect"}): errors.append("retained handoff values")
	if a.get("routes") != 3 or a.get("office_jobs") != 1 or a.get("office",{}).get("owned") != true or a.get("office",{}).get("upgrades",{}).get("desk") != true or a.get("office",{}).get("upgrades",{}).get("radio") != true or a.get("office",{}).get("upgrades",{}).get("cot") != true or a.get("kingdom",{}).get("stage") != "locked" or a.get("fallen_king") != false: errors.append("retained progression witnesses")
	if a.get("day") != 3 or a.get("rocks") != 0 or a.get("offenses") != 0 or a.get("rocks_smoked") != 3 or a.get("inventory") != [] or a.get("equip") != {"hat":null,"coat":null,"shoes":null,"tool":null}: errors.append("retained inventory and day witnesses")
	return errors

static func evidence_bounded(report: Dictionary) -> bool:
	for pair: Array in [["day_events",64],["captures",24],["samples",3600],["events",40000],["transactions",80],["legs",96],["menus",256],["walking",1024],["combat_navigation",2048],["attack_receipts",3000]]:
		var entries: Variant = report.get(pair[0],[])
		if not entries is Array or entries.size() > pair[1]: return false
	return true

static func resource_plan(start: Dictionary) -> Dictionary:
	var cash: float = _c_number(start,"cash"); var copper: float = _c_number(start,"copper")
	var valid: bool = is_finite(cash) and is_finite(copper) and cash >= 39 and copper >= 0
	return {"ok":valid,"reason":"" if valid else "insufficient or malformed resources","heists":3,"minimum_cash_before_kingdom":cash+6+90-30-90-15,"minimum_copper_after_claims":copper+6-3-3}

static func cot_action(row: Dictionary,used: int,boss_active: bool) -> String:
	var hp: float = _c_number(row,"hp"); var maximum: float = _c_number(row,"max_hp")
	if boss_active or used < 0 or used > COT_ACTION_LIMIT or not is_finite(hp) or not is_finite(maximum) or hp <= 0 or hp > maximum or maximum < COT_TARGET_HP: return "refuse"
	if hp >= COT_TARGET_HP: return "none"
	if used >= COT_ACTION_LIMIT: return "refuse"
	return "rest" if hp >= 80.0 else "sleep"

static func assess_cot(row: Dictionary) -> Array[String]:
	var errors: Array[String] = []; var a: Dictionary = row.get("before",{}); var b: Dictionary = row.get("after",{}); var d: Dictionary = row.get("details",{})
	var action: String = str(row.get("kind","")); var sleeping: bool = action == "sleep"
	var powered: bool = a.get("office",{}).get("upgrades",{}).get("generator") == true
	var rolled: bool = sleeping and _c_number(a,"day_time") > 0.3
	if action not in ["rest","sleep"] or d.get("source") != "office:cot" or d.get("action") != action or d.get("boss_active") != false: errors.append("ordinary noncombat cot action")
	for key: String in ["hp","max_hp","brain","shakes","wanted","day_time","high","crash"]:
		if not is_finite(_c_number(a,key)) or not is_finite(_c_number(b,key)): errors.append("finite cot field: "+key)
	if _c_number(b,"hp") != minf(_c_number(a,"max_hp"),_c_number(a,"hp")+(55.0 if sleeping else (18.0 if powered else 10.0))): errors.append("exact cot hp")
	if _c_number(b,"brain") != minf(100.0,_c_number(a,"brain")+((30.0 if powered else 25.0) if sleeping else (5.0 if powered else 0.0))): errors.append("exact cot brain")
	if _c_number(b,"shakes") != (minf(100.0,_c_number(a,"shakes")+15.0) if sleeping else _c_number(a,"shakes")): errors.append("exact cot shakes")
	if _c_number(b,"wanted") != maxf(0.0,_c_number(a,"wanted")-(2.0 if sleeping else 1.0)): errors.append("exact cot wanted")
	if b.get("day") != a.get("day",-1)+(1 if rolled else 0) or _c_number(b,"day_time") != (0.3 if sleeping else _c_number(a,"day_time")): errors.append("strict cot calendar branch")
	for key: String in ["high","crash","max_hp","cash","copper","rocks","rocks_smoked","weapon","equip","inventory","claims","street","cred","office_jobs","routes","offenses"]:
		if a.get(key) != b.get(key): errors.append("cot preserves "+key)
	for key: String in ["owned","upgrades","workJob","claimJob","jobsCompleted","orderSerial","lastWorkId"]:
		if a.get("office",{}).get(key) != b.get("office",{}).get(key): errors.append("cot preserves Office "+key)
	var days: Array = []
	for event: Dictionary in d.get("day_events",[]):
		if event.get("kind") == "day_started": days.append(event.get("payload",{}))
	if rolled:
		if days.size() != 1 or days[0].get("cause") != "office_sleep" or days[0].get("day") != b.get("day") or days[0].get("handled") != true: errors.append("real cot day receipt")
		if b.get("office",{}).get("workDay") != b.get("day") or b.get("office",{}).get("workToday") != 0: errors.append("cot resets daily Office capacity")
		for key: String in DAILY_COT_KEYS:
			if b.get("counters",{}).get(key) != 0: errors.append("cot resets "+key)
		if b.get("heists") != 0 or not b.get("hustles") is Array or b.get("hustles",[]).size() != 3 or not b.get("hustle_snapshot") is Dictionary: errors.append("cot records actual daily projection")
	else:
		if not days.is_empty(): errors.append("cot must not invent a day event")
		for key: String in ["workDay","workToday"]:
			if a.get("office",{}).get(key) != b.get("office",{}).get(key): errors.append("same-day cot preserves Office "+key)
		for key: String in ["counters","hustles","hustle_snapshot","heists","rng"]:
			if a.get(key) != b.get(key): errors.append("same-day cot preserves "+key)
	return errors

static func assess_transaction(row: Dictionary) -> Array[String]:
	var errors: Array[String] = []; var a: Dictionary = row.get("before",{}); var b: Dictionary = row.get("after",{}); var d: Dictionary = row.get("details",{})
	var cash: float = _c_number(b,"cash")-_c_number(a,"cash"); var copper: float = _c_number(b,"copper")-_c_number(a,"copper")
	if not is_finite(cash) or not is_finite(copper): return ["nonfinite resource receipt"]
	match str(row.get("kind","")):
		"work":
			if cash != 6 or copper != 0 or not evidence_value_equal(a.get("office",{}).get("workJob"),{"id":"canal","serial":2,"stage":"file"}) or b.get("office",{}).get("workJob") != null or b.get("office",{}).get("jobsCompleted") != a.get("office",{}).get("jobsCompleted",0)+1: errors.append("pending work settlement")
		"copper":
			if d.get("id") != "cold_not" or copper not in [2.0,3.0,4.0] or cash != 0 or int(a.get("heists",-1)) < 0 or int(a.get("heists",3)) >= 3 or b.get("heists") != a.get("heists",0)+1 or b.get("day") != a.get("day") or b.get("hp") != a.get("hp") or b.get("wanted") != a.get("wanted"): errors.append("ordinary cold site receipt")
			if d.get("entry") != "wait for his round." or d.get("exit") != "the front desk. wave at dennis.": errors.append("wrong copper source choices")
		"conductor":
			if d.get("id") != "conductor" or cash != 90 or copper != -3 or _c_number(a,"copper") < 6: errors.append("conductor reserve trade")
		"buy_rock":
			var price: int = 9 if _c_number(a,"street") >= 10 else 10
			if int(a.get("charisma",0)) >= 1: price = maxi(1,int(floor(float(price)*0.9+0.5)))
			if d.get("id") != "tony" or cash != -price or copper != 0 or b.get("rocks") != a.get("rocks",0)+1 or b.get("street") != a.get("street",0)+1 or b.get("offenses") != maxi(0,int(a.get("offenses",0))-1): errors.append("normal real-rock purchase")
		"short":
			if cash != -5 or copper != 0 or b.get("offenses") != a.get("offenses",0)+1 or b.get("rocks") != a.get("rocks"): errors.append("source short offense")
		"claim_file":
			var id: String = str(d.get("id","")); var count: int = a.get("claims",{}).size()
			if id not in CLAIM_ORDER or cash != -20-5*count or copper != -1 or _c_number(a,"street") < 10 or a.get("office",{}).get("claimJob") != {"id":id,"stage":"file"} or b.get("office",{}).get("claimJob") != {"id":id,"stage":"install"}: errors.append("claim price or prerequisite")
		"claim_install":
			var id: String = str(d.get("id","")); var expected: Dictionary = a.get("claims",{}).duplicate(true); expected[id] = true
			if id not in CLAIM_ORDER or cash != 0 or copper != 0 or _c_number(b,"cred")-_c_number(a,"cred") != 2 or b.get("claims") != expected or a.get("office",{}).get("claimJob") != {"id":id,"stage":"install"} or b.get("office",{}).get("claimJob") != null: errors.append("claim installation")
		"mark":
			var old: int = a.get("kingdom",{}).get("marks",-1); var bit: int = int(d.get("bit",0))
			if bit not in [1,2,4] or old&bit or b.get("kingdom",{}).get("marks") != (old|bit) or a.get("kingdom",{}).get("stage") != b.get("kingdom",{}).get("stage") or cash != 0 or copper != 0: errors.append("source correction bit")
			if not _endpoint_valid(d.get("endpoint",{}),58.0,"kingdom_mark:"): errors.append("fresh correction endpoint")
			var mark_index: int = [1,2,4].find(bit)
			if d.get("endpoint",{}).get("service") != "kingdom_mark:%s:%d" % [str(d.get("id","")),mark_index]: errors.append("matching correction identity")
		"summons":
			if a.get("kingdom",{}).get("stage") != "summons" or b.get("kingdom",{}).get("stage") != "tarp_marks" or b.get("kingdom",{}).get("marks") != 0 or cash != 0 or copper != 0: errors.append("source summons")
		"kingdom_reward":
			var id: String = str(d.get("id","")); var reward: Vector2 = REWARDS.get(id,Vector2.INF)
			var previous: Array = a.get("kingdom",{}).get("defeats",[]); var expected: Array = previous.duplicate(); expected.append(id)
			if not REWARDS.has(id) or id in previous or b.get("kingdom",{}).get("defeats") != expected or cash != reward.x or _c_number(b,"cred")-_c_number(a,"cred") != reward.y or copper != 0: errors.append("one exact Kingdom award")
		"rest", "sleep": errors.append_array(assess_cot(row))
		_: errors.append("unknown transaction kind")
	return errors

static func assess_smoke(row: Dictionary) -> Array[String]:
	var errors: Array[String] = []; var a: Dictionary = row.get("before",{}); var b: Dictionary = row.get("after",{})
	if row.get("kind") not in ["street","tony","royal"] or row.get("consumed") != 1 or row.get("initial_high") != 18000 or _c_number(a,"rocks")-_c_number(b,"rocks") != 1 or _c_number(b,"rocks_smoked")-_c_number(a,"rocks_smoked") != 1 or b.get("street") != a.get("street",0)+1: errors.append("real Block smoke receipt")
	if absf(_c_number(row,"high_ms")-18000) > 100 or absf(_c_number(row,"crash_ms")-8000) > 100 or not is_finite(_c_number(row,"high_ms")) or not is_finite(_c_number(row,"crash_ms")): errors.append("actual18s/8s loop")
	if row.get("kind") == "royal" and (a.get("kingdom",{}).get("stage") != "anoint" or b.get("kingdom",{}).get("stage") != "emperor_gate" or b.get("royal_static") != true): errors.append("royal anointing")
	return errors

static func _endpoint_valid(row: Dictionary,limit: float,prefix: String) -> bool:
	var distance: float = _c_number(row,"source_distance")
	return str(row.get("service","")).begins_with(prefix) and row.get("resolved_kind") == "kingdom_target" and row.get("resolved_id") == row.get("service") and row.get("reachable") == true and row.get("frame",-1) >= 0 and row.get("frame") == row.get("command_frame") and is_finite(distance) and distance >= 0 and distance < limit and row.get("limit") == limit

static func assess_battle(row: Dictionary) -> Array[String]:
	var errors: Array[String] = []; var id: String = str(row.get("id","")); var wall: float = _c_number(row,"wall_ms")
	if not BOSS_HP.has(id) or row.get("initial_hp") != BOSS_HP.get(id): errors.append("canonical boss admission")
	if row.get("started") != true or row.get("won") != true or row.get("defeat") != true or not is_finite(wall) or wall <= 0 or wall >= 90000: errors.append("actual sub90s victory")
	if int(row.get("accepted_attacks",0)) <= 0 or row.get("source_damage") != true or row.get("cooldowns_valid") != true or row.get("weapon_chain_valid") != true: errors.append("actual combat evidence")
	if row.get("mark_bits_before") != (7 if id in ["darryl_under_blue","general_receipt","bishop_wire"] else 0): errors.append("required corrections")
	if id == "tony" and row.get("victory_weapon") != "shoe": errors.append("Tony shoe reward")
	if id != "tony" and not _endpoint_valid(row.get("admission",{}),72.0,"kingdom_banner:"): errors.append("fresh banner endpoint")
	if id != "tony" and row.get("admission",{}).get("service") != "kingdom_banner:"+str(BANNERS.get(id,"")): errors.append("matching boss banner")
	if id in ["tony","curb_emperor"] and not evidence_value_equal(row.get("phase_seen"),[1,2,3]): errors.append("required source boss phases")
	if row.get("adds",[]).size() != 2: errors.append("two source adds observed")
	return errors

static func assess_campaign(report: Dictionary) -> Array[String]:
	var errors: Array[String] = []; var proof: Dictionary = report.get("input",{})
	if report.get("format") != "rock-bottom-campaign-continuation" or proof.get("handoff_sha256") != HANDOFF_SHA or proof.get("parent_report_sha256") != PARENT_SHA or proof.get("parent_accepted") != true or proof.get("fixture_writes") != 0: errors.append("earned input provenance")
	for key: String in ["state_writes","deaths","arrests","escapes","unexpected_epochs"]:
		if report.get(key,-1) != 0: errors.append("forbidden lifecycle or write: "+key)
	if report.get("bounded") != true or not evidence_bounded(report) or _c_number(report,"wall_ms") <= 0 or _c_number(report,"wall_ms") >= CAMPAIGN_LIMIT or not is_finite(_c_number(report,"wall_ms")): errors.append("finite campaign bound")
	var a: Dictionary = report.get("initial",{}); var b: Dictionary = report.get("final",{})
	errors.append_array(assess_initial(a))
	var actual_inputs: Dictionary = report.get("input_counts",{})
	for key: String in ["motion_frames","mouse_motion","keys","clicks"]:
		if int(actual_inputs.get(key,0)) <= 0: errors.append("actual input missing: "+key)
	if report.get("captures",[]).size() < 18 or report.get("captures",[]).size() > 24 or report.get("phase_states",[]).is_empty(): errors.append("rendered phase evidence")
	var phase_ids: Array = []
	for row: Dictionary in report.get("phase_states",[]):
		var id: String = str(row.get("id","")); phase_ids.append(id)
		if not CAMPAIGN_PHASES.has(id) or not is_finite(_c_number(row,"wall_ms")) or _c_number(row,"wall_ms") <= 0 or _c_number(row,"wall_ms") >= float(CAMPAIGN_PHASES.get(id,0)): errors.append("phase deadline proof")
	if phase_ids != CAMPAIGN_PHASES.keys(): errors.append("ordered finite campaign phases")
	if int(report.get("rest_count",-1)) < 0 or int(report.get("rest_count",13)) > 12: errors.append("finite normal cot use")
	var counts: Dictionary = {}; var filed: Array = []; var installed: Array = []; var awards: Array = []
	for row: Dictionary in report.get("transactions",[]):
		for error: String in assess_transaction(row): errors.append(error)
		var kind: String = str(row.get("kind","")); counts[kind] = counts.get(kind,0)+1
		if kind == "claim_file": filed.append(row.details.id)
		if kind == "claim_install": installed.append(row.details.id)
		if kind == "kingdom_reward": awards.append(row.details.id)
	for pair: Array in [["work",1],["copper",3],["conductor",1],["buy_rock",3],["short",3],["claim_file",3],["claim_install",3],["mark",9],["summons",1],["kingdom_reward",4]]:
		if counts.get(pair[0],0) != pair[1]: errors.append("required transaction count: "+str(pair[0]))
	if counts.get("rest",0)+counts.get("sleep",0) != report.get("rest_count",-1): errors.append("cot count matches actual accepted commands")
	if filed != CLAIM_ORDER or installed != CLAIM_ORDER or awards != REWARDS.keys(): errors.append("ordered claims/awards")
	var boss_ids: Array = []
	for row: Dictionary in report.get("battles",[]):
		boss_ids.append(row.get("id")); errors.append_array(assess_battle(row))
	if boss_ids != BOSS_HP.keys(): errors.append("five actual canonical fights")
	var smoke_ids: Array = []
	for row: Dictionary in report.get("smoke_loops",[]): smoke_ids.append(row.get("kind")); errors.append_array(assess_smoke(row))
	if smoke_ids != ["street","tony","royal"]: errors.append("three real smoke loops")
	var ending_ids: Array = []
	for row: Dictionary in report.get("endings",[]):
		ending_ids.append(row.get("id"))
		if row.get("seen") != true or row.get("continued") != true: errors.append("actual ending continuation")
	if ending_ids != ["tony","kingdom"]: errors.append("both source endings")
	if b.get("claims") != {"canal":true,"alley":true,"projects":true,"skidrow":true} or b.get("kingdom",{}).get("stage") != "complete" or b.get("kingdom",{}).get("defeats") != REWARDS.keys() or b.get("one_cracklord") != true: errors.append("durable four-claim Kingdom completion")
	var persisted: Dictionary = report.get("persistence",{})
	if persisted.get("ok") != true or persisted.get("durable_equal") != true or persisted.get("resumed_motion") != true: errors.append("final real save/load/movement")
	if not report.get("weapon_errors",["missing"]).is_empty(): errors.append("source-earned weapon chain")
	return errors

func _summary() -> Dictionary:
	var row: Dictionary = super._summary(); var p: Dictionary = game.runtime.p; var s: Dictionary = game.runtime.s
	row.merge({"street":p.faction.street,"kingdom":s.kingdom.duplicate(true),"fallen_king":s.quests.fallen_king.done,"royal_static":s.quests.royal_static.done,"one_cracklord":s.quests.one_cracklord.done,"heists":s.counters.heistsToday,"wanted":p.wanted,"flags":s.flags.duplicate(true),"counters":s.counters.duplicate(true),"hustles":s.hustles.duplicate(true),"hustle_snapshot":s.hustleSnapshot.duplicate(true)},true)
	return row

func _alive() -> bool:
	if finish_latch.started: return false
	if not failures.is_empty(): return false
	if not campaign_started: return true
	if not court_defense_budget.active_id.is_empty():
		var active_elapsed: int = Time.get_ticks_msec()-court_defense_budget.active_start
		if not _check(active_elapsed >= 0 and active_elapsed < court_defense_budget.remaining_ms(court_defense_budget.active_id),"independent active guard cumulative deadline"): return false
	if not _check(Time.get_ticks_msec()-began_wall+(int(tony_prefix_report.get("wall_ms",0)) if resume_tony else 0) < CAMPAIGN_LIMIT,"campaign30min cumulative global watchdog"): return false
	if not phase_name.is_empty() and not _check(Time.get_ticks_msec()-phase_wall < int(CAMPAIGN_PHASES[phase_name]),"campaign phase watchdog: "+phase_name): return false
	if not _check(not game.overflow and game.replacements.size() <= allowed_epochs,"bounded evidence/expected epochs"): return false
	if game.runtime.s.get("brutusOlderActive",false): return _check(false,"unexpected Older encounter")
	if game.runtime.s.bossActive:
		var active: Variant = game.runtime.s.get("bossNPC")
		if not _check(active is Dictionary and active.get("id") == expected_boss,"only expected canonical boss active"): return false
	if game.runtime.s.mode == "ending" and expected_ending.is_empty(): return _check(false,"unexpected ending")
	while checked_event_count < game.trace.size():
		var event: Dictionary = game.trace[checked_event_count]; checked_event_count += 1
		if event.kind in ["death","arrest","dependency_missing"]: return _check(false,"source event invalidates continuation: "+event.kind)
	if game.samples.size() > 3600 or walking.size() > 1024 or legs.size() > 96 or receipts.size() > 256 or campaign_transactions.size() > 80 or combat_navigation.size() > 2048 or attack_receipts.size() > 3000: return _check(false,"bounded campaign evidence arrays")
	return true

func _update_smoke() -> void:
	if active_smoke.is_empty() or game.crash_end < 0: return
	active_smoke.high_ms = game.high_end-game.loop_start; active_smoke.crash_ms = game.crash_end-game.high_end
	campaign_smokes.append(active_smoke.duplicate(true)); active_smoke = {}

func _tick_campaign() -> void:
	_update_smoke()
	if not _alive(): _request_campaign_finish()

func _c_transaction(kind: String,before: Dictionary,details: Dictionary) -> bool:
	var row := {"kind":kind,"before":before,"after":_summary(),"details":details,"wall_ms":Time.get_ticks_msec(),"active_ms":game.admitted_ms}
	campaign_transactions.append(row)
	for error: String in assess_transaction(row): _check(false,kind+": "+error)
	return failures.is_empty()

func _c_choose(prefix: String,kind: String = "",details: Dictionary = {}) -> bool:
	var day_start: int = (game as CampaignObservedScene).day_receipts.size()
	if not await _choose(prefix): return false
	if not kind.is_empty():
		if kind in ["rest","sleep"]:
			details = details.duplicate(true); details.events = receipts.back().events.duplicate(true)
			details.day_events = (game as CampaignObservedScene).day_receipts.slice(day_start).duplicate(true)
			rest_count += 1
		return _c_transaction(kind,receipts.back().before,details)
	return true

func _c_phase(id: String) -> void:
	_phase(id); _checkpoint("phase:"+id)

func _checkpoint(status: String) -> void:
	if output.is_empty() or not is_instance_valid(game) or game.runtime == null: return
	var row: Dictionary = _campaign_report(); row.status = status; row.acceptance = false; row.failures = failures.duplicate()
	var file := FileAccess.open(output.path_join("campaign-kingdom-suffix.json" if resume_tony else "campaign-continuation.json"),FileAccess.WRITE)
	if file == null: _check(false,"partial campaign evidence writable"); return
	file.store_string(JSON.stringify(row,"\t")); file.close()

func _c_capture(label: String) -> void:
	if not _check(capture_serial < 24,"at most24 campaign captures"): return
	capture_serial += 1; await _capture("%02d_%s" % [capture_serial,label]); _checkpoint("captured:"+label)

func _service_candidate(id: String) -> bool:
	if id.begins_with("copper:"): return game.physics.can_use_site(id)
	return super._service_candidate(id)

func _service_target(id: String) -> Vector3:
	if id.begins_with("copper:"): return game.physics.site_focus(id)
	return super._service_target(id)

func _c_matches(action: Dictionary,id: String) -> bool:
	if id.begins_with("copper:"): return action.get("kind") == "heist" and action.get("id") == id.trim_prefix("copper:")
	if id == "conductor": return action.get("kind") == "quest" and action.get("id") == id
	if id.begins_with("kingdom_mark:") or id.begins_with("kingdom_banner:"): return action.get("kind") == "kingdom_target" and action.get("id") == id
	return interaction_matches(action,id)

func _reach_service(id: String) -> bool:
	if not _service_candidate(id): return false
	if _c_matches(game.resolve_interaction(),id): service_aim_wait.clear(); return true
	var focus: Vector3 = _service_target(id)
	if same_aim_wait(service_aim_wait,id,game.runtime.p,game.runtime.s,game.physics._collision_revision,game.player.position,focus): return false
	_release()
	var resolved: Dictionary = {}
	for frame: int in range(120):
		if not _alive() or game.runtime.s.mode != "playing" or not _service_candidate(id): return false
		_aim(_service_target(id),_dt())
		resolved = game.resolve_interaction()
		if _c_matches(resolved,id): service_aim_wait.clear(); return true
		await _service_frame()
	service_aim_wait = {"id":id,"position":game.player.position,"focus":_service_target(id),"revision":game.physics._collision_revision,"player_epoch":game.runtime.p,"state_epoch":game.runtime.s}
	service_aim_context = {"reason":"intended_action_not_resolved_after120frames","id":id,"resolved":resolved.duplicate(true),"position":game.player.position,"target":_service_target(id)}
	return false

func _endpoint_proof(id: String,point: Vector3) -> Dictionary:
	if not id.begins_with("kingdom_"): return super._endpoint_proof(id,point)
	var service: Dictionary = game.world.service_points.get(id,{})
	if service.is_empty() or not point.is_finite(): return {"ok":false,"reason":"invalid_kingdom_service"}
	var center: Vector2 = Content.to_source(point); var source: Vector2 = service.source_point
	var limit: float = 72.0 if id.begins_with("kingdom_banner:") else 58.0
	if center.distance_squared_to(source) >= limit*limit: return {"ok":false,"reason":"exact_source_range"}
	var body: Dictionary = _probe_body(point); var origin := Vector2(body.x,body.y)
	if not game.physics._clear(body,origin,false) or not game.physics._peer_clear(body,origin,game.physics._contact_peers(body)) or not game.world.is_clear_position(point,0.486): return {"ok":false,"reason":"real_capsule_or_live_peer"}
	var hit: Dictionary = game.physics._ray(Content.to_world(center,game.physics.FEET+1.63),service.target)
	if not endpoint_ray_clear(hit,str(service.structure_id)): return {"ok":false,"reason":"banner_or_mark_occluded"}
	if same_aim_wait(service_aim_wait,id,game.runtime.p,game.runtime.s,game.physics._collision_revision,game.player.position,_service_target(id)) and point.distance_to(service_aim_wait.position) < 0.25: return {"ok":false,"reason":"unchanged_failed_aim_endpoint"}
	return {"ok":true,"point":point,"source_center":center,"source_target":source,"reason":"current_kingdom_endpoint_clear"}

func _visit(id: String,inter_stop: bool = false) -> bool:
	if not id.begins_with("kingdom_"): return await super._visit(id,inter_stop)
	endpoint_service = id; endpoint_original = game.world.service_points[id].approach
	endpoint_selected = Vector3.INF; endpoint_window = -1000000; endpoint_attempts = 0
	var started: int = Time.get_ticks_msec(); var origin: Vector3 = game.player.position; var active: float = game.admitted_ms
	var result: bool = await _walk_to(endpoint_original,id)
	legs.append({"service":id,"from":origin,"to":game.player.position,"wall_ms":Time.get_ticks_msec()-started,"active_ms":game.admitted_ms-active,"arrived":result})
	endpoint_service = ""; endpoint_selected = Vector3.INF
	return result

func _c_endpoint(id: String) -> Dictionary:
	var service: Dictionary = game.world.service_points[id]; var action: Dictionary = game.resolve_interaction()
	return {"service":id,"resolved_kind":action.get("kind"),"resolved_id":action.get("id"),"source_distance":game.runtime.state.player_center().distance_to(service.source_point),"limit":72.0 if id.begins_with("kingdom_banner:") else 58.0,"reachable":game.physics.can_reach_target(id),"frame":Engine.get_process_frames(),"command_frame":Engine.get_process_frames(),"collision_revision":game.physics._collision_revision}

func _c_field(id: String,kind: String = "",details: Dictionary = {}) -> bool:
	if not await _visit(id) or not await _reach_service(id): return false
	var before: Dictionary = _summary()
	if id.begins_with("kingdom_"): details = details.duplicate(true); details.endpoint = _c_endpoint(id)
	_key(KEY_E)
	if not kind.is_empty() and not _c_transaction(kind,before,details): return false
	return _alive()

func _c_smoke(kind: String) -> bool:
	if not active_smoke.is_empty():
		var waiting: int = Time.get_ticks_msec()
		while not active_smoke.is_empty() and _alive() and Time.get_ticks_msec()-waiting < 28000:
			_release(); await game.frame_sampled
		if not _check(active_smoke.is_empty(),"previous exact loop completed"): return false
	if not await _visit("smoke:block") or not await _open_target("smoke:block"): return false
	if not await _choose("smoke a rock. (-1 rock"): return false
	var before: Dictionary = receipts.back().before; var after: Dictionary = _summary()
	game.loop_start = game.admitted_ms; game.high_end = -1; game.crash_end = -1
	active_smoke = {"kind":kind,"before":before,"after":after,"initial_high":after.high,"consumed":int(before.rocks)-int(after.rocks),"high_ms":-1,"crash_ms":-1}
	return _check(after.high == 18000 and int(before.rocks)-int(after.rocks) == 1,"real reserved Block rock consumed")

func _c_resources() -> bool:
	_c_phase("resources")
	if not await _c_field("claim:canal:sign"): return false
	if not await _c_office_open() or not await _c_choose("file work order 2.","work",{"id":"canal"}): return false
	if game.runtime.s.mode == "dialogue" and not await _c_choose("leave the office."): return false
	if not await _visit("copper:cold_not"): return false
	for attempt: int in range(3):
		if not await _reach_service("copper:cold_not"): return _check(false,"real Cold re-entry available")
		var before: Dictionary = _summary(); _key(KEY_E)
		if not _check(game.runtime.s.mode == "dialogue","real Cold E opens site"): return false
		if not await _c_choose("wait for his round.") or not await _c_choose("strip them.") or not await _c_choose("the front desk. wave at dennis."): return false
		if not _c_transaction("copper",before,{"id":"cold_not","entry":"wait for his round.","exit":"the front desk. wave at dennis.","ordinal":attempt+1}): return false
	await _c_capture("earned_copper")
	if not await _visit("conductor") or not await _open_target("conductor") or not await _c_choose("sell 3 PURE COPPER. $90.","conductor",{"id":"conductor"}): return false
	if not await _visit("tony"): return false
	for purchase: int in range(3):
		if not await _open_target("tony") or not await _c_choose("buy a rock.","buy_rock",{"id":"tony","ordinal":purchase+1}): return false
	if not await _c_smoke("street"): return false
	return _check(game.runtime.p.faction.street >= 10 and game.runtime.p.rocks == 2 and game.runtime.p.copper >= 3,"earned street gate and reserved rocks/copper")

func _c_claims() -> bool:
	_c_phase("claims")
	for id: String in CLAIM_ORDER:
		if not await _c_office_open() or not await _c_choose("open district claims.") or not await _c_choose(CLAIM_NAMES[id]+" · open a survey file."): return false
		if not await _c_field("claim:"+id+":survey"): return false
		if not await _c_office_open() or not await _c_choose("file "+CLAIM_NAMES[id].to_lower()+".","claim_file",{"id":id}): return false
		if game.runtime.s.mode == "dialogue" and not await _c_choose("leave the office."): return false
		if not await _c_field("claim:"+id+":sign","claim_install",{"id":id}): return false
		await _c_capture("claimed_"+id)
	return _check(game.runtime.s.districtClaims.size() == 4 and game.runtime.s.quests.regional_office.done and not game.runtime.s.quests.all_business.done,"minimum four claims only")

func _c_office_open() -> bool:
	if not _check(not game.runtime.s.bossActive and expected_boss.is_empty(),"no cot recovery during an encounter"): return false
	if not await super._office_open(): return false
	while _alive():
		var action: String = cot_action(_summary(),rest_count,game.runtime.s.bossActive or not expected_boss.is_empty())
		if action == "none": return _check(game.runtime.p.hp >= COT_TARGET_HP,"actual Office departure recovery threshold")
		if not _check(action != "refuse","twelve real cot actions and valid living HP"): return false
		if not await _c_choose("use the cot."): return false
		var prefix: String = "rest 30 minutes." if action == "rest" else "sleep until morning."
		if not await _c_choose(prefix,action,{"source":"office:cot","action":action,"boss_active":false}): return false
		_checkpoint("cot:"+action)
		if game.runtime.s.mode == "playing":
			if not await _open_target("office"): return false
		elif game.runtime.s.mode == "dialogue":
			if not await _c_choose("back to the office."): return false
		else: return _check(false,"cot returns through its ordinary menu lifetime")
	return false

func _c_recover() -> bool:
	var action: String = cot_action(_summary(),rest_count,game.runtime.s.bossActive or not expected_boss.is_empty())
	if action == "none": return true
	if not _check(action != "refuse","between-encounter recovery remains bounded"): return false
	if not await _c_office_open(): return false
	return await _c_choose("leave the office.")

func _send_attack(geometry: Dictionary) -> void:
	var before: Dictionary = _summary(); var target: Dictionary = _actor(expected_boss); var hp: float = float(target.get("hp",0)); var prior: int = attack_receipts.size()
	super._send_attack(geometry)
	if attack_receipts.size() == prior: return
	var row: Dictionary = attack_receipts.back(); row.boss_id = expected_boss; row.boss_hp_before = hp; row.boss_hp_after = target.get("hp",0); row.boss_dead = target.get("dead",false)
	var errors: Array[String] = []; var catalog: Dictionary = Content.load_content().catalogs.weapons
	if str(row.before_weapon) != campaign_last_weapon: errors.append("unbacked pre-attack weapon")
	if campaign_last_attack_ms >= 0 and float(row.active_ms)-campaign_last_attack_ms < campaign_last_attack_cd-0.1: errors.append("accepted attack cooldown")
	if row.before_cd != 0 or row.after_cd != catalog.get(str(row.before_weapon),{}).get("cd"): errors.append("assigned source cooldown")
	var events: Array = row.events; var hits: Array = []; var seen_attack := 0; var deaths: Array = []; var toast_weapons: Array = []
	for event: Dictionary in events:
		if event.kind == "player_attack":
			seen_attack += 1; hits = event.payload.get("hits",[])
			if event.payload.get("used_weapon") != row.before_weapon: errors.append("used weapon mismatch")
		if event.kind == "actor_died": deaths.append(event.payload.get("actor_id"))
		if event.kind == "toast":
			for id: String in ["pipe","brick","baguette","shoe"]:
				if event.payload.get("text") == "+ "+str(catalog[id].n)+"\n(equipped.)": toast_weapons.append(id)
	if seen_attack != 1: errors.append("exact accepted attack event")
	if row.after_weapon != row.before_weapon:
		var changed: String = str(row.after_weapon); var backing := false
		if changed == "shoe": backing = "tony" in deaths and "tony" in hits and game.runtime.s.quests.fallen_king.done
		elif changed in ["brick","baguette"]: backing = ("lurch" if changed == "brick" else "paulie") in deaths and ("lurch" if changed == "brick" else "paulie") in hits
		if not backing or changed not in toast_weapons: errors.append("unbacked source weapon reward")
	for error: String in errors: campaign_weapon_errors.append(error); _check(false,error)
	campaign_last_weapon = str(row.after_weapon); campaign_last_attack_ms = row.active_ms; campaign_last_attack_cd = row.after_cd
	if REWARDS.has(expected_boss) and expected_boss not in before.kingdom.defeats and expected_boss in game.runtime.s.kingdom.defeats:
		campaign_reward_rows[expected_boss] = true; _c_transaction("kingdom_reward",before,{"id":expected_boss})

func _c_combat_target() -> Dictionary:
	var boss: Dictionary = _actor(expected_boss); var nearest: Dictionary = boss; var gap := 65.0
	for actor: Dictionary in game.runtime.state.npcs:
		if actor.get("dead",false) or not actor.get("hostile",false) or actor.get("essential",false): continue
		var distance: float = _center(actor).distance_to(game.runtime.state.player_center())
		if distance < gap: gap = distance; nearest = actor
	return nearest

func _c_battle(id: String,started: int,bits: int,admission: Dictionary = {}) -> bool:
	var body: Dictionary = _actor(id); var first: int = attack_receipts.size(); var errors_before: int = campaign_weapon_errors.size()
	var row := {"id":id,"started":game.runtime.s.bossActive and expected_boss == id,"initial_hp":body.get("hp"),"mark_bits_before":bits,"admission":admission,"first_attack_weapon":game.runtime.p.weapon,"phase_seen":[],"adds":[],"won":false}
	if not _check(row.started and row.initial_hp == BOSS_HP[id],"canonical actual boss admission: "+id): return false
	combat_plan = {}; combat_replans = 0; combat_last_plan = -1000; decision_wall = -1000
	await _c_capture("admitted_"+id)
	while game.runtime.s.bossActive and _alive() and Time.get_ticks_msec()-started < 90000:
		var phase: int = observed_boss_phase(id,game.runtime.s,body)
		if not _check(phase > 0,"actual source boss phase available: "+id): break
		if phase not in row.phase_seen:
			row.phase_seen.append(phase)
			if phase == 3 and id in ["tony","curb_emperor"]: await _c_capture(id+"_phase_three")
		for actor: Dictionary in game.runtime.state.npcs:
			if (str(actor.id).begins_with("sherri_boss_") if id == "tony" else str(actor.id).begins_with("kingdom_add_"+id+"_")):
				if actor.id not in row.adds: row.adds.append(actor.id)
		_combat_input(_c_combat_target()); await game.frame_sampled
	_release()
	row.wall_ms = Time.get_ticks_msec()-started; row.accepted_attacks = attack_receipts.size()-first; row.source_damage = false
	for attack: Dictionary in attack_receipts.slice(first):
		if attack.boss_id == id and attack.boss_hp_after < attack.boss_hp_before:
			for event: Dictionary in attack.events:
				if event.kind == "actor_hit" and event.payload.get("actor_id") == id and event.payload.get("damage",0) > 0: row.source_damage = true
	row.defeat = (body.get("dead",false) and game.runtime.s.quests.fallen_king.done) if id == "tony" else id in game.runtime.s.kingdom.defeats
	row.won = row.defeat and not game.runtime.s.bossActive; row.victory_weapon = game.runtime.p.weapon
	row.cooldowns_valid = campaign_weapon_errors.size() == errors_before; row.weapon_chain_valid = campaign_weapon_errors.is_empty(); row.replans = combat_replans
	campaign_battles.append(row)
	for error: String in assess_battle(row): _check(false,id+": "+error)
	if not _alive(): return false
	expected_boss = ""; await _c_capture("victory_"+id)
	return true

func _c_ending(id: String) -> bool:
	expected_ending = id; var started: int = Time.get_ticks_msec()
	while game.runtime.s.mode != "ending" and _alive() and Time.get_ticks_msec()-started < 8000:
		_combat_input(_c_combat_target()); await game.frame_sampled
	if not _check(game.runtime.s.mode == "ending","actual delayed ending: "+id): return false
	await _c_capture("ending_"+id)
	while (game.saving or not game.pending_save.is_empty()) and _alive() and Time.get_ticks_msec()-started < 15000: await game.frame_sampled
	_key(KEY_SPACE)
	var continued: bool = game.runtime.s.mode == "playing"
	campaign_endings.append({"id":id,"seen":true,"continued":continued,"elapsed_ms":Time.get_ticks_msec()-started})
	expected_ending = ""
	return _check(continued,"real ending Space retains campaign")

func _c_tony() -> bool:
	_c_phase("tony")
	if not await _c_recover() or not await _visit("tony"): return false
	for short_index: int in range(2):
		if not await _open_target("tony") or not await _c_choose("short him.","short",{"id":"tony"}): return false
	if not await _c_smoke("tony") or not await _visit("tony") or not await _open_target("tony"): return false
	expected_boss = "tony"; expected_ending = "tony"; var started: int = Time.get_ticks_msec()
	if not await _c_choose("short him.","short",{"id":"tony"}) or not await _c_battle("tony",started,0): return false
	if not await _c_ending("tony"): return false
	return _check(game.runtime.s.kingdom.stage == "summons" and game.runtime.p.rocks == 1,"actual Tony unlock and reserved royal rock")

func _c_court(clan: String,boss: String) -> bool:
	if phase_name != clan: _c_phase(clan)
	if not await _c_recover(): return false
	for index: int in range(3):
		if not await _c_field("kingdom_mark:%s:%d" % [clan,index],"mark",{"id":clan,"bit":1<<index}): return false
	await _c_capture(clan+"_three_corrections")
	var banner: String = "kingdom_banner:"+clan
	if not await _visit(banner) or not await _reach_service(banner): return false
	var bits: int = game.runtime.s.kingdom.marks; var admission: Dictionary = _c_endpoint(banner)
	expected_boss = boss; var started: int = Time.get_ticks_msec(); _key(KEY_E)
	return await _c_battle(boss,started,bits,admission)

func _c_persist() -> bool:
	_c_phase("persistence")
	var waiting: int = Time.get_ticks_msec()
	while not active_smoke.is_empty() and _alive() and Time.get_ticks_msec()-waiting < 28000: _release(); await game.frame_sampled
	if not _check(active_smoke.is_empty(),"royal18s/8s loop complete before persistence"): return false
	_release(); _key(KEY_ESCAPE)
	if not await _c_choose("remember this."): return false
	waiting = Time.get_ticks_msec()
	while (game.saving or not game.pending_save.is_empty()) and _alive() and Time.get_ticks_msec()-waiting < 10000: await game.frame_sampled
	var before: Dictionary = game.runtime.state.snapshot(); var payload: String = FileAccess.get_file_as_string(game.store.save_path)
	var saved: Variant = JSON.parse_string(payload)
	if not _check(saved is Dictionary and not game.save_failed,"durable completed campaign file"): return false
	allowed_epochs += 1
	if not await _c_choose("remember before."): return false
	waiting = Time.get_ticks_msec()
	while (game.loading or game.replacements.size() < allowed_epochs) and _alive() and Time.get_ticks_msec()-waiting < 10000: await game.frame_sampled
	var after: Dictionary = game.runtime.state.snapshot(); var equal := true
	for key: String in ["cash","copper","weapon","equip","inventory","rocks","lifetime"]: equal = equal and _same(before.player.get(key),saved.player.get(key)) and _same(saved.player.get(key),after.player.get(key))
	for key: String in ["office","districtClaims","kingdom","quests"]: equal = equal and _same(before.state.get(key),saved.state.get(key)) and _same(saved.state.get(key),after.state.get(key))
	if not await _c_choose("continue."): return false
	var origin: Vector3 = game.player.position; var moved := false
	for direction: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		var target: Vector3 = origin+Vector3(direction.x,0,direction.y)*0.75
		if not _combat_segment(origin,target).ok: continue
		moved = await _walk_to(target); break
	campaign_persistence = {"ok":game.replacements.size() == allowed_epochs,"durable_equal":equal,"resumed_motion":moved and game.player.position.distance_to(origin) > 0.35,"save_sha256":payload.sha256_text(),"before":before,"stored":saved,"after":after}
	await _c_capture("completed_loaded_and_moving")
	return _check(equal and campaign_persistence.resumed_motion,"exact completed persistence and real resumed motion")

func _source_hashes(directory: String = "res://scripts",result: Dictionary = {}) -> Dictionary:
	var access := DirAccess.open(directory)
	if access == null: return {}
	var files: PackedStringArray = access.get_files(); files.sort()
	for name: String in files:
		if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".json"):
			var path: String = directory.path_join(name); result[path] = FileAccess.get_sha256(path)
	var folders: PackedStringArray = access.get_directories(); folders.sort()
	for name: String in folders:
		if not name.begins_with("."): _source_hashes(directory.path_join(name),result)
	if directory == "res://scripts":
		if DirAccess.dir_exists_absolute("res://shaders"): _source_hashes("res://shaders",result)
		_source_hashes("res://data",result); result["res://project.godot"] = FileAccess.get_sha256("res://project.godot")
	result["res://data/source_content.json"] = FileAccess.get_sha256("res://data/source_content.json")
	return result

func _c_checkpoint_tony() -> bool:
	var waiting: int = Time.get_ticks_msec()
	while not active_smoke.is_empty() and _alive() and Time.get_ticks_msec()-waiting < 28000:
		_combat_input(_c_combat_target()); await game.frame_sampled
	if not _check(active_smoke.is_empty(),"both prefix18s/8s loops fully observed"): return false
	_release(); _finish_phase()
	var preview: Dictionary = _campaign_report().duplicate(true); preview.format = "rock-bottom-campaign-tony-prefix"
	for error: String in assess_prefix_content(preview): _check(false,"prefix before save: "+error)
	if not _alive(): return false
	_key(KEY_ESCAPE)
	if not await _c_choose("remember this."): return false
	var menu_receipt: Dictionary = receipts.back().duplicate(true); waiting = Time.get_ticks_msec()
	while (game.saving or not game.pending_save.is_empty()) and _alive() and Time.get_ticks_msec()-waiting < 10000: await game.frame_sampled
	if not _check(not game.saving and game.pending_save.is_empty() and not game.save_failed,"real prefix Pause save completed"): return false
	var payload: String = FileAccess.get_file_as_string(game.store.save_path); var stored: Variant = JSON.parse_string(payload)
	if not _check(stored is Dictionary,"real prefix saved snapshot readable"): return false
	var copy_path: String = output.path_join("earned-tony-handoff.json")
	if not _check(not FileAccess.file_exists(copy_path) and DirAccess.copy_absolute(game.store.save_path,copy_path) == OK,"immutable earned Tony save copied without overwrite"): return false
	var prefix: Dictionary = _campaign_report().duplicate(true); prefix.format = "rock-bottom-campaign-tony-prefix"
	prefix.checkpoint = {"saved_through_pause":true,"menu_receipt":menu_receipt,"save_completed":true,"save_sha256":FileAccess.get_sha256(copy_path),"before":game.runtime.state.snapshot(),"stored":stored,"path":copy_path}
	prefix.scope = "Actual earned native prefix only: resources, minimum4claims, Tony/ending and two complete18s/8s loops. Real Pause save. No Kingdom completion/Web/performance claim."
	for error: String in assess_prefix(prefix): _check(false,"prefix checkpoint: "+error)
	if not _alive(): return false
	prefix.acceptance = true; prefix.status = "complete"; prefix.failures = []; prefix.diagnostic = diagnostic
	var report_path: String = output.path_join("campaign-tony-prefix.json")
	if not _check(not FileAccess.file_exists(report_path),"prefix report never overwrites retained evidence"): return false
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	if not _check(file != null,"prefix evidence writable"): return false
	file.store_string(JSON.stringify(prefix,"\t")); file.close()
	tony_prefix_report = prefix
	tony_checkpoint_info = {"report":report_path,"report_sha256":FileAccess.get_sha256(report_path),"save":copy_path,"save_sha256":prefix.checkpoint.save_sha256,"accepted_prefix_only":true}
	_checkpoint("accepted_tony_prefix_retained")
	if stop_after_tony: return true
	return await _c_choose("continue.")

func _campaign_scenario() -> bool:
	if not await _c_resources() or not await _c_claims() or not await _c_tony(): return false
	if not await _c_checkpoint_tony(): return false
	if stop_after_tony: return true
	return await _c_kingdom_scenario()

func _c_kingdom_scenario() -> bool:
	_c_phase("blue_tarp")
	if not await _c_office_open() or not await _c_choose("open the hostile correspondence.") or not await _c_choose("answer the frequency.","summons",{"id":"office"}): return false
	if not await _c_court("blue_tarp","darryl_under_blue") or not await _c_court("cart_cavalry","general_receipt") or not await _c_court("copper_choir","bishop_wire"): return false
	_c_phase("anoint")
	if not await _c_recover() or not await _c_smoke("royal"): return false
	await _c_capture("royal_static_real_rock")
	_c_phase("emperor")
	if not await _visit("kingdom_banner:throne") or not await _reach_service("kingdom_banner:throne"): return false
	var admission: Dictionary = _c_endpoint("kingdom_banner:throne")
	expected_boss = "curb_emperor"; expected_ending = "kingdom"; var started: int = Time.get_ticks_msec(); _key(KEY_E)
	if not await _c_battle("curb_emperor",started,0,admission) or not await _c_ending("kingdom"): return false
	return await _c_persist()

func _campaign_report() -> Dictionary:
	var row: Dictionary = _base_campaign_report()
	row.source_hashes = immutable_source_hashes.duplicate(true); row.driver_sha256 = FileAccess.get_sha256(get_script().resource_path)
	row.court_defenses = court_defenses.duplicate(true); row.tony_checkpoint = tony_checkpoint_info.duplicate(true)
	if resume_tony:
		row.format = "rock-bottom-campaign-kingdom-suffix"; row.resume = resume_info.duplicate(true); row.loaded_input = resume_input_snapshot.duplicate(true)
		row.scope = "Actual native Kingdom suffix loaded from immutable accepted Tony prefix; four boss fights plus separately referenced original Tony proof. Two runs, no fabricated continuous run/Web/performance claim."
	return row

func _base_campaign_report() -> Dictionary:
	var deaths := 0; var arrests := 0; var escapes := 0
	for event: Dictionary in game.trace:
		if event.kind == "death": deaths += 1
		if event.kind == "arrest": arrests += 1
		if event.kind == "toast" and str(event.payload.get("text","")).begins_with("the appeal is recessed."): escapes += 1
	return {"schema":1,"format":"rock-bottom-campaign-continuation","input":campaign_input,"initial":campaign_initial,"final":_summary(),"transactions":campaign_transactions,"battles":campaign_battles,"smoke_loops":campaign_smokes,"pending_smoke":active_smoke,"endings":campaign_endings,"persistence":campaign_persistence,"phase_states":phases,"current_phase":phase_name,"state_writes":0,"deaths":deaths,"arrests":arrests,"escapes":escapes,"unexpected_epochs":maxi(0,game.replacements.size()-allowed_epochs),"bounded":not game.overflow and captures.size() <= 24 and game.samples.size() <= 3600 and game.trace.size() <= 40000 and campaign_transactions.size() <= 80 and legs.size() <= 96 and receipts.size() <= 256 and walking.size() <= 1024 and combat_navigation.size() <= 2048 and attack_receipts.size() <= 3000,"wall_ms":Time.get_ticks_msec()-began_wall,"active_ms":game.admitted_ms,"input_counts":inputs,"captures":captures,"weapon_errors":campaign_weapon_errors,"attack_receipts":attack_receipts,"events":game.trace,"samples":game.samples,"legs":legs,"menus":receipts,"walking":walking,"combat_navigation":combat_navigation,"rest_count":rest_count,"day_events":(game as CampaignObservedScene).day_receipts.duplicate(true),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Native normal-input continuation of retained fixture-declared Office handoff; minimum4claims and Kingdom, not all11claims/Web/performance."}

func _refuse_admission(reasons: Array[String],binding: Dictionary) -> void:
	var report := {"schema":1,"format":"rock-bottom-campaign-admission-failure","status":"failed","acceptance":false,"phase":"admission","failures":reasons.duplicate(),"binding":binding.duplicate(true),"driver_sha256":FileAccess.get_sha256(get_script().resource_path),"source_hashes":immutable_source_hashes.duplicate(true),"scene_created":false,"input_save_copied":false,"scope":"Admission only; no native campaign or suffix actions occurred. Original evidence is unchanged."}
	if not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output) and DirAccess.make_dir_recursive_absolute(output) == OK:
		var file := FileAccess.open(output.path_join("campaign-admission-failure.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
		else: push_error("Admission failure report could not be written: "+output)
	else: push_error("Admission failure output unavailable or already exists: "+output)
	for reason: String in reasons: push_error("Campaign admission: "+reason)
	quit(1)

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args(); var error: String = launch_error(arguments)
	if not error.is_empty() or DisplayServer.get_name() == "headless": push_error("Campaign native launch refused: "+error); quit(1); return
	var handoff := ""; var parent_path := ""; var save_pin := ""; var report_pin := ""
	for argument: String in arguments:
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument.begins_with("--handoff="): handoff = argument.trim_prefix("--handoff=")
		elif argument.begins_with("--parent-report="): parent_path = argument.trim_prefix("--parent-report=")
		elif argument == "--diagnostic": diagnostic = true
		elif argument == "--stop-after-tony": stop_after_tony = true
		elif argument == "--resume-tony": resume_tony = true
		elif argument.begins_with("--handoff-sha="): save_pin = argument.trim_prefix("--handoff-sha=")
		elif argument.begins_with("--parent-sha="): report_pin = argument.trim_prefix("--parent-sha=")
	if DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output): push_error("Campaign output already exists"); quit(1); return
	var binding := {"save_path":handoff,"report_path":parent_path,"expected_save_sha256":save_pin if resume_tony else HANDOFF_SHA,"expected_report_sha256":report_pin if resume_tony else PARENT_SHA,"actual_save_sha256":FileAccess.get_sha256(handoff),"actual_report_sha256":FileAccess.get_sha256(parent_path),"resume_tony":resume_tony}
	var admission_errors: Array[String] = []
	if binding.actual_save_sha256 != binding.expected_save_sha256: admission_errors.append("raw save hash differs: expected="+str(binding.expected_save_sha256)+" actual="+str(binding.actual_save_sha256))
	if binding.actual_report_sha256 != binding.expected_report_sha256: admission_errors.append("raw report hash differs: expected="+str(binding.expected_report_sha256)+" actual="+str(binding.actual_report_sha256))
	if not admission_errors.is_empty(): _refuse_admission(admission_errors,binding); return
	var parent: Variant = JSON.parse_string(FileAccess.get_file_as_string(parent_path))
	immutable_source_hashes = _source_hashes()
	if resume_tony:
		var saved_input: Variant = JSON.parse_string(FileAccess.get_file_as_string(handoff))
		admission_errors = resume_admission_errors(parent,saved_input,save_pin,immutable_source_hashes)
		if not admission_errors.is_empty(): _refuse_admission(admission_errors,binding); return
		tony_prefix_report = parent.duplicate(true); resume_input_snapshot = saved_input.duplicate(true)
		resume_info = {"prefix_accepted":true,"report_sha256":report_pin,"save_sha256":save_pin,"report_path":parent_path,"save_path":handoff,"continuous_run":false}
	elif not parent is Dictionary or parent.get("acceptance") != true:
		_refuse_admission(["parent Office report JSON is invalid or acceptance is not true"],binding); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: push_error("Campaign output unavailable"); quit(1); return
	campaign_output_owned = true
	var copied: String = output.path_join("campaign-save.json")
	if DirAccess.copy_absolute(handoff,copied) != OK: push_error("Could not preserve exact handoff bytes"); quit(1); return
	campaign_input = parent.input.duplicate(true) if resume_tony else {"handoff_sha256":HANDOFF_SHA,"parent_report_sha256":PARENT_SHA,"parent_accepted":true,"fixture_writes":0,"parent_fixture":parent.get("fixture"),"input_path":handoff,"parent_path":parent_path}
	root.size = Vector2i(1280,720); Engine.max_fps = 60
	game = CampaignObservedScene.new(); game.qa_mode = true; root.add_child(game)
	var boot: int = Time.get_ticks_msec()
	while not game.ready_for_play and Time.get_ticks_msec()-boot < 120000: await process_frame
	if not game.ready_for_play:
		var failed_boot := FileAccess.open(output.path_join("campaign-continuation.json"),FileAccess.WRITE)
		if failed_boot != null:
			failed_boot.store_string(JSON.stringify({"schema":1,"format":"rock-bottom-campaign-continuation","input":campaign_input,"status":"failed","acceptance":false,"failures":["cold title watchdog"],"phase":"cold_start","wall_ms":Time.get_ticks_msec()-boot})); failed_boot.close()
		push_error("Campaign cold title watchdog"); await _shutdown(1); return
	game.store.save_path = copied; game.store.storage_key = "rockbottom_campaign_continuation_qa"
	if resume_tony: rest_count = int(parent.rest_count)
	began_wall = Time.get_ticks_msec(); last_frame_wall = began_wall; campaign_started = true; _c_phase("load")
	if not await _c_choose("remember."): await _finish_campaign(); return
	var waiting: int = Time.get_ticks_msec()
	while game.loading and Time.get_ticks_msec()-waiting < 15000: await game.frame_sampled
	if not _check(not game.loading and game.runtime.s.office.owned,"actual retained load completes"): await _finish_campaign(); return
	campaign_initial = _summary(); campaign_last_weapon = str(game.runtime.p.weapon); game.start_audit(); game.frame_sampled.connect(_tick_campaign)
	if resume_tony: _check(checkpoint_durable_equal(resume_input_snapshot,game.runtime.state.snapshot()),"actual title load retains exact earned prefix state")
	else:
		for initial_error: String in assess_initial(campaign_initial): _check(false,initial_error)
	if not failures.is_empty(): await _finish_campaign(); return
	if not await _c_choose("continue."): await _finish_campaign(); return
	if not resume_tony and not _check(resource_plan(campaign_initial).ok,"finite authentic resource plan"): await _finish_campaign(); return
	await _c_capture("accepted_tony_prefix_loaded" if resume_tony else "retained_office_loaded")
	if resume_tony: await _c_kingdom_scenario()
	else: await _campaign_scenario()
	if stop_after_tony and failures.is_empty() and tony_prefix_report.get("acceptance") == true:
		finish_latch.begin(Time.get_ticks_msec()); _release()
		print("CAMPAIGN TONY PREFIX: PASS; accepted earned checkpoint only; ",output)
		await _shutdown(0); return
	await _finish_campaign()

func _finish_campaign() -> void:
	if not finish_latch.begin(Time.get_ticks_msec()): return
	if not is_instance_valid(game) or game.runtime == null: _force_failed_exit("campaign finalization before scene ready"); return
	_release(); _update_smoke(); _finish_phase()
	var report: Dictionary = _campaign_report()
	var result_errors: Array[String] = assess_suffix(report,tony_prefix_report) if resume_tony else assess_campaign(report)
	for error: String in result_errors: _check(false,error)
	if not failures.is_empty(): await _capture_failure(); report.failure_context = failure_context
	report.acceptance = failures.is_empty(); report.failures = failures.duplicate(); report.diagnostic = diagnostic; report.status = "complete" if failures.is_empty() else "failed"; report.captures = captures
	var file := FileAccess.open(output.path_join("campaign-kingdom-suffix.json" if resume_tony else "campaign-continuation.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	if resume_tony:
		var aggregate := {"schema":1,"format":"rock-bottom-campaign-two-run-aggregate","runs":2,"continuous_run":false,"prefix":tony_prefix_report,"suffix":report,"five_bosses":tony_prefix_report.get("battles",[])+report.get("battles",[]),"prefix_report_sha256":resume_info.get("report_sha256"),"suffix_report_sha256":FileAccess.get_sha256(output.path_join("campaign-kingdom-suffix.json")),"scope":"Two native runs: immutable earned prefix plus normal-input Kingdom suffix; not a continuous run, Web or performance acceptance."}
		for error: String in assess_aggregate(aggregate): _check(false,error)
		aggregate.acceptance = failures.is_empty(); aggregate.failures = failures.duplicate(); aggregate.status = "complete" if failures.is_empty() else "failed"
		file = FileAccess.open(output.path_join("campaign-two-run-aggregate.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(aggregate,"\t")); file.close()
	print("CAMPAIGN COMPOSED: " if resume_tony else "CAMPAIGN CONTINUATION: ","PASS" if failures.is_empty() else "FAIL","; five actual referenced fights; four claims; ",output)
	await _shutdown(0 if diagnostic or failures.is_empty() else 1)
