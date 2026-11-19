extends SceneTree
const View = preload("res://scripts/kingdom_world_view.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var cases: int = 0
var failures: Array[String] = []
var world: World
var view: View

class MovedFence extends Node3D:
	func obstacle_records() -> Array[Dictionary]:
		return [{"owner":"props:143","bounds":AABB(Vector3.ZERO,Vector3(34,1.65,0.24))}]

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _difference(actual: Variant,expected: Variant,path: String = "view") -> String:
	if (actual is int or actual is float) and (expected is int or expected is float):
		return "" if float(actual) == float(expected) else path+" number"
	if typeof(actual) != typeof(expected): return path+" type"
	if actual is Dictionary:
		if actual.size() != expected.size(): return path+" keys"
		for key: Variant in expected:
			if not actual.has(key): return path+" missing "+str(key)
			var mismatch: String = _difference(actual[key],expected[key],path+"."+str(key))
			if not mismatch.is_empty(): return mismatch
		return ""
	if actual is Array:
		if actual.size() != expected.size(): return path+" count"
		for index: int in range(expected.size()):
			var mismatch: String = _difference(actual[index],expected[index],path+"["+str(index)+"]")
			if not mismatch.is_empty(): return mismatch
		return ""
	return "" if actual == expected else path+" value"

func _source() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/kingdom_view_reference.json"))
	_check(raw is Dictionary and raw.get("counts",{}).get("cases") == 1599,"complete source reference exists")
	if not raw is Dictionary: return
	for row: Dictionary in raw.cases:
		var snapshot: Dictionary = row.snapshot.duplicate(true)
		var before: Dictionary = snapshot.duplicate(true)
		var result: Dictionary = View.facts(snapshot)
		var mismatch: String = _difference(result,row.expected)
		_check(mismatch.is_empty(),"source "+str(row.id)+" "+mismatch)
		_check(snapshot == before,"source snapshot untouched "+str(row.id))
		cases += 1
	_check(cases == 1599,"all1599 source views completed")
	for value: float in [INF,-INF]:
		_check(View.facts({"flags":{"blueTarpCleared":value}}).banners.blue_tarp.alpha == 0.58,"source numeric infinity remains truthy")
	_check(View.facts({"flags":{"blueTarpCleared":NAN}}).banners.blue_tarp.alpha == 1.0,"source NaN remains falsey")

func _nodes() -> Array[Node]:
	var nodes: Array[Node] = [view]; nodes.append_array(view.find_children("*","",true,false)); return nodes

func _resources() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in _nodes():
		if node is MeshInstance3D:
			var surfaces: Array = []
			for index: int in range(node.mesh.get_surface_count()):
				var material: StandardMaterial3D = node.get_active_material(index) as StandardMaterial3D
				surfaces.append([hash(node.mesh.surface_get_arrays(index)),material.get_instance_id(),material.albedo_color,material.transparency])
			result[node.get_instance_id()] = [node.mesh.get_instance_id(),surfaces]
		elif node is Label3D: result[node.get_instance_id()] = [node.text,node.font.get_instance_id(),node.transform]
	return result

func _geometry() -> void:
	var triangles: int = 0; var surfaces: int = 0; var labels: int = 0
	var finite: bool = true; var normals: bool = true
	for node: Node in _nodes():
		_check(not node is CollisionObject3D and not node is CollisionShape3D and not node is Light3D and not node is Timer and not node is Camera3D and not node is AudioStreamPlayer,"presentation-only "+str(node.name))
		_check(not node.is_processing() and not node.is_physics_processing() and not node.is_processing_input() and not node.is_processing_unhandled_input(),"no clock/input "+str(node.name))
		if node is Label3D:
			labels += 1
			_check(not node.no_depth_test and node.shaded and node.billboard == BaseMaterial3D.BILLBOARD_DISABLED,"fixed world-depth mark text "+node.text)
		if not node is MeshInstance3D: continue
		for index: int in range(node.mesh.get_surface_count()):
			surfaces += 1
			var arrays: Array = node.mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			triangles += int(arrays[Mesh.ARRAY_INDEX].size()/3.0) if arrays[Mesh.ARRAY_INDEX] != null else int(vertices.size()/3.0)
			for normal: Vector3 in ns: normals = normals and normal.is_finite() and absf(normal.length()-1.0) < 0.001
			for vertex: Vector3 in vertices: finite = finite and (node.global_transform*vertex).is_finite()
	_check(finite and normals,"finite original geometry and unit normals")
	_check(triangles <= 6000 and surfaces <= 90 and _nodes().size() <= 180 and labels == 18,"bank budget triangles=%d surfaces=%d nodes=%d labels=%d"%[triangles,surfaces,_nodes().size(),labels])
	_check(view._groups.size() == 26,"complete fixed26 state groups")
	for id: String in View.IDS:
		for faded: bool in [false,true]:
			var group: Node3D = view._groups["banner_"+id+("_faded" if faded else "_full")]
			var correct_alpha: bool = true
			for child: Node in group.get_children():
				if not child is MeshInstance3D: continue
				for surface: int in range(child.mesh.get_surface_count()):
					var material: StandardMaterial3D = child.get_active_material(surface) as StandardMaterial3D
					correct_alpha = correct_alpha and absf(material.albedo_color.a-(0.58 if faded else 1.0)) < 0.000001
					correct_alpha = correct_alpha and (material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA if faded else material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
			_check(correct_alpha,"actual banner alpha/depth bank "+id+str(faded))

func _ray(from: Vector3,to: Vector3) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))

