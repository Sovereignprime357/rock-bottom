extends SceneTree
## Detached evidence/receipt counterexamples. This never runs or accepts a native tour.
const Probe = preload("campaign_continuation_probe.gd")
const Campaign = preload("res://scripts/campaign_system.gd")
const HANDOFF_SHA := "dc13e35bc438725c69fd9d41299b85bb0665fb0a776abc9314cb6c035d0bc066"
const PARENT_SHA := "002bf2fb7f9ecb59e826b2f9a964f3049d93cc4ecc7a38f217cfac4bcc304708"
const RETAINED_PREFIX_SHA := "6cb8aa6a7b21c9e8cc3b7b97eb2752f74c78fe173c1069e7ff150c60ebe836fa"
const RETAINED_SAVE_SHA := "5de5c3210a855e8f7cfd98945439bce1dc30a906cb7108bea079388d877d112a"
const BOSSES := {"tony":200,"darryl_under_blue":180,"general_receipt":200,"bishop_wire":210,"curb_emperor":280}
var checks := 0
var failures: Array[String] = []
var completed_groups := 0

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initial() -> Dictionary:
	return {"cash":79,"copper":0,"hp":100.0,"max_hp":100.0,"brain":77.0,"shakes":100.0,"day_time":0.3,"rng":42,
		"counters":{"stripeFencedToday":0,"barbPacketsToday":0,"peteCashToday":0,"heistsToday":0,"robberiesToday":0,"breakinsToday":0},"hustles":[{"id":"one"},{"id":"two"},{"id":"three"}],"hustle_snapshot":{"bigPan":0},"weapon":"pipe","street":6,"rocks":0,
		"rocks_smoked":3,"high":0.0,"crash":0.0,"offenses":0,"cred":21,"day":3,
		"claims":{"canal":true},"office_jobs":1,"routes":3,"heists":0,"wanted":0.0,"charisma":0,
		"office":{"owned":true,"jobsCompleted":1,"workToday":0,"workDay":3,"lastWorkId":"canal","orderSerial":2,
			"claimJob":null,"workJob":{"id":"canal","serial":2,"stage":"inspect"},
			"upgrades":{"cot":true,"desk":true,"radio":true,"locker":false,"generator":false,"route_board":false}},
		"kingdom":{"stage":"locked","marks":0,"bossId":"","defeats":[]},
		"fallen_king":false,"royal_static":false,"one_cracklord":false,
		"source_position":{"x":4867.67529296875,"y":3220.14428710938},"inventory":[],
		"equip":{"hat":null,"coat":null,"shoes":null,"tool":null}}

func _errors(domain: String,row: Dictionary) -> Array[String]:
	match domain:
		"transaction": return Probe.assess_transaction(row)
		"battle": return Probe.assess_battle(row)
		"smoke": return Probe.assess_smoke(row)
		_: return Probe.assess_campaign(row)

func _bad(domain: String,base: Dictionary,path: Array,value: Variant,label: String) -> void:
	var edited: Dictionary = base.duplicate(true)
	var cursor: Variant = edited
	for index: int in range(path.size()-1): cursor = cursor[path[index]]
	cursor[path[-1]] = value
	_check(not _errors(domain,edited).is_empty(),label)

func _accept(domain: String,row: Dictionary,label: String) -> void:
	var original: Dictionary = row.duplicate(true)
	var errors: Array[String] = _errors(domain,row)
	_check(errors.is_empty(),label+": "+str(errors))
	_check(row == original,"assessor is read-only: "+label)

func _endpoint(service: String,limit: float) -> Dictionary:
	return {"service":service,"resolved_kind":"kingdom_target","resolved_id":service,
		"source_distance":40.0,"limit":limit,"reachable":true,"frame":10,"command_frame":10}

func _transaction(kind: String) -> Dictionary:
	var before: Dictionary = _initial()
	var after: Dictionary = before.duplicate(true)
	var details := {"id":"","cost":0,"yield":0,"street_before":6,"heist_counter_before":0,"day":3}
	match kind:
		"work":
			before.office.workJob.stage = "file"; after = before.duplicate(true)
			details.id = "canal"; after.cash += 6; after.office.jobsCompleted += 1; after.office_jobs += 1
			after.office.workToday += 1; after.office.workJob = null
		"copper":
			details.id = "cold_not"; details["yield"] = 2; after.copper += 2; after.heists += 1
			details["entry"] = "wait for his round."; details["exit"] = "the front desk. wave at dennis."
		"conductor":
			before.copper = 6; after = before.duplicate(true)
			details.id = "conductor"; after.copper -= 3; after.cash += 90
		"buy_rock":
			details.id = "tony"; details.cost = 10
			after.cash -= 10; after.rocks += 1; after.street += 1
		"short":
			details.id = "tony"; details.cost = 5
			after.cash -= 5; after.offenses += 1
		"claim_file":
			before.street = 10; before.copper = 3; before.office.workJob = null
			before.office.claimJob = {"id":"alley","stage":"file"}; after = before.duplicate(true)
			details.id = "alley"; details.cost = 25; details.street_before = 10
			after.cash -= 25; after.copper -= 1; after.office.claimJob.stage = "install"
		"claim_install":
			before.street = 10; before.office.workJob = null
			before.office.claimJob = {"id":"alley","stage":"install"}; after = before.duplicate(true)
			details.id = "alley"; details.street_before = 10
			after.claims.alley = true; after.cred += 2; after.office.claimJob = null
		"mark":
			before.kingdom.stage = "tarp_marks"; after = before.duplicate(true)
			details.id = "blue_tarp"; details["bit"] = 1; details["index"] = 0
			details["endpoint"] = _endpoint("kingdom_mark:blue_tarp:0",58.0)
			after.kingdom.marks = 1
		"summons":
			before.kingdom.stage = "summons"; before.fallen_king = true
			before.claims = {"canal":true,"alley":true,"projects":true,"skidrow":true}; after = before.duplicate(true)
			details.id = "accept"; after.kingdom.stage = "tarp_marks"
		"rest", "sleep":
			before.hp = 80.0 if kind == "rest" else 40.0
			before.shakes = 80.0; before.wanted = 2.0
			if kind == "sleep": before.day_time = 0.7; before.heists = 3; before.counters.heistsToday = 3; before.office.workToday = 1
			after = before.duplicate(true)
			details.id = "office:cot"; details["source"] = "office:cot"; details["action"] = kind; details["boss_active"] = false; details["events"] = []; details["day_events"] = []
			after.hp = 90.0 if kind == "rest" else 95.0; after.wanted = 1.0 if kind == "rest" else 0.0
			if kind == "sleep":
				after.brain = 100.0; after.shakes = 95.0; after.day = 4; after.day_time = 0.3; after.office.workDay = 4; after.office.workToday = 0
				after.heists = 0; after.counters.heistsToday = 0; after.rng = 128
				details.day_events.append({"kind":"day_started","payload":{"day":4,"cause":"office_sleep","handled":true}})
	return {"kind":kind,"before":before,"after":after,"details":details}

func _battle(id: String) -> Dictionary:
	var row := {"id":id,"started":true,"won":true,"wall_ms":42000.0,"initial_hp":BOSSES[id],
		"defeat":true,"accepted_attacks":12,"cooldowns_valid":true,"source_damage":true,
		"mark_bits_before":7 if id in ["darryl_under_blue","general_receipt","bishop_wire"] else 0,
		"first_attack_weapon":"pipe" if id == "tony" else "shoe","victory_weapon":"shoe","weapon_chain_valid":true}
	row["phase_seen"] = [1,2,3] if id in ["tony","curb_emperor"] else [1]
	row["adds"] = ["sherri_boss_1","sherri_boss_2"] if id == "tony" else ["kingdom_add_%s_0" % id,"kingdom_add_%s_1" % id]
	var banners := {"darryl_under_blue":"blue_tarp","general_receipt":"cart_cavalry","bishop_wire":"copper_choir","curb_emperor":"throne"}
	if banners.has(id): row["admission"] = _endpoint("kingdom_banner:"+str(banners[id]),72.0)
	return row

func _smoke(kind: String) -> Dictionary:
	var before: Dictionary = _initial()
	before.street = 9 if kind == "street" else (10 if kind == "tony" else 11)
	before.rocks = 3 if kind == "street" else (2 if kind == "tony" else 1)
	if kind == "royal": before.kingdom.stage = "anoint"
	var after: Dictionary = before.duplicate(true)
	after.rocks -= 1; after.street += 1; after.rocks_smoked += 1; after.cred += 1
	after.high = 18000.0; after.crash = 0.0
	if kind == "royal": after.kingdom.stage = "emperor_gate"; after.kingdom.marks = 0; after.royal_static = true
	return {"kind":kind,"before":before,"after":after,"initial_high":18000.0,"consumed":1,"high_ms":18000.0,"crash_ms":8000.0}

func _launch_checks() -> void:
	var good := PackedStringArray(["--qa-full","--output=C:/qa/campaign-new-run","--handoff=C:/qa/earned-handoff.json","--parent-report=C:/qa/office-tour.json"])
	_check(Probe.launch_error(good).is_empty(),"explicit full launch and three absolute paths are accepted syntactically")
	var diagnostic: PackedStringArray = good.duplicate(); diagnostic.append("--diagnostic")
	_check(Probe.launch_error(diagnostic).is_empty(),"diagnostic changes exit handling, not required launch provenance")
	var duplicate: PackedStringArray = good.duplicate(); duplicate.append("--output=C:/qa/different-run")
	_check(not Probe.launch_error(duplicate).is_empty(),"duplicate output cannot silently redirect evidence")
	for index: int in range(good.size()):
		var missing: PackedStringArray = good.duplicate(); missing.remove_at(index)
		_check(not Probe.launch_error(missing).is_empty(),"each required launch argument must be supplied")
	for flag: String in ["--frames=2","--seed=1","--grant-cash=100","--skip-tony"]:
		var altered: PackedStringArray = good.duplicate(); altered.append(flag)
		_check(not Probe.launch_error(altered).is_empty(),"unknown launch override rejected: "+flag)
	for index: int in range(1,good.size()):
		var relative: PackedStringArray = good.duplicate(); relative[index] = good[index].get_slice("=",0)+"=relative.json"
		_check(not Probe.launch_error(relative).is_empty(),"relative input/output path is not a fresh isolated launch")
	completed_groups += 1

