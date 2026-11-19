extends RefCounted
## Passive, one-capture measurement of existing Dave geometry. No pose tick.

static func _v(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

static func _push(groups: Dictionary, key: String, point: Vector3) -> void:
	if not groups.has(key): groups[key] = {"count":0,"minimum":point,"maximum":point}
	var group: Dictionary = groups[key]
	group.count += 1
	var minimum: Vector3 = group.minimum
	var maximum: Vector3 = group.maximum
	if point.y < minimum.y: group.minimum = point
	group.maximum = Vector3(maxf(maximum.x,point.x),maxf(maximum.y,point.y),maxf(maximum.z,point.z))

static func _ground(space: PhysicsDirectSpaceState3D, point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.04,point-Vector3.UP*3.0,1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return {"ok":false,"reason":"no_support_ray_hit","point":_v(point)}
	var normal: Vector3 = hit.normal
	var position: Vector3 = hit.position
	if normal.y < 0.5: return {"ok":false,"reason":"support_not_upward","normal":_v(normal),"point":_v(point)}
	var collider: Object = hit.collider
	return {"ok":true,"point":_v(point),"ground":_v(position),"normal":_v(normal),"clearance_m":point.y-position.y,"collider":str(collider.get_path()) if collider is Node else str(collider)}

static func measure(art: Node3D) -> Dictionary:
	if art == null or not art.is_inside_tree() or not art.has_meta("roster_rig"):
		return {"ok":false,"reason":"missing_live_rig"}
	var rig: Dictionary = art.get_meta("roster_rig")
	if String(rig.definition.visual_id) != "dave": return {"ok":false,"reason":"not_dave"}
	var stack: Array[Node] = [art]
	var groups: Dictionary = {}
	var parts: Array[Dictionary] = []
	var visited: int = 0
	var total_vertices: int = 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		visited += 1
		if visited > 512: return {"ok":false,"reason":"node_cap"}
		for child: Node in node.get_children(): stack.append(child)
		if not node is MeshInstance3D: continue
		var part := node as MeshInstance3D
		if not part.is_visible_in_tree(): continue
		if part.mesh == null: continue
		if parts.size() >= 64: return {"ok":false,"reason":"part_cap"}
		var path := String(art.get_path_to(part))
		var palette: Array[Transform3D] = []
		var bound_bones: Array[int] = []
		var head: int = -1
		if part.skin != null:
			var skeleton := part.get_node_or_null(part.skeleton) as Skeleton3D
			if skeleton == null: return {"ok":false,"reason":"missing_skeleton","part":path}
			head = skeleton.find_bone("head")
			for index: int in range(part.skin.get_bind_count()):
				var bone: int = part.skin.get_bind_bone(index)
				if bone < 0: return {"ok":false,"reason":"unnumbered_bind","part":path}
				bound_bones.append(bone)
				palette.append(skeleton.get_bone_global_pose(bone)*part.skin.get_bind_pose(index))
		var local_groups: Dictionary = {}
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total_vertices += vertices.size()
			if total_vertices > 200000: return {"ok":false,"reason":"vertex_cap"}
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			if part.skin != null:
				bones = arrays[Mesh.ARRAY_BONES]
				weights = arrays[Mesh.ARRAY_WEIGHTS]
				if bones.size() != vertices.size()*4 or weights.size() != vertices.size()*4:
					return {"ok":false,"reason":"unsupported_skin_layout","part":path}
			for index: int in range(vertices.size()):
				var point: Vector3 = vertices[index]
				var head_weight: float = 0.0
				if part.skin != null:
					point = Vector3.ZERO
					for slot: int in range(4):
						var offset: int = index*4+slot
						var binding: int = bones[offset]
						if binding < 0 or binding >= palette.size(): return {"ok":false,"reason":"bad_binding","part":path}
						point += (palette[binding]*vertices[index])*weights[offset]
						if bound_bones[binding] == head: head_weight += weights[offset]
				point = part.global_transform*point
				if not point.is_finite(): return {"ok":false,"reason":"nonfinite_vertex","part":path}
				_push(groups,"all_visible",point)
				_push(local_groups,"part",point)
				if part.skin != null: _push(groups,"skinned_head" if head_weight >= 0.25 else "skinned_body",point)
				else:
					_push(groups,"rigid_attachments",point)
					if path.to_lower().contains("pillow"): _push(groups,"pillow",point)
		if not local_groups.is_empty():
			parts.append({"path":path,"skinned":part.skin != null,"vertices":local_groups.part.count,"minimum_world":_v(local_groups.part.minimum)})
	if groups.is_empty(): return {"ok":false,"reason":"no_visible_geometry"}
	var space: PhysicsDirectSpaceState3D = art.get_world_3d().direct_space_state
	var result_groups: Dictionary = {}
	var ok: bool = true
	for key: String in groups:
		var group: Dictionary = groups[key]
		var support := _ground(space,group.minimum)
		ok = ok and bool(support.ok)
		result_groups[key] = {"vertices":group.count,"minimum_world":_v(group.minimum),"support":support}
	var root_support := _ground(space,art.global_position)
	return {"ok":ok and bool(root_support.ok),"format":"dave-posed-ground-diagnostic-v1","process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"art_global_transform":str(art.global_transform),"rig_state":rig.last_state.duplicate(true),"rig_time":rig.time,"root_support":root_support,"groups":result_groups,"parts":parts,"vertices":total_vertices,"no_pose_or_simulation_writes":true}
