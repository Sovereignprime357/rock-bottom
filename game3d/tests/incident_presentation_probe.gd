extends SceneTree
## Native original incident art/clearance evidence; does not activate FullRuntime.
const World = preload("res://scripts/full_neighborhood.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const State = preload("res://scripts/game_state.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Incidents = preload("res://scripts/incident_system.gd")
const Presentation = preload("res://scripts/incident_presentation.gd")
const Comms = preload("res://scripts/communications_system.gd")
const Props = preload("res://scripts/prop_state.gd")
const Roster = preload("res://scripts/character_roster.gd")
const PathMap = preload("res://scripts/incident_path_map.gd")
const STARTS := {"runaway_mattress":Vector2(1080,960),"possum_inventory":Vector2(1080,1510),"laundromat_walkout":Vector2(1640,1200),"yuri_receipt":Vector2(400,300),"park_dry_committee":Vector2(2600,1280),"ticketed_luggage":Vector2(800,2985)}
var world: Node3D
var adapter: RefCounted
var state: RefCounted
var incidents: RefCounted
var presentation: Node3D
var props: RefCounted
var comms: RefCounted
var paths: RefCounted
var camera: Camera3D
var receipt: Label
var output: String
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var samples: Dictionary = {}
var diagnostic: bool = false
func _initialize() -> void: call_deferred("_run")
func _unix() -> float: return 1763424000000.0
func _start(id: String) -> void:
	state.p.x = STARTS[id].x-state.p.w*0.5; state.p.y = STARTS[id].y-state.p.h*0.5
	state.s.incident = null; incidents._start(id); state.p.x = 8490; state.p.y = 5490
func _view(ms: float) -> Dictionary:
	state.s.incident.t = ms; incidents._update_active(state.s.incident)
	return incidents.visual_snapshot()
func _focus(view: Dictionary) -> Vector3:
	var active: Dictionary = view.active
	if Presentation.ENVELOPES.has(active.id): return Content.to_world(Presentation.display_point(active),0.75)
	var anchor: Dictionary = active.anchor
	if active.id == "yuri_receipt": return Content.to_world(Vector2(lerpf(anchor.x,anchor.tx,0.5),lerpf(anchor.y,anchor.ty,0.5)),1.65)
	return Content.to_world(Vector2(anchor.x,anchor.y),0.70)
func _set_camera(view: Dictionary) -> bool:
	var target: Vector3 = _focus(view); var distances: Array[float] = [3.8,2.8,5.0,2.2,6.0]
	if view.active.id == "yuri_receipt": distances = [8.0,6.0,10.0,4.0]
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for radius: float in distances:
		for step: int in range(24):
			var angle: float = step*TAU/24.0
			var foot: Vector3 = Vector3(target.x,0.06,target.z)+Vector3(sin(angle),0,cos(angle))*radius
			if not world.is_clear_position(foot,0.486): continue
			var eye: Vector3 = foot+Vector3.UP*1.65
			var query := PhysicsRayQueryParameters3D.create(eye,target,1)
			if not space.intersect_ray(query).is_empty(): continue
			camera.position = eye; camera.look_at(target); return true
	return false
func _capture(id: String,beat: int,phase: String,view: Dictionary) -> void:
	if not presentation.sync(view,float(view.active.t)): failures.append("sync refused "+id); return
	if not _set_camera(view): failures.append("No physically clear camera/eye ray "+id+" beat"+str(beat)); return
	receipt.text = str(incidents.definitions[id].beats[beat][1])
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var path: String = output.path_join("%s_beat%d_%s.png" % [id,beat,phase])
	var error: Error = root.get_texture().get_image().save_png(path)
	if error != OK: failures.append("Capture failed "+path)
	captures.append({"id":id,"beat":beat,"phase":phase,"source_ms":view.active.t,"receipt":receipt.text,"file":path,"camera_source":Content.to_source(camera.position),"eye_height":camera.position.y,"focus":_focus(view),"geometry":presentation.inspect(view)})
func _percentile(values: Array[float],fraction: float) -> float:
	if values.is_empty(): return 0.0
	var sorted: Array[float] = values.duplicate(); sorted.sort(); return sorted[mini(sorted.size()-1,int(ceil(sorted.size()*fraction))-1)]
func _profile(id: String) -> void:
	var elapsed: Array[float] = []; var engine: Array[float] = []; var draws: Array[float] = []
	for frame: int in range(150):
		var view: Dictionary = _view(14500+frame*16.6666667)
		var started: int = Time.get_ticks_usec(); presentation.sync(view,float(view.active.t)); var duration: float = float(Time.get_ticks_usec()-started)
		await process_frame
		if frame >= 30:
			elapsed.append(duration); engine.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0); draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	samples[id] = {"frames":elapsed.size(),"sync_p95_us":_percentile(elapsed,0.95),"sync_max_us":elapsed.max(),"engine_process_p95_ms":_percentile(engine,0.95),"draw_calls_p95":_percentile(draws,0.95),"scope":"quiet world+one incident; not60actor Runtime/GPU/Web acceptance"}
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Incident art probe requires a native renderer"); quit(1); return
	output = ProjectSettings.globalize_path("res://../.build/full-port/p14c/native")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument == "--diagnostic": diagnostic = true
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps = 60
	state = State.new(); props = Props.new(state); comms = Comms.new(state,props,_unix)
	world = World.new(); root.add_child(world); world.build(); adapter = Adapter.new(world,state)
	incidents = Incidents.new(state,adapter,comms); presentation = Presentation.new(); root.add_child(presentation); presentation.build(world)
	# Existing canonical witnesses provide the source beat0 context. They are
	# unregistered display instances in this isolated probe, not appended model NPCs.
	for actor: Dictionary in state.npcs:
		if actor.get("id") not in ["yuri","brutus","barb","possum","conductor"]: continue
		var visual: StringName = Roster.visual_for_actor(actor)
		var rig: Node3D = Roster.create(visual,17)
		if rig != null: world.add_child(rig); rig.position = Content.body_position(actor,0.06)
	camera = Camera3D.new(); root.add_child(camera); camera.fov = 76; camera.near = 0.07; camera.far = 500; camera.make_current()
	var canvas := CanvasLayer.new(); root.add_child(canvas)
	var backing := ColorRect.new(); backing.color = Color(0.075,0.085,0.067,0.94); backing.position = Vector2(200,605); backing.size = Vector2(880,90); canvas.add_child(backing)
	receipt = Label.new(); receipt.position = Vector2(215,616); receipt.size = Vector2(850,70); receipt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; receipt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	receipt.add_theme_color_override("font_color",Color("d4c896")); receipt.add_theme_font_size_override("font_size",25); canvas.add_child(receipt)
	state.s.mode = "playing"
	await physics_frame; await physics_frame; await create_timer(1.0).timeout
	paths = PathMap.new(); var path_report: Dictionary = paths.build(world)
	if not path_report.ok or not incidents.bind_path_owner(paths): failures.append("Static28-road mapping not ready: "+str(path_report.get("failures",[])))
	world.set_day_time(60.0)
	for id: String in Incidents.IDS:
		_start(id)
		for beat: int in range(4):
			var ms: float = float(incidents.definitions[id].beats[beat][0])+100.0
			await _capture(id,beat,"day",_view(ms))
		await _profile(id)
	world.set_day_time(180.0)
	for id: String in Incidents.IDS:
		_start(id); await _capture(id,2,"night",_view(float(incidents.definitions[id].beats[2][0])+100.0))
	if captures.size() != 30: failures.append("Expected24 day beat views plus6 night views")
	var geometry_failures: int = 0
	for capture: Dictionary in captures:
		if not capture.geometry.ok: geometry_failures += 1
	if geometry_failures > 0: failures.append("Actual collider intersections in%d captures; see geometry records" % geometry_failures)
	var report := {"scope":"original incident banks/actual-world native evidence; Runtime OFF; no live NPC/combat/Web claim","acceptance":failures.is_empty(),"diagnostic":diagnostic,"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"captures":captures,"samples":samples,"presentation":presentation.metrics(),"path_map":path_report,"failures":failures}
	var file := FileAccess.open(output.path_join("incident-native.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
	else: failures.append("Cannot write native manifest")
	for failure: String in failures: push_error(failure)
	print("3D INCIDENT NATIVE PROBE: %s (%d captures; Runtime OFF)" % ["PASS" if failures.is_empty() else "FAIL",captures.size()])
	world.free(); presentation.free(); quit(0 if failures.is_empty() or diagnostic else 1)
