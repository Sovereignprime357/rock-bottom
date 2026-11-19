extends SceneTree
## Fixed fixture-backed presentation, sampled from source values and actual rig anchors.
const Emitters = preload("res://scripts/dynamic_emitters.gd")
const Rig = preload("res://scripts/first_person_rig.gd")
const Roster = preload("res://scripts/character_roster.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _cop(id: String = "cop_test",sprite: String = "cop",is_cop: bool = true) -> Dictionary:
	return {"id":id,"isCop":is_cop,"sprite":sprite,"dead":false,"hidden":false,"visible":true,"cap_transform":Transform3D(Basis.IDENTITY,Vector3(0,1.6,0))}
func _snapshot(cops: Array = [],high: bool = false) -> Dictionary:
	return {"dayTime":0.5,"cops":cops,"player":{"rockedT":1000.0 if high else 0.0,"hitterHigh":false,"visible":true,"ember_transform":Transform3D(Basis.IDENTITY,Vector3(0,1.4,-0.4))}}
func _lights(view: Node) -> Array[OmniLight3D]:
	var result: Array[OmniLight3D] = []
	for node: Node in view.find_children("*","OmniLight3D",true,false): result.append(node as OmniLight3D)
	return result
func _resources(view: Node) -> Dictionary:
	var result: Dictionary = {}; var materials: Dictionary = {}
	for node: Node in view.find_children("*","",true,false):
		var record: Array = [node.get_instance_id()]
		if node is MeshInstance3D:
			record.append(node.mesh)
			if node.material_override != null: materials[node.material_override.get_instance_id()] = true
			for surface: int in range(node.mesh.get_surface_count()): record.append(hash(node.mesh.surface_get_arrays(surface)))
		result[str(view.get_path_to(node))] = record
	var material_ids: Array = materials.keys(); material_ids.sort(); result["materials"] = material_ids
	return result
func _poses(view: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in view.find_children("*","Node3D",true,false): result[node.get_instance_id()] = [node.transform,node.visible]
	return result
func _cop_light(view: Node,index: int = 0) -> OmniLight3D:
	var nodes: Array[OmniLight3D] = _lights(view.get_node("Cop"+str(index)))
	return nodes[0] if not nodes.is_empty() else null
func _lens(view: Node,index: int,side: String) -> Color:
	var leaf: MeshInstance3D = view.get_node("Cop"+str(index)+"/Fixture/"+side+"Lens")
	return (leaf.material_override as StandardMaterial3D).albedo_color
func _actual_vertices(node: Node,space: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array(); var inverse: Transform3D = space.global_transform.affine_inverse()
	for child: Node in node.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		for surface: int in range(mesh.mesh.get_surface_count()):
			for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]: result.append(inverse*mesh.global_transform*vertex)
	return result
func _geometry(node: Node,label: String) -> void:
	var valid: bool = true; var front: bool = true; var count: int = 0
	for child: Node in node.find_children("*","MeshInstance3D",true,false):
		var instance: MeshInstance3D = child as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			valid = valid and vertices.size() == normals.size(); count += vertices.size()
			for index: int in range(vertices.size()):
				valid = valid and vertices[index].is_finite() and index < normals.size()
				if index < normals.size(): valid = valid and normals[index].is_finite() and absf(normals[index].length()-1.0) < 0.001
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
			var size: int = indices.size() if not indices.is_empty() else vertices.size()
			for offset: int in range(0,size-2,3):
				var a: int = indices[offset] if not indices.is_empty() else offset
				var b: int = indices[offset+1] if not indices.is_empty() else offset+1
				var c: int = indices[offset+2] if not indices.is_empty() else offset+2
				if maxi(a,maxi(b,c)) >= mini(vertices.size(),normals.size()): valid = false; continue
				var cross: Vector3 = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
				if cross.length_squared() < 0.0000000000000001: continue
				var normal: Vector3 = -cross.normalized()
				front = front and normal.dot(normals[a]) > 0 and normal.dot(normals[b]) > 0 and normal.dot(normals[c]) > 0
	_check(valid and front and count > 0,label+" finite unit outward-facing original geometry")
func _advance(rig: Rig,seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var dt: float = minf(remaining,1.0/120.0); rig.tick(dt,Vector3.ZERO,false); remaining -= dt
func _qualifiers() -> void:
	for row: Dictionary in [{"sprite":"cop","isCop":false,"expected":true},{"sprite":"horsecop","isCop":false,"expected":true},{"sprite":"brendan","isCop":true,"expected":true},{"sprite":"brendan","isCop":false,"expected":false},{"sprite":"metermaid","isCop":false,"expected":false},{"sprite":"receipt_guard","isCop":false,"expected":false},{"sprite":"lurch","isCop":true,"expected":true}]:
		var record: Dictionary = _cop("test",row.sprite,row.isCop); record.archetype = "cop"
		_check(Emitters.qualifies_cop(record) == row.expected,"source eligibility follows exact flags/sprites, not archetype: "+str(row))
		if row.expected:
			record.dead = true; _check(not Emitters.qualifies_cop(record),"dead cop has no fixture")
			record.dead = false; record.hidden = true; _check(not Emitters.qualifies_cop(record),"hidden cop has no fixture")
func _pool_and_pulse(first: Emitters,second: Emitters) -> void:
	var resource_ids: Dictionary = _resources(first); var other_resources: Dictionary = _resources(second)
	_check(_lights(first).size() == 6 and first.inspect().allocated_lights == 6,"five cop and one player lights allocated exactly once")
	for light: OmniLight3D in _lights(first): _check(not light.shadow_enabled,"no dynamic shadow map allocation")
	var rows: Array = []
	for index: int in range(5):
		var row: Dictionary = _cop("cop_"+str(index)); row.cap_transform = Transform3D(Basis.IDENTITY,Vector3(index*1.2,1.6,0)); rows.append(row)
	var snapshot: Dictionary = _snapshot(rows,true); var original: Dictionary = snapshot.duplicate(true)
	_check(first.sync(snapshot,0.0) and first.inspect().active_lights == 6 and first.inspect().cop_count == 5,"all five source cops plus high player emit simultaneously")
	_check(snapshot == original,"sync leaves complete caller snapshot unchanged")
	var light: OmniLight3D = _cop_light(first); var player: OmniLight3D = first.get_node("PlayerLight")
	_check(is_equal_approx(light.omni_range,4.16) and is_equal_approx(player.omni_range,1.92),"source coordinate-scaled ranges preserved")
	_check(light.light_color.is_equal_approx(Color("4868d0")) and player.light_color.is_equal_approx(Color("d06030")),"source steady blue and ember field colors")
	var initial_left: Color = _lens(first,0,"Left"); var initial_right: Color = _lens(first,0,"Right")
	first.sync(snapshot,149.999); _check(_lens(first,0,"Left") == initial_left and _lens(first,0,"Right") == initial_right,"lens remains stable before150ms boundary")
	first.sync(snapshot,150.0); _check(_lens(first,0,"Left") == initial_right and _lens(first,0,"Right") == initial_left,"two actual lenses swap exactly at150ms")
	_check(light.light_color.is_equal_approx(Color("4868d0")) and is_equal_approx(light.light_energy,0.62*0.34),"lens swap does not recolor or blink the world field")
	first.sync(snapshot,300.0); _check(_lens(first,0,"Left") == initial_left,"full source beacon cycle is300ms")
	for row: Vector2 in [Vector2(0,1),Vector2(0.2,1),Vector2(0.25,0.5),Vector2(0.3,0),Vector2(0.5,0),Vector2(0.7,0),Vector2(0.75,0.5),Vector2(0.8,1),Vector2(1,1)]:
		snapshot.dayTime = row.x; first.sync(snapshot,0.0)
		_check(is_equal_approx(light.light_energy,0.62*maxf(0.34,row.y)) and is_equal_approx(player.light_energy,0.62*maxf(0.36,row.y)),"source night levels at "+str(row.x))
	second.sync(_snapshot([_cop()],true),150.0); var isolated_color: Color = _lens(second,0,"Left"); var isolated_pose: Dictionary = _poses(second)
	var other_lens: MeshInstance3D = second.get_node("Cop0/Fixture/LeftLens")
	var other_energy: float = (other_lens.material_override as StandardMaterial3D).emission_energy_multiplier
	for index: int in range(32):
		snapshot.dayTime = 0.5; snapshot.cops[0].cap_transform = Transform3D(Basis.IDENTITY,Vector3(index*0.01,1.6,0)); first.sync(snapshot,index*150.0)
	snapshot.dayTime = 0.9; first.sync(snapshot,4800.0)
	_check(_lens(second,0,"Left") == isolated_color and _poses(second) == isolated_pose and (other_lens.material_override as StandardMaterial3D).emission_energy_multiplier == other_energy,"other presenter retains independent material phase, level and transforms")
	_check(_resources(first) == resource_ids and _resources(second) == other_resources,"pulse, movement and activation reuse every original node/mesh/material")
	var a: MeshInstance3D = first.get_node("Cop0/Fixture/LeftLens"); var b: MeshInstance3D = second.get_node("Cop0/Fixture/LeftLens")
	_check(a.mesh == b.mesh and a.material_override != b.material_override,"original lens meshes shared but per-presenter phase materials isolated")
	var inspection: Dictionary = first.inspect(); inspection.cop_count = 100
	_check(first.inspect().cop_count == 5 and first.inspect().queries == 0 and first.inspect().dynamic_shadows == 0,"inspection is detached and no query/shadow owner exists")
	first.clear(); _check(first.inspect().active_lights == 0 and _resources(first) == resource_ids,"clear disables all lights without freeing cached resources")
	_geometry(first.get_node("Cop0/Fixture"),"cap beacon")
func _absence(first: Emitters) -> void:
	for flag: String in ["dead","hidden","visible"]:
		var row: Dictionary = _cop(); row[flag] = flag != "visible"; row.erase("cap_transform")
		_check(first.sync(_snapshot([row]),0.0) and first.inspect().active_lights == 0,"absent "+flag+" fixture needs no orphan transform/light")
	var stranger: Dictionary = _cop("other","metermaid",false); stranger.erase("cap_transform")
	_check(first.sync(_snapshot([stranger]),0.0) and first.inspect().cop_count == 0,"nonqualifying uniform cannot acquire a beacon")
	for state: Dictionary in [{"rockedT":0.0,"hitterHigh":false,"expected":false},{"rockedT":1.0,"hitterHigh":false,"expected":true},{"rockedT":0.0,"hitterHigh":true,"expected":true}]:
		var snapshot: Dictionary = _snapshot(); snapshot.player.rockedT = state.rockedT; snapshot.player.hitterHigh = state.hitterHigh
		_check(first.sync(snapshot,0.0) and first.inspect().player_active == state.expected,"source high OR hitter gate "+str(state))
	var hidden: Dictionary = _snapshot([],true); hidden.player.visible = false; hidden.player.erase("ember_transform")
	_check(first.sync(hidden,0.0) and not first.inspect().player_active,"stowed/freed player fixture stops light before another pose")
	var invalids: Array[Dictionary] = [{},{"dayTime":NAN},{"dayTime":1.1},{"cops":"cop"},{"player":{"rockedT":0,"hitterHigh":true,"visible":true}},{"cops":[{"id":"bad","isCop":true,"sprite":"cop","dead":false,"hidden":false,"visible":true,"cap_transform":Transform3D(Basis.IDENTITY,Vector3(INF,0,0))}]}]
	for invalid: Dictionary in invalids:
		first.sync(_snapshot([_cop()],true),0.0)
		var snapshot: Dictionary = _snapshot(); snapshot.merge(invalid,true)
		if invalid.is_empty(): snapshot.erase("player")
		_check(not first.sync(snapshot,0.0) and first.inspect().active_lights == 0,"malformed input clears prior live fixtures")
	first.sync(_snapshot([_cop()],true),0.0)
	_check(not first.sync(_snapshot([_cop()]),INF) and first.inspect().active_lights == 0,"nonfinite visual time cannot leave stale lights")
	first.sync(_snapshot([_cop()],true),0.0); first.sync(_snapshot(),0.0)
	_check(first.inspect().active_lights == 0,"removing all source rows releases every previous beacon")
	var overflow: Array = []
	for index: int in range(6): overflow.append(_cop("extra_"+str(index)))
	_check(not first.sync(_snapshot(overflow,true),0.0) and first.inspect().active_lights == 0,"over-cap caller input fails closed rather than allocating a seventh light")
func _actual_caps(first: Emitters) -> void:
	var actors: Array[Node3D] = []; var rows: Array = []
	for id: StringName in [&"cop",&"brendan",&"horsecop"]:
		var actor: Node3D = Roster.create(id); root.add_child(actor); actors.append(actor)
		var anchor: Node3D = actor.get_node("mounted_rider/head/hair_style" if id == &"horsecop" else "head/hair_style")
		var row: Dictionary = _cop(str(id),str(id),id != &"horsecop"); row.cap_transform = anchor.global_transform; rows.append(row)
	_check(first.sync(_snapshot(rows),0.0) and first.inspect().cop_count == 3,"actual cop, Brendan and mounted rider cap anchors bind")
	for index: int in range(actors.size()):
		var actor: Node3D = actors[index]; var anchor: Node3D = actor.get_node("mounted_rider/head/hair_style" if index == 2 else "head/hair_style")
		var fixture: Node3D = first.get_node("Cop"+str(index)+"/Fixture")
		var bottom: float = INF
		for point: Vector3 in _actual_vertices(fixture,anchor): bottom = minf(bottom,point.y)
		_check(absf(bottom-0.24) < 0.002,"fixture base touches actual cap top, including rider instead of horse head")
	for actor: Node3D in actors: actor.free()
	first.sync(_snapshot(),0.0); _check(first.inspect().cop_count == 0,"caller removal after freed roster fixtures clears pool")
func _rig(first: Emitters) -> void:
	var rig: Rig = Rig.create() as Rig; root.add_child(rig)
	var ids: Dictionary = _resources(rig); var original: Dictionary = _poses(rig)
	var mouth: Node3D = rig.emitter_anchor(&"player_ember"); var pipe: Node3D = rig.emitter_anchor(&"weapon_pipe"); var torch: Node3D = rig.emitter_anchor(&"torch_pilot")
	_check(mouth != null and pipe != null and torch != null and rig.emitter_anchor(&"unknown") == null,"exact cached mouth/weapon/tool emitter anchors")
	if mouth == null or pipe == null or torch == null: rig.free(); return
	_check(not mouth.is_visible_in_tree(),"mouth starts stowed with default context")
	_check(not rig.set_context({"high_ember":1,"weapon":"pipe"}) and _poses(rig) == original and rig.weapon == &"fists","nonboolean high context rejects every pending change atomically")
	for context: Dictionary in [{"weapon":"fists"},{"weapon":"pipe","tool":"propane_torch"},{"weapon":"knife","tool":"crowbar"},{"cart_grips":{"left":Vector3(-0.25,-0.30,-0.76),"right":Vector3(0.25,-0.30,-0.76)}}]:
		rig.reset(); rig.set_context(context); var before: Dictionary = _poses(rig)
		rig.set_context({"high_ember":true})
		var unchanged: bool = true
		for arm: String in ["left_arm","right_arm"]:
			for node: Node in rig.get_node(arm).find_children("*","Node3D",true,false):
				unchanged = unchanged and before[node.get_instance_id()] == [node.transform,node.visible]
		_check(mouth.is_visible_in_tree() and unchanged,"high mouth fixture leaves actual hand/gear/cart poses unchanged")
		rig.tick(1.0/60.0,Vector3(0,0,-16.83),true,true,false,0.0,Vector2.ZERO)
		_check(mouth.is_visible_in_tree(),"idle sprint retains source high fixture")
	for marker: Node3D in [mouth,pipe,torch]:
		var nearest: float = INF
		for point: Vector3 in _actual_vertices(marker.get_parent(),rig): nearest = minf(nearest,point.distance_to(rig.to_local(marker.global_position)))
		_check(nearest < 0.04,"emitter anchor lies at actual authored tip geometry")
		var lit_tip: bool = false
		for child: Node in marker.get_parent().find_children("*","MeshInstance3D",true,false):
			var mesh: MeshInstance3D = child as MeshInstance3D; var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
			if material == null or not material.emission_enabled or material.emission_energy_multiplier <= 0.0: continue
			for surface: int in range(mesh.mesh.get_surface_count()):
				for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					lit_tip = lit_tip or (mesh.global_transform*point).distance_to(marker.global_position) < 0.04
		_check(lit_tip,"actual geometry at each cached source tip uses an authored emissive material")
	_geometry(rig.get_node("MouthEmber"),"mouth stub")
	var safe: bool = true
	for point: Vector3 in _actual_vertices(rig.get_node("MouthEmber"),rig): safe = safe and point.is_finite() and point.y < 0 and point.z < -0.06 and point.length() < 0.7
	_check(safe,"all actual mouth vertices remain below center and behind near plane")
	for action: StringName in [&"punch",&"receipt",&"smoke",&"phone",&"bench",&"dumpster",&"kick"]:
		rig.reset(); rig.set_context({"high_ember":true,"weapon":"pipe","tool":"propane_torch"}); rig.acknowledge(action,true,false)
		_check(not mouth.is_visible_in_tree(),"accepted "+str(action)+" stows fixture immediately")
		var snapshot: Dictionary = _snapshot([],true); snapshot.player.visible = mouth.is_visible_in_tree(); snapshot.player.ember_transform = mouth.global_transform
		first.sync(snapshot,0.0); _check(not first.inspect().player_active,"stowed action has no orphan player point light")
		_advance(rig,0.65); _check(mouth.is_visible_in_tree(),"recovery restores current high fixture")
		rig.acknowledge(action,true,false); rig.set_context({"high_ember":false}); _advance(rig,0.65)
		_check(not mouth.is_visible_in_tree(),"recovery does not resurrect expired high")
	rig.set_context({"high_ember":true,"visible":false}); _check(not mouth.is_visible_in_tree(),"hidden rig ancestor suppresses mouth fixture")
	rig.reset(); _check(not mouth.is_visible_in_tree() and _resources(rig) == ids and _lights(rig).is_empty(),"reset clears high and reuses tips without item OmniLights")
	rig.free()
func _run() -> void:
	seed(71942); var expected_random: float = randf(); seed(71942)
	var first: Emitters = Emitters.create(); var second: Emitters = Emitters.create()
	_check(first.get_parent() == null and second.get_parent() == null,"dynamic factories return unparented fixed pools")
	root.add_child(first); root.add_child(second)
	_qualifiers(); _pool_and_pulse(first,second); _absence(first); _actual_caps(first); _rig(first)
	_check(randf() == expected_random,"presentation construction/projection consumes no global RNG")
	for node: Node in first.find_children("*","",true,false):
		_check(not node.is_processing() and not node.is_physics_processing() and not node.is_processing_input() and not (node is Timer or node is CollisionObject3D or node is AudioStreamPlayer or node is AudioStreamPlayer3D),"fixed emitter pool owns no clock/input/physics/audio")
	first.free(); second.free(); await process_frame
	if failures.is_empty(): print("3D DYNAMIC EMITTER GATE: PASS (%d checks;fixed six lights)"%checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D DYNAMIC EMITTER GATE: FAIL (%d failures/%d checks)"%[failures.size(),checks]); quit(1)
