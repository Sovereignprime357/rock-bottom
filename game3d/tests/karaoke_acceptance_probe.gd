extends "res://tests/boss_acceptance_probe.gd"
## Native rendered input evidence; reuse certified walking, never the Boss scenario.
const Driver = preload("res://tests/boss_acceptance_probe.gd")
const State = preload("res://scripts/game_state.gd")
const ARROWS := ["↑","↓","←","→"]
const RESULT := "· 8/8 hits ·\n+ $24 · + 4 cred\nthe crowd was three people.\ntwo of them were waiting for the bus."
const NEWS := "KARAOKE PERFECTION REPORTED. WITNESSES UNAVAILABLE."

class KaraokeScene:
	extends Driver.ObservedScene
	var karaoke_events: Array[Dictionary] = []
	var event_overflow := false
	func _consume_events() -> void:
		if audit_enabled and runtime != null:
			var events: Array = runtime._outbox.duplicate(); events.append_array(runtime.state.events)
			for event: Dictionary in events:
				if event.kind not in ["activity_started","activity_completed","toast","news","quest_completed","save_requested","achievement","death","arrest","boss_started","dependency_missing","player_attack"]: continue
				if karaoke_events.size() >= 512: event_overflow = true; break
				karaoke_events.append({"kind":event.kind,"payload":event.get("payload",{}).duplicate(true),"wall_ms":Time.get_ticks_msec(),"active_ms":admitted_ms})
		super._consume_events()

var proof: Dictionary = {"schema":1,"format":"rock-bottom-karaoke-acceptance","acceptance":false,"fixture_before":{},"fixture_after":{},"entry":{},"notes":[],"dwell":{},"durable":{},"movement":{},"final":{}}

