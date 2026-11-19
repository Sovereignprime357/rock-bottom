extends SceneTree

const Roster = preload("res://scripts/character_roster.gd")
const Animator = preload("res://scripts/actor_animation.gd")
const Visibility = preload("res://scripts/presentation_visibility.gd")
var checks: int = 0
var failures: Array[String] = []
var completed: int = 0
var floor_free_completed: bool = false


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	_geometry_cases()
	_floor_free_cases()
	var camera := Camera3D.new()
	var sun := DirectionalLight3D.new()
	camera.far = 380.0
	root.add_child(camera); root.add_child(sun)
	sun.rotation.x = -0.7
	await process_frame
	var context: Dictionary = Visibility.frame_context(camera,sun,-1.0,true)
	_check(Visibility.sphere_needs_pose(Vector3(0,0,-10),0.5,context),"real camera planes retain visible geometry")
	_check(not Visibility.sphere_needs_pose(Vector3(1000,0,0),0.5,context),"real camera planes reject a distant separated caster")
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 85
	var no_floor: Dictionary = Visibility.frame_context(camera,sun,-INF,true)
	_check(not Visibility.sphere_needs_pose(Vector3(1000,0,-1000),.5,no_floor),"real camera far-plane caster and outgoing sun extrusion separate without receiver floor")
	_check(Visibility.sphere_needs_pose(Vector3(1000,0,0),.5,Visibility.frame_context(camera,sun)),"actual context defaults to no uncertified shadow-light assumption")
	for id: String in Roster.supported_visuals():
		var first: Node3D = Roster.create(StringName(id),71)
		var reference: Node3D = Roster.create(StringName(id),71)
		_check(first != null and reference != null,id+": both originals construct")
		if first == null or reference == null:
			if first != null: first.free()
			if reference != null: reference.free()
			continue
		root.add_child(first); root.add_child(reference)
		_uncached(reference)
		await process_frame
		if _actor_cases(first,reference,id): completed += 1
		first.free(); reference.free()
	_check(completed == 72 and floor_free_completed,"all72 original templates and floor-free proof cases finish without aborting")
	var unknown := Node3D.new(); root.add_child(unknown)
	_check(Visibility.needs_pose(unknown,context),"unknown art fails open")
	unknown.set_meta("roster_rig",{})
	_check(Visibility.needs_pose(unknown,context),"incomplete unknown rig metadata also fails open without a script abort")
	unknown.free(); camera.free(); sun.free()
	if failures.is_empty():
		print("3D PRESENTATION VISIBILITY GATE: PASS (%d checks; %d templates; exact caches, hidden return, full bounds and shadows)" % [checks,completed])
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D PRESENTATION VISIBILITY GATE: FAIL (%d/%d checks; %d/72 templates)" % [failures.size(),checks,completed])
		quit(1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)


func _geometry_cases() -> void:
	var planes: Array[Plane] = [Plane(Vector3.RIGHT,10),Plane(Vector3.LEFT,10),Plane(Vector3.UP,10),Plane(Vector3.DOWN,10),Plane(Vector3.BACK,10),Plane(Vector3.FORWARD,10)]
	var context := {"camera":Vector3.ZERO,"planes":planes,"shadow_enabled":true,"shadow_distance":2.0,"light_direction":Vector3(0,-1,0),"min_receiver_y":-20.0,"sole_shadow_light":true}
	_check(Visibility.sphere_needs_pose(Vector3(11,0,0),1,context),"whole bound touching the frustum cannot be rejected by its center")
	_check(not Visibility.sphere_needs_pose(Vector3(20,4,0),1,context),"separated body and downward shadow can skip unchanged ambient work")
	context.light_direction = Vector3(-1,-1,0)
	_check(Visibility.sphere_needs_pose(Vector3(20,4,0),1,context),"offscreen caster outside shadow-distance sphere still updates when its shadow crosses view")
	context.light_direction = Vector3(0,-1,0)
	for patch: Dictionary in [{"light_direction":Vector3(INF,0,0)},{"shadow_distance":0.0},{"planes":[]},{"camera":Vector3(NAN,0,0)},{"sole_shadow_light":false}]:
		var broken := context.duplicate(true); broken.merge(patch,true)
		_check(Visibility.sphere_needs_pose(Vector3(20,4,0),1,broken),"unknown shadow/frustum data fails open: "+str(patch.keys()))
	_check(Visibility.sphere_needs_pose(Vector3(20,4,0),INF,context) and Visibility.sphere_needs_pose(Vector3(20,4,0),0,context),"invalid bounds fail open")
	context.shadow_distance = 30.0
	_check(not Visibility.sphere_needs_pose(Vector3(20,4,0),1,context),"complete outward shadow proof also excludes near separated bodies")
	context.shadow_enabled = false
	_check(not Visibility.sphere_needs_pose(Vector3(20,4,0),1,context),"explicitly disabled shadows do not manufacture a shadow region")
	for basis: Basis in [Basis.from_scale(Vector3(1,3,0.5)),Basis(Vector3(1,0,0),Vector3(2,1,0),Vector3(0,0,1)),Basis.from_euler(Vector3(0.7,0.2,1.1))]:
		var scale_bound: float = Visibility._stretch(basis)
		var bounded: bool = true
		for i: int in range(91):
			var direction := Vector3(sin(i*0.31),cos(i*0.17),sin(i*0.73)).normalized()
			bounded = bounded and (basis*direction).length() <= scale_bound
		_check(bounded,"scale/shear bound contains transformed sphere samples")


