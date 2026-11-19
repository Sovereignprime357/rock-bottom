extends SceneTree
## Independent extension gate; the existing41 P01 checks remain unchanged.
const Rig = preload("res://scripts/first_person_rig.gd")
const Content = preload("res://scripts/content_catalog.gd")
const WRIST := "right_arm/forearm/wrist"
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []
var _vertices: Dictionary = {}

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
func _weapons(rig: Rig) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in _nodes(rig):
		if node.has_meta("weapon_id"):
			var id: StringName = StringName(node.get_meta("weapon_id"))
			_check(not result.has(id),"cached weapon identity is unique "+str(id))
			result[id] = node
	return result
func _mounted(rig: Rig) -> StringName:
	var socket: Node = rig.get_node_or_null(WRIST+"/HeldWeapon")
	if socket == null: return &"missing_socket"
	var result: StringName = &"fists"
	for node: Node in socket.get_children():
		if node.has_meta("weapon_id") and node is Node3D and node.is_visible_in_tree(): result = StringName(node.get_meta("weapon_id"))
	return result
func _snapshot(rig: Rig) -> Dictionary:
	var poses: Dictionary = {}
	for node: Node in _nodes(rig):
		if node is Node3D: poses[node.get_instance_id()] = [node.transform,node.visible,node.get_parent().get_instance_id() if node.get_parent() != null else 0]
	return {"weapon":rig.weapon,"attack_weapon":rig.attack_weapon,"action":rig.action,"phase":rig.action_phase,"poses":poses}
func _resources(rig: Rig) -> Dictionary:
	var result: Dictionary = {}
	for mesh: MeshInstance3D in _meshes(rig): result[mesh.get_instance_id()] = [mesh.mesh,mesh.material_override]
	return result
func _resource_contents(rig: Rig) -> Dictionary:
	var result: Dictionary = {}
	for instance: MeshInstance3D in _meshes(rig):
		var mesh: Mesh = instance.mesh
		if not result.has(mesh.get_rid()):
			var surfaces: Array = []
			for surface: int in range(mesh.get_surface_count()): surfaces.append(hash(mesh.surface_get_arrays(surface)))
			result[mesh.get_rid()] = surfaces
		var material: StandardMaterial3D = instance.material_override as StandardMaterial3D
		if material != null: result[material.get_rid()] = [material.albedo_color,material.roughness,material.cull_mode,material.shading_mode,material.transparency,material.vertex_color_use_as_albedo]
	return result
func _advance(rig: Rig,seconds: float,velocity: Vector3 = Vector3.ZERO,sprinting: bool = false,stress: bool = false) -> void:
	var elapsed: float = 0
	while elapsed < seconds-0.000001:
		var dt: float = minf(1.0/120.0,seconds-elapsed)
		rig.tick(dt,velocity,sprinting,stress,stress,100.0 if stress else 0.0,Vector2(0.3,-0.3) if stress else Vector2.ZERO)
		elapsed += dt
func _local_vertices(mesh: Mesh) -> PackedVector3Array:
	var key: RID = mesh.get_rid()
	if not _vertices.has(key):
		var vertices := PackedVector3Array()
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
		_vertices[key] = vertices
	return _vertices[key]
func _safe(rig: Rig) -> bool:
	var inverse: Transform3D = rig.global_transform.affine_inverse()
	for mesh: MeshInstance3D in _meshes(rig):
		if mesh.mesh == null or not mesh.global_transform.is_finite(): return false
		var transform: Transform3D = inverse*mesh.global_transform
		for vertex: Vector3 in _local_vertices(mesh.mesh):
			var point: Vector3 = transform*vertex
			if not point.is_finite() or point.z >= -0.06 or point.z < -1.5 or absf(point.x) > 1.0 or absf(point.y) > 1.2: return false
	return true
func _triangles(rig: Rig,node: Node) -> PackedVector3Array:
	var result := PackedVector3Array()
	for mesh: MeshInstance3D in _meshes(node):
		var transform: Transform3D = rig.global_transform.affine_inverse()*mesh.global_transform
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for vertex: Vector3 in vertices: result.append(transform*vertex)
			else:
				for index: int in indices: result.append(transform*vertices[index])
	return result
