extends Node
## Rendered-pixel witness; run with native Compatibility or the exported Web scene.
const Grade = preload("res://scripts/district_grade.gd")
const GradeView = preload("res://scripts/district_grade_view.gd")
const Feedback = preload("res://scripts/world_feedback.gd")
class SceneSizeReader:
	extends "res://scripts/full_scene.gd"
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
var failures: Array[String] = []
var results: Array[Dictionary] = []
var checks: int = 0
var grade: ColorRect
var reader: Node3D
var output: String

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _rect(parent: Node,color: Color,at: Vector2,dimensions: Vector2) -> ColorRect:
	var item := ColorRect.new(); item.position = at; item.size = dimensions; item.color = color; item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item); return item
func _capture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
func _rgb(color: Color) -> Vector3i:
	return Vector3i(roundi(color.r*255),roundi(color.g*255),roundi(color.b*255))
func _error(a: Color,b: Color) -> int:
	var difference: Vector3i = (_rgb(a)-_rgb(b)).abs()
	return maxi(difference.x,maxi(difference.y,difference.z))
func _edge(frame: Image,horizontal: bool) -> int:
	var fixed: int = int((250.0/720.0)*frame.get_height()) if horizontal else int((200.0/1280.0)*frame.get_width())
	var limit: int = frame.get_width() if horizontal else frame.get_height()
	for index: int in range(limit):
		var color: Color = frame.get_pixel(index,fixed) if horizontal else frame.get_pixel(fixed,index)
		if color.r > 0.6: return index
	return -10000

func _ready() -> void:
	output = ProjectSettings.globalize_path("res://../evidence/feedback-raster")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	reader = SceneSizeReader.new(); add_child(reader)
	var world := CanvasLayer.new(); world.layer = 0; add_child(world)
	_rect(world,Color("1a1810"),Vector2.ZERO,Vector2(1280,720))
	_rect(world,Color("d4c896"),Vector2(640,0),Vector2(24,720))
	_rect(world,Color("d4c896"),Vector2(0,360),Vector2(1280,24))
	var pass_layer := CanvasLayer.new(); pass_layer.layer = 1; add_child(pass_layer)
	var model := Grade.new({"ambientGrades":{"default":{"multiply":"255,255,255","multiplyAlpha":0.0,"overlay":"128,128,128","overlayAlpha":0.0}},"zones":[],"terrainRegions":[]})
	grade = GradeView.new(model); pass_layer.add_child(grade); grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hud := CanvasLayer.new(); hud.layer = 2; add_child(hud)
	_rect(hud,Color("8a3a3a"),Vector2(40,40),Vector2(80,48))
	var first_offset := Vector2.ZERO
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		get_tree().root.size = dimensions
		await get_tree().process_frame; await get_tree().process_frame
		grade.visible = false
		var original: Image = await _capture()
		var render_size: Vector2 = reader._feedback_render_size()
		var logical_size: Vector2 = get_viewport().get_visible_rect().size
		_check(original.get_size() == dimensions and render_size == Vector2(dimensions),"actual raster/Scene texture metadata match requested "+str(dimensions))
		_check(logical_size == Vector2(1280,720),"project canvas_items retains logical1280x720 at "+str(dimensions))
		grade.sync(0,0,"playing"); grade.set_world_feedback_offset(Vector2.ZERO)
		var zero: Image = await _capture()
		var max_zero: int = 0
		for y: int in range(0,dimensions.y,7):
			for x: int in range(0,dimensions.x,7): max_zero = maxi(max_zero,_error(original.get_pixel(x,y),zero.get_pixel(x,y)))
		_check(max_zero <= 2,"zero-offset identity preserves source grade golden within2bytes at "+str(dimensions))
		var sampled: Vector2 = Feedback.world_offset(14.0,1000.0,render_size,"playing")
		if dimensions.x == 1280: first_offset = sampled
		else: _check(sampled.distance_to(first_offset*0.75) < 0.000001,"actual960 framebuffer samples exactly3:4 source comfort displacement")
		# Exact comfort boundary makes integer raster displacement measurable. Fractional
		# nearest filtering may choose either adjacent texel at a half-pixel boundary.
		var forced := Vector2(2.0,-2.0)*(render_size.y/720.0)
		grade.set_world_feedback_offset(forced)
		var shifted: Image = await _capture()
		var movement := Vector2(_edge(shifted,true)-_edge(zero,true),_edge(shifted,false)-_edge(zero,false))
		_check(absf(movement.x-forced.x) <= 0.501 and absf(movement.y-forced.y) <= 0.501,"actual framebuffer world displacement agrees with nearest sampling at "+str(dimensions))
		var hud_same: bool = true
		for y: int in range(int(38.0*render_size.y/720.0),int(90.0*render_size.y/720.0)):
			for x: int in range(int(38.0*render_size.x/1280.0),int(122.0*render_size.x/1280.0)):
				if _error(zero.get_pixel(x,y),shifted.get_pixel(x,y)) > 2: hud_same = false
		_check(hud_same,"HUD patch and edges remain fixed while world shifts at "+str(dimensions))
		grade.clear()
		_check(grade.material.get_shader_parameter("world_feedback_offset_px") == Vector2.ZERO,"clear resets current material uniform")
		grade.sync(0,0,"playing")
		var cleared: Image = await _capture()
		_check(_edge(cleared,true) == _edge(zero,true) and _edge(cleared,false) == _edge(zero,false),"clear/rebind restores zero raster")
		results.append({"requested":[dimensions.x,dimensions.y],"framebuffer":[original.get_width(),original.get_height()],"logical":[logical_size.x,logical_size.y],"metadata":[render_size.x,render_size.y],"sampled_offset":[sampled.x,sampled.y],"forced_offset":[forced.x,forced.y],"measured_shift":[movement.x,movement.y],"zero_max_byte_error":max_zero,"hud_fixed":hud_same})
		if not OS.has_feature("web"):
			DirAccess.make_dir_recursive_absolute(output)
			zero.save_png(output+"/%dx%d-zero.png"%[dimensions.x,dimensions.y]); shifted.save_png(output+"/%dx%d-shift.png"%[dimensions.x,dimensions.y])
	_check(results.size() == 2,"both actual project resolutions completed")
	var report := {"pass":failures.is_empty(),"checks":checks,"rows":results,"failures":failures,"web":OS.has_feature("web"),"renderer":RenderingServer.get_current_rendering_method()}
	print("WORLD FEEDBACK RASTER: "+JSON.stringify(report))
	if not OS.has_feature("web"):
		var file := FileAccess.open(output+"/feedback-raster.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
		get_tree().quit(0 if failures.is_empty() else 1)
	else:
		var label := Label.new(); label.position = Vector2(8,100); label.text = "FEEDBACK RASTER "+("PASS" if failures.is_empty() else "FAIL")+" · "+str(checks)+" checks"; hud.add_child(label)
