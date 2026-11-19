extends SceneTree
## Native proof of original post, weighted dog collar and isolated HUD perimeter.
const Leash = preload("res://scripts/dog_leash_view.gd")
const Border = preload("res://scripts/district_border_view.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Roster = preload("res://scripts/character_roster.gd")
const Animator = preload("res://scripts/actor_animation.gd")
const Hud = preload("res://scripts/full_hud.gd")
const Runtime = preload("res://scripts/full_runtime.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
var world: World
var camera: Camera3D
var dog: Node3D
var marker: Node3D
var post: Node3D
var leash: Leash
var border: Border
var hud: Hud
var runtime: Runtime
var adapter: Adapter
var source_dog: Dictionary
var output_dir: String
var captures: Array[Dictionary] = []
var failed: bool = false
var sample_times: Array[float] = []

func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failed = true; push_error("Leash/border capture: "+label)
	return ok
func _output() -> String:
	var path: String = ProjectSettings.globalize_path("res://../.build/full-port/p14f")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index].begins_with("--output="): path = args[index].trim_prefix("--output=")
		elif args[index] == "--output" and index+1 < args.size(): path = args[index+1]
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
func _snapshot() -> Dictionary:
	return {"post_present":true,"dog":source_dog.duplicate(true),"post_position":post.global_position,"collar_position":marker.global_position}
func _sync() -> void:
	_require(leash.sync(_snapshot()),"project actual post/collar endpoints")
func _pose(snapshot: Dictionary,yaw: float = 0.0) -> void:
	dog.rotation.y = yaw; Animator.tick(dog,0.12,snapshot,0); _sync()
func _look() -> void:
	var at: Vector3 = (post.global_position+marker.global_position)*0.5
	camera.position = at+Vector3(2.0,1.1,2.4); camera.look_at(at,Vector3.UP)
func _native_segments() -> bool:
	if not leash.inspect().active: return not leash.visible
	var points: PackedVector3Array = leash.inspect().points
	var segments: MultiMeshInstance3D = leash.get_node("Segments")
	if points.size() != 7 or segments.multimesh.instance_count != 6: return false
	for index: int in range(6):
		# Native renderer readback, deliberately not the dummy headless getter.
		var transform: Transform3D = segments.multimesh.get_instance_transform(index)
		if not transform.is_finite(): return false
		if (transform*Vector3(0,-0.5,0)).distance_to(points[index]) > 0.0001: return false
		if (transform*Vector3(0,0.5,0)).distance_to(points[index+1]) > 0.0001: return false
	var links: MultiMeshInstance3D = leash.get_node("Links")
	for index: int in range(5):
		var transform: Transform3D = links.multimesh.get_instance_transform(index)
		if not transform.is_finite() or transform.basis.determinant() < 0.99: return false
	return leash.to_global(points[0]).distance_to(post.global_position) < 0.0001 and leash.to_global(points[6]).distance_to(marker.global_position) < 0.0001
func _capture(label: String) -> void:
	if failed: return
	await process_frame; await RenderingServer.frame_post_draw
	if not _require(_native_segments(),label+" actual native instance transforms meet the supplied endpoints"): return
	if not _require(root.get_texture().get_image().save_png(output_dir.path_join(label+".png")) == OK,"write "+label): return
	var points: Array = []
	for point: Vector3 in leash.inspect().points: points.append([point.x,point.y,point.z])
	captures.append({"file":label+".png","leash_active":leash.inspect().active,"points":points,"post":[post.global_position.x,post.global_position.y,post.global_position.z],"collar":[marker.global_position.x,marker.global_position.y,marker.global_position.z],"border":border.inspect(),"tint":hud.tint.color.to_html(true),"native_transforms_verified":true})
func _tint(kind: String) -> void:
	runtime.p.rockedT = 1000.0 if kind == "high" else 0.0
	runtime.p.crashT = 1000.0 if kind == "crash" else 0.0
	runtime.p.hitterHigh = false; hud.update_runtime(runtime)
func _border(color: String,remaining: float = 600.0) -> void:
	var original: Color = hud.tint.color
	_require(border.sync({"remaining_ms":remaining,"color":color,"visible":true}),"project source border color")
	_require(hud.tint.color == original,"border cannot mutate existing HUD tint")
func _profile() -> void:
	var snapshot: Dictionary = _snapshot(); var before: Dictionary = snapshot.duplicate(true)
	for frame: int in range(180):
		var start: int = Time.get_ticks_usec()
		leash.sync(snapshot); border.sync({"remaining_ms":600.0-float(frame)*3.0,"color":"#c08038","visible":true})
		sample_times.append(float(Time.get_ticks_usec()-start)/1000.0)
		await process_frame
	_require(snapshot == before and leash.inspect().queries == 0 and leash.inspect().dynamic_shadows == 0,"measured presentation preserves caller state without queries/shadows")
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Leash/border evidence requires native rendering."); quit(1); return
	output_dir = _output()
	if not _require(DirAccess.make_dir_recursive_absolute(output_dir) == OK,"create output directory"): quit(1); return
	root.size = Vector2i(1280,720)
	world = World.new(); root.add_child(world); world.build(); world.set_day_time(84.0)
	post = world.leash_post_anchor()
	if not _require(post != null,"actual original world post anchor exists"): world.free(); quit(1); return
	for row: Dictionary in Content.load_content().actors.base:
		if row.id == "scrap_dog": source_dog = row.duplicate(true); break
	if not _require(not source_dog.is_empty(),"canonical original scrap dog record exists"): world.free(); quit(1); return
	source_dog.dead = false
	dog = Roster.create(&"scrap_dog"); world.add_child(dog)
	dog.position = Content.to_world(Vector2(source_dog.x+source_dog.w*0.5,source_dog.y+source_dog.h*0.5),0.02)
	marker = dog.get_node("leash_collar")
	leash = Leash.create(); world.add_child(leash)
	camera = Camera3D.new(); camera.fov = 78.0; camera.near = 0.06; camera.far = 180.0; world.add_child(camera); camera.current = true
	adapter = Adapter.new(world); runtime = Runtime.new(adapter); adapter.bind_state(runtime.state); runtime.s.mode = "playing"
	runtime.p.x = source_dog.x; runtime.p.y = source_dog.y
	hud = Hud.new(); root.add_child(hud); hud.set_process(false)
	border = Border.new(); hud.root.add_child(border); border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.root.move_child(border,hud.root.get_children().find(hud.tint)+1)
	_tint(""); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame; await physics_frame
	_pose({"local_velocity":Vector3.ZERO,"action":&"","action_phase":0.0}); _look(); await _capture("living_original_idle")
	source_dog.chained = false; _sync(); await _capture("attacked_alive_chain_flag_false")
	_pose({"local_velocity":Vector3(0,0,0.9),"action":&"","action_phase":0.0},0.65); await _capture("weighted_collar_walk_yaw")
	_pose({"local_velocity":Vector3.ZERO,"action":&"bite","action_phase":0.4,"hurt":0.8},-0.4); await _capture("weighted_collar_hurt")
	source_dog.dead = true; _sync(); await _capture("dead_original_no_leash")
	source_dog.dead = false; source_dog.id = "freed_dog_follower"; _sync(); await _capture("freed_follower_no_leash")
	source_dog.id = "scrap_dog"; _pose({"local_velocity":Vector3.ZERO,"action":&"","action_phase":0.0})
	var missing: Dictionary = _snapshot(); missing.post_present = false; leash.sync(missing); await _capture("missing_post_no_leash")
	_sync()
	for item: Array in [["street","#a04848"],["scrap","#c08038"],["spiritual","#d8c068"]]:
		_border(item[1]); await _capture("border_"+item[0])
	_tint("high"); _border("#c08038"); await _capture("border_with_existing_high_tint")
	_tint("crash"); _border("#d8c068"); await _capture("border_with_existing_crash_tint")
	_tint(""); _border("#a04848",300.0); await _capture("border_half_fade")
	_border("#a04848",0.0); await _capture("border_expired")
	border.clear(); await _capture("border_clear_preserves_world")
	_require(captures.size() == 15,"all15 native leash/border views completed")
	if not failed: await _profile()
	sample_times.sort()
	var profile := {"samples":sample_times.size(),"sync_p95_ms":sample_times[int(ceil(sample_times.size()*0.95))-1] if not sample_times.is_empty() else 0.0,"leash":leash.inspect(),"note":"No screenshot/readback during180 measured frames; isolated presenter costs, not full-game performance acceptance."}
	profile.leash.erase("points")
	var manifest := {"count":captures.size(),"captures":captures,"profile":profile,"camera":{"fov":camera.fov,"near":camera.near,"size":[1280,720]},"scope":"Actual FullNeighborhood post and weighted Roster dog. Actual FullHUD.update_runtime supplies high/crash tint; no active gameplay ticks, input, save or audio."}
	var file := FileAccess.open(output_dir.path_join("captures.json"),FileAccess.WRITE)
	if file == null: _require(false,"write capture manifest")
	else: file.store_string(JSON.stringify(manifest,"\t")); file.close()
	hud.free(); world.free()
	if failed: print("3D LEASH BORDER PROBE: FAIL"); quit(1)
	else: print("3D LEASH BORDER PROBE: PASS (%d frames;%s)"%[captures.size(),output_dir]); quit(0)
