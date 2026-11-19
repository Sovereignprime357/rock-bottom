extends "res://tests/test_tony_coat_fit.gd"
## Explicit successor: inherited shell/resource/pose/71-identity gates still run.
## All new rays use actual final four-weight triangles, never raw rest substitutes.
const SURFACE_DIRECTIONS := [Vector3.BACK,Vector3.RIGHT,Vector3.LEFT,Vector3.UP]
const SURFACE_VIEW_NAMES := ["front","right","left","top"]
const LAPEL_SHADES := ["","69703e","b08e4e","946b3c"]
const CLOTH_SHADES := ["","454c2e","8c6b3b","604020"]
var surface_groups := 0
var surface_pose_cases := 0
var surface_lapel_rays := 0
var surface_skin_rays := 0
var surface_layer_rays := 0
var surface_lapel_minima := {"2:1":INF,"3:2":INF,"3:1":INF}
var surface_original_lapels := {"2:1":INF,"3:2":INF,"3:1":INF}
var surface_original_skin := {"front":0,"right":0,"left":0,"top":0}
var surface_skin_minimum := INF
var surface_layer_minimum := INF
var surface_missing_cloth := 0
var surface_lapel_shapes: Dictionary = {}
var surface_worst: Array[Dictionary] = []
var surface_channel_differences: Array[Dictionary] = []
var surface_self_ray_misses := 0
var surface_self_ray_details: Array[Dictionary] = []

func _fit_raw_scope() -> void:
	var old := OriginalRoster._raw_character(&"tony"); var now := Roster._raw_character(&"tony")
	var old_parts := _meshes(old); var new_parts := _meshes(now)
	_check(old_parts.size() == new_parts.size(),"raw Tony part count unchanged")
	var changed := {"coat_one":0,"coat_two":0,"coat_three":0,"b08e4e":0,"69703e":0}
	var lower_front := 0; var lower_rear := 0
	for part_index: int in range(mini(old_parts.size(),new_parts.size())):
		var a: MeshInstance3D = old_parts[part_index]; var b: MeshInstance3D = new_parts[part_index]
		_check(a.transform == b.transform and a.mesh.get_surface_count() == b.mesh.get_surface_count(),"raw part transform and surface count: "+str(part_index))
		for surface: int in range(a.mesh.get_surface_count()):
			var before := a.mesh.surface_get_arrays(surface); var after := b.mesh.surface_get_arrays(surface)
			if before == after: continue
			var vertices: PackedVector3Array = before[Mesh.ARRAY_VERTEX]; var moved: PackedVector3Array = after[Mesh.ARRAY_VERTEX]
			var shade := (a.material_override as StandardMaterial3D).albedo_color.to_html(false)
			var part_name := String(a.name)
			var is_lapel: bool = shade in ["b08e4e","69703e"] and vertices.size() == 9 and a.get_parent() == old
			var allowed: bool = part_name in ["coat_one","coat_two","coat_three"] or is_lapel
			_check(allowed,"only declared three garments and four inner/middle lapels change: "+str(part_index))
			if not allowed: continue
			changed[shade if is_lapel else part_name] += 1
			var attributes_equal: bool = vertices.size() == moved.size()
			for channel: int in range(Mesh.ARRAY_MAX):
				if channel not in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL]:
					if before[channel] != after[channel]: _surface_channel_diagnostic(part_index,part_name,channel,before[channel],after[channel])
					if channel == Mesh.ARRAY_TANGENT and part_name in ["coat_one","coat_two","coat_three"]:
						attributes_equal = attributes_equal and _surface_tangents_valid(before[channel],vertices.size()) and _surface_tangents_valid(after[channel],moved.size())
					else: attributes_equal = attributes_equal and before[channel] == after[channel]
			_check(attributes_equal,"raw topology/other channels exact; named garment tangents are validated normal-derived data: "+str(part_index))
			var scoped := true
			for vertex: int in range(mini(vertices.size(),moved.size())):
				var prior: Vector3 = vertices[vertex]; var actual: Vector3 = moved[vertex]
				if is_lapel:
					var dz: float = -0.022 if shade == "b08e4e" else -0.0305
					scoped = scoped and prior.x == actual.x and prior.y == actual.y and absf(actual.z-prior.z-dz) <= 0.0000001
				elif part_name == "coat_one":
					if prior.y == Vector3(0,1.42,0).y:
						var expected := Vector3(prior.x*(0.30/0.245),1.4315,prior.z)
						scoped = scoped and actual.z == prior.z and actual.distance_to(expected) <= 0.0000005
					else: scoped = scoped and actual == prior
				else:
					var old_profiles: Array[Vector3]
					var new_profiles: Array[Vector3]
					if part_name == "coat_two":
						old_profiles = [Vector3(.30,.61,.20),Vector3(.288,.8508,.188),Vector3(.3136,1.1948,.21),Vector3(.32,1.3668,.21),Vector3(.256,1.4356,.1764),Vector3(.128,1.47,.126)]
						new_profiles = [old_profiles[0],old_profiles[1],old_profiles[2],Vector3(.34,1.43,.21),Vector3(.27,1.455,.1764),Vector3(.19,1.47,.155)]
					else:
						old_profiles = [Vector3(.38,.39,.27),Vector3(.3648,.698,.2538),Vector3(.343,1.138,.245),Vector3(.35,1.358,.245),Vector3(.28,1.446,.2058),Vector3(.14,1.49,.147)]
						new_profiles = [old_profiles[0],old_profiles[1],old_profiles[2],Vector3(.365,1.43,.25),Vector3(.26,1.465,.2058),old_profiles[5]]
					var row := -1
					for candidate: int in range(old_profiles.size()):
						if absf(prior.y-old_profiles[candidate].y) <= 0.0000001: row = candidate; break
					if row < 0: scoped = false; continue
					if part_name == "coat_three" and row in [0,1,2,5]:
						scoped = scoped and actual == prior
						continue
					var mapped := _surface_profile_point(prior,old_profiles[row],new_profiles[row],0.0235 if part_name == "coat_two" else 0.0)
					scoped = scoped and mapped.w < 0.00001 and actual.distance_to(Vector3(mapped.x,mapped.y,mapped.z)) <= 0.0000005
					if part_name == "coat_two" and row <= 2:
						scoped = scoped and actual.x == prior.x and actual.y == prior.y
						if prior.z <= 0: lower_rear += 1; scoped = scoped and actual == prior
						else:
							lower_front += 1
							scoped = scoped and actual.z > prior.z and actual.z-prior.z <= 0.0235*cos(0.45)+(0.02072-0.023*cos(0.45))
			_check(scoped,"exact declared upper-ring coordinates/lapel depths; unchanged lower/back/neck outside scope: "+str(part_index))
	_check(changed == {"coat_one":1,"coat_two":1,"coat_three":1,"b08e4e":2,"69703e":2},"exact seven changed raw parts; outer lapels and bare body remain exact")
	_check(lower_front > 100 and lower_rear > 100,"retained lower middle-shell front fit and exact rear are nonvacuous")
	old.free(); now.free()
	for dimensions: Vector4 in [Vector4(.3,.32,.2,.21),Vector4(.28,.31,.19,.22),Vector4(.40,.43,.30,.27)]:
		var a := Node3D.new(); var b := Node3D.new()
		OriginalArt._coat_shell(a,.6,1.5,Vector2(dimensions.x,dimensions.y),Vector2(dimensions.z,dimensions.w),"604020","default_coat")
		CurrentArt._coat_shell(b,.6,1.5,Vector2(dimensions.x,dimensions.y),Vector2(dimensions.z,dimensions.w),"604020","default_coat")
		_check((a.get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0) == (b.get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0),"shared default shell arrays remain exact")
		a.free(); b.free()
	fit_groups += 1

