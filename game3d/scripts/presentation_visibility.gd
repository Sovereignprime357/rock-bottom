class_name RockBottomPresentationVisibility
extends RefCounted
## Conservative visual work eligibility. Never hides nodes or changes model state.

static func frame_context(camera: Camera3D, sun: DirectionalLight3D, min_receiver_y: float = -INF, sole_shadow_light: bool = false) -> Dictionary:
	if camera == null or sun == null or not camera.is_inside_tree() or not sun.is_inside_tree(): return {}
	var planes: Array[Plane] = camera.get_frustum()
	return {"camera":camera.global_position,"planes":planes,"shadow_enabled":sun.shadow_enabled,
		"shadow_distance":sun.directional_shadow_max_distance,"light_direction":-sun.global_basis.z,
		"min_receiver_y":min_receiver_y,"sole_shadow_light":sole_shadow_light}


static func needs_pose(art: Node3D, context: Dictionary) -> bool:
	if art == null or not art.is_inside_tree(): return true
	var radius: float = local_radius(art)
	var scale_bound: float = _stretch(art.global_basis)
	return sphere_needs_pose(art.global_position,radius*scale_bound,context)


static func sphere_needs_pose(center: Vector3, radius: float, context: Dictionary) -> bool:
	if not center.is_finite() or not is_finite(radius) or radius <= 0.0: return true
	if not context.get("camera") is Vector3 or not (context.camera as Vector3).is_finite(): return true
	if not context.get("planes") is Array or context.planes.size() != 6: return true
	for raw: Variant in context.planes:
		if not raw is Plane: return true
		var plane: Plane = raw
		if not plane.normal.is_finite() or not is_finite(plane.d) or absf(plane.normal.length_squared()-1.0) > 0.0001: return true
	if not _separated(center,center,radius,context.planes): return true
	# Root certifies all current fixture/beacon shadow flags; an unmodeled light
	# could illuminate a visible receiver from another direction.
	if not context.get("sole_shadow_light") is bool or not context.sole_shadow_light: return true
	if not context.get("shadow_enabled") is bool: return true
	if not context.shadow_enabled: return false
	if not context.get("shadow_distance") is float and not context.get("shadow_distance") is int: return true
	var distance: float = float(context.shadow_distance)
	if not is_finite(distance) or distance <= 0.0: return true # Zero means unbounded, not absent.
	if not context.get("light_direction") is Vector3: return true
	var direction: Vector3 = context.light_direction
	var direction_squared: float = direction.length_squared()
	if not direction.is_finite() or not is_finite(direction_squared) or direction_squared < 0.000001: return true
	direction = direction.normalized()
	if not direction.is_finite() or direction.length_squared() < 0.9999: return true
	# A common separating half-space remains separating for the whole infinite
	# shadow extrusion. This requires no minimum receiving-surface height.
	for plane: Plane in context.planes:
		if plane.distance_to(center) > radius*plane.normal.length() and plane.normal.dot(direction) >= 0.0: return false
	# Complete infinite separation above is independent of caster distance. Keep
	# the conservative near guard for every case without that complete proof.
	if center.distance_to(context.camera) <= distance+radius: return true
	if direction.y >= -0.0001: return true
	if not context.get("min_receiver_y") is float and not context.get("min_receiver_y") is int: return true
	var floor_y: float = float(context.min_receiver_y)
	if not is_finite(floor_y): return true
	# Every possible caster point has reached below all certified receivers at
	# this endpoint. Test the whole capsule, not just the center's shadow ray.
	var travel: float = maxf(0.0,(center.y+radius-floor_y)/-direction.y)
	var end: Vector3 = center+direction*travel
	if not end.is_finite(): return true
	return not _separated(center,end,radius,context.planes)


static func _separated(start: Vector3, end: Vector3, radius: float, planes: Array) -> bool:
	# Godot camera planes face outward; is_position_in_frustum rejects positive
	# plane distance. One common separating plane proves the capsule invisible.
	for plane: Plane in planes:
		var projected_radius: float = radius*plane.normal.length()
		if plane.distance_to(start) > projected_radius and plane.distance_to(end) > projected_radius: return true
	return false


static func local_radius(art: Node3D) -> float:
	if art == null or not art.has_meta("roster_rig"): return INF
	var raw: Variant = art.get_meta("roster_rig")
	if not raw is Dictionary: return INF
	var rig: Dictionary = raw
	if not _weighted_markers_safe(art,rig): return INF
	if rig.has("presentation_radius"):
		if not rig.presentation_radius is float and not rig.presentation_radius is int: return INF
		return float(rig.presentation_radius) if int(rig.get("presentation_child_count",-1)) == art.get_child_count() else INF
	for key: String in ["base_poses","layers","attachments","companions"]:
		if not rig.get(key) is Array: return INF
	if not rig.get("parents") is PackedInt32Array or not rig.get("definition") is Dictionary or not rig.get("markers") is Dictionary or not rig.get("skeleton") is Skeleton3D: return INF
	if not rig.definition.has("family") or not rig.definition.has("height"): return INF
	var radius: float = _rig_radius(art,rig)
	rig["presentation_radius"] = radius
	rig["presentation_child_count"] = art.get_child_count()
	return radius


