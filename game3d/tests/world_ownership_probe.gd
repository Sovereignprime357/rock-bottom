extends SceneTree
## Explicitly staged visual facts in the actual full world, not earned campaign progress.
const View = preload("res://scripts/world_ownership_view.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Weather = preload("res://scripts/weather_presentation.gd")
const Content = preload("res://scripts/content_catalog.gd")
var world: World
var view: View
var weather: Weather
var camera: Camera3D
var output: String
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var snapshot: Dictionary = {}
var samples: Array[float] = []

func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failures.append(label); push_error("Ownership probe: "+label)
	return ok

func _output() -> String:
	var result: String = ProjectSettings.globalize_path("res://../.build/full-port/world-ownership")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): result = arg.trim_prefix("--output=")
	return ProjectSettings.globalize_path(result) if result.begins_with("res://") else result

func _state(owned: bool,count: int,upgrades: bool = false) -> Dictionary:
	var claims: Dictionary = {}; var bits: Dictionary = {}
	var sites: Array = Content.definition("src/systems/campaigns.js","CLAIM_SITES",[])
	for index: int in range(mini(count,sites.size())): claims[sites[index].id] = true
	for id: String in View.UPGRADES: bits[id] = upgrades
	return {"office":{"owned":owned,"upgrades":bits},"districtClaims":claims,"flags":{"scrapHideoutOwned":true,"momHideoutOwned":true}}

