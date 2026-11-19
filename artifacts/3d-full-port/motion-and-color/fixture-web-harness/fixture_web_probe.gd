extends "res://tests/fixture_motion_probe.gd"
## Isolated actual Web framebuffer evidence. Native geometry/camera helpers are inherited.
const MAX_REQUESTS := 60
var steps: Array[Dictionary] = []
var step_results: Dictionary = {}
var request_count: int = 0
var busy: bool = true
var step_callback: JavaScriptObject
var hashes: Dictionary = {}

func _run() -> void:
	if not OS.has_feature("web"):
		push_error("Fixture Web evidence requires the actual Web export."); quit(1); return
	root.size = Vector2i(1280,720); Engine.max_fps = 60
	world = World.new(); world.dynamic_fixture_motion = true; root.add_child(world); world.build()
	bindings = world.fixture_motion_bindings()
	view = View.create(); world.add_child(view)
	if not _require(view.build(bindings),"actual opt-in world bindings"): _publish(-1,false); return
	for actor: Dictionary in Content.load_content().actors.base:
		if actor.id == "pete": source_pete = actor.duplicate(true); break
	if not _require(not source_pete.is_empty(),"canonical Pete record"): _publish(-1,false); return
	pete = Roster.create(&"pete","pete".hash()); world.add_child(pete)
	pete.position = Content.body_position(source_pete,0.06)
	Animator.tick(pete,0.1,{"local_velocity":Vector3.ZERO,"action":&"eat","action_phase":0.4,"ambient_action":true},0)
	food = pete.find_child("hot_pocket",true,false) as Node3D
	if not _require(food != null,"real rig/food binding"): _publish(-1,false); return
	pete.visible = false # Explicit staged visibility; real Day/Scene lifecycle is gated separately.
	camera = Camera3D.new(); camera.fov = 52; camera.near = 0.05; camera.far = 380; world.add_child(camera); camera.current = true
	eye_shape = SphereShape3D.new(); eye_shape.radius = 0.06
	weather = Weather.new(); world.add_child(weather)
	if not _require(weather.build(world,camera),"existing Weather owner"): _publish(-1,false); return
	for index: int in range(3):
		for day: float in [0.5,0.9]:
			var prefix: String = "sodium_%d_%s_"%[index,"day" if day == 0.5 else "night"]
			steps.append({"id":prefix+"min","kind":"sodium","patch":index,"day":day,"visual_ms":PI*1050.0,"unix_ms":3000.0})
			steps.append({"id":prefix+"max","kind":"sodium","patch":index,"day":day,"visual_ms":PI*350.0,"unix_ms":3000.0})
	steps.append({"id":"pawn_counter_steam_night_phase0","kind":"steam","day":0.9,"visual_ms":713.0,"unix_ms":3000.0})
	steps.append({"id":"pawn_counter_steam_night_phase1","kind":"steam","day":0.9,"visual_ms":1373.0,"unix_ms":3000.0})
	steps.append({"id":"pawn_counter_steam_hidden_day","kind":"steam","day":0.5,"visual_ms":713.0,"unix_ms":3000.0})
	for path: String in ["res://scripts/fixture_motion_view.gd","res://scripts/full_neighborhood.gd","res://scripts/weather_presentation.gd","res://data/source_content.json","res://tests/fixture_motion_probe.gd","res://tests/fixture_web_probe.gd"]:
		hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	await physics_frame; await physics_frame
	step_callback = JavaScriptBridge.create_callback(_request_step)
	var browser: JavaScriptObject = JavaScriptBridge.get_interface("window")
	browser.rbFixtureControl = step_callback
	busy = false; _request_step([0])

func _request_step(args: Array) -> void:
	if busy or args.size() != 1 or not (args[0] is int or args[0] is float): return
	var number: float = float(args[0])
	if not is_finite(number) or number != floor(number) or number < 0 or number >= steps.size(): return
	if request_count >= MAX_REQUESTS:
		_require(false,"bounded60 screenshot requests exhausted"); _publish(int(number),false); return
	busy = true; request_count += 1
	JavaScriptBridge.eval("window.rbFixtureBusy(%d)"%int(number))
	call_deferred("_render_step",int(number))

func _rendered_frame() -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _pixels(frame: Image,point: Vector2) -> Array[int]:
	var result: Array[int] = []
	for y: int in range(-1,2):
		for x: int in range(-1,2):
			var pixel: Color = frame.get_pixel(clampi(roundi(point.x)+x,0,frame.get_width()-1),clampi(roundi(point.y)+y,0,frame.get_height()-1))
			result.append(roundi(pixel.r*255)); result.append(roundi(pixel.g*255)); result.append(roundi(pixel.b*255))
	return result

