extends "res://tests/boss_acceptance_probe.gd"
## DRAFT: real Web FullScene routing; no direct gameplay or Rig action calls.
const Driver = preload("res://tests/boss_acceptance_probe.gd")
const PHASES := ["idle","right_attack","right_recovery","left_attack","left_recovery",
	"pickup","pickup_recovery","cart_parked","cart_mount_level","cart_down_grip",
	"cart_roll","cart_stop","cart_attack","cart_regrip","cart_level_release","cart_dismount"]
const SESSION_MS := 1200000
const COLD_MS := 180000
const MAX_REQUESTS := 32
const CASH_ID := "cp_intro_remember"

class WebHandsScene:
	extends Driver.ObservedScene
	var hand_events: Array[Dictionary] = []
	var hand_samples: Array[Dictionary] = []
	var overflow := false
	var phase_index := -1
	func _consume_events() -> void:
		if audit_enabled and runtime != null:
			var events: Array = runtime._outbox.duplicate(); events.append_array(runtime.state.events)
			for event: Dictionary in events:
				if event.kind not in ["player_attack","gesture","cart_changed","toast","death","arrest","boss_started","dependency_missing"]: continue
				if hand_events.size() >= 512: overflow = true; break
				hand_events.append({"kind":event.kind,"payload":event.get("payload",{}).duplicate(true),"phase":phase_index,"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms})
		super._consume_events()
	func _process(delta: float) -> void:
		super._process(delta)
		if not audit_enabled or runtime.s.mode != "playing" or hands == null: return
		if hand_samples.size() >= 8192: overflow = true; return
		var row := {"phase":phase_index,"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms,"action":str(hands.action),"age":hands._action_age,"side":hands.last_punch_side,"source":[runtime.p.x,runtime.p.y],"wrists":{}}
		for side: int in [-1,1]:
			var wrist: Node3D = hands._arms[side].wrist
			var at: Vector3 = camera.to_local(wrist.global_position)
			row.wrists[str(side)] = [at.x,at.y,at.z]
		hand_samples.append(row)

var _web_callback: JavaScriptObject
var _web_busy := true
var _web_finished := false
var _web_current := -1
var _web_requests := 0
var _web_phase_started := 0
var _web_phase_limit := 5000
var _web_boot_started := 0
var _web_size := Vector2i(1280,720)
var _web_records: Array[Dictionary] = []
var _web_mesh_cache: Array[Dictionary] = []
var _web_initial: Dictionary = {}
var _web_hashes: Dictionary = {}
var _web_last_event := 0
var _web_roll_angle := 0.0
var _web_roll_start := Vector3.ZERO
var _web_report: Dictionary = {}

static func frame_errors(row: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var index: int = int(row.get("index",-1))
	if index < 0 or index >= PHASES.size() or row.get("label") != PHASES[index]: return ["invalid phase identity"]
	if row.get("framebuffer") not in [[1280,720],[960,540]]: errors.append("actual framebuffer size")
	if row.get("mode") != "playing" or row.get("hands_visible") != true: errors.append("capture was not actual active hands")
	var envelope: Dictionary = row.get("envelope",{})
	var nearest: float = float(envelope.get("nearest_z",NAN))
	var near_plane: float = float(row.get("camera_near",NAN))
	if envelope.get("finite") != true or envelope.get("vertices",0) <= 0 or envelope.get("on_screen",0) <= 0 or not is_finite(nearest) or not is_finite(near_plane) or near_plane <= 0.0 or nearest > -near_plane+0.000001: errors.append("visible geometry or actual near-plane envelope")
	if index in [1,3,12]:
		var age: float = float(row.get("age",NAN))
		if row.get("action") != "punch" or row.get("attack_weapon") != "fists" or row.get("side") != (-1 if index == 3 else 1) or not is_finite(age) or age < 0.0 or age >= 0.24: errors.append("actual alternating active attack")
	elif index == 5:
		var age: float = float(row.get("age",NAN))
		if row.get("action") != "pickup" or row.get("cash_collected") != true or not is_finite(age) or age < 0.04 or age >= 0.32: errors.append("actual committed rendered pickup pose")
	elif row.get("action") != "": errors.append("recovery/rest contains unfinished action")
	var cart: Dictionary = row.get("cart",{})
	if index >= 8 and index <= 14:
		if cart.get("mounted") != true or cart.get("layer") != 0 or cart.get("clear") != true: errors.append("mounted live cart/collider/clearance")
	if index in [9,10,11,13]:
		for hand: String in ["left","right"]:
			var distance: float = float(cart.get("grip_error",{}).get(hand,NAN))
			if not is_finite(distance) or distance > 0.0001: errors.append("actual handle grip "+hand)
	if index == 12:
		var left: float = float(cart.get("grip_error",{}).get("left",NAN))
		var right: float = float(cart.get("grip_error",{}).get("right",NAN))
		if not is_finite(left) or left > 0.0001 or not is_finite(right) or right < 0.01: errors.append("only attacking hand leaves handle")
	if index in [8,14] and not cart.get("targets",[]).is_empty(): errors.append("level view retains offscreen targets")
	if index == 15 and (cart.get("mounted") != false or cart.get("layer") != 1): errors.append("actual dismount restores parked body")
	return errors

static func sequence_errors(report: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var records: Array = report.get("records",[])
	if report.get("web") != true or records.size() != PHASES.size(): errors.append("complete actual Web sequence required")
	for index: int in range(records.size()):
		if records[index].get("index") != index: errors.append("ordered one-time phase required")
		errors.append_array(frame_errors(records[index]))
	if report.get("initial",{}).get("fixture") != "none" or report.get("initial",{}).get("weapon") != "fists" or report.get("initial",{}).get("cash") != 0 or report.get("initial",{}).get("cart_mounted") != false: errors.append("ordinary fresh baseline required")
	if report.get("replacements",1) != 0 or report.get("overflow",true): errors.append("same epoch and finite evidence required")
	var attacks := 0; var pickups := 0; var mounts: Array[bool] = []
	for event: Dictionary in report.get("events",[]):
		if event.get("kind") == "player_attack":
			attacks += 1
			if event.get("payload",{}).get("used_weapon") != "fists": errors.append("source accepted fists receipt required")
		elif event.get("kind") == "gesture" and event.get("payload",{}).get("action") == "pickup": pickups += 1
		elif event.get("kind") == "cart_changed": mounts.append(event.get("payload",{}).get("mounted",false) == true)
	if attacks != 3 or pickups != 1 or mounts != [true,false]: errors.append("exact committed source receipts required")
	for kind: String in ["motion_frames","mouse_motion","keys","clicks"]:
		if report.get("inputs",{}).get(kind,0) <= 0: errors.append("actual input evidence "+kind)
	if report.get("samples",[]).is_empty(): errors.append("actual wrist trajectory required")
	return errors

func _alive() -> bool:
	if _web_finished or not failures.is_empty(): return false
	if not _check(Time.get_ticks_msec()-_web_boot_started < SESSION_MS,"bounded whole Web session"): return false
	if _web_busy and _web_phase_started > 0 and not _check(Time.get_ticks_msec()-_web_phase_started < _web_phase_limit,"bounded active Web phase"): return false
	if game == null or not game.audit_enabled: return true
	var observed := game as WebHandsScene
	if not _check(game.replacements == 0 and not observed.overflow,"same epoch and bounded Web evidence"): return false
	if not _check(game.runtime.p.hp > 0 and game.runtime.s.mode not in ["dead","arrested","title"],"living current source session"): return false
	for event: Dictionary in observed.hand_events:
		if event.kind in ["death","arrest","boss_started","dependency_missing"]: return _check(false,"unexpected source lifecycle: "+str(event.kind))
	return true

func _defend_exit() -> bool: return false

func _key(code: int) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = pressed
		root.push_input(event,true)
	inputs.keys += 1

func _aim(target: Vector3,dt: float) -> float:
	if game.runtime.s.mode != "playing": return -1.0
	var to: Vector3 = target-game.camera.global_position
	var desired := Vector2(to.x,to.z)
	var forward3: Vector3 = -game.camera.global_basis.z
	var forward := Vector2(forward3.x,forward3.z)
	if desired.length_squared() < 0.000001: return 1.0
	var yaw: float = clampf(forward.angle_to(desired),-4.5*dt,4.5*dt)
	var pitch: float = clampf(atan2(to.y,desired.length()),-1.1,1.1)
	var pitch_step: float = clampf(pitch-game.pitch,-3.0*dt,3.0*dt)
	var event := InputEventMouseMotion.new(); event.button_mask = MOUSE_BUTTON_MASK_RIGHT
	event.relative = Vector2(yaw/0.0022,-pitch_step/0.0022); root.push_input(event,true); inputs.mouse_motion += 1
	forward3 = -game.camera.global_basis.z
	return Vector2(forward3.x,forward3.z).normalized().dot(desired.normalized())

func _web_pile() -> Dictionary:
	for pile: Dictionary in game.runtime.state.cash_piles:
		if pile.get("id") == CASH_ID: return pile
	return {}

func _reach_service(id: String) -> bool:
	if id == "cash:"+CASH_ID:
		# Movement already triggered source auto-collect. Never send stale E.
		return _web_pile().get("collected",false)
	if id.is_empty() or not game.world.service_points.has(id) or not game.physics.can_reach_target(id): return false
	_release()
	for frame: int in range(120):
		if not _alive() or game.runtime.s.mode != "playing" or not game.physics.can_reach_target(id): return false
		_aim(game.world.service_points[id].target,_dt())
		var selected: Dictionary = game.resolve_interaction()
		if selected.get("kind") == "cart" and selected.get("id") == id: return true
		await game.frame_sampled
	return false

func _web_click_menu(label: String) -> bool:
	await process_frame # Let the real Control layout settle.
	for child: Node in game.hud.menu_box.get_children():
		if not child is Button or child.text != label: continue
		if not _check(child.is_visible_in_tree() and not child.disabled,"actual enabled UI button "+label): return false
		var at: Vector2 = child.get_global_rect().get_center()
		var motion_event := InputEventMouseMotion.new(); motion_event.position = at; motion_event.global_position = at
		root.push_input(motion_event,true)
		for pressed: bool in [true,false]:
			var event := InputEventMouseButton.new(); event.position = at; event.global_position = at
			event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; root.push_input(event,true)
		inputs.clicks += 1
		return true
	return _check(false,"actual UI button exists: "+label)

func _web_wait(seconds: float) -> bool:
	var start: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec()-start) < seconds*1000.0:
		if not _alive(): return false
		await game.frame_sampled
	return true

func _web_rest() -> bool:
	_release()
	while not game.hands.action.is_empty() or game.runtime.p.attackCd > 0:
		if not _alive(): return false
		await game.frame_sampled
	return await _web_wait(0.12)

func _web_pitch(value: float) -> bool:
	var horizontal: Vector3 = -game.player.global_basis.z; horizontal.y = 0; horizontal = horizontal.normalized()
	var target: Vector3 = game.camera.global_position+horizontal*4.0+Vector3.UP*tan(value)*4.0
	for frame: int in range(150):
		if not _alive(): return false
		_aim(target,_dt()); await game.frame_sampled
		if absf(game.pitch-value) < 0.003: return true
	return _check(false,"actual right-drag look reached pitch")

func _web_event_count(kind: String,action_id: String = "") -> int:
	var result := 0
	for row: Dictionary in (game as WebHandsScene).hand_events:
		if row.kind == kind and (action_id.is_empty() or row.payload.get("action") == action_id): result += 1
	return result

func _web_attack(side: int) -> bool:
	if not await _web_rest(): return false
	var before: int = _web_event_count("player_attack")
	if not _check(game.runtime.p.weapon == "fists" and game.runtime.p.attackCd == 0,"fresh real fists/cooldown"): return false
	_key(KEY_SPACE)
	if not _check(_web_event_count("player_attack") == before+1 and game.hands.action == &"punch" and game.hands.last_punch_side == side,"one real input accepted expected fist"): return false
	while game.hands.action == &"punch" and game.hands._action_age < 0.035:
		if not _alive(): return false
		await game.frame_sampled
	return _check(game.hands.action == &"punch","transient attack remains available for actual draw")

func _web_roll() -> bool:
	var selected := Vector2.ZERO
	var forward3: Vector3 = -game.player.global_basis.z
	var direction := Vector2(forward3.x,forward3.z).normalized()
	# Existing wheels respond to longitudinal local velocity, not sidestepping.
	for angle: float in [0.0,PI]:
		var candidate: Vector2 = direction.rotated(angle)
		var body: Dictionary = game.runtime.p.duplicate(true)
		var goal: Vector2 = Vector2(body.x,body.y)+candidate*(1.7/0.04)
		var moved: Dictionary = game.physics.move_body(body,goal)
		if not moved.blocked and not moved.get("body_contact",false) and moved.position.distance_to(goal) < 0.005: selected = candidate; break
	if not _check(selected != Vector2.ZERO,"actual swept rolling corridor"): return false
	_web_roll_start = game.player.position; _web_roll_angle = game.cart_view._wheel_angle
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 250:
		if not _alive(): _release(); return false
		_motion(selected*0.65); await game.frame_sampled
	return _check(game.player.position.distance_to(_web_roll_start) > 0.1 and not is_equal_approx(game.cart_view._wheel_angle,_web_roll_angle),"actual input rolls real cart wheels")

func _execute_hands_phase(index: int) -> bool:
	match index:
		0: return await _web_rest() and await _web_pitch(0.0)
		1: return await _web_attack(1)
		2,4,6,13: return await _web_rest()
		3: return await _web_attack(-1)
		5:
			var pile: Dictionary = _web_pile()
			if not _check(not pile.is_empty() and not pile.get("collected",false),"original intro pile not injected/collected"): return false
			var count: int = _web_event_count("gesture","pickup")
			if not await _walk_to(Content.to_world(Vector2(pile.x,pile.y),game.player.position.y),"cash:"+CASH_ID): return false
			_release()
			if not _check(_web_pile().get("collected",false) and _web_event_count("gesture","pickup") == count+1 and game.hands.action == &"pickup","ordinary walking committed one pickup"): return false
			while game.hands.action == &"pickup" and game.hands._action_age < 0.06:
				if not _alive(): return false
				await game.frame_sampled
			return _check(game.hands.action == &"pickup" and game.hands._action_age >= 0.04 and game.hands._action_age < 0.32,"pickup reached a rendered motion frame")
		7:
			var record: Dictionary = game.runtime.s.travelRuntime.cart
			var target: Vector3 = game.physics.cart_approach(Vector2(record.x,record.y))
			if not _check(target.is_finite(),"live original cart has physical approach"): return false
			return await _walk_to(target,game.runtime.travel._cart_id) and await _web_rest()
		8:
			var selected: Dictionary = game.resolve_interaction()
			if not _check(selected.get("kind") == "cart" and selected.get("id") == game.runtime.travel._cart_id,"real E selects original cart"): return false
			_key(KEY_E)
			return _check(game.runtime.p.cartMounted,"source mount committed") and await _web_pitch(0.0) and await _web_rest()
		9: return await _web_pitch(-0.55) and await _web_rest()
		10: return await _web_roll()
		11:
			_release(); var wheel: float = game.cart_view._wheel_angle
			return await _web_rest() and _check(is_equal_approx(wheel,game.cart_view._wheel_angle),"stopped real cart does not rotate")
		12: return await _web_attack(1)
		14: return await _web_pitch(0.0) and await _web_rest()
		15:
			# NPC/site/bench/can/phone priority is source behavior. Look above those
			# targets using real input before requesting the mounted cart branch.
			if not await _web_pitch(1.05): return false
			if not _check(game.resolve_interaction().get("kind") == "cart","real upward look selects mounted cart"): return false
			_key(KEY_E)
			return _check(not game.runtime.p.cartMounted,"real E commits valid physical dismount") and await _web_pitch(0.0) and await _web_rest()
	return _check(false,"unknown Web phase")

func _web_cache_meshes(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var vertices := PackedVector3Array()
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_VERTEX] != null: vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
		_web_mesh_cache.append({"node":node,"vertices":vertices})
	for child: Node in node.get_children(): _web_cache_meshes(child)

static func projection_visible(point: Vector2, rectangle: Rect2, behind: bool) -> bool:
	return not behind and point.is_finite() and rectangle.position.is_finite() and rectangle.size.is_finite() and rectangle.size.x > 0.0 and rectangle.size.y > 0.0 and rectangle.has_point(point)

func _web_envelope() -> Dictionary:
	var result := {"vertices":0,"on_screen":0,"finite":true,"nearest_z":-INF,"farthest_z":INF}
	# Camera projection is in logical viewport coordinates; PNG/window pixels may differ.
	var rectangle: Rect2 = game.camera.get_viewport().get_visible_rect()
	result.projection_rect = [rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y]
	for entry: Dictionary in _web_mesh_cache:
		var mesh: MeshInstance3D = entry.node
		if not mesh.is_visible_in_tree(): continue
		for vertex: Vector3 in entry.vertices:
			var global: Vector3 = mesh.to_global(vertex); var local: Vector3 = game.camera.to_local(global)
			result.vertices += 1; result.finite = result.finite and local.is_finite()
			result.nearest_z = maxf(result.nearest_z,local.z); result.farthest_z = minf(result.farthest_z,local.z)
			if projection_visible(game.camera.unproject_position(global),rectangle,game.camera.is_position_behind(global)): result.on_screen += 1
	return result

func _web_cart() -> Dictionary:
	var targets: Dictionary = game.cart_view.grip_context(game.camera.global_transform,game.camera.fov,float(_web_size.x)/_web_size.y)
	var errors: Dictionary = {}
	for side: int in [-1,1]:
		var key: String = "left" if side < 0 else "right"
		if not targets.has(key): continue
		var wrist: Node3D = game.hands._arms[side].wrist
		var actual: Vector3 = game.camera.to_local(wrist.to_global(Vector3(0,-0.036,-0.082)))
		errors[key] = actual.distance_to(targets[key])
	return {"mounted":game.runtime.p.cartMounted,"layer":game.cart_view.parked_body().collision_layer,"clear":game.cart_view.presentation_clear,"offset":game.cart_view.presentation_offset,"targets":targets.keys(),"grip_error":errors,"wheel_angle":game.cart_view._wheel_angle,"record":game.runtime.s.travelRuntime.cart.duplicate(true)}

func _web_capture(index: int) -> bool:
	# No extra process step: capture the next actual draw of the observed live pose.
	await RenderingServer.frame_post_draw
	if not _alive(): return false
	var frame: Image = root.get_texture().get_image()
	var row := {"index":index,"label":PHASES[index],"framebuffer":[frame.get_width(),frame.get_height()],"mode":game.runtime.s.mode,"hands_visible":game.hands.is_visible_in_tree(),"action":str(game.hands.action),"age":game.hands._action_age,"side":game.hands.last_punch_side,"attack_weapon":str(game.hands.attack_weapon),"envelope":_web_envelope(),"cart":_web_cart(),"cash_collected":_web_pile().get("collected",false),"source":[game.runtime.p.x,game.runtime.p.y],"pitch":game.pitch,"summary":_summary(),"active_ms":game.admitted_ms,"wall_ms":Time.get_ticks_msec(),"mouse_captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED}
	row.camera_near = game.camera.near
	if index == 10: row.roll = {"metres":game.player.position.distance_to(_web_roll_start),"wheel_before":_web_roll_angle,"wheel_after":game.cart_view._wheel_angle}
	row.events = (game as WebHandsScene).hand_events.slice(_web_last_event).duplicate(true)
	_web_last_event = (game as WebHandsScene).hand_events.size()
	row.errors = frame_errors(row); row.pass = row.errors.is_empty()
	for error: String in row.errors: _check(false,PHASES[index]+": "+error)
	var bytes: PackedByteArray = frame.save_png_to_buffer()
	if not _check(not bytes.is_empty() and bytes.size() <= 6291456,"bounded actual PNG readback"): return false
	var hashing := HashingContext.new(); hashing.start(HashingContext.HASH_SHA256); hashing.update(bytes)
	row.png_sha256 = hashing.finish().hex_encode(); row.png_bytes = bytes.size()
	_web_records.append(row)
	JavaScriptBridge.eval("window.rbHandsFrame(%d,%s,%s,%s)" % [index,JSON.stringify(PHASES[index]),JSON.stringify(Marshalls.raw_to_base64(bytes)),JSON.stringify(row)])
	return failures.is_empty()

func _web_control(args: Array) -> void:
	if args.size() != 2 or not args[0] is String or not (args[1] is int or args[1] is float): return
	if args[0] == "abort": _check(false,"operator aborted Web draft"); _web_stop(); return
	var index: float = float(args[1])
	if _web_busy or _web_finished or args[0] != "next" or not is_finite(index) or index != floorf(index) or index != _web_current+1 or index >= PHASES.size(): return
	_web_requests += 1
	if not _check(_web_requests <= MAX_REQUESTS,"bounded bridge requests"): _web_stop(); return
	_web_busy = true; _web_phase_started = Time.get_ticks_msec(); _web_phase_limit = 90000 if int(index) in [5,7] else 5000
	JavaScriptBridge.eval("window.rbHandsBusy(%d)" % int(index)); call_deferred("_web_step",int(index))

func _web_step(index: int) -> void:
	if index == 0:
		if not await _web_click_menu("wake up."): _web_stop(); return
		if not _check(game.runtime.s.mode == "playing","real title click started fresh"): _web_stop(); return
		game.start_audit(); began_wall = Time.get_ticks_msec(); last_frame_wall = began_wall
		_web_initial = _summary(); _web_initial.fixture = "none"; _web_cache_meshes(game.hands)
	else:
		if not _check(game.runtime.s.mode == "paused","previous capture used ordinary pause") or not await _web_click_menu("continue."): _web_stop(); return
		if not _check(game.runtime.s.mode == "playing","actual Continue resumed"): _web_stop(); return
	(game as WebHandsScene).phase_index = index
	if not await _execute_hands_phase(index) or not await _web_capture(index): _web_stop(); return
	_release(); _key(KEY_ESCAPE); await process_frame
	if not _check(game.runtime.s.mode == "paused" and game.hud.modal.visible,"real Escape paused after framebuffer copy"): _web_stop(); return
	_web_current = index; _web_busy = false
	if index == PHASES.size()-1: _web_finished = true
	_web_publish()

func _web_stop() -> void:
	_release(); _web_finished = true; _web_busy = false
	if game != null and game.runtime != null and game.runtime.s.mode == "playing": _key(KEY_ESCAPE)
	_web_publish()

func _web_publish() -> void:
	var observed := game as WebHandsScene
	_web_report = {"schema":1,"format":"rock-bottom-web-hands-draft","current":_web_current,"phases":PHASES,"ready":not _web_busy and not _web_finished,"finished":_web_finished,"input_frame_checks_pass":_web_records.size() == PHASES.size() and failures.is_empty(),"visual_acceptance":false,"failures":failures,"records":_web_records,"initial":_web_initial,"inputs":inputs,"walking":walking,"requests":_web_requests,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"web":OS.has_feature("web"),"hashes":_web_hashes,"size":[_web_size.x,_web_size.y],"scope":"Actual Web frame + synthetic normal input routing. Not trusted hardware input, pointer-lock, audio, weapon catalog, visual approval or frame-budget evidence."}
	if observed != null:
		_web_report.events = observed.hand_events; _web_report.samples = observed.hand_samples
		_web_report.replacements = observed.replacements; _web_report.overflow = observed.overflow
	if _web_records.size() == PHASES.size():
		_web_report.sequence_errors = sequence_errors(_web_report)
		_web_report.input_frame_checks_pass = _web_report.input_frame_checks_pass and _web_report.sequence_errors.is_empty()
	JavaScriptBridge.eval("window.rbHandsReport(%s)" % JSON.stringify(_web_report))

func _web_watchdog() -> void:
	while not _web_finished:
		await process_frame
		if not _alive(): _web_stop(); return

func _run() -> void:
	if not OS.has_feature("web") or "--qa-full" not in OS.get_cmdline_user_args():
		push_error("Web hand draft requires actual Web and --qa-full before FullScene construction."); quit(1); return
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--web-hands-size=960": _web_size = Vector2i(960,540)
	root.size = _web_size; Engine.max_fps = 60; _web_boot_started = Time.get_ticks_msec()
	_web_callback = JavaScriptBridge.create_callback(_web_control)
	var browser: JavaScriptObject = JavaScriptBridge.get_interface("window"); browser.rbHandsControl = _web_callback
	game = WebHandsScene.new(); root.add_child(game)
	for frame: int in range(12000):
		await process_frame
		if game.ready_for_play: break
		if Time.get_ticks_msec()-_web_boot_started >= COLD_MS: break
	if not _check(game.ready_for_play,"bounded real Web cold startup"): _web_stop(); return
	game.store.save_path = "user://rockbottom_3d_web_hands_qa.json"; game.store.storage_key = "rockbottom_3d_web_hands_qa"
	for path: String in ["res://scripts/full_scene.gd","res://scripts/first_person_rig.gd","res://scripts/cart_view.gd","res://tests/boss_acceptance_probe.gd","res://tests/web_hands_probe.gd","res://data/source_content.json"]:
		_web_hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	_web_busy = false; _web_publish(); call_deferred("_web_watchdog")
