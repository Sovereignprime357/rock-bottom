extends SceneTree
## Synthetic assessor counterexamples only. Never claims a rendered song.
const State = preload("res://scripts/game_state.gd")
const Probe = preload("res://tests/karaoke_acceptance_probe.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _valid() -> Dictionary:
	var state := State.new()
	var before := {"player":state.p.duplicate(true),"state":state.s.duplicate(true),"rng":12345}
	var after: Dictionary = before.duplicate(true); after.player.cash = 5
	var result := {"fixture_before":before,"fixture_after":after,
		"entry":{"resolved":{"kind":"street","id":"karaoke"},"distance":42.0,"reachable":true,"alive":true,"before":{"cash":5},"after":{"cash":0},"rng_before":12345,"rng_after":12345},
		"notes":[],"events":[],"dwell":{"before":{"page":1,"cash":0},"after":{"page":1,"cash":0},"active_before":7000.0,"active_after":7000.0,"wall_ms":550.0},
		"final":{"cash":24,"cred":5,"achievement":true,"intro_remember":true,"intro_tony":true,"mode":"playing","modal":false,"activity":false},
		"durable":{"schema":2,"cash":24,"cred":5,"achievement":true,"intro_remember":true},
		"movement":{"metres":0.2,"inputs":6,"cash":24,"cred":5},"inputs":{"motion_frames":70,"mouse_motion":60,"keys":10,"capture_clicks":2},"replacements":0,"overflow":false,"wall_ms":15000.0,"captures":[]}
	var history: Array[String] = []
	for index: int in range(8):
		result.entry.rng_after = (int(result.entry.rng_after)*1664525+1013904223)&0xffffffff
		var chosen: int = index%4; var choices: Array = []
		for option: int in range(4): choices.append({"label":Probe.ARROWS[option]+(" (now!)" if option == chosen else " "),"enabled":true})
		choices.append({"label":"forfeit. (you sound tired)","enabled":true})
		result.notes.append({"menu":{"title":"· %d / 8 ·" % (index+1),"body":"next: "+Probe.ARROWS[chosen]+"\n\nyour line:\n"+" ".join(history),"choices":choices},"index":chosen,"key":KEY_1+chosen,"rendered":true,"released":true,"before":{"cash":0,"cred":0},"after":{"cash":0 if index < 7 else 24,"cred":0 if index < 7 else 5}})
		history.append(Probe.ARROWS[chosen])
	result.events = [{"kind":"activity_started","payload":{"id":"karaoke"}},{"kind":"toast","payload":{"text":Probe.RESULT}},{"kind":"achievement","payload":{"id":"not_a_phase"}},{"kind":"news","payload":{"text":Probe.NEWS}},{"kind":"activity_completed","payload":{"id":"karaoke","hits":8}},{"kind":"quest_completed","payload":{"id":"intro_remember"}}]
	for index: int in range(11): result.captures.append("synthetic_%02d" % index)
	return result
func _bad(base: Dictionary,path: Array,value: Variant,label: String) -> void:
	var edited: Dictionary = base.duplicate(true); var cursor: Variant = edited
	for index: int in range(path.size()-1): cursor = cursor[path[index]]
	cursor[path[-1]] = value
	_check(not Probe.karaoke_errors(edited).is_empty(),label)
func _run() -> void:
	var good: Dictionary = _valid()
	_check(Probe.karaoke_errors(good).is_empty(),"complete synthetic receipt passes only its assessor")
	for path: Array in [["fixture_after","player","hp"],["fixture_after","player","speed"],["fixture_after","rng"]]: _bad(good,path,999,"sole fixture forbids stat/time/RNG grants")
	_bad(good,["fixture_before","player","hp"],200,"starting HP grant cannot hide before fixture")
	_bad(good,["entry","resolved","id"],"tony","actual resolver cannot substitute actor")
	for distance: float in [60.0,-1.0,NAN,INF]: _bad(good,["entry","distance"],distance,"strict finite physical range")
	for key: String in ["alive","reachable"]: _bad(good,["entry",key],false,"actual living LOS entry")
	_bad(good,["entry","after","cash"],5,"payment required")
	_bad(good,["entry","rng_after"],1,"exact eight source draws")
	_bad(good,["notes"],good.notes.slice(0,7),"eight real pages required")
	for key: String in ["rendered","released"]: _bad(good,["notes",2,key],false,"real rendered press/release required")
	_bad(good,["notes",2,"key"],KEY_W,"unused WASD keyMap cannot stand in for dialogue input")
	_bad(good,["notes",3,"menu","body"],"next: fake","visible history cannot be invented")
	_bad(good,["notes",3,"menu","choices",2,"enabled"],false,"disabled choice not accepted")
	_bad(good,["notes",3,"after","cash"],24,"no early reward")
	_bad(good,["dwell","wall_ms"],499,"meaningful visible dialogue dwell")
	_bad(good,["dwell","active_after"],7001.0,"world clock cannot run during note menu")
	_bad(good,["dwell","after","page"],2,"no automatic beat/index advancement")
	for key: String in ["cash","cred"]: _bad(good,["final",key],0,"exact source plus intro reward")
	for key: String in ["achievement","intro_remember","intro_tony"]: _bad(good,["final",key],false,"completion progression required")
	_bad(good,["final","modal"],true,"song must release menu")
	_bad(good,["final","activity"],true,"song capability revoked")
	_bad(good,["events"],good.events.slice(1),"start receipt required")
	var repeated: Array = good.events.duplicate(true); repeated.append(good.events[4]); _bad(good,["events"],repeated,"duplicate completion rejected")
	var missing_achievement: Array = good.events.duplicate(true); missing_achievement.remove_at(2); _bad(good,["events"],missing_achievement,"new achievement event cannot be replaced by final state")
	var repeated_achievement: Array = good.events.duplicate(true); repeated_achievement.append(good.events[2]); _bad(good,["events"],repeated_achievement,"achievement unlock occurs once")
	for pair: Array in [[1,2],[2,3],[3,4],[4,5]]:
		var reordered: Array = good.events.duplicate(true); var item: Variant = reordered[pair[0]]; reordered[pair[0]] = reordered[pair[1]]; reordered[pair[1]] = item
		_bad(good,["events"],reordered,"source completion event order retained")
	for kind: String in ["death","arrest","boss_started","dependency_missing","player_attack"]:
		var events: Array = good.events.duplicate(true); events.append({"kind":kind,"payload":{}}); _bad(good,["events"],events,"unexpected source lifecycle/combat invalidates run")
	_bad(good,["events",4,"payload","hits"],7,"perfect source outcome required")
	_bad(good,["durable","cash"],0,"durable payout required")
	_bad(good,["durable","achievement"],false,"durable achievement required")
	for value: float in [0.0,0.10,NAN,INF]: _bad(good,["movement","metres"],value,"actual finite movement required")
	_bad(good,["movement","cash"],48,"resumed frames cannot pay twice")
	_bad(good,["inputs","keys"],0,"actual input evidence required")
	_bad(good,["replacements"],1,"no reset/load epoch escape")
	_bad(good,["overflow"],true,"bounded evidence cannot truncate silently")
	for value: float in [120000.0,NAN,INF]: _bad(good,["wall_ms"],value,"strict finite whole-run watchdog")
	_bad(good,["captures"],[],"rendered pages/receipt/movement evidence required")
	if failures.is_empty(): print("3D KARAOKE ACCEPTANCE CONTRACT: PASS (%d synthetic checks; not native evidence)" % checks)
	else:
		for failure: String in failures: push_error(failure)
		print("3D KARAOKE ACCEPTANCE CONTRACT: FAIL (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)