func _closest_triangle(p: Vector3,a: Vector3,b: Vector3,c: Vector3) -> Vector3:
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
	var sum: float = va+vb+vc
	if absf(sum) < 0.0000000001: return a
	return a+ab*(vb/sum)+ac*(vc/sum)
func _surface_distance(point: Vector3,triangles: PackedVector3Array) -> float:
	var nearest: float = INF
	for index: int in range(0,triangles.size()-2,3): nearest = minf(nearest,point.distance_to(_closest_triangle(point,triangles[index],triangles[index+1],triangles[index+2])))
	return nearest
func _digit_center(rig: Rig,finger: String,in_wrist: bool = false) -> Vector3:
	var path: String = WRIST+"/"+finger+("/tip/thumb_tip" if finger == "thumb" else "/middle/tip/tip_mesh")
	var mesh: MeshInstance3D = rig.get_node(path) as MeshInstance3D
	var point: Vector3 = mesh.global_transform*mesh.mesh.get_aabb().get_center()
	return (rig.get_node(WRIST) as Node3D).to_local(point) if in_wrist else rig.to_local(point)
func _knuckle(rig: Rig) -> Vector3: return rig.to_local((rig.get_node(WRIST+"/knuckle_marker") as Node3D).global_position)
func _visible_fraction(rig: Rig,mesh: MeshInstance3D) -> float:
	var shown: int = 0
	var vertices: PackedVector3Array = _local_vertices(mesh.mesh)
	var transform: Transform3D = rig.global_transform.affine_inverse()*mesh.global_transform
	var vertical: float = tan(deg_to_rad(78.0)*0.5)
	for vertex: Vector3 in vertices:
		var point: Vector3 = transform*vertex
		if point.z < -0.06 and absf(point.y) < -point.z*vertical and absf(point.x) < -point.z*vertical*1280.0/720.0: shown += 1
	return float(shown)/float(maxi(1,vertices.size()))

func _catalog_and_cache(first: Rig,second: Rig) -> void:
	var expected: Array = Content.load_content().catalogs.weapons.keys(); expected.sort()
	var supported: Array = []
	for id: StringName in Rig.supported_weapons(): supported.append(str(id))
	supported.sort(); _check(supported == expected and supported.size() == 9,"exact canonical weapon catalog without aliases or fallback")
	var first_items: Dictionary = _weapons(first); var second_items: Dictionary = _weapons(second)
	_check(first_items.size() == expected.size()-1 and first_items.keys() == second_items.keys(),"each nonfist weapon is authored and cached in both independent rigs")
	_check(first.has_node("WeaponPool") and first.has_node(WRIST+"/HeldWeapon") and first.has_node(WRIST+"/held_grip_marker"),"fixed pool socket and wrist grip marker are exposed")
	var resources: Dictionary = _resources(first); var second_before: Dictionary = _snapshot(second)
	var a: Array[MeshInstance3D] = _meshes(first); var b: Array[MeshInstance3D] = _meshes(second)
	var shared: bool = a.size() == b.size() and not a.is_empty()
	for index: int in range(mini(a.size(),b.size())): shared = shared and is_same(a[index].mesh,b[index].mesh) and is_same(a[index].material_override,b[index].material_override)
	_check(shared,"all hand and weapon Mesh/Material resources are shared between instances")
	for node: Node in _nodes(first):
		_check(not (node is CollisionObject3D or node is Timer or node is AudioStreamPlayer or node is AudioStreamPlayer3D) and not node.is_processing() and not node.is_physics_processing(),"presentation node owns no gameplay physics audio timer or automatic clock")
		if node is MeshInstance3D: _check(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"all visible and parked props suppress world shadows")
	for id: String in expected:
		_check(first.set_context({"weapon":id}),"canonical weapon context accepted "+id)
		_check(_mounted(first) == StringName(id),"selected canonical silhouette mounts at right wrist "+id)
		for other: StringName in first_items:
			_check(first_items[other] == _weapons(first).get(other),"weapon switch retains original cached item instance")
		_advance(first,0.04,Vector3(0,0,-5.5))
	_check(_resources(first) == resources and _snapshot(second) == second_before,"switches and gait allocate no meshes and never cross instance pose state")
	first.reset(); groups += 1