func _run() -> void:
	_source()
	var bad_world := MovedFence.new(); var refused := View.new()
	root.add_child(bad_world); root.add_child(refused)
	_check(refused.build(bad_world).is_empty() and refused.get_child_count() == 0,"moved/missing fence refuses atomically without relocating targets")
	bad_world.free(); refused.free()
	world = World.new(); root.add_child(world); world.build()
	await physics_frame; await physics_frame
	var colliders: Array = world.obstacle_records().duplicate(true)
	var services: Dictionary = world.service_points.duplicate(true)
	var footprints: Array[Rect2] = world.collision_footprints()
	view = View.new(); root.add_child(view)
	_check(not view.build(world).is_empty(),"build actual Kingdom bank")
	_geometry()
	var anchors: Dictionary = view.inspect().anchors
	var definitions: Array[Dictionary] = View._definitions()
	for index: int in range(View.IDS.size()):
		var id: String = View.IDS[index]; var d: Dictionary = definitions[index]
		_check(anchors.banners[id].point == Content.to_world(Vector2(d.banner.x,d.banner.y)),"canonical banner anchor "+id)
		var marks: Array = d.get("marks",[])
		for mark_index: int in range(marks.size()):
			var key: String = id+":"+str(mark_index); var anchor: Dictionary = anchors.marks[key]
			var source := Vector2(marks[mark_index].x,marks[mark_index].y)
			var expected: Vector3 = Content.to_world(source)
			_check(anchor.source == source and absf(anchor.transform.origin.x-expected.x) < 0.0001,"canonical mark target retained "+key)
			if anchor.mount == "ground":
				_check(anchor.transform.origin.is_equal_approx(expected+Vector3.UP*0.025) and anchor.transform.basis.z.dot(Vector3.UP) > 0.999,"ground paint exactpoint/normal "+key)
			elif anchor.mount == "fence":
				var fence: AABB = anchors.fence
				_check(absf(expected.z-fence.position.z) < 0.002 and absf(anchor.transform.origin.z-(fence.position.z-0.012)) < 0.0001,"actual fence face bound at canonical target")
				for suffix: String in ["_open","_done"]:
					var group: Node3D = view._groups["mark_cart_cavalry_0"+suffix]
					var clear: bool = true
					for child: Node in group.find_children("*","GeometryInstance3D",true,false):
						var geometry: GeometryInstance3D = child as GeometryInstance3D
						for endpoint: int in range(8):
							var p: Vector3 = geometry.global_transform*geometry.get_aabb().get_endpoint(endpoint)
							clear = clear and p.z < fence.position.z-0.008 and p.x > fence.position.x and p.x < fence.end.x and p.y > 0 and p.y < fence.end.y
					_check(clear,"entire actual fence mark geometry outside solid "+suffix)
				var at: Vector3 = anchor.transform.origin
				_check(_ray(at+Vector3(0,0,-1),at).is_empty() and not _ray(at+Vector3(0,0,-1),at+Vector3(0,0,0.5)).is_empty(),"real layer1 fence remains behind mark")
			else:
				var newsbox: AABB = anchors.newsbox
				_check(key == "blue_tarp:0" and source == Vector2(6020,1180) and absf(expected.z-newsbox.get_center().z) < 0.002,"newsbox stencil retains exact canonical source point")
				_check(anchor.transform.basis.get_scale().is_equal_approx(Vector3.ONE*0.45) and absf(anchor.transform.origin.z-newsbox.end.z-0.012) < 0.0001,"stencil scale/face attachment from actual box")
				for suffix: String in ["_open","_done"]:
					var group: Node3D = view._groups["mark_blue_tarp_0"+suffix]
					var clear: bool = true
					for child: Node in group.find_children("*","GeometryInstance3D",true,false):
						var geometry: GeometryInstance3D = child as GeometryInstance3D
						for endpoint: int in range(8):
							var p: Vector3 = geometry.global_transform*geometry.get_aabb().get_endpoint(endpoint)
							clear = clear and p.z > newsbox.end.z+0.008 and p.x > newsbox.position.x and p.x < newsbox.end.x and p.y > newsbox.position.y and p.y < newsbox.position.y+0.50
					_check(clear,"entire stencil fits lower newsbox face outside solid and below window "+suffix)
				var at: Vector3 = anchor.transform.origin
				_check(_ray(at+Vector3(0,0,1),at).is_empty() and not _ray(at+Vector3(0,0,1),at-Vector3(0,0,0.5)).is_empty(),"real layer1 newsbox remains behind stencil")
	var snapshot: Dictionary = {"kingdom":{"stage":"tarp_marks","marks":1},"flags":{"blueTarpCleared":true}}
	var before: Dictionary = snapshot.duplicate(true); view.sync(snapshot)
	_check(snapshot == before,"sync leaves input unchanged")
	_check(view.inspect().visible.size() == 7 and view.inspect().visible.has("mark_blue_tarp_0_done") and view.inspect().visible.has("mark_blue_tarp_1_open"),"done and pending marks coexist with all4 banners")
	var resource_ids: Dictionary = _resources(); var writes: int = view.inspect().writes
	for index: int in range(1000): view.sync(snapshot)
	_check(view.inspect().writes == writes and _resources() == resource_ids,"1000 identical syncs preserve resources and avoid property writes")
	view.build(world); _check(_resources() == resource_ids,"repeated build preserves bank")
	view.sync({"kingdom":{"stage":"tarp_boss","marks":7},"flags":{"blueTarpCleared":false}})
	_check(view.inspect().visible.size() == 4 and view.inspect().visible.has("banner_blue_tarp_full"),"boss stage hides completed marks and independent flag reverses fade")
	view.sync({"kingdom":{"stage":"wire_marks","marks":7},"flags":{"throneDitchCleared":true}})
	_check(view.inspect().visible.has("mark_copper_choir_2_done") and view.inspect().visible.has("banner_emperor_faded"),"independent final flag and active clan")
	view.sync({}); _check(view.inspect().visible.size() == 4 and not view.inspect().visible.has("banner_emperor_faded"),"fresh/revoked snapshot clears stale marks and fades")
	_check(_resources() == resource_ids,"reverse snapshots never mutate shared resources")
	var exposed: Dictionary = view.inspect(); exposed.facts.clear(); exposed.anchors.clear()
	_check(not view.inspect().facts.is_empty() and not view.inspect().anchors.is_empty(),"inspection copies detached")
	await physics_frame
	_check(world.obstacle_records() == colliders and world.service_points == services and world.collision_footprints() == footprints,"all real collider/service/navigation data unchanged")
	view.free(); world.free()
	_check(cases == 1599,"oracle completion guard")
	for failure: String in failures: push_error(failure)
	print("3D KINGDOM VIEW: %s (%d checks; %d unchanged-source views)"%["PASS" if failures.is_empty() else "FAIL",checks,cases])
	quit(0 if failures.is_empty() else 1)