func _floor_free_cases() -> void:
	var planes: Array[Plane] = [Plane(Vector3.RIGHT,10),Plane(Vector3.LEFT,10),Plane(Vector3.UP,10),Plane(Vector3.DOWN,10),Plane(Vector3.BACK,10),Plane(Vector3.FORWARD,10)]
	var context := {"camera":Vector3.ZERO,"planes":planes,"shadow_enabled":true,"shadow_distance":2.0,"light_direction":Vector3.DOWN,"min_receiver_y":-INF,"sole_shadow_light":true}
	var axes: Array[Vector3] = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
	for outward: Vector3 in axes:
		var center: Vector3 = outward*20.0
		var tangent: Vector3 = outward.cross(Vector3.UP)
		if tangent.length_squared() < .5: tangent = outward.cross(Vector3.RIGHT)
		for direction: Vector3 in [outward,tangent,tangent+outward*.01]:
			context.light_direction = direction
			_check(not Visibility.sphere_needs_pose(center,1,context),"whole outward or parallel infinite shadow can skip without any floor")
			# Independently sample the actual extruded sphere surface against all
			# camera half-spaces, including huge distances and the caster itself.
			for distance: float in [0.0,.5,10.0,1000.0,1000000.0]:
				for surface: Vector3 in axes:
					var point: Vector3 = center+surface+direction.normalized()*distance
					var outside: bool = false
					for plane: Plane in planes:
						if plane.distance_to(point) > 0.0: outside = true; break
					_check(outside,"certified caster's surface/ray never enters viewport volume")
		context.light_direction = -outward
		_check(Visibility.sphere_needs_pose(center,1,context),"incoming shadow crosses view and retains current pose without floor")
		_check(Visibility.sphere_needs_pose(outward*11.0,1,context),"touching whole sphere cannot be hidden")
	context.light_direction = Vector3(-1,-.1,0)
	_check(Visibility.sphere_needs_pose(Vector3(20,0,0),1,context),"downward incoming offscreen shadow remains visible at an unknown low receiver")
	context.light_direction = Vector3(-1,-4,0)
	_check(Visibility.sphere_needs_pose(Vector3(20,0,0),1,context),"absence of a common separating plane fails open even if sampled center ray misses")
	context.light_direction = Vector3.DOWN
	var overflowing: Dictionary = context.duplicate(true); overflowing.light_direction = Vector3(1e30,1e30,1e30)
	_check(Visibility.sphere_needs_pose(Vector3(20,0,0),1,overflowing),"finite light components with overflowing squared length fail open before normalization")
	var almost_unit: Dictionary = context.duplicate(true); almost_unit.min_receiver_y = -20.0
	almost_unit.planes[0] = Plane(Vector3(1.00002,0,0),10)
	_check(Visibility.sphere_needs_pose(Vector3((10.0+1.00001)/1.00002,0,0),1,almost_unit),"tolerated near-unit plane scales sphere projection instead of rejecting a touching bound")
	for certificate: Variant in [false,null,1,"true"]:
		var unknown: Dictionary = context.duplicate(true); unknown.sole_shadow_light = certificate
		_check(Visibility.sphere_needs_pose(Vector3(20,0,0),1,unknown),"unknown/extra shadow light revokes floor-free eligibility")
		unknown.shadow_enabled = false
		_check(Visibility.sphere_needs_pose(Vector3(20,0,0),1,unknown),"disabled sun does not certify an unmodeled shadow light")
	var missing: Dictionary = context.duplicate(true); missing.erase("sole_shadow_light")
	_check(Visibility.sphere_needs_pose(Vector3(20,0,0),1,missing),"missing light policy is not assumed")
	context.shadow_distance = 30.0
	_check(not Visibility.sphere_needs_pose(Vector3(20,0,0),1,context),"complete outward extrusion proof is independent of near shadow distance")
	context.light_direction = Vector3.LEFT
	_check(Visibility.sphere_needs_pose(Vector3(20,0,0),1,context),"near incoming shadow still retains the whole current pose")
	context.light_direction = Vector3.DOWN
	_check(Visibility.sphere_needs_pose(Vector3(11,0,0),1,context),"near touching sphere cannot use the outward proof")
	floor_free_completed = true