static func karaoke_errors(report: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var before: Dictionary = report.get("fixture_before",{}); var after: Dictionary = report.get("fixture_after",{})
	if before.is_empty() or after.is_empty(): errors.append("missing sole cash fixture")
	else:
		var expected: Dictionary = before.duplicate(true); expected.player.cash = 5
		if expected != after: errors.append("fixture changed more than cash")
		var source: Dictionary = State.new().p
		for key: String in ["cash","hp","maxHp","brain","shakes","speed","cred","weapon","equip","rocks","rockedT","crashT"]:
			if before.player.get(key) != source.get(key): errors.append("fixture does not begin at fresh source "+key)
		if before.state.get("flags",{}).get("introDone",false) or before.state.get("quests",{}).get("intro_remember",{}).get("done",false): errors.append("fixture injected intro progress")
	var entry: Dictionary = report.get("entry",{})
	if entry.get("resolved",{}) != {"kind":"street","id":"karaoke"}: errors.append("missing real Karaoke resolver")
	var distance: float = float(entry.get("distance",NAN))
	if not is_finite(distance) or distance < 0 or distance >= 60 or entry.get("reachable") != true or entry.get("alive") != true: errors.append("invalid living physical entry")
	if entry.get("before",{}).get("cash") != 5 or entry.get("after",{}).get("cash") != 0: errors.append("entry did not spend exactly five")
	var seed: int = int(entry.get("rng_before",-1))
	for index: int in range(8): seed = (seed*1664525+1013904223)&0xffffffff
	if entry.get("rng_after") != seed: errors.append("entry did not generate exactly eight source notes")
	var notes: Array = report.get("notes",[]); var history: Array[String] = []
	if notes.size() != 8: errors.append("exactly eight UI choices required")
	for index: int in range(notes.size()):
		var row: Dictionary = notes[index]; var menu: Dictionary = row.get("menu",{})
		var choices: Array = menu.get("choices",[]); var chosen: int = int(row.get("index",-1))
		if choices.size() != 5 or chosen < 0 or chosen > 3: errors.append("invalid offered note choice"); continue
		if menu.get("title") != "· %d / 8 ·" % (index+1) or menu.get("body") != "next: "+ARROWS[chosen]+"\n\nyour line:\n"+" ".join(history): errors.append("rendered note/history mismatch")
		for option: int in range(4):
			if choices[option].get("label") != ARROWS[option]+(" (now!)" if option == chosen else " ") or choices[option].get("enabled") != true: errors.append("rendered arrow choice mismatch")
		if choices[4].get("label") != "forfeit. (you sound tired)": errors.append("forfeit choice missing")
		if row.get("key") != KEY_1+chosen or row.get("rendered") != true or row.get("released") != true: errors.append("note lacks rendered press/release")
		if row.get("before",{}).get("cash") != 0 or row.get("before",{}).get("cred") != 0: errors.append("reward before final note")
		if index < 7 and (row.get("after",{}).get("cash") != 0 or row.get("after",{}).get("cred") != 0): errors.append("early note reward")
		if index == 7 and (row.get("after",{}).get("cash") != 24 or row.get("after",{}).get("cred") != 5): errors.append("last real input did not commit the reward")
		history.append(ARROWS[chosen])
	var dwell: Dictionary = report.get("dwell",{})
	var dwell_ms: float = float(dwell.get("wall_ms",NAN))
	if not is_finite(dwell_ms) or dwell_ms < 500 or not is_finite(float(dwell.get("active_before",NAN))) or dwell.get("before") != dwell.get("after") or dwell.get("active_before") != dwell.get("active_after"): errors.append("untimed dialogue dwell changed note/resources/world clock")
	var final: Dictionary = report.get("final",{})
	if final.get("cash") != 24 or final.get("cred") != 5 or final.get("achievement") != true or final.get("intro_remember") != true or final.get("intro_tony") != true or final.get("mode") != "playing" or final.get("modal") != false or final.get("activity") != false: errors.append("source perfect result plus intro handoff missing")
	var starts := 0; var completions := 0; var result_count := 0; var news_count := 0; var quests := 0; var achievements := 0
	var result_index := -1; var achievement_index := -1; var news_index := -1; var completion_index := -1; var quest_index := -1
	var events: Array = report.get("events",[])
	for index: int in range(events.size()):
		var event: Dictionary = events[index]; var data: Dictionary = event.get("payload",{})
		match event.get("kind"):
			"activity_started":
				if data.get("id") == "karaoke": starts += 1
			"activity_completed":
				if data.get("id") == "karaoke" and data.get("hits") == 8: completions += 1; completion_index = index
			"toast":
				if data.get("text") == RESULT: result_count += 1; result_index = index
			"news":
				if data.get("text") == NEWS: news_count += 1; news_index = index
			"achievement":
				if data.get("id") == "not_a_phase": achievements += 1; achievement_index = index
			"quest_completed":
				if data.get("id") == "intro_remember": quests += 1; quest_index = index
			"death","arrest","boss_started","dependency_missing","player_attack": errors.append("unexpected lifecycle/combat event")
	if starts != 1 or completions != 1 or result_count != 1 or news_count != 1 or quests != 1 or achievements != 1 or result_index < 0 or achievement_index <= result_index or news_index <= achievement_index or completion_index <= news_index or quest_index <= completion_index: errors.append("single ordered completion receipts missing")
	var durable: Dictionary = report.get("durable",{})
	if durable.get("schema") != 2 or durable.get("cash") != 24 or durable.get("cred") != 5 or durable.get("achievement") != true or durable.get("intro_remember") != true: errors.append("reward not durably saved")
	var movement: Dictionary = report.get("movement",{}); var metres: float = float(movement.get("metres",NAN))
	if not is_finite(metres) or metres <= 0.10 or movement.get("inputs",0) <= 0 or movement.get("cash") != 24 or movement.get("cred") != 5: errors.append("ordinary movement did not resume without another reward")
	for key: String in ["motion_frames","mouse_motion","keys","capture_clicks"]:
		if report.get("inputs",{}).get(key,0) <= 0: errors.append("missing actual input "+key)
	if report.get("replacements",1) != 0 or report.get("overflow",true): errors.append("epoch replacement or evidence overflow")
	var elapsed: float = float(report.get("wall_ms",NAN))
	if not is_finite(elapsed) or elapsed < 0 or elapsed >= 120000: errors.append("whole scenario watchdog")
	if report.get("captures",[]).size() < 11: errors.append("rendered page/receipt/movement captures missing")
	return errors

func _summary() -> Dictionary:
	var p: Dictionary = game.runtime.p; var s: Dictionary = game.runtime.s
	return {"cash":p.cash,"cred":p.cred,"hp":p.hp,"weapon":p.weapon,"mode":s.mode,"modal":game.hud.modal.visible,"activity":game.runtime.rhythm.is_active(),"achievement":s.achievements.has("not_a_phase"),"intro_remember":s.quests.intro_remember.done,"intro_tony":s.quests.intro_tony.available}
func _fixture() -> Dictionary:
	return {"player":game.runtime.p.duplicate(true),"state":game.runtime.s.duplicate(true),"rng":game.runtime.state.rng_seed}
func _alive() -> bool:
	if not _check(Time.get_ticks_msec()-began_wall < 120000,"whole Karaoke watchdog"): return false
	if not failures.is_empty(): return false
	if game.audit_enabled:
		if not _check(game.replacements == 0 and not (game as KaraokeScene).event_overflow,"same epoch and finite evidence"): return false
		for event: Dictionary in (game as KaraokeScene).karaoke_events:
			if event.kind in ["death","arrest","boss_started","dependency_missing","player_attack"]: return _check(false,"unexpected event: "+str(event.kind))
	return true
func _defend_exit() -> bool: return false
func _key(code: int) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = true
	game._unhandled_input(event)
	event = InputEventKey.new(); event.physical_keycode = code; event.pressed = false
	game._unhandled_input(event); inputs.keys += 1
func _reach_service(id: String) -> bool:
	if id != "karaoke" or not game.physics.can_reach_target(id): return false
	_release()
	for frame: int in range(120):
		if not _alive() or game.runtime.s.mode != "playing" or not game.physics.can_reach_target(id): return false
		_aim(game.world.service_points[id].target,_dt())
		var resolved: Dictionary = game.resolve_interaction()
		if resolved.get("kind") == "street" and resolved.get("id") == id: return true
		await game.frame_sampled
	return false
func _menu_snapshot() -> Dictionary:
	var labels: Array[String] = []; var choices: Array[Dictionary] = []
	for child: Node in game.hud.menu_box.get_children():
		if child is Label: labels.append(child.text)
		if child is Button: choices.append({"label":child.text,"enabled":not child.disabled and child.is_visible_in_tree()})
	return {"title":labels[0] if labels.size() > 0 else "","body":labels[1] if labels.size() > 1 else "","choices":choices}
func _capture(label: String) -> void:
	# Failure evidence must not depend on a scene signal that incomplete startup
	# or a script error might never emit. This is the actual viewport draw.
	await process_frame; await RenderingServer.frame_post_draw
	if _check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label): captures.append(label)
	_persist(false)
