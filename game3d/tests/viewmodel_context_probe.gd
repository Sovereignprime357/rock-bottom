extends SceneTree
## Native evidence only. Explicit pose ticks, no Runtime, gameplay input or save owner.
const Rig = preload("res://scripts/first_person_rig.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
var hands: Rig
var camera: Camera3D
var output_dir: String
var captures: Array[Dictionary] = []
var failed: bool = false

func _initialize() -> void: call_deferred("_run")
func _advance(seconds: float,velocity: Vector3 = Vector3.ZERO,sprint: bool = false,high: bool = false,crash: bool = false,shakes: float = 0.0,look: Vector2 = Vector2.ZERO) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds-0.000001:
		var dt: float = minf(1.0/120.0,seconds-elapsed)
		hands.tick(dt,velocity,sprint,high,crash,shakes,look)
		elapsed += dt
func _reset(weapon: StringName = &"fists",seated: bool = false) -> void:
	hands.reset(); hands.set_context({"weapon":weapon,"walk_speed":5.5,"seated":seated,"visible":true})
func _capture(label: String) -> void:
	if failed: return
	await process_frame; await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var error: Error = frame.save_png(output_dir.path_join(label+".png"))
	if error != OK:
		failed = true; push_error("Cannot save viewmodel context frame "+label+": "+str(error)); return
	captures.append({"file":label+".png","weapon":str(hands.weapon),"attack_weapon":str(hands.attack_weapon),"action":str(hands.action),"phase":hands.action_phase,"visible":hands.visible})
func _output() -> String:
	var selected: String = ProjectSettings.globalize_path("res://../.build/full-port/p05c")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index].begins_with("--output="): selected = args[index].trim_prefix("--output=")
		elif args[index] == "--output" and index+1 < args.size(): selected = args[index+1]
	return ProjectSettings.globalize_path(selected) if selected.begins_with("res://") or selected.begins_with("user://") else selected
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Viewmodel context evidence requires native rendering."); quit(1); return
	output_dir = _output()
	var made: Error = DirAccess.make_dir_recursive_absolute(output_dir)
	if made != OK: push_error("Cannot create context evidence directory: "+output_dir); quit(1); return
	root.size = Vector2i(1280,720)
	var world := World.new(); root.add_child(world); world.build(); world.set_day_time(84.0)
	camera = Camera3D.new(); camera.name = "ViewmodelEvidenceCamera"; camera.fov = 78.0; camera.near = 0.06; camera.far = 180.0
	world.add_child(camera); camera.position = Content.to_world(Vector2(1050,840),1.69); camera.rotation = Vector3.ZERO; camera.current = true
	hands = Rig.create() as Rig; camera.add_child(hands)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame; await physics_frame
	for weapon: StringName in Rig.supported_weapons():
		_reset(weapon); await _capture(str(weapon)+"_rest")
		hands.acknowledge(&"punch",true,false,weapon); await _capture(str(weapon)+"_immediate")
		_advance(0.045); await _capture(str(weapon)+"_miss_peak")
		_advance(0.115); await _capture(str(weapon)+"_recovery")
		_reset(weapon); hands.acknowledge(&"punch",true,true,weapon)
		_advance(0.045); await _capture(str(weapon)+"_contact_peak")
	for action: StringName in [&"phone",&"bench",&"dumpster",&"kick"]:
		_reset(&"pipe"); hands.acknowledge(action,true,false)
		_advance(0.10); await _capture("context_"+str(action)+"_early")
		_advance(0.12); await _capture("context_"+str(action)+"_late")
	_reset(); await _capture("context_standing_fists")
	_reset(&"fists",true); await _capture("context_seated_fists")
	_reset(&"pipe",true); await _capture("context_seated_pipe")
	_reset(&"pipe"); _advance(0.30,Vector3(0,0,-5.5)); await _capture("context_walk_5_5")
	_reset(&"pipe"); _advance(0.30,Vector3(0,0,-16.83),true,true); await _capture("context_sprint_16_83")
	_reset(&"pipe"); _advance(0.20,Vector3(5.5,0,-5.5),true,true,true,100.0,Vector2(0.30,-0.30)); await _capture("context_look_shakes")
	hands.set_context({"visible":false}); await _capture("context_menu_hidden")
	hands.reset(); await _capture("context_reset")
	_reset(); hands.acknowledge(&"punch",true,true,&"fists"); _advance(0.025)
	hands.set_context({"weapon":&"broken_bottle"}); await _capture("capture_original_fists_after_bottle_receipt")
	_advance(0.35); await _capture("capture_new_bottle_after_recovery")
	var metadata: Dictionary = {"camera":{"fov":camera.fov,"near":camera.near,"size":[1280,720]},"count":captures.size(),"captures":captures,
		"scope":"Production first-person rig, explicit presentation time, original full-world lighting; no gameplay/Runtime/save actions."}
	var file := FileAccess.open(output_dir.path_join("captures.json"),FileAccess.WRITE)
	if file == null: failed = true; push_error("Cannot save viewmodel capture manifest.")
	else: file.store_string(JSON.stringify(metadata,"\t")); file.close()
	world.free()
	if failed: print("3D VIEWMODEL CONTEXT PROBE: FAIL"); quit(1)
	else: print("3D VIEWMODEL CONTEXT PROBE: PASS (%d frames; %s)" % [captures.size(),output_dir]); quit(0)