func _contexts(first: Rig) -> void:
	first.reset(); _check(first.weapon == &"fists" and first.visible and _mounted(first) == &"fists","unchanged default API starts with visible empty fists")
	var caller: Dictionary = {"weapon":"pipe","walk_speed":5.5,"seated":false,"visible":true,"source_cash":17}
	_check(first.set_context(caller),"context accepts canonical known fields and ignores unrelated snapshot state")
	caller.weapon = "brick"; caller.seated = true
	_check(first.weapon == &"pipe","caller snapshot is copied rather than retained")
	var invalid: Array = [{"weapon":"unknown"},{"weapon":1},{"weapon":null},{"weapon":"brick","seated":"yes"},{"weapon":"brick","visible":1},{"weapon":"brick","walk_speed":NAN},{"weapon":"brick","walk_speed":INF},{"weapon":"brick","walk_speed":0.99},{"weapon":"brick","walk_speed":10.01}]
	for bad: Dictionary in invalid:
		var before: Dictionary = _snapshot(first)
		_check(not first.set_context(bad) and _snapshot(first) == before,"malformed known context rejects atomically "+str(bad))
	_check(first.set_context({"walk_speed":1.0}) and first.set_context({"walk_speed":10.0}) and first.set_context({"walk_speed":5.5}),"finite normalization endpoints and full-game walk speed are accepted")
	var standing: Vector3 = _knuckle(first)
	_check(first.set_context({"seated":true}) and first.weapon == &"pipe","partial seated context retains selected weapon")
	_check(_knuckle(first).distance_to(standing) > 0.006,"seated context changes actual supported hand posture")
	first.acknowledge(&"phone",true,false); _advance(first,0.08)
	var phase: float = first.action_phase
	_check(first.set_context({"visible":false}) and not first.visible and first.action_phase == phase,"menu visibility hides rig without advancing the gesture clock")
	await process_frame; await physics_frame
	_check(first.action_phase == phase,"wall time cannot advance hidden presentation")
	first.reset()
	_check(first.weapon == &"fists" and first.visible and first.action.is_empty() and _mounted(first) == &"fists","reset clears contextual state and restores backward-compatible default")
	groups += 1

func _grips(first: Rig) -> void:
	first.reset(); var relaxed: Dictionary = {}
	for finger: String in ["index","middle","ring","little"]: relaxed[finger] = _digit_center(first,finger,true)
	var items: Dictionary = _weapons(first)
	for id: StringName in Rig.supported_weapons():
		if id == &"fists": continue
		first.reset(); first.set_context({"weapon":id})
		if not items.has(id): _check(false,"missing grip geometry "+str(id)); continue
		var triangles: PackedVector3Array = _triangles(first,items[id])
		var marker: Vector3 = first.to_local((first.get_node(WRIST+"/held_grip_marker") as Node3D).global_position)
		_check(not triangles.is_empty() and _surface_distance(marker,triangles) < 0.065,"grip marker lies at actual held geometry "+str(id))
		var touching: int = 0; var curled: int = 0
		for finger: String in ["index","middle","ring","little"]:
			if _surface_distance(_digit_center(first,finger),triangles) < 0.055: touching += 1
			if _digit_center(first,finger,true).distance_to(relaxed[finger]) > 0.005: curled += 1
		_check(touching >= 2 and curled >= 2,"actual fingers curl onto weapon surface rather than hovering "+str(id)+" contacts="+str(touching))
		_check(_surface_distance(_digit_center(first,"thumb"),triangles) < 0.07,"actual thumb supports held item "+str(id))
		var center_clear: bool = true
		for index: int in range(0,triangles.size()-2,3):
			if Geometry3D.segment_intersects_triangle(Vector3(0,0,-0.06),Vector3(0,0,-1.5),triangles[index],triangles[index+1],triangles[index+2]) is Vector3: center_clear = false; break
		_check(center_clear,"resting held silhouette leaves exact center sightline clear "+str(id))
	groups += 1

