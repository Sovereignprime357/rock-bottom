class_name RockBottomInteractivePropView
extends Node3D
## Original prop meshes, source-clock poses and live physical presentation only.
const Content = preload("res://scripts/content_catalog.gd")
static var _shapes: Dictionary = {}
var _world_ref: WeakRef
var _adapter_ref: WeakRef
var _actions_ref: WeakRef
var _slots: Dictionary = {}
var _bound: bool = false

func _object(reference: WeakRef) -> Object: return reference.get_ref() if reference != null else null
func _index(id: String) -> int:
	if not id.begins_with("interactive:"): return -1
	var value: String = id.trim_prefix("interactive:")
	if not value.is_valid_int(): return -1
	var index: int = int(value)
	return index if index >= 0 and index < 14 and str(index) == value else -1
func slot(id: String) -> Node3D: return _slots[id].slot if _slots.has(id) else null
func collider(id: String) -> StaticBody3D: return _slots[id].body if _slots.has(id) else null
func collision_rid(id: String) -> RID:
	var body: StaticBody3D = collider(id)
	return body.get_rid() if body != null else RID()
func bind(world: Node3D,adapter: RefCounted,actions: RefCounted) -> bool:
	if _bound: return is_same(world,_object(_world_ref)) and is_same(adapter,_object(_adapter_ref)) and is_same(actions,_object(_actions_ref))
	if not is_inside_tree() or world == null or world.get("dynamic_interactive") != true or adapter == null or actions == null: return false
	if not adapter.has_method(&"bind_interactive_props") or not adapter.has_method(&"update_navigation_obstacles") or not adapter.has_method(&"interactive_approach") or not actions.has_method(&"render_records") or not actions.has_method(&"ready"): return false
	var originals: Dictionary = {}
	for index: int in range(14): originals["interactiveProps:%d" % index] = []
	for child: Node in world.get_children():
		if child is MeshInstance3D:
			var owner: String = str(child.get_meta("source_owner",""))
			if owner.begins_with("interactiveProps:") and not originals.has(owner): return false
			if originals.has(owner): originals[owner].append(child)
	for index: int in range(14):
		var nodes: Array = originals["interactiveProps:%d" % index]
		if nodes.size() != 2: return false
		# Godot may suffix duplicate sibling names with an internal @ identifier;
		# geometry identity is also checked through the two expected mesh dimensions.
		for part: int in range(2):
			if not nodes[part].mesh is CylinderMesh: return false
			var expected_height: float = ([0.76,0.08] if index < 6 else [0.25,0.10])[part]
			if not is_equal_approx(nodes[part].mesh.height,expected_height): return false
	_world_ref = weakref(world); _adapter_ref = weakref(adapter); _actions_ref = weakref(actions)
	for index: int in range(14):
		var id := "interactive:%d" % index
		var owner := "interactiveProps:%d" % index
		var kind: String = "trashcan" if index < 6 else "b_bottle"
		var holder := Node3D.new(); holder.name = "interactive_%02d" % index; add_child(holder)
		var source: Dictionary = world.content.interactiveProps[index]
		holder.global_position = Content.to_world(Vector2(source.x,source.y))
		var art := Node3D.new(); art.name = "Art"; holder.add_child(art)
		for node: MeshInstance3D in originals[owner]: node.reparent(art,true); node.visible = true
		art.visible = false
		var height: float = 0.76 if index < 6 else 0.25
		var radius: float = 0.30 if index < 6 else 0.065
		if not _shapes.has(kind):
			var shape := CylinderShape3D.new(); shape.height = height; shape.radius = radius; _shapes[kind] = shape
		var body := StaticBody3D.new(); body.name = "Body"; body.collision_layer = 0; body.collision_mask = 0
		body.set_meta("source_owner",owner); holder.add_child(body); body.position.y = height*0.5
		var collision := CollisionShape3D.new(); collision.shape = _shapes[kind]; body.add_child(collision)
		_slots[id] = {"slot":holder,"art":art,"body":body,"owner":owner,"kind":kind,"active":false,"point":Vector2.INF,
			"bounds":AABB(Vector3(-radius,-height*0.5,-radius),Vector3(radius*2,height,radius*2))}
		world.service_points.erase(id)
	_bound = true
	return adapter.bind_interactive_props(actions,self)