func _render_step(index: int) -> void:
	var step: Dictionary = steps[index]; var first_failure: int = failures.size()
	if step.kind == "sodium": _sodium_camera(int(step.patch),float(step.day) == 0.9)
	else: _pawn_counter_camera()
	var snapshot: Dictionary = _snapshot(float(step.day)); var original: Dictionary = snapshot.duplicate(true)
	_require(weather.sync({"dayTime":step.day,"weather":"clear","office_generator":false,"geometry_revision":0},step.visual_ms),"real clear/day/night lighting")
	_require(view.sync(snapshot,step.visual_ms,step.unix_ms),"actual supplied-clock fixture projection")
	await physics_frame
	var frame: Image = await _rendered_frame()
	_require(frame.get_width() == 1280 and frame.get_height() == 720,"actual1280x720 framebuffer")
	_require(_eye_clear(),"actual camera sphere clear")
	var inspected: Dictionary = view.inspect()
	var expected: Dictionary = View.source_sample(step.visual_ms,step.unix_ms,step.day)
	_require(inspected.sample == expected and inspected.steam_visible == expected.steam_visible,"exact source phase and nightly fallback")
	var pixels: Dictionary = {}
	if step.kind == "sodium":
		var patch: Dictionary = bindings.sodium[int(step.patch)]
		var point: Vector3 = Content.to_world(patch.source_center)
		for receiver: Dictionary in patch.receivers:
			if Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),receiver.polygon): point.y = float(receiver.height)+0.002; break
		var projected: Vector2 = camera.unproject_position(point)
		_require(not camera.is_position_behind(point) and Rect2(Vector2.ZERO,Vector2(root.size)).grow(-50).has_point(projected) and _ray_clear(point),"actual visible sodium center")
		var overlay: MeshInstance3D = view.get_node("SodiumPatches")
		_require(overlay.visible and overlay.mesh.get_surface_count() == 1,"one actual combined sodium surface")
		# Real framebuffer baseline: no replacement pixels and no shader/model modification.
		overlay.visible = false
		var baseline: Image = await _rendered_frame()
		_require(view.sync(snapshot,step.visual_ms,step.unix_ms),"restore exact source overlay after diagnostic baseline")
		frame = await _rendered_frame()
		var hidden: Array[int] = _pixels(baseline,projected); var shown: Array[int] = _pixels(frame,projected)
		var positive: int = 0; var negative: int = 0
		for channel: int in range(shown.size()):
			positive += maxi(0,shown[channel]-hidden[channel]); negative += maxi(0,hidden[channel]-shown[channel])
		_require(positive > 0 and negative == 0,"actual additive shader contributes positive framebuffer pixels")
		pixels = {"screen_point":[projected.x,projected.y],"baseline":hidden,"shown":shown,"positive_delta":positive,"negative_delta":negative,"sample":"actual3x3 rendered center RGB bytes"}
	else:
		_require(not food.is_visible_in_tree(),"actual retained rig/food remains hidden")
		var steam: MeshInstance3D = view.get_node("PocketSteam")
		if expected.steam_visible:
			var rectangle: Rect2 = _bounds(steam)
			_require(steam.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(root.size)).grow(-8).encloses(rectangle) and rectangle.size.x >= 6 and rectangle.size.y >= 4 and _ray_clear(steam.global_position),"actual counter steam is readable and unobstructed")
		else: _require(not steam.visible,"source day hides counter steam")
		pixels = {"counter":bindings.pawn_counter,"steam_position":steam.global_position,"steam_visible":steam.visible}
	_require(snapshot == original and food.global_transform == snapshot.food_transform,"no rig/snapshot authority writes")
	var inventory: Dictionary = _inventory()
	_require(inventory.physics == 0 and inventory.lights == 0 and inventory.particles == 0 and inventory.timers == 0,"presenter retains zero physics/light/particle/timer nodes")
	step_results[step.id] = {"index":index,"step":step,"pass":failures.size() == first_failure,"failures":failures.slice(first_failure),"camera":camera.global_transform,"inspection":view.inspect(),"pixels":pixels,"framebuffer":[frame.get_width(),frame.get_height()],"inventory":inventory}
	busy = false; _publish(index,true)

func _pair_results() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for patch: int in range(3):
		for phase: String in ["day","night"]:
			var prefix: String = "sodium_%d_%s_"%[patch,phase]
			if not step_results.has(prefix+"min") or not step_results.has(prefix+"max"): continue
			var low: Dictionary = step_results[prefix+"min"]; var high: Dictionary = step_results[prefix+"max"]
			var increase: int = 0; var decrease: int = 0
			for channel: int in range(low.pixels.shown.size()):
				increase += maxi(0,int(high.pixels.shown[channel])-int(low.pixels.shown[channel]))
				decrease += maxi(0,int(low.pixels.shown[channel])-int(high.pixels.shown[channel]))
			result.append({"pair":prefix,"pass":low.camera == high.camera and increase > 0 and decrease == 0,"positive_delta":increase,"negative_delta":decrease,"same_camera":low.camera == high.camera})
	return result

func _publish(index: int,ready: bool) -> void:
	var pairs: Array[Dictionary] = _pair_results(); var pass_value: bool = ready and failures.is_empty() and step_results.size() == 15 and pairs.size() == 6
	for pair: Dictionary in pairs: pass_value = pass_value and pair.pass
	var unavailable: Array[String] = []
	for path: String in hashes:
		if str(hashes[path]).is_empty(): unavailable.append(path)
	var hash_note: String = "Empty hashes are unavailable: exported compiled GDScript may replace source paths. This is not a runtime failure or source-identity proof. Root retains external copied-source/archive/export-pack hashes; the source_content JSON hash remains separately reported."
	var report := {"schema":1,"format":"rock-bottom-fixture-web-evidence","ready":ready,"current":index,"steps":steps,"results":step_results,"pairs":pairs,"visited":step_results.size(),"complete":step_results.size() == 15,"model_and_framebuffer_pass":pass_value,"failures":failures,"checks":checks,"requests":request_count,"request_cap":MAX_REQUESTS,"web":OS.has_feature("web"),"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string,"hashes":hashes,"source_hashes_available":not hashes.is_empty() and unavailable.is_empty(),"unavailable_source_hashes":unavailable,"source_content_hash_available":not str(hashes.get("res://data/source_content.json","")).is_empty(),"provenance_note":hash_note,"scope":"Actual Web3D staged framebuffer/geometry evidence only; no Runtime, gameplay, source RNG/save, Canvas pixel parity or frame-budget claim."}
	JavaScriptBridge.eval("window.rbFixtureReport(%s)"%JSON.stringify(report))
