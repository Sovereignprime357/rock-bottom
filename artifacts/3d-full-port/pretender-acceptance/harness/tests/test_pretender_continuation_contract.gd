extends SceneTree
## Pure evidence-contract counterexamples. No native tour, gameplay or fixture installation.
const Probe = preload("res://tests/pretender_continuation_probe.gd")
const CampaignProof = preload("res://tests/campaign_continuation_probe.gd")
const Campaign = preload("res://scripts/campaign_system.gd")
const REPORT_SHA := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
const SAVE_SHA := "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
const DEFEATS := ["darryl_under_blue","general_receipt","bishop_wire","curb_emperor"]
const GROUPS := 11
var checks := 0
var completed_groups := 0
var failures: Array[String] = []
var source_clans: Array = []

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _errors(domain: String,row: Dictionary) -> Array[String]:
	match domain:
		"spawn": return Probe.assess_spawn(row)
		"reward": return Probe.assess_pretender_reward(row)
		"reload": return Probe.assess_pretender_reload(row)
		_: return Probe.assess_pretender_tour(row)

func _accept(domain: String,row: Dictionary,label: String) -> void:
	var original: Dictionary = row.duplicate(true)
	var errors: Array[String] = _errors(domain,row)
	_check(errors.is_empty(),label+": "+str(errors))
	_check(row == original,"read-only assessor: "+label)

func _bad(domain: String,row: Dictionary,path: Array,value: Variant,label: String) -> void:
	var changed: Dictionary = row.duplicate(true)
	var cursor: Variant = changed
	for index: int in range(path.size()-1): cursor = cursor[path[index]]
	cursor[path[-1]] = value
	_check(not _errors(domain,changed).is_empty(),label)

func _summary(day: int = 5,count: int = 2) -> Dictionary:
	return {"cash":200.0,"copper":7,"cred":240,"hp":40.0,"max_hp":100.0,"brain":40.0,
		"shakes":80.0,"wanted":1.0,"day":day,"day_time":0.4,"high":0.0,"crash":0.0,
		"weapon":"shoe","equip":{"hat":null,"coat":null,"shoes":null,"tool":null},
		"inventory":[],"rocks":0,"rocks_smoked":6,"street":12,"offenses":0,"routes":3,
		"office_jobs":1,"heists":1,"rng":42,"pretenders_lifetime":count,
		"claims":{"canal":true,"alley":true,"projects":true,"skidrow":true},
		"office":{"owned":true,"upgrades":{"cot":true,"desk":true,"radio":true,"generator":false},
			"workJob":null,"claimJob":null,"jobsCompleted":1,"orderSerial":2,"lastWorkId":"canal","workDay":day,"workToday":1},
		"kingdom":{"stage":"complete","marks":7,"bossId":"","defeats":DEFEATS.duplicate(),
			"pretenderDay":day,"pretenderDefeatedDay":day-1,"pretendersDefeated":count},
		"counters":{"stripeFencedToday":1,"barbPacketsToday":1,"peteCashToday":1,"heistsToday":1,"robberiesToday":1,"breakinsToday":1},
		"hustles":[{"id":"one"},{"id":"two"},{"id":"three"}],"hustle_snapshot":{"bigPan":0}}

func _saved(summary: Dictionary) -> Dictionary:
	return {"schema":2,"player":{"cash":summary.cash,"copper":summary.copper,"cred":summary.cred,
		"weapon":summary.weapon,"equip":summary.equip.duplicate(true),"inventory":summary.inventory.duplicate(true),
		"rocks":summary.rocks,"lifetime":{"pretendersDefeated":summary.pretenders_lifetime,"routesCompleted":3},
		"faction":{"street":12,"scrap":0,"spiritual":-6}},
		"state":{"day":summary.day,"office":summary.office.duplicate(true),"districtClaims":summary.claims.duplicate(true),
			"kingdom":summary.kingdom.duplicate(true),"quests":{"one_cracklord":{"done":true}}}}

func _parent(saved: Dictionary) -> Dictionary:
	return {"format":"rock-bottom-campaign-continuation","acceptance":true,"status":"complete","failures":[],
		"persistence":{"save_sha256":SAVE_SHA,"stored":saved.duplicate(true),"after":saved.duplicate(true)}}

func _profile(day: int,prior: int) -> Dictionary:
	## Independent source table and literal actor payload from campaigns.js:532-535.
	var clan: Dictionary = source_clans[day%3]
	return {"id":"curb_pretender_%d" % day,"name":"CURB PRETENDER No. %d" % (prior+1),
		"kingdomClan":clan.id,"archetype":["charger","grabber","ranged"][day%3],"sprite":clan.guardSprite,
		"hp":100,"maxHp":100,"dmg":9,"speed":1.45,"w":32,"h":32,"hostile":true,"showHp":true,
		"kingdomPretender":true,"transient":false,"noComboReward":true,"dead":false}

func _spawn(day: int = 6,prior: int = 2) -> Dictionary:
	var actor: Dictionary = _profile(day,prior)
	var at: Dictionary = source_clans[day%3].boss
	actor.x = float(at.x)-16.0; actor.y = float(at.y)-16.0
	return {"day":day,"prior":prior,"actor":actor,"live_count":1,"stage":"complete","defeated_day":day-1,"spawn_day":day}

func _reward(day: int = 6,prior: int = 2) -> Dictionary:
	var before: Dictionary = _summary(day,prior)
	before.cash += (prior-2)*10; before.cred += (prior-2)*2
	var after: Dictionary = before.duplicate(true)
	after.cash += 10; after.cred += 2; after.kingdom.pretenderDefeatedDay = day
	after.kingdom.pretendersDefeated += 1; after.pretenders_lifetime += 1
	var id: String = "curb_pretender_%d" % day
	return {"id":id,"before":before,"after":after,"target_before":{"id":id,"dead":false,"hp":20.0},
		"target_after":{"id":id,"dead":true,"hp":-9.0},"events":[
			{"kind":"player_attack","payload":{"hits":[id]}},
			{"kind":"actor_died","payload":{"actor_id":id}}]}

func _reload(day: int = 6,prior: int = 2) -> Dictionary:
	var saved: Dictionary = _saved(_reward(day,prior).after)
	return {"day":day,"before":saved.duplicate(true),"stored":saved.duplicate(true),"after":saved.duplicate(true),
		"epoch_delta":1,"live_count":0,"resumed_motion":true,"save_sha256":SAVE_SHA}

