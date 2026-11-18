extends SceneTree
## Diagnostic only: production scene, real active frames, then frozen visibility ablations.
## No gameplay repair, altered AI, stock fixture actors, browser control or production save.
const Scene = preload("res://scripts/full_scene.gd")
var game: Node3D
var output: String
var idle_seconds: float = 60.0
var report: Dictionary = {"purpose":"diagnose long-play camera polygons; not a performance or visual pass","samples":[],"captures":[],"interruptions":[],"travel":[]}

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Render diagnostic needs a native rendering device."); quit(1); return
	output = ProjectSettings.globalize_path("res://../.build/full-port/render-diagnostic")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument.begins_with("--idle-seconds="): idle_seconds = clampf(float(argument.trim_prefix("--idle-seconds=")),0.0,240.0)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720); root.msaa_3d = Viewport.MSAA_4X
	Engine.max_fps = 60
	game = Scene.new(); root.add_child(game); game.qa_mode = true
	for frame: int in range(900):
		await process_frame
		if game.ready_for_play: break
	if not game.ready_for_play: push_error("Diagnostic scene did not reach title."); quit(1); return
	game.store.save_path = output.path_join("probe-only-save.json")
	game.store.storage_key = "rockbottom_full_render_diagnostic"
	game.sound.muted = true
	game._new_game(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	report["startup"] = game.startup_report
	var source_hashes: Dictionary = {}
	for path: String in ["full_scene","actor_animation","character_roster","first_person_rig"]:
		source_hashes[path] = FileAccess.get_sha256("res://scripts/"+path+".gd")
	report["source_sha256"] = source_hashes
	report["renderer"] = {"name":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method()}
	await _capture("00_spawn")
	_sample("spawn",true)
	var remaining := idle_seconds
	while remaining > 0.0:
		var span := minf(30.0,remaining)
		if not await _travel(span,""): break
		remaining -= span
		_sample("idle_%.0f" % (idle_seconds-remaining),false)
		await _capture("idle_%.0f" % (idle_seconds-remaining))
	# Preserve the first idle obstruction before walking away from it.
	game.set_process(false)
	_sample("idle_final_geometry",true)
	await _ablations("idle")
	game.set_process(true)
	if game.runtime.s.mode == "playing":
		await _travel(2.7,"right")
		_sample("after_D_2700ms",true); await _capture("after_D")
		await _travel(2.7,"back")
		_sample("after_S_2700ms",true); await _capture("after_S")
	_release()
	game.set_process(false)
	await _ablations("after_travel")
	report["final_mode"] = game.runtime.s.mode
	report["final_active_ms"] = game.active_ms
	report["idle_seconds_requested"] = idle_seconds
	_persist()
	print("3D FULL RENDER DIAGNOSTIC: CAPTURED ",report.captures.size()," views; active_ms=",game.active_ms,"; inspect ",output)
	game.ready_for_play = false; game.queue_free(); await process_frame; quit(0)

func _release() -> void:
	for action: String in ["left","right","forward","back","sprint"]: Input.action_release(action)
func _travel(seconds: float,action: String) -> bool:
	_release()
	if not action.is_empty(): Input.action_press(action)
	var started: int = Time.get_ticks_msec()
	var active_before: float = game.active_ms
	while Time.get_ticks_msec()-started < seconds*1000.0:
		await process_frame
		if game.runtime.s.mode != "playing":
			report.interruptions.append({"action":action,"elapsed_ms":Time.get_ticks_msec()-started,"mode":game.runtime.s.mode,"hp":game.runtime.p.hp})
			_release(); return false
	_release()
	report.travel.append({"action":action,"wall_ms":Time.get_ticks_msec()-started,"active_ms":game.active_ms-active_before,"player":_v(game.player.global_position)})
	return true
func _capture(label: String) -> void:
	var running: bool = game.is_processing()
	game.set_process(false)
	await process_frame; await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output.path_join(label+".png"))
	report.captures.append({"label":label,"error":error,"active_ms":game.active_ms})
	_persist()
	game.set_process(running)

