extends "office_endpoint_driver.gd"
## Isolated confirmation/replay from an actual earned save, not a new progression fixture.
var endpoint_rows: Array[Dictionary] = []
var endpoint_recording := false

func _walk_frame() -> void:
	if not endpoint_recording: await super._walk_frame(); return
	var before := Vector2(game.runtime.p.x,game.runtime.p.y)
	var decoded: Vector2 = Input.get_vector("left","right","forward","back")
	await game.frame_sampled
	if endpoint_rows.size() >= 8000: _check(false,"bounded focused endpoint frame evidence"); return
	endpoint_rows.append({"before":[before.x,before.y],"after":[game.runtime.p.x,game.runtime.p.y],"input":decoded,"hp":game.runtime.p.hp,"stun":game.runtime.p.stunT,"active_ms":game.admitted_ms,"reason":walking_context.get("reason",""),"replans":walking_context.get("replans",0)})

func _endpoint_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame; await RenderingServer.frame_post_draw
	if _check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"endpoint capture "+label): captures.append(label)

func _endpoint_overlaps(point: Vector3) -> Array:
	var body: Dictionary = _probe_body(point)
	var rows: Array = []
	for hit: Dictionary in game.physics._space().intersect_shape(game.physics._query(body,Vector2(body.x,body.y)),16):
		var collider: Object = hit.get("collider")
		var row := {"owner":str(collider.get_meta("source_owner","")) if is_instance_valid(collider) else "","name":str(collider.name) if collider is Node else "","shapes":[]}
		if collider is Node3D:
			for child: Node in collider.get_children():
				if child is CollisionShape3D:
					var shape: Shape3D = child.shape
					var entry := {"type":shape.get_class(),"position":child.global_position}
					if shape is CylinderShape3D: entry.radius = shape.radius; entry.height = shape.height
					elif shape is CapsuleShape3D: entry.radius = shape.radius; entry.height = shape.height
					elif shape is BoxShape3D: entry.size = shape.size
					row.shapes.append(entry)
		rows.append(row)
	return rows

func _run() -> void:
	if "--qa-full" not in OS.get_cmdline_user_args(): push_error("endpoint diagnostic requires --qa-full"); quit(1); return
	var source_save := ""; var walk := false
	output = ProjectSettings.globalize_path("res://../.build/full-port/office-endpoint")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source-save="): source_save = argument.trim_prefix("--source-save=")
		elif argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument == "--walk": walk = true
	if source_save.is_empty() or not FileAccess.file_exists(source_save): push_error("actual retained earned save is required"); quit(1); return
	var payload: String = FileAccess.get_file_as_string(source_save)
	var saved: Variant = JSON.parse_string(payload)
	if not saved is Dictionary or saved.get("schema") != 2 or saved.state.blockRoute.stops[saved.state.blockRoute.cursor] != "alley_can":
		push_error("focused replay requires the retained earned alley_can cursor"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var copy_path: String = output.path_join("loaded-earned-save.json")
	if copy_path.simplify_path() == source_save.simplify_path(): push_error("source save must remain immutable"); quit(1); return
	var copy := FileAccess.open(copy_path,FileAccess.WRITE)
	if copy == null: push_error("cannot create isolated earned-save copy"); quit(1); return
	copy.store_string(payload); copy.close()
	root.size = Vector2i(1280,720); Engine.max_fps = 60
	began_wall = Time.get_ticks_msec(); last_frame_wall = began_wall
	game = ObservedScene.new(); root.add_child(game)
	for frame: int in range(900):
		await process_frame
		if game.ready_for_play: break
	if not _check(game.ready_for_play,"actual full scene ready"): await _shutdown(1); return
	game.store.save_path = copy_path; game.store.storage_key = "rockbottom_office_endpoint_diagnostic"
	if not await _choose("remember.","load"): await _shutdown(1); return
	var deadline: int = Time.get_ticks_msec()+10000
	while game.loading or game.runtime.s.mode != "paused":
		if not _check(Time.get_ticks_msec() < deadline,"normal saved-state load completes"): await _shutdown(1); return
		await game.frame_sampled
	if not _check(_same(game.runtime.s.blockRoute,saved.state.blockRoute),"actual menu load retains earned route cursor"): await _shutdown(1); return
	game.set_process(false); await physics_frame
	var id := "route:alley_can"
	var service: Dictionary = game.world.service_points[id].duplicate(true)
	var original: Vector3 = service.approach
	var proof: Dictionary = _endpoint_proof(id,original)
	var overlaps: Array = _endpoint_overlaps(original)
	var confirmed := false
	for hit: Dictionary in overlaps:
		if hit.owner == "interactiveProps:4": confirmed = true
	_check(not proof.ok and proof.reason == "actual_capsule_overlap" and confirmed,"actual live alley can overlaps the old guidance endpoint")
	var candidates: Array[Dictionary] = []
	var legal := 0
	for candidate: Vector3 in endpoint_candidates(service.source_point,original,game.player.position):
		var result: Dictionary = _endpoint_proof(id,candidate)
		candidates.append(result)
		if result.ok: legal += 1
	_check(legal > 0,"same canonical route has legal source-range physical endpoints")
	var before: Dictionary = _summary()
	await _endpoint_capture("loaded_confirmation")
	var stamp: Dictionary = {}
	if walk and failures.is_empty():
		game.set_process(true)
		if await _choose("continue.","resume"):
			game.start_audit(); endpoint_recording = true
			var reached: bool = await _visit(id,true)
			endpoint_recording = false
			if _check(reached and interaction_matches(game.resolve_interaction(),id),"actual input resolves the unchanged alley route stop"):
				stamp = _field_receipt("stamp",id)
				_check(game.runtime.s.blockRoute.cursor == int(before.route.cursor)+1 and game.runtime.s.blockRoute.serial == before.route.serial,"one normal E advances the real route exactly once")
		game.set_process(false); _release()
		await _endpoint_capture("walk_final")
	_check(_same(game.world.service_points[id],service),"probe never relocates or rewrites canonical service guidance")
	_check(FileAccess.get_file_as_string(source_save).sha256_text() == payload.sha256_text(),"retained earned save stays immutable")
	var report := {"schema":1,"diagnostic_only":true,"office_acceptance":false,"complete":failures.is_empty(),"walk_requested":walk,"source_save_sha256":payload.sha256_text(),"loaded_source_position":[before.source_position.x,before.source_position.y],"original_service":service,"original_proof":proof,"actual_overlaps":overlaps,"candidate_proofs":candidates,"legal_candidates":legal,"before":before,"after":_summary(),"endpoint_history":endpoint_history,"walking":walking,"walking_context":walking_context,"rows":endpoint_rows,"stamp":stamp,"legs":legs,"inputs":inputs,"events":game.trace,"captures":captures,"failures":failures,"engine":Engine.get_version_info().string,"headless":DisplayServer.get_name() == "headless"}
	var file := FileAccess.open(output.path_join("office-service-endpoint.json"),FileAccess.WRITE)
	if file == null: _check(false,"focused endpoint report writable")
	else: file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
	print("OFFICE SERVICE ENDPOINT ","REPLAY" if walk else "CONFIRMATION",": ","PASS" if failures.is_empty() else "FAIL","; ",output)
	await _shutdown(0 if failures.is_empty() else 1)