func _attacks_and_geometry(first: Rig,second: Rig) -> void:
	var catalog: Dictionary = Content.load_content().catalogs.weapons
	var resources: Dictionary = _resources(first)
	var contents: Dictionary = _resource_contents(first)
	for id: StringName in Rig.supported_weapons():
		for contact: bool in [false,true]:
			first.reset(); first.set_context({"weapon":id,"walk_speed":5.5})
			var rest: Vector3 = _knuckle(first)
			first.acknowledge(&"punch",true,contact,id)
			_check(first.action == &"punch" and first.attack_weapon == id and _knuckle(first).distance_to(rest) > 0.008,"accepted attack presents immediately "+str(id))
			var safe: bool = _safe(first)
			for frame: int in range(48):
				first.tick(1.0/120.0,Vector3(7.0,0,-16.83),true,true,true,100.0,Vector2(0.3,-0.3))
				safe = safe and _safe(first)
			_check(safe,"all visible and parked actual vertices clear eye plane/bounds through stressed phases "+str(id)+" contact="+str(contact))
			_check(first.action.is_empty(),"armed recovery has no queued action "+str(id))
		first.reset(); first.set_context({"weapon":id}); first.acknowledge(&"punch",true,false,id)
		_advance(first,float(catalog[str(id)].cd)/1000.0-0.001)
		_check(first.action.is_empty(),"visual recovery finishes before source attack cadence "+str(id))
	first.reset(); first.acknowledge(&"punch",true,false,&"fists"); _advance(first,0.03)
	first.set_context({"weapon":&"broken_bottle"})
	_check(first.weapon == &"broken_bottle" and first.attack_weapon == &"fists" and _mounted(first) == &"fists","bottle receipt cannot retroactively arm the original fist swing")
	_advance(first,0.3); _check(_mounted(first) == &"broken_bottle","new weapon appears when original swing recovers")
	first.reset(); first.set_context({"weapon":&"brick"}); first.acknowledge(&"punch",true,true,&"pipe")
	_check(first.attack_weapon == &"pipe" and _mounted(first) == &"pipe","explicit accepted weapon owns attack despite newer selected equipment")
	var before: Dictionary = _snapshot(first)
	first.acknowledge(&"punch",true,false,&"unknown")
	_check(_snapshot(first) == before,"invalid explicit accepted weapon refuses only visual acknowledgement")
	first.acknowledge(&"phone",true,false)
	_check(_snapshot(first) == before,"context gesture cannot displace accepted attack")
	first.acknowledge(&"punch",true,false,&"knife")
	_check(first.action == &"punch" and first.action_phase == 0.0 and first.attack_weapon == &"knife","new authoritative attack replaces cosmetic recovery immediately")
	first.reset(); second.reset(); first.set_context({"weapon":"pipe"}); second.set_context({"weapon":"pipe"})
	first.acknowledge(&"punch",true,true); second.acknowledge(&"punch",true,false)
	_advance(first,0.05); _advance(second,0.05)
	_check(_knuckle(first).distance_to(_knuckle(second)) > 0.005,"contact and miss have distinct physical hand recovery poses")
	_check(_resources(first) == resources,"all phase transitions preserve constructed resource identities")
	_check(_resource_contents(first) == contents,"pose animation never edits shared mesh arrays or material state")
	groups += 1

