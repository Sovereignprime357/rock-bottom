extends SceneTree
const View = preload("res://scripts/world_ownership_view.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var oracle_cases: int = 0
var failures: Array[String] = []
var world: World
var view: View

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _difference(actual: Variant,expected: Variant,path: String = "view") -> String:
	# JSON numbers deserialize as float; Godot Dictionary equality treats nested
	# int/float values as distinct. Compare exact numeric value, never truthiness
	# or an epsilon, and retain exact keys, strings, booleans and array ordering.
	if (actual is int or actual is float) and (expected is int or expected is float):
		return "" if float(actual) == float(expected) else path+" numeric value"
	if typeof(actual) != typeof(expected): return path+" type"
	if actual is Dictionary:
		if actual.size() != expected.size(): return path+" key count"
		for key: Variant in expected:
			if not actual.has(key): return path+" missing "+str(key)
			var mismatch: String = _difference(actual[key],expected[key],path+"."+str(key))
			if not mismatch.is_empty(): return mismatch
		return ""
	if actual is Array:
		if actual.size() != expected.size(): return path+" array count"
		for index: int in range(expected.size()):
			var mismatch: String = _difference(actual[index],expected[index],path+"["+str(index)+"]")
			if not mismatch.is_empty(): return mismatch
		return ""
	return "" if actual == expected else path+" value"

func _source() -> void:
	_check(_difference({"n":1},{"n":1.0}).is_empty(),"fixture JSON numeric transport equals exact integer")
	_check(not _difference({"n":1},{"n":1.01}).is_empty(),"fixture comparator detects numeric drift without epsilon")
	_check(not _difference({"n":true},{"n":1.0}).is_empty(),"fixture comparator retains boolean type")
	_check(not _difference({"n":1},{"other":1}).is_empty(),"fixture comparator retains keys")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_ownership_reference.json"))
	_check(raw is Dictionary and raw.get("counts",{}).get("cases") == 1078,"complete source fixture exists")
	if not raw is Dictionary: return
	for row: Dictionary in raw.cases:
		var snapshot: Dictionary = row.snapshot.duplicate(true)
		var before: Dictionary = snapshot.duplicate(true)
		var result: Dictionary = View.facts(snapshot,Vector2(row.center[0],row.center[1]))
		var mismatch: String = _difference(result,row.expected)
		_check(mismatch.is_empty(),"source view "+str(row.id)+" "+mismatch)
		_check(snapshot == before,"pure source view "+str(row.id))
		oracle_cases += 1
	_check(oracle_cases == 1078,"all 1078 source comparisons completed")
	_check(View.facts({},Vector2.INF).is_empty(),"nonfinite source position refuses")

func _all() -> Dictionary:
	var claims: Dictionary = {}; var upgrades: Dictionary = {}
	for site: Dictionary in Content.definition("src/systems/campaigns.js","CLAIM_SITES",[]): claims[site.id] = true
	for id: String in View.UPGRADES: upgrades[id] = true
	return {"office":{"owned":true,"upgrades":upgrades},"districtClaims":claims,"flags":{"scrapHideoutOwned":true,"momHideoutOwned":true}}

func _cached_source() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_ownership_reference.json"))
	var completed: int = 0
	for row: Dictionary in raw.cases:
		var snapshot: Dictionary = row.snapshot.duplicate(true)
		var center := Vector2(row.center[0],row.center[1])
		_check(view.sync(snapshot,center) and _difference(view.inspect().facts,row.expected).is_empty(),"cached exact source output "+str(row.id))
		completed += 1
	_check(completed == 1078,"all1078 cached source outputs completed")
	var snapshot: Dictionary = _all(); var point := Vector2(4380,2110)
	view.sync(snapshot,point)
	var builds: int = view.inspect().fact_builds
	view.sync(snapshot.duplicate(true),point+Vector2(0.01,0))
	_check(view.inspect().fact_builds == builds,"fresh equal dictionary and same proximity skip nested reconstruction")
	snapshot.districtClaims.canal = 1
	view.sync(snapshot,point)
	_check(view.inspect().facts.office.claims == 10 and view.inspect().facts.claims.canal.visible,"mutated same dictionary preserves truthy versus strict-true claim split")
	snapshot.flags.momHideoutOwned = false
	view.sync(snapshot,point)
	_check(not view.inspect().facts.hideouts.mom.visible,"mutated same flags dictionary revokes hatch")
	for center: Vector2 in [Vector2(4380+99.99,2110),Vector2(4480,2110),Vector2(4380+100.01,2110),Vector2(4380+99.99,2110)]:
		view.sync(snapshot,center)
		_check(_difference(view.inspect().facts,View.facts(snapshot,center)).is_empty(),"cached strict100 crossing "+str(center))
	var before: Dictionary = view.inspect()
	_check(not view.sync(snapshot,Vector2.INF) and view.inspect() == before,"nonfinite center refuses before cache/counters/node writes")

func _nodes() -> Array[Node]:
	var result: Array[Node] = [view]
	result.append_array(view.find_children("*","",true,false)); return result

func _ids() -> Array[int]:
	var result: Array[int] = []
	for node: Node in _nodes(): result.append(node.get_instance_id())
	return result

func _resources() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in _nodes():
		if node is MeshInstance3D:
			var surfaces: Array = []
			for index: int in range(node.mesh.get_surface_count()):
				var material: Material = node.get_active_material(index)
				surfaces.append([hash(node.mesh.surface_get_arrays(index)),material.get_instance_id() if material != null else 0])
			result[node.get_instance_id()] = [node.mesh.get_instance_id(),surfaces]
		elif node is Label3D: result[node.get_instance_id()] = [node.font.get_instance_id(),node.text]
	return result

func _ray(from: Vector3,to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _geometry() -> void:
	var triangles: int = 0; var surfaces: int = 0; var labels: int = 0
	var finite: bool = true; var normals: bool = true; var aperture: bool = true
	var front: Vector3 = world.ownership_surfaces().office.front
	for node: Node in _nodes():
		_check(not node is CollisionObject3D and not node is CollisionShape3D and not node is Timer and not node is Light3D and not node is Camera3D and not node is AudioStreamPlayer,"presentation-only node "+str(node.name))
		_check(not node.is_processing() and not node.is_physics_processing() and not node.is_processing_input() and not node.is_processing_unhandled_input(),"no independent clock/input "+str(node.name))
		if node is Label3D:
			labels += 1
			_check(not node.no_depth_test and node.shaded and node.billboard == BaseMaterial3D.BILLBOARD_DISABLED,"world depth and fixed label "+node.text)
		if not node is MeshInstance3D: continue
		for index: int in range(node.mesh.get_surface_count()):
			surfaces += 1
			var arrays: Array = node.mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			triangles += int(arrays[Mesh.ARRAY_INDEX].size()/3.0) if arrays[Mesh.ARRAY_INDEX] != null else int(vertices.size()/3.0)
			for normal: Vector3 in ns: normals = normals and normal.is_finite() and absf(normal.length()-1.0) < 0.001
			for vertex: Vector3 in vertices:
				var p: Vector3 = node.global_transform*vertex
				finite = finite and p.is_finite()
				if absf(p.z-front.z) < 0.27 and p.y > 0.04 and p.y < 2.5 and absf(p.x-front.x) < 1.2: aperture = false
	_check(finite and normals,"all bank vertices finite and normals unit")
	_check(aperture,"all Office door/upgrade bank geometry leaves actual 2.4m aperture clear")
	_check(triangles <= 10000 and surfaces <= 100 and _nodes().size() <= 200 and labels == 15,"bounded complete bank triangles=%d surfaces=%d nodes=%d labels=%d" % [triangles,surfaces,_nodes().size(),labels])

func _run() -> void:
	_source()
	world = World.new(); world.dynamic_ownership = true; root.add_child(world); world.build()
	await physics_frame
	await physics_frame
	var colliders: Array = world.obstacle_records().duplicate(true)
	var services: Dictionary = world.service_points.duplicate(true)
	var footprints: Array[Rect2] = world.collision_footprints()
	var surfaces: Dictionary = world.ownership_surfaces()
	_check(surfaces.claims.size() == 11 and surfaces.hideouts.size() == 2,"actual world has canonical ownership anchors")
	_check(surfaces.office.source_center == Vector2(4920,3220),"Office source door center retained")
	var front: Vector3 = surfaces.office.front
	var from: Vector3 = front+Vector3(0,1.6,1.0)
	var to: Vector3 = front+Vector3(0,1.6,-1.0)
	_check(_ray(from,to).is_empty(),"real physics sees existing Office aperture before view")
	var wall_from: Vector3 = from+Vector3(3.0,0,0)
	var wall_to: Vector3 = to+Vector3(3.0,0,0)
	_check(not _ray(wall_from,wall_to).is_empty(),"real physics still sees adjacent facade")
	view = View.new(); root.add_child(view)
	_check(not view.build(world).is_empty(),"builds against real opt-in FullWorld")
	_cached_source()
	var all: Dictionary = _all(); var input_before: Dictionary = all.duplicate(true)
	_check(view.sync(all,Vector2(4920,3260)),"all owned sync accepted")
	_check(all == input_before,"render sync does not alter source snapshot")
	_geometry()
	var ids: Array[int] = _ids(); var resources: Dictionary = _resources()
	var writes: int = view.inspect().writes
	var fact_builds: int = view.inspect().fact_builds
	for index: int in range(1000): view.sync(all,Vector2(4920,3260))
	_check(view.inspect().writes == writes and view.inspect().fact_builds == fact_builds and _ids() == ids and _resources() == resources,"1000 unchanged syncs create no resources, facts or property writes")
	view.build(world)
	_check(view.inspect().builds == 1 and _ids() == ids,"second build retains exact bank")
	var exposed: Dictionary = view.inspect(); exposed.facts.clear(); exposed.surfaces.clear()
	_check(not view.inspect().facts.is_empty() and not view.inspect().surfaces.is_empty(),"inspection dictionaries cannot mutate renderer")
	var fresh: Dictionary = {"office":{"owned":false,"upgrades":{}},"districtClaims":{},"flags":{}}
	view.sync(fresh,Vector2(4920,3260))
	_check(view.inspect().visible == ["door_locked","title_0"],"fresh/revoked state removes all stale ownership geometry")
	view.sync(all,Vector2(4920,3260)); view.sync(fresh,Vector2(4920,3260)); view.sync(all,Vector2(4920,3260))
	_check(_ids() == ids and _resources() == resources,"reverse/restore cycles reuse immutable meshes and final material bindings")
	for site: Dictionary in Content.definition("src/systems/campaigns.js","CLAIM_SITES",[]):
		var point := Vector2(site.sign.x,site.sign.y)
		_check(surfaces.claims[site.id] == Content.to_world(point),"canonical sign pivot "+str(site.id))
		view.sync(all,point+Vector2(99.99,0)); _check(view.inspect().visible.has("caption_"+str(site.id)),"claim near caption "+str(site.id))
		view.sync(all,point+Vector2(100,0)); _check(not view.inspect().visible.has("caption_"+str(site.id)),"claim strict100 boundary "+str(site.id))
	for id: String in ["mom","scrap"]:
		var door: Dictionary = Content.definition("src/systems/daily_hideouts.js","HIDEOUT_DOORS",{})[id]
		var rect: Rect2 = surfaces.hideouts[id]
		_check(rect.position == Vector2(Content.to_world(Vector2(door.x,door.y)).x,Content.to_world(Vector2(door.x,door.y)).z) and rect.size.is_equal_approx(Vector2(door.w,door.h)*0.04),"exact flat source door rectangle "+id)
	await physics_frame
	_check(_ray(from,to).is_empty() and not _ray(wall_from,wall_to).is_empty(),"actual aperture/wall rays unchanged after ownership bank")
	_check(world.obstacle_records() == colliders and world.service_points == services and world.collision_footprints() == footprints,"all actual colliders/services/navigation footprints unchanged")
	var count: int = oracle_cases
	view.free(); world.free()
	_check(count == 1078,"oracle completion guard")
	for failure: String in failures: push_error(failure)
	print("3D WORLD OWNERSHIP: %s (%d checks; %d unchanged-source views)" % ["PASS" if failures.is_empty() else "FAIL",checks,count])
	quit(0 if failures.is_empty() else 1)