func _number(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value))
func _valid(rows: Array) -> bool:
	if rows.size() != 14: return false
	var bounds: Dictionary = Content.load_content().world.bounds
	for index: int in range(14):
		if not rows[index] is Dictionary: return false
		var row: Dictionary = rows[index]
		if row.get("id") != "interactive:%d" % index or row.get("index") != index or row.get("type") != ("trashcan" if index < 6 else "b_bottle"): return false
		if not _number(row.get("x")) or not _number(row.get("y")) or row.x < 0 or row.y < 0 or row.x > bounds.w or row.y > bounds.h: return false
		if not row.get("placed") is bool or not row.get("pending") is bool or (row.placed and row.pending): return false
		if index >= 6:
			if not row.get("broken") is bool: return false
		else:
			for key: String in ["cdT","tipT","rotPulse"]:
				if not _number(row.get(key)): return false
			if row.tipT > 200 or row.rotPulse > 200 or row.tipT < -50 or row.rotPulse < -50: return false
	return true
func _disable(entry: Dictionary,id: String) -> void:
	entry.art.visible = false; entry.body.collision_layer = 0
	var world: Object = _object(_world_ref)
	if world != null: world.service_points.erase(id)
	if entry.active:
		var adapter: Object = _object(_adapter_ref)
		if adapter != null: adapter.update_navigation_obstacles(entry.owner,[])
	entry.active = false
func _hide_all() -> void:
	for id: String in _slots: _disable(_slots[id],id)
func clear_active() -> void: _hide_all()
func sync_current() -> bool:
	var world: Object = _object(_world_ref); var adapter: Object = _object(_adapter_ref); var actions: Object = _object(_actions_ref)
	if not _bound or world == null or adapter == null or actions == null or not actions.ready():
		_hide_all(); return false
	var rows: Array = actions.render_records()
	if not _valid(rows): _hide_all(); return false
	return _apply_rows(rows,world,adapter)
func sync(rows: Array) -> bool:
	var world: Object = _object(_world_ref); var adapter: Object = _object(_adapter_ref); var actions: Object = _object(_actions_ref)
	if not _bound or world == null or adapter == null or actions == null or not actions.ready() or not _valid(rows) or rows != actions.render_records():
		_hide_all(); return false
	return _apply_rows(rows,world,adapter)
func _apply_rows(rows: Array,world: Object,adapter: Object) -> bool:
	for row: Dictionary in rows:
		var id: String = row.id; var entry: Dictionary = _slots[id]
		var point := Vector2(row.x,row.y)
		var active: bool = row.placed and not row.pending and not row.get("broken",false)
		var moved: bool = point != entry.point
		if moved: entry.slot.global_position = Content.to_world(point); entry.point = point
		if not active: _disable(entry,id); continue
		entry.art.visible = true
		if entry.kind == "trashcan":
			entry.art.rotation.z = sin(float(row.tipT)/30.0)*0.4 if row.tipT > 0 else 0.0
			entry.art.scale = Vector3.ONE*(1.0+float(row.rotPulse)/1000.0 if row.rotPulse > 0 else 1.0)
		if not entry.active or moved:
			entry.body.collision_layer = 1
			adapter.update_navigation_obstacles(entry.owner,[{"owner":entry.owner,"bounds":entry.body.global_transform*entry.bounds}])
			var height: float = 0.50 if entry.kind == "trashcan" else 0.17
			world.service_points[id] = {"kind":entry.kind,"structure_id":entry.owner,"source_point":point,
				"target":Content.to_world(point,height),"reach":2.0 if entry.kind == "trashcan" else 1.9,
				"approach":adapter.interactive_approach(id,point),"dynamic":true}
		entry.active = true
	return true
func dispose() -> void:
	_hide_all(); _bound = false
	_world_ref = null; _adapter_ref = null; _actions_ref = null
func _exit_tree() -> void: dispose()
