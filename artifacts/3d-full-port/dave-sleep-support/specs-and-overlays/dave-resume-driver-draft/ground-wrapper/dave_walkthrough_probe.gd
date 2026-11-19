extends "res://tests/boss_acceptance_probe.gd"
## Three actual frames and one ordinary wake; no source state fixtures.
const Driver = preload("res://tests/boss_acceptance_probe.gd")
const TOTAL_MS := 120000
const LABELS := ["01_sleeping_dave","02_awake_dave","03_pigeon_dialogue"]
const PIGEONS := "dave is explaining a theory about pigeons.\nthe theory has 17 parts."
class DaveScene:
	extends Driver.ObservedScene
	var wake_events: Array[Dictionary] = []
	var overflow := false
	func _consume_events() -> void:
		if audit_enabled and runtime != null:
			var pending: Array = runtime._outbox.duplicate(); pending.append_array(runtime.state.events)
			for event: Dictionary in pending:
				if event.kind not in ["toast","death","arrest","boss_started","dependency_missing","player_attack"]: continue
				if wake_events.size() >= 512: overflow = true; break
				wake_events.append({"kind":event.kind,"payload":event.get("payload",{}).duplicate(true),"wall_ms":Time.get_ticks_msec()})
		super._consume_events()

var proof := {"schema":1,"format":"rock-bottom-dave-walkthrough","fixture":"none","frames":[],"wake":{},"idle":[],"movement":{},"initial":{},"acceptance":false,"visual_acceptance":false}
var started := false
var finishing := false
var finished := false
var boot_wall := 0
var browser_callback: JavaScriptObject
var frame_size := Vector2i(1280,720)
var output_owned := false

static func wake_unchanged(before: Dictionary,after: Dictionary) -> bool:
	if before.get("actor",{}).get("asleep") != true or after.get("actor",{}).get("asleep") != false: return false
	var expected: Dictionary = before.duplicate(true); expected.actor.asleep = false
	return expected == after

static func resume_choice(origin: Vector3, preferred: Vector3, certify: Callable) -> Dictionary:
	if not origin.is_finite() or not preferred.is_finite() or not certify.is_valid(): return {"ok":false,"attempts":0}
	var heading := Vector2(preferred.x-origin.x,preferred.z-origin.z)
	if heading.length_squared() < 0.000001: return {"ok":false,"attempts":0}
	var angle: float = heading.angle()
	var attempts: int = 0
	for offset: float in [0.0,PI*0.25,-PI*0.25,PI*0.5,-PI*0.5,PI*0.75,-PI*0.75,PI]:
		var point := origin+Vector3(cos(angle+offset),0,sin(angle+offset))*0.35
		attempts += 1
		var receipt: Dictionary = certify.call(origin,point)
		if receipt.get("ok") == true: return {"ok":true,"point":point,"attempts":attempts,"certificate":receipt.duplicate(true)}
	return {"ok":false,"attempts":attempts}

