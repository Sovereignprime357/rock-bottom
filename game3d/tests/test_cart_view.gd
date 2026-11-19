extends SceneTree
## Central runner only. Real original geometry, Travel and Adapter; no permissive placement fake.
const World = preload("res://scripts/full_neighborhood.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Travel = preload("res://scripts/travel_system.gd")
const View = preload("res://scripts/cart_view.gd")
const Rig = preload("res://scripts/first_person_rig.gd")
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []
var vertex_cache: Dictionary = {}
var mounted_query_shape := BoxShape3D.new()

class ObservedState extends "res://scripts/game_state.gd":
	var draws: int = 0
	func random_float() -> float:
		draws += 1
		return super.random_float()

class EpochAdapter extends "res://scripts/world_adapter.gd":
	var replace_on_drop: String = ""
	var replacement_snapshot: Dictionary = {}
	func _init(world_node: Node3D,game: RefCounted) -> void: super(world_node,game)
	func find_cart_drop(preferred: Vector2,maximum: float) -> Variant:
		var result: Variant = super.find_cart_drop(preferred,maximum)
		if replace_on_drop.is_empty(): return result
		var game: RefCounted = _host()
		if replace_on_drop == "player": game.p = game.p.duplicate(true)
		else: game.s = game.s.duplicate(true)
		replacement_snapshot = {"p":game.p.duplicate(true),"s":game.s.duplicate(true),"events":game.events.duplicate(true)}
		replace_on_drop = ""
		return result

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _cart_index() -> int:
	var props: Array = Content.load_content().props
	for index: int in range(props.size()):
		if props[index].type == "cart": return index
	return -1
func _owner() -> String: return "props:%d" % _cart_index()
func _service() -> String: return "prop:%d" % _cart_index()
func _parts(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in node.find_children("*","MeshInstance3D",true,false):
		if child.get_meta("source_owner","") == _owner(): result.append(child as MeshInstance3D)
	return result
func _nav(adapter: RefCounted,owner: String) -> Array:
	var result: Array = []
	for row: Dictionary in adapter._navigation._records:
		if str(row.owner) == owner: result.append(row.duplicate(true))
	return result
func _revision(adapter: RefCounted) -> int: return int(adapter.navigation_metrics().revision)
func _place(game: RefCounted,center: Vector2) -> void:
	game.p.x = center.x-float(game.p.w)*0.5; game.p.y = center.y-float(game.p.h)*0.5
func _record(game: RefCounted,top_left: Vector2) -> void:
	game.s.travelRuntime.cart.x = top_left.x; game.s.travelRuntime.cart.y = top_left.y
func _snapshot(game: RefCounted) -> Dictionary:
	return {"p":game.p.duplicate(true),"s":game.s.duplicate(true),"actors":game.npcs.duplicate(true),"events":game.events.duplicate(true),"draws":game.draws}
func _poses(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for child: Node in node.find_children("*","Node3D",true,false):
		result[child.get_instance_id()] = {"transform":child.transform,"visible":child.visible}
	return result
func _resources(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for mesh: MeshInstance3D in _parts(node): result[mesh.get_instance_id()] = [mesh.mesh,mesh.material_override,mesh.get_aabb(),mesh.get_meta("source_owner")]
	return result
func _sync(rig: Dictionary) -> bool:
	var before: Dictionary = _snapshot(rig.game)
	var accepted: bool = rig.view.sync()
	_check(_snapshot(rig.game) == before,"cart sync is a pure read, including RNG/events and malformed runtime")
	return accepted
func _hidden(rig: Dictionary,label: String) -> void:
	for mesh: MeshInstance3D in _parts(rig.view): _check(not mesh.is_visible_in_tree(),label+" hides original "+str(mesh.name))
	var body: StaticBody3D = rig.view.parked_body()
	_check(body == null or body.collision_layer == 0,label+" disables parked physical body")
	_check(not rig.world.service_points.has(_service()) and _nav(rig.adapter,_owner()).is_empty(),label+" removes only cart service/navigation")
func _solid(world: Node3D,at: Vector3,size: Vector3,owner: String = "cart_fixture") -> StaticBody3D:
	var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0; body.set_meta("source_owner",owner)
	var shape := BoxShape3D.new(); shape.size = size
	var child := CollisionShape3D.new(); child.shape = shape; body.add_child(child); world.add_child(body); body.global_position = at
	return body
func _capsule_clear(world: Node3D,at: Vector3) -> bool:
	var shape := CapsuleShape3D.new(); shape.radius = 0.48; shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.collision_mask = 1; query.margin = 0.002
	query.transform = Transform3D(Basis.IDENTITY,Vector3(at.x,Adapter.FEET+0.9,at.z))
	return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _ray_owner(world: Node3D,top_left: Vector2) -> String:
	var at: Vector3 = Content.to_world(top_left+Vector2(12,10),0.6)
	var query := PhysicsRayQueryParameters3D.create(at+Vector3(0,2,0),at-Vector3(0,0.5,0),1); query.hit_from_inside = true
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	return str(hit.collider.get_meta("source_owner","")) if hit.get("collider") is CollisionObject3D else ""
func _shape_bounds(body: StaticBody3D) -> Array[AABB]:
	var result: Array[AABB] = []
	for child: Node in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			result.append(child.global_transform*AABB(-child.shape.size*0.5,child.shape.size))
	return result
func _geometry_bounds(node: Node3D) -> AABB:
	var result := AABB(); var started: bool = false
	for mesh: MeshInstance3D in _parts(node):
		if not mesh.is_visible_in_tree(): continue
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		result = result.merge(bounds) if started else bounds; started = true
	return result
func _vertices(mesh: Mesh) -> PackedVector3Array:
	if vertex_cache.has(mesh.get_instance_id()): return vertex_cache[mesh.get_instance_id()]
	var result := PackedVector3Array()
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: result.append_array(arrays[Mesh.ARRAY_VERTEX])
	vertex_cache[mesh.get_instance_id()] = result
	return result
func _vertex_bounds(node: Node3D,space: Node3D = null) -> AABB:
	var result := AABB(); var started: bool = false
	var inverse: Transform3D = space.global_transform.affine_inverse() if space != null else Transform3D.IDENTITY
	for mesh: MeshInstance3D in _parts(node):
		if not mesh.is_visible_in_tree(): continue
		var transform: Transform3D = inverse*mesh.global_transform
		for vertex: Vector3 in _vertices(mesh.mesh):
			var at: Vector3 = transform*vertex
			result = result.expand(at) if started else AABB(at,Vector3.ZERO); started = true
	return result
func _visible_cart(node: Node3D) -> bool:
	var visible_parts: int = 0
	for mesh: MeshInstance3D in _parts(node):
		if mesh.is_visible_in_tree(): visible_parts += 1
	return visible_parts == 16 # All original art; the seventeenth mesh is the hidden basket proxy.
func _actual_presentation_clear(rig: Dictionary) -> bool:
	if not _visible_cart(rig.view): return false
	var holder: Node3D = rig.view.get_node("Cart")
	var bounds: AABB = _vertex_bounds(rig.view,holder)
	if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0: return false
	mounted_query_shape.size = bounds.size
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = mounted_query_shape; query.collision_mask = 1; query.margin = 0.0
	query.transform = holder.global_transform*Transform3D(Basis.IDENTITY,bounds.get_center()); query.exclude = rig.view.collision_rids()
	return rig.world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _mesh_on_screen(mesh: MeshInstance3D,camera: Node3D,vertical_fov: float = 78.0,aspect: float = 16.0/9.0) -> bool:
	if mesh == null or not mesh.is_visible_in_tree(): return false
	var transform: Transform3D = camera.global_transform.affine_inverse()*mesh.global_transform
	var tangent: float = tan(deg_to_rad(vertical_fov)*0.5)
	for vertex: Vector3 in _vertices(mesh.mesh):
		var at: Vector3 = transform*vertex
		if at.is_finite() and at.z <= -0.06 and absf(at.y) <= -at.z*tangent and absf(at.x) <= -at.z*tangent*aspect: return true
	return false
func _hand_camera_clear(hands: Node3D) -> bool:
	for node: Node in hands.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
		var transform: Transform3D = hands.global_transform.affine_inverse()*mesh.global_transform
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			if arrays.is_empty() or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: return false
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var at: Vector3 = transform*point
				if not at.is_finite() or at.z > -0.06: return false
	return true
func _await_physics() -> void:
	await physics_frame; await physics_frame

func _static_regression() -> void:
	var world := World.new(); root.add_child(world); world.build(); await _await_physics()
	var bodies: int = 0
	for body: Node in world.find_children("*","StaticBody3D",true,false):
		if body.get_meta("source_owner","") == _owner(): bodies += 1
	_check(bodies == 2,"default static world preserves both original cart solids")
	var service: Dictionary = world.service_points[_service()]
	_check(service.source_point == Vector2(1012,1610) and is_equal_approx(service.reach,47.5*0.04),"default static world keeps legacy center/reach contract")
	var game := ObservedState.new(); game.s.mode = "playing"; game.npcs.clear(); var adapter := Adapter.new(world,game)
	_place(game,Content.to_source(service.approach))
	_check(_capsule_clear(world,service.approach) and adapter.can_reach_target(_service()),"legacy cart approach retains real capsule and LOS")
	world.free(); groups += 1

func _adoption() -> Dictionary:
	var world := World.new(); world.dynamic_cart = true; root.add_child(world); world.build(); await _await_physics()
	var meshes: Array[MeshInstance3D] = _parts(world); var originals: Dictionary = {}
	_check(meshes.size() == 17,"dynamic world retains exactly17 original unique-cart meshes")
	for mesh: MeshInstance3D in meshes:
		originals[mesh.get_instance_id()] = {"node":mesh,"mesh":mesh.mesh,"material":mesh.material_override,"transform":mesh.global_transform,"name":mesh.name}
		_check(not mesh.visible,"dynamic cart is hidden before adoption "+str(mesh.name))
	var carts: int = 0; var husks: int = 0
	for prop: Dictionary in world.content.props:
		if prop.type == "cart": carts += 1
		elif prop.type == "cart_husk": husks += 1
	_check(carts == 1 and husks == 6,"one rideable cart and six separate scenery husks")
	_check(world.source_records.props[str(_cart_index())].mesh_count == 17,"source coverage remains original17")
	for row: Dictionary in world.obstacle_records(): _check(row.owner != _owner(),"dynamic build has no original cart navigation seed")
	for body: Node in world.find_children("*","StaticBody3D",true,false): _check(body.get_meta("source_owner","") != _owner(),"dynamic build has no original cart physics seed")
	_check(world.service_points["route:cart_barrier"].structure_id == "props:143" and world.service_points["kingdom_mark:cart_cavalry:0"].structure_id == "props:143","scenery cart remains both canonical contact owners")
	var game := ObservedState.new(); game.s.mode = "playing"; game.npcs.clear()
	var adapter := EpochAdapter.new(world,game); var travel := Travel.new(game,adapter); var view := View.new(); world.add_child(view)
	var rig: Dictionary = {"world":world,"game":game,"adapter":adapter,"travel":travel,"view":view,"originals":originals}
	if meshes.size() != 17: return rig
	var missing: MeshInstance3D = meshes[0]; world.remove_child(missing)
	_check(not view.bind(world,adapter,travel),"incomplete original set refuses bind atomically")
	world.add_child(missing)
	var extra := MeshInstance3D.new(); extra.mesh = missing.mesh; extra.set_meta("source_owner",_owner()); world.add_child(extra)
	_check(not view.bind(world,adapter,travel),"extra tagged original refuses bind atomically")
	extra.free()
	_check(meshes.all(func(mesh: MeshInstance3D): return mesh.get_parent() == world),"failed preflights leave all17 original objects untouched")
	_check(view.bind(world,adapter,travel) and adapter.bind_cart(travel,view),"real view and adapter bind to sole Travel authority")
	_check(view.bind(world,adapter,travel),"same-owner binding is idempotent")
	_check(_sync(rig),"source spawn projects without relocating authoritative cart")
	await _await_physics()
	var adopted: Array[MeshInstance3D] = _parts(view)
	_check(adopted.size() == 17,"all17 original objects adopted exactly once")
	var invisible: int = 0
	for mesh: MeshInstance3D in adopted:
		var original: Dictionary = originals.get(mesh.get_instance_id(),{})
		_check(not original.is_empty(),"adoption preserves original object identity")
		if original.is_empty(): continue
		_check(mesh.mesh == original.mesh and mesh.material_override == original.material and mesh.global_transform.is_equal_approx(original.transform),"parked adoption preserves mesh/material/pose "+str(mesh.name))
		if not mesh.is_visible_in_tree(): invisible += 1; _check(str(mesh.name).begins_with("cart_basket_collision"),"only original collision proxy remains invisible")
	_check(invisible == 1,"invisible basket proxy stays hidden")
	var body: StaticBody3D = view.parked_body()
	_check(body != null and body.collision_layer == 1 and body.get_meta("source_owner","") == _owner(),"single parked body retains cart source owner")
	if body != null:
		var sizes: Array[Vector3] = []
		for child: Node in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D: sizes.append(child.shape.size)
		_check(sizes.size() == 2 and sizes.any(func(v: Vector3): return v.is_equal_approx(Vector3(0.96,0.08,0.80))) and sizes.any(func(v: Vector3): return v.is_equal_approx(Vector3(0.96,0.55,0.80))),"single body retains both original frame/basket shapes")
		_check(view.collision_rids().size() == 1 and view.collision_rids()[0] == body.get_rid(),"cart collision identity is one stable body RID")
		var boxes: Array[AABB] = _shape_bounds(body)
		var source_center: Vector3 = Content.to_world(Vector2(1012,1610))
		_check(boxes.size() == 2 and boxes.any(func(box: AABB): return box.get_center().is_equal_approx(source_center+Vector3(0,0.28,0))) and boxes.any(func(box: AABB): return box.get_center().is_equal_approx(source_center+Vector3(0,0.63,0))),"actual physical shape centers match both authored solids")
	var visual_bounds: AABB = _geometry_bounds(view)
	var expected_center: Vector3 = Content.to_world(Vector2(1012,1610))
	# Original upright wheel cylinders reach beyond the frame: .96*.38+.13=.4948.
	_check(visual_bounds.position.is_equal_approx(expected_center+Vector3(-0.4948,0.07,-0.40)) and visual_bounds.end.is_equal_approx(expected_center+Vector3(0.4948,1.039,0.499)),"actual revised shaft envelope retains original wheel width and handle center: "+str(visual_bounds))
	_check(AABB(expected_center+Vector3(-0.4948,0.07,-0.40),Vector3(0.9896,0.995,0.925)).grow(0.00001).encloses(visual_bounds),"slimmer visible art stays inside the unchanged original conservative envelope")
	_check(adapter._cart_envelope(Vector2(1000,1600)).grow(0.00001).encloses(visual_bounds),"drop envelope contains actual original parked meshes including both exposed wheels")
	_check(_ray_owner(world,Vector2(1000,1600)) == _owner(),"actual ray finds parked source cart")
	var revision: int = _revision(adapter); var resources: Dictionary = _resources(view)
	for index: int in range(12): _check(_sync(rig),"unchanged authoritative snapshot remains valid")
	_check(_revision(adapter) == revision and _resources(view) == resources,"stable sync has no topology/resource churn")
	# Source can commit a drop before the next view publication. Sequential prop
	# staging must see that authoritative parked envelope, not only its old body.
	var old_cart: Dictionary = travel.cart_record(); var old_player := Vector2(game.p.x,game.p.y)
	var old_body: Transform3D = view.parked_body().global_transform
	_record(game,Vector2(1050,840)); _place(game,Vector2(950,840))
	var staged_point := Vector2(1062,850)
	var before_stage: Dictionary = _snapshot(game)
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",staged_point,0.0) == null,"same-frame authoritative parked cart rejects bottle before view body moves")
	_check(_snapshot(game) == before_stage and view.parked_body().global_transform == old_body,"parked logical exclusion is pure and does not secretly sync old body")
	game.p.cartMounted = true; before_stage = _snapshot(game)
	_check(adapter.stage_interactive_prop("interactive:6","b_bottle",staged_point,0.0) == staged_point,"mounted source flag releases only proposed parked envelope at identical physical point")
	_check(_snapshot(game) == before_stage and view.parked_body().global_transform == old_body,"mounted prop staging consumes no RNG and writes no cart/model state")
	adapter._interactive_approaches.erase("interactive:6")
	game.s.travelRuntime.cart = old_cart; game.p.cartMounted = false; game.p.x = old_player.x; game.p.y = old_player.y
	groups += 1; return rig

func _mount_and_pose(rig: Dictionary) -> void:
	var top_left := Vector2(1000,1600)
	var approach: Vector3 = rig.adapter.cart_approach(top_left)
	_check(approach.is_finite() and _capsule_clear(rig.world,approach),"current cart has actual clear approach capsule")
	if not approach.is_finite(): return
	_check(Content.to_source(approach).distance_to(top_left) < 36.0,"approach obeys source top-left36 range")
	_place(rig.game,Content.to_source(approach)); _check(rig.adapter.can_reach_target(_service()),"approach has actual current cart LOS")
	var witnessed: bool = false
	for direction: Vector2 in [Vector2.LEFT,Vector2.UP,Vector2.RIGHT,Vector2.DOWN]:
		_place(rig.game,top_left+direction*35.999)
		if not _capsule_clear(rig.world,Content.to_world(rig.game.player_center())) or not rig.adapter.can_reach_target(_service()): continue
		witnessed = true
		_place(rig.game,top_left+direction*36.0)
		var before: Dictionary = _snapshot(rig.game)
		_check(not rig.adapter.can_reach_target(_service()) and not rig.travel.interact_cart().ok,"exact36 refuses adapter and Travel source range")
		_check(_snapshot(rig.game) == before,"exact-boundary refusal has no model effect")
		_place(rig.game,top_left+direction*35.999); break
	_check(witnessed,"clear35.999/36 source boundary witness exists")
	var hp: float = rig.game.p.hp
	_check(rig.travel.interact_cart().ok and rig.game.p.cartMounted and rig.game.p.maxHp == 110 and rig.game.p.hp == hp,"actual mount raises maximum without healing")
	_check(_sync(rig),"mounted state synchronizes immediately")
	await _await_physics()
	_check(rig.view.parked_body().collision_layer == 0 and _nav(rig.adapter,_owner()).is_empty() and not rig.world.service_points.has(_service()),"mounted art removes collider/navigation/service")
	_check(_ray_owner(rig.world,top_left) != _owner() and not rig.adapter.can_reach_target(_service()),"old parked point cannot be ray-hit or interacted while mounted")
	var body_transform := Transform3D(Basis.IDENTITY,Content.to_world(rig.game.player_center()))
	rig.view.tick_pose(0.016,body_transform,Vector3.ZERO)
	var camera := Transform3D(Basis.IDENTITY,body_transform.origin+Vector3(0,1.69,0))
	_check(rig.view.grip_context(camera).is_empty(),"level camera releases the low bar rather than pulling both hands below the frustum")
	camera.basis = Basis.from_euler(Vector3(-0.55,0,0))
	var grips: Dictionary = rig.view.grip_context(camera)
	_check(grips.has("left") and grips.has("right") and grips.left.is_finite() and grips.right.is_finite(),"mounted handle supplies finite camera-local grip points")
	if grips.has("left") and grips.has("right"):
		_check(grips.left.x < grips.right.x and grips.left.z < 0 and grips.right.z < 0,"grips remain on corresponding sides ahead of camera")
		for side: String in ["left","right"]:
			var marker: Node3D = rig.view.get_node("Cart/Art/GripLeft" if side == "left" else "Cart/Art/GripRight")
			_check((camera*grips[side]).distance_to(marker.global_position) < 0.0001,"grip is derived from actual handle marker "+side)
	var state_before: Dictionary = _snapshot(rig.game); var resources: Dictionary = _resources(rig.view)
	var stationary: Dictionary = _poses(rig.view); var revision: int = _revision(rig.adapter)
	for index: int in range(40): rig.view.tick_pose(0.05,body_transform,Vector3.ZERO)
	_check(_poses(rig.view) == stationary,"zero accepted travel produces no wheel or grip drift")
	rig.view.tick_pose(0.05,body_transform,Vector3(0,0,-5.5))
	_check(_poses(rig.view) != stationary,"actual accepted travel rotates authored wheels")
	var rolled: Dictionary = _poses(rig.view)
	for delta: float in [0.0,-1.0,NAN,INF]: rig.view.tick_pose(delta,body_transform,Vector3(0,0,-5.5))
	_check(_poses(rig.view) == rolled,"paused or malformed pose time is a complete no-op")
	rig.view.tick_pose(0.05,Transform3D(Basis.from_euler(Vector3(0.8,0.6,0.2)),body_transform.origin),Vector3.ZERO)
	var marker: Node3D = rig.view.get_node("Cart/Art/GripLeft")
	_check(absf(marker.global_position.y-(body_transform.origin.y+1.02)) < 0.005,"cart ignores camera/body pitch and roll; original handle remains grounded")
	_check(_snapshot(rig.game) == state_before and _resources(rig.view) == resources and _revision(rig.adapter) == revision,"all mounted poses preserve source state/resources/navigation")
	var old_player: Dictionary = rig.game.p
	rig.game.p = rig.game.p.duplicate(true)
	_check(rig.view.grip_context(camera).is_empty(),"grip read refuses replaced player epoch before any sync/tick")
	rig.game.p = old_player
	var old_state: Dictionary = rig.game.s
	rig.game.s = rig.game.s.duplicate(true)
	_check(rig.view.grip_context(camera).is_empty(),"grip read refuses replaced state epoch before any sync/tick")
	rig.game.s = old_state
	rig.game.p.cartMounted = false
	_check(rig.view.grip_context(camera).is_empty(),"grip read refuses current dismounted flag before projection sync")
	rig.game.p.cartMounted = true; rig.view.sync()
	var valid_runtime: Dictionary = rig.game.s.travelRuntime
	rig.game.s.travelRuntime = {"cart":null}
	var malformed_before: Dictionary = _snapshot(rig.game)
	_check(rig.view.grip_context(camera).is_empty(),"mounted grip refuses malformed same-epoch record without a preceding sync")
	rig.view.tick_pose(0.016,body_transform,Vector3(0,0,-5.5))
	_hidden(rig,"mounted malformed record before sync")
	_check(_snapshot(rig.game) == malformed_before,"mounted invalidation does not lazily repair source runtime")
	rig.game.s.travelRuntime = valid_runtime; _check(_sync(rig),"restored valid authority can resume mounted presentation")
	groups += 1

func _hand_grips(rig: Dictionary) -> void:
	rig.game.p.cartMounted = true; rig.view.sync(); _place(rig.game,Vector2(1050,840))
	var player := Transform3D(Basis.IDENTITY,Content.to_world(rig.game.player_center()))
	rig.view.tick_pose(0.016,player,Vector3.ZERO)
	var camera := Node3D.new(); rig.world.add_child(camera); camera.global_transform = Transform3D(Basis.IDENTITY,player.origin+Vector3(0,1.69,0))
	var hands: Rig = Rig.create() as Rig; camera.add_child(hands)
	var level_grips: Dictionary = rig.view.grip_context(camera.global_transform)
	_check(level_grips.is_empty() and hands.set_context({"weapon":"fists","cart_grips":level_grips}),"level view uses relaxed hands instead of off-screen handle targets")
	hands.tick(0.016,Vector3.ZERO,false,false,false,0.0,Vector2.ZERO)
	for side: String in ["left","right"]:
		var palm: MeshInstance3D = hands.get_node(side+"_arm/forearm/wrist/palm")
		var visible_digits: int = 0
		for digit: String in ["index","middle","ring","little"]:
			var tip: MeshInstance3D = hands.get_node(side+"_arm/forearm/wrist/"+digit+"/middle/tip/tip_mesh")
			if _mesh_on_screen(tip,camera): visible_digits += 1
		_check(_mesh_on_screen(palm,camera) and visible_digits >= 2,"neutral mounted "+side+" palm and actual finger vertices remain on screen")
	camera.rotation.x = -0.55
	var handle: MeshInstance3D
	for mesh: MeshInstance3D in _parts(rig.view):
		if mesh.get_meta("cart_part","") == "handle" and mesh.mesh is ArrayMesh: handle = mesh
	_check(handle != null,"real authored shaft is available for hand geometry contact")
	var grips: Dictionary = rig.view.grip_context(camera.global_transform)
	_check(grips.size() == 2,"looking down exposes both actual handle grips")
	for fov: float in [0.0,-1.0,180.0,NAN,INF]: _check(rig.view.grip_context(camera.global_transform,fov,16.0/9.0).is_empty(),"invalid vertical FOV fails closed")
	for aspect: float in [0.0,-1.0,NAN,INF]: _check(rig.view.grip_context(camera.global_transform,78.0,aspect).is_empty(),"invalid aspect fails closed")
	_check(hands.set_context({"weapon":"pipe","cart_grips":grips}),"existing rig accepts current actual cart grips")
	hands.tick(0.016,Vector3.ZERO,false,false,false,0.0,Vector2.ZERO)
	if handle != null:
		var bounds: AABB = handle.get_aabb()
		for side: String in ["left","right"]:
			var count: int = 0
			for digit: String in ["index","middle","ring","little"]:
				var tip: MeshInstance3D = hands.get_node(side+"_arm/forearm/wrist/"+digit+"/middle/tip/tip_mesh")
				var local: Vector3 = handle.to_local(tip.to_global(tip.get_aabb().get_center()))
				if local.distance_to(local.clamp(bounds.position,bounds.end)) < 0.07: count += 1
			_check(count >= 2,"at least two actual distal fingers contact original handle envelope "+side)
	var before: Dictionary = _poses(hands); var selected: StringName = hands.weapon
	for bad: Variant in [null,true,{"left":Vector3.ZERO},{"left":Vector3(NAN,0,0),"right":Vector3.ZERO},{"left":"wrong","right":Vector3.ZERO}]:
		_check(not hands.set_context({"weapon":"brick","cart_grips":bad}) and _poses(hands) == before and hands.weapon == selected,"invalid cart context is atomic across weapon and hand pose")
	var detached: Dictionary = grips.duplicate(true); hands.set_context({"cart_grips":detached}); before = _poses(hands)
	if detached.has("left"): detached.left = Vector3.ZERO
	hands.tick(0.0,Vector3.ZERO,false,false,false,0.0,Vector2.ZERO)
	_check(_poses(hands) == before,"rig does not retain mutable caller grip dictionary")
	hands.acknowledge(&"punch",true,true,&"pipe"); hands.tick(0.045,Vector3.ZERO,false,false,false,0.0,Vector2.ZERO)
	_check(hands.action == &"punch" and hands.attack_weapon == &"pipe" and _poses(hands) != before,"mounted grip releases immediately for authoritative original-weapon attack")
	hands.set_context({"weapon":"broken_bottle","cart_grips":grips})
	_check(hands.attack_weapon == &"pipe","mounted equip cannot retroactively change accepted attack weapon")
	for index: int in range(40): hands.tick(0.01,Vector3.ZERO,false,false,false,0.0,Vector2.ZERO)
	_check(hands.action.is_empty() and hands.weapon == &"broken_bottle","mounted recovery returns to latest context without queued action")
	for gesture: StringName in [&"phone",&"eat"]:
		hands.acknowledge(gesture,true,false); hands.tick(0.1,Vector3.ZERO,false,false,false,0.0,Vector2.ZERO)
		_check(hands.action == gesture,"mounted grip permits actual contextual gesture "+str(gesture))
		hands.acknowledge(&"punch",true,false,&"fists")
		_check(hands.action == &"punch" and hands.attack_weapon == &"fists" and hands.action_phase == 0.0,"mounted gesture never delays accepted fist swing")
		for index: int in range(30): hands.tick(0.01,Vector3.ZERO,false,false,false,0.0,Vector2.ZERO)
	_check(hands.set_context({"cart_grips":{}}),"empty grip context releases both hands")
	for pitch: float in [-1.25,-0.7,0.0,0.7,1.25]:
		camera.rotation.x = pitch
		var actual_grips: Dictionary = rig.view.grip_context(camera.global_transform)
		_check(hands.set_context({"cart_grips":actual_grips}),"camera-derived finite or released grip context accepted")
		for weapon: StringName in [&"fists",&"pipe",&"cart_wheel",&"broken_bottle"]:
			hands.set_context({"weapon":weapon}); hands.acknowledge(&"punch",true,false,weapon)
			var clear: bool = true
			for index: int in range(35):
				hands.tick(0.01,Vector3(5.5,0,-16.83),true,true,true,100,Vector2(0.3,-0.3))
				clear = clear and _hand_camera_clear(hands)
			_check(clear,"actual mounted/released hand and weapon vertices clear0.06m near plane at pitch "+str(pitch)+" "+str(weapon))
	camera.free(); groups += 1

func _mounted_wall_clearance(rig: Dictionary) -> void:
	rig.game.p.cartMounted = true; rig.game.s.mode = "playing"; rig.game.npcs.clear()
	_place(rig.game,Vector2(1050,840)); _check(_sync(rig),"mounted clearance fixture uses existing Travel record")
	await _await_physics()
	var resources: Dictionary = _resources(rig.view); var revision: int = _revision(rig.adapter)
	var parked_body: StaticBody3D = rig.view.parked_body(); var body_rid: RID = parked_body.get_rid()
	var shapes: Array[Shape3D] = []
	for collision: CollisionShape3D in parked_body.get_children(): shapes.append(collision.shape)
	var before: Dictionary = _snapshot(rig.game)
	var player_pose := Transform3D(Basis.IDENTITY,Content.to_world(rig.game.player_center()))
	# Three full turns, sampled more finely than the eight authored radial facets.
	for index: int in range(192):
		var query_count: int = rig.view.presentation_queries
		rig.view.tick_pose(1.0/120.0,player_pose,Vector3(0,0,-TAU*0.13*3.0/(192.0/120.0)))
		_check(_visible_cart(rig.view) and _vertex_bounds(rig.view).position.y >= -0.00001,"actual rolling vertices stay above ground at phase "+str(index))
		_check(rig.view.presentation_queries-query_count <= 9,"rolling pose remains within bounded physics-query budget")
	_check(_snapshot(rig.game) == before and _resources(rig.view) == resources and _revision(rig.adapter) == revision,"full wheel revolutions preserve model/resources/navigation")
	var cases: Array[Dictionary] = [
		{"id":"front","heading":0.0,"wall":Vector2(1050,807),"size":Vector3(4,2,0.10),"velocity":Vector2(0,-137.5)},
		{"id":"diagonal","heading":-PI*0.25,"wall":Vector2(1080,840),"size":Vector3(0.10,2,4),"velocity":Vector2(97.227,-97.227)}]
	for entry: Dictionary in cases:
		_place(rig.game,Vector2(1050,840)); rig.view.sync()
		var heading: float = entry.heading; var basis := Basis.from_euler(Vector3(0,heading,0))
		var wall := _solid(rig.world,Content.to_world(entry.wall,1.0),entry.size,"mounted_cart_wall")
		await _await_physics()
		var contact: bool = false; var retreat: bool = false
		var queries_before: int = rig.view.presentation_queries
		for index: int in range(32):
			var dt: float = 1.0/60.0
			var start := Vector2(rig.game.p.x,rig.game.p.y)
			var intended: Vector2 = start+entry.velocity*dt
			var body := {"id":"player","x":start.x,"y":start.y,"w":rig.game.p.w,"h":rig.game.p.h}
			var moved: Dictionary = rig.adapter.move_body(body,intended)
			_check(moved.get("position") is Vector2 and moved.position.is_finite(),entry.id+" actual player sweep yields finite accepted position")
			if not moved.get("position") is Vector2: break
			contact = contact or moved.position.distance_to(intended) > 0.001
			rig.game.p.x = moved.position.x; rig.game.p.y = moved.position.y
			var accepted: Vector2 = (moved.position-start)*0.04/dt
			var local_velocity: Vector3 = basis.inverse()*Vector3(accepted.x,0,accepted.y)
			player_pose = Transform3D(basis,Content.to_world(rig.game.player_center()))
			before = _snapshot(rig.game)
			# The preceding real movement may legitimately initialize/reset its
			# navigation epoch. Measure presentation ownership around tick_pose only.
			var pose_revision: int = _revision(rig.adapter)
			var query_count: int = rig.view.presentation_queries
			rig.view.tick_pose(dt,player_pose,local_velocity)
			var offset: Vector3 = rig.view.presentation_offset
			retreat = retreat or offset.length() > 0.005
			_check(rig.view.presentation_clear and _visible_cart(rig.view) and _actual_presentation_clear(rig),entry.id+" mounted art remains visible and independently physics-clear after accepted movement "+str(index))
			_check(offset.is_finite() and absf(offset.y) < 0.00001 and offset.length() <= 0.32001,entry.id+" presentation correction is finite horizontal and bounded")
			_check(_vertex_bounds(rig.view).position.y >= -0.00001,entry.id+" actual cart vertices never penetrate ground")
			var after: Dictionary = _snapshot(rig.game)
			var changed_state: Array[String] = []
			for key: String in before:
				if after.get(key) != before[key]: changed_state.append(key)
			_check(after == before,entry.id+" pose correction preserves authority; changed components="+str(changed_state))
			_check(_resources(rig.view) == resources,entry.id+" pose correction preserves original mesh/material resources")
			_check(_revision(rig.adapter) == pose_revision,entry.id+" pose correction preserves navigation revision; before=%d after=%d" % [pose_revision,_revision(rig.adapter)])
			var current_shapes: Array[Shape3D] = []
			for collision: CollisionShape3D in parked_body.get_children(): current_shapes.append(collision.shape)
			_check(parked_body.collision_layer == 0 and parked_body.get_rid() == body_rid and current_shapes == shapes and _nav(rig.adapter,_owner()).is_empty(),entry.id+" presentation keeps the original body inactive and shapes/RID immutable")
			_check(rig.view.presentation_queries-query_count <= 9,entry.id+" pose uses at most nine physics queries")
		_check(contact and retreat and rig.view.presentation_queries > queries_before,entry.id+" fixture reaches actual player contact and exercises bounded cart separation")
		var left: Node3D = rig.view.get_node("Cart/Art/WheelLeft"); var right: Node3D = rig.view.get_node("Cart/Art/WheelRight")
		var wheel_poses: Array[Transform3D] = [left.transform,right.transform]
		for index: int in range(12): rig.view.tick_pose(1.0/60.0,player_pose,Vector3.ZERO)
		_check(left.transform == wheel_poses[0] and right.transform == wheel_poses[1],entry.id+" blocked actual travel cannot keep wheels spinning")
		wall.free(); await _await_physics()
		rig.view.tick_pose(0.016,player_pose,Vector3.ZERO)
		_check(rig.view.presentation_clear and rig.view.presentation_offset.length() < 0.00001 and _visible_cart(rig.view),entry.id+" removing wall restores source-centered visible pose")
	groups += 1

func _drop_certificates(rig: Dictionary) -> void:
	# Use an actual open Block patch; no fake physics or permissive adapter.
	var desired := Vector2(1050,840)
	rig.game.npcs.clear(); rig.game.s.mode = "playing"; rig.game.p.cartMounted = true; rig.view.sync()
	_place(rig.game,desired+Vector2(-30,10)); await _await_physics()
	var before: Dictionary = _snapshot(rig.game)
	var accepted: Variant = rig.adapter.find_cart_drop(desired,0.0)
	_check(accepted is Vector2 and accepted == desired,"actual unobstructed cart envelope admits exact zero-radius placement")
	_check(_snapshot(rig.game) == before,"spatial drop certification never commits model/RNG/events")
	if not accepted is Vector2: return
	for maximum: float in [-1.0,50.001,NAN,INF]: _check(rig.adapter.find_cart_drop(desired,maximum) == null,"invalid drop bound rejected "+str(maximum))
	_check(rig.adapter.find_cart_drop(Vector2(INF,840),50.0) == null,"nonfinite preferred point rejected")
	_place(rig.game,desired+Vector2(12,10))
	_check(rig.adapter.find_cart_drop(desired,0.0) == null,"cart cannot be placed through actual player/source body")
	_place(rig.game,desired+Vector2(-30,10))
	var center: Vector3 = Content.to_world(desired+Vector2(12,10))
	var obstacle := _solid(rig.world,center+Vector3(0,0.63,0),Vector3(0.16,0.8,0.16)); await _await_physics()
	_check(rig.adapter.find_cart_drop(desired,0.0) == null,"real solid inside basket refuses exact drop")
	obstacle.free(); await _await_physics()
	obstacle = _solid(rig.world,center+Vector3(0,0.42,0),Vector3(0.60,0.84,0.60),"interactiveProps:0"); await _await_physics()
	_check(rig.adapter.find_cart_drop(desired,0.0) == null,"live dynamic-prop collision cannot be excluded with the cart's own body")
	obstacle.free(); await _await_physics()
	# This blocks only the handle extension, beyond the original basket's depth.
	obstacle = _solid(rig.world,center+Vector3(0,1.02,0.49),Vector3(0.12,0.06,0.025)); await _await_physics()
	_check(rig.adapter.find_cart_drop(desired,0.0) == null,"full authored handle envelope prevents clipping missed by basket-only test")
	obstacle.free(); await _await_physics()
	# Each blocker clears the frame/query margin but intersects an exposed wheel.
	for side: float in [-1.0,1.0]:
		obstacle = _solid(rig.world,center+Vector3(side*0.489,0.14,0.256),Vector3(0.006,0.08,0.018)); await _await_physics()
		_check(rig.adapter.find_cart_drop(desired,0.0) == null,"original wheel outside frame refuses clipping on side "+str(side))
		obstacle.free(); await _await_physics()
	var npc: Dictionary = {"id":"cart_clearance_npc","x":desired.x+5,"y":desired.y+5,"w":24.0,"h":28.0,"dead":false,"hostile":false}
	rig.game.npcs.append(npc)
	_check(rig.adapter.find_cart_drop(desired,0.0) == null,"live source NPC body rejects cart before actor mesh instantiation")
	npc.dead = true; _check(rig.adapter.find_cart_drop(desired,0.0) == desired,"dead NPC releases its drop exclusion")
	rig.game.npcs.clear()
	var geometry: Dictionary = rig.adapter.incident_geometry_snapshot()
	var route: Array = [{"from":center+Vector3(-0.6,0.65,0),"to":center+Vector3(0.6,0.65,0),"size":Vector3(0.10,0.20,0.10)}]
	_check(rig.adapter.reserve_incident_corridor("cart_gate",geometry.revision,route,rig.game.p,rig.game.s),"actual shared incident reservation acquires clear corridor")
	_check(rig.adapter.find_cart_drop(desired,0.0) == null,"cart drop respects existing reserved moving-envelope corridor")
	_check(rig.adapter.release_incident_corridor("cart_gate") and rig.adapter.find_cart_drop(desired,0.0) == desired,"releasing shared reservation restores exact valid candidate")
	# Both cart and player are otherwise clear, but a wall cuts the fresh eye ray.
	obstacle = _solid(rig.world,Content.to_world(desired+Vector2(-10,10),1.0),Vector3(0.06,2.0,2.0)); await _await_physics()
	_check(rig.adapter.find_cart_drop(desired,0.0) == null,"fresh eye LOS prevents placing cart across an intervening wall")
	obstacle.free(); await _await_physics()
	_place(rig.game,desired)
	var preferred := Vector2(rig.game.p.x+4,rig.game.p.y+8)
	obstacle = _solid(rig.world,Content.to_world(preferred+Vector2(12,10),0.7),Vector3(6.5,1.4,6.5)); await _await_physics()
	before = _snapshot(rig.game)
	_check(not rig.travel.interact_cart().ok and _snapshot(rig.game) == before,"enclosed50px search refuses dismount atomically")
	var mounted_pose := Transform3D(Basis.IDENTITY,Content.to_world(rig.game.player_center()))
	rig.view.tick_pose(0.016,mounted_pose,Vector3.ZERO)
	_check(not rig.view.presentation_clear and not _visible_cart(rig.view) and rig.view.grip_context(Transform3D(Basis.IDENTITY,mounted_pose.origin+Vector3(0,1.69,0))).is_empty(),"intentional enclosing solid explicitly hides uncertifiable art and releases grips")
	_check(_snapshot(rig.game) == before and rig.view.parked_body().collision_layer == 0,"uncertifiable mounted pose changes no authority or active collision")
	obstacle.free(); await _await_physics()
	rig.view.tick_pose(0.016,mounted_pose,Vector3.ZERO)
	_check(rig.view.presentation_clear and _visible_cart(rig.view),"removed enclosure recovers hidden mounted art without a state reset")
	var dropped: Dictionary = rig.travel.interact_cart()
	_check(dropped.ok and not rig.game.p.cartMounted,"real Travel commits an actual certified drop")
	if dropped.ok:
		_check(dropped.source_drop.distance_to(preferred) <= 50.0 and not Rect2(Vector2(rig.game.p.x,rig.game.p.y),Vector2(rig.game.p.w,rig.game.p.h)).intersects(Rect2(dropped.source_drop,Vector2(24,20))),"committed drop keeps strict search bound and player separation")
		_check(_sync(rig),"committed drop enables original parked geometry")
		await _await_physics()
		_check(_ray_owner(rig.world,dropped.source_drop) == _owner() and _ray_owner(rig.world,Vector2(1000,1600)) != _owner(),"same cart has actual new ray target and no old spawn ghost")
		var approach: Vector3 = rig.adapter.cart_approach(dropped.source_drop)
		_check(approach.is_finite() and _capsule_clear(rig.world,approach),"drop certificate has an actual clear approach after body activation")
		_place(rig.game,Content.to_source(approach)); _check(rig.adapter.can_reach_target(_service()),"drop updates live service to actual current body")
		_check(rig.world.service_points[_service()].source_point == dropped.source_drop,"mutable service uses committed top-left, not original center")
		_check(not rig.adapter.cart_approach(Vector2(1000,1600)).is_finite(),"public current-cart approach refuses old parked coordinates after a committed move")
		var source_approach: Vector2 = Content.to_source(approach)
		var revision: int = _revision(rig.adapter)
		var resident: Dictionary = {"id":"cart_approach_resident","x":source_approach.x-12,"y":source_approach.y-14,"w":24.0,"h":28.0,"hostile":false}
		rig.game.npcs.append(resident)
		var current: Vector3 = rig.adapter.cart_approach(dropped.source_drop)
		_check(_revision(rig.adapter) == revision and (not current.is_finite() or current.distance_to(approach) > 0.05),"live NPC entering cached approach invalidates certificate even without static topology revision")
		if current.is_finite():
			var at: Vector2 = Content.to_source(current)-Vector2(rig.game.p.w,rig.game.p.h)*0.5
			_check(rig.adapter._peer_clear(rig.game.p,at,rig.adapter._contact_peers(rig.game.p)) and _capsule_clear(rig.world,current),"replacement approach passes actual current body/capsule clearance")
		rig.game.npcs.clear()
	groups += 1

func _lifecycle(rig: Dictionary) -> void:
	var valid: Dictionary = rig.game.s.travelRuntime.duplicate(true)
	for broken: Variant in [null,{}, {"cart":{}},{"cart":{"x":NAN,"y":1600,"w":24,"h":20,"type":"cart"}}, {"cart":{"x":1000,"y":1600,"w":25,"h":20,"type":"cart"}}]:
		rig.game.s.travelRuntime = broken
		var before: Dictionary = _snapshot(rig.game)
		_check(not rig.view.sync(),"malformed authoritative cart fails closed")
		# NAN dictionaries do not compare equal; compare serialized contents for this witness.
		_check(JSON.stringify(_snapshot(rig.game)) == JSON.stringify(before),"malformed view read never calls lazy model repair")
		_hidden(rig,"malformed cart")
	rig.game.s.erase("travelRuntime"); _check(not rig.view.sync() and not rig.game.s.has("travelRuntime"),"missing runtime remains absent after rejected pure view read")
	rig.game.s.travelRuntime = valid; rig.game.p.cartMounted = false; _check(_sync(rig),"valid record restores view after failure")
	var previous: Dictionary = rig.travel.cart_record(); var identity: Dictionary = _resources(rig.view)
	for replace: String in ["player","state"]:
		if replace == "player": rig.game.p = rig.game.p.duplicate(true)
		else: rig.game.s = rig.game.s.duplicate(true)
		_check(rig.adapter.begin_cart_epoch(),"new "+replace+" epoch can be cleared before any staging")
		_hidden(rig,"new "+replace+" epoch")
		var revision: int = _revision(rig.adapter)
		_check(rig.adapter.begin_cart_epoch() and _revision(rig.adapter) == revision,"same epoch clearing is an idempotent no-op")
		rig.travel.reset_session("restore",previous); _check(_sync(rig),"same-process restore projects retained parked coordinates")
		_check(rig.travel.cart_record() == previous and _resources(rig.view) == identity,"epoch reset retains source coordinates and adopted resource identities")
	var saved: Dictionary = rig.game.snapshot()
	_check(rig.game.restore(saved).ok,"real source save restores")
	rig.adapter.begin_cart_epoch(); rig.travel.reset_session("restore",previous)
	_check(rig.travel.cart_record() == previous and _sync(rig),"actual same-process restore retains mutable cart location")
	rig.game.fresh(); rig.adapter.begin_cart_epoch(); rig.travel.reset_session("fresh")
	_check(rig.travel.cart_record().x == 1000 and rig.travel.cart_record().y == 1600 and not rig.game.p.cartMounted and _sync(rig),"fresh resets unique cart and parked presentation exactly")
	rig.game.npcs.clear(); rig.game.s.mode = "playing"; rig.game.p.cartMounted = true; rig.game.apply_equip_stats(); rig.view.sync()
	for operation: String in ["die","arrest"]:
		previous = rig.travel.cart_record(); rig.game.call(operation)
		_check(rig.game.p.cartMounted and rig.travel.cart_record() == previous and _sync(rig),operation+" retains mounted flag and source cart position")
	for replacement: String in ["player","state"]:
		_place(rig.game,Vector2(1050,840)); rig.game.s.mode = "playing"; rig.game.p.cartMounted = true; rig.adapter.replace_on_drop = replacement
		var rejected: Dictionary = rig.travel.interact_cart()
		_check(not rejected.ok and rig.game.p.cartMounted,"spatial callback replacing "+replacement+" rejects stale dismount")
		_check({"p":rig.game.p,"s":rig.game.s,"events":rig.game.events} == rig.adapter.replacement_snapshot,"stale callback cannot mutate replacement epoch or emit stale receipt")
		rig.adapter.begin_cart_epoch(); rig.travel.reset_session("restore",previous); rig.view.sync()
	groups += 1

func _dispose(rig: Dictionary) -> void:
	rig.game.p.cartMounted = false; rig.travel.reset_session("fresh"); rig.view.sync()
	var unrelated: Array = _nav(rig.adapter,"props:143"); var witnesses: Dictionary = rig.world.service_points["route:cart_barrier"].duplicate(true)
	rig.view.dispose(); _hidden(rig,"disposed")
	_check(_nav(rig.adapter,"props:143") == unrelated and rig.world.service_points["route:cart_barrier"] == witnesses,"dispose preserves all other owner geometry/services/navigation")
	var revision: int = _revision(rig.adapter); rig.view.dispose()
	_check(_revision(rig.adapter) == revision,"repeated dispose makes no topology change")
	groups += 1
func _independent_cold_and_purchase(first: Dictionary) -> void:
	first.game.p.cartMounted = true; _record(first.game,Vector2(1080,840)); first.view.sync()
	var saved: Dictionary = first.game.snapshot()
	var game := ObservedState.new(); _check(game.restore(saved).ok,"second real state accepts mounted source save")
	var world := World.new(); world.dynamic_cart = true; root.add_child(world); world.build(); await _await_physics()
	var adapter := Adapter.new(world,game); var travel := Travel.new(game,adapter); var view := View.new(); world.add_child(view)
	_check(view.bind(world,adapter,travel) and view.sync(),"independent real world owns independent adopted cart")
	_check(game.p.cartMounted and travel.cart_record().x == 1000 and travel.cart_record().y == 1600,"cold restore uses source spawn while preserving saved mounted flag")
	var player_pose := Transform3D(Basis.IDENTITY,Content.to_world(game.player_center()))
	view.tick_pose(0.01,player_pose,Vector3.ZERO)
	var state_before: Dictionary = _snapshot(game); var poses_before: Dictionary = _poses(view); var resources_before: Dictionary = _resources(view)
	first.view.tick_pose(0.05,Transform3D(Basis.from_euler(Vector3(0,0.7,0)),Content.to_world(first.game.player_center())),Vector3(0,0,-5.5))
	_check(_snapshot(game) == state_before and _poses(view) == poses_before and _resources(view) == resources_before,"one cart pose cannot change another model/instance/resources")
	game.s.mode = "playing"; game.p.copper = 15; game.p.hp = 60
	_place(game,Content.to_source(world.service_points.biggu.approach))
	for index: int in range(2):
		var opened: Dictionary = travel.open("biggu")
		_check(opened.get("ok",false) and opened.has("token"),"actual Big Guy service opens cart purchase")
		if not opened.has("token"): break
		var purchase: Dictionary = travel.select(opened.token,"buy_cart")
		_check(purchase.ok and game.p.cartMounted and game.p.copper == 10-index*5 and game.p.hp == 60,"repeat mounted purchase spends exactly5 copper without healing")
		_check(view.sync() and view.parked_body().collision_layer == 0,"repeat purchase never reactivates parked blocker")
		travel.close(); game.s.mode = "playing"
	# Isolate the ownership witness from a nearby shop's presentation-clearance geometry.
	_place(game,Vector2(1050,840))
	player_pose = Transform3D(Basis.IDENTITY,Content.to_world(game.player_center()))
	view.tick_pose(0.016,player_pose,Vector3.ZERO)
	var camera_pose := Transform3D(Basis.from_euler(Vector3(-0.55,0,0)),player_pose.origin+Vector3(0,1.69,0))
	_check(view.grip_context(camera_pose).size() == 2,"mounted lifetime witness starts with actual usable grips")
	var lifetime: WeakRef = weakref(travel); travel = null; state_before = _snapshot(game)
	_check(lifetime.get_ref() == null and view.grip_context(camera_pose).is_empty(),"expired Travel refuses mounted grips before a sync can mask stale ownership")
	view.tick_pose(0.016,player_pose,Vector3(0,0,-5.5))
	_check(_parts(view).all(func(mesh: MeshInstance3D): return not mesh.is_visible_in_tree()) and view.parked_body().collision_layer == 0,"mounted pose tick itself fails closed on expired Travel")
	_check(_snapshot(game) == state_before and not view.sync(),"expired owner projection leaves surviving model untouched")
	view.dispose(); world.free(); groups += 1
func _run() -> void:
	await _static_regression()
	var rig: Dictionary = await _adoption()
	if _parts(rig.view).size() == 17:
		await _mount_and_pose(rig); _hand_grips(rig); await _mounted_wall_clearance(rig); await _drop_certificates(rig); _lifecycle(rig); await _independent_cold_and_purchase(rig); _dispose(rig)
	_check(groups == 9,"all static/adoption/mount/grip/mounted-clearance/drop/lifecycle/cold-independent/dispose groups completed")
	rig.world.free(); rig.clear(); await process_frame
	if failures.is_empty(): print("3D CART VIEW GATE: PASS (%d checks; original17/real capsule and drop/strict36/epochs/resources)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D CART VIEW GATE: FAIL (%d failures/%d checks)" % [failures.size(),checks]); quit(1)
