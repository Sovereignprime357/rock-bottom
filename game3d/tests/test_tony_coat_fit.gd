extends "res://tests/test_character_roster.gd"

const OriginalRoster = preload("res://tests/reference_tony_character_roster.gd")
const OriginalArt = preload("res://tests/reference_tony_character_art.gd")
const CurrentArt = preload("res://scripts/character_art.gd")
var fit_groups: int = 0
var fit_pose_cases: int = 0
var fit_shared_rays: int = 0
var fit_other_models: int = 0
var fit_minimum: float = INF
var fit_baseline_minimum: float = INF
var fit_outer_minimum: float = INF
var fit_outer_rays: int = 0


func _run() -> void:
	_fit_raw_scope()
	var current := Roster.create(&"tony",17)
	var shared := Roster.create(&"tony",17)
	var original := OriginalRoster.create(&"tony",17)
	_check(current != null and shared != null and original != null,"all candidate/cache/reference Tony instances construct")
	if current == null or shared == null or original == null:
		quit(1)
		return
	for model: Node3D in [current,shared,original]: root.add_child(model)
	await process_frame
	_check(_geometry(current,shared,"tony"),"retained original geometry gate completes")
	_check(current.get_meta("roster_metrics") == original.get_meta("roster_metrics"),"exact triangles, surfaces, meshes, bones and maximum weights")
	_check(_fit_resource_counts(current) == _fit_resource_counts(original),"exact unique mesh, skin and material resource counts")
	_check(_fit_bones(current,original),"unchanged bone hierarchy, rest transforms and skin bind poses")
	_check(_fit_materials(current) == _fit_materials(original),"exact material properties, textures and palette")
	fit_groups += 1
	_fit_posed(current,original,shared)
	for model: Node3D in [current,shared,original]: model.free()
	await _fit_other_identities()
	_check(fit_groups == 4 and fit_pose_cases == 48 and fit_other_models == 71,"all four completion tails,48 posed/removal cases and71 unchanged identities finish")
	_check(fit_shared_rays > 12000 and fit_baseline_minimum < -0.004,"nonvacuous posed coverage and original protrusion witness")
	_check(fit_outer_rays > 3600 and is_finite(fit_outer_minimum),"outer shell coverage is checked, including shoulder/collar")
	_check(CurrentArt._meshes.size() == OriginalArt._meshes.size() and CurrentArt._materials.size() == OriginalArt._materials.size(),"full authored mesh/material cache counts unchanged")
	if failures.is_empty():
		print("TONY COAT FIT: PASS; %d checks; %d/4 groups; %d pose/coat cases; %d inner/%d outer actual shared rays;71 unchanged identities; minimum=%.9f outer=%.9f original=%.9f; no rendered acceptance" % [checks,fit_groups,fit_pose_cases,fit_shared_rays,fit_outer_rays,fit_minimum,fit_outer_minimum,fit_baseline_minimum])
	else:
		print("TONY COAT FIT: FAIL; %d failures/%d checks; %d/4 groups" % [failures.size(),checks,fit_groups])
	print("TONY COAT FIT DIAGNOSTIC: ",JSON.stringify({"failures":failures,"checks":checks,"groups":fit_groups,"pose_cases":fit_pose_cases,"other_identities":fit_other_models,"inner_rays":fit_shared_rays,"outer_rays":fit_outer_rays,"inner_minimum_m":fit_minimum if is_finite(fit_minimum) else null,"outer_minimum_m":fit_outer_minimum if is_finite(fit_outer_minimum) else null,"original_minimum_m":fit_baseline_minimum if is_finite(fit_baseline_minimum) else null}))
	quit(0 if failures.is_empty() else 1)


