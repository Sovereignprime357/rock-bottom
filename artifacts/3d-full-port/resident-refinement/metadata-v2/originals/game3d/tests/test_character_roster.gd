extends SceneTree

const Roster = preload("res://scripts/character_roster.gd")
const Animator = preload("res://scripts/actor_animation.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var visuals := Roster.supported_visuals()
	_check(visuals.size() == 72,"B3 advertises72 authored templates for63 canonical rows, keeping variants/helpers separate")
	_mapping()
	_site_mapping()
	_check(Roster.create(&"unbuilt_bird") == null and Roster.definition(&"unbuilt_bird").is_empty(),"unsupported identities cannot silently become generic models")
	var copy := Roster.definition(&"tony")
	copy.height = 99.0
	copy.actions.clear()
	_check(float(Roster.definition(&"tony").height) < 3.0 and not Roster.definition(&"tony").actions.is_empty(),"definition edits cannot corrupt the immutable roster")
	var completed_models: int = 0
	var cold_total: int = 0
	var warm_total: int = 0
	for id: String in visuals:
		var started := Time.get_ticks_usec()
		var first := Roster.create(StringName(id),17)
		var cold := Time.get_ticks_usec()-started
		started = Time.get_ticks_usec()
		var second := Roster.create(StringName(id),17)
		var warm := Time.get_ticks_usec()-started
		cold_total += cold
		warm_total += warm
		print("BUILD %s: first=%.3fms cached=%.3fms" % [id,float(cold)/1000.0,float(warm)/1000.0])
		_check(first != null and second != null,id+": both complete model instances construct successfully")
		if first == null or second == null:
			if first != null: first.free()
			if second != null: second.free()
			continue
		root.add_child(first)
		root.add_child(second)
		await process_frame
		var geometry_complete := _geometry(first,second,id)
		var animation_complete := _animation(first,second,id)
		var budget_complete: bool = true
		if id in ["tony","cop","brutus","pigeon","price_guy","model_family","horsecop","raccoon_quorum"]: budget_complete = _presentation_budget(first,second,id)
		_check(geometry_complete and animation_complete and budget_complete,id+": all applicable gate sections reach completion without a script abort")
		if geometry_complete and animation_complete and budget_complete: completed_models += 1
		first.free()
		second.free()
	_check(completed_models == visuals.size(),"every advertised visual completes construction, geometry and animation checks")
	print("ROSTER BUILD TOTAL: first=%.3fms cached=%.3fms (lazy per identity; companion templates may already be warm)" % [float(cold_total)/1000.0,float(warm_total)/1000.0])
	if failures.is_empty():
		print("3D CHARACTER ROSTER GATE: PASS (%d checks; B1/B2/B3 cast, exact actor/site mappings, shared resources/independent poses, finite joints/UVs and current actions)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D CHARACTER ROSTER GATE: FAIL (%d / %d checks)" % [failures.size(),checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)


func _presentation_budget(first: Node3D, second: Node3D, id: String) -> bool:
	Animator.reset(first)
	Animator.reset(second)
	var rig: Dictionary = first.get_meta("roster_rig")
	var other: Dictionary = second.get_meta("roster_rig")
	var origin := first.transform
	if id == "tony":
		var snapshot := {"action":&"inspect","action_phase":0.0,"ambient_action":true,"local_velocity":Vector3(0,0,0.4)}
		for frame: int in range(60):
			snapshot.action_phase = fmod(float(frame)*0.097,1.0)
			Animator.tick(first,1.0/60.0,snapshot,0)
			Animator.tick(second,1.0/60.0,snapshot,2)
		_check(int(other.pose_updates) < int(rig.pose_updates)/2 and int(other.finger_updates) == 0,"ambient distant gestures reduce poses and fingers without treating the gesture as a combat action")
		_check(is_equal_approx(float(rig.time),float(other.time)) and is_equal_approx(float(rig.phase),float(other.phase)),"ambient scheduling consumes actual time and travel on every call")
		snapshot.action_phase = 0.93
		var untouched := snapshot.duplicate(true)
		Animator.tick(first,1.0/60.0,snapshot,0)
		Animator.tick(second,1.0/60.0,snapshot,0)
		_check(_max_motion(_posed_vertices(first),_posed_vertices(second)) < 0.00001 and snapshot == untouched,"far-to-near return matches current unthrottled geometry after repeated phase wraps without mutating the snapshot")
		Animator.reset(first)
		Animator.tick(first,0.02,snapshot,1)
		_check(int(rig.finger_updates) == 0,"mid-distance ambient gestures suppress finger cosmetics")
		snapshot.ambient_action = false
		Animator.tick(first,0.02,snapshot,2)
		_check(int(rig.finger_updates) == 1,"changing the same gesture from ambient to accepted restores fingers immediately")
		for malformed: Variant in [null,"true",1,{},[]]:
			Animator.reset(first)
			Animator.reset(second)
			for phase: float in [0.12,0.81]:
				Animator.tick(first,0.02,{"action":&"inspect","action_phase":phase},2)
				Animator.tick(second,0.02,{"action":&"inspect","action_phase":phase,"ambient_action":malformed},2)
			_check(int(other.pose_updates) == 2 and _max_motion(_posed_vertices(first),_posed_vertices(second)) < 0.00001,"malformed ambient provenance behaves as false: "+str(malformed))
		# The second call lies between distant slots. Each transition must still
		# refresh, including changing positive envelopes rather than only flags.
		for patch: Dictionary in [{"action":&"talk"},{"action_serial":7},{"contact":true},{"grounded":false},{"coat_count":2},{"hurt":0.3},{"dead":true,"death_phase":0.2}]:
			Animator.reset(first)
			var current := {"action":&"inspect","ambient_action":true,"action_phase":0.2}
			Animator.tick(first,0.02,current,2)
			var updates := int(rig.pose_updates)
			current.merge(patch,true)
			Animator.tick(first,0.02,current,2)
			_check(int(rig.pose_updates) == updates+1,"distant ambient pose refreshes immediately on current "+str(patch.keys()))
		for envelope: String in ["hurt","death_phase"]:
			Animator.reset(first)
			var current := {"action":&"inspect","ambient_action":true,"dead":envelope == "death_phase"}
			current[envelope] = 0.2
			Animator.tick(first,0.02,current,2)
			var previous := _posed_vertices(first)
			var updates := int(rig.pose_updates)
			current[envelope] = 0.8
			Animator.tick(first,0.02,current,2)
			_check(int(rig.pose_updates) == updates+1 and _max_motion(previous,_posed_vertices(first)) > 0.01,"positive "+envelope+" changes remain immediate between distant ambient slots")
		Animator.reset(first)
		Animator.reset(second)
		for coats: int in [0,2,2,0]:
			var before := int(rig.visibility_writes)
			var previous := int(rig.last_coats)
			Animator.tick(first,0.02,{"coat_count":coats,"action":&"inspect","ambient_action":true},2)
			var visible_correct: bool = true
			for layer: int in range(1,4):
				for mesh: MeshInstance3D in rig.layers[layer]: visible_correct = visible_correct and mesh.visible == (layer <= coats)
			_check(visible_correct and (int(rig.visibility_writes) == before if coats == previous else int(rig.visibility_writes) > before),"coat visibility applies immediately and repeated counts avoid engine writes: "+str(coats))
		Animator.reset(first)
		Animator.tick(first,0.02,{"coat_count":0,"ambient_action":true},2)
		var reset_correct: bool = true
		for layer: int in range(1,4):
			for mesh: MeshInstance3D in rig.layers[layer]: reset_correct = reset_correct and not mesh.visible
			for mesh: MeshInstance3D in other.layers[layer]: reset_correct = reset_correct and mesh.visible
		_check(reset_correct,"Tony zero coats, reset, zero coats restores the visibility cache without changing another Tony")
	if id in ["tony","cop","brutus","pigeon"]:
		for action: StringName in [&"windup",&"strike",&"grab",&"throw",&"lunge",&"bite",&"taser"]:
			if action not in rig.definition.actions: continue
			Animator.reset(first)
			Animator.reset(second)
			for phase: float in [0.12,0.81]:
				Animator.tick(first,0.02,{"action":action,"action_phase":phase},2)
				Animator.tick(second,0.02,{"action":action,"action_phase":phase,"ambient_action":true},2)
			var fingers: bool = int(other.finger_updates) == 2 if rig.definition.family == "human" else true
			_check(int(other.pose_updates) == 2 and fingers and _max_motion(_posed_vertices(first),_posed_vertices(second)) < 0.00001,id+": ambient flag cannot throttle, alter or uncurl accepted "+String(action))
	if id == "price_guy":
		Animator.tick(first,0.02,{},0)
		var before := int(rig.bone_writes)
		var rest := _poses(first)
		Animator.tick(first,0.02,{"gaze":Vector2(0.000004,0)},0)
		var tiny := _poses(first)
		_check(int(rig.bone_writes) > before and tiny != rest,"exact transform cache preserves an authored four-microradian gaze change")
		before = int(rig.bone_writes)
		Animator.tick(first,0.02,{"gaze":Vector2(0.000004,0)},0)
		_check(int(rig.bone_writes) == before and _poses(first) == tiny,"identical stationary transforms cause no redundant engine bone writes")
		Animator.tick(first,0.02,{},0)
		_check(int(rig.bone_writes) > before and _poses(first) == rest,"cached targets do not alias mutable pose scratch storage")
	if id in ["model_family","horsecop","raccoon_quorum"]:
		var start := _posed_vertices(first)
		var before := _bone_writes(first)
		var action: StringName = &"vote" if id == "raccoon_quorum" else &"talk"
		for frame: int in range(25):
			var snapshot := {"action":action,"ambient_action":true,"action_phase":fmod(float(frame)*0.13,1.0),"hurt":0.8 if id == "model_family" else 0.0}
			Animator.tick(first,0.02,snapshot,0)
			Animator.tick(second,0.02,snapshot,2)
		var clocks: bool = true
		for child: Dictionary in other.companions:
			var child_rig: Dictionary = child.node.get_meta("roster_rig")
			clocks = clocks and is_equal_approx(float(child_rig.time),float(other.time))
		_check(clocks,id+": child clocks consume every snapshot while parent ambient poses are skipped")
		if id == "model_family": _check(_bone_writes(first) == before and _max_motion(start,_posed_vertices(first)) < 0.000001,"inert family and furniture remain frozen with zero redundant bone writes under active hurt snapshots")
		Animator.tick(first,0.02,{"action":action,"ambient_action":true,"action_phase":0.93},0)
		Animator.tick(second,0.02,{"action":action,"ambient_action":true,"action_phase":0.93},0)
		_check(_max_motion(_posed_vertices(first),_posed_vertices(second)) < 0.00001,id+": current child geometry and attachments match the near reference on return")
	Animator.reset(first)
	var restored := _poses(first)
	Animator.reset(first)
	_check(int(rig.bone_writes) == 0 and _poses(first) == restored and first.transform == origin,id+": repeated reset keeps the authored pose without redundant bone writes or root movement")
	return true


func _bone_writes(art: Node3D) -> int:
	var rig: Dictionary = art.get_meta("roster_rig")
	var result := int(rig.bone_writes)
	for child: Dictionary in rig.companions: result += _bone_writes(child.node)
	return result


func _mapping() -> void:
	var actors: Dictionary = Content.load_content().actors
	_check(actors.base.size() == 41 and actors.day1.size() == 56,"coverage uses the actual exported base and day-one actor records")
	var mapped: bool = true
	var canonical: Dictionary = {}
	for actor: Dictionary in actors.day1:
		var visual := Roster.visual_for_actor(actor)
		mapped = mapped and not visual.is_empty() and not Roster.definition(visual).is_empty()
		canonical[String(actors.aliases.get(actor.name,actor.name))] = true
	_check(mapped and canonical.size() == 42,"all 56 day-one instances resolve to the 42 actual canonical names")
	for pair: Array in [["laundromat_lady","launderlady"],["meter_maid","metermaid"],["food_truck","foodtruck"],["priests_son","priestson"]]:
		var matched: bool = false
		for actor: Dictionary in actors.base:
			if actor.id == pair[0]: matched = Roster.visual_for_actor(actor) == StringName(pair[1])
		_check(matched,"source ID/sprite distinction remains explicit: "+pair[0])
	var fallen := {"id":"omalley_fallen","name":"FATHER O'MALLEY (FALLEN)","sprite":"priest","isOmalleyFallen":true}
	_check(Roster.visual_for_actor(fallen) == &"priest_fallen" and Roster.visual_for_actor({"name":"FATHER O'MALLEY","sprite":"priest"}) == &"priest","fallen identity wins while the source sprite remains priest")
	var guards: bool = true
	for sprite: String in ["blue_tarp_guard","receipt_guard","wire_guard"]: guards = guards and Roster.visual_for_actor({"name":"KNIGHT EMERITUS","sprite":sprite,"kingdomGuard":true}) == StringName(sprite)
	_check(guards,"Knight Emeritus retains each explicit source uniform variant")
	_check(Roster.visual_for_actor({"name":"UNKNOWN","sprite":"tony"}).is_empty() and Roster.visual_for_actor({"name":"TRE BAG TONY","sprite":"pete"}).is_empty() and Roster.visual_for_actor({"name":42,"sprite":"pete"}).is_empty(),"unknown, conflicting and malformed identities never become a generic actor")
	_check(Roster.visual_for_actor({"name":"DENNIS (NIGHTS)","sprite":"lurch"}).is_empty(),"site-only identities cannot resolve through unrelated actor sprite aliases")
	_mapping_b2()


func _mapping_b2() -> void:
	var cases := [
		[{"id":"cop_3d_19","name":"COP","sprite":"cop","archetype":"cop","isCop":true},&"cop"],
		[{"id":"brendan_3d_20","name":"COUSIN BRENDAN","sprite":"brendan","isBrendan":true},&"brendan"],
		[{"id":"sherri_3d_21","name":"SPIDER-BITE SHERRI","sprite":"sherri","archetype":"swarmer"},&"sherri"],
		[{"id":"freed_dog_follower","name":"THE DOG","sprite":"scrap_dog","isPet":true},&"scrap_dog"],
		[{"id":"pet_possum","name":"YOUR POSSUM","sprite":"possum","isPet":true},&"possum"],
		[{"id":"bus_driver","name":"THE BUS DRIVER","sprite":"lurch","isBusDriver":true},&"bus_driver"],
		[{"id":"day3_visitor_888","name":"SOMEONE YOU DON'T KNOW","sprite":"lurch","isDay3Visitor":true},&"day3_visitor"],
		[{"id":"price_guy","name":"THE PRICE GUY","sprite":"price_guy"},&"price_guy"],
		[{"id":"os_brutus","name":"OLD SCHOOL BRUTUS","sprite":"os_brutus","isOsBrutus":true},&"os_brutus"]]
	for entry: Array in cases: _check(Roster.visual_for_actor(entry[0]) == entry[1],"B2 exact source identity: "+String(entry[0].id))
	for hostile: bool in [false,true]:
		var older := {"id":"brutus_older","name":"BRUTUS THE OLDER","sprite":"brutus","isBossB":true,"scale":1.5,"hostile":hostile,"archetype":"charger_older" if hostile else "passive"}
		_check(Roster.visual_for_actor(older) == &"brutus_older","Brutus Older keeps his own scaled body in passive and boss states")
	_check(Roster.definition(&"brutus_older").height > Roster.definition(&"brutus").height*1.4 and Roster.definition(&"brutus_older").source_scale_baked == 1.5,"Older advertises the already-authored source scale so bindings can avoid double scaling")
	for ruler: Array in [["DARRYL UNDER BLUE","darryl_under_blue"],["GENERAL RECEIPT","general_receipt"],["BISHOP WIRE","bishop_wire"],["THE CURB EMPEROR","curb_emperor"]]:
		_check(Roster.visual_for_actor({"name":ruler[0],"sprite":ruler[1],"kingdomBoss":true}) == StringName(ruler[1]),"ruler canonical mapping: "+ruler[0])
	for uniform: Array in [["blue_tarp_guard","pretender_tarp"],["receipt_guard","pretender_receipt"],["wire_guard","pretender_wire"]]:
		_check(Roster.visual_for_actor({"id":"curb_pretender_99","name":"CURB PRETENDER No. 137","sprite":uniform[0],"kingdomPretender":true}) == StringName(uniform[1]),"generated pretender preserves uniform: "+uniform[0])
	var malformed: bool = true
	for name_text: String in ["CURB PRETENDER No. 0","CURB PRETENDER No. -1","CURB PRETENDER No. 01","CURB PRETENDER No. N","CURB PRETENDER No. 1 extra"]:
		malformed = malformed and Roster.visual_for_actor({"name":name_text,"sprite":"blue_tarp_guard"}).is_empty()
	_check(malformed and Roster.visual_for_actor({"name":"CURB PRETENDER No. 1","sprite":"tony"}).is_empty(),"pretender generated family rejects invalid numbers and wrong source uniforms")
	_check(Roster.visual_for_actor({"name":"COP","sprite":"brendan"}).is_empty() and Roster.visual_for_actor({"name":"BRUTUS THE OLDER","sprite":"os_brutus"}).is_empty(),"known B2 names still reject mismatched sprite identities")


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		if child is MeshInstance3D: result.append(child as MeshInstance3D)
		result.append_array(_meshes(child))
	return result


func _no_gameplay(node: Node) -> bool:
	if node is CollisionObject3D or node is Timer or node is AudioStreamPlayer or node is AudioStreamPlayer3D: return false
	for child: Node in node.get_children():
		if not _no_gameplay(child): return false
	return true


func _geometry(first: Node3D, second: Node3D, id: String) -> bool:
	var a := _meshes(first)
	var b := _meshes(second)
	var rig: Dictionary = first.get_meta("roster_rig")
	var skeleton: Skeleton3D = rig.skeleton
	var human: bool = rig.definition.family == "human"
	var object_actor: bool = rig.definition.family in ["object","assembly"]
	var cached: bool = a.size() == b.size()
	var finite: bool = true
	var weights_valid: bool = true
	var uv_valid: bool = true
	var oriented: bool = true
	var weighted_vertices: int = 0
	var blended_vertices: int = 0
	var max_influences: int = 0
	var triangles: int = 0
	var surfaces: int = 0
	for mesh_index: int in range(a.size()):
		var item: MeshInstance3D = a[mesh_index]
		cached = cached and item.mesh == b[mesh_index].mesh and item.skin == b[mesh_index].skin and item.material_override == b[mesh_index].material_override
		for surface: int in range(item.mesh.get_surface_count()):
			surfaces += 1
			var arrays: Array = item.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			triangles += floori(float(count)/3.0)
			finite = finite and vertices.size() == normals.size()
			for i: int in range(vertices.size()): finite = finite and vertices[i].is_finite() and normals[i].is_finite()
			for i: int in range(0,count,3):
				var ia: int = indices[i] if not indices.is_empty() else i
				var ib: int = indices[i+1] if not indices.is_empty() else i+1
				var ic: int = indices[i+2] if not indices.is_empty() else i+2
				var outward := -(vertices[ib]-vertices[ia]).cross(vertices[ic]-vertices[ia])
				if outward.length_squared() < 0.000000000001: continue
				# Legacy rigid heads retain zero-area pole triangles. Unit/outward
				# requirements apply to triangles that can actually be rendered.
				for index: int in [ia,ib,ic]: oriented = oriented and normals[index].dot(outward) > 0.0 and absf(normals[index].length()-1.0) < 0.002
			if item.skin == null: continue
			var mesh_skeleton := item.get_node(item.skeleton) as Skeleton3D
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			weights_valid = weights_valid and bones.size() == vertices.size()*4 and weights.size() == vertices.size()*4
			uv_valid = uv_valid and uvs.size() == vertices.size()
			for uv: Vector2 in uvs: uv_valid = uv_valid and uv.is_finite() and absf(uv.x) < 4.0 and absf(uv.y) < 4.0
			for vertex: int in range(vertices.size()):
				var total: float = 0.0
				var influences: int = 0
				for slot: int in range(4):
					var offset := vertex*4+slot
					weights_valid = weights_valid and bones[offset] >= 0 and bones[offset] < mesh_skeleton.get_bone_count() and is_finite(weights[offset]) and weights[offset] >= 0.0
					total += weights[offset]
					if weights[offset] > 0.00001: influences += 1
				weights_valid = weights_valid and absf(total-1.0) < 0.0001
				weighted_vertices += 1
				if influences > 1: blended_vertices += 1
				max_influences = maxi(max_influences,influences)
	var metrics: Dictionary = first.get_meta("roster_metrics")
	var total_bones := _bone_count(first)
	print("ROSTER %s: family=%s meshes=%d surfaces=%d triangles=%d bones=%d max_weights=%d blended_vertices=%d" % [id,rig.definition.family,a.size(),surfaces,triangles,total_bones,max_influences,blended_vertices])
	_check(cached,id+": instances share meshes, skins and materials")
	_check(finite and oriented,id+": geometry has finite unit outward normals")
	_check(weights_valid and (object_actor or weighted_vertices > 100 and blended_vertices > 50) and max_influences <= 4,id+": normalized bounded skin influences actually blend articulated surfaces (flat objects are rigid)")
	_check(uv_valid,id+": deforming surfaces carry finite fixed UVs")
	var minimum_bones: int = 24 if human else (2 if rig.definition.family == "assembly" else (3 if object_actor else (12 if rig.definition.family == "bird" else 18)))
	_check(triangles > (100 if object_actor else 600) and triangles < 40000 and skeleton.get_bone_count() >= minimum_bones,id+": useful bounded geometry and a family-appropriate bone hierarchy")
	_check(metrics.meshes == a.size() and metrics.surfaces == surfaces and metrics.triangles == triangles and metrics.bones == total_bones,id+": reported metrics include child skeletons and all weighted/attached geometry")
	_check(first.has_node("head") and _no_gameplay(first),id+": stable head handle and presentation-only node ownership")
	var rest_vertices := _posed_vertices(first)
	_check(_bounded(rest_vertices,Vector3(1.3,3.3,1.8)),id+": actual rest geometry fits its broad actor envelope")
	if id == "pigeon": _check(first.has_node("single_leg") and not first.has_node("right_leg"),"pigeon anatomy has the source's one foot")
	if id in ["dogwalker","horsecop"]:
		_check(rig.companions.size() == 1 and (rig.companions[0].node as Node3D).has_meta("roster_rig") and total_bones > skeleton.get_bone_count(),id+": companion is an actual independently rigged animal/person")
	_signatures(first,id,rest_vertices)
	if bool(rig.definition.get("site_resident",false)): _site_signatures(first,id)
	return true


func _signatures(art: Node3D, id: String, rest_vertices: PackedVector3Array) -> void:
	var held := {"sherri":["phone"],"dave":["pillow"],"mom":["kombucha","tote"],"conductor":["ticket_punch","timetable"],"stripe":["soap_package"],"cubscout":["popcorn"],"jogger":["stopwatch"],"dogwalker":["leash_handle","paisley"],"busker":["guitar"],"vapelord":["spectrum_device"],"mayorscousin":["bread_phone"],"phoneguy":["phone"],"barb":["crossword","hard_purse"],"math":["equation_board","pencil"],"philosopher":["cane"],"lease_guy":["clipboard","key_ring"],"gutter_greg":["inventory_hook","rubber_duck"],"launderlady":["laundry_basket"],"metermaid":["ticket_book","personal_meter"],"foodtruck":["order_pad","spatula"],"priestson":["cassette_player"],"karaoke":["microphone","karaoke_machine"],"blue_tarp_guard":["bucket_lid"],"receipt_guard":["cart_fork"],"wire_guard":["wire_coil"],"horsecop":["mounted_rider"],"pigeon":["left_wing","right_wing","single_leg"],"pothole":["mouth"]}
	held.merge({"cop":["radio","coffee"],"brendan":["radio","taser"],"bus_driver":["ticket_roll","route_sheet"],"darryl_under_blue":["ruler_bucket_lid"],"general_receipt":["receipt_scroll","head/paper_crown"],"bishop_wire":["antenna_crozier","head/antenna_mitre"],"curb_emperor":["broken_ruler","folding_chair","head/curb_crown"],"pretender_tarp":["petition","bucket_lid","head/paper_crown"],"pretender_receipt":["petition","cart_fork","head/paper_crown"],"pretender_wire":["petition","wire_coil","head/paper_crown"]})
	if held.has(id):
		var present: bool = true
		for label: String in held[id]: present = present and art.has_node(NodePath(label))
		_check(present,id+": source signature props/companions survive packing as actual geometry handles")
	if id == "paulie":
		var head := art.get_node("head") as Node3D
		var min_x: float = INF
		var max_x: float = -INF
		for part: MeshInstance3D in _meshes(head):
			var transform := Roster._relative(part,art)
			for surface: int in range(part.mesh.get_surface_count()):
				var arrays := part.mesh.surface_get_arrays(surface)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					var point: Vector3 = transform*vertex
					min_x = minf(min_x,point.x)
					max_x = maxf(max_x,point.x)
		_check(max_x-min_x > 0.58,"Paulie's face has actual oversized breadth, not only a named profile or recolor")
	if id in ["biggu","cubscout"]:
		var high: float = 0.0
		for point: Vector3 in rest_vertices: high = maxf(high,point.y)
		_check(high > 2.10 if id == "biggu" else high < 1.55,id+": authored stature survives the shared anatomical builder")
	if Roster.definition(StringName(id)).get("hair","") in ["hood","tarp_hood"]:
		var head := art.get_node("head") as Node3D
		var roof: float = -INF
		for part: MeshInstance3D in _meshes(head):
			var transform := Roster._relative(part,head)
			for surface: int in range(part.mesh.get_surface_count()):
				var arrays := part.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices := PackedInt32Array()
				if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					for i: int in range(vertices.size()): indices.append(i)
				for i: int in range(0,indices.size()-2,3):
					var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(0,0.6,0),Vector3(0,0.2,0),transform*vertices[indices[i]],transform*vertices[indices[i+1]],transform*vertices[indices[i+2]])
					if hit is Vector3: roof = maxf(roof,hit.y)
		_check(roof > 0.27,id+": actual cloth triangles close the hood above the scalp")


func _bone_count(node: Node) -> int:
	var total: int = (node as Skeleton3D).get_bone_count() if node is Skeleton3D else 0
	for child: Node in node.get_children(): total += _bone_count(child)
	return total


func _posed_vertices(art: Node3D, selected_bone: int = -1, only_skinned: bool = false) -> PackedVector3Array:
	var rig: Dictionary = art.get_meta("roster_rig")
	var result := PackedVector3Array()
	for part: MeshInstance3D in _meshes(art):
		if not part.is_visible_in_tree(): continue
		var local := Roster._relative(part,art)
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if part.skin == null:
				if selected_bone < 0 and not only_skinned:
					for vertex: Vector3 in vertices: result.append(local*vertex)
				continue
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var skeleton := part.get_node(part.skeleton) as Skeleton3D
			if selected_bone >= 0 and skeleton != rig.skeleton: continue
			var palette: Array[Transform3D] = []
			for i: int in range(part.skin.get_bind_count()): palette.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(i))*part.skin.get_bind_pose(i))
			for vertex: int in range(vertices.size()):
				var point := Vector3.ZERO
				var relevant: bool = selected_bone < 0
				for slot: int in range(4):
					var offset := vertex*4+slot
					point += (palette[bones[offset]]*vertices[vertex])*weights[offset]
					if bones[offset] == selected_bone and weights[offset] > 0.25: relevant = true
				if relevant: result.append(local*point)
	return result


