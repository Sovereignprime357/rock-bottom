class_name RockBottomCartView
extends Node3D
## One adopted cart. Travel owns every record/transaction; this node projects it.
const Content = preload("res://scripts/content_catalog.gd")
static var _shapes: Dictionary = {}
var target_id: String = ""
var source_owner: String = ""
var mounted: bool = false
var point := Vector2.INF
var presentation_clear: bool = false
var presentation_offset := Vector3.ZERO
var presentation_queries: int = 0
var _world_ref: WeakRef
var _adapter_ref: WeakRef
var _travel_ref: WeakRef
var _host_ref: WeakRef
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _holder: Node3D
var _art: Node3D
var _body: StaticBody3D
var _handle: MeshInstance3D
var _grips: Array[Node3D] = []
var _wheels: Array[Node3D] = []
var _originals: Array[Dictionary] = []
var _bound: bool = false
var _active: bool = false
var _pose_valid: bool = false
var _wheel_angle: float = 0.0
var _yaw: float = 0.0
var _mounted_query: PhysicsShapeQueryParameters3D
const MOUNTED_SIZE := Vector3(0.96,1.055,0.925)
const MOUNTED_CENTER := Vector3(0,0.5375,0.0625)
const MAX_PRESENTATION_OFFSET: float = 0.32

func _object(reference: WeakRef) -> Object: return reference.get_ref() if reference != null else null
func parked_body() -> StaticBody3D: return _body
func collision_rids() -> Array[RID]:
	var result: Array[RID] = []
	if is_instance_valid(_body): result.append(_body.get_rid())
	return result
func _number(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value))
func _authority_current() -> bool:
	var host: Object = _object(_host_ref)
	if _object(_world_ref) == null or _object(_adapter_ref) == null or _object(_travel_ref) == null or host == null: return false
	if not is_same(_player_epoch,host.p) or not is_same(_state_epoch,host.s) or host.p.get("cartMounted") != true: return false
	return not _record().is_empty()
func _record() -> Dictionary:
	var host: Object = _object(_host_ref); var travel: Object = _object(_travel_ref)
	if host == null or travel == null or not is_same(travel.get("host"),host): return {}
	var state: Variant = host.get("s"); var player: Variant = host.get("p")
	if not state is Dictionary or not player is Dictionary or not player.get("cartMounted") is bool: return {}
	var runtime: Variant = state.get("travelRuntime")
	if not runtime is Dictionary or not runtime.get("cart") is Dictionary: return {}
	var cart: Dictionary = runtime.cart
	if cart.get("type") != "cart" or cart.get("w") != 24.0 or cart.get("h") != 20.0: return {}
	if not _number(cart.get("x")) or not _number(cart.get("y")): return {}
	var bounds: Dictionary = Content.load_content().world.bounds
	if cart.x < 0 or cart.y < 0 or cart.x+24.0 > bounds.w or cart.y+20.0 > bounds.h: return {}
	# Read the sole existing record without invoking Travel's lazy repair path.
	# Callers only inspect it; no per-pose detached record allocation is needed.
	return cart

func _part_kind(mesh: MeshInstance3D) -> String:
	if mesh.get_meta("cart_part","") == "handle" and mesh.mesh is ArrayMesh:
		var bounds: AABB = mesh.mesh.get_aabb()
		if bounds.position.is_equal_approx(Vector3(-0.48,-0.019,-0.019)) and bounds.size.is_equal_approx(Vector3(0.96,0.038,0.038)) and mesh.mesh.get_surface_count() == 1: return "handle"
	if mesh.mesh is CylinderMesh:
		var cylinder: CylinderMesh = mesh.mesh as CylinderMesh
		if is_equal_approx(cylinder.height,0.14) and is_equal_approx(cylinder.top_radius,0.13) and is_equal_approx(cylinder.bottom_radius,0.13): return "wheel"
	elif mesh.mesh is BoxMesh:
		var size: Vector3 = (mesh.mesh as BoxMesh).size
		if size.is_equal_approx(Vector3(0.96,0.08,0.80)): return "frame"
		if size.is_equal_approx(Vector3(0.045,0.52,0.72)): return "side"
		if size.is_equal_approx(Vector3(0.96,0.025,0.025)): return "wire"
		if size.is_equal_approx(Vector3(0.96,0.55,0.80)): return "proxy"
	return ""