func _resource_checks() -> void:
	var start: Dictionary = _initial(); var original: Dictionary = start.duplicate(true)
	var plan: Dictionary = Probe.resource_plan(start)
	_check(plan.get("ok",false) == true,"retained handoff admits the conservative resource plan")
	_check(plan.get("minimum_cash_before_kingdom") == 40,"minimum2+2+2 yields fund exact6+90-30-90-15 ledger")
	_check(plan.get("minimum_copper_after_claims") == 0,"minimum6 copper leaves zero after3 sale and3 fees")
	_check(start == original,"planning never grants resources or clears the pending work")
	for value: Variant in [0,-1,NAN,INF]:
		var bad: Dictionary = start.duplicate(true); bad.cash = value
		_check(Probe.resource_plan(bad).get("ok",true) == false,"insufficient/invalid starting cash cannot be repaired")
	var exact_floor: Dictionary = start.duplicate(true); exact_floor.cash = 39
	var floor_plan: Dictionary = Probe.resource_plan(exact_floor)
	_check(floor_plan.get("ok",false) and floor_plan.get("minimum_cash_before_kingdom") == 0,"arithmetic helper exposes its exact zero-cash floor without pretending it is the retained handoff")
	for value: Variant in [-1,NAN,INF]:
		var bad: Dictionary = start.duplicate(true); bad.copper = value
		_check(Probe.resource_plan(bad).get("ok",true) == false,"invalid copper cannot inflate the guaranteed reserve")
	completed_groups += 1

func _transaction_checks() -> void:
	for kind: String in ["work","copper","conductor","buy_rock","short","claim_file","claim_install","mark","summons","rest"]:
		_accept("transaction",_transaction(kind),"source-valid "+kind+" receipt")
	var work: Dictionary = _transaction("work")
	_bad("transaction",work,["after","cash"],91,"work pays6 once, not12")
	_bad("transaction",work,["after","office","workJob"],work.before.office.workJob,"filed work must actually clear its contract")
	var copper: Dictionary = _transaction("copper")
	for amount: int in [2,3,4]:
		var yielded: Dictionary = copper.duplicate(true); yielded.details["yield"] = amount; yielded.after.copper = amount
		_accept("transaction",yielded,"all three real copper yield branches remain admissible")
	for amount: int in [1,5]:
		var altered: Dictionary = copper.duplicate(true); altered.details["yield"] = amount; altered.after.copper = amount
		_check(not Probe.assess_transaction(altered).is_empty(),"outside2–4 copper yield rejected even when receipt delta agrees")
	_bad("transaction",copper,["details","id"],"water_dept","earning leg cannot substitute an unapproved site")
	var over_cap: Dictionary = copper.duplicate(true); over_cap.before.heists = 3; over_cap.after.heists = 4
	_check(not Probe.assess_transaction(over_cap).is_empty(),"fourth same-day heist cannot count as earnings")
	_bad("transaction",copper,["details","entry"],"walk in like you are the day shift.","finite route keeps its approved sure entry")
	_bad("transaction",copper,["details","exit"],"the loading dock.","finite route keeps the no-damage exit")
	var sale: Dictionary = _transaction("conductor")
	_bad("transaction",sale,["after","cash"],259,"Conductor cannot pay90 twice")
	_bad("transaction",sale,["after","copper"],6,"Conductor copper payment cannot be omitted")
	var buy: Dictionary = _transaction("buy_rock")
	_bad("transaction",buy,["after","rocks"],0,"cash loss alone cannot stand for a real rock purchase")
	_bad("transaction",buy,["after","street"],6,"Tony purchase supplies its actual street reputation")
	_bad("transaction",buy,["after","cash"],70,"street6 purchase cannot receive the street10 price")
	var liked: Dictionary = buy.duplicate(true)
	liked.before.street = 10; liked.after.street = 11; liked.after.cash = liked.before.cash-9
	_accept("transaction",liked,"incidental earned street10 keeps the actual discounted source price")
	for pair: Array in [[6,9],[10,8]]:
		var charming: Dictionary = buy.duplicate(true)
		charming.before.charisma = 1; charming.after.charisma = 1
		charming.before.street = pair[0]; charming.after.street = int(pair[0])+1
		charming.after.cash = charming.before.cash-int(pair[1])
		_accept("transaction",charming,"actual charisma rounding applies after the street price")
	var short: Dictionary = _transaction("short")
	_bad("transaction",short,["after","cash"],79,"normal Tony short costs5")
	_bad("transaction",short,["after","offenses"],3,"one short cannot manufacture all three offenses")
	var filing: Dictionary = _transaction("claim_file")
	var prior_claims := {"canal":true}
	for pair: Array in [["alley",25],["projects",30],["skidrow",35]]:
		var exact: Dictionary = filing.duplicate(true)
		exact.before.claims = prior_claims.duplicate(true); exact.after.claims = prior_claims.duplicate(true)
		exact.before.office.claimJob.id = pair[0]; exact.after.office.claimJob.id = pair[0]
		exact.details.id = pair[0]; exact.details.cost = pair[1]; exact.after.cash = exact.before.cash-int(pair[1])
		_accept("transaction",exact,"actual claim count supplies the exact fee for "+str(pair[0]))
		_bad("transaction",exact,["after","cash"],exact.after.cash-5,"next claim's fee cannot be silently charged early")
		prior_claims[pair[0]] = true
	_bad("transaction",filing,["after","copper"],3,"claim filing must consume its copper")
	_bad("transaction",filing,["after","cash"],49,"second total claim fee is25, not30")
	_bad("transaction",filing,["before","street"],9,"faction gate must already hold before filing")
	_bad("transaction",filing,["after","office","claimJob","stage"],"file","payment must advance to installation")
	var installed: Dictionary = _transaction("claim_install")
	_bad("transaction",installed,["after","cred"],25,"claim cannot pay its2cred twice")
	_bad("transaction",installed,["after","claims","alley"],false,"real sign installation must durably claim the district")
	var mark: Dictionary = _transaction("mark")
	_bad("transaction",mark,["after","kingdom","marks"],7,"one aimed mark cannot set all three bits")
	for distance: float in [58.0,-1.0,NAN,INF]: _bad("transaction",mark,["details","endpoint","source_distance"],distance,"mark keeps strict finite58px range")
	_bad("transaction",mark,["details","endpoint","command_frame"],11,"last-frame mark certificate cannot authorize this E")
	_bad("transaction",mark,["details","endpoint","reachable"],false,"mark requires actual fresh reachability")
	_bad("transaction",mark,["details","endpoint","resolved_id"],"kingdom_mark:blue_tarp:1","aimed resolver must match the certified mark")
	var wrong_mark: Dictionary = mark.duplicate(true)
	wrong_mark.details.endpoint.service = "kingdom_mark:cart_cavalry:0"; wrong_mark.details.endpoint.resolved_id = "kingdom_mark:cart_cavalry:0"
	_check(not Probe.assess_transaction(wrong_mark).is_empty(),"a self-consistent different court target cannot certify this mark")
	var edge_mark: Dictionary = mark.duplicate(true); edge_mark.details.endpoint.source_distance = 57.999
	_accept("transaction",edge_mark,"mark immediately inside the source boundary remains legal")
	var summons: Dictionary = _transaction("summons")
	_bad("transaction",summons,["after","kingdom","stage"],"tarp_boss","answering radio cannot skip marks and banner")
	var unknown: Dictionary = buy.duplicate(true); unknown.kind = "grant"
	_check(not Probe.assess_transaction(unknown).is_empty(),"unknown transaction cannot launder a grant")
	completed_groups += 1

func _battle_checks() -> void:
	for id: String in BOSSES:
		var good: Dictionary = _battle(id)
		_accept("battle",good,"canonical "+id+" admission and combat receipt")
		_bad("battle",good,["initial_hp"],BOSSES[id]-1,"boss HP cannot be pre-damaged: "+id)
		_bad("battle",good,["wall_ms"],90001.0,"every encounter retains its90-second limit: "+id)
		for key: String in ["started","won","defeat","cooldowns_valid","source_damage","weapon_chain_valid"]:
			_bad("battle",good,[key],false,"missing real combat proof "+key+": "+id)
		_bad("battle",good,["accepted_attacks"],0,"direct fatal HP cannot substitute accepted attacks: "+id)
		_bad("battle",good,["adds"],good.adds.slice(0,1),"one observed add cannot stand for the required two: "+id)
		if id in ["tony","curb_emperor"]:
			_bad("battle",good,["phase_seen"],[1,3],"phase2 cannot be omitted from the real encounter: "+id)
		if id in ["darryl_under_blue","general_receipt","bishop_wire"]:
			_bad("battle",good,["mark_bits_before"],3,"court admission requires all three source mark bits: "+id)
		if id != "tony":
			_bad("battle",good,["admission","source_distance"],72.0,"banner boundary is strictly72px: "+id)
			_bad("battle",good,["admission","command_frame"],11,"banner proof must belong to the actual E frame: "+id)
			_bad("battle",good,["admission","reachable"],false,"banner requires actual current geometry: "+id)
	for duration: float in [-1.0,NAN,INF]: _bad("battle",_battle("tony"),["wall_ms"],duration,"battle duration must be finite and positive")
	_bad("battle",_battle("tony"),["id"],"fake_tony","unknown boss cannot replace a canonical encounter")
	_bad("battle",_battle("tony"),["victory_weapon"],"pipe","Tony source outcome must actually equip his shoe")
	var earned: Dictionary = _battle("darryl_under_blue"); earned.first_attack_weapon = "broken_bottle"
	_accept("battle",earned,"verified incidental weapon chain may use a real alternative weapon")
	var wrong_banner: Dictionary = _battle("darryl_under_blue")
	wrong_banner.admission.service = "kingdom_banner:throne"; wrong_banner.admission.resolved_id = "kingdom_banner:throne"
	_check(not Probe.assess_battle(wrong_banner).is_empty(),"Emperor's consistent banner proof cannot admit Darryl")
	var edge_banner: Dictionary = _battle("curb_emperor"); edge_banner.admission.source_distance = 71.999
	_accept("battle",edge_banner,"banner immediately inside the source boundary remains legal")
	completed_groups += 1

func _smoke_checks() -> void:
	for kind: String in ["street","tony","royal"]:
		var good: Dictionary = _smoke(kind)
		_accept("smoke",good,"real "+kind+" smoke and full loop receipt")
		_bad("smoke",good,["consumed"],0,"real rock payment required: "+kind)
		_bad("smoke",good,["after","rocks"],good.before.rocks,"remaining rocks must match the source debit: "+kind)
		_bad("smoke",good,["after","street"],good.before.street,"actual smoke reputation required: "+kind)
		_bad("smoke",good,["initial_high"],12000.0,"full initial18s high required: "+kind)
		_bad("smoke",good,["high_ms"],0.0,"no skipped high observation: "+kind)
		_bad("smoke",good,["crash_ms"],0.0,"no skipped crash observation: "+kind)
		_bad("smoke",good,["high_ms"],NAN,"nonfinite smoke duration cannot satisfy the loop: "+kind)
	var royal: Dictionary = _smoke("royal")
	_bad("smoke",royal,["before","kingdom","stage"],"wire_marks","royal smoke cannot skip Bishop's actual victory")
	_bad("smoke",royal,["after","kingdom","stage"],"anoint","reserved royal rock must open the Emperor gate")
	_bad("smoke",royal,["after","royal_static"],false,"royal progression must be witnessed, not inferred from consumption")
	var remaining := 3
	var street := 9
	for kind: String in ["street","tony","royal"]:
		var row: Dictionary = _smoke(kind)
		_check(row.before.rocks == remaining and row.before.street == street,"sequential reserved-rock/street witness: "+kind)
		remaining = row.after.rocks; street = row.after.street
	_check(remaining == 0 and street == 12,"three purchases and three real smokes close the source resource arithmetic")
	completed_groups += 1