func _fit_raw_scope() -> void:
	var old := OriginalRoster._raw_character(&"tony")
	var now := Roster._raw_character(&"tony")
	var old_parts := _meshes(old)
	var new_parts := _meshes(now)
	_check(old_parts.size() == new_parts.size(),"raw Tony part count unchanged")
	var changed: int = 0
	var moved_front: int = 0
	var exact_rear: int = 0
	var bounded_front: bool = true
	for i: int in range(mini(old_parts.size(),new_parts.size())):
		var a := old_parts[i]
		var b := new_parts[i]
		_check(a.transform == b.transform and a.mesh.get_surface_count() == b.mesh.get_surface_count(),"raw part transform and surface count: "+str(i))
		for surface: int in range(a.mesh.get_surface_count()):
			var before := a.mesh.surface_get_arrays(surface)
			var after := b.mesh.surface_get_arrays(surface)
			if before == after: continue
			changed += 1
			_check(a.name == &"coat_two" and b.name == &"coat_two","only middle-shell raw geometry changes")
			var av: PackedVector3Array = before[Mesh.ARRAY_VERTEX]
			var bv: PackedVector3Array = after[Mesh.ARRAY_VERTEX]
			_check(av.size() == bv.size(),"middle shell preserves every triangle vertex")
			for v: int in range(mini(av.size(),bv.size())):
				bounded_front = bounded_front and av[v].x == bv[v].x and av[v].y == bv[v].y
				if av[v].z <= 0.0:
					exact_rear += 1
					bounded_front = bounded_front and av[v] == bv[v]
				else:
					moved_front += 1
					bounded_front = bounded_front and bv[v].z > av[v].z and bv[v].z-av[v].z <= 0.0235*cos(0.45)+(0.02072-0.023*cos(0.45))
	_check(changed == 1 and moved_front > 100 and exact_rear > 100 and bounded_front,"one front-only shell change; exact rear/XY, bounded23.5mm front-profile displacement")
	old.free(); now.free()
	# Default behavior is checked directly, including a non-Tony open shell.
	for dimensions: Vector4 in [Vector4(0.3,0.32,0.2,0.21),Vector4(0.28,0.31,0.19,0.22),Vector4(0.40,0.43,0.30,0.27)]:
		var a := Node3D.new()
		var b := Node3D.new()
		OriginalArt._coat_shell(a,0.6,1.5,Vector2(dimensions.x,dimensions.y),Vector2(dimensions.z,dimensions.w),"604020","default_coat")
		CurrentArt._coat_shell(b,0.6,1.5,Vector2(dimensions.x,dimensions.y),Vector2(dimensions.z,dimensions.w),"604020","default_coat")
		_check((a.get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0) == (b.get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0),"shared default shell arrays remain exact")
		a.free(); b.free()
	fit_groups += 1


func _fit_resource_counts(model: Node3D) -> Vector3i:
	var meshes: Dictionary = {}
	var skins: Dictionary = {}
	var materials: Dictionary = {}
	for part: MeshInstance3D in _meshes(model):
		meshes[part.mesh] = true
		if part.skin != null: skins[part.skin] = true
		if part.material_override != null: materials[part.material_override] = true
		for surface: int in range(part.mesh.get_surface_count()):
			var material := part.mesh.surface_get_material(surface)
			if material != null: materials[material] = true
	return Vector3i(meshes.size(),skins.size(),materials.size())


func _fit_materials(model: Node3D) -> Array:
	var signatures: Array = []
	for part: MeshInstance3D in _meshes(model):
		var selected: Array[Material] = [part.material_override]
		for surface: int in range(part.mesh.get_surface_count()): selected.append(part.mesh.surface_get_material(surface))
		for material: Material in selected:
			var props: Dictionary = {}
			if material != null:
				for property: Dictionary in material.get_property_list():
					if (int(property.usage)&PROPERTY_USAGE_STORAGE) != 0: props[String(property.name)] = material.get(property.name)
			signatures.append(props)
	return signatures