static func _rig_radius(art: Node3D, rig: Dictionary) -> float:
	var count: int = rig.parents.size()
	if count == 0 or rig.base_poses.size() != count: return INF
	if rig.definition.family not in ["human","quadruped","mounted","bird","object","assembly"]: return INF
	var reaches := PackedFloat64Array()
	var stretches := PackedFloat64Array()
	for i: int in range(count):
		var parent: int = rig.parents[i]
		if parent >= i or parent < -1: return INF
		var local: Transform3D = rig.base_poses[i]
		if not local.is_finite(): return INF
		var parent_stretch: float = stretches[parent] if parent >= 0 else 1.0
		var reach: float = reaches[parent] if parent >= 0 else 0.0
		# Current animation translates only root, pelvis and object mouth.
		var name_text: String = (rig.skeleton as Skeleton3D).get_bone_name(i)
		var extra: float = 0.0
		if name_text == "root": extra = maxf(0.27,float(rig.definition.get("death_lift",float(rig.definition.height)*0.27)))
		elif name_text == "pelvis": extra = maxf(float(rig.definition.get("leg",0.0)),0.044)
		elif name_text == "mouth": extra = 0.004
		reaches.append(reach+parent_stretch*(local.origin.length()+extra))
		stretches.append(parent_stretch*_stretch(local.basis))
	var radius: float = 0.0
	# Bound convex weighted skinning by every possible contributing bone. This
	# uses complete mesh AABBs and inverse binds, never a sampled rest-pose eye.
	var known: Dictionary = {rig.skeleton:true}
	for marker: Dictionary in rig.markers.values(): known[marker.node] = true
	for marker: Dictionary in rig.get("weighted_markers",[]): known[marker.node] = true
	for layers: Array in rig.layers:
		for part: MeshInstance3D in layers:
			known[part] = true
			if part.transform != Transform3D.IDENTITY or part.mesh == null or part.skin == null or part.skin.get_bind_count() != count: return INF
			var mesh_radius: float = _box_radius(part.mesh.get_aabb())
			for i: int in range(count):
				var bind: Transform3D = part.skin.get_bind_pose(i)
				var bound: float = reaches[i]+stretches[i]*(bind.origin.length()+_stretch(bind.basis)*mesh_radius)
				radius = maxf(radius,bound)
	for item: Dictionary in rig.attachments:
		known[item.node] = true
		var leaf: float = _static_radius(item.node)
		var offset: Transform3D = item.offset
		radius = maxf(radius,reaches[item.bone]+stretches[item.bone]*(offset.origin.length()+_stretch(offset.basis)*leaf))
		if rig.definition.get("death_props",{}).has(String(item.node.name)):
			var released: Transform3D = rig.definition.death_props[String(item.node.name)]
			radius = maxf(radius,released.origin.length()+_stretch(released.basis)*leaf)
	for item: Dictionary in rig.companions:
		known[item.node] = true
		var child: float = local_radius(item.node)
		var offset: Transform3D = item.offset if item.follow_bone else item.anchor
		var bound: float = offset.origin.length()+_stretch(offset.basis)*child
		if item.follow_bone: bound = reaches[item.bone]+stretches[item.bone]*bound
		radius = maxf(radius,bound)
	# Unknown additional geometry must opt into an audited bound, not disappear.
	for child: Node in art.get_children():
		if not known.has(child) or child is Node3D and (child as Node3D).top_level: return INF
	return radius+0.05 if is_finite(radius) and radius > 0.0 else INF


static func _static_radius(node: Node3D) -> float:
	var radius: float = 0.0
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or mesh_node.skin != null: return INF
		radius = _box_radius(mesh_node.mesh.get_aabb())
	elif node is VisualInstance3D: return INF
	for child: Node in node.get_children():
		if not child is Node3D: continue
		var spatial := child as Node3D
		if not spatial.transform.is_finite() or spatial.top_level: return INF
		var child_bound: float = spatial.position.length()+_stretch(spatial.basis)*_static_radius(spatial)
		radius = maxf(radius,child_bound)
	return radius

static func _weighted_markers_safe(art: Node3D, rig: Dictionary) -> bool:
	var markers: Variant = rig.get("weighted_markers",[])
	if not markers is Array: return false
	for marker: Variant in markers:
		if not marker is Dictionary: return false
		var node: Variant = marker.get("node")
		if not node is Node3D or not is_instance_valid(node) or node.get_class() != "Node3D": return false
		if node.get_parent() != art or node.top_level or node.get_child_count() != 0 or not node.transform.is_finite(): return false
	return true


static func _box_radius(box: AABB) -> float:
	if not box.position.is_finite() or not box.size.is_finite() or box.size.x < 0 or box.size.y < 0 or box.size.z < 0: return INF
	var radius: float = 0.0
	for i: int in range(8): radius = maxf(radius,box.get_endpoint(i).length())
	return radius


static func _stretch(basis: Basis) -> float:
	if not basis.is_finite(): return INF
	# Orthogonal axes allow the exact largest scale. The induced-norm bound
	# also handles sheared roots without assuming uniform authoring scale.
	var lengths := Vector3(basis.x.length(),basis.y.length(),basis.z.length())
	if lengths.x <= 0 or lengths.y <= 0 or lengths.z <= 0: return INF
	if absf(basis.x.dot(basis.y)) < 0.0000001 and absf(basis.x.dot(basis.z)) < 0.0000001 and absf(basis.y.dot(basis.z)) < 0.0000001:
		return maxf(lengths.x,maxf(lengths.y,lengths.z))+0.000001
	var columns: float = maxf(basis.x.abs().x+basis.x.abs().y+basis.x.abs().z,maxf(basis.y.abs().x+basis.y.abs().y+basis.y.abs().z,basis.z.abs().x+basis.z.abs().y+basis.z.abs().z))
	var rows: float = maxf(absf(basis.x.x)+absf(basis.y.x)+absf(basis.z.x),maxf(absf(basis.x.y)+absf(basis.y.y)+absf(basis.z.y),absf(basis.x.z)+absf(basis.y.z)+absf(basis.z.z)))
	return sqrt(columns*rows)+0.000001