func _bounded(vertices: PackedVector3Array, extent: Vector3) -> bool:
	if vertices.is_empty(): return false
	for vertex: Vector3 in vertices:
		if not vertex.is_finite() or absf(vertex.x) > extent.x or vertex.y < -0.35 or vertex.y > extent.y or absf(vertex.z) > extent.z: return false
	return true


func _poses(art: Node3D) -> Array[Transform3D]:
	var skeleton := art.get_node("Skeleton") as Skeleton3D
	var result: Array[Transform3D] = []
	for i: int in range(skeleton.get_bone_count()): result.append(skeleton.get_bone_pose(i))
	return result


func _max_motion(before: PackedVector3Array, after: PackedVector3Array) -> float:
	if before.size() != after.size(): return INF
	var distance: float = 0.0
	for i: int in range(before.size()): distance = maxf(distance,before[i].distance_to(after[i]))
	return distance


func _animation(first: Node3D, second: Node3D, id: String) -> bool:
	var rig: Dictionary = first.get_meta("roster_rig")
	if bool(rig.definition.get("site_resident",false)):
		_site_state(first,second,id)
		_site_hand_contacts(first,id)
		return true
	if rig.definition.family in ["bird","object"]: return _special_animation(first,second,id)
	var other: Dictionary = second.get_meta("roster_rig")
	var human: bool = rig.definition.family == "human"
	var initial := _poses(first)
	var origin := first.transform
	var resources := _meshes(first)
	var elbow: int = rig.lookup["right_elbow" if human else "front_left_knee"]
	var rest_joint := _posed_vertices(first,elbow)
	var request := {"action":&"windup","action_phase":1.0,"local_velocity":Vector3.ZERO,"coat_count":3}
	var saved_request := request.duplicate(true)
	Animator.tick(first,1.0/60.0,request)
	_check(request == saved_request and first.transform == origin,id+": presentation cannot modify snapshot or actor origin")
	_check(_poses(second) == initial and rig.skeleton != other.skeleton,id+": independent skeleton poses cannot cross between cached instances")
	if human: _check(_max_motion(rest_joint,_posed_vertices(first,elbow)) > 0.03,id+": accepted windup deforms actual elbow geometry")
	Animator.reset(first)
	if human:
		var finger: int = rig.lookup["right_fingertips"]
		var open_extent := _finger_extent(first,finger,"right_wrist")
		Animator.tick(first,1.0/60.0,{"action":&"strike","action_phase":0.03,"contact":true,"action_serial":0})
		var skeleton: Skeleton3D = rig.skeleton
		var shoulder := skeleton.get_bone_global_pose(rig.lookup["right_shoulder"]).origin
		var wrist := skeleton.get_bone_global_pose(rig.lookup["right_wrist"]).origin
		_check(wrist.y > shoulder.y-0.18 and wrist.z > shoulder.z+0.25,id+": peak strike extends a nearly level hand toward actor +Z")
		var closed_extent := _finger_extent(first,finger,"right_wrist")
		_check(closed_extent > open_extent+0.015,id+": peak strike curls actual finger geometry into a shorter grip (open %.5f, closed %.5f)" % [open_extent,closed_extent])
		Animator.reset(first)
	var knee: int = rig.lookup["left_knee" if human else "front_left_knee"]
	var knee_rest := _posed_vertices(first,knee)
	var motion: float = 0.0
	var safe: bool = true
	for frame: int in range(12):
		Animator.tick(first,1.0/60.0,{"local_velocity":Vector3(0,0,1.6)})
		if frame%3 == 0:
			motion = maxf(motion,_max_motion(knee_rest,_posed_vertices(first,knee)))
			safe = safe and _bounded(_posed_vertices(first),Vector3(1.5,3.0,1.8))
	if id == "mounted_rider": _check(motion < 0.015 and safe,"mounted rider keeps a seated leg pose while its parent supplies travel")
	else: _check(motion > 0.015 and safe,id+": actual +Z travel bends weighted knees within the actor envelope")
	for frame: int in range(90): Animator.tick(first,1.0/60.0,{"local_velocity":Vector3.ZERO})
	_check(float(rig.motion) < 0.001,id+": stopped motion settles without input-driven walking")
	Animator.reset(first)
	Animator.reset(second)
	for frame: int in range(120):
		Animator.tick(first,1.0/60.0,{},0)
		Animator.tick(second,1.0/60.0,{},2)
	_check(int(other.pose_updates) < int(rig.pose_updates)/2 and is_equal_approx(float(other.time),float(rig.time)),id+": distant detail reduces pose work while consuming active time")
	if human: _check(int(other.finger_updates) == 0 and int(rig.finger_updates) > 0,id+": distant detail suppresses finger cosmetics")
	Animator.tick(second,1.0/60.0,{"action":&"windup","action_phase":1.0},2)
	var wound := _poses(second)
	Animator.tick(second,1.0/60.0,{"action":&"strike" if human else &"bite","action_phase":1.0},2)
	_check(_poses(second) != wound,id+": current action phase replaces a far-away pose immediately")
	Animator.tick(second,1.0/60.0,{"dead":true,"death_phase":1.0},2)
	var fallen_vertices := _posed_vertices(second)
	_check(_bounded(fallen_vertices,Vector3(3.6,4.0,3.6)) and second.transform == Transform3D.IDENTITY,id+": death changes visual bones without moving the actor")
	if id in ["philosopher","receipt_guard","pretender_receipt","bishop_wire"]:
		var prop := second.get_node("cane" if id == "philosopher" else ("antenna_crozier" if id == "bishop_wire" else "cart_fork")) as Node3D
		_check(_minimum_y(_rigid_vertices(prop,second)) >= -0.05,id+": the actual long tool rests above ground after the owner collapses")
	if id == "curb_emperor": _check(_minimum_y(_rigid_vertices(second.get_node("folding_chair") as Node3D,second)) >= -0.05,"the emperor's actual folding chair stays above ground through collapse")
	if id == "launderlady":
		var basket := second.get_node("laundry_basket") as Node3D
		var grounded_basket: bool = true
		for phase: float in [0.25,0.50,0.75,1.0]:
			Animator.tick(second,1.0/60.0,{"dead":true,"death_phase":phase},2)
			grounded_basket = grounded_basket and _minimum_y(_rigid_vertices(basket,second)) >= -0.05
		_check(grounded_basket and basket.basis.y.dot(Vector3.UP) > 0.99,"Laundry Lady's actual released basket settles upright above ground throughout collapse")
	if id == "dogwalker":
		var companion := second.get_node("paisley") as Node3D
		_check(companion.basis.is_equal_approx(Basis.IDENTITY) and _minimum_y(_posed_vertices(companion)) >= -0.05,"Paisley collapses once above ground without inheriting the owner's visual root fall")
	var uncropped := _skin_inside_bounds(second)
	for state: Dictionary in [{"action":&"windup","action_phase":1.0},{"action":&"throw" if human else &"lunge","action_phase":0.0}]:
		Animator.tick(second,1.0/60.0,state,0)
		uncropped = uncropped and _skin_inside_bounds(second)
	_check(uncropped,id+": actual weighted death/extended geometry stays within its render culling bounds")
	Animator.tick(second,1.0/60.0,{},0)
	_check(_poses(second) != wound and absf((other.skeleton as Skeleton3D).get_bone_pose_rotation(0).get_euler().x) < 0.01,id+": return to near detail clears stale death/action transforms")
	Animator.reset(first)
	var before := _poses(first)
	for invalid: float in [NAN,INF,0.0,-1.0]: Animator.tick(first,invalid,{"action":&"windup","action_phase":1.0})
	_check(before == _poses(first),id+": malformed time does not advance poses")
	Animator.tick(first,1000.0,{"local_velocity":Vector3(NAN,INF,-INF),"turn_rate":INF,"gaze":Vector2(NAN,INF),"hurt":NAN,"action":{},"coat_count":"bad","death_phase":INF},2)
	_check(_bounded(_posed_vertices(first),Vector3(3.6,4.0,3.6)),id+": malformed pose input stays finite and bounded")
	Animator.reset(first)
	_check(_poses(first) == initial and first.transform == origin and _meshes(first).size() == resources.size(),id+": reset restores rest without changing cached resources or node count")
	if id == "tony":
		for coats: int in range(4):
			Animator.tick(first,1.0/60.0,{"coat_count":coats},2)
			var correct: bool = true
			for layer: int in range(1,4):
				correct = correct and not (rig.layers[layer] as Array).is_empty()
				for mesh: MeshInstance3D in rig.layers[layer]: correct = correct and mesh.visible == (layer <= coats)
			_check(correct,"Tony: exact %d-coat visibility applies at distant detail" % coats)
		Animator.reset(first)
		Animator.tick(first,1.0/60.0,{"coat_count":0})
		var skin_vertices := _posed_vertices(first,-1,true)
		var joined: bool = true
		for side: float in [-1.0,1.0]:
			for x: float in [0.21,0.24,0.27]: joined = joined and _front_covers(skin_vertices,Vector2(side*x,1.38))
		_check(joined,"Tony's bare shoulder silhouette connects the chest and both upper arms")
		var head := first.get_node("head") as Node3D
		var eye_parts: Array[Transform3D] = []
		for mesh: MeshInstance3D in _meshes(head): eye_parts.append(mesh.transform)
		for frame: int in range(180): Animator.tick(first,1.0/60.0,{})
		var unchanged: bool = true
		var index: int = 0
		for mesh: MeshInstance3D in _meshes(head):
			unchanged = unchanged and mesh.transform == eye_parts[index]
			index += 1
		_check(unchanged,"Tony's face parts never blink or change eye scale")
	if id == "pete":
		Animator.reset(first)
		var continuous: bool = true
		for x: float in [-0.10,0.0,0.10]:
			for y: float in [0.70,0.80,0.98,1.11,1.21]:
				continuous = continuous and _front_color(first,Vector2(x,y)).is_equal_approx(Color("b9ad7f"))
		for x: float in [-0.24,-0.20,0.20,0.24]:
			for y: float in [0.70,0.80,0.90,0.98,1.05,1.11]:
				continuous = continuous and _front_color(first,Vector2(x,y)).is_equal_approx(Color("b9ad7f"))
		_check(continuous,"Pete's apron is the visible continuous front surface across its lower panel, belly and bib")
	if id == "dave":
		Animator.reset(first)
		var awake := _poses(first)
		Animator.tick(first,1.0/60.0,{"asleep":true},2)
		_check(_poses(first) != awake and first.transform == Transform3D.IDENTITY,"Dave's authoritative asleep flag selects a horizontal visual pose")
		Animator.tick(first,1.0/60.0,{"asleep":false},2)
		_check(absf((rig.skeleton as Skeleton3D).get_bone_pose_rotation(0).get_euler().z) < 0.05,"Dave wakes immediately at distant detail without an animation-owned sleep timer")
	if bool(rig.definition.get("still",false)):
		Animator.reset(first)
		var still_pose := _poses(first)
		for frame: int in range(20): Animator.tick(first,0.05,{})
		_check(_poses(first) == still_pose and float(rig.time) > 0.9,id+": intentional visual stillness consumes time without cosmetic fidgeting")
		Animator.tick(first,0.04,{"action":&"windup","action_phase":0.8},2)
		_check(_poses(first) != still_pose,id+": a current action overrides intentional idle stillness")
	if not (rig.companions as Array).is_empty():
		var child: Node3D = rig.companions[0].node
		var other_rig: Dictionary = second.get_meta("roster_rig")
		var other_child: Node3D = other_rig.companions[0].node
		var child_start := _poses(other_child)
		Animator.tick(first,0.04,{"local_velocity":Vector3(0,0,2.0),"action":&"windup","action_phase":0.6},2)
		_check(_poses(other_child) == child_start and child.get_node("Skeleton") != other_child.get_node("Skeleton"),id+": child pose ownership never crosses actor instances")
	if id in ["busker","launderlady","math"]: _prop_contacts(first,id)
	return true


