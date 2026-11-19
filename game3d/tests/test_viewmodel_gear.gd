extends SceneTree
## Central runner only. Equipment is presentation context, never a weapon/gameplay owner.
const Rig = preload("res://scripts/first_person_rig.gd")
const Content = preload("res://scripts/content_catalog.gd")
const LEFT := "left_arm/forearm/wrist"
const RIGHT := "right_arm/forearm/wrist"
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []
var vertices_cache: Dictionary = {}

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child: Node in node.get_children(): result.append_array(_nodes(child))
	return result
func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in _nodes(node):
		if child is MeshInstance3D: result.append(child as MeshInstance3D)
	return result
func _items(rig: Rig,key: String) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in _nodes(rig):
		if node.has_meta(key):
			var id: String = str(node.get_meta(key))
			_check(not result.has(id),"cached identity unique: "+key+"/"+id)
			result[id] = node
	return result
func _mounted(rig: Rig,path: String,key: String) -> String:
	var socket: Node = rig.get_node_or_null(path)
	if socket == null: return "missing_socket"
	for node: Node in socket.get_children():
		if node is Node3D and node.has_meta(key) and node.is_visible_in_tree(): return str(node.get_meta(key))
	return ""
func _tool(rig: Rig) -> String: return _mounted(rig,LEFT+"/HeldTool","tool_id")
func _weapon(rig: Rig) -> String:
	var mounted: String = _mounted(rig,RIGHT+"/HeldWeapon","weapon_id")
	return "fists" if mounted.is_empty() else mounted
func _snapshot(rig: Rig) -> Dictionary:
	var poses: Dictionary = {}
	for node: Node in _nodes(rig):
		if node is Node3D: poses[node.get_instance_id()] = [node.transform,node.visible,node.get_parent().get_instance_id() if node.get_parent() != null else 0]
	return {"tool":rig.tool,"coat":rig.coat,"shoes":rig.shoes,"weapon":rig.weapon,"attack_weapon":rig.attack_weapon,"action":rig.action,"phase":rig.action_phase,"poses":poses}
