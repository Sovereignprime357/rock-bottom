extends SceneTree
## Native-only evidence. Real Travel/Adapter/cart/Rig, explicit visual ticks, no Runtime/save IO.
const World = preload("res://scripts/full_neighborhood.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Content = preload("res://scripts/content_catalog.gd")
const State = preload("res://scripts/game_state.gd")
const Travel = preload("res://scripts/travel_system.gd")
const View = preload("res://scripts/cart_view.gd")
const Rig = preload("res://scripts/first_person_rig.gd")
var world: World
var game: State
var adapter: Adapter
var travel: Travel
var cart: View
var camera: Camera3D
var hands: Rig
var output_dir: String
var captures: Array[Dictionary] = []
var failure: bool = false
var original_resources: Dictionary = {}
var heading: float = 0.0
var fixture_bounds: Array[AABB] = []
var vertex_cache: Dictionary = {}
var query_shape := BoxShape3D.new()
var max_pose_queries: int = 0
var rolling_minimum_y: float = INF

func _initialize() -> void: call_deferred("_run")
func _require(ok: bool,label: String) -> bool:
	if not ok: failure = true; push_error("Cart capture: "+label)
	return ok
func _output() -> String:
	var path: String = ProjectSettings.globalize_path("res://../.build/full-port/p12c")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index].begins_with("--output="): path = args[index].trim_prefix("--output=")
		elif args[index] == "--output" and index+1 < args.size(): path = args[index+1]
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
func _parts() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in cart.find_children("*","MeshInstance3D",true,false):
		if str(child.get_meta("source_owner","")).begins_with("props:"): result.append(child as MeshInstance3D)
	return result
func _resources() -> Dictionary:
	var result: Dictionary = {}
	for mesh: MeshInstance3D in _parts(): result[mesh.get_instance_id()] = [mesh.mesh,mesh.material_override]
	return result
func _place(center: Vector2) -> void:
	game.p.x = center.x-float(game.p.w)*0.5; game.p.y = center.y-float(game.p.h)*0.5
func _body_transform() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0,heading,0)),Content.to_world(game.player_center()))
func _first_person(pitch: float = 0.0) -> void:
	camera.position = Content.to_world(game.player_center(),1.69)
	camera.rotation = Vector3(pitch,heading,0)
	hands.set_context({"visible":true,"walk_speed":5.5,"cart_grips":cart.grip_context(camera.global_transform,camera.fov,float(root.size.x)/float(root.size.y))})
func _tick(seconds: float,local_velocity: Vector3 = Vector3.ZERO,pitch: float = 0.0) -> void:
	var elapsed: float = 0.0
	var authority := {"p":game.p.duplicate(true),"s":game.s.duplicate(true),"events":game.events.duplicate(true),"rng":game.rng_seed}
	while elapsed < seconds-0.000001:
		var dt: float = minf(1.0/120.0,seconds-elapsed)
		var previous_queries: int = cart.presentation_queries
		cart.tick_pose(dt,_body_transform(),local_velocity)
		max_pose_queries = maxi(max_pose_queries,cart.presentation_queries-previous_queries)
		_require(cart.presentation_queries-previous_queries <= 9,"bounded mounted physics queries")
		if _visible_cart():
			var low: float = _bounds().position.y
			rolling_minimum_y = minf(rolling_minimum_y,low)
			_require(low >= -0.00001,"actual cart vertex remains above ground while rolling")
		_first_person(pitch)
		hands.tick(dt,local_velocity,false,false,false,0.0,Vector2.ZERO)
		elapsed += dt
	_require({"p":game.p,"s":game.s,"events":game.events,"rng":game.rng_seed} == authority,"presentation ticks preserve complete source state and RNG/events")
func _observer(target: Vector3,offset: Vector3) -> void:
	hands.set_context({"visible":false,"cart_grips":{}})
	camera.position = target+offset; camera.look_at(target,Vector3.UP)
func _conservative_bounds() -> AABB:
	var result := AABB(); var first: bool = true
	for mesh: MeshInstance3D in _parts():
		if not mesh.is_visible_in_tree(): continue
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		result = bounds if first else result.merge(bounds); first = false
	return result
func _vertices(mesh: Mesh) -> PackedVector3Array:
	if vertex_cache.has(mesh.get_instance_id()): return vertex_cache[mesh.get_instance_id()]
	var result := PackedVector3Array()
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: result.append_array(arrays[Mesh.ARRAY_VERTEX])
	vertex_cache[mesh.get_instance_id()] = result; return result
func _visible_cart() -> bool:
	var count: int = 0
	for mesh: MeshInstance3D in _parts():
		if mesh.is_visible_in_tree(): count += 1
	return count == 16