func _site_hand_contacts(art: Node3D, id: String) -> void:
	if id not in ["dennis","transit_dan","former_teller","docent","lifeguard_seated"]: return
	var rig: Dictionary = art.get_meta("roster_rig")
	Animator.reset(art)
	if id == "dennis":
		Animator.tick(art,1.0/60.0,{"action":&"inspect","action_phase":0.5})
		var cup := art.get_node("empty_thermos") as Node3D
		var near: bool = true
		for side: String in ["left","right"]:
			var sign_value := -1.0 if side == "left" else 1.0
			near = near and _nearest(_posed_vertices(art,rig.lookup[side+"_fingertips"]),cup.transform*Vector3(sign_value*0.062,-0.025,0)) < 0.065
		_check(near,"Dennis's actual finger geometry supports the empty thermos with both hands")
	elif id == "transit_dan":
		var paper := art.get_node("transfer_slips") as Node3D
		var pencil := art.get_node("pencil") as Node3D
		for phase: float in [0.15,0.80]:
			Animator.tick(art,1.0/60.0,{"action":&"write","action_phase":phase})
			var contact := paper.transform*Vector3(0.04*sin(phase*TAU*3.0),0.01,0.018)
			_check(_nearest(_rigid_vertices(pencil,art),contact) < 0.012,"Dan's actual pencil tip reaches the transfer slip at the current writing phase")
	elif id == "former_teller":
		Animator.tick(art,1.0/60.0,{"action":&"stamp","action_phase":0.5})
		var paper := art.get_node("bank_papers") as Node3D
		var stamp := art.get_node("rubber_stamp") as Node3D
		var contact := paper.transform*Vector3(0.025,0.01,0.018)
		_check(_rigid_segment_hit(stamp,art,contact-paper.basis.z*0.012,contact+paper.basis.z*0.012),"the actual stamp face reaches the paper at the supplied contact phase")
	elif id == "docent":
		Animator.tick(art,1.0/60.0,{"action":&"wave","action_phase":0.5})
		var brochure := art.get_node("brochure") as Node3D
		_check(_nearest(_posed_vertices(art,rig.lookup.left_fingertips),brochure.transform*Vector3(-0.11,-0.02,0.018)) < 0.080,"the docent keeps the actual support hand on the brochure while waving")
	elif id == "lifeguard_seated":
		Animator.tick(art,1.0/60.0,{"action":&"score","action_phase":0.5})
		var card := art.get_node("score_card") as Node3D
		_check(card.basis.z.normalized().dot(Vector3.BACK) > 0.95 and _nearest(_posed_vertices(art,rig.lookup.right_fingertips),card.transform*Vector3(0,0.035,0.02)) < 0.075,"the lifeguard holds the actual score card facing forward within his fingers")
	Animator.reset(art)


