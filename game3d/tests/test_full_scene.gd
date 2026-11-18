extends SceneTree
const Scene = preload("res://scripts/full_scene.gd")
const Content = preload("res://scripts/content_catalog.gd")
class DelayedStore:
	extends "res://scripts/save_store.gd"
	signal read_started
	signal release_read
	var response: Dictionary = {}
	var writes: Array[Dictionary] = []
	var concurrent_writes: int = 0
	func read_save() -> Dictionary:
		busy = true; read_started.emit()
		await release_read
		busy = false; return response.duplicate(true)
	func write_save(data: Dictionary) -> bool:
		if busy: concurrent_writes += 1; return false
		writes.append(data.duplicate(true)); return true
var game: Node3D
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _place(point: Vector3,target: Vector3 = Vector3.INF) -> void:
	var center: Vector2 = Content.to_source(point)
	game.runtime.p.x = center.x-game.runtime.p.w*0.5; game.runtime.p.y = center.y-game.runtime.p.h*0.5
	game._sync_player()
	if target.is_finite(): game.camera.look_at(target)
func _key(code: Key) -> void:
	var event := InputEventKey.new(); event.pressed = true; event.physical_keycode = code
	game._unhandled_input(event)
func _run() -> void:
	game = Scene.new(); root.add_child(game); game.qa_mode = true
	for frame: int in range(500):
		await process_frame
		if game.ready_for_play: break
	check(game.ready_for_play,"actual full scene reaches title")
	if not game.ready_for_play: await _finish(); return
	game.set_process(false); game.qa_mode = true
	game.store.save_path = ProjectSettings.globalize_path("res://../.build/3d/full-scene-test-save.json")
	game.store.storage_key = "rockbottom_3d_full_test"
	check(game.actors.size() == 56 and game.missing_visuals.is_empty(),"all56real day-one instances have authored visuals")
	check(game.runtime._actors_enabled and game.runtime.combat != null and game.runtime.director != null,"one actual composed combat/director")
	check(game.runtime.s.mode == "title" and game.hud.modal.visible,"startup title mode agrees with surface")
	game._new_game()
	check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"new game closes menu once")
	await physics_frame
	game._process(1.0/60.0)
	check(game.player.position.distance_to(Content.to_world(game.runtime.state.player_center(),game.Adapter.FEET)) < 0.00001,"player view mirrors the authoritative controller")
	for record: Dictionary in game.runtime.state.npcs:
		check(game.actors[record.id].position.distance_to(Content.body_position(record,game.Adapter.FEET)) < 0.0001,"source actor position:"+record.id)
	_key(KEY_ESCAPE)
	check(game.runtime.s.mode == "paused" and game.hud.modal.visible,"Escape opens pause")
	var timer: float = game.runtime.s.dayTime
	game._process(0.1)
	check(game.runtime.s.dayTime == timer,"pause does not advance model")
	_key(KEY_ESCAPE)
	check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"second desktop Escape resumes once")
	game.web_controls = true; game.capture_acquired = false
	game._sync_mouse_capture(false)
	check(game.runtime.s.mode == "playing","initial/refused Web capture keeps game playable")
	game._sync_mouse_capture(true); game._sync_mouse_capture(false)
	check(game.runtime.s.mode == "paused","losing acquired Web capture pauses")
	_key(KEY_ESCAPE)
	check(game.runtime.s.mode == "paused","Web Escape does not recapture from pause")
	game._resume(); game.web_controls = false
	_key(KEY_P); game.hud.update_runtime(game.runtime)
	check(game.runtime.communications.snapshot().visible and game.hud.feed_panel.visible and game.runtime.s.mode == "playing","P opens real phone without freezing world")
	_key(KEY_P); game.hud.update_runtime(game.runtime)
	check(not game.hud.feed_panel.visible,"P closes source phone")
	var count: Array[int] = [0]
	game._begin_menu()
	var stale: Dictionary = game._option("old",func(): count[0] += 1)
	game._begin_menu(); stale.action.call()
	check(count[0] == 0,"stale scene callbacks cannot execute")
	var pickup: Dictionary = game.world.service_points["cash:cp_intro_remember"]
	_place(pickup.approach,pickup.target)
	var action: Dictionary = game.resolve_interaction()
	check(action.get("kind") == "cash","cash prompt consumes actual closest low target")
	game.interact()
	check(game.runtime.p.cash == 10,"actual scene pickup resolves source intro cash")
	var tony: Dictionary = game.world.service_points.tony
	_place(tony.approach,tony.target)
	action = game.interact()
	check(action.get("id") == "tony" and game.runtime.s.mode == "dialogue","aimed Tony opens real vendor menu")
	var buttons: Array[Button] = []
	for child: Node in game.hud.menu_box.get_children():
		if child is Button: buttons.append(child)
	check(buttons.size() == 5,"vendor renders each source choice once including Leave")
	if not buttons.is_empty(): buttons[0].pressed.emit()
	check(game.runtime.p.rocks == 1 and game.runtime.p.cash == 0 and game.runtime.s.mode == "playing","real menu buy commits once and closes")
	var block: Dictionary = game.world.service_points["smoke:block"]
	_place(block.approach)
	game.camera.rotation = Vector3.ZERO
	action = game.interact()
	check(action.get("kind") == "smoke" and action.id == "block","whole Block zone verb follows NPC priority without marker aim")
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text == "smoke a rock.": child.pressed.emit(); break
	check(game.runtime.p.rockedT == 18000 and game.runtime.p.rocks == 0 and game.runtime.s.flags.introDone,"actual smoke menu starts single18s high and completesintro")
	check(game.hands.action == &"smoke","accepted source action reaches hand rig")
	game._ledger(true)
	check(game.runtime.s.mode == "dialogue" and game.hud.modal.visible,"inventory is modal readonly full ledger")
	var before: Dictionary = game.runtime.snapshot()
	check(game.hud.inventory_copy(game.runtime).contains("equipment"),"inventory displays actual equipment")
	check(game.runtime.snapshot() == before,"inventory rendering cannot mutate resources")
	game._resume()
	game._ledger(false); check(game.hud.modal.visible,"quest/hustle ledger renders actual state"); game._resume()
	while game.saving or not game.pending_save.is_empty(): await process_frame
	game._request_save(game.runtime.snapshot())
	while game.saving or not game.pending_save.is_empty(): await process_frame
	var saved: Dictionary = await game.store.read_save()
	check(saved.get("schema") == 2 and saved.get("format") == "rock-bottom-full-state","isolated full scene persistence stores full schema")
	game.runtime.p.cash = 73
	await game._load()
	check(game.runtime.p.cash == 0 and game.runtime.s.mode == "paused","load restores owned state then awaits deliberate Continue")
	check(game.hud.modal.visible,"load cannot leave input captured behind a modal")
	game._resume()
	check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"Continue after load is playable")
	game.runtime.p.cash = 23
	await game.store.write_save({"schema":900,"cash":999})
	await game._load()
	check(game.runtime.p.cash == 23,"invalid save cannot erase current progress")
	game._resume()
	var pinky: Dictionary = game.world.service_points.pinky
	_place(pinky.approach,pinky.target)
	action = game.interact()
	check(action.get("kind") == "street" and action.id == "pinky","actual aimed Pinky uses full Street menu")
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text.begins_with("buy 1 house cut"):
			child.pressed.emit(); break
	check(game.runtime.p.dirtySupplies == 1 and game.runtime.s.mode == "playing","Pinky supply choice commits and releases modal")
	var singer: Dictionary = game.world.service_points.karaoke
	_place(singer.approach,singer.target)
	action = game.interact()
	check(action.get("id") == "karaoke","actual Karaoke interaction resolves")
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text.begins_with("sing a song"):
			child.pressed.emit(); break
	check(game.runtime.rhythm.is_active() and game.runtime.s.mode == "dialogue","returned activities domain keeps actual rhythm modal")
	var first_index: int = game.runtime.rhythm._index
	_key(KEY_1)
	check(game.runtime.rhythm._index == first_index+1 and game.runtime.rhythm.is_active(),"source number shortcut advances exactly one Karaoke note")
	_key(KEY_ESCAPE)
	check(not game.runtime.rhythm.is_active() and game.runtime.s.mode == "playing" and not game.hud.modal.visible,"Escape cancels rhythm and releases actual menu")
	var rig: Dictionary = game.actors.busker.get_node("Art").get_meta("roster_rig")
	game.runtime.s.hitPause = 100
	var pose_clock: float = rig.time
	game._process(1.0/60.0)
	check(rig.time == pose_clock,"hitpause freezes actual actor pose clock")
	game.runtime.s.hitPause = 0
	var rng: int = game.runtime.state.rng_seed
	game._sync_model_nodes(1.0/60.0)
	check(rig.time > pose_clock and game.runtime.state.rng_seed == rng,"identity idle pose advances without model RNG")
	await _load_arrival_race(false)
	await _load_arrival_race(true)
	await _finish()

