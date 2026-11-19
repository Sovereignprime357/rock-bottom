extends SceneTree
## Acceptance-validator counterexamples. These dictionaries are not fight evidence.
const Probe = preload("res://tests/boss_acceptance_probe.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _valid() -> Dictionary:
	return {"fixture":{"kind":"fresh_cash_only","cash_grant":25,"weapon":"fists","hp":100},"initial":{"cash":25,"hp":100,"max_hp":100,"weapon":"fists","rocks":0,"cred":0,"brain":70,"offenses":0,"rocks_smoked":0,"speed":2.2,"cart_mounted":false,"equip":{"coat":null,"hat":null,"shoes":null,"tool":null},"inventory":[]},"costs":[10,5,5,5],"fight":{"started":true,"won":true,"tony_dead":true,"globals_clear":true,"quest_done":true,"shoe_reward":true,"fists_only":true,"cooldowns_valid":true,"wall_ms":8000.0,"active_ms":7500.0,"phases":[1,2,3],"adds":["sherri_boss_a","sherri_boss_b"],"damage":205,"high_hits":8,"accepted_attacks":8},"loop":{"purchased":true,"spent":true,"smokes":1,"initial_high":18000.0,"high_ms":18020.0,"crash_ms":8005.0,"ending_seen":true,"continued":true},"deaths":0,"arrests":0,"epoch_replacements":0,"dependencies":[],"canonical_roster_retained":true,"inputs":{"motion_frames":2,"mouse_motion":2,"keys":2,"clicks":2,"capture_clicks":2}}
func _attack_row(before: String,after: String,id: String,ordinary: bool,victory: bool,active: float) -> Dictionary:
	# Synthetic evidence-validator fixtures only; no model damage or fight claim.
	var events: Array[Dictionary] = [
		{"kind":"actor_hit","payload":{"actor_id":id,"damage":20,"weapon":after}},
		{"kind":"actor_died","payload":{"actor_id":id}}]
	if before != after:
		var name_value: String = Content.load_content().catalogs.weapons[after].n
		events.append({"kind":"toast","payload":{"text":"+ "+name_value+"\n(equipped.)"}})
		events.append({"kind":"feed","payload":{"text":"picked up "+name_value+". things are escalating."}})
	events.append({"kind":"player_attack","payload":{"used_weapon":before,"hits":[id],"connected":true}})
	var pre: Dictionary = {}; var post: Dictionary = {}
	pre[id] = {"hp":15.0,"dead":false,"ordinary_reward":ordinary}; post[id] = {"hp":-5.0,"dead":true}
	return {"before_weapon":before,"after_weapon":after,"before_cd":0.0,"after_cd":Content.load_content().catalogs.weapons[before].cd,"active_ms":active,"wall_ms":active+100.0,"boss_before":true,"quest_before":false,"victory_after":victory,"events":events,"actors_before":pre,"actors_after":post}
func _earned_rows() -> Array[Dictionary]:
	return [_attack_row("fists","pipe","sherri_boss_a",true,false,1000.0),_attack_row("pipe","shoe","tony",false,true,1400.0)]
func _weapon_checks() -> void:
	var rows: Array[Dictionary] = _earned_rows()
	var result: Dictionary = Probe.weapon_chain(rows)
	_check(result.ok and not result.fists_only and result.weapons_used == ["fists","pipe"],"actual source reward evidence permits earned pipe and explicitly denies fists-only")
	_check(result.transitions.size() == 2 and result.transitions[0].actor_id == "sherri_boss_a" and result.transitions[1].actor_id == "tony","pipe and special Tony shoe have separate source death provenance")
	var report: Dictionary = _valid(); report.contract_mode = "source_earned"; report.attack_receipts = rows; report.fight.fists_only = false
	_check(Probe.assess(report).is_empty(),"source-earned acceptance is a separate explicit contract")
	_check(not Probe.assess(report,"fists_only").is_empty(),"same earned-pipe receipt still fails optional strict fists-only")
	rows = [_attack_row("fists","shoe","tony",false,true,1000.0)]
	result = Probe.weapon_chain(rows)
	_check(result.ok and result.fists_only,"post-fatal shoe snapshot does not rewrite pre-attack fists/used_weapon")
	# Source special death may emit actor_died before actor_hit in the fatal call.
	var swap: Dictionary = rows[0].events[0]; rows[0].events[0] = rows[0].events[1]; rows[0].events[1] = swap
	_check(Probe.weapon_chain(rows).ok,"source Tony fatal event order remains valid")
	for change: String in ["starting_pipe","used_weapon","missing_death","dead_before","hp_after","nonordinary","missing_toast","missing_feed","unbacked_switch","early_shoe","wrong_kill","missing_victory","cooldown","premature_quest","nan_health","nan_cooldown","feed_order","reward_order"]:
		rows = _earned_rows()
		match change:
			"starting_pipe": rows[0].before_weapon = "pipe"
			"used_weapon": rows[0].events[-1].payload.used_weapon = "pipe"
			"missing_death": rows[0].events.remove_at(1)
			"dead_before": rows[0].actors_before.sherri_boss_a.dead = true
			"hp_after": rows[0].actors_after.sherri_boss_a.hp = 1.0
			"nonordinary": rows[0].actors_before.sherri_boss_a.ordinary_reward = false
			"missing_toast": rows[0].events.remove_at(2)
			"missing_feed": rows[0].events.remove_at(3)
			"unbacked_switch": rows[1].before_weapon = "brick"; rows[1].events[-1].payload.used_weapon = "brick"
			"early_shoe": rows[0] = _attack_row("fists","shoe","sherri_boss_a",true,false,1000.0)
			"wrong_kill": rows[0] = _attack_row("fists","brick","sherri_boss_a",true,false,1000.0)
			"missing_victory": rows[1].victory_after = false
			"cooldown": rows[1].after_cd = 1.0
			"premature_quest": rows[1].quest_before = true
			"nan_health": rows[0].actors_after.sherri_boss_a.hp = NAN
			"nan_cooldown": rows[0].before_cd = NAN
			"feed_order": rows[0].events.insert(0,rows[0].events.pop_at(3))
			"reward_order": rows[0].events.insert(0,rows[0].events.pop_at(2))
		_check(not Probe.weapon_chain(rows).ok,"source reward chain rejects "+change)
	rows = _earned_rows(); rows.insert(1,_attack_row("pipe","pipe","skid_sherri",true,false,1300.0)); rows[2].active_ms = 1600.0
	_check(not Probe.weapon_chain(rows).ok,"previous pipe cooldown320ms cannot be replaced by fists280ms")
	report = _valid(); report.contract_mode = "source_earned"; report.attack_receipts = _earned_rows(); report.initial.weapon = "pipe"
	_check(not Probe.assess(report).is_empty(),"source-earned contract still forbids starting-pipe fixture")
	report = _valid(); report.contract_mode = "source_earned"
	_check(not Probe.assess(report).is_empty(),"source-earned mode cannot pass without actual attack receipts")
func _run() -> void:
	_weapon_checks()
	# Exercise the actual circular deadzone, not a mirrored hand-written decoder.
	var actions: Array[StringName] = [&"boss_qa_left",&"boss_qa_right",&"boss_qa_forward",&"boss_qa_back"]
	for action: StringName in actions: InputMap.add_action(action,0.5)
	for angle: float in [0.0,0.003,0.1,0.5,PI*0.25,PI*0.49,PI*0.5,PI*0.75,PI,PI*1.3,PI*1.75]:
		for strength: float in [0.0,0.005,0.1,0.4,1.0,2.0]:
			for action: StringName in actions: Input.action_release(action)
			var desired := Vector2(cos(angle),sin(angle))*strength
			var raw: Vector2 = Probe.encode_motion(desired)
			if absf(raw.x) > 0.000001: Input.action_press(actions[1] if raw.x > 0 else actions[0],absf(raw.x))
			if absf(raw.y) > 0.000001: Input.action_press(actions[3] if raw.y > 0 else actions[2],absf(raw.y))
			var observed: Vector2 = Input.get_vector(actions[0],actions[1],actions[2],actions[3])
			_check(observed.distance_to(desired.limit_length(1.0)) < 0.00001,"actual radial input preserves direction and speed %s/%s" % [angle,strength])
	for action: StringName in actions: Input.action_release(action); InputMap.erase_action(action)
	_check(Probe.interaction_matches({"kind":"vendor","id":"tony"},"tony"),"actual intended vendor receipt ends approach")
	_check(Probe.interaction_matches({"kind":"smoke","id":"block"},"smoke:block"),"actual intended Block receipt ends approach")
	for action: Dictionary in [{},{"kind":"resident","id":"tony"},{"kind":"vendor","id":"pete"},{"kind":"cash","id":"block"},{"kind":"smoke","id":"market"}]:
		_check(not Probe.interaction_matches(action,"tony") and not Probe.interaction_matches(action,"smoke:block"),"unrelated nearby interaction cannot satisfy destination")
	_check(Probe.assess(_valid()).is_empty(),"all declared receipts can satisfy acceptance schema")
	for key: String in ["started","won","tony_dead","globals_clear","quest_done","shoe_reward","fists_only","cooldowns_valid"]:
		var row: Dictionary = _valid(); row.fight[key] = false
		_check(not Probe.assess(row).is_empty(),"missing actual fight receipt refuses "+key)
	for key: String in ["wall_ms","active_ms"]:
		for value: float in [0.0,-1.0,90000.0,90000.01,INF,NAN]:
			var row: Dictionary = _valid(); row.fight[key] = value
			_check(not Probe.assess(row).is_empty(),"strict finite below90s boundary "+key+" "+str(value))
	for key: String in ["damage","high_hits","accepted_attacks"]:
		var row: Dictionary = _valid(); row.fight[key] = 199 if key == "damage" else 0
		_check(not Probe.assess(row).is_empty(),"injected or unobserved damage cannot pass "+key)
	for key: String in ["phases","adds"]:
		var row: Dictionary = _valid(); row.fight[key] = [1,3] if key == "phases" else ["one_add"]
		_check(not Probe.assess(row).is_empty(),"omitted source encounter behavior refuses "+key)
	for ids: Array in [["sherri_boss_a","sherri_boss_a"],["sherri_boss_a","unknown_add"]]:
		var row: Dictionary = _valid(); row.fight.adds = ids
		_check(not Probe.assess(row).is_empty(),"duplicate or substituted add cannot pass")
	for key: String in ["purchased","spent","ending_seen","continued"]:
		var row: Dictionary = _valid(); row.loop[key] = false
		_check(not Probe.assess(row).is_empty(),"missing actual loop/ending receipt refuses "+key)
	for key: String in ["smokes","initial_high","high_ms","crash_ms"]:
		var row: Dictionary = _valid(); row.loop[key] = 2 if key == "smokes" else 6000.0
		_check(not Probe.assess(row).is_empty(),"alternate/refilled/incomplete loop refuses "+key)
	for key: String in ["high_ms","crash_ms"]:
		for value: float in [INF,NAN]:
			var row: Dictionary = _valid(); row.loop[key] = value
			_check(not Probe.assess(row).is_empty(),"non-finite loop cannot pass "+key)
	for key: String in ["cash","hp","max_hp","weapon","rocks","cred","brain","offenses","rocks_smoked","speed","cart_mounted"]:
		var row: Dictionary = _valid()
		row.initial[key] = "shoe" if key == "weapon" else (true if key == "cart_mounted" else 999)
		_check(not Probe.assess(row).is_empty(),"honest fixture label cannot hide changed actual start "+key)
	for slot: String in ["coat","hat","shoes","tool"]:
		var row: Dictionary = _valid(); row.initial.equip[slot] = "prearmed_bonus"
		_check(not Probe.assess(row).is_empty(),"unearned equipment refuses "+slot)
	for key: String in ["deaths","arrests","epoch_replacements"]:
		var row: Dictionary = _valid(); row[key] = 1
		_check(not Probe.assess(row).is_empty(),"failure lifecycle cannot be hidden "+key)
	for key: String in ["motion_frames","mouse_motion","keys","clicks","capture_clicks"]:
		var row: Dictionary = _valid(); row.inputs[key] = 0
		_check(not Probe.assess(row).is_empty(),"direct-call substitute lacks controller evidence "+key)
	var row: Dictionary = _valid(); row.costs = [0,5,5,5]
	_check(not Probe.assess(row).is_empty(),"free pre-fight rock cannot pass")
	row = _valid(); row.fixture.hp = 999
	_check(not Probe.assess(row).is_empty(),"boosted HP fixture cannot pass")
	row = _valid(); row.fixture.weapon = "shoe"
	_check(not Probe.assess(row).is_empty(),"post-victory weapon cannot pre-arm fixture")
	row = _valid(); row.dependencies = ["tony_add_placement"]
	_check(not Probe.assess(row).is_empty(),"missing physical adds cannot pass")
	row = _valid(); row.canonical_roster_retained = false
	_check(not Probe.assess(row).is_empty(),"filtered source roster cannot pass")
	row = _valid(); row.initial.inventory = [{"id":"extra_resource"}]
	_check(not Probe.assess(row).is_empty(),"unearned starting inventory cannot pass")
	if failures.is_empty(): print("3D BOSS ACCEPTANCE CONTRACT: PASS (%d counterexample checks; no simulated fight claim)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D BOSS ACCEPTANCE CONTRACT: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