func _reward(id: String,previous: Array = []) -> Dictionary:
	var pairs := {"darryl_under_blue":[24,18],"general_receipt":[30,22],"bishop_wire":[36,26],"curb_emperor":[60,40]}
	var stages := {"darryl_under_blue":["tarp_boss","cart_marks"],"general_receipt":["cart_boss","wire_marks"],"bishop_wire":["wire_boss","anoint"],"curb_emperor":["emperor_boss","complete"]}
	var before: Dictionary = _initial(); before.cash = 40; before.kingdom.defeats = previous.duplicate()
	before.kingdom.stage = stages[id][0]; before.kingdom.bossId = id
	var after: Dictionary = before.duplicate(true)
	after.cash += int(pairs[id][0]); after.cred += int(pairs[id][1]); after.kingdom.defeats.append(id)
	after.kingdom.stage = stages[id][1]; after.kingdom.bossId = ""
	return {"kind":"kingdom_reward","before":before,"after":after,"details":{"id":id}}

func _reward_checks() -> void:
	var previous: Array = []
	for id: String in ["darryl_under_blue","general_receipt","bishop_wire","curb_emperor"]:
		var good: Dictionary = _reward(id,previous)
		_accept("transaction",good,"exact once-only award for "+id)
		_bad("transaction",good,["after","cash"],good.after.cash+1,"cash reward amount is source-exact: "+id)
		_bad("transaction",good,["after","cred"],good.after.cred+1,"cred reward amount is source-exact: "+id)
		_bad("transaction",good,["after","kingdom","defeats"],previous.duplicate(),"payout needs its durable canonical defeat: "+id)
		var repeated: Dictionary = good.duplicate(true); repeated.before.kingdom.defeats.append(id); repeated.after.kingdom.defeats.append(id)
		_check(not Probe.assess_transaction(repeated).is_empty(),"a repeated award cannot append duplicate defeat: "+id)
		previous.append(id)
	completed_groups += 1

func _report() -> Dictionary:
	# Compact assessor witness: the rows are independent valid source receipts.
	# It is not a fabricated native timeline or an alternate simulation of gameplay.
	var rows: Array = [_transaction("work")]
	for index: int in range(3):
		var strip: Dictionary = _transaction("copper")
		strip.before.heists = index; strip.after.heists = index+1
		strip.before.copper = 2*index; strip.after.copper = 2*(index+1)
		rows.append(strip)
	rows.append(_transaction("conductor"))
	for index: int in range(3):
		var buy: Dictionary = _transaction("buy_rock")
		buy.before.street += index; buy.after.street += index
		buy.before.rocks = index; buy.after.rocks = index+1
		rows.append(buy)
	var claims := {"canal":true}
	for pair: Array in [["alley",25],["projects",30],["skidrow",35]]:
		var filed: Dictionary = _transaction("claim_file")
		filed.details.id = pair[0]; filed.details.cost = pair[1]
		filed.before.claims = claims.duplicate(true); filed.after.claims = claims.duplicate(true)
		filed.before.office.claimJob.id = pair[0]; filed.after.office.claimJob.id = pair[0]
		filed.after.cash = filed.before.cash-int(pair[1]); rows.append(filed)
		var installed: Dictionary = _transaction("claim_install")
		installed.details.id = pair[0]; installed.before.office.claimJob.id = pair[0]
		installed.before.claims = claims.duplicate(true); claims[pair[0]] = true
		installed.after.claims = claims.duplicate(true); rows.append(installed)
	for index: int in range(3):
		var short: Dictionary = _transaction("short")
		short.before.offenses = index; short.after.offenses = index+1; rows.append(short)
	rows.append(_transaction("summons"))
	var previous: Array = []
	for pair: Array in [["blue_tarp","tarp_marks","darryl_under_blue"],["cart_cavalry","cart_marks","general_receipt"],["copper_choir","wire_marks","bishop_wire"]]:
		var bits := 0
		for index: int in range(3):
			var mark: Dictionary = _transaction("mark")
			mark.details.id = pair[0]; mark.details.bit = 1<<index
			mark.details.endpoint = _endpoint("kingdom_mark:%s:%d" % [pair[0],index],58.0)
			mark.before.kingdom.stage = pair[1]; mark.after.kingdom.stage = pair[1]
			mark.before.kingdom.marks = bits; bits |= 1<<index; mark.after.kingdom.marks = bits
			rows.append(mark)
		rows.append(_reward(pair[2],previous)); previous.append(pair[2])
	rows.append(_reward("curb_emperor",previous)); previous.append("curb_emperor")
	var battles: Array = []
	for id: String in BOSSES: battles.append(_battle(id))
	var final_state: Dictionary = _initial()
	final_state.merge({"cash":190,"copper":0,"weapon":"shoe","street":12,"rocks":0,"rocks_smoked":6,"cred":336,
		"claims":claims.duplicate(true),"office_jobs":2,"fallen_king":true,"royal_static":true,"one_cracklord":true},true)
	final_state.office.jobsCompleted = 2; final_state.office.workJob = null
	final_state.kingdom = {"stage":"complete","marks":0,"bossId":"","defeats":previous}
	var phases: Array = []
	for id: String in ["load","resources","claims","tony","blue_tarp","cart_cavalry","copper_choir","anoint","emperor","persistence"]:
		phases.append({"id":id,"wall_ms":1000.0,"active_ms":500.0,"state":final_state.duplicate(true)})
	var images: Array = []
	for index: int in range(20): images.append("synthetic_%02d.png" % index)
	return {"schema":1,"format":"rock-bottom-campaign-continuation",
		"input":{"handoff_sha256":HANDOFF_SHA,"parent_report_sha256":PARENT_SHA,"parent_accepted":true,"fixture_writes":0},
		"initial":_initial(),"final":final_state,"transactions":rows,"battles":battles,
		"smoke_loops":[_smoke("street"),_smoke("tony"),_smoke("royal")],"pending_smoke":{},
		"endings":[{"id":"tony","seen":true,"continued":true},{"id":"kingdom","seen":true,"continued":true}],
		"phase_states":phases,"state_writes":0,"deaths":0,"arrests":0,"escapes":0,"unexpected_epochs":0,
		"bounded":true,"wall_ms":600000.0,"input_counts":{"motion_frames":1000,"mouse_motion":500,"keys":80,"clicks":60,"menu_clicks":10,"capture_clicks":10},
		"captures":images,"weapon_errors":[],"rest_count":0,"events":[],"samples":[],"legs":[],"menus":[],"walking":[],"combat_navigation":[],"attack_receipts":[],
		"persistence":{"ok":true,"durable_equal":true,"resumed_motion":true}}

func _campaign_checks() -> void:
	var good: Dictionary = _report()
	_accept("campaign",good,"complete synthetic report passes its required-proof assessor")
	_check(not Probe.assess_campaign({}).is_empty(),"empty report is never a completed continuation")
	_bad("campaign",good,["input","handoff_sha256"],PARENT_SHA,"wrong retained handoff bytes rejected")
	_bad("campaign",good,["input","parent_report_sha256"],HANDOFF_SHA,"wrong parent report bytes rejected")
	_bad("campaign",good,["input","parent_accepted"],false,"copied report without accepted parent rejected")
	_bad("campaign",good,["input","fixture_writes"],1,"no new initial resource fixture permitted")
	for pair: Array in [["cash",80],["copper",1],["hp",101],["weapon","knife"],["street",10],["routes",4],["office_jobs",2]]:
		_bad("campaign",good,["initial",pair[0]],pair[1],"retained initial fact cannot change: "+str(pair[0]))
	_bad("campaign",good,["initial","office","workJob"],null,"pending source work cannot disappear before continuation")
	_bad("campaign",good,["initial","office","upgrades","radio"],false,"retained radio prerequisite cannot be assumed")
	_bad("campaign",good,["initial","kingdom","stage"],"summons","already-unlocked Kingdom is not the supplied handoff")
	for key: String in ["state_writes","deaths","arrests","escapes","unexpected_epochs"]:
		_bad("campaign",good,[key],1,"source failure or forbidden mutation cannot count as continuation: "+key)
	_bad("campaign",good,["bounded"],false,"evidence overflow is not silently accepted")
	for wall: float in [-1.0,0.0,1800000.0,NAN,INF]: _bad("campaign",good,["wall_ms"],wall,"finite positive whole-run30min bound")
	for kind: String in ["copper","conductor","buy_rock","short","claim_file","claim_install","mark","summons","kingdom_reward"]:
		var omitted: Dictionary = good.duplicate(true)
		for index: int in range(omitted.transactions.size()):
			if omitted.transactions[index].kind == kind: omitted.transactions.remove_at(index); break
		_check(not Probe.assess_campaign(omitted).is_empty(),"required source receipt cannot be omitted: "+kind)
	var duplicate: Dictionary = good.duplicate(true); duplicate.transactions.append(_reward("curb_emperor",["darryl_under_blue","general_receipt","bishop_wire"]))
	_check(not Probe.assess_campaign(duplicate).is_empty(),"a second valid-looking Emperor payout fails overall award count")
	_bad("campaign",good,["battles"],good.battles.slice(0,4),"four victories cannot replace the fifth actual fight")
	var swapped: Array = good.battles.duplicate(true); var first: Variant = swapped[1]; swapped[1] = swapped[2]; swapped[2] = first
	_bad("campaign",good,["battles"],swapped,"court order cannot be replaced by unordered defeat flags")
	_bad("campaign",good,["smoke_loops"],good.smoke_loops.slice(0,2),"spending or omitting the reserved royal rock fails")
	_bad("campaign",good,["endings"],good.endings.slice(0,1),"final source ending must actually be observed")
	_bad("campaign",good,["endings",0,"continued"],false,"Tony ending cannot be skipped with a mode write")
	_bad("campaign",good,["final","claims","skidrow"],false,"four-claim count requires four true claims")
	_bad("campaign",good,["final","kingdom","stage"],"emperor_boss","active encounter is not completed campaign")
	_bad("campaign",good,["final","kingdom","defeats"],[],"ending display cannot replace durable canonical defeats")
	for key: String in ["ok","durable_equal","resumed_motion"]:
		_bad("campaign",good,["persistence",key],false,"real final save/load proof required: "+key)
	_bad("campaign",good,["weapon_errors"],["unbacked source reward"],"an unexplained weapon transition fails the whole tour")
	_bad("campaign",good,["input_counts"],{},"no actual movement/menu/combat input proof is not a tour")
	_bad("campaign",good,["captures"],[],"detached receipts cannot substitute rendered evidence")
	var overflow_images: Array = good.captures.duplicate()
	while overflow_images.size() < 25: overflow_images.append("synthetic_overflow.png")
	_bad("campaign",good,["captures"],overflow_images,"a claimed bounded flag cannot conceal more than24 screenshots")
	_bad("campaign",good,["phase_states"],[],"missing phase checkpoints cannot count as complete orchestration")
	_bad("campaign",good,["phase_states",2,"id"],"resources","duplicate phase cannot erase the real claims watchdog")
	_bad("campaign",good,["phase_states",2,"wall_ms"],600000.0,"phase must remain strictly inside its own deadline")
	_bad("campaign",good,["rest_count"],13,"normal recovery cannot exceed the declared twelve-rest allowance")
	for pair: Array in [["samples",3600],["events",40000],["transactions",80],["legs",96],["menus",256],["walking",1024],["combat_navigation",2048],["attack_receipts",3000]]:
		var entries: Array = []; entries.resize(int(pair[1])+1)
		entries.fill(good.transactions[0] if pair[0] == "transactions" else {})
		_bad("campaign",good,[pair[0]],entries,"claimed bounded flag cannot conceal actual "+str(pair[0])+" overflow")
	_check(Probe.assess_initial(_initial()).is_empty(),"retained initial handoff is checked before continuation")
	var missing_cot: Dictionary = _initial(); missing_cot.office.upgrades.cot = false
	_check(not Probe.assess_initial(missing_cot).is_empty(),"early handoff check rejects absent recovery prerequisite")
	var extra_item: Dictionary = _initial(); extra_item.inventory.append("brass_knuckles")
	_check(not Probe.assess_initial(extra_item).is_empty(),"early handoff check rejects extra equipment")
	completed_groups += 1