func _load_arrival_race(valid: bool) -> void:
	while game.saving or not game.pending_save.is_empty(): await process_frame
	game.runtime.fresh(); game._resume()
	game.runtime.p.inventory.append({"id":"bus_pass","n":"a bus pass","q":1})
	var pinky: Dictionary = game.world.service_points.pinky
	_place(pinky.approach,pinky.target)
	var menu: Dictionary = game.runtime.open_travel("bus")
	var ride: String = ""
	for choice: Dictionary in menu.get("options",[]):
		if choice.id.begins_with("ride:") and choice.enabled: ride = choice.id; break
	var result: Dictionary = game.runtime.select_travel(menu.get("token"),ride)
	check(result.get("pending",false),"delayed load fixture begins actual bus ride")
	if not result.get("pending",false): return
	game._resume(); game._consume_events()
	var original_store: Node = game.store
	var delayed := DelayedStore.new(); game.add_child(delayed); game.store = delayed
	game.runtime.p.cash = 77
	if valid: delayed.response = game.runtime.snapshot()
	game.runtime.p.cash = 12
	game.call_deferred("_load")
	await delayed.read_started
	game.runtime.advance_wall(game.runtime._wall_ms+380.0); game._consume_events()
	await process_frame
	check(game.loading and not game.pending_save.is_empty() and delayed.writes.is_empty() and delayed.concurrent_writes == 0,"actual arrival save queues while asynchronous read owns storage")
	var arrived: Vector2 = game.runtime.state.player_center()
	delayed.release_read.emit()
	while game.loading or game.saving or not game.pending_save.is_empty(): await process_frame
	if valid:
		check(game.runtime.p.cash == 77 and delayed.writes.is_empty(),"successful restore discards replaced-epoch arrival snapshot")
	else:
		check(game.runtime.p.cash == 12 and game.runtime.state.player_center() == arrived and delayed.writes.size() == 1,"failed read preserves arrival and writes its queued snapshot once")
		check(delayed.writes.size() == 1 and delayed.writes[0].player.cash == 12,"retained save contains current-session arrival progress")
	check(delayed.concurrent_writes == 0,"single adapter never receives overlapping read/write")
	game.store = original_store; delayed.queue_free()
	game._resume()

func _finish() -> void:
	for voice: AudioStreamPlayer in game.sound.players:
		voice.stop(); voice.stream = null
	# The native audio mixer releases its playback references on its own thread.
	await create_timer(0.10).timeout
	game.free(); game = null
	await process_frame
	await process_frame
	if failures.is_empty() and checks >= 80:
		print("3D FULL SCENE GATE: PASS (%d checks;56actors, controls, realcash/Tony/Block, readonlyledger, isolatedsave/load)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D FULL SCENE GATE: FAIL (%d/%dchecks)" % [failures.size(),checks]); quit(1)