func _fit_bones(a: Node3D, b: Node3D) -> bool:
	var sa := a.get_node("Skeleton") as Skeleton3D
	var sb := b.get_node("Skeleton") as Skeleton3D
	if sa.get_bone_count() != sb.get_bone_count(): return false
	for i: int in range(sa.get_bone_count()):
		if sa.get_bone_name(i) != sb.get_bone_name(i) or sa.get_bone_parent(i) != sb.get_bone_parent(i) or sa.get_bone_rest(i) != sb.get_bone_rest(i): return false
	var am := _meshes(a)
	var bm := _meshes(b)
	if am.size() != bm.size(): return false
	for i: int in range(am.size()):
		if (am[i].skin == null) != (bm[i].skin == null): return false
		if am[i].skin == null: continue
		if am[i].skin.get_bind_count() != bm[i].skin.get_bind_count(): return false
		for bind: int in range(am[i].skin.get_bind_count()):
			if am[i].skin.get_bind_bone(bind) != bm[i].skin.get_bind_bone(bind) or am[i].skin.get_bind_pose(bind) != bm[i].skin.get_bind_pose(bind): return false
	return true


func _fit_chest_frame(model: Node3D) -> Transform3D:
	var rig: Dictionary = model.get_meta("roster_rig")
	var skeleton: Skeleton3D = rig.skeleton
	var chest: int = rig.lookup.chest
	for part: MeshInstance3D in _meshes(model):
		if part.skin != null and part.get_node(part.skeleton) == skeleton:
			return skeleton.get_bone_global_pose(chest)*part.skin.get_bind_pose(chest)
	return Transform3D.IDENTITY


func _fit_front_triangles(model: Node3D, layer: int, shade: String, frame: Transform3D) -> PackedVector3Array:
	var rig: Dictionary = model.get_meta("roster_rig")
	var allowed := [int(rig.lookup.pelvis),int(rig.lookup.spine),int(rig.lookup.chest),int(rig.lookup.neck)]
	var result := PackedVector3Array()
	var inverse := frame.affine_inverse()
	for part: MeshInstance3D in rig.layers[layer]:
		if not part.is_visible_in_tree() or part.skin == null: continue
		var skeleton := part.get_node(part.skeleton) as Skeleton3D
		var palette: Array[Transform3D] = []
		for bind: int in range(part.skin.get_bind_count()): palette.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(bind))*part.skin.get_bind_pose(bind))
		var local := Roster._relative(part,model)
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			if indices.is_empty():
				for i: int in range(vertices.size()): indices.append(i)
			for i: int in range(0,indices.size()-2,3):
				var ids := [indices[i],indices[i+1],indices[i+2]]
				var selected: bool = true
				for vertex: int in ids:
					selected = selected and colors[vertex].to_html(false) == shade
					for slot: int in range(4):
						if weights[vertex*4+slot] > 0.0 and bones[vertex*4+slot] not in allowed: selected = false
				if not selected: continue
				var normal := -(vertices[ids[1]]-vertices[ids[0]]).cross(vertices[ids[2]]-vertices[ids[0]])
				if normal.z <= 0.0000000001 or vertices[ids[0]].z+vertices[ids[1]].z+vertices[ids[2]].z <= 0.0: continue
				for vertex: int in ids:
					var posed := Vector3.ZERO
					for slot: int in range(4): posed += (palette[bones[vertex*4+slot]]*vertices[vertex])*weights[vertex*4+slot]
					result.append(inverse*(local*posed))
	return result


func _fit_front_at(triangles: PackedVector3Array, sample: Vector2) -> float:
	var front: float = -INF
	for i: int in range(0,triangles.size()-2,3):
		var a := triangles[i]
		var b := triangles[i+1]
		var c := triangles[i+2]
		if sample.x < minf(a.x,minf(b.x,c.x))-0.0000001 or sample.x > maxf(a.x,maxf(b.x,c.x))+0.0000001: continue
		if sample.y < minf(a.y,minf(b.y,c.y))-0.0000001 or sample.y > maxf(a.y,maxf(b.y,c.y))+0.0000001: continue
		var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(sample.x,sample.y,1.0),Vector3(sample.x,sample.y,-1.0),a,b,c)
		if hit is Vector3: front = maxf(front,(hit as Vector3).z)
	return front


