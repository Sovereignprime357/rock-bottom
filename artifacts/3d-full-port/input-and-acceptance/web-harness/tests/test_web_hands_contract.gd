extends SceneTree
## Draft acceptance validator counterexamples; no engine/scene evidence by itself.
const Probe = preload("res://tests/web_hands_probe.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _frame(index: int) -> Dictionary:
	var mounted: bool = index >= 8 and index <= 14
	var gripping: bool = index in [9,10,11,12,13]
	var attack: bool = index in [1,3,12]
	return {"index":index,"label":Probe.PHASES[index],"framebuffer":[1280,720],"mode":"playing","hands_visible":true,"camera_near":0.06,"envelope":{"finite":true,"vertices":100,"on_screen":30,"nearest_z":-0.15},"action":"punch" if attack else ("pickup" if index == 5 else ""),"age":0.04,"attack_weapon":"fists" if attack else "","side":-1 if index == 3 else 1,"cash_collected":index >= 5,"cart":{"mounted":mounted,"layer":0 if mounted else 1,"clear":true,"targets":["left","right"] if gripping else [],"grip_error":{"left":0.0,"right":0.1 if index == 12 else 0.0} if gripping else {}}}
func _report() -> Dictionary:
	var records: Array[Dictionary] = []
	for index: int in range(16): records.append(_frame(index))
	return {"web":true,"records":records,"initial":{"fixture":"none","weapon":"fists","cash":0,"cart_mounted":false},"replacements":0,"overflow":false,"samples":[{"phase":1}],"inputs":{"motion_frames":1,"mouse_motion":1,"keys":1,"clicks":1},"events":[{"kind":"player_attack","payload":{"used_weapon":"fists"}},{"kind":"player_attack","payload":{"used_weapon":"fists"}},{"kind":"gesture","payload":{"action":"pickup"}},{"kind":"cart_changed","payload":{"mounted":true}},{"kind":"player_attack","payload":{"used_weapon":"fists"}},{"kind":"cart_changed","payload":{"mounted":false}}]}
func _actual_projection() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	for physical_size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = physical_size
		await process_frame
		await process_frame
		var rectangle: Rect2 = camera.get_viewport().get_visible_rect()
		var bottom: Vector2 = rectangle.position+rectangle.size*Vector2(0.5,0.92)
		var world_point: Vector3 = camera.project_position(bottom,0.4)
		var actual: Vector2 = camera.unproject_position(world_point)
		_check(Probe.projection_visible(actual,rectangle,camera.is_position_behind(world_point)),"real camera lower hand projection remains visible at "+str(physical_size))
		_check(actual.distance_to(bottom) < 0.01,"actual projection roundtrip uses the viewport coordinate space")
		if physical_size == Vector2i(960,540):
			_check(rectangle.size.is_equal_approx(Vector2(1280,720)) and not Rect2(Vector2.ZERO,Vector2(physical_size)).has_point(actual),"actual canvas_items resize reproduces old logical-versus-framebuffer rejection")
		var outside: Vector3 = camera.project_position(rectangle.position+rectangle.size*Vector2(0.5,1.04),0.4)
		_check(not Probe.projection_visible(camera.unproject_position(outside),rectangle,camera.is_position_behind(outside)),"real camera point below logical viewport remains rejected")
		var behind: Vector3 = camera.to_global(Vector3(0,0,0.4))
		_check(not Probe.projection_visible(camera.unproject_position(behind),rectangle,camera.is_position_behind(behind)),"real camera behind point remains rejected")
	camera.free()
	root.size = Vector2i(1280,720)

func _run() -> void:
	await _actual_projection()
	var logical := Rect2(0,0,1280,720)
	var physical := Rect2(0,0,960,540)
	var lower_hand := Vector2(1000,680)
	_check(not physical.has_point(lower_hand) and physical.has_point(lower_hand*0.75),"counterexample: visible scaled hand lies outside raw framebuffer coordinates")
	_check(Probe.projection_visible(lower_hand,logical,false),"logical lower/right hand remains visible in960 framebuffer")
	_check(Probe.projection_visible(lower_hand,logical,false) and Probe.projection_visible(lower_hand*0.75,physical,false),"matching-space projection is resolution invariant")
	_check(Probe.projection_visible(Vector2(0,0),logical,false),"viewport top-left remains included")
	for outside: Vector2 in [Vector2(-0.01,300),Vector2(1280,300),Vector2(600,-0.01),Vector2(600,720),Vector2(1500,900)]:
		_check(not Probe.projection_visible(outside,logical,false),"genuinely outside logical viewport remains rejected")
	_check(not Probe.projection_visible(lower_hand,logical,true),"behind-camera point remains rejected")
	_check(not Probe.projection_visible(Vector2(NAN,680),logical,false),"nonfinite projection remains rejected")
	_check(not Probe.projection_visible(lower_hand,Rect2(0,0,0,720),false),"empty projection rectangle cannot pass")
	_check(not Probe.projection_visible(lower_hand,Rect2(0,0,1280,-720),false),"negative projection rectangle cannot pass")
	_check(not Probe.projection_visible(lower_hand,Rect2(0,0,INF,720),false),"nonfinite projection rectangle cannot pass")
	_check(Probe.projection_visible(Vector2(110,220),Rect2(100,200,400,300),false),"actual viewport origin is respected")
	_check(not Probe.projection_visible(Vector2(10,20),Rect2(100,200,400,300),false),"point outside offset viewport remains rejected")
	for index: int in range(16):
		var row: Dictionary = _frame(index)
		_check(Probe.frame_errors(row).is_empty(),"valid synthetic contract frame "+str(index))
		row.framebuffer = [960,540]; _check(Probe.frame_errors(row).is_empty(),"actual alternate size contract "+str(index))
		row.camera_near = 0.06; row.envelope.nearest_z = -0.05
		_check(not Probe.frame_errors(row).is_empty(),"reject geometry behind real near plane "+str(index))
	var row: Dictionary = _frame(1); row.action = ""; _check(not Probe.frame_errors(row).is_empty(),"missed transient is not impact evidence")
	row = _frame(3); row.side = 1; _check(not Probe.frame_errors(row).is_empty(),"left is not repeated right")
	row = _frame(5); row.cash_collected = false; _check(not Probe.frame_errors(row).is_empty(),"gesture alone is not collection")
	for age: float in [0.0,0.039,0.32,NAN]:
		row = _frame(5); row.age = age; _check(not Probe.frame_errors(row).is_empty(),"pickup acknowledgement/expired/nonfinite is not a rendered reach")
	row = _frame(12); row.cart.grip_error.left = 0.1; _check(not Probe.frame_errors(row).is_empty(),"inactive hand remains on actual handle")
	row = _frame(12); row.cart.grip_error.right = 0.0; _check(not Probe.frame_errors(row).is_empty(),"mounted attack actually releases active grip")
	row = _frame(13); row.cart.grip_error.right = 0.1; _check(not Probe.frame_errors(row).is_empty(),"actual recovery regrips")
	row = _frame(14); row.cart.targets = ["left","right"]; _check(not Probe.frame_errors(row).is_empty(),"offscreen grips must release")
	row = _frame(15); row.cart.layer = 0; _check(not Probe.frame_errors(row).is_empty(),"parked collider restores")
	var report: Dictionary = _report(); _check(Probe.sequence_errors(report).is_empty(),"complete synthetic validator fixture")
	for key: String in ["web","overflow"]:
		report = _report(); report[key] = key == "overflow"; _check(not Probe.sequence_errors(report).is_empty(),"reject "+key)
	report = _report(); report.records.remove_at(5); _check(not Probe.sequence_errors(report).is_empty(),"cannot skip/reorder transaction")
	report = _report(); report.events.remove_at(0); _check(not Probe.sequence_errors(report).is_empty(),"pose requires accepted source attack")
	report = _report(); report.initial.cash = 5; _check(not Probe.sequence_errors(report).is_empty(),"this driver grants no cash fixture")
	report = _report(); report.replacements = 1; _check(not Probe.sequence_errors(report).is_empty(),"epoch replacement invalidates proof")
	report = _report(); report.samples.clear(); _check(not Probe.sequence_errors(report).is_empty(),"snapshot alone is not trajectory")
	print("DRAFT WEB HANDS CONTRACT: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks. Synthetic validation only, not browser evidence.")
	quit(0 if failures.is_empty() else 1)
