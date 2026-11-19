extends SceneTree
## Pure report counterexamples; this never produces or accepts rendered evidence.
const Probe = preload("dave_walkthrough_probe.gd")
var checks := 0
var failures: Array[String] = []
var completed_groups := 0

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _good() -> Dictionary:
	var before := {"player":{"cash":0,"hp":100.0,"brain":70.0,"weapon":"fists","inventory":[]},
		"actor":{"id":"dave","x":900.0,"y":1480.0,"hp":40,"asleep":true,"hostile":false},"rng":12345}
	var after: Dictionary = before.duplicate(true); after.actor.asleep = false
	var frames: Array = []
	for index: int in range(3):
		frames.append({"label":["01_sleeping_dave","02_awake_dave","03_pigeon_dialogue"][index],
			"framebuffer":[1280,720],"png_bytes":100,"png_sha256":"a".repeat(64),"root_up":0.09 if index == 0 else 1.0,
			"asleep":index == 0,"sleep_markers":2 if index == 0 else 0,"projected":true,"clear_ray":true,"reachable":true,
			"mode":"dialogue" if index == 2 else "playing","menu":{"labels":["dave is explaining a theory about pigeons.\nthe theory has 17 parts."] if index == 2 else [],"buttons":["listen for a while. (-5 brain)","leave."] if index == 2 else []}})
	return {"format":"rock-bottom-dave-walkthrough","fixture":"none","title_input":true,
		"initial":{"cash":0,"hp":100,"weapon":"fists","rocks":0,"cred":0,"cart_mounted":false,"source_position":[1050.0,840.0],"inventory":[],"equip":{"hat":null,"coat":null,"shoes":null,"tool":null}},
		"frames":frames,"wake":{"resolved":{"kind":"quest","id":"dave"},"pressed":true,"before":before,"after":after,"distance":40.0,"reachable":true},
		"idle":[{"root_up":1.0,"asleep":false,"sleep_markers":0},{"root_up":0.99,"asleep":false,"sleep_markers":0}],"idle_active_ms":4000.0,
		"movement":{"metres":0.15,"input_frames":3,"mode":"playing","modal":false},
		"events":[{"kind":"toast","payload":{"text":"dave wakes up. he is talking immediately."}}],"replacements":0,"overflow":false,
		"inputs":{"motion_frames":50,"mouse_motion":30,"keys":2,"clicks":3},"wall_ms":15000.0}

func _bad(path: Array,value: Variant,label: String) -> void:
	var row: Dictionary = _good(); var cursor: Variant = row
	for index: int in range(path.size()-1): cursor = cursor[path[index]]
	cursor[path[-1]] = value
	_check(not Probe.report_errors(row).is_empty(),label)

func _valid_checks() -> void:
	var row: Dictionary = _good(); var original: Dictionary = row.duplicate(true)
	_check(Probe.report_errors(row).is_empty(),"complete synthetic native report is structurally valid, not rendered acceptance")
	_check(row == original,"report assessment owns no input state")
	for frame: Dictionary in row.frames: frame.framebuffer = [960,540]
	_check(Probe.report_errors(row).is_empty(),"Web960 evidence uses the same source contract")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(row))
	_check(Probe.report_errors(decoded).is_empty(),"detached JSON report retains equivalent numeric framebuffer values")
	_check(not Probe.report_errors({}).is_empty(),"empty evidence cannot pass")
	for pair: Array in [["cash",5],["hp",99],["weapon","pipe"],["rocks",1],["cred",1],["cart_mounted",true],["source_position",[1051.0,840.0]],["inventory",["paper"]]]:
		_bad(["initial",pair[0]],pair[1],"canonical fresh field required: "+str(pair[0]))
	_bad(["initial","equip","tool"],"crowbar","no equipment fixture")
	_bad(["initial","equip"],{"hat":null,"coat":null,"shoes":null},"all four normalized equipment slots observed")
	_bad(["fixture"],"cash only","any fixture disqualifies this walk")
	_bad(["title_input"],false,"actual title input required")
	completed_groups += 1

