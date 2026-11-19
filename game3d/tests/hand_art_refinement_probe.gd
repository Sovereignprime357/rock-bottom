extends "res://tests/cart_view_probe.gd"
## Isolated native art proof. Explicit visual phases/QA placement, not normal-input evidence.

func _detail_capture(label: String,observer: Camera3D = null) -> void:
	await _capture(label,{"scope":"Explicit presentation pose; not gameplay input evidence.","physical_size":[root.size.x,root.size.y],"projection_rect":str(camera.get_viewport().get_visible_rect()),"supporting_oblique":observer != null,"render_camera":observer.global_transform if observer != null else camera.global_transform})

func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Hand art evidence requires native rendering."); quit(1); return
	output_dir = ProjectSettings.globalize_path("res://../native-hand-art")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_dir = argument.trim_prefix("--output=")
	if not _require(DirAccess.make_dir_recursive_absolute(output_dir) == OK,"create output directory"): quit(1); return
	world = World.new(); world.dynamic_cart = true; root.add_child(world); world.build(); world.set_day_time(84.0)
	game = State.new(); game.s.mode = "playing"; game.npcs.clear()
	adapter = Adapter.new(world,game); travel = Travel.new(game,adapter)
	cart = View.new(); world.add_child(cart)
	if not _require(cart.bind(world,adapter,travel) and cart.sync(),"bind authored cart"): world.free(); quit(1); return
	original_resources = _resources()
	camera = Camera3D.new(); camera.fov = 78.0; camera.near = 0.06; camera.far = 180.0; world.add_child(camera); camera.current = true
	hands = Rig.create() as Rig; camera.add_child(hands); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame; await physics_frame
	_place(Vector2(1050,840))
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = size; await process_frame; await process_frame
		var prefix: String = str(size.x)+"_"
		hands.reset(); _tick(0.04); await _detail_capture(prefix+"idle")
		hands.acknowledge(&"pickup",true); _tick(0.16); await _detail_capture(prefix+"pickup")
		hands.reset(); hands.acknowledge(&"punch",true,true,&"fists"); _tick(0.045); await _detail_capture(prefix+"right_attack")
		_tick(0.30); hands.acknowledge(&"punch",true,true,&"fists"); _tick(0.045); await _detail_capture(prefix+"left_attack")
		_tick(0.30); await _detail_capture(prefix+"recovered")
	var record: Dictionary = travel.cart_record()
	var approach: Vector3 = adapter.cart_approach(Vector2(record.x,record.y))
	if not _require(approach.is_finite(),"real parked approach"): world.free(); quit(1); return
	_place(Content.to_source(approach))
	if not _require(travel.interact_cart().ok and cart.sync(),"actual Travel source mount"): world.free(); quit(1); return
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = size; await process_frame; await process_frame
		var prefix: String = str(size.x)+"_"
		hands.reset(); _tick(0.05,Vector3.ZERO,-0.60)
		_require(cart.grip_context(camera.global_transform,camera.fov,16.0/9.0).size() == 2,"actual visible handle targets")
		await _detail_capture(prefix+"cart_grip")
		hands.acknowledge(&"punch",true,true,&"fists"); _tick(0.045,Vector3.ZERO,-0.60); await _detail_capture(prefix+"cart_attack")
		_tick(0.30,Vector3.ZERO,-0.60); await _detail_capture(prefix+"cart_regrip")
		var observer := Camera3D.new(); observer.fov = 78.0; observer.near = 0.06; observer.far = 180.0; world.add_child(observer)
		var target: Vector3 = cart.get_node("Cart/Art/GripRight").global_position
		observer.position = target+Vector3(0.22,0.16,0.30); observer.look_at(target); observer.current = true
		await _detail_capture(prefix+"cart_oblique",observer)
		camera.current = true; observer.free()
	var file := FileAccess.open(output_dir.path_join("captures.json"),FileAccess.WRITE)
	if _require(file != null,"write honest native manifest"):
		file.store_string(JSON.stringify({"count":captures.size(),"captures":captures,"scope":"Candidate art only: real world/cart resources and Travel mount; explicit QA source positions, no NPCs, and Rig acknowledgements/ticks. Not user input, browser, performance or gameplay evidence."},"\t")); file.close()
	_require(captures.size() == 18,"all18 bounded anatomy/cart captures completed")
	world.free(); game = null; adapter = null; travel = null
	print("DRAFT HAND ART NATIVE: ","FAIL" if failure else "PASS","; ",captures.size()," captures; ",output_dir)
	quit(1 if failure else 0)
