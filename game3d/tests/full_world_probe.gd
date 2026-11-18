extends SceneTree
## Native geometry-only evidence. No main scene, actors, gameplay state or save IO.

const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
const ZONE_VIEWS := {
	"block": [Vector2(1080, 960), Vector2(1060, 810)],
	"scrap": [Vector2(500, 440), Vector2(330, 210)],
	"pawn": [Vector2(264, 785), Vector2(264, 700)],
	"dealer": [Vector2(1634, 985), Vector2(1634, 870)],
	"abandoned": [Vector2(1640, 450), Vector2(1638, 292)],
	"market": [Vector2(1060, 1600), Vector2(1110, 1400)],
	"alley": [Vector2(420, 1590), Vector2(250, 1370)],
	"church": [Vector2(1800, 1630), Vector2(1790, 1470)],
	"projects": [Vector2(420, 1840), Vector2(245, 1700)],
	"underpass": [Vector2(1210, 485), Vector2(1200, 330)],
	"laundromat": [Vector2(1640, 1280), Vector2(1640, 1160)],
	"busstop": [Vector2(1300, 1230), Vector2(1285, 1115)],
	"trainyard": [Vector2(900, 3120), Vector2(800, 2930)],
	"park": [Vector2(2630, 1390), Vector2(2700, 1140)],
	"skidrow": [Vector2(2860, 2210), Vector2(2830, 2030)],
	"oldschool": [Vector2(3770, 840), Vector2(3780, 650)],
	"warehouse_row": [Vector2(4920, 900), Vector2(4700, 480)],
	"canal": [Vector2(5200, 2190), Vector2(4760, 1800)],
	"the_lot": [Vector2(4900, 3350), Vector2(4920, 3140)],
	"blue_tarp_court": [Vector2(6750, 620), Vector2(6820, 450)],
	"cart_cavalry_keep": [Vector2(8060, 1890), Vector2(8120, 1710)],
	"copper_choir_yard": [Vector2(6750, 3220), Vector2(6830, 3020)],
	"throne_ditch": [Vector2(7900, 4570), Vector2(8050, 4380)],
}

var world: Node3D
var camera: Camera3D
var output_dir: String = ""
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var zone_filter: String = ""
var day_only: bool = false
var services_only: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Full-world render probe requires a native rendering device.")
		quit(1)
		return
	output_dir = ProjectSettings.globalize_path("res://../.build/full-port/p04")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_dir = argument.trim_prefix("--output=")
		elif argument.begins_with("--zone="): zone_filter = argument.trim_prefix("--zone=")
		elif argument == "--day-only": day_only = true
		elif argument == "--services-only": services_only = true
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world = World.new()
	root.add_child(world)
	world.build()
	camera = Camera3D.new()
	camera.fov = 76.0
	camera.near = 0.07
	camera.far = 650.0
	root.add_child(camera)
	camera.make_current()
	await process_frame
	await physics_frame
	await create_timer(1.5).timeout
	var phases: Array[String] = ["day"]
	if not day_only: phases.append("night")
	for phase: String in phases:
		world.set_day_time(60.0 if phase == "day" else 180.0)
		if not services_only:
			for raw: Variant in Content.load_content().world.zones:
				var zone: Dictionary = raw
				var id: String = str(zone.id)
				if not zone_filter.is_empty() and zone_filter != id: continue
				if not ZONE_VIEWS.has(id):
					failures.append("Missing curated zone view: " + id)
					continue
				var view: Array = ZONE_VIEWS[id]
				var preferred: Vector3 = Content.to_world(view[0], 0.06)
				var feet: Vector3 = _clear_view_foot(preferred)
				if not feet.is_finite():
					failures.append("No physical camera placement: " + id)
					continue
				var focus: Vector3 = Content.to_world(view[1], 1.40)
				camera.projection = Camera3D.PROJECTION_PERSPECTIVE
				camera.position = feet + Vector3(0, 1.65, 0)
				camera.look_at(focus)
				await _capture("zone_" + id + "_" + phase, {"kind": "zone", "id": id,
					"phase": phase, "preferred_source": _vec2(view[0]), "actual_source": _vec2(Content.to_source(feet)), "camera_clearance": 0.48})
		if zone_filter.is_empty():
			await _service_views(phase)
			if not services_only: await _overhead(phase)
	var report: Dictionary = {"scope": "native full-world geometry only; no NPCs, input/controller, gameplay, AI or save claims",
		"engine": Engine.get_version_info().string, "device": RenderingServer.get_video_adapter_name(),
		"resolution": [1280, 720], "source_corpus": Content.load_content().source.corpusSha256,
		"world_metrics": world.build_metrics, "captures": captures, "failures": failures}
	var file := FileAccess.open(output_dir.path_join("world-render-evidence.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write full-world render evidence manifest")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("FULL WORLD RENDER PROBE: ", "PASS" if failures.is_empty() else "FAIL", "; ", captures.size(), " captures; ", output_dir)
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _clear_view_foot(preferred: Vector3) -> Vector3:
	if world.is_clear_position(preferred): return preferred
	for radius: float in [0.4, 0.8, 1.2, 2.0, 3.0, 5.0]:
		for step: int in range(24):
			var angle: float = step * TAU / 24.0
			var candidate := preferred + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
			if world.is_clear_position(candidate): return candidate
	return Vector3.INF


func _service_views(phase: String) -> void:
	for id: String in ["pete", "tony", "train_hopper", "skid_sherri", "prop:3", "prop:4", "office_objective"]:
		var service: Dictionary = world.service_points[id]
		var feet: Vector3 = service.approach
		if not feet.is_finite() or not world.is_clear_position(feet):
			failures.append("No physical service camera: " + id)
			continue
		var target: Vector3 = service.target
		var heading := Vector3(target.x - feet.x, 0, target.z - feet.z).normalized()
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.position = feet + Vector3(0, 1.65, 0)
		camera.look_at(Vector3(target.x, 1.4, target.z) + heading * 2.0)
		await _capture("service_" + id.replace(":", "_") + "_" + phase,
			{"kind": "service", "id": id, "phase": phase, "source_point": _vec2(service.source_point),
			"actual_source": _vec2(Content.to_source(feet)), "camera_clearance": 0.48})


func _overhead(phase: String) -> void:
	var center := Vector3(130.0, 0, 78.4)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 260.0
	camera.position = center + Vector3(0, 260.0, 0)
	camera.look_at(center, Vector3(0, 0, -1))
	await _capture("world_overhead_" + phase, {"kind": "overview", "phase": phase,
		"source_bounds": [0, 0, 8600, 5600], "metres_per_pixel": 0.04})
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE


func _capture(label: String, metadata: Dictionary) -> void:
	for frame: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var output: String = output_dir.path_join(label + ".png")
	var error: Error = root.get_texture().get_image().save_png(output)
	if error != OK:
		failures.append("Capture failed: " + label + " error " + str(error))
		return
	var entry: Dictionary = metadata.duplicate(true)
	entry["file"] = label + ".png"
	entry["eye_world"] = [camera.position.x, camera.position.y, camera.position.z]
	entry["render_draw_calls_snapshot"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	entry["scope"] = "still-frame geometry evidence; snapshot counters are not a frame-time benchmark"
	captures.append(entry)
	print("FULL WORLD CAPTURE: ", label)


func _vec2(value: Vector2) -> Array[float]:
	return [value.x, value.y]