func bind(world: Node3D,adapter: RefCounted,travel: RefCounted) -> bool:
	if _bound: return is_same(world,_object(_world_ref)) and is_same(adapter,_object(_adapter_ref)) and is_same(travel,_object(_travel_ref))
	if not is_inside_tree() or world == null or world.get("dynamic_cart") != true or adapter == null or travel == null: return false
	for method: StringName in [&"bind_cart",&"update_navigation_obstacles",&"cart_approach"]:
		if not adapter.has_method(method): return false
	if not travel.has_method(&"cart_record") or travel.get("host") == null: return false
	var owner_index: int = -1
	for index: int in range(world.content.props.size()):
		if world.content.props[index].get("type") != "cart": continue
		if owner_index >= 0: return false
		owner_index = index
	if owner_index < 0: return false
	var owner := "props:%d" % owner_index
	var originals: Array[MeshInstance3D] = []
	var counts: Dictionary = {"frame":0,"side":0,"wire":0,"wheel":0,"proxy":0,"handle":0}
	for child: Node in world.get_children():
		if str(child.get_meta("source_owner","")) != owner: continue
		if child is CollisionObject3D: return false # Never coexist with seed solids.
		if not child is MeshInstance3D: continue
		var kind: String = _part_kind(child)
		if kind.is_empty() or child.mesh == null or child.material_override == null: return false
		counts[kind] += 1; originals.append(child)
	if originals.size() != 17 or counts != {"frame":1,"side":2,"wire":10,"wheel":2,"proxy":1,"handle":1}: return false
	_world_ref = weakref(world); _adapter_ref = weakref(adapter); _travel_ref = weakref(travel); _host_ref = weakref(travel.get("host"))
	if _record().is_empty(): _forget(); return false
	target_id = "prop:%d" % owner_index; source_owner = owner
	_holder = Node3D.new(); _holder.name = "Cart"; add_child(_holder)
	_holder.global_position = Content.body_position(world.content.props[owner_index])
	_art = Node3D.new(); _art.name = "Art"; _holder.add_child(_art); _art.visible = false
	_body = StaticBody3D.new(); _body.name = "Body"; _body.collision_layer = 0; _body.collision_mask = 0; _body.set_meta("source_owner",owner); _holder.add_child(_body)
	for item: Array in [["Frame",Vector3(0.96,0.08,0.80),0.28],["Basket",Vector3(0.96,0.55,0.80),0.63]]:
		if not _shapes.has(item[0]):
			var shape := BoxShape3D.new(); shape.size = item[1]; _shapes[item[0]] = shape
		var collision := CollisionShape3D.new(); collision.name = item[0]; collision.shape = _shapes[item[0]]; collision.position.y = item[2]; _body.add_child(collision)
	if adapter.bind_cart(travel,self) != true:
		_holder.free(); _holder = null; _body = null; _art = null; _forget(); return false
	for mesh: MeshInstance3D in originals:
		var kind: String = _part_kind(mesh)
		mesh.reparent(_art,true)
		_originals.append({"mesh":mesh,"transform":mesh.transform,"visible":kind != "proxy"})
		mesh.visible = kind != "proxy"
		if kind == "handle": _handle = mesh
		if kind == "wheel":
			var wheel := Node3D.new(); wheel.name = "WheelLeft" if _wheels.is_empty() else "WheelRight"; _art.add_child(wheel)
			wheel.transform = mesh.transform; mesh.reparent(wheel,true); _wheels.append(wheel)
	for side: int in [-1,1]:
		var grip := Node3D.new(); grip.name = "GripLeft" if side < 0 else "GripRight"; _art.add_child(grip)
		grip.position = _handle.position+Vector3(-float(side)*0.25,0,0); _grips.append(grip)
	_bound = true
	world.service_points.erase(target_id)
	return true