func _gestures(first: Rig) -> void:
	for kind: StringName in [&"phone",&"bench",&"dumpster",&"kick"]:
		first.reset(); first.set_context({"weapon":"pipe","walk_speed":5.5})
		var before: Dictionary = _snapshot(first)
		first.acknowledge(kind,false,false)
		_check(_snapshot(first) == before,"failed contextual outcome is visual no-op "+str(kind))
		first.acknowledge(kind,true,false); _advance(first,0.12)
		_check(first.action == kind and _snapshot(first).poses != before.poses and _safe(first),"accepted contextual outcome changes bounded real pose "+str(kind))
		if kind == &"kick":
			_check(_visible_fraction(first,first.get_node("kick_foot/worn_shoe/shoe_form/worn_leather")) > 0.33,"actual active shoe occupies the native78-degree view rather than a clipped toe sliver")
			_check(_visible_fraction(first,first.get_node("kick_foot/trouser_cuff")) > 0.33,"active kick shows its connected trouser cuff")
		first.acknowledge(&"punch",true,false,&"pipe")
		_check(first.action == &"punch" and first.action_phase == 0.0,"context gesture never delays the next accepted hit "+str(kind))
		_advance(first,0.6)
		_check(first.action.is_empty() and _mounted(first) == &"pipe","gesture/hit sequence returns current item without backlog "+str(kind))
	first.reset()
	for index: int in range(80): first.acknowledge(&"phone" if index%2 == 0 else &"dumpster",true,false)
	_advance(first,1.0); _check(first.action.is_empty(),"repeated contextual receipts coalesce without action queue")
	groups += 1

func _skin_points(rig: Rig,side: String) -> PackedVector3Array:
	var result := PackedVector3Array()
	var wrist: Node3D = rig.get_node(side+"_arm/forearm/wrist")
	for part: String in ["palm","index","middle","ring","little","thumb"]:
		for mesh: MeshInstance3D in _meshes(wrist.get_node(part)):
			var transform: Transform3D = rig.global_transform.affine_inverse()*mesh.global_transform
			for point: Vector3 in _local_vertices(mesh.mesh): result.append(transform*point)
	return result

func _skin_delta(a: PackedVector3Array,b: PackedVector3Array) -> float:
	if a.size() != b.size(): return INF
	var result: float = 0.0
	for index: int in range(a.size()): result = maxf(result,a[index].distance_to(b[index]))
	return result

