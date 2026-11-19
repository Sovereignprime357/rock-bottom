extends SceneTree
## Native evidence: cached production rig, full-world light and actual mounted-cart handles.
## Explicit fixture/pose time only; no Runtime, gameplay input or persistence IO.
const Rig = preload("res://scripts/first_person_rig.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
const State = preload("res://scripts/game_state.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Travel = preload("res://scripts/travel_system.gd")
const Cart = preload("res://scripts/cart_view.gd")
var world: World
var hands: Rig
var camera: Camera3D
var game: State
var adapter: Adapter
var travel: Travel
var cart: Cart
var output_dir: String
var captures: Array[Dictionary] = []
var failed: bool = false
var vertex_cache: Dictionary = {}

func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failed = true; push_error("Gear capture: "+label)
	return ok
func _output() -> String:
	var path: String = ProjectSettings.globalize_path("res://../.build/full-port/p05e")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index].begins_with("--output="): path = args[index].trim_prefix("--output=")
		elif args[index] == "--output" and index+1 < args.size(): path = args[index+1]
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
func _place(center: Vector2) -> void:
	game.p.x = center.x-float(game.p.w)*0.5; game.p.y = center.y-float(game.p.h)*0.5
	camera.position = Content.to_world(center,1.69); camera.rotation = Vector3.ZERO
func _reset(tool: StringName = &"",weapon: StringName = &"fists",coat: StringName = &"",shoes: StringName = &"") -> void:
	hands.reset(); camera.rotation = Vector3.ZERO
	_require(hands.set_context({"tool":tool,"weapon":weapon,"coat":coat,"shoes":shoes,"walk_speed":5.5,"visible":true}),"accept fixture gear context")
func _advance(seconds: float,velocity: Vector3 = Vector3.ZERO,sprint: bool = false,high: bool = false,crash: bool = false,shakes: float = 0.0,look: Vector2 = Vector2.ZERO) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds-0.000001:
		var dt: float = minf(1.0/120.0,seconds-elapsed)
		hands.tick(dt,velocity,sprint,high,crash,shakes,look); elapsed += dt
func _vertices(mesh: Mesh) -> PackedVector3Array:
	if vertex_cache.has(mesh.get_rid()): return vertex_cache[mesh.get_rid()]
	var result := PackedVector3Array()
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: result.append_array(arrays[Mesh.ARRAY_VERTEX])
	vertex_cache[mesh.get_rid()] = result; return result
func _geometry() -> Dictionary:
	var low := Vector3(INF,INF,INF); var high := Vector3(-INF,-INF,-INF)
	var count: int = 0; var meshes: int = 0; var resources: Dictionary = {}; var material_ids: Dictionary = {}
	var inverse: Transform3D = camera.global_transform.affine_inverse(); var safe: bool = true
	for node: Node in hands.find_children("*","MeshInstance3D",true,false):
		var instance: MeshInstance3D = node as MeshInstance3D
		if not instance.is_visible_in_tree(): continue
		meshes += 1; resources[instance.mesh.get_instance_id()] = true
		if instance.material_override != null: material_ids[instance.material_override.get_instance_id()] = true
		var transform: Transform3D = inverse*instance.global_transform
		for vertex: Vector3 in _vertices(instance.mesh):
			var at: Vector3 = transform*vertex
			safe = safe and at.is_finite() and at.z < -0.06 and at.z >= -1.5 and absf(at.x) <= 1.0 and absf(at.y) <= 1.2
			low = low.min(at); high = high.max(at); count += 1
	return {"finite_near_plane_bounds":safe and count > 0,"visible_vertices":count,"visible_meshes":meshes,"mesh_resources":resources.size(),"material_resources":material_ids.size(),"camera_min":[low.x,low.y,low.z],"camera_max":[high.x,high.y,high.z]}
func _shown_tool() -> String:
	for node: Node in hands.get_node("left_arm/forearm/wrist/HeldTool").get_children():
		if node is Node3D and node.is_visible_in_tree() and node.has_meta("tool_id"): return str(node.get_meta("tool_id"))
	return ""
func _capture(label: String,extra: Dictionary = {}) -> void:
	if failed: return
	var geometry: Dictionary = _geometry()
	if not _require(bool(geometry.finite_near_plane_bounds),label+" actual visible vertices stay finite and behind the near plane"): return
	await process_frame; await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output_dir.path_join(label+".png"))
	if not _require(error == OK,"write "+label): return
	var record := {"file":label+".png","tool":str(hands.tool),"visible_tool":_shown_tool(),"coat":str(hands.coat),"shoes":str(hands.shoes),"weapon":str(hands.weapon),"attack_weapon":str(hands.attack_weapon),"action":str(hands.action),"phase":hands.action_phase,"geometry":geometry}
	record.merge(extra); captures.append(record)
func _tool_frames(tool: StringName) -> void:
	var prefix: String = str(tool)
	_reset(tool); await _capture(prefix+"_fists_rest")
	_reset(tool,&"pipe"); await _capture(prefix+"_pipe_rest")
	hands.acknowledge(&"punch",true,true,&"pipe"); _advance(0.045); await _capture(prefix+"_right_pipe_contact")
	_reset(tool); hands.acknowledge(&"punch",true,false,&"fists"); _advance(0.30)
	hands.acknowledge(&"punch",true,true,&"fists"); _advance(0.045); await _capture(prefix+"_left_fist_stowed")
	_reset(tool,&"pipe"); hands.acknowledge(&"receipt",true); _advance(0.15); await _capture(prefix+"_receipt_stowed")
	_reset(tool,&"pipe"); hands.acknowledge(&"smoke",true); _advance(0.20); await _capture(prefix+"_smoke_stowed")
	_reset(tool,&"pipe"); hands.acknowledge(&"phone",true); _advance(0.12); await _capture(prefix+"_phone_carried")
	_reset(tool); hands.acknowledge(&"punch",true,false,&"fists"); _advance(0.30)
	hands.acknowledge(&"punch",true,true,&"fists"); _advance(0.025)
	var replacement: StringName = &"crowbar" if tool == &"propane_torch" else &"propane_torch"
	hands.set_context({"tool":replacement,"weapon":"broken_bottle"}); _advance(0.30)
	await _capture(prefix+"_replacement_after_recovery",{"previous_tool":str(tool)})
