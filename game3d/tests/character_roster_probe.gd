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
var packet_b1: bool = false
var packet_b2: bool = false
var packet_b3: bool = false
var target_ids := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Character roster evidence requires a rendering device.")
		quit(1)
		return
	output_dir = ProjectSettings.globalize_path("res://../.build/full-port/p05")
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--packet=b1": packet_b1 = true
		if arg == "--packet=b2": packet_b2 = true
		if arg == "--packet=b3": packet_b3 = true
	if packet_b1: output_dir = ProjectSettings.globalize_path("res://../.build/full-port/p05b1")
	if packet_b2: output_dir = ProjectSettings.globalize_path("res://../.build/full-port/p05b2")
	if packet_b3: output_dir = ProjectSettings.globalize_path("res://../.build/full-port/p05b3")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=")
		if arg.begins_with("--ids="): target_ids = arg.trim_prefix("--ids=").split(",",false)
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
	var visuals := Roster.Profiles.supported_visuals("b2" if packet_b2 else "b1") if packet_b1 or packet_b2 else PackedStringArray(["tony","pete","yuri","lurch","brutus","possum"])
	if packet_b3: visuals = Roster.Sites.supported_visuals("b3")
	if not target_ids.is_empty():
		visuals = target_ids
		for id: String in visuals:
			if id not in Roster.supported_visuals():
				push_error("Unsupported targeted roster identity: "+id)
				quit(1)
				return
	for id: String in visuals:
		var art := Roster.create(StringName(id),17)
		if art == null:
			push_error("Roster probe could not construct "+id)
			quit(1)
			return
		root.add_child(art)
		art.position = stage
		if packet_b1 or packet_b2 or packet_b3 or not target_ids.is_empty():
			if not await _profile_evidence(art,id): return
			art.free()
			continue
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


func _profile_evidence(art: Node3D, id: String) -> bool:
	var def := Roster.definition(StringName(id))
	var near_label := "3m" if def.family in ["mounted","assembly"] else "2m"
	_pose(art,{},0.0)
	_profile_view(def,false,false)
	if not await _capture(id+"_front_rest_"+near_label,art): return false
	_pose(art,{"local_velocity":Vector3.ZERO if def.family == "assembly" else Vector3(0,0,1.6)},0.20)
	_profile_view(def,true,false)
	if not await _capture(id+"_quarter_walk_"+near_label,art): return false
	var action: StringName = def.get("action",&"talk" if def.family in ["bird","object","mounted"] else &"bite")
	_pose(art,{"action":action,"action_phase":0.46,"asleep":id == "dave"},1.0/60.0)
	if id == "dave":
		camera.position = stage+Vector3(1.5,1.4,2.4)
		camera.look_at(stage+Vector3(-0.7,0.22,0))
	if not await _capture(id+"_identity_gesture",art): return false
	if packet_b3:
		for phase: float in [0.15,0.80]:
			_pose(art,{"action":action,"action_phase":phase},1.0/60.0)
			_profile_view(def,phase < 0.5,false)
			if not await _capture(id+"_site_action_%02d" % int(phase*100),art): return false
		if id == "former_teller":
			_pose(art,{"action":&"stamp","action_phase":0.5},1.0/60.0)
			camera.position = stage+Vector3(0.8,1.65,1.25)
			camera.look_at(stage+Vector3(0,1.10,0.20))
			if not await _capture(id+"_stamp_contact",art): return false
	if not target_ids.is_empty():
		if id in ["busker","math","launderlady"]:
			for phase: float in [0.15,0.80]:
				_pose(art,{"action":action,"action_phase":phase},1.0/60.0)
				camera.position = stage+Vector3(0.85,1.65,1.25)
				camera.look_at(stage+Vector3(0,1.10,0.15))
				if not await _capture(id+"_contact_%02d" % int(phase*100),art): return false
		if def.get("hair","") in ["hood","tarp_hood"]:
			_pose(art,{},1.0/60.0)
			camera.position = stage+Vector3(0.50,float(def.height)+0.35,0.85)
			camera.look_at(stage+Vector3(0,float(def.height)-0.15,0))
			if not await _capture(id+"_hood_roof",art): return false
	if def.family == "human" and not bool(def.get("site_resident",false)):
		_pose(art,{"action":&"strike","action_phase":0.03,"contact":true},1.0/60.0)
		_profile_view(def,false,false)
		if not await _capture(id+"_front_peak_strike_2m",art): return false
	if id in ["dogwalker","philosopher","receipt_guard","bishop_wire","curb_emperor","os_brutus","brutus_older"] or (id == "launderlady" and not target_ids.is_empty()):
		_pose(art,{"dead":true,"death_phase":1.0},1.0/60.0)
		camera.position = stage+Vector3(1.6,1.6,2.8)
		camera.look_at(stage+Vector3(0,0.20,0.80))
		if not await _capture(id+"_quarter_death",art): return false
	_pose(art,{},0.0)
	var near_stage := stage
	stage = Vector3(0,0.03,-6.5)
	art.position = stage
	art.rotation.y = PI*0.5
	_profile_view(def,false,true)
	var focus_y := maxf(0.03,float(def.height)*0.52)
	var ray := PhysicsRayQueryParameters3D.create(camera.position,stage+Vector3(0,focus_y,0),3)
	if not camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		push_error("B1 far evidence has blocked line of sight: "+id)
		quit(1)
		return false
	if not await _capture(id+"_front_rest_20m",art): return false
	stage = near_stage
	art.position = stage
	art.rotation = Vector3.ZERO
	return true


func _profile_view(def: Dictionary, quarter: bool, far: bool) -> void:
	var focus_y := maxf(0.03,float(def.height)*0.52)
	var eye := maxf(0.65,focus_y+0.65)
	var distance := 20.0 if far else (3.0 if def.family in ["mounted","assembly"] else 2.0)
	var side := distance*0.60 if quarter else 0.0
	if quarter: distance *= 0.80
	camera.position = stage+(Vector3(distance,eye,0) if far else Vector3(side,eye,distance))
	camera.look_at(stage+Vector3(0,focus_y,0))


func _pose(art: Node3D, snapshot: Dictionary, duration: float) -> void:
	Animator.reset(art)
	# A rendered idle includes the active holding pose, not the anatomical bind.
	if duration <= 0.0:
		Animator.tick(art,1.0/60.0,snapshot)
		return
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
