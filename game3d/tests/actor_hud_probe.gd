extends SceneTree
## Native display evidence with explicitly staged source facts. Not a fight/gameplay test.
const Scene = preload("res://scripts/full_scene.gd")
const Content = preload("res://scripts/content_catalog.gd")
class MemoryStore:
	extends "res://scripts/save_store.gd"
	func write_save(_data: Dictionary) -> bool: return true
	func read_save() -> Dictionary: return {}
var game: Node3D
var output: String
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var baseline: Array[Dictionary] = []
func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failures.append(label); push_error(label)
	return ok
func _npc(id: String) -> Dictionary:
	for record: Dictionary in game.runtime.state.npcs:
		if record.id == id: return record
	return {}
func _reset_facts() -> void:
	game.runtime.state.npcs.assign(baseline.duplicate(true))
	game.runtime.p.hp = 100.0; game.runtime.p.stunT = 0.0; game.runtime.p.slowT = 0.0; game.runtime.p.shakes = 0.0
	game.runtime.s.bossActive = false; game.runtime.s.bossNPC = null; game.runtime.s.bossKind = null; game.runtime.s.combo = 0; game.runtime.s.comboT = 0
	game.runtime.s.mode = "playing"; game.runtime.s.dayTime = .35; game.runtime.s.metVendors.erase("tony")
	game.hud.modal.hide(); game.hud.receipt.text = ""; game.hud.prompt.text = ""
	game._sync_model_nodes(0.016)
func _camera_at_actor(id: String) -> bool:
	var head: Vector3 = game._actor_hud_anchor(id)
	var service: Dictionary = game.world.service_points.get(id,{})
	if not head.is_finite() or service.is_empty(): return false
	var away: Vector3 = service.approach-Vector3(head.x,service.approach.y,head.z); away.y = 0
	if away.length_squared() < .01: away = Vector3(0,0,1)
	away = away.normalized()
	for distance: float in [1.0,2.0,.0,3.0]:
		var foot: Vector3 = service.approach+away*distance
		if not game.world.is_clear_position(foot,.486): continue
		var eye: Vector3 = foot+Vector3.UP*1.63
		var ray := PhysicsRayQueryParameters3D.create(eye,head,1)
		if not game.world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		var center: Vector2 = Content.to_source(foot)
		game.runtime.p.x = center.x-game.runtime.p.w*.5; game.runtime.p.y = center.y-game.runtime.p.h*.5
		game._sync_player(); game.player.rotation = Vector3.ZERO
		game.camera.global_position = eye; game.camera.look_at(head-Vector3.UP*.25)
		return true
	return false
func _drawn(id: String,report: Dictionary) -> bool:
	for cluster: Dictionary in report.clusters:
		if cluster.facts.id == id: return true
	return false
func _capture(label: String,context: Dictionary = {}) -> Dictionary:
	game.hud.update_runtime(game.runtime)
	game.hud.update_actor_hud(1000.0)
	var before := {"p":game.runtime.p.duplicate(true),"s":game.runtime.s.duplicate(true),"actors":game.runtime.state.npcs.duplicate(true),"rng":game.runtime.state.rng_seed}
	await process_frame; await RenderingServer.frame_post_draw
	var report: Dictionary = game.hud.actor_overlay.inspect()
	_require({"p":game.runtime.p,"s":game.runtime.s,"actors":game.runtime.state.npcs,"rng":game.runtime.state.rng_seed} == before,"render only, no gameplay mutation: "+label)
	_require(report.counters.rays <= 64 and report.counters.max_layout_attempts <= 8,"bounded display work: "+label)
	var bounds: Rect2 = root.get_visible_rect(); var occupied: Array[Rect2] = game.hud.actor_hud_occupied_rects()
	for cluster: Dictionary in report.clusters:
		_require(bounds.encloses(cluster.rect),"native cluster inside viewport: "+label+":"+cluster.facts.id)
		for drawn: Rect2 in cluster.geometry.draw_bounds: _require(Rect2(Vector2.ZERO,cluster.rect.size).encloses(drawn),"native measured drawn union fits reported cluster: "+label+":"+cluster.facts.id)
		for other: Rect2 in occupied: _require(not cluster.rect.intersects(other),"native label clear of actual HUD: "+label+":"+cluster.facts.id)
	var file: String = label+".png"
	_require(root.get_texture().get_image().save_png(output.path_join(file)) == OK,"write "+file)
	captures.append({"file":file,"viewport":root.size,"camera":game.camera.global_transform,"fov":game.camera.fov,"context":context,"display":report,"scope":"QA-staged source display facts, original actual FullScene rigs/world and live layer1 rays; no gameplay/fight/performance acceptance"})
	return report