func _surface_profile_point(point: Vector3,prior: Vector3,next: Vector3,outset: float) -> Vector4:
	var outer_error: float = absf(pow(point.x/prior.x,2)+pow(point.z/prior.z,2)-1.0)
	var inner_error: float = absf(pow(point.x/(prior.x-.009),2)+pow(point.z/(prior.z-.009),2)-1.0)
	var inset: float = .009 if inner_error < outer_error else 0.0
	var sine: float = point.x/(prior.x-inset); var cosine: float = point.z/(prior.z-inset)
	return Vector4(sine*(next.x-inset),next.y,cosine*(next.z-inset)+(cosine*outset if cosine > 0 else 0.0),minf(outer_error,inner_error))

func _run() -> void:
	_surface_math()
	_surface_lapel_fingerprints()
	_fit_raw_scope()
	var current := Roster.create(&"tony",17)
	var shared := Roster.create(&"tony",17)
	var original := OriginalRoster.create(&"tony",17)
	_check(current != null and shared != null and original != null,"all candidate/cache/reference Tony instances construct")
	if current == null or shared == null or original == null:
		quit(1); return
	for model: Node3D in [current,shared,original]: root.add_child(model)
	await process_frame
	_check(_geometry(current,shared,"tony"),"retained original geometry gate completes")
	_check(current.get_meta("roster_metrics") == original.get_meta("roster_metrics"),"exact triangles, surfaces, meshes, bones and maximum weights")
	_check(_fit_resource_counts(current) == _fit_resource_counts(original),"exact unique mesh, skin and material resource counts")
	_check(_fit_bones(current,original),"unchanged bone hierarchy, rest transforms and skin bind poses")
	_check(_fit_materials(current) == _fit_materials(original),"exact material properties, textures and palette")
	fit_groups += 1
	_fit_posed(current,original,shared) # Unchanged original1mm shell and pose checks.
	_surface_posed(current,original,shared)
	for model: Node3D in [current,shared,original]: model.free()
	await _fit_other_identities()
	_check(fit_groups == 4 and fit_pose_cases == 48 and fit_other_models == 71,"all inherited tails,48 shell poses and71 unchanged identities finish")
	_check(surface_groups == 2 and surface_pose_cases == 48,"both additional completion tails and48 surface poses finish")
	_check(fit_shared_rays > 12000 and fit_baseline_minimum < -0.004,"nonvacuous posed shell coverage and original protrusion witness")
	_check(fit_outer_rays > 3600 and is_finite(fit_outer_minimum),"outer shell coverage remains checked including shoulder/collar")
	_check(CurrentArt._meshes.size() == OriginalArt._meshes.size() and CurrentArt._materials.size() == OriginalArt._materials.size(),"full authored mesh/material cache counts unchanged")
	for key: String in surface_original_lapels:
		_check(surface_original_lapels[key] < -0.004,"original weighted lapel overlap independently reproduced: "+key)
	for view: String in surface_original_skin:
		_check(surface_original_skin[view] > 0,"original bare-shoulder breakthrough independently reproduced: "+view)
	_check(surface_lapel_rays > 100 and surface_skin_rays > 1000 and surface_layer_rays > 1000,"expanded surface coverage cannot pass vacuously")
	print("TONY COAT SURFACES: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",fit_groups,"/4 inherited and ",surface_groups,"/2 surface groups; ",surface_pose_cases," surface poses; no rendered acceptance")
	print("TONY COAT SURFACES DIAGNOSTIC: ",JSON.stringify(_surface_json_safe({"failures":failures,"checks":checks,"inherited_groups":fit_groups,"surface_groups":surface_groups,"shell_pose_cases":fit_pose_cases,"surface_pose_cases":surface_pose_cases,"other_identities":fit_other_models,"shell_inner_minimum_m":fit_minimum,"shell_outer_minimum_m":fit_outer_minimum,"lapel_rays":surface_lapel_rays,"lapel_minima_m":surface_lapel_minima,"original_lapel_minima_m":surface_original_lapels,"skin_rays":surface_skin_rays,"skin_minimum_m":surface_skin_minimum,"missing_cloth":surface_missing_cloth,"original_skin_defects":surface_original_skin,"layer_rays":surface_layer_rays,"layer_minimum_m":surface_layer_minimum,"channel_differences":surface_channel_differences,"self_ray_misses":surface_self_ray_misses,"self_ray_details":surface_self_ray_details,"worst":surface_worst})))
	quit(0 if failures.is_empty() else 1)