func _resources(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for mesh: MeshInstance3D in _meshes(node): result[mesh.get_instance_id()] = [mesh.mesh,mesh.material_override]
	return result
func _contents(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for instance: MeshInstance3D in _meshes(node):
		var mesh: Mesh = instance.mesh
		if mesh != null and not result.has(mesh.get_rid()):
			var surfaces: Array = []
			for surface: int in range(mesh.get_surface_count()): surfaces.append(hash(mesh.surface_get_arrays(surface)))
			result[mesh.get_rid()] = surfaces
		var material: StandardMaterial3D = instance.material_override as StandardMaterial3D
		if material != null:
			result[material.get_rid()] = [material.albedo_color,material.roughness,material.emission_enabled,material.emission,material.emission_energy_multiplier,material.cull_mode,material.transparency,material.uv1_scale,material.uv1_triplanar,material.uv1_world_triplanar,material.albedo_texture]
	return result
func _vertices(mesh: Mesh) -> PackedVector3Array:
	if vertices_cache.has(mesh.get_rid()): return vertices_cache[mesh.get_rid()]
	var result := PackedVector3Array()
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: result.append_array(arrays[Mesh.ARRAY_VERTEX])
	vertices_cache[mesh.get_rid()] = result; return result
func _safe(rig: Rig,include_hidden: bool = false) -> bool:
	var inverse: Transform3D = rig.global_transform.affine_inverse()
	for mesh: MeshInstance3D in _meshes(rig):
		if mesh.mesh == null or not mesh.transform.is_finite(): return false
		if not include_hidden and not mesh.is_visible_in_tree(): continue
		var transform: Transform3D = inverse*mesh.global_transform
		for vertex: Vector3 in _vertices(mesh.mesh):
			var at: Vector3 = transform*vertex
			if not at.is_finite() or at.z >= -0.06 or at.z < -1.5 or absf(at.x) > 1.0 or absf(at.y) > 1.2: return false
	return true
func _advance(rig: Rig,seconds: float,stress: bool = false) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds-0.000001:
		var dt: float = minf(1.0/120.0,seconds-elapsed)
		rig.tick(dt,Vector3(5.5,0,-16.83) if stress else Vector3.ZERO,stress,stress,stress,100.0 if stress else 0.0,Vector2(0.3,-0.3) if stress else Vector2.ZERO)
		elapsed += dt
func _triangles(rig: Rig,node: Node) -> PackedVector3Array:
	var result := PackedVector3Array()
	for instance: MeshInstance3D in _meshes(node):
		var transform: Transform3D = rig.global_transform.affine_inverse()*instance.global_transform
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for point: Vector3 in vertices: result.append(transform*point)
			else:
				for index: int in indices: result.append(transform*vertices[index])
	return result
func _closest(p: Vector3,a: Vector3,b: Vector3,c: Vector3) -> Vector3:
	var ab := b-a; var ac := c-a; var ap := p-a
	var d1: float = ab.dot(ap); var d2: float = ac.dot(ap)
	if d1 <= 0 and d2 <= 0: return a
	var bp := p-b; var d3: float = ab.dot(bp); var d4: float = ac.dot(bp)
	if d3 >= 0 and d4 <= d3: return b
	var vc: float = d1*d4-d3*d2
	if vc <= 0 and d1 >= 0 and d3 <= 0: return a+ab*(d1/(d1-d3))
	var cp := p-c; var d5: float = ab.dot(cp); var d6: float = ac.dot(cp)
	if d6 >= 0 and d5 <= d6: return c
	var vb: float = d5*d2-d1*d6
	if vb <= 0 and d2 >= 0 and d6 <= 0: return a+ac*(d2/(d2-d6))
	var va: float = d3*d6-d5*d4
	if va <= 0 and d4-d3 >= 0 and d5-d6 >= 0: return b+(c-b)*((d4-d3)/((d4-d3)+(d5-d6)))
	var total: float = va+vb+vc
	return a if absf(total) < 0.0000000001 else a+ab*(vb/total)+ac*(vc/total)
func _distance(point: Vector3,triangles: PackedVector3Array) -> float:
	var result: float = INF
	for index: int in range(0,triangles.size()-2,3): result = minf(result,point.distance_to(_closest(point,triangles[index],triangles[index+1],triangles[index+2])))
	return result
func _finger(rig: Rig,digit: String,wrist_local: bool = false) -> Vector3:
	var path: String = LEFT+"/"+digit+("/tip/thumb_tip" if digit == "thumb" else "/middle/tip/tip_mesh")
	var mesh: MeshInstance3D = rig.get_node(path); var at: Vector3 = mesh.to_global(mesh.mesh.get_aabb().get_center())
	return (rig.get_node(LEFT) as Node3D).to_local(at) if wrist_local else rig.to_local(at)
func _sleeves(rig: Rig) -> Dictionary:
	var result: Dictionary = {}
	for side: String in ["left","right"]:
		for tail: String in ["upper_sleeve","forearm/sleeve","forearm/cuff"]:
			var path: String = side+"_arm/"+tail; var mesh: MeshInstance3D = rig.get_node(path)
			result[path] = [mesh.get_instance_id(),mesh.mesh,mesh.material_override,mesh.transform]
	return result
func _shown_foot(rig: Rig) -> String:
	for name: String in ["worn_shoe","footwear_crocs","footwear_walmart_sneak","footwear_vibrams"]:
		var node: Node3D = rig.get_node_or_null("kick_foot/"+name)
		if node != null and node.is_visible_in_tree(): return name
	return ""

func _catalog_and_owners(first: Rig,second: Rig) -> void:
	var catalog: Dictionary = Content.load_content().catalogs.equipment
	var tools: Array[String] = []; var coats: Array[String] = []; var shoes: Array[String] = []
	for id: String in catalog:
		match str(catalog[id].slot):
			"tool": tools.append(id)
			"coat": coats.append(id)
			"shoes": shoes.append(id)
	tools.sort(); coats.sort(); shoes.sort()
	var supported: Array[String] = []
	for id: StringName in Rig.supported_tools(): supported.append(str(id))
	supported.sort(); _check(supported == tools and tools == ["crowbar","propane_torch"],"exact independent two-tool source catalog")
	_check(coats == ["bathrobe","parka","trench","windbreaker"] and shoes == ["airpods","crocs","vibrams","walmart_sneak"],"exact source clothing slot coverage")
	var weapon_ids: Array[String] = []
	for id: StringName in Rig.supported_weapons(): weapon_ids.append(str(id))
	var expected: Array = Content.load_content().catalogs.weapons.keys(); expected.sort(); weapon_ids.sort()
	_check(weapon_ids == expected and not weapon_ids.has("crowbar") and not weapon_ids.has("propane_torch"),"tool presentation creates no weapon catalog/mechanics")
	var items: Dictionary = _items(first,"tool_id"); var other_items: Dictionary = _items(second,"tool_id")
	_check(items.size() == 2 and items.keys() == other_items.keys() and first.has_node("ToolPool") and first.has_node(LEFT+"/HeldTool") and first.has_node(LEFT+"/tool_grip_marker"),"stable separate tool pool/socket/marker and both cached identities")
	for id: String in tools:
		first.set_context({"tool":id}); second.set_context({"tool":id})
		_check(_tool(first) == id and _tool(second) == id,"selected tool is actually visible in left wrist "+id)
		if not items.has(id) or not other_items.has(id): continue
		var a: Array[MeshInstance3D] = _meshes(items[id]); var b: Array[MeshInstance3D] = _meshes(other_items[id]); var shared: bool = a.size() == b.size() and not a.is_empty()
		for index: int in range(mini(a.size(),b.size())): shared = shared and a[index].mesh == b[index].mesh and a[index].material_override == b[index].material_override
		_check(shared,"tool resources shared while instances remain independent "+id)
	for node: Node in _nodes(first):
		_check(not (node is CollisionObject3D or node is CollisionShape3D or node is Timer or node is Light3D or node is AudioStreamPlayer or node is AudioStreamPlayer3D) and not node.is_processing() and not node.is_physics_processing() and not node.is_processing_input(),"gear adds no collision/light/audio/input/automatic clock owner")
		if node is MeshInstance3D: _check(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"visible and pooled gear suppress world shadows")
	first.reset(); second.reset(); groups += 1

func _contexts(rig: Rig) -> void:
	rig.reset(); var original_sleeves: Dictionary = _sleeves(rig)
	_check(rig.tool.is_empty() and rig.coat.is_empty() and rig.shoes.is_empty() and _tool(rig).is_empty(),"default old API remains empty gear")
	var supplied := {"tool":"propane_torch","coat":"parka","shoes":"vibrams","weapon":"pipe"}
	_check(rig.set_context(supplied),"all exact canonical gear fields accepted together")
	supplied.tool = "crowbar"; supplied.coat = "bathrobe"; supplied.shoes = "crocs"
	_check(rig.tool == &"propane_torch" and rig.coat == &"parka" and rig.shoes == &"vibrams","caller dictionary is not retained")
	_check(rig.set_context({"weapon":"brick"}) and rig.tool == &"propane_torch" and rig.coat == &"parka" and rig.shoes == &"vibrams","omitted fields retain gear independently of weapon")
	for field: String in ["tool","coat","shoes"]:
		for bad: Variant in [true,1,NAN,INF,[],{},"unknown"]:
			var next := {"weapon":"knife","tool":"crowbar","coat":"trench","shoes":"crocs"}; next[field] = bad
			var before: Dictionary = _snapshot(rig); var resources: Dictionary = _resources(rig)
			_check(not rig.set_context(next) and _snapshot(rig) == before and _resources(rig) == resources,"malformed "+field+" rejects whole multi-field context atomically")
	for bad: Dictionary in [{"tool":"crowbar","weapon":"propane_torch"},{"coat":"bathrobe","walk_speed":INF},{"shoes":"crocs","cart_grips":{"left":Vector3.ZERO}}]:
		var before: Dictionary = _snapshot(rig)
		_check(not rig.set_context(bad) and _snapshot(rig) == before,"existing invalid context rejects pending gear changes atomically")
	for empty: Variant in [null,"",&""]:
		_check(rig.set_context({"tool":empty,"coat":empty,"shoes":empty}) and rig.tool.is_empty() and rig.coat.is_empty() and rig.shoes.is_empty() and _tool(rig).is_empty(),"null/empty values clear gear")
	_check(_sleeves(rig) == original_sleeves,"cleared coat restores original sleeve/cuff mesh material and transforms exactly")
	rig.set_context({"peteToolLocker":"propane_torch"})
	_check(rig.tool.is_empty() and _tool(rig).is_empty(),"locker ownership never becomes a carried tool")
	rig.set_context({"tool":&"crowbar","coat":&"windbreaker","shoes":&"airpods"}); rig.acknowledge(&"smoke",true,false); _advance(rig,0.1)
	var before: Dictionary = _snapshot(rig)
	for dt: float in [0.0,-1.0,NAN,INF]: rig.tick(dt,Vector3.ONE,true,true,true,100,Vector2.ONE)
	_check(_snapshot(rig) == before,"paused/invalid time cannot advance or restore gear gestures")
	rig.reset()
	_check(rig.tool.is_empty() and rig.coat.is_empty() and rig.shoes.is_empty() and rig.action.is_empty() and _sleeves(rig) == original_sleeves,"reset clears gear and exactly restores backward-compatible sleeves")
	groups += 1

func _grip_geometry(rig: Rig) -> void:
	rig.reset(); var relaxed: Dictionary = {}
	for finger: String in ["index","middle","ring","little"]: relaxed[finger] = _finger(rig,finger,true)
	var items: Dictionary = _items(rig,"tool_id")
	for id: StringName in Rig.supported_tools():
		rig.reset(); rig.set_context({"tool":id})
		if not items.has(str(id)): _check(false,"actual tool geometry missing "+str(id)); continue
		var triangles: PackedVector3Array = _triangles(rig,items[str(id)])
		var marker: Vector3 = rig.to_local((rig.get_node(LEFT+"/tool_grip_marker") as Node3D).global_position)
		_check(not triangles.is_empty() and _distance(marker,triangles) < 0.065,"tool marker reaches actual tool surface "+str(id))
		var touching: int = 0; var curled: int = 0
		for digit: String in ["index","middle","ring","little"]:
			if _distance(_finger(rig,digit),triangles) < 0.055: touching += 1
			if _finger(rig,digit,true).distance_to(relaxed[digit]) > 0.005: curled += 1
		_check(touching >= 2 and curled >= 2,"at least two actual fingers curl onto tool surface "+str(id)+" contacts="+str(touching))
		_check(_distance(_finger(rig,"thumb"),triangles) < 0.07,"actual thumb supports carried tool "+str(id))
		var center_clear: bool = true
		for index: int in range(0,triangles.size()-2,3):
			if Geometry3D.segment_intersects_triangle(Vector3(0,0,-0.06),Vector3(0,0,-1.5),triangles[index],triangles[index+1],triangles[index+2]) is Vector3: center_clear = false; break
		_check(center_clear and _safe(rig,true),"low carried tool preserves sightline and actual visible/parked geometry bounds "+str(id))
	groups += 1

func _actions(rig: Rig,other: Rig) -> void:
	var resources: Dictionary = _resources(rig); var contents: Dictionary = _contents(rig)
	other.reset(); var independent: Dictionary = _snapshot(other)
	for tool: StringName in Rig.supported_tools():
		for weapon: StringName in Rig.supported_weapons():
			for contact: bool in [false,true]:
				rig.reset(); rig.set_context({"tool":tool,"weapon":weapon,"walk_speed":5.5})
				var selected: String = _tool(rig); rig.acknowledge(&"punch",true,contact,weapon)
				_check(selected == str(tool) and rig.action == &"punch" and rig.attack_weapon == weapon and _weapon(rig) == str(weapon),"tool does not replace acknowledged original weapon "+str(tool)+"/"+str(weapon))
				_check(_tool(rig) == str(tool),"independent right-hand attack retains low offhand tool")
				var safe: bool = _safe(rig)
				for index: int in range(48):
					rig.tick(1.0/120.0,Vector3(5.5,0,-16.83),true,true,true,100,Vector2(0.3,-0.3)); safe = safe and _safe(rig)
				_check(safe and rig.action.is_empty(),"tool plus weapon contact/miss stressed phases remain finite and clear near plane "+str(tool)+"/"+str(weapon))
		var replacement: StringName = &"crowbar" if tool == &"propane_torch" else &"propane_torch"
		rig.reset(); rig.set_context({"tool":tool}); rig.acknowledge(&"punch",true,false,&"fists"); _advance(rig,0.3)
		rig.acknowledge(&"punch",true,true,&"fists")
		_check(rig.last_punch_side == -1 and _tool(rig).is_empty(),"left fist immediately stows its carried tool")
		rig.set_context({"tool":replacement,"weapon":"broken_bottle"})
		_check(_tool(rig).is_empty() and rig.attack_weapon == &"fists" and _weapon(rig) == "fists","tool/equipment replacement cannot alter original left-fist attack")
		_advance(rig,0.3)
		_check(_tool(rig) == str(replacement) and _weapon(rig) == "broken_bottle","recovery restores current tool and current weapon without a queue")
		for action: StringName in [&"receipt",&"smoke",&"bench",&"dumpster"]:
			rig.reset(); rig.set_context({"tool":tool,"weapon":"pipe"}); var before: Dictionary = _snapshot(rig)
			rig.acknowledge(action,false,false); _check(_snapshot(rig) == before,"failed outcome does not stow tool "+str(action))
			rig.acknowledge(action,true,false); _check(rig.action == action and _tool(rig).is_empty(),"accepted gesture stows tool "+str(action))
			var safe: bool = true
			for index: int in range(18): rig.tick(1.0/120.0,Vector3.ZERO,false); safe = safe and _safe(rig)
			_check(safe,"gesture geometry remains safe with stowed tool "+str(action))
			rig.set_context({"tool":replacement}); _advance(rig,0.6)
			_check(rig.action.is_empty() and _tool(rig) == str(replacement),"gesture recovery restores current context "+str(action))
		for action: StringName in [&"phone",&"eat"]:
			rig.reset(); rig.set_context({"tool":tool,"weapon":"pipe"}); rig.acknowledge(action,true,false); _advance(rig,0.12)
			_check(_tool(rig) == str(tool) and _safe(rig),"independent right-hand gesture preserves actual offhand tool "+str(action))
			rig.acknowledge(&"punch",true,false,&"knife")
			_check(rig.action == &"punch" and rig.action_phase == 0.0 and rig.attack_weapon == &"knife","equipment gesture never delays new accepted combat")
		var grips := {"left":Vector3(-0.25,-0.30,-0.76),"right":Vector3(0.25,-0.30,-0.76)}
		rig.reset(); rig.set_context({"tool":tool,"weapon":"pipe","cart_grips":grips})
		_check(_tool(rig).is_empty() and _safe(rig),"active cart left grip stows carried tool")
		rig.acknowledge(&"punch",true,true,&"pipe")
		_check(_tool(rig).is_empty(),"right cart attack does not put a tool through the still-gripping left hand")
		rig.set_context({"cart_grips":{},"tool":replacement}); _advance(rig,0.4)
		_check(_tool(rig) == str(replacement),"released cart grip restores latest tool")
	_check(_resources(rig) == resources and _contents(rig) == contents,"all tool poses/transitions preserve original cached mesh/material resources")
	_check(_snapshot(other) == independent,"gear actions cannot cross instance pose state")
	groups += 1

func _clothing(rig: Rig,other: Rig) -> void:
	rig.reset(); other.reset(); var original: Dictionary = _sleeves(rig); var states: Dictionary = {}
	for coat: String in ["trench","windbreaker","bathrobe","parka"]:
		_check(rig.set_context({"coat":coat}) and other.set_context({"coat":coat}),"canonical coat accepted "+coat)
		var selected: Dictionary = _sleeves(rig); var second: Dictionary = _sleeves(other)
		var changed: bool = false; var shared: bool = true
		for path: String in original:
			_check(selected[path][0] == original[path][0] and selected[path][1] == original[path][1],"coat keeps original sleeve node and mesh "+coat+"/"+path)
			changed = changed or selected[path][2] != original[path][2] or selected[path][3] != original[path][3]
			shared = shared and selected[path][1] == second[path][1] and selected[path][2] == second[path][2]
		_check(changed and shared,"coat changes readable garment while sharing immutable resources "+coat)
		states[coat] = selected; var resources: Dictionary = _resources(rig); var contents: Dictionary = _contents(rig); var other_before: Dictionary = _snapshot(other)
		for action: StringName in [&"bench",&"punch",&"dumpster"]:
			rig.acknowledge(action,true,false,&"pipe" if action == &"punch" else &""); var safe: bool = true
			for index: int in range(48): rig.tick(1.0/120.0,Vector3(5.5,0,-16.83),true,true,true,100,Vector2(0.3,-0.3)); safe = safe and _safe(rig)
			_check(safe,"coat fullness stays behind near plane through movement/action "+coat+"/"+str(action))
		_check(_resources(rig) == resources and _contents(rig) == contents and _snapshot(other) == other_before,"coat animation creates/mutates no resource or other instance "+coat)
	for coat: String in states:
		rig.set_context({"coat":coat}); _check(_sleeves(rig) == states[coat],"reselect coat returns same cached garment state "+coat)
	rig.set_context({"coat":null}); _check(_sleeves(rig) == original,"none restores original mold sleeves/cuffs exactly")
	groups += 1

func _footwear(rig: Rig) -> void:
	rig.reset(); rig.set_context({"weapon":"shoe"}); var weapon_items: Dictionary = _items(rig,"weapon_id")
	var tony_shoe: Node = weapon_items.get("shoe"); _check(tony_shoe != null,"separate Tony weapon shoe exists")
	var weapon_resources: Dictionary = _resources(tony_shoe) if tony_shoe != null else {}
	var weapon_contents: Dictionary = _contents(tony_shoe) if tony_shoe != null else {}
	var feet: Dictionary = {}
	for id: String in ["crocs","walmart_sneak","vibrams"]:
		var node: Node3D = rig.get_node_or_null("kick_foot/footwear_"+id)
		_check(node != null and str(node.get_meta("footwear_id","")) == id,"cached footwear identity exists "+id)
		if node != null: feet[id] = _resources(node)
	for id: String in ["","airpods","crocs","walmart_sneak","vibrams",""]:
		rig.set_context({"shoes":id}); rig.acknowledge(&"kick",true,false); _advance(rig,0.10)
		var expected: String = "worn_shoe" if id in ["","airpods"] else "footwear_"+id
		_check(_shown_foot(rig) == expected,"kick shows source-correct footwear "+id)
		var shown: int = 0
		for name: String in ["worn_shoe","footwear_crocs","footwear_walmart_sneak","footwear_vibrams"]:
			var node: Node3D = rig.get_node_or_null("kick_foot/"+name)
			if node != null and node.is_visible_in_tree(): shown += 1
		_check(shown == 1 and _safe(rig),"exactly one finite foot silhouette during kick")
		_check(rig.weapon == &"shoe" and _weapon(rig) == "fists" and (tony_shoe == null or (_resources(tony_shoe) == weapon_resources and _contents(tony_shoe) == weapon_contents)),"worn footwear never changes Tony's independent weapon while kick temporarily stows it")
		_advance(rig,0.3); _check(_shown_foot(rig).is_empty() and _weapon(rig) == "shoe","kick recovery parks footwear and restores the separate weapon shoe")
	for id: String in feet: _check(_resources(rig.get_node("kick_foot/footwear_"+id)) == feet[id],"footwear selection reuses constructed resources "+id)
	rig.reset(); _check(rig.shoes.is_empty() and _shown_foot(rig).is_empty(),"reset clears footwear context without an active kick")
	groups += 1

func _run() -> void:
	var first: Rig = Rig.create() as Rig; var second: Rig = Rig.create() as Rig; root.add_child(first); root.add_child(second)
	_catalog_and_owners(first,second); _contexts(first); _grip_geometry(first); _actions(first,second); _clothing(first,second); _footwear(first)
	_check(groups == 6,"all gear catalog/context/grip/action/clothing/footwear groups completed")
	first.free(); second.free(); await process_frame
	if failures.is_empty(): print("3D VIEWMODEL GEAR GATE: PASS (%d checks;2tools/4coats/4shoe slots/9independent weapons)"%checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D VIEWMODEL GEAR GATE: FAIL (%d failures/%d checks)"%[failures.size(),checks]); quit(1)