func _phase_checks() -> void:
	for phase: int in [1,2,3]:
		_check(Probe.observed_boss_phase("tony",{"bossPhase":phase},{"id":"tony","kingdomPhase":1}) == phase,"Tony reads the actual shared phase counter")
		_check(Probe.observed_boss_phase("curb_emperor",{"bossPhase":1},{"id":"curb_emperor","kingdomPhase":phase}) == phase,"Emperor reads its independently advanced actor phase")
	_check(Probe.observed_boss_phase("curb_emperor",{"bossPhase":3},{"id":"curb_emperor","kingdomPhase":1}) == 1,"shared counter cannot invent an Emperor phase")
	_check(Probe.observed_boss_phase("curb_emperor",{"bossPhase":3},{"id":"curb_emperor"}) == 0,"missing actor phase cannot fall back to stale shared counter")
	_check(Probe.observed_boss_phase("curb_emperor",{"bossPhase":1},{"id":"tony","kingdomPhase":3}) == 0,"wrong actor cannot prove a canonical phase")
	for value: Variant in [0,4,1.5,NAN,INF,"3",null]:
		_check(Probe.observed_boss_phase("tony",{"bossPhase":value},{"id":"tony"}) == 0,"malformed phase rejected without coercion")

	var owner := "kingdom_marker_blue_tarp_0"
	var owned_body := StaticBody3D.new(); owned_body.set_meta("source_owner",owner)
	var unrelated_body := StaticBody3D.new(); unrelated_body.set_meta("source_owner","other_structure")
	var cosmetic := Node3D.new(); cosmetic.set_meta("source_owner",owner)
	_check(Probe.endpoint_ray_clear({},owner),"empty endpoint ray is clear")
	_check(Probe.endpoint_ray_clear({},""),"empty ray needs no invented source owner")
	_check(Probe.endpoint_ray_clear({"collider":owned_body},owner),"actual same-owner StaticBody may be the visible target surface")
	_check(not Probe.endpoint_ray_clear({"collider":unrelated_body},owner),"unrelated physical body cannot inherit target ownership")
	_check(not Probe.endpoint_ray_clear({"collider":owned_body},""),"nonempty ray cannot pass with an empty service owner")
	_check(not Probe.endpoint_ray_clear({"collider":cosmetic},owner),"matching metadata on a generic Node3D is not a physical-owner certificate")
	_check(not Probe.endpoint_ray_clear({"position":Vector3.ZERO},owner),"nonempty malformed ray cannot act like a clear ray")
	_check(owned_body.get_meta("source_owner") == owner and unrelated_body.get_meta("source_owner") == "other_structure","ray validation does not rewrite collider ownership")
	owned_body.free(); unrelated_body.free(); cosmetic.free()

	var player_epoch := {"hp":100,"position":{"x":10,"y":20}}
	var state_epoch := {"mode":"playing","kingdom":{"stage":"tarp_marks"}}
	var at := Vector3(12.0,0.06,40.0)
	var focus := Vector3(13.0,1.2,42.0)
	var id := "kingdom_mark:blue_tarp:0"
	var revision := 49
	var wait := {"id":id,"player_epoch":player_epoch,"state_epoch":state_epoch,"revision":revision,"position":at,"focus":focus}
	_check(Probe.same_aim_wait(wait,id,player_epoch,state_epoch,revision,at,focus),"unchanged actual aim context retains one wait budget")
	var player_alias: Dictionary = player_epoch; var state_alias: Dictionary = state_epoch
	_check(Probe.same_aim_wait(wait,id,player_alias,state_alias,revision,at,focus),"epoch aliases remain the identical p/s owners")
	var other_player: Dictionary = player_epoch.duplicate(true)
	var other_state: Dictionary = state_epoch.duplicate(true)
	_check(other_player == player_epoch and not is_same(other_player,player_epoch),"player replacement counterexample is equal-valued but detached")
	_check(other_state == state_epoch and not is_same(other_state,state_epoch),"state replacement counterexample is equal-valued but detached")
	_check(not Probe.same_aim_wait(wait,id,other_player,state_epoch,revision,at,focus),"equal replacement p alone invalidates the aim wait")
	_check(not Probe.same_aim_wait(wait,id,player_epoch,other_state,revision,at,focus),"equal replacement s alone invalidates the aim wait")
	_check(not Probe.same_aim_wait(wait,id+"_other",player_epoch,state_epoch,revision,at,focus),"different target does not reuse an old aim deadline")
	_check(not Probe.same_aim_wait(wait,id,player_epoch,state_epoch,revision+1,at,focus),"changed geometry revision invalidates the wait token")
	_check(Probe.same_aim_wait(wait,id,player_epoch,state_epoch,revision,at+Vector3(0.249,0,0),focus),"position movement strictly below0.25 keeps the existing deadline")
	_check(Probe.same_aim_wait(wait,id,player_epoch,state_epoch,revision,at,focus+Vector3(0.249,0,0)),"focus movement strictly below0.25 keeps the existing deadline")
	_check(not Probe.same_aim_wait(wait,id,player_epoch,state_epoch,revision,at+Vector3(0.25,0,0),focus),"position movement exactly0.25 invalidates the wait token")
	_check(not Probe.same_aim_wait(wait,id,player_epoch,state_epoch,revision,at,focus+Vector3(0.25,0,0)),"focus movement exactly0.25 invalidates the wait token")
	_check(Probe.same_aim_wait(wait.duplicate(),id,player_epoch,state_epoch,revision,at,focus),"shallow token copy preserves original epoch identities")
	_check(not Probe.same_aim_wait(wait.duplicate(true),id,player_epoch,state_epoch,revision,at,focus),"deep token clone cannot forge the retained epoch identities")
	_check(is_same(wait.player_epoch,player_epoch) and is_same(wait.state_epoch,state_epoch) and wait.position == at and wait.focus == focus and wait.revision == revision,"aim validation is read-only and retains the original captured context")

	var queued := Probe.FinishLatch.new()
	_check(not queued.timed_out(100000),"unstarted finalization has no fabricated timeout")
	_check(queued.request() and queued.queued and not queued.started,"first actual watchdog request queues finalization once")
	_check(not queued.request(),"duplicate watchdog request cannot queue a second finish")
	_check(not queued.timed_out(100000),"a queued request alone has not started the15s finalization timeout")
	_check(queued.begin(1000) and queued.started and queued.started_at == 1000,"queued finalization starts with its actual clock once")
	_check(not queued.begin(2000) and queued.started_at == 1000,"second begin cannot extend or restart the finish deadline")
	_check(not queued.request(),"started finish cannot be queued again")
	_check(not queued.timed_out(15999),"finalization remains inside its deadline at14999ms")
	_check(queued.timed_out(16000),"finalization reaches its hard deadline at15000ms")
	var direct := Probe.FinishLatch.new()
	_check(direct.begin(500) and direct.started and direct.started_at == 500,"normal completion may begin without a watchdog request")
	_check(not direct.request() and not direct.begin(600),"direct completion blocks both later request and duplicate begin")
	completed_groups += 1