func _bounds(space: Node3D = null) -> AABB:
	var result := AABB(); var first: bool = true
	var inverse: Transform3D = space.global_transform.affine_inverse() if space != null else Transform3D.IDENTITY
	for mesh: MeshInstance3D in _parts():
		if not mesh.is_visible_in_tree(): continue
		var transform: Transform3D = inverse*mesh.global_transform
		for vertex: Vector3 in _vertices(mesh.mesh):
			var at: Vector3 = transform*vertex
			result = AABB(at,Vector3.ZERO) if first else result.expand(at); first = false
	return result
func _actual_presentation_clear() -> bool:
	if not _visible_cart(): return false
	var holder: Node3D = cart.get_node("Cart"); var bounds: AABB = _bounds(holder)
	query_shape.size = bounds.size
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = query_shape; query.collision_mask = 1; query.margin = 0.0
	query.transform = holder.global_transform*Transform3D(Basis.IDENTITY,bounds.get_center()); query.exclude = cart.collision_rids()
	return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _fixture_vertex_overlap() -> bool:
	for mesh: MeshInstance3D in _parts():
		if not mesh.is_visible_in_tree(): continue
		for vertex: Vector3 in _vertices(mesh.mesh):
			var point: Vector3 = mesh.global_transform*vertex
			for fixture: AABB in fixture_bounds:
				if fixture.has_point(point): return true
	return false
