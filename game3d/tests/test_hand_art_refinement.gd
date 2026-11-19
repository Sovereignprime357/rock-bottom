extends SceneTree
## Isolated candidate gate. Root stages the frozen baseline and runs the engine.
const Rig = preload("res://scripts/first_person_rig.gd")
const Baseline = preload("res://tests/fixtures/hand_art_baseline_rig.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const PAD_GAP := 0.008
const SKIN_PENETRATION := 0.0025 # 2.5mm skin tolerance; not a loose handle AABB.
const DIGITS: Array[String] = ["index","middle","ring","little"]
var checks := 0
var groups := 0
var failures: Array[String] = []
var vertex_cache: Dictionary = {}
var triangle_cache: Dictionary = {}
var printed_mismatches := 0

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child: Node in node.get_children(): result.append_array(_nodes(child))
	return result
func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in _nodes(node):
		if child is MeshInstance3D: result.append(child)
	return result
func _is_generated_name(node: Node) -> bool:
	var prefix := "@"+node.get_class()+"@"
	var text_name := String(node.name)
	if not text_name.begins_with(prefix): return false
	var suffix: String = text_name.trim_prefix(prefix)
	return suffix.is_valid_int() and int(suffix) > 0
func _node_key(rig: Node,node: Node) -> String:
	if node == rig: return "."
	var parts: Array[String] = []
	var current: Node = node
	while current != rig:
		if current == null: return "<outside-root>"
		# Only Godot's generated duplicate-name IDs are unstable across instances.
		# Named ancestors remain exact; anonymous siblings retain index and class.
		parts.push_front(("@"+current.get_class()+"#"+str(current.get_index())) if _is_generated_name(current) else String(current.name))
		current = current.get_parent()
	return "/".join(parts)
func _node_map(rig: Node) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in _nodes(rig): result[_node_key(rig,node)] = node
	return result
func _dump_raw_difference(current: Dictionary,original: Dictionary,label: String) -> void:
	var keys: Array = current.keys()
	for key: Variant in original:
		if not current.has(key): keys.append(key)
	for key: Variant in keys:
		if current.has(key) and original.has(key) and current[key] == original[key]: continue
		if printed_mismatches >= 32: return
		print("HAND RAW MISMATCH ",printed_mismatches+1," ",label," key=",key," candidate=",var_to_str(current.get(key,"<missing>"))," baseline=",var_to_str(original.get(key,"<missing>")))
		printed_mismatches += 1
func _hand_meshes(rig: Node3D,side: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var wrist: Node = rig.get_node(side+"_arm/forearm/wrist")
	for part: String in ["palm","index","middle","ring","little","thumb"]: result.append_array(_meshes(wrist.get_node(part)))
	return result
func _vertices(mesh: Mesh) -> PackedVector3Array:
	if not vertex_cache.has(mesh.get_rid()):
		var result := PackedVector3Array()
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: result.append_array(arrays[Mesh.ARRAY_VERTEX])
		vertex_cache[mesh.get_rid()] = result
	return vertex_cache[mesh.get_rid()]
func _triangles(mesh: Mesh) -> PackedVector3Array:
	if not triangle_cache.has(mesh.get_rid()):
		var result := PackedVector3Array()
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and not arrays[Mesh.ARRAY_INDEX].is_empty():
				for index: int in arrays[Mesh.ARRAY_INDEX]: result.append(vertices[index])
			else: result.append_array(vertices)
		triangle_cache[mesh.get_rid()] = result
	return triangle_cache[mesh.get_rid()]
func _in_space(mesh: MeshInstance3D,space: Node3D,triangles: bool = false) -> PackedVector3Array:
	var transform: Transform3D = space.global_transform.affine_inverse()*mesh.global_transform
	var result := PackedVector3Array()
	for point: Vector3 in (_triangles(mesh.mesh) if triangles else _vertices(mesh.mesh)): result.append(transform*point)
	return result
func _mesh_digest(mesh: Mesh) -> Array:
	var result: Array = []
	for surface: int in range(mesh.get_surface_count()): result.append(hash(mesh.surface_get_arrays(surface)))
	return result
func _material_signature(material: Material) -> Array:
	if material == null: return []
	var result: Array = [material.get_class()]
	for key: String in ["albedo_color","roughness","metallic","cull_mode","shading_mode","transparency","vertex_color_use_as_albedo","emission_enabled","emission","emission_energy_multiplier"]: result.append(material.get(key))
	return result
func _resource_snapshot(rig: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for mesh: MeshInstance3D in _meshes(rig): result[_node_key(rig,mesh)] = [mesh.mesh,mesh.material_override,_mesh_digest(mesh.mesh),_material_signature(mesh.material_override)]
	return result
func _poses(rig: Node3D,omit_cart_digits: bool = false,normalize_generated_names: bool = true) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in _nodes(rig):
		if not node is Node3D: continue
		var path: String = String(rig.get_path_to(node))
		if omit_cart_digits and ("/wrist/thumb" in path or "/wrist/index" in path or "/wrist/middle" in path or "/wrist/ring" in path or "/wrist/little" in path): continue
		var key: String = _node_key(rig,node) if normalize_generated_names else path
		# Every node remains represented. Different classes, named paths, sibling
		# order or child counts cannot disappear behind name normalization.
		result[key] = [node.get_class(),node.get_child_count(),node.get_index() if node != rig else 0,node.transform,node.visible]
	return result
func _state(rig: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["action","action_phase","last_punch_side","attack_weapon","weapon","tool","coat","shoes","high_ember","_next_punch_side","_contact","_action_age","_action_duration","_time","_travel_phase","_motion","_sprint","_strafe","_look","_shake","_high","_crash","_cart_grips"]:
		var value: Variant = rig.get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result
func _advance(rig: Variant,seconds: float,stress: bool = false) -> void:
	var elapsed := 0.0
	while elapsed < seconds-0.0000001:
		var dt: float = minf(1.0/120.0,seconds-elapsed)
		rig.tick(dt,Vector3(0.8,0,-5.5) if stress else Vector3.ZERO,stress,stress,stress,100.0 if stress else 0.0,Vector2(0.12,-0.08) if stress else Vector2.ZERO)
		elapsed += dt
func _same_pose(first: Node3D,baseline: Node3D,label: String,cart: bool = false) -> void:
	_check(_state(first) == _state(baseline),label+" preserves state/clocks/action capture")
	var current: Dictionary = _poses(first,cart); var original: Dictionary = _poses(baseline,cart)
	if current != original: _dump_raw_difference(current,original,label+" structural")
	_check(current == original,label+" preserves exact stable transforms and visibility")
func _safe_hands(rig: Node3D) -> bool:
	for side: String in ["left","right"]:
		for mesh: MeshInstance3D in _hand_meshes(rig,side):
			for point: Vector3 in _in_space(mesh,rig):
				if not point.is_finite() or point.z > -0.06 or point.z < -1.5 or absf(point.x) > 1.0 or absf(point.y) > 1.2: return false
	return true

func _geometry(first: Node3D,baseline: Node3D,second: Node3D) -> void:
	_check(first.get_script() == Rig and baseline.get_script() == Baseline and first.get_script() != baseline.get_script(),"candidate and baseline instantiate different actual scripts")
	var current: Dictionary = _resource_snapshot(first); var original: Dictionary = _resource_snapshot(baseline); var shared: Dictionary = _resource_snapshot(second)
	var current_nodes: Dictionary = _node_map(first); var original_nodes: Dictionary = _node_map(baseline)
	_check(current.keys() == original.keys() and current.keys() == shared.keys(),"all existing mesh paths retained without added mesh leaves")
	var seen: Dictionary = {}; var material_ids: Dictionary = {}; var old_material_ids: Dictionary = {}
	var surfaces := 0; var old_surfaces := 0; var hand_tris := 0; var old_hand_tris := 0
	for path: String in current:
		if not original.has(path) or not shared.has(path): continue
		var mesh: MeshInstance3D = current_nodes[path]; var old: MeshInstance3D = original_nodes[path]
		surfaces += mesh.mesh.get_surface_count(); old_surfaces += old.mesh.get_surface_count()
		if mesh.material_override != null: material_ids[mesh.material_override.get_rid()] = true
		if old.material_override != null: old_material_ids[old.material_override.get_rid()] = true
		_check(current[path][0] == shared[path][0] and current[path][1] == shared[path][1],"independent rigs share cached immutable mesh/material "+path)
		_check(current[path][3] == original[path][3] and mesh.cast_shadow == old.cast_shadow,"material/render flags unchanged "+path)
		var allowed: bool = mesh.name in [&"palm",&"thumb_base",&"proximal"]
		if not allowed: _check(current[path][2] == original[path][2],"unowned geometry stays identical "+path)
		if seen.has(mesh.mesh.get_rid()): continue
		seen[mesh.mesh.get_rid()] = true
		var finite := true; var unit := true; var front := true
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			finite = finite and vertices.size() > 0 and normals.size() == vertices.size()
			for i: int in range(mini(vertices.size(),normals.size())):
				finite = finite and vertices[i].is_finite() and normals[i].is_finite()
				unit = unit and absf(normals[i].length()-1.0) < 0.002
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i: int in range(vertices.size()): indices.append(i)
			for i: int in range(0,indices.size()-2,3):
				var a: int = indices[i]; var b: int = indices[i+1]; var c: int = indices[i+2]
				var normal := -(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
				if normal.length_squared() < 0.00000000000001: continue
				for index: int in [a,b,c]: front = front and normal.dot(normals[index]) > 0.0
		_check(finite and unit and front,"finite unit outward actual triangle normals "+path)
	for side: String in ["left","right"]:
		for mesh: MeshInstance3D in _hand_meshes(first,side): hand_tris += int(_triangles(mesh.mesh).size()/3)
		for mesh: MeshInstance3D in _hand_meshes(baseline,side): old_hand_tris += int(_triangles(mesh.mesh).size()/3)
		for part: String in ["palm","thumb/thumb_base"]:
			var path := side+"_arm/forearm/wrist/"+part
			var key: String = _node_key(first,first.get_node(path))
			_check(current[key][2] != original[key][2],"requested authored anatomy changes are present "+path)
	_check(hand_tris > 0 and hand_tris <= floori(float(old_hand_tris)*1.10),"hand-only triangle budget "+str(hand_tris)+" <=110% of "+str(old_hand_tris))
	_check(surfaces == old_surfaces and material_ids.size() == old_material_ids.size(),"no added surfaces or material instances")
	print("HAND ART METRICS: baseline=",old_hand_tris," triangles; candidate=",hand_tris,"; surfaces=",surfaces,"; materials=",material_ids.size())
	groups += 1

func _unchanged_motion(first: Variant,baseline: Variant) -> void:
	for weapon: StringName in Rig.supported_weapons():
		for tool: String in ["","propane_torch","crowbar"]:
			first.reset(); baseline.reset()
			var context := {"weapon":weapon,"tool":tool,"walk_speed":5.5}
			var accepted: bool = first.set_context(context); var original_accepted: bool = baseline.set_context(context)
			_check(accepted and original_accepted,"same canonical context accepted")
			_same_pose(first,baseline,"rest "+String(weapon)+"/"+tool)
			_advance(first,0.12,true); _advance(baseline,0.12,true)
			_same_pose(first,baseline,"stressed gait "+String(weapon)+"/"+tool)
			_check(_safe_hands(first),"refined hands remain in camera envelope at gait "+String(weapon)+"/"+tool)
		for contact: bool in [false,true]:
			first.reset(); baseline.reset(); first.set_context({"weapon":weapon}); baseline.set_context({"weapon":weapon})
			for swing: int in range(2 if weapon == &"fists" else 1):
				first.acknowledge(&"punch",true,contact,weapon); baseline.acknowledge(&"punch",true,contact,weapon)
				var previous := 0.0
				for age: float in [0.0,0.02,0.035,0.055,0.12,0.22,0.34,0.45]:
					_advance(first,age-previous); _advance(baseline,age-previous); previous = age
					_same_pose(first,baseline,"attack "+String(weapon)+"/"+str(contact)+"/"+str(swing)+" at "+str(age))
					_check(_safe_hands(first),"actual skin clears near plane throughout attack")
					if weapon == &"fists" and is_equal_approx(age,0.035): _root_coverage(first,"closed fist "+str(swing)+"/"+str(contact))
	for action: StringName in Rig.ACTION_LENGTHS:
		if action == &"punch": continue
		first.reset(); baseline.reset(); first.acknowledge(action); baseline.acknowledge(action)
		var previous := 0.0
		for fraction: float in [0.0,0.2,0.5,0.8,1.001]:
			var target: float = float(Rig.ACTION_LENGTHS[action])*fraction
			_advance(first,target-previous); _advance(baseline,target-previous); previous = target
			_same_pose(first,baseline,"gesture "+String(action)+"/"+str(fraction)); _check(_safe_hands(first),"gesture skin retains camera envelope")
			if action == &"pickup" and is_equal_approx(fraction,0.5): _root_coverage(first,"pickup")
	groups += 1

func _closest(point: Vector3,a: Vector3,b: Vector3,c: Vector3) -> Vector3:
	var ab := b-a; var ac := c-a; var ap := point-a
	var d1: float = ab.dot(ap); var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0: return a
	var bp := point-b; var d3: float = ab.dot(bp); var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3: return b
	var vc: float = d1*d4-d3*d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0: return a+ab*d1/(d1-d3)
	var cp := point-c; var d5: float = ab.dot(cp); var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6: return c
	var vb: float = d5*d2-d1*d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0: return a+ac*d2/(d2-d6)
	var va: float = d3*d6-d5*d4
	if va <= 0.0 and d4-d3 >= 0.0 and d5-d6 >= 0.0: return b+(c-b)*(d4-d3)/(d4-d3+d5-d6)
	var denominator: float = va+vb+vc
	if absf(denominator) < 0.000000000001: return a
	return a+ab*vb/denominator+ac*vc/denominator
func _nearest(point: Vector3,triangles: PackedVector3Array) -> Dictionary:
	var distance := INF; var closest := Vector3.ZERO
	for i: int in range(0,triangles.size()-2,3):
		var candidate := _closest(point,triangles[i],triangles[i+1],triangles[i+2])
		var gap: float = point.distance_to(candidate)
		if gap < distance: distance = gap; closest = candidate
	return {"distance":distance,"point":closest}
func _inside_closed_surface(point: Vector3,triangles: PackedVector3Array) -> bool:
	# General closed-mesh parity, not a convex-palm assumption. Deduplicate shared edges.
	var direction := Vector3(1.0,0.271,0.137).normalized()
	var hits: Array[float] = []
	for i: int in range(0,triangles.size()-2,3):
		var edge_a: Vector3 = triangles[i+1]-triangles[i]; var edge_b: Vector3 = triangles[i+2]-triangles[i]
		var cross: Vector3 = direction.cross(edge_b); var determinant: float = edge_a.dot(cross)
		if absf(determinant) < 0.000000001: continue
		var relative: Vector3 = point-triangles[i]; var u: float = relative.dot(cross)/determinant
		if u < 0.0 or u > 1.0: continue
		var q: Vector3 = relative.cross(edge_a); var v: float = direction.dot(q)/determinant
		if v < 0.0 or u+v > 1.0: continue
		var distance: float = edge_b.dot(q)/determinant
		if distance <= 0.000001: continue
		var duplicate := false
		for old: float in hits:
			if absf(old-distance) < 0.000001: duplicate = true; break
		if not duplicate: hits.append(distance)
	return hits.size()%2 == 1
func _root_coverage(rig: Node3D,label: String) -> void:
	for side: String in ["left","right"]:
		var wrist: Node3D = rig.get_node(side+"_arm/forearm/wrist")
		var palm: MeshInstance3D = wrist.get_node("palm")
		var triangles: PackedVector3Array = _in_space(palm,wrist,true)
		for path: String in ["thumb/thumb_base","index/proximal","middle/proximal","ring/proximal","little/proximal"]:
			var mesh: MeshInstance3D = wrist.get_node(path)
			var transform: Transform3D = wrist.global_transform.affine_inverse()*mesh.global_transform
			var proximal_z: float = mesh.mesh.get_aabb().end.z-0.008
			var covered := false; var sampled := 0
			for vertex: Vector3 in _vertices(mesh.mesh):
				if vertex.z < proximal_z: continue
				sampled += 1
				var point: Vector3 = transform*vertex
				if _nearest(point,triangles).distance <= 0.0025 or _inside_closed_surface(point,triangles): covered = true; break
			_check(sampled > 0 and covered,label+" "+side+" actual proximal skin joins palm without a detached root: "+path)
func _planes(triangles: PackedVector3Array) -> Array[Plane]:
	var result: Array[Plane] = []
	for i: int in range(0,triangles.size()-2,3):
		var normal := -(triangles[i+1]-triangles[i]).cross(triangles[i+2]-triangles[i])
		if normal.length_squared() < 0.000000000001: continue
		normal = normal.normalized(); var plane := Plane(normal,normal.dot(triangles[i]))
		var seen := false
		for other: Plane in result:
			if plane.normal.is_equal_approx(other.normal) and absf(plane.d-other.d) < 0.000001: seen = true; break
		if not seen: result.append(plane)
	return result
func _intrudes(triangle: PackedVector3Array,planes: Array[Plane],depth: float) -> bool:
	# Clip each rendered triangle against the shaft's inward-offset convex volume.
	# Any surviving area is actual deep intersection, including edges with outside vertices.
	var polygon: PackedVector3Array = triangle
	for plane: Plane in planes:
		if polygon.is_empty(): return false
		var clipped := PackedVector3Array()
		for i: int in range(polygon.size()):
			var a: Vector3 = polygon[i]; var b: Vector3 = polygon[(i+1)%polygon.size()]
			var da: float = plane.distance_to(a)+depth; var db: float = plane.distance_to(b)+depth
			if da <= 0.0: clipped.append(a)
			if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0): clipped.append(a+(b-a)*da/(da-db))
		polygon = clipped
	if polygon.size() < 3: return false
	for i: int in range(1,polygon.size()-1):
		if (polygon[i]-polygon[0]).cross(polygon[i+1]-polygon[0]).length_squared() > 0.00000000000001: return true
	return false
func _pad_contact(mesh: MeshInstance3D,shaft: MeshInstance3D,triangles: PackedVector3Array) -> Dictionary:
	var best := {"distance":INF,"point":Vector3.ZERO}
	var bounds: AABB = mesh.mesh.get_aabb()
	var transform: Transform3D = shaft.global_transform.affine_inverse()*mesh.global_transform
	var cut: float = bounds.get_center().y-bounds.size.y*0.20
	var samples: Dictionary = {}
	var skin: PackedVector3Array = _triangles(mesh.mesh)
	# Clip actual rendered pad triangles to the negative-Y palmar band. Include
	# intersection points on their edges, so sparse ring vertices cannot create
	# a false separation at the band's boundary. Every sample is real skin.
	for i: int in range(0,skin.size()-2,3):
		for edge: int in range(3):
			var a: Vector3 = skin[i+edge]; var b: Vector3 = skin[i+(edge+1)%3]
			var da: float = a.y-cut; var db: float = b.y-cut
			if da <= 0.0: samples[a] = true
			if da*db < 0.0: samples[a+(b-a)*da/(da-db)] = true
	for point: Vector3 in samples:
		var near: Dictionary = _nearest(transform*point,triangles)
		if near.distance < best.distance: best = near
	return best
func _opposition(finger_radial: Vector2,thumb_point: Vector3) -> float:
	var thumb_radial := Vector2(thumb_point.y,thumb_point.z)
	if finger_radial.length_squared() <= 0.000001 or thumb_radial.length_squared() <= 0.000001: return 1.0
	return finger_radial.normalized().dot(thumb_radial.normalized())
func _contact_counterexamples(rig: Node3D,shaft: MeshInstance3D) -> void:
	var triangles: PackedVector3Array = _triangles(shaft.mesh)
	var planes: Array[Plane] = _planes(triangles)
	var pad: MeshInstance3D = rig.get_node("right_arm/forearm/wrist/middle/middle/tip/tip_mesh")
	var before: Transform3D = pad.transform
	var contact: Dictionary = _pad_contact(pad,shaft,triangles)
	var outward := Vector3(0,contact.point.y,contact.point.z).normalized()
	_check(contact.distance <= PAD_GAP and outward.length_squared() > 0.9,"separation counterexample starts from an actual contacting finger pad")
	var parent: Node3D = pad.get_parent()
	pad.position += parent.global_transform.basis.inverse()*shaft.global_transform.basis*outward*0.015
	var separated: Dictionary = _pad_contact(pad,shaft,triangles)
	_check(separated.distance > PAD_GAP,"moving actual distal pad15mm outward fails the8mm rendered-surface contact check")
	pad.transform = before
	_check(pad.transform == before and _pad_contact(pad,shaft,triangles) == contact,"counterexample restores actual pad geometry/transform exactly")
	var crossing := PackedVector3Array([Vector3(0,0.05,0),Vector3(0,-0.05,0.04),Vector3(0,-0.05,-0.04)])
	var all_outside := true
	for vertex: Vector3 in crossing:
		var outside := false
		for plane: Plane in planes: outside = outside or plane.distance_to(vertex) > 0.0
		all_outside = all_outside and outside
	_check(all_outside and _intrudes(crossing,planes,SKIN_PENETRATION),"triangle crosses deep shaft despite all three vertices lying outside")
	var finger_radial := Vector2(contact.point.y,contact.point.z)
	_check(_opposition(finger_radial,contact.point) >= -0.10,"same-side thumb/finger contacts fail the opposed-wrap check")
func _fixed_digit_origins(first: Node3D,baseline: Node3D) -> bool:
	for side: String in ["left","right"]:
		for digit: String in ["thumb","index","middle","ring","little"]:
			var path := side+"_arm/forearm/wrist/"+digit
			for node: Node in _nodes(first.get_node(path)):
				if not node is Node3D: continue
				var other: Node3D = baseline.get_node(first.get_path_to(node))
				if node.position != other.position or not node.scale.is_equal_approx(other.scale): return false
	return true
func _wrap(rig: Node3D,shaft: MeshInstance3D,side: String,label: String) -> void:
	var triangles: PackedVector3Array = _triangles(shaft.mesh); var planes: Array[Plane] = _planes(triangles)
	var wrist: Node3D = rig.get_node(side+"_arm/forearm/wrist")
	var radial := Vector2.ZERO; var count := 0
	for digit: String in DIGITS:
		var pad: MeshInstance3D = wrist.get_node(digit+"/middle/tip/tip_mesh")
		var contact: Dictionary = _pad_contact(pad,shaft,triangles)
		if contact.distance <= PAD_GAP:
			count += 1; radial += Vector2(contact.point.y,contact.point.z).normalized()
		print("CART PAD ",label," ",side," ",digit," gap=",contact.distance)
	var thumb: Dictionary = _pad_contact(wrist.get_node("thumb/tip/thumb_tip"),shaft,triangles)
	_check(count >= 3 and thumb.distance <= PAD_GAP,label+" "+side+" three actual finger pads and thumb within8mm of rendered shaft")
	var opposition: float = _opposition(radial,thumb.point)
	_check(opposition < -0.10,label+" "+side+" thumb visibly opposes finger contacts in shaft cross-section: "+str(opposition))
	var intrusions := 0; var palm_intrusions := 0
	for mesh: MeshInstance3D in _hand_meshes(rig,side):
		var skin: PackedVector3Array = _in_space(mesh,shaft,true)
		for i: int in range(0,skin.size()-2,3):
			if _intrudes(PackedVector3Array([skin[i],skin[i+1],skin[i+2]]),planes,SKIN_PENETRATION):
				intrusions += 1
				if mesh.name == &"palm": palm_intrusions += 1
	_check(palm_intrusions == 0,label+" "+side+" actual palm triangles remain outside shaft interior")
	_check(intrusions == 0,label+" "+side+" actual skin triangles do not deeply penetrate shaft: "+str(intrusions))

func _cart(first: Variant,baseline: Variant) -> void:
	var world := World.new(); root.add_child(world)
	_check(world.has_method(&"_cart_handle"),"production unique-cart shaft factory exists")
	if not world.has_method(&"_cart_handle"): world.free(); return
	var shaft: MeshInstance3D = world.call(&"_cart_handle",Vector3(0,-0.30,-0.76),0.96)
	if shaft == null: _check(false,"production shaft constructed"); world.free(); return
	var vertices: PackedVector3Array = _vertices(shaft.mesh); var bounds := AABB(vertices[0],Vector3.ZERO)
	for point: Vector3 in vertices: bounds = bounds.expand(point)
	_check(shaft.mesh is ArrayMesh and shaft.get_meta("cart_part","") == "handle","actual unique-cart authored shaft resource and adoption tag")
	_check(absf(bounds.size.x-0.96) < 0.00001 and maxf(bounds.size.y,bounds.size.z) <= 0.04001 and minf(bounds.size.y,bounds.size.z) >= 0.03599,"real shaft stays .96m wide with hand-sized36–40mm cross-section")
	var planes: Array[Plane] = _planes(_triangles(shaft.mesh)); var convex := planes.size() >= 12
	for point: Vector3 in vertices:
		for plane: Plane in planes: convex = convex and plane.distance_to(point) < 0.00001
	_check(convex,"rendered shaft is a closed convex faceted contact surface")
	var shaft_mesh: Mesh = shaft.mesh; var shaft_material: Material = shaft.material_override; var digest: Array = _mesh_digest(shaft.mesh)
	for center: Vector3 in [Vector3(0,-0.30,-0.76),Vector3(0,-0.45,-0.66)]:
		shaft.position = center
		var grips := {"left":center+Vector3(-0.25,0,0),"right":center+Vector3(0.25,0,0)}
		first.reset(); baseline.reset()
		var accepted: bool = first.set_context({"cart_grips":grips}); var original_accepted: bool = baseline.set_context({"cart_grips":grips})
		_check(accepted and original_accepted,"both real rigs accept supported actual cart targets")
		_same_pose(first,baseline,"cart arm solve",true)
		_check(_fixed_digit_origins(first,baseline),"cart wrap changes rotations only, retaining every finger pivot origin and segment scale")
		for side: String in ["left","right"]:
			var wrist: Node3D = first.get_node(side+"_arm/forearm/wrist")
			_check(first.to_local(wrist.to_global(Vector3(0,-0.036,-0.082))).distance_to(grips[side]) < 0.000001,"unchanged exact cart grip marker "+side)
			_wrap(first,shaft,side,"rest")
		_contact_counterexamples(first,shaft)
		_check(_safe_hands(first),"wrapped hands retain actual camera bounds")
		first.acknowledge(&"punch",true,true,&"fists"); baseline.acknowledge(&"punch",true,true,&"fists")
		_advance(first,0.04); _advance(baseline,0.04)
		_same_pose(first,baseline,"cart peak preserves non-finger transforms",true)
		var active: Node3D = first.get_node("right_arm/forearm/wrist")
		var old_active: Node3D = baseline.get_node("right_arm/forearm/wrist")
		_check(_poses(active) == _poses(old_active),"active cart fist restores exact accepted contact finger pose")
		_check(first.to_local(active.to_global(Vector3(0,-0.036,-0.082))).distance_to(grips.right) > 0.01,"active cart attack releases real handle immediately")
		_wrap(first,shaft,"left","during right attack")
		_advance(first,0.30); _advance(baseline,0.30)
		_same_pose(first,baseline,"cart recovery state",true)
		_wrap(first,shaft,"right","recovery")
		first.set_context({"cart_grips":{}}); baseline.set_context({"cart_grips":{}})
		_same_pose(first,baseline,"level-look grip release")
	_check(shaft.mesh == shaft_mesh and shaft.material_override == shaft_material and _mesh_digest(shaft.mesh) == digest,"wrap/attack never mutate shaft resource or material")
	world.free(); groups += 1

func _run() -> void:
	var first: Variant = Rig.create(); root.add_child(first)
	# Explicit constructor prevents a wrongly renamed baseline create() from selecting candidate.
	var baseline: Variant = Baseline.new(); baseline.name = "Baseline"; baseline._build(); baseline.reset(); root.add_child(baseline)
	var second: Variant = Rig.create(); root.add_child(second)
	_dump_raw_difference(_poses(first,false,false),_poses(baseline,false,false),"original generated paths")
	var generated := 0
	for node: Node in _nodes(first):
		if _is_generated_name(node): generated += 1
	_check(generated > 0,"duplicate authored part names produce actual instance-specific Godot names")
	_check(_node_map(first).size() == _nodes(first).size() and _node_map(baseline).size() == _nodes(baseline).size(),"structural keys retain every node without collisions")
	var stable_poses: Dictionary = _poses(first)
	var named: Node3D = first.get_node("right_arm/forearm/wrist/palm")
	named.name = "palm_counterexample"
	_check(_poses(first) != stable_poses,"authored-name changes are rejected, not normalized")
	named.name = "palm"
	_check(_poses(first) == stable_poses,"authored-name counterexample restores exact structure")
	var resources: Dictionary = _resource_snapshot(first); var idle: Dictionary = _poses(second)
	_geometry(first,baseline,second)
	_root_coverage(first,"rest")
	_unchanged_motion(first,baseline)
	_cart(first,baseline)
	first.reset(); baseline.reset()
	_check(_resource_snapshot(first) == resources,"all ticks/context transitions retain cached resources and immutable contents")
	_check(_poses(second) == idle,"a second cached rig never receives another instance's poses")
	_check(groups == 3,"all construction/motion/cart groups completed")
	first.free(); baseline.free(); second.free()
	print("DRAFT HAND ART REFINEMENT: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",groups," groups. Geometry/contract evidence, not visual acceptance.")
	quit(0 if failures.is_empty() else 1)