func _cot_checks() -> void:
	var state: Dictionary = _initial()
	for pair: Array in [[100.0,"none"],[90.0,"none"],[89.999,"rest"],[80.0,"rest"],[79.999,"sleep"],[40.0875,"sleep"],[1.0,"sleep"]]:
		state.hp = pair[0]
		_check(Probe.cot_action(state,0,false) == pair[1],"actual HP selects ordinary cot action: "+str(pair[0]))
		for clocks: Vector2 in [Vector2(12000,0),Vector2(0,4000)]:
			state.high = clocks.x; state.crash = clocks.y
			_check(Probe.cot_action(state,0,false) == pair[1],"active high/crash cannot fabricate recovered HP")
		_check(Probe.cot_action(state,0,true) == "refuse","even healthy HP cannot authorize cot during combat")
	state.hp = 90.0
	_check(Probe.cot_action(state,12,false) == "none","full allowance accepts already recovered HP")
	state.hp = 89.999
	_check(Probe.cot_action(state,11,false) == "rest","twelfth action is usable")
	_check(Probe.cot_action(state,12,false) == "refuse","thirteenth recovery action is refused")
	for value: Variant in [0,-1,101,NAN,INF,"90",null]:
		state.hp = value
		_check(Probe.cot_action(state,0,false) == "refuse","invalid or dead HP cannot satisfy recovery")
	state.hp = 80.0
	for value: Variant in [89,NAN,INF,"100",null]:
		state.max_hp = value
		_check(Probe.cot_action(state,0,false) == "refuse","impossible maximum cannot create an unbounded recovery loop")
	state.max_hp = 100.0
	for value: int in [-1,13]: _check(Probe.cot_action(state,value,false) == "refuse","invalid action count fails closed")
	for action: String in ["rest","sleep"]:
		var row: Dictionary = _transaction(action)
		_accept("transaction",row,"exact ordinary "+action+" commit")
		for key: String in ["hp","brain","shakes","wanted","day_time","high","crash","cash","copper","rocks","street","cred"]:
			_bad("transaction",row,["after",key],float(row.after[key])+1.0,"cot cannot invent delta or advance "+key)
		for key: String in ["workJob","claimJob"]:
			var pending: Dictionary = row.duplicate(true)
			pending.before.office[key] = {"id":"alley","stage":"install"}; pending.after.office[key] = pending.before.office[key].duplicate(true)
			_accept("transaction",pending,"cot keeps pending "+key)
			_bad("transaction",pending,["after","office",key],null,"cot cannot discard pending "+key)
		_bad("transaction",row,["details","boss_active"],true,"cot during a boss is rejected")
		_bad("transaction",row,["details","action"],"different","receipt names actual menu action")
		for clocks: Vector2 in [Vector2(18000,0),Vector2(0,7999)]:
			var timed: Dictionary = row.duplicate(true)
			timed.before.high = clocks.x; timed.after.high = clocks.x; timed.before.crash = clocks.y; timed.after.crash = clocks.y
			_accept("transaction",timed,"cot preserves full active loop timers")
		var powered: Dictionary = row.duplicate(true)
		powered.before.office.upgrades.generator = true; powered.after.office.upgrades.generator = true
		powered.before.brain = 60.0; powered.after.brain = 90.0 if action == "sleep" else 65.0
		powered.after.hp = 95.0 if action == "sleep" else 98.0
		_accept("transaction",powered,"powered source effects remain exact")
	var rest: Dictionary = _transaction("rest")
	_bad("transaction",rest,["after","day"],4,"30-minute label is not a day advance")
	_bad("transaction",rest,["after","rng"],1234,"ordinary rest does not draw RNG")
	var capped: Dictionary = rest.duplicate(true); capped.before.hp = 95.0; capped.after.hp = 100.0
	_accept("transaction",capped,"source health caps at maxHP")
	var sleep: Dictionary = _transaction("sleep")
	_bad("transaction",sleep,["details","day_events"],[],"rolled sleep needs its actual day receipt")
	_bad("transaction",sleep,["details","day_events"],[sleep.details.day_events[0],sleep.details.day_events[0]],"sleep cannot advance two days")
	_bad("transaction",sleep,["details","day_events",0,"payload","cause"],"natural","natural dawn is not a cot receipt")
	_bad("transaction",sleep,["after","counters","heistsToday"],3,"sleep resets the real heist cap")
	_bad("transaction",sleep,["after","office","workToday"],1,"sleep resets Office capacity")
	_bad("transaction",sleep,["after","hustles"],[],"day records the real three rolled hustles")
	for time: float in [0.0,0.299999,0.3,0.300001]:
		var boundary: Dictionary = sleep.duplicate(true); boundary.before.day_time = time
		if time <= 0.3:
			boundary.after.day = boundary.before.day; boundary.after.office.workDay = boundary.before.office.workDay; boundary.after.office.workToday = boundary.before.office.workToday
			for key: String in ["counters","heists","hustles","hustle_snapshot","rng"]: boundary.after[key] = boundary.before[key]
			boundary.details.day_events = []
		_accept("transaction",boundary,"strict source morning branch at "+str(time))
		_bad("transaction",boundary,["after","day"],boundary.after.day+1,"calendar branch cannot add an extra day")
	var counted: Dictionary = _report()
	counted.transactions.append(rest); counted.rest_count = 1
	_accept("campaign",counted,"accepted cot command counts against shared cap")
	_bad("campaign",counted,["rest_count"],0,"cot receipt cannot disappear from total")
	var source_day := {"kind":"day_started","payload":{"day":4,"cause":"office_sleep","handled":true}}
	var outbox: Array = [{"kind":"toast","payload":{"text":"real source text"}},source_day]
	var pending: Array = [{"kind":"actor_spawned","payload":{"actor_id":"guard"}}]
	var before_outbox: Array = outbox.duplicate(true); var before_pending: Array = pending.duplicate(true)
	var projected: Array[Dictionary] = Probe.CampaignObservedScene.project_day_events(outbox,pending)
	_check(projected == [source_day],"real outbox day survives the campaign observer despite inherited combat trace filtering")
	_check(outbox == before_outbox and pending == before_pending,"observer never drains/reorders source event queues")
	source_day.payload.day = 99
	_check(projected[0].payload.day == 4,"captured day payload is detached from later source writes")
	var captured: Dictionary = sleep.duplicate(true); captured.details.day_events = projected
	_accept("transaction",captured,"actual observer projection supplies exact cot day receipt")
	var from_pending: Array[Dictionary] = Probe.CampaignObservedScene.project_day_events([],projected)
	_check(from_pending == projected and not is_same(from_pending[0],projected[0]),"pending State queue uses same detached source capture")
	_check(Probe.CampaignObservedScene.project_day_events([outbox[0]],pending).is_empty(),"other event categories cannot fabricate a day receipt")
	var both: Array[Dictionary] = Probe.CampaignObservedScene.project_day_events(projected,projected)
	_check(both.size() == 2,"duplicate source events remain visible rather than being deduplicated into success")
	_bad("transaction",sleep,["details","day_events"],both,"duplicate captured days still fail cot contract")
	var history: Array[Dictionary] = projected.duplicate(true); var cursor: int = history.size()
	_check(history.slice(cursor).is_empty(),"stale prior cot day cannot satisfy the current command window")
	history.append(projected[0].duplicate(true))
	_check(history.slice(cursor).size() == 1,"only the newly consumed real source event enters this cot receipt")

	completed_groups += 1

func _court_defense_checks() -> void:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/source_content.json"))
	_check(decoded is Dictionary,"court defense uses exported actual source actors")
	if not decoded is Dictionary: return
	var guards: Array[Dictionary] = []
	for body: Dictionary in decoded.get("actors",{}).get("day1",[]):
		if body.get("kingdomGuard",false): guards.append(body.duplicate(true))
	_check(guards.size() == 15,"actual source court census is4+4+4+3")
	if guards.size() != 15: return
	var ids: Array[String] = []
	for body: Dictionary in guards:
		var center := Vector2(float(body.x)+16.0,float(body.y)+16.0)
		var original: Dictionary = body.duplicate(true)
		_check(body.hostile == true and body.aggro == false,"exported source guard is hostile without aggro: "+str(body.id))
		_check(Probe.court_guard_candidate(body,1,center),"unaltered hostile source guard needs walking defense: "+str(body.id))
		_check(body == original,"guard eligibility is read-only")
		ids.append(str(body.id))
	# Use the actual production planner, including current-day and post-defeat
	# forces. Never patch the generated flags to make the observer pass.
	var source_clans: Array = decoded.get("definitions",{}).get("src/systems/campaigns.js",{}).get("KINGDOM_CLAN_LIST",[])
	_check(source_clans.size() == 3,"actual force-plan stage vocabulary exists")
	if source_clans.size() != 3: return
	for item: Dictionary in [{"day":1,"state":{"stage":"summons"},"count":15},
		{"day":10,"state":{"stage":source_clans[0].marksStage},"count":15},
		{"day":10,"state":{"stage":source_clans[0].bossStage},"count":11},
		{"day":11,"state":{"stage":"complete","defeats":["darryl_under_blue","general_receipt","bishop_wire","curb_emperor"]},"count":8}]:
		var supplied: Dictionary = item.state.duplicate(true)
		var plan: Dictionary = Campaign.plan_for_state(item.day,supplied,0)
		_check(plan.get("ok",false) and supplied == item.state,"real force planner succeeds without changing supplied source state")
		if not plan.get("ok",false): return
		var unchanged: Dictionary = plan.duplicate(true); var count := 0
		for generated: Dictionary in plan.actors:
			var point := Vector2(float(generated.x)+16.0,float(generated.y)+16.0)
			if generated.get("kingdomGuard",false):
				count += 1
				_check(generated.hostile == true and generated.aggro == false,"actual planner preserves hostile-only source guard:"+str(generated.id))
				_check(Probe.court_guard_candidate(generated,item.day,point),"actual generated guard is an eligible nearby threat:"+str(generated.id))
				_check(not Probe.court_guard_candidate(generated,item.day,point+Vector2(85,0)),"generated guard still respects exact85px boundary:"+str(generated.id))
			else: _check(not Probe.court_guard_candidate(generated,item.day,point),"generated pretender is not an ordinary guard defense")
		_check(count == item.count and plan == unchanged,"actual guard census and source records remain untouched")
	var body: Dictionary = guards[0].duplicate(true)
	var center := Vector2(float(body.x)+16.0,float(body.y)+16.0)
	for flags: Array in [[true,false,true],[false,true,true],[true,true,true],[false,false,false]]:
		var flagged: Dictionary = body.duplicate(true); flagged.hostile = flags[0]; flagged.aggro = flags[1]
		_check(Probe.court_guard_candidate(flagged,1,center) == flags[2],"hostile OR aggro uses source threat semantics:"+str(flags))
	var absent: Dictionary = body.duplicate(true); absent.erase("aggro")
	_check(Probe.court_guard_candidate(absent,1,center),"hostile needs no separate aggro field")
	absent.erase("hostile")
	_check(not Probe.court_guard_candidate(absent,1,center),"absent threat flags cannot authorize defense")
	for pair: Array in [["dead",true],["hostile",false],["kingdomGuard",false],["essential",true],
		["kingdomBoss",true],["kingdomPretender",true],["hp",0],["hp",NAN],["x",INF],["w",31],["h",33],
		["kingdomClan","throne"],["name","KNIGHT EMERITUS"],["sprite","receipt_guard"],
		["id","kingdom_guard_blue_tarp_0_0"],["id","kingdom_guard_blue_tarp_1_4"],["id","kingdom_guard_blue_tarp_1_00"],
		["id","kingdom_guard_blue_tarp_1_0_extra"],["id","darryl_under_blue"]]:
		var changed: Dictionary = body.duplicate(true); changed[pair[0]] = pair[1]
		_check(not Probe.court_guard_candidate(changed,1,center),"reject noncanonical/ineligible court target "+str(pair))
	_check(not Probe.court_guard_candidate(body,0,center),"invalid source day refuses defense")
	_check(not Probe.court_guard_candidate(body,2,center),"previous-day guard identity is stale")
	_check(not Probe.court_guard_candidate(body,1,Vector2(INF,0)),"nonfinite player center refused")
	_check(Probe.court_guard_candidate(body,1,center+Vector2(84.99,0)),"inside strict85px court range")
	_check(not Probe.court_guard_candidate(body,1,center+Vector2(85.0,0)),"exact85px is outside court range")
	_check(not Probe.court_guard_candidate(body,1,center+Vector2(100.0,0)),"distant hostile guard is not eligible")
	var next_day: Dictionary = body.duplicate(true); next_day.id = "kingdom_guard_blue_tarp_2_0"
	_check(Probe.court_guard_candidate(next_day,2,center),"actual new-day identity can qualify without resetting budgets")

	var budget := Probe.CourtDefenseBudget.new()
	_check(budget.remaining_ms(ids[0]) == 10000 and budget.guard_ms.is_empty(),"querying unused budget does not reserve a guard")
	_check(not budget.can_begin("") and not budget.begin(ids[0],-1),"empty id and invalid start clock refused")
	_check(budget.finish(0).get("ok") == false and budget.bouts == 0,"no-active finish cannot invent a bout")
	_check(budget.begin(ids[0],1000),"first eligible guard bout admitted")
	_check(not budget.begin(ids[0],1200) and not budget.begin(ids[1],1200),"duplicate active or competing begin rejected")
	_check(budget.bouts == 1 and budget.guard_bouts[ids[0]] == 1 and budget.guard_ms.size() == 1,"rejected begin consumes no new count")
	_check(budget.remaining_ms(ids[0]) == 10000,"active wall time remains caller-owned until finish")
	_check(budget.finish(999).get("ok") == false and budget.active_id == ids[0] and budget.active_start == 1000,"backward finish retains active bout and accounting")
	var first: Dictionary = budget.finish(4000)
	_check(first == {"ok":true,"id":ids[0],"elapsed_ms":3000,"guard_ms":3000,"total_ms":3000,"bouts":1,"unique_guards":1},"finish records actual elapsed and cumulative counters")
	_check(budget.remaining_ms(ids[0]) == 7000 and budget.active_id.is_empty(),"completed time reduces remaining allowance")
	_check(budget.finish(4500).get("ok") == false and budget.total_ms == 3000,"duplicate finish cannot double charge")
	_check(budget.begin(ids[1],5000),"different guard shares same global ledger")
	var other: Dictionary = budget.finish(7000)
	_check(other.ok and other.total_ms == 5000 and budget.remaining_ms(ids[0]) == 7000,"another guard does not reset first guard")
	_check(budget.begin(ids[0],8000),"second bout resumes remaining first-guard allowance")
	var second: Dictionary = budget.finish(14999)
	_check(second.ok and second.elapsed_ms == 6999 and second.guard_ms == 9999 and second.total_ms == 11999,"second bout shares cumulative10s allowance, excludes idle clock gaps")
	_check(budget.remaining_ms(ids[0]) == 1 and not budget.can_begin(ids[0]),"two-bout limit rejects third even with1ms remaining")
	_check(first.total_ms == 3000 and first.guard_ms == 3000,"earlier receipt remains immutable after later bouts")

	var exact := Probe.CourtDefenseBudget.new()
	_check(exact.begin(ids[0],0),"zero monotonic start allowed")
	_check(exact.finish(6000).ok and exact.begin(ids[0],6500),"two-bout exact boundary setup")
	var exhausted: Dictionary = exact.finish(10500)
	_check(exhausted.ok == false and exhausted.elapsed_ms == 4000 and exhausted.guard_ms == 10000 and exhausted.total_ms == 10000,"exact cumulative10s is failure and actual time is consumed")
	_check(exact.remaining_ms(ids[0]) == 0 and not exact.can_begin(ids[0]),"exhausted guard cannot receive fresh10s")
	var over := Probe.CourtDefenseBudget.new()
	_check(over.begin(ids[0],100),"overshoot setup")
	var overshot: Dictionary = over.finish(10601)
	_check(not overshot.ok and overshot.elapsed_ms == 10501 and over.total_ms == 10501,"failed overshoot is retained rather than clamped")

	var census := Probe.CourtDefenseBudget.new()
	for index: int in range(15):
		_check(census.begin(ids[index],index*10),"admit distinct guard "+str(index))
		_check(census.finish(index*10+1).ok,"short first bout "+str(index))
	_check(census.guard_ms.size() == 15 and census.bouts == 15,"fifteen unique guards counted once")
	_check(not census.can_begin(str(next_day.id)),"day replacement cannot create a sixteenth budget slot")
	_check(census.can_begin(ids[0]),"unique cap still permits existing guard's second bout")
	for index: int in range(15):
		_check(census.begin(ids[index],1000+index*10),"second existing-guard bout "+str(index))
		_check(census.finish(1001+index*10).ok,"short second bout "+str(index))
	_check(census.bouts == 30 and census.total_ms == 30 and census.guard_ms.size() == 15,"thirty bouts share one persistent ledger")
	_check(not census.can_begin(ids[0]) and not census.can_begin(str(next_day.id)),"thirty-bout cap admits neither old nor new identity")

	var global := Probe.CourtDefenseBudget.new()
	for index: int in range(15):
		_check(global.begin(ids[index],index*20000),"global budget first bout "+str(index))
		_check(global.finish(index*20000+9999).ok,"each first bout is strictly below10s "+str(index))
	_check(global.total_ms == 149985 and global.remaining_ms(ids[14]) == 1,"global actual consumption retained at149985ms")
	for index: int in range(15):
		_check(global.begin(ids[index],400000+index*10),"last remaining millisecond admitted "+str(index))
		var final_bout: Dictionary = global.finish(400001+index*10)
		_check(not final_bout.ok and final_bout.guard_ms == 10000,"each exact per-guard boundary fails without forgiving elapsed time")
	_check(global.total_ms == 150000 and global.bouts == 30 and global.remaining_ms("new_guard") == 0,"exact150s global boundary leaves zero allowance for every identity")
	_check(not global.can_begin(ids[0]) and not global.can_begin("new_guard"),"no reset/reentry after global exhaustion")
	completed_groups += 1