func _rigid_segment_hit(node: Node3D, art: Node3D, start: Vector3, end: Vector3) -> bool:
	for part: MeshInstance3D in _meshes(node):
		var transform := Roster._relative(part,art)
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i: int in range(vertices.size()): indices.append(i)
			for i: int in range(0,indices.size()-2,3):
				if Geometry3D.segment_intersects_triangle(start,end,transform*vertices[indices[i]],transform*vertices[indices[i+1]],transform*vertices[indices[i+2]]) is Vector3: return true
	return false


func _nearest(vertices: PackedVector3Array, point: Vector3) -> float:
	var distance: float = INF
	for vertex: Vector3 in vertices: distance = minf(distance,vertex.distance_to(point))
	return distance


func _prop_contacts(art: Node3D, id: String) -> void:
	var rig: Dictionary = art.get_meta("roster_rig")
	var skeleton: Skeleton3D = rig.skeleton
	var action: StringName = {"busker":&"strum","launderlady":&"fold","math":&"write"}[id]
	var root_before := art.transform
	Animator.reset(art)
	var lengths: Array[float] = []
	for side: String in ["left","right"]:
		var shoulder := skeleton.get_bone_global_pose(rig.lookup[side+"_shoulder"]).origin
		var elbow := skeleton.get_bone_global_pose(rig.lookup[side+"_elbow"]).origin
		var wrist := skeleton.get_bone_global_pose(rig.lookup[side+"_wrist"]).origin
		lengths.append(shoulder.distance_to(elbow))
		lengths.append(elbow.distance_to(wrist))
	var first_tip := Vector3.ZERO
	var stroke_span: float = 0.0
	for phase: float in [0.15,0.46,0.80]:
		Animator.tick(art,1.0/60.0,{"action":action,"action_phase":phase})
		var left := _posed_vertices(art,rig.lookup.left_fingertips)
		var right := _posed_vertices(art,rig.lookup.right_fingertips)
		if id == "busker":
			var guitar := art.get_node("guitar") as Node3D
			var neck := _nearest(left,guitar.transform*Vector3(0,0.40,0.030))
			var strings := _nearest(right,guitar.transform*Vector3(0,0.03,0.064))
			_check(neck < 0.075 and strings < 0.075,"Busker %.2f: actual fingers contact the neck and string region (%.4f / %.4fm)" % [phase,neck,strings])
		elif id == "launderlady":
			var basket := art.get_node("laundry_basket") as Node3D
			var left_rim := _nearest(left,basket.transform*Vector3(-0.30,0.07,0))
			var right_rim := _nearest(right,basket.transform*Vector3(0.30,0.07,0))
			_check(basket.basis.y.normalized().dot(Vector3.UP) > 0.98 and left_rim < 0.065 and right_rim < 0.065,"Laundry Lady %.2f: level basket is supported by both actual hands (%.4f / %.4fm)" % [phase,left_rim,right_rim])
		else:
			var board := art.get_node("equation_board") as Node3D
			var pencil := art.get_node("pencil") as Node3D
			var target := board.transform*Vector3(0.02+0.045*sin(phase*TAU*3.0),0.01,0.018)
			var tip_distance := _nearest(_rigid_vertices(pencil,art),target)
			var support := _nearest(left,board.transform*Vector3(-0.13,-0.02,0.018))
			_check(tip_distance < 0.012 and support < 0.080,"Mathematician %.2f: actual pencil tip meets the board and the other hand supports it (%.4f / %.4fm)" % [phase,tip_distance,support])
			var tip: Vector3 = pencil.transform*Vector3(0,0.09,0)
			if phase == 0.15: first_tip = tip
			else: stroke_span = maxf(stroke_span,tip.distance_to(first_tip))
		var unchanged_lengths: bool = true
		var index: int = 0
		for side: String in ["left","right"]:
			var shoulder := skeleton.get_bone_global_pose(rig.lookup[side+"_shoulder"]).origin
			var elbow := skeleton.get_bone_global_pose(rig.lookup[side+"_elbow"]).origin
			var wrist := skeleton.get_bone_global_pose(rig.lookup[side+"_wrist"]).origin
			unchanged_lengths = unchanged_lengths and absf(shoulder.distance_to(elbow)-lengths[index]) < 0.00001 and absf(elbow.distance_to(wrist)-lengths[index+1]) < 0.00001
			index += 2
		_check(unchanged_lengths and art.transform == root_before and _bounded(_posed_vertices(art),Vector3(1.5,3.0,1.8)),id+": contact pose preserves segment lengths, origin and the finite visual envelope")
	if id == "math": _check(stroke_span > 0.01,"supplied writing phase moves the actual pencil across the board")
	Animator.reset(art)