func _cot(day: int) -> Dictionary:
	var before: Dictionary = _summary(day-1,day-4)
	var after: Dictionary = before.duplicate(true)
	after.hp = 95.0; after.brain = 65.0; after.shakes = 95.0; after.wanted = 0.0
	after.day = day; after.day_time = 0.3; after.office.workDay = day; after.office.workToday = 0
	for key: String in after.counters: after.counters[key] = 0
	after.heists = 0; after.rng = 99
	return {"kind":"sleep","before":before,"after":after,"details":{"source":"office:cot","action":"sleep",
		"boss_active":false,"day_events":[{"kind":"day_started","payload":{"cause":"office_sleep","day":day,"handled":true}}]}}

func _tour() -> Dictionary:
	var initial: Dictionary = _summary(5,2)
	var final: Dictionary = _reward(8,4).after
	var report := {"format":"rock-bottom-pretender-continuation","input":{"parent_contract_valid":true,"parent_accepted":true,
		"fixture_writes":0,"handoff_sha256":SAVE_SHA,"parent_report_sha256":REPORT_SHA,
		"parent_format":"rock-bottom-campaign-continuation","parent_runs":1},
		"initial":initial,"final":final,"state_writes":0,"deaths":0,"arrests":0,"escapes":0,"unexpected_epochs":0,
		"bounded":true,"wall_ms":180000.0,"rest_count":3,"spawns":[],"rewards":[],"reloads":[],"fights":[],
		"transactions":[],"captures":[],"phase_states":[{"id":"load","wall_ms":1000.0}],"weapon_errors":[],
		"input_counts":{"motion_frames":300,"mouse_motion":120,"keys":100,"clicks":30},
		"events":[],"samples":[],"day_events":[],"legs":[],"menus":[],"walking":[],"combat_navigation":[],"attack_receipts":[],"court_defenses":[]}
	for index: int in range(3):
		var day: int = 6+index
		report.spawns.append(_spawn(day,2+index)); report.rewards.append(_reward(day,2+index)); report.reloads.append(_reload(day,2+index))
		report.fights.append({"id":"curb_pretender_%d" % day,"day":day,"won":true,"wall_ms":40000.0,
			"source_damage":true,"cooldowns_valid":true,"accepted_attacks":5,
			"engagement_view":{"id":"curb_pretender_%d" % day,"kind":"completed_frame_before_first_click",
				"saved":true,"alive":true,"on_screen":true,"static_los":true,"process_frame":100+index,"distance":30.0}})
		report.transactions.append(_cot(day))
		report.phase_states.append({"id":"day_%d" % (index+1),"wall_ms":55000.0})
	for index: int in range(10): report.captures.append({"path":"synthetic_contract_%02d.png" % index})
	return report

func _launch_checks() -> void:
	var args := PackedStringArray(["--qa-full","--handoff=C:/retained/save.json","--parent-report=C:/retained/parent.json",
		"--handoff-sha="+SAVE_SHA,"--parent-sha="+REPORT_SHA,"--output=C:/new-run"])
	_check(Probe.pretender_launch_error(args).is_empty(),"explicit absolute pinned launch admitted")
	var diagnostic := args.duplicate(); diagnostic.append("--diagnostic")
	_check(Probe.pretender_launch_error(diagnostic).is_empty(),"optional diagnostic flag admitted")
	for index: int in range(args.size()):
		var missing := args.duplicate(); missing.remove_at(index)
		_check(not Probe.pretender_launch_error(missing).is_empty(),"required launch field "+str(index))
	for extra: String in ["--qa-full","--diagnostic=yes","--headless","--seed=1","--teleport=1"]:
		var changed := args.duplicate(); changed.append(extra)
		_check(not Probe.pretender_launch_error(changed).is_empty(),"reject duplicate/unknown/value flag "+extra)
	for index: int in [1,2,5]:
		var changed := args.duplicate(); changed[index] = args[index].get_slice("=",0)+"=relative/path"
		_check(not Probe.pretender_launch_error(changed).is_empty(),"reject relative input/output "+str(index))
	_check(Probe.valid_sha(REPORT_SHA) and Probe.valid_sha(SAVE_SHA),"lowercase hexadecimal SHA256")
	for value: Variant in [null,123,true,[],{},"",REPORT_SHA.substr(0,63),REPORT_SHA+"0",REPORT_SHA.to_upper(),"g".repeat(64)]:
		_check(not Probe.valid_sha(value),"malformed digest "+str(value))
	completed_groups += 1

func _durable_checks() -> void:
	var saved: Dictionary = _saved(_summary())
	_check(Probe.durable_equal(saved,saved.duplicate(true)),"detached identical durable projection")
	var numeric: Dictionary = saved.duplicate(true); numeric.player.copper = 7.0
	_check(Probe.durable_equal(saved,numeric),"JSON int/float equal value")
	for root_key: String in ["player","state"]:
		for key: String in saved[root_key]:
			var removed: Dictionary = saved.duplicate(true); removed[root_key].erase(key)
			_check(not Probe.durable_equal(saved,removed),"missing durable key "+root_key+"."+key)
	var nested: Dictionary = saved.duplicate(true); nested.player.equip.tool = "crowbar"
	_check(not Probe.durable_equal(saved,nested),"nested equipment delta rejected")
	nested = saved.duplicate(true); nested.player.lifetime.pretendersDefeated += 1
	_check(not Probe.durable_equal(saved,nested),"nested lifetime delta rejected")
	nested = saved.duplicate(true); nested.player.cash += 0.00005
	_check(not Probe.durable_equal(saved,nested),"tiny actual cash change is not exact equality")
	for value: float in [NAN,INF,-INF]:
		nested = saved.duplicate(true); nested.player.cash = value
		_check(not Probe.durable_equal(saved,nested),"nonfinite durable cash rejected")
	var incidental: Dictionary = saved.duplicate(true); incidental["render_clock"] = 123; incidental.player["visual_bob"] = 3.0
	_check(Probe.durable_equal(saved,incidental),"unowned cosmetic fields excluded from durable projection")
	completed_groups += 1

