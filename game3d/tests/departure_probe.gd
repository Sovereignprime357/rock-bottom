extends SceneTree
## Visible original day actor walking to its real edge pad in unmodified Scene ticks.
const Scene = preload("res://scripts/full_scene.gd")
const Content = preload("res://scripts/content_catalog.gd")
var game: Node3D
var output: String
var failures: Array[String] = []
var captures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> bool:
	checks += 1
	if not ok: failures.append(label); push_error(label)
	return ok
func _center(actor: Dictionary) -> Vector2: return Vector2(actor.x+actor.w*0.5,actor.y+actor.h*0.5)
func _actor(id: String) -> Dictionary:
	for actor: Dictionary in game.runtime.state.npcs:
		if actor.id == id: return actor
	return {}
func _key(code: Key) -> void:
	var event := InputEventKey.new(); event.pressed = true; event.physical_keycode = code
	game._unhandled_input(event)
func _capture(label: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	if _check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native departure capture "+label): captures.append(label)
func _walk_player(target: Vector2) -> bool:
	var began: int = Time.get_ticks_msec()
	while game.runtime.state.player_center().distance_to(target) > 2.0:
		if Time.get_ticks_msec()-began > 12000:
			Input.action_release("forward"); return _check(false,"real source approach walk stalled")
		var point: Vector3 = Content.to_world(target,game.player.position.y)
		game.player.look_at(point); game.camera.rotation = Vector3(-0.03,0,0)
		var distance: float = game.runtime.state.player_center().distance_to(target)*0.04
		Input.action_press("forward",0.5+0.5*minf(1.0,distance/0.4))
		await process_frame
	Input.action_release("forward"); return true
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Departure native probe requires a renderer"); quit(1); return
	output = ProjectSettings.globalize_path("res://../.build/full-port/p14-departures/native")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720); Engine.max_fps = 60
	game = Scene.new(); game.qa_mode = true; root.add_child(game)
	for frame: int in range(600):
		await process_frame
		if game.ready_for_play: break
	if not _check(game.ready_for_play,"actual FullScene cold startup"): quit(1); return
	game.store.save_path = ProjectSettings.globalize_path("res://../.build/3d/departure-native-qa.json")
	game.store.storage_key = "rockbottom_3d_departure_native_qa"
	game._new_game(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Explicit initial fixture only. The source actor does not exist yet.
	var pad: Dictionary = {}
	for candidate: Dictionary in game.world.departure_pads():
		if candidate.edge == "east" and int(candidate.source.y) == 2538: pad = candidate; break
	if not _check(not pad.is_empty(),"visible existing east road-end pad"): quit(1); return
	var start: Vector2 = pad.source-Vector2(260,0)
	game.runtime.p.x = start.x-game.runtime.p.w*0.5; game.runtime.p.y = start.y-game.runtime.p.h*0.5
	game.runtime.s.day = 3; game.runtime.s.dayTime = 0.65; game.runtime.s.flags.introDone = true
	game._sync_player()
	game.runtime.days._fire_visitor()
	var actor: Dictionary = {}
	for candidate: Dictionary in game.runtime.state.npcs:
		if candidate.get("isDay3Visitor",false): actor = candidate; break
	if not _check(not actor.is_empty(),"real source Day visitor is physically staged"): quit(1); return
	var id: String = str(actor.id)
	await process_frame; await physics_frame
	if not _check(game.actors.has(id),"live source actor has original3D rig"): quit(1); return
	if not await _walk_player(_center(actor)-Vector2(40,0)): quit(1); return
	game.camera.look_at(Content.to_world(_center(actor),1.6))
	_key(KEY_E)
	if not _check(game.runtime.s.mode == "dialogue" and not actor.get("wanderOff",false),"actual E resolves source visitor menu before departure"): quit(1); return
	await _capture("01_visitor_menu")
	_key(KEY_1)
	if not _check(game.runtime.s.mode == "playing" and actor.get("wanderOff",false) and actor.speed == 1.2,"actual source leave callback starts source-speed departure"): quit(1); return
	game.camera.look_at(Content.to_world(pad.source,1.5))
	var first: Vector2 = _center(actor)
	var previous: Vector2 = first
	var active_start: float = game.runtime._elapsed_ms
	var previous_ms: float = active_start
	var wall_start: int = Time.get_ticks_msec()
	var route: Dictionary = {}
	var middle: bool = false; var approach: bool = false
	await _capture("02_departure_start")
	while not _actor(id).is_empty() and Time.get_ticks_msec()-wall_start < 25000:
		await process_frame
		var now: float = game.runtime._elapsed_ms
		var position: Vector2 = _center(actor)
		_check(position.distance_to(previous) <= actor.speed*(now-previous_ms)/16.0+0.01,"native per-frame movement stays within admitted source time")
		previous = position; previous_ms = now
		var cached: Dictionary = game.physics._departure_entries.get(id,{})
		if cached.get("status") == "ready": route = {"exit_id":cached.exit_id,"target":cached.target}
		if not middle and position.distance_to(first) >= 50.0:
			middle = true; await _capture("03_walking_to_exit")
		if not approach and not route.is_empty() and position.distance_to(route.target) < 30.0:
			approach = true; await _capture("04_pad_approach")
	var active_elapsed: float = game.runtime._elapsed_ms-active_start
	var wall_elapsed: int = Time.get_ticks_msec()-wall_start
	_check(not route.is_empty() and _actor(id).is_empty() and _center(actor).distance_to(route.target) <= 4.0001,"native actor disappears only after actual named-pad arrival")
	_check(first.distance_to(_center(actor)) > 50.0 and middle and approach,"native walk is visibly observed before removal")
	await process_frame; await process_frame
	_check(not game.actors.has(id),"removed live actor releases original rig")
	await _capture("05_empty_marked_exit")
	game._pause()
	var report := {"acceptance":failures.is_empty(),"checks":checks,"failures":failures,"captures":captures,"actor_id":id,"start":first,"last":_center(actor),"exit":route,"active_ms":active_elapsed,"wall_ms":wall_elapsed,"planner":game.physics.departure_metrics(),"scope":"one real source Day visitor/menu/input/physical edge-pad departure; initial player fixture precedes spawn; no fight or60-AI performance claim"}
	var file := FileAccess.open(output.path_join("departure-native.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
	else: _check(false,"native report available")
	print("3D DEPARTURE NATIVE PROBE: ","PASS" if failures.is_empty() else "FAIL","; ",output)
	game.free(); quit(0 if failures.is_empty() else 1)