func _wake_checks() -> void:
	var row: Dictionary = _good(); var before: Dictionary = row.wake.before; var after: Dictionary = row.wake.after
	var original: Dictionary = before.duplicate(true)
	_check(Probe.wake_unchanged(before,after) and before == original,"wake comparison accepts only the source asleep transition without mutation")
	_check(not Probe.wake_unchanged({},{}),"absent wake states cannot pass")
	_bad(["wake","before","actor","asleep"],false,"already-awake actor is not the wake transition")
	_bad(["wake","after","actor","asleep"],true,"sleep must end")
	for pair: Array in [["x",901.0],["hp",39],["hostile",true],["id","mom"]]:
		_bad(["wake","after","actor",pair[0]],pair[1],"wake cannot mutate actor "+str(pair[0]))
	for pair: Array in [["cash",8],["hp",99.0],["brain",65.0],["weapon","pipe"],["inventory",["paper"]]]:
		_bad(["wake","after","player",pair[0]],pair[1],"wake owns no player effect: "+str(pair[0]))
	_bad(["wake","after","rng"],12346,"wake consumes no RNG")
	_bad(["wake","resolved"],{"kind":"resident","id":"dave"},"source quest owner required")
	_bad(["wake","resolved","id"],"mom","Dave must be the actual E target")
	_bad(["wake","pressed"],false,"actual wake Control required")
	_bad(["wake","reachable"],false,"actual reach certificate required")
	for distance: float in [-0.001,60.0,NAN,INF]: _bad(["wake","distance"],distance,"strict finite60px source range: "+str(distance))
	var inside: Dictionary = _good(); inside.wake.distance = 59.999
	_check(Probe.report_errors(inside).is_empty(),"inside strict source range remains admissible")
	completed_groups += 1

func _frame_checks() -> void:
	_bad(["frames"],_good().frames.slice(0,2),"all three stages required")
	var extra: Array = _good().frames.duplicate(true); extra.append(extra[2].duplicate(true))
	_bad(["frames"],extra,"extra frame cannot evade bounded ordered captures")
	_bad(["frames",0,"label"],"02_awake_dave","capture order is exact")
	for index: int in range(3):
		for key: String in ["projected","clear_ray","reachable"]: _bad(["frames",index,key],false,"frame requires "+key)
		_bad(["frames",index,"root_up"],NAN,"every pose is finite")
		_bad(["frames",index,"asleep"],index != 0,"each source sleep flag matches stage")
		_bad(["frames",index,"mode"],"paused","paused image cannot substitute for active/dialogue stage")
	_bad(["frames",0,"root_up"],0.2,"horizontal sleep threshold stays strict")
	_bad(["frames",1,"root_up"],0.95,"upright threshold stays strict")
	_bad(["frames",0,"sleep_markers"],0,"source sleeping Z markers required")
	_bad(["frames",1,"sleep_markers"],2,"wake removes both Z markers")
	for pair: Array in [["png_bytes",0],["png_bytes",6291457],["png_sha256","short"],["framebuffer",[1280,540]]]:
		_bad(["frames",0,pair[0]],pair[1],"bounded original image evidence: "+str(pair[0]))
	_bad(["frames",2,"menu","labels"],["dave is asleep. his wallet is half out."],"exact awake pigeon dialogue required")
	_bad(["frames",2,"menu","buttons"],["wake him up.","leave."],"awake menu cannot still offer wake")
	for elapsed: float in [3999.0,NAN,INF]: _bad(["idle_active_ms"],elapsed,"finite complete4000ms active period: "+str(elapsed))
	_bad(["idle"],[],"idle cannot be inferred from one endpoint")
	_bad(["idle",1,"root_up"],0.09,"awake cannot return horizontal mid-cycle")
	_bad(["idle",1,"asleep"],true,"idle source flag stays awake")
	_bad(["idle",1,"sleep_markers"],1,"idle cannot reacquire sleep marker")
	completed_groups += 1