func _persist(complete: bool) -> void:
	proof.events = (game as KaraokeScene).karaoke_events.duplicate(true) if game != null else []
	proof.inputs = inputs.duplicate(true); proof.captures = captures.duplicate(); proof.walking = walking.duplicate(true)
	proof.replacements = game.replacements if game != null else 0; proof.overflow = (game as KaraokeScene).event_overflow if game != null else false
	proof.wall_ms = Time.get_ticks_msec()-began_wall; proof.failures = failures.duplicate(); proof.acceptance = complete and failures.is_empty()
	proof.engine = Engine.get_version_info().string; proof.renderer = RenderingServer.get_current_rendering_method(); proof.platform = OS.get_name()
	proof.probe_sha256 = FileAccess.get_sha256(get_script().resource_path)
	proof.source_corpus = Content.load_content().source.corpusSha256
	proof.scope = "Actual native input/menu/movement and one source Karaoke completion; not Web/audio/performance evidence."
	var file := FileAccess.open(output.path_join("karaoke-acceptance.json"),FileAccess.WRITE)
	if file == null: _check(false,"persist Karaoke report"); return
	file.store_string(JSON.stringify(proof,"\t")); file.close()
func _karaoke_scenario() -> void:
	game._new_game() # Fresh setup only; every subsequent gameplay action is input.
	if not _check(game.runtime.s.mode == "playing","ordinary fresh source start"): return
	proof.fixture_before = _fixture(); game.runtime.p.cash = 5; proof.fixture_after = _fixture()
	game.start_audit(); began_wall = Time.get_ticks_msec(); last_frame_wall = began_wall
	if not _check(game.world.service_points.has("karaoke"),"actual Mike service exists"): return
	if not await _walk_to(game.world.service_points.karaoke.approach,"karaoke"): return
	_release()
	var actor: Dictionary = _actor("karaoke"); var resolved: Dictionary = game.resolve_interaction()
	if not _check(not actor.is_empty(),"living canonical Mike record remains present"): return
	proof.entry = {"resolved":{"kind":resolved.get("kind"),"id":resolved.get("id")},"distance":game.runtime.state.player_center().distance_to(_center(actor)),"reachable":game.physics.can_reach_target("karaoke"),"alive":not actor.is_empty() and not actor.get("dead",false)}
	_key(KEY_E); await _capture("01_mike_menu")
	if not _check(game.runtime.s.mode == "dialogue","real E opened Mike menu"): return
	proof.entry.before = _summary(); proof.entry.rng_before = game.runtime.state.rng_seed
	if not _choose("sing a song. $5."): return
	proof.entry.after = _summary(); proof.entry.rng_after = game.runtime.state.rng_seed
	var paid_at: int = Time.get_ticks_msec()
	for index: int in range(8):
		if not _alive() or not _check(Time.get_ticks_msec()-paid_at < 30000,"finite paid sequence watchdog"): return
		await _capture("%02d_note_%d" % [index+2,index+1])
		if index == 0:
			var start: int = Time.get_ticks_msec()
			proof.dwell = {"before":{"menu":_menu_snapshot(),"state":_summary()},"active_before":game.admitted_ms}
			while Time.get_ticks_msec()-start < 550 and _alive(): await game.frame_sampled
			proof.dwell.merge({"after":{"menu":_menu_snapshot(),"state":_summary()},"active_after":game.admitted_ms,"wall_ms":Time.get_ticks_msec()-start})
		var menu: Dictionary = _menu_snapshot(); var chosen := -1
		for option: int in range(menu.choices.size()):
			if menu.choices[option].label.ends_with("(now!)") and menu.choices[option].enabled:
				if not _check(chosen == -1,"exactly one displayed current note"): return
				chosen = option
		if not _check(chosen >= 0 and chosen < 4,"displayed current note exists"): return
		var row: Dictionary = {"menu":menu,"index":chosen,"key":KEY_1+chosen,"rendered":true,"released":true,"before":_summary()}
		_key(KEY_1+chosen); row.after = _summary(); proof.notes.append(row); _persist(false)
	proof.final = _summary(); proof.visible_receipt = game.hud.receipt.text
	await _capture("10_actual_result_and_intro_receipt")
	var save_at: int = Time.get_ticks_msec()
	while game.saving or not game.pending_save.is_empty():
		if not _alive() or not _check(Time.get_ticks_msec()-save_at < 10000,"source save drain watchdog"): return
		await game.frame_sampled
	var saved: Dictionary = await game.store.read_save()
	proof.durable = {"schema":saved.get("schema"),"cash":saved.get("player",{}).get("cash"),"cred":saved.get("player",{}).get("cred"),"achievement":saved.get("state",{}).get("achievements",{}).has("not_a_phase"),"intro_remember":saved.get("state",{}).get("quests",{}).get("intro_remember",{}).get("done")}
	var origin: Vector3 = game.player.position; var count: int = int(inputs.motion_frames); var movement_at: int = Time.get_ticks_msec()
	# Retrace toward the actual approach start through the same physical input path.
	var route: PackedVector3Array = _resident_route(origin,Content.to_world(Vector2(proof.fixture_after.player.x+proof.fixture_after.player.w*0.5,proof.fixture_after.player.y+proof.fixture_after.player.h*0.5),origin.y))
	if not _check(route.size() >= 2,"real return movement route"): return
	var point: Vector3 = route[1]
	while origin.distance_to(game.player.position) <= 0.15:
		if not _alive() or not _check(Time.get_ticks_msec()-movement_at < 5000,"post-song movement watchdog"): _release(); return
		var aligned: float = _aim(Vector3(point.x,game.camera.global_position.y,point.z),_dt())
		_motion(Vector2(point.x-game.player.position.x,point.z-game.player.position.z).normalized() if aligned > 0.96 else Vector2.ZERO)
		await game.frame_sampled
	_release(); proof.movement = {"metres":origin.distance_to(game.player.position),"inputs":int(inputs.motion_frames)-count,"cash":game.runtime.p.cash,"cred":game.runtime.p.cred}
	await _capture("11_movement_resumed")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or "--qa-full" not in args: push_error("Karaoke native acceptance requires rendering and --qa-full"); quit(1); return
	output = ProjectSettings.globalize_path("res://../.build/full-port/karaoke-acceptance")
	for arg: String in args:
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if DirAccess.make_dir_recursive_absolute(output) != OK: push_error("Cannot create Karaoke evidence directory"); quit(1); return
	root.size = Vector2i(1280,720); game = KaraokeScene.new(); root.add_child(game)
	var boot_at: int = Time.get_ticks_msec()
	while not game.ready_for_play:
		if Time.get_ticks_msec()-boot_at >= 120000: _check(false,"cold startup watchdog"); break
		await process_frame
	if not game.ready_for_play or game.store == null or game.runtime == null or game.hud == null:
		_check(false,"FullScene startup dependencies unavailable")
		began_wall = Time.get_ticks_msec(); proof.boot_wall_ms = began_wall-boot_at
		_persist(false); await _capture("startup_failure")
		print("3D KARAOKE NATIVE ACCEPTANCE: FAIL; startup; ",output)
		game.free(); quit(1); return
	game.store.save_path = output.path_join("earned-karaoke.json"); game.store.storage_key = "rockbottom_3d_karaoke_acceptance_qa"
	began_wall = Time.get_ticks_msec()
	if failures.is_empty(): await _karaoke_scenario()
	_release(); _persist(false)
	if failures.is_empty():
		for error: String in karaoke_errors(proof): _check(false,error)
	if not failures.is_empty(): await _capture("failure")
	_persist(true)
	print("3D KARAOKE NATIVE ACCEPTANCE: ","PASS" if failures.is_empty() else "FAIL","; ",output)
	game.free(); quit(0 if failures.is_empty() else 1)
