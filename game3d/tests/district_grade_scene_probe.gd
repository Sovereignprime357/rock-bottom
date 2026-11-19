extends SceneTree
## Staged source facts in the actual FullScene, never an earned progression claim.
const Scene = preload("res://scripts/full_scene.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Grade = preload("res://scripts/district_grade.gd")
var game: Node3D
var captures: Array = []
var failures: Array[String] = []
var output: String

func _initialize() -> void: call_deferred("_run")

func _capture(id: String) -> void:
	game._process(0.0)
	await process_frame; await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.save_png(output+"/"+id+".png") != OK: failures.append("write "+id)
	captures.append({"id":id,"viewport":[image.get_width(),image.get_height()],"source_center":[game.runtime.state.player_center().x,game.runtime.state.player_center().y],"grade":game.hud.district_grade.inspect(),"mode":game.runtime.s.mode,"weather":game.runtime.s.weather,"day_time":game.runtime.s.dayTime,"high":game.runtime.p.rockedT,"crash":game.runtime.p.crashT})

func _place(point: Vector2) -> void:
	game.runtime.p.x = point.x-float(game.runtime.p.w)*0.5; game.runtime.p.y = point.y-float(game.runtime.p.h)*0.5
	game._sync_player(); game.camera.rotation = Vector3(-0.08,0,0)

func _run() -> void:
	if "--qa-full" not in OS.get_cmdline_user_args(): push_error("District scene probe requires --qa-full"); quit(1); return
	output = ProjectSettings.globalize_path("res://../.build/full-port/district-grade/scene")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	game = Scene.new(); root.add_child(game)
	for index: int in range(800):
		await process_frame
		if game.ready_for_play: break
	if not game.ready_for_play: push_error("Full scene failed startup"); quit(1); return
	game.set_process(false); game.sound.muted = true
	game.store.save_path = output+"/isolated-qa.json"; game.store.storage_key = "rockbottom_grade_scene_probe"
	game._new_game()
	var world: Dictionary = Content.load_content().world
	var model := Grade.new(world); var locations: Dictionary = {}
	for rectangle: Dictionary in world.zones+world.terrainRegions:
		for offset: Vector2 in [Vector2(0.5,0.5),Vector2(0.1,0.1),Vector2(0.9,0.9),Vector2(0.1,0.9),Vector2(0.9,0.1)]:
			var point := Vector2(rectangle.x+rectangle.w*offset.x,rectangle.y+rectangle.h*offset.y)
			var profile: Dictionary = model.at(point.x,point.y)
			if locations.has(profile.index): continue
			if game.world.is_clear_position(Content.to_world(point),0.5): locations[profile.index] = {"point":point,"district":rectangle.id}
	if locations.size() != 6: failures.append("Only "+str(locations.size())+" clear distinct district recipes found")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions; root.content_scale_size = dimensions
		await process_frame
		for index: int in locations:
			_place(locations[index].point)
			game.runtime.s.mode = "playing"; game.runtime.s.weather = "clear"; game.runtime.s.dayTime = 0.3
			game.runtime.p.rockedT = 0.0; game.runtime.p.crashT = 0.0
			await _capture(str(dimensions.x)+"_"+str(locations[index].district))
		_place(Vector2(1220,1000))
		game.runtime.s.weather = "rain"; game.runtime.s.dayTime = 0.9
		await _capture(str(dimensions.x)+"_rain_night")
		game.runtime.p.rockedT = 12000.0
		await _capture(str(dimensions.x)+"_high")
		game.runtime.p.rockedT = 0.0; game.runtime.p.crashT = 6000.0
		await _capture(str(dimensions.x)+"_crash")
		game._pause()
		await _capture(str(dimensions.x)+"_pause")
		game._resume(); game.runtime.p.crashT = 0.0; game.runtime.s.weather = "clear"
		_place(Content.to_source(game.world.service_points["smoke:block"].approach))
		game.runtime.p.supplies = 2; game.runtime.p.rockedT = 12000.0
		var menu: Dictionary = game.runtime.cooking.open_menu()
		var result: Dictionary = game.runtime.cooking.select(menu.get("token",""),"slow")
		if not result.get("started",false): failures.append("staged cooking did not start")
		await _capture(str(dimensions.x)+"_cooking")
		game.runtime.cooking.cancel("probe"); game.runtime.s.mode = "playing"
	game._title(); await _capture("title_off")
	if game.hud.district_grade.visible: failures.append("grade visible at title")
	var report := {"pass":failures.is_empty(),"captures":captures,"failures":failures,"scope":"staged facts in actual FullScene; visual review required; no campaign completion claim"}
	var file := FileAccess.open(output+"/scene-grade.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("3D DISTRICT GRADE SCENE: "+JSON.stringify({"pass":failures.is_empty(),"captures":captures.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
