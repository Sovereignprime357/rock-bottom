extends "res://tests/office_acceptance_probe.gd"
## Actual input-only purchase. Never invokes the inherited Office scenario.
const Base = preload("res://tests/office_acceptance_probe.gd")
const WHOLE_MS := 300000
const RUN_MS := 120000
const PHASE_MS := {"cash":40000,"tony":60000,"menu":10000,"gesture":5000}
const CASH_ID := "cp_intro_remember"
const LABELS := ["01_intro_cash","02_tony_menu","03_receipt_mid","04_recovered_hands"]

class ReceiptScene:
	extends Base.ObservedScene
	var evidence_events: Array[Dictionary] = []
	var purchases: Array[Dictionary] = []
	var collections: Array[Dictionary] = []
	var hand_frames: Array[Dictionary] = []
	var evidence_overflow := false
	func _consume_events() -> void:
		var commits: Array[Dictionary] = []
		if audit_enabled and runtime != null:
			var pending: Array = runtime._outbox.duplicate(); pending.append_array(runtime.state.events)
			for event: Dictionary in pending:
				if event.kind not in ["vendor_action","gesture","quest_completed","toast","save_requested","death","arrest","boss_started","player_attack","dependency_missing"]: continue
				if evidence_events.size() >= 512: evidence_overflow = true; break
				var row := {"kind":event.kind,"payload":event.get("payload",{}).duplicate(true),"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms,"process_frame":Engine.get_process_frames()}
				evidence_events.append(row)
				if event.kind == "vendor_action": commits.append(row.duplicate(true))
		super._consume_events()
		for row: Dictionary in commits:
			row.hand_after = {"action":str(hands.action),"phase":hands.action_phase,"age":hands._action_age}
			if purchases.size() >= 8: evidence_overflow = true
			else: purchases.append(row)
	func _process(delta: float) -> void:
		var previous: Dictionary = {}
		var previous_cash := 0
		if audit_enabled and runtime != null:
			previous_cash = int(runtime.p.cash)
			for pile: Dictionary in runtime.state.cash_piles:
				if pile.id == CASH_ID and not pile.get("collected",false): previous = pile.duplicate(true)
		super._process(delta)
		if not audit_enabled: return
		if not previous.is_empty():
			for pile: Dictionary in runtime.state.cash_piles:
				if pile.id == CASH_ID and pile.get("collected",false):
					collections.append({"id":pile.id,"record":previous,"cash_before":previous_cash,"cash_after":runtime.p.cash,"player_center":runtime.state.player_center(),"process_frame":Engine.get_process_frames(),"active_ms":admitted_ms})
		if not purchases.is_empty():
			if hand_frames.size() >= 360: evidence_overflow = true
			else: hand_frames.append({"frame":Engine.get_process_frames(),"active_ms":admitted_ms,"admitted_ms":runtime.last_advanced_ms,"action":str(hands.action),"age":hands._action_age,"phase":hands.action_phase,"paper_visible":hands._props[&"receipt"].is_visible_in_tree(),"mode":runtime.s.mode})

var proof := {"schema":1,"format":"rock-bottom-vendor-receipt-visual","fixture":"none","frames":[],"initial":{},"transaction":{},"acceptance":false,"visual_acceptance":false,"performance_acceptance":false,"shutdown_acceptance":false}
var boot_ms := 0
var start_ms := 0
var started := false
var finishing := false
var finished := false
var ready := false
var run_id := ""
var size := Vector2i(1280,720)
var callback: JavaScriptObject
var output_owned := false
var fresh_namespace := false
var store_bound := false
var checks := 0
var safety_cursor := 0

static func _finite_receipt_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func commit_errors(row: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not row.get("before") is Dictionary or not row.get("after") is Dictionary: return ["resource receipt dictionaries"]
	var before: Dictionary = row.before; var after: Dictionary = row.after
	for key: String in ["cash","rocks","bought","street"]:
		if not _finite_receipt_number(before.get(key)): errors.append("invalid before "+key)
		if not _finite_receipt_number(after.get(key)): errors.append("invalid after "+key)
	if not before.get("first_rock") is bool or not after.get("first_rock") is bool: errors.append("boolean quest receipt")
	if not errors.is_empty(): return errors
	if before.cash != 10 or after.cash != 0 or before.rocks != 0 or after.rocks != 1 or before.bought != 0 or after.bought != 1: errors.append("exact10 dollar/one rock purchase")
	if after.street != before.street+1 or before.first_rock != false or after.first_rock != true: errors.append("source reputation/quest receipt")
	if not _finite_receipt_number(row.get("distance")) or not row.get("reachable") is bool or not row.get("resolved") is Dictionary: errors.append("typed live resolver receipt"); return errors
	var resolved: Dictionary = row.resolved
	if not resolved.get("kind") is String or not resolved.get("id") is String: errors.append("string live resolver identity"); return errors
	var distance: float = float(row.distance)
	if resolved != {"kind":"vendor","id":"tony"} or distance < 0.0 or distance >= 60 or row.reachable != true: errors.append("live resolver strict range/LOS")
	if not row.get("events") is Array: errors.append("vendor event array"); return errors
	var events: Array = row.events
	if events.size() != 1: errors.append("exactly one vendor action"); return errors
	if not events[0] is Dictionary: errors.append("vendor event dictionary"); return errors
	var event: Dictionary = events[0]
	if not event.get("payload") is Dictionary or not event.get("hand_after") is Dictionary: errors.append("vendor payload/hand dictionaries"); return errors
	var payload: Dictionary = event.payload; var hand: Dictionary = event.hand_after
	if not payload.get("ok") is bool or not payload.get("vendor") is String or not payload.get("action") is String: errors.append("typed successful Tony receipt"); return errors
	if payload.ok != true or payload.vendor != "tony" or payload.action != "buy_rock": errors.append("real successful Tony receipt")
	if not hand.get("action") is String or not _finite_receipt_number(hand.get("phase")) or not _finite_receipt_number(hand.get("age")): errors.append("typed hand-start receipt"); return errors
	if hand != {"action":"receipt","phase":0.0,"age":0.0}: errors.append("existing receipt begins at actual event")
	return errors

static func frame_errors(rows: Array) -> Array[String]:
	var errors: Array[String] = []
	if rows.size() != 4: return ["four completed original frames"]
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		if row.get("label") != LABELS[index] or str(row.get("png_sha256","")).length() != 64 or row.get("png_bytes",0) <= 0 or row.get("png_bytes",6291457) > 6291456: errors.append("ordered original PNG receipt")
		var framebuffer: Variant = row.get("framebuffer")
		if not framebuffer is Array or framebuffer not in [[1280,720],[960,540]]: errors.append("actual framebuffer dimensions")
		var phase: float = float(row.get("phase",NAN))
		if index == 2 and (row.get("action") != "receipt" or not is_finite(phase) or phase < 0.30 or phase > 0.80 or row.get("paper_visible") != true or row.get("paper_projected") != true): errors.append("visible natural mid gesture")
		if index == 3 and (row.get("action") != "" or row.get("paper_visible") != false or row.get("mode") != "playing" or row.get("modal") != false): errors.append("ordinary hand recovery")
	return errors

func _check(ok: bool,label: String) -> bool:
	checks += 1
	if not ok and label not in failures: failures.append(label); push_error(label)
	return ok
func _process(_delta: float) -> bool:
	if not finishing and not finished and boot_ms > 0 and Time.get_ticks_msec()-boot_ms >= WHOLE_MS:
		_check(false,"independent300s whole attempt watchdog"); _queue_finish()
	return false
func _alive() -> bool:
	if finished or finishing or not failures.is_empty(): return false
	if boot_ms > 0 and not _check(Time.get_ticks_msec()-boot_ms < WHOLE_MS,"300s whole deadline"): return false
	if started and not _check(Time.get_ticks_msec()-start_ms < RUN_MS,"120s actual input attempt"): return false
	if not phase_name.is_empty() and not _check(Time.get_ticks_msec()-phase_wall < int(PHASE_MS[phase_name]),"phase deadline "+phase_name): return false
	if is_instance_valid(game) and game.audit_enabled:
		if not _check(game.replacements.is_empty() and not game.overflow and not (game as ReceiptScene).evidence_overflow and game.runtime.p.hp > 0,"same live bounded source epoch"): return false
		var events: Array = (game as ReceiptScene).evidence_events
		while safety_cursor < events.size():
			var event: Dictionary = events[safety_cursor]; safety_cursor += 1
			if event.kind in ["death","arrest","boss_started","player_attack","dependency_missing"]: return _check(false,"unexpected source event "+str(event.kind))
	return true
func _defend_exit() -> bool: return false # This purchase-only attempt never attacks residents.
func _key(code: int) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed; root.push_input(event,true)
	inputs.keys += 1
func _aim(target: Vector3,dt: float) -> float:
	if not OS.has_feature("web"): return super._aim(target,dt)
	if game.runtime.s.mode != "playing": return -1.0
	var offset: Vector3 = target-game.camera.global_position; var desired := Vector2(offset.x,offset.z)
	var forward: Vector3 = -game.camera.global_basis.z
	if desired.length_squared() < 0.000001: return 1.0
	var yaw: float = clampf(Vector2(forward.x,forward.z).angle_to(desired),-4.5*dt,4.5*dt)
	var wanted: float = clampf(atan2(offset.y,desired.length()),-1.1,1.1)
	var step: float = clampf(wanted-game.pitch,-3.0*dt,3.0*dt)
	var event := InputEventMouseMotion.new(); event.button_mask = MOUSE_BUTTON_MASK_RIGHT; event.relative = Vector2(yaw/0.0022,-step/0.0022)
	root.push_input(event,true); inputs.mouse_motion += 1; forward = -game.camera.global_basis.z
	return Vector2(forward.x,forward.z).normalized().dot(desired.normalized())
func _reach_service(id: String) -> bool:
	if id == "cash:"+CASH_ID:
		for pile: Dictionary in game.runtime.state.cash_piles:
			if pile.id == CASH_ID and pile.get("collected",false): return true
		return false
	return await super._reach_service(id)
func _committed() -> Dictionary:
	return {"cash":game.runtime.p.cash,"rocks":game.runtime.p.rocks,"bought":game.runtime.s.counters.rocksBought,"street":game.runtime.p.faction.street,"first_rock":game.runtime.s.quests.first_rock.done,"rng":game.runtime.state.rng_seed,"player":game.runtime.p.duplicate(true)}
func _hand() -> Dictionary:
	var hands = game.hands; var paper: Node3D = hands._props[&"receipt"]
	var mesh: MeshInstance3D = paper.get_node("paper")
	var projected: Array = []; var visible_rect: Rect2 = root.get_visible_rect()
	var inside := false
	var bounds: AABB = mesh.get_aabb()
	for index: int in range(8):
		var point: Vector3 = mesh.global_transform*bounds.get_endpoint(index)
		if game.camera.is_position_behind(point): continue
		var screen: Vector2 = game.camera.unproject_position(point); projected.append([screen.x,screen.y]); inside = inside or visible_rect.has_point(screen)
	return {"action":str(hands.action),"phase":hands.action_phase,"age":hands._action_age,"paper_visible":paper.is_visible_in_tree(),"paper_projected":inside and projected.size() == 8,"paper_logical_pixels":projected,"logical_viewport":[visible_rect.position.x,visible_rect.position.y,visible_rect.size.x,visible_rect.size.y],"paper_transform":str(paper.global_transform),"left_wrist":str(hands._arms[-1].wrist.transform),"right_wrist":str(hands._arms[1].wrist.transform),"camera":str(game.camera.global_transform),"fov":game.camera.fov,"mode":game.runtime.s.mode,"modal":game.hud.modal.visible,"process_frame":Engine.get_process_frames(),"active_ms":game.admitted_ms,"player":[game.runtime.p.x,game.runtime.p.y]}
func _capture_receipt(label: String) -> bool:
	await RenderingServer.frame_post_draw
	if not _alive(): return false
	var row: Dictionary = _hand(); var image: Image = root.get_texture().get_image(); var bytes: PackedByteArray = image.save_png_to_buffer()
	if not _check(bytes.size() > 0 and bytes.size() <= 6291456 and proof.frames.size() < 4,"bounded original PNG"): return false
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	row.merge({"label":label,"framebuffer":[image.get_width(),image.get_height()],"png_bytes":bytes.size(),"png_sha256":hash.finish().hex_encode(),"wall_ms":Time.get_ticks_msec()-boot_ms})
	proof.frames.append(row)
	if OS.has_feature("web"): JavaScriptBridge.eval("window.rbReceiptFrame(%d,%s,%s)" % [proof.frames.size()-1,JSON.stringify(Marshalls.raw_to_base64(bytes)),JSON.stringify(row)])
	else:
		var file := FileAccess.open(output.path_join(label+".png"),FileAccess.WRITE)
		if not _check(file != null,"native capture file opens"): return false
		file.store_buffer(bytes); file.close()
	_publish(false); return true
func _scenario() -> bool:
	if not await _choose("wake up."): return false
	if not _check(game.runtime.s.mode == "playing","actual title Control starts fresh"): return false
	game.start_audit(); last_frame_wall = Time.get_ticks_msec()
	proof.initial = _summary(); proof.initial.source_position = [game.runtime.p.x,game.runtime.p.y]
	if not _check(proof.initial.cash == 0 and proof.initial.rocks == 0 and proof.initial.hp == 100 and proof.initial.weapon == "fists" and proof.initial.routes == 0 and proof.initial.source_position == [1050.0,840.0],"source fresh state without fixtures"): return false
	_phase("cash")
	if not await _visit("cash:"+CASH_ID): return false
	await process_frame
	var collected: Array = (game as ReceiptScene).collections
	if not _check(collected.size() == 1 and collected[0].record.get("amt") == 10 and collected[0].cash_before == 0 and collected[0].cash_after == 10,"real source intro cash transition"): return false
	if not await _capture_receipt(LABELS[0]): return false
	_phase("tony")
	if not await _visit("tony") or not await _reach_service("tony"): return false
	var resolved: Dictionary = game.resolve_interaction().duplicate(true)
	if not _check(Base.interaction_matches(resolved,"tony"),"live Tony resolver before E"): return false
	_key(KEY_E)
	if not _check(game.runtime.s.mode == "dialogue","actual E opens Tony"): return false
	_phase("menu")
	await game.frame_sampled
	if not await _capture_receipt(LABELS[1]): return false
	proof.transaction = {"resolved":{"kind":resolved.get("kind"),"id":resolved.get("id")},"distance":game.runtime.state.player_center().distance_to(_center(_actor("tony"))),"reachable":game.physics.can_reach_target("tony"),"before":_committed()}
	if not await _choose("buy a rock. $10.","buy_rock"): return false
	proof.transaction.after = _committed(); proof.transaction.events = (game as ReceiptScene).purchases.duplicate(true)
	for error: String in commit_errors(proof.transaction): _check(false,error)
	if not _alive(): return false
	_phase("gesture")
	var midpoint := false
	while _alive():
		await game.frame_sampled
		if game.hands.action == &"receipt" and game.hands.action_phase >= 0.30:
			midpoint = await _capture_receipt(LABELS[2]); break
		if game.hands.action.is_empty(): break
	if not _check(midpoint,"actual midpoint observed without hand clock injection"): return false
	while _alive() and not game.hands.action.is_empty(): await game.frame_sampled
	if not _alive(): return false
	await game.frame_sampled
	if not await _capture_receipt(LABELS[3]): return false
	for error: String in frame_errors(proof.frames): _check(false,error)
	var previous_phase := -1.0; var receipt_count := 0; var recovered := false
	for row: Dictionary in (game as ReceiptScene).hand_frames:
		if row.action == "receipt":
			_check(not recovered and row.phase > previous_phase,"receipt advances once without a reset/replay"); previous_phase = row.phase; receipt_count += 1
		elif receipt_count > 0: recovered = true
	_check(receipt_count >= 2 and recovered,"sampled receipt and natural recovery")
	_check((game as ReceiptScene).purchases.size() == 1 and game.runtime.p.cash == 0 and game.runtime.p.rocks == 1 and game.runtime.p.weapon == "fists","one committed purchase and unchanged gear")
	_finish_phase(); return failures.is_empty()
func _publish(complete: bool) -> void:
	proof.finished = finished; proof.ready = ready and not started and not finishing; proof.acceptance = complete and failures.is_empty(); proof.failures = failures.duplicate(); proof.checks = checks
	proof.web = OS.has_feature("web"); proof.framebuffer = [size.x,size.y]; proof.run_id = run_id; proof.storage_fresh = fresh_namespace
	proof.wall_ms = Time.get_ticks_msec()-boot_ms; proof.run_ms = Time.get_ticks_msec()-start_ms if started else 0
	proof.inputs = inputs.duplicate(true); proof.phases = phases.duplicate(true); proof.walking = walking.duplicate(true); proof.walking_context = walking_context.duplicate(true)
	if is_instance_valid(game):
		proof.events = (game as ReceiptScene).evidence_events.duplicate(true); proof.collections = (game as ReceiptScene).collections.duplicate(true)
		proof.hand_frames = (game as ReceiptScene).hand_frames.duplicate(true); proof.replacements = game.replacements.duplicate(true)
	proof.scope = "Actual unaltered viewport; automated ordinary input, no gameplay fixtures. Visual approval, trusted hardware, audio, performance and Web shutdown remain unclaimed."
	if OS.has_feature("web"): JavaScriptBridge.eval("window.rbReceiptReport(%s)" % JSON.stringify(proof))
	elif output_owned:
		var file := FileAccess.open(output.path_join("receipt-visual.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(proof,"\t")); file.close()
func _queue_finish() -> void:
	if finishing or finished: return
	finishing = true; call_deferred("_finish")
func _finish() -> void:
	if finished: return
	_release()
	if not failures.is_empty() and is_instance_valid(game) and game.ready_for_play:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image(); var bytes := image.save_png_to_buffer()
		if bytes.size() > 0 and bytes.size() <= 6291456:
			var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
			proof.failure_frame = {"label":"failure","framebuffer":[image.get_width(),image.get_height()],"png_sha256":hash.finish().hex_encode(),"png_bytes":bytes.size()}
			if OS.has_feature("web"): JavaScriptBridge.eval("window.rbReceiptFrame(4,%s,%s)" % [JSON.stringify(Marshalls.raw_to_base64(bytes)),JSON.stringify(proof.failure_frame)])
			elif output_owned:
				var file := FileAccess.open(output.path_join("failure.png"),FileAccess.WRITE)
				if file != null: file.store_buffer(bytes); file.close()
	if OS.has_feature("web") and is_instance_valid(game) and game.runtime != null and game.runtime.s.mode == "playing": _key(KEY_ESCAPE)
	finished = true; _publish(true)
	if not OS.has_feature("web"):
		print("VENDOR RECEIPT VISUAL: ","PASS" if failures.is_empty() else "FAIL","; ",output)
		await _shutdown(0 if failures.is_empty() else 1)
func _start() -> void:
	if started or finishing or finished or not ready: return
	started = true; start_ms = Time.get_ticks_msec()
	var complete: bool = await _scenario()
	_check(complete and proof.frames.size() == 4,"whole input scenario completed")
	_queue_finish()
func _control(args: Array) -> void:
	if args.size() != 1 or not args[0] is String: return
	if args[0] == "start": call_deferred("_start")
	elif args[0] == "abort": _check(false,"operator aborted"); _queue_finish()
func _run() -> void:
	boot_ms = Time.get_ticks_msec(); began_wall = boot_ms
	if DisplayServer.get_name() == "headless" or "--qa-full" not in OS.get_cmdline_user_args(): push_error("Receipt visual requires actual renderer and --qa-full"); quit(1); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument.begins_with("--run-id="): run_id = argument.trim_prefix("--run-id=")
	var expression := RegEx.new(); expression.compile("^[a-z0-9][a-z0-9_-]{0,47}$")
	if expression.search(run_id) == null: push_error("Explicit unique receipt run ID required"); quit(1); return
	if OS.has_feature("web"):
		size = Vector2i(960,540); callback = JavaScriptBridge.create_callback(_control); JavaScriptBridge.get_interface("window").rbReceiptControl = callback
	else:
		if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output): push_error("Fresh absolute output required; no retry overwrite"); quit(1); return
		if DirAccess.make_dir_recursive_absolute(output) != OK: push_error("Output unavailable"); quit(1); return
		output_owned = true
	root.size = size; Engine.max_fps = 60; game = ReceiptScene.new(); root.add_child(game)
	while not game.ready_for_play and _alive():
		_bind_store()
		if Time.get_ticks_msec()-boot_ms >= 180000: _check(false,"180s cold startup"); break
		await process_frame
	if not _alive(): _queue_finish(); return
	_bind_store()
	var data: Dictionary = await game.store.read_save()
	if not _check(data.is_empty() and game.store.last_error.is_empty(),"fresh isolated save read"): _queue_finish(); return
	if OS.has_feature("web"):
		var result: Variant = JSON.parse_string(str(JavaScriptBridge.eval("window.rb3dStorageResult || ''")))
		if not _check(result is Dictionary and result.get("ok") == true and result.get("data") == "","actual fresh IndexedDB key"): _queue_finish(); return
	fresh_namespace = true; ready = true; proof.hashes = {}
	for path: String in ["res://scripts/full_scene.gd","res://scripts/save_store.gd","res://scripts/first_person_rig.gd","res://scripts/vendors_core.gd","res://tests/vendor_receipt_probe.gd","res://tests/office_acceptance_probe.gd","res://data/source_content.json"]: proof.hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	proof.source_hashes_available = not str(proof.hashes["res://scripts/full_scene.gd"]).is_empty()
	_publish(false)
	if not OS.has_feature("web"): await _start()

func _bind_store() -> void:
	if store_bound or not is_instance_valid(game) or game.store == null: return
	game.store.storage_key = "rockbottom_3d_receipt_qa_"+run_id
	game.store.save_path = "user://receipt_qa_"+run_id+".json" if OS.has_feature("web") else output.path_join("qa-save.json")
	store_bound = true

# Movement/planning is inherited byte-for-byte, including the empty-route wait.