static func report_errors(row: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if row.get("format") != "rock-bottom-dave-walkthrough" or row.get("fixture") != "none" or row.get("title_input") != true: errors.append("ordinary title start without fixtures")
	var initial_row: Dictionary = row.get("initial",{})
	for pair: Array in [["cash",0],["hp",100],["weapon","fists"],["rocks",0],["cred",0],["cart_mounted",false]]:
		if initial_row.get(pair[0]) != pair[1]: errors.append("fresh source field "+str(pair[0]))
	var position: Variant = initial_row.get("source_position")
	var position_ok: bool = position is Array and position.size() == 2
	if position_ok: position_ok = position[0] == 1050 and position[1] == 840
	if not position_ok or initial_row.get("inventory") != []: errors.append("fresh source spawn/inventory")
	for slot: String in ["hat","coat","shoes","tool"]:
		if not initial_row.get("equip",{}).has(slot) or initial_row.equip[slot] != null: errors.append("fresh equipment "+slot)
	var frames: Array = row.get("frames",[])
	if frames.size() != 3: errors.append("exactly three original frames")
	for index: int in range(frames.size()):
		var frame: Dictionary = frames[index]
		if index >= 3 or frame.get("label") != LABELS[index]: errors.append("ordered frame identity"); continue
		var size: Variant = frame.get("framebuffer")
		var size_ok: bool = size is Array and size.size() == 2
		if size_ok: size_ok = (size[0] == 1280 and size[1] == 720) or (size[0] == 960 and size[1] == 540)
		if not size_ok or frame.get("png_bytes",0) <= 0 or frame.get("png_bytes",6291457) > 6291456 or str(frame.get("png_sha256","")).length() != 64: errors.append("bounded original framebuffer")
		var up: float = float(frame.get("root_up",NAN))
		if not is_finite(up) or (absf(up) >= 0.2 if index == 0 else up <= 0.95): errors.append("source sleep/awake actual root pose")
		if frame.get("asleep") != (index == 0) or frame.get("sleep_markers") != (2 if index == 0 else 0): errors.append("source flag and rendered Z facts")
		if frame.get("projected") != true or frame.get("clear_ray") != true or frame.get("reachable") != true: errors.append("actual visible/reachable Dave framing")
		if frame.get("mode") != ("dialogue" if index == 2 else "playing"): errors.append("capture mode")
		if index == 2 and (PIGEONS not in frame.get("menu",{}).get("labels",[]) or "wake him up." in frame.get("menu",{}).get("buttons",[])): errors.append("actual awake pigeon menu")
	var wake: Dictionary = row.get("wake",{})
	if wake.get("resolved") != {"kind":"quest","id":"dave"} or wake.get("pressed") != true or not wake_unchanged(wake.get("before",{}),wake.get("after",{})): errors.append("exact ordinary wake boundary")
	var distance: float = float(wake.get("distance",NAN))
	if not is_finite(distance) or distance < 0 or distance >= 60 or wake.get("reachable") != true: errors.append("real source wake range")
	var idle: Array = row.get("idle",[])
	var idle_ms: float = float(row.get("idle_active_ms",NAN))
	if idle.size() < 2 or idle.size() > 360 or not is_finite(idle_ms) or idle_ms < 4000: errors.append("complete active idle cosmetic period")
	for sample: Dictionary in idle:
		var up: float = float(sample.get("root_up",NAN))
		if not is_finite(up) or up <= 0.95 or sample.get("asleep") != false or sample.get("sleep_markers") != 0: errors.append("awake idle cannot return to sleep")
	var movement: Dictionary = row.get("movement",{})
	var metres: float = float(movement.get("metres",NAN))
	if not is_finite(metres) or metres < 0.15 or movement.get("input_frames",0) <= 0 or movement.get("mode") != "playing" or movement.get("modal") != false: errors.append("Leave and actual resumed movement")
	var wake_toasts := 0
	for event: Dictionary in row.get("events",[]):
		if event.kind == "toast" and event.get("payload",{}).get("text") == "dave wakes up. he is talking immediately.": wake_toasts += 1
		if event.kind in ["death","arrest","boss_started","dependency_missing","player_attack"]: errors.append("unexpected lifecycle/combat "+str(event.kind))
	if wake_toasts != 1 or row.get("replacements",1) != 0 or row.get("overflow",true): errors.append("one real wake and same bounded epoch")
	for kind: String in ["motion_frames","mouse_motion","keys","clicks"]:
		if row.get("inputs",{}).get(kind,0) <= 0: errors.append("actual normal input "+kind)
	var elapsed: float = float(row.get("wall_ms",NAN))
	if not is_finite(elapsed) or elapsed <= 0 or elapsed >= TOTAL_MS: errors.append("one120s whole attempt")
	return errors

func _process(_delta: float) -> bool:
	if not finished and not finishing and boot_wall > 0 and Time.get_ticks_msec()-boot_wall >= TOTAL_MS:
		_check(false,"independent120s whole attempt watchdog"); call_deferred("_finish_dave"); finishing = true
	return false

func _alive() -> bool:
	if finished or finishing or not failures.is_empty(): return false
	if not _check(Time.get_ticks_msec()-boot_wall < TOTAL_MS,"one120s whole attempt deadline"): return false
	if game == null or not game.audit_enabled: return true
	if not _check(game.replacements == 0 and not (game as DaveScene).overflow and game.runtime.p.hp > 0,"living same bounded source epoch"): return false
	for event: Dictionary in (game as DaveScene).wake_events:
		if event.kind in ["death","arrest","boss_started","dependency_missing","player_attack"]: return _check(false,"unexpected source event "+str(event.kind))
	return true
func _defend_exit() -> bool: return false
func _key(code: int) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = pressed; root.push_input(event,true)
	inputs.keys += 1
func _aim(target: Vector3,dt: float) -> float:
	if not OS.has_feature("web"): return super._aim(target,dt)
	if game.runtime.s.mode != "playing": return -1.0
	var to: Vector3 = target-game.camera.global_position; var desired := Vector2(to.x,to.z)
	var forward3: Vector3 = -game.camera.global_basis.z; var forward := Vector2(forward3.x,forward3.z)
	if desired.length_squared() < 0.000001: return 1.0
	var yaw: float = clampf(forward.angle_to(desired),-4.5*dt,4.5*dt)
	var pitch_step: float = clampf(clampf(atan2(to.y,desired.length()),-1.1,1.1)-game.pitch,-3.0*dt,3.0*dt)
	var event := InputEventMouseMotion.new(); event.button_mask = MOUSE_BUTTON_MASK_RIGHT; event.relative = Vector2(yaw/0.0022,-pitch_step/0.0022)
	root.push_input(event,true); inputs.mouse_motion += 1; forward3 = -game.camera.global_basis.z
	return Vector2(forward3.x,forward3.z).normalized().dot(desired.normalized())
func _reach_service(id: String) -> bool:
	if id != "dave" or not game.physics.can_reach_target(id): return false
	_release()
	for frame: int in range(120):
		if not _alive() or game.runtime.s.mode != "playing" or not game.physics.can_reach_target(id): return false
		_aim(game.world.service_points[id].target,_dt())
		var selected: Dictionary = game.resolve_interaction()
		if selected.get("kind") == "quest" and selected.get("id") == id: return true
		await game.frame_sampled
	return false
func _click_option(label: String) -> bool:
	await process_frame
	for child: Node in game.hud.menu_box.get_children():
		if not child is Button or child.text != label: continue
		if not _check(child.is_visible_in_tree() and not child.disabled,"real enabled Control "+label): return false
		var at: Vector2 = child.get_global_rect().get_center()
		for pressed: bool in [true,false]:
			var event := InputEventMouseButton.new(); event.position = at; event.global_position = at; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; root.push_input(event,true)
		inputs.clicks += 1; return true
	return _check(false,"actual menu option exists "+label)
func _menu() -> Dictionary:
	var result := {"labels":[],"buttons":[]}
	for child: Node in game.hud.menu_box.get_children():
		if child is Label: result.labels.append(child.text)
		elif child is Button and child.is_visible_in_tree(): result.buttons.append(child.text)
	return result
func _wake_state() -> Dictionary:
	return {"player":game.runtime.p.duplicate(true),"actor":_actor("dave").duplicate(true),"rng":game.runtime.state.rng_seed}
func _pose_record() -> Dictionary:
	var body: Dictionary = _actor("dave"); var result := {"asleep":body.get("asleep"),"root_up":NAN,"sleep_markers":-1}
	var art: Node3D = game.actors.get("dave").get_node_or_null("Art") if game.actors.has("dave") else null
	if art != null and art.has_meta("roster_rig"):
		var rig: Dictionary = art.get_meta("roster_rig"); var skeleton: Skeleton3D = rig.skeleton
		result.root_up = skeleton.get_bone_pose(skeleton.find_bone("root")).basis.y.normalized().dot(Vector3.UP)
	if game.hud.actor_overlay != null and game.hud.actor_overlay._view != null:
		for row: Dictionary in game.hud.actor_overlay._view.snapshot(0.0).get("actors",[]):
			if row.get("id") != "dave": continue
			result.sleep_markers = 0
			for marker: Dictionary in row.get("markers",[]):
				if marker.get("kind") == "sleep": result.sleep_markers += 1
	return result
func _visual_focus() -> Vector3:
	var art: Node3D = game.actors.dave.get_node("Art"); var rig: Dictionary = art.get_meta("roster_rig"); var skeleton: Skeleton3D = rig.skeleton
	var head: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin)
	return (head+game.actors.dave.global_position)*0.5+Vector3.UP*0.25