func _ablations(prefix: String) -> void:
	# Every image has the identical simulation state and camera/pose. Only visibility differs.
	var meshes: Array[MeshInstance3D] = []
	for body: Node3D in game.actors.values(): _collect(body,meshes)
	var original: Dictionary = {}
	for part: MeshInstance3D in meshes: original[part] = part.visible
	var hands_visible: bool = game.hands.visible
	await _capture(prefix+"_ablation_0_baseline")
	game.hands.visible = false; await _capture(prefix+"_ablation_1_no_hands"); game.hands.visible = hands_visible
	for part: MeshInstance3D in meshes:
		if part.skin != null: part.visible = false
	await _capture(prefix+"_ablation_2_no_npc_skinned_meshes")
	for part: MeshInstance3D in meshes: part.visible = original[part] and part.skin != null
	await _capture(prefix+"_ablation_3_no_npc_attachments")
	for part: MeshInstance3D in meshes: part.visible = false
	await _capture(prefix+"_ablation_4_no_npcs")
	game.hands.visible = false; await _capture(prefix+"_ablation_5_world_only")
	game.hands.visible = hands_visible
	for part: MeshInstance3D in meshes: part.visible = original[part]
	await _capture(prefix+"_ablation_6_restored")

func _persist() -> void:
	report["last_checkpoint_ticks_ms"] = Time.get_ticks_msec()
	var file := FileAccess.open(output.path_join("render-diagnostic.json"),FileAccess.WRITE)
	if file == null: push_error("Could not write diagnostic checkpoint."); return
	file.store_string(JSON.stringify(report,"\t")); file.close()

func _v(value: Vector3) -> Array: return [value.x,value.y,value.z]
func _transform(value: Transform3D) -> Dictionary:
	return {"position":_v(value.origin),"scale":_v(value.basis.get_scale()),"determinant":value.basis.determinant(),"finite":value.is_finite()}
func _collect(node: Node,meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: meshes.append(node)
	for child: Node in node.get_children(): _collect(child,meshes)
func _bone_metrics(node: Node,rows: Array[Dictionary]) -> void:
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		var max_position: float = 0.0; var max_scale: float = 0.0; var finite: bool = true
		for bone: int in range(skeleton.get_bone_count()):
			var pose := skeleton.get_bone_global_pose(bone)
			finite = finite and pose.is_finite()
			if not pose.is_finite(): continue
			max_position = maxf(max_position,pose.origin.length())
			var scale: Vector3 = pose.basis.get_scale().abs()
			max_scale = maxf(max_scale,scale[scale.max_axis_index()])
		rows.append({"node":str(skeleton.get_path()),"bones":skeleton.get_bone_count(),"max_global_origin_m":max_position,"max_scale":max_scale,"finite":finite})
	for child: Node in node.get_children(): _bone_metrics(child,rows)

func _sample(label: String,geometry: bool) -> void:
	var rows: Array[Dictionary] = []
	var bones: Array[Dictionary] = []
	var camera: Camera3D = game.camera
	var source_rows: Dictionary = {}
	for record: Dictionary in game.runtime.state.npcs: source_rows[str(record.id)] = record
	for id: String in game.actors:
		var body: Node3D = game.actors[id]
		var actor: Dictionary = source_rows.get(id,{})
		var state: Dictionary = {}
		for key: String in ["name","archetype","x","y","w","h","hp","speed","hostile","aggro","attackCd","chargeState","chargeT","grabFreezeT","stunT","dead"]:
			if actor.has(key): state[key] = actor[key]
		var width: float = float(actor.get("w",0)); var depth: float = float(actor.get("h",0))
		var overlapping: bool = Rect2(Vector2(game.runtime.p.x,game.runtime.p.y),Vector2(game.runtime.p.w,game.runtime.p.h)).intersects(Rect2(Vector2(actor.get("x",0),actor.get("y",0)),Vector2(width,depth)))
		rows.append({"id":id,"visual":str(body.get_meta("visual_id")),"source_state":state,"source_contact_overlap":overlapping,"source_half_diagonal_m":sqrt(width*width+depth*depth)*0.02,"visual_height_m":body.get_node("Art").get_meta("height",0),"visible":body.is_visible_in_tree(),"horizontal_distance_m":Vector2(body.global_position.x-camera.global_position.x,body.global_position.z-camera.global_position.z).length(),"transform":_transform(body.global_transform)})
		_bone_metrics(body,bones)
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.horizontal_distance_m < b.horizontal_distance_m)
	var sample := {"label":label,"active_ms":game.active_ms,"mode":game.runtime.s.mode,"hp":game.runtime.p.hp,"wanted":game.runtime.p.wanted,"actor_count":game.actors.size(),"player_source":[game.runtime.p.x,game.runtime.p.y],"camera":_transform(camera.global_transform),"near":camera.near,"fov":camera.fov,"hands":_transform(game.hands.transform),"hand_action":str(game.hands.action),"hand_phase":game.hands.action_phase,"hand_time":game.hands.get("_time"),"nearest_actors":rows.slice(0,12),"skeletons":bones}
	if geometry:
		var meshes: Array[MeshInstance3D] = []
		_collect(game.hands,meshes)
		for body: Node3D in game.actors.values(): _collect(body,meshes)
		var bounds: Array[Dictionary] = []
		for part: MeshInstance3D in meshes:
			if part.mesh != null and part.is_visible_in_tree(): bounds.append(_mesh_bounds(part,camera))
		bounds.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.camera_box_distance_m < b.camera_box_distance_m)
		sample["geometry"] = bounds
	report.samples.append(sample)
	_persist()