func _surface_json_safe(value: Variant) -> Variant:
	if value is float and not is_finite(value): return null
	if value is Vector2: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		for key: Variant in value: dictionary_result[key] = _surface_json_safe(value[key])
		return dictionary_result
	if value is Array:
		var array_result: Array = []
		for item: Variant in value: array_result.append(_surface_json_safe(item))
		return array_result
	return value

func _surface_lapel_fingerprints() -> void:
	var raw := OriginalRoster._raw_character(&"tony")
	for shade: String in LAPEL_SHADES:
		if not shade.is_empty(): surface_lapel_shapes[shade] = []
	for part: MeshInstance3D in _meshes(raw):
		var shade := (part.material_override as StandardMaterial3D).albedo_color.to_html(false)
		if not surface_lapel_shapes.has(shade) or part.get_parent() != raw: continue
		if part.mesh.get_surface_count() != 1: continue
		var arrays := part.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.size() != 9: continue # Three-triangle lapels; excludes same-palette seams.
		for i: int in range(0,9,3):
			surface_lapel_shapes[shade].append(PackedVector2Array([Vector2(vertices[i].x,vertices[i].y),Vector2(vertices[i+1].x,vertices[i+1].y),Vector2(vertices[i+2].x,vertices[i+2].y)]))
	for shade: String in surface_lapel_shapes: _check(surface_lapel_shapes[shade].size() == 6,"six actual original lapel triangle fingerprints: "+shade)
	raw.free()

func _surface_is_lapel(shade: String,points: PackedVector3Array) -> bool:
	for shape: PackedVector2Array in surface_lapel_shapes.get(shade,[]):
		var matches := true
		for point: Vector3 in points:
			if Vector2(point.x,point.y) not in shape: matches = false
		if matches: return true
	return false

func _surface_rows(model: Node3D,layer: int,shade: String,frame: Transform3D,lapels: bool = false) -> Array[Dictionary]:
	var rig: Dictionary = model.get_meta("roster_rig")
	var allowed := [int(rig.lookup.pelvis),int(rig.lookup.spine),int(rig.lookup.chest),int(rig.lookup.neck)]
	var result: Array[Dictionary] = []
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
				for vertex: int in range(vertices.size()): indices.append(vertex)
			for face: int in range(0,indices.size()-2,3):
				var rest := PackedVector3Array(); var posed := PackedVector3Array(); var selected := true
				for corner: int in range(3):
					var vertex: int = indices[face+corner]
					selected = selected and colors[vertex].to_html(false) == shade
					for slot: int in range(4):
						if weights[vertex*4+slot] > 0 and bones[vertex*4+slot] not in allowed: selected = false
					rest.append(vertices[vertex])
				if not selected or (lapels and not _surface_is_lapel(shade,rest)): continue
				for corner: int in range(3):
					var vertex: int = indices[face+corner]; var point := Vector3.ZERO
					for slot: int in range(4): point += (palette[bones[vertex*4+slot]]*vertices[vertex])*weights[vertex*4+slot]
					posed.append(inverse*(local*point))
				result.append({"rest":rest,"posed":posed})
	return result

