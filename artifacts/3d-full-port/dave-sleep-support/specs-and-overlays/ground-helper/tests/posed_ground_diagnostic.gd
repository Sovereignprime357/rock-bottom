extends RefCounted
## Passive, one-capture measurement of existing Dave geometry. No pose tick.

static func _v(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

static func _t(value: Transform3D) -> Dictionary:
	return {"origin":_v(value.origin),"basis_x":_v(value.basis.x),"basis_y":_v(value.basis.y),"basis_z":_v(value.basis.z)}

static func _push(groups: Dictionary, key: String, point: Vector3) -> void:
	if not groups.has(key): groups[key] = {"count":0,"minimum":point,"maximum":point,"bounds_minimum":point,"bounds_maximum":point}
	var group: Dictionary = groups[key]
	group.count += 1
	var minimum: Vector3 = group.minimum
	var maximum: Vector3 = group.maximum
	if point.y < minimum.y: group.minimum = point
	if point.y > maximum.y: group.maximum = point
	var low: Vector3 = group.bounds_minimum
	var high: Vector3 = group.bounds_maximum
	group.bounds_minimum = Vector3(minf(low.x,point.x),minf(low.y,point.y),minf(low.z,point.z))
	group.bounds_maximum = Vector3(maxf(high.x,point.x),maxf(high.y,point.y),maxf(high.z,point.z))

static func _ground(space: PhysicsDirectSpaceState3D, point: Vector3, ray_origin_y: float) -> Dictionary:
	var from := Vector3(point.x,ray_origin_y,point.z)
	var to := point-Vector3.UP*3.0
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return {"ok":false,"reason":"no_support_ray_hit","point":_v(point),"ray_from":_v(from),"ray_to":_v(to)}
	var normal: Vector3 = hit.normal
	var position: Vector3 = hit.position
	if normal.y < 0.5: return {"ok":false,"reason":"support_not_upward","normal":_v(normal),"point":_v(point),"ray_from":_v(from),"ray_to":_v(to)}
	var collider: Object = hit.collider
	return {"ok":true,"point":_v(point),"ground":_v(position),"normal":_v(normal),"clearance_m":point.y-position.y,"collider":str(collider.get_path()) if collider is Node else str(collider),"ray_from":_v(from),"ray_to":_v(to)}

static func measure(art: Node3D) -> Dictionary:
	if art == null or not art.is_inside_tree() or not art.has_meta("roster_rig"):
		return {"ok":false,"reason":"missing_live_rig"}
	var rig: Dictionary = art.get_meta("roster_rig")
	if String(rig.definition.visual_id) != "dave": return {"ok":false,"reason":"not_dave"}
	var head_binding: Dictionary = rig.get("prop_lookup",{}).get("head",{})
	var pillow_binding: Dictionary = rig.get("prop_lookup",{}).get("pillow",{})
	var head_attachment := head_binding.get("node") as Node3D
	var pillow_attachment := pillow_binding.get("node") as Node3D
	if not is_instance_valid(head_attachment) or int(head_binding.get("bone",-1)) != int(rig.lookup.get("head",-2)):
		return {"ok":false,"reason":"missing_actual_head_attachment"}
	if not is_instance_valid(pillow_attachment): return {"ok":false,"reason":"missing_actual_pillow_attachment"}
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
		var is_rigid_head: bool = part.skin == null and (part == head_attachment or head_attachment.is_ancestor_of(part))
		var is_pillow: bool = part.skin == null and (part == pillow_attachment or pillow_attachment.is_ancestor_of(part))
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
				if part.skin != null:
					_push(groups,"skinned_head" if head_weight >= 0.25 else "skinned_body",point)
					if head_weight >= 0.25: _push(groups,"head",point)
				else:
					_push(groups,"rigid_attachments",point)
					if is_rigid_head:
						_push(groups,"rigid_head",point)
						_push(groups,"head",point)
					if is_pillow: _push(groups,"pillow",point)
		if not local_groups.is_empty():
			parts.append({"path":path,"skinned":part.skin != null,"rigid_head":is_rigid_head,"pillow":is_pillow,"vertices":local_groups.part.count,"minimum_world":_v(local_groups.part.minimum),"maximum_world":_v(local_groups.part.maximum),"bounds_minimum_world":_v(local_groups.part.bounds_minimum),"bounds_maximum_world":_v(local_groups.part.bounds_maximum),"global_transform":_t(part.global_transform)})
	if groups.is_empty(): return {"ok":false,"reason":"no_visible_geometry"}
	var space: PhysicsDirectSpaceState3D = art.get_world_3d().direct_space_state
	var result_groups: Dictionary = {}
	var ok: bool = groups.has("rigid_head") and groups.has("pillow")
	var ray_origin_y := maxf(art.global_position.y+2.0,float(groups.all_visible.bounds_maximum.y)+0.5)
	for key: String in groups:
		var group: Dictionary = groups[key]
		var support := _ground(space,group.minimum,ray_origin_y)
		ok = ok and bool(support.ok)
		result_groups[key] = {"vertices":group.count,"minimum_world":_v(group.minimum),"maximum_world":_v(group.maximum),"bounds_minimum_world":_v(group.bounds_minimum),"bounds_maximum_world":_v(group.bounds_maximum),"support":support}
	var root_support := _ground(space,art.global_position,ray_origin_y)
	return {"ok":ok and bool(root_support.ok),"format":"dave-posed-ground-diagnostic-v2","process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"art_global_transform":_t(art.global_transform),"head_attachment":{"path":String(art.get_path_to(head_attachment)),"bone":head_binding.bone,"global_transform":_t(head_attachment.global_transform)},"pillow_attachment":{"path":String(art.get_path_to(pillow_attachment)),"bone":pillow_binding.bone,"global_transform":_t(pillow_attachment.global_transform)},"rig_state":rig.last_state.duplicate(true),"rig_time":rig.time,"ray_origin_y":ray_origin_y,"root_support":root_support,"groups":result_groups,"parts":parts,"vertices":total_vertices,"no_pose_or_simulation_writes":true}