func _staged_crowd() -> int:
	var selected: Array[String] = ["tony","yuri","pete","barb","stripe","conductor","math","pinky"]
	var origin: Vector3 = game.world.service_points["smoke:block"].approach
	var points: Array[Vector3] = []
	for z: int in range(-3,4):
		for x: int in range(-3,4):
			var point: Vector3 = origin+Vector3(x*1.65,0,z*1.65)
			if game.world.is_clear_position(point,.6): points.append(point)
	if points.size() < selected.size(): return 0
	for index: int in range(selected.size()):
		var record: Dictionary = _npc(selected[index]); var point: Vector2 = Content.to_source(points[index])
		record.x = point.x-record.w*.5; record.y = point.y-record.h*.5; record.vendor = true; record.hp = record.maxHp*.5; record.showHp = true
	game._sync_model_nodes(0.016)
	var center: Vector3 = Vector3.ZERO
	for index: int in range(selected.size()): center += points[index]
	center /= selected.size()
	for offset: Vector3 in [Vector3(0,0,8),Vector3(8,0,0),Vector3(0,0,-8),Vector3(-8,0,0)]:
		var eye: Vector3 = center+offset+Vector3.UP*1.63
		if not game.world.is_clear_position(eye-Vector3.UP*1.63,.486): continue
		var point: Vector2 = Content.to_source(eye)
		game.runtime.p.x = point.x-game.runtime.p.w*.5; game.runtime.p.y = point.y-game.runtime.p.h*.5
		game._sync_player(); game.player.rotation = Vector3.ZERO; game.camera.global_position = eye; game.camera.look_at(center+Vector3.UP*1.5)
		return selected.size()
	return 0
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Actor HUD evidence requires native rendering."); quit(1); return
	output = ProjectSettings.globalize_path("res://../.build/full-port/p15b")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not _require(DirAccess.make_dir_recursive_absolute(output) == OK,"create capture directory"): quit(1); return
	root.size = Vector2i(1280,720)
	game = Scene.new(); root.add_child(game); game.qa_mode = true
	for frame: int in range(900):
		await process_frame
		if game.ready_for_play: break
	if not _require(game.ready_for_play,"actual full scene ready"): game.free(); quit(1); return
	game.set_process(false); game.qa_mode = true; game.store.free(); game.store = MemoryStore.new(); game.add_child(game.store)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; baseline.assign(game.runtime.state.npcs.duplicate(true))
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions; await process_frame; await process_frame
		var suffix: String = "_%dx%d"%[dimensions.x,dimensions.y]
		_reset_facts(); await physics_frame; await physics_frame
		if not _require(_camera_at_actor("tony"),"clear physical Tony camera"): break
		var report: Dictionary = await _capture("neutral_vendor"+suffix)
		_require(_drawn("tony",report),"Tony name/floater actually drawn "+suffix)
		var tony: Dictionary = _npc("tony"); tony.hp = tony.maxHp*.5; tony.showHp = true; tony.aggro = true; tony.chargeState = "windup"; tony.chatter = "the copper sings in b flat."; tony.chatterT = 5000.0
		report = await _capture("aggro_windup_chatter"+suffix,{"staged_actor":"tony","hp_ratio":.5,"chargeState":"windup","chatter":tony.chatter})
		_require(_drawn("tony",report),"source damage/windup/chatter cluster drawn "+suffix)
		var damage_bar: bool = false
		for cluster: Dictionary in report.clusters:
			if cluster.facts.id == "tony": damage_bar = not cluster.facts.hp.is_empty() and cluster.facts.hp.ratio == .5 and cluster.facts.hp.color == "#e8c040"
		_require(damage_bar,"actual source showHp bar, half-health ratio and gold threshold drawn "+suffix)
		tony.chargeState = "cooldown"; tony.aimingThrow = true; tony.radioVisualT = 1000.0; tony.grabFreezeT = 1000.0
		await _capture("independent_cues"+suffix,{"explicit_QA_composition":true,"fields":["cooldown","aimingThrow","radioVisualT","grabFreezeT"]})
		game.runtime.p.hp = 22.0; game.runtime.p.stunT = 1000.0; game.runtime.p.slowT = 1000.0; game.runtime.p.shakes = 95.0
		game.runtime.s.combo = 4; game.runtime.s.comboT = 900.0; game.runtime.s.bossActive = true; game.runtime.s.bossNPC = tony; game.runtime.s.bossKind = "tony"
		report = await _capture("global_combat"+suffix,{"explicit_QA_composition":true,"hp":22,"stunT":1000,"slowT":1000,"shakes":95,"combo":4})
		_require(report.combat.stun_text == "GRABBED" and report.combat.boss.text.begins_with("TRE BAG TONY") and report.status_boxes.get("boss",Rect2()).has_area(),"actual global combat source text/safe boss box "+suffix)
		_reset_facts(); _camera_at_actor("tony")
		var target: Vector3 = game._actor_hud_anchor("tony")
		var wall := StaticBody3D.new(); wall.collision_layer = 1; wall.collision_mask = 0; game.add_child(wall)
		wall.global_position = game.camera.global_position.lerp(target,.5); wall.look_at(target)
		var shape := BoxShape3D.new(); shape.size = Vector3(3,3,.2); var collision := CollisionShape3D.new(); collision.shape = shape; wall.add_child(collision)
		var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = shape.size; mesh.mesh = box
		var material := StandardMaterial3D.new(); material.albedo_color = Color("#604020"); material.roughness = 1; mesh.material_override = material; wall.add_child(mesh)
		await physics_frame; await physics_frame
		report = await _capture("actual_wall_occlusion"+suffix,{"QA_inserted_layer1_wall":wall.global_transform})
		_require(not game._actor_hud_visible("tony",target) and not _drawn("tony",report),"actual wall hides Tony label "+suffix)
		wall.free(); await physics_frame; await physics_frame
		report = await _capture("wall_removed_current_ray"+suffix)
		_require(_drawn("tony",report),"no stale occlusion after wall removal "+suffix)
		_reset_facts(); var staged: int = _staged_crowd()
		_require(staged == 8,"eight original actors at explicit QA world-clear staging points")
		await physics_frame; await physics_frame
		await _capture("crowded_actual_rigs"+suffix,{"QA_repositioned_original_actors":staged,"gameplay_frozen":true})
	_require(captures.size() == 14,"all14 native display views completed")
	var file := FileAccess.open(output.path_join("actor-hud.json"),FileAccess.WRITE)
	if _require(file != null,"write actor HUD report"):
		file.store_string(JSON.stringify({"pass":failures.is_empty(),"failures":failures,"captures":captures,"actor_count":game.runtime.state.npcs.size(),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"scope":"QA-staged presentation only; not fight duration, gameplay outcome, audible evidence or whole60-actor frame budget."},"\t")); file.close()
	for voice: AudioStreamPlayer in game.sound.players: voice.stop(); voice.stream = null
	game.free(); game = null; await process_frame
	print("3D ACTOR HUD NATIVE PROBE: ","PASS" if failures.is_empty() else "FAIL"," (",captures.size()," captures; ",output,")"); quit(0 if failures.is_empty() else 1)