func _frame_dave() -> bool:
	_release()
	for frame: int in range(120):
		if not _alive(): return false
		var focus: Vector3 = _visual_focus(); _aim(focus,_dt()); await game.frame_sampled
		var direction: Vector3 = (focus-game.camera.global_position).normalized()
		if (-game.camera.global_basis.z).dot(direction) > 0.995: return true
	return _check(false,"bounded actual input frames Dave")
func _capture_dave(index: int) -> bool:
	await game.frame_sampled; await RenderingServer.frame_post_draw
	if not _alive(): return false
	var image: Image = root.get_texture().get_image(); var bytes: PackedByteArray = image.save_png_to_buffer()
	if not _check(bytes.size() > 0 and bytes.size() <= 6291456 and proof.frames.size() == index and index < 3,"bounded ordered original PNG"): return false
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	var row: Dictionary = _pose_record(); var focus: Vector3 = _visual_focus(); var rectangle: Rect2 = game.camera.get_viewport().get_visible_rect()
	row.merge({"label":LABELS[index],"framebuffer":[image.get_width(),image.get_height()],"png_bytes":bytes.size(),"png_sha256":hash.finish().hex_encode(),"process_frame":Engine.get_process_frames(),"mode":game.runtime.s.mode,"menu":_menu(),"reachable":game.physics.can_reach_target("dave"),"projected":not game.camera.is_position_behind(focus) and rectangle.has_point(game.camera.unproject_position(focus)),"clear_ray":game.physics._ray(game.camera.global_position,focus).is_empty(),"focus":[focus.x,focus.y,focus.z],"camera":[game.camera.global_position.x,game.camera.global_position.y,game.camera.global_position.z]})
	row["posed_ground"] = preload("res://tests/posed_ground_diagnostic.gd").measure(game.actors.dave.get_node("Art"))
	proof.frames.append(row); captures.append(LABELS[index])
	if OS.has_feature("web"): JavaScriptBridge.eval("window.rbDaveFrame(%d,%s,%s)" % [index,JSON.stringify(Marshalls.raw_to_base64(bytes)),JSON.stringify(row)])
	else:
		var file := FileAccess.open(output.path_join(LABELS[index]+".png"),FileAccess.WRITE)
		if not _check(file != null,"native PNG file opens"): return false
		file.store_buffer(bytes); file.close()
	_publish_dave(false); return true