func _cart_frames() -> void:
	var record: Dictionary = travel.cart_record(); var point := Vector2(float(record.x),float(record.y))
	var approach: Vector3 = adapter.cart_approach(point)
	if not _require(approach.is_finite(),"original parked cart has a certified approach"): return
	_place(Content.to_source(approach))
	if not _require(bool(travel.interact_cart().get("ok",false)) and cart.sync(),"actual Travel mount adopts original cart"): return
	_place(Vector2(1050,840))
	for tool: StringName in Rig.supported_tools():
		_reset(tool,&"pipe"); camera.rotation.x = -0.55
		cart.tick_pose(1.0/120.0,Transform3D(Basis.IDENTITY,Content.to_world(game.player_center())),Vector3.ZERO)
		var grips: Dictionary = cart.grip_context(camera.global_transform,camera.fov,float(root.size.x)/float(root.size.y))
		if not _require(grips.size() == 2 and cart.presentation_clear,"downward camera supplies both actual handle grips"): return
		hands.set_context({"cart_grips":grips}); _advance(0.06)
		if not _require(_shown_tool().is_empty(),"actual cart left grip stows tool"): return
		await _capture(str(tool)+"_actual_cart_grip",{"grips":grips.size(),"cart_clear":cart.presentation_clear})
		camera.rotation.x = 0.0
		grips = cart.grip_context(camera.global_transform,camera.fov,float(root.size.x)/float(root.size.y))
		if not _require(grips.is_empty(),"level camera releases offscreen handle"): return
		hands.set_context({"cart_grips":grips}); _advance(0.06)
		await _capture(str(tool)+"_cart_look_release",{"grips":grips.size(),"cart_clear":cart.presentation_clear})
	cart.clear_active()
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Viewmodel gear evidence requires native rendering."); quit(1); return
	output_dir = _output()
	if not _require(DirAccess.make_dir_recursive_absolute(output_dir) == OK,"create output directory"): quit(1); return
	root.size = Vector2i(1280,720)
	world = World.new(); world.dynamic_cart = true; root.add_child(world); world.build(); world.set_day_time(84.0)
	game = State.new(); game.s.mode = "playing"; game.npcs.clear(); adapter = Adapter.new(world,game); travel = Travel.new(game,adapter)
	cart = Cart.new(); world.add_child(cart)
	if not _require(cart.bind(world,adapter,travel) and cart.sync(),"bind original cart for grip evidence"): world.free(); quit(1); return
	camera = Camera3D.new(); camera.name = "GearEvidenceCamera"; camera.fov = 78.0; camera.near = 0.06; camera.far = 180.0; world.add_child(camera); camera.current = true
	hands = Rig.create() as Rig; camera.add_child(hands); _place(Vector2(1050,840))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame; await physics_frame; await physics_frame
	for tool: StringName in Rig.supported_tools(): await _tool_frames(tool)
	for coat: StringName in [&"trench",&"windbreaker",&"bathrobe",&"parka"]:
		_reset(&"",&"fists",coat); await _capture(str(coat)+"_sleeves_rest")
		hands.acknowledge(&"bench",true); _advance(0.15); await _capture(str(coat)+"_sleeves_bench")
	for shoes: StringName in [&"",&"airpods",&"crocs",&"walmart_sneak",&"vibrams"]:
		_reset(&"",&"shoe",&"",shoes); hands.acknowledge(&"kick",true); _advance(0.10)
		await _capture(("default" if shoes.is_empty() else str(shoes))+"_kick")
	await _cart_frames()
	_reset(&"propane_torch",&"pipe",&"parka"); _advance(0.30,Vector3(0,0,-16.83),true,true,true,100,Vector2(0.30,-0.30)); await _capture("torch_sprint_stress")
	_reset(&"crowbar",&"knife",&"trench"); _advance(0.30,Vector3(0,0,-5.5)); await _capture("crowbar_walk")
	hands.reset(); await _capture("reset_original_mold_and_empty_tools")
	_require(captures.size() == 36,"all 36 bounded gear frames completed")
	var metadata := {"camera":{"fov":camera.fov,"near":camera.near,"size":[1280,720]},"count":captures.size(),"captures":captures,"scope":"Production rig and full-world lighting; actual Cart/Travel handle projection. Explicit fixture and presentation time; no Runtime, gameplay input, save IO, performance claim or automatic visual acceptance."}
	var file := FileAccess.open(output_dir.path_join("captures.json"),FileAccess.WRITE)
	if file == null: _require(false,"write capture manifest")
	else: file.store_string(JSON.stringify(metadata,"\t")); file.close()
	world.free()
	if failed: print("3D VIEWMODEL GEAR PROBE: FAIL"); quit(1)
	else: print("3D VIEWMODEL GEAR PROBE: PASS (%d frames; %s)"%[captures.size(),output_dir]); quit(0)