func _uncached(art: Node3D) -> void:
	var rig: Dictionary = art.get_meta("roster_rig")
	rig.pose_cache_enabled = false
	for child: Dictionary in rig.companions: _uncached(child.node)


func _actor_cases(first: Node3D, reference: Node3D, id: String) -> bool:
	var rig: Dictionary = first.get_meta("roster_rig")
	var other: Dictionary = reference.get_meta("roster_rig")
	var origin: Transform3D = first.transform
	var meshes: Array[MeshInstance3D] = _meshes(first)
	var resources: Array = []
	for part: MeshInstance3D in meshes: resources.append([part.mesh,part.skin])
	var radius: float = Visibility.local_radius(first)
	_check(is_finite(radius) and radius > 0.0,id+": complete authored rig has a finite conservative bound")
	Animator.reset(first); Animator.reset(reference)
	var action: StringName = rig.definition.get("action",&"inspect")
	# Some profiles default to an accepted action (e.g. guard), which must never
	# be relabeled as cosmetic by this fixture. Those are tested separately below.
	if action not in rig.definition.actions or action not in Animator.AMBIENT_ACTIONS: action = &""
	var snapshot := {"action":action,"ambient_action":true,"action_phase":0.0,"local_velocity":Vector3(0.2,0,0.7),"gaze":Vector2(0.1,-0.1)}
	for frame: int in range(17):
		snapshot.action_phase = fmod(frame*0.173,1.0)
		Animator.tick(first,0.016,snapshot,0,frame == 0)
		Animator.tick(reference,0.016,snapshot,0,true)
	_check(int(rig.hidden_pose_skips) > 10 and int(rig.pose_updates) < int(other.pose_updates),id+": hidden unchanged ambient poses skip work")
	_check(_same_clocks(first,reference),id+": parent and nested clocks/gait consume every current snapshot")
	var paused_time: float = rig.time
	var paused_frame: int = rig.frame
	Animator.tick(first,0.0,{"dead":true},0,true)
	_check(float(rig.time) == paused_time and int(rig.frame) == paused_frame and rig.pose_deferred,id+": paused call neither consumes time nor flushes hidden presentation")
	snapshot.action_phase = 0.931
	var untouched := snapshot.duplicate(true)
	Animator.tick(first,0.016,snapshot,0,true); Animator.tick(reference,0.016,snapshot,0,true)
	_check(_same_geometry(first,reference) and snapshot == untouched,id+": visible return has current uncached geometry and does not mutate input")
	_check(_inside(first,radius),id+": moving original geometry including children/held props fits conservative bound")
	# Every accepted action remains immediate even if a caller also marks it ambient.
	for active: StringName in rig.definition.actions:
		if active in Animator.AMBIENT_ACTIONS: continue
		var before: int = rig.pose_updates
		for phase: float in [0.13,0.81]:
			var current := {"action":active,"ambient_action":true,"action_phase":phase,"action_serial":5,"contact":phase > 0.5}
			Animator.tick(first,0.02,current,0,false); Animator.tick(reference,0.02,current,0,true)
		_check(int(rig.pose_updates) == before+2 and _same_geometry(first,reference),id+": hidden accepted action remains current: "+String(active))
	for patch: Dictionary in [{"hurt":0.3},{"hurt":0.8},{"coat_count":0},{"coat_count":2},{"dead":true,"death_phase":0.2},{"dead":true,"death_phase":0.9},{"dead":true,"death_phase":0.9}]:
		var current := {"action":action,"ambient_action":true,"action_phase":0.71}
		current.merge(patch,true)
		var before: int = rig.pose_updates
		Animator.tick(first,0.02,current,0,false); Animator.tick(reference,0.02,current,0,true)
		_check(int(rig.pose_updates) == before+1 and _same_geometry(first,reference),id+": hidden transitions/death props remain current: "+str(patch))
	_check(_inside(first,radius),id+": full death release and mounted/assembly geometry fit bounds")
	Animator.reset(first); Animator.reset(reference)
	_check(not rig.pose_deferred and _same_geometry(first,reference) and first.transform == origin,id+": reset revokes deferred pose and restores actual geometry without moving authority")
	var same: bool = _meshes(first).size() == resources.size()
	for index: int in range(meshes.size()): same = same and meshes[index].mesh == resources[index][0] and meshes[index].skin == resources[index][1]
	_check(same,id+": animation does not rebuild or mutate shared geometry resources")
	if id in ["busker","launderlady","math","dennis","transit_dan","former_teller","docent"]:
		for phase: float in [0.12,0.68,0.91]:
			var current := {"action":rig.definition.get("action",&"inspect"),"action_phase":phase}
			Animator.tick(first,0.016,current); Animator.tick(reference,0.016,current)
		_check(_same_geometry(first,reference) and int(rig.global_pose_solves) < int(other.global_pose_solves),id+": exact global cache reduces chain solves through contact IK without stale descendants")
	if id == "price_guy":
		Animator.tick(first,0.02,{}); Animator.tick(reference,0.02,{})
		var queries: int = rig.attachment_queries
		var writes: int = rig.attachment_writes
		Animator.tick(first,0.02,{}); Animator.tick(reference,0.02,{})
		_check(int(rig.attachment_queries) == queries and int(rig.attachment_writes) == writes,"unchanged inert bindings avoid global queries and transform setters")
		Animator.tick(first,0.02,{"gaze":Vector2(0.000004,0)}); Animator.tick(reference,0.02,{"gaze":Vector2(0.000004,0)})
		_check(int(rig.attachment_writes) > writes and _same_geometry(first,reference),"tiny gaze remains exact through attachment cache")
	if id == "scrap_dog":
		var marker: Node3D = first.get_node("leash_collar")
		var extra := MeshInstance3D.new(); extra.mesh = BoxMesh.new(); marker.add_child(extra)
		_check(not is_finite(Visibility.local_radius(first)),"geometry added under weighted marker invalidates already cached bounds")
		extra.free()
		_check(is_finite(Visibility.local_radius(first)),"restored nonrendering weighted marker retains audited bounds")
		marker.top_level = true
		_check(not is_finite(Visibility.local_radius(first)),"top-level weighted marker cannot bypass bound validation")
		marker.top_level = false
		var records: Array = rig.weighted_markers
		rig.weighted_markers = [{"node":17}]
		_check(not is_finite(Visibility.local_radius(first)),"invalid weighted marker fails open without invoking object methods")
		rig.weighted_markers = records
	if id == "tony":
		Animator.reset(first)
		for frame: int in range(4): Animator.tick(first,0.02,{"ambient_action":true},2,false)
		var updates: int = rig.pose_updates
		Animator.tick(first,0.02,{"ambient_action":true},2,true)
		_check(int(rig.pose_updates) == updates+1 and not rig.pose_deferred,"same-detail return forces a current pose between distant update slots")
		var extra := MeshInstance3D.new(); extra.mesh = BoxMesh.new(); first.add_child(extra)
		_check(not is_finite(Visibility.local_radius(first)),"new unaudited geometry invalidates cached eligibility rather than disappearing")
		extra.free()
	return true