func _dave_scenario() -> void:
	if not await _click_option("wake up."): return
	if not _check(game.runtime.s.mode == "playing","actual title input starts fresh"): return
	proof.title_input = true; game.start_audit(); last_frame_wall = Time.get_ticks_msec()
	proof.initial = _summary(); proof.initial.source_position = [game.runtime.p.x,game.runtime.p.y]
	var spawn: Vector3 = game.player.position
	if not await _walk_to(game.world.service_points.dave.approach,"dave"): return
	if not await _frame_dave() or not await _capture_dave(0): return
	if not await _reach_service("dave"): _check(false,"real Dave E reacquired after sleeping portrait"); return
	var action: Dictionary = game.resolve_interaction()
	proof.wake = {"resolved":{"kind":action.get("kind"),"id":action.get("id")},"distance":game.runtime.state.player_center().distance_to(_center(_actor("dave"))),"reachable":game.physics.can_reach_target("dave")}
	_key(KEY_E)
	if not _check(game.runtime.s.mode == "dialogue" and "wake him up." in _menu().buttons,"real E opens sleeping Dave options"): return
	# Capture immediately around the synchronous actual Control handler, not frames.
	await process_frame; proof.wake.before = _wake_state()
	proof.wake.pressed = await _click_option("wake him up."); proof.wake.after = _wake_state()
	if not _check(proof.wake.pressed and wake_unchanged(proof.wake.before,proof.wake.after),"wake changes only source asleep flag"): return
	var idle_start: float = game.admitted_ms
	while game.admitted_ms-idle_start < 4000:
		if not _alive() or not _check(proof.idle.size() < 360,"bounded active idle pose samples"): return
		await game.frame_sampled; proof.idle.append(_pose_record())
	proof.idle_active_ms = game.admitted_ms-idle_start
	if not await _frame_dave() or not await _capture_dave(1): return
	if not await _reach_service("dave"): _check(false,"real awake Dave E target reacquired"); return
	_key(KEY_E)
	if not _check(game.runtime.s.mode == "dialogue" and PIGEONS in _menu().labels,"actual reopened awake pigeon dialogue"): return
	if not await _capture_dave(2) or not await _click_option("leave."): return
	var origin: Vector3 = game.player.position; var input_count: int = int(inputs.motion_frames)
	var point := Vector3.INF
	var move_start: int = Time.get_ticks_msec()
	var last_choice: int = move_start-250
	var choices: int = 0
	proof.resume_choices = []
	while game.player.position.distance_to(origin) < 0.15:
		if not _alive() or not _check(Time.get_ticks_msec()-move_start < 5000,"finite resumed movement"): _release(); return
		var now: int = Time.get_ticks_msec()
		var clear: bool = point.is_finite() and bool(_combat_segment(game.player.position,point).ok)
		if not clear:
			_release()
			if now-last_choice >= 250 and choices < 20:
				last_choice = now; choices += 1
				var selected: Dictionary = resume_choice(game.player.position,spawn,Callable(self,"_combat_segment"))
				proof.resume_choices.append({"wall_ms":now-boot_wall,"choice":choices,"result":selected.duplicate(true)})
				point = selected.point if selected.ok else Vector3.INF
				clear = bool(selected.ok)
		if clear:
			var alignment: float = _aim(Vector3(point.x,game.camera.global_position.y,point.z),_dt())
			_motion(Vector2(point.x-game.player.position.x,point.z-game.player.position.z).normalized() if alignment > 0.96 else Vector2.ZERO)
		await game.frame_sampled
	_release(); proof.movement = {"metres":game.player.position.distance_to(origin),"input_frames":int(inputs.motion_frames)-input_count,"mode":game.runtime.s.mode,"modal":game.hud.modal.visible}

