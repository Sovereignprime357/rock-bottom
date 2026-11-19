extends Node
## Real SDR framebuffer comparison against Chromium's captured Canvas pixels.
const Grade = preload("res://scripts/district_grade.gd")
const GradeView = preload("res://scripts/district_grade_view.gd")
var results: Array = []
var failures: Array[String] = []

func _rect(parent: Node,color: Color,at: Vector2,dimensions: Vector2) -> ColorRect:
	var rect := ColorRect.new(); rect.position = at; rect.size = dimensions; rect.color = color
	parent.add_child(rect); return rect

func _bytes(color: Color) -> Array:
	return [roundi(color.r*255),roundi(color.g*255),roundi(color.b*255)]

func _ready() -> void:
	await get_tree().process_frame
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/district_grade_reference.json"))
	var canvas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/district_grade_canvas.json"))
	if FileAccess.get_sha256("res://tests/fixtures/district_grade_reference.json") != canvas.fixtureSha256:
		push_error("Canvas fixture source hash mismatch"); get_tree().quit(1); return
	var stage := Control.new(); add_child(stage)
	for row: int in range(canvas.rows.size()):
		for col: int in range(canvas.patches.size()):
			var bytes: Array = canvas.patches[col]
			_rect(stage,Color(bytes[0]/255.0,bytes[1]/255.0,bytes[2]/255.0,1),Vector2(col*40,row*40),Vector2(40,40))
	# Disjoint rects share the initial screen copy; each region receives one grade.
	for row: int in range(canvas.rows.size()):
		var data: Dictionary = reference.variants.source.duplicate(true)
		data.zones = [{"id":canvas.rows[row].id,"x":0,"y":0,"w":1,"h":1}]; data.terrainRegions = []
		var view := GradeView.new(Grade.new(data)); stage.add_child(view)
		view.position = Vector2(0,row*40); view.size = Vector2(600,40); view.sync(0.5,0.5,"playing")
	# Final UI patch must bypass every grade pass.
	var hud_color := Color(0.83,0.27,0.61,1)
	_rect(stage,hud_color,Vector2(0,250),Vector2(600,40))
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	if frame.get_width() < 600 or frame.get_height() < 290:
		push_error("Raster harness requires an actual framebuffer of at least600x290; got "+str(frame.get_size()))
		get_tree().quit(1); return
	var maximum: int = 0; var total: int = 0; var channels: int = 0
	for row: int in range(canvas.rows.size()):
		var pixels: Array = []
		for col: int in range(canvas.patches.size()):
			var actual: Array = _bytes(frame.get_pixel(col*40+20,row*40+20)); pixels.append(actual)
			for channel: int in range(3):
				var error: int = absi(actual[channel]-int(canvas.rows[row].pixels[col][channel]))
				maximum = maxi(maximum,error); total += error; channels += 1
				if error > 2: failures.append("%s/%d/%d: %d byte error"%[canvas.rows[row].id,col,channel,error])
		results.append({"id":canvas.rows[row].id,"pixels":pixels})
	var hud_actual: Array = _bytes(frame.get_pixel(300,270))
	if hud_actual != _bytes(hud_color): failures.append("HUD patch was changed: "+str(hud_actual))
	var report: Dictionary = {"pass":failures.is_empty(),"maximum_byte_error":maximum,"mean_byte_error":float(total)/channels,"channels":channels,"hud_actual":hud_actual,"hud_expected":_bytes(hud_color),"rows":results,"failures":failures,"framebuffer":[frame.get_width(),frame.get_height()],"renderer":RenderingServer.get_current_rendering_method(),"web":OS.has_feature("web")}
	print("3D DISTRICT GRADE RASTER: "+JSON.stringify(report))
	if not OS.has_feature("web"):
		var output := ProjectSettings.globalize_path("res://../.build/full-port/district-grade")
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		DirAccess.make_dir_recursive_absolute(output)
		frame.save_png(output+"/native-raster.png")
		var file := FileAccess.open(output+"/native-raster.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	var label := Label.new(); label.position = Vector2(8,302); label.text = "RASTER %s | max %d bytes | HUD %s"%["PASS" if failures.is_empty() else "FAIL",maximum,str(hud_actual)]; add_child(label)
	if not OS.has_feature("web"): get_tree().quit(0 if failures.is_empty() else 1)