func _same_clocks(first: Node3D, second: Node3D) -> bool:
	var a: Dictionary = first.get_meta("roster_rig")
	var b: Dictionary = second.get_meta("roster_rig")
	for key: String in ["time","phase","motion","frame"]:
		if a[key] != b[key]: return false
	for i: int in range(a.companions.size()):
		if not _same_clocks(a.companions[i].node,b.companions[i].node): return false
	return true


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		if child is MeshInstance3D: result.append(child)
		result.append_array(_meshes(child))
	return result


func _vertices(art: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for part: MeshInstance3D in _meshes(art):
		if not part.is_visible_in_tree(): continue
		var local: Transform3D = Roster._relative(part,art)
		var palette: Array[Transform3D] = []
		if part.skin != null:
			var skeleton := part.get_node(part.skeleton) as Skeleton3D
			for i: int in range(part.skin.get_bind_count()): palette.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(i))*part.skin.get_bind_pose(i))
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if part.skin == null:
				for vertex: Vector3 in vertices: result.append(local*vertex)
				continue
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for index: int in range(vertices.size()):
				var point := Vector3.ZERO
				for slot: int in range(4):
					var offset: int = index*4+slot
					point += (palette[bones[offset]]*vertices[index])*weights[offset]
				result.append(local*point)
	return result


func _same_geometry(first: Node3D, second: Node3D) -> bool:
	var a: PackedVector3Array = _vertices(first)
	var b: PackedVector3Array = _vertices(second)
	if a.is_empty() or a.size() != b.size(): return false
	for i: int in range(a.size()):
		if not a[i].is_finite() or not b[i].is_finite() or a[i].distance_to(b[i]) > 0.000001: return false
	return true


func _inside(art: Node3D, radius: float) -> bool:
	if not is_finite(radius): return false
	for point: Vector3 in _vertices(art):
		if not point.is_finite() or point.length() > radius: return false
	return true