func clear_active() -> void:
	if is_instance_valid(_art): _art.visible = false
	if is_instance_valid(_body): _body.collision_layer = 0
	var world: Object = _object(_world_ref); var adapter: Object = _object(_adapter_ref)
	if world != null and not target_id.is_empty(): world.service_points.erase(target_id)
	if _active and adapter != null: adapter.update_navigation_obstacles(source_owner,[])
	_active = false; _pose_valid = false; presentation_clear = false; presentation_offset = Vector3.ZERO

func _restore_wheels() -> void:
	_wheel_angle = 0.0
	for wheel: Node3D in _wheels: wheel.basis = Basis.IDENTITY

func _pose_wheels() -> void:
	for wheel: Node3D in _wheels: wheel.basis = Basis(Vector3.RIGHT,_wheel_angle)*Basis(Vector3.FORWARD,PI*0.5)

func _project_mounted(center: Vector3) -> void:
	# This reads static physics and moves only art. Travel/player/body/nav stay authoritative.
	var world: Node3D = _object(_world_ref) as Node3D
	presentation_clear = false; presentation_offset = Vector3.ZERO
	if world == null or not world.is_inside_tree(): _art.visible = false; return
	if _mounted_query == null:
		_mounted_query = PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new(); shape.size = MOUNTED_SIZE
		_mounted_query.shape = shape; _mounted_query.collision_mask = 1; _mounted_query.margin = 0.002
		_mounted_query.exclude = collision_rids()
	var mounted_basis := Basis(Vector3.UP,_yaw+PI)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for attempt: int in range(5):
		var candidate := Transform3D(mounted_basis,center+presentation_offset)
		_mounted_query.transform = Transform3D(mounted_basis,candidate*MOUNTED_CENTER)
		presentation_queries += 1
		if space.intersect_shape(_mounted_query,1).is_empty():
			_holder.global_transform = candidate; presentation_clear = true; _art.visible = true; _pose_valid = true
			return
		if attempt == 4: break
		presentation_queries += 1
		var contact: Dictionary = space.get_rest_info(_mounted_query)
		if contact.is_empty() or not contact.get("normal") is Vector3 or not contact.get("point") is Vector3: break
		var normal: Vector3 = contact.normal; normal.y = 0.0
		var contact_point: Vector3 = contact.point
		if not normal.is_finite() or not contact_point.is_finite() or normal.length_squared() < 0.000001: break
		normal = normal.normalized()
		var support: float = absf(normal.dot(mounted_basis.x))*MOUNTED_SIZE.x*0.5+absf(normal.dot(mounted_basis.z))*MOUNTED_SIZE.z*0.5
		var distance: float = normal.dot(_mounted_query.transform.origin-contact_point)
		var separation: float = maxf(0.004,support+0.004-distance)
		var proposed: Vector3 = presentation_offset+normal*separation
		if not proposed.is_finite() or proposed.length() > MAX_PRESENTATION_OFFSET: break
		presentation_offset = proposed
	# No clear bounded pose. Keep the failure observable; do not conceal a passing claim.
	_holder.global_transform = Transform3D(mounted_basis,center+presentation_offset)
	_art.visible = false; _pose_valid = false

