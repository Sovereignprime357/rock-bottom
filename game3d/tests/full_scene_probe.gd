extends SceneTree
## Native evidence of the actual full scene/controller/menus/timers. Isolated save only.
const Scene = preload("res://scripts/full_scene.gd")
const Content = preload("res://scripts/content_catalog.gd")
var game: Node3D
var output: String
var failed: bool = false
func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failed = true; push_error(label)
	return ok
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Full scene evidence requires a rendering device."); quit(1); return
	root.size = Vector2i(1280,720)
	output = ProjectSettings.globalize_path("res://../.build/full-port/p15a")
	DirAccess.make_dir_recursive_absolute(output)
	game = Scene.new(); root.add_child(game); game.qa_mode = true
	for frame: int in range(600):
		await process_frame
		if game.ready_for_play: break
	if not _require(game.ready_for_play,"Full scene reached its title"): quit(1); return
	game.qa_mode = true
	game.store.save_path = ProjectSettings.globalize_path("res://../.build/3d/full-scene-native-qa.json")
	game.store.storage_key = "rockbottom_3d_full_native_qa"
	await _capture("title")
	game._new_game(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _capture("block_spawn")
	# One fixture start at the canonical pickup. All subsequent travel uses real input.
	var pickup: Dictionary = game.world.service_points["cash:cp_intro_remember"]
	_place(pickup.approach); game.camera.look_at(pickup.target)
	game.interact()
	if not _require(game.runtime.p.cash == 10,"Native intro cash picked through actual resolver"): quit(1); return
	var tony: Dictionary = game.world.service_points.tony
	if not await _walk_to(tony.approach): quit(1); return
	game.camera.look_at(tony.target)
	game.interact()
	if not _require(game.runtime.s.mode == "dialogue","Native controller reaches Tony and opens menu"): quit(1); return
	await _capture("tony_menu")
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text.begins_with("buy a rock"):
			child.pressed.emit(); break
	if not _require(game.runtime.p.rocks == 1,"Native source menu purchased rock"): quit(1); return
	if not await _walk_to(game.world.service_points["smoke:block"].approach): quit(1); return
	game.camera.rotation = Vector3(-0.04,0,0)
	game.interact()
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text == "smoke a rock.": child.pressed.emit(); break
	if not _require(game.runtime.p.rockedT > 17900 and game.runtime.s.flags.introDone,"Native actual smoke starts source high"): quit(1); return
	var started: int = Time.get_ticks_msec()
	var crash: float = -1.0; var finished: float = -1.0
	await _capture("first_person_smoke")
	while Time.get_ticks_msec()-started < 27500:
		await process_frame
		var elapsed: float = float(Time.get_ticks_msec()-started)/1000.0
		if game.runtime.p.crashT > 0 and crash < 0:
			crash = elapsed; await _capture("crash")
		if crash > 0 and game.runtime.p.crashT <= 0 and finished < 0: finished = elapsed
	_require(absf(crash-18.0) < 1.0 and absf(finished-26.0) < 1.0,"Actual rendered18s/8s loop; crash=%s complete=%s" % [crash,finished])
	print("3D FULL NATIVE LOOP: crash=",crash,"s complete=",finished,"s; actors=",game.actors.size()," queries=",game.physics.query_count)
	game._pause(); await _capture("pause")
	game._resume(); game._ledger(true); await _capture("inventory")
	game._resume(); game._manual_save()
	while game.saving or not game.pending_save.is_empty(): await process_frame
	var saved: Dictionary = await game.store.read_save()
	_require(saved.get("schema") == 2 and saved.state.flags.introDone,"Native full progress saved in isolated schema2file")
	game._pause(); game.ready_for_play = false
	await _capture("block_complete")
	var report := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"actors":game.actors.size(),"crash_seconds":crash,"cycle_seconds":finished,"source_schema":saved.get("schema"),"pass":not failed,"scope":"actual full scene opening, controller, menu, hand gesture and source18s/8s loop; full parity remains tracked"}
	var file := FileAccess.open(output.path_join("native-tour.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("3D FULL SCENE NATIVE PROBE: ","FAIL" if failed else "PASS","; ",output)
	game.free(); quit(1 if failed else 0)
func _place(point: Vector3) -> void:
	var at: Vector2 = Content.to_source(point)
	game.runtime.p.x = at.x-game.runtime.p.w*0.5; game.runtime.p.y = at.y-game.runtime.p.h*0.5
	game._sync_player()
func _walk_to(target: Vector3) -> bool:
	var route: PackedVector3Array = game.world.find_route(game.player.position,target)
	if not _require(not route.is_empty(),"Actual route exists"): return false
	for point: Vector3 in route:
		var started: int = Time.get_ticks_msec()
		while Vector2(game.player.position.x-point.x,game.player.position.z-point.z).length() > 0.06:
			if Time.get_ticks_msec()-started > 20000:
				Input.action_release("forward"); return _require(false,"Native input walk stalled at "+str(game.player.position)+" goal "+str(point))
			var look: Vector3 = point; look.y = game.player.position.y
			game.player.look_at(look)
			game.camera.rotation = Vector3(-0.04,0,0)
			var distance: float = Vector2(game.player.position.x-point.x,game.player.position.z-point.z).length()
			# Input.get_vector applies the default0.5deadzone; encode the desired
			# remaining-distance strength above it instead of stalling near a waypoint.
			Input.action_press("forward",0.5+0.5*minf(1.0,distance/0.4))
			await process_frame
	Input.action_release("forward")
	return true
func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output.path_join(label+".png"))
	_require(error == OK,"Native capture saved:"+label)