func _checkpoint_snapshot(summary: Dictionary) -> Dictionary:
	# Raw save spelling is independent of the compact observer summary spelling.
	return {"schema":2,"player":{"cash":summary.cash,"copper":summary.copper,"cred":summary.cred,
		"hp":summary.hp,"brain":summary.brain,"shakes":summary.shakes,"wanted":summary.wanted,
		"weapon":summary.weapon,"rocks":summary.rocks,
		"equip":summary.equip.duplicate(true),"inventory":summary.inventory.duplicate(true),
		"lifetime":{"rocksSmoked":summary.rocks_smoked,"routesCompleted":summary.routes,"officeJobs":summary.office_jobs},
		"faction":{"street":summary.street,"scrap":0,"spiritual":-5}},
		"state":{"day":summary.day,"office":summary.office.duplicate(true),"districtClaims":summary.claims.duplicate(true),
			"kingdom":summary.kingdom.duplicate(true),"quests":{"fallen_king":{"done":summary.fallen_king},
				"royal_static":{"done":summary.royal_static},"one_cracklord":{"done":summary.one_cracklord}}}}

func _prefix_report() -> Dictionary:
	var whole: Dictionary = _report()
	var report: Dictionary = whole.duplicate(true)
	report.format = "rock-bottom-campaign-tony-prefix"; report.transactions = []
	for row: Dictionary in whole.transactions:
		if row.kind not in ["summons","mark","kingdom_reward"]: report.transactions.append(row.duplicate(true))
	report.battles = whole.battles.slice(0,1); report.smoke_loops = whole.smoke_loops.slice(0,2)
	report.endings = whole.endings.slice(0,1); report.phase_states = whole.phase_states.slice(0,4)
	report.captures = whole.captures.slice(0,9); report.wall_ms = 600000.0
	report.final.cash = 40.0; report.final.cred = 230; report.final.rocks = 1; report.final.rocks_smoked = 5
	report.final.royal_static = false; report.final.one_cracklord = false
	report.final.kingdom = {"stage":"summons","marks":0,"bossId":"","defeats":[]}
	var saved: Dictionary = _checkpoint_snapshot(report.final)
	report.checkpoint = {"saved_through_pause":true,"menu_receipt":{"option":"remember this."},
		"save_completed":true,"save_sha256":"2".repeat(64),"before":saved.duplicate(true),"stored":saved.duplicate(true)}
	report.source_hashes = {"res://data/source_content.json":"3".repeat(64),"res://scripts/full_runtime.gd":"4".repeat(64)}
	report.driver_sha256 = "5".repeat(64)
	report.acceptance = true; report.status = "complete"; report.failures = []
	return report

func _suffix_report(prefix: Dictionary) -> Dictionary:
	var whole: Dictionary = _report()
	var report: Dictionary = whole.duplicate(true)
	report.format = "rock-bottom-campaign-kingdom-suffix"; report.transactions = []
	for row: Dictionary in whole.transactions:
		if row.kind in ["summons","mark","kingdom_reward"]: report.transactions.append(row.duplicate(true))
	report.battles = whole.battles.slice(1); report.smoke_loops = whole.smoke_loops.slice(2)
	report.endings = whole.endings.slice(1); report.phase_states = [whole.phase_states[0].duplicate(true)]+whole.phase_states.slice(4)
	report.captures = whole.captures.slice(0,15); report.wall_ms = 600000.0
	report.initial = prefix.final.duplicate(true); report.input = prefix.input.duplicate(true)
	report.loaded_input = prefix.checkpoint.stored.duplicate(true)
	report.resume = {"prefix_accepted":true,"report_sha256":"6".repeat(64),"save_sha256":prefix.checkpoint.save_sha256}
	report.source_hashes = prefix.source_hashes.duplicate(true); report.driver_sha256 = "7".repeat(64)
	report.rest_count = prefix.rest_count
	report.acceptance = true; report.status = "complete"; report.failures = []
	return report

func _checkpoint_errors(domain: String,report: Dictionary,prefix: Dictionary = {}) -> Array[String]:
	match domain:
		"content": return Probe.assess_prefix_content(report)
		"prefix": return Probe.assess_prefix(report)
		"suffix": return Probe.assess_suffix(report,prefix)
		_: return Probe.assess_aggregate(report)

func _checkpoint_bad(domain: String,report: Dictionary,path: Array,value: Variant,label: String,prefix: Dictionary = {}) -> void:
	var changed: Dictionary = report.duplicate(true)
	var cursor: Variant = changed
	for index: int in range(path.size()-1): cursor = cursor[path[index]]
	cursor[path[-1]] = value
	_check(not _checkpoint_errors(domain,changed,prefix).is_empty(),label)