func _publish_dave(complete: bool) -> void:
	proof.wall_ms = Time.get_ticks_msec()-boot_wall; proof.inputs = inputs.duplicate(true); proof.walking = walking.duplicate(true)
	proof.events = (game as DaveScene).wake_events.duplicate(true) if is_instance_valid(game) else []
	proof.replacements = game.replacements if is_instance_valid(game) else 0; proof.overflow = (game as DaveScene).overflow if is_instance_valid(game) else false
	proof.finished = finished; proof.failures = failures.duplicate(); proof.acceptance = complete and failures.is_empty(); proof.web = OS.has_feature("web")
	proof.engine = Engine.get_version_info().string; proof.renderer = RenderingServer.get_current_rendering_method()
	proof.scope = "Actual rendered viewport and synthetic ordinary input; visual review still required. No trusted hardware/pointer-lock/audio/performance claim. Empty packaged hashes are unavailable."
	if OS.has_feature("web"): JavaScriptBridge.eval("window.rbDaveReport(%s)" % JSON.stringify(proof))
	elif output_owned:
		var file := FileAccess.open(output.path_join("dave-walkthrough.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(proof,"\t")); file.close()
func _finish_dave() -> void:
	if finished: return
	finishing = true; _release(); _publish_dave(false)
	if failures.is_empty():
		for error: String in report_errors(proof): _check(false,error)
	finished = true
	if OS.has_feature("web"):
		if is_instance_valid(game) and game.runtime != null and game.runtime.s.mode == "playing":
			_key(KEY_ESCAPE); _check(game.runtime.s.mode == "paused" and game.hud.modal.visible,"actual Escape pauses completed Web playback")
		_publish_dave(true)
	else:
		_publish_dave(true); print("DAVE WALKTHROUGH: ","PASS" if failures.is_empty() else "FAIL","; ",output)
		await _shutdown(0 if failures.is_empty() else 1)
func _start_dave() -> void:
	if started or finished or finishing: return
	started = true
	await _dave_scenario(); await _finish_dave()
func _browser_control(args: Array) -> void:
	if args.size() != 1 or not args[0] is String: return
	if args[0] == "abort": _check(false,"operator aborted"); call_deferred("_finish_dave")
	elif args[0] == "start" and not started and game.ready_for_play: call_deferred("_start_dave")
func _run() -> void:
	boot_wall = Time.get_ticks_msec(); began_wall = boot_wall
	if "--qa-full" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": push_error("Dave walkthrough requires actual rendering and --qa-full"); quit(1); return
	if OS.has_feature("web"):
		frame_size = Vector2i(960,540); browser_callback = JavaScriptBridge.create_callback(_browser_control)
		JavaScriptBridge.get_interface("window").rbDaveControl = browser_callback
	else:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output): push_error("Dave requires a new absolute output directory"); quit(1); return
		if DirAccess.make_dir_recursive_absolute(output) != OK: push_error("Dave output unavailable"); quit(1); return
		output_owned = true
	root.size = frame_size; Engine.max_fps = 60; game = DaveScene.new(); game.qa_mode = true; root.add_child(game)
	while not game.ready_for_play and _alive(): await process_frame
	if not _alive() or not game.ready_for_play: await _finish_dave(); return
	game.store.save_path = "user://dave_walkthrough_qa.json" if OS.has_feature("web") else output.path_join("qa-save.json")
	game.store.storage_key = "rockbottom_dave_walkthrough_qa"
	proof.hashes = {}
	for path: String in ["res://scripts/cast_profiles.gd","res://scripts/actor_animation.gd","res://scripts/full_scene.gd","res://scripts/quest_dialogue.gd","res://tests/boss_acceptance_probe.gd","res://tests/dave_walkthrough_probe.gd","res://data/source_content.json"]:
		proof.hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	if OS.has_feature("web"): _publish_dave(false)
	else: await _start_dave()
