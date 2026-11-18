extends SceneTree

const Rig = preload("res://scripts/first_person_rig.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var first: Node3D = Rig.create()
	var second: Node3D = Rig.create()
	root.add_child(first)
	root.add_child(second)
	_test_geometry_and_cache(first,second)
	_test_actions(first,second)
	_test_motion_and_bad_inputs(first,second)
	first.free()
	second.free()
	if failures.is_empty():
		print("3D VIEWMODEL GATE: PASS (%d checks; relaxed articulated hands, resolved-action gestures, alternating contact/recovery, bounded inputs and shared geometry)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D VIEWMODEL GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		if child is MeshInstance3D: found.append(child as MeshInstance3D)
		found.append_array(_meshes(child))
	return found


func _transforms(node: Node) -> Array[Transform3D]:
	var found: Array[Transform3D] = []
	for child: Node in node.get_children():
		if child is Node3D: found.append((child as Node3D).transform)
		found.append_array(_transforms(child))
	return found


func _marker(rig: Node3D, side: String) -> Vector3:
	return (rig.get_node(side+"_arm/forearm/wrist/knuckle_marker") as Node3D).global_position


func _advance(rig: Node3D, duration: float, velocity: Vector3 = Vector3.ZERO, sprinting: bool = false) -> void:
	var elapsed: float = 0.0
	while elapsed < duration-0.00001:
		var dt := minf(1.0/60.0,duration-elapsed)
		rig.call("tick",dt,velocity,sprinting,false,false,0.0,Vector2.ZERO)
		elapsed += dt


func _test_geometry_and_cache(first: Node3D, second: Node3D) -> void:
	var a := _meshes(first)
	var b := _meshes(second)
	_check(a.size() > 0 and a.size() == b.size(),"two controllers construct the same nonempty mesh inventory")
	var shared: bool = true
	var no_shadows: bool = true
	var valid: bool = true
	var oriented: bool = true
	var triangle_count: int = 0
	for i: int in range(a.size()):
		shared = shared and a[i].mesh == b[i].mesh and a[i].material_override == b[i].material_override
		no_shadows = no_shadows and a[i].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface: int in range(a[i].mesh.get_surface_count()):
			var arrays: Array = a[i].mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			valid = valid and vertices.size() == normals.size()
			for j: int in range(vertices.size()):
				valid = valid and vertices[j].is_finite() and normals[j].is_finite() and absf(normals[j].length()-1.0) < 0.001
			var elements := indices.size() if not indices.is_empty() else vertices.size()
			triangle_count += elements/3
			for index: int in range(0,elements,3):
				var ia := indices[index] if not indices.is_empty() else index
				var ib := indices[index+1] if not indices.is_empty() else index+1
				var ic := indices[index+2] if not indices.is_empty() else index+2
				var outward := -(vertices[ib]-vertices[ia]).cross(vertices[ic]-vertices[ia])
				if outward.length_squared() <= 0.0000000001: continue
				for vertex: int in [ia,ib,ic]: oriented = oriented and normals[vertex].dot(outward) > 0.0
	_check(shared,"instances reuse their Mesh and Material resources")
	_check(no_shadows,"every mesh, including hidden action props, suppresses world shadows")
	_check(valid and oriented,"authored meshes have finite vertices and outward finite unit normals")
	_check(triangle_count > 1500 and triangle_count < 15000,"articulated close hands use a bounded useful geometry budget (%d triangles)" % triangle_count)
	var attached: bool = true
	for side: String in ["left","right"]:
		for finger: String in ["index","middle","ring","little"]:
			attached = attached and first.has_node(side+"_arm/forearm/wrist/"+finger+"/middle/tip")
		attached = attached and first.has_node(side+"_arm/forearm/wrist/thumb/tip")
	_check(attached,"both wrists have individual finger joints and a two-joint thumb")
	_check(_marker(first,"left").y < -0.30 and _marker(first,"right").y < -0.30,"resting knuckles stay below the center sightline")
	_check(_no_gameplay_nodes(first),"viewmodel owns no physics body, area, timer or audio playback node")
	var identities: Array = []
	for mesh: MeshInstance3D in a: identities.append([mesh.mesh,mesh.material_override])
	for i: int in range(90):
		first.call("acknowledge",&"pickup",true,false)
		first.call("tick",0.016,Vector3(1,0,-3.6),false,false,false,0.0,Vector2(0.01,0.0))
	var preserved: bool = _meshes(first).size() == a.size()
	for i: int in range(a.size()): preserved = preserved and identities[i][0] == a[i].mesh and identities[i][1] == a[i].material_override
	_check(preserved,"repeated gait and gesture updates preserve mesh/material resources and node count")
	first.call("reset")


func _no_gameplay_nodes(node: Node) -> bool:
	if node is CollisionObject3D or node is Timer or node is AudioStreamPlayer or node is AudioStreamPlayer3D: return false
	for child: Node in node.get_children():
		if not _no_gameplay_nodes(child): return false
	return true


func _test_actions(first: Node3D, second: Node3D) -> void:
	first.call("reset")
	var rest_right := _marker(first,"right")
	var rest_left := _marker(first,"left")
	var before := _transforms(first)
	first.call("acknowledge",&"pickup",false,false)
	first.call("acknowledge",&"not_a_gesture",true,false)
	_check(before == _transforms(first) and StringName(first.get("action")).is_empty(),"failed and unknown actions are presentation no-ops")
	first.call("acknowledge",&"punch",true,false)
	var right_distance := _marker(first,"right").distance_to(rest_right)
	var left_distance := _marker(first,"left").distance_to(rest_left)
	_check(first.get("last_punch_side") == 1 and right_distance > left_distance+0.035,"first accepted punch immediately presents the right hand")
	first.call("acknowledge",&"receipt",true,false)
	_check(first.get("action") == &"punch","a receipt cannot displace an accepted punch")
	_advance(first,0.27)
	_check(StringName(first.get("action")).is_empty() and _marker(first,"right").distance_to(rest_right) < 0.015,"punch recovers before the existing 0.28-second gameplay cadence")
	first.call("acknowledge",&"punch",true,false)
	_check(first.get("last_punch_side") == -1 and _marker(first,"left").distance_to(rest_left) > 0.06,"next accepted punch uses the left hand")
	_advance(first,0.05)
	_check(_hand_clear_of_cuff(first,"left"),"left punch exposes its knuckle silhouette beyond the cuff")
	first.call("reset")
	second.call("reset")
	first.call("acknowledge",&"punch",true,true)
	second.call("acknowledge",&"punch",true,false)
	_advance(first,0.05)
	_advance(second,0.05)
	_check(_marker(first,"right").z > _marker(second,"right").z+0.02,"contact compresses extension compared with an unobstructed miss")
	_check(_hand_clear_of_cuff(first,"right") and _hand_clear_of_cuff(second,"right"),"contact and missed punches expose the right fist beyond the cuff")
	for kind: StringName in [&"interact",&"pickup",&"receipt",&"eat",&"smoke",&"equip"]:
		first.call("reset")
		var baseline := _transforms(first)
		first.call("acknowledge",kind,true,false)
		_advance(first,0.12)
		_check(first.get("action") == kind and baseline != _transforms(first),"%s produces a brief acknowledged pose" % kind)
		if kind in [&"receipt",&"eat"]:
			_check(_props_visible(first),"%s presents its held silhouette during the gesture" % kind)
		_advance(first,0.6)
		_check(StringName(first.get("action")).is_empty() and not _props_visible(first),"%s returns without leaving held props or queued actions" % kind)
	first.call("reset")
	for i: int in range(50): first.call("acknowledge",&"receipt" if i%2 == 0 else &"pickup",true,false)
	_advance(first,0.6)
	_check(StringName(first.get("action")).is_empty() and not _props_visible(first),"rapid successful acknowledgements coalesce without a gesture backlog")
	first.call("acknowledge",&"eat",true,false)
	_advance(first,0.15)
	first.call("reset")
	_check(not _props_visible(first) and first.get("last_punch_side") == 0 and _marker(first,"right").is_equal_approx(rest_right),"reset removes props, clears punch sequence and restores the initial rest pose")
	# Traverse actual geometry through every gesture to catch eye-plane clipping.
	var clear_eye: bool = true
	for kind: StringName in [&"punch",&"interact",&"pickup",&"receipt",&"eat",&"smoke",&"equip"]:
		first.call("reset")
		first.call("acknowledge",kind,true,true)
		for i: int in range(40):
			first.call("tick",1.0/60.0,Vector3.ZERO,false,false,false,0.0,Vector2.ZERO)
			clear_eye = clear_eye and _safe_geometry_pose(first)
	_check(clear_eye,"all action meshes remain finite and in front of the 0.06m eye plane")
	first.call("reset")


func _props_visible(rig: Node3D) -> bool:
	return (rig.get_node("left_arm/forearm/wrist/receipt") as Node3D).visible or (rig.get_node("right_arm/forearm/wrist/food") as Node3D).visible


func _hand_clear_of_cuff(rig: Node3D, side: String) -> bool:
	# Compare actual camera-local projected geometry, not a copied pose angle:
	# a downward-folded wrist can pass finite/bounds gates yet hide the whole fist.
	var cuff := rig.get_node(side+"_arm/forearm/cuff") as MeshInstance3D
	var local := rig.global_transform.affine_inverse()*cuff.global_transform
	var cuff_top: float = -INF
	for surface: int in range(cuff.mesh.get_surface_count()):
		var arrays: Array = cuff.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var point := local*vertex
			if point.z >= -0.06: return false
			cuff_top = maxf(cuff_top,point.y/-point.z)
	var knuckle := rig.to_local(_marker(rig,side))
	return knuckle.z < -0.06 and knuckle.y/-knuckle.z > cuff_top+0.005


func _safe_geometry_pose(rig: Node3D) -> bool:
	for mesh: MeshInstance3D in _meshes(rig):
		if not mesh.global_transform.is_finite(): return false
		var bounds := mesh.mesh.get_aabb()
		for corner: int in range(8):
			var point := bounds.get_endpoint(corner)
			point = rig.global_transform.affine_inverse()*mesh.global_transform*point
			if not point.is_finite() or point.z >= -0.06 or absf(point.x) > 1.0 or absf(point.y) > 1.2 or point.z < -1.5: return false
	return true


func _test_motion_and_bad_inputs(rig: Node3D, stationary: Node3D) -> void:
	rig.call("reset")
	stationary.call("reset")
	var baseline := _marker(rig,"right")
	# Sample a span of gait against same-clock breathing; a single endpoint can
	# coincide with the walk cycle returning to rest despite real arm movement.
	var walk_excursion: float = 0.0
	for i: int in range(24):
		rig.call("tick",1.0/60.0,Vector3(0,0,-3.6),false,false,false,0.0,Vector2.ZERO)
		stationary.call("tick",1.0/60.0,Vector3.ZERO,false,false,false,0.0,Vector2.ZERO)
		walk_excursion = maxf(walk_excursion,_marker(rig,"right").distance_to(_marker(stationary,"right")))
	var walked := _marker(rig,"right")
	_check(walk_excursion > 0.006,"actual travel produces arm movement beyond stationary breathing")
	_advance(rig,0.30,Vector3(0,0,-6.1),true)
	_check(_marker(rig,"right").y < walked.y-0.015,"sprinting lowers the arm posture")
	_advance(rig,1.0,Vector3.ZERO,true)
	_check(_marker(rig,"right").distance_to(baseline) < 0.012,"zero actual travel settles gait even when sprint input remains held")
	var snapshot := _transforms(rig)
	for bad_delta: float in [NAN,INF,-1.0,0.0]: rig.call("tick",bad_delta,Vector3(99,0,99),true,true,true,INF,Vector2(INF,NAN))
	_check(snapshot == _transforms(rig),"invalid, negative and zero deltas do not advance the presentation")
	for i: int in range(40): rig.call("tick",1000.0,Vector3(NAN,INF,-INF),true,true,true,NAN,Vector2(INF,NAN))
	_check(_safe_geometry_pose(rig),"malformed movement/look/status and a stalled delta keep transforms finite and bounded")
	rig.call("reset")
	for i: int in range(60): rig.call("tick",1.0/60.0,Vector3.ZERO,false,false,false,100.0,Vector2(100.0,-100.0))
	_check(_marker(rig,"right").distance_to(baseline) < 0.06 and _safe_geometry_pose(rig),"large repeated look and maximum shakes remain bounded on the hands")
	rig.call("reset")
	_check(_marker(rig,"right").is_equal_approx(baseline),"reset clears accumulated look lag, gait and tremor")