func _retained_prefix_json_checks() -> bool:
	var prefix_path := ""; var save_path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--retained-prefix="): prefix_path = argument.trim_prefix("--retained-prefix=")
		elif argument.begins_with("--retained-save="): save_path = argument.trim_prefix("--retained-save=")
	var paths_ok: bool = prefix_path.is_absolute_path() and save_path.is_absolute_path() and FileAccess.file_exists(prefix_path) and FileAccess.file_exists(save_path)
	_check(paths_ok,"actual retained-prefix/save absolute paths are required; no synthetic fallback")
	if not paths_ok: return false
	var hashes_ok: bool = FileAccess.get_sha256(prefix_path) == RETAINED_PREFIX_SHA and FileAccess.get_sha256(save_path) == RETAINED_SAVE_SHA
	_check(hashes_ok,"actual native-v4 accepted prefix and Pause-save raw bytes are pinned")
	if not hashes_ok: return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(prefix_path))
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_check(parsed is Dictionary and saved is Dictionary,"actual retained evidence decodes to object roots")
	if not parsed is Dictionary or not saved is Dictionary: return false
	var prefix: Dictionary = parsed
	var errors: Array[String] = Probe.assess_prefix(prefix)
	_check(errors.is_empty(),"actual decoded accepted Tony prefix is admissible: "+str(errors))
	_check(prefix.initial.office.workJob.serial is float and prefix.battles[0].phase_seen[0] is float,"actual JSON witness exercises float leaves against integer schema literals")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(prefix))
	errors = Probe.assess_prefix(roundtrip)
	_check(errors.is_empty(),"actual prefix survives an additional JSON roundtrip: "+str(errors))
	_check(Probe.checkpoint_value_equal(prefix.checkpoint.stored,saved),"actual pinned Pause-save remains exactly linked")
	errors = Probe.resume_admission_errors(prefix,saved,RETAINED_SAVE_SHA,prefix.source_hashes)
	_check(errors.is_empty(),"actual decoded prefix/save/source admission: "+str(errors))
	_check(prefix.source_hashes.size() == 90 and prefix.rest_count == 8 and prefix.wall_ms == 545484,"retained original source inventory and shared budgets are unchanged")
	var work: Dictionary = {}
	for row: Dictionary in prefix.transactions:
		if row.get("kind") == "work": work = row; break
	_check(not work.is_empty(),"actual pending-work settlement receipt exists")
	if work.is_empty(): return false
	for value: Variant in [2.00005,"2",true,NAN,INF,-INF,null]:
		var initial: Dictionary = prefix.initial.duplicate(true); initial.office.workJob.serial = value
		_check(not Probe.assess_initial(initial).is_empty(),"decoded initial rejects nonexact serial "+str(value))
		var transaction: Dictionary = work.duplicate(true); transaction.before.office.workJob.serial = value
		_check(not Probe.assess_transaction(transaction).is_empty(),"decoded settlement rejects nonexact serial "+str(value))
	for key: String in ["id","serial","stage"]:
		var initial: Dictionary = prefix.initial.duplicate(true); initial.office.workJob.erase(key)
		_check(not Probe.assess_initial(initial).is_empty(),"decoded initial rejects missing job field "+key)
		var transaction: Dictionary = work.duplicate(true); transaction.before.office.workJob.erase(key)
		_check(not Probe.assess_transaction(transaction).is_empty(),"decoded settlement rejects missing job field "+key)
	var extra: Dictionary = prefix.initial.duplicate(true); extra.office.workJob.invented = true
	_check(not Probe.assess_initial(extra).is_empty(),"decoded initial rejects extra job schema key")
	var extra_work: Dictionary = work.duplicate(true); extra_work.before.office.workJob.invented = true
	_check(not Probe.assess_transaction(extra_work).is_empty(),"decoded settlement rejects extra job schema key")
	for phases: Variant in [[1,2.00005,3],[1,"2",3],[1,true,3],[1,NAN,3],[1,INF,3],[1,3,2],[1,2,2,3],[1,2],null]:
		var fight: Dictionary = prefix.battles[0].duplicate(true); fight.phase_seen = phases
		_check(not Probe.assess_battle(fight).is_empty(),"decoded actual fight rejects nonexact phase proof "+str(phases))
	var missing_phase: Dictionary = prefix.battles[0].duplicate(true); missing_phase.erase("phase_seen")
	_check(not Probe.assess_battle(missing_phase).is_empty(),"decoded actual fight requires phase field")
	var changed: Dictionary = prefix.duplicate(true)
	changed.initial.office.workJob.serial = 2.00005
	for row: Dictionary in changed.transactions:
		if row.get("kind") == "work": row.before.office.workJob.serial = "2"
	changed.battles[0].phase_seen = [1,2.00005,3]
	errors = Probe.resume_admission_errors(changed,saved,RETAINED_SAVE_SHA,prefix.source_hashes)
	for reason: String in ["retained handoff values","pending work settlement","required source boss phases"]:
		_check(errors.has("prefix proof: "+reason),"admission preserves each concrete schema failure: "+reason)
	var sources: Dictionary = prefix.source_hashes.duplicate(true)
	sources.erase("res://data/source_content.json"); sources["res://scripts/full_runtime.gd"] = "0".repeat(64); sources["res://scripts/invented.gd"] = "1".repeat(64)
	errors = Probe.resume_admission_errors(prefix,saved,RETAINED_SAVE_SHA,sources)
	_check(errors.has("source missing: res://data/source_content.json") and errors.has("source extra: res://scripts/invented.gd"),"admission distinguishes missing and extra source paths")
	var changed_source_reason := false
	for reason: String in errors:
		if reason.begins_with("source changed: res://scripts/full_runtime.gd expected=") and reason.ends_with(" actual="+"0".repeat(64)): changed_source_reason = true
	_check(changed_source_reason,"changed source diagnostic includes path and both exact digests")
	var wrong_save: Dictionary = saved.duplicate(true); wrong_save.player.cash += 0.00005
	errors = Probe.resume_admission_errors(prefix,wrong_save,"0".repeat(64),prefix.source_hashes)
	_check(errors.has("prefix checkpoint digest differs from pinned save digest") and errors.has("prefix stored save differs from decoded pinned save"),"admission separately diagnoses digest and stored-value mismatch")
	changed = prefix.duplicate(true); changed.acceptance = false; changed.status = "failed"; changed.failures = ["actual death"]
	errors = Probe.resume_admission_errors(changed,saved,RETAINED_SAVE_SHA,prefix.source_hashes)
	_check(errors.has("prefix acceptance is not true") and errors.has("prefix status is not complete") and errors.has("prefix failures are present or missing"),"failed full-run metadata cannot enter through numeric compatibility")
	_check(Probe.resume_admission_errors(null,saved,RETAINED_SAVE_SHA,prefix.source_hashes) == ["prefix JSON root is not a dictionary"],"invalid parent root reports its exact admission cause")
	_check(Probe.resume_admission_errors(prefix,null,RETAINED_SAVE_SHA,prefix.source_hashes).has("save JSON root is not a dictionary"),"invalid save root is diagnosed without coercion")
	_check(FileAccess.get_sha256(prefix_path) == RETAINED_PREFIX_SHA and FileAccess.get_sha256(save_path) == RETAINED_SAVE_SHA,"all actual-evidence checks leave both immutable input files untouched")
	return true