func _special_animation(first: Node3D, second: Node3D, id: String) -> bool:
	var rig: Dictionary = first.get_meta("roster_rig")
	var initial := _poses(first)
	var untouched := _poses(second)
	var before := _posed_vertices(first)
	Animator.tick(first,0.08,{"action":&"talk","action_phase":0.18,"local_velocity":Vector3(0,0,0.9)},0)
	_check(_max_motion(before,_posed_vertices(first)) > 0.001 and _poses(second) == untouched,id+": family-specific geometry moves while other instances stay independent")
	_check(first.transform == Transform3D.IDENTITY and _skin_inside_bounds(first),id+": dedicated rig preserves origin and culling bounds")
	Animator.tick(first,0.04,{"action":&"talk","action_phase":0.61},2)
	var current := _poses(first)
	Animator.tick(first,0.04,{},2)
	_check(_poses(first) != current,id+": far detail consumes action completion without a stale mouth/wing pose")
	for invalid: float in [NAN,INF,-1.0,0.0]: Animator.tick(first,invalid,{"dead":true})
	Animator.tick(first,100.0,{"action":{},"hurt":NAN,"gaze":Vector2(INF,NAN),"local_velocity":Vector3(NAN,INF,-INF)},2)
	_check(_bounded(_posed_vertices(first),Vector3(1.5,2.0,1.5)),id+": malformed snapshots stay finite")
	Animator.reset(first)
	_check(_poses(first) == initial,id+": reset returns every dedicated bone to its authored rest")
	if rig.definition.family == "object":
		Animator.tick(first,0.04,{"dead":true,"death_phase":1.0},0)
		_check(_poses(first) == initial,"pothole never receives a humanoid/animal death collapse")
	return true