func sync() -> bool:
	var world: Object = _object(_world_ref); var adapter: Object = _object(_adapter_ref); var host: Object = _object(_host_ref)
	if not _bound or world == null or adapter == null or host == null: clear_active(); return false
	var changed_epoch: bool = not is_same(_player_epoch,host.p) or not is_same(_state_epoch,host.s)
	if changed_epoch:
		clear_active(); _player_epoch = host.p; _state_epoch = host.s; _restore_wheels(); _yaw = 0.0
	var cart: Dictionary = _record()
	if cart.is_empty(): clear_active(); return false
	var next_point := Vector2(cart.x,cart.y)
	var next_mounted: bool = host.p.cartMounted
	var changed: bool = changed_epoch or next_point != point or next_mounted != mounted
	point = next_point; mounted = next_mounted
	if mounted:
		if _active: clear_active()
		if changed: _restore_wheels()
		_pose_wheels(); _project_mounted(Content.body_position(host.p))
		return true
	if changed or not _active:
		_restore_wheels(); _holder.global_transform = Transform3D(Basis.IDENTITY,Content.to_world(point+Vector2(12,10)))
		_body.collision_layer = 1; _art.visible = true
		var obstacles: Array[Dictionary] = []
		for shape: CollisionShape3D in _body.get_children():
			var size: Vector3 = (shape.shape as BoxShape3D).size
			obstacles.append({"owner":source_owner,"body":_body,"bounds":shape.global_transform*AABB(-size*0.5,size)})
		adapter.update_navigation_obstacles(source_owner,obstacles)
		world.service_points[target_id] = {"kind":"cart","structure_id":source_owner,"source_point":point,"target":_handle.global_position,"reach":1.44,"approach":adapter.cart_approach(point),"dynamic":true}
		_active = true
	_pose_valid = false; presentation_clear = false; presentation_offset = Vector3.ZERO
	return true

func tick_pose(delta: float,player_transform: Transform3D,actual_local_velocity: Vector3) -> void:
	if not _bound or not mounted or not is_finite(delta) or delta <= 0 or not player_transform.is_finite() or not actual_local_velocity.is_finite(): return
	var host: Object = _object(_host_ref)
	if not _authority_current(): clear_active(); return
	var forward: Vector3 = -player_transform.basis.z; forward.y = 0
	if forward.length_squared() < 0.000001: return
	forward = forward.normalized(); _yaw = atan2(-forward.x,-forward.z)
	var distance: float = clampf(-actual_local_velocity.z,-20.0,20.0)*minf(delta,0.1)
	_wheel_angle = fposmod(_wheel_angle+distance/0.13,TAU)
	_pose_wheels(); _project_mounted(Content.body_position(host.p))

func grip_context(camera_transform: Transform3D,vertical_fov: float = 78.0,aspect: float = 16.0/9.0) -> Dictionary:
	if not _bound or not mounted or not _pose_valid or not _art.visible or not camera_transform.is_finite() or absf(camera_transform.basis.determinant()) < 0.000001: return {}
	if not is_finite(vertical_fov) or not is_finite(aspect) or vertical_fov <= 1.0 or vertical_fov >= 179.0 or aspect <= 0.0: return {}
	if not _authority_current(): return {}
	var inverse: Transform3D = camera_transform.affine_inverse()
	var vertical: float = tan(deg_to_rad(vertical_fov)*0.5)
	var points: Array[Vector3] = []
	for marker: Node3D in _grips:
		var local: Vector3 = inverse*marker.global_position
		if not local.is_finite() or local.z > -0.44 or local.z < -1.3 or absf(local.x) > 0.72 or local.y < -0.90 or local.y > 0.80: return {}
		if absf(local.y)+0.04 > -local.z*vertical or absf(local.x)+0.04 > -local.z*vertical*aspect: return {}
		points.append(local)
	return {"left":points[0],"right":points[1]} if points.size() == 2 else {}

func _forget() -> void:
	_world_ref = null; _adapter_ref = null; _travel_ref = null; _host_ref = null
	target_id = ""; source_owner = ""; _bound = false
func dispose() -> void:
	clear_active(); _forget()
func _exit_tree() -> void: dispose()