func _hand_visibility() -> Dictionary:
	var result: Dictionary = {}; var inverse: Transform3D = camera.global_transform.affine_inverse()
	var tangent: float = tan(deg_to_rad(camera.fov)*0.5); var aspect: float = float(root.size.x)/float(root.size.y)
	for side: String in ["left","right"]:
		var count: int = 0
		var wrist: Node3D = hands.get_node(side+"_arm/forearm/wrist")
		for node: Node in wrist.find_children("*","MeshInstance3D",true,false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			if not mesh.is_visible_in_tree() or not (str(mesh.name) == "palm" or str(mesh.name) == "tip_mesh"): continue
			for vertex: Vector3 in _vertices(mesh.mesh):
				var point: Vector3 = inverse*mesh.global_transform*vertex
				if point.z <= -camera.near and absf(point.y) <= -point.z*tangent and absf(point.x) <= -point.z*tangent*aspect: count += 1
		result[side] = count
	return result
func _capture(label: String,extra: Dictionary = {}) -> void:
	if failure: return
	await process_frame; await physics_frame; await RenderingServer.frame_post_draw
	var required_clear: bool = label in ["narrow_wall_front","diagonal_wall_skimming","diagonal_wall_external"]
	if required_clear:
		_require(cart.presentation_clear and _visible_cart() and _actual_presentation_clear() and not _fixture_vertex_overlap(),label+" must show visible cart with independently clear actual geometry")
	if label == "mounted_forward":
		var visibility: Dictionary = _hand_visibility()
		_require(cart.grip_context(camera.global_transform,camera.fov,float(root.size.x)/float(root.size.y)).is_empty() and visibility.left > 0 and visibility.right > 0,"level mounted camera shows relaxed hands instead of off-screen grips")
	var error: Error = root.get_texture().get_image().save_png(output_dir.path_join(label+".png"))
	if not _require(error == OK,"write "+label): return
	var record: Dictionary = {"file":label+".png","source_cart":travel.cart_record(),"source_player":[game.p.x,game.p.y],"mounted":game.p.cartMounted,
		"camera":camera.global_transform,"view_bounds":_bounds(),"actual_vertex_bounds":_bounds(),"conservative_mesh_aabb_bounds":_conservative_bounds(),"collision_active":cart.parked_body().collision_layer != 0,
		"resource_count":_resources().size(),"original_resources_unchanged":_resources() == original_resources,
		"grips":cart.grip_context(camera.global_transform,camera.fov,float(root.size.x)/float(root.size.y)),"weapon":str(hands.weapon),"attack_weapon":str(hands.attack_weapon),"action":str(hands.action),"phase":hands.action_phase,
		"presentation_clear":cart.presentation_clear,"presentation_offset":cart.presentation_offset,"presentation_queries":cart.presentation_queries,"original_art_visible":_visible_cart(),
		"actual_geometry_physics_clear":_actual_presentation_clear() if game.p.cartMounted else null,"hand_vertices_in_frustum":_hand_visibility(),
		"fixture_envelope_overlap":false,"fixture_actual_vertex_overlap":_fixture_vertex_overlap(),"grip_to_palm_m":{}}
	for fixture: AABB in fixture_bounds:
		if fixture.intersects(_conservative_bounds()): record.fixture_envelope_overlap = true
	for side: String in ["left","right"]:
		if not record.grips.has(side): continue
		var marker: Node3D = hands.get_node(side+"_arm/forearm/wrist/palm_marker")
		record.grip_to_palm_m[side] = marker.global_position.distance_to(camera.global_transform*record.grips[side])
	record.merge(extra); captures.append(record)
func _wall(center: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0; body.set_meta("source_owner","cart_probe_wall")
	var shape := BoxShape3D.new(); shape.size = size; var collision := CollisionShape3D.new(); collision.shape = shape; body.add_child(collision)
	var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = size; mesh.mesh = box
	var material := StandardMaterial3D.new(); material.albedo_color = Color("797767"); material.roughness = 0.96; mesh.material_override = material; body.add_child(mesh)
	world.add_child(body); body.global_position = center; fixture_bounds.append(AABB(center-size*0.5,size)); return body
func _physical_motion(source_velocity: Vector2,seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds-0.000001:
		var dt: float = minf(1.0/60.0,seconds-elapsed)
		var before := Vector2(game.p.x,game.p.y)
		var result: Dictionary = adapter.move_body(game.p,before+source_velocity*dt)
		game.p.x = result.position.x; game.p.y = result.position.y
		var actual: Vector2 = (result.position-before)*0.04/dt
		var local: Vector3 = Basis.from_euler(Vector3(0,heading,0)).inverse()*Vector3(actual.x,0,actual.y)
		_tick(dt,local,-0.55); elapsed += dt
func _run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Cart evidence requires native rendering."); quit(1); return
	output_dir = _output()
	if not _require(DirAccess.make_dir_recursive_absolute(output_dir) == OK,"create output directory"): quit(1); return
	root.size = Vector2i(1280,720)
	world = World.new(); world.dynamic_cart = true; root.add_child(world); world.build(); world.set_day_time(84.0)
	game = State.new(); game.s.mode = "playing"; game.npcs.clear(); adapter = Adapter.new(world,game); travel = Travel.new(game,adapter)
	cart = View.new(); world.add_child(cart)
	if not _require(cart.bind(world,adapter,travel) and cart.sync(),"bind all original cart geometry"): world.free(); quit(1); return
	original_resources = _resources()
	camera = Camera3D.new(); camera.fov = 78.0; camera.near = 0.06; camera.far = 180.0; world.add_child(camera); camera.current = true
	hands = Rig.create() as Rig; camera.add_child(hands); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame; await physics_frame
	var source_cart: Dictionary = travel.cart_record(); var top_left := Vector2(source_cart.x,source_cart.y)
	var center: Vector3 = Content.to_world(top_left+Vector2(12,10),0.55)
	_observer(center,Vector3(2.2,1.4,2.8)); await _capture("parked_original")
	var approach: Vector3 = adapter.cart_approach(top_left)
	if not _require(approach.is_finite(),"actual parked approach"): world.free(); quit(1); return
	_place(Content.to_source(approach)); camera.position = Content.to_world(game.player_center(),1.69); camera.look_at(center)
	hands.set_context({"visible":true,"cart_grips":{}}); await _capture("parked_approach")
	if not _require(travel.interact_cart().ok and cart.sync(),"actual source mount"): world.free(); quit(1); return
	heading = 0; hands.reset(); _tick(0.05); await _capture("mounted_forward")
	_tick(0.05,Vector3.ZERO,-0.70); await _capture("mounted_down_look")
	_tick(0.05,Vector3.ZERO,0.65); await _capture("mounted_up_release")
	_place(Vector2(1050,840)); _tick(0.05,Vector3.ZERO,-0.45)
	# Explicit cosmetic phase sweep checks actual octagon vertices for three full turns.
	_tick(3.0*TAU*0.13/5.5,Vector3(0,0,-5.5),-0.45)
	_physical_motion(Vector2(0,-137.5),0.18); await _capture("mounted_rolling")
	_tick(0.30,Vector3.ZERO,-0.45); await _capture("mounted_stationary")
	hands.set_context({"weapon":"pipe"}); _tick(0.02,Vector3.ZERO,-0.45); await _capture("mounted_weapon_stowed")
	hands.acknowledge(&"punch",true,true,&"pipe"); _tick(0.045,Vector3.ZERO,-0.45); await _capture("mounted_weapon_contact")
	_tick(0.35,Vector3.ZERO,-0.45); await _capture("mounted_weapon_regrip")
	hands.acknowledge(&"phone",true,false); _tick(0.18,Vector3.ZERO,-0.45); await _capture("mounted_phone_release")
	_tick(0.5,Vector3.ZERO,-0.45)
	_place(Vector2(1050,840)); _tick(0.02,Vector3.ZERO,-0.5)
	var before: Dictionary = game.snapshot(); var previous_cart: Dictionary = travel.cart_record()
	var block := _wall(Content.to_world(game.player_center(),0.7),Vector3(6.5,1.4,6.5)); await physics_frame; await physics_frame
	var refusal: Dictionary = travel.interact_cart()
	_require(not refusal.ok and game.snapshot() == before and travel.cart_record() == previous_cart,"blocked drop remains mounted and unchanged")
	_tick(0.02,Vector3.ZERO,-0.5)
	_require(not cart.presentation_clear and not _visible_cart() and cart.grip_context(camera.global_transform).is_empty(),"intentional enclosing fixture explicitly hides uncertifiable mounted art and releases grips")
	_observer(Content.to_world(game.player_center(),0.7),Vector3(4.2,3.0,4.2)); await _capture("blocked_drop",{"outcome":refusal,"intentional_player_enclosure":true,"expected_hidden_uncertifiable_art":true})
	block.free(); fixture_bounds.clear(); await physics_frame; await physics_frame
	_tick(0.02,Vector3.ZERO,-0.5)
	_require(cart.presentation_clear and _visible_cart(),"removed enclosure allows hidden cart to recover without authority change")
	var drop: Dictionary = travel.interact_cart()
	if not _require(drop.ok and cart.sync(),"clear drop commits through actual adapter"): world.free(); quit(1); return
	source_cart = travel.cart_record(); center = Content.to_world(Vector2(source_cart.x+12,source_cart.y+10),0.55)
	_observer(center,Vector3(2.2,1.4,2.8)); await _capture("successful_drop",{"outcome":drop})
	previous_cart = travel.cart_record(); var save: Dictionary = game.snapshot()
	_require(game.restore(save).ok,"source restore"); adapter.begin_cart_epoch(); travel.reset_session("restore",previous_cart); _require(cart.sync(),"restored cart projection")
	_observer(center,Vector3(2.2,1.4,2.8)); await _capture("same_process_restored")
	approach = adapter.cart_approach(Vector2(previous_cart.x,previous_cart.y)); _place(Content.to_source(approach)); game.s.mode = "playing"
	_require(travel.interact_cart().ok and cart.sync(),"remount before source death"); game.die(); _require(cart.sync(),"death preserves mounted projection")
	game.npcs.clear(); hands.reset(); _tick(0.02,Vector3.ZERO,-0.6); await _capture("death_retains_mount")
	# Real accepted player sweeps exercise bounded cosmetic separation, not hidden art.
	_place(Vector2(1050,840)); heading = 0; _tick(0.02,Vector3.ZERO,-0.55)
	var wall := _wall(Content.to_world(Vector2(1050,807),1.0),Vector3(4.0,2.0,0.10)); await physics_frame; await physics_frame
	_physical_motion(Vector2(0,-137.5),0.35); await _capture("narrow_wall_front")
	wall.free(); fixture_bounds.clear(); await physics_frame
	_place(Vector2(1050,840)); heading = -PI*0.25
	wall = _wall(Content.to_world(Vector2(1080,840),1.0),Vector3(0.10,2.0,4.0)); await physics_frame; await physics_frame
	_physical_motion(Vector2(97.227,-97.227),0.35); await _capture("diagonal_wall_skimming")
	_observer(Content.to_world(game.player_center(),0.6),Vector3(-2.2,1.8,2.4)); await _capture("diagonal_wall_external")
	wall.free(); fixture_bounds.clear()
	var file := FileAccess.open(output_dir.path_join("captures.json"),FileAccess.WRITE)
	if _require(file != null,"write capture manifest"):
		file.store_string(JSON.stringify({"count":captures.size(),"camera":{"fov":78,"near":0.06,"size":[1280,720]},"captures":captures,
			"maximum_queries_per_pose":max_pose_queries,"rolling_actual_vertex_minimum_y":rolling_minimum_y,"explicit_rolling_sweep_revolutions":3,
			"scope":"Original unique cart; actual Travel and player physics; explicit rig pose. Front/diagonal evidence requires visible, independently physics-clear geometry. Actual vertex bounds are separate from conservative rotated mesh AABBs; the enclosing blocked-drop fixture deliberately reports hidden uncertifiable art."},"\t")); file.close()
	world.free(); game = null; adapter = null; travel = null
	if failure: print("3D CART VIEW PROBE: FAIL"); quit(1)
	else: print("3D CART VIEW PROBE: PASS (%d captures; %s)" % [captures.size(),output_dir]); quit(0)
