extends SceneTree
## Real native input fight, never a direct-damage or simulated boss substitute.
const Content = preload("res://scripts/content_catalog.gd")
const Contact = preload("res://scripts/actor_contact.gd")
const COMBAT_MAX_REPLANS := 32
const COMBAT_REPLAN_MS := 500
const COMBAT_ROUTE_ATTEMPTS := 4

class ObservedScene:
	extends "res://scripts/full_scene.gd"
	signal frame_sampled
	var audit_enabled := false
	var admitted_ms := 0.0
	var trace: Array[Dictionary] = []
	var samples: Array[Dictionary] = []
	var player_epoch: Dictionary = {}
	var state_epoch: Dictionary = {}
	var replacements := 0
	var loop_start := -1.0
	var high_end := -1.0
	var crash_end := -1.0
	var last_sample := -1000.0
	func start_audit() -> void:
		audit_enabled = true; player_epoch = runtime.p; state_epoch = runtime.s
	func _process(delta: float) -> void:
		var active: bool = ready_for_play and runtime != null and runtime.s.mode == "playing" and not loading
		var was_high: float = float(runtime.p.rockedT) if runtime != null else 0.0
		var was_crash: float = float(runtime.p.crashT) if runtime != null else 0.0
		super._process(delta)
		if not audit_enabled: frame_sampled.emit(); return
		if active: admitted_ms += runtime.last_advanced_ms
		if not is_same(player_epoch,runtime.p) or not is_same(state_epoch,runtime.s):
			replacements += 1; player_epoch = runtime.p; state_epoch = runtime.s
		if loop_start >= 0:
			if was_high > 0 and runtime.p.rockedT <= 0 and high_end < 0: high_end = admitted_ms
			if high_end >= 0 and was_crash > 0 and runtime.p.crashT <= 0 and crash_end < 0: crash_end = admitted_ms
		if admitted_ms-last_sample >= 100.0 and samples.size() < 2400:
			last_sample = admitted_ms
			var tony: Dictionary = runtime.combat.actor("tony")
			samples.append({"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms,"mode":runtime.s.mode,"player_hp":runtime.p.hp,"player":[runtime.p.x,runtime.p.y],"high":runtime.p.rockedT,"crash":runtime.p.crashT,"attack_cd":runtime.p.attackCd,"tony_hp":tony.get("hp"),"phase":runtime.s.get("bossPhase",0),"actors":runtime.state.npcs.size()})
		frame_sampled.emit()
	func _consume_events() -> void:
		if audit_enabled and runtime != null:
			var observed: Array = runtime._outbox.duplicate()
			observed.append_array(runtime.state.events)
			for event: Dictionary in observed:
				if event.kind in ["actor_hit","player_attack","hurt","death","arrest","boss_started","boss_phase_changed","actor_spawned","actor_died","ending_requested","ending","dependency_missing","toast","feed"] and trace.size() < 2400:
					trace.append({"kind":event.kind,"payload":event.get("payload",{}).duplicate(true),"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms,"high":runtime.p.rockedT,"weapon":runtime.p.weapon})
		super._consume_events()

var game: ObservedScene
var output := ""
var diagnostic := false
var contract_mode := "source_earned"
var failures: Array[String] = []
var captures: Array[String] = []
var receipts: Array[Dictionary] = []
var attack_receipts: Array[Dictionary] = []
var inputs: Dictionary = {"motion_frames":0,"mouse_motion":0,"keys":0,"clicks":0,"capture_clicks":0}
var initial: Dictionary = {}
var fight: Dictionary = {"started":false,"won":false,"wall_ms":0.0,"active_ms":0.0,"phases":[],"adds":[],"damage":0,"high_hits":0,"accepted_attacks":0,"fists_only":true,"cooldowns_valid":true,"tony_dead":false,"globals_clear":false,"quest_done":false,"shoe_reward":false}
var loop: Dictionary = {"purchased":false,"spent":false,"smokes":0,"initial_high":0.0,"high_ms":-1.0,"crash_ms":-1.0,"ending_seen":false,"continued":false}
var began_wall := 0
var fight_wall := -1
var fight_active := -1.0
var fight_finished_wall := -1
var fight_finished_active := -1.0
var decision_wall := -1000
var motion := Vector2.ZERO
var initial_actor_ids: Array[String] = []
var last_frame_wall := 0
var walking: Array[Dictionary] = []
var failure_context: Dictionary = {}
var walking_goal := Vector3.INF
var last_requested_motion := Vector2.ZERO
var last_actual_input := Vector2.ZERO
var combat_plan: Dictionary = {}
var combat_context: Dictionary = {}
var combat_navigation: Array[Dictionary] = []
var combat_replans := 0
var combat_last_plan := -1000
var combat_endpoint_attempts := 0
var combat_occluded_decisions := 0

static func launch_error(arguments: PackedStringArray) -> String:
	return "" if "--qa-full" in arguments else "Tony acceptance requires --qa-full before FullScene creation"

static func melee_ring(origin: Vector2,target: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not origin.is_finite() or not target.is_finite(): return result
	var heading: float = (origin-target).angle()
	for radius: float in [44.0,30.0]:
		for step: int in range(12):
			result.append(target+Vector2.from_angle(heading+TAU*float(step)/12.0)*radius)
	result.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	return result

static func combat_attack_ready(distance: float,alignment: float,cooldown: float,stun: float,line_clear: bool) -> bool:
	return line_clear and is_finite(distance) and is_finite(alignment) and is_finite(cooldown) and is_finite(stun) and distance >= 0.0 and distance < 57.0 and alignment > 0.985 and cooldown <= 0.0 and stun <= 0.0

static func combat_replan_ready(now: int,last: int,count: int) -> bool:
	return count >= 0 and count < COMBAT_MAX_REPLANS and now-last >= COMBAT_REPLAN_MS

static func combat_route_reason(plan: Dictionary,target_id: String,target: Vector2,phase: int,revision: int,endpoint_clear: bool,segment_clear: bool) -> String:
	if plan.is_empty(): return "no_cached_route"
	if plan.get("target_id") != target_id: return "target_changed"
	if plan.get("phase") != phase: return "phase_changed"
	if plan.get("revision") != revision: return "collision_revision_changed"
	var captured: Vector2 = plan.get("target_center",Vector2.INF)
	if not captured.is_finite() or not target.is_finite() or captured.distance_to(target) > 24.0: return "target_drift"
	if not endpoint_clear: return "endpoint_no_longer_melee_clear"
	if not segment_clear: return "next_segment_blocked"
	return ""

static func encode_motion(desired: Vector2) -> Vector2:
	var length: float = minf(desired.length(),1.0)
	if length <= 0.000001: return Vector2.ZERO
	# Input.get_vector removes one circular deadzone, not a deadzone per axis.
	return desired.normalized()*(0.5+0.5*length)

static func interaction_matches(action: Dictionary,id: String) -> bool:
	if id == "smoke:block": return action.get("kind") == "smoke" and action.get("id") == "block"
	return id == "tony" and action.get("kind") == "vendor" and action.get("id") == "tony"

static func weapon_chain(rows: Array) -> Dictionary:
	var errors: Array[String] = []; var transitions: Array[Dictionary] = []; var weapons: Array[String] = []
	var expected := "fists"; var fists_only := true; var victory := false
	var previous_ms := -1.0; var previous_cd := 0.0; var accepted := 0
	var catalog: Dictionary = Content.load_content().catalogs.weapons
	for row: Dictionary in rows:
		if victory: break # Residual hostiles after the earned Tony reward are outside this fight.
		accepted += 1
		var before: String = str(row.get("before_weapon","")); var after: String = str(row.get("after_weapon",""))
		var attacks: Array[Dictionary] = []; var hits: Dictionary = {}; var deaths: Dictionary = {}
		var evidence: Array = row.get("events",[])
		for event: Dictionary in evidence:
			var payload: Dictionary = event.get("payload",{})
			if event.get("kind") == "player_attack": attacks.append(payload)
			elif event.get("kind") == "actor_hit" and float(payload.get("damage",0)) > 0: hits[str(payload.get("actor_id",""))] = true
		if attacks.size() != 1:
			errors.append("one accepted input event required per attack"); continue
		var used: String = str(attacks[0].get("used_weapon",""))
		if before != expected or used != before or not catalog.has(used): errors.append("unbacked pre-attack weapon or mismatched used_weapon")
		if used != "fists": fists_only = false
		if used not in weapons: weapons.append(used)
		var active: float = float(row.get("active_ms",NAN))
		var before_cd: float = float(row.get("before_cd",NAN))
		if not is_finite(active) or not is_finite(before_cd) or before_cd != 0.0 or (previous_ms >= 0 and active-previous_ms < previous_cd-0.1): errors.append("actual accepted weapon cooldown violated")
		previous_ms = active; previous_cd = float(catalog.get(used,{}).get("cd",INF))
		if float(row.get("after_cd",-1)) != previous_cd: errors.append("assigned source weapon cooldown differs")
		var current: String = before
		for evidence_index: int in range(evidence.size()):
			var event: Dictionary = evidence[evidence_index]
			var payload: Dictionary = event.get("payload",{})
			if event.get("kind") == "actor_died":
				var id: String = str(payload.get("actor_id",""))
				var pre: Dictionary = row.get("actors_before",{}).get(id,{})
				var post: Dictionary = row.get("actors_after",{}).get(id,{})
				var pre_hp: float = float(pre.get("hp",NAN)); var post_hp: float = float(post.get("hp",NAN))
				if not hits.has(id) or id not in attacks[0].get("hits",[]) or pre.get("dead",true) or not is_finite(pre_hp) or pre_hp <= 0 or not post.get("dead",false) or not is_finite(post_hp) or post_hp > 0:
					errors.append("reward death lacks actual live hit-to-death evidence"); continue
				deaths[id] = pre
			elif event.get("kind") == "toast":
				for reward: String in ["pipe","brick","baguette","shoe"]:
					var name_value: String = str(catalog[reward].n)
					if payload.get("text") != "+ "+name_value+"\n(equipped.)": continue
					var backing := ""
					if reward == "pipe" and current == "fists":
						for id: String in deaths:
							if deaths[id].get("ordinary_reward",false): backing = id; break
					elif reward == "brick" and deaths.get("lurch",{}).get("ordinary_reward",false): backing = "lurch"
					elif reward == "baguette" and deaths.get("paulie",{}).get("ordinary_reward",false): backing = "paulie"
					elif reward == "shoe" and deaths.has("tony") and row.get("boss_before",false) and not row.get("quest_before",true) and row.get("victory_after",false): backing = "tony"
					var feed_after := false
					for later: int in range(evidence_index+1,evidence.size()):
						if evidence[later].get("kind") == "feed" and evidence[later].get("payload",{}).get("text") == "picked up "+name_value+". things are escalating.": feed_after = true; break
					if backing.is_empty() or not feed_after:
						errors.append("unbacked source reward: "+reward); continue
					transitions.append({"from":current,"to":reward,"actor_id":backing,"active_ms":active,"wall_ms":row.get("wall_ms",-1)})
					current = reward
		if current != after: errors.append("post-attack weapon changed without source death/reward events")
		expected = current
		if row.get("victory_after",false):
			victory = deaths.has("tony") and current == "shoe"
			if not victory: errors.append("Tony victory requires the special death and shoe reward")
	if accepted == 0 or not victory: errors.append("complete accepted attack chain through Tony victory required")
	return {"ok":errors.is_empty(),"errors":errors,"fists_only":fists_only,"transitions":transitions,"weapons_used":weapons,"accepted_attacks":accepted,"victory":victory}

static func assess(report: Dictionary,mode: String = "") -> Array[String]:
	var errors: Array[String] = []
	var driver: Dictionary = report.get("driver",{})
	if driver.get("version") != 2 or driver.get("qa_full") != true: errors.append("version2 driver requires the exact --qa-full launch flag")
	var replans: float = float(driver.get("combat_replans",-1)); var attempts: float = float(driver.get("endpoint_route_attempts",-1))
	if not is_finite(replans) or not is_finite(attempts) or replans != floorf(replans) or attempts != floorf(attempts) or replans < 0 or replans > COMBAT_MAX_REPLANS or attempts < 0 or attempts > replans*COMBAT_ROUTE_ATTEMPTS: errors.append("combat driver exceeded its bounded route work")
	for row: Dictionary in report.get("attack_receipts",[]):
		var geometry: Dictionary = row.get("geometry",{})
		if str(geometry.get("target_id","")).is_empty() or not combat_attack_ready(float(geometry.get("distance",NAN)),float(geometry.get("alignment",NAN)),float(geometry.get("cooldown",NAN)),float(geometry.get("stun",NAN)),geometry.get("can_hit") == true): errors.append("accepted click lacks current clear melee/aim/cooldown evidence")
	var selected: String = mode if not mode.is_empty() else str(report.get("contract_mode","fists_only"))
	if selected not in ["source_earned","fists_only"]: errors.append("unknown weapon acceptance contract")
	var f: Dictionary = report.get("fight",{}); var l: Dictionary = report.get("loop",{})
	var fixture: Dictionary = report.get("fixture",{})
	if fixture.get("kind") != "fresh_cash_only" or fixture.get("cash_grant") != 25 or fixture.get("weapon") != "fists" or fixture.get("hp") != 100: errors.append("unapproved pre-fight fixture")
	var start: Dictionary = report.get("initial",{})
	var expected: Dictionary = {"cash":25,"hp":100,"max_hp":100,"weapon":"fists","rocks":0,"cred":0,"brain":70,"offenses":0,"rocks_smoked":0,"speed":2.2,"cart_mounted":false}
	for key: String in ["cash","hp","max_hp","weapon","rocks","cred","brain","offenses","rocks_smoked","speed","cart_mounted"]:
		if start.get(key) != expected[key]: errors.append("actual starting state differs from lawful fresh fixture: "+key)
	var equipment: Dictionary = start.get("equip",{})
	for slot: String in ["coat","hat","shoes","tool"]:
		if equipment.get(slot) != null: errors.append("pre-fight equipment bonus: "+slot)
	if not start.get("inventory",[]).is_empty(): errors.append("pre-fight inventory was granted")
	if report.get("costs",[]) != [10,5,5,5]: errors.append("source purchase/three-offense costs not proven")
	for key: String in ["started","won","tony_dead","globals_clear","quest_done","shoe_reward","cooldowns_valid"]:
		if f.get(key) != true: errors.append("fight invariant: "+key)
	if selected == "fists_only" and f.get("fists_only") != true: errors.append("fight invariant: fists_only")
	if selected == "source_earned" or report.has("attack_receipts"):
		var audit: Dictionary = weapon_chain(report.get("attack_receipts",[]))
		if not audit.ok: errors.append_array(audit.errors)
		if selected == "fists_only" and not audit.fists_only: errors.append("strict fists-only input chain rejected earned weapon")
	for key: String in ["wall_ms","active_ms"]:
		var elapsed: float = float(f.get(key,0))
		if not is_finite(elapsed) or elapsed <= 0 or elapsed >= 90000: errors.append("fight must finish strictly below90seconds: "+key)
	var adds: Array = f.get("adds",[])
	var valid_adds: bool = adds.size() == 2
	if valid_adds: valid_adds = adds[0] != adds[1] and str(adds[0]).begins_with("sherri_boss_") and str(adds[1]).begins_with("sherri_boss_")
	if f.get("phases",[]) != [1,2,3] or not valid_adds: errors.append("source phases and two distinct real adds not observed")
	if int(f.get("damage",0)) < 200 or int(f.get("high_hits",0)) < 1 or int(f.get("accepted_attacks",0)) < 1: errors.append("actual high-state input damage not proven")
	if not l.get("purchased",false) or not l.get("spent",false) or int(l.get("smokes",0)) != 1 or float(l.get("initial_high",0)) != 18000: errors.append("one real purchased rock must start the source high")
	var high_ms: float = float(l.get("high_ms",-1)); var crash_ms: float = float(l.get("crash_ms",-1))
	if not is_finite(high_ms) or not is_finite(crash_ms) or absf(high_ms-18000.0) > 100 or absf(crash_ms-8000.0) > 100: errors.append("same18s high and8s crash did not complete on admitted world time")
	if not l.get("ending_seen",false) or not l.get("continued",false): errors.append("source ending/continuation not observed")
	if int(report.get("deaths",0)) != 0 or int(report.get("arrests",0)) != 0 or int(report.get("epoch_replacements",0)) != 0: errors.append("death/arrest/state replacement invalidates competent-fight run")
	if not report.get("dependencies",[]).is_empty(): errors.append("unresolved live dependency")
	if report.get("canonical_roster_retained") != true: errors.append("canonical source roster was removed from the acceptance scene")
	var controls: Dictionary = report.get("inputs",{})
	for key: String in ["motion_frames","mouse_motion","keys","clicks","capture_clicks"]:
		if int(controls.get(key,0)) <= 0: errors.append("actual controller input missing: "+key)
	return errors

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> bool:
	if not ok and label not in failures: failures.append(label); push_error(label)
	return ok
func _alive() -> bool:
	return Time.get_ticks_msec()-began_wall < 180000 and failures.is_empty()
func _actor(id: String) -> Dictionary: return game.runtime.combat.actor(id)
func _center(body: Dictionary) -> Vector2: return Vector2(body.x+body.w*0.5,body.y+body.h*0.5)
func _summary() -> Dictionary:
	return {"cash":game.runtime.p.cash,"hp":game.runtime.p.hp,"max_hp":game.runtime.p.maxHp,"weapon":game.runtime.p.weapon,"equip":game.runtime.p.equip.duplicate(true),"inventory":game.runtime.p.inventory.duplicate(true),"speed":game.runtime.p.speed,"cart_mounted":game.runtime.p.cartMounted,"rocks":game.runtime.p.rocks,"cred":game.runtime.p.cred,"shakes":game.runtime.p.shakes,"brain":game.runtime.p.brain,"offenses":game.runtime.p.tonyOffenses,"rocks_smoked":game.runtime.p.lifetime.rocksSmoked,"rng":game.runtime.state.rng_seed,"actors":game.runtime.state.npcs.size()}
func _release() -> void:
	for action: String in ["forward","back","left","right","sprint"]: Input.action_release(action)
func _motion(world_vector: Vector2) -> void:
	_release()
	last_requested_motion = Vector2.ZERO; last_actual_input = Vector2.ZERO
	if world_vector.length_squared() < 0.000001: return
	var local: Vector3 = game.player.global_basis.inverse()*Vector3(world_vector.x,0,world_vector.y)
	var plane := Vector2(local.x,local.z).limit_length(1.0)
	var raw: Vector2 = encode_motion(plane)
	if absf(raw.x) > 0.000001: Input.action_press("right" if raw.x > 0 else "left",absf(raw.x))
	if absf(raw.y) > 0.000001: Input.action_press("back" if raw.y > 0 else "forward",absf(raw.y))
	last_requested_motion = plane; last_actual_input = Input.get_vector("left","right","forward","back")
	inputs.motion_frames += 1
func _aim(target: Vector3,dt: float) -> float:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and game.runtime.s.mode == "playing":
		# qa_mode keeps look released after menus. Use the actual native click-to-
		# capture branch, whose first click deliberately does not request an attack.
		var capture := InputEventMouseButton.new(); capture.button_index = MOUSE_BUTTON_LEFT; capture.pressed = true
		game._unhandled_input(capture); inputs.capture_clicks += 1
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return -1.0
	var to: Vector3 = target-game.camera.global_position
	var desired := Vector2(to.x,to.z)
	var forward3: Vector3 = -game.camera.global_basis.z
	var forward := Vector2(forward3.x,forward3.z)
	if desired.length_squared() < 0.000001: return 1.0
	var yaw: float = clampf(forward.angle_to(desired),-4.5*dt,4.5*dt)
	var pitch: float = clampf(atan2(to.y,desired.length()),-1.1,1.1)
	var pitch_step: float = clampf(pitch-game.pitch,-3.0*dt,3.0*dt)
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(yaw/0.0022,-pitch_step/0.0022)
	game._unhandled_input(event); inputs.mouse_motion += 1
	forward3 = -game.camera.global_basis.z
	return Vector2(forward3.x,forward3.z).normalized().dot(desired.normalized())
func _dt() -> float:
	var now: int = Time.get_ticks_msec()
	var delta: float = clampf(float(now-last_frame_wall)/1000.0,0.001,0.1)
	last_frame_wall = now; return delta
func _key(code: int) -> void:
	var event := InputEventKey.new(); event.pressed = true; event.physical_keycode = code
	game._unhandled_input(event); inputs.keys += 1
func _choose(prefix: String) -> bool:
	var index: int = 0
	for child: Node in game.hud.menu_box.get_children():
		if not child is Button: continue
		if child.text.begins_with(prefix):
			if not _check(not child.disabled,"normal source menu option enabled: "+prefix): return false
			_key(KEY_1+index); return true
		index += 1
	return _check(false,"normal source menu option present: "+prefix)
func _capture(label: String) -> void:
	await game.frame_sampled; await RenderingServer.frame_post_draw
	if _check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label): captures.append(label)
func _capture_failure() -> void:
	var nearby: Array[Dictionary] = []
	for peer: Dictionary in game.physics._contact_peers(game.runtime.p):
		if _center(peer).distance_to(game.runtime.state.player_center()) <= 200.0: nearby.append(peer.duplicate(true))
	failure_context = {"world_position":game.player.position,"source_center":game.runtime.state.player_center(),"mode":game.runtime.s.mode,"hp":game.runtime.p.hp,"nearby":nearby,"walks":walking.duplicate(true),"last_pre_fight_walking_goal":walking_goal,"combat":combat_context.duplicate(true),"combat_replans":combat_replans,"requested_motion":last_requested_motion,"actual_input":last_actual_input,"mouse_captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED}
	print("TONY PROBE FAILURE CONTEXT: ",JSON.stringify(failure_context))
	# Freeze only an already-failed scenario; unwind frame_sampled before readback.
	game.set_process(false)
	await process_frame; await RenderingServer.frame_post_draw
	if _check(root.get_texture().get_image().save_png(output.path_join("failure.png")) == OK,"failed scenario capture"): captures.append("failure")
func _shutdown(code: int) -> void:
	_release()
	if is_instance_valid(game): game.set_process(false); game.queue_free()
	await process_frame
	quit(code)
func _probe_body(point: Vector3) -> Dictionary:
	var half := Vector2(game.runtime.p.w,game.runtime.p.h)*0.5
	var origin: Vector2 = Content.to_source(point)-half
	return {"id":"player","x":origin.x,"y":origin.y,"w":game.runtime.p.w,"h":game.runtime.p.h}
func _static_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	var direct: PackedVector3Array = game.world.find_route(from,to)
	if not direct.is_empty() or game.world.is_clear_position(from) or not game.world.is_clear_position(to): return direct
	var body: Dictionary = _probe_body(from)
	if not game.physics._clear(body,Vector2(body.x,body.y),false): return direct
	var heading: float = atan2(to.z-from.z,to.x-from.x)
	for radius: float in [0.25,0.5,1.0]:
		for offset: float in [0.0,PI*0.25,-PI*0.25,PI*0.5,-PI*0.5,PI*0.75,-PI*0.75,PI]:
			var candidate: Vector3 = from+Vector3(cos(heading+offset)*radius,0,sin(heading+offset)*radius)
			if not game.world.is_clear_position(candidate): continue
			var destination: Dictionary = _probe_body(candidate); var goal := Vector2(destination.x,destination.y)
			var moved: Dictionary = game.physics.move_body(body,goal)
			if moved.blocked or moved.get("body_contact",false) or moved.position.distance_to(goal) >= 0.005: continue
			var tail: PackedVector3Array = game.world.find_route(candidate,to)
			if tail.size() < 2: continue
			var joined := PackedVector3Array([from]); joined.append_array(tail)
			if walking.size() < 128: walking.append({"wall_ms":Time.get_ticks_msec(),"reason":"actual_capsule_corner_link","from":from,"joined_at":candidate,"metres":radius})
			return joined
	return direct
func _resident_route(from: Vector3,to: Vector3) -> PackedVector3Array:
	var base: PackedVector3Array = _static_route(from,to)
	if base.size() < 2:
		if walking.size() < 128: walking.append({"wall_ms":Time.get_ticks_msec(),"reason":"static_route_unavailable","from":from,"to":to,"metrics":game.world.last_route_metrics.duplicate(true)})
		return base
	var peers: Array[Dictionary] = game.physics._contact_peers(game.runtime.p)
	var blockers: Array[String] = []
	for index: int in range(1,base.size()):
		var body: Dictionary = _probe_body(base[index-1])
		var origin := Vector2(body.x,body.y)
		var destination: Dictionary = _probe_body(base[index])
		for peer: Dictionary in peers:
			var one: Array[Dictionary] = [peer]
			if not Contact.first_hit(body,origin,Vector2(destination.x,destination.y)-origin,one).is_empty() and str(peer.id) not in blockers: blockers.append(str(peer.id))
	if blockers.is_empty(): return base
	var points: Array[Vector3] = [from,to]
	for point: Vector3 in base:
		if point not in points: points.append(point)
	var half := Vector2(game.runtime.p.w,game.runtime.p.h)*0.5
	for peer: Dictionary in peers:
		var center := Vector2(peer.x+peer.w*0.5,peer.y+peer.h*0.5)
		var at: Vector3 = Content.to_world(center,from.y)
		var nearby := false
		for index: int in range(1,base.size()):
			if Geometry3D.get_closest_point_to_segment(at,base[index-1],base[index]).distance_to(at) < 3.0: nearby = true; break
		if not nearby: continue
		var extent: Vector2 = half+Vector2(peer.w,peer.h)*0.5+Vector2(6,6)
		for sign_x: float in [-1,1]:
			for sign_y: float in [-1,1]:
				var candidate: Vector3 = Content.to_world(center+extent*Vector2(sign_x,sign_y),from.y)
				if candidate not in points: points.append(candidate)
		if points.size() > 80: return PackedVector3Array()
	var graph := AStar2D.new()
	for index: int in range(points.size()):
		var body: Dictionary = _probe_body(points[index]); var origin := Vector2(body.x,body.y)
		if game.physics._clear(body,origin,false) and game.physics._peer_clear(body,origin,peers): graph.add_point(index,Vector2(points[index].x,points[index].z))
	if not graph.has_point(0) or not graph.has_point(1): return PackedVector3Array()
	for a: int in range(points.size()):
		if not graph.has_point(a): continue
		var body: Dictionary = _probe_body(points[a])
		for b: int in range(a+1,points.size()):
			if not graph.has_point(b): continue
			var destination: Dictionary = _probe_body(points[b]); var goal := Vector2(destination.x,destination.y)
			# A detached query body never commits this candidate movement to the model.
			var moved: Dictionary = game.physics.move_body(body,goal)
			if not moved.blocked and not moved.get("body_contact",false) and moved.position.distance_to(goal) < 0.005: graph.connect_points(a,b)
	var result := PackedVector3Array()
	for index: int in graph.get_id_path(0,1): result.append(points[index])
	if walking.size() < 128: walking.append({"wall_ms":Time.get_ticks_msec(),"blockers":blockers,"graph_points":points.size(),"route_points":result.size()})
	return result
func _resident_ahead(point: Vector3) -> bool:
	var body: Dictionary = game.runtime.p
	var origin := Vector2(body.x,body.y)
	var goal: Vector2 = Content.to_source(point)-Vector2(body.w,body.h)*0.5
	var motion: Vector2 = (goal-origin).limit_length(75.0)
	return not Contact.first_hit(body,origin,motion,game.physics._contact_peers(body)).is_empty()
func _service_candidate(id: String) -> bool:
	if id.is_empty(): return false
	if id == "smoke:block": return game.runtime.memory._zone_contains("block",game.runtime.state.player_center()) and game.physics.can_use_zone("block")
	return game.physics.can_reach_target(id)
func _reach_service(id: String) -> bool:
	if not _service_candidate(id): return false
	_release()
	for frame: int in range(120):
		if not _alive() or game.runtime.s.mode != "playing" or not _service_candidate(id): return false
		_aim(game.world.service_points[id].target,_dt())
		if interaction_matches(game.resolve_interaction(),id): return true
		await game.frame_sampled
	return false
func _defend_exit() -> bool:
	var target: Dictionary = {}; var distance := 65.0
	for actor: Dictionary in game.runtime.state.npcs:
		if actor.get("dead",false) or not actor.get("hostile",false) or actor.id == "tony": continue
		var gap: float = _center(actor).distance_to(game.runtime.state.player_center())
		if gap < distance: target = actor; distance = gap
	if target.is_empty(): return false
	var started: int = Time.get_ticks_msec()
	while _alive() and game.runtime.s.mode == "playing" and Time.get_ticks_msec()-started < 10000:
		if target.get("dead",false) or _center(target).distance_to(game.runtime.state.player_center()) > 85.0:
			_release(); walking.append({"defended_against":target.id,"wall_ms":Time.get_ticks_msec()-started,"dead":target.get("dead",false)}); return true
		_combat_input(target); await game.frame_sampled
	_release()
	walking.append({"defended_against":target.id,"wall_ms":Time.get_ticks_msec()-started,"dead":target.get("dead",false),"result":"bounded_attempt_finished","actual_position":game.player.position})
	return true # Attempted motion must always be followed by a fresh route query.
func _walk_to(target: Vector3,service_id: String = "") -> bool:
	if await _reach_service(service_id): return true
	var route: PackedVector3Array = _resident_route(game.player.position,target)
	if route.is_empty() and await _defend_exit(): route = _resident_route(game.player.position,target)
	if not _check(not route.is_empty(),"real authored walking route exists"): return false
	var index := 0; var replans := 0; var last_check := -1000
	var waypoint_start: int = Time.get_ticks_msec(); var progressed_at: int = waypoint_start
	var last_position: Vector3 = game.player.position
	while index < route.size():
		if await _reach_service(service_id): _release(); return true
		var point: Vector3 = route[index]; var now: int = Time.get_ticks_msec()
		if Vector2(game.player.position.x-point.x,game.player.position.z-point.z).length() <= 0.085:
			index += 1; waypoint_start = now; progressed_at = now; last_position = game.player.position; continue
		if not _alive() or now-waypoint_start > 20000:
			_release(); return _check(false,"actual controller walking stalled at "+str(game.player.position)+" toward "+str(point))
		if game.runtime.s.mode != "playing": _release(); return _check(false,"unexpected modal during real approach: "+str(game.runtime.s.mode))
		if game.player.position.distance_to(last_position) > 0.025: last_position = game.player.position; progressed_at = now
		if now-last_check >= 250:
			last_check = now
			if _resident_ahead(point) or now-progressed_at >= 500:
				_release(); replans += 1
				if not _check(replans <= 32,"bounded live-resident approach replans"): return false
				route = _resident_route(game.player.position,target)
				if route.size() < 2 and await _defend_exit():
					if await _reach_service(service_id): return true
					route = _resident_route(game.player.position,target)
				if not _check(route.size() >= 2,"actual residents leave a swept detour without moving them"): return false
				index = 1; point = route[index]; progressed_at = now
		var delta: Vector2 = Vector2(point.x-game.player.position.x,point.z-game.player.position.z)
		walking_goal = point
		var aligned: float = _aim(Vector3(point.x,game.camera.global_position.y,point.z),_dt())
		_motion(delta.normalized()*minf(1.0,delta.length()/0.4) if aligned > 0.96 else Vector2.ZERO)
		await game.frame_sampled
	_release(); return true
func _open_target(id: String) -> bool:
	_release()
	var target: Vector3 = game.world.service_points[id].target
	for frame: int in range(180):
		if _aim(target,_dt()) > 0.995: break
		await game.frame_sampled
	if not _check(interaction_matches(game.resolve_interaction(),id),"actual resolver selects intended service "+id): return false
	_key(KEY_E)
	return _check(game.runtime.s.mode == "dialogue","real E opens "+id)
func _tony_option(prefix: String,cost: int) -> bool:
	if not await _open_target("tony"): return false
	var cash: int = game.runtime.p.cash
	if not _choose(prefix): return false
	var charged: int = cash-int(game.runtime.p.cash)
	receipts.append({"option":prefix,"cost":charged,"before_cash":cash,"after_cash":game.runtime.p.cash})
	return _check(charged == cost and game.runtime.s.mode == "playing","actual source transaction price "+prefix)
func _target(tony_only: bool = false) -> Dictionary:
	var tony: Dictionary = _actor("tony")
	var best: Dictionary = tony if not tony.is_empty() and not tony.get("dead",false) else {}
	var nearest: float = 42.0
	for actor: Dictionary in game.runtime.state.npcs:
		if actor.get("dead",false) or not actor.get("hostile",false) or actor.id == "tony": continue
		var distance: float = _center(actor).distance_to(game.runtime.state.player_center())
		if distance < nearest:
			best = actor; nearest = distance
	if tony_only and best.is_empty(): return tony
	return best
func _send_attack(geometry: Dictionary) -> void:
	var before: Dictionary = {}
	for actor: Dictionary in game.runtime.state.npcs:
		before[str(actor.id)] = {"hp":actor.get("hp",0),"dead":actor.get("dead",false),"ordinary_reward":not actor.get("essential",false) and not actor.get("kingdomGuard",false) and not actor.get("kingdomAdd",false) and not game.runtime.combat._special_death(actor)}
	var row := {"wall_ms":Time.get_ticks_msec(),"active_ms":game.admitted_ms,"before_weapon":game.runtime.p.weapon,"before_cd":game.runtime.p.attackCd,"boss_before":game.runtime.s.bossActive and game.runtime.s.bossKind == "tony","quest_before":game.runtime.s.quests.fallen_king.done,"actors_before":{},"actors_after":{}}
	row.geometry = geometry.duplicate(true)
	var event_start: int = game.trace.size()
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	game._unhandled_input(event); inputs.clicks += 1
	row.events = game.trace.slice(event_start).duplicate(true)
	var accepted := false
	for observed: Dictionary in row.events:
		if observed.kind == "player_attack": accepted = true
		if observed.kind not in ["actor_hit","actor_died"]: continue
		var id: String = str(observed.payload.get("actor_id","")); var actual: Dictionary = _actor(id)
		row.actors_before[id] = before.get(id,{}).duplicate(true)
		row.actors_after[id] = {"hp":actual.get("hp",1),"dead":actual.get("dead",false)}
	if not accepted: return
	row.after_weapon = game.runtime.p.weapon; row.after_cd = game.runtime.p.attackCd
	row.victory_after = _actor("tony").get("dead",false) and game.runtime.s.quests.fallen_king.done and not game.runtime.s.bossActive and game.runtime.s.bossKind == ""
	attack_receipts.append(row)
func _combat_segment(from: Vector3,to: Vector3) -> Dictionary:
	var body: Dictionary = _probe_body(from)
	var destination: Dictionary = _probe_body(to)
	var goal := Vector2(destination.x,destination.y)
	# A detached body performs the same sweep/contact query, never a model write.
	var moved: Dictionary = game.physics.move_body(body,goal)
	var reached: Vector2 = moved.get("position",Vector2.INF)
	var reason := ""
	if moved.get("blocked",true): reason = "static_sweep_blocked"
	elif moved.get("body_contact",false): reason = "live_peer_contact"
	elif not reached.is_finite() or reached.distance_to(goal) >= 0.005: reason = "sweep_endpoint_not_reached"
	return {"ok":reason.is_empty(),"reason":reason,"from":Content.to_source(from),"to":Content.to_source(to),"actual_end":reached+Vector2(body.w,body.h)*0.5}
func _combat_endpoint(point: Vector3,target: Dictionary,peers: Array[Dictionary]) -> bool:
	var center: Vector2 = Content.to_source(point)
	if center.distance_to(_center(target)) >= 57.0: return false
	var body: Dictionary = _probe_body(point); var origin := Vector2(body.x,body.y)
	return game.physics._clear(body,origin,false) and game.physics._peer_clear(body,origin,peers) and game.physics.can_hit(center,_center(target),"player",str(target.id))
func _combat_blocker(target: Dictionary) -> Dictionary:
	var hit: Dictionary = game.physics._ray(Content.to_world(game.runtime.state.player_center(),game.physics.FEET+game.physics._height("player")*0.6),Content.to_world(_center(target),game.physics.FEET+game.physics._height(str(target.id))*0.6))
	if hit.is_empty(): return {}
	var collider: Object = hit.get("collider")
	return {"owner":str(collider.get_meta("source_owner","")) if is_instance_valid(collider) else "","position":hit.get("position"),"normal":hit.get("normal")}
func _plan_combat_route(target: Dictionary,reason: String) -> bool:
	if not _check(combat_replans < COMBAT_MAX_REPLANS,"bounded combat replans remain below32"): return false
	combat_replans += 1; combat_last_plan = Time.get_ticks_msec(); combat_plan = {}
	var started: int = Time.get_ticks_msec()
	var origin: Vector3 = game.player.position
	var peers: Array[Dictionary] = game.physics._contact_peers(game.runtime.p)
	var attempts := 0; var certified := 0
	for center: Vector2 in melee_ring(game.runtime.state.player_center(),_center(target)):
		var point: Vector3 = Content.to_world(center,origin.y)
		if not _combat_endpoint(point,target,peers) or not game.world.is_clear_position(point): continue
		certified += 1; attempts += 1; combat_endpoint_attempts += 1
		var route: PackedVector3Array = _resident_route(origin,point)
		if route.size() >= 2:
			combat_plan = {"target_id":str(target.id),"target_center":_center(target),"phase":int(game.runtime.s.bossPhase),"revision":int(game.physics._collision_revision),"endpoint":point,"route":route,"index":1}
			combat_navigation.append({"wall_ms":started,"active_ms":game.admitted_ms,"reason":reason,"target_id":target.id,"target_center":_center(target),"from":Content.to_source(origin),"endpoint":center,"route":route,"attempts":attempts,"planner_ms":Time.get_ticks_msec()-started,"replan":combat_replans})
			return true
		if attempts >= COMBAT_ROUTE_ATTEMPTS: break
	combat_navigation.append({"wall_ms":started,"active_ms":game.admitted_ms,"reason":"route_unavailable","trigger":reason,"target_id":target.id,"target_center":_center(target),"from":Content.to_source(origin),"certified_endpoints":certified,"attempts":attempts,"planner_ms":Time.get_ticks_msec()-started,"replan":combat_replans,"retryable":combat_replans < COMBAT_MAX_REPLANS,"next_plan_ms":combat_last_plan+COMBAT_REPLAN_MS})
	# Live peers can close every current route without ending a lawful fight.
	# This spent plan stays counted; steering holds until the same bounded retry.
	combat_context.reason = "route_unavailable"
	combat_context.next_plan_ms = combat_last_plan+COMBAT_REPLAN_MS
	return false
func _combat_steering(target: Dictionary,now: int,line_clear: bool) -> Vector2:
	var center: Vector2 = game.runtime.state.player_center()
	var target_center: Vector2 = _center(target)
	var delta: Vector2 = target_center-center; var distance: float = delta.length()
	var toward: Vector2 = delta.normalized() if distance > 0.001 else Vector2.RIGHT
	var desired: Vector2 = toward*clampf((distance-45.0)/16.0,-1.0,1.0) if distance < 40.0 or distance > 50.0 else Vector2.ZERO
	var dodging: bool = line_clear and target.get("chargeState","") in ["windup","lunge"]
	if dodging:
		desired = (Vector2(-toward.y,toward.x)*0.75-toward*(0.35 if distance < 45.0 else 0.0)).limit_length(1.0)
	var goal: Vector2 = target_center-toward*44.0 if distance > 50.0 and not dodging else center+desired*20.0
	var direct: Dictionary = _combat_segment(game.player.position,Content.to_world(goal,game.player.position.y))
	combat_context = {"wall_ms":now,"active_ms":game.admitted_ms,"target_id":target.id,"target_center":target_center,"player_center":center,"distance":distance,"can_hit":line_clear,"phase":game.runtime.s.bossPhase,"revision":game.physics._collision_revision,"direct_segment":direct}
	if line_clear and (direct.ok or distance <= 50.0):
		if not combat_plan.is_empty():
			combat_navigation.append({"wall_ms":now,"active_ms":game.admitted_ms,"reason":"direct_melee_reacquired","target_id":target.id,"target_center":target_center,"from":center})
		combat_plan = {}
		combat_context.reason = "direct_melee" if direct.ok else "blocked_retreat_or_dodge"
		return desired if direct.ok else Vector2.ZERO
	if not line_clear:
		combat_occluded_decisions += 1
		combat_context.line_blocker = _combat_blocker(target)
	var peers: Array[Dictionary] = game.physics._contact_peers(game.runtime.p)
	var endpoint_clear := false; var next_clear := false
	var segment: Dictionary = {}
	if not combat_plan.is_empty():
		var route: PackedVector3Array = combat_plan.route
		while int(combat_plan.index) < route.size() and game.player.position.distance_to(route[int(combat_plan.index)]) <= 0.085:
			combat_plan.index += 1
		endpoint_clear = _combat_endpoint(combat_plan.endpoint,target,peers)
		if int(combat_plan.index) < route.size():
			segment = _combat_segment(game.player.position,route[int(combat_plan.index)])
			next_clear = segment.ok
	var reason: String = combat_route_reason(combat_plan,str(target.id),target_center,int(game.runtime.s.bossPhase),int(game.physics._collision_revision),endpoint_clear,next_clear)
	if not reason.is_empty():
		combat_context.reason = reason; combat_context.current_segment = segment
		combat_plan = {} # Never follow an invalidated route while awaiting a retry.
		if not _check(combat_replans < COMBAT_MAX_REPLANS,"bounded combat replans remain below32"): return Vector2.ZERO
		if not combat_replan_ready(now,combat_last_plan,combat_replans):
			combat_context.reason = "waiting_for_replan_budget"
			combat_context.waiting_for_replan_budget = true
			combat_context.next_plan_ms = combat_last_plan+COMBAT_REPLAN_MS
			return Vector2.ZERO
		if not _plan_combat_route(target,reason):
			combat_context.waiting_for_replan_budget = true
			_check(combat_replans < COMBAT_MAX_REPLANS,"bounded combat replans remain below32")
			return Vector2.ZERO
	var points: PackedVector3Array = combat_plan.route
	var point: Vector3 = points[int(combat_plan.index)]
	segment = _combat_segment(game.player.position,point)
	combat_context.reason = "following_melee_route"; combat_context.endpoint = Content.to_source(combat_plan.endpoint)
	combat_context.current_segment = segment; combat_context.route_index = combat_plan.index
	if not segment.ok: combat_context.reason = "new_route_segment_blocked"; return Vector2.ZERO
	var direction := Vector2(point.x-game.player.position.x,point.z-game.player.position.z)
	return direction.normalized()*minf(1.0,direction.length()/0.4)
func _combat_route_motion() -> Vector2:
	# Steering converges each render frame; only costly route decisions use100ms.
	# Otherwise high-speed movement can overshoot a short corner between decisions.
	var route: PackedVector3Array = combat_plan.route
	while int(combat_plan.index) < route.size() and game.player.position.distance_to(route[int(combat_plan.index)]) <= 0.085:
		combat_plan.index += 1
	if int(combat_plan.index) >= route.size(): return Vector2.ZERO
	var point: Vector3 = route[int(combat_plan.index)]
	combat_context.current_input_segment = {"from":Content.to_source(game.player.position),"to":Content.to_source(point)}
	var direction := Vector2(point.x-game.player.position.x,point.z-game.player.position.z)
	return direction.normalized()*minf(1.0,direction.length()/0.4)
func _combat_input(preferred: Dictionary = {}) -> void:
	var target: Dictionary = preferred if not preferred.is_empty() else _target()
	if target.is_empty(): _release(); return
	var delta: Vector2 = _center(target)-game.runtime.state.player_center()
	var distance: float = delta.length()
	var aligned: float = _aim(Content.to_world(_center(target),1.35),_dt())
	var now: int = Time.get_ticks_msec()
	var line_clear: bool = game.physics.can_hit(game.runtime.state.player_center(),_center(target),"player",str(target.id))
	if now-decision_wall >= 100:
		decision_wall = now
		motion = _combat_steering(target,now,line_clear)
	if not combat_plan.is_empty() and combat_plan.target_id == str(target.id) and combat_context.get("reason") == "following_melee_route": motion = _combat_route_motion()
	_motion(motion)
	if failures.is_empty() and combat_attack_ready(distance,aligned,float(game.runtime.p.attackCd),float(game.runtime.p.stunT),line_clear):
		_send_attack({"target_id":target.id,"target_center":_center(target),"player_center":game.runtime.state.player_center(),"distance":distance,"alignment":aligned,"cooldown":game.runtime.p.attackCd,"stun":game.runtime.p.stunT,"can_hit":line_clear})
func _fight() -> bool:
	fight.started = game.runtime.s.bossActive and game.runtime.s.bossKind == "tony"
	if not _check(fight.started and _actor("tony").hp == 200 and game.runtime.p.tonyOffenses == 3,"actual third-short callback starts canonical200HP Tony"): return false
	fight_wall = Time.get_ticks_msec(); fight_active = game.admitted_ms
	for event: Dictionary in game.trace:
		if event.kind == "boss_started" and event.payload.get("actor_id") == "tony": fight_wall = event.wall_ms; fight_active = event.active_ms
	fight.phases = [1]
	await _capture("04_fight_coat_one")
	var captured: Dictionary = {1:true}
	while game.runtime.s.bossActive and _alive() and Time.get_ticks_msec()-fight_wall < 90000:
		if game.runtime.s.mode != "playing": return _check(false,"unexpected mode during actual fight: "+str(game.runtime.s.mode))
		var phase: int = game.runtime.s.bossPhase
		if phase > 0 and phase not in fight.phases: fight.phases.append(phase)
		for actor: Dictionary in game.runtime.state.npcs:
			if str(actor.id).begins_with("sherri_boss_") and actor.id not in fight.adds: fight.adds.append(actor.id)
		if phase in [2,3] and not captured.has(phase): captured[phase] = true; await _capture("05_fight_coat_%d" % phase)
		_combat_input()
		await game.frame_sampled
	_release(); fight_finished_wall = Time.get_ticks_msec(); fight_finished_active = game.admitted_ms
	fight.wall_ms = float(fight_finished_wall-fight_wall); fight.active_ms = fight_finished_active-fight_active
	var tony: Dictionary = _actor("tony")
	fight.tony_dead = not tony.is_empty() and tony.get("dead",false) and float(tony.hp) <= 0
	fight.globals_clear = not game.runtime.s.bossActive and game.runtime.s.bossKind == ""
	fight.quest_done = game.runtime.s.quests.fallen_king.done
	fight.shoe_reward = game.runtime.p.weapon == "shoe"
	fight.won = fight.tony_dead and fight.globals_clear and fight.quest_done
	if not _check(fight.won,"actual input fight ends in Tony defeat, not respawn/abort"): return false
	await _capture("06_actual_victory")
	return true
func _scenario() -> bool:
	game._new_game(); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Sole approved fixture write. No other player/actor/gameplay state is authored.
	game.runtime.p.cash = 25
	initial = _summary(); game.start_audit()
	for actor: Dictionary in game.runtime.state.npcs: initial_actor_ids.append(actor.id)
	if not await _walk_to(game.world.service_points.tony.approach,"tony"): return false
	if not await _tony_option("buy a rock",10): return false
	loop.purchased = game.runtime.p.rocks == 1
	if not await _tony_option("short him",5) or not await _tony_option("short him",5): return false
	await _capture("01_two_source_offenses")
	if not await _walk_to(game.world.service_points["smoke:block"].approach,"smoke:block"): return false
	if not await _open_target("smoke:block"): return false
	var smoked: int = game.runtime.p.lifetime.rocksSmoked
	if not _choose("smoke a rock. (-1 rock"): return false
	loop.spent = game.runtime.p.rocks == 0; loop.smokes = game.runtime.p.lifetime.rocksSmoked-smoked
	loop.initial_high = game.runtime.p.rockedT; game.loop_start = game.admitted_ms
	await _capture("02_real_rock_smoked")
	if not await _walk_to(game.world.service_points.tony.approach,"tony"): return false
	await _capture("03_corner_approach_high")
	if not await _tony_option("short him",5): return false
	if not await _fight(): return false
	var victory_wall: int = Time.get_ticks_msec()
	while game.runtime.s.mode != "ending" and Time.get_ticks_msec()-victory_wall < 7000 and _alive():
		# Residual source adds remain real threats during the source four-second delay.
		_combat_input(); await game.frame_sampled
	_release(); loop.ending_seen = game.runtime.s.mode == "ending"
	if not _check(loop.ending_seen,"source delayed Tony ending appears"): return false
	await _capture("07_source_ending")
	for frame: int in range(300):
		if not game.saving and game.pending_save.is_empty(): break
		await game.frame_sampled
	_key(KEY_SPACE)
	loop.continued = game.runtime.s.mode == "playing" and not game.runtime.s.endingContinue and game.runtime.s.quests.fallen_king.done
	if not _check(loop.continued,"actual ending input preserves earned progress"): return false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not await _walk_to(game.world.service_points["smoke:block"].approach,"smoke:block"): return false
	var crash_captured := false
	while game.crash_end < 0 and _alive():
		if game.high_end >= 0 and not crash_captured:
			crash_captured = true; await _capture("08_same_rock_crash")
		_combat_input(); await game.frame_sampled
	_release()
	loop.high_ms = game.high_end-game.loop_start if game.high_end >= 0 else -1.0
	loop.crash_ms = game.crash_end-game.high_end if game.crash_end >= 0 and game.high_end >= 0 else -1.0
	await _capture("09_same_loop_complete")
	return true
func _report() -> Dictionary:
	var deaths := 0; var arrests := 0; var dependencies: Array[String] = []; var last_attack := -1.0; var last_cooldown := 0.0
	for event: Dictionary in game.trace:
		if event.kind == "death": deaths += 1
		if event.kind == "arrest": arrests += 1
		if event.kind == "dependency_missing": dependencies.append(JSON.stringify(event.payload))
		if event.kind == "actor_hit" and event.payload.get("actor_id") == "tony" and fight_wall >= 0 and event.wall_ms >= fight_wall and event.wall_ms <= fight_finished_wall:
			fight.damage += int(event.payload.get("damage",0))
			if event.high > 0: fight.high_hits += 1
		if event.kind == "player_attack" and fight_wall >= 0 and event.wall_ms >= fight_wall and event.wall_ms <= fight_finished_wall:
			fight.accepted_attacks += 1
			if event.payload.get("used_weapon") != "fists": fight.fists_only = false
			if last_attack >= 0 and event.active_ms-last_attack < last_cooldown-0.1: fight.cooldowns_valid = false
			last_attack = event.active_ms
			last_cooldown = float(Content.load_content().catalogs.weapons.get(str(event.payload.get("used_weapon","")),{}).get("cd",INF))
	var costs: Array[int] = []
	for receipt: Dictionary in receipts: costs.append(int(receipt.cost))
	var retained: bool = true
	for id: String in initial_actor_ids:
		if _actor(id).is_empty(): retained = false
	return {"schema":1,"format":"rock-bottom-boss-acceptance","contract_mode":contract_mode,"claim":"initial fists and normal HP; only verified source-earned weapon transitions" if contract_mode == "source_earned" else "strict fists-only accepted attacks through Tony defeat","fixture":{"kind":"fresh_cash_only","cash_grant":25,"weapon":initial.get("weapon"),"hp":initial.get("hp"),"note":"$25 is a labeled normal-resource pre-fight fixture; no claim of earning it in this run. No other state edits, retry, teleports or injected damage."},"initial":initial,"final":_summary(),"fight":fight,"loop":loop,"costs":costs,"transactions":receipts,"inputs":inputs,"deaths":deaths,"arrests":arrests,"epoch_replacements":game.replacements,"dependencies":dependencies,"canonical_roster_retained":retained,"initial_actor_ids":initial_actor_ids,"events":game.trace,"attack_receipts":attack_receipts,"weapon_audit":weapon_chain(attack_receipts),"samples":game.samples,"captures":captures,"walking":walking,"driver":{"version":2,"qa_full":launch_error(OS.get_cmdline_user_args()).is_empty(),"combat_replans":combat_replans,"endpoint_route_attempts":combat_endpoint_attempts,"occluded_decisions":combat_occluded_decisions},"combat_navigation":combat_navigation,"combat_context":combat_context,"failure_context":failure_context,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"scope":"actual native Tony fight from fresh fists/HP, verified source rewards, real purchase/offenses/smoke/input/physics and same18s/8s loop; not full campaign/Web/performance acceptance"}
func _run() -> void:
	var launch_failure: String = launch_error(OS.get_cmdline_user_args())
	if not launch_failure.is_empty():
		push_error(launch_failure); print("3D TONY FIGHT ACCEPTANCE: FAIL; missing_qa_full"); quit(1); return
	if DisplayServer.get_name() == "headless": push_error("Tony acceptance requires a native renderer"); quit(1); return
	output = ProjectSettings.globalize_path("res://../.build/full-port/boss-acceptance/tony")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument == "--diagnostic": diagnostic = true
		elif argument == "--fists-only": contract_mode = "fists_only"
	DirAccess.make_dir_recursive_absolute(output); root.size = Vector2i(1280,720); Engine.max_fps = 60
	game = ObservedScene.new(); game.qa_mode = true; root.add_child(game)
	for frame: int in range(900):
		await process_frame
		if game.ready_for_play: break
	if not _check(game.ready_for_play,"native FullScene reached title"):
		var boot_file := FileAccess.open(output.path_join("tony-fight.json"),FileAccess.WRITE)
		if boot_file != null:
			boot_file.store_string(JSON.stringify({"schema":1,"format":"rock-bottom-boss-acceptance","acceptance":false,"failures":failures,"stage":"cold_start","diagnostic":diagnostic},"  ")); boot_file.close()
		print("3D TONY FIGHT ACCEPTANCE: FAIL; cold_start; ",output)
		await _shutdown(0 if diagnostic else 1); return
	game.store.save_path = ProjectSettings.globalize_path("res://../.build/3d/boss-acceptance-native-qa.json")
	game.store.storage_key = "rockbottom_3d_tony_acceptance_qa"
	began_wall = Time.get_ticks_msec(); last_frame_wall = began_wall
	await _scenario()
	_release()
	var report: Dictionary = _report()
	report.assessments = {}
	for mode: String in ["source_earned","fists_only"]:
		var reasons: Array[String] = assess(report,mode)
		report.assessments[mode] = {"acceptance":reasons.is_empty(),"failures":reasons}
	for error: String in assess(report): _check(false,error)
	if not failures.is_empty():
		await _capture_failure()
		report.failure_context = failure_context; report.captures = captures
	report.acceptance = failures.is_empty(); report.failures = failures; report.diagnostic = diagnostic
	var file := FileAccess.open(output.path_join("tony-fight.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
	else: _check(false,"native fight report available")
	print("3D TONY FIGHT ACCEPTANCE: ","PASS" if failures.is_empty() else "FAIL","; wall_ms=",fight.wall_ms," active_ms=",fight.active_ms,"; ",output)
	await _shutdown(0 if failures.is_empty() or diagnostic else 1)