func _clear_ray(from: Vector3,to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _office(near_side: float = 0.0) -> void:
	var front: Vector3 = world.ownership_surfaces().office.front
	camera.position = front+Vector3(near_side,1.65,14.0 if near_side == 0 else 6.0)
	camera.look_at(front+Vector3(near_side,2.8,0.15))

func _claim_camera(point: Vector3) -> bool:
	# Old School's sign is .8m north of a real fence. Include oblique front-face
	# approaches around its eastern end; keep source caption distance and LOS.
	for radius: float in [3.6,3.0,2.5,2.0]:
		for angle: float in [0.0,0.35,-0.35,0.7,-0.7,1.05,-1.05,1.2,-1.2,1.35,-1.35]:
			var eye: Vector3 = point+Vector3(sin(angle)*radius,1.65,cos(angle)*radius)
			if not world.is_clear_position(eye,0.25): continue
			if not _clear_ray(eye,point+Vector3(0,1.3,0.08)) or not _clear_ray(eye,point+Vector3(0,1.86,0.08)): continue
			camera.position = eye; camera.look_at(point+Vector3(0,1.13,0.04)); return true
	return false

func _hatch(id: String) -> void:
	var rect: Rect2 = world.ownership_surfaces().hideouts[id]
	var at := Vector3(rect.get_center().x,0.03,rect.get_center().y)
	camera.position = at+Vector3(0,1.65,2.2); camera.look_at(at)

func _screen_bounds(group: Node3D) -> Rect2:
	var result := Rect2(); var started: bool = false
	for child: Node in group.find_children("*","GeometryInstance3D",true,false):
		var geometry: GeometryInstance3D = child as GeometryInstance3D
		if not geometry.is_visible_in_tree(): continue
		var box: AABB = geometry.get_aabb()
		for index: int in range(8):
			var point: Vector3 = geometry.global_transform*box.get_endpoint(index)
			if camera.is_position_behind(point): return Rect2(Vector2(-10000,-10000),Vector2.ONE)
			var screen: Vector2 = camera.unproject_position(point)
			if not started: result = Rect2(screen,Vector2.ZERO); started = true
			else: result = result.expand(screen)
	return result

func _capture(id: String,night: bool = false,required: Array[String] = []) -> void:
	var before: Dictionary = snapshot.duplicate(true)
	var center: Vector2 = Content.to_source(camera.position)
	_require(view.sync(snapshot,center),"sync "+id)
	weather.sync({"dayTime":0.05 if night else 0.5,"weather":"clear","office_generator":snapshot.office.upgrades.generator,"geometry_revision":0},1000.0)
	await process_frame; await physics_frame; await RenderingServer.frame_post_draw
	var report: Dictionary = view.inspect()
	var projected: Dictionary = {}
	_require(world.is_clear_position(camera.global_position,0.25),"camera ground placement clear "+id)
	for key: String in required:
		_require(report.visible.has(key),"visible "+key+" in "+id)
		var node: Node3D = view._groups[key]
		var target: Vector3 = node.global_position
		if key.begins_with("claim_"): target += Vector3(0,1.28,0.08)
		elif key.begins_with("caption_"): target += Vector3(0,1.86,0.08)
		elif key.begins_with("hideout_"): target += Vector3(0,0.025,0)
		elif key.begins_with("door_"): target += Vector3(0,1.12,0.075)
		elif key == "upgrade_radio": target += Vector3(0,0.74,0)
		projected[key] = _screen_bounds(node)
		_require(Rect2(Vector2.ZERO,Vector2(root.size)).grow(-6).encloses(projected[key]),"complete actual geometry in viewport "+key)
		_require(not camera.is_position_behind(target) and Rect2(Vector2.ZERO,Vector2(root.size)).grow(-16).has_point(camera.unproject_position(target)),"actual target projects inside viewport "+key)
		_require(_clear_ray(camera.global_position,target),"actual layer1 visibility "+key)
	_require(snapshot == before,"capture owns no source mutation "+id)
	var image: Image = root.get_texture().get_image()
	_require(image.save_png(output.path_join(id+".png")) == OK,"save "+id)
	captures.append({"file":id+".png","size":[root.size.x,root.size.y],"camera":camera.global_transform,"lighting":"night" if night else "day","snapshot":snapshot.duplicate(true),"facts":report.facts,"visible":report.visible,"required":required,"projected":projected,"scope":"staged presentation; no purchase/progression claim"})

func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Ownership probe requires a native renderer."); quit(1); return
	output = _output()
	if not _require(DirAccess.make_dir_recursive_absolute(output) == OK,"output directory"): quit(1); return
	root.size = Vector2i(1280,720)
	world = World.new(); world.dynamic_ownership = true; root.add_child(world); world.build()
	camera = Camera3D.new(); camera.fov = 70; camera.near = 0.06; camera.far = 380; world.add_child(camera); camera.current = true
	view = View.new(); world.add_child(view)
	if not _require(not view.build(world).is_empty(),"real world view bank"): world.free(); quit(1); return
	weather = Weather.new(); world.add_child(weather)
	if not _require(weather.build(world,camera),"actual weather/static light owner"): world.free(); quit(1); return
	await physics_frame; await physics_frame
	_office()
	snapshot = _state(false,0); await _capture("office_locked",false,["door_locked","title_0"])
	snapshot = _state(true,0); await _capture("office_owned_empty",false,["door_owned","title_1"])
	for count: int in [1,4,8,11]:
		snapshot = _state(true,count,true)
		var title: String = "title_3" if count == 11 else "title_2" if count >= 4 else "title_1"
		await _capture("office_claims_%02d"%count,false,[title,"mailbox"])
	snapshot = _state(true,11,true)
	_office(-5.0); await _capture("office_upgrade_left",false,["upgrade_locker","upgrade_cot","paper_5"])
	_office(5.0); await _capture("office_upgrade_right",false,["upgrade_generator","upgrade_route_board","upgrade_radio"])
	for site: Dictionary in Content.definition("src/systems/campaigns.js","CLAIM_SITES",[]):
		var point: Vector3 = world.ownership_surfaces().claims[site.id]
		if not _require(_claim_camera(point),"actual clear camera at claim "+str(site.id)): continue
		await _capture("claim_"+str(site.id),false,["claim_"+str(site.id),"caption_"+str(site.id)])
	for id: String in ["scrap","mom"]:
		_hatch(id); await _capture("hideout_"+id,false,["hideout_"+id])
	_office(); await _capture("office_night",true,["title_3","upgrade_radio"])
	root.size = Vector2i(960,540); _hatch("mom")
	await _capture("hideout_mom_small_night",true,["hideout_mom"])
	snapshot = _state(false,0); snapshot.flags = {}; _office()
	await _capture("ownership_revoked_small",false,["title_0","door_locked"])
	_require(not view.inspect().visible.has("hideout_mom") and not view.inspect().visible.has("claim_canal"),"revocation removes previous visuals")
	snapshot = _state(true,11,true); view.sync(snapshot,Content.to_source(camera.position))
	var writes: int = view.inspect().writes
	for frame: int in range(120):
		var started: int = Time.get_ticks_usec()
		view.sync(snapshot,Content.to_source(camera.position))
		samples.append((Time.get_ticks_usec()-started)/1000.0)
		await process_frame
	samples.sort(); var p95: float = samples[int(floor((samples.size()-1)*0.95))]
	_require(view.inspect().writes == writes,"unchanged native sync no property writes")
	_require(captures.size() == 24,"all24 actual-world fixtures captured")
	var file := FileAccess.open(output.path_join("world-ownership.json"),FileAccess.WRITE)
	if _require(file != null,"write report"):
		file.store_string(JSON.stringify({"pass":failures.is_empty(),"failures":failures,"captures":captures,"sync_p95_ms":p95,"sync_target_ms":0.05,"sync_target_pass":p95 < 0.05,"msaa_3d":root.msaa_3d,"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string,"scope":"Pure staged ownership visuals; timing is local sync only, not whole-scene performance or earned campaign completion."},"\t")); file.close()
	world.free()
	print("3D WORLD OWNERSHIP NATIVE: %s (%d captures; sync p95 %.4fms; %s)"%["PASS" if failures.is_empty() else "FAIL",captures.size(),p95,output])
	quit(0 if failures.is_empty() else 1)