func _fit_samples() -> Array[Vector2]:
	var samples: Array[Vector2] = []
	for side: float in [-1.0,1.0]:
		for x: int in range(13,28):
			for y: int in range(76,141,2): samples.append(Vector2(side*float(x)*0.01,float(y)*0.01))
		for point: Vector2 in [Vector2(0.15,1.02),Vector2(0.16,0.95),Vector2(0.17,1.30),Vector2(0.26,1.32)]: samples.append(Vector2(side*point.x,point.y))
	return samples


func _fit_outer_samples() -> Array[Vector2]:
	var samples: Array[Vector2] = []
	for side: float in [-1.0,1.0]:
		for x: int in range(12,37,2):
			for y: int in range(62,147,4): samples.append(Vector2(side*float(x)*0.01,float(y)*0.01))
		# Additional collar/shoulder rows include the static limiting region.
		for x: int in range(6,28):
			for y: float in [1.34,1.36,1.37,1.38,1.40,1.42,1.44,1.46]: samples.append(Vector2(side*float(x)*0.01,y))
		samples.append(Vector2(side*0.145,1.37))
		# Off-grid projected-triangle boundary: tighter than the regular grid.
		samples.append(Vector2(side*0.14527852218710688,1.3667999505996704))
	return samples


func _fit_posed(current: Node3D, original: Node3D, shared: Node3D) -> void:
	var states: Array[Dictionary] = [{"name":"rest"},{"name":"walk","local_velocity":Vector3(0,0,1.8)},
		{"name":"windup","action":&"windup","action_phase":0.9},{"name":"peak_strike","action":&"strike","action_phase":0.03,"contact":true}]
	var samples := _fit_samples()
	var outer_samples := _fit_outer_samples()
	var untouched := _poses(shared)
	for state: Dictionary in states:
		for time: float in [0.05,1.25,4.75]:
			for coats: int in [3,2,1,0]:
				var snapshot := state.duplicate(true)
				snapshot.erase("name")
				snapshot["coat_count"] = coats
				for model: Node3D in [current,original]:
					Animator.reset(model)
					var remaining := time
					while remaining > 0.000001:
						var dt := minf(remaining,0.05)
						Animator.tick(model,dt,snapshot,0)
						remaining -= dt
				var rig: Dictionary = current.get_meta("roster_rig")
				var visibility_ok: bool = true
				for layer: int in range(1,4):
					for mesh: MeshInstance3D in rig.layers[layer]: visibility_ok = visibility_ok and mesh.visible == (layer <= coats)
				_check(visibility_ok and _poses(current) == _poses(original) and _poses(shared) == untouched,"exact pose, independent instance and coat visibility: %s %.2f coats%d" % [state.name,time,coats])
				_check(current.transform == Transform3D.IDENTITY and _skin_inside_bounds(current),"posed original render bounds and actor origin: %s coats%d" % [state.name,coats])
				var frame := _fit_chest_frame(current)
				var inner := _fit_front_triangles(current,1,"454c2e",frame)
				var middle := _fit_front_triangles(current,2,"8c6b3b",frame)
				var outer := _fit_front_triangles(current,3,"604020",frame)
				_check((not inner.is_empty()) == (coats >= 1) and (not middle.is_empty()) == (coats >= 2) and (not outer.is_empty()) == (coats >= 3),"actual triangles follow layer removal, no absent-layer pass")
				if coats >= 2:
					var before_frame := _fit_chest_frame(original)
					var before_inner := _fit_front_triangles(original,1,"454c2e",before_frame)
					var before_middle := _fit_front_triangles(original,2,"8c6b3b",before_frame)
					var minimum: float = INF
					var reference_minimum: float = INF
					var covered: int = 0
					for sample: Vector2 in samples:
						var a := _fit_front_at(inner,sample)
						var b := _fit_front_at(middle,sample)
						if is_finite(a) and is_finite(b):
							covered += 1
							minimum = minf(minimum,b-a)
						var aa := _fit_front_at(before_inner,sample)
						var bb := _fit_front_at(before_middle,sample)
						if is_finite(aa) and is_finite(bb): reference_minimum = minf(reference_minimum,bb-aa)
					fit_shared_rays += covered
					fit_minimum = minf(fit_minimum,minimum)
					fit_baseline_minimum = minf(fit_baseline_minimum,reference_minimum)
					_check(covered >= 600 and reference_minimum < -0.004,"actual dense triangle rays reproduce original overlap: %s %.2f count%d" % [state.name,time,covered])
					_check(minimum >= 0.001,"middle front clears inner garment by1mm: %s %.2f coats%d actual%.9f" % [state.name,time,coats,minimum])
				if coats == 3:
					var outer_count: int = 0
					var outer_minimum: float = INF
					for sample: Vector2 in outer_samples:
						var m := _fit_front_at(middle,sample)
						var o := _fit_front_at(outer,sample)
						if is_finite(m) and is_finite(o):
							outer_count += 1
							outer_minimum = minf(outer_minimum,o-m)
					fit_outer_rays += outer_count
					fit_outer_minimum = minf(fit_outer_minimum,outer_minimum)
					_check(outer_count > 300 and outer_minimum >= 0.001,"outer coat clears adjusted middle by1mm including collar/shoulder: %s %.2f count%d actual%.9f" % [state.name,time,outer_count,outer_minimum])
				fit_pose_cases += 1
	Animator.reset(current)
	Animator.tick(current,0.05,{"coat_count":0},2)
	var hidden: bool = true
	var rig: Dictionary = current.get_meta("roster_rig")
	for layer: int in range(1,4):
		for mesh: MeshInstance3D in rig.layers[layer]: hidden = hidden and not mesh.visible
	_check(hidden,"far/reset path immediately removes all three coats")
	fit_groups += 1