func _relaxed_hands(first: Rig,second: Rig) -> void:
	first.reset(); second.reset()
	var original_resources: Dictionary = _resources(first)
	var original_contents: Dictionary = _resource_contents(first)
	var left: Node3D = first.get_node("left_arm/forearm/wrist")
	var right: Node3D = first.get_node(WRIST)
	var reflected_normal: Vector3 = left.global_basis.y
	reflected_normal.x = -reflected_normal.x
	_check(reflected_normal.angle_to(right.global_basis.y) > 0.04,"empty palms have actual asymmetric orientation rather than a mirrored flat pose")
	_check(left.global_position.y < right.global_position.y-0.008,"empty left wrist rests lower than the dominant wrist")
	for side: String in ["left","right"]:
		var wrist: Node3D = first.get_node(side+"_arm/forearm/wrist")
		var flexions: Array[float] = []
		for finger: String in ["index","middle","ring","little"]:
			var tip: Node3D = wrist.get_node(finger+"/middle/tip")
			flexions.append((-wrist.global_basis.z).angle_to(-tip.global_basis.z))
		_check(flexions[3] > flexions[0]+0.30 and flexions[0] > 0.35 and flexions[3] < 1.9,"actual digit directions form a relaxed open cascade "+side)
		var points: PackedVector3Array = _skin_points(first,side)
		var low: bool = true
		for point: Vector3 in points: low = low and point.y < -0.25 and point.z < -0.06
		_check(low,"all resting skin remains below the central view and clear of the near plane "+side)
	# Match both actual native/browser review sizes using authored skin vertices.
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		for crash: bool in [false,true]:
			first.reset(); first.tick(0.1,Vector3.ZERO,false,false,crash)
			for side: String in ["left","right"]:
				var shown: int = 0
				var points: PackedVector3Array = _skin_points(first,side)
				for point: Vector3 in points:
					var half_height: float = -point.z*tan(deg_to_rad(78.0)*0.5)
					if absf(point.y) < half_height and absf(point.x) < half_height*float(size.x)/float(size.y): shown += 1
				_check(float(shown)/float(maxi(1,points.size())) > 0.18,"substantial relaxed skin remains visible at "+str(size)+" crash="+str(crash)+" "+side)
	for velocity: Vector3 in [Vector3.ZERO,Vector3(0,0,-5.5),Vector3(0,0,-16.83)]:
		first.reset(); first.set_context({"walk_speed":5.5})
		_advance(first,0.6,velocity,velocity.length() > 6.0,true)
		_check(_safe(first),"empty relaxed anatomy remains finite and near-plane safe through gait/sprint/look/crash "+str(velocity))
		_advance(first,1.0)
		_check(_safe(first),"gait settles safely back into empty stance")
	# No acknowledgement/end pop: compare the same clock on two real rigs, and
	# prove that the measured geometric boundary error shrinks with epsilon.
	for kind: StringName in [&"interact",&"pickup",&"receipt",&"eat",&"smoke",&"equip",&"phone",&"bench",&"dumpster",&"kick"]:
		first.reset(); second.reset()
		var before_left: PackedVector3Array = _skin_points(first,"left")
		var before_right: PackedVector3Array = _skin_points(first,"right")
		first.acknowledge(kind,true,false)
		_check(_skin_delta(before_left,_skin_points(first,"left")) < 0.000001 and _skin_delta(before_right,_skin_points(first,"right")) < 0.000001,"empty gesture begins from the actual resting skin without a pose jump "+str(kind))
		var errors: Array[float] = []
		for epsilon: float in [0.001,0.00001]:
			first.reset(); second.reset(); first.acknowledge(kind,true,false)
			var age: float = float(Rig.ACTION_LENGTHS[kind])-epsilon
			_advance(first,age); _advance(second,age)
			errors.append(maxf(_skin_delta(_skin_points(first,"left"),_skin_points(second,"left")),_skin_delta(_skin_points(first,"right"),_skin_points(second,"right"))))
		_check(errors[1] < 0.0001 and (errors[1] < errors[0]*0.05 or errors[0] < 0.000001),"actual recovery approaches the same-clock rest continuously "+str(kind))
		first.tick(0.001,Vector3.ZERO,false); second.tick(0.001,Vector3.ZERO,false)
		_check(first.action.is_empty() and _skin_delta(_skin_points(first,"left"),_skin_points(second,"left")) < 0.000001 and _skin_delta(_skin_points(first,"right"),_skin_points(second,"right")) < 0.000001,"action expiry returns both hands exactly to current empty stance "+str(kind))
	# Original hard thresholds caused a finite finger jump even at vanishing dt.
	for kind: StringName in [&"pickup",&"dumpster"]:
		first.reset(); first.acknowledge(kind,true,false)
		var age: float = float(Rig.ACTION_LENGTHS[kind])*(0.35 if kind == &"pickup" else 0.5)
		_advance(first,age-0.00001)
		var before: PackedVector3Array = _skin_points(first,"right")
		first.tick(0.00002,Vector3.ZERO,false)
		_check(_skin_delta(before,_skin_points(first,"right")) < 0.0001,"open-to-close gesture has no finger discontinuity "+str(kind))
	_check(_resources(first) == original_resources and _resource_contents(first) == original_contents,"empty relaxation and transitions preserve all authored immutable resources")
	first.reset(); second.reset(); groups += 1

