extends "res://tests/vendor_receipt_probe.gd"
const Probe = preload("res://tests/vendor_receipt_probe.gd")
var contract_checks := 0
var contract_failures: Array[String] = []
var groups := 0
var driver_mode := false
var clock_ms := 1000
var step_frames := 0
var route_calls := 0
var segment_calls := 0
var motion_calls := 0
var release_calls := 0
var recover := false
class StateStub:
	extends RefCounted
	var s := {"mode":"playing"}

func _check(ok: bool,label: String) -> bool:
	if driver_mode:
		if not ok: failures.append(label)
		return ok
	contract_checks += 1
	if not ok: contract_failures.append(label)
	return ok
func _process(_delta: float) -> bool: return false
func _alive() -> bool: return step_frames < 50 if driver_mode else true
func _walk_clock() -> int: return clock_ms
func _walk_frame() -> void:
	clock_ms += 1000; step_frames += 1
	await process_frame
func _reach_service(_id: String) -> bool: return false
func _resident_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	route_calls += 1
	return PackedVector3Array([from,to]) if recover and route_calls >= 3 else PackedVector3Array()
func _combat_segment(_from: Vector3,_to: Vector3) -> Dictionary:
	segment_calls += 1; return {"ok":true}
func _walking_step(_point: Vector3) -> Dictionary: return {"ok":true}
func _aim(_target: Vector3,_dt_value: float) -> float: return 1.0
func _dt() -> float: return 0.016
func _motion(vector: Vector2) -> void:
	motion_calls += 1
	if not vector.is_zero_approx(): game.player.position = Vector3(2,0,0)
func _release() -> void: release_calls += 1

func good_commit() -> Dictionary:
	return {"before":{"cash":10,"rocks":0,"bought":0,"street":0,"first_rock":false},"after":{"cash":0,"rocks":1,"bought":1,"street":1,"first_rock":true},"resolved":{"kind":"vendor","id":"tony"},"distance":59.99,"reachable":true,"events":[{"payload":{"ok":true,"vendor":"tony","action":"buy_rock"},"hand_after":{"action":"receipt","phase":0.0,"age":0.0}}]}
func good_frames() -> Array:
	var rows: Array = []
	for index: int in range(4):
		rows.append({"label":Probe.LABELS[index],"png_sha256":"a".repeat(64),"png_bytes":100,"framebuffer":[1280,720],"action":"receipt" if index == 2 else "","phase":0.5 if index == 2 else 0.0,"paper_visible":index == 2,"paper_projected":true,"mode":"playing","modal":false})
	return rows
func _commits() -> void:
	_check(Probe.commit_errors(good_commit()).is_empty(),"exact valid paid owner receipt")
	for field: String in ["cash","rocks","bought","street","first_rock"]:
		var row := good_commit(); row.after[field] = 99
		_check(not Probe.commit_errors(row).is_empty(),"reject wrong committed "+field)
	for distance: float in [60.0,60.001,INF,NAN,-1.0]:
		var row := good_commit(); row.distance = distance
		_check(not Probe.commit_errors(row).is_empty(),"strict60 source boundary")
	for action: String in ["leave","negotiate","challenge","short","swap_tools"]:
		var row := good_commit(); row.events[0].payload.action = action
		_check(not Probe.commit_errors(row).is_empty(),"not the tested committed purchase: "+action)
	for field: String in ["ok","vendor"]:
		var row := good_commit(); row.events[0].payload[field] = false
		_check(not Probe.commit_errors(row).is_empty(),"invalid emitted "+field)
	var duplicate := good_commit(); duplicate.events.append(duplicate.events[0].duplicate(true))
	_check(not Probe.commit_errors(duplicate).is_empty(),"reject duplicate receipt event")
	var missing := good_commit(); missing.events.clear()
	_check(not Probe.commit_errors(missing).is_empty(),"reject missing event even matching resources")
	var injected := good_commit(); injected.events[0].hand_after.phase = 0.5
	_check(not Probe.commit_errors(injected).is_empty(),"cannot fake initial mid-phase action")
	# Actual v1 runtime errors must become ordinary refusals, never coercions.
	for container: String in ["before","after","resolved"]:
		for malformed: Variant in [null,false,1,"{}",[]]:
			var row := good_commit(); row[container] = malformed
			_check(not Probe.commit_errors(row).is_empty(),"typed dictionary refusal "+container)
	for side: String in ["before","after"]:
		for field: String in ["cash","rocks","bought","street"]:
			for malformed: Variant in [null,true,"1",NAN,INF,[],{}]:
				var row := good_commit(); row[side][field] = malformed
				_check(not Probe.commit_errors(row).is_empty(),"finite numeric refusal "+side+"/"+field)
		for malformed: Variant in [null,0,1,"true",[],{}]:
			var row := good_commit(); row[side].first_rock = malformed
			_check(not Probe.commit_errors(row).is_empty(),"strict boolean quest "+side)
	for malformed: Variant in [null,true,"59.99",[],{}]:
		var row := good_commit(); row.distance = malformed
		_check(not Probe.commit_errors(row).is_empty(),"distance cannot coerce")
	for malformed: Variant in [null,1,"true",[],{}]:
		var row := good_commit(); row.reachable = malformed
		_check(not Probe.commit_errors(row).is_empty(),"reach cannot coerce")
	for field: String in ["kind","id"]:
		var row := good_commit(); row.resolved[field] = true
		_check(not Probe.commit_errors(row).is_empty(),"resolver string refusal "+field)
	for malformed: Variant in [null,false,1,"[]",{}]:
		var row := good_commit(); row.events = malformed
		_check(not Probe.commit_errors(row).is_empty(),"event array refusal")
	for malformed: Variant in [null,false,1,"{}",[]]:
		var row := good_commit(); row.events[0] = malformed
		_check(not Probe.commit_errors(row).is_empty(),"event dictionary refusal")
	for container: String in ["payload","hand_after"]:
		for malformed: Variant in [null,false,1,"{}",[]]:
			var row := good_commit(); row.events[0][container] = malformed
			_check(not Probe.commit_errors(row).is_empty(),"event child dictionary "+container)
	for field: String in ["ok","vendor","action"]:
		for malformed: Variant in [null,1,[],{}]:
			var row := good_commit(); row.events[0].payload[field] = malformed
			_check(not Probe.commit_errors(row).is_empty(),"payload typed refusal "+field)
	var coerced := good_commit(); coerced.events[0].payload.ok = "true"
	_check(not Probe.commit_errors(coerced).is_empty(),"truthy text not successful boolean")
	for field: String in ["action","phase","age"]:
		for malformed: Variant in [null,true,[],{}]:
			var row := good_commit(); row.events[0].hand_after[field] = malformed
			_check(not Probe.commit_errors(row).is_empty(),"typed hand refusal "+field)
	for field: String in ["phase","age"]:
		var row := good_commit(); row.events[0].hand_after[field] = "0"
		_check(not Probe.commit_errors(row).is_empty(),"zero text not hand numeric")
	var floats := good_commit()
	for side: String in ["before","after"]:
		for field: String in ["cash","rocks","bought","street"]: floats[side][field] = float(floats[side][field])
	_check(Probe.commit_errors(floats).is_empty(),"legitimate numeric resource representation retained")
	groups += 1