func _fit_exact_geometry(a: Node3D, b: Node3D) -> bool:
	var am := _meshes(a)
	var bm := _meshes(b)
	if am.size() != bm.size() or a.get_meta("roster_metrics") != b.get_meta("roster_metrics"): return false
	if _fit_resource_counts(a) != _fit_resource_counts(b) or _fit_materials(a) != _fit_materials(b): return false
	for i: int in range(am.size()):
		if Roster._relative(am[i],a) != OriginalRoster._relative(bm[i],b) or am[i].mesh.get_surface_count() != bm[i].mesh.get_surface_count(): return false
		for surface: int in range(am[i].mesh.get_surface_count()):
			if am[i].mesh.surface_get_arrays(surface) != bm[i].mesh.surface_get_arrays(surface): return false
	return true


func _fit_all_poses(node: Node) -> Array[Transform3D]:
	# Compound actors own independent child skeletons as well as the root rig.
	var result: Array[Transform3D] = []
	if node is Node3D: result.append((node as Node3D).transform)
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		for bone: int in range(skeleton.get_bone_count()):
			result.append(skeleton.get_bone_rest(bone))
			result.append(skeleton.get_bone_pose(bone))
	for child: Node in node.get_children(): result.append_array(_fit_all_poses(child))
	return result


func _fit_other_identities() -> void:
	for id: String in Roster.supported_visuals():
		if id == "tony": continue
		var current := Roster.create(StringName(id),31)
		var original := OriginalRoster.create(StringName(id),31)
		_check(current != null and original != null,id+": both independent original/current models construct")
		if current == null or original == null: continue
		root.add_child(current); root.add_child(original)
		await process_frame
		_check(_fit_exact_geometry(current,original) and _fit_bones(current,original),id+": exact unchanged arrays, materials, resource counts, attachments and bones")
		for snapshot: Dictionary in [{},{"local_velocity":Vector3(0.3,0,1.2)},{"action":&"windup","action_phase":0.7},{"dead":true,"death_phase":0.8}]:
			Animator.tick(current,0.05,snapshot,0)
			Animator.tick(original,0.05,snapshot,0)
			_check(_fit_all_poses(current) == _fit_all_poses(original) and _fit_exact_geometry(current,original),id+": current action/attachment/companion skeleton output remains exact")
		current.free(); original.free()
		fit_other_models += 1
	fit_groups += 1