func _mesh_bounds(part: MeshInstance3D,camera: Camera3D) -> Dictionary:
	var palette: Array[Transform3D] = []
	if part.skin != null:
		var skeleton := part.get_node_or_null(part.skeleton) as Skeleton3D
		if skeleton != null:
			for bind: int in range(part.skin.get_bind_count()): palette.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(bind))*part.skin.get_bind_pose(bind))
	var box := AABB(); var camera_box := AABB(); var started: bool = false; var finite: bool = true
	var vertices_count: int = 0; var outside_custom: int = 0; var minimum_vertex: float = INF
	var to_camera: Transform3D = camera.global_transform.affine_inverse()*part.global_transform
	for surface: int in range(part.mesh.get_surface_count()):
		var arrays := part.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]; var indices: Variant = arrays[Mesh.ARRAY_BONES]
		for index: int in range(vertices.size()):
			var point: Vector3 = vertices[index]
			if not palette.is_empty() and weights is PackedFloat32Array and indices is PackedInt32Array:
				point = Vector3.ZERO
				for slot: int in range(4): point += (palette[indices[index*4+slot]]*vertices[index])*weights[index*4+slot]
			vertices_count += 1
			if not point.is_finite(): finite = false; continue
			if part.skin != null and not part.custom_aabb.grow(0.001).has_point(point): outside_custom += 1
			var in_camera: Vector3 = to_camera*point
			minimum_vertex = minf(minimum_vertex,in_camera.length())
			if not started: box = AABB(point,Vector3.ZERO); camera_box = AABB(in_camera,Vector3.ZERO); started = true
			else: box = box.expand(point); camera_box = camera_box.expand(in_camera)
	var nearest := Vector3(clampf(0.0,camera_box.position.x,camera_box.end.x),clampf(0.0,camera_box.position.y,camera_box.end.y),clampf(0.0,camera_box.position.z,camera_box.end.z))
	return {"node":str(part.get_path()),"skinned":part.skin != null,"finite":finite,"vertices":vertices_count,"outside_custom_aabb":outside_custom,"local_position":_v(box.position),"local_size":_v(box.size),"camera_box_position":_v(camera_box.position),"camera_box_size":_v(camera_box.size),"camera_inside_box":camera_box.has_point(Vector3.ZERO),"camera_box_distance_m":nearest.length(),"nearest_vertex_m":minimum_vertex,"transform":_transform(part.global_transform)}