func _checkpoint_checks() -> void:
	var launch := PackedStringArray(["--qa-full","--output=C:/qa/campaign-checkpoint","--handoff=C:/qa/earned-handoff.json","--parent-report=C:/qa/office-tour.json"])
	var stop_launch: PackedStringArray = launch.duplicate(); stop_launch.append("--stop-after-tony")
	_check(Probe.launch_error(stop_launch).is_empty(),"explicit full launch may stop after earned Tony checkpoint")
	var resume_launch: PackedStringArray = launch.duplicate()
	resume_launch.append_array(PackedStringArray(["--resume-tony","--handoff-sha="+HANDOFF_SHA,"--parent-sha="+PARENT_SHA]))
	_check(Probe.launch_error(resume_launch).is_empty(),"explicit full resume requires both saved-byte and prefix-report pins")
	for flag: String in ["--handoff-sha=","--parent-sha="]:
		var missing_pin: PackedStringArray = resume_launch.duplicate()
		for index: int in range(missing_pin.size()-1,-1,-1):
			if missing_pin[index].begins_with(flag): missing_pin.remove_at(index)
		_check(not Probe.launch_error(missing_pin).is_empty(),"resume rejects missing pin "+flag)
		var malformed_pin: PackedStringArray = resume_launch.duplicate()
		for index: int in range(malformed_pin.size()):
			if malformed_pin[index].begins_with(flag): malformed_pin[index] = flag+"G".repeat(64)
		_check(not Probe.launch_error(malformed_pin).is_empty(),"resume rejects non-lowercase-hex pin "+flag)
	var dual_launch: PackedStringArray = resume_launch.duplicate(); dual_launch.append("--stop-after-tony")
	_check(not Probe.launch_error(dual_launch).is_empty(),"stop and resume checkpoint modes are exclusive")
	var pins_only: PackedStringArray = resume_launch.duplicate(); pins_only.remove_at(pins_only.find("--resume-tony"))
	_check(not Probe.launch_error(pins_only).is_empty(),"prefix pins cannot silently select a resume mode")
	var prefix: Dictionary = _prefix_report()
	var suffix: Dictionary = _suffix_report(prefix)
	var aggregate := {"format":"rock-bottom-campaign-two-run-aggregate","runs":2,"continuous_run":false,
		"prefix":prefix.duplicate(true),"suffix":suffix.duplicate(true),"five_bosses":prefix.battles+suffix.battles}
	var original_prefix: Dictionary = prefix.duplicate(true); var original_suffix: Dictionary = suffix.duplicate(true)
	var errors: Array[String] = Probe.assess_prefix_content(prefix)
	_check(errors.is_empty(),"complete synthetic earned prefix content: "+str(errors))
	errors = Probe.assess_prefix(prefix)
	_check(errors.is_empty(),"Pause-saved synthetic prefix and hashes: "+str(errors))
	errors = Probe.assess_suffix(suffix,prefix)
	_check(errors.is_empty(),"bound synthetic Kingdom suffix: "+str(errors))
	errors = Probe.assess_aggregate(aggregate)
	_check(errors.is_empty(),"honest two-run synthetic aggregate: "+str(errors))
	_check(prefix == original_prefix and suffix == original_suffix,"checkpoint assessors do not mutate either run")
	_check(not Probe.assess_campaign(aggregate).is_empty(),"two runs cannot masquerade as uninterrupted original campaign")
	_check(Probe.digest_valid(HANDOFF_SHA),"canonical lowercase digest accepted")
	for value: Variant in [null,5,true,{},[],"",HANDOFF_SHA.substr(0,63),HANDOFF_SHA+"0",HANDOFF_SHA.to_upper(),"g".repeat(64)]:
		_check(not Probe.digest_valid(value),"malformed checkpoint digest "+str(value))
	var saved: Dictionary = prefix.checkpoint.stored
	_check(Probe.checkpoint_durable_equal(saved,saved.duplicate(true)),"detached exact durable checkpoint")
	_check(not saved.player.has("maxHp") and not saved.player.has("rockedT") and not saved.player.has("crashT"),"raw source save omits derived maximumHP and transient high/crash timers")
	_check(Probe.assess_prefix(prefix).is_empty() and Probe.assess_suffix(suffix,prefix).is_empty(),"real source omission of maximumHP/high/crash does not invalidate earned checkpoint")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(saved))
	_check(Probe.checkpoint_durable_equal(saved,roundtrip),"actual JSON storage representation preserves durable checkpoint")
	for root_key: String in ["player","state"]:
		for key: String in saved[root_key]:
			var removed: Dictionary = saved.duplicate(true); removed[root_key].erase(key)
			_check(not Probe.checkpoint_durable_equal(saved,removed),"checkpoint missing required durable field "+root_key+"."+key)
	var changed: Dictionary = saved.duplicate(true); changed.player.cash += 0.00005
	_check(not Probe.checkpoint_durable_equal(saved,changed),"JSON-distinguishable small cash change is not equal")
	changed = saved.duplicate(true); changed.player.hp = NAN
	_check(not Probe.checkpoint_durable_equal(saved,changed),"nonfinite savedHP rejected")
	changed = saved.duplicate(true); changed.player.copper = float(saved.player.copper)
	_check(Probe.checkpoint_durable_equal(saved,changed),"equal JSON numeric int/float values retained")

	_checkpoint_bad("content",prefix,["input","fixture_writes"],1,"prefix cannot add a resource fixture")
	_checkpoint_bad("content",prefix,["initial","cash"],80,"prefix still begins at exact accepted Office handoff")
	_checkpoint_bad("content",prefix,["transactions"],prefix.transactions.slice(1),"prefix needs original pending-work settlement")
	var downstream: Array = prefix.transactions.duplicate(true); downstream.append(_transaction("summons"))
	_checkpoint_bad("content",prefix,["transactions"],downstream,"prefix cannot include downstream Kingdom transactions")
	_checkpoint_bad("content",prefix,["battles"],[],"prefix requires actual Tony victory")
	_checkpoint_bad("content",prefix,["battles",0,"wall_ms"],90000.0,"prefix Tony remains strictly sub90s")
	_checkpoint_bad("content",prefix,["smoke_loops"],prefix.smoke_loops.slice(0,1),"prefix needs both completed real loops")
	_checkpoint_bad("content",prefix,["pending_smoke"],{"kind":"tony"},"prefix cannot truncate active smoke")
	_checkpoint_bad("content",prefix,["endings",0,"continued"],false,"prefix needs actual Tony ending continuation")
	for pair: Array in [["weapon","pipe"],["rocks",0],["fallen_king",false],["high",1.0],["crash",1.0]]:
		_checkpoint_bad("content",prefix,["final",pair[0]],pair[1],"earned Tony endpoint "+str(pair))
	_checkpoint_bad("content",prefix,["final","kingdom","stage"],"tarp_marks","prefix stops before answering summons")
	_checkpoint_bad("content",prefix,["phase_states"],prefix.phase_states.slice(0,3),"prefix retains full finite phase witness")
	_checkpoint_bad("content",prefix,["deaths"],1,"later or earlier death cannot become accepted prefix content")
	_checkpoint_bad("prefix",prefix,["checkpoint","saved_through_pause"],false,"checkpoint requires real Pause action")
	_checkpoint_bad("prefix",prefix,["checkpoint","menu_receipt","option"],"remember before.","load receipt is not a save receipt")
	_checkpoint_bad("prefix",prefix,["checkpoint","save_completed"],false,"pending save cannot be handed off")
	_checkpoint_bad("prefix",prefix,["checkpoint","save_sha256"],"","exact saved-byte digest required")
	_checkpoint_bad("prefix",prefix,["checkpoint","stored","player","cash"],41.0,"stored state must match observed pre-save state")
	var linked: Dictionary = prefix.duplicate(true)
	linked.checkpoint.before.player.cash += 1; linked.checkpoint.stored.player.cash += 1
	_check(not Probe.assess_prefix(linked).is_empty(),"consistent invented save still fails final-summary linkage")
	_checkpoint_bad("prefix",prefix,["source_hashes"],{},"production source inventory cannot disappear")
	_checkpoint_bad("prefix",prefix,["source_hashes","res://data/source_content.json"],"bad","source-content digest validated")
	_checkpoint_bad("prefix",prefix,["driver_sha256"],"bad","prefix driver provenance separate from production hashes")

	_checkpoint_bad("suffix",suffix,["resume","prefix_accepted"],false,"suffix requires accepted prefix",prefix)
	_checkpoint_bad("suffix",suffix,["resume","report_sha256"],"bad","prefix report digest retained",prefix)
	_checkpoint_bad("suffix",suffix,["resume","save_sha256"],HANDOFF_SHA,"suffix cannot load an unrelated save",prefix)
	_checkpoint_bad("suffix",suffix,["source_hashes","res://scripts/full_runtime.gd"],"8".repeat(64),"production source cannot change across split runs",prefix)
	_checkpoint_bad("suffix",suffix,["loaded_input","player","cash"],41.0,"loaded saved resources must match pinned prefix",prefix)
	for pair: Array in [["cash",41.0],["weapon","knife"],["hp",101.0],["max_hp",101.0],["high",1.0],["crash",1.0]]:
		_checkpoint_bad("suffix",suffix,["initial",pair[0]],pair[1],"suffix actual start agrees with loaded save "+str(pair),prefix)
	_checkpoint_bad("suffix",suffix,["input","fixture_writes"],1,"original fixture disclosure cannot be rewritten on resume",prefix)
	_checkpoint_bad("suffix",suffix,["driver_sha256"],"","suffix test driver hash required",prefix)
	for key: String in ["motion_frames","mouse_motion","keys","clicks"]:
		_checkpoint_bad("suffix",suffix,["input_counts",key],0,"suffix has its own real inputs: "+key,prefix)
	_checkpoint_bad("suffix",suffix,["pending_smoke"],{"kind":"royal"},"suffix cannot retain unfinished royal loop",prefix)
	var replayed: Array = suffix.transactions.duplicate(true); replayed.append(_transaction("work"))
	_checkpoint_bad("suffix",suffix,["transactions"],replayed,"suffix cannot replay prefix earning",prefix)
	_checkpoint_bad("suffix",suffix,["transactions"],suffix.transactions.slice(1),"suffix must actually answer summons",prefix)
	_checkpoint_bad("suffix",suffix,["battles"],suffix.battles.slice(0,3),"four actual Kingdom fights required",prefix)
	_checkpoint_bad("suffix",suffix,["smoke_loops"],[],"royal smoke required only in suffix",prefix)
	_checkpoint_bad("suffix",suffix,["endings",0,"continued"],false,"actual Kingdom ending continuation required",prefix)
	_checkpoint_bad("suffix",suffix,["wall_ms"],1200000.0,"combined exact30min boundary fails",prefix)
	_checkpoint_bad("suffix",suffix,["captures"],suffix.captures.slice(0,14),"suffix needs its own rendered evidence",prefix)
	_checkpoint_bad("suffix",suffix,["phase_states",1,"id"],"resources","suffix cannot disguise restarted prefix phase",prefix)
	_checkpoint_bad("suffix",suffix,["persistence","resumed_motion"],false,"suffix final loaded controls actually resume",prefix)
	var rested_prefix: Dictionary = prefix.duplicate(true); rested_prefix.transactions.append(_transaction("rest")); rested_prefix.rest_count = 1
	var rested_suffix: Dictionary = _suffix_report(rested_prefix); rested_suffix.transactions.append(_transaction("rest")); rested_suffix.rest_count = 2
	errors = Probe.assess_suffix(rested_suffix,rested_prefix)
	_check(errors.is_empty(),"cot allowance is cumulative across legitimate split runs: "+str(errors))
	_checkpoint_bad("suffix",rested_suffix,["rest_count"],1,"resume cannot reset previously spent cot count",rested_prefix)
	var exhausted: Dictionary = rested_suffix.duplicate(true)
	for index: int in range(11): exhausted.transactions.append(_transaction("rest"))
	exhausted.rest_count = 13
	_check(not Probe.assess_suffix(exhausted,rested_prefix).is_empty(),"combined thirteen source-valid cots fail shared twelve limit")

	_checkpoint_bad("aggregate",aggregate,["runs"],1,"two runs cannot be advertised as one")
	_checkpoint_bad("aggregate",aggregate,["continuous_run"],true,"continuous-run assertion explicitly rejected")
	_checkpoint_bad("aggregate",aggregate,["prefix","acceptance"],false,"failed native-v3 is not an accepted prefix")
	_checkpoint_bad("aggregate",aggregate,["prefix","status"],"failed","partial prefix cannot be promoted by aggregate")
	_checkpoint_bad("aggregate",aggregate,["prefix","failures"],["actual death"],"prefix failures remain disqualifying")
	_checkpoint_bad("aggregate",aggregate,["suffix","acceptance"],false,"failed suffix cannot be promoted")
	_checkpoint_bad("aggregate",aggregate,["suffix","status"],"partial","unfinished suffix cannot be accepted")
	_checkpoint_bad("aggregate",aggregate,["suffix","failures"],["actual death"],"suffix failures remain disqualifying")
	_checkpoint_bad("aggregate",aggregate,["five_bosses"],aggregate.five_bosses.slice(1),"Tony plus four referenced fights remain required")
	var altered: Array = aggregate.five_bosses.duplicate(true); altered[0].wall_ms = 1.0
	_checkpoint_bad("aggregate",aggregate,["five_bosses"],altered,"aggregate cannot rewrite referenced fight receipt")
	var decoded_prefix: Dictionary = JSON.parse_string(JSON.stringify(prefix))
	errors = Probe.assess_prefix(decoded_prefix)
	_check(errors.is_empty(),"complete synthetic prefix JSON roundtrip: "+str(errors))
	errors = Probe.assess_campaign(JSON.parse_string(JSON.stringify(_report())))
	_check(errors.is_empty(),"unchanged full campaign assessor accepts decoded complete evidence: "+str(errors))
	errors = Probe.assess_suffix(suffix,decoded_prefix)
	_check(errors.is_empty(),"mixed live suffix and decoded prefix preserve exact numeric lineage: "+str(errors))
	var mixed: Dictionary = aggregate.duplicate(true); mixed.five_bosses = JSON.parse_string(JSON.stringify(mixed.five_bosses))
	errors = Probe.assess_aggregate(mixed)
	_check(errors.is_empty(),"mixed decoded fight receipts preserve exact aggregate identity: "+str(errors))
	_checkpoint_bad("suffix",suffix,["input","fixture_writes"],0.00005,"mixed lineage retains subinteger changes",decoded_prefix)
	_checkpoint_bad("suffix",suffix,["input","fixture_writes"],"0","mixed lineage never coerces numeric strings",decoded_prefix)
	mixed.five_bosses[0].initial_hp += 0.00005
	_check(not Probe.assess_aggregate(mixed).is_empty(),"mixed fight copies cannot change even a small HP value")
	_check(Probe.evidence_value_equal({"serial":2,"phases":[1,2,3]},{"serial":2.0,"phases":[1.0,2.0,3.0]}),"exact finite numeric values are representation independent")
	for pair: Array in [[2,2.0000000000000004],[0,"0"],[0,false],[NAN,NAN],[INF,INF],[-INF,-INF],[{},[]]]:
		_check(not Probe.evidence_value_equal(pair[0],pair[1]),"evidence has no epsilon/coercion/nonfinite allowance "+str(pair))
	if not _retained_prefix_json_checks(): return
	completed_groups += 1

func _run() -> void:
	_launch_checks(); _resource_checks(); _transaction_checks(); _battle_checks(); _smoke_checks(); _reward_checks(); _campaign_checks(); _phase_checks(); _cot_checks(); _court_defense_checks(); _checkpoint_checks()
	_check(completed_groups == 11,"all eleven contract groups reached their actual completion tails")
	for failure: String in failures: push_error(failure)
	print("CAMPAIGN CONTINUATION CONTRACT: ","PASS" if failures.is_empty() else "FAIL"," (",checks," detached and retained-JSON checks; ",completed_groups,"/11 groups; not a new native run)")
	quit(0 if failures.is_empty() else 1)