func _occupied_pose_preservation(first: Rig) -> void:
	# Captured pre-polish rest contract, independent of the new relaxation helper.
	for id: StringName in Rig.supported_weapons():
		if id == &"fists": continue
		first.reset(); first.set_context({"weapon":id})
		var arm: Node3D = first.get_node("right_arm")
		var wrist: Node3D = first.get_node(WRIST)
		_check(arm.position.is_equal_approx(Vector3(0.305,-0.410+sin(0.24)*0.002,-0.515)) and arm.rotation.is_equal_approx(Vector3(0.10,-0.08,-0.06)) and wrist.rotation.is_equal_approx(Vector3(0.15,-0.35,-0.055)),"occupied weapon arm/wrist retains its original rest anchors "+str(id))
		_check(_original_finger_pose(wrist,1,float(Rig.WEAPONS[id].grip)),"occupied weapon finger endpoints remain unchanged "+str(id))
	for id: StringName in Rig.supported_tools():
		first.reset(); first.set_context({"tool":id})
		var arm: Node3D = first.get_node("left_arm")
		var wrist: Node3D = first.get_node("left_arm/forearm/wrist")
		_check(arm.position.is_equal_approx(Vector3(-0.295,-0.370+sin(-0.24)*0.002,-0.530)) and arm.rotation.is_equal_approx(Vector3(0.10,0.08,0.06)) and wrist.rotation.is_equal_approx(Vector3(0.15,0.18,-1.045)),"occupied tool arm/wrist retains its original rest anchors "+str(id))
		_check(_original_finger_pose(wrist,-1,0.83),"occupied tool finger endpoints remain unchanged "+str(id))
	var grips: Dictionary = {"left":Vector3(-0.25,-0.34,-0.66),"right":Vector3(0.25,-0.34,-0.66)}
	first.reset(); first.set_context({"cart_grips":grips})
	for side: String in ["left","right"]:
		var wrist: Node3D = first.get_node(side+"_arm/forearm/wrist")
		var marker: Vector3 = first.to_local(wrist.to_global(Vector3(0,-0.036,-0.082)))
		# The dedicated cart wrap supersedes only the generic .83 tool-curl pin.
		# Real opposed skin/shaft contact is checked in test_hand_art_refinement.
		_check(marker.distance_to(grips[side]) < 0.000001,"cart grip correction retains its exact original target "+side)
	first.reset(); first.acknowledge(&"punch",true,false,&"fists"); _advance(first,0.045)
	var wrist: Node3D = first.get_node(WRIST)
	_check(wrist.rotation.is_equal_approx(Vector3(0.78,0,-0.055)) and _original_finger_pose(wrist,1,1.0),"full-extension fist keeps its accepted wrist/finger contact pose")
	first.reset(); groups += 1

func _original_finger_pose(wrist: Node3D,side: int,curl: float) -> bool:
	var fingers: Array[String] = ["index","middle","ring","little"]
	for index: int in range(fingers.size()):
		var base: Node3D = wrist.get_node(fingers[index])
		var middle: Node3D = base.get_node("middle")
		var tip: Node3D = middle.get_node("tip")
		if not base.rotation.is_equal_approx(Vector3(-lerpf(0.10+float(index)*0.035,1.10,curl),float(side)*float(index-1)*0.045*(1.0-curl),0)): return false
		if not is_equal_approx(middle.rotation.x,-lerpf(0.24+float(index)*0.025,1.35,curl)) or not is_equal_approx(tip.rotation.x,-lerpf(0.12,0.72,curl)): return false
	var thumb: Node3D = wrist.get_node("thumb")
	return thumb.rotation.is_equal_approx(Vector3(-lerpf(0.13,0.55,curl),float(side)*lerpf(0.58,-0.95,curl),float(side)*lerpf(0.10,0.20,curl))) and is_equal_approx((thumb.get_node("tip") as Node3D).rotation.x,-lerpf(0.20,0.90,curl))

func _run() -> void:
	var first: Rig = Rig.create() as Rig; var second: Rig = Rig.create() as Rig; root.add_child(first); root.add_child(second)
	_catalog_and_cache(first,second)
	await _contexts(first)
	_grips(first)
	_attacks_and_geometry(first,second)
	_gestures(first)
	_relaxed_hands(first,second)
	_occupied_pose_preservation(first)
	_check(groups == 7,"all context/cache/grip/phase/gesture/empty-stance/preservation groups complete")
	first.free(); second.free()
	if failures.is_empty(): print("3D VIEWMODEL CONTEXT GATE: PASS (%d checks;9canonical weapons, original grip geometry, immutable accepted weapon, camera bounds, contexts/caches)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D VIEWMODEL CONTEXT GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks]); quit(1)