func _finger_extent(art: Node3D, bone: int, wrist_name: String) -> float:
	var rig: Dictionary = art.get_meta("roster_rig")
	var skeleton: Skeleton3D = rig.skeleton
	var hand_space := skeleton.get_bone_global_pose(rig.lookup[wrist_name]).affine_inverse()
	var extent: float = INF
	for vertex: Vector3 in _posed_vertices(art,bone): extent = minf(extent,(hand_space*vertex).y)
	return extent


func _minimum_y(vertices: PackedVector3Array) -> float:
	var lowest: float = INF
	for point: Vector3 in vertices: lowest = minf(lowest,point.y)
	return lowest


func _rigid_vertices(node: Node3D, art: Node3D) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for part: MeshInstance3D in _meshes(node):
		var transform := Roster._relative(part,art)
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: vertices.append(transform*vertex)
	return vertices


func _front_covers(vertices: PackedVector3Array, point: Vector2) -> bool:
	# Weighted body surfaces are sequential triangles. Test their actual front
	# projection for the shoulder opening that bounds/weight checks cannot see.
	for i: int in range(0,vertices.size(),3):
		var polygon := PackedVector2Array([Vector2(vertices[i].x,vertices[i].y),Vector2(vertices[i+1].x,vertices[i+1].y),Vector2(vertices[i+2].x,vertices[i+2].y)])
		if Geometry2D.is_point_in_polygon(point,polygon): return true
	return false