func _frames() -> void:
	for resolution: Array in [[1280,720],[960,540]]:
		var rows := good_frames()
		for row: Dictionary in rows: row.framebuffer = resolution.duplicate()
		_check(Probe.frame_errors(rows).is_empty(),"same original frame contract both resolutions")
	for field: String in ["paper_visible","paper_projected"]:
		var rows := good_frames(); rows[2][field] = false
		_check(not Probe.frame_errors(rows).is_empty(),"cannot accept invisible/offscreen paper")
	for phase: float in [0.0,0.299,0.801,1.0,NAN]:
		var rows := good_frames(); rows[2].phase = phase
		_check(not Probe.frame_errors(rows).is_empty(),"actual bounded middle phase")
	var rows := good_frames(); rows[3].action = "receipt"
	_check(not Probe.frame_errors(rows).is_empty(),"normal recovery required")
	rows = good_frames(); rows[3].modal = true
	_check(not Probe.frame_errors(rows).is_empty(),"cannot hide recovery behind menu")
	rows = good_frames(); rows.remove_at(1)
	_check(not Probe.frame_errors(rows).is_empty(),"partial scenario cannot pass")
	groups += 1
func _empty_route() -> void:
	game = Base.ObservedScene.new(); game.runtime = StateStub.new(); game.player = Node3D.new(); game.add_child(game.player)
	game.camera = Camera3D.new(); root.add_child(game.camera)
	driver_mode = true; recover = false
	var arrived: bool = await _walk_to(Vector3(2,0,0))
	driver_mode = false
	_check(not arrived and failures.size() == 1 and failures[0].begins_with("actual controller walking stalled"),"permanent empty route fails actual inherited20s watchdog")
	_check(route_calls == 21 and step_frames == 21 and segment_calls == 0 and motion_calls == 0,"empty routes never index[1]/query segment/move and retain cadence")
	_check(walking_context.no_progress_ms == 21000 and walking_context.replans == 20 and release_calls > 0,"unchanged finite counters and release")
	game.camera.free(); game.free(); failures.clear(); groups += 1
func _transient_route() -> void:
	game = Base.ObservedScene.new(); game.runtime = StateStub.new(); game.player = Node3D.new(); game.add_child(game.player)
	game.camera = Camera3D.new(); root.add_child(game.camera)
	clock_ms = 1000; step_frames = 0; route_calls = 0; segment_calls = 0; motion_calls = 0; release_calls = 0
	driver_mode = true; recover = true
	var arrived: bool = await _walk_to(Vector3(2,0,0))
	driver_mode = false
	_check(arrived and failures.is_empty(),"two empty false-defense plans recover without restart")
	_check(route_calls == 3 and walking_context.replans == 2 and motion_calls == 1 and segment_calls == 1,"fresh nonempty route receives proof before one input")
	_check(clock_ms == 4000 and step_frames == 3,"cumulative clock retained across retries")
	game.camera.free(); game.free(); groups += 1
func _run() -> void:
	_commits(); _frames(); await _empty_route(); await _transient_route()
	_check(groups == 4,"all four groups completed without runtime abort")
	print("VENDOR RECEIPT VISUAL CONTRACT: ","PASS" if contract_failures.is_empty() else "FAIL"," (",contract_checks," checks; ",groups,"/4 groups)")
	for error: String in contract_failures: push_error(error)
	quit(0 if contract_failures.is_empty() else 1)