func _surface_uv(point: Vector3,direction: Vector3) -> Vector2:
	if direction == Vector3.UP: return Vector2(point.x,point.z)
	if absf(direction.x) > 0: return Vector2(point.z,point.y)
	return Vector2(point.x,point.y)

func _surface_projection(rows: Array[Dictionary],direction: Vector3) -> Array[PackedFloat64Array]:
	var result: Array[PackedFloat64Array] = []
	for row: Dictionary in rows:
		var points: PackedVector3Array = row.posed
		var outward := -(points[1]-points[0]).cross(points[2]-points[0])
		if outward.dot(direction) <= 0.0000000001: continue
		if direction != Vector3.UP and (points[0]+points[1]+points[2]).dot(direction) <= 0.0: continue
		var a := _surface_uv(points[0],direction); var b := _surface_uv(points[1],direction); var c := _surface_uv(points[2],direction)
		var denominator: float = (b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
		if absf(denominator) <= 0.0000000001: continue
		result.append(PackedFloat64Array([a.x,a.y,b.x,b.y,c.x,c.y,points[0].dot(direction),points[1].dot(direction),points[2].dot(direction),denominator,minf(a.x,minf(b.x,c.x)),maxf(a.x,maxf(b.x,c.x)),minf(a.y,minf(b.y,c.y)),maxf(a.y,maxf(b.y,c.y))]))
	return result

func _surface_depth(projected: Array[PackedFloat64Array],point: Vector2) -> float:
	var depth := -INF
	for triangle: PackedFloat64Array in projected:
		if point.x < triangle[10]-0.0000001 or point.x > triangle[11]+0.0000001 or point.y < triangle[12]-0.0000001 or point.y > triangle[13]+0.0000001: continue
		var u: float = ((triangle[3]-triangle[5])*(point.x-triangle[4])+(triangle[4]-triangle[2])*(point.y-triangle[5]))/triangle[9]
		var v: float = ((triangle[5]-triangle[1])*(point.x-triangle[4])+(triangle[0]-triangle[4])*(point.y-triangle[5]))/triangle[9]
		var w: float = 1.0-u-v
		if minf(u,minf(v,w)) < -0.000001: continue
		depth = maxf(depth,u*triangle[6]+v*triangle[7]+w*triangle[8])
	return depth

func _surface_ccw(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if (result[1]-result[0]).cross(result[2]-result[0]) < 0: result.reverse()
	return result

func _surface_clip(subject: PackedVector2Array,clip: PackedVector2Array) -> PackedVector2Array:
	var result := subject.duplicate()
	for edge: int in range(clip.size()):
		if result.is_empty(): break
		var a: Vector2 = clip[edge]; var b: Vector2 = clip[(edge+1)%clip.size()]
		var input := result; result = PackedVector2Array()
		var previous: Vector2 = input[-1]
		var previous_side: float = (b-a).cross(previous-a)
		for point: Vector2 in input:
			var side: float = (b-a).cross(point-a)
			if (side >= 0.0) != (previous_side >= 0.0):
				var denominator: float = previous_side-side
				if absf(denominator) > 0.000000000001: result.append(previous+(point-previous)*(previous_side/denominator))
			if side >= 0.0: result.append(point)
			previous = point; previous_side = side
	return result

func _surface_overlap(a: Array[Dictionary],b: Array[Dictionary],direction: Vector3) -> Array[Vector2]:
	var unique: Dictionary = {}
	for first: Dictionary in a:
		var x := PackedVector2Array()
		for point: Vector3 in first.posed: x.append(_surface_uv(point,direction))
		if absf((x[1]-x[0]).cross(x[2]-x[0])) <= 0.0000000001: continue
		x = _surface_ccw(x)
		for second: Dictionary in b:
			var y := PackedVector2Array()
			for point: Vector3 in second.posed: y.append(_surface_uv(point,direction))
			if absf((y[1]-y[0]).cross(y[2]-y[0])) <= 0.0000000001: continue
			var polygon := _surface_clip(x,_surface_ccw(y))
			if polygon.size() < 3: continue
			var area := 0.0; var centroid := Vector2.ZERO
			for i: int in range(polygon.size()): area += polygon[i].cross(polygon[(i+1)%polygon.size()])
			if absf(area) <= 0.0000000001: continue
			for point: Vector2 in polygon: unique[point] = true; centroid += point
			unique[centroid/float(polygon.size())] = true
	var result: Array[Vector2] = []
	for point: Vector2 in unique: result.append(point)
	return result

func _surface_shoulder(point: Vector3) -> bool:
	# Explicitly exclude the neck/front opening; no hidden skin-dependent pruning.
	return point.y >= 1.35 and point.y <= 1.465 and absf(point.x) >= 0.16

func _surface_samples(rows: Array[Dictionary],direction: Vector3) -> Array[Dictionary]:
	var unique: Dictionary = {}
	for row: Dictionary in rows:
		var rest: PackedVector3Array = row.rest; var posed: PackedVector3Array = row.posed
		var normal := -(posed[1]-posed[0]).cross(posed[2]-posed[0])
		if normal.dot(direction) <= 0.0000000001: continue
		if direction != Vector3.UP and (posed[0]+posed[1]+posed[2]).dot(direction) <= 0.0: continue
		for bary: Vector3 in [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1),Vector3(0.5,0.5,0),Vector3(0,0.5,0.5),Vector3(0.5,0,0.5),Vector3.ONE/3.0]:
			var at: Vector3 = rest[0]*bary.x+rest[1]*bary.y+rest[2]*bary.z
			if _surface_shoulder(at) and not unique.has(at): unique[at] = {"rest":at,"point":posed[0]*bary.x+posed[1]*bary.y+posed[2]*bary.z,"face":posed,"bary":bary}
	var result: Array[Dictionary] = []
	for at: Vector3 in unique: result.append(unique[at])
	return result

func _surface_pose(model: Node3D,time: float,snapshot: Dictionary) -> void:
	Animator.reset(model)
	var remaining := time
	while remaining > 0.000001:
		var delta := minf(remaining,0.05); Animator.tick(model,delta,snapshot,0); remaining -= delta

func _surface_lapel_pair(inner: Array[Dictionary],outer: Array[Dictionary]) -> Dictionary:
	var samples := _surface_overlap(inner,outer,Vector3.BACK)
	var a := _surface_projection(inner,Vector3.BACK); var b := _surface_projection(outer,Vector3.BACK)
	var minimum := INF; var covered := 0; var worst := Vector2.ZERO
	for point: Vector2 in samples:
		var first := _surface_depth(a,point); var second := _surface_depth(b,point)
		if not is_finite(first) or not is_finite(second): continue
		covered += 1
		if second-first < minimum: minimum = second-first; worst = point
	return {"covered":covered,"minimum":minimum,"worst":worst,"boundary_samples":samples.size()}

func _surface_posed(current: Node3D,original: Node3D,shared: Node3D) -> void:
	var untouched := _fit_all_poses(shared)
	var states: Array[Dictionary] = [{"name":"rest"},{"name":"walk","local_velocity":Vector3(0,0,1.8)},{"name":"windup","action":&"windup","action_phase":0.9},{"name":"peak_strike","action":&"strike","action_phase":0.03,"contact":true}]
	for state: Dictionary in states:
		for time: float in [0.05,1.25,4.75]:
			for coats: int in [3,2,1,0]:
				var snapshot := state.duplicate(true); snapshot.erase("name"); snapshot.coat_count = coats
				for model: Node3D in [current,original]: _surface_pose(model,time,snapshot)
				var label := "%s %.2f coats%d" % [state.name,time,coats]
				var frame := _fit_chest_frame(current); var old_frame := _fit_chest_frame(original)
				var skin := _surface_rows(current,0,"bd9b69",frame)
				var old_skin := _surface_rows(original,0,"bd9b69",old_frame)
				_check(not skin.is_empty() and skin == old_skin,"unchanged actual bare torso, including zero coats: "+label)
				_check(_fit_all_poses(current) == _fit_all_poses(original) and _fit_all_poses(shared) == untouched,"surface tests retain all instance/bone/attachment poses: "+label)
				var lapels: Array = [[],[],[],[]]; var old_lapels: Array = [[],[],[],[]]
				var cloth: Array = [[],[],[],[]]; var old_cloth: Array = [[],[],[],[]]
				for layer: int in range(1,4):
					lapels[layer] = _surface_rows(current,layer,LAPEL_SHADES[layer],frame,true)
					old_lapels[layer] = _surface_rows(original,layer,LAPEL_SHADES[layer],old_frame,true)
					cloth[layer] = _surface_rows(current,layer,CLOTH_SHADES[layer],frame)
					old_cloth[layer] = _surface_rows(original,layer,CLOTH_SHADES[layer],old_frame)
					_check(lapels[layer].size() == (6 if layer <= coats else 0) and old_lapels[layer].size() == lapels[layer].size(),"actual lapel palette/XY selector and removal layer%d: %s" % [layer,label])
				for pair: Vector2i in [Vector2i(2,1),Vector2i(3,2),Vector2i(3,1)]:
					if coats < pair.x: continue
					var key := "%d:%d" % [pair.x,pair.y]
					var result := _surface_lapel_pair(lapels[pair.y],lapels[pair.x])
					var baseline := _surface_lapel_pair(old_lapels[pair.y],old_lapels[pair.x])
					surface_lapel_rays += int(result.covered)
					surface_lapel_minima[key] = minf(surface_lapel_minima[key],result.minimum)
					surface_original_lapels[key] = minf(surface_original_lapels[key],baseline.minimum)
					_check(result.covered >= 6 and baseline.covered >= 6 and result.minimum >= 0.001,"actual lapel order %s %s rays%d minimum%.9f at%s" % [key,label,result.covered,result.minimum,result.worst])
					if result.minimum < 0.001: surface_worst.append({"kind":"lapel","pair":key,"pose":label,"rays":result.covered,"point":result.worst,"minimum_m":result.minimum})
				if coats > 0:
					for view: int in range(4):
						_surface_shoulders(skin,old_skin,cloth,old_cloth,coats,SURFACE_DIRECTIONS[view],SURFACE_VIEW_NAMES[view],label)
				surface_pose_cases += 1
	surface_groups += 1

func _surface_channel_diagnostic(part: int,part_name: String,channel: int,before: Variant,after: Variant) -> void:
	var before_count: int = before.size() if before is Array or typeof(before) >= TYPE_PACKED_BYTE_ARRAY else 0
	var after_count: int = after.size() if after is Array or typeof(after) >= TYPE_PACKED_BYTE_ARRAY else 0
	var examples: Array[Dictionary] = []
	var differences := 0
	for index: int in range(maxi(before_count,after_count)):
		var a: Variant = before[index] if index < before_count else null
		var b: Variant = after[index] if index < after_count else null
		if a == b: continue
		differences += 1
		if examples.size() < 4: examples.append({"index":index,"before":a,"after":b})
	surface_channel_differences.append({"part":part,"name":part_name,"channel":channel,"before_type":type_string(typeof(before)),"after_type":type_string(typeof(after)),"before_size":before_count,"after_size":after_count,"differences":differences,"first":examples})

func _surface_bary_diagnostic(triangle: PackedFloat64Array,point: Vector2) -> Array[float]:
	var u: float = ((triangle[3]-triangle[5])*(point.x-triangle[4])+(triangle[4]-triangle[2])*(point.y-triangle[5]))/triangle[9]
	var v: float = ((triangle[5]-triangle[1])*(point.x-triangle[4])+(triangle[0]-triangle[4])*(point.y-triangle[5]))/triangle[9]
	return [u,v,1.0-u-v]

func _surface_self_ray_diagnostic(sample: Dictionary,projected: Array[PackedFloat64Array],direction: Vector3,view: String,label: String) -> void:
	surface_self_ray_misses += 1
	if surface_self_ray_details.size() >= 8: return
	var face: PackedVector3Array = sample.face
	var point := _surface_uv(sample.point,direction)
	var own_rows: Array[Dictionary] = [{"posed":face}]
	var own := _surface_projection(own_rows,direction)
	var own_bary: Array[float] = []
	var determinant := 0.0
	if not own.is_empty():
		determinant = own[0][9]
		own_bary = _surface_bary_diagnostic(own[0],point)
	var closest_minimum := -INF
	var closest_bary: Array[float] = []
	for triangle: PackedFloat64Array in projected:
		var bary := _surface_bary_diagnostic(triangle,point)
		var minimum := minf(bary[0],minf(bary[1],bary[2]))
		if minimum > closest_minimum: closest_minimum = minimum; closest_bary = bary
	var facing := -(face[1]-face[0]).cross(face[2]-face[0])
	surface_self_ray_details.append({"label":label,"view":view,"rest":sample.rest,"point":sample.point,"posed_triangle":[face[0],face[1],face[2]],"authored_bary":sample.bary,"projection_determinant":determinant,"recomputed_bary":own_bary,"facing_normal":facing,"facing_dot":facing.dot(direction),"closest_projected_min_bary":closest_minimum,"closest_projected_bary":closest_bary})

func _surface_shoulders(skin: Array[Dictionary],old_skin: Array[Dictionary],cloth: Array,old_cloth: Array,coats: int,direction: Vector3,view: String,label: String) -> void:
	var skin_samples := _surface_samples(skin,direction)
	var skin_projection := _surface_projection(skin,direction)
	var old_skin_projection := _surface_projection(old_skin,direction)
	var cloth_projection: Array = [[],[],[],[]]; var old_projection: Array = [[],[],[],[]]
	var visible_cloth: Array[PackedFloat64Array] = []; var old_visible_cloth: Array[PackedFloat64Array] = []
	for layer: int in range(1,coats+1):
		cloth_projection[layer] = _surface_projection(cloth[layer],direction)
		old_projection[layer] = _surface_projection(old_cloth[layer],direction)
		visible_cloth.append_array(cloth_projection[layer]); old_visible_cloth.append_array(old_projection[layer])
	var covered := 0; var missing := 0; var minimum := INF; var worst := Vector3.ZERO
	for sample: Dictionary in skin_samples:
		var point := _surface_uv(sample.point,direction)
		var body := _surface_depth(skin_projection,point)
		var shell := _surface_depth(visible_cloth,point)
		if not is_finite(body):
			_surface_self_ray_diagnostic(sample,skin_projection,direction,view,label)
		body = _surface_measured_body(sample.point,direction,body)
		covered += 1
		if not is_finite(shell): missing += 1; worst = sample.rest
		elif shell-body < minimum: minimum = shell-body; worst = sample.rest
		var old_body := _surface_depth(old_skin_projection,point)
		var old_shell := _surface_depth(old_visible_cloth,point)
		if is_finite(old_body) and (not is_finite(old_shell) or old_shell-old_body < 0.001): surface_original_skin[view] += 1
	surface_skin_rays += covered; surface_missing_cloth += missing; surface_skin_minimum = minf(surface_skin_minimum,minimum)
	_check(covered >= 8 and covered == skin_samples.size() and missing == 0 and minimum >= 0.001,"actual shoulder coverage %s %s skin%d missing%d min%.9f rest%s" % [view,label,covered,missing,minimum,worst])
	if missing > 0 or minimum < 0.001: surface_worst.append({"kind":"skin","view":view,"pose":label,"samples":covered,"missing":missing,"minimum_m":minimum,"rest":worst})
	for outer: int in range(2,coats+1):
		var inner: int = outer-1
		var samples := _surface_samples(cloth[inner],direction); samples.append_array(_surface_samples(cloth[outer],direction))
		var unique: Dictionary = {}
		var common := 0; var gap := INF; var limiting := Vector2.ZERO
		for sample: Dictionary in samples:
			var point := _surface_uv(sample.point,direction)
			if unique.has(point): continue
			unique[point] = true
			var a := _surface_depth(cloth_projection[inner],point); var b := _surface_depth(cloth_projection[outer],point)
			if not is_finite(a) or not is_finite(b): continue # Intentional disjoint neck/opening silhouettes.
			common += 1
			if b-a < gap: gap = b-a; limiting = point
		surface_layer_rays += common; surface_layer_minimum = minf(surface_layer_minimum,gap)
		_check(common >= 8 and gap >= 0.001,"actual shoulder layer%d>%d %s %s common%d min%.9f at%s" % [outer,inner,view,label,common,gap,limiting])
		if gap < 0.001: surface_worst.append({"kind":"layer","pair":"%d:%d" % [outer,inner],"view":view,"pose":label,"common":common,"minimum_m":gap,"point":limiting})

func _surface_tangents_valid(values: Variant,vertex_count: int) -> bool:
	if not values is PackedFloat32Array or vertex_count <= 0 or values.size() != vertex_count*4: return false
	for vertex: int in range(vertex_count):
		for component: int in range(4):
			if not is_finite(values[vertex*4+component]): return false
		var direction := Vector3(values[vertex*4],values[vertex*4+1],values[vertex*4+2])
		if not is_equal_approx(direction.length(),1.0) or values[vertex*4+3] not in [-1.0,1.0]: return false
	return true

func _surface_measured_body(point: Vector3,direction: Vector3,self_ray: float) -> float:
	# This point was constructed on the actual submitted triangle. A failed
	# numerical self-intersection cannot erase it; any farther body hit still wins.
	var known_depth: float = point.dot(direction)
	return maxf(known_depth,self_ray) if is_finite(self_ray) else known_depth

func _surface_correction_math() -> void:
	# Exact retained v5 midpoint: float32 interpolation moves projected bary U
	# below -1e-6 although authored barycentric weights are exactly(0,.5,.5).
	var face := PackedVector3Array([Vector3(.159095123410225,1.46245574951172,.0314962789416313),Vector3(.1624925583601,1.46243321895599,-.00000270793680101633),Vector3(.239996314048767,1.44497811794281,-.00000994873698800802)])
	var point: Vector3 = face[0]*0.0+face[1]*0.5+face[2]*0.5
	var rows: Array[Dictionary] = [{"posed":face}]
	var projected := _surface_projection(rows,Vector3.BACK)
	var ray := _surface_depth(projected,_surface_uv(point,Vector3.BACK))
	_check(not projected.is_empty() and not is_finite(ray),"retained actual edge midpoint reproduces old body self-ray miss without epsilon changes")
	var measured := _surface_measured_body(point,Vector3.BACK,ray)
	_check(is_finite(measured) and measured == point.z,"known actual triangle midpoint remains measured when numerical self-ray misses")
	var center := point+Vector3(0,0,.002)
	var cloth_face := PackedVector3Array([center+Vector3(-.02,-.02,0),center+Vector3(0,.02,0),center+Vector3(.02,-.02,0)])
	var cloth_rows: Array[Dictionary] = [{"posed":cloth_face}]
	var cloth := _surface_depth(_surface_projection(cloth_rows,Vector3.BACK),_surface_uv(point,Vector3.BACK))
	_check(is_finite(cloth) and cloth-measured >= .001,"known midpoint is tested against real covering cloth triangles")
	var empty: Array[Dictionary] = []
	var absent := _surface_depth(_surface_projection(empty,Vector3.BACK),_surface_uv(point,Vector3.BACK))
	_check(not (is_finite(absent) and absent-measured >= .001),"known-point correction never supplies missing cloth")
	var near_face := cloth_face.duplicate()
	for index: int in range(near_face.size()): near_face[index] -= Vector3(0,0,.0015)
	var near_rows: Array[Dictionary] = [{"posed":near_face}]
	var near_cloth := _surface_depth(_surface_projection(near_rows,Vector3.BACK),_surface_uv(point,Vector3.BACK))
	_check(is_finite(near_cloth) and near_cloth-measured < .001,"real sub1mm cloth remains a clearance failure")
	var farther_face := cloth_face.duplicate()
	for index: int in range(farther_face.size()): farther_face[index] -= Vector3(0,0,.0005)
	var farther_rows: Array[Dictionary] = [{"posed":farther_face}]
	var farther := _surface_depth(_surface_projection(farther_rows,Vector3.BACK),_surface_uv(point,Vector3.BACK))
	var conservative := _surface_measured_body(point,Vector3.BACK,farther)
	_check(is_finite(farther) and conservative == farther and conservative > measured and cloth-conservative < .001,"farther actual body ray wins and preserves the stronger outer-body clearance failure")
	_check(_surface_tangents_valid(PackedFloat32Array([1,0,0,1,0,1,0,-1]),2),"unit normal-derived tangents accept both exact handedness signs")
	_check(not _surface_tangents_valid(PackedFloat32Array([1,0,0]),1),"tangent vertex-count mismatch is rejected")
	_check(not _surface_tangents_valid(PackedFloat32Array([1,0,0,.5]),1),"noncanonical tangent handedness is rejected")
	_check(not _surface_tangents_valid(PackedFloat32Array([INF,0,0,1]),1) and not _surface_tangents_valid(PackedFloat32Array([1,0,0,NAN]),1),"nonfinite tangent direction and handedness are rejected")
	_check(not _surface_tangents_valid(PackedFloat32Array([2,0,0,1]),1),"nonunit tangent direction is rejected")

func _surface_math() -> void:
	_surface_correction_math()
	var a: Array[Dictionary] = [{"posed":PackedVector3Array([Vector3(0,0,0.1),Vector3(0,1,0.1),Vector3(1,0,0.1)])}]
	var b: Array[Dictionary] = [{"posed":PackedVector3Array([Vector3(0.25,0.25,0.102),Vector3(0.25,0.75,0.102),Vector3(0.75,0.25,0.102)])}]
	var overlap := _surface_overlap(a,b,Vector3.BACK)
	_check(overlap.size() >= 4,"projected overlap includes actual boundary and interior witnesses")
	var fit := _surface_lapel_pair(a,b)
	_check(fit.covered >= 4 and absf(fit.minimum-0.002) < 0.00000001,"ray helper measures actual2mm triangle separation")
	var displaced: Vector3 = b[0].posed[0]; displaced.z = 0.095; b[0].posed[0] = displaced
	var crossing := _surface_lapel_pair(a,b)
	_check(crossing.minimum < -0.004,"one off-grid triangle-boundary breakthrough cannot hide behind a good centroid")
	var empty: Array[Dictionary] = []
	_check(not is_finite(_surface_depth(_surface_projection(empty,Vector3.BACK),Vector2(0.25,0.25))),"absent cloth is missing coverage, not zero clearance")
	var opposite: Array[Dictionary] = [{"posed":PackedVector3Array([Vector3(0,0,-0.1),Vector3(0,1,-0.1),Vector3(1,0,-0.1)])}]
	var inward: Array[Dictionary] = [{"posed":PackedVector3Array([Vector3(0,0,0.2),Vector3(1,0,0.2),Vector3(0,1,0.2)])}]
	_check(_surface_projection(opposite,Vector3.BACK).is_empty() and _surface_projection(inward,Vector3.BACK).is_empty(),"opposite-half lining and inward-facing cloth cannot fabricate front coverage")
	for direction: Vector3 in SURFACE_DIRECTIONS:
		var center := Vector3(0.2,1.4,0.1)
		if direction == Vector3.LEFT: center.x = -0.2
		var u := Vector3.RIGHT if direction == Vector3.BACK or direction == Vector3.UP else Vector3.BACK
		var v := Vector3.BACK if direction == Vector3.UP else Vector3.UP
		var vertices := PackedVector3Array([center-u*0.1-v*0.1,center+u*0.1-v*0.1,center+v*0.1])
		if -(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).dot(direction) < 0:
			var swap := vertices[1]; vertices[1] = vertices[2]; vertices[2] = swap
		var triangle: Array[Dictionary] = [{"posed":vertices}]
		_check(absf(_surface_depth(_surface_projection(triangle,direction),_surface_uv(center,direction))-center.dot(direction)) < 0.0000001,"front/side/top rays preserve signed depth: "+str(direction))
	_check(_surface_shoulder(Vector3(0.29,1.405,0)) and _surface_shoulder(Vector3(-0.24,1.445,0)),"canonical shoulder-width defect witnesses are included")
	_check(not _surface_shoulder(Vector3(0.085,1.48,0)) and not _surface_shoulder(Vector3(0.12,1.43,0.1)),"neck and intentional central opening are explicitly excluded")
	surface_groups += 1