func _front_color(art: Node3D, point: Vector2) -> Color:
	# Inspect final weighted triangles, not construction rows. A shirt/button
	# protruding through the apron must be caught as the nearer visible surface.
	var vertices := _posed_vertices(art,-1,true)
	var colors := PackedColorArray()
	for part: MeshInstance3D in _meshes(art):
		if part.skin == null or not part.is_visible_in_tree(): continue
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			colors.append_array(arrays[Mesh.ARRAY_COLOR] as PackedColorArray)
	var nearest: float = -INF
	var color := Color.TRANSPARENT
	for i: int in range(0,vertices.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(point.x,point.y,2.0),Vector3(point.x,point.y,-2.0),vertices[i],vertices[i+1],vertices[i+2])
		if hit is Vector3 and hit.z > nearest:
			nearest = hit.z
			color = colors[i]
	return color


func _skin_inside_bounds(art: Node3D) -> bool:
	for part: MeshInstance3D in _meshes(art):
		if part.skin == null: continue
		var skeleton := part.get_node(part.skeleton) as Skeleton3D
		var palette: Array[Transform3D] = []
		for i: int in range(part.skin.get_bind_count()): palette.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(i))*part.skin.get_bind_pose(i))
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for i: int in range(vertices.size()):
				var point := Vector3.ZERO
				for slot: int in range(4): point += (palette[bones[i*4+slot]]*vertices[i])*weights[i*4+slot]
				if not point.is_finite() or not part.custom_aabb.grow(0.001).has_point(point): return false
	return true


func _site_mapping() -> void:
	var expected := {"copper:cold_not":["dennis (nights)",&"dennis"],"copper:water_dept":["the raccoon quorum",&"raccoon_quorum"],"copper:rust_car":["transit authority dan",&"transit_dan"],"breakin:model_home":["the model family",&"model_family"],"breakin:spoil_bank":["the former teller",&"former_teller"],"breakin:sod_office":["the goose (manager)",&"goose_manager"],"breakin:drained_pool":["the lifeguard (still certified)",&"lifeguard"],"breakin:visitor_center":["the docent (self-guided)",&"docent"]}
	var seen: Dictionary = {}
	for table: Array in [[&"copper","COPPER_SITES"],[&"breakin","BREAKIN_SITES"]]:
		var kind: StringName = table[0]
		for site: Dictionary in Content.definition("src/data/props.js",table[1],[]):
			var key := String(kind)+":"+String(site.id)
			var visual := Roster.visual_for_site(kind,site)
			if not expected.has(key):
				_check(visual.is_empty(),"unlisted source site does not acquire a substitute resident: "+key)
				continue
			var record: Array = expected[key]
			seen[key] = true
			_check(site.who == record[0] and visual == record[1] and not Roster.definition(visual).is_empty(),"B3 resolves the actual exported site identity: "+key)
			var rejected: bool = Roster.visual_for_site(&"breakin" if kind == &"copper" else &"copper",site).is_empty()
			for change: Dictionary in [{"id":"unknown_site"},{"id":null},{"id":42},{"id":StringName(site.id)},{"who":null},{"who":[]},{"who":String(site.who).to_upper()},{"who":"someone else"}]:
				var invalid := site.duplicate(true)
				invalid.merge(change,true)
				rejected = rejected and Roster.visual_for_site(kind,invalid).is_empty()
			_check(rejected and Roster.visual_for_site(&"actor",site).is_empty(),"site resolution rejects malformed, conflicting and cross-table identities: "+key)
			_check(Roster.visual_for_actor({"id":site.id,"name":String(site.who).to_upper(),"sprite":String(visual)}).is_empty(),"site identity cannot impersonate an actor through an invented sprite: "+key)
	_check(seen.size() == 8,"all eight canonical site residents occur in the exported source tables")
	var templates := Roster.Sites.supported_visuals("b3")
	var required := PackedStringArray(["dennis","transit_dan","former_teller","docent","lifeguard_seated","lifeguard","model_father","model_mother","model_son","model_family","quorum_raccoon","raccoon_quorum","goose_body","goose_manager"])
	templates.sort()
	required.sort()
	_check(templates == required,"B3 advertises fourteen concrete templates for eight canonical identities")
	_check(Roster.visual_for_site(&"copper",{}).is_empty() and Roster.visual_for_site(&"breakin",{"id":"model_home"}).is_empty(),"missing site identity fields never resolve")