func _binding_checks() -> void:
	var saved: Dictionary = _saved(_summary())
	var parent: Dictionary = _parent(saved)
	var untouched: Dictionary = parent.duplicate(true)
	_check(Probe.assess_parent_binding(parent,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"exact pinned lineage binding")
	_check(parent == untouched,"binding does not mutate parent")
	_check(not CampaignProof.assess_campaign(parent).is_empty(),"binding-only synthetic parent cannot satisfy full inherited campaign proof")
	for key: String in ["acceptance","status","format","failures"]:
		var changed: Dictionary = parent.duplicate(true)
		changed[key] = {"acceptance":false,"status":"failed","format":"other","failures":["native failure"]}[key]
		_check(not Probe.assess_parent_binding(changed,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"reject unsuccessful parent "+key)
	_check(not Probe.assess_parent_binding(parent,saved,REPORT_SHA,SAVE_SHA,SAVE_SHA,SAVE_SHA).is_empty(),"report hash pin mismatch")
	_check(not Probe.assess_parent_binding(parent,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,REPORT_SHA).is_empty(),"save hash pin mismatch")
	var changed: Dictionary = parent.duplicate(true); changed.persistence.save_sha256 = REPORT_SHA
	_check(not Probe.assess_parent_binding(changed,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"parent names different stored save")
	changed = parent.duplicate(true); changed.persistence.stored.player.cash += 10
	_check(not Probe.assess_parent_binding(changed,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"handoff does not match parent stored bytes")
	changed = parent.duplicate(true); changed.persistence.after.player.cash += 1
	_check(not Probe.assess_parent_binding(changed,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"parent resumed state differs from save")
	for value: Variant in ["emperor_boss","locked"]:
		var bad_saved: Dictionary = saved.duplicate(true); bad_saved.state.kingdom.stage = value
		_check(not Probe.assess_parent_binding(_parent(bad_saved),bad_saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"reject incomplete kingdom "+str(value))
	var bad_saved: Dictionary = saved.duplicate(true); bad_saved.state.kingdom.defeats.pop_back()
	_check(not Probe.assess_parent_binding(_parent(bad_saved),bad_saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"all four canonical ruler defeats required")
	completed_groups += 1

func _profile_checks() -> void:
	_check(source_clans.size() == 3,"source exports exactly three clan profiles")
	for day: int in [1,2,3,4,5,6,999999999,1000000000]:
		var expected: Dictionary = _profile(day,7)
		_check(Probe.pretender_profile(day,7) == expected,"actual source day modulo/profile "+str(day))
	for day: int in [-1,0,1000000001]: _check(Probe.pretender_profile(day,0).is_empty(),"invalid source day "+str(day))
	_check(Probe.pretender_profile(1,-1).is_empty(),"negative prior count refused")
	var one: Dictionary = Probe.pretender_profile(3,0); one.hp = 1
	_check(Probe.pretender_profile(3,0).hp == 100,"profile calls do not share mutable actor state")
	completed_groups += 1

func _spawn_checks() -> void:
	for day: int in [6,7,8]: _accept("spawn",_spawn(day,2),"canonical actual spawn "+str(day))
	var row: Dictionary = _spawn()
	for key: String in row.actor:
		if key in ["x","y","dead"]: continue
		var changed: Dictionary = row.duplicate(true); changed.actor.erase(key)
		_check(not Probe.assess_spawn(changed).is_empty(),"spawn requires actual source field "+key)
	for pair: Array in [["live_count",0],["live_count",2],["stage","emperor_boss"],["defeated_day",6],["spawn_day",5],["prior",-1]]:
		_bad("spawn",row,[pair[0]],pair[1],"spawn source/state mutation "+str(pair))
	_bad("spawn",row,["actor","archetype"],"grabber","wrong modulo archetype")
	_bad("spawn",row,["actor","noComboReward"],false,"pretender cannot acquire ordinary combo reward")
	var omitted: Dictionary = row.duplicate(true); omitted.actor.erase("dead")
	_accept("spawn",omitted,"source newly live actor may omit dead:false")
	_bad("spawn",row,["actor","dead"],true,"explicit dead actor cannot be the daily live spawn")
	var anchor: Dictionary = source_clans[0].boss
	var edge: Dictionary = row.duplicate(true); edge.actor.x = float(anchor.x)-16.0+100.0
	_accept("spawn",edge,"source anchor relocation at permitted100px boundary")
	_bad("spawn",row,["actor","x"],float(anchor.x)-16.0+100.01,"reject placement outside100px envelope")
	_bad("spawn",row,["actor","x"],NAN,"reject nonfinite position")
	completed_groups += 1

func _cot_checks() -> void:
	var row := {"hp":34.999,"max_hp":100.0,"day":5}
	_check(Probe.next_cot_action(row,0,6,false) == "rest","below35 uses real unpowered rest")
	row.hp = 35.0
	_check(Probe.next_cot_action(row,0,6,false) == "sleep","35 plus actual55 sleep reaches90")
	row.hp = 90.0
	_check(Probe.next_cot_action(row,0,6,false) == "sleep","healthy actor still needs next source day")
	_check(Probe.next_cot_action(row,8,6,false) == "sleep","ninth action allowed")
	_check(Probe.next_cot_action(row,9,6,false) == "refuse","budget exhausted before target day")
	row.day = 6
	_check(Probe.next_cot_action(row,9,6,false) == "done","completed day requires no additional action budget")
	row.hp = 89.999
	_check(Probe.next_cot_action(row,3,6,false) == "refuse","no extra recovery allowed after target day shortfall")
	for day: float in [4.0,7.0,5.5,NAN,INF]:
		_check(Probe.next_cot_action({"hp":90.0,"max_hp":100.0,"day":day},0,6,false) == "refuse","invalid/skipped day "+str(day))
	for hp: Variant in [0,-1,NAN,INF,"90"]:
		_check(Probe.next_cot_action({"hp":hp,"max_hp":100.0,"day":5},0,6,false) == "refuse","invalid or dead cot hp "+str(hp))
	_check(Probe.next_cot_action({"hp":35.0,"max_hp":100.0,"day":5},0,6,true) == "refuse","no cot recovery in combat")
	for used: int in [-1,10]: _check(Probe.next_cot_action({"hp":90.0,"max_hp":100.0,"day":6},used,6,false) == "refuse","invalid cot budget "+str(used))
	for maximum: Variant in [89.99,NAN,INF,"100"]:
		_check(Probe.next_cot_action({"hp":35.0,"max_hp":maximum,"day":5},0,6,false) == "refuse","invalid/insufficient maximumHP "+str(maximum))
	_check(Probe.next_cot_action({"hp":101.0,"max_hp":100.0,"day":5},0,6,false) == "refuse","HP cannot exceed maximum")
	var cot: Dictionary = _cot(6)
	_check(CampaignProof.assess_cot(cot).is_empty(),"source unpowered55HP sleep receipt with actual day event")
	var bad: Dictionary = cot.duplicate(true); bad.after.hp = 90.0
	_check(not CampaignProof.assess_cot(bad).is_empty(),"not an invented50HP sleep")
	completed_groups += 1

func _reward_checks() -> void:
	var row: Dictionary = _reward()
	_accept("reward",row,"single actual fatal hit source reward")
	var omitted: Dictionary = row.duplicate(true); omitted.target_before.erase("dead")
	_accept("reward",omitted,"source positiveHP target may omit predeath flag")
	for pair: Array in [["cash",211.0],["cred",243],["copper",8],["rocks",1],["weapon","pipe"],["pretenders_lifetime",4]]:
		_bad("reward",row,["after",pair[0]],pair[1],"reject extra/replaced reward "+str(pair))
	_bad("reward",row,["after","equip","tool"],"crowbar","reward cannot grant equipment")
	_bad("reward",row,["after","claims","canal"],false,"reward cannot alter claims")
	_bad("reward",row,["after","kingdom","defeats"],[],"reward preserves ruler defeats")
	_bad("reward",row,["before","kingdom","pretenderDefeatedDay"],6,"same-day duplicate reward refused")
	_bad("reward",row,["after","kingdom","pretendersDefeated"],4,"Kingdom counter increments once")
	_bad("reward",row,["after","kingdom","pretenderDefeatedDay"],7,"reward stamped exact day")
	_bad("reward",row,["after","day"],7,"fatal receipt cannot straddle dawn")
	_bad("reward",row,["events"],[],"missing actual attack and death receipts")
	var duplicate: Array = row.events.duplicate(true); duplicate.append(duplicate[1].duplicate(true))
	_bad("reward",row,["events"],duplicate,"duplicate death receipt rejected")
	duplicate = row.events.duplicate(true); duplicate.append(duplicate[0].duplicate(true))
	_bad("reward",row,["events"],duplicate,"duplicate hit receipt rejected")
	_bad("reward",row,["events",0,"payload","hits"],["other"],"fatal target absent from actual hit list")
	_bad("reward",row,["events",1,"payload","actor_id"],"other","wrong actual actor death")
	_bad("reward",row,["target_before","id"],"other","before body must be fatal target")
	_bad("reward",row,["target_after","id"],"other","after body must be fatal target")
	_bad("reward",row,["target_before","dead"],true,"cannot kill already dead body")
	_bad("reward",row,["target_before","hp"],0.0,"fatal input must start from positiveHP")
	_bad("reward",row,["target_before","hp"],NAN,"fatal input needs finiteHP")
	_bad("reward",row,["target_after","hp"],1.0,"positiveHP is not a source death")
	_bad("reward",row,["target_after","dead"],false,"actual death flag required")
	completed_groups += 1

func _reload_checks() -> void:
	var row: Dictionary = _reload()
	_accept("reload",row,"exact same-day durable reload")
	for phase: String in ["before","stored","after"]:
		_bad("reload",row,[phase,"player","cash"],999.0,"reload resource drift in "+phase)
		_bad("reload",row,[phase,"state","kingdom","pretenderDefeatedDay"],5,"reload loses defeat stamp in "+phase)
		_bad("reload",row,[phase,"state","day"],7,"reload crosses day in "+phase)
	for pair: Array in [["epoch_delta",0],["epoch_delta",2],["live_count",1],["resumed_motion",false],["save_sha256","missing"]]:
		_bad("reload",row,[pair[0]],pair[1],"reload evidence mutation "+str(pair))
	completed_groups += 1

func _tour_checks() -> void:
	var report: Dictionary = _tour()
	_accept("tour",report,"complete synthetic three-day evidence fixture, not native acceptance")
	for key: String in ["spawns","rewards","reloads","fights","transactions","captures","phase_states"]:
		_bad("tour",report,[key],[],"missing required evidence "+key)
	for key: String in ["state_writes","deaths","arrests","escapes","unexpected_epochs"]:
		_bad("tour",report,[key],1,"forbidden continuation change "+key)
	for key: String in ["parent_contract_valid","parent_accepted"]: _bad("tour",report,["input",key],false,"missing full parent proof "+key)
	_bad("tour",report,["input","fixture_writes"],1,"no new resource fixture allowed")
	_bad("tour",report,["input","handoff_sha256"],"","hash-backed handoff required")
	for value: float in [0.0,-1.0,600000.0,INF,NAN]: _bad("tour",report,["wall_ms"],value,"strict10min positive finite watchdog "+str(value))
	for count: int in [2,10]: _bad("tour",report,["rest_count"],count,"bounded actual cot count "+str(count))
	_bad("tour",report,["final","day"],9,"three consecutive days only")
	_bad("tour",report,["final","kingdom","pretendersDefeated"],6,"final counter must increase exactly3")
	_bad("tour",report,["final","pretenders_lifetime"],4,"final lifetime must increase exactly3")
	_bad("tour",report,["final","claims","canal"],false,"no claim mutation in bounded tour")
	_bad("tour",report,["spawns",1],_spawn(8,3),"duplicate/skipped spawn day")
	_bad("tour",report,["spawns",1],_spawn(7,2),"spawn prior must follow first actual reward")
	_bad("tour",report,["rewards",1],_reward(7,2),"per-day reward counters must join initial and preceding reward")
	_bad("tour",report,["reloads",1],_reload(7,2),"reload must retain that day's actual counter")
	for pair: Array in [["id","curb_pretender_99"],["day",9],["won",false],["source_damage",false],["cooldowns_valid",false],["accepted_attacks",0],["wall_ms",90000.0],["wall_ms",0.0]]:
		_bad("tour",report,["fights",0,pair[0]],pair[1],"actual timed fight witness "+str(pair))
	for pair: Array in [["id","curb_pretender_99"],["kind","office_before_approach"],["saved",false],["alive",false],
		["on_screen",false],["static_los",false],["process_frame",-1],["distance",65.0]]:
		_bad("tour",report,["fights",0,"engagement_view",pair[0]],pair[1],"completed engagement witness "+str(pair))
	var boundary: Dictionary = report.duplicate(true)
	boundary.fights[0].engagement_view.process_frame = 0; boundary.fights[0].engagement_view.distance = 0.0
	_accept("tour",boundary,"engagement frame and distance admit their nonnegative endpoints")
	boundary.fights[0].engagement_view.distance = 64.999
	_accept("tour",boundary,"engagement distance strictly below65 remains valid")
	_bad("tour",report,["transactions",0,"after","hp"],100.0,"cot receipt cannot invent healing")
	_bad("tour",report,["transactions",0,"details","boss_active"],true,"cot receipt cannot hide combat")
	_bad("tour",report,["phase_states",0,"wall_ms"],30000.0,"strict load phase boundary")
	_bad("tour",report,["phase_states",1,"wall_ms"],180000.0,"strict day phase boundary")
	_bad("tour",report,["phase_states",2,"id"],"day_3","ordered phase identity")
	var phases: Array = report.phase_states.duplicate(true); phases.append({"id":"extra","wall_ms":1.0})
	_bad("tour",report,["phase_states"],phases,"extra phase rejects cleanly rather than indexing past names")
	for key: String in ["motion_frames","mouse_motion","keys","clicks"]: _bad("tour",report,["input_counts",key],0,"required real input evidence "+key)
	_bad("tour",report,["weapon_errors"],["invalid chain"],"source-earned weapon chain audit")
	var captures: Array = report.captures.duplicate(true)
	while captures.size() < 13: captures.append({"path":"extra.png"})
	_bad("tour",report,["captures"],captures,"twelve-capture bound")
	for pair: Array in [["day_events",65],["events",40001],["samples",3601],["legs",97],["menus",257],["walking",1025],["combat_navigation",2049],["attack_receipts",3001]]:
		var excess: Array = []; excess.resize(pair[1]); excess.fill({})
		_bad("tour",report,[pair[0]],excess,"bounded retained evidence "+str(pair[0]))
	completed_groups += 1

func _aggregate_parent(saved: Dictionary) -> Dictionary:
	# Admission binding fixture only: it intentionally omits actual campaign receipts.
	var suffix: Dictionary = _parent(saved)
	suffix.format = "rock-bottom-campaign-kingdom-suffix"
	var checkpoint: Dictionary = saved.duplicate(true)
	checkpoint.state.kingdom.stage = "summons"; checkpoint.state.kingdom.defeats = []
	return {"format":"rock-bottom-campaign-two-run-aggregate","runs":2,"continuous_run":false,
		"acceptance":true,"status":"complete","failures":[],
		"prefix":{"format":"rock-bottom-campaign-tony-prefix","acceptance":true,"status":"complete","failures":[],
			"checkpoint":{"save_sha256":"a".repeat(64),"stored":checkpoint.duplicate(true)}},
		"suffix":suffix,"five_bosses":[]}

func _admission_reject(parent: Dictionary,saved: Dictionary,path: Array,value: Variant,label: String) -> void:
	var changed: Dictionary = parent.duplicate(true)
	var cursor: Variant = changed
	for index: int in range(path.size()-1): cursor = cursor[path[index]]
	cursor[path[-1]] = value
	_check(Probe.completed_parent_run(changed).is_empty(),"completed-parent selection rejects "+label)
	_check(not Probe.assess_parent_binding(changed,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"binding rejects "+label)
	_check(not Probe.parent_contract_errors(changed).is_empty(),"mandatory parent proof rejects "+label)

func _aggregate_admission_checks() -> void:
	var saved: Dictionary = _saved(_summary())
	var full: Dictionary = _parent(saved)
	var aggregate: Dictionary = _aggregate_parent(saved)
	var original: Dictionary = aggregate.duplicate(true)
	_check(Probe.completed_parent_run(full) == full,"accepted full parent projects its own completed run")
	_check(Probe.completed_parent_run(aggregate) == aggregate.suffix,"accepted aggregate projects only its completed suffix")
	_check(Probe.assess_parent_binding(aggregate,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"aggregate binding uses suffix final persistence with top-level pins")
	_check(aggregate == original,"aggregate admission leaves both original constituent reports unchanged")
	_check(not Probe.parent_contract_errors(full).is_empty(),"binding-only full fixture still lacks the mandatory full campaign proof")
	_check(not Probe.parent_contract_errors(aggregate).is_empty(),"binding-only aggregate still lacks mandatory prefix and suffix campaign proofs")
	_check(Probe.parent_contract_errors(full) == CampaignProof.assess_campaign(full),"accepted full format invokes unchanged complete campaign contract")
	_check(Probe.parent_contract_errors(aggregate) == CampaignProof.assess_aggregate(aggregate),"accepted aggregate invokes complete two-run contract rather than suffix alone")
	var projected: Dictionary = Probe.completed_parent_run(aggregate)
	projected.persistence.stored.player.cash += 1
	projected.persistence.stored.state.kingdom.defeats.append("invented")
	_check(aggregate == original and Probe.completed_parent_run(aggregate) == original.suffix,"aggregate selected run has no nested mutable aliases")
	var full_original: Dictionary = full.duplicate(true)
	projected = Probe.completed_parent_run(full); projected.persistence.after.player.equip.tool = "crowbar"
	_check(full == full_original,"full completed run projection is also deeply detached")
	for key: String in ["acceptance","status","failures"]:
		var value: Variant = {"acceptance":false,"status":"failed","failures":["retained native failure"]}[key]
		_admission_reject(aggregate,saved,[key],value,"aggregate "+key)
		for part: String in ["prefix","suffix"]:
			_admission_reject(aggregate,saved,[part,key],value,part+" "+key)
	_admission_reject(aggregate,saved,["status"],"partial","partial top-level report")
	_admission_reject(aggregate,saved,["prefix","status"],"partial","partial prefix")
	_admission_reject(aggregate,saved,["suffix","status"],"partial","partial suffix")
	for pair: Array in [["runs",1],["runs",3],["continuous_run",true],["format","other"]]:
		_admission_reject(aggregate,saved,[pair[0]],pair[1],"incorrect aggregate composition "+str(pair))
	_admission_reject(aggregate,saved,["prefix","format"],"rock-bottom-campaign-continuation","wrong prefix format")
	_admission_reject(aggregate,saved,["suffix","format"],"rock-bottom-campaign-continuation","wrong suffix format")
	for part: String in ["prefix","suffix"]:
		_admission_reject(aggregate,saved,[part],null,"missing "+part+" dictionary")
		_check(Probe.completed_parent_run(aggregate[part]).is_empty(),"standalone "+part+" is not a completed campaign parent")
		_check(not Probe.assess_parent_binding(aggregate[part],saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"standalone "+part+" cannot authorize pretender save")
		_check(not Probe.parent_contract_errors(aggregate[part]).is_empty(),"standalone "+part+" cannot bypass full campaign assessment")
	var misleading: Dictionary = aggregate.duplicate(true)
	misleading.persistence = {"save_sha256":"a".repeat(64),"stored":aggregate.prefix.checkpoint.stored.duplicate(true),"after":aggregate.prefix.checkpoint.stored.duplicate(true)}
	_check(Probe.assess_parent_binding(misleading,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"aggregate top-level persistence cannot override selected completed suffix")
	var before_kingdom: Dictionary = aggregate.prefix.checkpoint.stored
	_check(not Probe.assess_parent_binding(aggregate,before_kingdom,REPORT_SHA,"a".repeat(64),REPORT_SHA,"a".repeat(64)).is_empty(),"pre-Kingdom prefix checkpoint cannot replace completed suffix handoff")
	misleading = aggregate.duplicate(true); misleading.suffix.persistence = misleading.prefix.checkpoint.duplicate(true)
	misleading.suffix.persistence.after = before_kingdom.duplicate(true)
	_check(not Probe.assess_parent_binding(misleading,before_kingdom,REPORT_SHA,"a".repeat(64),REPORT_SHA,"a".repeat(64)).is_empty(),"consistently substituted pre-Kingdom save still fails completed-Kingdom requirement")
	_check(not Probe.assess_parent_binding(aggregate,saved,REPORT_SHA,SAVE_SHA,"b".repeat(64),SAVE_SHA).is_empty(),"nested suffix pin cannot replace exact raw top-level report pin")
	misleading = aggregate.duplicate(true); misleading.suffix.persistence.after.player.cash += 1
	_check(not Probe.assess_parent_binding(misleading,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"completed suffix actual resumed state must match retained final save")
	var tour: Dictionary = _tour()
	tour.input.parent_format = "rock-bottom-campaign-two-run-aggregate"; tour.input.parent_runs = 2
	_accept("tour",tour,"same finite pretender tour truthfully declares two-run aggregate parent")
	_bad("tour",tour,["input","parent_runs"],1,"aggregate parent cannot be labeled one continuous run")
	_bad("tour",_tour(),["input","parent_runs"],2,"uninterrupted full parent cannot be mislabeled as two runs")
	for value: String in ["rock-bottom-campaign-tony-prefix","rock-bottom-campaign-kingdom-suffix","other"]:
		_bad("tour",tour,["input","parent_format"],value,"pretender tour refuses unsupported parent format "+value)
	var decoded_full: Dictionary = JSON.parse_string(JSON.stringify(full))
	var decoded_aggregate: Dictionary = JSON.parse_string(JSON.stringify(aggregate))
	var decoded_save: Dictionary = JSON.parse_string(JSON.stringify(saved))
	_check(Probe.assess_parent_binding(decoded_full,decoded_save,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"parsed full parent and parsed final save retain exact binding")
	_check(Probe.assess_parent_binding(decoded_aggregate,decoded_save,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"parsed aggregate and parsed suffix save retain exact binding")
	_check(Probe.assess_parent_binding(aggregate,decoded_save,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"live aggregate and decoded equal numeric save retain exact binding")
	_check(Probe.assess_parent_binding(decoded_aggregate,saved,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"decoded aggregate and live equal numeric save retain exact binding")
	var decoded_original: Dictionary = decoded_aggregate.duplicate(true)
	projected = Probe.completed_parent_run(decoded_aggregate); projected.persistence.stored.state.office.orderSerial += 1
	_check(decoded_aggregate == decoded_original,"parsed selected suffix remains deeply detached")
	var parsed_errors: Array[String] = Probe.parent_contract_errors(decoded_aggregate)
	_check(not parsed_errors.is_empty() and parsed_errors == CampaignProof.assess_aggregate(decoded_aggregate),"parsed binding-only aggregate still requires complete inherited campaign proof")
	_check(not Probe.parent_contract_errors(decoded_full).is_empty() and Probe.parent_contract_errors(decoded_full) == CampaignProof.assess_campaign(decoded_full),"parsed binding-only full report still requires complete uninterrupted proof")
	for path: Array in [["status"],["prefix","status"],["suffix","status"]]:
		for status: String in ["failed","partial"]: _admission_reject(decoded_aggregate,decoded_save,path,status,"parsed failed/partial boundary "+str(path))
	for path: Array in [["acceptance"],["prefix","acceptance"],["suffix","acceptance"]]:
		_admission_reject(decoded_aggregate,decoded_save,path,false,"parsed false acceptance "+str(path))
	for path: Array in [["failures"],["prefix","failures"],["suffix","failures"]]:
		_admission_reject(decoded_aggregate,decoded_save,path,["actual failure"],"parsed retained failures "+str(path))
	for part: String in ["prefix","suffix"]:
		_check(Probe.completed_parent_run(decoded_aggregate[part]).is_empty() and not Probe.parent_contract_errors(decoded_aggregate[part]).is_empty(),"parsed standalone "+part+" still cannot admit a continuation")
	for value: Variant in [2.00005,"2",true,NAN,INF,-INF]:
		var bad_save: Dictionary = decoded_save.duplicate(true); bad_save.state.office.orderSerial = value
		_check(not Probe.assess_parent_binding(decoded_aggregate,bad_save,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"parsed saved serial rejects nonexact value "+str(value))
	var bad_save: Dictionary = decoded_save.duplicate(true); bad_save.player.cash += 0.00005
	_check(not Probe.assess_parent_binding(decoded_aggregate,bad_save,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"parsed tiny real cash difference remains disqualifying")
	bad_save = decoded_save.duplicate(true); bad_save.state.office.erase("orderSerial")
	_check(not Probe.assess_parent_binding(decoded_aggregate,bad_save,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"parsed missing nested field is not normalized away")
	bad_save = decoded_save.duplicate(true); bad_save["invented"] = 0
	_check(not Probe.assess_parent_binding(decoded_aggregate,bad_save,REPORT_SHA,SAVE_SHA,REPORT_SHA,SAVE_SHA).is_empty(),"exact whole stored save rejects even an extra cosmetic root key")
	_check(not Probe.assess_parent_binding(decoded_aggregate,decoded_save,REPORT_SHA,SAVE_SHA,"b".repeat(64),SAVE_SHA).is_empty(),"parsed equivalence never replaces exact raw top-level report pin")
	_check(not Probe.assess_parent_binding(decoded_aggregate,decoded_aggregate.prefix.checkpoint.stored,REPORT_SHA,"a".repeat(64),REPORT_SHA,"a".repeat(64)).is_empty(),"parsed pre-Kingdom checkpoint remains ineligible")
	completed_groups += 1

func _transit_row(body: Dictionary,day: int,phase: String,started: int,elapsed: int,first: int,last: int,budget: Dictionary) -> Dictionary:
	return {"id":body.id,"day":day,"source_before":body.duplicate(true),
		"admission":{"phase":phase,"expected":"","mode":"playing","boss_active":false,"source_center":[float(body.x)+16.0,float(body.y)+16.0]},
		"start_wall":started,"end_wall":started+elapsed,"first_attack":first,"last_attack":last,"budget":budget.duplicate(true)}

func _transit_bad(rows: Array,attacks: Array,index: int,path: Array,value: Variant,label: String) -> void:
	var changed: Array = rows.duplicate(true)
	var cursor: Variant = changed[index]
	for position: int in range(path.size()-1): cursor = cursor[path[position]]
	cursor[path[-1]] = value
	_check(not Probe.assess_transit_defenses(changed,attacks).is_empty(),label)

func _transit_defense_checks() -> void:
	for phase: String in ["day_1","day_2","day_3"]:
		_check(Probe.guard_transit_allowed(phase,"","playing",false),"ordinary pretender transit admits defense: "+phase)
		_check(not Probe.guard_transit_allowed(phase,"curb_pretender_14","playing",false),"expected pretender retains its own fight selector")
		_check(not Probe.guard_transit_allowed(phase,"","playing",true),"active boss never becomes transit defense")
		for mode: String in ["dialogue","paused","title","cookmini","ending"]:
			_check(not Probe.guard_transit_allowed(phase,"",mode,false),"nonplaying mode refuses transit defense: "+mode)
	for phase: String in ["","load","day_0","day_4","blue_tarp","cart_cavalry","copper_choir","emperor","persistence"]:
		_check(not Probe.guard_transit_allowed(phase,"","playing",false),"old or unrelated phase remains excluded: "+phase)
	var generated_guards: Array[Dictionary] = []
	for day: int in range(13,17):
		var supplied := {"stage":"complete","defeats":DEFEATS.duplicate(),"pretendersDefeated":3}
		var untouched: Dictionary = supplied.duplicate(true)
		var plan: Dictionary = Campaign.plan_for_state(day,supplied,3)
		_check(plan.get("ok",false) and supplied == untouched,"real completed-stage force plan is read-only: "+str(day))
		if not plan.get("ok",false): return
		var guard_count := 0
		for actor: Dictionary in plan.actors:
			var center := Vector2(float(actor.x)+16.0,float(actor.y)+16.0)
			var original: Dictionary = actor.duplicate(true)
			if actor.get("kingdomGuard",false):
				guard_count += 1; generated_guards.append(actor.duplicate(true))
				_check(actor.get("hostile") == true and actor.get("aggro") == false,"actual post-Kingdom guard is hostile without aggro: "+str(actor.id))
				_check(CampaignProof.court_guard_candidate(actor,day,center),"actual generated guard can be defended against: "+str(actor.id))
				_check(not CampaignProof.court_guard_candidate(actor,day,center+Vector2(85,0)),"actual guard respects exact85px boundary")
				_check(not CampaignProof.court_guard_candidate(actor,day+1,center),"old-day generated guard is stale")
			else: _check(not CampaignProof.court_guard_candidate(actor,day,center),"generated pretender is never ordinary guard defense")
			_check(actor == original,"candidate inspection preserves actual generated record")
		_check(guard_count == 8,"completed source day retains eight ordinary guards")
	_check(generated_guards.size() == 32,"four real day plans supply32 distinct guard witnesses")
	if generated_guards.size() != 32: return
	var guard: Dictionary = generated_guards[0]
	var center := Vector2(float(guard.x)+16.0,float(guard.y)+16.0)
	_check(CampaignProof.court_guard_candidate(guard,13,center+Vector2(84.99,0)),"inside strict guard radius is accepted")
	for pair: Array in [["dead",true],["hostile",false],["kingdomGuard",false],["essential",true],["kingdomBoss",true],["kingdomPretender",true],
		["hp",0],["hp",NAN],["x",INF],["w",31],["name","CURB PRETENDER No. 4"],["sprite","receipt_guard"],
		["kingdomClan","cart_cavalry"],["id","kingdom_guard_blue_tarp_12_0"],["id","kingdom_guard_blue_tarp_13_00"]]:
		var changed: Dictionary = guard.duplicate(true); changed[pair[0]] = pair[1]
		_check(not CampaignProof.court_guard_candidate(changed,13,center),"invalid ordinary guard rejected: "+str(pair))
	var aggro_only: Dictionary = guard.duplicate(true); aggro_only.hostile = false; aggro_only.aggro = true
	_check(CampaignProof.court_guard_candidate(aggro_only,13,center),"aggro-only actual identity also qualifies")

	var budget := CampaignProof.CourtDefenseBudget.new()
	var id: String = str(guard.id); var next_id: String = str(generated_guards[8].id)
	_check(budget.begin(id,1000),"first transit bout admitted")
	_check(not budget.begin(id,1100) and not budget.begin(next_id,1100),"active bout excludes duplicate and competing begins")
	var first_budget: Dictionary = budget.finish(4000)
	_check(first_budget.ok and first_budget.elapsed_ms == 3000 and budget.remaining_ms(id) == 7000,"actual completed time reduces original guard allowance")
	_check(budget.begin(next_id,5000) and budget.finish(6000).ok,"next source day shares the same budget instance")
	_check(budget.remaining_ms(id) == 7000 and budget.total_ms == 4000,"day transition does not reset prior guard or global time")
	_check(budget.begin(id,7000),"second bout resumes original guard")
	var second_budget: Dictionary = budget.finish(13999)
	_check(second_budget.ok and second_budget.guard_ms == 9999 and second_budget.total_ms == 10999,"second bout accumulates without charging idle gaps")
	_check(not budget.can_begin(id) and budget.remaining_ms(id) == 1,"two-bout cap applies despite residual time")
	_check(first_budget.total_ms == 3000 and first_budget.guard_ms == 3000,"earlier receipt stays detached")
	var exact := CampaignProof.CourtDefenseBudget.new()
	_check(exact.begin(id,0) and exact.finish(6000).ok and exact.begin(id,7000),"exact10s two-bout boundary setup")
	var exact_end: Dictionary = exact.finish(11000)
	_check(not exact_end.ok and exact_end.guard_ms == 10000 and exact.remaining_ms(id) == 0 and not exact.can_begin(id),"exact cumulative10s is consumed and rejected")
	var census := CampaignProof.CourtDefenseBudget.new()
	for index: int in range(15):
		var candidate_id: String = str(generated_guards[index].id)
		_check(census.begin(candidate_id,index*10) and census.finish(index*10+1).ok,"one persistent ledger admits unique guard: "+str(index))
	_check(census.guard_ms.size() == 15 and not census.can_begin(str(generated_guards[15].id)),"new source-day identities cannot exceed15 slots")
	for index: int in range(15):
		var candidate_id: String = str(generated_guards[index].id)
		_check(census.begin(candidate_id,1000+index*10) and census.finish(1001+index*10).ok,"existing guard can use second bout: "+str(index))
	_check(census.bouts == 30 and census.total_ms == 30 and not census.can_begin(id) and not census.can_begin(next_id),"thirty total bouts never reset")
	var global_budget := CampaignProof.CourtDefenseBudget.new()
	for index: int in range(15):
		var candidate_id: String = str(generated_guards[index].id)
		_check(global_budget.begin(candidate_id,index*20000) and global_budget.finish(index*20000+9999).ok,"global ledger near-limit setup: "+str(index))
	_check(global_budget.total_ms == 149985,"all near-limit elapsed time is retained")
	for index: int in range(15):
		var candidate_id: String = str(generated_guards[index].id)
		_check(global_budget.begin(candidate_id,400000+index*10),"final remaining guard millisecond admitted")
		_check(not global_budget.finish(400001+index*10).ok,"exact per-guard exhaustion cannot be forgiven")
	_check(global_budget.total_ms == 150000 and global_budget.remaining_ms(str(generated_guards[16].id)) == 0 and not global_budget.can_begin(id),"exact150s global exhaustion denies all new admissions")

	# Explicit synthetic evidence, not native receipts. Counts are stated independently
	# of the budget implementation, including a real next-day actor identity.
	var attacks: Array = [{"synthetic":true},{"synthetic":true},{"synthetic":true},{"synthetic":true}]
	var rows: Array = [
		_transit_row(guard,13,"day_1",100,1000,0,1,{"ok":true,"id":id,"elapsed_ms":1000,"guard_ms":1000,"total_ms":1000,"bouts":1,"unique_guards":1}),
		_transit_row(guard,13,"day_1",2000,2000,1,2,{"ok":true,"id":id,"elapsed_ms":2000,"guard_ms":3000,"total_ms":3000,"bouts":2,"unique_guards":1}),
		_transit_row(generated_guards[8],14,"day_2",5000,1500,2,4,{"ok":true,"id":next_id,"elapsed_ms":1500,"guard_ms":1500,"total_ms":4500,"bouts":3,"unique_guards":2})]
	var immutable: Array = rows.duplicate(true)
	var errors: Array[String] = Probe.assess_transit_defenses(rows,attacks)
	_check(errors.is_empty(),"explicit synthetic transit receipts accepted: "+str(errors))
	_check(rows == immutable and attacks.size() == 4,"receipt validation changes no inputs")
	var parsed_rows: Variant = JSON.parse_string(JSON.stringify(rows))
	_check(parsed_rows is Array and Probe.assess_transit_defenses(parsed_rows,attacks).is_empty(),"JSON-decoded exact numeric defense receipts accepted")
	var receipt_overhead: Array = rows.duplicate(true); receipt_overhead[0].end_wall += 1
	_check(Probe.assess_transit_defenses(receipt_overhead,attacks).is_empty(),"one millisecond after budget finish is honest receipt overhead")
	_check(Probe.assess_transit_defenses([],[]).is_empty(),"no necessary transit defense is a valid empty ledger")
	for pair: Array in [["phase","blue_tarp"],["phase","day_4"],["expected","curb_pretender_13"],["mode","dialogue"],["boss_active",true],
		["source_center",[center.x+85.0,center.y]],["source_center",[NAN,center.y]],["source_center",[center.x]]]:
		_transit_bad(rows,attacks,0,["admission",pair[0]],pair[1],"invalid admission receipt: "+str(pair))
	for pair: Array in [["day",14],["id",next_id],["start_wall",-1],["end_wall",1099],["end_wall",10100],["first_attack",-1],["first_attack",1.5],["last_attack",5],["last_attack",-1]]:
		_transit_bad(rows,attacks,0,[pair[0]],pair[1],"invalid defense row: "+str(pair))
	for pair: Array in [["ok",false],["id",next_id],["elapsed_ms",1000.5],["guard_ms",999],["total_ms",999],["bouts",2],["unique_guards",2]]:
		_transit_bad(rows,attacks,0,["budget",pair[0]],pair[1],"invalid cumulative receipt: "+str(pair))
	_transit_bad(rows,attacks,2,["budget","total_ms"],1500,"next-day receipt cannot reset global consumption")
	_transit_bad(rows,attacks,2,["budget","bouts"],1,"next-day receipt cannot reset bout count")
	_transit_bad(rows,attacks,0,["source_before","dead"],true,"dead source target cannot be justified after the fact")
	_transit_bad(rows,attacks,0,["source_before","hostile"],false,"neutral nonaggro source target cannot be defended against")
	var zero_shots: Array = rows.duplicate(true); zero_shots[0].last_attack = 0
	_check(Probe.assess_transit_defenses(zero_shots,attacks).is_empty(),"target leaving before first click permits a real empty attack slice")
	completed_groups += 1

func _run() -> void:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/source_content.json"))
	_check(decoded is Dictionary,"canonical exported source content readable")
	if decoded is Dictionary:
		source_clans = decoded.get("definitions",{}).get("src/systems/campaigns.js",{}).get("KINGDOM_CLAN_LIST",[])
	_check(source_clans.size() == 3,"independent source clan table exists")
	if source_clans.size() == 3:
		_launch_checks(); _durable_checks(); _binding_checks(); _profile_checks(); _spawn_checks()
		_cot_checks(); _reward_checks(); _reload_checks(); _tour_checks(); _aggregate_admission_checks(); _transit_defense_checks()
	_check(completed_groups == GROUPS,"all eleven groups reach their actual tails; runtime abort cannot pass")
	for failure: String in failures: printerr("FAIL: "+failure)
	print("DRAFT PRETENDER CONTINUATION CONTRACT: %s (%d checks; %d/%d completed groups; synthetic evidence only, not native acceptance)" % ["PASS" if failures.is_empty() else "FAIL",checks,completed_groups,GROUPS])
	quit(0 if failures.is_empty() else 1)
