extends SceneTree
## Actual FullScene/input/render path; initial staging is visual evidence only.
const Content = preload("res://scripts/content_catalog.gd")
const FullScene = preload("res://scripts/full_scene.gd")
const STEP := 1.0/60.0
const CASES: Array[String] = ["walk_down","blocked_intent","clear_day","clear_night","rain","camera_turn","wall_occlusion","expiry"]
const MAX_WALL_MS := 180000
const MAX_CAPTURES := 90
var game: Node3D
var width: int = 1280
var output: String = ""
var started: int = 0
var finishing: bool = false
var checks: int = 0
var failures: Array[String] = []
var completed: Array[String] = []
var contexts: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var fixture: Dictionary = {}
var eye_shape: SphereShape3D
var visual_ms: float = 713.0
var observer: Variant = null

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		if failures.size() <= 24: push_error("Dust visual: "+label)
	return ok
static func _hash(bytes: PackedByteArray) -> String:
	var hasher := HashingContext.new(); hasher.start(HashingContext.HASH_SHA256); hasher.update(bytes); return hasher.finish().hex_encode()
static func _json(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Color: return [value.r,value.g,value.b,value.a]
	if value is Transform3D: return {"origin":_json(value.origin),"basis":[_json(value.basis.x),_json(value.basis.y),_json(value.basis.z)]}
	if value is Rect2 or value is Rect2i: return {"position":_json(value.position),"size":_json(value.size)}
	if value is AABB: return {"position":_json(value.position),"size":_json(value.size)}
	if value is Array or value is PackedStringArray or value is PackedVector3Array:
		var result: Array = []
		for item: Variant in value: result.append(_json(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = _json(value[key])
		return result
	if value is Object: return "object:"+value.get_class()
	return value
static func pixel_rect(points: Array[Vector2],logical: Vector2,actual: Vector2i) -> Rect2i:
	if points.is_empty() or not logical.is_finite() or logical.x <= 0 or logical.y <= 0 or actual.x <= 0 or actual.y <= 0: return Rect2i()
	var low := Vector2(INF,INF); var high := Vector2(-INF,-INF)
	var scale := Vector2(actual)/logical
	for point: Vector2 in points:
		if not point.is_finite(): return Rect2i()
		low = low.min(point*scale); high = high.max(point*scale)
	var a := Vector2i(floori(low.x)-3,floori(low.y)-3)
	var b := Vector2i(ceili(high.x)+4,ceili(high.y)+4)
	return Rect2i(a,b-a).intersection(Rect2i(Vector2i.ZERO,actual))
static func assess(report: Dictionary) -> bool:
	if report.get("complete") != true or not report.get("failures") is Array or not report.failures.is_empty() or report.get("completed") != CASES: return false
	if not report.get("contexts") is Array or report.contexts.size() != CASES.size() or not report.get("captures") is Array or report.captures.is_empty() or report.captures.size() > MAX_CAPTURES: return false
	if report.get("wall_ms",INF) > MAX_WALL_MS or report.get("width") not in [1280,960] or report.get("height") != int(float(report.width)*9.0/16.0): return false
	for i: int in range(CASES.size()):
		var context: Dictionary = report.contexts[i]
		if context.get("id") != CASES[i] or context.get("end_capture",0) <= context.get("start_capture",0): return false
		if context.get("fixture",{}).get("physics_sentinel",{}).get("ok") != true: return false
		if context.id == "expiry" and (not context.get("survived") is Array or not context.survived.is_empty() or not context.get("tracked") is Array or context.tracked.is_empty() or context.get("admitted_ms",0) < 6000): return false
		if context.id == "wall_occlusion" and (context.get("wall",{}).get("ok") != true or context.get("ablation",{}).get("changed_pixels",-1) != 0): return false
		if context.id in ["walk_down","blocked_intent","clear_day","clear_night","rain"] and context.get("ablation",{}).get("changed_pixels",0) <= 0: return false
	return true
func _release() -> void:
	for action: String in ["forward","back","left","right","sprint"]: Input.action_release(action)
func _args() -> bool:
	if not _check("--qa-full" in OS.get_cmdline_user_args(),"--qa-full required before constructing Scene"): return false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if not _check(width in [1280,960],"finite1280/960 framebuffer selection"): return false
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../dust-visual-"+str(width))
	if output.begins_with("res://") or output.begins_with("user://"): output = ProjectSettings.globalize_path(output)
	if not _check(not FileAccess.file_exists(output.path_join("dust-visual.json")),"fresh evidence destination"): return false
	return _check(DirAccess.make_dir_recursive_absolute(output) == OK,"isolated evidence directory")
func _suspend_callbacks() -> void:
	game.set_process(false); game.set_physics_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	if game.hud != null: game.hud.set_process(false)
func _physics_sentinel() -> Dictionary:
	var attempts: int = 0
	for record: Dictionary in game.world._obstacles:
		var bounds: AABB = record.bounds
		if not str(record.owner).begins_with("structures:") or bounds.size.y < 2 or minf(bounds.size.x,bounds.size.z) > 0.55: continue
		attempts += 1
		if attempts > 16: break
		var center: Vector3 = bounds.get_center()
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = eye_shape; query.transform = Transform3D(Basis.IDENTITY,center); query.collision_mask = 1; query.margin = 0.002
		var overlaps: Array[Dictionary] = game.world.get_world_3d().direct_space_state.intersect_shape(query,8)
		var overlap_ok: bool = false
		for hit: Dictionary in overlaps:
			if hit.get("collider") == record.get("body"): overlap_ok = true
		var axis: int = 0 if bounds.size.x < bounds.size.z else 2
		var from: Vector3 = center; var to: Vector3 = center
		from[axis] = bounds.position[axis]-0.3; to[axis] = bounds.end[axis]+0.3
		var ray: Dictionary = _ray(from,to)
		if overlap_ok and ray.get("collider") == record.get("body"):
			return {"ok":true,"wall":record.owner,"bounds":bounds,"overlap_count":overlaps.size(),"crossing_from":from,"crossing_to":to,"hit":ray.position,"process_mode":game.process_mode,"wall_disable_mode":record.body.disable_mode}
	return {"ok":false,"reason":"existing wall is not live in both overlap and crossing ray","attempts":attempts}
func _body(center: Vector2) -> Dictionary:
	var point: Vector2 = center-Vector2(game.runtime.p.w,game.runtime.p.h)*0.5
	return {"id":"player","x":point.x,"y":point.y,"w":game.runtime.p.w,"h":game.runtime.p.h}
func _place(center: Vector2) -> bool:
	var body: Dictionary = _body(center)
	var clear: Variant = game.physics.clear_placement(body)
	if not clear is Vector2 or clear.distance_to(Vector2(body.x,body.y)) > 0.0001: return false
	game.runtime.p.x = clear.x; game.runtime.p.y = clear.y
	fixture.placements.append({"requested_center":center,"actual_top_left":clear,"proof":"exact current Adapter.clear_placement"})
	game._sync_model_nodes(0.0)
	return true
func _street() -> bool:
	for point: Vector2 in [Vector2(1062,900),Vector2(1150,1100),Vector2(900,1260),Vector2(720,1280),Vector2(1300,1280),Vector2(750,1180)]:
		var body: Dictionary = _body(point)
		var end: Dictionary = game.physics.move_body(body,Vector2(body.x,body.y)+Vector2(0,25))
		if end.get("blocked",true) or end.get("body_contact",true) or not end.get("position") is Vector2 or end.position.distance_to(Vector2(body.x,body.y)+Vector2(0,25)) > 0.01: continue
		if _place(point): return true
	return false
func _blocked_wall() -> Dictionary:
	var seen: int = 0
	for record: Dictionary in game.world._obstacles:
		var bounds: AABB = record.bounds
		if not str(record.owner).begins_with("structures:") or bounds.size.y < 2 or minf(bounds.size.x,bounds.size.z) > 0.55 or maxf(bounds.size.x,bounds.size.z) < 2: continue
		if bounds.get_center().distance_to(Content.to_world(Vector2(1062,900),1)) > 24.0: continue
		seen += 1
		if seen > 24: break
		var axis: int = 0 if bounds.size.x < bounds.size.z else 2
		for sign_value: float in [-1.0,1.0]:
			var point: Vector3 = bounds.get_center(); point.y = 0.06
			point[axis] = (bounds.position[axis] if sign_value < 0 else bounds.end[axis])+sign_value*0.49
			var center: Vector2 = Content.to_source(point); var body: Dictionary = _body(center)
			var forward := Vector2(-sign_value,0) if axis == 0 else Vector2(0,-sign_value)
			var result: Dictionary = game.physics.move_body(body,Vector2(body.x,body.y)+forward*25.0,null,true)
			if not result.get("blocked",false) or not _place(center): continue
			game.player.rotation.y = atan2(-forward.x,-forward.y)
			return {"owner":record.owner,"bounds":bounds,"forward":forward,"initial_sweep":result,"center":center}
	return {}
func _fresh(id: String) -> bool:
	_release(); observer = null
	fixture = {"id":id,"scope":"explicit visual initial fixture; not earned progression","placements":[],"fields":{},"control":"actual InputMap forward plus source uncaptured right-drag path"}
	if not _check(game.runtime.fresh(),id+" real fresh epoch"): return false
	game._reset_presentation(); game._sync_model_nodes(0.0); game._resume(); game._consume_events()
	var night: bool = id == "clear_night"
	game.runtime.s.dayTime = 0.78 if night else 0.55
	game.runtime.s.weather = "rain" if id == "rain" else "clear"
	fixture.fields = {"s.dayTime":game.runtime.s.dayTime,"s.weather":game.runtime.s.weather}
	game.physics.invalidate_placement_cache()
	await physics_frame
	fixture.physics_sentinel = _physics_sentinel()
	if not _check(fixture.physics_sentinel.ok,id+" live existing wall overlap/ray sentinel"): return false
	if not _check(_street(),id+" actual unobstructed street placement"): return false
	game.player.rotation.y = PI
	game.pitch = -1.15 if id in ["walk_down","blocked_intent","expiry"] else (-0.60 if id == "wall_occlusion" else -0.04)
	game._sync_player(); game._sync_feedback_context()
	fixture.camera = game.camera.global_transform
	return true
func _advance(milliseconds: float,walking: bool = false) -> float:
	observer = null
	if walking: Input.action_press("forward",1.0)
	else: _release()
	var admitted: float = 0.0; var attempts: int = 0
	while admitted+0.001 < milliseconds and attempts < 420 and not finishing:
		attempts += 1
		game._process(STEP)
		admitted += game.runtime.last_advanced_ms
		await physics_frame
		if game.runtime.s.mode != "playing": break
	_release()
	_check(admitted+0.001 >= milliseconds,"actual Scene admitted active interval "+str(milliseconds))
	return admitted
func _paint() -> void:
	var rng: int = game.runtime.state.rng_seed
	game._sync_model_nodes(0.0)
	if observer is Transform3D: game.camera.global_transform = observer
	game._sync_feedback_context()
	game.weather_view.sync({"dayTime":game.runtime.s.dayTime,"weather":game.runtime.s.weather,"office_generator":false,"geometry_revision":game.physics._collision_revision},visual_ms)
	game._sync_dynamic_emitters(visual_ms)
	game.hud.update_runtime(game.runtime); game.hud.update_actor_hud(visual_ms)
	game._sync_world_feedback(visual_ms)
	_check(game.runtime.state.rng_seed == rng,"passive paint leaves gameplay RNG unchanged")
func _rows(recipe: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in game.runtime.feedback_snapshot().particles:
		if row.recipe == recipe: result.append(row)
	return result
static func row_point(row: Dictionary) -> Vector3:
	return row.world_anchor+row.birth_right*float(row.offset.x)*0.04-Vector3.UP*float(row.offset.y)*0.04
func _vertices(row: Dictionary) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var key: String = str(row.shape)+("_add" if row.glow else "_mix")
	var bank: MultiMeshInstance3D = game.feedback_view._banks[key]
	var raw: PackedVector3Array = bank.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Read the real submitted transform, including newer birth-static art roll.
	# Renderer-only probe: the dummy headless backend cannot certify this readback.
	var bank_index: int = 0; var found: bool = false
	for current: Dictionary in game.runtime.feedback_snapshot().particles:
		var current_key: String = str(current.shape)+("_add" if current.glow else "_mix")
		if current_key != key: continue
		if current.serial == row.serial: found = true; break
		bank_index += 1
	if not _check(found and bank_index < bank.multimesh.visible_instance_count,"actual visible bank index for serial "+str(row.serial)): return result
	var pose: Transform3D = bank.multimesh.get_instance_transform(bank_index)
	if not _check(pose.is_finite() and raw.size() >= 3,"actual rendered particle transform/mesh vertices"): return result
	for point: Vector3 in raw: result.append(bank.global_transform*(pose*point))
	return result
func _projection(row: Dictionary) -> Dictionary:
	var points: Array[Vector2] = []
	var vertices: Array[Vector3] = _vertices(row)
	var front: bool = not vertices.is_empty()
	for point: Vector3 in vertices:
		front = front and not game.camera.is_position_behind(point)
		points.append(game.camera.unproject_position(point))
	return {"serial":row.serial,"recipe":row.recipe,"world_anchor":row.world_anchor,"world_point":row_point(row),"front":front,"pixels":pixel_rect(points,root.get_visible_rect().size,Vector2i(width,int(width*9/16)))}
func _capture(id: String,extra: Dictionary = {},show_feedback: bool = true) -> Dictionary:
	if finishing or not _check(captures.size() < MAX_CAPTURES,"hard90 capture limit"): return {}
	_paint(); game.feedback_view.visible = show_feedback
	var pool: Dictionary = game.runtime.feedback_snapshot(); var rng: int = game.runtime.state.rng_seed; var eye: Transform3D = game.camera.global_transform
	await process_frame; await RenderingServer.frame_post_draw
	await process_frame; await RenderingServer.frame_post_draw
	if finishing: return {}
	_check(pool == game.runtime.feedback_snapshot() and rng == game.runtime.state.rng_seed and eye == game.camera.global_transform,"frozen source/camera/RNG during capture "+id)
	var image: Image = root.get_texture().get_image()
	_check(image.get_size() == Vector2i(width,int(width*9/16)),"actual framebuffer dimensions "+id)
	var path: String = output.path_join(id+".png")
	_check(image.save_png(path) == OK,"raw framebuffer PNG "+id)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var view: Dictionary = game.feedback_view.inspect()
	_check(view.live == pool.particles.size() and view.live <= 220 and view.triangles <= 880 and view.banks == 4,"same bounded actual passive banks "+id)
	var projected: Array[Dictionary] = []
	for row: Dictionary in pool.particles: projected.append(_projection(row))
	var evidence := {"file":id+".png","sha256":_hash(bytes),"png_bytes":bytes.size(),"framebuffer":image.get_size(),"camera":eye,"player_center":game.runtime.state.player_center(),"pool":pool,"dust":game.runtime.world_dust.inspect(),"view":view,"projected":projected,"feedback_visible":show_feedback,"details":extra}
	captures.append(evidence); _publish_frame(id,evidence,bytes)
	game.feedback_view.visible = true
	return {"image":image,"evidence":evidence}
func _publish_frame(_id: String,_evidence: Dictionary,_bytes: PackedByteArray) -> void: pass
func _publish_report(_report: Dictionary,_text: String,_sha256: String) -> void: pass
static func pixel_changes(a: Image,b: Image,rect: Rect2i) -> int:
	if a == null or b == null or a.get_size() != b.get_size(): return -1
	var clipped: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO,a.get_size()))
	var changed: int = 0
	for y: int in range(clipped.position.y,clipped.end.y):
		for x: int in range(clipped.position.x,clipped.end.x):
			if a.get_pixel(x,y) != b.get_pixel(x,y): changed += 1
	return changed
func _ablation(id: String,occluded: bool = false,region: Rect2i = Rect2i()) -> Dictionary:
	var shown: Dictionary = await _capture(id+"-shown",{},true)
	var hidden: Dictionary = await _capture(id+"-hidden",{},false)
	if shown.is_empty() or hidden.is_empty(): return {}
	if region.size == Vector2i.ZERO: region = Rect2i(0,int(width*0.15),width,int(width*9/16)-int(width*0.15))
	var changed: int = pixel_changes(shown.image,hidden.image,region)
	_check(changed == 0 if occluded else changed > 0,id+" "+("fully wall-hidden particle region is unchanged" if occluded else "actual passive geometry changes world pixels"))
	return {"region":region,"changed_pixels":changed,"expected_occluded":occluded,"shown":shown.evidence.file,"hidden":hidden.evidence.file}
func _eye_clear(eye: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = eye_shape; query.transform = Transform3D(Basis.IDENTITY,eye); query.margin = 0.002; query.collision_mask = 1
	if not game.world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	for body: Node3D in game.actors.values():
		if body.is_visible_in_tree() and eye.distance_to(body.global_position+Vector3.UP*0.95) < 0.65: return false
	return true
func _ray(a: Vector3,b: Vector3) -> Dictionary:
	return game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
static func wall_candidates(records: Array,point: Vector3) -> Dictionary:
	var stats := {"records":records.size(),"structure_walls":0,"vertical_matches":0,"candidates":[],"candidate_count":0}
	for record: Dictionary in records:
		var bounds: AABB = record.bounds
		if not str(record.owner).begins_with("structures:") or bounds.size.y < 2 or minf(bounds.size.x,bounds.size.z) > 0.55 or maxf(bounds.size.x,bounds.size.z) < 0.8: continue
		stats.structure_walls += 1
		if point.y <= bounds.position.y+0.15 or point.y >= bounds.end.y-0.15: continue
		stats.vertical_matches += 1
		stats.candidates.append({"owner":record.owner,"bounds":bounds,"distance":bounds.get_center().distance_to(point)})
	stats.candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.distance < b.distance)
	stats.candidate_count = stats.candidates.size()
	stats.candidates = stats.candidates.slice(0,16)
	return stats
func _wall_observer(row: Dictionary) -> Dictionary:
	var point: Vector3 = row_point(row); var vertices: Array[Vector3] = _vertices(row)
	if vertices.size() < 3: return {"ok":false,"reason":"actual displayed vertices unavailable"}
	var census: Dictionary = wall_candidates(game.world._obstacles,point)
	var nearby: Array = census.candidates
	var attempts: Array[Dictionary] = []
	for wall: Dictionary in nearby.slice(0,16):
		var bounds: AABB = wall.bounds; var axis: int = 0 if bounds.size.x < bounds.size.z else 2; var along: int = 2 if axis == 0 else 0
		var side: float = -1.0 if point[axis] >= bounds.get_center()[axis] else 1.0
		for clearance: float in [0.35,0.75]:
			var eye: Vector3 = point; eye[axis] = (bounds.position[axis] if side < 0 else bounds.end[axis])+side*clearance
			eye[along] = clampf(point[along],bounds.position[along]+0.2,bounds.end[along]-0.2)
			var ok: bool = _eye_clear(eye); var hits: Array[Dictionary] = []
			if ok:
				for vertex: Vector3 in vertices:
					var hit: Dictionary = _ray(eye,vertex)
					var owner: String = str(hit.collider.get_meta("source_owner","")) if hit.get("collider") is Node else ""
					var blocks: bool = not hit.is_empty() and owner.begins_with("structures:") and absf(float(hit.get("normal",Vector3.UP).y)) < 0.2 and eye.distance_to(hit.position)+0.001 < eye.distance_to(vertex)
					hits.append({"wall":owner,"position":hit.get("position"),"target":vertex,"blocked":blocks})
					ok = ok and blocks
			var trial := {"eye":eye,"wall":wall.owner,"distance":wall.distance,"ok":ok,"reason":"certified" if ok else ("eye blocked by current physical geometry or visible actor" if hits.is_empty() else "one or more displayed vertices lack a nearer vertical structure-wall hit"),"vertex_rays":hits}; attempts.append(trial)
			if ok:
				observer = Transform3D(Basis.looking_at(point-eye,Vector3.UP),eye); game.camera.global_transform = observer
				return {"ok":true,"census":census,"attempts":attempts,"selected":trial,"projection":_projection(row)}
	return {"ok":false,"census":census,"attempts":attempts,"reason":"nearest16 real walls exhausted; particle was not relocated"}
func _case(id: String) -> void:
	var initial_capture: int = captures.size()
	if not await _fresh(id):
		contexts.append({"id":id,"fixture":fixture,"status":"fresh_failed","start_capture":initial_capture,"end_capture":captures.size()}); return
	var context := {"id":id,"fixture":fixture,"status":"pending","admitted_ms":0.0,"start_capture":initial_capture,"end_capture":captures.size()}
	contexts.append(context)
	if id == "blocked_intent":
		var wall: Dictionary = _blocked_wall(); context.wall = wall
		if not _check(not wall.is_empty(),"real wall/capsule fixture"): return
		game.pitch = -1.15; game._sync_player(); game._sync_feedback_context()
		var before: Vector2 = game.runtime.state.player_center()
		context.admitted_ms = await _advance(400,true)
		context.displacement_m = before.distance_to(game.runtime.state.player_center())*0.04
		_check(context.displacement_m < 0.15 and game.runtime.world_dust.inspect().walk_births > 0,"blocked actual intent still emits without walking through wall")
		context.ablation = await _ablation(id)
	elif id in ["walk_down","clear_day","clear_night","rain"]:
		var walking: bool = id == "walk_down"; var before: Vector2 = game.runtime.state.player_center()
		context.admitted_ms = await _advance(400 if walking else 3000,walking)
		context.displacement_m = before.distance_to(game.runtime.state.player_center())*0.04
		var dust: Dictionary = game.runtime.world_dust.inspect()
		_check(dust.walk_births > 0 and context.displacement_m > 0.5 if walking else dust.walk_births == 0 and dust.ambient_births >= 4 and context.displacement_m < 0.0001,id+" exact movement/idle scheduler path")
		var color := Color(180.0/255,200.0/255,220.0/255,0.6) if id == "rain" else Color(232.0/255,210.0/255,160.0/255,0.32)
		for row: Dictionary in _rows("ambient_mote"): _check(row.color.is_equal_approx(color),id+" literal ambient color")
		context.ablation = await _ablation(id)
	elif id == "camera_turn":
		context.admitted_ms = await _advance(1)
		var before: Dictionary = game.runtime.feedback_snapshot(); var rng: int = game.runtime.state.rng_seed
		await _capture(id+"-before")
		var motion := InputEventMouseMotion.new(); motion.relative = Vector2(-PI*0.5/0.0022,0); motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
		game._unhandled_input(motion)
		await _capture(id+"-after")
		_check(before == game.runtime.feedback_snapshot() and rng == game.runtime.state.rng_seed,"source camera turn freezes born particle data and gameplay RNG")
		_check(captures[-1].camera != captures[-2].camera,"actual source right-drag changes camera view")
		context.frozen_serials = before.particles.map(func(row: Dictionary): return row.serial)
	elif id == "wall_occlusion":
		context.admitted_ms = await _advance(1)
		var rows: Array[Dictionary] = _rows("ambient_mote")
		if not _check(rows.size() == 1 and game.runtime.feedback_snapshot().particles.size() == 1,"single real initial mote for isolated occlusion"): return
		await _capture(id+"-birth")
		context.wall = _wall_observer(rows[0]); context.end_capture = captures.size(); context.status = "wall_search_failed" if not context.wall.ok else "wall_certified"
		if not _check(context.wall.ok,"live wall blocks every actual mote vertex from clear eye"): return
		var region: Rect2i = context.wall.projection.pixels
		if not _check(region.size.x > 0 and region.size.y > 0 and context.wall.projection.front,"occluded actual particle projects inside framebuffer"): return
		context.ablation = await _ablation(id,true,region)
	else:
		context.admitted_ms = await _advance(150,true)
		var original: Dictionary = game.runtime.feedback_snapshot(); var ids: Dictionary = {}; var kinds: Dictionary = {}
		for row: Dictionary in original.particles: ids[row.serial] = true; kinds[row.recipe] = true
		_check(kinds.has("walking_dust") and kinds.has("ambient_mote"),"expiry starts with both real named recipes")
		await _capture(id+"-birth")
		context.admitted_ms += await _advance(6150)
		var survived: Array = []
		for row: Dictionary in game.runtime.feedback_snapshot().particles:
			if ids.has(row.serial): survived.append(row.serial)
		_check(survived.is_empty(),"all tracked original births expire via real particle pass")
		context.tracked = ids.keys(); context.survived = survived
		await _capture(id+"-expired",{"new_motes_are_allowed":true,"tracked_serials":ids.keys()})
	context.end_capture = captures.size(); context.status = "complete"; context.final_dust = game.runtime.world_dust.inspect(); completed.append(id)
func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["scripts/full_scene.gd","scripts/full_runtime.gd","scripts/world_dust.gd","scripts/world_feedback.gd","scripts/world_feedback_view.gd","tests/world_dust_visual_probe.gd","tests/web_dust_visual_probe.gd","data/source_content.json"]:
		result[path] = FileAccess.get_sha256("res://"+path) if FileAccess.file_exists("res://"+path) else ""
	return result
func _finish(complete: bool) -> void:
	if finishing: return
	finishing = true; _release()
	if game != null: _suspend_callbacks()
	var hashes: Dictionary = _source_hashes(); var unavailable: Array[String] = []
	for path: String in hashes:
		if str(hashes[path]).is_empty(): unavailable.append(path)
	var report := {"schema":1,"format":"rock-bottom-world-dust-visual","packet":"dust","complete":complete,"finished":true,"width":width,"height":int(width*9/16),"wall_ms":Time.get_ticks_msec()-started,"checks":checks,"failures":failures,"completed":completed,"contexts":contexts,"captures":captures,"source_hashes":hashes,"unavailable_source_hashes":unavailable,"source_hash_note":"Compiled scripts may be unavailable; retain external source and pack hashes.","scope":"staged actual FullScene input/render receipts only; no campaign/performance acceptance","visual_review_required":true,"visual_acceptance":false,"web":OS.has_feature("web"),"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string}
	report.acceptance = assess(report)
	var text: String = JSON.stringify(_json(report),"\t")+"\n"; var digest: String = _hash(text.to_utf8_buffer())
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("dust-visual.json"),FileAccess.WRITE)
		if file != null: file.store_string(text); file.close()
		var hash_file := FileAccess.open(output.path_join("dust-visual.sha256"),FileAccess.WRITE)
		if hash_file != null: hash_file.store_string(digest+"  dust-visual.json\n"); hash_file.close()
	_publish_report(report,text,digest)
	print("ACTUAL FULLSCENE DUST VISUAL: ","PASS" if report.acceptance else "FAIL","; ",checks," checks; ",completed.size()," contexts; ",captures.size()," captures; human visual review pending")
	if OS.has_feature("web"): return
	if game != null: game.queue_free()
	await process_frame
	quit(0 if report.acceptance else 1)
func _timeout() -> void:
	if finishing: return
	_check(false,"global180s wall limit including startup; incomplete run fails")
	_finish(false)
func _run() -> void:
	started = Time.get_ticks_msec()
	if not _args(): await _finish(false); return
	if not _check(DisplayServer.get_name() != "headless","real renderer required"): await _finish(false); return
	root.size = Vector2i(width,int(width*9/16)); root.content_scale_size = Vector2i(1280,720); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	create_timer(float(MAX_WALL_MS)/1000.0).timeout.connect(_timeout)
	eye_shape = SphereShape3D.new(); eye_shape.radius = 0.06
	game = FullScene.new(); root.add_child(game)
	while not game.ready_for_play and Time.get_ticks_msec()-started < 90000 and not finishing: await process_frame
	if finishing: return
	if not _check(game.ready_for_play,"actual FullScene startup within90s"): await _finish(false); return
	_suspend_callbacks()
	game.store.save_path = output.path_join("visual-only-save.json"); game.store.storage_key = "world_dust_visual_fixture"
	game.sound.muted = true; game.web_controls = true; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for id: String in CASES:
		if finishing: return
		await _case(id)
	_check(completed == CASES and contexts.size() == CASES.size(),"all eight contexts complete in canonical order")
	await _finish(true)