func _completion_checks() -> void:
	for metres: float in [0.149,NAN,INF]: _bad(["movement","metres"],metres,"finite actual post-menu movement: "+str(metres))
	for pair: Array in [["input_frames",0],["mode","dialogue"],["modal",true]]: _bad(["movement",pair[0]],pair[1],"Leave must release real movement: "+str(pair[0]))
	for kind: String in ["death","arrest","boss_started","dependency_missing","player_attack"]:
		var events: Array = _good().events.duplicate(true); events.append({"kind":kind,"payload":{}})
		_bad(["events"],events,"unexpected source event disqualifies: "+kind)
	_bad(["events"],[],"real wake toast required")
	var repeated: Array = _good().events.duplicate(true); repeated.append(repeated[0].duplicate(true))
	_bad(["events"],repeated,"duplicate wake toast cannot count as one action")
	_bad(["replacements"],1,"no epoch replacement after title")
	_bad(["overflow"],true,"truncated evidence cannot pass")
	for kind: String in ["motion_frames","mouse_motion","keys","clicks"]: _bad(["inputs",kind],0,"normal input ledger requires "+kind)
	for elapsed: float in [0.0,-1.0,120000.0,NAN,INF]: _bad(["wall_ms"],elapsed,"finite strict whole-attempt deadline: "+str(elapsed))
	completed_groups += 1

class ResumeCertificates:
	extends RefCounted
	var accepted_call: int = 0
	var points: Array[Vector3] = []
	func certify(from: Vector3,to: Vector3) -> Dictionary:
		points.append(to)
		return {"ok":accepted_call > 0 and points.size() == accepted_call,"from":from,"to":to,"reason":"fixture certificate"}

func _resume_checks() -> void:
	var witness := ResumeCertificates.new()
	var from := Vector3(2,0.06,3)
	var preferred := from+Vector3(0,0,-25)
	witness.accepted_call = 2
	var alternate: Dictionary = Probe.resume_choice(from,preferred,witness.certify)
	_check(alternate.ok and alternate.attempts == 2 and witness.points.size() == 2,"blocked return heading chooses actual certified alternate, without requiring a distant route")
	_check(alternate.point == witness.points[1] and alternate.point != witness.points[0],"chosen point is the accepted alternate only")
	_check(alternate.certificate.to == alternate.point,"choice retains the actual matching certificate")
	witness.points.clear(); witness.accepted_call = 0
	var blocked: Dictionary = Probe.resume_choice(from,preferred,witness.certify)
	_check(not blocked.ok and blocked.attempts == 8 and witness.points.size() == 8,"all eight blocked directions refuse without blind movement")
	for point: Vector3 in witness.points:
		_check(point.is_finite() and point.y == from.y and absf(point.distance_to(from)-0.35) < 0.000001,"every finite local heading keeps the bounded horizontal radius")
	_check(witness.points[0].distance_to(from+Vector3(0,0,-0.35)) < 0.000001,"preferred original-spawn heading stays first")
	var first_order: Array[Vector3] = witness.points.duplicate()
	witness.points.clear(); Probe.resume_choice(from,preferred,witness.certify)
	_check(witness.points == first_order,"same inputs retain exact finite choice order without RNG")
	witness.points.clear(); witness.accepted_call = 1
	var forward: Dictionary = Probe.resume_choice(from,preferred,witness.certify)
	_check(forward.ok and forward.attempts == 1 and witness.points.size() == 1,"first clear direction needs no unnecessary alternatives")
	witness.points.clear(); witness.accepted_call = 0
	_check(not Probe.resume_choice(from,preferred,witness.certify).ok,"fresh blocked certificates cannot reuse a previous successful selection")
	witness.points.clear()
	_check(not Probe.resume_choice(Vector3.INF,preferred,witness.certify).ok and witness.points.is_empty(),"invalid origin makes no certificate query")
	_check(not Probe.resume_choice(from,from,witness.certify).ok and witness.points.is_empty(),"degenerate desired heading makes no blind motion")
	completed_groups += 1

func _run() -> void:
	_valid_checks(); _wake_checks(); _frame_checks(); _completion_checks(); _resume_checks()
	_check(completed_groups == 5,"all five contract groups reached their actual tails")
	for failure: String in failures: push_error(failure)
	print("DAVE WALKTHROUGH CONTRACT: ","PASS" if failures.is_empty() else "FAIL"," (",checks," checks; ",completed_groups,"/5 groups; no rendered acceptance)")
	quit(0 if failures.is_empty() else 1)