func _site_signatures(art: Node3D, id: String) -> void:
	var rig: Dictionary = art.get_meta("roster_rig")
	if not bool(rig.definition.get("site_resident",false)): return
	var props := {"dennis":["empty_thermos"],"transit_dan":["transfer_slips","ticket_punch","pencil"],"former_teller":["bank_papers","rubber_stamp","shoe_drawer"],"docent":["brochure"],"lifeguard_seated":["score_card"],"model_son":["raised_toast"],"lifeguard":["head/lifeguard_chair"],"raccoon_quorum":["head/filing_cabinet","head/filing_cabinet/evidence_can"],"model_family":["head/dinner_table","head/empty_fourth_chair"],"goose_manager":["head/manager_desk"]}
	if props.has(id):
		var present: bool = true
		for path: String in props[id]:
			var prop := art.get_node_or_null(NodePath(path)) as Node3D
			present = present and prop != null and not _meshes(prop).is_empty()
		_check(present,id+": source signature handles contain real mesh geometry after packing")
	if id == "goose_body":
		var two_legs: bool = rig.definition.family == "bird" and bool(rig.definition.get("two_feet",false)) and not rig.lookup.has("single_leg")
		for bone: String in ["bird_left","bird_left_knee","bird_left_ankle","bird_right","bird_right_knee","bird_right_ankle"]:
			two_legs = two_legs and rig.lookup.has(bone)
			if rig.lookup.has(bone): two_legs = two_legs and not _posed_vertices(art,rig.lookup[bone]).is_empty()
		_check(two_legs,"the manager goose has two actual weighted leg chains, not the Pigeon King's missing-foot rig")
	if id == "quorum_raccoon":
		var paws: bool = rig.definition.family == "quadruped"
		for bone: String in ["front_left_ankle","front_right_ankle","back_left_ankle","back_right_ankle"]:
			paws = paws and rig.lookup.has(bone)
			if rig.lookup.has(bone): paws = paws and not _posed_vertices(art,rig.lookup[bone]).is_empty()
		_check(paws,"each quorum raccoon has four physical weighted paws")
	if rig.definition.family != "assembly": return
	var expected_children := {"lifeguard":["lifeguard_seated"],"goose_manager":["goose_body"],"model_family":["model_father","model_mother","model_son"],"raccoon_quorum":["raccoon_1","raccoon_2","raccoon_3","raccoon_4","raccoon_5","raccoon_6","raccoon_7"]}
	var child_names: Array[String] = []
	var child_skeletons: Dictionary = {}
	var independent: bool = true
	var support_points := PackedVector3Array()
	for entry: Dictionary in rig.companions:
		var child: Node3D = entry.node
		child_names.append(String(child.name))
		if not child.has_meta("roster_rig"):
			independent = false
			continue
		var child_rig: Dictionary = child.get_meta("roster_rig")
		var skeleton: Skeleton3D = child_rig.skeleton
		independent = independent and skeleton != rig.skeleton and not child_skeletons.has(skeleton.get_instance_id())
		child_skeletons[skeleton.get_instance_id()] = true
		var transform := Roster._relative(child,art)
		var limbs: Array = ["left_hip","right_hip"] if id in ["lifeguard","model_family"] else (["bird_left_ankle","bird_right_ankle"] if id == "goose_manager" else ["front_left_ankle","front_right_ankle","back_left_ankle","back_right_ankle"])
		for bone: String in limbs:
			if not child_rig.lookup.has(bone):
				independent = false
				continue
			if id in ["lifeguard","model_family"]:
				support_points.append(transform*skeleton.get_bone_global_pose(child_rig.lookup[bone]).origin)
			else:
				var foot := _posed_vertices(child,child_rig.lookup[bone])
				var bottom := Vector3(0,INF,0)
				for vertex: Vector3 in foot:
					var point: Vector3 = transform*vertex
					if point.y < bottom.y: bottom = point
				if bottom.is_finite(): support_points.append(bottom)
				else: independent = false
	child_names.sort()
	var required_children: Array = expected_children.get(id,[]).duplicate()
	required_children.sort()
	_check(independent and PackedStringArray(child_names) == PackedStringArray(required_children),id+": exact independently rigged group members survive assembly (seven raccoons / three family figures)")
	var furniture := art.get_node_or_null("head") as Node3D
	var triangles := PackedVector3Array()
	if furniture != null:
		for part: MeshInstance3D in _meshes(furniture):
			var transform := Roster._relative(part,art)
			for surface: int in range(part.mesh.get_surface_count()):
				var arrays := part.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
				if indices.is_empty():
					for vertex: Vector3 in vertices: triangles.append(transform*vertex)
				else:
					for index: int in indices: triangles.append(transform*vertices[index])
	var support_ok: bool = not support_points.is_empty() and not triangles.is_empty()
	var permitted_gap := 0.20 if id in ["lifeguard","model_family"] else 0.08
	for point: Vector3 in support_points:
		var supported: bool = false
		for triangle: int in range(0,triangles.size()-2,3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(point+Vector3(0,0.025,0),point-Vector3(0,permitted_gap,0),triangles[triangle],triangles[triangle+1],triangles[triangle+2])
			if hit is Vector3:
				supported = true
				break
		support_ok = support_ok and supported
	_check(support_ok,id+": actual chair/cabinet/desk triangles support every seated hip or animal foot")


func _site_state(art: Node3D, other: Node3D, id: String) -> void:
	var rig: Dictionary = art.get_meta("roster_rig")
	if not bool(rig.definition.get("site_resident",false)): return
	var other_rig: Dictionary = other.get_meta("roster_rig")
	Animator.reset(art)
	Animator.reset(other)
	var origin := art.transform
	var initial := _poses(art)
	var initial_vertices := _posed_vertices(art)
	var other_vertices := _posed_vertices(other)
	var initial_resources: Array = []
	for part: MeshInstance3D in _meshes(art): initial_resources.append([part.mesh,part.skin])
	var inert: bool = bool(rig.definition.get("inert",false))
	var action := StringName(rig.definition.get("action",&"talk"))
	if action.is_empty() and not inert: action = &"talk"
	var request := {"action":action,"action_phase":0.15,"local_velocity":Vector3.ZERO,"contact":true,"action_serial":9}
	var unchanged_request := request.duplicate(true)
	Animator.tick(art,0.03,request,2)
	var early := _posed_vertices(art)
	_check(request == unchanged_request and art.transform == origin,id+": site presentation cannot mutate the source request or actor origin")
	_check(_max_motion(other_vertices,_posed_vertices(other)) < 0.000001 and _poses(other) == initial,id+": another cached instance keeps its actual bones/geometry unchanged")
	Animator.tick(art,0.03,{"action":action,"action_phase":0.80,"action_serial":9},2)
	if not inert: _check(_max_motion(early,_posed_vertices(art)) > 0.001,id+": current action phase changes actual non-inert geometry even at distant detail")
	if inert:
		var still: bool = true
		for state: Dictionary in [{"local_velocity":Vector3(3,0,4),"turn_rate":2.0},{"action":&"wave","action_phase":0.5,"hurt":1.0,"gaze":Vector2(0.5,0.3)},{"dead":true,"death_phase":1.0,"action":&"strike","action_phase":0.0}]:
			Animator.tick(art,0.04,state,0)
			still = still and _poses(art) == initial and _max_motion(initial_vertices,_posed_vertices(art)) < 0.000001
		_check(still and float(rig.time) > 0.1,id+": model-family figures preserve every actual pose/vertex under movement, gestures, hurt and death while time advances")
	if rig.definition.family == "assembly":
		Animator.reset(art)
		var furniture := art.get_node("head") as Node3D
		var fixed := _rigid_vertices(furniture,art)
		var furniture_still: bool = true
		for state: Dictionary in [{"local_velocity":Vector3(2,0,2),"hurt":1.0,"gaze":Vector2(0.4,0.2)},{"action":action,"action_phase":0.6},{"dead":true,"death_phase":1.0}]:
			Animator.tick(art,0.04,state,0)
			furniture_still = furniture_still and _max_motion(fixed,_rigid_vertices(furniture,art)) < 0.000001
		_check(furniture_still and art.transform == origin,id+": actual assembly furniture never inherits a human fall, hurt or gaze pose")
		if rig.companions.size() > 1:
			Animator.reset(art)
			var sibling_geometry: Array[PackedVector3Array] = []
			for index: int in range(1,rig.companions.size()):
				sibling_geometry.append(_posed_vertices(rig.companions[index].node))
			var selected: Node3D = rig.companions[0].node
			var selected_rig: Dictionary = selected.get_meta("roster_rig")
			Animator.tick(selected,0.04,{"action":StringName(selected_rig.definition.get("action",&"talk")),"action_phase":0.5},0)
			var siblings_unchanged: bool = true
			for index: int in range(1,rig.companions.size()):
				siblings_unchanged = siblings_unchanged and _max_motion(sibling_geometry[index-1],_posed_vertices(rig.companions[index].node)) < 0.000001
			_check(siblings_unchanged,id+": directly posing one member cannot alter any sibling's actual geometry")
	Animator.reset(art)
	Animator.reset(other)
	for frame: int in range(11):
		Animator.tick(art,0.02,{},0)
		Animator.tick(other,0.02,{},2)
	var clocks: bool = is_equal_approx(float(rig.time),float(other_rig.time)) and float(rig.time) > 0.20
	for child: Dictionary in rig.companions:
		var peer := other.get_node_or_null(NodePath(String(child.node.name))) as Node3D
		if peer == null or not peer.has_meta("roster_rig"):
			clocks = false
			continue
		var child_rig: Dictionary = child.node.get_meta("roster_rig")
		var peer_rig: Dictionary = peer.get_meta("roster_rig")
		clocks = clocks and is_equal_approx(float(child_rig.time),float(peer_rig.time)) and float(child_rig.time) > 0.20
	_check(clocks,id+": reduced detail consumes current time for every independent child, including still figures")
	var before_invalid := _posed_vertices(art)
	var before_time: float = rig.time
	for invalid: float in [NAN,INF,0.0,-1.0]: Animator.tick(art,invalid,{"action":action,"action_phase":0.5,"dead":true})
	_check(float(rig.time) == before_time and _max_motion(before_invalid,_posed_vertices(art)) < 0.000001,id+": invalid elapsed time does not advance site or child geometry")
	Animator.tick(art,1000.0,{"local_velocity":Vector3(NAN,INF,-INF),"gaze":Vector2(NAN,INF),"action":{},"action_phase":NAN,"hurt":INF},2)
	_check(_bounded(_posed_vertices(art),Vector3(4.0,5.0,4.0)) and art.transform == origin,id+": malformed site snapshots remain finite without moving the origin")
	var resource_stable: bool = _meshes(art).size() == initial_resources.size()
	var parts := _meshes(art)
	for i: int in range(mini(parts.size(),initial_resources.size())):
		resource_stable = resource_stable and parts[i].mesh == initial_resources[i][0] and parts[i].skin == initial_resources[i][1]
	_check(resource_stable,id+": site actions preserve mesh/skin resources and mesh instance count")
	Animator.reset(art)
	Animator.reset(other)
	_check(_poses(art) == initial and _max_motion(initial_vertices,_posed_vertices(art)) < 0.000001,id+": reset restores the authored site and companion arrangement")
