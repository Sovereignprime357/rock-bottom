extends SceneTree
## Isolated render evidence: production neighborhood lighting/ground, explicit
## animation snapshots, no simulation, player, save, audio or automatic pose tick.

const Roster = preload("res://scripts/character_roster.gd")
const Animator = preload("res://scripts/actor_animation.gd")
const Neighborhood = preload("res://scripts/neighborhood.gd")
var output_dir: String
var camera: Camera3D
var caption: Label
var captures: int = 0
var stage := Vector3(0,0.02,8)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Character roster evidence requires a rendering device.")
		quit(1)
		return
	output_dir = ProjectSettings.globalize_path("res://../.build/full-port/p05")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Cannot create roster evidence directory.")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	root.msaa_3d = Viewport.MSAA_4X
	var world := Neighborhood.new()
	root.add_child(world)
	world.build()
	world.set_day_time(60.0)
	camera = Camera3D.new()
	camera.name = "EvidenceCamera"
	camera.fov = 78.0
	camera.near = 0.06
	camera.current = true
	root.add_child(camera)
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	caption = Label.new()
	caption.position = Vector2(18,14)
	caption.add_theme_color_override("font_color",Color("d4c896"))
	caption.add_theme_color_override("font_shadow_color",Color("1a1810"))
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	caption.add_theme_font_size_override("font_size",20)
	overlay.add_child(caption)
	await process_frame
	await physics_frame
	for id: String in Roster.supported_visuals():
		var art := Roster.create(StringName(id),17)
		if art == null:
			push_error("Roster probe could not construct "+id)
			quit(1)
			return
		root.add_child(art)
		art.position = stage
		var human: bool = Roster.definition(StringName(id)).family == "human"
		_pose(art,{},0.0)
		_view(human,false,false,false)
		if not await _capture(id+"_front_rest_2m",art): return
		_view(human,true,false,false)
		if not await _capture(id+"_quarter_rest_2m",art): return
		_pose(art,{"local_velocity":Vector3(0,0,1.6)},0.20 if human else 0.10)
		_view(human,false,false,false)
		if not await _capture(id+"_front_walk_2m",art): return
		_view(human,true,false,false)
		if not await _capture(id+"_quarter_walk_2m",art): return
		_pose(art,{"action":&"strike" if human else &"bite","action_phase":0.08 if human else 0.5,"contact":true,"action_serial":0},1.0/60.0)
		if not await _capture(id+"_quarter_strike_2m",art): return
		if human:
			_pose(art,{"action":&"strike","action_phase":0.03,"contact":true,"action_serial":0},1.0/60.0)
			_view(true,false,false,false)
			if not await _capture(id+"_front_peak_strike_2m",art): return
			_view(true,true,false,false)
		_pose(art,{"hurt":1.0},1.0/60.0)
		if not await _capture(id+"_quarter_hurt_2m",art): return
		_pose(art,{"dead":true,"death_phase":1.0},1.0/60.0)
		_view(human,true,true,false)
		if not await _capture(id+"_quarter_death",art): return
		_pose(art,{},0.0)
		var near_stage := stage
		stage = Vector3(0,0.03,-6.5)
		art.position = stage
		art.rotation.y = PI*0.5
		_view(human,false,false,true)
		var ray := PhysicsRayQueryParameters3D.create(camera.position,stage+Vector3(0,1.05 if human else 0.32,0),3)
		if not camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			push_error("Roster far evidence has blocked line of sight: "+id)
			quit(1)
			return
		if not await _capture(id+"_front_rest_20m",art): return
		stage = near_stage
		art.position = stage
		art.rotation = Vector3.ZERO
		if id == "tony":
			for coats: int in [3,2,1,0]:
				_pose(art,{"coat_count":coats},1.0/60.0)
				_view(true,true,false,false)
				if not await _capture("tony_coats_%d" % coats,art): return
		if id in ["pete","yuri"]:
			_pose(art,{"action":&"eat" if id == "pete" else &"inspect","action_phase":0.5},1.0/60.0)
			_view(true,true,false,false)
			if not await _capture(id+"_identity_gesture",art): return
		art.free()
	print("3D CHARACTER ROSTER PROBE: PASS (%d native PNGs); %s" % [captures,output_dir])
	quit(0)


func _pose(art: Node3D, snapshot: Dictionary, duration: float) -> void:
	Animator.reset(art)
	var elapsed: float = 0.0
	while elapsed < duration-0.00001:
		var dt := minf(1.0/60.0,duration-elapsed)
		Animator.tick(art,dt,snapshot)
		elapsed += dt


func _view(human: bool, quarter: bool, dead: bool, far: bool) -> void:
	var distance := 20.0 if far else 2.0
	var eye := 1.63 if human else 0.85
	var focus := Vector3(0,1.05 if human else 0.32,0)
	var side := 0.0
	if quarter:
		side = distance*0.60
		distance *= 0.80
	if dead:
		side = 1.8 if human else 1.0
		distance = 2.8 if human else 2.0
		eye = 1.75 if human else 1.1
		focus = Vector3(0,0.25,0.65 if human else 0)
	camera.position = stage+(Vector3(distance,eye,0) if far else Vector3(side,eye,distance))
	camera.look_at(stage+focus)


func _capture(label: String, art: Node3D) -> bool:
	var metrics: Dictionary = art.get_meta("roster_metrics")
	caption.text = "%s  ·  %d triangles / %d surfaces / %d bones" % [label.replace("_"," "),metrics.triangles,metrics.surfaces,metrics.bones]
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output_dir.path_join(label+".png"))
	if error != OK:
		push_error("Cannot save roster evidence: "+label)
		quit(1)
		return false
	captures += 1
	return true
