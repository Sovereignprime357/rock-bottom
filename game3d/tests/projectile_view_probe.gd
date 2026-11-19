extends SceneTree
## Native evidence only; explicit projectile records/render time and production world lighting.
const View = preload("res://scripts/projectile_view.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
const POINT := Vector2(1050,840)
var world: World
var camera: Camera3D
var shot: View
var other: View
var output_dir: String
var captures: Array[Dictionary] = []
var failed: bool = false

func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failed = true; push_error("Projectile capture: "+label)
	return ok
func _output() -> String:
	var path: String = ProjectSettings.globalize_path("res://../.build/full-port/p07c")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index].begins_with("--output="): path = args[index].trim_prefix("--output=")
		elif args[index] == "--output" and index+1 < args.size(): path = args[index+1]
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
func _record(kind: String,rotation: float = 0.0,point: Vector2 = POINT) -> Dictionary:
	return {"kind":kind,"x":point.x,"y":point.y,"rot":rotation,"life":2000.0,"vx":320.0,"vy":0.0}
func _look(distance: float,side: float = 0.0) -> void:
	var at: Vector3 = Content.to_world(POINT,1.0)
	camera.position = at+Vector3(side,0.69,distance); camera.look_at(at,Vector3.UP)
func _geometry(view: View) -> Dictionary:
	var low := Vector3(INF,INF,INF); var high := Vector3(-INF,-INF,-INF)
	var triangles: int = 0; var vertices: int = 0; var meshes: int = 0; var safe: bool = true
	for node: Node in view.find_children("*","MeshInstance3D",true,false):
		var instance: MeshInstance3D = node as MeshInstance3D
		if not instance.is_visible_in_tree(): continue
		meshes += 1
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; vertices += points.size()
			var count: int = points.size()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and not arrays[Mesh.ARRAY_INDEX].is_empty(): count = arrays[Mesh.ARRAY_INDEX].size()
			triangles += count/3
			for vertex: Vector3 in points:
				var at: Vector3 = instance.global_transform*vertex
				safe = safe and at.is_finite(); low = low.min(at); high = high.max(at)
	var result := {"kind":view.presentation_kind,"source_rotation":view.source_rotation,"origin":[view.position.x,view.position.y,view.position.z],"visible_meshes":meshes,"vertices":vertices,"triangles":triangles,"finite":safe,"world_min":[low.x,low.y,low.z],"world_max":[high.x,high.y,high.z]}
	if view.presentation_kind == "holy":
		result.glass_alpha = ((view.get_node("Art/holy/Glass") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a
		result.halo_alpha = ((view.get_node("Art/holy/Halo") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a
	return result
func _capture(label: String,time: float,night: bool = false) -> void:
	if failed: return
	var shown: Array[Dictionary] = []
	for view: View in [shot,other]:
		if not view.visible: continue
		var stats: Dictionary = _geometry(view)
		if not _require(bool(stats.finite) and int(stats.vertices) > 0,label+" finite visible geometry"): return
		shown.append(stats)
	await process_frame; await RenderingServer.frame_post_draw
	if not _require(root.get_texture().get_image().save_png(output_dir.path_join(label+".png")) == OK,"write "+label): return
	captures.append({"file":label+".png","render_ms":time,"lighting":"night" if night else "day","projectiles":shown})
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Projectile evidence requires native rendering."); quit(1); return
	output_dir = _output()
	if not _require(DirAccess.make_dir_recursive_absolute(output_dir) == OK,"create output directory"): quit(1); return
	root.size = Vector2i(1280,720)
	world = World.new(); root.add_child(world); world.build(); world.set_day_time(84.0)
	camera = Camera3D.new(); camera.fov = 78.0; camera.near = 0.06; camera.far = 180.0; world.add_child(camera); camera.current = true
	shot = View.create(); other = View.create(); world.add_child(shot); world.add_child(other)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame; await physics_frame
	for kind: String in ["bottle","holy"]:
		var rotations: Array[float] = [0.0,PI*0.5,0.65]
		for index: int in range(rotations.size()):
			_look(0.70,0.25); _require(shot.project(_record(kind,rotations[index]),0.0),"project close "+kind)
			await _capture(kind+"_close_rotation_"+str(index),0.0)
		_look(2.0); shot.project(_record(kind,0.65),0.0); await _capture(kind+"_standing_2m",0.0)
	for night: bool in [false,true]:
		world.set_day_time(180.0 if night else 84.0); _look(0.70,0.25)
		for peak: bool in [false,true]:
			var time: float = 80.0*PI*(0.5 if peak else 1.5)
			shot.project(_record("holy",0.65),time)
			await _capture("holy_"+("night" if night else "day")+"_pulse_"+("maximum" if peak else "minimum"),time,night)
	world.set_day_time(84.0); _look(1.8)
	shot.project(_record("bottle",0.15,POINT+Vector2(-8,0)),0.0); other.project(_record("holy",-0.35,POINT+Vector2(8,0)),80.0*PI*0.5)
	await _capture("mixed_same_time_row",80.0*PI*0.5)
	other.project({}); shot.project(_record("holy",PI*0.5),0.0); _look(0.70,0.25)
	await _capture("same_index_bottle_to_holy",0.0)
	_require(captures.size() == 14,"all14 bounded projectile captures completed")
	var manifest := {"camera":{"fov":camera.fov,"near":camera.near,"size":[1280,720]},"count":captures.size(),"captures":captures,"scope":"Original production projectile presentation and full-world lighting, explicit source records/render time. No Runtime, projectile simulation, physics, gameplay input or visual acceptance claim."}
	var file := FileAccess.open(output_dir.path_join("captures.json"),FileAccess.WRITE)
	if file == null: _require(false,"write manifest")
	else: file.store_string(JSON.stringify(manifest,"\t")); file.close()
	world.free()
	if failed: print("3D PROJECTILE VIEW PROBE: FAIL"); quit(1)
	else: print("3D PROJECTILE VIEW PROBE: PASS (%d frames; %s)"%[captures.size(),output_dir]); quit(0)
